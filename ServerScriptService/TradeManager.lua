-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RemotesFolder = ReplicatedStorage:WaitForChild("Network")

local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local ActiveTrades = {} 
local TradeRequests = {} 

local MAX_INVENTORY_CAPACITY = 50

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

local function CancelTrade(tradeId, reason)
	local trade = ActiveTrades[tradeId]
	if not trade then return end
	trade.Version = (trade.Version or 0) + 1 

	if trade.P1 then RemotesFolder.TradeUpdate:FireClient(trade.P1, "TradeCancelled", reason) end
	if trade.P2 then RemotesFolder.TradeUpdate:FireClient(trade.P2, "TradeCancelled", reason) end
	ActiveTrades[tradeId] = nil
end

local function GetTradeForPlayer(player)
	for id, trade in pairs(ActiveTrades) do
		if trade.P1 == player or trade.P2 == player then return id, trade end
	end
	return nil, nil
end

local function SyncTradeUI(trade)
	if trade.P1 then RemotesFolder.TradeUpdate:FireClient(trade.P1, "Sync", trade) end
	if trade.P2 then RemotesFolder.TradeUpdate:FireClient(trade.P2, "Sync", trade) end
end

local function ExecuteTrade(tradeId)
	local trade = ActiveTrades[tradeId]
	if not trade then return end

	local function ValidateOffer(plr, offer)
		if plr.leaderstats.Dews.Value < offer.Dews then return false, "Not enough Dews." end
		for itemName, amount in pairs(offer.Items) do
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			if (plr:GetAttribute(safeName) or 0) < amount then return false, "Missing items." end

			if plr:GetAttribute("EquippedWeapon") == itemName or plr:GetAttribute("EquippedAccessory") == itemName then
				return false, "Cannot trade equipped items."
			end
		end
		return true, ""
	end

	local p1Valid, p1Err = ValidateOffer(trade.P1, trade.P1Offer)
	local p2Valid, p2Err = ValidateOffer(trade.P2, trade.P2Offer)

	if not p1Valid or not p2Valid then
		CancelTrade(tradeId, "Trade failed: " .. (p1Err ~= "" and p1Err or p2Err ~= "" and p2Err or "Invalid items."))
		return
	end

	local p1NewSlots = 0
	for itemName, _ in pairs(trade.P2Offer.Items) do
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		if (trade.P1:GetAttribute(safeName) or 0) == 0 then p1NewSlots += 1 end
	end

	local p2NewSlots = 0
	for itemName, _ in pairs(trade.P1Offer.Items) do
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		if (trade.P2:GetAttribute(safeName) or 0) == 0 then p2NewSlots += 1 end
	end

	if p1NewSlots > 0 and (GetUniqueSlotCount(trade.P1) + p1NewSlots) > MAX_INVENTORY_CAPACITY then
		CancelTrade(tradeId, trade.P1.Name .. "'s inventory is full!")
		return
	end
	if p2NewSlots > 0 and (GetUniqueSlotCount(trade.P2) + p2NewSlots) > MAX_INVENTORY_CAPACITY then
		CancelTrade(tradeId, trade.P2.Name .. "'s inventory is full!")
		return
	end

	trade.P1.leaderstats.Dews.Value -= trade.P1Offer.Dews
	for itemName, amount in pairs(trade.P1Offer.Items) do
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		trade.P1:SetAttribute(safeName, trade.P1:GetAttribute(safeName) - amount)
	end
	trade.P2.leaderstats.Dews.Value -= trade.P2Offer.Dews
	for itemName, amount in pairs(trade.P2Offer.Items) do
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		trade.P2:SetAttribute(safeName, trade.P2:GetAttribute(safeName) - amount)
	end

	trade.P1.leaderstats.Dews.Value += trade.P2Offer.Dews
	for itemName, amount in pairs(trade.P2Offer.Items) do
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		trade.P1:SetAttribute(safeName, (trade.P1:GetAttribute(safeName) or 0) + amount)
	end
	trade.P2.leaderstats.Dews.Value += trade.P1Offer.Dews
	for itemName, amount in pairs(trade.P1Offer.Items) do
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		trade.P2:SetAttribute(safeName, (trade.P2:GetAttribute(safeName) or 0) + amount)
	end

	RemotesFolder.TradeUpdate:FireClient(trade.P1, "TradeComplete")
	RemotesFolder.TradeUpdate:FireClient(trade.P2, "TradeComplete")
	ActiveTrades[tradeId] = nil
end

local function ResetTradeState(trade)
	trade.P1Ready = false
	trade.P2Ready = false
	trade.P1Confirmed = false
	trade.P2Confirmed = false
	trade.Countdown = -1
	trade.Version += 1
end

