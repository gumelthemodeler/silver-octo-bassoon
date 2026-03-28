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
local MAX_INVENTORY_CAPACITY = 50
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
	return 1.0 + (targetPart * 0.5) + (prestige * 1.5) 
end
local function GetDmgScale(targetPart, prestige)
	return 1.0 + (targetPart * 0.3) + (prestige * 1.0) 
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
		targetPart = 1 

		-- [[ THE FIX: Progressively scales the pool of available memories based on the floor ]]
		local maxMemoryIndex = math.min(#EnemyData.PathsMemories, math.max(1, math.ceil(floor / 3)))
		eTemplate = EnemyData.PathsMemories[math.random(1, maxMemoryIndex)]
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
	local dropMult = 1.0 + (targetPart * 0.3) + (prestige * 0.5)

	if isEndless then 
		hpMult *= 1.4; dmgMult *= 1.4; dropMult *= 1.5 
	elseif isPaths then
		local floor = player:GetAttribute("PathsFloor") or 1
		-- [[ THE FIX: Weak early scaling (35% base) that multiplies exponentially per floor ]]
		local pathScale = 0.35 * math.pow(1.20, floor - 1) 
		hpMult = hpMult * pathScale
		dmgMult = dmgMult * pathScale
		dropMult = 1.0 + (prestige * 0.5) + (floor * 0.15)
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
	local baseClan = string.gsub(clanName, "Awakened ", "")
	local isAwakened = string.find(clanName, "Awakened") ~= nil
	local tName = player:GetAttribute("Titan") or "None"

	local pMaxHP = ((player:GetAttribute("Health") or 10) + (wpnBonus.Health or 0) + (accBonus.Health or 0)) * 10
	if baseClan == "Reiss" then pMaxHP = math.floor(pMaxHP * (isAwakened and 2.0 or 1.5)) end
	if baseClan == "Arlert" and string.find(tName, "Colossal Titan") then pMaxHP = math.floor(pMaxHP * 1.5) end 
	pMaxHP = pMaxHP + awakenedStats.HpBonus

	local pMaxGas = ((player:GetAttribute("Gas") or 10) + (wpnBonus.Gas or 0) + (accBonus.Gas or 0)) * 10
	pMaxGas = pMaxGas + awakenedStats.GasBonus

	local pTotalStr = (player:GetAttribute("Strength") or 10) + (wpnBonus.Strength or 0) + (accBonus.Strength or 0)
	local pTotalDef = (player:GetAttribute("Defense") or 10) + (wpnBonus.Defense or 0) + (accBonus.Defense or 0)

	local pTotalSpd = (player:GetAttribute("Speed") or 10) + (wpnBonus.Speed or 0) + (accBonus.Speed or 0)
	pTotalSpd = pTotalSpd + awakenedStats.SpdBonus

	local pTotalRes = (player:GetAttribute("Resolve") or 10) + (wpnBonus.Resolve or 0) + (accBonus.Resolve or 0)

	local ctxRange = "Close"
	if eTemplate.Name:find("Beast Titan") or eTemplate.IsLongRange then
		ctxRange = "Long"
		logFlavor = logFlavor .. "\n<font color='#FF5555'>" .. eTemplate.Name .. " is at LONG RANGE.</font>"
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
			eGateType = "Reinforced Skin"; eGateHP = math.floor(eHP * 0.3)
			logFlavor = logFlavor .. "\n<font color='#AAAAAA'>[MUTATOR: ARMORED] Target has extreme hardening!</font>"
		elseif selectedMutator == "Frenzied" then
			eSpd = eSpd * 2.0; eStr = eStr * 1.2
			logFlavor = logFlavor .. "\n<font color='#FF5555'>[MUTATOR: FRENZIED] Target is moving at terrifying speeds!</font>"
		elseif selectedMutator == "Elusive" then
			enemyAwakenedStats = { DodgeBonus = 15 }
			logFlavor = logFlavor .. "\n<font color='#55FF55'>[MUTATOR: ELUSIVE] Target is incredibly hard to hit!</font>"
		elseif selectedMutator == "Colossal" then
			eHP = eHP * 2.0; eStr = eStr * 1.5; eSpd = math.floor(eSpd * 0.5)
			logFlavor = logFlavor .. "\n<font color='#FFAA00'>[MUTATOR: COLOSSAL] Target is massive and deals lethal damage!</font>"
		end
	end

	ActiveBattles[player.UserId] = {
		IsProcessing = false,
		Context = { IsStoryMission = isStory, IsEndless = isEndless, IsPaths = isPaths, IsWorldBoss = isWorldBoss, TargetPart = targetPart, CurrentWave = startingWave, TotalWaves = totalWaves, MissionData = activeMissionData, TurnCount = 0, Range = ctxRange, GapCloses = 0 },
		Player = {
			IsPlayer = true, Name = player.Name, PlayerObj = player, Titan = player:GetAttribute("Titan") or "None",
			Style = GetActualStyle(player), Clan = clanName,
			HP = pMaxHP, MaxHP = pMaxHP, TitanEnergy = 100, MaxTitanEnergy = 100, Gas = pMaxGas, MaxGas = pMaxGas,
			TotalStrength = pTotalStr, TotalDefense = pTotalDef, TotalSpeed = pTotalSpd, TotalResolve = pTotalRes,
			Statuses = {}, Cooldowns = {}, LastSkill = "None", AwakenedStats = awakenedStats
		},
		Enemy = {
			IsMinigame = isMinigame,
			IsPlayer = false, Name = eTemplate.Name, IsHuman = isPaths and false or (eTemplate.IsHuman or false),
			HP = eHP, MaxHP = eHP, GateType = eGateType, GateHP = eGateHP, MaxGateHP = eGateHP,
			TotalStrength = eStr, TotalDefense = eDef, TotalSpeed = eSpd,
			Statuses = {}, Cooldowns = {}, Skills = eTemplate.Skills or {"Brutal Swipe"},
			Drops = { XP = finalDropXP, Dews = finalDropDews, ItemChance = eTemplate.Drops and eTemplate.Drops.ItemChance or {} },
			LastSkill = "None", AwakenedStats = enemyAwakenedStats
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

		battle.Context.StoredBoss = nil; battle.Context.TurnCount = 0 
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
		player:SetAttribute("PathsFloor", floor + 1)

		local rewardStr = "<font color='#55FFFF'>Memory Cleared! +" .. dustGain .. " Path Dust</font>"
		local prestige = player.leaderstats.Prestige.Value

		-- [[ THE FIX: Progressively scaled pool based on next floor ]]
		local maxMemoryIndex = math.min(#EnemyData.PathsMemories, math.max(1, math.ceil((floor + 1) / 3)))
		local nextEnemyTemplate = EnemyData.PathsMemories[math.random(1, maxMemoryIndex)]

		local pathScale = 0.35 * math.pow(1.20, floor)
		local hpMult = GetHPScale(1, prestige) * pathScale
		local dmgMult = GetDmgScale(1, prestige) * pathScale
		local dropMult = 1.0 + (prestige * 0.5) + ((floor + 1) * 0.15)

		local eHP = math.floor(nextEnemyTemplate.Health * hpMult)
		local eGateType = nextEnemyTemplate.GateType
		local eGateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (eGateType == "Steam" and 1 or hpMult))
		local eStr = math.floor(nextEnemyTemplate.Strength * dmgMult)
		local eDef = math.floor(nextEnemyTemplate.Defense * dmgMult)
		local eSpd = math.floor(nextEnemyTemplate.Speed * dmgMult)

		local enemyAwakenedStats = nil
		local mutators = {"Armored", "Frenzied", "Elusive", "Colossal"}
		local selectedMutator = mutators[math.random(1, #mutators)]
		local logFlavor = "<font color='#55FFFF'>[THE PATHS - MEMORY " .. (floor + 1) .. "]</font>\nA manifestation of " .. nextEnemyTemplate.Name .. " emerges from the sand..."

		if selectedMutator == "Armored" then
			eGateType = "Reinforced Skin"; eGateHP = math.floor(eHP * 0.3)
			logFlavor = logFlavor .. "\n<font color='#AAAAAA'>[MUTATOR: ARMORED] Target has extreme hardening!</font>"
		elseif selectedMutator == "Frenzied" then
			eSpd = eSpd * 2.0; eStr = eStr * 1.2
			logFlavor = logFlavor .. "\n<font color='#FF5555'>[MUTATOR: FRENZIED] Target is moving at terrifying speeds!</font>"
		elseif selectedMutator == "Elusive" then
			enemyAwakenedStats = { DodgeBonus = 15 }
			logFlavor = logFlavor .. "\n<font color='#55FF55'>[MUTATOR: ELUSIVE] Target is incredibly hard to hit!</font>"
		elseif selectedMutator == "Colossal" then
			eHP = eHP * 2.0; eStr = eStr * 1.5; eSpd = math.floor(eSpd * 0.5)
			logFlavor = logFlavor .. "\n<font color='#FFAA00'>[MUTATOR: COLOSSAL] Target is massive and deals lethal damage!</font>"
		end

		if nextEnemyTemplate.Name:find("Beast Titan") or nextEnemyTemplate.IsLongRange then
			battle.Context.Range = "Long"
			logFlavor = logFlavor .. "\n<font color='#FF5555'>" .. nextEnemyTemplate.Name .. " is at LONG RANGE.</font>"
		else
			battle.Context.Range = "Close"
		end

		battle.Enemy = {
			IsMinigame = nextEnemyTemplate.IsMinigame, IsPlayer = false, Name = nextEnemyTemplate.Name, IsHuman = false, 
			HP = eHP, MaxHP = eHP, GateType = eGateType, GateHP = eGateHP, MaxGateHP = eGateHP, TotalStrength = eStr, TotalDefense = eDef, TotalSpeed = eSpd,
			Statuses = {}, Cooldowns = {}, Skills = nextEnemyTemplate.Skills or {"Brutal Swipe"},
			Drops = { XP = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.XP or 15) * dropMult), Dews = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.Dews or 10) * dropMult), ItemChance = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.ItemChance or {} },
			LastSkill = "None", AwakenedStats = enemyAwakenedStats
		}
		battle.Player.Cooldowns = {}; battle.Player.Statuses = {} 
		battle.Player.HP = battle.Player.MaxHP; battle.Player.Gas = battle.Player.MaxGas; battle.Player.TitanEnergy = math.min(100, (battle.Player.TitanEnergy or 0) + 30); battle.Player.LastSkill = "None"

		if nextEnemyTemplate.IsMinigame then CombatUpdate:FireClient(player, "StartMinigame", {Battle = battle, LogMsg = logFlavor .. "\n" .. rewardStr .. killMsg, MinigameType = nextEnemyTemplate.IsMinigame})
		else CombatUpdate:FireClient(player, "WaveComplete", {Battle = battle, LogMsg = logFlavor .. "\n" .. rewardStr .. killMsg, XP = xpGain, Dews = dewsGain, Items = droppedItems}) end
		battle.IsProcessing = false
		return
	end

	if battle.Context.IsEndless then
		battle.Context.CurrentWave += 1
		local nextWave = battle.Context.CurrentWave
		local prestige = player.leaderstats.Prestige.Value
		local maxPart = math.min(8, player:GetAttribute("CurrentPart") or 1)
		local targetPart = math.random(1, maxPart)
		local partData = EnemyData.Parts[targetPart]
		local nextEnemyTemplate = partData.Mobs[math.random(1, #partData.Mobs)]

		local hpMult = GetHPScale(targetPart, prestige) * 1.4
		local dmgMult = GetDmgScale(targetPart, prestige) * 1.4
		local dropMult = (1.0 + (targetPart * 0.3) + (prestige * 0.5)) * 1.5

		local eHP = math.floor(nextEnemyTemplate.Health * hpMult)
		local eGateType = nextEnemyTemplate.GateType
		local eGateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (eGateType == "Steam" and 1 or hpMult))
		local eStr = math.floor(nextEnemyTemplate.Strength * dmgMult)
		local eDef = math.floor(nextEnemyTemplate.Defense * dmgMult)
		local eSpd = math.floor(nextEnemyTemplate.Speed * dmgMult)

		local logFlavor = "<font color='#AA55FF'>[ENDLESS EXPEDITION - WAVE " .. nextWave .. "]</font>\nYou encounter a " .. nextEnemyTemplate.Name .. "!"

		battle.Context.Range = "Close"
		if nextEnemyTemplate.Name:find("Beast Titan") or nextEnemyTemplate.IsLongRange then
			battle.Context.Range = "Long"
			logFlavor = logFlavor .. "\n<font color='#FF5555'>" .. nextEnemyTemplate.Name .. " is at LONG RANGE.</font>"
		end

		battle.Context.TurnCount = 0; battle.Context.StoredBoss = nil
		battle.Enemy = {
			IsMinigame = nextEnemyTemplate.IsMinigame, IsPlayer = false, Name = nextEnemyTemplate.Name, IsHuman = nextEnemyTemplate.IsHuman or false,
			HP = eHP, MaxHP = eHP, GateType = eGateType, GateHP = eGateHP, MaxGateHP = eGateHP, TotalStrength = eStr, TotalDefense = eDef, TotalSpeed = eSpd,
			Statuses = {}, Cooldowns = {}, Skills = nextEnemyTemplate.Skills or {"Brutal Swipe"},
			Drops = { XP = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.XP or 15) * dropMult), Dews = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.Dews or 10) * dropMult), ItemChance = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.ItemChance or {} },
			LastSkill = "None"
		}
		battle.Player.Cooldowns = {}; battle.Player.Statuses = {} 
		battle.Player.HP = battle.Player.MaxHP; battle.Player.Gas = battle.Player.MaxGas; battle.Player.TitanEnergy = math.min(100, (battle.Player.TitanEnergy or 0) + 30); battle.Player.LastSkill = "None"

		if isMinigame then CombatUpdate:FireClient(player, "StartMinigame", {Battle = battle, LogMsg = logFlavor .. "\n" .. killMsg, MinigameType = nextEnemyTemplate.IsMinigame})
		else CombatUpdate:FireClient(player, "WaveComplete", {Battle = battle, LogMsg = logFlavor .. "\n" .. killMsg, XP = xpGain, Dews = dewsGain, Items = droppedItems}) end
		battle.IsProcessing = false
		return
	end

	if battle.Context.IsStoryMission and battle.Context.CurrentWave < battle.Context.TotalWaves then
		battle.Context.CurrentWave += 1
		if battle.Context.TargetPart == 2 and battle.Context.CurrentWave == battle.Context.TotalWaves then
			local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
			if currentReg ~= "Cadet Corps" then
				player:SetAttribute("CampaignClear_Part2", true)
				if (player:GetAttribute("CurrentPart") or 1) == 2 then
					player:SetAttribute("CurrentPart", 3); player:SetAttribute("CurrentWave", 1) 
				end
				CombatUpdate:FireClient(player, "Victory", {Battle = battle, XP = xpGain, Dews = dewsGain, Items = droppedItems, ExtraLog = killMsg .. "<br/><font color='#55FFFF'>Skipped Regiment Selection (Already enlisted).</font>"})
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

		local dropMult = 1.0 + (battle.Context.TargetPart * 0.3) + (prestige * 0.5)
		local nextBaseDropXP = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.XP or 15
		local nextBaseDropDews = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.Dews or 10
		local nextFinalDropXP = math.floor(nextBaseDropXP * dropMult)
		local nextFinalDropDews = math.floor(nextBaseDropDews * dropMult)

		local flavorText = waveData.Flavor
		if nextEnemyTemplate.Name:find("Beast Titan") or nextEnemyTemplate.IsLongRange then
			battle.Context.Range = "Long"
			flavorText = flavorText .. "\n<font color='#FF5555'>" .. nextEnemyTemplate.Name .. " is at LONG RANGE.</font>"
		else
			battle.Context.Range = "Close"
		end
		battle.Context.TurnCount = 0; battle.Context.StoredBoss = nil

		battle.Enemy = {
			IsMinigame = nextEnemyTemplate.IsMinigame, IsPlayer = false, Name = nextEnemyTemplate.Name, IsHuman = nextEnemyTemplate.IsHuman or false,
			HP = math.floor(nextEnemyTemplate.Health * hpMult), MaxHP = math.floor(nextEnemyTemplate.Health * hpMult),
			GateType = nextEnemyTemplate.GateType, GateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (nextEnemyTemplate.GateType == "Steam" and 1 or hpMult)), MaxGateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (nextEnemyTemplate.GateType == "Steam" and 1 or hpMult)),
			TotalStrength = math.floor(nextEnemyTemplate.Strength * dmgMult), TotalDefense = math.floor(nextEnemyTemplate.Defense * dmgMult), TotalSpeed = math.floor(nextEnemyTemplate.Speed * dmgMult),
			Statuses = {}, Cooldowns = {}, Skills = nextEnemyTemplate.Skills or {"Brutal Swipe"},
			Drops = { XP = nextFinalDropXP, Dews = nextFinalDropDews, ItemChance = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.ItemChance or {} },
			LastSkill = "None"
		}
		battle.Player.Cooldowns = {}; battle.Player.Statuses = {} 
		battle.Player.HP = battle.Player.MaxHP; battle.Player.Gas = battle.Player.MaxGas; battle.Player.TitanEnergy = math.min(100, (battle.Player.TitanEnergy or 0) + 30); battle.Player.LastSkill = "None"

		if isMinigame then CombatUpdate:FireClient(player, "StartMinigame", {Battle = battle, LogMsg = "<font color='#FFD700'>[WAVE " .. battle.Context.CurrentWave .. "]</font>\n" .. flavorText, MinigameType = nextEnemyTemplate.IsMinigame})
		else CombatUpdate:FireClient(player, "WaveComplete", {Battle = battle, LogMsg = "<font color='#FFD700'>[WAVE " .. battle.Context.CurrentWave .. "]</font>\n" .. flavorText .. killMsg, XP = xpGain, Dews = dewsGain, Items = droppedItems}) end
		battle.IsProcessing = false
	else
		if battle.Context.IsStoryMission then
			player:SetAttribute("CampaignClear_Part" .. battle.Context.TargetPart, true)
			local playerCurrentPart = player:GetAttribute("CurrentPart") or 1
			if battle.Context.TargetPart == playerCurrentPart then
				local nextPart = playerCurrentPart + 1
				if EnemyData.Parts[nextPart] or nextPart == 9 then
					player:SetAttribute("CurrentPart", nextPart); player:SetAttribute("CurrentWave", 1) 
				end
			end
		end
		CombatUpdate:FireClient(player, "Victory", {Battle = battle, XP = xpGain, Dews = dewsGain, Items = droppedItems, ExtraLog = killMsg})
		ActiveBattles[player.UserId] = nil
	end
