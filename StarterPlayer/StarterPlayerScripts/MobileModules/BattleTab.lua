-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local BattleTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))

local player = Players.LocalPlayer
local MainFrame
local ContentArea
local SubTabs = {}
local SubBtns = {}
local cBtns = {}
local rBtns = {}
local CompletionBanner

local pBtn, pStats

local expeditionList = {
	{ Id = 1, Name = "The Fall of Shiganshina", Req = 0, Desc = "The breach of Wall Maria. Survival is the only objective." },
	{ Id = 2, Name = "104th Cadet Corps Training", Req = 0, Desc = "Prove your worth as a cadet. Master your balance." },
	{ Id = 3, Name = "Clash of the Titans", Req = 0, Desc = "Battle at Utgard Castle and the treacherous betrayal." },
	{ Id = 4, Name = "The Uprising", Req = 0, Desc = "Fight the Interior MP and uncover the royal bloodline." },
	{ Id = 5, Name = "Marleyan Assault", Req = 0, Desc = "Infiltrate Liberio. Strike at the heart of the enemy." },
	{ Id = 6, Name = "Return to Shiganshina", Req = 0, Desc = "Reclaim Wall Maria. Beware the beast's pitch." },
	{ Id = 7, Name = "War for Paradis", Req = 0, Desc = "Marley's counterattack. A desperate struggle for the Founder." },
	{ Id = 8, Name = "The Rumbling", Req = 0, Desc = "March of the Wall Titans. The end of all things." }
}

local raidList = {
	{ Id = "Raid_Part1", Name = "Female Titan", Req = 1, Desc = "A deadly raid against a highly intelligent shifter." },
	{ Id = "Raid_Part2", Name = "Armored Titan", Req = 2, Desc = "Pierce the Bastion's armor. Bring Thunder Spears!" },
	{ Id = "Raid_Part3", Name = "Beast Titan", Req = 3, Desc = "Avoid the crushed boulders. A terrifying intellect." },
	{ Id = "Raid_Part5", Name = "Founding Titan (Eren)", Req = 5, Desc = "The Coordinate commands all. Survive the Rumbling." }
}

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
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

local function TweenGradient(grad, targetTop, targetBot, duration)
	local startTop = grad.Color.Keypoints[1].Value
	local startBot = grad.Color.Keypoints[#grad.Color.Keypoints].Value
	local val = Instance.new("NumberValue"); val.Value = 0
	local tween = TweenService:Create(val, TweenInfo.new(duration), {Value = 1})
	val.Changed:Connect(function(v)
		grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, startTop:Lerp(targetTop, v)), ColorSequenceKeypoint.new(1, startBot:Lerp(targetBot, v))}
	end)
	tween:Play(); tween.Completed:Connect(function() val:Destroy() end)
end

