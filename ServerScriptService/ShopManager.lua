-- @ScriptType: Script
-- @ScriptType: Script
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData")) 
local GameDataStore = DataStoreService:GetDataStore("AoT_Data_V5") 

local Network = ReplicatedStorage:WaitForChild("Network")
local GetShopData = Network:WaitForChild("GetShopData")
local BuyAction = Network:FindFirstChild("ShopAction") or Instance.new("RemoteEvent", Network)
BuyAction.Name = "ShopAction"
local NotificationEvent = Network:WaitForChild("NotificationEvent")

local PathNodes = {
	["Path of the Striker"] = { Stat = "DMG", Cost = 5, Increment = 5, MaxLevel = 10, Desc = "+5% Base Damage" },
	["Path of the Phantom"] = { Stat = "DODGE", Cost = 8, Increment = 2, MaxLevel = 10, Desc = "+2% Dodge Chance" },
	["Path of the Juggernaut"] = { Stat = "MAX HP", Cost = 5, Increment = 50, MaxLevel = 10, Desc = "+50 Max HP" },
	["Path of the Executioner"] = { Stat = "CRIT", Cost = 10, Increment = 2, MaxLevel = 10, Desc = "+2% Crit Chance" },
	["Path of the Breaker"] = { Stat = "IGNORE", Cost = 15, Increment = 5, MaxLevel = 5, Desc = "+5% Armor Penetration" }
}

-- Removed Serums from the Paths Shop
local RarePathsItems = {
	{ Name = "Coordinate's Sand", Cost = 100, Desc = "Godlike power. The rarest relic in the Paths." },
	{ Name = "Ymir's Clay Fragment", Cost = 200, Desc = "Awakens the Attack Titan into the Founding Attack Titan." },
	{ Name = "Titan Hardening Extract", Cost = 25, Desc = "Used in the Forge to Awaken max-tier weapons." }
}

local itemPool = {}

for name, data in pairs(ItemData.Equipment) do 
	if not data.IsGift then 
		table.insert(itemPool, {Name = name, Data = data}) 
	end
end

for name, data in pairs(ItemData.Consumables) do 
	-- STRICT FILTER: completely ban these keywords from the rotating shop
	local lowerName = string.lower(name)
	local isBannedFromShop = string.find(lowerName, "serum") 
		or string.find(lowerName, "vial") 
		or string.find(lowerName, "syringe")
		or string.find(lowerName, "itemized") 
		or name == "Ymir's Clay Fragment"
		or name == "Titan Hardening Extract"

	if not data.IsGift and not isBannedFromShop then 
		table.insert(itemPool, {Name = name, Data = data}) 
	end
end

