-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local ProfileTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

local NotificationManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("NotificationManager"))

local player = Players.LocalPlayer
local MainFrame
local InvGrid
local wpnLabel, accLabel, titanLabel, clanLabel, regimentLabel
local titanAwakenBtn, clanAwakenBtn, prestigeBtn
local RadarContainer, regIcon, AvatarBox
local toggleStatsBtn
local InvTitle 
local isShowingTitanStats = false
local MAX_INVENTORY_CAPACITY = 50

local RarityColors = { ["Common"] = "#AAAAAA", ["Uncommon"] = "#55FF55", ["Rare"] = "#5588FF", ["Epic"] = "#CC44FF", ["Legendary"] = "#FFD700", ["Mythical"] = "#FF3333", ["Transcendent"] = "#FF55FF" }
local RarityOrder = { Transcendent = 0, Mythical = 1, Legendary = 2, Epic = 3, Rare = 4, Uncommon = 5, Common = 6 }
local SellValues = { Common = 10, Uncommon = 25, Rare = 75, Epic = 200, Legendary = 500, Mythical = 1500, Transcendent = 0 }

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}
	grad.Rotation = 90

	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 4)

	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn)
		stroke.Color = strokeColor
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end

	if not btn:GetAttribute("GradientTextFixed") then
		btn:SetAttribute("GradientTextFixed", true)

		local textLbl = Instance.new("TextLabel", btn)
		textLbl.Name = "BtnTextLabel"
		textLbl.Size = UDim2.new(1, 0, 1, 0)
		textLbl.BackgroundTransparency = 1
		textLbl.Font = btn.Font
		textLbl.TextSize = btn.TextSize
		textLbl.TextScaled = btn.TextScaled
		textLbl.RichText = btn.RichText
		textLbl.TextWrapped = btn.TextWrapped
		textLbl.TextXAlignment = btn.TextXAlignment
		textLbl.TextYAlignment = btn.TextYAlignment
		textLbl.ZIndex = btn.ZIndex + 1

		local tConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint")
		if tConstraint then tConstraint.Parent = textLbl end

		btn.ChildAdded:Connect(function(child)
			if child:IsA("UITextSizeConstraint") then
				task.delay(0, function() child.Parent = textLbl end)
			end
		end)

		textLbl.Text = btn.Text
		textLbl.TextColor3 = btn.TextColor3
		btn.Text = ""

		btn:GetPropertyChangedSignal("Text"):Connect(function()
			if btn.Text ~= "" then
				textLbl.Text = btn.Text
				btn.Text = ""
			end
		end)
		btn:GetPropertyChangedSignal("TextColor3"):Connect(function()
			textLbl.TextColor3 = btn.TextColor3
		end)
	end
end

local function DrawLineScale(parent, p1x, p1y, p2x, p2y, color, thickness, zindex)
	local dx = p2x - p1x; local dy = p2y - p1y; local dist = math.sqrt(dx*dx + dy*dy)
	local frame = Instance.new("Frame", parent)
	frame.Size = UDim2.new(0, dist, 0, thickness); frame.Position = UDim2.new(0, (p1x + p2x)/2, 0, (p1y + p2y)/2)
	frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Rotation = math.deg(math.atan2(dy, dx))
	frame.BackgroundColor3 = color; frame.BorderSizePixel = 0; frame.ZIndex = zindex or 1
	return frame
end

local function DrawUITriangle(parent, p1, p2, p3, color, transp, zIndex)
	local edges = { {p1, p2}, {p2, p3}, {p3, p1} }
	table.sort(edges, function(a, b) return (a[1]-a[2]).Magnitude > (b[1]-b[2]).Magnitude end)
	local a, b = edges[1][1], edges[1][2]; local c = edges[2][1] == a and edges[2][2] or edges[2][1]
	if c == b then c = edges[3][1] == a and edges[3][2] or edges[3][1] end
	local ab = b - a; local ac = c - a; local dir = ab.Unit; local projLen = ac:Dot(dir); local proj = dir * projLen; local h = (ac - proj).Magnitude
	local w1 = projLen; local w2 = ab.Magnitude - projLen
	local t1 = Instance.new("ImageLabel")
	t1.BackgroundTransparency = 1; t1.Image = "rbxassetid://319692171"; t1.ImageColor3 = color; t1.ImageTransparency = transp; t1.ZIndex = zIndex; t1.BorderSizePixel = 0; t1.AnchorPoint = Vector2.new(0.5, 0.5)
	local t2 = t1:Clone(); t1.Size = UDim2.new(0, w1, 0, h); t2.Size = UDim2.new(0, w2, 0, h)
	t1.Position = UDim2.new(0, a.X + proj.X/2, 0, a.Y + proj.Y/2); t2.Position = UDim2.new(0, b.X + (proj.X - ab.X)/2, 0, b.Y + (proj.Y - ab.Y)/2)
	t1.Rotation = math.deg(math.atan2(dir.Y, dir.X)); t2.Rotation = math.deg(math.atan2(-dir.Y, -dir.X))
	t1.Parent = parent; t2.Parent = parent