RemotesFolder:WaitForChild("TradeAction").OnServerEvent:Connect(function(player, action, data)
	local tradeId, trade = GetTradeForPlayer(player)

	if action == "SendRequest" then
		if trade then RemotesFolder.NotificationEvent:FireClient(player, "You are already in a trade!", "Error") return end
		local target = Players:FindFirstChild(data)
		if not target or target == player then return end
		if GetTradeForPlayer(target) then RemotesFolder.NotificationEvent:FireClient(player, "That player is busy.", "Error") return end

		if not TradeRequests[target.UserId] then TradeRequests[target.UserId] = {} end
		TradeRequests[target.UserId][player.UserId] = true

		RemotesFolder.TradeRequest:FireClient(target, player.Name)
		RemotesFolder.NotificationEvent:FireClient(player, "Trade request sent to " .. target.Name, "Info")

	elseif action == "AcceptRequest" then
		local target = Players:FindFirstChild(data)
		if not target then 
			RemotesFolder.NotificationEvent:FireClient(player, "Player has left the game.", "Error")
			return 
		end

		if not TradeRequests[player.UserId] or not TradeRequests[player.UserId][target.UserId] then
			RemotesFolder.NotificationEvent:FireClient(player, "This trade request has expired.", "Error")
			return
		end

		TradeRequests[player.UserId][target.UserId] = nil

		if GetTradeForPlayer(player) or GetTradeForPlayer(target) then 
			RemotesFolder.NotificationEvent:FireClient(player, "One of the players is currently busy.", "Error")
			return 
		end

		RemotesFolder.NotificationEvent:FireClient(target, player.Name .. " accepted your trade request!", "Success")

		local newTradeId = HttpService:GenerateGUID(false)
		ActiveTrades[newTradeId] = {
			P1 = player, P2 = target, 
			P1Offer = {Dews = 0, Items = {}}, P2Offer = {Dews = 0, Items = {}}, 
			P1Ready = false, P2Ready = false, 
			P1Confirmed = false, P2Confirmed = false,
			Countdown = -1, Version = 1
		}

		RemotesFolder.TradeUpdate:FireClient(player, "Open", {OtherPlayer = target.Name})
		RemotesFolder.TradeUpdate:FireClient(target, "Open", {OtherPlayer = player.Name})

		task.delay(0.2, function()
			if ActiveTrades[newTradeId] then SyncTradeUI(ActiveTrades[newTradeId]) end
		end)

	elseif action == "DeclineRequest" then
		local target = Players:FindFirstChild(data)
		if target and TradeRequests[player.UserId] then 
			TradeRequests[player.UserId][target.UserId] = nil 
			RemotesFolder.NotificationEvent:FireClient(target, player.Name .. " declined your trade request.", "Error")
		end

	elseif trade then
		local isP1 = (trade.P1 == player)
		local myOffer = isP1 and trade.P1Offer or trade.P2Offer

		if action == "Cancel" then
			CancelTrade(tradeId, player.Name .. " cancelled the trade.")

		elseif action == "UpdateDews" then
			local amt = math.clamp(tonumber(data) or 0, 0, player.leaderstats.Dews.Value)
			myOffer.Dews = amt
			ResetTradeState(trade)
			SyncTradeUI(trade)

		elseif action == "AddItem" then
			-- [[ THE FIX: Extract item name properly depending on whether it was sent as an object or raw string ]]
			local itemName = type(data) == "table" and data.Item or data
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			local owned = player:GetAttribute(safeName) or 0
			local currentlyOffered = myOffer.Items[itemName] or 0

			if player:GetAttribute("EquippedWeapon") == itemName or player:GetAttribute("EquippedAccessory") == itemName then
				RemotesFolder.NotificationEvent:FireClient(player, "Cannot trade equipped items!", "Error")
				return
			end

			if currentlyOffered < owned then
				myOffer.Items[itemName] = currentlyOffered + 1
				ResetTradeState(trade)
				SyncTradeUI(trade)
			end

		elseif action == "RemoveItem" then
			-- [[ THE FIX: Safely parse item removal ]]
			local itemName = type(data) == "table" and data.Item or data
			if myOffer.Items[itemName] and myOffer.Items[itemName] > 0 then
				myOffer.Items[itemName] -= 1
				if myOffer.Items[itemName] <= 0 then myOffer.Items[itemName] = nil end
				ResetTradeState(trade)
				SyncTradeUI(trade)
			end

		elseif action == "ToggleReady" then
			if isP1 then trade.P1Ready = not trade.P1Ready else trade.P2Ready = not trade.P2Ready end

			if not trade.P1Ready then trade.P1Confirmed = false end
			if not trade.P2Ready then trade.P2Confirmed = false end

			trade.Version += 1
			trade.Countdown = -1
			SyncTradeUI(trade)

		elseif action == "ToggleConfirm" then
			if isP1 then trade.P1Confirmed = not trade.P1Confirmed else trade.P2Confirmed = not trade.P2Confirmed end
			trade.Version += 1

			if trade.P1Confirmed and trade.P2Confirmed then
				local currentVersion = trade.Version
				task.spawn(function()
					for i = 3, 1, -1 do
						if not ActiveTrades[tradeId] or trade.Version ~= currentVersion then return end
						trade.Countdown = i
						SyncTradeUI(trade)
						task.wait(1)
					end
					if ActiveTrades[tradeId] and trade.Version == currentVersion then
						ExecuteTrade(tradeId)
					end
				end)
			else
				trade.Countdown = -1
				SyncTradeUI(trade)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	local tid, trade = GetTradeForPlayer(plr)
	if tid then CancelTrade(tid, plr.Name .. " disconnected.") end
	TradeRequests[plr.UserId] = nil
end)