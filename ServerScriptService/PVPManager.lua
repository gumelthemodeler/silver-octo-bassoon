-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")

local PvPAction = Network:FindFirstChild("PvPAction") or Instance.new("RemoteEvent", Network); PvPAction.Name = "PvPAction"
local PvPUpdate = Network:FindFirstChild("PvPUpdate") or Instance.new("RemoteEvent", Network); PvPUpdate.Name = "PvPUpdate"
local PvPTaunt = Network:FindFirstChild("PvPTaunt") or Instance.new("RemoteEvent", Network); PvPTaunt.Name = "PvPTaunt"

local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local CombatCore = require(script.Parent:WaitForChild("CombatCore")) -- USING YOUR COMBAT CORE

local ActiveMatches = {}
local PvPQueue = {}
local MatchCounter = 0

-- Mirrors how CombatManager constructs a combatant
local function CreatePvPCombatant(player)
	local wpnName = player:GetAttribute("EquippedWeapon") or "None"
	local accName = player:GetAttribute("EquippedAccessory") or "None"
	local wpnBonus = (ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Bonus) or {}
	local accBonus = (ItemData.Equipment[accName] and ItemData.Equipment[accName].Bonus) or {}

	-- Parse Awakened Stats
	local safeWpnName = wpnName:gsub("[^%w]", "")
	local awakenedString = player:GetAttribute(safeWpnName .. "_Awakened")
	local awakenedStats = { DmgMult = 1.0, DodgeBonus = 0, CritBonus = 0, HpBonus = 0, SpdBonus = 0, GasBonus = 0, HealOnKill = 0, IgnoreArmor = 0 }
	if awakenedString then
		for stat in string.gmatch(awakenedString, "[^|]+") do
			stat = stat:match("^%s*(.-)%s*$")
			if stat:find("DMG") then awakenedStats.DmgMult += tonumber(stat:match("%d+")) / 100
			elseif stat:find("DODGE") then awakenedStats.DodgeBonus += tonumber(stat:match("%d+"))
			elseif stat:find("CRIT") then awakenedStats.CritBonus += tonumber(stat:match("%d+"))
			elseif stat:find("MAX HP") then awakenedStats.HpBonus += tonumber(stat:match("%d+"))
			elseif stat:find("SPEED") then awakenedStats.SpdBonus += tonumber(stat:match("%d+"))
			elseif stat:find("GAS CAP") then awakenedStats.GasBonus += tonumber(stat:match("%d+"))
			elseif stat:find("IGNORE") then awakenedStats.IgnoreArmor += tonumber(stat:match("%d+")) / 100
			end
		end
	end

	local pMaxHP = ((player:GetAttribute("Health") or 10) + (wpnBonus.Health or 0) + (accBonus.Health or 0)) * 10
	pMaxHP = pMaxHP + awakenedStats.HpBonus

	local pMaxGas = ((player:GetAttribute("Gas") or 10) + (wpnBonus.Gas or 0) + (accBonus.Gas or 0)) * 10
	pMaxGas = pMaxGas + awakenedStats.GasBonus

	return {
		IsPlayer = true, Name = player.Name, PlayerObj = player,
		Clan = player:GetAttribute("Clan") or "None",
		Titan = player:GetAttribute("Titan") or "None",
		Style = ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Style or "None",
		HP = pMaxHP, MaxHP = pMaxHP, Gas = pMaxGas, MaxGas = pMaxGas,
		TitanEnergy = 100, MaxTitanEnergy = 100,
		TotalStrength = (player:GetAttribute("Strength") or 10) + (wpnBonus.Strength or 0) + (accBonus.Strength or 0),
		TotalDefense = (player:GetAttribute("Defense") or 10) + (wpnBonus.Defense or 0) + (accBonus.Defense or 0),
		TotalSpeed = (player:GetAttribute("Speed") or 10) + (wpnBonus.Speed or 0) + (accBonus.Speed or 0) + awakenedStats.SpdBonus,
		TotalResolve = (player:GetAttribute("Resolve") or 10) + (wpnBonus.Resolve or 0) + (accBonus.Resolve or 0),
		Statuses = {}, Cooldowns = {}, LastSkill = "None", AwakenedStats = awakenedStats, ResolveSurvivals = 0
	}
end

local function StartMatch(p1, p2)
	MatchCounter += 1
	local matchId = "Match_" .. MatchCounter

	ActiveMatches[matchId] = {
		P1 = CreatePvPCombatant(p1),
		P2 = CreatePvPCombatant(p2),
		Turn = 1, State = "WaitingForMoves",
		Bets = { [p1.UserId] = {}, [p2.UserId] = {} }
	}
	PvPUpdate:FireAllClients("MatchStarted", matchId, p1.Name, p2.Name, p1.UserId, p2.UserId)