end

function ProfileTab.Init(parentFrame, tooltipMgr)
	local cachedTooltipMgr = tooltipMgr
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "ProfileFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false
	MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local mLayout = Instance.new("UIListLayout", MainFrame)
	mLayout.SortOrder = Enum.SortOrder.LayoutOrder; mLayout.Padding = UDim.new(0, 15); mLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local mPad = Instance.new("UIPadding", MainFrame); mPad.PaddingTop = UDim.new(0, 10); mPad.PaddingBottom = UDim.new(0, 30)

	local TopPanel = Instance.new("Frame", MainFrame)
	TopPanel.Size = UDim2.new(0.95, 0, 0, 480); TopPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TopPanel.LayoutOrder = 1
	Instance.new("UICorner", TopPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", TopPanel).Color = Color3.fromRGB(80, 80, 90)

	local topLayout = Instance.new("UIListLayout", TopPanel)
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; topLayout.SortOrder = Enum.SortOrder.LayoutOrder; topLayout.Padding = UDim.new(0, 10)
	local topPad = Instance.new("UIPadding", TopPanel); topPad.PaddingTop = UDim.new(0, 15); topPad.PaddingBottom = UDim.new(0, 15)

	local TopHeader = Instance.new("Frame", TopPanel)
	TopHeader.Size = UDim2.new(1, 0, 0, 90); TopHeader.BackgroundTransparency = 1; TopHeader.LayoutOrder = 1

	AvatarBox = Instance.new("ImageLabel", TopHeader)
	AvatarBox.Size = UDim2.new(0, 90, 0, 90); AvatarBox.Position = UDim2.new(0.5, 0, 0.5, 0); AvatarBox.AnchorPoint = Vector2.new(0.5, 0.5); AvatarBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	AvatarBox.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
	Instance.new("UICorner", AvatarBox).CornerRadius = UDim.new(0, 45); Instance.new("UIStroke", AvatarBox).Color = Color3.fromRGB(120, 100, 60)

	regIcon = Instance.new("ImageLabel", TopHeader)
	regIcon.Size = UDim2.new(0, 60, 0, 60); regIcon.Position = UDim2.new(0.5, 50, 0.5, 0); regIcon.AnchorPoint = Vector2.new(0, 0.5); regIcon.BackgroundTransparency = 1

	local NameLabel = Instance.new("TextLabel", TopPanel)
	NameLabel.Size = UDim2.new(1, 0, 0, 30); NameLabel.BackgroundTransparency = 1; NameLabel.LayoutOrder = 2
	NameLabel.Font = Enum.Font.GothamBlack; NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255); NameLabel.TextSize = 22; NameLabel.TextXAlignment = Enum.TextXAlignment.Center
	NameLabel.Text = player.Name
	ApplyGradient(NameLabel, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	RadarContainer = Instance.new("Frame", TopPanel)
	RadarContainer.Size = UDim2.new(0.9, 0, 0, 200); RadarContainer.BackgroundTransparency = 1; RadarContainer.LayoutOrder = 3
	Instance.new("UIAspectRatioConstraint", RadarContainer).AspectRatio = 1

	local StatsRect = Instance.new("Frame", TopPanel)
	StatsRect.Size = UDim2.new(0.95, 0, 0, 0); StatsRect.AutomaticSize = Enum.AutomaticSize.Y; StatsRect.BackgroundTransparency = 1; StatsRect.LayoutOrder = 4
	local statsLayout = Instance.new("UIListLayout", StatsRect); statsLayout.Padding = UDim.new(0, 6); statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function CreateInfoLabel(parent)
		local l = Instance.new("TextLabel", parent); l.Size = UDim2.new(1, 0, 0, 35); l.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
		l.Font = Enum.Font.GothamBold; l.TextColor3 = Color3.fromRGB(200, 200, 200); l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextWrapped = true
		local pad = Instance.new("UIPadding", l); pad.PaddingLeft = UDim.new(0, 10); Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
		Instance.new("UIStroke", l).Color = Color3.fromRGB(60, 60, 70)
		return l
	end

	local titanRow = Instance.new("Frame", StatsRect); titanRow.Size = UDim2.new(1, 0, 0, 35); titanRow.BackgroundTransparency = 1
	titanLabel = CreateInfoLabel(titanRow); titanLabel.Size = UDim2.new(1, 0, 1, 0)
	titanAwakenBtn = Instance.new("TextButton", titanRow); titanAwakenBtn.Size = UDim2.new(0.3, 0, 0.8, 0); titanAwakenBtn.Position = UDim2.new(0.68, 0, 0.1, 0)
	titanAwakenBtn.Font = Enum.Font.GothamBold; titanAwakenBtn.TextColor3 = Color3.fromRGB(255, 255, 255); titanAwakenBtn.TextSize = 10; titanAwakenBtn.Text = "AWAKEN"
	ApplyButtonGradient(titanAwakenBtn, Color3.fromRGB(200, 60, 60), Color3.fromRGB(120, 30, 30), Color3.fromRGB(80, 20, 20)); titanAwakenBtn.Visible = false

	regimentLabel = CreateInfoLabel(StatsRect)

	local clanRow = Instance.new("Frame", StatsRect); clanRow.Size = UDim2.new(1, 0, 0, 35); clanRow.BackgroundTransparency = 1
	clanLabel = CreateInfoLabel(clanRow); clanLabel.Size = UDim2.new(1, 0, 1, 0)
	clanAwakenBtn = Instance.new("TextButton", clanRow); clanAwakenBtn.Size = UDim2.new(0.3, 0, 0.8, 0); clanAwakenBtn.Position = UDim2.new(0.68, 0, 0.1, 0)
	clanAwakenBtn.Font = Enum.Font.GothamBold; clanAwakenBtn.TextColor3 = Color3.fromRGB(255, 255, 255); clanAwakenBtn.TextSize = 10; clanAwakenBtn.Text = "AWAKEN"
	ApplyButtonGradient(clanAwakenBtn, Color3.fromRGB(200, 60, 60), Color3.fromRGB(120, 30, 30), Color3.fromRGB(80, 20, 20)); clanAwakenBtn.Visible = false

	wpnLabel = CreateInfoLabel(StatsRect)
	accLabel = CreateInfoLabel(StatsRect)

	prestigeBtn = Instance.new("TextButton", TopPanel)
	prestigeBtn.Size = UDim2.new(0.9, 0, 0, 35); prestigeBtn.LayoutOrder = 5
	prestigeBtn.Font = Enum.Font.GothamBlack; prestigeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); prestigeBtn.TextSize = 12; prestigeBtn.Text = "PRESTIGE (RESET CAMPAIGN)"
	ApplyButtonGradient(prestigeBtn, Color3.fromRGB(220, 180, 50), Color3.fromRGB(140, 100, 20), Color3.fromRGB(255, 215, 100)); prestigeBtn.Visible = false

	toggleStatsBtn = Instance.new("TextButton", TopPanel)
	toggleStatsBtn.Size = UDim2.new(0.9, 0, 0, 35); toggleStatsBtn.LayoutOrder = 6
	toggleStatsBtn.Font = Enum.Font.GothamBold; toggleStatsBtn.TextColor3 = Color3.fromRGB(200, 200, 255); toggleStatsBtn.TextSize = 12; toggleStatsBtn.Text = "VIEW TITAN STATS"
	ApplyButtonGradient(toggleStatsBtn, Color3.fromRGB(60, 60, 80), Color3.fromRGB(30, 30, 40), Color3.fromRGB(100, 100, 150))

	topLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TopPanel.Size = UDim2.new(0.95, 0, 0, topLayout.AbsoluteContentSize.Y + 30) end)

	local BottomPanel = Instance.new("Frame", MainFrame)
	BottomPanel.Size = UDim2.new(0.95, 0, 0, 500); BottomPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); BottomPanel.LayoutOrder = 2
	Instance.new("UICorner", BottomPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", BottomPanel).Color = Color3.fromRGB(80, 80, 90)

	InvTitle = Instance.new("TextLabel", BottomPanel)
	InvTitle.Size = UDim2.new(1, 0, 0, 40); InvTitle.BackgroundTransparency = 1; InvTitle.Font = Enum.Font.GothamBlack; InvTitle.TextColor3 = Color3.fromRGB(255, 215, 100); InvTitle.TextSize = 18; InvTitle.Text = "INVENTORY (0/50)"
	ApplyGradient(InvTitle, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	local AutoSellFrame = Instance.new("Frame", BottomPanel)
	AutoSellFrame.Size = UDim2.new(1, 0, 0, 30); AutoSellFrame.Position = UDim2.new(0, 0, 0, 40); AutoSellFrame.BackgroundTransparency = 1
	local asLayout = Instance.new("UIListLayout", AutoSellFrame); asLayout.FillDirection = Enum.FillDirection.Horizontal; asLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; asLayout.Padding = UDim.new(0, 5)

	local asLabel = Instance.new("TextLabel", AutoSellFrame)
	asLabel.Size = UDim2.new(0, 70, 1, 0); asLabel.BackgroundTransparency = 1; asLabel.Font = Enum.Font.GothamBold; asLabel.TextColor3 = Color3.fromRGB(180, 180, 180); asLabel.TextSize = 11; asLabel.TextXAlignment = Enum.TextXAlignment.Right; asLabel.Text = "Auto-Sell:"

	local autoSellStates = {Common = false, Uncommon = false, Rare = false}
	local function CreateAutoSell(rarity, color)
		local asBtn = Instance.new("TextButton", AutoSellFrame)
		asBtn.Size = UDim2.new(0, 75, 1, 0)
		asBtn.Font = Enum.Font.GothamBold; asBtn.TextColor3 = color; asBtn.TextSize = 11; asBtn.Text = "All " .. rarity
		ApplyButtonGradient(asBtn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 70))

		asBtn.MouseButton1Click:Connect(function()
			autoSellStates[rarity] = not autoSellStates[rarity]
			if autoSellStates[rarity] then
				ApplyButtonGradient(asBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(60, 120, 60))
				Network.AutoSell:FireServer(rarity)
				if NotificationManager then NotificationManager.Show("Auto-Sell " .. rarity .. " ENABLED", "Info") end
			else
				ApplyButtonGradient(asBtn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 70))
				if NotificationManager then NotificationManager.Show("Auto-Sell " .. rarity .. " DISABLED", "Info") end
			end
		end)
	end
	CreateAutoSell("Common", Color3.fromRGB(180, 180, 180))
	CreateAutoSell("Uncommon", Color3.fromRGB(100, 255, 100))
	CreateAutoSell("Rare", Color3.fromRGB(100, 100, 255))

	InvGrid = Instance.new("ScrollingFrame", BottomPanel)
	InvGrid.Size = UDim2.new(1, -10, 1, -90); InvGrid.Position = UDim2.new(0, 5, 0, 80); InvGrid.BackgroundTransparency = 1; InvGrid.BorderSizePixel = 0; InvGrid.ScrollBarThickness = 4
	local gl = Instance.new("UIGridLayout", InvGrid)
	gl.CellSize = UDim2.new(0, 75, 0, 75) 
	gl.CellPadding = UDim2.new(0, 8, 0, 10)
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.SortOrder = Enum.SortOrder.LayoutOrder

	titanAwakenBtn.MouseButton1Click:Connect(function() Network.AwakenAction:FireServer("Titan") end)
	clanAwakenBtn.MouseButton1Click:Connect(function() Network.AwakenAction:FireServer("Clan") end)
	prestigeBtn.MouseButton1Click:Connect(function() Network.PrestigeEvent:FireServer() end)

	local function RenderRadarChart()
		local w = RadarContainer.AbsoluteSize.X; local h = RadarContainer.AbsoluteSize.Y
		if w == 0 then return end 
		for _, child in ipairs(RadarContainer:GetChildren()) do if not child:IsA("UIAspectRatioConstraint") then child:Destroy() end end
		local ls = player:FindFirstChild("leaderstats"); local p = ls and ls:FindFirstChild("Prestige")
		local maxVal = GameData.GetStatCap(p and p.Value or 0)
		local stats = isShowingTitanStats and { {Name = "POW", Val = player:GetAttribute("Titan_Power_Val") or 1}, {Name = "SPD", Val = player:GetAttribute("Titan_Speed_Val") or 1}, {Name = "HRD", Val = player:GetAttribute("Titan_Hardening_Val") or 1}, {Name = "END", Val = player:GetAttribute("Titan_Endurance_Val") or 1}, {Name = "STM", Val = player:GetAttribute("Titan_Precision_Val") or 1}, {Name = "POT", Val = player:GetAttribute("Titan_Potential_Val") or 1} } or { {Name = "HP", Val = player:GetAttribute("Health") or 1}, {Name = "STR", Val = player:GetAttribute("Strength") or 1}, {Name = "DEF", Val = player:GetAttribute("Defense") or 1}, {Name = "SPD", Val = player:GetAttribute("Speed") or 1}, {Name = "GAS", Val = player:GetAttribute("Gas") or 1}, {Name = "RES", Val = player:GetAttribute("Resolve") or 1} }
		toggleStatsBtn.Text = isShowingTitanStats and "VIEW HUMAN STATS" or "VIEW TITAN STATS"
		local angles = {-90, -30, 30, 90, 150, 210}; local centerX, centerY = w/2, h/2; local maxRadius = math.min(w, h) * 0.35
		for ring = 1, 3 do local r = maxRadius * (ring / 3) for i = 1, 6 do local nextI = i % 6 + 1; DrawLineScale(RadarContainer, centerX + r*math.cos(math.rad(angles[i])), centerY + r*math.sin(math.rad(angles[i])), centerX + r*math.cos(math.rad(angles[nextI])), centerY + r*math.sin(math.rad(angles[nextI])), Color3.fromRGB(60, 60, 70), 1, 1) end end
		for i = 1, 6 do 
			local rad = math.rad(angles[i]); local px = centerX + maxRadius * math.cos(rad); local py = centerY + maxRadius * math.sin(rad)
			DrawLineScale(RadarContainer, centerX, centerY, px, py, Color3.fromRGB(60, 60, 70), 1, 1)
			local lbl = Instance.new("TextLabel", RadarContainer); lbl.Size = UDim2.new(0, 30, 0, 15); lbl.BackgroundTransparency = 1; lbl.Position = UDim2.new(0, centerX + (maxRadius + 15) * math.cos(rad), 0, centerY + (maxRadius + 15) * math.sin(rad)); lbl.AnchorPoint = Vector2.new(0.5, 0.5); lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(200, 200, 200); lbl.TextSize = 9; lbl.Text = stats[i].Name .. "\n" .. stats[i].Val
		end
		local statColor = isShowingTitanStats and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
		local pts = {}
		for i = 1, 6 do local r1 = maxRadius * math.clamp(stats[i].Val / maxVal, 0.05, 1); table.insert(pts, Vector2.new(centerX + r1 * math.cos(math.rad(angles[i])), centerY + r1 * math.sin(math.rad(angles[i])))) end
		for i = 1, 6 do local nextI = i % 6 + 1; DrawLineScale(RadarContainer, pts[i].X, pts[i].Y, pts[nextI].X, pts[nextI].Y, statColor, 2, 5); DrawUITriangle(RadarContainer, Vector2.new(centerX, centerY), pts[i], pts[nextI], statColor, 0.5, 3) end
	end
	RadarContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(RenderRadarChart)
	toggleStatsBtn.MouseButton1Click:Connect(function() isShowingTitanStats = not isShowingTitanStats; RenderRadarChart() end)

	local function RefreshProfile()
		local tName = player:GetAttribute("Titan") or "None"; local cName = player:GetAttribute("Clan") or "None"; local cPart = player:GetAttribute("CurrentPart") or 1
		local regName = player:GetAttribute("Regiment") or "Cadet Corps"
		local hasRegData, regDataModule = pcall(function() return require(game.ReplicatedStorage:WaitForChild("RegimentData")) end)
		if hasRegData and regDataModule and regDataModule.Regiments[regName] then 
			regIcon.Image = regDataModule.Regiments[regName].Icon 
		end

		if cName == "Ackerman" or cName == "Awakened Ackerman" then titanLabel.Text = "Titan: <font color='#FF5555'>(Titan Disabled)</font>" else titanLabel.Text = "Titan: <font color='#FF5555'>" .. tName .. "</font>" end
		titanLabel.RichText = true; clanLabel.Text = "Clan: <font color='#55FF55'>" .. cName .. "</font>"; clanLabel.RichText = true
		regimentLabel.Text = "Regiment: <font color='#AAAAAA'>" .. regName .. "</font>"; regimentLabel.RichText = true
		wpnLabel.Text = "Weapon: " .. (player:GetAttribute("EquippedWeapon") or "None"); accLabel.Text = "Accessory: " .. (player:GetAttribute("EquippedAccessory") or "None")

		if tName == "Attack Titan" and (player:GetAttribute("YmirsClayFragmentCount") or 0) > 0 then titanAwakenBtn.Visible = true else titanAwakenBtn.Visible = false end

		-- Check all valid clans for awakening button
		local validClans = {["Ackerman"] = true, ["Yeager"] = true, ["Tybur"] = true, ["Braun"] = true, ["Galliard"] = true}
		if validClans[cName] and (player:GetAttribute("AncestralAwakeningSerumCount") or 0) > 0 then clanAwakenBtn.Visible = true else clanAwakenBtn.Visible = false end

		if cPart > 8 then prestigeBtn.Visible = true else prestigeBtn.Visible = false end

		RenderRadarChart()

		for _, child in ipairs(InvGrid:GetChildren()) do 
			if child.Name == "ItemCard" then child:Destroy() end 
		end

		local inventoryItems = {}
		local currentSlotsUsed = 0

		for iName, iData in pairs(ItemData.Equipment) do table.insert(inventoryItems, {Name = iName, Data = iData}) end
		for iName, iData in pairs(ItemData.Consumables) do table.insert(inventoryItems, {Name = iName, Data = iData}) end
		table.sort(inventoryItems, function(a, b) local rA = RarityOrder[a.Data.Rarity or "Common"] or 7; local rB = RarityOrder[b.Data.Rarity or "Common"] or 7; if rA == rB then return a.Name < b.Name else return rA < rB end end)

		local layoutOrderCounter = 1

		for _, item in ipairs(inventoryItems) do
			local itemName = item.Name; local itemInfo = item.Data; 
			local safeNameBase = itemName:gsub("[^%w]", "")
			local count = player:GetAttribute(safeNameBase .. "Count") or 0

			if count > 0 then
				currentSlotsUsed += 1

				local card = Instance.new("TextButton", InvGrid)
				card.Name = "ItemCard"
				card.Size = UDim2.new(1, 0, 1, 0)
				card.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
				card.Text = ""
				card.LayoutOrder = layoutOrderCounter
				layoutOrderCounter += 1
				Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
				card.ClipsDescendants = true

				local rarityKey = itemInfo.Rarity or "Common"
				local awakenedStats = player:GetAttribute(safeNameBase .. "_Awakened")
				if awakenedStats then rarityKey = "Transcendent" end

				local cColor = RarityColors[rarityKey] or "#FFFFFF"
				local rarityRGB = Color3.fromHex(cColor:gsub("#", ""))

				local cStroke = Instance.new("UIStroke", card)
				cStroke.Color = rarityRGB
				cStroke.Thickness = 1
				cStroke.Transparency = 0.55
				cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

				local accentBar = Instance.new("Frame", card)
				accentBar.Size = UDim2.new(1, 0, 0, 3)
				accentBar.Position = UDim2.new(0, 0, 0, 0)
				accentBar.BackgroundColor3 = rarityRGB
				accentBar.BorderSizePixel = 0
				accentBar.ZIndex = 2

				local bgGlow = Instance.new("Frame", card)
				bgGlow.Size = UDim2.new(1, 0, 0.5, 0)
				bgGlow.Position = UDim2.new(0, 0, 0.5, 0)
				bgGlow.BackgroundColor3 = rarityRGB
				bgGlow.BackgroundTransparency = 0.92
				bgGlow.BorderSizePixel = 0
				bgGlow.ZIndex = 1

				local countBadge = Instance.new("Frame", card)
				countBadge.Size = UDim2.new(0, 20, 0, 12)
				countBadge.AnchorPoint = Vector2.new(1, 0)
				countBadge.Position = UDim2.new(1, -3, 0, 6)
				countBadge.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
				countBadge.BorderSizePixel = 0
				countBadge.ZIndex = 3
				Instance.new("UICorner", countBadge).CornerRadius = UDim.new(0, 3)

				local countTag = Instance.new("TextLabel", countBadge)
				countTag.Size = UDim2.new(1, 0, 1, 0)
				countTag.BackgroundTransparency = 1
				countTag.Font = Enum.Font.GothamBlack
				countTag.TextColor3 = Color3.fromRGB(210, 210, 210)
				countTag.TextSize = 8
				countTag.Text = "x" .. count
				countTag.ZIndex = 4

				local nameLbl = Instance.new("TextLabel", card)
				nameLbl.Size = UDim2.new(0.88, 0, 0.5, 0)
				nameLbl.Position = UDim2.new(0.5, 0, 0.5, 2)
				nameLbl.AnchorPoint = Vector2.new(0.5, 0.5)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Font = Enum.Font.GothamBold
				nameLbl.TextColor3 = Color3.fromRGB(235, 235, 235)
				nameLbl.TextScaled = true
				nameLbl.TextWrapped = true
				nameLbl.Text = itemName
				nameLbl.ZIndex = 3
				local tConstraint = Instance.new("UITextSizeConstraint", nameLbl)
				tConstraint.MaxTextSize = 10
				tConstraint.MinTextSize = 6

				local rarityTag = Instance.new("TextLabel", card)
				rarityTag.Size = UDim2.new(0, 14, 0, 14)
				rarityTag.Position = UDim2.new(0, 4, 1, -18)
				rarityTag.BackgroundTransparency = 1
				rarityTag.Font = Enum.Font.GothamBlack
				rarityTag.TextColor3 = rarityRGB
				rarityTag.TextTransparency = 0.3
				rarityTag.TextSize = 9
				rarityTag.Text = string.sub(rarityKey, 1, 1)
				rarityTag.ZIndex = 3

				local tTipStr = "<font color='" .. cColor .. "'>[" .. rarityKey .. "]</font> <b>" .. itemName .. "</b>"
				if itemInfo.Bonus then 
					local bList = {}; for k, v in pairs(itemInfo.Bonus) do table.insert(bList, "+" .. v .. " " .. string.sub(k, 1, 3):upper()) end; 
					tTipStr = tTipStr .. "\n<font color='#55FF55'>" .. table.concat(bList, "\n") .. "</font>" 
				elseif itemInfo.Desc then 
					local desc = itemInfo.Desc
					local wrapped = ""
					local lineLen = 0
					for word in desc:gmatch("%S+") do
						if lineLen + #word + 1 > 28 and lineLen > 0 then
							wrapped = wrapped .. "\n" .. word
							lineLen = #word
						else
							wrapped = wrapped .. (lineLen > 0 and " " or "") .. word
							lineLen = lineLen + #word + (lineLen > 0 and 1 or 0)
						end
					end
					tTipStr = tTipStr .. "\n<font color='#AAAAAA'>" .. wrapped .. "</font>" 
				end
				if awakenedStats then tTipStr = tTipStr .. "\n<font color='#AA55FF'>[Awakened]:\n" .. awakenedStats .. "</font>" end

				local btnCover = Instance.new("TextButton", card)
				btnCover.Size = UDim2.new(1,0,1,0)
				btnCover.BackgroundTransparency = 1
				btnCover.Text = ""
				btnCover.ZIndex = 5
				btnCover.MouseEnter:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Show(tTipStr) end end)
				btnCover.MouseLeave:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Hide() end end)

				if itemInfo.IsGift then
					local giftTag = Instance.new("TextLabel", card)
					giftTag.Size = UDim2.new(1, 0, 0, 14)
					giftTag.Position = UDim2.new(0, 0, 1, -18)
					giftTag.BackgroundTransparency = 1
					giftTag.Font = Enum.Font.GothamBold
					giftTag.TextColor3 = Color3.fromRGB(255, 210, 80)
					giftTag.TextTransparency = 0.2
					giftTag.TextSize = 8
					giftTag.Text = "GIFT"
					giftTag.ZIndex = 3
				else
					local ActionsOverlay = Instance.new("Frame", card)
					ActionsOverlay.Name = "ActionsOverlay"
					ActionsOverlay.Size = UDim2.new(1, 0, 1, 0)
					ActionsOverlay.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
					ActionsOverlay.BackgroundTransparency = 0.05
					ActionsOverlay.Visible = false
					ActionsOverlay.ZIndex = 10 
					ActionsOverlay.Active = true 
					Instance.new("UICorner", ActionsOverlay).CornerRadius = UDim.new(0, 6)

					local actLayout = Instance.new("UIListLayout", ActionsOverlay)
					actLayout.Padding = UDim.new(0, 3)
					actLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
					actLayout.VerticalAlignment = Enum.VerticalAlignment.Center

					local buttonConsumed = false
					local function MakeOverlayBtn(text, bgColor)
						local btn = Instance.new("TextButton", ActionsOverlay)
						btn.Size = UDim2.new(0.85, 0, 0, 18)
						btn.BackgroundColor3 = bgColor
						btn.Font = Enum.Font.GothamBold
						btn.TextColor3 = Color3.fromRGB(255, 255, 255)
						btn.TextSize = 8
						btn.Text = text
						btn.ZIndex = 11 
						Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
						return btn
					end

					local equipBtn = MakeOverlayBtn("EQUIP", Color3.fromRGB(40, 80, 40))
					local sellBtn = MakeOverlayBtn("SELL 1x", Color3.fromRGB(80, 35, 35))
					local sellAllBtn = MakeOverlayBtn("SELL ALL", Color3.fromRGB(120, 30, 30))

					local sellVal = SellValues[rarityKey] or 10

					if itemInfo.Type ~= nil then 
						local isEq = (player:GetAttribute("EquippedWeapon") == itemName) or (player:GetAttribute("EquippedAccessory") == itemName)
						if isEq then 
							ApplyButtonGradient(equipBtn, Color3.fromRGB(200, 80, 80), Color3.fromRGB(120, 40, 40), Color3.fromRGB(80, 20, 20))
							equipBtn.Text = "UNEQUIP" 
						else 
							ApplyButtonGradient(equipBtn, Color3.fromRGB(80, 160, 80), Color3.fromRGB(40, 90, 40), Color3.fromRGB(20, 60, 20))
							equipBtn.Text = "EQUIP" 
						end

						equipBtn.MouseButton1Click:Connect(function() 
							buttonConsumed = true
							if isEq then
								Network.EquipItem:FireServer("Unequip_" .. itemInfo.Type)
							else
								Network.EquipItem:FireServer(itemName)
							end
							ActionsOverlay.Visible = false
						end)
					elseif itemInfo.Action ~= nil then 
						ApplyButtonGradient(equipBtn, Color3.fromRGB(140, 80, 200), Color3.fromRGB(80, 40, 140), Color3.fromRGB(60, 20, 100))
						equipBtn.Text = "USE"

						if itemInfo.Buff == "Gamepass" and player:GetAttribute("Has" .. (itemInfo.Unlock or "")) then
							equipBtn.Visible = false
						else
							equipBtn.MouseButton1Click:Connect(function() 
								buttonConsumed = true
								if itemInfo.Action == "AwakenTitan" then Network.AwakenAction:FireServer("Titan") 
								elseif itemInfo.Action == "AwakenClan" then Network.AwakenAction:FireServer("Clan") 
									-- [[ THE FIX: Updated to natively fire the Consume action for Itemized Titans ]]
								elseif itemInfo.Action == "Consume" or itemInfo.Action == "EquipTitan" then Network.ConsumeItem:FireServer(itemName)
								end 
								ActionsOverlay.Visible = false
							end)
						end
					else 
						equipBtn.Visible = false
					end

					sellBtn.MouseButton1Click:Connect(function() 
						buttonConsumed = true
						Network.SellItem:FireServer(itemName, false)
						ActionsOverlay.Visible = false
					end)

					sellAllBtn.MouseButton1Click:Connect(function()
						buttonConsumed = true
						Network.SellItem:FireServer(itemName, true)
						ActionsOverlay.Visible = false
					end)

					local function CloseAllOverlays()
						for _, c in ipairs(InvGrid:GetChildren()) do
							if c.Name == "ItemCard" then
								local ov = c:FindFirstChild("ActionsOverlay")
								if ov then ov.Visible = false end
							end
						end
					end

					btnCover.MouseButton1Click:Connect(function()
						if buttonConsumed then
							buttonConsumed = false
							return
						end
						if ActionsOverlay.Visible then
							ActionsOverlay.Visible = false
						else
							CloseAllOverlays()
							ActionsOverlay.Visible = true
						end
					end)
				end
			end
		end

		InvTitle.Text = "INVENTORY (" .. currentSlotsUsed .. "/" .. MAX_INVENTORY_CAPACITY .. ")"
		if currentSlotsUsed >= MAX_INVENTORY_CAPACITY then InvTitle.TextColor3 = Color3.fromRGB(255, 100, 100) else InvTitle.TextColor3 = Color3.fromRGB(255, 215, 100) end

		task.delay(0.05, function() InvGrid.CanvasSize = UDim2.new(0, 0, 0, math.ceil(layoutOrderCounter / 4) * 85) end)
		task.delay(0.05, function() MainFrame.CanvasSize = UDim2.new(0, 0, 0, mLayout.AbsoluteContentSize.Y + 40) end)
	end
	player.AttributeChanged:Connect(RefreshProfile); RefreshProfile()
end

function ProfileTab.Show() if MainFrame then MainFrame.Visible = true end end
return ProfileTab