function BattleTab.Init(parentFrame)
	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "BattleFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 100, 100); Title.TextSize = 22; Title.Text = "COMBAT OPERATIONS"
	ApplyGradient(Title, Color3.fromRGB(255, 150, 150), Color3.fromRGB(200, 50, 50))

	local TopNav = Instance.new("ScrollingFrame", MainFrame)
	TopNav.Size = UDim2.new(1, 0, 0, 45); TopNav.Position = UDim2.new(0, 0, 0, 40); TopNav.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	TopNav.ScrollBarThickness = 0; TopNav.ScrollingDirection = Enum.ScrollingDirection.X; TopNav.BorderSizePixel = 0
	Instance.new("UICorner", TopNav).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", TopNav).Color = Color3.fromRGB(80, 40, 40)

	local navLayout = Instance.new("UIListLayout", TopNav)
	navLayout.FillDirection = Enum.FillDirection.Horizontal; navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left; navLayout.VerticalAlignment = Enum.VerticalAlignment.Center; navLayout.Padding = UDim.new(0, 10)
	local navPad = Instance.new("UIPadding", TopNav); navPad.PaddingLeft = UDim.new(0, 10); navPad.PaddingRight = UDim.new(0, 10)
	navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TopNav.CanvasSize = UDim2.new(0, navLayout.AbsoluteContentSize.X + 20, 0, 0) end)

	ContentArea = Instance.new("Frame", MainFrame)
	ContentArea.Size = UDim2.new(1, 0, 1, -95); ContentArea.Position = UDim2.new(0, 0, 0, 95); ContentArea.BackgroundTransparency = 1

	local function CreateSubNavBtn(name, text)
		local btn = Instance.new("TextButton", TopNav)
		btn.Size = UDim2.new(0, 140, 0, 30)
		btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(180, 180, 180); btn.TextSize = 11; btn.Text = text
		ApplyButtonGradient(btn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 65))

		btn.MouseButton1Click:Connect(function()
			for k, v in pairs(SubBtns) do 
				local cGrad = v:FindFirstChildOfClass("UIGradient")
				if cGrad then TweenGradient(cGrad, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), 0.2) end
				TweenService:Create(v, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play() 
			end
			local grad = btn:FindFirstChildOfClass("UIGradient")
			if grad then TweenGradient(grad, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), 0.2) end
			TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()

			for k, frame in pairs(SubTabs) do frame.Visible = (k == name) end
		end)
		SubBtns[name] = btn
		return btn
	end

	CreateSubNavBtn("Campaign", "CAMPAIGN")
	CreateSubNavBtn("Endless", "ENDLESS EXPEDITION")
	CreateSubNavBtn("Paths", "THE PATHS")
	CreateSubNavBtn("Raids", "MULTIPLAYER RAIDS")
	CreateSubNavBtn("World", "WORLD BOSSES")

	SubTabs["Campaign"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Campaign"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Campaign"].BackgroundTransparency = 1; SubTabs["Campaign"].BorderSizePixel = 0; SubTabs["Campaign"].ScrollBarThickness = 0; SubTabs["Campaign"].Visible = true
	local cListLayout = Instance.new("UIListLayout", SubTabs["Campaign"]); cListLayout.Padding = UDim.new(0, 10); cListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; cListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local cPad = Instance.new("UIPadding", SubTabs["Campaign"]); cPad.PaddingTop = UDim.new(0, 10); cPad.PaddingBottom = UDim.new(0, 20)

	CompletionBanner = Instance.new("TextLabel", SubTabs["Campaign"])
	CompletionBanner.Size = UDim2.new(0.95, 0, 0, 50); CompletionBanner.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
	CompletionBanner.Font = Enum.Font.GothamBlack; CompletionBanner.TextColor3 = Color3.fromRGB(255, 215, 100); CompletionBanner.TextSize = 13; CompletionBanner.TextWrapped = true
	CompletionBanner.Text = "STORY COMPLETE! Replay missions to max your stats and Prestige."
	CompletionBanner.LayoutOrder = 0; CompletionBanner.Visible = false
	Instance.new("UICorner", CompletionBanner).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", CompletionBanner).Color = Color3.fromRGB(200, 150, 50)

	for _, dInfo in ipairs(expeditionList) do
		local card = Instance.new("Frame", SubTabs["Campaign"])
		card.Size = UDim2.new(0.95, 0, 0, 105); card.BackgroundColor3 = Color3.fromRGB(20, 20, 25); card.LayoutOrder = dInfo.Id
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(50, 50, 60); stroke.Thickness = 1.5; stroke.Transparency = 0.5; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local accentBar = Instance.new("Frame", card); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255); accentBar.BorderSizePixel = 0; Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(1, -20, 0, 20); title.Position = UDim2.new(0, 15, 0, 10); title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack; title.TextColor3 = Color3.fromRGB(255, 255, 255); title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = dInfo.Name

		local desc = Instance.new("TextLabel", card)
		desc.Size = UDim2.new(1, -20, 0, 35); desc.Position = UDim2.new(0, 15, 0, 30); desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(160, 160, 170); desc.TextSize = 11; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = dInfo.Desc

		local btn = Instance.new("TextButton", card)
		btn.Size = UDim2.new(0.4, 0, 0, 28); btn.AnchorPoint = Vector2.new(1, 0); btn.Position = UDim2.new(1, -10, 1, -35)
		btn.Font = Enum.Font.GothamBlack; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 12; btn.Text = "DEPLOY"
		ApplyButtonGradient(btn, Color3.fromRGB(25, 35, 25), Color3.fromRGB(15, 20, 15), Color3.fromRGB(80, 180, 80))

		btn.MouseButton1Click:Connect(function() if btn.Active then Network:WaitForChild("CombatAction"):FireServer("EngageStory", {PartId = dInfo.Id}) end end)
		cBtns[dInfo.Id] = { Btn = btn, Stroke = stroke, Accent = accentBar }
	end

	SubTabs["Endless"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Endless"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Endless"].BackgroundTransparency = 1; SubTabs["Endless"].Visible = false; SubTabs["Endless"].ScrollBarThickness = 0
	SubTabs["Endless"].AutomaticCanvasSize = Enum.AutomaticSize.Y
	local eLayout = Instance.new("UIListLayout", SubTabs["Endless"]); eLayout.Padding = UDim.new(0, 10); eLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local ePad = Instance.new("UIPadding", SubTabs["Endless"]); ePad.PaddingTop = UDim.new(0, 10); ePad.PaddingBottom = UDim.new(0, 20)

	local eBox = Instance.new("Frame", SubTabs["Endless"])
	eBox.Size = UDim2.new(0.95, 0, 0, 220); eBox.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	Instance.new("UICorner", eBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", eBox).Color = Color3.fromRGB(150, 100, 255); eBox.UIStroke.Thickness = 1.5

	local eTitle = Instance.new("TextLabel", eBox)
	eTitle.Size = UDim2.new(1, 0, 0, 50); eTitle.BackgroundTransparency = 1; eTitle.Font = Enum.Font.GothamBlack; eTitle.TextColor3 = Color3.fromRGB(220, 150, 255); eTitle.TextSize = 20; eTitle.Text = "ENDLESS EXPEDITION"

	local eDesc = Instance.new("TextLabel", eBox)
	eDesc.Size = UDim2.new(0.9, 0, 0, 80); eDesc.Position = UDim2.new(0.05, 0, 0, 50); eDesc.BackgroundTransparency = 1
	eDesc.Font = Enum.Font.GothamMedium; eDesc.TextColor3 = Color3.fromRGB(180, 180, 190); eDesc.TextSize = 13; eDesc.TextWrapped = true; eDesc.Text = "Venture beyond the walls continuously. Fight random enemies scaling with your Campaign progress. Drops are multiplied by 1.2x."

	local eBtn = Instance.new("TextButton", eBox)
	eBtn.Size = UDim2.new(0.7, 0, 0, 45); eBtn.AnchorPoint = Vector2.new(0.5, 0); eBtn.Position = UDim2.new(0.5, 0, 1, -60)
	eBtn.Font = Enum.Font.GothamBlack; eBtn.TextColor3 = Color3.fromRGB(220, 150, 255); eBtn.TextSize = 16; eBtn.Text = "DEPART"
	ApplyButtonGradient(eBtn, Color3.fromRGB(35, 20, 45), Color3.fromRGB(20, 10, 25), Color3.fromRGB(150, 80, 200))

	eBtn.MouseButton1Click:Connect(function() Network:WaitForChild("CombatAction"):FireServer("EngageEndless") end)

	SubTabs["Paths"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Paths"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Paths"].BackgroundTransparency = 1; SubTabs["Paths"].Visible = false; SubTabs["Paths"].ScrollBarThickness = 0
	local pathsLayout = Instance.new("UIListLayout", SubTabs["Paths"]); pathsLayout.FillDirection = Enum.FillDirection.Vertical; pathsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; pathsLayout.Padding = UDim.new(0, 15)
	local pPad = Instance.new("UIPadding", SubTabs["Paths"]); pPad.PaddingTop = UDim.new(0, 10); pPad.PaddingBottom = UDim.new(0, 20)

	local pBox = Instance.new("Frame", SubTabs["Paths"])
	pBox.Size = UDim2.new(0.95, 0, 0, 260); pBox.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	Instance.new("UICorner", pBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", pBox).Color = Color3.fromRGB(100, 200, 255); pBox.UIStroke.Thickness = 1.5

	local pTitleLbl = Instance.new("TextLabel", pBox)
	pTitleLbl.Size = UDim2.new(1, 0, 0, 50); pTitleLbl.BackgroundTransparency = 1; pTitleLbl.Font = Enum.Font.GothamBlack; pTitleLbl.TextColor3 = Color3.fromRGB(255, 255, 255); pTitleLbl.TextSize = 22; pTitleLbl.Text = "THE PATHS"
	ApplyGradient(pTitleLbl, Color3.fromRGB(150, 200, 255), Color3.fromRGB(200, 100, 255))

	local pDesc = Instance.new("TextLabel", pBox)
	pDesc.Size = UDim2.new(0.9, 0, 0, 100); pDesc.Position = UDim2.new(0.05, 0, 0, 50); pDesc.BackgroundTransparency = 1
	pDesc.Font = Enum.Font.GothamMedium; pDesc.TextColor3 = Color3.fromRGB(180, 180, 190); pDesc.TextSize = 13; pDesc.TextWrapped = true
	pDesc.Text = "Face brutally mutated memories that scale infinitely in power to earn <font color='#55FFFF'>Path Dust</font>.\n\n<font color='#AA55FF'>Only those who have stopped The Rumbling may enter.</font>"; pDesc.RichText = true

	pStats = Instance.new("TextLabel", pBox)
	pStats.Size = UDim2.new(1, 0, 0, 20); pStats.Position = UDim2.new(0, 0, 0, 160); pStats.BackgroundTransparency = 1
	pStats.Font = Enum.Font.GothamBlack; pStats.TextColor3 = Color3.fromRGB(150, 255, 255); pStats.TextSize = 13
	pStats.Text = "MEMORY: 1   |   DUST: 0"

	pBtn = Instance.new("TextButton", pBox)
	pBtn.Size = UDim2.new(0.7, 0, 0, 45); pBtn.AnchorPoint = Vector2.new(0.5, 0); pBtn.Position = UDim2.new(0.5, 0, 1, -60)
	pBtn.Font = Enum.Font.GothamBlack; pBtn.TextColor3 = Color3.fromRGB(150, 200, 255); pBtn.TextSize = 15; pBtn.Text = "ENTER THE PATHS"
	ApplyButtonGradient(pBtn, Color3.fromRGB(25, 25, 35), Color3.fromRGB(15, 15, 20), Color3.fromRGB(100, 150, 255))
	pBtn.MouseButton1Click:Connect(function() if pBtn.Active then Network:WaitForChild("CombatAction"):FireServer("EngagePaths") end end)

	pathsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SubTabs["Paths"].CanvasSize = UDim2.new(0, 0, 0, pathsLayout.AbsoluteContentSize.Y + 30) end)

	SubTabs["Raids"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Raids"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Raids"].BackgroundTransparency = 1; SubTabs["Raids"].BorderSizePixel = 0; SubTabs["Raids"].ScrollBarThickness = 0; SubTabs["Raids"].Visible = false
	local rListLayout = Instance.new("UIListLayout", SubTabs["Raids"]); rListLayout.Padding = UDim.new(0, 10); rListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; rListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local rPad = Instance.new("UIPadding", SubTabs["Raids"]); rPad.PaddingTop = UDim.new(0, 10); rPad.PaddingBottom = UDim.new(0, 20)

	for _, rInfo in ipairs(raidList) do
		local card = Instance.new("Frame", SubTabs["Raids"])
		card.Size = UDim2.new(0.95, 0, 0, 105); card.BackgroundColor3 = Color3.fromRGB(20, 20, 25); card.LayoutOrder = rInfo.Req
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(60, 50, 50); stroke.Thickness = 1.5; stroke.Transparency = 0.5; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local accentBar = Instance.new("Frame", card); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(180, 60, 60); accentBar.BorderSizePixel = 0; Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(1, -20, 0, 20); title.Position = UDim2.new(0, 15, 0, 10); title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack; title.TextColor3 = Color3.fromRGB(255, 100, 100); title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = rInfo.Name

		local desc = Instance.new("TextLabel", card)
		desc.Size = UDim2.new(1, -20, 1, -45); desc.Position = UDim2.new(0, 15, 0, 30); desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(180, 170, 170); desc.TextSize = 11; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = rInfo.Desc

		local btn = Instance.new("TextButton", card)
		btn.Size = UDim2.new(0.4, 0, 0, 28); btn.AnchorPoint = Vector2.new(1, 0); btn.Position = UDim2.new(1, -10, 1, -35)
		btn.Font = Enum.Font.GothamBlack; btn.TextColor3 = Color3.fromRGB(255, 100, 100); btn.TextSize = 11; btn.Text = "HOST LOBBY"
		ApplyButtonGradient(btn, Color3.fromRGB(35, 20, 20), Color3.fromRGB(20, 10, 10), Color3.fromRGB(180, 60, 60))

		btn.MouseButton1Click:Connect(function() if btn.Active then Network:WaitForChild("RaidAction"):FireServer("CreateLobby", {RaidId = rInfo.Id, FriendsOnly = false}) end end)
		rBtns[rInfo.Id] = { Btn = btn, Req = rInfo.Req, Stroke = stroke, Accent = accentBar }
	end

	SubTabs["World"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["World"].Size = UDim2.new(1, 0, 1, 0); SubTabs["World"].BackgroundTransparency = 1; SubTabs["World"].BorderSizePixel = 0; SubTabs["World"].ScrollBarThickness = 0; SubTabs["World"].Visible = false
	local wListLayout = Instance.new("UIListLayout", SubTabs["World"]); wListLayout.Padding = UDim.new(0, 10); wListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; wListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local wPad = Instance.new("UIPadding", SubTabs["World"]); wPad.PaddingTop = UDim.new(0, 10); wPad.PaddingBottom = UDim.new(0, 20)

	local sortedBosses = {}
	for bId, bData in pairs(EnemyData.WorldBosses) do table.insert(sortedBosses, {Id = bId, Data = bData}) end
	table.sort(sortedBosses, function(a, b) return (a.Data.Health or 0) < (b.Data.Health or 0) end)

	for _, bInfo in ipairs(sortedBosses) do
		local bId = bInfo.Id; local bData = bInfo.Data

		local card = Instance.new("Frame", SubTabs["World"])
		card.Size = UDim2.new(0.95, 0, 0, 105); card.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(80, 60, 40); stroke.Thickness = 1.5; stroke.Transparency = 0.5; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local accentBar = Instance.new("Frame", card); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(200, 120, 50); accentBar.BorderSizePixel = 0; Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(1, -20, 0, 20); title.Position = UDim2.new(0, 15, 0, 10); title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold; title.TextColor3 = Color3.fromRGB(255, 180, 50); title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = bData.Name

		local desc = Instance.new("TextLabel", card)
		desc.Size = UDim2.new(1, -20, 1, -45); desc.Position = UDim2.new(0, 15, 0, 30); desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(180, 170, 160); desc.TextSize = 11; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = bData.Desc or "A massive world boss event."

		local btn = Instance.new("TextButton", card)
		btn.Size = UDim2.new(0.4, 0, 0, 28); btn.AnchorPoint = Vector2.new(1, 0); btn.Position = UDim2.new(1, -10, 1, -35)
		btn.Font = Enum.Font.GothamBlack; btn.TextColor3 = Color3.fromRGB(255, 180, 50); btn.TextSize = 11; btn.Text = "ENGAGE"
		ApplyButtonGradient(btn, Color3.fromRGB(40, 30, 20), Color3.fromRGB(20, 15, 10), Color3.fromRGB(200, 120, 50))

		btn.MouseButton1Click:Connect(function() Network:WaitForChild("CombatAction"):FireServer("EngageWorldBoss", {BossId = bId}) end)
	end


	local function UpdateLocks()
		local currentPart = player:GetAttribute("CurrentPart") or 1
		local prestigeObj = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige")
		local prestige = prestigeObj and prestigeObj.Value or 0

		local floor = player:GetAttribute("PathsFloor") or 1
		local dust = player:GetAttribute("PathDust") or 0
		if pStats then pStats.Text = "MEMORY: " .. floor .. "   |   DUST: " .. dust end

		if currentPart > 8 then
			if CompletionBanner then CompletionBanner.Visible = true end
			if pBtn then 
				ApplyButtonGradient(pBtn, Color3.fromRGB(25, 20, 35), Color3.fromRGB(15, 10, 20), Color3.fromRGB(100, 150, 255))
				pBtn.Text = "ENTER THE PATHS"; pBtn.TextColor3 = Color3.fromRGB(150, 200, 255); pBtn.Active = true 
			end
		else
			if CompletionBanner then CompletionBanner.Visible = false end
			if pBtn then 
				ApplyButtonGradient(pBtn, Color3.fromRGB(25, 25, 30), Color3.fromRGB(15, 15, 20), Color3.fromRGB(60, 60, 70))
				pBtn.Text = "LOCKED"; pBtn.TextColor3 = Color3.fromRGB(120, 120, 120); pBtn.Active = false 
			end
		end

		for id, data in pairs(cBtns) do
			if currentPart > id then
				ApplyButtonGradient(data.Btn, Color3.fromRGB(20, 30, 40), Color3.fromRGB(15, 20, 30), Color3.fromRGB(80, 140, 220))
				data.Btn.Text = "REPLAY"; data.Btn.TextColor3 = Color3.fromRGB(150, 200, 255); data.Btn.Active = true 
				data.Stroke.Color = Color3.fromRGB(60, 80, 120); data.Accent.BackgroundColor3 = Color3.fromRGB(80, 140, 220)
			elseif currentPart == id then
				ApplyButtonGradient(data.Btn, Color3.fromRGB(25, 40, 25), Color3.fromRGB(15, 25, 15), Color3.fromRGB(80, 180, 80))
				data.Btn.Text = "DEPLOY"; data.Btn.TextColor3 = Color3.fromRGB(150, 255, 150); data.Btn.Active = true
				data.Stroke.Color = Color3.fromRGB(60, 100, 60); data.Accent.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
			else
				ApplyButtonGradient(data.Btn, Color3.fromRGB(25, 25, 30), Color3.fromRGB(15, 15, 20), Color3.fromRGB(60, 60, 70))
				data.Btn.Text = "LOCKED"; data.Btn.TextColor3 = Color3.fromRGB(120, 120, 120); data.Btn.Active = false
				data.Stroke.Color = Color3.fromRGB(40, 40, 50); data.Accent.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			end
		end

		for _, data in pairs(rBtns) do
			if prestige < data.Req then
				ApplyButtonGradient(data.Btn, Color3.fromRGB(25, 25, 30), Color3.fromRGB(15, 15, 20), Color3.fromRGB(60, 60, 70))
				data.Btn.Text = "LOCKED"; data.Btn.TextColor3 = Color3.fromRGB(120, 120, 120); data.Btn.Active = false
				data.Stroke.Color = Color3.fromRGB(40, 40, 50); data.Accent.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			else
				ApplyButtonGradient(data.Btn, Color3.fromRGB(40, 25, 25), Color3.fromRGB(25, 15, 15), Color3.fromRGB(180, 60, 60))
				data.Btn.Text = "HOST LOBBY"; data.Btn.TextColor3 = Color3.fromRGB(255, 150, 150); data.Btn.Active = true
				data.Stroke.Color = Color3.fromRGB(100, 50, 50); data.Accent.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
			end
		end

		task.delay(0.05, function() SubTabs["Campaign"].CanvasSize = UDim2.new(0, 0, 0, cListLayout.AbsoluteContentSize.Y + 40) end)
		task.delay(0.05, function() SubTabs["Raids"].CanvasSize = UDim2.new(0, 0, 0, rListLayout.AbsoluteContentSize.Y + 40) end)
		task.delay(0.05, function() SubTabs["World"].CanvasSize = UDim2.new(0, 0, 0, wListLayout.AbsoluteContentSize.Y + 40) end)
	end

	local lastKnownPart = player:GetAttribute("CurrentPart") or 1
	player.AttributeChanged:Connect(function(attr)
		if attr == "CurrentPart" then
			local newPart = player:GetAttribute("CurrentPart") or 1
			lastKnownPart = newPart
			UpdateLocks()
		elseif attr == "PathsFloor" or attr == "PathDust" then UpdateLocks() end
	end)

	task.spawn(function()
		local pObj = player:WaitForChild("leaderstats", 10) and player.leaderstats:WaitForChild("Prestige", 10)
		if pObj then pObj.Changed:Connect(UpdateLocks) end
		UpdateLocks()
		local cGrad = SubBtns["Campaign"]:FindFirstChildOfClass("UIGradient")
		if cGrad then TweenGradient(cGrad, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), 0) end
		TweenService:Create(SubBtns["Campaign"], TweenInfo.new(0), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)

	Network:WaitForChild("CombatUpdate").OnClientEvent:Connect(function(action, data)
		if (action == "Defeat" or action == "Fled") and data.Battle and data.Battle.Context.IsPaths then
			for k, frame in pairs(SubTabs) do frame.Visible = (k == "Paths") end
			for k, v in pairs(SubBtns) do 
				local btnGrad = v:FindFirstChildOfClass("UIGradient")
				if btnGrad then TweenGradient(btnGrad, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), 0) end
				TweenService:Create(v, TweenInfo.new(0), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play() 
			end
			local pGrad = SubBtns["Paths"]:FindFirstChildOfClass("UIGradient")
			if pGrad then TweenGradient(pGrad, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), 0) end
			TweenService:Create(SubBtns["Paths"], TweenInfo.new(0), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		end
	end)
end

function BattleTab.Show() if MainFrame then MainFrame.Visible = true end end

return BattleTab