end

local function ResolveTurn(matchId)
	local match = ActiveMatches[matchId]
	if not match then return end
	match.State = "Resolving"

	local turnDelay = 1.5

	-- Determine Turn Order based on TotalSpeed
	local first, second
	local p1Spd = match.P1.TotalSpeed + math.random(1, 15)
	local p2Spd = match.P2.TotalSpeed + math.random(1, 15)

	if match.P1.Statuses and match.P1.Statuses["Crippled"] then p1Spd *= 0.5 end
	if match.P2.Statuses and match.P2.Statuses["Crippled"] then p2Spd *= 0.5 end

	if p1Spd >= p2Spd then first, second = match.P1, match.P2 else first, second = match.P2, match.P1 end

	local function ProcessStrike(attacker, defender, skillName)
		if attacker.HP <= 0 or defender.HP <= 0 then return end
		local targetLimb = attacker.TargetLimb or "Body"

		-- DEDUCT GAS AND ENERGY
		local skill = SkillData.Skills[skillName]
		if skill then
			if skill.GasCost then attacker.Gas = math.max(0, attacker.Gas - skill.GasCost) end
			if skill.EnergyCost then attacker.TitanEnergy = math.max(0, attacker.TitanEnergy - skill.EnergyCost) end
			if skill.Effect == "Rest" or skillName == "Recover" then attacker.Gas = math.min(attacker.MaxGas, attacker.Gas + (attacker.MaxGas * 0.40)) end
		end

		-- USE YOUR COMBAT CORE LOGIC
		local logMsg, didHit, shakeType = CombatCore.ExecuteStrike(attacker, defender, skillName, targetLimb, attacker.Name, defender.Name, "#55FF55", "#FF5555")

		-- ADDED: 'Attacker' so the client knows which way to play the visual effect
		PvPUpdate:FireAllClients("TurnStrike", matchId, {
			LogMsg = logMsg, DidHit = didHit, ShakeType = shakeType, SkillUsed = skillName, Attacker = attacker.Name,
			P1_HP = match.P1.HP, P2_HP = match.P2.HP, P1_Max = match.P1.MaxHP, P2_Max = match.P2.MaxHP
		})
		task.wait(turnDelay)
	end

	-- Execute Strikes
	ProcessStrike(first, second, first.Move)
	if second.HP > 0 then ProcessStrike(second, first, second.Move) end

	-- Check for Death
	if match.P1.HP <= 0 or match.P2.HP <= 0 then
		local winner = match.P1.HP > 0 and match.P1 or match.P2
		PvPUpdate:FireAllClients("MatchEnded", matchId, winner.PlayerObj.UserId)
		ActiveMatches[matchId] = nil
		return
	end

	-- Reset turn
	match.Turn += 1
	match.P1.Move = nil; match.P1.TargetLimb = nil
	match.P2.Move = nil; match.P2.TargetLimb = nil
	match.State = "WaitingForMoves"
	PvPUpdate:FireAllClients("NextTurnStarted", matchId, match.Turn)
end
PvPAction.OnServerEvent:Connect(function(player, actionType, matchId, data1, data2)
	if actionType == "JoinQueue" then
		for _, m in pairs(ActiveMatches) do if m.P1.PlayerObj == player or m.P2.PlayerObj == player then return end end
		for _, qp in ipairs(PvPQueue) do if qp == player then return end end

		table.insert(PvPQueue, player)
		Network.NotificationEvent:FireClient(player, "Entered the Underground Arena Queue...", "Success")

		if #PvPQueue >= 2 then
			local p1 = table.remove(PvPQueue, 1)
			local p2 = table.remove(PvPQueue, 1)
			if p1 and p1.Parent and p2 and p2.Parent then StartMatch(p1, p2) end
		end
		return
	elseif actionType == "LeaveQueue" then
		for i, qp in ipairs(PvPQueue) do
			if qp == player then table.remove(PvPQueue, i); break end
		end
		return
	end

	local match = ActiveMatches[matchId]
	if not match then return end

	if actionType == "SubmitMove" and match.State == "WaitingForMoves" then
		local moveName = data1
		local targetLimb = data2 or "Body"
		if not SkillData.Skills[moveName] then return end

		if match.P1.PlayerObj == player then match.P1.Move = moveName; match.P1.TargetLimb = targetLimb
		elseif match.P2.PlayerObj == player then match.P2.Move = moveName; match.P2.TargetLimb = targetLimb end

		if match.P1.Move and match.P2.Move then ResolveTurn(matchId) end
	end
end)