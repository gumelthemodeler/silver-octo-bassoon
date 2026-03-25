-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local TitanData = require(ReplicatedStorage:WaitForChild("TitanData"))

local RemotesFolder = ReplicatedStorage:WaitForChild("Network")

local function UpdateBountyProgress(plr, taskType, amt)
	for i = 1, 3 do
		if plr:GetAttribute("D"..i.."_Task") == taskType and not plr:GetAttribute("D"..i.."_Claimed") then
			local p = plr:GetAttribute("D"..i.."_Prog") or 0; local m = plr:GetAttribute("D"..i.."_Max") or 1
			plr:SetAttribute("D"..i.."_Prog", math.min(p + amt, m))
		end
	end
	if plr:GetAttribute("W1_Task") == taskType and not plr:GetAttribute("W1_Claimed") then
		local p = plr:GetAttribute("W1_Prog") or 0; local m = plr:GetAttribute("W1_Max") or 1
		plr:SetAttribute("W1_Prog", math.min(p + amt, m))
	end
end

RemotesFolder:WaitForChild("PrestigeEvent").OnServerEvent:Connect(function(player)
	if player.leaderstats.Prestige.Value >= 10 then return end
	if (player:GetAttribute("CurrentPart") or 1) > 8 then
		player.leaderstats.Prestige.Value += 1
		player:SetAttribute("CurrentPart", 1); player:SetAttribute("CurrentWave", 1); player:SetAttribute("XP", 0)
		for _, s in ipairs({"Health", "Strength", "Defense", "Speed", "Gas", "Resolve"}) do player:SetAttribute(s, 10) end
	end
end)

RemotesFolder:WaitForChild("UpgradeStat").OnServerEvent:Connect(function(player, statName, amount)
	local prestige = player.leaderstats.Prestige.Value; local statCap = GameData.GetStatCap(prestige)
	local currentStat = player:GetAttribute(statName) or 1
	if type(currentStat) == "string" then currentStat = GameData.TitanRanks[currentStat] or 10 end
	if currentStat >= statCap then return end

	local isTitanStat = string.find(statName, "Titan_"); local xpPoolName = isTitanStat and "TitanXP" or "XP"
	local currentXP = player:GetAttribute(xpPoolName) or 0
	local cleanName = statName:gsub("_Val", ""):gsub("Titan_", ""); local base = (prestige == 0) and (GameData.BaseStats[cleanName] or 0) or (prestige * 5)
	local targetAdd = (amount == "MAX") and 9999 or amount; local added = 0

	for i = 0, targetAdd - 1 do
		if currentStat + added >= statCap then break end
		local stepCost = GameData.CalculateStatCost(currentStat + added, base, prestige)
		if currentXP >= stepCost then currentXP -= stepCost; added += 1 else break end
	end
	if added > 0 then player:SetAttribute(xpPoolName, currentXP); player:SetAttribute(statName, currentStat + added) end
end)

RemotesFolder:WaitForChild("TrainAction").OnServerEvent:Connect(function(player, comboBonus, isTitan)
	player:SetAttribute("AutoTrainSessionTime", 0) 
	local prestige = player.leaderstats.Prestige.Value
	local totalStats = (player:GetAttribute("Strength") or 10) + (player:GetAttribute("Defense") or 10) + (player:GetAttribute("Speed") or 10) + (player:GetAttribute("Resolve") or 10)
	local baseXP = 1 + (prestige * 50) + math.floor(totalStats / 4)
	local xpGain = math.floor(baseXP * (1.0 + ((comboBonus or 0) * 0.1)))

	if player:GetAttribute("HasDoubleXP") then xpGain *= 2 end
	if player:GetAttribute("Buff_XP_Expiry") and os.time() < player:GetAttribute("Buff_XP_Expiry") then xpGain *= 2 end

	local winReg = RemotesFolder:FindFirstChild("WinningRegiment")
	if winReg and winReg.Value ~= "None" and player:GetAttribute("Regiment") == winReg.Value then xpGain = math.floor(xpGain * 1.15) end

	local xpPoolName = isTitan and "TitanXP" or "XP"
	player:SetAttribute(xpPoolName, (player:GetAttribute(xpPoolName) or 0) + xpGain)
end)

