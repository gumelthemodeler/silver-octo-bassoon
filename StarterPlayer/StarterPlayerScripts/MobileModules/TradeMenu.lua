-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local TradeMenu = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local player = Players.LocalPlayer
local MainFrame
local HubPanel, ActiveTradePanel
local PlayerList, RequestsList
local MyOfferList, TheirOfferList, InventoryList
local MyDewsInput, MyReadyBtn, tTitle

local RarityColors = { Common = "#AAAAAA", Uncommon = "#55FF55", Rare = "#5555FF", Epic = "#AA00FF", Legendary = "#FFD700", Mythical = "#FF3333" }

function TradeMenu.Init(parentFrame)
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "TradeFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false
	MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local mainLayout = Instance.new("UIListLayout", MainFrame); mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.Padding = UDim.new(0, 15)

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 30); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 215, 100); Title.TextSize = 20; Title.Text = "TRADE HUB"; Title.LayoutOrder = 1

	-- [[ HUB PANEL (Vertical Stack) ]]
	HubPanel = Instance.new("Frame", MainFrame)
	HubPanel.Size = UDim2.new(1, 0, 0, 0); HubPanel.AutomaticSize = Enum.AutomaticSize.Y; HubPanel.BackgroundTransparency = 1; HubPanel.LayoutOrder = 2
	local hLayout = Instance.new("UIListLayout", HubPanel); hLayout.Padding = UDim.new(0, 15)

	local PlayersFrame = Instance.new("Frame", HubPanel)
	PlayersFrame.Size = UDim2.new(1, 0, 0, 200); PlayersFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Instance.new("UICorner", PlayersFrame).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", PlayersFrame).Color = Color3.fromRGB(60, 60, 70)
	local pTitle = Instance.new("TextLabel", PlayersFrame); pTitle.Size = UDim2.new(1, 0, 0, 30); pTitle.BackgroundTransparency = 1; pTitle.Font = Enum.Font.GothamBlack; pTitle.TextColor3 = Color3.new(1,1,1); pTitle.TextSize = 14; pTitle.Text = "SERVER PLAYERS"
	PlayerList = Instance.new("ScrollingFrame", PlayersFrame); PlayerList.Size = UDim2.new(1, -20, 1, -40); PlayerList.Position = UDim2.new(0, 10, 0, 35); PlayerList.BackgroundTransparency = 1; PlayerList.BorderSizePixel = 0; PlayerList.ScrollBarThickness = 2
	local plLayout = Instance.new("UIListLayout", PlayerList); plLayout.Padding = UDim.new(0, 8)

	local ReqFrame = Instance.new("Frame", HubPanel)
	ReqFrame.Size = UDim2.new(1, 0, 0, 150); ReqFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Instance.new("UICorner", ReqFrame).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", ReqFrame).Color = Color3.fromRGB(60, 60, 70)
	local rTitle = Instance.new("TextLabel", ReqFrame); rTitle.Size = UDim2.new(1, 0, 0, 30); rTitle.BackgroundTransparency = 1; rTitle.Font = Enum.Font.GothamBlack; rTitle.TextColor3 = Color3.fromRGB(150, 255, 150); rTitle.TextSize = 14; rTitle.Text = "INCOMING REQUESTS"
	RequestsList = Instance.new("ScrollingFrame", ReqFrame); RequestsList.Size = UDim2.new(1, -20, 1, -40); RequestsList.Position = UDim2.new(0, 10, 0, 35); RequestsList.BackgroundTransparency = 1; RequestsList.BorderSizePixel = 0; RequestsList.ScrollBarThickness = 2
	local rlLayout = Instance.new("UIListLayout", RequestsList); rlLayout.Padding = UDim.new(0, 8)

	-- [[ ACTIVE TRADE PANEL (Vertical Stack) ]]
	ActiveTradePanel = Instance.new("Frame", MainFrame)
	ActiveTradePanel.Size = UDim2.new(1, 0, 0, 0); ActiveTradePanel.AutomaticSize = Enum.AutomaticSize.Y; ActiveTradePanel.BackgroundTransparency = 1; ActiveTradePanel.Visible = false; ActiveTradePanel.LayoutOrder = 3
	local aLayout = Instance.new("UIListLayout", ActiveTradePanel); aLayout.Padding = UDim.new(0, 15)

	local MySide = Instance.new("Frame", ActiveTradePanel)
	MySide.Size = UDim2.new(1, 0, 0, 280); MySide.BackgroundColor3 = Color3.fromRGB(20, 25, 20); Instance.new("UICorner", MySide).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", MySide).Color = Color3.fromRGB(60, 100, 60)
	local mTitle = Instance.new("TextLabel", MySide); mTitle.Size = UDim2.new(1, 0, 0, 30); mTitle.BackgroundTransparency = 1; mTitle.Font = Enum.Font.GothamBlack; mTitle.TextColor3 = Color3.fromRGB(150, 255, 150); mTitle.TextSize = 14; mTitle.Text = "YOUR OFFER"

	MyDewsInput = Instance.new("TextBox", MySide)
	MyDewsInput.Size = UDim2.new(0.9, 0, 0, 30); MyDewsInput.Position = UDim2.new(0.05, 0, 0, 30); MyDewsInput.BackgroundColor3 = Color3.fromRGB(15, 15, 18); MyDewsInput.Font = Enum.Font.GothamBold; MyDewsInput.TextColor3 = Color3.fromRGB(150, 200, 255); MyDewsInput.TextSize = 12; MyDewsInput.PlaceholderText = "Dews to offer..."; Instance.new("UICorner", MyDewsInput).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", MyDewsInput).Color = Color3.fromRGB(60, 60, 70)

	MyOfferList = Instance.new("ScrollingFrame", MySide)
	MyOfferList.Size = UDim2.new(0.9, 0, 0, 80); MyOfferList.Position = UDim2.new(0.05, 0, 0, 70); MyOfferList.BackgroundColor3 = Color3.fromRGB(15, 15, 18); MyOfferList.BorderSizePixel = 0; MyOfferList.ScrollBarThickness = 2; Instance.new("UICorner", MyOfferList).CornerRadius = UDim.new(0, 6); local moLayout = Instance.new("UIListLayout", MyOfferList); moLayout.Padding = UDim.new(0, 5)

	local invTitle = Instance.new("TextLabel", MySide)
	invTitle.Size = UDim2.new(1, 0, 0, 20); invTitle.Position = UDim2.new(0, 0, 0, 160); invTitle.BackgroundTransparency = 1; invTitle.Font = Enum.Font.GothamBold; invTitle.TextColor3 = Color3.new(1,1,1); invTitle.TextSize = 11; invTitle.Text = "INVENTORY (TAP TO ADD)"

	InventoryList = Instance.new("ScrollingFrame", MySide)
	InventoryList.Size = UDim2.new(0.9, 0, 0, 80); InventoryList.Position = UDim2.new(0.05, 0, 0, 185); InventoryList.BackgroundColor3 = Color3.fromRGB(15, 15, 18); InventoryList.BorderSizePixel = 0; InventoryList.ScrollBarThickness = 2; Instance.new("UICorner", InventoryList).CornerRadius = UDim.new(0, 6); local ilLayout = Instance.new("UIListLayout", InventoryList); ilLayout.Padding = UDim.new(0, 5)

	local TheirSide = Instance.new("Frame", ActiveTradePanel)
	TheirSide.Size = UDim2.new(1, 0, 0, 150); TheirSide.BackgroundColor3 = Color3.fromRGB(25, 20, 20); Instance.new("UICorner", TheirSide).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", TheirSide).Color = Color3.fromRGB(100, 60, 60)
	tTitle = Instance.new("TextLabel", TheirSide); tTitle.Size = UDim2.new(1, 0, 0, 30); tTitle.BackgroundTransparency = 1; tTitle.Font = Enum.Font.GothamBlack; tTitle.TextColor3 = Color3.fromRGB(255, 150, 150); tTitle.TextSize = 14; tTitle.Text = "PARTNER's OFFER"

	TheirOfferList = Instance.new("ScrollingFrame", TheirSide)
	TheirOfferList.Size = UDim2.new(0.9, 0, 0, 100); TheirOfferList.Position = UDim2.new(0.05, 0, 0, 35); TheirOfferList.BackgroundColor3 = Color3.fromRGB(15, 15, 18); TheirOfferList.BorderSizePixel = 0; TheirOfferList.ScrollBarThickness = 2; Instance.new("UICorner", TheirOfferList).CornerRadius = UDim.new(0, 6); local toLayout = Instance.new("UIListLayout", TheirOfferList); toLayout.Padding = UDim.new(0, 5)

	local BtnControls = Instance.new("Frame", ActiveTradePanel)
	BtnControls.Size = UDim2.new(1, 0, 0, 45); BtnControls.BackgroundTransparency = 1
	local bcLayout = Instance.new("UIListLayout", BtnControls); bcLayout.FillDirection = Enum.FillDirection.Horizontal; bcLayout.Padding = UDim.new(0.05, 0)

	MyReadyBtn = Instance.new("TextButton", BtnControls)
	MyReadyBtn.Size = UDim2.new(0.475, 0, 1, 0); MyReadyBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 160); MyReadyBtn.Font = Enum.Font.GothamBlack; MyReadyBtn.TextColor3 = Color3.new(1,1,1); MyReadyBtn.TextSize = 12; MyReadyBtn.Text = "READY"; Instance.new("UICorner", MyReadyBtn).CornerRadius = UDim.new(0, 6)

	local CancelBtn = Instance.new("TextButton", BtnControls)
	CancelBtn.Size = UDim2.new(0.475, 0, 1, 0); CancelBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 60); CancelBtn.Font = Enum.Font.GothamBlack; CancelBtn.TextColor3 = Color3.new(1,1,1); CancelBtn.TextSize = 12; CancelBtn.Text = "CANCEL"; Instance.new("UICorner", CancelBtn).CornerRadius = UDim.new(0, 6)

	-- [[ Logic (Identical to PC, just adapted for mobile bounds) ]]
	local function PopulateHub()
		for _, child in ipairs(PlayerList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local row = Instance.new("Frame", PlayerList); row.Size = UDim2.new(1, 0, 0, 35); row.BackgroundColor3 = Color3.fromRGB(30, 30, 35); Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
				local nameLbl = Instance.new("TextLabel", row); nameLbl.Size = UDim2.new(0.6, 0, 1, 0); nameLbl.Position = UDim2.new(0, 10, 0, 0); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = Color3.new(1,1,1); nameLbl.TextSize = 12; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Text = p.Name
				local reqBtn = Instance.new("TextButton", row); reqBtn.Size = UDim2.new(0, 60, 0, 25); reqBtn.AnchorPoint = Vector2.new(1, 0.5); reqBtn.Position = UDim2.new(1, -5, 0.5, 0); reqBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 160); reqBtn.Font = Enum.Font.GothamBold; reqBtn.TextColor3 = Color3.new(1,1,1); reqBtn.TextSize = 10; reqBtn.Text = "INVITE"; Instance.new("UICorner", reqBtn).CornerRadius = UDim.new(0, 4)
				reqBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("SendRequest", p.Name); reqBtn.Text = "SENT"; task.wait(1); reqBtn.Text = "INVITE" end)
			end
		end
		task.delay(0.1, function() PlayerList.CanvasSize = UDim2.new(0,0,0,plLayout.AbsoluteContentSize.Y + 10) end)
	end

	Network:WaitForChild("TradeRequest").OnClientEvent:Connect(function(senderName)
		local row = Instance.new("Frame", RequestsList); row.Size = UDim2.new(1, 0, 0, 35); row.BackgroundColor3 = Color3.fromRGB(30, 40, 30); Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", row).Color = Color3.fromRGB(80, 150, 80)
		local nameLbl = Instance.new("TextLabel", row); nameLbl.Size = UDim2.new(0.5, 0, 1, 0); nameLbl.Position = UDim2.new(0, 10, 0, 0); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = Color3.new(1,1,1); nameLbl.TextSize = 12; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Text = senderName
		local accBtn = Instance.new("TextButton", row); accBtn.Size = UDim2.new(0, 60, 0, 25); accBtn.AnchorPoint = Vector2.new(1, 0.5); accBtn.Position = UDim2.new(1, -70, 0.5, 0); accBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60); accBtn.Font = Enum.Font.GothamBold; accBtn.TextColor3 = Color3.new(1,1,1); accBtn.TextSize = 10; accBtn.Text = "ACCEPT"; Instance.new("UICorner", accBtn).CornerRadius = UDim.new(0, 4)
		accBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("AcceptRequest", senderName); row:Destroy() end)
		local decBtn = Instance.new("TextButton", row); decBtn.Size = UDim2.new(0, 60, 0, 25); decBtn.AnchorPoint = Vector2.new(1, 0.5); decBtn.Position = UDim2.new(1, -5, 0.5, 0); decBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 60); decBtn.Font = Enum.Font.GothamBold; decBtn.TextColor3 = Color3.new(1,1,1); decBtn.TextSize = 10; decBtn.Text = "DECLINE"; Instance.new("UICorner", decBtn).CornerRadius = UDim.new(0, 4)
		decBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("DeclineRequest", senderName); row:Destroy() end)
		task.delay(0.1, function() RequestsList.CanvasSize = UDim2.new(0,0,0,rlLayout.AbsoluteContentSize.Y + 10) end)
	end)

	local function PopulateInventory(tradeData)
		for _, child in ipairs(InventoryList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		local isP1 = (tradeData.P1.Name == player.Name); local myOffer = isP1 and tradeData.P1Offer or tradeData.P2Offer
		local allItems = {}
		for k, _ in pairs(ItemData.Equipment) do table.insert(allItems, k) end
		for k, _ in pairs(ItemData.Consumables) do table.insert(allItems, k) end
		table.sort(allItems)

		for _, name in ipairs(allItems) do
			local safeName = name:gsub("[^%w]", "") .. "Count"; local owned = player:GetAttribute(safeName) or 0; local offered = myOffer.Items[name] or 0; local available = owned - offered
			if available > 0 then
				local rColor = RarityColors[(ItemData.Equipment[name] or ItemData.Consumables[name]).Rarity or "Common"]
				local row = Instance.new("TextButton", InventoryList); row.Size = UDim2.new(1, -10, 0, 30); row.BackgroundColor3 = Color3.fromRGB(25, 25, 30); row.Text = ""; Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", row).Color = Color3.fromHex(rColor:gsub("#",""))
				local lbl = Instance.new("TextLabel", row); lbl.Size = UDim2.new(1, -10, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamMedium; lbl.TextColor3 = Color3.new(1,1,1); lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.RichText = true
				lbl.Text = "<font color='" .. rColor .. "'>" .. name .. "</font> (x" .. available .. ")"
				row.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("AddItem", {Item = name}) end)
			end
		end
		task.delay(0.1, function() InventoryList.CanvasSize = UDim2.new(0,0,0,ilLayout.AbsoluteContentSize.Y + 10) end)
	end

	local function SyncTradeScreen(trade)
		HubPanel.Visible = false; ActiveTradePanel.Visible = true
		for _, child in ipairs(MyOfferList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		for _, child in ipairs(TheirOfferList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end

		local isP1 = (trade.P1.Name == player.Name)
		local myOffer = isP1 and trade.P1Offer or trade.P2Offer; local theirOffer = isP1 and trade.P2Offer or trade.P1Offer
		local myReady = isP1 and trade.P1Ready or trade.P2Ready; local theirReady = isP1 and trade.P2Ready or trade.P1Ready

		tTitle.Text = (isP1 and trade.P2.Name or trade.P1.Name) .. "'s OFFER"

		local function DrawOffer(list, offer, isMine)
			if offer.Dews > 0 then
				local row = Instance.new("Frame", list); row.Size = UDim2.new(1, -10, 0, 25); row.BackgroundColor3 = Color3.fromRGB(30, 40, 50); Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
				local lbl = Instance.new("TextLabel", row); lbl.Size = UDim2.new(1, -10, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(150, 200, 255); lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = offer.Dews .. " Dews"
			end
			for name, amt in pairs(offer.Items) do
				local rColor = RarityColors[(ItemData.Equipment[name] or ItemData.Consumables[name]).Rarity or "Common"]
				local row = Instance.new("TextButton", list); row.Size = UDim2.new(1, -10, 0, 25); row.BackgroundColor3 = Color3.fromRGB(25, 25, 30); row.Text = ""; Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
				local lbl = Instance.new("TextLabel", row); lbl.Size = UDim2.new(1, -10, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamMedium; lbl.TextColor3 = Color3.new(1,1,1); lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.RichText = true; lbl.Text = "<font color='" .. rColor .. "'>" .. name .. "</font> (x" .. amt .. ")"
				if isMine then row.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("RemoveItem", {Item = name}) end) end
			end
		end

		DrawOffer(MyOfferList, myOffer, true); DrawOffer(TheirOfferList, theirOffer, false); PopulateInventory(trade)
		task.delay(0.1, function() MyOfferList.CanvasSize = UDim2.new(0,0,0,moLayout.AbsoluteContentSize.Y+10); TheirOfferList.CanvasSize = UDim2.new(0,0,0,toLayout.AbsoluteContentSize.Y+10) end)

		if myReady and theirReady then MyReadyBtn.Text = "CONFIRM TRADE"; MyReadyBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
		elseif myReady then MyReadyBtn.Text = "WAITING..."; MyReadyBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 60)
		else MyReadyBtn.Text = "READY"; MyReadyBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 160) end

		if theirReady then tTitle.TextColor3 = Color3.fromRGB(150, 255, 150); tTitle.Text = tTitle.Text .. " (READY)" else tTitle.TextColor3 = Color3.fromRGB(255, 150, 150) end
	end

	Network:WaitForChild("TradeUpdate").OnClientEvent:Connect(function(action, data)
		if action == "Sync" then SyncTradeScreen(data)
		elseif action == "TradeCancelled" then ActiveTradePanel.Visible = false; HubPanel.Visible = true;
		elseif action == "TradeComplete" then ActiveTradePanel.Visible = false; HubPanel.Visible = true; end
	end)

	MyDewsInput.FocusLost:Connect(function() Network.TradeAction:FireServer("UpdateDews", MyDewsInput.Text); MyDewsInput.Text = "" end)
	MyReadyBtn.MouseButton1Click:Connect(function() if MyReadyBtn.Text == "CONFIRM TRADE" then Network.TradeAction:FireServer("Confirm") else Network.TradeAction:FireServer("ToggleReady") end end)
	CancelBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("Cancel") end)

	task.spawn(function() while true do task.wait(5) if MainFrame.Visible and HubPanel.Visible then PopulateHub() end end end)
	PopulateHub()
end

function TradeMenu.Show() if MainFrame then MainFrame.Visible = true end end

return TradeMenu