-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local TitanData = require(ReplicatedStorage:WaitForChild("TitanData"))

local Network = ReplicatedStorage:WaitForChild("Network")
local NotificationEvent = Network:WaitForChild("NotificationEvent")
local GachaResult = Network:WaitForChild("GachaResult")

local SellValues = { Common = 10, Uncommon = 25, Rare = 75, Epic = 200, Legendary = 500, Mythical = 1500, Transcendent = 0 }

local FusionRecipes = { 
	["Female Titan"] = { ["Founding Titan"] = "Founding Female Titan" }, 
	["Founding Titan"] = { ["Female Titan"] = "Founding Female Titan" }, 
	["Attack Titan"] = { ["Armored Titan"] = "Armored Attack Titan", ["War Hammer Titan"] = "War Hammer Attack Titan" }, 
	["Armored Titan"] = { ["Attack Titan"] = "Armored Attack Titan" }, 
	["War Hammer Titan"] = { ["Attack Titan"] = "War Hammer Attack Titan" }, 
	["Colossal Titan"] = { ["Jaw Titan"] = "Colossal Jaw Titan" }, 
	["Jaw Titan"] = { ["Colossal Titan"] = "Colossal Jaw Titan" } 
}

-- [[ INVENTORY MANAGEMENT ]]
Network:WaitForChild("EquipItem").OnServerEvent:Connect(function(player, itemName)
	if string.match(itemName, "^Unequip_") then
		local slotType = string.gsub(itemName, "Unequip_", "")
		if slotType == "Weapon" then
			player:SetAttribute("EquippedWeapon", "None")
			player:SetAttribute("FightingStyle", "None")
		elseif slotType == "Accessory" then
			player:SetAttribute("EquippedAccessory", "None")
		end
		return
	end

	local itemInfo = ItemData.Equipment[itemName]
	if itemInfo then
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		local count = player:GetAttribute(safeName) or 0
		if count > 0 then
			if itemInfo.Type == "Weapon" then
				player:SetAttribute("EquippedWeapon", itemName)
				player:SetAttribute("FightingStyle", itemInfo.Style or "None")
			elseif itemInfo.Type == "Accessory" then
				player:SetAttribute("EquippedAccessory", itemName)
			end
		end
	end
end)

Network:WaitForChild("SellItem").OnServerEvent:Connect(function(player, itemName, sellAll)
	local itemInfo = ItemData.Equipment[itemName] or ItemData.Consumables[itemName]
	if itemInfo then
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		local count = player:GetAttribute(safeName) or 0
		if count > 0 then
			local sellPrice = SellValues[itemInfo.Rarity or "Common"] or 10
			local amountToSell = sellAll and count or 1

			player:SetAttribute(safeName, count - amountToSell)
			player.leaderstats.Dews.Value += (sellPrice * amountToSell)
		end
	end
end)

Network:WaitForChild("AutoSell").OnServerEvent:Connect(function(player, rarity)
	local attrName = "AutoSell_" .. rarity
	player:SetAttribute(attrName, not player:GetAttribute(attrName))
end)

-- [[ CONSUMABLES & BUFFS ]]
Network:WaitForChild("ConsumeItem").OnServerEvent:Connect(function(player, itemName)
	local itemInfo = ItemData.Consumables[itemName]
	if itemInfo and itemInfo.Action == "Consume" then
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		local count = player:GetAttribute(safeName) or 0
		if count > 0 then
			player:SetAttribute(safeName, count - 1)

			if itemInfo.Buff == "Dews" then
				local amt = math.random(itemInfo.MinAmount or 5000, itemInfo.MaxAmount or 20000)
				player.leaderstats.Dews.Value += amt
				NotificationEvent:FireClient(player, "Gained " .. amt .. " Dews!", "Success")
			elseif itemInfo.Buff == "Gamepass" then
				player:SetAttribute("Has" .. itemInfo.Unlock, true)
				NotificationEvent:FireClient(player, "Unlocked " .. itemInfo.Unlock .. "!", "Success")
			else
				local expiryAttr = "Buff_" .. itemInfo.Buff .. "_Expiry"
				player:SetAttribute(expiryAttr, os.time() + (itemInfo.Duration or 900))
			end
		end
	end
end)

