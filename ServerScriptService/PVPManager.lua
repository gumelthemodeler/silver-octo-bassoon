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
local CombatCore = require(script.Parent:WaitForChild("CombatCore"))

local ActiveMatches = {}
local PvPQueue = {}
local MatchCounter = 0
local TURN_DURATION = 15 

local function CreatePvPCombatant(player)
	local wpnName = player:GetAttribute("EquippedWeapon") or "None"
	local accName = player:GetAttribute("EquippedAccessory") or "None"
	local wpnBonus = (ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Bonus) or {}
	local accBonus = (ItemData.Equipment[accName] and ItemData.Equipment[accName].Bonus) or {}

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
		Clan = player:GetAttribute("Clan") or "None", Titan = player:GetAttribute("Titan") or "None",
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

local function EndMatch(matchId, winnerUserId)
	local match = ActiveMatches[matchId]
	if not match then return end

	local p1 = match.P1.PlayerObj
	local p2 = match.P2.PlayerObj
	local winner = nil
	local loser = nil

	if p1 and p1.UserId == winnerUserId then winner = p1; loser = p2
	elseif p2 and p2.UserId == winnerUserId then winner = p2; loser = p1 end

	if winner and loser then
		local wElo = winner:FindFirstChild("leaderstats") and winner.leaderstats:FindFirstChild("Elo")
		local lElo = loser:FindFirstChild("leaderstats") and loser.leaderstats:FindFirstChild("Elo")

		if wElo and lElo then
			wElo.Value = wElo.Value + 25
			lElo.Value = math.max(100, lElo.Value - 15)
		end

		winner.leaderstats.Dews.Value += 2500
		winner:SetAttribute("XP", (winner:GetAttribute("XP") or 0) + 1500)
		Network.NotificationEvent:FireClient(winner, "Victory! +25 Elo, +2500 Dews", "Success")
		Network.NotificationEvent:FireClient(loser, "Defeat. -15 Elo", "Error")
	end

	local winningBets = match.Bets[winnerUserId]
	for _, betData in pairs(winningBets) do
		local spectator = betData.Spectator
		if spectator and spectator.Parent then
			local payout = betData.Amount * 2
			spectator.leaderstats.Dews.Value += payout
			Network.NotificationEvent:FireClient(spectator, "You won " .. payout .. " Dews from your wager!", "Success")
		end
	end

	ActiveMatches[matchId] = nil
	PvPUpdate:FireAllClients("MatchEnded", matchId, winnerUserId)
end

local function StartMatch(p1, p2)
	MatchCounter += 1
	local matchId = "Match_" .. MatchCounter

	ActiveMatches[matchId] = {
		P1 = CreatePvPCombatant(p1),
		P2 = CreatePvPCombatant(p2),
		Turn = 1, State = "WaitingForMoves",
		TurnEndTime = os.time() + TURN_DURATION, 
		Bets = { [p1.UserId] = {}, [p2.UserId] = {} }
	}
	PvPUpdate:FireAllClients("MatchStarted", matchId, p1.Name, p2.Name, p1.UserId, p2.UserId, ActiveMatches[matchId].TurnEndTime)
end