local function GenerateShopItems(seed)
	local rng = Random.new(seed)
	local shopItems = {}
	local selectedNames = {}

	for i = 1, 6 do
		local roll = rng:NextNumber(0, 100)
		local targetRarity = "Common"

		if roll <= 0.2 then targetRarity = "Mythical"
		elseif roll <= 2.0 then targetRarity = "Legendary"
		elseif roll <= 10.0 then targetRarity = "Epic"
		elseif roll <= 30.0 then targetRarity = "Rare"
		elseif roll <= 60.0 then targetRarity = "Uncommon" end

		local validItems = {}
		for _, item in ipairs(itemPool) do
			if (item.Data.Rarity or "Common") == targetRarity and not selectedNames[item.Name] then
				table.insert(validItems, item)
			end
		end

		if #validItems == 0 then
			for _, item in ipairs(itemPool) do
				if not selectedNames[item.Name] then table.insert(validItems, item) end
			end
		end

		if #validItems > 0 then
			local picked = validItems[rng:NextInteger(1, #validItems)]
			selectedNames[picked.Name] = true
			table.insert(shopItems, {Name = picked.Name, Cost = picked.Data.Cost or 1000})
		else
			break
		end
	end
	return shopItems
end

GetShopData.OnServerInvoke = function(player, requestType)
	if requestType == "PathsShop" then
		local pData = {}
		for nodeName, nodeData in pairs(PathNodes) do
			local safeNodeName = string.gsub(nodeName, "[^%w]", "")
			local currentLvl = player:GetAttribute("PathNode_" .. safeNodeName) or 0

			table.insert(pData, {
				Name = nodeName, Desc = nodeData.Desc, 
				CurrentLevel = currentLvl, MaxLevel = nodeData.MaxLevel, 
				Cost = currentLvl < nodeData.MaxLevel and nodeData.Cost or "MAX"
			})
		end
		return { Nodes = pData, Items = RarePathsItems, Dust = player:GetAttribute("PathDust") or 0 }
	end

	local globalSeed = math.floor(os.time() / 600)
	local personalSeed = player:GetAttribute("PersonalShopSeed") or 0

	if player:GetAttribute("ShopSeedTime") ~= globalSeed then
		player:SetAttribute("PersonalShopSeed", nil); personalSeed = globalSeed
	end

	local activeSeed = player:GetAttribute("PersonalShopSeed") or globalSeed
	if player:GetAttribute("ShopPurchases_Seed") ~= activeSeed then
		player:SetAttribute("ShopPurchases_Seed", activeSeed)
		player:SetAttribute("ShopPurchases_Data", "")
	end

	local timeRemaining = 600 - (os.time() % 600)
	local items = GenerateShopItems(activeSeed)

	local boughtStr = player:GetAttribute("ShopPurchases_Data") or ""
	for _, item in ipairs(items) do
		if string.find(boughtStr, "%[" .. item.Name .. "%]") then item.SoldOut = true end
	end
	return { Items = items, TimeLeft = timeRemaining }
end

BuyAction.OnServerEvent:Connect(function(player, actionType, itemName)
	local targetPurchase = itemName
	if not itemName and actionType ~= "BuyPathNode" and actionType ~= "ClosePathsShop" and actionType ~= "BuyPathsItem" then
		targetPurchase = actionType
	end

	if actionType == "BuyPathNode" then
		local nodeData = PathNodes[targetPurchase]
		if not nodeData then return end

		local safeTarget = string.gsub(targetPurchase, "[^%w]", "")
		local currentLvl = player:GetAttribute("PathNode_" .. safeTarget) or 0

		if currentLvl >= nodeData.MaxLevel then return end

		local dust = player:GetAttribute("PathDust") or 0
		if dust >= nodeData.Cost then
			player:SetAttribute("PathDust", dust - nodeData.Cost)
			player:SetAttribute("PathNode_" .. safeTarget, currentLvl + 1)

			local currentString = player:GetAttribute("PathsAwakened") or ""
			local newString = ""
			for stat in string.gmatch(currentString, "[^|]+") do
				if not string.find(stat, nodeData.Stat) then newString = newString .. stat .. "|" end
			end
			local totalStatValue = (currentLvl + 1) * nodeData.Increment
			newString = newString .. " +" .. totalStatValue .. " " .. nodeData.Stat .. "|"
			player:SetAttribute("PathsAwakened", newString)

			NotificationEvent:FireClient(player, "Coordinate Memory Unlocked!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Path Dust!", "Error")
		end
		return

	elseif actionType == "BuyPathsItem" then
		local itemDef = nil
		for _, it in ipairs(RarePathsItems) do if it.Name == targetPurchase then itemDef = it; break end end
		if not itemDef then return end

		local dust = player:GetAttribute("PathDust") or 0
		if dust >= itemDef.Cost then
			player:SetAttribute("PathDust", dust - itemDef.Cost)
			local safeName = targetPurchase:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + 1)
			NotificationEvent:FireClient(player, "Obtained " .. targetPurchase .. " from the Paths!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Path Dust!", "Error")
		end
		return

	elseif actionType == "ClosePathsShop" then
		player:SetAttribute("PathDust", 0)
		NotificationEvent:FireClient(player, "Path Dust scattered. Returning to reality.", "Info")
		return
	end

	local globalSeed = math.floor(os.time() / 600)
	local activeSeed = player:GetAttribute("PersonalShopSeed") or globalSeed
	local availableItems = GenerateShopItems(activeSeed)

	local targetItem = nil
	for _, item in ipairs(availableItems) do
		if item.Name == targetPurchase then targetItem = item; break end
	end

	if targetItem then
		local boughtStr = player:GetAttribute("ShopPurchases_Data") or ""
		if string.find(boughtStr, "%[" .. targetItem.Name .. "%]") then return end 

		if GameData.GetInventoryCount(player) >= GameData.GetMaxInventory(player) then
			NotificationEvent:FireClient(player, "Your inventory is full! Sell items at the Forge.", "Error")
			return
		end

		if player.leaderstats.Dews.Value >= targetItem.Cost then
			player.leaderstats.Dews.Value -= targetItem.Cost
			local attrName = targetItem.Name:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(attrName, (player:GetAttribute(attrName) or 0) + 1)
			player:SetAttribute("ShopPurchases_Data", boughtStr .. "[" .. targetItem.Name .. "]")
			NotificationEvent:FireClient(player, "Purchased " .. targetItem.Name .. "!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Dews!", "Error")
		end
	end
end)

local VIPFreeReroll = Network:FindFirstChild("VIPFreeReroll") or Instance.new("RemoteEvent", Network)
VIPFreeReroll.Name = "VIPFreeReroll"

VIPFreeReroll.OnServerEvent:Connect(function(player, isDews)
	local canReroll = false

	if isDews then
		local dews = player.leaderstats and player.leaderstats:FindFirstChild("Dews")
		if dews and dews.Value >= 300000 then
			dews.Value -= 300000
			canReroll = true
		end
	else
		local hasVIP = player:GetAttribute("HasVIP")
		local lastRoll = player:GetAttribute("LastFreeReroll") or 0
		if hasVIP and (os.time() - lastRoll) >= 86400 then
			player:SetAttribute("LastFreeReroll", os.time())
			canReroll = true
		end
	end

	if canReroll then
		local newSeed = math.random(1, 9999999)
		player:SetAttribute("PersonalShopSeed", newSeed)
		player:SetAttribute("ShopSeedTime", math.floor(os.time() / 600))
		player:SetAttribute("ShopPurchases_Seed", newSeed)
		player:SetAttribute("ShopPurchases_Data", "")
		NotificationEvent:FireClient(player, "Shop Successfully Rerolled!", "Success")
	else
		NotificationEvent:FireClient(player, "Reroll failed. Missing requirements.", "Error")
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	for _, prod in ipairs(ItemData.Products) do
		if prod.ID == receiptInfo.ProductId then
			if prod.IsReroll then
				local newSeed = math.random(1, 9999999)
				player:SetAttribute("PersonalShopSeed", newSeed); player:SetAttribute("ShopSeedTime", math.floor(os.time() / 600))
				player:SetAttribute("ShopPurchases_Seed", newSeed); player:SetAttribute("ShopPurchases_Data", "")
				NotificationEvent:FireClient(player, "Shop Successfully Rerolled!", "Success")
			elseif prod.Reward == "Dews" then
				player.leaderstats.Dews.Value += prod.Amount
				NotificationEvent:FireClient(player, "Purchased " .. prod.Amount .. " Dews!", "Success")
			elseif prod.Reward == "Item" then
				local attrName = prod.ItemName:gsub("[^%w]", "") .. "Count"
				player:SetAttribute(attrName, (player:GetAttribute(attrName) or 0) + prod.Amount)
				NotificationEvent:FireClient(player, "Purchased " .. prod.ItemName .. "!", "Success")
			end

			task.spawn(function()
				local d = { Prestige = player.leaderstats.Prestige.Value, Dews = player.leaderstats.Dews.Value, Elo = player.leaderstats.Elo.Value }
				for k, v in pairs(player:GetAttributes()) do if k ~= "DataLoaded" then d[k] = v end end
				pcall(function() GameDataStore:SetAsync(player.UserId, d) end)
			end)

			break
		end
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end