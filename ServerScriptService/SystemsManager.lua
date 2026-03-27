-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local CombatCore = require(script.Parent:WaitForChild("CombatCore"))

local Network = ReplicatedStorage:FindFirstChild("Network") or Instance.new("Folder", ReplicatedStorage)
Network.Name = "Network"

local function GetRemote(name)
	local r = Network:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Network end
	return r
end

local CombatAction = GetRemote("CombatAction")
local CombatUpdate = GetRemote("CombatUpdate")

local ActiveBattles = {}

-- [[ INVENTORY CAP & AUTO-SELL CONFIG ]]
local MAX_INVENTORY_CAPACITY = 25
local SellValues = { Common = 10, Uncommon = 25, Rare = 75, Epic = 200, Legendary = 500, Mythical = 1500, Transcendent = 0 }

local function GetUniqueSlotCount(plr)
	local count = 0
	for iName, _ in pairs(ItemData.Equipment) do
		if (plr:GetAttribute(iName:gsub("[^%w]", "") .. "Count") or 0) > 0 then count += 1 end
	end
	for iName, _ in pairs(ItemData.Consumables) do
		if (plr:GetAttribute(iName:gsub("[^%w]", "") .. "Count") or 0) > 0 then count += 1 end
	end
	return count
end

local function UpdateBountyProgress(plr, taskType, amt)
	for i = 1, 3 do
		if plr:GetAttribute("D"..i.."_Task") == taskType and not plr:GetAttribute("D"..i.."_Claimed") then
			local p = plr:GetAttribute("D"..i.."_Prog") or 0
			local m = plr:GetAttribute("D"..i.."_Max") or 1
			plr:SetAttribute("D"..i.."_Prog", math.min(p + amt, m))
		end
	end
	if plr:GetAttribute("W1_Task") == taskType and not plr:GetAttribute("W1_Claimed") then
		local p = plr:GetAttribute("W1_Prog") or 0
		local m = plr:GetAttribute("W1_Max") or 1
		plr:SetAttribute("W1_Prog", math.min(p + amt, m))
	end
end

local function GetTemplate(partData, templateName)
	if partData.Templates and partData.Templates[templateName] then return partData.Templates[templateName] end
	for _, mob in ipairs(partData.Mobs) do if mob.Name == templateName then return mob end end
	return partData.Mobs[1] 
end

local function GetHPScale(targetPart, prestige)
	return 1.0 + (targetPart * 0.2) + (prestige * 0.4) 
end
local function GetDmgScale(targetPart, prestige)
	return 1.0 + (targetPart * 0.1) + (prestige * 0.2) 
end

local function GetActualStyle(plr)
	local eqWpn = plr:GetAttribute("EquippedWeapon") or "None"
	if ItemData.Equipment[eqWpn] and ItemData.Equipment[eqWpn].Style then return ItemData.Equipment[eqWpn].Style end
	return "None"
end

local function ParseAwakenedStats(statString)
	local stats = { DmgMult = 1.0, DodgeBonus = 0, CritBonus = 0, HpBonus = 0, SpdBonus = 0, GasBonus = 0, HealOnKill = 0, IgnoreArmor = 0 }
	if not statString then return stats end

	for stat in string.gmatch(statString, "[^|]+") do
		stat = stat:match("^%s*(.-)%s*$")
		if stat:find("DMG") then stats.DmgMult += tonumber(stat:match("%d+")) / 100
		elseif stat:find("DODGE") then stats.DodgeBonus += tonumber(stat:match("%d+"))
		elseif stat:find("CRIT") then stats.CritBonus += tonumber(stat:match("%d+"))
		elseif stat:find("MAX HP") then stats.HpBonus += tonumber(stat:match("%d+"))
		elseif stat:find("SPEED") then stats.SpdBonus += tonumber(stat:match("%d+"))
		elseif stat:find("GAS CAP") then stats.GasBonus += tonumber(stat:match("%d+"))
		elseif stat:find("HEAL") then stats.HealOnKill += tonumber(stat:match("%d+")) / 100
		elseif stat:find("IGNORE") then stats.IgnoreArmor += tonumber(stat:match("%d+")) / 100
		end
	end
	return stats