-- [[ FORGE & AWAKENING ]]
Network:WaitForChild("ForgeItem").OnServerEvent:Connect(function(player, reqItem)
	local recipe = ItemData.ForgeRecipes[reqItem]
	if recipe then
		local safeReq = reqItem:gsub("[^%w]", "") .. "Count"
		local count = player:GetAttribute(safeReq) or 0
		local dews = player.leaderstats.Dews.Value

		if count >= recipe.ReqAmt and dews >= recipe.DewCost then
			player:SetAttribute(safeReq, count - recipe.ReqAmt)
			player.leaderstats.Dews.Value -= recipe.DewCost

			local resSafeName = recipe.Result:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(resSafeName, (player:GetAttribute(resSafeName) or 0) + 1)
			NotificationEvent:FireClient(player, "Forged " .. recipe.Result .. "!", "Success")
		end
	end
end)

Network:WaitForChild("AwakenWeapon").OnServerEvent:Connect(function(player, weaponName)
	local extracts = player:GetAttribute("TitanHardeningExtractCount") or 0
	if extracts >= 1 then
		local safeWpn = weaponName:gsub("[^%w]", "")
		if (player:GetAttribute(safeWpn .. "Count") or 0) > 0 then
			player:SetAttribute("TitanHardeningExtractCount", extracts - 1)

			local possibleStats = { "DMG", "DODGE", "CRIT", "MAX HP", "SPEED", "GAS CAP", "IGNORE ARMOR" }
			local stat1 = possibleStats[math.random(1, #possibleStats)]
			local stat2 = possibleStats[math.random(1, #possibleStats)]

			local val1 = math.random(5, 25)
			local val2 = math.random(5, 25)

			local statStr = "+" .. val1 .. (stat1 == "MAX HP" and "" or "%") .. " " .. stat1 .. " | +" .. val2 .. (stat2 == "MAX HP" and "" or "%") .. " " .. stat2
			player:SetAttribute(safeWpn .. "_Awakened", statStr)
			NotificationEvent:FireClient(player, weaponName .. " Awakened!", "Success")
		end
	end
end)

Network:WaitForChild("AwakenAction").OnServerEvent:Connect(function(player, actionType)
	if actionType == "Clan" then
		local count = player:GetAttribute("AncestralAwakeningSerumCount") or 0
		if count >= 1 and player:GetAttribute("Clan") == "Ackerman" then
			player:SetAttribute("AncestralAwakeningSerumCount", count - 1)
			player:SetAttribute("Clan", "Awakened Ackerman")
			NotificationEvent:FireClient(player, "Ackerman Bloodline Awakened!", "Success")
		end
	elseif actionType == "Titan" then
		local count = player:GetAttribute("YmirsClayFragmentCount") or 0
		if count >= 1 and player:GetAttribute("Titan") == "Attack Titan" then
			player:SetAttribute("YmirsClayFragmentCount", count - 1)
			player:SetAttribute("Titan", "Founding Titan")
			NotificationEvent:FireClient(player, "You have reached the Coordinate!", "Success")
		end
	end
end)

Network:WaitForChild("FuseTitan").OnServerEvent:Connect(function(player, slotIndex)
	local dews = player.leaderstats.Dews.Value
	if dews >= 50000 then
		local currentTitan = player:GetAttribute("Titan") or "None"
		local storedTitan = player:GetAttribute("Titan_Slot" .. slotIndex) or "None"
		local result = FusionRecipes[currentTitan] and FusionRecipes[currentTitan][storedTitan]

		if result then
			player.leaderstats.Dews.Value -= 50000
			player:SetAttribute("Titan_Slot" .. slotIndex, "None")
			player:SetAttribute("Titan", result)
			-- UI cinematic triggers based on Attribute change
		end
	end
end)

-- [[ STORAGE MANAGEMENT ]]
Network:WaitForChild("ManageStorage").OnServerEvent:Connect(function(player, gType, slotIndex)
	local currentAttr = (gType == "Titan") and "Titan" or "Clan"
	local slotAttr = currentAttr .. "_Slot" .. slotIndex

	local currentVal = player:GetAttribute(currentAttr) or "None"
	local slotVal = player:GetAttribute(slotAttr) or "None"

	player:SetAttribute(currentAttr, slotVal)
	player:SetAttribute(slotAttr, currentVal)
end)

-- [[ GACHA SYSTEM ]]
local function HandleRoll(player, gType, isPremium)
	local attrReq = ""
	if gType == "Titan" then
		attrReq = isPremium and "SpinalFluidSyringeCount" or "StandardTitanSerumCount"
	else
		attrReq = "ClanBloodVialCount"
	end

	local itemsOwned = player:GetAttribute(attrReq) or 0
	if itemsOwned > 0 then
		player:SetAttribute(attrReq, itemsOwned - 1)

		local resultName, rarity
		if gType == "Titan" then
			local legPity = player:GetAttribute("TitanPity") or 0
			local mythPity = player:GetAttribute("TitanMythicalPity") or 0
			if isPremium then legPity += 100 end -- Guarantee Legendary+

			resultName, rarity = TitanData.RollTitan(legPity, mythPity)

			if rarity == "Mythical" then
				player:SetAttribute("TitanPity", 0)
				player:SetAttribute("TitanMythicalPity", 0)
			elseif rarity == "Legendary" then
				player:SetAttribute("TitanPity", 0)
				player:SetAttribute("TitanMythicalPity", mythPity + 1)
			else
				player:SetAttribute("TitanPity", legPity + 1)
				player:SetAttribute("TitanMythicalPity", mythPity + 1)
			end
		else
			resultName = TitanData.RollClan()
			local weight = TitanData.ClanWeights[resultName] or 40
			if weight <= 1.5 then rarity = "Mythical"
			elseif weight <= 4.0 then rarity = "Legendary"
			elseif weight <= 8.0 then rarity = "Epic"
			elseif weight <= 15.0 then rarity = "Rare"
			else rarity = "Common" end
		end

		player:SetAttribute(gType, resultName)
		GachaResult:FireClient(player, gType, resultName, rarity)
		return rarity
	end
	return nil
end

Network:WaitForChild("GachaRoll").OnServerEvent:Connect(function(player, gType, isPremium)
	HandleRoll(player, gType, isPremium)
end)

Network:WaitForChild("GachaRollAuto").OnServerEvent:Connect(function(player, gType)
	-- Loop until a high rarity is hit or user runs out of items
	local maxRolls = 50 -- Safety breaker to prevent freezing
	for i = 1, maxRolls do
		local rarity = HandleRoll(player, gType, false)
		if not rarity then break end
		if rarity == "Legendary" or rarity == "Mythical" or rarity == "Transcendent" then
			break
		end
		task.wait(0.05) -- Fast roll effect
	end
end)

-- [[ TRAINING & STATS ]]
Network:WaitForChild("TrainAction").OnServerEvent:Connect(function(player, combo, isTitan)
	local prestige = player.leaderstats and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
	local totalStats = (player:GetAttribute("Strength") or 10) + (player:GetAttribute("Defense") or 10) + (player:GetAttribute("Speed") or 10) + (player:GetAttribute("Resolve") or 10)

	local baseXP = 1 + (prestige * 50) + math.floor(totalStats / 4)
	local xpGain = math.floor(baseXP * (1.0 + (combo * 0.02)))

	local targetAttr = isTitan and "TitanXP" or "XP"
	player:SetAttribute(targetAttr, (player:GetAttribute(targetAttr) or 0) + xpGain)
end)

Network:WaitForChild("UpgradeStat").OnServerEvent:Connect(function(player, statName, amount)
	local isTitanStat = string.match(statName, "Titan_.*_Val$")
	local xpAttr = isTitanStat and "TitanXP" or "XP"

	local currentStat = player:GetAttribute(statName) or 10
	if type(currentStat) == "string" then currentStat = GameData.TitanRanks[currentStat] or 10 end

	local prestige = player.leaderstats and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
	local cleanName = statName:gsub("_Val", ""):gsub("Titan_", "")
	local base = (prestige == 0) and (GameData.BaseStats[cleanName] or 10) or (prestige * 5)
	local statCap = GameData.GetStatCap(prestige)

	local totalCost = 0
	local pXP = player:GetAttribute(xpAttr) or 0

	for i = 0, amount - 1 do
		if currentStat + i >= statCap then break end
		totalCost += GameData.CalculateStatCost(currentStat + i, base, prestige)
	end

	if pXP >= totalCost and totalCost > 0 then
		player:SetAttribute(xpAttr, pXP - totalCost)
		player:SetAttribute(statName, currentStat + amount)
	end
end)