end

CombatAction.OnServerEvent:Connect(function(player, actionType, actionData)
	if actionType == "EngageRandom" or actionType == "EngageStory" or actionType == "EngageEndless" or actionType == "EngagePaths" or actionType == "EngageWorldBoss" then 
		local pId = actionData and (actionData.PartId or actionData.BossId) or nil; StartBattle(player, actionType, pId); return 
	end

	if actionType == "MinigameResult" then
		return
	end

	local battle = ActiveBattles[player.UserId]
	if not battle or actionType ~= "Attack" then return end
	if battle.IsProcessing then return end

	local skillName = actionData.SkillName
	local targetLimb = actionData.TargetLimb or "Body" 
	local skill = SkillData.Skills[skillName]

	if not skill or (battle.Player.Cooldowns[skillName] and battle.Player.Cooldowns[skillName] > 0) or ((battle.Player.Gas or 0) < (skill.GasCost or 0)) then 
		CombatUpdate:FireClient(player, "Update", {Battle = battle}); return 
	end

	if (battle.Player.TitanEnergy or 0) < (skill.EnergyCost or 0) then
		if battle.Player.Statuses and battle.Player.Statuses["Transformed"] then
			skillName = "Eject"; skill = SkillData.Skills["Eject"]; targetLimb = "Body"
		else
			CombatUpdate:FireClient(player, "Update", {Battle = battle}); return 
		end
	end

	local sRange = skill.Range or "Close"
	if sRange ~= "Any" and sRange ~= battle.Context.Range then
		CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#FF5555'>You cannot use " .. skillName .. " at this range!</font>", DidHit = false, ShakeType = "None"})
		return
	end

	battle.IsProcessing = true
	local turnDelay = player:GetAttribute("HasDoubleSpeed") and 0.75 or 1.5

	if skillName == "Maneuver" then UpdateBountyProgress(player, "Maneuver", 1) end
	if skillName == "Transform" then UpdateBountyProgress(player, "Transform", 1) end

	local function DispatchStrike(attacker, defender, strikeSkill, aimLimb)
		if attacker.HP <= 0 or defender.HP <= 0 then return end
		local success, msg, didHit, shakeType = pcall(function() 
			return CombatCore.ExecuteStrike(attacker, defender, strikeSkill, aimLimb, attacker.IsPlayer and "You" or attacker.Name, defender.IsPlayer and "you" or defender.Name, attacker.IsPlayer and "#FFFFFF" or "#FF5555", defender.IsPlayer and "#FFFFFF" or "#FF5555") 
		end)
		if success then 
			if not didHit and string.find(defender.Name, "Dummy") then
				msg = "<font color='#AAAAAA'>You missed the " .. defender.Name .. "!</font>"
			end
			CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = msg, DidHit = didHit, ShakeType = shakeType, SkillUsed = strikeSkill, IsPlayerAttacking = attacker.IsPlayer})
			task.wait(turnDelay) 
		else 
			CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#FF0000'>SERVER LOGIC ERROR: " .. tostring(msg) .. "</font>", DidHit = false, ShakeType = "None"}) 
		end
	end

	local pSpeed = battle.Player.TotalSpeed or 10
	if battle.Player.Statuses and battle.Player.Statuses["Crippled"] then pSpeed *= 0.5 end
	if battle.Player.Statuses and battle.Player.Statuses["Immobilized"] then pSpeed = -999 end

	local eSpeed = battle.Enemy.TotalSpeed or 10
	if battle.Enemy.Statuses and battle.Enemy.Statuses["Crippled"] then eSpeed *= 0.5 end
	if battle.Enemy.Statuses and battle.Enemy.Statuses["Immobilized"] then eSpeed = -999 end

	if skillName == "Maneuver" or skillName == "Evasive Maneuver" or skillName == "Smoke Screen" or skillName == "Block" then pSpeed += 9999 end

	local pRoll = pSpeed + math.random(1, 15)
	local eRoll = eSpeed + math.random(1, 15)

	local combatants = { battle.Player, battle.Enemy }
	table.sort(combatants, function(a, b)
		local speedA = a.IsPlayer and pRoll or eRoll
		local speedB = b.IsPlayer and pRoll or eRoll
		return speedA > speedB
	end)

	for _, combatant in ipairs(combatants) do
		if battle.Player.HP < 1 or battle.Enemy.HP < 1 then break end
		if combatant.HP < 1 then continue end

		local dotDamage = 0
		local dotLog = ""

		if combatant.Statuses then
			if combatant.Statuses["Bleed"] and combatant.Statuses["Bleed"] > 0 then
				local dmg = combatant.IsPlayer and math.floor(combatant.MaxHP * 0.05) or math.min(math.floor(combatant.MaxHP * 0.02), 500)
				dotDamage += dmg
				dotLog = dotLog .. " <font color='#FF5555'>[BLEED: -" .. dmg .. "]</font>"
			end
			if combatant.Statuses["Burn"] and combatant.Statuses["Burn"] > 0 then
				local dmg = combatant.IsPlayer and math.floor(combatant.MaxHP * 0.05) or math.min(math.floor(combatant.MaxHP * 0.02), 600)
				dotDamage += dmg
				dotLog = dotLog .. " <font color='#FFAA00'>[BURN: -" .. dmg .. "]</font>"
			end

			local immunitiesToTick = {}
			local immunitiesToAdd = {}

			for sName, duration in pairs(combatant.Statuses) do
				if string.find(sName, "Immunity") then
					table.insert(immunitiesToTick, sName)
				elseif sName ~= "Transformed" and type(duration) == "number" and duration > 0 then
					combatant.Statuses[sName] = duration - 1
					if combatant.Statuses[sName] <= 0 then 
						combatant.Statuses[sName] = nil 
						if sName == "Stun" or sName == "Bleed" or sName == "Burn" or sName == "Crippled" or sName == "Immobilized" or sName == "Weakened" or sName == "Blinded" or sName == "TrueBlind" or sName == "Debuff_Defense" then
							immunitiesToAdd[sName .. "Immunity"] = 2
						end
					end
				end
			end

			for _, immName in ipairs(immunitiesToTick) do
				combatant.Statuses[immName] = combatant.Statuses[immName] - 1
				if combatant.Statuses[immName] <= 0 then combatant.Statuses[immName] = nil end
			end
			for immName, dur in pairs(immunitiesToAdd) do
				combatant.Statuses[immName] = dur
			end
		end

		if dotDamage > 0 then
			combatant.HP -= dotDamage
			local targetName = combatant.IsPlayer and "You" or combatant.Name
			CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = targetName .. " took damage from status effects!" .. dotLog, DidHit = false, ShakeType = "None"})
			task.wait(turnDelay)
			if combatant.HP < 1 then continue end 
		end

		if combatant.Statuses and (combatant.Statuses["Blinded"] or combatant.Statuses["TrueBlind"] or combatant.Statuses["Stun"]) then
			local denyMsg = combatant.IsPlayer and "<font color='#555555'>You are INCAPACITATED and lost your turn!</font>" or "<font color='#555555'>" .. combatant.Name .. " is INCAPACITATED and lost their turn!</font>"
			CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = denyMsg, DidHit = false, ShakeType = "None"})
			task.wait(turnDelay)

			if combatant.Cooldowns then for sName, cd in pairs(combatant.Cooldowns) do if cd > 0 then combatant.Cooldowns[sName] = cd - 1 end end end
			if combatant.GateType == "Steam" and combatant.GateHP and combatant.GateHP > 0 then combatant.GateHP = math.max(0, combatant.GateHP - 1) end

			if not combatant.IsPlayer and not combatant.IsHuman then
				if not (combatant.Statuses and combatant.Statuses["Burn"]) then
					local regenAmt = math.min(math.floor(combatant.MaxHP * 0.05), 100)
					combatant.HP = math.min(combatant.MaxHP, combatant.HP + regenAmt)
				end
			end
			continue
		end

		if combatant.Cooldowns then for sName, cd in pairs(combatant.Cooldowns) do if cd > 0 then combatant.Cooldowns[sName] = cd - 1 end end end
		if combatant.GateType == "Steam" and combatant.GateHP and combatant.GateHP > 0 then combatant.GateHP = math.max(0, combatant.GateHP - 1) end

		if combatant.IsPlayer then
			if skill.Effect == "Flee" or skillName == "Retreat" then 
				CombatUpdate:FireClient(player, "Fled", {Battle = battle})
				if battle.Context.IsPaths then 
					CombatUpdate:FireClient(player, "PathsDeath", {Battle = battle}) 
				end
				ActiveBattles[player.UserId] = nil
				return 
			end

			if skillName == "Fall Back" then
				combatant.Gas = math.max(0, combatant.Gas - (skill.GasCost or 15))
				battle.Context.Range = "Long"
				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#55FFFF'>You fell back to LONG RANGE! Close-range attacks cannot reach you.</font>", DidHit = false, ShakeType = "None"})
				task.wait(turnDelay)
				continue
			end

			if skillName == "Close In" then
				combatant.Gas = math.max(0, combatant.Gas - (skill.GasCost or 15))
				battle.Context.Range = "Close"
				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#55FF55'>You fired your ODM gear and closed the gap to MELEE RANGE!</font>", DidHit = false, ShakeType = "None"})
				task.wait(turnDelay)
				continue
			end

			if skill.GasCost then combatant.Gas = math.max(0, combatant.Gas - skill.GasCost) end
			if skill.Effect == "Rest" or skillName == "Recover" then combatant.Gas = math.min(combatant.MaxGas, combatant.Gas + (combatant.MaxGas * 0.40)) end
			if skill.EnergyCost then combatant.TitanEnergy = math.max(0, combatant.TitanEnergy - skill.EnergyCost) end

			DispatchStrike(battle.Player, battle.Enemy, skillName, targetLimb)

			if combatant.Statuses and combatant.Statuses["Transformed"] then if combatant.TitanEnergy <= 0 then combatant.Statuses["Transformed"] = nil end end
		else
			if string.find(combatant.Name, "Dummy") then
				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = combatant.Name .. " stands completely still.", DidHit = false, ShakeType = "None"})
				local dummyDelay = player:GetAttribute("HasDoubleSpeed") and 0.5 or 1.0
				task.wait(dummyDelay)
				continue
			end

			if not combatant.Cooldowns then combatant.Cooldowns = {} end

			local validAiSkills = {}
			local hasRangedOptions = false
			local isDodging = combatant.Statuses and combatant.Statuses["Dodge"]

			for _, s in ipairs(combatant.Skills) do
				if not combatant.Cooldowns[s] or combatant.Cooldowns[s] <= 0 then
					if isDodging and (s == "Evasive Maneuver" or s == "Smoke Screen" or s == "Block") then continue end

					local sData = SkillData.Skills[s]
					if sData then
						local sRange = sData.Range or "Close"
						if battle.Context.Range == "Long" then
							if sRange == "Long" or sRange == "Any" or sData.Effect == "CloseGap" then
								table.insert(validAiSkills, s)
								hasRangedOptions = true
							end
						else
							if sRange == "Close" or sRange == "Any" then
								table.insert(validAiSkills, s)
							end
						end
					end
				end
			end

			battle.Context.TurnCount = (battle.Context.TurnCount or 0) + 1
			local aiSkill = "Brutal Swipe"

			if combatant.Statuses["Telegraphing"] then
				aiSkill = combatant.Statuses["Telegraphing"]
				combatant.Statuses["Telegraphing"] = nil
			else
				if battle.Context.Range == "Long" and not hasRangedOptions then
					aiSkill = "Advance"
				else
					if battle.Context.Range == "Long" and table.find(validAiSkills, "Crushed Boulders") then
						aiSkill = "Crushed Boulders"
					elseif string.find(combatant.Name, "Female Titan") and combatant.Statuses and combatant.Statuses.Crippled and table.find(validAiSkills, "Nape Guard") then
						aiSkill = "Nape Guard"
					elseif string.find(combatant.Name, "Founding Titan") and battle.Context.TurnCount % 8 == 0 and not battle.Context.StoredBoss then
						aiSkill = "Coordinate Command"
					elseif combatant.LastSkill == "Titan Grab" and table.find(validAiSkills, "Titan Bite") then
						aiSkill = "Titan Bite" 
					elseif #validAiSkills > 0 then
						local attackMoves = {}
						for _, s in ipairs(validAiSkills) do
							if s ~= "Evasive Maneuver" and s ~= "Smoke Screen" and s ~= "Block" and s ~= "Regroup" then
								table.insert(attackMoves, s)
							end
						end

						if #attackMoves > 0 and math.random(1, 100) <= 80 then
							aiSkill = attackMoves[math.random(1, #attackMoves)]
						else
							aiSkill = validAiSkills[math.random(1, #validAiSkills)]
						end
					end
				end

				if aiSkill ~= "Advance" and SkillData.Skills[aiSkill] and SkillData.Skills[aiSkill].Telegraphed then
					combatant.Statuses["Telegraphing"] = aiSkill
					CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<b><font color='#FFAA00'>WARNING: " .. combatant.Name .. " is charging up " .. aiSkill:upper() .. "! Brace yourself!</font></b>", DidHit = false, ShakeType = "Heavy"})
					task.wait(turnDelay)
					continue
				end
			end

			if aiSkill == "Advance" then
				battle.Context.Range = "Close"
				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#FF5555'>" .. combatant.Name .. " charged forward, closing the gap to MELEE RANGE!</font>", DidHit = false, ShakeType = "Heavy"})
				task.wait(turnDelay)
				continue
			end

			if (aiSkill == "Maneuver" or aiSkill == "Evasive Maneuver" or aiSkill == "Smoke Screen") and isDodging then 
				aiSkill = "Heavy Slash" 
			end

			if aiSkill == "Armored Tackle" or aiSkill == "Titan Grab" then
				battle.Context.Range = "Close"
			end

			local aiTargets = {"Body", "Body", "Arms", "Legs", "Nape"}
			local chosenSkillData = SkillData.Skills[aiSkill]
			local sRange = chosenSkillData and chosenSkillData.Range or "Close"

			if battle.Context.Range == "Long" and sRange == "Close" then
				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#AAAAAA'>" .. combatant.Name .. " used " .. aiSkill:upper() .. ", but you are at LONG RANGE! The attack missed completely!</font>", DidHit = false, ShakeType = "None"})
				task.wait(turnDelay)
			else
				DispatchStrike(battle.Enemy, battle.Player, aiSkill, aiTargets[math.random(1, #aiTargets)])
			end

			if aiSkill == "Coordinate Command" and string.find(combatant.Name, "Founding Titan") then
				local pPrestige = player.leaderstats.Prestige.Value
				local hpMult = GetHPScale(5, pPrestige) * 0.5 
				local dmgMult = GetDmgScale(5, pPrestige)

				battle.Context.StoredBoss = {
					Name = battle.Enemy.Name, HP = battle.Enemy.HP, MaxHP = battle.Enemy.MaxHP, GateType = battle.Enemy.GateType, GateHP = battle.Enemy.GateHP, MaxGateHP = battle.Enemy.MaxGateHP, TotalStrength = battle.Enemy.TotalStrength, TotalDefense = battle.Enemy.TotalDefense, TotalSpeed = battle.Enemy.TotalSpeed, Drops = battle.Enemy.Drops, Skills = battle.Enemy.Skills, Statuses = battle.Enemy.Statuses, Cooldowns = battle.Enemy.Cooldowns, LastSkill = battle.Enemy.LastSkill
				}

				battle.Enemy.Name = "Summoned Pure Titan"
				battle.Enemy.HP = math.floor(1000 * hpMult)
				battle.Enemy.MaxHP = math.floor(1000 * hpMult)
				battle.Enemy.GateType = nil
				battle.Enemy.GateHP = 0
				battle.Enemy.MaxGateHP = 0
				battle.Enemy.TotalStrength = math.floor(50 * dmgMult)
				battle.Enemy.TotalDefense = math.floor(20 * dmgMult)
				battle.Enemy.TotalSpeed = math.floor(15 * dmgMult)
				battle.Enemy.Skills = {"Brutal Swipe", "Titan Grab", "Titan Bite"}
				battle.Enemy.Statuses = {}
				battle.Enemy.Cooldowns = {}

				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#FF5555'>The Founding Titan summoned a Pure Titan to protect itself!</font>", DidHit = false, ShakeType = "Heavy"})
				task.wait(turnDelay)
			end
		end

		if not combatant.IsPlayer and not combatant.IsHuman and combatant.HP > 0 then
			if not (combatant.Statuses and combatant.Statuses["Burn"]) then
				local regenAmt = math.min(math.floor(combatant.MaxHP * 0.05), 100)
				combatant.HP = math.min(combatant.MaxHP, combatant.HP + regenAmt)
			end
		end
	end

	if battle.Player.HP < 1 then
		CombatUpdate:FireClient(player, "Defeat", {Battle = battle})
		if battle.Context.IsPaths then 
			CombatUpdate:FireClient(player, "PathsDeath", {Battle = battle}) 
		end
		ActiveBattles[player.UserId] = nil
	elseif battle.Enemy.HP < 1 then
		ProcessEnemyDeath(player, battle)
	else
		if not battle.Player.Statuses or not battle.Player.Statuses["Transformed"] then battle.Player.TitanEnergy = math.min(100, (battle.Player.TitanEnergy or 0) + 15) end
		battle.IsProcessing = false
		CombatUpdate:FireClient(player, "Update", {Battle = battle})
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ActiveBattles[player.UserId] = nil
end)