end

local function StartBattle(player, encounterType, requestedPartId)
	local currentPart = player:GetAttribute("CurrentPart") or 1
	local eTemplate, logFlavor
	local isStory = false
	local isEndless = false
	local isPaths = false
	local isWorldBoss = false
	local activeMissionData = nil
	local totalWaves = 1
	local startingWave = 1
	local targetPart = currentPart

	local prestige = player:FindFirstChild("leaderstats") and player.leaderstats.Prestige.Value or 0

	if encounterType == "EngageStory" then
		isStory = true
		targetPart = requestedPartId or currentPart
		if type(targetPart) == "number" and targetPart > currentPart then targetPart = currentPart end

		local partData = EnemyData.Parts[targetPart]
		if not partData then return end

		if targetPart == currentPart then startingWave = player:GetAttribute("CurrentWave") or 1 else startingWave = 1 end

		local missionTable = (prestige > 0 and partData.PrestigeMissions) and partData.PrestigeMissions or partData.Missions
		activeMissionData = missionTable[1]
		totalWaves = #activeMissionData.Waves

		if startingWave > totalWaves then startingWave = totalWaves end
		local waveData = activeMissionData.Waves[startingWave]
		eTemplate = GetTemplate(partData, waveData.Template)
		logFlavor = "<font color='#FFD700'>[Mission: " .. activeMissionData.Name .. "]</font>\n" .. waveData.Flavor

	elseif encounterType == "EngageEndless" then
		isEndless = true
		local maxPart = math.min(8, currentPart)
		targetPart = math.random(1, maxPart)
		local partData = EnemyData.Parts[targetPart]
		eTemplate = partData.Mobs[math.random(1, #partData.Mobs)]
		logFlavor = "<font color='#AA55FF'>[ENDLESS EXPEDITION]</font>\nYou have encountered a " .. eTemplate.Name .. "!"

	elseif encounterType == "EngagePaths" then
		isPaths = true
		local floor = player:GetAttribute("PathsFloor") or 1
		targetPart = math.random(1, 8) 
		local partData = EnemyData.Parts[targetPart]
		eTemplate = partData.Mobs[math.random(1, #partData.Mobs)]
		logFlavor = "<font color='#55FFFF'>[THE PATHS - MEMORY " .. floor .. "]</font>\nA manifestation of " .. eTemplate.Name .. " emerges from the sand..."

	elseif encounterType == "EngageWorldBoss" then
		isWorldBoss = true
		eTemplate = EnemyData.WorldBosses[requestedPartId]
		if not eTemplate then return end
		logFlavor = "<font color='#FFAA00'>[WORLD EVENT]</font>\n" .. eTemplate.Name .. " has appeared!"
		targetPart = 1 
	else
		targetPart = math.min(8, currentPart)
		local partData = EnemyData.Parts[targetPart]
		eTemplate = partData.Mobs[math.random(1, #partData.Mobs)]
		local flavors = partData.RandomFlavor or {"You encounter a %s!"}
		logFlavor = string.format(flavors[math.random(1, #flavors)], eTemplate.Name)
	end

	local hpMult = GetHPScale(targetPart, prestige)
	local dmgMult = GetDmgScale(targetPart, prestige)
	local dropMult = 1.0 + (targetPart * 1.5) + (prestige * 2.5)

	if isEndless then 
		hpMult *= 1.4; dmgMult *= 1.4; dropMult *= 1.5 
	elseif isPaths then
		local floor = player:GetAttribute("PathsFloor") or 1
		local pathScale = math.pow(1.25, floor - 1) 
		hpMult = hpMult * pathScale
		dmgMult = dmgMult * pathScale
	end

	local baseDropXP = eTemplate.Drops and eTemplate.Drops.XP or 15
	local baseDropDews = eTemplate.Drops and eTemplate.Drops.Dews or 10
	local finalDropXP = math.floor(baseDropXP * dropMult)
	local finalDropDews = math.floor(baseDropDews * dropMult)

	local wpnName = player:GetAttribute("EquippedWeapon") or "None"
	local accName = player:GetAttribute("EquippedAccessory") or "None"

	local wpnBonus = (ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Bonus) or {}
	local accBonus = (ItemData.Equipment[accName] and ItemData.Equipment[accName].Bonus) or {}

	local safeWpnName = wpnName:gsub("[^%w]", "")
	local awakenedString = player:GetAttribute(safeWpnName .. "_Awakened")
	local awakenedStats = ParseAwakenedStats(awakenedString)

	local clanName = player:GetAttribute("Clan") or "None"
	local pMaxHP = ((player:GetAttribute("Health") or 10) + (wpnBonus.Health or 0) + (accBonus.Health or 0)) * 10
	if clanName == "Reiss" then pMaxHP = math.floor(pMaxHP * 1.5) end
	pMaxHP = pMaxHP + awakenedStats.HpBonus

	local pMaxGas = ((player:GetAttribute("Gas") or 10) + (wpnBonus.Gas or 0) + (accBonus.Gas or 0)) * 10
	pMaxGas = pMaxGas + awakenedStats.GasBonus

	local pTotalStr = (player:GetAttribute("Strength") or 10) + (wpnBonus.Strength or 0) + (accBonus.Strength or 0)
	local pTotalDef = (player:GetAttribute("Defense") or 10) + (wpnBonus.Defense or 0) + (accBonus.Defense or 0)

	local pTotalSpd = (player:GetAttribute("Speed") or 10) + (wpnBonus.Speed or 0) + (accBonus.Speed or 0)
	pTotalSpd = pTotalSpd + awakenedStats.SpdBonus

	local pTotalRes = (player:GetAttribute("Resolve") or 10) + (wpnBonus.Resolve or 0) + (accBonus.Resolve or 0)

	local ctxRange = "Close"
	if eTemplate.Name:find("Beast Titan") then
		ctxRange = "Long"
		logFlavor = logFlavor .. "\n<font color='#FF5555'>The Beast Titan is at LONG RANGE. Use Maneuver to close the gap!</font>"
	end

	local isMinigame = eTemplate.IsMinigame

	local eHP = math.floor(eTemplate.Health * hpMult)
	local eGateType = eTemplate.GateType
	local eGateHP = math.floor((eTemplate.GateHP or 0) * (eGateType == "Steam" and 1 or hpMult))
	local eStr = math.floor(eTemplate.Strength * dmgMult)
	local eDef = math.floor(eTemplate.Defense * dmgMult)
	local eSpd = math.floor(eTemplate.Speed * dmgMult)

	local enemyAwakenedStats = nil
	if isPaths then
		local mutators = {"Armored", "Frenzied", "Elusive", "Colossal"}
		local selectedMutator = mutators[math.random(1, #mutators)]

		if selectedMutator == "Armored" then
			eGateType = "Reinforced Skin"
			eGateHP = math.floor(eHP * 0.3)
			logFlavor = logFlavor .. "\n<font color='#AAAAAA'>[MUTATOR: ARMORED] Target has extreme hardening!</font>"
		elseif selectedMutator == "Frenzied" then
			eSpd = eSpd * 2.0
			eStr = eStr * 1.2
			logFlavor = logFlavor .. "\n<font color='#FF5555'>[MUTATOR: FRENZIED] Target is moving at terrifying speeds!</font>"
		elseif selectedMutator == "Elusive" then
			enemyAwakenedStats = { DodgeBonus = 15 }
			logFlavor = logFlavor .. "\n<font color='#55FF55'>[MUTATOR: ELUSIVE] Target is incredibly hard to hit!</font>"
		elseif selectedMutator == "Colossal" then
			eHP = eHP * 2.0
			eStr = eStr * 1.5
			eSpd = math.floor(eSpd * 0.5)
			logFlavor = logFlavor .. "\n<font color='#FFAA00'>[MUTATOR: COLOSSAL] Target is massive and deals lethal damage!</font>"
		end
	end

	ActiveBattles[player.UserId] = {
		IsProcessing = false,
		Context = { IsStoryMission = isStory, IsEndless = isEndless, IsPaths = isPaths, IsWorldBoss = isWorldBoss, TargetPart = targetPart, CurrentWave = startingWave, TotalWaves = totalWaves, MissionData = activeMissionData, TurnCount = 0, Range = ctxRange, GapCloses = 0 },
		Player = {
			IsPlayer = true, Name = player.Name, PlayerObj = player, Titan = player:GetAttribute("Titan") or "None",
			Style = GetActualStyle(player), Clan = clanName,
			HP = pMaxHP, MaxHP = pMaxHP,
			TitanEnergy = 100, MaxTitanEnergy = 100, Gas = pMaxGas, MaxGas = pMaxGas,
			TotalStrength = pTotalStr, TotalDefense = pTotalDef,
			TotalSpeed = pTotalSpd, TotalResolve = pTotalRes,
			Statuses = {}, Cooldowns = {}, LastSkill = "None",
			AwakenedStats = awakenedStats
		},
		Enemy = {
			IsMinigame = isMinigame,
			IsPlayer = false, Name = eTemplate.Name, 
			IsHuman = isPaths and false or (eTemplate.IsHuman or false),
			HP = eHP, MaxHP = eHP,
			GateType = eGateType, GateHP = eGateHP, MaxGateHP = eGateHP,
			TotalStrength = eStr, TotalDefense = eDef, TotalSpeed = eSpd,
			Statuses = {}, Cooldowns = {}, Skills = eTemplate.Skills or {"Brutal Swipe"},
			Drops = { XP = finalDropXP, Dews = finalDropDews, ItemChance = eTemplate.Drops and eTemplate.Drops.ItemChance or {} },
			LastSkill = "None",
			AwakenedStats = enemyAwakenedStats
		}
	}

	if isMinigame then
		CombatUpdate:FireClient(player, "StartMinigame", { Battle = ActiveBattles[player.UserId], LogMsg = logFlavor, MinigameType = isMinigame })
	else
		CombatUpdate:FireClient(player, "Start", { Battle = ActiveBattles[player.UserId], LogMsg = logFlavor })
	end
end

local function ProcessEnemyDeath(player, battle)
	if not player or not player:FindFirstChild("leaderstats") then return end

	local turnDelay = player:GetAttribute("HasDoubleSpeed") and 0.75 or 1.5

	if battle.Context.StoredBoss then
		local b = battle.Context.StoredBoss
		battle.Enemy.Name = b.Name; battle.Enemy.HP = b.HP; battle.Enemy.MaxHP = b.MaxHP
		battle.Enemy.GateType = b.GateType; battle.Enemy.GateHP = b.GateHP; battle.Enemy.MaxGateHP = b.MaxGateHP
		battle.Enemy.TotalStrength = b.TotalStrength; battle.Enemy.TotalDefense = b.TotalDefense; battle.Enemy.TotalSpeed = b.TotalSpeed
		battle.Enemy.Drops = b.Drops; battle.Enemy.Skills = b.Skills; battle.Enemy.Statuses = b.Statuses; battle.Enemy.Cooldowns = b.Cooldowns; battle.Enemy.LastSkill = b.LastSkill

		battle.Context.StoredBoss = nil
		battle.Context.TurnCount = 0 

		CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#55FF55'>The Summoned Titan falls! The Founder is exposed!</font>", DidHit = false, ShakeType = "Heavy"})
		task.wait(turnDelay)
		battle.IsProcessing = false
		CombatUpdate:FireClient(player, "Update", {Battle = battle})
		return
	end

	UpdateBountyProgress(player, "Kill", 1); UpdateBountyProgress(player, "Clear", 1)

	if battle.Context.IsWorldBoss then
		local vpEvent = game:GetService("ServerStorage"):FindFirstChild("AddRegimentVP")
		if vpEvent then vpEvent:Fire(player, 250) end
	end

	local xpGain = battle.Enemy.Drops.XP; local dewsGain = battle.Enemy.Drops.Dews
	if player:GetAttribute("HasDoubleXP") then xpGain *= 2; dewsGain *= 2 end
	if player:GetAttribute("Buff_XP_Expiry") and os.time() < player:GetAttribute("Buff_XP_Expiry") then xpGain *= 2 end

	local winReg = Network:FindFirstChild("WinningRegiment")
	if winReg and winReg.Value ~= "None" and player:GetAttribute("Regiment") == winReg.Value then
		xpGain = math.floor(xpGain * 1.15)
		dewsGain = math.floor(dewsGain * 1.15)
	end

	player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + xpGain)
	player:SetAttribute("TitanXP", (player:GetAttribute("TitanXP") or 0) + xpGain)

	player.leaderstats.Dews.Value += dewsGain

	local killMsg = ""

	local currentSlots = GetUniqueSlotCount(player)
	local droppedItems = {}
	local autoSoldDews = 0

	if battle.Enemy.Drops.ItemChance then
		for itemName, baseChance in pairs(battle.Enemy.Drops.ItemChance) do
			local iData = ItemData.Equipment[itemName] or ItemData.Consumables[itemName]
			local rarity = iData and iData.Rarity or "Common"
			local finalChance = baseChance

			if rarity == "Mythical" then
				finalChance = baseChance * 1.0 
				if battle.Context.IsEndless then finalChance += (battle.Context.CurrentWave * 0.1) end
				finalChance = math.min(finalChance, math.max(5, baseChance))
			elseif rarity == "Legendary" then
				finalChance = baseChance * 1.2
				if battle.Context.IsEndless then finalChance += (battle.Context.CurrentWave * 0.25) end
				finalChance = math.min(finalChance, math.max(12, baseChance))
			elseif rarity == "Epic" then
				finalChance = baseChance * 2.0
				if battle.Context.IsEndless then finalChance += (battle.Context.CurrentWave * 1.0) end
				finalChance = math.min(finalChance, math.max(40, baseChance))
			else
				finalChance = baseChance * 3.0
				if battle.Context.IsEndless then finalChance += (battle.Context.CurrentWave * 2.5) end
				finalChance = math.min(finalChance, 100)
			end

			local roll = math.random() * 100
			if roll <= finalChance then
				local attrName = itemName:gsub("[^%w]", "") .. "Count"
				local currentAmt = player:GetAttribute(attrName) or 0
				local dropMultiplier = player:GetAttribute("HasDoubleDrops") and 2 or 1

				if currentAmt == 0 and currentSlots >= MAX_INVENTORY_CAPACITY then
					autoSoldDews += (SellValues[rarity] or 10) * dropMultiplier
				else
					local nameTag = (dropMultiplier > 1) and (itemName .. " (x" .. dropMultiplier .. ")") or itemName
					table.insert(droppedItems, nameTag)
					player:SetAttribute(attrName, currentAmt + dropMultiplier)
					if currentAmt == 0 then currentSlots += 1 end
				end
			end
		end

		if battle.Context.IsEndless and #droppedItems == 0 and autoSoldDews == 0 and battle.Context.CurrentWave % 3 == 0 then
			local pool = {}
			for iname, _ in pairs(battle.Enemy.Drops.ItemChance) do 
				local iData = ItemData.Equipment[iname] or ItemData.Consumables[iname]
				if iData and iData.Rarity ~= "Mythical" and iData.Rarity ~= "Legendary" then
					table.insert(pool, iname) 
				end
			end
			if #pool > 0 then
				local pItem = pool[math.random(1, #pool)]
				local attrName = pItem:gsub("[^%w]", "") .. "Count"
				local currentAmt = player:GetAttribute(attrName) or 0
				local dropMultiplier = player:GetAttribute("HasDoubleDrops") and 2 or 1

				if currentAmt == 0 and currentSlots >= MAX_INVENTORY_CAPACITY then
					local iData = ItemData.Equipment[pItem] or ItemData.Consumables[pItem]
					autoSoldDews += (SellValues[iData and iData.Rarity or "Common"] or 10) * dropMultiplier
				else
					local nameTag = (dropMultiplier > 1) and (pItem .. " (x" .. dropMultiplier .. ")") or pItem
					table.insert(droppedItems, nameTag)
					player:SetAttribute(attrName, currentAmt + dropMultiplier)
					if currentAmt == 0 then currentSlots += 1 end
				end
			end
		end
	end

	if autoSoldDews > 0 then
		player.leaderstats.Dews.Value += autoSoldDews
		killMsg = killMsg .. "<br/><font color='#FFD700'>[Inventory Full: Auto-sold new drops for " .. autoSoldDews .. " Dews]</font>"
	end

	if battle.Player.AwakenedStats and battle.Player.AwakenedStats.HealOnKill > 0 then
		local pMax = tonumber(battle.Player.MaxHP) or 100
		local pCur = tonumber(battle.Player.HP) or 100
		local healAmt = math.floor(pMax * battle.Player.AwakenedStats.HealOnKill)

		battle.Player.HP = math.min(pMax, pCur + healAmt)
		killMsg = killMsg .. "<br/><font color='#55FF55'>[Awakened: Healed " .. healAmt .. " HP!]</font>"
	end

	if battle.Context.IsPaths then
		local floor = player:GetAttribute("PathsFloor") or 1
		local dustGain = math.floor(1 + (floor * 0.2)) 
		player:SetAttribute("PathDust", (player:GetAttribute("PathDust") or 0) + dustGain)

		local nextFloor = floor + 1
		player:SetAttribute("PathsFloor", nextFloor)

		local rewardStr = "<font color='#55FFFF'>Memory Cleared! +" .. dustGain .. " Path Dust</font>"

		local prestige = player.leaderstats.Prestige.Value
		local targetPart = math.random(1, 8)
		local partData = EnemyData.Parts[targetPart]
		local nextEnemyTemplate = partData.Mobs[math.random(1, #partData.Mobs)]

		local pathScale = math.pow(1.25, nextFloor - 1)
		local hpMult = GetHPScale(targetPart, prestige) * pathScale
		local dmgMult = GetDmgScale(targetPart, prestige) * pathScale
		local dropMult = 1.0 + (targetPart * 1.5) + (prestige * 2.5)

		local eHP = math.floor(nextEnemyTemplate.Health * hpMult)
		local eGateType = nextEnemyTemplate.GateType
		local eGateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (eGateType == "Steam" and 1 or hpMult))
		local eStr = math.floor(nextEnemyTemplate.Strength * dmgMult)
		local eDef = math.floor(nextEnemyTemplate.Defense * dmgMult)
		local eSpd = math.floor(nextEnemyTemplate.Speed * dmgMult)

		local enemyAwakenedStats = nil
		local mutators = {"Armored", "Frenzied", "Elusive", "Colossal"}
		local selectedMutator = mutators[math.random(1, #mutators)]
		local logFlavor = "<font color='#55FFFF'>[THE PATHS - MEMORY " .. nextFloor .. "]</font>\nA manifestation of " .. nextEnemyTemplate.Name .. " emerges from the sand..."

		if selectedMutator == "Armored" then
			eGateType = "Reinforced Skin"
			eGateHP = math.floor(eHP * 0.3)
			logFlavor = logFlavor .. "\n<font color='#AAAAAA'>[MUTATOR: ARMORED] Target has extreme hardening!</font>"
		elseif selectedMutator == "Frenzied" then
			eSpd = eSpd * 2.0
			eStr = eStr * 1.2
			logFlavor = logFlavor .. "\n<font color='#FF5555'>[MUTATOR: FRENZIED] Target is moving at terrifying speeds!</font>"
		elseif selectedMutator == "Elusive" then
			enemyAwakenedStats = { DodgeBonus = 15 }
			logFlavor = logFlavor .. "\n<font color='#55FF55'>[MUTATOR: ELUSIVE] Target is incredibly hard to hit!</font>"
		elseif selectedMutator == "Colossal" then
			eHP = eHP * 2.0
			eStr = eStr * 1.5
			eSpd = math.floor(eSpd * 0.5)
			logFlavor = logFlavor .. "\n<font color='#FFAA00'>[MUTATOR: COLOSSAL] Target is massive and deals lethal damage!</font>"
		end

		battle.Enemy = {
			IsMinigame = nextEnemyTemplate.IsMinigame,
			IsPlayer = false, Name = nextEnemyTemplate.Name, 
			IsHuman = false, 
			HP = eHP, MaxHP = eHP,
			GateType = eGateType, GateHP = eGateHP, MaxGateHP = eGateHP,
			TotalStrength = eStr, TotalDefense = eDef, TotalSpeed = eSpd,
			Statuses = {}, Cooldowns = {}, Skills = nextEnemyTemplate.Skills or {"Brutal Swipe"},
			Drops = { XP = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.XP or 15) * dropMult), Dews = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.Dews or 10) * dropMult), ItemChance = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.ItemChance or {} },
			LastSkill = "None",
			AwakenedStats = enemyAwakenedStats
		}

		battle.Player.Cooldowns = {} 
		battle.Player.Statuses = {} 
		battle.Player.HP = battle.Player.MaxHP; battle.Player.Gas = battle.Player.MaxGas; battle.Player.TitanEnergy = math.min(100, (battle.Player.TitanEnergy or 0) + 30); battle.Player.LastSkill = "None"

		if nextEnemyTemplate.IsMinigame then
			CombatUpdate:FireClient(player, "StartMinigame", {Battle = battle, LogMsg = logFlavor .. "\n" .. rewardStr .. killMsg, MinigameType = nextEnemyTemplate.IsMinigame})
		else
			CombatUpdate:FireClient(player, "WaveComplete", {Battle = battle, LogMsg = logFlavor .. "\n" .. rewardStr .. killMsg, XP = xpGain, Dews = dewsGain, Items = droppedItems})
		end
		battle.IsProcessing = false
		return
	end

	if battle.Context.IsStoryMission and battle.Context.CurrentWave < battle.Context.TotalWaves then
		battle.Context.CurrentWave += 1

		if battle.Context.TargetPart == 2 and battle.Context.CurrentWave == battle.Context.TotalWaves then
			local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
			if currentReg ~= "Cadet Corps" then
				CombatUpdate:FireClient(player, "Victory", {Battle = battle, XP = xpGain, Dews = dewsGain, Items = droppedItems, ExtraLog = killMsg})
				ActiveBattles[player.UserId] = nil
				return
			end
		end

		if battle.Context.TargetPart == (player:GetAttribute("CurrentPart") or 1) then player:SetAttribute("CurrentWave", battle.Context.CurrentWave) end

		local prestige = player.leaderstats.Prestige.Value
		local hpMult = GetHPScale(battle.Context.TargetPart, prestige)
		local dmgMult = GetDmgScale(battle.Context.TargetPart, prestige)

		local currentPart = battle.Context.TargetPart
		local partData = EnemyData.Parts[currentPart]
		local waveData = battle.Context.MissionData.Waves[battle.Context.CurrentWave]
		local nextEnemyTemplate = GetTemplate(partData, waveData.Template)

		local dropMult = 1.0 + (battle.Context.TargetPart * 1.5) + (prestige * 2.5)
		local nextBaseDropXP = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.XP or 15
		local nextBaseDropDews = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.Dews or 10
		local nextFinalDropXP = math.floor(nextBaseDropXP * dropMult)
		local nextFinalDropDews = math.floor(nextBaseDropDews * dropMult)

		local flavorText = waveData.Flavor

		if nextEnemyTemplate.Name:find("Beast Titan") then
			battle.Context.Range = "Long"
			battle.Context.GapCloses = 0
			flavorText = flavorText .. "\n<font color='#FF5555'>The Beast Titan is at LONG RANGE. Use Maneuver to close the gap!</font>"
		else
			battle.Context.Range = "Close"
			battle.Context.GapCloses = 0
		end
		battle.Context.TurnCount = 0
		battle.Context.StoredBoss = nil

		local isMinigame = nextEnemyTemplate.IsMinigame

		battle.Enemy = {
			IsMinigame = isMinigame,
			IsPlayer = false, Name = nextEnemyTemplate.Name, IsHuman = nextEnemyTemplate.IsHuman or false,
			HP = math.floor(nextEnemyTemplate.Health * hpMult), MaxHP = math.floor(nextEnemyTemplate.Health * hpMult),
			GateType = nextEnemyTemplate.GateType, GateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (nextEnemyTemplate.GateType == "Steam" and 1 or hpMult)), MaxGateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (nextEnemyTemplate.GateType == "Steam" and 1 or hpMult)),
			TotalStrength = math.floor(nextEnemyTemplate.Strength * dmgMult), TotalDefense = math.floor(nextEnemyTemplate.Defense * dmgMult), TotalSpeed = math.floor(nextEnemyTemplate.Speed * dmgMult),
			Statuses = {}, Cooldowns = {}, Skills = nextEnemyTemplate.Skills or {"Brutal Swipe"},
			Drops = { XP = nextFinalDropXP, Dews = nextFinalDropDews, ItemChance = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.ItemChance or {} },
			LastSkill = "None"
		}

		battle.Player.Cooldowns = {} 
		battle.Player.Statuses = {} 
		battle.Player.HP = battle.Player.MaxHP; battle.Player.Gas = battle.Player.MaxGas; battle.Player.TitanEnergy = math.min(100, (battle.Player.TitanEnergy or 0) + 30); battle.Player.LastSkill = "None"

		if isMinigame then
			CombatUpdate:FireClient(player, "StartMinigame", {Battle = battle, LogMsg = "<font color='#FFD700'>[WAVE " .. battle.Context.CurrentWave .. "]</font>\n" .. flavorText, MinigameType = isMinigame})
		else
			CombatUpdate:FireClient(player, "WaveComplete", {Battle = battle, LogMsg = "<font color='#FFD700'>[WAVE " .. battle.Context.CurrentWave .. "]</font>\n" .. flavorText .. killMsg, XP = xpGain, Dews = dewsGain, Items = droppedItems})
		end
		battle.IsProcessing = false
	else
		if battle.Context.IsStoryMission then
			player:SetAttribute("CampaignClear_Part" .. battle.Context.TargetPart, true)

			local playerCurrentPart = player:GetAttribute("CurrentPart") or 1
			if battle.Context.TargetPart == playerCurrentPart then
				local nextPart = playerCurrentPart + 1

				if EnemyData.Parts[nextPart] or nextPart == 9 then
					player:SetAttribute("CurrentPart", nextPart)
					player:SetAttribute("CurrentWave", 1) 
				end
			end
		end
		CombatUpdate:FireClient(player, "Victory", {Battle = battle, XP = xpGain, Dews = dewsGain, Items = droppedItems, ExtraLog = killMsg})
		ActiveBattles[player.UserId] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	ActiveBattles[player.UserId] = nil
end)