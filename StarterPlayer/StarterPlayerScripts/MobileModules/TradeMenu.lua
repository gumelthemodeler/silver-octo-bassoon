-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local TradeMenu = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local NotificationManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("NotificationManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local MainFrame, PlayerListFrame

local RarityColors = { ["Common"] = "#AAAAAA", ["Uncommon"] = "#55FF55", ["Rare"] = "#5588FF", ["Epic"] = "#CC44FF", ["Legendary"] = "#FFD700", ["Mythical"] = "#FF3333", ["Transcendent"] = "#FF55FF" }
local RarityOrder = { Transcendent = 0, Mythical = 1, Legendary = 2, Epic = 3, Rare = 4, Uncommon = 5, Common = 6 }

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
	grad.Rotation = 90
end

local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}; grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 4)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn)
		stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.LineJoinMode = Enum.LineJoinMode.Miter
	end
	if not btn:GetAttribute("GradientTextFixed") then
		btn:SetAttribute("GradientTextFixed", true)
		local textLbl = Instance.new("TextLabel", btn); textLbl.Name = "BtnTextLabel"; textLbl.Size = UDim2.new(1, 0, 1, 0); textLbl.BackgroundTransparency = 1
		textLbl.Font = btn.Font; textLbl.TextSize = btn.TextSize; textLbl.TextScaled = btn.TextScaled; textLbl.RichText = btn.RichText; textLbl.TextWrapped = btn.TextWrapped
		textLbl.TextXAlignment = btn.TextXAlignment; textLbl.TextYAlignment = btn.TextYAlignment; textLbl.ZIndex = btn.ZIndex + 1
		local tConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint"); if tConstraint then tConstraint.Parent = textLbl end
		btn.ChildAdded:Connect(function(child) if child:IsA("UITextSizeConstraint") then task.delay(0, function() child.Parent = textLbl end) end end)
		textLbl.Text = btn.Text; textLbl.TextColor3 = btn.TextColor3; btn.Text = ""
		btn:GetPropertyChangedSignal("Text"):Connect(function() if btn.Text ~= "" then textLbl.Text = btn.Text; btn.Text = "" end end)
		btn:GetPropertyChangedSignal("TextColor3"):Connect(function() textLbl.TextColor3 = btn.TextColor3 end)
	end
end

local function CreateItemCard(parent, itemName, count, isOfferCard, onClick)
	local itemInfo = ItemData.Equipment[itemName] or ItemData.Consumables[itemName]
	if not itemInfo then return nil end

	local card = Instance.new("TextButton", parent)
	card.Name = itemName; card.Size = UDim2.new(1, 0, 0, 35); card.BackgroundColor3 = Color3.fromRGB(25, 25, 30); card.Text = ""; card.ZIndex = 5005
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6); card.ClipsDescendants = true

	local rarityKey = itemInfo.Rarity or "Common"
	local safeNameBase = itemName:gsub("[^%w]", "")
	local awakenedStats = player:GetAttribute(safeNameBase .. "_Awakened")
	if awakenedStats then rarityKey = "Transcendent" end

	local cColor = RarityColors[rarityKey] or "#FFFFFF"; local rarityRGB = Color3.fromHex(cColor:gsub("#", ""))

	local cStroke = Instance.new("UIStroke", card); cStroke.Color = rarityRGB; cStroke.Thickness = 1; cStroke.Transparency = 0.55; cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local accentBar = Instance.new("Frame", card); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = rarityRGB; accentBar.BorderSizePixel = 0; accentBar.ZIndex = 5006
	local bgGlow = Instance.new("Frame", card); bgGlow.Size = UDim2.new(0.5, 0, 1, 0); bgGlow.BackgroundColor3 = rarityRGB; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 5006

	local nameLbl = Instance.new("TextLabel", card); nameLbl.Size = UDim2.new(1, -40, 1, 0); nameLbl.Position = UDim2.new(0, 10, 0, 0); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = Color3.fromRGB(235, 235, 235); nameLbl.TextSize = 10; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Text = itemName; nameLbl.ZIndex = 5007; nameLbl.TextScaled = true; Instance.new("UITextSizeConstraint", nameLbl).MaxTextSize = 10

	local countBadge = Instance.new("Frame", card); countBadge.Size = UDim2.new(0, 20, 0, 16); countBadge.AnchorPoint = Vector2.new(1, 0.5); countBadge.Position = UDim2.new(1, -5, 0.5, 0); countBadge.BackgroundColor3 = Color3.fromRGB(12, 12, 16); countBadge.BorderSizePixel = 0; countBadge.ZIndex = 5007; Instance.new("UICorner", countBadge).CornerRadius = UDim.new(0, 4)
	local countTag = Instance.new("TextLabel", countBadge); countTag.Size = UDim2.new(1, 0, 1, 0); countTag.BackgroundTransparency = 1; countTag.Font = Enum.Font.GothamBlack; countTag.TextColor3 = Color3.fromRGB(210, 210, 210); countTag.TextSize = 9; countTag.Text = "x" .. count; countTag.ZIndex = 5008

	if onClick then card.MouseButton1Click:Connect(function() onClick(itemName) end) end
	return card
