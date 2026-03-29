-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")

-- [[ 1. REMOTE EVENT CREATION (SERVER EXCLUSIVE) ]]
local PvPAction = Network:FindFirstChild("PvPAction") or Instance.new("RemoteEvent")
PvPAction.Name = "PvPAction"
PvPAction.Parent = Network

local PvPUpdate = Network:FindFirstChild("PvPUpdate") or Instance.new("RemoteEvent")
PvPUpdate.Name = "PvPUpdate"
PvPUpdate.Parent = Network

local PvPTaunt = Network:FindFirstChild("PvPTaunt") or Instance.new("RemoteEvent")
PvPTaunt.Name = "PvPTaunt"
PvPTaunt.Parent = Network

local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

local ActiveMatches = {}
local MatchCounter = 0

-- [[ 2. CORE MATCH FUNCTIONS ]]
local function EndMatch(matchId, winnerUserId)
	local match = ActiveMatches[matchId]
	if not match then return end

	-- Process Bets
	local winningBets = match.Bets[winnerUserId]
	for _, betData in pairs(winningBets) do
		local spectator = betData.Spectator
		if spectator and spectator.Parent then
			-- Give 2x Dews Back
			local payout = betData.Amount * 2
			spectator.leaderstats.Dews.Value += payout
			Network.NotificationEvent:FireClient(spectator, "You won " .. payout .. " Dews from betting!", "Success")

			-- 10% Chance for a Random Item Reward
			if math.random(1, 100) <= 10 then
				local itemReward = "Standard Titan Serum"
				spectator:SetAttribute(itemReward:gsub("[^%w]", "") .. "Count", (spectator:GetAttribute(itemReward:gsub("[^%w]", "") .. "Count") or 0) + 1)
				Network.NotificationEvent:FireClient(spectator, "Bonus Reward: You received a " .. itemReward .. "!", "Success")
			end
		end
	end

	ActiveMatches[matchId] = nil
	PvPUpdate:FireAllClients("MatchEnded", matchId, winnerUserId)
end

local function GetNormalizedStats(player)
	local rawStr = player:GetAttribute("Strength") or 10
	local rawDef = player:GetAttribute("Defense") or 10
	local rawSpd = player:GetAttribute("Speed") or 10

	local totalRaw = rawStr + rawDef + rawSpd
	if totalRaw == 0 then totalRaw = 1 end

	local pvpBaseline = 1000
	local scaleFactor = pvpBaseline / totalRaw

	return {
		Strength = math.floor(rawStr * scaleFactor),
		Defense = math.floor(rawDef * scaleFactor),
		Speed = math.floor(rawSpd * scaleFactor)
	}
end

local function ResolveTurn(matchId)
	local match = ActiveMatches[matchId]
	if not match then return end

	match.State = "Resolving"

	local p1Stats = GetNormalizedStats(match.P1.Player)
	local p2Stats = GetNormalizedStats(match.P2.Player)

	local p1Skill = SkillData.Skills[match.P1.Move]
	local p2Skill = SkillData.Skills[match.P2.Move]

	-- Determine Turn Order based on Normalized Speed
	local firstActor, secondActor, firstStats, secondStats, firstSkill, secondSkill
	if p1Stats.Speed >= p2Stats.Speed then
		firstActor, secondActor = match.P1, match.P2
		firstStats, secondStats = p1Stats, p2Stats
		firstSkill, secondSkill = p1Skill, p2Skill
	else
		firstActor, secondActor = match.P2, match.P1
		firstStats, secondStats = p2Stats, p1Stats
		firstSkill, secondSkill = p2Skill, p1Skill
	end

	local function ExecuteStrike(attacker, defender, atkStats, defStats, skill)
		if skill.Effect == "Block" then return 0, "BlockMark" end

		local baseDamage = (atkStats.Strength * (skill.Mult or 1))
		local mitigation = (defStats.Defense * 0.5)
		local finalDamage = math.max(1, math.floor(baseDamage - mitigation))

		defender.HP -= finalDamage
		return finalDamage, skill.VFX or "SlashMark"
	end

	-- 1st Strike
	local dmg1, vfx1 = ExecuteStrike(firstActor, secondActor, firstStats, secondStats, firstSkill)

	if secondActor.HP <= 0 then
		PvPUpdate:FireAllClients("TurnResolved", matchId, {
			First = {Player = firstActor.Player.Name, Move = firstSkill.Name, Damage = dmg1, VFX = vfx1, NewHP = firstActor.HP},
			Second = {Player = secondActor.Player.Name, Move = "None", Damage = 0, VFX = "None", NewHP = 0}
		})
		EndMatch(matchId, firstActor.Player.UserId)
		return
	end

	-- 2nd Strike
	local dmg2, vfx2 = ExecuteStrike(secondActor, firstActor, secondStats, firstStats, secondSkill)

	PvPUpdate:FireAllClients("TurnResolved", matchId, {
		First = {Player = firstActor.Player.Name, Move = firstSkill.Name, Damage = dmg1, VFX = vfx1, NewHP = firstActor.HP},
		Second = {Player = secondActor.Player.Name, Move = secondSkill.Name, Damage = dmg2, VFX = vfx2, NewHP = secondActor.HP}
	})

	if firstActor.HP <= 0 then
		EndMatch(matchId, secondActor.Player.UserId)
		return
	end

	-- Reset for the next turn
	match.Turn += 1
	match.P1.Move = nil
	match.P2.Move = nil
	match.State = "WaitingForMoves"
	PvPUpdate:FireAllClients("NextTurnStarted", matchId, match.Turn)
