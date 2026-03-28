-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService") 
local BountyData = require(ReplicatedStorage:WaitForChild("BountyData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local GameDataStore = DataStoreService:GetDataStore("AoT_Data_V6") -- Changed to V6
local BackupDataStore = DataStoreService:GetDataStore("AoT_Backups_V3") -- Changed to V3
local RegimentStore = DataStoreService:GetDataStore("RegimentWars_V3") -- Changed to V3

local PrestigeLB = DataStoreService:GetOrderedDataStore("Global_Prestige_LB_V3") -- Changed to V3
local EloLB = DataStoreService:GetOrderedDataStore("Global_Elo_LB_V3") -- Changed to V3
local LBCache = { Prestige = {}, Elo = {} }

local RemotesFolder = ReplicatedStorage:FindFirstChild("Network") or Instance.new("Folder", ReplicatedStorage)
RemotesFolder.Name = "Network"

local requiredRemotes = {
	"ToggleMute", "CombatAction", "CombatUpdate", "PrestigeEvent", "NotificationEvent", "DungeonUpdate", "WorldBossUpdate", "WorldBossAction", 
	"RaidAction", "RaidUpdate", "ToggleTraining", "ShopAction", "ShopUpdate", "UpgradeStat", "TrainAction", "EquipItem", "SellItem", "AutoSell", "AdminCommand",
	"GachaRoll", "GachaRollAuto", "GachaResult", "AwakenAction", "ManageStorage", "VIPFreeReroll", "RedeemCode", "ClaimBounty", "ForgeItem", "ConsumeItem", "JoinRegiment", "ShowRegimentUI",
	"FuseTitan", "PathsShopBuy", "AwakenWeapon", "DispatchAction", "TradeAction", "TradeUpdate", "TradeRequest"
}

for _, remoteName in ipairs(requiredRemotes) do
	if not RemotesFolder:FindFirstChild(remoteName) then
		local re = Instance.new("RemoteEvent"); re.Name = remoteName; re.Parent = RemotesFolder
	end
end

if not RemotesFolder:FindFirstChild("GetShopData") then
	local rf = Instance.new("RemoteFunction"); rf.Name = "GetShopData"; rf.Parent = RemotesFolder
end

local lbRf = RemotesFolder:FindFirstChild("GetLeaderboardData")
if not lbRf then
	lbRf = Instance.new("RemoteFunction")
	lbRf.Name = "GetLeaderboardData"
	lbRf.Parent = RemotesFolder
end

lbRf.OnServerInvoke = function(player, lbType)
	local cache = LBCache[lbType] or {}
	local dynamicList = {}

	for _, entry in ipairs(cache) do
		table.insert(dynamicList, {Name = entry.Name, Value = entry.Value})
	end

	for _, p in ipairs(Players:GetPlayers()) do
		local ls = p:FindFirstChild("leaderstats")
		if ls then
			local liveVal = 0
			if lbType == "Prestige" and ls:FindFirstChild("Prestige") then liveVal = ls.Prestige.Value
			elseif lbType == "Elo" and ls:FindFirstChild("Elo") then liveVal = ls.Elo.Value end

			local found = false
			for _, entry in ipairs(dynamicList) do
				if entry.Name == p.Name then
					entry.Value = liveVal
					found = true
					break
				end
			end

			if not found and (lbType == "Elo" or liveVal > 0) then
				table.insert(dynamicList, {Name = p.Name, Value = liveVal})
			end
		end
	end

	table.sort(dynamicList, function(a, b) return a.Value > b.Value end)

	local finalList = {}
	for i = 1, math.min(50, #dynamicList) do
		if lbType == "Elo" or dynamicList[i].Value > 0 then
			table.insert(finalList, {Rank = i, Name = dynamicList[i].Name, Value = dynamicList[i].Value})
		end
	end
	return finalList
end

local DefaultData = { 
	Prestige = 0, CurrentPart = 1, CurrentMission = 1, CurrentWave = 1, XP = 0, TitanXP = 0, Dews = 0, Elo = 1000, 
	Titan = "None", FightingStyle = "None", Clan = "None", Regiment = "Cadet Corps", 
	TitanPity = 0, TitanMythicalPity = 0, ClanPity = 0, ClanMythicalPity = 0, 
	EquippedWeapon = "None", EquippedAccessory = "None", PathDust = 0, PathsFloor = 1, 
	DispatchData = "{}", AllyLevels = "{}", UnlockedAllies = "", MaxDeployments = 2, 
	Health = 10, Strength = 10, Defense = 10, Speed = 10, Gas = 10, Resolve = 10, LastFreeReroll = 0, RedeemedCodes = "", RewardClaimedWeek = 0,
	LoginStreak = 0, LastLoginDate = "", AutoTrainSessionTime = 0 
}

local CurrentVP = { ["Scout Regiment"] = 0, ["Garrison"] = 0, ["Military Police"] = 0, Week = math.floor(os.time() / 604800), Winner = "None" }
local winVal = Instance.new("StringValue", RemotesFolder); winVal.Name = "WinningRegiment"; winVal.Value = "None"
local GetVpRf = Instance.new("RemoteFunction", RemotesFolder); GetVpRf.Name = "GetRegimentVP"
GetVpRf.OnServerInvoke = function() return CurrentVP end

pcall(function() local data = RegimentStore:GetAsync("GlobalWarData") if data then CurrentVP = data; winVal.Value = data.Winner or "None" end end)

local vpEvent = Instance.new("BindableEvent", game:GetService("ServerStorage")); vpEvent.Name = "AddRegimentVP"
vpEvent.Event:Connect(function(player, amount)
	local reg = player:GetAttribute("Regiment")
	if CurrentVP[reg] then CurrentVP[reg] += amount end
end)

task.spawn(function()
	while true do
		local currentWeek = math.floor(os.time() / 604800)
		if currentWeek > CurrentVP.Week then
			local winner = "None"; local highest = -1
			for reg, vp in pairs(CurrentVP) do if reg ~= "Week" and reg ~= "Winner" and vp > highest then highest = vp; winner = reg end end
			CurrentVP = { ["Scout Regiment"] = 0, ["Garrison"] = 0, ["Military Police"] = 0, Week = currentWeek, Winner = winner }; winVal.Value = winner
			pcall(function() RegimentStore:SetAsync("GlobalWarData", CurrentVP) end)
		end

		pcall(function()
			local pages = PrestigeLB:GetSortedAsync(false, 50)
			local data = pages:GetCurrentPage()
			local newCache = {}
			for rank, entry in ipairs(data) do
				local pName = "Unknown"
				pcall(function() pName = Players:GetNameFromUserIdAsync(tonumber(entry.key)) end)
				table.insert(newCache, {Rank = rank, Name = pName, Value = entry.value})
			end
			LBCache.Prestige = newCache
		end)
		task.wait(2)

		pcall(function()
			local pages = EloLB:GetSortedAsync(false, 50)
			local data = pages:GetCurrentPage()
			local newCache = {}
			for rank, entry in ipairs(data) do
				local pName = "Unknown"
				pcall(function() pName = Players:GetNameFromUserIdAsync(tonumber(entry.key)) end)
				table.insert(newCache, {Rank = rank, Name = pName, Value = entry.value})
			end
			LBCache.Elo = newCache
		end)
		task.wait(60)
	end
end)

RemotesFolder.ClaimBounty.OnServerEvent:Connect(function(player, bType)
	local claimedAttr = bType .. "_Claimed"
	if player:GetAttribute(claimedAttr) then return end
	if (player:GetAttribute(bType .. "_Prog") or 0) >= (player:GetAttribute(bType .. "_Max") or 1) then
		player:SetAttribute(claimedAttr, true)
		vpEvent:Fire(player, 25)

		local hasBuff = winVal.Value ~= "None" and player:GetAttribute("Regiment") == winVal.Value

		if string.sub(bType, 1, 1) == "D" then
			local reward = player:GetAttribute(bType .. "_Reward") or 500
			if hasBuff then reward = math.floor(reward * 1.15) end
			player.leaderstats.Dews.Value += reward
		else
			local rType = player:GetAttribute(bType .. "_RewardType")
			local safeName = rType:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + (player:GetAttribute(bType .. "_RewardAmt") or 1))
		end
	end
end)

RemotesFolder.JoinRegiment.OnServerEvent:Connect(function(player, regName)
	local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
	if currentReg ~= "Cadet Corps" and currentReg ~= regName then
		if player.leaderstats.Dews.Value >= 50000 then
			player.leaderstats.Dews.Value -= 50000
		else
			RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews! Need 50,000 to swap.", "Error")
			return
		end
	end

	player:SetAttribute("Regiment", regName)
	RemotesFolder.NotificationEvent:FireClient(player, "You have pledged your life to the " .. regName .. "!", "Success")
end)

pcall(function()
	MessagingService:SubscribeAsync("GlobalDataRollback", function(message)
		for _, p in ipairs(Players:GetPlayers()) do
			local success, backup = pcall(function() return BackupDataStore:GetAsync("Backup_" .. p.UserId) end)
			if success and backup then
				pcall(function() GameDataStore:SetAsync(p.UserId, backup) end)
				p:Kick("SYSTEM ALARM: A Global Data Rollback has been initiated by Administrators. Your previous safe save has been restored. Please rejoin.")
			end
		end
	end)
end)

RemotesFolder.AdminCommand.OnServerEvent:Connect(function(player, command, targetName, args)
	if player.UserId ~= 4068160397 and player.Name ~= "girthbender1209" then player:Kick("Unauthorized Admin Access"); return end

	if command == "GlobalRollback" then
		pcall(function() MessagingService:PublishAsync("GlobalDataRollback", "Initiate") end)
		RemotesFolder.NotificationEvent:FireClient(player, "GLOBAL ROLLBACK INITIATED ACROSS ALL SERVERS.", "Success")
		return
	end

	if command == "GenerateRecovery" then
		local targetId = tonumber(targetName)
		if not targetId then for _, p in ipairs(Players:GetPlayers()) do if string.find(p.Name:lower(), "^" .. targetName:lower()) then targetId = p.UserId; break end end end
		if targetId then
			local success, backupData = pcall(function() return BackupDataStore:GetAsync("Backup_" .. targetId) end)
			if success and backupData then
				local code = "AOT-" .. string.upper(string.sub(HttpService:GenerateGUID(false), 1, 6)); pcall(function() BackupDataStore:SetAsync(code, backupData) end)
				RemotesFolder.NotificationEvent:FireClient(player, "Code for " .. targetId .. ": " .. code, "Success")
			else RemotesFolder.NotificationEvent:FireClient(player, "No auto-backup found for ID: " .. targetId, "Error") end
		else RemotesFolder.NotificationEvent:FireClient(player, "Player not found. Type their exact UserID.", "Error") end
		return
	end

	local targetPlayer = player
	if targetName and targetName ~= "" and targetName:lower() ~= "me" then targetPlayer = nil; for _, p in ipairs(Players:GetPlayers()) do if string.find(p.Name:lower(), "^" .. targetName:lower()) then targetPlayer = p; break end end end
	if not targetPlayer then return end

	if command == "SetXP" then targetPlayer:SetAttribute("XP", tonumber(args) or 0)
	elseif command == "SetDews" then targetPlayer.leaderstats.Dews.Value = tonumber(args) or 0
	elseif command == "UnlockAllParts" then targetPlayer:SetAttribute("CurrentPart", 8); targetPlayer:SetAttribute("CurrentWave", 1)
	elseif command == "GiveItem" then local safeName = args.Item:gsub("[^%w]", "") .. "Count"; targetPlayer:SetAttribute(safeName, (targetPlayer:GetAttribute(safeName) or 0) + (tonumber(args.Amount) or 1))
	elseif command == "MaxPrestige" then 
		targetPlayer.leaderstats.Prestige.Value = 10
		task.spawn(function() PrestigeLB:SetAsync(tostring(targetPlayer.UserId), 10) end) 
	elseif command == "SetTitan" then targetPlayer:SetAttribute("Titan", tostring(args))
	elseif command == "SetClan" then targetPlayer:SetAttribute("Clan", tostring(args))
	elseif command == "SetTitle" then targetPlayer:SetAttribute("CustomTitle", tostring(args))
	elseif command == "MaxStats" then
		local GameDataInfo = require(ReplicatedStorage:WaitForChild("GameData"))
		local p = targetPlayer.leaderstats.Prestige.Value; local c = GameDataInfo.GetStatCap(p)
		local statsToMax = {"Health", "Strength", "Defense", "Speed", "Gas", "Resolve", "Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val"}
		for _, s in ipairs(statsToMax) do targetPlayer:SetAttribute(s, c) end
	elseif command == "WipePlayer" then
		targetPlayer.leaderstats.Prestige.Value = 0; targetPlayer.leaderstats.Dews.Value = 0; targetPlayer.leaderstats.Elo.Value = 1000

		local savedGamepasses = {}
		for k, v in pairs(targetPlayer:GetAttributes()) do
			if string.match(k, "^Has") then
				savedGamepasses[k] = v
			end
		end

		for k, _ in pairs(targetPlayer:GetAttributes()) do targetPlayer:SetAttribute(k, nil) end
		for k, v in pairs(DefaultData) do if k ~= "Prestige" and k ~= "Dews" and k ~= "Elo" then targetPlayer:SetAttribute(k, v) end end
		for k, v in pairs(savedGamepasses) do targetPlayer:SetAttribute(k, v) end

		task.spawn(function() 
			PrestigeLB:SetAsync(tostring(targetPlayer.UserId), 0)
			EloLB:SetAsync(tostring(targetPlayer.UserId), 1000)
		end)
	end
end)

-- [[ THE FIX: Forces bounties to load properly even if attributes were wiped ]]
local function RollBounties(player)
	local now = os.time(); local currentDay = math.floor(now / 86400); local currentWeek = math.floor(now / 604800)

	if player:GetAttribute("LastDailyReset") ~= currentDay or player:GetAttribute("D1_Desc") == nil then
		player:SetAttribute("LastDailyReset", currentDay)
		local available = {}
		for _, v in ipairs(BountyData.Dailies) do table.insert(available, v) end
		for i = 1, 3 do 
			if #available == 0 then break end 
			local idx = math.random(1, #available); local b = available[idx]; table.remove(available, idx)
			local target = math.random(b.Min, b.Max)
			player:SetAttribute("D"..i.."_Task", b.Task)
			player:SetAttribute("D"..i.."_Desc", string.format(b.Desc, target))
			player:SetAttribute("D"..i.."_Prog", 0)
			player:SetAttribute("D"..i.."_Max", target)
			player:SetAttribute("D"..i.."_Reward", b.Reward)
			player:SetAttribute("D"..i.."_Claimed", false) 
		end
	end

	if player:GetAttribute("LastWeeklyReset") ~= currentWeek or player:GetAttribute("W1_Desc") == nil then
		player:SetAttribute("LastWeeklyReset", currentWeek)
		local b = BountyData.Weeklies[math.random(1, #BountyData.Weeklies)]
		local target = math.random(b.Min, b.Max)
		player:SetAttribute("W1_Task", b.Task)
		player:SetAttribute("W1_Desc", string.format(b.Desc, target))
		player:SetAttribute("W1_Prog", 0)
		player:SetAttribute("W1_Max", target)
		player:SetAttribute("W1_RewardType", b.RewardType)
		player:SetAttribute("W1_RewardAmt", b.RewardAmt)
		player:SetAttribute("W1_Claimed", false)
	end
end

local function LoadPlayer(player)
	local success, savedData = pcall(function() return GameDataStore:GetAsync(player.UserId) end)

	if not success then
		player:Kick("Roblox DataStores are currently experiencing issues. Please rejoin to protect your save data.")
		return
	end

	if savedData then
		pcall(function() BackupDataStore:SetAsync("Backup_" .. player.UserId, savedData) end)
	end

	local data = savedData or DefaultData

	for _, gp in ipairs(ItemData.Gamepasses) do 
		local hasPass = false
		pcall(function() hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.ID) end)
		if player.UserId == 4068160397 then hasPass = true end
		player:SetAttribute("Has" .. gp.Key, hasPass) 
	end

	local leaderstats = Instance.new("Folder"); leaderstats.Name = "leaderstats"; leaderstats.Parent = player
	local pVal = Instance.new("IntValue"); pVal.Name = "Prestige"; pVal.Value = data.Prestige or 0; pVal.Parent = leaderstats
	local dVal = Instance.new("IntValue"); dVal.Name = "Dews"; dVal.Value = data.Dews or 0; dVal.Parent = leaderstats
	local eVal = Instance.new("IntValue"); eVal.Name = "Elo"; eVal.Value = data.Elo or 1000; eVal.Parent = leaderstats

	for k, v in pairs(DefaultData) do if k ~= "Prestige" and k ~= "Dews" and k ~= "Elo" then player:SetAttribute(k, data[k] or v) end end
	for k, v in pairs(data) do if DefaultData[k] == nil and k ~= "Prestige" and k ~= "Dews" and k ~= "Elo" then player:SetAttribute(k, v) end end

	if CurrentVP.Winner ~= "None" and player:GetAttribute("Regiment") == CurrentVP.Winner and player:GetAttribute("RewardClaimedWeek") ~= CurrentVP.Week then
		player:SetAttribute("RewardClaimedWeek", CurrentVP.Week); player:SetAttribute("TitanHardeningExtractCount", (player:GetAttribute("TitanHardeningExtractCount") or 0) + 2); player:SetAttribute("AncestralAwakeningSerumCount", (player:GetAttribute("AncestralAwakeningSerumCount") or 0) + 1)
		task.delay(3, function() RemotesFolder.NotificationEvent:FireClient(player, "Your Regiment won the war! Received Forge Chest!", "Success") end)
	end

	local LoginData = require(ReplicatedStorage:WaitForChild("LoginData"))

	local now = os.time()
	local dateDict = os.date("!*t", now)
	local todayStr = dateDict.year .. "-" .. dateDict.month .. "-" .. dateDict.day
	local lastLogin = player:GetAttribute("LastLoginDate") or ""

	if lastLogin ~= todayStr then
		local streak = player:GetAttribute("LoginStreak") or 0
		local yesterdayTime = now - 86400
		local yDict = os.date("!*t", yesterdayTime)
		local yesterdayStr = yDict.year .. "-" .. yDict.month .. "-" .. yDict.day

		if lastLogin == yesterdayStr then
			streak += 1
		else
			streak = 1 
		end
		if streak > 7 then streak = 1 end

		player:SetAttribute("LoginStreak", streak)
		player:SetAttribute("LastLoginDate", todayStr)

		local rewardData = LoginData[streak]
		if rewardData then
			if rewardData.Type == "Dews" then
				dVal.Value += rewardData.Amount
			elseif rewardData.Type == "Item" then
				local safeName = rewardData.Name:gsub("[^%w]", "") .. "Count"
				player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + rewardData.Amount)
			end

			task.delay(5, function()
				local rewardName = rewardData.Name or "Dews"
				RemotesFolder.NotificationEvent:FireClient(player, "Day " .. streak .. " Login Reward: " .. rewardData.Amount .. "x " .. rewardName, "Success")
			end)
		end
	end

	RollBounties(player)
	player:SetAttribute("DataLoaded", true)

	pcall(function() PrestigeLB:SetAsync(tostring(player.UserId), pVal.Value) end)
	pcall(function() EloLB:SetAsync(tostring(player.UserId), eVal.Value) end)
end

Players.PlayerAdded:Connect(LoadPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(function() LoadPlayer(p) end) end

local function SavePlayer(p)
	if not p:GetAttribute("DataLoaded") then return end
	if not p:FindFirstChild("leaderstats") then return end

	local d = { Prestige = p.leaderstats.Prestige.Value, Dews = p.leaderstats.Dews.Value, Elo = p.leaderstats.Elo.Value }
	for k, v in pairs(p:GetAttributes()) do 
		if k ~= "DataLoaded" then d[k] = v end 
	end

	pcall(function() GameDataStore:SetAsync(p.UserId, d) end)

	pcall(function() PrestigeLB:SetAsync(tostring(p.UserId), p.leaderstats.Prestige.Value) end)
	pcall(function() EloLB:SetAsync(tostring(p.UserId), p.leaderstats.Elo.Value) end)
end

Players.PlayerRemoving:Connect(SavePlayer)

task.spawn(function() 
	while true do 
		task.wait(120) 
		for _, p in ipairs(Players:GetPlayers()) do SavePlayer(p) end 
	end 
end)

game:BindToClose(function() 
	for _, p in ipairs(Players:GetPlayers()) do SavePlayer(p) end 
	task.wait(3) 
end)