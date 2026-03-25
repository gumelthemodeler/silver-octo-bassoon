-- @ScriptType: Script
-- @ScriptType: Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local RemotesFolder = ReplicatedStorage:WaitForChild("Network")

local function GetDispatchData(player)
	local raw = player:GetAttribute("DispatchData")
	if not raw or raw == "" then return {} end
	local success, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return success and decoded or {}
end

local function SaveDispatchData(player, dataTable)
	local success, encoded = pcall(function() return HttpService:JSONEncode(dataTable) end)
	if success then player:SetAttribute("DispatchData", encoded) end
end

local function GetAllyLevels(player)
	local raw = player:GetAttribute("AllyLevels")
	if not raw or raw == "" then return {} end
	local success, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return success and decoded or {}
end

local function SaveAllyLevels(player, dataTable)
	local success, encoded = pcall(function() return HttpService:JSONEncode(dataTable) end)
	if success then player:SetAttribute("AllyLevels", encoded) end
end

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

RemotesFolder:WaitForChild("DispatchAction").OnServerEvent:Connect(function(player, action, allyName)
	local dData = GetDispatchData(player)
	local allyLevels = GetAllyLevels(player)
	local maxDeployments = player:GetAttribute("MaxDeployments") or 2

	if action == "UnlockAlly" then
		-- [[ THE FIX: Unlock Costs ]]
		local AllyCosts = {
			["Armin Arlert"] = 1000, ["Sasha Braus"] = 2500, ["Connie Springer"] = 2500,
			["Jean Kirstein"] = 5000, ["Hange Zoe"] = 10000, ["Erwin Smith"] = 20000,
			["Mikasa Ackerman"] = 50000, ["Levi Ackerman"] = 100000
		}

		local cost = AllyCosts[allyName]
		if not cost then return end

		local unlocked = player:GetAttribute("UnlockedAllies") or ""
		if string.find(unlocked, "%[" .. allyName .. "%]") then return end

		if player.leaderstats.Dews.Value >= cost then
			player.leaderstats.Dews.Value -= cost
			player:SetAttribute("UnlockedAllies", unlocked .. "[" .. allyName .. "]")
			RemotesFolder.NotificationEvent:FireClient(player, "Successfully recruited " .. allyName .. "!", "Success")
		else
			RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews to recruit!", "Error")
		end

	elseif action == "Deploy" then
		if dData[allyName] then return end

		local currentActive = 0
		for _, _ in pairs(dData) do currentActive += 1 end
		if currentActive >= maxDeployments then
			RemotesFolder.NotificationEvent:FireClient(player, "Deployment capacity reached! Upgrade slots to send more.", "Error")
			return
		end

		dData[allyName] = { StartTime = os.time() }
		SaveDispatchData(player, dData)
		RemotesFolder.NotificationEvent:FireClient(player, allyName .. " dispatched for expedition!", "Success")

	elseif action == "Recall" then
		local info = dData[allyName]
		if not info then return end

		local elapsedMins = math.floor((os.time() - info.StartTime) / 60)
		if elapsedMins < 1 then
			RemotesFolder.NotificationEvent:FireClient(player, allyName .. " returned empty-handed.", "Error")
			dData[allyName] = nil; SaveDispatchData(player, dData); return
		end

		local lvl = allyLevels[allyName] or 1
		local lvlMultiplier = 1 + ((lvl - 1) * 0.20) 

		local dewsGained = math.floor((elapsedMins * 12) * lvlMultiplier)
		local xpGained = math.floor((elapsedMins * 5) * lvlMultiplier)

		local winReg = RemotesFolder:FindFirstChild("WinningRegiment")
		if winReg and winReg.Value ~= "None" and player:GetAttribute("Regiment") == winReg.Value then
			dewsGained = math.floor(dewsGained * 1.15)
			xpGained = math.floor(xpGained * 1.15)
		end

		local rolls = math.floor(elapsedMins / 30)
		local itemsFound = {}

		for i = 1, rolls do
			local rng = math.random(1, 100)
			if rng <= 10 then table.insert(itemsFound, "Standard Titan Serum")
			elseif rng <= 30 then table.insert(itemsFound, "Garrison Supply Crate")
			elseif rng <= 50 then table.insert(itemsFound, "Worn Trainee Badge")
			end
		end

		player.leaderstats.Dews.Value += dewsGained
		player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + xpGained)
		UpdateBountyProgress(player, "Dispatch", 1)

		local dropLog = "Collected: " .. dewsGained .. " Dews, " .. xpGained .. " XP."
		for _, item in ipairs(itemsFound) do
			local safeName = item:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + 1)
			dropLog = dropLog .. "\nFound: " .. item
		end

		dData[allyName] = nil; SaveDispatchData(player, dData)
		RemotesFolder.NotificationEvent:FireClient(player, allyName .. " returned!\n" .. dropLog, "Success")

	elseif action == "UpgradeAlly" then
		local lvl = allyLevels[allyName] or 1
		if lvl >= 10 then
			RemotesFolder.NotificationEvent:FireClient(player, allyName .. " is already MAX Level!", "Error")
			return
		end

		local cost = 5000 * lvl
		if player.leaderstats.Dews.Value >= cost then
			player.leaderstats.Dews.Value -= cost
			allyLevels[allyName] = lvl + 1
			SaveAllyLevels(player, allyLevels)
			RemotesFolder.NotificationEvent:FireClient(player, allyName .. " upgraded to Level " .. (lvl + 1) .. "!", "Success")
		else
			RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews to upgrade ally! (" .. cost .. " required)", "Error")
		end

	elseif action == "UpgradeCapacity" then
		if maxDeployments >= 8 then
			RemotesFolder.NotificationEvent:FireClient(player, "You have reached the maximum deployment capacity!", "Error")
			return
		end

		local cost = 100000 -- [[ THE FIX: Flat 100k Cost per slot ]]
		if player.leaderstats.Dews.Value >= cost then
			player.leaderstats.Dews.Value -= cost
			player:SetAttribute("MaxDeployments", maxDeployments + 1)
			RemotesFolder.NotificationEvent:FireClient(player, "Deployment capacity increased to " .. (maxDeployments + 1) .. "!", "Success")
		else
			RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews! Needs 100,000.", "Error")
		end
	end
end)