local MAX_AFK_TIME = 43200 -- 12 Hours in seconds

task.spawn(function()
	while true do
		task.wait(1.5) 
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("HasAutoTrain") then
				local sessionTime = p:GetAttribute("AutoTrainSessionTime") or 0

				if sessionTime < MAX_AFK_TIME then
					p:SetAttribute("AutoTrainSessionTime", sessionTime + 1.5)

					local prestige = p:FindFirstChild("leaderstats") and p.leaderstats.Prestige.Value or 0
					local baseGain = math.max(1, math.floor((1 + (prestige * 5)) * 0.25))

					if p:GetAttribute("HasDoubleXP") then baseGain *= 2 end
					if p:GetAttribute("HasVIP") then baseGain = math.floor(baseGain * 1.25) end
					if p:GetAttribute("Buff_XP_Expiry") and os.time() < p:GetAttribute("Buff_XP_Expiry") then baseGain *= 2 end

					local winReg = RemotesFolder:FindFirstChild("WinningRegiment")
					if winReg and winReg.Value ~= "None" and p:GetAttribute("Regiment") == winReg.Value then baseGain = math.floor(baseGain * 1.15) end

					p:SetAttribute("XP", (p:GetAttribute("XP") or 0) + baseGain)
					if (p:GetAttribute("Titan") or "None") ~= "None" then p:SetAttribute("TitanXP", (p:GetAttribute("TitanXP") or 0) + baseGain) end
				end
			end
		end
	end
end)

RemotesFolder:WaitForChild("VIPFreeReroll").OnServerEvent:Connect(function(player, useDews)
	if useDews then
		if player.leaderstats.Dews.Value >= 100000 then player.leaderstats.Dews.Value -= 100000; player:SetAttribute("PersonalShopSeed", math.random(1, 9999999)); player:SetAttribute("ShopSeedTime", math.floor(os.time() / 600))
		else RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews to restock!", "Error") end
	else
		if not player:GetAttribute("HasVIP") then return end
		local lastRoll = player:GetAttribute("LastFreeReroll") or 0; local now = os.time()
		if now - lastRoll >= 86400 then player:SetAttribute("LastFreeReroll", now); player:SetAttribute("PersonalShopSeed", math.random(1, 9999999)); player:SetAttribute("ShopSeedTime", math.floor(os.time() / 600)) end
	end
end)

RemotesFolder:WaitForChild("EquipItem").OnServerEvent:Connect(function(player, itemName)
	if itemName == "Unequip_Weapon" then player:SetAttribute("EquippedWeapon", "None"); player:SetAttribute("FightingStyle", "None")
	elseif itemName == "Unequip_Accessory" then player:SetAttribute("EquippedAccessory", "None")
	else
		local itemData = ItemData.Equipment[itemName]
		if not itemData then return end
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		if (player:GetAttribute(safeName) or 0) > 0 then
			if itemData.Type == "Weapon" then player:SetAttribute("EquippedWeapon", itemName); player:SetAttribute("FightingStyle", itemData.Style or "None")
			elseif itemData.Type == "Accessory" then player:SetAttribute("EquippedAccessory", itemName) end
		end
	end
end)