end

-- [[ 3. PUBLIC API & EVENTS ]]
function StartMatch(player1, player2)
	MatchCounter += 1
	local matchId = "Match_" .. MatchCounter

	ActiveMatches[matchId] = {
		P1 = { Player = player1, HP = 100, MaxHP = 100, Move = nil },
		P2 = { Player = player2, HP = 100, MaxHP = 100, Move = nil },
		Turn = 1,
		State = "WaitingForMoves",
		Bets = { [player1.UserId] = {}, [player2.UserId] = {} }
	}

	PvPUpdate:FireAllClients("MatchStarted", matchId, player1.Name, player2.Name, player1.UserId, player2.UserId)
end

local PvPQueue = {} -- Add this near the top of your variables, under ActiveMatches

PvPAction.OnServerEvent:Connect(function(player, actionType, matchId, data1, data2)
	-- [[ NEW: MATCHMAKING QUEUE ]]
	if actionType == "JoinQueue" then
		-- 1. Check if they are already fighting
		for _, m in pairs(ActiveMatches) do
			if m.P1.Player == player or m.P2.Player == player then return end
		end

		-- 2. Check if they are already in the queue
		for _, queuedPlayer in ipairs(PvPQueue) do
			if queuedPlayer == player then return end
		end

		table.insert(PvPQueue, player)
		Network.NotificationEvent:FireClient(player, "Joined PvP Matchmaking...", "Success")

		-- 3. If there are 2 players in the queue, start a match!
		if #PvPQueue >= 2 then
			local p1 = table.remove(PvPQueue, 1)
			local p2 = table.remove(PvPQueue, 1)

			-- Sanity check: Ensure both players are still in the server
			if p1 and p1.Parent and p2 and p2.Parent then
				StartMatch(p1, p2)
			end
		end
		return
	end

	-- [[ EXISTING: BETTING & COMBAT ]]
	local match = ActiveMatches[matchId]
	if not match then return end

	if actionType == "PlaceBet" and match.State == "WaitingForMoves" then
		local targetUserId = data1
		local betAmount = data2
		local dews = player.leaderstats.Dews.Value

		if dews >= betAmount and betAmount > 0 then
			player.leaderstats.Dews.Value -= betAmount
			table.insert(match.Bets[targetUserId], { Spectator = player, Amount = betAmount })
			Network.NotificationEvent:FireClient(player, "Bet placed successfully!", "Success")
		else
			Network.NotificationEvent:FireClient(player, "Not enough Dews!", "Error")
		end

	elseif actionType == "SubmitMove" and match.State == "WaitingForMoves" then
		local moveName = data1
		if not SkillData.Skills[moveName] then return end

		if match.P1.Player == player then
			match.P1.Move = moveName
		elseif match.P2.Player == player then
			match.P2.Move = moveName
		end

		if match.P1.Move and match.P2.Move then
			ResolveTurn(matchId)
		end
	end
end)

PvPTaunt.OnServerEvent:Connect(function(player, matchId, tauntId)
	local match = ActiveMatches[matchId]
	if not match then return end

	if match.P1.Player ~= player and match.P2.Player ~= player then return end

	if player:GetAttribute("HasPvPTaunts") then
		PvPTaunt:FireAllClients(matchId, player.Name, tauntId)
	else
		Network.NotificationEvent:FireClient(player, "You must own the Taunt Gamepass to do this!", "Error")
	end
end)