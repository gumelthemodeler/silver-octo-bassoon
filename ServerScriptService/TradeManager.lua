-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemotesFolder = ReplicatedStorage:WaitForChild("Network")

local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

local ActiveTrades = {} -- [TradeID] = {P1 = player, P2 = player, P1Offer = {Dews=0, Items={}}, P2Offer = {Dews=0, Items={}}, P1Ready=false, P2Ready=false, P1Confirm=false, P2Confirm=false}
local TradeRequests = {} -- [TargetId] = {RequesterId1, RequesterId2}

local function CancelTrade(tradeId, reason)
	local trade = ActiveTrades[tradeId]
	if not trade then return end

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
		if plr.leaderstats.Dews.Value < offer.Dews then return false end
		for itemName, amount in pairs(offer.Items) do
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			if (plr:GetAttribute(safeName) or 0) < amount then return false end
		end
		return true
	end

	if not ValidateOffer(trade.P1, trade.P1Offer) or not ValidateOffer(trade.P2, trade.P2Offer) then
		CancelTrade(tradeId, "A player no longer has the required items.")
		return
	end

	-- [[ THE FIX: Check Inventory Caps based on net item flow ]]
	local p1NetItems = 0; local p2NetItems = 0
	for _, amt in pairs(trade.P2Offer.Items) do p1NetItems += amt end
	for _, amt in pairs(trade.P1Offer.Items) do p1NetItems -= amt end
	for _, amt in pairs(trade.P1Offer.Items) do p2NetItems += amt end
	for _, amt in pairs(trade.P2Offer.Items) do p2NetItems -= amt end

	if p1NetItems > 0 and (GameData.GetInventoryCount(trade.P1) + p1NetItems) > GameData.GetMaxInventory(trade.P1) then
		CancelTrade(tradeId, trade.P1.Name .. "'s inventory is full!")
		return
	end
	if p2NetItems > 0 and (GameData.GetInventoryCount(trade.P2) + p2NetItems) > GameData.GetMaxInventory(trade.P2) then
		CancelTrade(tradeId, trade.P2.Name .. "'s inventory is full!")
		return
	end

	-- Deduct Offers
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

	-- Grant Loot
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
		if not target then return end

		if TradeRequests[player.UserId] and TradeRequests[player.UserId][target.UserId] then
			TradeRequests[player.UserId][target.UserId] = nil
			if GetTradeForPlayer(player) or GetTradeForPlayer(target) then return end

			local newTradeId = HttpService:GenerateGUID(false)
			ActiveTrades[newTradeId] = {
				P1 = player, P2 = target, 
				P1Offer = {Dews = 0, Items = {}}, P2Offer = {Dews = 0, Items = {}}, 
				P1Ready = false, P2Ready = false, P1Confirm = false, P2Confirm = false
			}
			SyncTradeUI(ActiveTrades[newTradeId])
		end

	elseif action == "DeclineRequest" then
		local target = Players:FindFirstChild(data)
		if target and TradeRequests[player.UserId] then TradeRequests[player.UserId][target.UserId] = nil end

	elseif trade then
		local isP1 = (trade.P1 == player)
		local myOffer = isP1 and trade.P1Offer or trade.P2Offer

		if action == "Cancel" then
			CancelTrade(tradeId, player.Name .. " cancelled the trade.")

		elseif action == "UpdateDews" and not (isP1 and trade.P1Ready or not isP1 and trade.P2Ready) then
			local amt = math.clamp(tonumber(data) or 0, 0, player.leaderstats.Dews.Value)
			myOffer.Dews = amt
			trade.P1Ready = false; trade.P2Ready = false
			SyncTradeUI(trade)

		elseif action == "AddItem" and not (isP1 and trade.P1Ready or not isP1 and trade.P2Ready) then
			local itemName = data.Item
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			local owned = player:GetAttribute(safeName) or 0
			local currentlyOffered = myOffer.Items[itemName] or 0

			if currentlyOffered < owned then
				myOffer.Items[itemName] = currentlyOffered + 1
				trade.P1Ready = false; trade.P2Ready = false
				SyncTradeUI(trade)
			end

		elseif action == "RemoveItem" and not (isP1 and trade.P1Ready or not isP1 and trade.P2Ready) then
			local itemName = data.Item
			if myOffer.Items[itemName] and myOffer.Items[itemName] > 0 then
				myOffer.Items[itemName] -= 1
				if myOffer.Items[itemName] <= 0 then myOffer.Items[itemName] = nil end
				trade.P1Ready = false; trade.P2Ready = false
				SyncTradeUI(trade)
			end

		elseif action == "ToggleReady" then
			if isP1 then trade.P1Ready = not trade.P1Ready else trade.P2Ready = not trade.P2Ready end
			SyncTradeUI(trade)

		elseif action == "Confirm" then
			if not trade.P1Ready or not trade.P2Ready then return end
			if isP1 then trade.P1Confirm = true else trade.P2Confirm = true end
			SyncTradeUI(trade)
			if trade.P1Confirm and trade.P2Confirm then ExecuteTrade(tradeId) end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	local tid, trade = GetTradeForPlayer(plr)
	if tid then CancelTrade(tid, plr.Name .. " disconnected.") end
	TradeRequests[plr.UserId] = nil
end)