local SellValues = { Common = 10, Uncommon = 25, Rare = 75, Epic = 200, Legendary = 500, Mythical = 1500 }
RemotesFolder:WaitForChild("SellItem").OnServerEvent:Connect(function(player, itemName)
	local safeName = itemName:gsub("[^%w]", "") .. "Count"; local count = player:GetAttribute(safeName) or 0
	if count > 0 then
		local iData = ItemData.Equipment[itemName] or ItemData.Consumables[itemName]
		if iData then
			player:SetAttribute(safeName, count - 1); player.leaderstats.Dews.Value += (SellValues[iData.Rarity or "Common"] or 10)
			if (count - 1) == 0 then
				if player:GetAttribute("EquippedWeapon") == itemName then player:SetAttribute("EquippedWeapon", "None"); player:SetAttribute("FightingStyle", "None") end
				if player:GetAttribute("EquippedAccessory") == itemName then player:SetAttribute("EquippedAccessory", "None") end
			end
		end
	end
end)

RemotesFolder:WaitForChild("AutoSell").OnServerEvent:Connect(function(player, targetRarity)
	if targetRarity == "Legendary" or targetRarity == "Mythical" or targetRarity == "Transcendent" then return end
	local totalEarned = 0
	for iName, iData in pairs(ItemData.Equipment) do
		if (iData.Rarity or "Common") == targetRarity then
			local safeName = iName:gsub("[^%w]", "") .. "Count"; local count = player:GetAttribute(safeName) or 0
			if count > 0 then
				totalEarned += count * (SellValues[targetRarity] or 10); player:SetAttribute(safeName, 0)
				if player:GetAttribute("EquippedWeapon") == iName then player:SetAttribute("EquippedWeapon", "None"); player:SetAttribute("FightingStyle", "None") end
				if player:GetAttribute("EquippedAccessory") == iName then player:SetAttribute("EquippedAccessory", "None") end
			end
		end
	end
	if totalEarned > 0 then player.leaderstats.Dews.Value += totalEarned end
end)

local ClanAwakeningMap = { ["Ackerman"] = "Awakened Ackerman", ["Yeager"] = "Awakened Yeager", ["Reiss"] = "Awakened Reiss", ["Tybur"] = "Awakened Tybur", ["Arlert"] = "Awakened Arlert" }
RemotesFolder:WaitForChild("AwakenAction").OnServerEvent:Connect(function(player, aType)
	if aType == "Titan" then
		if player:GetAttribute("Titan") == "Attack Titan" and (player:GetAttribute("YmirsClayFragmentCount") or 0) > 0 then
			player:SetAttribute("YmirsClayFragmentCount", player:GetAttribute("YmirsClayFragmentCount") - 1); player:SetAttribute("Titan", "Founding Titan (Coordinate)")
			RemotesFolder.NotificationEvent:FireClient(player, "The Attack Titan has reached the Coordinate...", "Success")
		end
	elseif aType == "Clan" then
		local currentClan = player:GetAttribute("Clan") or "None"; local targetAwakened = ClanAwakeningMap[currentClan]
		if not targetAwakened then RemotesFolder.NotificationEvent:FireClient(player, "Your current clan lineage cannot be awakened.", "Error"); return end
		local count = player:GetAttribute("AncestralAwakeningSerumCount") or 0
		if count > 0 then
			player:SetAttribute("AncestralAwakeningSerumCount", count - 1); player:SetAttribute("Clan", targetAwakened)
			RemotesFolder.NotificationEvent:FireClient(player, "Your bloodline has awakened to " .. targetAwakened .. "!", "Success")
		else RemotesFolder.NotificationEvent:FireClient(player, "You need an Ancestral Awakening Serum to do this!", "Error") end
	end
end)

