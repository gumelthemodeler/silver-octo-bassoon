-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local WelcomeHub = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local MainFrame, HubPanel
local TourGui, Blocker, DialogBox, SpeakerTxt, DialogTxt, NextBtn
local MaskTop, MaskBottom, MaskLeft, MaskRight, HighlightFrame
local InterceptorBtn

local activeTarget = nil
local interceptingTarget = false
local tutorialConnection = nil
local waitingForElement = false

local CombatSimPanel, T_LogText, ActionGrid, TargetMenu
local EnemyHPBar
local glowTweens = {}

-- [[ UI STYLING HELPERS ]]
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
		stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
		btn:GetPropertyChangedSignal("RichText"):Connect(function() textLbl.RichText = btn.RichText end)
	end
end

local function HighlightSimBtn(btn, color)
	local topC = Color3.new(math.clamp(color.R * 1.2, 0, 1), math.clamp(color.G * 1.2, 0, 1), math.clamp(color.B * 1.2, 0, 1))
	local botC = Color3.new(math.clamp(color.R * 0.7, 0, 1), math.clamp(color.G * 0.7, 0, 1), math.clamp(color.B * 0.7, 0, 1))
	ApplyButtonGradient(btn, topC, botC, color)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)

	local glow = btn:FindFirstChild("TutorialGlow") or Instance.new("UIStroke", btn)
	glow.Name = "TutorialGlow"; glow.Color = Color3.fromRGB(255, 255, 100); glow.Thickness = 3
	if glowTweens[btn] then glowTweens[btn]:Cancel() end
	local t = TweenService:Create(glow, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 1})
	t:Play(); glowTweens[btn] = t
end

local function DimSimBtn(btn, baseColor)
	local c = baseColor or Color3.fromRGB(30, 30, 35)
	local botC = Color3.new(math.clamp(c.R * 0.7, 0, 1), math.clamp(c.G * 0.7, 0, 1), math.clamp(c.B * 0.7, 0, 1))
	ApplyButtonGradient(btn, c, botC, Color3.fromRGB(50, 50, 55))
	btn.TextColor3 = Color3.fromRGB(120, 120, 120)
	if glowTweens[btn] then glowTweens[btn]:Cancel(); glowTweens[btn] = nil end
	local glow = btn:FindFirstChild("TutorialGlow"); if glow then glow:Destroy() end
end

-- [[ ROBUST REAL UI FINDERS ]]
local function FindNavCategory(name)
	local pg = player:WaitForChild("PlayerGui")
	local aot = pg:FindFirstChild("AOT_Interface")
	if not aot then return nil end
	for _, obj in ipairs(aot:GetDescendants()) do
		if obj:IsA("TextLabel") and obj.Text == name then
			if obj.Parent and obj.Parent:IsA("TextButton") and obj.Parent.AbsoluteSize.X > 0 and obj.Parent.Visible then return obj.Parent end
		end
	end
	return nil
end

local function FindNavTab(btnName)
	local pg = player:WaitForChild("PlayerGui")
	local aot = pg:FindFirstChild("AOT_Interface")
	if not aot then return nil end
	local target = aot:FindFirstChild(btnName, true)
	if target and target:IsA("TextButton") and target.AbsoluteSize.Y > 5 and target.Visible then
		local isVis = true; local cur = target
		while cur and cur:IsA("GuiObject") do
			if not cur.Visible then isVis = false; break end
			cur = cur.Parent
		end
		if isVis then return target end
	end
	return nil
end

local function FindDeployBtn()
	local pg = player:WaitForChild("PlayerGui")
	local aot = pg:FindFirstChild("AOT_Interface")
	if not aot then return nil end
	for _, obj in ipairs(aot:GetDescendants()) do
		if obj:IsA("TextButton") and obj.Text:upper():match("DEPLOY") then
			if obj.AbsoluteSize.X > 0 and obj.Visible then
				local isVis = true; local cur = obj
				while cur and cur:IsA("GuiObject") do
					if not cur.Visible then isVis = false; break end
					cur = cur.Parent
				end
				if isVis then return obj end
			end
		end
	end
	return nil
end

local function WaitForTarget(finderFunc, intercept, callback)
	waitingForElement = true
	interceptingTarget = intercept
	task.spawn(function()
		local elem = nil
		while waitingForElement and not elem do
			elem = finderFunc()
			task.wait(0.2)
		end
		if waitingForElement then
			waitingForElement = false
			activeTarget = elem
			if intercept then
				tutorialConnection = InterceptorBtn.MouseButton1Click:Connect(callback)
			else
				tutorialConnection = elem.MouseButton1Click:Connect(callback)
			end
		end
	end)
end