end

function TradeMenu.Init(parentFrame)
	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "TradeMenuFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(150, 200, 255); Title.TextSize = 22; Title.Text = "SECURE TRADE HUB"
	ApplyGradient(Title, Color3.fromRGB(150, 200, 255), Color3.fromRGB(50, 150, 255))

	PlayerListFrame = Instance.new("ScrollingFrame", MainFrame)
	PlayerListFrame.Size = UDim2.new(0.95, 0, 1, -60); PlayerListFrame.Position = UDim2.new(0.025, 0, 0, 60); PlayerListFrame.BackgroundTransparency = 1; PlayerListFrame.ScrollBarThickness = 0; PlayerListFrame.BorderSizePixel = 0

	local plLayout = Instance.new("UIListLayout", PlayerListFrame)
	plLayout.Padding = UDim.new(0, 10); plLayout.SortOrder = Enum.SortOrder.Name; plLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local plPad = Instance.new("UIPadding", PlayerListFrame); plPad.PaddingTop = UDim.new(0, 5); plPad.PaddingBottom = UDim.new(0, 20)

	local function RefreshPlayers()
		for _, child in ipairs(PlayerListFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local row = Instance.new("Frame", PlayerListFrame)
				row.Name = p.Name; row.Size = UDim2.new(1, 0, 0, 75); row.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
				local stroke = Instance.new("UIStroke", row); stroke.Color = Color3.fromRGB(50, 50, 60); stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

				local accentBar = Instance.new("Frame", row); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(80, 140, 220); accentBar.BorderSizePixel = 0
				Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

				local avatar = Instance.new("ImageLabel", row)
				avatar.Size = UDim2.new(0, 50, 0, 50); avatar.Position = UDim2.new(0, 15, 0.5, 0); avatar.AnchorPoint = Vector2.new(0, 0.5); avatar.BackgroundColor3 = Color3.fromRGB(15, 15, 20); avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..p.UserId.."&w=150&h=150"
				Instance.new("UIStroke", avatar).Color = Color3.fromRGB(80, 140, 220); Instance.new("UIStroke", avatar).Thickness = 2; Instance.new("UIStroke", avatar).LineJoinMode = Enum.LineJoinMode.Miter

				local nLbl = Instance.new("TextLabel", row)
				nLbl.Size = UDim2.new(1, -190, 1, 0); nLbl.Position = UDim2.new(0, 80, 0, 0); nLbl.BackgroundTransparency = 1; nLbl.Font = Enum.Font.GothamBlack; nLbl.TextColor3 = Color3.fromRGB(230, 230, 240); nLbl.TextSize = 14; nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.Text = string.upper(p.Name)
				nLbl.TextScaled = true; Instance.new("UITextSizeConstraint", nLbl).MaxTextSize = 14

				local reqBtn = Instance.new("TextButton", row)
				reqBtn.Size = UDim2.new(0, 95, 0, 35); reqBtn.Position = UDim2.new(1, -10, 0.5, 0); reqBtn.AnchorPoint = Vector2.new(1, 0.5); reqBtn.Font = Enum.Font.GothamBlack; reqBtn.TextSize = 12; reqBtn.Text = "REQUEST"
				ApplyButtonGradient(reqBtn, Color3.fromRGB(20, 25, 35), Color3.fromRGB(10, 15, 25), Color3.fromRGB(80, 140, 220)); reqBtn.TextColor3 = Color3.fromRGB(150, 200, 255)

				reqBtn.MouseButton1Click:Connect(function()
					Network.TradeAction:FireServer("SendRequest", p.Name)
					reqBtn.Text = "SENT"; reqBtn.TextColor3 = Color3.fromRGB(150, 255, 150)
					ApplyButtonGradient(reqBtn, Color3.fromRGB(25, 35, 25), Color3.fromRGB(15, 20, 15), Color3.fromRGB(80, 180, 80))
					task.delay(3, function() 
						if reqBtn and reqBtn.Parent then
							reqBtn.Text = "REQUEST"; reqBtn.TextColor3 = Color3.fromRGB(150, 200, 255)
							ApplyButtonGradient(reqBtn, Color3.fromRGB(20, 25, 35), Color3.fromRGB(10, 15, 25), Color3.fromRGB(80, 140, 220)) 
						end
					end)
				end)
			end
		end
		task.delay(0.05, function() PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, math.ceil((#Players:GetPlayers() - 1) / 2) * 105 + 30) end)
	end

	MainFrame:GetPropertyChangedSignal("Visible"):Connect(function() if MainFrame.Visible then RefreshPlayers() end end)
	Players.PlayerAdded:Connect(function() if MainFrame.Visible then RefreshPlayers() end end)
	Players.PlayerRemoving:Connect(function() if MainFrame.Visible then RefreshPlayers() end end)

	local PopupsContainer = Instance.new("Frame", playerGui:WaitForChild("AOT_Interface"))
	PopupsContainer.Name = "TradePopups"; PopupsContainer.Size = UDim2.new(0, 250, 1, 0); PopupsContainer.Position = UDim2.new(1, -260, 0, 0); PopupsContainer.BackgroundTransparency = 1; PopupsContainer.ZIndex = 6000
	local pcLayout = Instance.new("UIListLayout", PopupsContainer); pcLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom; pcLayout.Padding = UDim.new(0, 10); pcLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local pcPad = Instance.new("UIPadding", PopupsContainer); pcPad.PaddingBottom = UDim.new(0, 20)

	Network.TradeRequest.OnClientEvent:Connect(function(requesterName)
		local popup = Instance.new("Frame", PopupsContainer)
		popup.Size = UDim2.new(1, 0, 0, 80); popup.BackgroundColor3 = Color3.fromRGB(25, 25, 30); popup.Position = UDim2.new(1, 350, 0, 0); popup.ZIndex = 6001
		Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", popup).Color = Color3.fromRGB(80, 140, 220); popup.UIStroke.Thickness = 2

		local tLbl = Instance.new("TextLabel", popup); tLbl.Size = UDim2.new(1, -20, 0, 30); tLbl.Position = UDim2.new(0, 10, 0, 5); tLbl.BackgroundTransparency = 1; tLbl.Font = Enum.Font.GothamBlack; tLbl.TextColor3 = Color3.fromRGB(255, 255, 255); tLbl.TextSize = 12; tLbl.Text = "Trade from " .. requesterName:upper(); tLbl.TextXAlignment = Enum.TextXAlignment.Left; tLbl.ZIndex = 6002

		local btnYes = Instance.new("TextButton", popup); btnYes.Size = UDim2.new(0.45, 0, 0, 30); btnYes.Position = UDim2.new(0.025, 0, 1, -35); btnYes.Font = Enum.Font.GothamBlack; btnYes.TextColor3 = Color3.fromRGB(255, 255, 255); btnYes.TextSize = 12; btnYes.Text = "ACCEPT"; btnYes.ZIndex = 6002
		ApplyButtonGradient(btnYes, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))
		local btnNo = Instance.new("TextButton", popup); btnNo.Size = UDim2.new(0.45, 0, 0, 30); btnNo.Position = UDim2.new(0.525, 0, 1, -35); btnNo.Font = Enum.Font.GothamBlack; btnNo.TextColor3 = Color3.fromRGB(255, 255, 255); btnNo.TextSize = 12; btnNo.Text = "DECLINE"; btnNo.ZIndex = 6002
		ApplyButtonGradient(btnNo, Color3.fromRGB(180, 80, 80), Color3.fromRGB(100, 40, 40), Color3.fromRGB(80, 20, 20))

		TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()

		btnYes.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("AcceptRequest", requesterName); popup:Destroy() end)
		btnNo.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("DeclineRequest", requesterName); popup:Destroy() end)
		task.delay(15, function() if popup and popup.Parent then TweenService:Create(popup, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play(); task.wait(0.3); popup:Destroy() end end)
	end)

	local TradeUIElements = {}
	local TradeScreenGui = playerGui:FindFirstChild("TradeScreenGui") or Instance.new("ScreenGui", playerGui)
	TradeScreenGui.Name = "TradeScreenGui"; TradeScreenGui.DisplayOrder = 9999; TradeScreenGui.ResetOnSpawn = false; TradeScreenGui.IgnoreGuiInset = true

	Network.TradeUpdate.OnClientEvent:Connect(function(action, data)
		if action == "Open" then
			TradeScreenGui:ClearAllChildren()

			local overlay = Instance.new("Frame", TradeScreenGui)
			overlay.Name = "TradeOverlay"; overlay.Size = UDim2.new(1, 0, 1, 0); overlay.BackgroundColor3 = Color3.new(0,0,0); overlay.BackgroundTransparency = 0.6; overlay.Active = true; overlay.ZIndex = 5000

			local mainPanel = Instance.new("Frame", overlay)
			mainPanel.Size = UDim2.new(0.96, 0, 0.9, 0); mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0); mainPanel.AnchorPoint = Vector2.new(0.5, 0.5); mainPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22); mainPanel.ZIndex = 5001
			Instance.new("UICorner", mainPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", mainPanel).Color = Color3.fromRGB(80, 140, 220); mainPanel.UIStroke.Thickness = 2

			local title = Instance.new("TextLabel", mainPanel)
			title.Size = UDim2.new(1, 0, 0, 40); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextColor3 = Color3.fromRGB(150, 200, 255); title.TextSize = 16; title.Text = "SECURE SESSION: " .. string.upper(data.OtherPlayer); title.ZIndex = 5002
			ApplyGradient(title, Color3.fromRGB(150, 200, 255), Color3.fromRGB(50, 150, 255))

			local sep = Instance.new("Frame", mainPanel)
			sep.Size = UDim2.new(0.96, 0, 0, 1); sep.Position = UDim2.new(0.02, 0, 0, 45); sep.BackgroundColor3 = Color3.fromRGB(80, 140, 220); sep.BackgroundTransparency = 0.5; sep.BorderSizePixel = 0; sep.ZIndex = 5002

			local OffersArea = Instance.new("Frame", mainPanel); OffersArea.Size = UDim2.new(1, -10, 0.45, 0); OffersArea.Position = UDim2.new(0, 5, 0, 50); OffersArea.BackgroundTransparency = 1; OffersArea.ZIndex = 5002
			local InvArea = Instance.new("Frame", mainPanel); InvArea.Size = UDim2.new(1, -10, 0.55, -105); InvArea.Position = UDim2.new(0, 5, 0.45, 55); InvArea.BackgroundColor3 = Color3.fromRGB(20, 20, 25); InvArea.ZIndex = 5002; Instance.new("UICorner", InvArea).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", InvArea).Color = Color3.fromRGB(60, 60, 70)

			TradeUIElements.Col2 = Instance.new("Frame", OffersArea); TradeUIElements.Col2.Size = UDim2.new(0.48, 0, 1, 0); TradeUIElements.Col2.Position = UDim2.new(0.01, 0, 0, 0); TradeUIElements.Col2.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TradeUIElements.Col2.ZIndex = 5003; Instance.new("UICorner", TradeUIElements.Col2).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", TradeUIElements.Col2).Color = Color3.fromRGB(60, 60, 70)
			TradeUIElements.Col3 = Instance.new("Frame", OffersArea); TradeUIElements.Col3.Size = UDim2.new(0.48, 0, 1, 0); TradeUIElements.Col3.Position = UDim2.new(0.51, 0, 0, 0); TradeUIElements.Col3.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TradeUIElements.Col3.ZIndex = 5003; Instance.new("UICorner", TradeUIElements.Col3).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", TradeUIElements.Col3).Color = Color3.fromRGB(60, 60, 70)

			local function MakeColHeader(parent, text, color)
				local lbl = Instance.new("TextLabel", parent); lbl.Size = UDim2.new(1, 0, 0, 25); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBlack; lbl.TextColor3 = color; lbl.TextSize = 12; lbl.Text = text; lbl.ZIndex = 5004; return lbl
			end
			MakeColHeader(InvArea, "YOUR INVENTORY", Color3.fromRGB(200, 200, 200))
			MakeColHeader(TradeUIElements.Col2, "YOUR OFFER", Color3.fromRGB(150, 255, 150))
			MakeColHeader(TradeUIElements.Col3, data.OtherPlayer:upper() .. "'S OFFER", Color3.fromRGB(255, 150, 150))

			TradeUIElements.MyInvList = Instance.new("ScrollingFrame", InvArea); TradeUIElements.MyInvList.Size = UDim2.new(1, -10, 1, -30); TradeUIElements.MyInvList.Position = UDim2.new(0, 5, 0, 25); TradeUIElements.MyInvList.BackgroundTransparency = 1; TradeUIElements.MyInvList.ScrollBarThickness = 2; TradeUIElements.MyInvList.BorderSizePixel = 0; TradeUIElements.MyInvList.ZIndex = 5004
			local l1 = Instance.new("UIListLayout", TradeUIElements.MyInvList); l1.Padding = UDim.new(0, 4); l1.HorizontalAlignment = Enum.HorizontalAlignment.Center

			TradeUIElements.MyOfferList = Instance.new("ScrollingFrame", TradeUIElements.Col2); TradeUIElements.MyOfferList.Size = UDim2.new(1, -10, 1, -65); TradeUIElements.MyOfferList.Position = UDim2.new(0, 5, 0, 25); TradeUIElements.MyOfferList.BackgroundTransparency = 1; TradeUIElements.MyOfferList.ScrollBarThickness = 2; TradeUIElements.MyOfferList.BorderSizePixel = 0; TradeUIElements.MyOfferList.ZIndex = 5004
			local l2 = Instance.new("UIListLayout", TradeUIElements.MyOfferList); l2.Padding = UDim.new(0, 4); l2.HorizontalAlignment = Enum.HorizontalAlignment.Center

			TradeUIElements.TheirOfferList = Instance.new("ScrollingFrame", TradeUIElements.Col3); TradeUIElements.TheirOfferList.Size = UDim2.new(1, -10, 1, -65); TradeUIElements.TheirOfferList.Position = UDim2.new(0, 5, 0, 25); TradeUIElements.TheirOfferList.BackgroundTransparency = 1; TradeUIElements.TheirOfferList.ScrollBarThickness = 2; TradeUIElements.TheirOfferList.BorderSizePixel = 0; TradeUIElements.TheirOfferList.ZIndex = 5004
			local l3 = Instance.new("UIListLayout", TradeUIElements.TheirOfferList); l3.Padding = UDim.new(0, 4); l3.HorizontalAlignment = Enum.HorizontalAlignment.Center

			local myDewsBg = Instance.new("Frame", TradeUIElements.Col2); myDewsBg.Size = UDim2.new(1, -10, 0, 30); myDewsBg.Position = UDim2.new(0, 5, 1, -35); myDewsBg.BackgroundColor3 = Color3.fromRGB(15, 15, 18); myDewsBg.ZIndex = 5004; Instance.new("UICorner", myDewsBg).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", myDewsBg).Color = Color3.fromRGB(80, 80, 90)
			local myDewsLbl = Instance.new("TextLabel", myDewsBg); myDewsLbl.Size = UDim2.new(0.4, 0, 1, 0); myDewsLbl.Position = UDim2.new(0, 5, 0, 0); myDewsLbl.BackgroundTransparency = 1; myDewsLbl.Font = Enum.Font.GothamBold; myDewsLbl.TextColor3 = Color3.fromRGB(180, 220, 255); myDewsLbl.TextSize = 10; myDewsLbl.TextXAlignment = Enum.TextXAlignment.Left; myDewsLbl.Text = "DEWS:"; myDewsLbl.ZIndex = 5005
			TradeUIElements.MyDewsBox = Instance.new("TextBox", myDewsBg); TradeUIElements.MyDewsBox.Size = UDim2.new(0.55, 0, 0.8, 0); TradeUIElements.MyDewsBox.Position = UDim2.new(0.4, 0, 0.1, 0); TradeUIElements.MyDewsBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35); TradeUIElements.MyDewsBox.Font = Enum.Font.GothamBold; TradeUIElements.MyDewsBox.TextColor3 = Color3.fromRGB(255, 255, 255); TradeUIElements.MyDewsBox.TextSize = 10; TradeUIElements.MyDewsBox.Text = "0"; TradeUIElements.MyDewsBox.ZIndex = 5005; Instance.new("UICorner", TradeUIElements.MyDewsBox).CornerRadius = UDim.new(0, 4)

			local theirDewsBg = Instance.new("Frame", TradeUIElements.Col3); theirDewsBg.Size = UDim2.new(1, -10, 0, 30); theirDewsBg.Position = UDim2.new(0, 5, 1, -35); theirDewsBg.BackgroundColor3 = Color3.fromRGB(15, 15, 18); theirDewsBg.ZIndex = 5004; Instance.new("UICorner", theirDewsBg).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", theirDewsBg).Color = Color3.fromRGB(80, 80, 90)
			local theirDewsLbl = Instance.new("TextLabel", theirDewsBg); theirDewsLbl.Size = UDim2.new(0.4, 0, 1, 0); theirDewsLbl.Position = UDim2.new(0, 5, 0, 0); theirDewsLbl.BackgroundTransparency = 1; theirDewsLbl.Font = Enum.Font.GothamBold; theirDewsLbl.TextColor3 = Color3.fromRGB(180, 220, 255); theirDewsLbl.TextSize = 10; theirDewsLbl.TextXAlignment = Enum.TextXAlignment.Left; theirDewsLbl.Text = "DEWS:"; theirDewsLbl.ZIndex = 5005
			TradeUIElements.TheirDewsBox = Instance.new("TextLabel", theirDewsBg); TradeUIElements.TheirDewsBox.Size = UDim2.new(0.55, 0, 0.8, 0); TradeUIElements.TheirDewsBox.Position = UDim2.new(0.4, 0, 0.1, 0); TradeUIElements.TheirDewsBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TradeUIElements.TheirDewsBox.Font = Enum.Font.GothamBold; TradeUIElements.TheirDewsBox.TextColor3 = Color3.fromRGB(255, 255, 255); TradeUIElements.TheirDewsBox.TextSize = 10; TradeUIElements.TheirDewsBox.Text = "0"; TradeUIElements.TheirDewsBox.ZIndex = 5005; Instance.new("UICorner", TradeUIElements.TheirDewsBox).CornerRadius = UDim.new(0, 4)

			TradeUIElements.MyDewsBox.FocusLost:Connect(function()
				local amt = tonumber(TradeUIElements.MyDewsBox.Text) or 0
				Network.TradeAction:FireServer("UpdateDews", amt)
			end)

			local cancelBtn = Instance.new("TextButton", mainPanel); cancelBtn.Size = UDim2.new(0.35, 0, 0, 45); cancelBtn.Position = UDim2.new(0.1, 0, 1, -55); cancelBtn.Font = Enum.Font.GothamBlack; cancelBtn.TextColor3 = Color3.fromRGB(255, 150, 150); cancelBtn.TextSize = 14; cancelBtn.Text = "CANCEL"; cancelBtn.ZIndex = 5002; cancelBtn.TextScaled = true; Instance.new("UITextSizeConstraint", cancelBtn).MaxTextSize = 14
			ApplyButtonGradient(cancelBtn, Color3.fromRGB(60, 20, 20), Color3.fromRGB(30, 10, 10), Color3.fromRGB(180, 60, 60))
			cancelBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("Cancel") end)

			TradeUIElements.ReadyBtn = Instance.new("TextButton", mainPanel); TradeUIElements.ReadyBtn.Size = UDim2.new(0.35, 0, 0, 45); TradeUIElements.ReadyBtn.Position = UDim2.new(0.55, 0, 1, -55); TradeUIElements.ReadyBtn.Font = Enum.Font.GothamBlack; TradeUIElements.ReadyBtn.TextColor3 = Color3.fromRGB(255, 255, 255); TradeUIElements.ReadyBtn.TextSize = 14; TradeUIElements.ReadyBtn.Text = "READY UP"; TradeUIElements.ReadyBtn.ZIndex = 5002; TradeUIElements.ReadyBtn.TextScaled = true; Instance.new("UITextSizeConstraint", TradeUIElements.ReadyBtn).MaxTextSize = 14
			ApplyButtonGradient(TradeUIElements.ReadyBtn, Color3.fromRGB(80, 160, 80), Color3.fromRGB(40, 90, 40), Color3.fromRGB(20, 60, 20))
			TradeUIElements.ReadyBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("ToggleReady") end)

			TradeUIElements.ConfirmBtn = Instance.new("TextButton", mainPanel); TradeUIElements.ConfirmBtn.Size = UDim2.new(0.8, 0, 0, 45); TradeUIElements.ConfirmBtn.Position = UDim2.new(0.1, 0, 1, -55); TradeUIElements.ConfirmBtn.Font = Enum.Font.GothamBlack; TradeUIElements.ConfirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255); TradeUIElements.ConfirmBtn.TextSize = 14; TradeUIElements.ConfirmBtn.Text = "WAITING ON PLAYERS"; TradeUIElements.ConfirmBtn.AutoButtonColor = false; TradeUIElements.ConfirmBtn.ZIndex = 5002; TradeUIElements.ConfirmBtn.Visible = false; TradeUIElements.ConfirmBtn.TextScaled = true; Instance.new("UITextSizeConstraint", TradeUIElements.ConfirmBtn).MaxTextSize = 14
			ApplyButtonGradient(TradeUIElements.ConfirmBtn, Color3.fromRGB(60, 60, 70), Color3.fromRGB(30, 30, 35), Color3.fromRGB(40, 40, 50))
			TradeUIElements.ConfirmBtn.MouseButton1Click:Connect(function() if TradeUIElements.ConfirmBtn.Text == "CONFIRM TRADE" then Network.TradeAction:FireServer("ToggleConfirm") end end)

		elseif action == "Sync" then
			if not TradeUIElements.MyInvList then return end

			-- [[ THE FIX: Bulletproof Boolean Parsing without Ternary Trap ]]
			local isP1 = (data.P1.Name == player.Name)
			local myOffer = isP1 and data.P1Offer or data.P2Offer
			local theirOffer = isP1 and data.P2Offer or data.P1Offer

			local myReady, theirReady, myConfirm, theirConfirm
			if isP1 then
				myReady = data.P1Ready; theirReady = data.P2Ready
				myConfirm = data.P1Confirmed; theirConfirm = data.P2Confirmed
			else
				myReady = data.P2Ready; theirReady = data.P1Ready
				myConfirm = data.P2Confirmed; theirConfirm = data.P1Confirmed
			end

			TradeUIElements.MyDewsBox.Text = tostring(myOffer.Dews)
			TradeUIElements.TheirDewsBox.Text = tostring(theirOffer.Dews)

			for _, child in ipairs(TradeUIElements.MyInvList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
			local invCount = 0
			for attr, val in pairs(player:GetAttributes()) do
				if string.match(attr, "Count$") and val > 0 then
					local itemName = attr:gsub("Count", "")
					local actualItemName = itemName
					for realName, _ in pairs(ItemData.Equipment) do if realName:gsub("[^%w]", "") == itemName then actualItemName = realName break end end
					for realName, _ in pairs(ItemData.Consumables) do if realName:gsub("[^%w]", "") == itemName then actualItemName = realName break end end

					local offeredAmt = myOffer.Items[actualItemName] or 0
					local remaining = val - offeredAmt
					if remaining > 0 then
						CreateItemCard(TradeUIElements.MyInvList, actualItemName, remaining, false, function(name)
							Network.TradeAction:FireServer("AddItem", {Item = name})
						end)
						invCount += 1
					end
				end
			end
			TradeUIElements.MyInvList.CanvasSize = UDim2.new(0, 0, 0, invCount * 45)

			for _, child in ipairs(TradeUIElements.MyOfferList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
			local mCount = 0
			for itemName, amt in pairs(myOffer.Items) do
				CreateItemCard(TradeUIElements.MyOfferList, itemName, amt, true, function(name)
					Network.TradeAction:FireServer("RemoveItem", {Item = name})
				end)
				mCount += 1
			end
			TradeUIElements.MyOfferList.CanvasSize = UDim2.new(0, 0, 0, mCount * 45)

			for _, child in ipairs(TradeUIElements.TheirOfferList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
			local tCount = 0
			for itemName, amt in pairs(theirOffer.Items) do
				CreateItemCard(TradeUIElements.TheirOfferList, itemName, amt, true, nil)
				tCount += 1
			end
			TradeUIElements.TheirOfferList.CanvasSize = UDim2.new(0, 0, 0, tCount * 45)

			-- [[ THE FIX: Real-time visual feedback for the OTHER player's readiness ]]
			if myConfirm then
				TradeUIElements.Col2.UIStroke.Color = Color3.fromRGB(80, 220, 80)
			elseif myReady then
				TradeUIElements.Col2.UIStroke.Color = Color3.fromRGB(150, 200, 100)
			else
				TradeUIElements.Col2.UIStroke.Color = Color3.fromRGB(60, 60, 70)
			end

			if theirConfirm then
				TradeUIElements.Col3.UIStroke.Color = Color3.fromRGB(80, 220, 80)
			elseif theirReady then
				TradeUIElements.Col3.UIStroke.Color = Color3.fromRGB(150, 200, 100)
			else
				TradeUIElements.Col3.UIStroke.Color = Color3.fromRGB(60, 60, 70)
			end

			if myReady and theirReady then
				TradeUIElements.ReadyBtn.Visible = false
				TradeUIElements.ConfirmBtn.Visible = true

				if data.Countdown and data.Countdown > 0 then
					TradeUIElements.ConfirmBtn.Text = "TRADING IN " .. data.Countdown .. "..."
					ApplyButtonGradient(TradeUIElements.ConfirmBtn, Color3.fromRGB(200, 150, 50), Color3.fromRGB(120, 80, 20), Color3.fromRGB(255, 200, 0))
				elseif myConfirm then
					TradeUIElements.ConfirmBtn.Text = "WAITING ON PARTNER..."
					ApplyButtonGradient(TradeUIElements.ConfirmBtn, Color3.fromRGB(60, 60, 70), Color3.fromRGB(30, 30, 35), Color3.fromRGB(40, 40, 50))
				elseif theirConfirm then
					TradeUIElements.ConfirmBtn.Text = "PARTNER CONFIRMED!"
					ApplyButtonGradient(TradeUIElements.ConfirmBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))
				else
					TradeUIElements.ConfirmBtn.Text = "CONFIRM TRADE"
					ApplyButtonGradient(TradeUIElements.ConfirmBtn, Color3.fromRGB(80, 160, 80), Color3.fromRGB(40, 90, 40), Color3.fromRGB(20, 60, 20))
				end
			else
				TradeUIElements.ConfirmBtn.Visible = false
				TradeUIElements.ReadyBtn.Visible = true

				if myReady then
					TradeUIElements.ReadyBtn.Text = "UNREADY"
					ApplyButtonGradient(TradeUIElements.ReadyBtn, Color3.fromRGB(180, 80, 80), Color3.fromRGB(100, 40, 40), Color3.fromRGB(80, 20, 20))
				else
					TradeUIElements.ReadyBtn.Text = "READY UP"
					ApplyButtonGradient(TradeUIElements.ReadyBtn, Color3.fromRGB(80, 160, 80), Color3.fromRGB(40, 90, 40), Color3.fromRGB(20, 60, 20))
				end
			end

		elseif action == "TradeComplete" then
			TradeScreenGui:ClearAllChildren()
			if NotificationManager then NotificationManager.Show("Trade completed successfully!", "Success") end
			TradeUIElements = {}

		elseif action == "TradeCancelled" then
			TradeScreenGui:ClearAllChildren()
			if NotificationManager then NotificationManager.Show(data or "Trade Cancelled.", "Error") end
			TradeUIElements = {}
		end
	end)
end

function TradeMenu.Show()
	if MainFrame then MainFrame.Visible = true end
end

return TradeMenu