RemotesFolder:WaitForChild("ConsumeItem").OnServerEvent:Connect(function(player, itemName)
	local safeName = itemName:gsub("[^%w]", "") .. "Count"; local count = player:GetAttribute(safeName) or 0
	if count > 0 then
		local itemData = ItemData.Consumables[itemName]
		if itemData and itemData.Action == "Consume" then
			if itemData.Buff == "Gamepass" and itemData.Unlock then
				if player:GetAttribute("Has" .. itemData.Unlock) == true then RemotesFolder.NotificationEvent:FireClient(player, "You already own this Gamepass!", "Error"); return end
				player:SetAttribute("Has" .. itemData.Unlock, true); RemotesFolder.NotificationEvent:FireClient(player, "Unlocked Gamepass: " .. itemData.Unlock .. "!", "Success")
			end
			player:SetAttribute(safeName, count - 1)
			if itemData.Buff == "Dews" then player.leaderstats.Dews.Value += (itemData.Amount or 500)
			elseif itemData.Buff == "Damage" then player:SetAttribute("Buff_Damage_Expiry", os.time() + (itemData.Duration or 60))
			elseif itemData.Buff == "XP" then player:SetAttribute("Buff_XP_Expiry", os.time() + (itemData.Duration or 60)) end
		end
	end
end)

RemotesFolder:WaitForChild("PathsShopBuy").OnServerEvent:Connect(function(player, itemType)
	local dust = player:GetAttribute("PathDust") or 0
	if itemType == "Serum" and dust >= 100 then
		player:SetAttribute("PathDust", dust - 100); player:SetAttribute("AncestralAwakeningSerumCount", (player:GetAttribute("AncestralAwakeningSerumCount") or 0) + 1)
		RemotesFolder.NotificationEvent:FireClient(player, "Purchased Ancestral Awakening Serum!", "Success")
	elseif itemType == "Extract" and dust >= 25 then
		player:SetAttribute("PathDust", dust - 25); player:SetAttribute("TitanHardeningExtractCount", (player:GetAttribute("TitanHardeningExtractCount") or 0) + 1)
		RemotesFolder.NotificationEvent:FireClient(player, "Purchased Titan Hardening Extract!", "Success")
	elseif itemType == "Sand" and dust >= 500 then
		player:SetAttribute("PathDust", dust - 500); player:SetAttribute("CoordinatesSandCount", (player:GetAttribute("CoordinatesSandCount") or 0) + 1)
		RemotesFolder.NotificationEvent:FireClient(player, "Purchased Coordinate's Sand!", "Success")
	else RemotesFolder.NotificationEvent:FireClient(player, "Not enough Path Dust!", "Error") end
end)

