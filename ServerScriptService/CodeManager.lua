-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local GameDataStore = DataStoreService:GetDataStore("AoT_Data_V3") 
local BackupDataStore = DataStoreService:GetDataStore("AoT_Backups_V1") 

local RemotesFolder = ReplicatedStorage:WaitForChild("Network")

-- =====================================================================
-- [[ PROMO CODE GUIDE ]]
-- To create a code, use the exact format below. You can include or 
-- remove any parameter you want (e.g., just Dews, or just Items).
--
-- ["YOUR_CODE_HERE"] = {
--      Dews = 50000,
--      XP = 1000,
--      TitanXP = 500,
--      Items = {
--          ["Standard Titan Serum"] = 5,
--          ["Worn Trainee Badge"] = 10
--      }
-- }
-- =====================================================================

local ActiveCodes = { 
	["RELEASE"] = { 
		Dews = 5000,
		XP = 500,
		Items = {
			["Standard Titan Serum"] = 30,
			["Clan Blood Vial"] = 25 
		}
		
	}, 
	["SORRYFORBUGS"] = { 
		Dews = 10000, 
		Items = {
			["Spinal Fluid Syringe"] = 1,
			["Clan Blood Vial"] = 3
		}
	}, 
	["TITAN"] = { 
		TitanXP = 1000,
		Items = {
			["Standard Titan Serum"] = 3 
		}
	} 
}

RemotesFolder:WaitForChild("RedeemCode").OnServerEvent:Connect(function(player, codeStr)
	local codeKey = string.upper(codeStr)

	-- 1. Check if it's an Admin Data Recovery Code
	if string.sub(codeKey, 1, 4) == "AOT-" then
		local success, backupData = pcall(function() return BackupDataStore:GetAsync(codeKey) end)
		if success and backupData then 
			pcall(function() GameDataStore:SetAsync(player.UserId, backupData) end)
			player:Kick("Data Backup Restored! Please reconnect to the game.") 
		else 
			RemotesFolder.NotificationEvent:FireClient(player, "Invalid or Expired Backup Code.", "Error") 
		end
		return
	end

	-- 2. Standard Promo Code Validation
	local codeData = ActiveCodes[codeKey]
	if not codeData then 
		RemotesFolder.NotificationEvent:FireClient(player, "Invalid Code.", "Error")
		return 
	end

	local redeemedStr = player:GetAttribute("RedeemedCodes") or ""
	if string.find(redeemedStr, "%[" .. codeKey .. "%]") then 
		RemotesFolder.NotificationEvent:FireClient(player, "Code already redeemed.", "Error")
		return 
	end 

	-- 3. Grant Complex Rewards
	player:SetAttribute("RedeemedCodes", redeemedStr .. "[" .. codeKey .. "]")

	if codeData.Dews then player.leaderstats.Dews.Value += codeData.Dews end
	if codeData.XP then player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + codeData.XP) end
	if codeData.TitanXP then player:SetAttribute("TitanXP", (player:GetAttribute("TitanXP") or 0) + codeData.TitanXP) end

	if codeData.Items then
		for itemName, amount in pairs(codeData.Items) do
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + amount) 
		end
	end

	RemotesFolder.NotificationEvent:FireClient(player, "Code Redeemed!", "Success")
end)