-- [[ COMBAT SIMULATOR BUILDER ]]
local function BuildCombatSim()
	if CombatSimPanel then CombatSimPanel:Destroy() end

	CombatSimPanel = Instance.new("Frame", TourGui)
	CombatSimPanel.Size = UDim2.new(0, 750, 0, 520); CombatSimPanel.Position = UDim2.new(0.5, 0, 0.42, 0); CombatSimPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	CombatSimPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 20); CombatSimPanel.Visible = false; CombatSimPanel.ZIndex = 500
	Instance.new("UICorner", CombatSimPanel).CornerRadius = UDim.new(0, 12)
	local outerStroke = Instance.new("UIStroke", CombatSimPanel); outerStroke.Thickness = 3; outerStroke.Color = Color3.fromRGB(200, 160, 50)
	Instance.new("UIAspectRatioConstraint", CombatSimPanel).AspectRatio = 750 / 520

	local mainLayout = Instance.new("UIListLayout", CombatSimPanel); mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.Padding = UDim.new(0, 10); mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local mainPadding = Instance.new("UIPadding", CombatSimPanel); mainPadding.PaddingTop = UDim.new(0, 10); mainPadding.PaddingBottom = UDim.new(0, 10)

	local WaveLabel = Instance.new("TextLabel", CombatSimPanel); WaveLabel.Size = UDim2.new(1, 0, 0, 20); WaveLabel.BackgroundTransparency = 1; WaveLabel.Font = Enum.Font.GothamBlack; WaveLabel.TextColor3 = Color3.fromRGB(255, 215, 100); WaveLabel.TextSize = 18; WaveLabel.Text = "TUTORIAL - 104TH CADET CORPS"; WaveLabel.LayoutOrder = 1; ApplyGradient(WaveLabel, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	local CombatantsFrame = Instance.new("Frame", CombatSimPanel); CombatantsFrame.Size = UDim2.new(0.96, 0, 0, 100); CombatantsFrame.BackgroundTransparency = 1; CombatantsFrame.LayoutOrder = 2

	local function CreateBar(parent, c1, c2, size, txt, alignR)
		local c = Instance.new("Frame", parent); c.Size = size; c.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Instance.new("UICorner", c).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", c).Color = Color3.fromRGB(80, 80, 90)
		local f = Instance.new("Frame", c); f.Size = UDim2.new(1, 0, 1, 0); f.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
		if alignR then f.AnchorPoint = Vector2.new(1, 0); f.Position = UDim2.new(1, 0, 0, 0) end
		local grad = Instance.new("UIGradient", f); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2)}; grad.Rotation = 90
		local t = Instance.new("TextLabel", c); t.Size = UDim2.new(1, -10, 1, 0); t.Position = UDim2.new(0, alignR and 0 or 5, 0, 0); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextColor3 = Color3.fromRGB(255, 255, 255); t.TextSize = 11; t.TextStrokeTransparency = 0.5; t.Text = txt; t.TextXAlignment = alignR and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left; t.ZIndex = 5
		return f
	end

	local pPanel = Instance.new("Frame", CombatantsFrame); pPanel.Size = UDim2.new(0.46, 0, 1, 0); pPanel.BackgroundTransparency = 1
	local pAvatar = Instance.new("Frame", pPanel); pAvatar.Size = UDim2.new(0, 80, 0, 80); pAvatar.Position = UDim2.new(0, 0, 0.5, 0); pAvatar.AnchorPoint = Vector2.new(0, 0.5); pAvatar.BackgroundColor3 = Color3.fromRGB(10, 10, 15); Instance.new("UIStroke", pAvatar).Color = Color3.fromRGB(80, 120, 200); Instance.new("UIStroke", pAvatar).Thickness = 2
	local pImg = Instance.new("ImageLabel", pAvatar); pImg.Size = UDim2.new(1, 0, 1, 0); pImg.BackgroundTransparency = 1; pImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
	local pStats = Instance.new("Frame", pPanel); pStats.Size = UDim2.new(1, -90, 1, 0); pStats.Position = UDim2.new(0, 90, 0, 0); pStats.BackgroundTransparency = 1; local psLayout = Instance.new("UIListLayout", pStats); psLayout.Padding = UDim.new(0, 4); psLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local pName = Instance.new("TextLabel", pStats); pName.Size = UDim2.new(1, 0, 0, 15); pName.BackgroundTransparency = 1; pName.Font = Enum.Font.GothamBlack; pName.TextColor3 = Color3.fromRGB(200, 220, 255); pName.TextSize = 14; pName.TextXAlignment = Enum.TextXAlignment.Left; pName.Text = player.Name
	CreateBar(pStats, Color3.fromRGB(220, 60, 60), Color3.fromRGB(140, 30, 30), UDim2.new(1, 0, 0, 14), "HP: 100", false)
	CreateBar(pStats, Color3.fromRGB(150, 220, 255), Color3.fromRGB(60, 140, 200), UDim2.new(1, 0, 0, 12), "GAS: 100", false)

	local vs = Instance.new("TextLabel", CombatantsFrame); vs.Size = UDim2.new(0.08, 0, 1, 0); vs.Position = UDim2.new(0.46, 0, 0, 0); vs.BackgroundTransparency = 1; vs.Font = Enum.Font.GothamBlack; vs.TextColor3 = Color3.fromRGB(100, 100, 110); vs.TextSize = 24; vs.Text = "VS"

	local ePanel = Instance.new("Frame", CombatantsFrame); ePanel.Size = UDim2.new(0.46, 0, 1, 0); ePanel.Position = UDim2.new(0.54, 0, 0, 0); ePanel.BackgroundTransparency = 1
	local eAvatar = Instance.new("Frame", ePanel); eAvatar.Size = UDim2.new(0, 80, 0, 80); eAvatar.Position = UDim2.new(1, 0, 0.5, 0); eAvatar.AnchorPoint = Vector2.new(1, 0.5); eAvatar.BackgroundColor3 = Color3.fromRGB(0, 0, 0); Instance.new("UIStroke", eAvatar).Color = Color3.fromRGB(255, 100, 100); Instance.new("UIStroke", eAvatar).Thickness = 2
	local eIcon = Instance.new("TextLabel", eAvatar); eIcon.Size = UDim2.new(1, 0, 1, 0); eIcon.BackgroundTransparency = 1; eIcon.Font = Enum.Font.GothamBlack; eIcon.TextColor3 = Color3.fromRGB(200, 50, 50); eIcon.TextScaled = true; eIcon.Text = "?"
	local eStats = Instance.new("Frame", ePanel); eStats.Size = UDim2.new(1, -90, 1, 0); eStats.Position = UDim2.new(0, 0, 0, 0); eStats.BackgroundTransparency = 1; local esLayout = Instance.new("UIListLayout", eStats); esLayout.Padding = UDim.new(0, 4); esLayout.VerticalAlignment = Enum.VerticalAlignment.Center; esLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local eName = Instance.new("TextLabel", eStats); eName.Size = UDim2.new(1, 0, 0, 15); eName.BackgroundTransparency = 1; eName.Font = Enum.Font.GothamBlack; eName.TextColor3 = Color3.fromRGB(255, 120, 120); eName.TextSize = 14; eName.TextXAlignment = Enum.TextXAlignment.Right; eName.Text = "WOODEN TITAN DUMMY"
	EnemyHPBar = CreateBar(eStats, Color3.fromRGB(220, 60, 60), Color3.fromRGB(140, 30, 30), UDim2.new(1, 0, 0, 14), "HP: 100", true)

	local FeedBox = Instance.new("Frame", CombatSimPanel); FeedBox.Size = UDim2.new(0.96, 0, 0, 90); FeedBox.BackgroundColor3 = Color3.fromRGB(22, 22, 26); FeedBox.LayoutOrder = 3; Instance.new("UICorner", FeedBox).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", FeedBox).Color = Color3.fromRGB(60, 60, 70)
	T_LogText = Instance.new("TextLabel", FeedBox); T_LogText.Size = UDim2.new(1, -20, 1, -10); T_LogText.Position = UDim2.new(0, 10, 0, 5); T_LogText.BackgroundTransparency = 1; T_LogText.Font = Enum.Font.GothamMedium; T_LogText.TextColor3 = Color3.fromRGB(230, 230, 230); T_LogText.TextSize = 13; T_LogText.TextXAlignment = Enum.TextXAlignment.Left; T_LogText.TextYAlignment = Enum.TextYAlignment.Bottom; T_LogText.RichText = true; T_LogText.Text = "<i>Holographic Simulator Initialized...</i>"

	local BottomArea = Instance.new("Frame", CombatSimPanel); BottomArea.Size = UDim2.new(0.96, 0, 0, 180); BottomArea.BackgroundTransparency = 1; BottomArea.LayoutOrder = 4

	ActionGrid = Instance.new("Frame", BottomArea); ActionGrid.Size = UDim2.new(1, 0, 1, 0); ActionGrid.BackgroundTransparency = 1
	local gridLayout = Instance.new("UIGridLayout", ActionGrid); gridLayout.CellSize = UDim2.new(0, 170, 0, 45); gridLayout.CellPadding = UDim2.new(0, 8, 0, 12); gridLayout.SortOrder = Enum.SortOrder.LayoutOrder; gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	TargetMenu = Instance.new("Frame", BottomArea); TargetMenu.Size = UDim2.new(1, 0, 1, -10); TargetMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TargetMenu.Visible = false; Instance.new("UICorner", TargetMenu).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", TargetMenu).Color = Color3.fromRGB(80, 80, 90)
	local InfoPanel = Instance.new("Frame", TargetMenu); InfoPanel.Size = UDim2.new(0.45, 0, 1, 0); InfoPanel.BackgroundTransparency = 1
	local tHoverTitle = Instance.new("TextLabel", InfoPanel); tHoverTitle.Size = UDim2.new(1, -20, 0, 30); tHoverTitle.Position = UDim2.new(0, 20, 0, 15); tHoverTitle.BackgroundTransparency = 1; tHoverTitle.Font = Enum.Font.GothamBlack; tHoverTitle.TextColor3 = Color3.fromRGB(255, 215, 100); tHoverTitle.TextSize = 20; tHoverTitle.TextXAlignment = Enum.TextXAlignment.Left; tHoverTitle.Text = "SELECT TARGET"
	local tHoverDesc = Instance.new("TextLabel", InfoPanel); tHoverDesc.Size = UDim2.new(1, -20, 0, 100); tHoverDesc.Position = UDim2.new(0, 20, 0, 60); tHoverDesc.BackgroundTransparency = 1; tHoverDesc.Font = Enum.Font.GothamMedium; tHoverDesc.TextColor3 = Color3.fromRGB(200, 200, 200); tHoverDesc.TextSize = 13; tHoverDesc.TextXAlignment = Enum.TextXAlignment.Left; tHoverDesc.TextYAlignment = Enum.TextYAlignment.Top; tHoverDesc.TextWrapped = true; tHoverDesc.Text = "Hover over a limb to see its tactical advantage."

	local BodyContainer = Instance.new("Frame", TargetMenu); BodyContainer.Size = UDim2.new(0.5, 0, 1, -20); BodyContainer.Position = UDim2.new(0.5, 0, 0, 10); BodyContainer.BackgroundTransparency = 1
	Instance.new("UIAspectRatioConstraint", BodyContainer).AspectRatio = 0.8
