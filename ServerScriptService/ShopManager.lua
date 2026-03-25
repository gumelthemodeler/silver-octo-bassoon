-- @ScriptType: Script
-- @ScriptType: Script
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local Network = ReplicatedStorage:WaitForChild("Network")
local GetShopData = Network:WaitForChild("GetShopData")
local BuyAction = Network:FindFirstChild("ShopAction") or Instance.new("RemoteEvent", Network)
BuyAction.Name = "ShopAction"

-- [[ THE FIX: Use WaitForChild to guarantee the remote exists ]]
local NotificationEvent = Network:WaitForChild("NotificationEvent")

-- Combine all equipment and consumables into a single pool for the RNG
local itemPool = {}
for name, data in pairs(ItemData.Equipment) do table.insert(itemPool, {Name = name, Data = data}) end
for name, data in pairs(ItemData.Consumables) do table.insert(itemPool, {Name = name, Data = data}) end

local function GenerateShopItems(seed)
	local rng = Random.new(seed)
	local shopItems = {}
	local selectedNames = {}

	for i = 1, 6 do
		local roll = rng:NextNumber(0, 100)
		local targetRarity = "Common"

		-- Weighted Rarity System: Allows Mythicals and Legendaries to appear!
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

		-- Fallback: If no items of that rarity are left, pick literally anything available
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

GetShopData.OnServerInvoke = function(player)
	local globalSeed = math.floor(os.time() / 600)
	local personalSeed = player:GetAttribute("PersonalShopSeed") or 0

	if player:GetAttribute("ShopSeedTime") ~= globalSeed then
		player:SetAttribute("PersonalShopSeed", nil)
		personalSeed = globalSeed
	end

	local activeSeed = player:GetAttribute("PersonalShopSeed") or globalSeed
	if player:GetAttribute("ShopPurchases_Seed") ~= activeSeed then
		player:SetAttribute("ShopPurchases_Seed", activeSeed)
		player:SetAttribute("ShopPurchases_Data", "") -- Reset bought items on new shop rotation
	end

	local timeRemaining = 600 - (os.time() % 600)
	local items = GenerateShopItems(activeSeed)

	-- Mark items as sold out if the player already bought them in this rotation
	local boughtStr = player:GetAttribute("ShopPurchases_Data") or ""
	for _, item in ipairs(items) do
		if string.find(boughtStr, "%[" .. item.Name .. "%]") then
			item.SoldOut = true
		end
	end

	return { Items = items, TimeLeft = timeRemaining }
end

BuyAction.OnServerEvent:Connect(function(player, itemName)
	local globalSeed = math.floor(os.time() / 600)
	local activeSeed = player:GetAttribute("PersonalShopSeed") or globalSeed
	local availableItems = GenerateShopItems(activeSeed)

	local targetItem = nil
	for _, item in ipairs(availableItems) do
		if item.Name == itemName then targetItem = item; break end
	end

	if targetItem then
		local boughtStr = player:GetAttribute("ShopPurchases_Data") or ""
		if string.find(boughtStr, "%[" .. targetItem.Name .. "%]") then return end -- Block double purchase!

		if player.leaderstats.Dews.Value >= targetItem.Cost then
			player.leaderstats.Dews.Value -= targetItem.Cost
			local attrName = itemName:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(attrName, (player:GetAttribute(attrName) or 0) + 1)

			player:SetAttribute("ShopPurchases_Data", boughtStr .. "[" .. targetItem.Name .. "]")

			NotificationEvent:FireClient(player, "Purchased " .. itemName .. "!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Dews!", "Error")
		end
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	for _, prod in ipairs(ItemData.Products) do
		if prod.ID == receiptInfo.ProductId then
			if prod.IsReroll then
				local newSeed = math.random(1, 9999999)
				player:SetAttribute("PersonalShopSeed", newSeed)
				player:SetAttribute("ShopSeedTime", math.floor(os.time() / 600))
				player:SetAttribute("ShopPurchases_Seed", newSeed)
				player:SetAttribute("ShopPurchases_Data", "")
				NotificationEvent:FireClient(player, "Shop Successfully Rerolled!", "Success")
			elseif prod.Reward == "Dews" then
				player.leaderstats.Dews.Value += prod.Amount
				NotificationEvent:FireClient(player, "Purchased " .. prod.Amount .. " Dews!", "Success")
			elseif prod.Reward == "Item" then
				local attrName = prod.ItemName:gsub("[^%w]", "") .. "Count"
				player:SetAttribute(attrName, (player:GetAttribute(attrName) or 0) + prod.Amount)
				NotificationEvent:FireClient(player, "Purchased " .. prod.ItemName .. "!", "Success")
			end
			break
		end
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end