local PossibleSubstats = { "+10% DMG", "+15% DMG", "+20% DODGE", "+5% CRIT", "+10% CRIT", "+15% CRIT", "+20 MAX HP", "+50 MAX HP", "+100 MAX HP", "+10% SPEED", "+20% SPEED", "+30% SPEED", "+15 GAS CAP", "+30 GAS CAP", "HEAL 5% HP ON KILL", "IGNORE 10% ARMOR" }
RemotesFolder:WaitForChild("AwakenWeapon").OnServerEvent:Connect(function(player, itemName)
	if not itemName then return end
	local extractCount = player:GetAttribute("TitanHardeningExtractCount") or 0
	if extractCount < 1 then RemotesFolder.NotificationEvent:FireClient(player, "Not enough Titan Hardening Extract!", "Error"); return end
	local safeNameBase = itemName:gsub("[^%w]", ""); local owned = player:GetAttribute(safeNameBase .. "Count") or 0
	if owned < 1 then return end

	player:SetAttribute("TitanHardeningExtractCount", extractCount - 1)
	local numStats = math.random(1, 100); local statCount = 1
	if numStats > 90 then statCount = 3 elseif numStats > 50 then statCount = 2 end

	local rolled = {}
	for i = 1, statCount do table.insert(rolled, PossibleSubstats[math.random(#PossibleSubstats)]) end
	local statString = table.concat(rolled, " | ")

	player:SetAttribute(safeNameBase .. "_Awakened", statString)
	RemotesFolder.NotificationEvent:FireClient(player, "Awakened " .. itemName .. ": " .. statString, "Success")
end)

RemotesFolder:WaitForChild("ForgeItem").OnServerEvent:Connect(function(player, baseItemName)
	local recipe = ItemData.ForgeRecipes[baseItemName]
	if not recipe then return end
	local safeBaseName = baseItemName:gsub("[^%w]", "") .. "Count"; local safeResultName = recipe.Result:gsub("[^%w]", "") .. "Count"
	local currentAmt = player:GetAttribute(safeBaseName) or 0
	if currentAmt >= recipe.ReqAmt and player.leaderstats.Dews.Value >= recipe.DewCost then
		player.leaderstats.Dews.Value -= recipe.DewCost; player:SetAttribute(safeBaseName, currentAmt - recipe.ReqAmt); player:SetAttribute(safeResultName, (player:GetAttribute(safeResultName) or 0) + 1)
		if (currentAmt - recipe.ReqAmt) == 0 then
			if player:GetAttribute("EquippedWeapon") == baseItemName then player:SetAttribute("EquippedWeapon", "None"); player:SetAttribute("FightingStyle", "None") end
			if player:GetAttribute("EquippedAccessory") == baseItemName then player:SetAttribute("EquippedAccessory", "None") end
		end
	end
end)

local FusionRecipes = { ["Female Titan"] = { ["Founding Titan"] = "Founding Female Titan" }, ["Founding Titan"] = { ["Female Titan"] = "Founding Female Titan" }, ["Attack Titan"] = { ["Armored Titan"] = "Armored Attack Titan", ["War Hammer Titan"] = "War Hammer Attack Titan" }, ["Armored Titan"] = { ["Attack Titan"] = "Armored Attack Titan" }, ["War Hammer Titan"] = { ["Attack Titan"] = "War Hammer Attack Titan" }, ["Colossal Titan"] = { ["Jaw Titan"] = "Colossal Jaw Titan" }, ["Jaw Titan"] = { ["Colossal Titan"] = "Colossal Jaw Titan" } }
RemotesFolder:WaitForChild("FuseTitan").OnServerEvent:Connect(function(player, slotNum)
	if type(slotNum) ~= "number" or slotNum < 1 or slotNum > 6 then return end
	local activeTitan = player:GetAttribute("Titan") or "None"; if activeTitan == "None" then return end
	local slotKey = "Titan_Slot" .. tostring(slotNum); local sacrificeTitan = player:GetAttribute(slotKey) or "None"; if sacrificeTitan == "None" then return end
	local resultTitan = FusionRecipes[activeTitan] and FusionRecipes[activeTitan][sacrificeTitan]
	if not resultTitan then RemotesFolder.NotificationEvent:FireClient(player, "These Titans are incompatible for fusion!", "Error"); return end

	local fusionCost = 50000
	if player.leaderstats.Dews.Value >= fusionCost then
		player.leaderstats.Dews.Value -= fusionCost; player:SetAttribute(slotKey, "None"); player:SetAttribute("Titan", resultTitan) 
		RemotesFolder.NotificationEvent:FireClient(player, "FUSION SUCCESS! You are now the " .. resultTitan .. "!", "Success")
	else RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews to fuse! Need " .. fusionCost .. ".", "Error") end
end)

RemotesFolder:WaitForChild("ManageStorage").OnServerEvent:Connect(function(player, gType, slotNum)
	if type(slotNum) ~= "number" or slotNum < 1 or slotNum > 6 then return end
	if slotNum > 3 then
		if gType == "Titan" and not player:GetAttribute("HasTitanVault") then return end
		if gType == "Clan" and not player:GetAttribute("HasClanVault") then return end
	end
	local current = player:GetAttribute(gType) or "None"; local slotKey = gType .. "_Slot" .. slotNum; local stored = player:GetAttribute(slotKey) or "None"
	player:SetAttribute(gType, stored); player:SetAttribute(slotKey, current)
end)

local function PerformRoll(gType, isPremium, pObj)
	local legPityKey = gType .. "Pity"
	local mythPityKey = gType .. "MythicalPity"
	local legPityVal = pObj:GetAttribute(legPityKey) or 0
	local mythPityVal = pObj:GetAttribute(mythPityKey) or 0

	local resultName, resultRarity = "", "Common"

	if gType == "Titan" then
		if isPremium then
			if math.random(1, 100) <= 15 then resultRarity = "Mythical" else resultRarity = "Legendary" end
			local possibleTitans = {}; for tName, data in pairs(TitanData.Titans) do if data.Rarity == resultRarity then table.insert(possibleTitans, tName) end end
			resultName = possibleTitans[math.random(1, #possibleTitans)]
			pObj:SetAttribute(legPityKey, 0); pObj:SetAttribute(mythPityKey, 0)
		else
			resultName, resultRarity = TitanData.RollTitan(legPityVal, mythPityVal)
			if resultRarity == "Mythical" or resultRarity == "Transcendent" then
				pObj:SetAttribute(legPityKey, 0); pObj:SetAttribute(mythPityKey, 0)
			elseif resultRarity == "Legendary" then
				pObj:SetAttribute(legPityKey, 0); pObj:SetAttribute(mythPityKey, mythPityVal + 1)
			else
				pObj:SetAttribute(legPityKey, legPityVal + 1); pObj:SetAttribute(mythPityKey, mythPityVal + 1)
			end
		end
	elseif gType == "Clan" then
		if mythPityVal >= 250 then
			resultName = "Ackerman"; resultRarity = "Mythical"
		else
			resultName = TitanData.RollClan(); local weight = TitanData.ClanWeights[resultName] or 40.0
			if weight <= 1.5 then resultRarity = "Mythical" elseif weight <= 4.0 then resultRarity = "Legendary" elseif weight <= 8.0 then resultRarity = "Epic" elseif weight <= 15.0 then resultRarity = "Rare" else resultRarity = "Common" end
		end

		if resultRarity == "Mythical" or resultRarity == "Transcendent" then
			pObj:SetAttribute(legPityKey, 0); pObj:SetAttribute(mythPityKey, 0)
		elseif resultRarity == "Legendary" then
			pObj:SetAttribute(legPityKey, 0); pObj:SetAttribute(mythPityKey, mythPityVal + 1)
		else
			pObj:SetAttribute(legPityKey, legPityVal + 1); pObj:SetAttribute(mythPityKey, mythPityVal + 1)
		end
	end
	return resultName, resultRarity
end

RemotesFolder:WaitForChild("GachaRoll").OnServerEvent:Connect(function(player, gType, isPremium)
	local reqAttr = isPremium and "SpinalFluidSyringeCount" or (gType == "Titan" and "StandardTitanSerumCount" or "ClanBloodVialCount")
	local amt = player:GetAttribute(reqAttr) or 0
	if amt >= 1 then
		player:SetAttribute(reqAttr, amt - 1); local result, rType = PerformRoll(gType, isPremium, player); player:SetAttribute(gType, result)
		UpdateBountyProgress(player, "Roll", 1)
		if gType == "Titan" then for _, s in ipairs({"Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val"}) do player:SetAttribute(s, 10) end end
		RemotesFolder.GachaResult:FireClient(player, gType, result, rType)
	end
end)

RemotesFolder:WaitForChild("GachaRollAuto").OnServerEvent:Connect(function(player, gType)
	local reqAttr = gType == "Titan" and "StandardTitanSerumCount" or "ClanBloodVialCount"; local result, rType
	while (player:GetAttribute(reqAttr) or 0) > 0 do
		player:SetAttribute(reqAttr, player:GetAttribute(reqAttr) - 1)
		UpdateBountyProgress(player, "Roll", 1)
		result, rType = PerformRoll(gType, false, player)
		if rType == "Legendary" or rType == "Mythical" then break end
	end
	if result then
		player:SetAttribute(gType, result)
		if gType == "Titan" then for _, s in ipairs({"Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val"}) do player:SetAttribute(s, 10) end end
		RemotesFolder.GachaResult:FireClient(player, gType, result, rType)
	end
end)