local function ResolveTurn(matchId)
	local match = ActiveMatches[matchId]
	if not match then return end
	match.State = "Resolving"

	local turnDelay = 1.5
	local first, second
	local p1Spd = match.P1.TotalSpeed + math.random(1, 15)
	local p2Spd = match.P2.TotalSpeed + math.random(1, 15)

	if match.P1.Statuses and match.P1.Statuses["Crippled"] then p1Spd *= 0.5 end
	if match.P2.Statuses and match.P2.Statuses["Crippled"] then p2Spd *= 0.5 end

	if p1Spd >= p2Spd then first, second = match.P1, match.P2 else first, second = match.P2, match.P1 end

	local function ApplyPvPCCReduction(combatant)
		if not combatant.Statuses then return end
		-- Convert Hard CC (Turn Skips) into Soft CC (Stat Reductions)
		if combatant.Statuses["Stun"] then
			combatant.Statuses["Crippled"] = combatant.Statuses["Stun"]
			combatant.Statuses["Stun"] = nil
		end
		if combatant.Statuses["Blinded"] then
			combatant.Statuses["Weakened"] = combatant.Statuses["Blinded"]
			combatant.Statuses["Blinded"] = nil
		end
		if combatant.Statuses["TrueBlind"] then
			combatant.Statuses["Weakened"] = combatant.Statuses["TrueBlind"]
			combatant.Statuses["TrueBlind"] = nil
		end
	end

	local function TickStatuses(combatant)
		if not combatant.Statuses then return end
		if combatant.Statuses["Bleed"] then combatant.HP -= math.min(combatant.MaxHP * 0.05, 500) end
		if combatant.Statuses["Burn"] then combatant.HP -= math.min(combatant.MaxHP * 0.05, 600) end

		for sName, dur in pairs(combatant.Statuses) do
			if type(dur) == "number" and sName ~= "Transformed" then
				combatant.Statuses[sName] = dur - 1
				if combatant.Statuses[sName] <= 0 then combatant.Statuses[sName] = nil end
			end
		end
	end

	local function ProcessStrike(attacker, defender, skillName)
		if attacker.HP <= 0 or defender.HP <= 0 then return end
		local targetLimb = attacker.TargetLimb or "Body"

		ApplyPvPCCReduction(attacker) -- Prevent turn skipping in PvP

		local skill = SkillData.Skills[skillName]
		if skill then
			if skill.GasCost then attacker.Gas = math.max(0, attacker.Gas - skill.GasCost) end
			if skill.EnergyCost then attacker.TitanEnergy = math.max(0, attacker.TitanEnergy - skill.EnergyCost) end
			if skill.Effect == "Rest" or skillName == "Recover" then attacker.Gas = math.min(attacker.MaxGas, attacker.Gas + (attacker.MaxGas * 0.40)) end
		end

		local logMsg, didHit, shakeType = CombatCore.ExecuteStrike(attacker, defender, skillName, targetLimb, attacker.Name, defender.Name, "#55FF55", "#FF5555")

		PvPUpdate:FireAllClients("TurnStrike", matchId, {
			LogMsg = logMsg, DidHit = didHit, ShakeType = shakeType, SkillUsed = skillName, Attacker = attacker.Name,
			P1_HP = match.P1.HP, P2_HP = match.P2.HP, P1_Max = match.P1.MaxHP, P2_Max = match.P2.MaxHP,
			P1_Gas = match.P1.Gas, P2_Gas = match.P2.Gas, P1_MaxGas = match.P1.MaxGas, P2_MaxGas = match.P2.MaxGas,
			P1_Statuses = match.P1.Statuses, P2_Statuses = match.P2.Statuses -- SEND STATUSES TO CLIENT
		})
		task.wait(turnDelay)
	end

	ProcessStrike(first, second, first.Move)
	if second.HP > 0 then ProcessStrike(second, first, second.Move) end

	TickStatuses(match.P1)
	TickStatuses(match.P2)

	if match.P1.HP <= 0 or match.P2.HP <= 0 then
		local winner = match.P1.HP > 0 and match.P1 or match.P2
		EndMatch(matchId, winner.PlayerObj.UserId)
		return
	end

	match.Turn += 1
	match.P1.Move = nil; match.P1.TargetLimb = nil
	match.P2.Move = nil; match.P2.TargetLimb = nil
	match.State = "WaitingForMoves"
	match.TurnEndTime = os.time() + TURN_DURATION 

	PvPUpdate:FireAllClients("NextTurnStarted", matchId, match.Turn, match.TurnEndTime)
end

task.spawn(function()
	while task.wait(1) do
		local now = os.time()
		for matchId, match in pairs(ActiveMatches) do
			if match.State == "WaitingForMoves" and now >= match.TurnEndTime then
				local function GetFallbackMove(combatant)
					if combatant.Statuses and combatant.Statuses["Transformed"] then return "Titan Punch" end
					return "Basic Slash"
				end

				if not match.P1.Move then 
					match.P1.Move = GetFallbackMove(match.P1)
					match.P1.TargetLimb = "Body" 
				end
				if not match.P2.Move then 
					match.P2.Move = GetFallbackMove(match.P2)
					match.P2.TargetLimb = "Body" 
				end
				ResolveTurn(matchId)
			end
		end
	end
end)

PvPAction.OnServerEvent:Connect(function(player, actionType, matchId, data1, data2)
	if actionType == "JoinQueue" then
		for _, m in pairs(ActiveMatches) do if m.P1.PlayerObj == player or m.P2.PlayerObj == player then return end end
		for _, qp in ipairs(PvPQueue) do if qp == player then return end end
		table.insert(PvPQueue, player)

		if #PvPQueue >= 2 then
			local p1 = table.remove(PvPQueue, 1)
			local p2 = table.remove(PvPQueue, 1)
			if p1 and p1.Parent and p2 and p2.Parent then StartMatch(p1, p2) end
		end
		return
	elseif actionType == "LeaveQueue" then
		for i, qp in ipairs(PvPQueue) do if qp == player then table.remove(PvPQueue, i); break end end
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
	elseif actionType == "PlaceBet" and match.State == "WaitingForMoves" then
		local targetUserId = data1
		local betAmount = data2
		if player.leaderstats.Dews.Value >= betAmount and betAmount > 0 then
			player.leaderstats.Dews.Value -= betAmount
			table.insert(match.Bets[targetUserId], { Spectator = player, Amount = betAmount })
			Network.NotificationEvent:FireClient(player, "Wager locked in!", "Success")
		else
			Network.NotificationEvent:FireClient(player, "Not enough Dews!", "Error")
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	-- Clean up queue
	for i, qp in ipairs(PvPQueue) do
		if qp == player then table.remove(PvPQueue, i); break end
	end

	-- Clean up active matches and award Elo to the remaining player
	for matchId, match in pairs(ActiveMatches) do
		if match.P1.PlayerObj == player then
			match.P1.HP = 0
			EndMatch(matchId, match.P2.PlayerObj.UserId)
		elseif match.P2.PlayerObj == player then
			match.P2.HP = 0
			EndMatch(matchId, match.P1.PlayerObj.UserId)
		end
	end
end)