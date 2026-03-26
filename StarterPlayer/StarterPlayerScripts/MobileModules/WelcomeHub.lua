-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local WelcomeHub = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local MainFrame, HubPanel, TourOverlay
local DialogBox, SpeakerTxt, DialogTxt, NextBtn
local tutorialConnection = nil

local LBScroll
local currentLBMode = "Prestige"
local isFetchingLB = false

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

-- [[ LEADERBOARD LOGIC ]]
local function RefreshLeaderboard(mode)
	if not LBScroll or isFetchingLB then return end
	isFetchingLB = true
	currentLBMode = mode

	for _, child in ipairs(LBScroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end

	local loadingLbl = Instance.new("TextLabel", LBScroll)
	loadingLbl.Size = UDim2.new(1, 0, 0, 40); loadingLbl.BackgroundTransparency = 1
	loadingLbl.Font = Enum.Font.GothamMedium; loadingLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
	loadingLbl.TextSize = 14; loadingLbl.Text = "Fetching live data..."

	task.spawn(function()
		local success, data = pcall(function()
			return ReplicatedStorage:WaitForChild("Network", 5):WaitForChild("GetLeaderboardData", 5):InvokeServer(mode)
		end)

		if loadingLbl and loadingLbl.Parent then loadingLbl:Destroy() end

		if not success or not data then
			local err = Instance.new("TextLabel", LBScroll)
			err.Size = UDim2.new(1, 0, 0, 40); err.BackgroundTransparency = 1
			err.Font = Enum.Font.GothamMedium; err.TextColor3 = Color3.fromRGB(255, 100, 100)
			err.TextSize = 14; err.Text = "Leaderboard data unavailable."
			isFetchingLB = false
			return
		end

		if #data == 0 then
			local emptyMsg = Instance.new("TextLabel", LBScroll)
			emptyMsg.Size = UDim2.new(1, 0, 0, 40); emptyMsg.BackgroundTransparency = 1
			emptyMsg.Font = Enum.Font.GothamMedium; emptyMsg.TextColor3 = Color3.fromRGB(180, 180, 180)
			emptyMsg.TextSize = 14; emptyMsg.Text = "No players ranked yet!"
			isFetchingLB = false
			return
		end

		for i, entry in ipairs(data) do
			local row = Instance.new("Frame", LBScroll)
			row.Size = UDim2.new(1, -10, 0, 35); row.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
			Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
			Instance.new("UIStroke", row).Color = Color3.fromRGB(50, 50, 60)

			local rankColor = Color3.fromRGB(180, 180, 180)
			if i == 1 then rankColor = Color3.fromRGB(255, 215, 0)
			elseif i == 2 then rankColor = Color3.fromRGB(192, 192, 192)
			elseif i == 3 then rankColor = Color3.fromRGB(205, 127, 50) end

			local rankLbl = Instance.new("TextLabel", row)
			rankLbl.Size = UDim2.new(0, 40, 1, 0); rankLbl.Position = UDim2.new(0, 5, 0, 0)
			rankLbl.BackgroundTransparency = 1; rankLbl.Font = Enum.Font.GothamBlack
			rankLbl.TextColor3 = rankColor; rankLbl.TextSize = 16; rankLbl.Text = "#" .. entry.Rank

			local nameLbl = Instance.new("TextLabel", row)
			nameLbl.Size = UDim2.new(0.6, 0, 1, 0); nameLbl.Position = UDim2.new(0, 50, 0, 0)
			nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamMedium
			nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230); nameLbl.TextSize = 14
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Text = entry.Name

			local valLbl = Instance.new("TextLabel", row)
			valLbl.Size = UDim2.new(0, 80, 1, 0); valLbl.Position = UDim2.new(1, -85, 0, 0)
			valLbl.BackgroundTransparency = 1; valLbl.Font = Enum.Font.GothamBlack
			valLbl.TextColor3 = (mode == "Prestige") and Color3.fromRGB(255, 215, 100) or Color3.fromRGB(100, 150, 255)
			valLbl.TextSize = 16; valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.Text = tostring(entry.Value)

			if entry.Name == player.Name then
				row.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
				row.UIStroke.Color = Color3.fromRGB(100, 100, 200)
			end
		end

		LBScroll.CanvasSize = UDim2.new(0, 0, 0, #data * 40)
		isFetchingLB = false
	end)
end

-- [[ GUIDED CINEMATIC TOUR STATE MACHINE ]]
local RunTourStep
RunTourStep = function(step)
	if tutorialConnection then tutorialConnection:Disconnect(); tutorialConnection = nil end

	if step == 1 then
		SpeakerTxt.Text = "SYSTEM"
		DialogTxt.Text = "Welcome to Attack on Titan: Chronicles! Let's take a guided tour of your HUD so you know where everything is."
		tutorialConnection = NextBtn.MouseButton1Click:Connect(function() RunTourStep(2) end)

	elseif step == 2 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "This is your PROFILE. Here, you will use XP and Dews to upgrade your core Stats and equip new Weapons."
		if _G.AOT_OpenCategory then _G.AOT_OpenCategory("PLAYER") end
		if _G.AOT_SwitchTab then _G.AOT_SwitchTab("Profile") end
		tutorialConnection = NextBtn.MouseButton1Click:Connect(function() RunTourStep(3) end)

	elseif step == 3 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "This is the FORGE. Your inventory has a CAP! You must sell old drops here to make room, or craft Legendary gear."
		if _G.AOT_OpenCategory then _G.AOT_OpenCategory("SUPPLY") end
		if _G.AOT_SwitchTab then _G.AOT_SwitchTab("Forge") end
		tutorialConnection = NextBtn.MouseButton1Click:Connect(function() RunTourStep(4) end)

	elseif step == 4 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "This is EXPEDITIONS. Send your unlocked Allies on AFK missions to gather Dews and XP while you do other things."
		if _G.AOT_OpenCategory then _G.AOT_OpenCategory("OPERATIONS") end
		if _G.AOT_SwitchTab then _G.AOT_SwitchTab("Dispatch") end
		tutorialConnection = NextBtn.MouseButton1Click:Connect(function() RunTourStep(5) end)

	elseif step == 5 then
		SpeakerTxt.Text = "INSTRUCTOR"
		DialogTxt.Text = "This is your COMBAT Map. Deploy to the Campaign, Raids, or Endless mode from here."
		if _G.AOT_SwitchTab then _G.AOT_SwitchTab("Battle") end
		tutorialConnection = NextBtn.MouseButton1Click:Connect(function() RunTourStep(6) end)

	elseif step == 6 then
		NextBtn.Text = "FINISH"
		SpeakerTxt.Text = "SYSTEM"
		DialogTxt.Text = "Tutorial Complete! You are ready to Deploy. Check the main Hub menu if you need to review the Synergy Guide."

		tutorialConnection = NextBtn.MouseButton1Click:Connect(function() 
			TourOverlay.Enabled = false
			NextBtn.Text = "NEXT ➔"
			WelcomeHub.Show(true)
		end)
	end
end

function WelcomeHub.Init(parentFrame)
	local ScreenGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
	if not ScreenGui then return end

	-- ==========================================
	-- GUIDED TOUR OVERLAY
	-- ==========================================
	TourOverlay = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
	TourOverlay.Name = "TutorialTourOverlay"; TourOverlay.DisplayOrder = 1000; TourOverlay.Enabled = false; TourOverlay.IgnoreGuiInset = true

	DialogBox = Instance.new("Frame", TourOverlay); DialogBox.Size = UDim2.new(0.85, 0, 0, 110); DialogBox.Position = UDim2.new(0.5, 0, 0.96, 0); DialogBox.AnchorPoint = Vector2.new(0.5, 1); DialogBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25); DialogBox.ZIndex = 5100
	Instance.new("UICorner", DialogBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", DialogBox).Color = Color3.fromRGB(255, 215, 100); DialogBox.UIStroke.Thickness = 2

	SpeakerTxt = Instance.new("TextLabel", DialogBox); SpeakerTxt.Size = UDim2.new(1, -20, 0, 25); SpeakerTxt.Position = UDim2.new(0, 15, 0, 10); SpeakerTxt.BackgroundTransparency = 1; SpeakerTxt.Font = Enum.Font.GothamBlack; SpeakerTxt.TextColor3 = Color3.fromRGB(255, 215, 100); SpeakerTxt.TextSize = 16; SpeakerTxt.TextXAlignment = Enum.TextXAlignment.Left; SpeakerTxt.ZIndex = 5101
	DialogTxt = Instance.new("TextLabel", DialogBox); DialogTxt.Size = UDim2.new(1, -30, 1, -45); DialogTxt.Position = UDim2.new(0, 15, 0, 35); DialogTxt.BackgroundTransparency = 1; DialogTxt.Font = Enum.Font.GothamMedium; DialogTxt.TextColor3 = Color3.fromRGB(230, 230, 230); DialogTxt.TextSize = 13; DialogTxt.TextWrapped = true; DialogTxt.RichText = true; DialogTxt.TextXAlignment = Enum.TextXAlignment.Left; DialogTxt.TextYAlignment = Enum.TextYAlignment.Top; DialogTxt.ZIndex = 5101

	NextBtn = Instance.new("TextButton", DialogBox); NextBtn.Size = UDim2.new(0.2, 0, 0, 35); NextBtn.Position = UDim2.new(0.98, 0, 0.9, 0); NextBtn.AnchorPoint = Vector2.new(1, 1); NextBtn.Font = Enum.Font.GothamBlack; NextBtn.TextSize = 14; NextBtn.Text = "NEXT ➔"; NextBtn.ZIndex = 5101
	ApplyButtonGradient(NextBtn, Color3.fromRGB(255, 215, 100), Color3.fromRGB(200, 150, 50), Color3.fromRGB(150, 100, 20)); NextBtn.TextColor3 = Color3.fromRGB(25, 25, 30)

	-- ==========================================
	-- THE SPLIT-SCREEN HUB PANEL 
	-- ==========================================
	MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Name = "WelcomeHub"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12); MainFrame.BackgroundTransparency = 0.1; MainFrame.ZIndex = 500; MainFrame.Visible = false; MainFrame.Active = true 

	HubPanel = Instance.new("Frame", MainFrame); HubPanel.Size = UDim2.new(0.9, 0, 0.85, 0); HubPanel.Position = UDim2.new(0.5, 0, 0.5, 0); HubPanel.AnchorPoint = Vector2.new(0.5, 0.5); HubPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	Instance.new("UICorner", HubPanel).CornerRadius = UDim.new(0, 12); Instance.new("UIStroke", HubPanel).Color = Color3.fromRGB(200, 160, 50)
	Instance.new("UIAspectRatioConstraint", HubPanel).AspectRatio = 1.6; Instance.new("UIAspectRatioConstraint", HubPanel).AspectType = Enum.AspectType.FitWithinMaxSize

	local Header = Instance.new("Frame", HubPanel); Header.Size = UDim2.new(1, 0, 0.15, 0); Header.BackgroundTransparency = 1
	local Title = Instance.new("TextLabel", Header); Title.Size = UDim2.new(0.8, 0, 0.5, 0); Title.Position = UDim2.new(0.02, 0, 0.2, 0); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 215, 100); Title.TextSize = 24; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.Text = "ATTACK ON TITAN: CHRONICLES"
	ApplyGradient(Title, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	local ContentArea = Instance.new("Frame", HubPanel); ContentArea.Size = UDim2.new(0.96, 0, 0.65, 0); ContentArea.Position = UDim2.new(0.02, 0, 0.15, 0); ContentArea.BackgroundTransparency = 1

	-- LEFT SIDE (Info)
	local LeftPanel = Instance.new("Frame", ContentArea); LeftPanel.Size = UDim2.new(0.48, 0, 1, 0); LeftPanel.BackgroundTransparency = 1
	local leftLayout = Instance.new("UIListLayout", LeftPanel); leftLayout.SortOrder = Enum.SortOrder.LayoutOrder; leftLayout.Padding = UDim.new(0.05, 0)

	local function CreateSection(parent, titleTxt, bodyTxt, layoutOrder)
		local Section = Instance.new("Frame", parent); Section.Size = UDim2.new(1, 0, 0.47, 0); Section.BackgroundColor3 = Color3.fromRGB(22, 22, 26); Section.LayoutOrder = layoutOrder; Instance.new("UICorner", Section).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", Section).Color = Color3.fromRGB(60, 60, 70)
		local STitle = Instance.new("TextLabel", Section); STitle.Size = UDim2.new(1, 0, 0.15, 0); STitle.BackgroundTransparency = 1; STitle.Font = Enum.Font.GothamBlack; STitle.TextColor3 = Color3.fromRGB(255, 255, 255); STitle.TextSize = 14; STitle.Text = titleTxt
		local SBody = Instance.new("TextLabel", Section); SBody.Size = UDim2.new(0.9, 0, 0.8, 0); SBody.Position = UDim2.new(0.05, 0, 0.15, 0); SBody.BackgroundTransparency = 1; SBody.Font = Enum.Font.GothamMedium; SBody.TextColor3 = Color3.fromRGB(200, 200, 200); SBody.TextSize = 12; SBody.TextXAlignment = Enum.TextXAlignment.Left; SBody.TextYAlignment = Enum.TextYAlignment.Top; SBody.TextWrapped = true; SBody.RichText = true; SBody.Text = bodyTxt
	end

	CreateSection(LeftPanel, "CHANGELOG", "<b>v1.0.0 is LIVE!</b>\n\n• Cinematic Tutorial Tour\n• Secure Player Trading System\n• Regiment Wars & Leaderboards\n• The Paths Endgame Area added\n\nUse Code <b>RELEASE</b> for free rewards!", 1)
	CreateSection(LeftPanel, "QUICK SYNERGIES", "Using skills in sequence creates devastating <font color='#FFD700'>Synergies</font>!\n\n• <b>Maneuver</b> ➔ <b>Nape Strike</b>\n• <b>Basic Slash</b> ➔ <b>Spinning Slash</b>\n• <b>Basic Slash</b> ➔ <b>Dual Slash</b>\n• <b>Evasive Maneuver</b> ➔ <b>Swift Exec.</b>", 2)

	-- RIGHT SIDE (Leaderboard)
	local RightPanel = Instance.new("Frame", ContentArea); RightPanel.Size = UDim2.new(0.48, 0, 1, 0); RightPanel.Position = UDim2.new(0.52, 0, 0, 0); RightPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 26); Instance.new("UICorner", RightPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", RightPanel).Color = Color3.fromRGB(60, 60, 70)

	local LBHeader = Instance.new("TextLabel", RightPanel); LBHeader.Size = UDim2.new(1, 0, 0.1, 0); LBHeader.BackgroundTransparency = 1; LBHeader.Font = Enum.Font.GothamBlack; LBHeader.TextColor3 = Color3.fromRGB(255, 255, 255); LBHeader.TextSize = 14; LBHeader.Text = "GLOBAL LEADERBOARDS"

	local LBTabs = Instance.new("Frame", RightPanel); LBTabs.Size = UDim2.new(0.9, 0, 0.12, 0); LBTabs.Position = UDim2.new(0.05, 0, 0.1, 0); LBTabs.BackgroundTransparency = 1
	local PresBtn = Instance.new("TextButton", LBTabs); PresBtn.Size = UDim2.new(0.48, 0, 1, 0); PresBtn.Font = Enum.Font.GothamBlack; PresBtn.TextSize = 12; PresBtn.Text = "PRESTIGE"; ApplyButtonGradient(PresBtn, Color3.fromRGB(150, 120, 40), Color3.fromRGB(100, 80, 20), Color3.fromRGB(200, 160, 50)); PresBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	local EloBtn = Instance.new("TextButton", LBTabs); EloBtn.Size = UDim2.new(0.48, 0, 1, 0); EloBtn.Position = UDim2.new(0.52, 0, 0, 0); EloBtn.Font = Enum.Font.GothamBlack; EloBtn.TextSize = 12; EloBtn.Text = "PvP ELO"; ApplyButtonGradient(EloBtn, Color3.fromRGB(40, 60, 100), Color3.fromRGB(20, 30, 50), Color3.fromRGB(80, 100, 150)); EloBtn.TextColor3 = Color3.fromRGB(180, 180, 180)

	LBScroll = Instance.new("ScrollingFrame", RightPanel); LBScroll.Size = UDim2.new(0.9, 0, 0.73, 0); LBScroll.Position = UDim2.new(0.05, 0, 0.25, 0); LBScroll.BackgroundTransparency = 1; LBScroll.ScrollBarThickness = 4; LBScroll.BorderSizePixel = 0
	local lbsLayout = Instance.new("UIListLayout", LBScroll); lbsLayout.Padding = UDim.new(0, 4); lbsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	PresBtn.MouseButton1Click:Connect(function()
		ApplyButtonGradient(PresBtn, Color3.fromRGB(150, 120, 40), Color3.fromRGB(100, 80, 20), Color3.fromRGB(200, 160, 50)); PresBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		ApplyButtonGradient(EloBtn, Color3.fromRGB(40, 60, 100), Color3.fromRGB(20, 30, 50), Color3.fromRGB(80, 100, 150)); EloBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
		RefreshLeaderboard("Prestige")
	end)

	EloBtn.MouseButton1Click:Connect(function()
		ApplyButtonGradient(EloBtn, Color3.fromRGB(60, 100, 160), Color3.fromRGB(40, 60, 100), Color3.fromRGB(100, 150, 255)); EloBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		ApplyButtonGradient(PresBtn, Color3.fromRGB(100, 80, 20), Color3.fromRGB(60, 50, 10), Color3.fromRGB(150, 120, 40)); PresBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
		RefreshLeaderboard("Elo")
	end)

	-- FOOTER BUTTONS
	local BtnArea = Instance.new("Frame", HubPanel); BtnArea.Size = UDim2.new(0.96, 0, 0.15, 0); BtnArea.Position = UDim2.new(0.02, 0, 0.82, 0); BtnArea.BackgroundTransparency = 1

	local GuideBtn = Instance.new("TextButton", BtnArea); GuideBtn.Size = UDim2.new(0.48, 0, 1, 0); GuideBtn.Font = Enum.Font.GothamBlack; GuideBtn.TextSize = 16; GuideBtn.Text = "PLAY TUTORIAL"; ApplyButtonGradient(GuideBtn, Color3.fromRGB(120, 80, 160), Color3.fromRGB(60, 40, 80), Color3.fromRGB(80, 50, 120)); GuideBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	local PlayBtn = Instance.new("TextButton", BtnArea); PlayBtn.Size = UDim2.new(0.48, 0, 1, 0); PlayBtn.Position = UDim2.new(0.52, 0, 0, 0); PlayBtn.Font = Enum.Font.GothamBlack; PlayBtn.TextSize = 16; PlayBtn.Text = "DEPLOY TO BASE"; ApplyButtonGradient(PlayBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20)); PlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

	PlayBtn.MouseButton1Click:Connect(function()
		TweenService:Create(MainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		TweenService:Create(HubPanel, TweenInfo.new(0.3), {Position = UDim2.new(0.5, 0, 1.5, 0)}):Play()
		task.wait(0.3); MainFrame.Visible = false
	end)

	GuideBtn.MouseButton1Click:Connect(function()
		MainFrame.Visible = false
		TourOverlay.Enabled = true
		RunTourStep(1)
	end)

	-- [[ LIVE UPDATING: Redraws LB if your stats change while the Hub is open ]]
	task.spawn(function()
		local ls = player:WaitForChild("leaderstats", 10)
		if ls then
			local function updateUI()
				if MainFrame.Visible then RefreshLeaderboard(currentLBMode) end
			end
			if ls:FindFirstChild("Prestige") then ls.Prestige.Changed:Connect(updateUI) end
			if ls:FindFirstChild("Elo") then ls.Elo.Changed:Connect(updateUI) end
		end
	end)
end

function WelcomeHub.Show(force)
	if MainFrame then
		MainFrame.Visible = true; HubPanel.Position = UDim2.new(0.5, 0, 1.5, 0); MainFrame.BackgroundTransparency = 1
		TweenService:Create(MainFrame, TweenInfo.new(0.4), {BackgroundTransparency = 0.1}):Play()
		TweenService:Create(HubPanel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
		RefreshLeaderboard(currentLBMode)
	end
end

return WelcomeHub