end

-- [[ THE TOUR STATE MACHINE ]]
local RunTourStep
RunTourStep = function(step)
	if tutorialConnection then tutorialConnection:Disconnect(); tutorialConnection = nil end
	waitingForElement = false; activeTarget = nil
	NextBtn.Visible = false
	if CombatSimPanel then CombatSimPanel.Visible = false end

	if step == 1 then
		SpeakerTxt.Text = "SYSTEM"
		DialogTxt.Text = "Welcome to Attack on Titan: Chronicles! Let's take a tour of the actual menus so you know where everything is."
		NextBtn.Visible = true
		tutorialConnection = NextBtn.MouseButton1Click:Connect(function() RunTourStep(2) end)

	elseif step == 2 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Your Menus are grouped into Categories. Let's find your Gear. Click the [PLAYER] category to expand it."
		WaitForTarget(function() return FindNavCategory("PLAYER") end, false, function(btn)
			activeTarget = btn
			tutorialConnection = btn.MouseButton1Click:Connect(function() RunTourStep(3) end)
		end)

	elseif step == 3 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Click the [PROFILE] tab. Here, you will use XP and Dews to upgrade your core Stats and equip new Weapons."
		WaitForTarget(function() return FindNavTab("ProfileBtn") end, false, function(btn)
			activeTarget = btn
			tutorialConnection = btn.MouseButton1Click:Connect(function() RunTourStep(4) end)
		end)

	elseif step == 4 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Your inventory has a CAP. You must sell old drops to make room for new ones. Click the [SUPPLY] category."
		WaitForTarget(function() return FindNavCategory("SUPPLY") end, false, function(btn)
			activeTarget = btn
			tutorialConnection = btn.MouseButton1Click:Connect(function() RunTourStep(5) end)
		end)

	elseif step == 5 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Click the [FORGE] tab. This is where you sell items for Dews and craft powerful Legendary gear."
		WaitForTarget(function() return FindNavTab("ForgeBtn") end, false, function(btn)
			activeTarget = btn
			tutorialConnection = btn.MouseButton1Click:Connect(function() RunTourStep(6) end)
		end)

	elseif step == 6 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Time to learn about missions. Click the [OPERATIONS] category."
		WaitForTarget(function() return FindNavCategory("OPERATIONS") end, false, function(btn)
			activeTarget = btn
			tutorialConnection = btn.MouseButton1Click:Connect(function() RunTourStep(7) end)
		end)

	elseif step == 7 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Click the [COMBAT] tab. This opens your Operations Map to deploy to the Campaign, Raids, or Endless mode."
		WaitForTarget(function() return FindNavTab("BattleBtn") end, false, function(btn)
			activeTarget = btn
			tutorialConnection = btn.MouseButton1Click:Connect(function() RunTourStep(8) end)
		end)

	elseif step == 8 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Find the '104th Cadet Corps' mission and click [DEPLOY] to launch a simulated training battle."
		WaitForTarget(function() return FindDeployBtn() end, true, function() -- [[ INTERCEPTED SO IT DOESN'T ACTUALLY START A BATTLE ]]
			InterceptorBtn.Visible = false
			RunTourStep(9)
		end)

	elseif step == 9 then
		activeTarget = nil
		BuildCombatSim()
		CombatSimPanel.Visible = true
		ActionGrid.Visible = true; TargetMenu.Visible = false

		local function MakeMockAction(name, order)
			local btn = Instance.new("TextButton", ActionGrid); btn.Name = name:gsub("%s+", "") .. "Btn"; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.LayoutOrder = order; btn.Text = name:upper() .. "\n<font size='9' color='#AAAAAA'>[READY]</font>"; btn.RichText = true
			DimSimBtn(btn, Color3.fromRGB(30, 30, 35)); return btn
		end
		local btnBasic = MakeMockAction("Basic Slash", 1); local btnManeuver = MakeMockAction("Maneuver", 2); local btnSpinning = MakeMockAction("Spinning Slash", 3)

		local function MakeMockTarget(name, size, pos)
			local btn = Instance.new("TextButton", TargetMenu.BodyContainer); btn.Name = name .. "Btn"; btn.Size = size; btn.Position = pos; btn.Font = Enum.Font.GothamBlack; btn.TextSize = 12; btn.Text = name:upper(); btn.AnchorPoint = Vector2.new(0.5, 0.5); DimSimBtn(btn, Color3.fromRGB(30, 30, 35)); return btn
		end
		MakeMockTarget("Eyes", UDim2.new(0.24, 0, 0.18, 0), UDim2.new(0.5, 0, 0.08, 0)); MakeMockTarget("Nape", UDim2.new(0.24, 0, 0.06, 0), UDim2.new(0.5, 0, 0.22, 0)); MakeMockTarget("Body", UDim2.new(0.48, 0, 0.38, 0), UDim2.new(0.5, 0, 0.45, 0))

		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Combat requires GAS and HEAT. Click [MANEUVER] to evade attacks and position yourself."
		HighlightSimBtn(ActionGrid.ManeuverBtn, Color3.fromRGB(40, 80, 140))
		tutorialConnection = ActionGrid.ManeuverBtn.MouseButton1Click:Connect(function() RunTourStep(10) end)

	elseif step == 10 then
		CombatSimPanel.Visible = true; ActionGrid.Visible = true
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Maneuvering lets you dodge. Now, let's start a Synergy chain. Click your [BASIC SLASH] skill."
		DimSimBtn(ActionGrid.ManeuverBtn, Color3.fromRGB(30, 30, 35))
		HighlightSimBtn(ActionGrid.BasicSlashBtn, Color3.fromRGB(120, 40, 40))
		tutorialConnection = ActionGrid.BasicSlashBtn.MouseButton1Click:Connect(function() RunTourStep(11) end)

	elseif step == 11 then
		CombatSimPanel.Visible = true; ActionGrid.Visible = false; TargetMenu.Visible = true
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Target selection is vital. Aim for the [BODY]."
		DimSimBtn(ActionGrid.BasicSlashBtn, Color3.fromRGB(30, 30, 35))
		local tBody = TargetMenu.BodyContainer.BodyBtn
		HighlightSimBtn(tBody, Color3.fromRGB(80, 160, 80))
		tutorialConnection = tBody.MouseButton1Click:Connect(function() RunTourStep(12) end)

	elseif step == 12 then
		CombatSimPanel.Visible = true; ActionGrid.Visible = true; TargetMenu.Visible = false
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Basic Slash primed your next attack! Look at [SPINNING SLASH]. The Synergy is ready! Click it to execute!"
		T_LogText.Text = "You struck the Body for 150 Damage."
		TweenService:Create(EnemyHPBar, TweenInfo.new(0.3), {Size = UDim2.new(0.6, 0, 1, 0)}):Play()
		DimSimBtn(TargetMenu.BodyContainer.BodyBtn, Color3.fromRGB(30, 30, 35))
		HighlightSimBtn(ActionGrid.SpinningSlashBtn, Color3.fromRGB(60, 40, 80))
		tutorialConnection = ActionGrid.SpinningSlashBtn.MouseButton1Click:Connect(function() RunTourStep(13) end)

	elseif step == 13 then
		CombatSimPanel.Visible = true; ActionGrid.Visible = false; TargetMenu.Visible = true
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "Finish the combo! Aim for the [NAPE] to maximize the multiplier!"
		DimSimBtn(ActionGrid.SpinningSlashBtn, Color3.fromRGB(30, 30, 35))
		local tNape = TargetMenu.BodyContainer.NapeBtn
		HighlightSimBtn(tNape, Color3.fromRGB(220, 80, 80))
		tutorialConnection = tNape.MouseButton1Click:Connect(function() RunTourStep(14) end)

	elseif step == 14 then
		CombatSimPanel.Visible = true; ActionGrid.Visible = true; TargetMenu.Visible = false
		SpeakerTxt.Text = "SYSTEM"
		DialogTxt.Text = "Tutorial Complete! Synergies deal massive bonus damage. Check the Hub for the Synergy Guide. You are ready to Deploy!"
		T_LogText.Text = "<font color='#FFD700'><b>[SYNERGY: Basic Slash -> Spinning Slash]</b></font>\nYou struck the Nape for 9,999 DMG!\n<b><font color='#55FF55'>ENEMY DEFEATED!</font></b>"
		TweenService:Create(EnemyHPBar, TweenInfo.new(0.3), {Size = UDim2.new(0, 0, 1, 0)}):Play()
		DimSimBtn(TargetMenu.BodyContainer.NapeBtn, Color3.fromRGB(30, 30, 35))

		NextBtn.Visible = true; NextBtn.Text = "FINISH"
		tutorialConnection = NextBtn.MouseButton1Click:Connect(function() 
			TourGui.Enabled = false
			NextBtn.Text = "NEXT ➔"
			WelcomeHub.Show(true)
		end)
	end
end

function WelcomeHub.Init(parentFrame)
	local ScreenGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
	if not ScreenGui then return end

	-- ==========================================
	-- THE MASKING OVERLAY (Hole-Punch System)
	-- ==========================================
	TourGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
	TourGui.Name = "TutorialTourOverlay"; TourGui.DisplayOrder = 1000; TourGui.Enabled = false; TourGui.IgnoreGuiInset = true -- [[ CRITICAL FIX FOR HIGHLIGHT OFFSET ]]

	local function MakeMask()
		local f = Instance.new("TextButton", TourGui); f.BackgroundColor3 = Color3.new(0, 0, 0); f.BackgroundTransparency = 0.65
		f.AutoButtonColor = false; f.Text = ""; f.Active = true -- BLOCKS ALL CLICKS
		return f
	end
	MaskTop = MakeMask(); MaskBottom = MakeMask(); MaskLeft = MakeMask(); MaskRight = MakeMask()

	HighlightFrame = Instance.new("Frame", TourGui); HighlightFrame.BackgroundTransparency = 1
	local hlStroke = Instance.new("UIStroke", HighlightFrame); hlStroke.Color = Color3.fromRGB(255, 215, 100); hlStroke.Thickness = 4
	TweenService:Create(hlStroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 1}):Play()

	InterceptorBtn = Instance.new("TextButton", TourGui); InterceptorBtn.Name = "TutorialInterceptor"; InterceptorBtn.BackgroundTransparency = 1; InterceptorBtn.Text = ""; InterceptorBtn.ZIndex = 5000; InterceptorBtn.Visible = false

	-- [[ MATH SAFEGUARD: Prevents Negative Size Errors ]]
	local function SafeDim(val)
		if val ~= val or val == math.huge or val == -math.huge then return 0 end
		return val
	end

	RunService.RenderStepped:Connect(function()
		if not TourGui.Enabled then return end
		local screen = TourGui.AbsoluteSize

		if activeTarget and activeTarget.Parent and activeTarget.AbsoluteSize.X > 0 then
			local isVis = true; local cur = activeTarget
			while cur and cur:IsA("GuiObject") do
				if not cur.Visible then isVis = false break end
				cur = cur.Parent
			end

			if isVis then
				local pos = activeTarget.AbsolutePosition; local size = activeTarget.AbsoluteSize
				local pad = 6

				local tX = math.max(0, pos.X - pad); local tY = math.max(0, pos.Y - pad)
				local tW = math.clamp(size.X + (pad * 2), 0, screen.X - tX)
				local tH = math.clamp(size.Y + (pad * 2), 0, screen.Y - tY)

				local bottomH = math.max(0, screen.Y - (tY + tH))
				local rightW = math.max(0, screen.X - (tX + tW))

				MaskTop.Size = UDim2.new(1, 0, 0, SafeDim(tY)); MaskTop.Position = UDim2.new(0, 0, 0, 0); MaskTop.Visible = true
				MaskBottom.Size = UDim2.new(1, 0, 0, SafeDim(bottomH)); MaskBottom.Position = UDim2.new(0, 0, 0, SafeDim(tY + tH)); MaskBottom.Visible = true
				MaskLeft.Size = UDim2.new(0, SafeDim(tX), 0, SafeDim(tH)); MaskLeft.Position = UDim2.new(0, 0, 0, SafeDim(tY)); MaskLeft.Visible = true
				MaskRight.Size = UDim2.new(0, SafeDim(rightW), 0, SafeDim(tH)); MaskRight.Position = UDim2.new(0, SafeDim(tX + tW), 0, SafeDim(tY)); MaskRight.Visible = true

				HighlightFrame.Position = UDim2.new(0, SafeDim(tX), 0, SafeDim(tY)); HighlightFrame.Size = UDim2.new(0, SafeDim(tW), 0, SafeDim(tH)); HighlightFrame.Visible = true

				if interceptingTarget then
					InterceptorBtn.Position = UDim2.new(0, SafeDim(pos.X), 0, SafeDim(pos.Y))
					InterceptorBtn.Size = UDim2.new(0, SafeDim(size.X), 0, SafeDim(size.Y))
					InterceptorBtn.Visible = true
				else
					InterceptorBtn.Visible = false
				end
				return
			end
		end
		MaskTop.Size = UDim2.new(1, 0, 1, 0); MaskTop.Position = UDim2.new(0, 0, 0, 0); MaskTop.Visible = true
		MaskBottom.Visible = false; MaskLeft.Visible = false; MaskRight.Visible = false; HighlightFrame.Visible = false; InterceptorBtn.Visible = false
	end)

	DialogBox = Instance.new("Frame", TourGui); DialogBox.Size = UDim2.new(0.85, 0, 0, 110); DialogBox.Position = UDim2.new(0.5, 0, 0.96, 0); DialogBox.AnchorPoint = Vector2.new(0.5, 1); DialogBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25); DialogBox.ZIndex = 100
	Instance.new("UICorner", DialogBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", DialogBox).Color = Color3.fromRGB(255, 215, 100); DialogBox.UIStroke.Thickness = 2

	SpeakerTxt = Instance.new("TextLabel", DialogBox); SpeakerTxt.Size = UDim2.new(1, -20, 0, 25); SpeakerTxt.Position = UDim2.new(0, 15, 0, 10); SpeakerTxt.BackgroundTransparency = 1; SpeakerTxt.Font = Enum.Font.GothamBlack; SpeakerTxt.TextColor3 = Color3.fromRGB(255, 215, 100); SpeakerTxt.TextSize = 16; SpeakerTxt.TextXAlignment = Enum.TextXAlignment.Left; SpeakerTxt.ZIndex = 101
	DialogTxt = Instance.new("TextLabel", DialogBox); DialogTxt.Size = UDim2.new(1, -30, 1, -45); DialogTxt.Position = UDim2.new(0, 15, 0, 35); DialogTxt.BackgroundTransparency = 1; DialogTxt.Font = Enum.Font.GothamMedium; DialogTxt.TextColor3 = Color3.fromRGB(230, 230, 230); DialogTxt.TextSize = 13; DialogTxt.TextWrapped = true; DialogTxt.RichText = true; DialogTxt.TextXAlignment = Enum.TextXAlignment.Left; DialogTxt.TextYAlignment = Enum.TextYAlignment.Top; DialogTxt.ZIndex = 101

	NextBtn = Instance.new("TextButton", DialogBox); NextBtn.Size = UDim2.new(0.2, 0, 0, 35); NextBtn.Position = UDim2.new(0.98, 0, 0.9, 0); NextBtn.AnchorPoint = Vector2.new(1, 1); NextBtn.Font = Enum.Font.GothamBlack; NextBtn.TextSize = 14; NextBtn.Text = "NEXT ➔"; NextBtn.ZIndex = 101
	ApplyButtonGradient(NextBtn, Color3.fromRGB(255, 215, 100), Color3.fromRGB(200, 150, 50), Color3.fromRGB(150, 100, 20)); NextBtn.TextColor3 = Color3.fromRGB(25, 25, 30)


	-- ==========================================
	-- THE MAIN HUB PANEL (Always starts here)
	-- ==========================================
	MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Name = "WelcomeHub"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12); MainFrame.BackgroundTransparency = 0.1; MainFrame.ZIndex = 500; MainFrame.Visible = false; MainFrame.Active = true 

	HubPanel = Instance.new("Frame", MainFrame); HubPanel.Size = UDim2.new(0.9, 0, 0.85, 0); HubPanel.Position = UDim2.new(0.5, 0, 0.5, 0); HubPanel.AnchorPoint = Vector2.new(0.5, 0.5); HubPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	Instance.new("UICorner", HubPanel).CornerRadius = UDim.new(0, 12); Instance.new("UIStroke", HubPanel).Color = Color3.fromRGB(200, 160, 50)
	Instance.new("UIAspectRatioConstraint", HubPanel).AspectRatio = 1.6; Instance.new("UIAspectRatioConstraint", HubPanel).AspectType = Enum.AspectType.FitWithinMaxSize

	local Header = Instance.new("Frame", HubPanel); Header.Size = UDim2.new(1, 0, 0.2, 0); Header.BackgroundTransparency = 1
	local Title = Instance.new("TextLabel", Header); Title.Size = UDim2.new(0.8, 0, 0.5, 0); Title.Position = UDim2.new(0.05, 0, 0.2, 0); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 215, 100); Title.TextSize = 24; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.Text = "ATTACK ON TITAN: CHRONICLES"
	ApplyGradient(Title, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	local ContentArea = Instance.new("Frame", HubPanel); ContentArea.Size = UDim2.new(0.96, 0, 0.55, 0); ContentArea.Position = UDim2.new(0.02, 0, 0.22, 0); ContentArea.BackgroundTransparency = 1
	local contentLayout = Instance.new("UIListLayout", ContentArea); contentLayout.FillDirection = Enum.FillDirection.Horizontal; contentLayout.Padding = UDim.new(0.02, 0); contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function CreateSection(titleTxt, bodyTxt, layoutOrder)
		local Section = Instance.new("Frame", ContentArea); Section.Size = UDim2.new(0.32, 0, 1, 0); Section.BackgroundColor3 = Color3.fromRGB(22, 22, 26); Section.LayoutOrder = layoutOrder; Instance.new("UICorner", Section).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", Section).Color = Color3.fromRGB(60, 60, 70)
		local STitle = Instance.new("TextLabel", Section); STitle.Size = UDim2.new(1, 0, 0.15, 0); STitle.BackgroundTransparency = 1; STitle.Font = Enum.Font.GothamBlack; STitle.TextColor3 = Color3.fromRGB(255, 255, 255); STitle.TextSize = 14; STitle.Text = titleTxt
		local SBody = Instance.new("TextLabel", Section); SBody.Size = UDim2.new(0.9, 0, 0.8, 0); SBody.Position = UDim2.new(0.05, 0, 0.15, 0); SBody.BackgroundTransparency = 1; SBody.Font = Enum.Font.GothamMedium; SBody.TextColor3 = Color3.fromRGB(200, 200, 200); SBody.TextSize = 12; SBody.TextXAlignment = Enum.TextXAlignment.Left; SBody.TextYAlignment = Enum.TextYAlignment.Top; SBody.TextWrapped = true; SBody.RichText = true; SBody.Text = bodyTxt
	end

	CreateSection("CHANGELOG", "<b>v1.0.0 is LIVE!</b>\n\n• Interactive Tutorial Experience\n• Secure Player Trading System\n• Regiment Wars & Leaderboards\n• The Paths Endgame Area added\n\nUse Code <b>RELEASE</b> for free rewards!", 1)
	CreateSection("QUICK SYNERGIES", "Using skills in sequence creates devastating <font color='#FFD700'>Synergies</font>!\n\n• <b>Maneuver</b> ➔ <b>Nape Strike</b>\n• <b>Basic Slash</b> ➔ <b>Spinning Slash</b>\n• <b>Basic Slash</b> ➔ <b>Dual Slash</b>\n• <b>Evasive Maneuver</b> ➔ <b>Swift Exec.</b>", 2)
	CreateSection("LEADERBOARDS", "Prove you are humanity's strongest soldier!\n\nCheck the physical <b>Leaderboard Statues</b> located in the main Hub to view the Top 50 Global Players sorted by:\n\n• Highest Prestige\n• PvP Elo Rating", 3)

	local BtnArea = Instance.new("Frame", HubPanel); BtnArea.Size = UDim2.new(0.96, 0, 0.15, 0); BtnArea.Position = UDim2.new(0.02, 0, 0.82, 0); BtnArea.BackgroundTransparency = 1

	local GuideBtn = Instance.new("TextButton", BtnArea); GuideBtn.Size = UDim2.new(0.48, 0, 1, 0); GuideBtn.Font = Enum.Font.GothamBlack; GuideBtn.TextSize = 16; GuideBtn.Text = "REPLAY TUTORIAL"; ApplyButtonGradient(GuideBtn, Color3.fromRGB(120, 80, 160), Color3.fromRGB(60, 40, 80), Color3.fromRGB(80, 50, 120)); GuideBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	local PlayBtn = Instance.new("TextButton", BtnArea); PlayBtn.Size = UDim2.new(0.48, 0, 1, 0); PlayBtn.Position = UDim2.new(0.52, 0, 0, 0); PlayBtn.Font = Enum.Font.GothamBlack; PlayBtn.TextSize = 16; PlayBtn.Text = "DEPLOY TO BASE"; ApplyButtonGradient(PlayBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20)); PlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

	PlayBtn.MouseButton1Click:Connect(function()
		TweenService:Create(MainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		TweenService:Create(HubPanel, TweenInfo.new(0.3), {Position = UDim2.new(0.5, 0, 1.5, 0)}):Play()
		task.wait(0.3); MainFrame.Visible = false
	end)

	GuideBtn.MouseButton1Click:Connect(function()
		MainFrame.Visible = false
		TourGui.Enabled = true
		DimSimBtn(GuideBtn, Color3.fromRGB(60, 40, 80))
		GuideBtn.Text = "REPLAY TUTORIAL"
		RunTourStep(1)
	end)

	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if not player:GetAttribute("HasSeenHub") then
			GuideBtn.Text = "PLAY TUTORIAL (RECOMMENDED)"
			HighlightSimBtn(GuideBtn, Color3.fromRGB(120, 80, 160))
		end
	end)
end

function WelcomeHub.Show(force)
	if MainFrame then
		if force or not player:GetAttribute("HasSeenHub") then
			if not force then player:GetAttributeChangedSignal("DataLoaded"):Wait() end
			player:SetAttribute("HasSeenHub", true)
			MainFrame.Visible = true; HubPanel.Position = UDim2.new(0.5, 0, 1.5, 0); MainFrame.BackgroundTransparency = 1
			TweenService:Create(MainFrame, TweenInfo.new(0.4), {BackgroundTransparency = 0.1}):Play()
			TweenService:Create(HubPanel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
		end
	end
end

return WelcomeHub