-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local WelcomeHub = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local MainFrame, HubPanel, SynergyPanel, TourOverlay
local DialogBox, SpeakerTxt, DialogTxt, NextBtn
local tutorialConnection = nil

local LBScroll
local currentLBMode = "Prestige"
local isFetchingLB = false

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
			rankLbl.Size = UDim2.new(0, 30, 1, 0); rankLbl.Position = UDim2.new(0, 5, 0, 0)
			rankLbl.BackgroundTransparency = 1; rankLbl.Font = Enum.Font.GothamBlack
			rankLbl.TextColor3 = rankColor; rankLbl.TextSize = 14; rankLbl.Text = "#" .. entry.Rank

			local nameLbl = Instance.new("TextLabel", row)
			nameLbl.Size = UDim2.new(0.5, 0, 1, 0); nameLbl.Position = UDim2.new(0, 40, 0, 0)
			nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamMedium
			nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230); nameLbl.TextSize = 12
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.TextScaled = true; nameLbl.Text = entry.Name

			local valLbl = Instance.new("TextLabel", row)
			valLbl.Size = UDim2.new(0, 60, 1, 0); valLbl.Position = UDim2.new(1, -65, 0, 0)
			valLbl.BackgroundTransparency = 1; valLbl.Font = Enum.Font.GothamBlack
			valLbl.TextColor3 = (mode == "Prestige") and Color3.fromRGB(255, 215, 100) or Color3.fromRGB(100, 150, 255)
			valLbl.TextSize = 14; valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.Text = tostring(entry.Value)

			if entry.Name == player.Name then
				row.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
				row.UIStroke.Color = Color3.fromRGB(100, 100, 200)
			end
		end

		LBScroll.CanvasSize = UDim2.new(0, 0, 0, #data * 40)
		isFetchingLB = false
	end)
end

local RunTourStep
RunTourStep = function(step)
	if tutorialConnection then tutorialConnection:Disconnect(); tutorialConnection = nil end

	if step == 1 then
		SpeakerTxt.Text = "SYSTEM"
		DialogTxt.Text = "Welcome to Attack on Titan: Incremental! Let's take a guided tour of your HUD so you know where everything is."
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
			NextBtn.Text = "NEXT ->"
			WelcomeHub.Show(true)
		end)
	end
end

function WelcomeHub.Init(parentFrame)
	local ScreenGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
	if not ScreenGui then return end

	TourOverlay = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
	TourOverlay.Name = "TutorialTourOverlay"; TourOverlay.DisplayOrder = 1000; TourOverlay.Enabled = false; TourOverlay.IgnoreGuiInset = true

	DialogBox = Instance.new("Frame", TourOverlay); DialogBox.Size = UDim2.new(0.9, 0, 0, 110); DialogBox.Position = UDim2.new(0.5, 0, 0.95, 0); DialogBox.AnchorPoint = Vector2.new(0.5, 1); DialogBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25); DialogBox.ZIndex = 5100
	Instance.new("UICorner", DialogBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", DialogBox).Color = Color3.fromRGB(255, 215, 100); DialogBox.UIStroke.Thickness = 2

	SpeakerTxt = Instance.new("TextLabel", DialogBox); SpeakerTxt.Size = UDim2.new(1, -20, 0, 25); SpeakerTxt.Position = UDim2.new(0, 10, 0, 5); SpeakerTxt.BackgroundTransparency = 1; SpeakerTxt.Font = Enum.Font.GothamBlack; SpeakerTxt.TextColor3 = Color3.fromRGB(255, 215, 100); SpeakerTxt.TextSize = 14; SpeakerTxt.TextXAlignment = Enum.TextXAlignment.Left; SpeakerTxt.ZIndex = 5101
	DialogTxt = Instance.new("TextLabel", DialogBox); DialogTxt.Size = UDim2.new(1, -20, 1, -40); DialogTxt.Position = UDim2.new(0, 10, 0, 30); DialogTxt.BackgroundTransparency = 1; DialogTxt.Font = Enum.Font.GothamMedium; DialogTxt.TextColor3 = Color3.fromRGB(230, 230, 230); DialogTxt.TextSize = 11; DialogTxt.TextWrapped = true; DialogTxt.RichText = true; DialogTxt.TextXAlignment = Enum.TextXAlignment.Left; DialogTxt.TextYAlignment = Enum.TextYAlignment.Top; DialogTxt.ZIndex = 5101

	NextBtn = Instance.new("TextButton", DialogBox); NextBtn.Size = UDim2.new(0.25, 0, 0, 30); NextBtn.Position = UDim2.new(0.98, 0, 0.9, 0); NextBtn.AnchorPoint = Vector2.new(1, 1); NextBtn.Font = Enum.Font.GothamBlack; NextBtn.TextSize = 12; NextBtn.Text = "NEXT ->"; NextBtn.ZIndex = 5101
	ApplyButtonGradient(NextBtn, Color3.fromRGB(255, 215, 100), Color3.fromRGB(200, 150, 50), Color3.fromRGB(150, 100, 20)); NextBtn.TextColor3 = Color3.fromRGB(25, 25, 30)

	MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Name = "WelcomeHub"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12); MainFrame.BackgroundTransparency = 0.1; MainFrame.ZIndex = 500; MainFrame.Visible = false; MainFrame.Active = true 

	-- [[ THE FIX: Use a regular frame for the Panel so the pattern doesn't get messed up by UIListLayout ]]
	HubPanel = Instance.new("Frame", MainFrame)
	HubPanel.Size = UDim2.new(0.95, 0, 0.9, 0)
	HubPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
	HubPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	HubPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	HubPanel.ClipsDescendants = true
	Instance.new("UICorner", HubPanel).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", HubPanel).Color = Color3.fromRGB(255, 215, 100)
	HubPanel.UIStroke.Thickness = 2

	local bgPattern = Instance.new("ImageLabel", HubPanel)
	bgPattern.Size = UDim2.new(1.5, 0, 1.5, 0); bgPattern.Position = UDim2.new(0.5, 0, 0.5, 0); bgPattern.AnchorPoint = Vector2.new(0.5, 0.5)
	bgPattern.BackgroundTransparency = 1; bgPattern.Image = "rbxassetid://319692171"; bgPattern.ImageTransparency = 0.95; bgPattern.ImageColor3 = Color3.fromRGB(255, 215, 100)
	bgPattern.ScaleType = Enum.ScaleType.Tile; bgPattern.TileSize = UDim2.new(0, 100, 0, 100); bgPattern.ZIndex = 0

	-- [[ THE FIX: Separate Scrolling Container for the actual Content ]]
	local HubScroll = Instance.new("ScrollingFrame", HubPanel)
	HubScroll.Size = UDim2.new(1, 0, 1, 0)
	HubScroll.BackgroundTransparency = 1
	HubScroll.ScrollBarThickness = 0
	HubScroll.ZIndex = 1

	local hpLayout = Instance.new("UIListLayout", HubScroll); hpLayout.SortOrder = Enum.SortOrder.LayoutOrder; hpLayout.Padding = UDim.new(0, 10); hpLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local hpPad = Instance.new("UIPadding", HubScroll); hpPad.PaddingTop = UDim.new(0, 15); hpPad.PaddingBottom = UDim.new(0, 20)

	local Title = Instance.new("TextLabel", HubScroll); Title.Size = UDim2.new(0.9, 0, 0, 30); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 215, 100); Title.TextSize = 18; Title.TextXAlignment = Enum.TextXAlignment.Center; Title.Text = "ATTACK ON TITAN: INCREMENTAL"; Title.LayoutOrder = 1
	ApplyGradient(Title, Color3.fromRGB(255, 235, 150), Color3.fromRGB(255, 150, 50))

	local function CreateSection(parent, titleTxt, bodyTxt, layoutOrder)
		local Section = Instance.new("Frame", parent); Section.Size = UDim2.new(0.95, 0, 0, 0); Section.AutomaticSize = Enum.AutomaticSize.Y; Section.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Section.LayoutOrder = layoutOrder; Instance.new("UICorner", Section).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", Section).Color = Color3.fromRGB(100, 80, 40)
		local slayout = Instance.new("UIListLayout", Section); slayout.Padding = UDim.new(0, 5)
		local spad = Instance.new("UIPadding", Section); spad.PaddingTop = UDim.new(0, 10); spad.PaddingBottom = UDim.new(0, 10); spad.PaddingLeft = UDim.new(0, 10); spad.PaddingRight = UDim.new(0, 10)
		local STitle = Instance.new("TextLabel", Section); STitle.Size = UDim2.new(1, 0, 0, 20); STitle.BackgroundTransparency = 1; STitle.Font = Enum.Font.GothamBlack; STitle.TextColor3 = Color3.fromRGB(255, 215, 100); STitle.TextSize = 14; STitle.Text = titleTxt; STitle.TextXAlignment = Enum.TextXAlignment.Left
		local SBody = Instance.new("TextLabel", Section); SBody.Size = UDim2.new(1, 0, 0, 0); SBody.AutomaticSize = Enum.AutomaticSize.Y; SBody.BackgroundTransparency = 1; SBody.Font = Enum.Font.GothamMedium; SBody.TextColor3 = Color3.fromRGB(220, 220, 220); SBody.TextSize = 12; SBody.TextXAlignment = Enum.TextXAlignment.Left; SBody.TextYAlignment = Enum.TextYAlignment.Top; SBody.TextWrapped = true; SBody.RichText = true; SBody.Text = bodyTxt
	end

	CreateSection(HubScroll, "CHANGELOG: THE COMBAT UPDATE", "<b>v1.1.0 is LIVE!</b>\n\n• <b>Expanded Movesets:</b> New skills for Anti-Personnel, Blades, & Spears!\n• <b>3-Hit Synergies:</b> Chain attacks for massive multipliers.\n• <b>Real-Time Leaderboards:</b> Global PvP & Prestige tracking.\n• <b>Visual Upgrades:</b> Enhanced Hub and Combat UI.", 2)
	CreateSection(HubScroll, "QUICK SYNERGIES", "Use skills in sequence to trigger devastating <font color='#FFD700'>Synergies</font>!\n\n• <b>Basic Slash</b> -> <b>Spinning Slash</b> -> <b>Nape Strike</b>\n• <b>Dual Slash</b> -> <b>Momentum Strike</b> -> <b>Vortex Slash</b>\n• <b>Armor Piercer</b> -> <b>Spear Volley</b> -> <b>Reckless Barrage</b>", 3)

	local LBContainer = Instance.new("Frame", HubScroll); LBContainer.Size = UDim2.new(0.95, 0, 0, 200); LBContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Instance.new("UICorner", LBContainer).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", LBContainer).Color = Color3.fromRGB(100, 80, 40); LBContainer.LayoutOrder = 4

	local LBHeader = Instance.new("TextLabel", LBContainer); LBHeader.Size = UDim2.new(1, 0, 0, 30); LBHeader.BackgroundTransparency = 1; LBHeader.Font = Enum.Font.GothamBlack; LBHeader.TextColor3 = Color3.fromRGB(255, 215, 100); LBHeader.TextSize = 14; LBHeader.Text = " GLOBAL LEADERBOARDS"; LBHeader.TextXAlignment = Enum.TextXAlignment.Left

	local LBTabs = Instance.new("Frame", LBContainer); LBTabs.Size = UDim2.new(0.9, 0, 0, 30); LBTabs.Position = UDim2.new(0.05, 0, 0, 30); LBTabs.BackgroundTransparency = 1
	local PresBtn = Instance.new("TextButton", LBTabs); PresBtn.Size = UDim2.new(0.48, 0, 1, 0); PresBtn.Font = Enum.Font.GothamBlack; PresBtn.TextSize = 12; PresBtn.Text = "PRESTIGE"; ApplyButtonGradient(PresBtn, Color3.fromRGB(150, 120, 40), Color3.fromRGB(100, 80, 20), Color3.fromRGB(200, 160, 50)); PresBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	local EloBtn = Instance.new("TextButton", LBTabs); EloBtn.Size = UDim2.new(0.48, 0, 1, 0); EloBtn.Position = UDim2.new(0.52, 0, 0, 0); EloBtn.Font = Enum.Font.GothamBlack; EloBtn.TextSize = 12; EloBtn.Text = "PvP ELO"; ApplyButtonGradient(EloBtn, Color3.fromRGB(40, 60, 100), Color3.fromRGB(20, 30, 50), Color3.fromRGB(80, 100, 150)); EloBtn.TextColor3 = Color3.fromRGB(180, 180, 180)

	LBScroll = Instance.new("ScrollingFrame", LBContainer); LBScroll.Size = UDim2.new(0.9, 0, 0, 125); LBScroll.Position = UDim2.new(0.05, 0, 0, 65); LBScroll.BackgroundTransparency = 1; LBScroll.ScrollBarThickness = 4; LBScroll.BorderSizePixel = 0
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
	local BtnArea = Instance.new("Frame", HubScroll); BtnArea.Size = UDim2.new(0.95, 0, 0, 90); BtnArea.BackgroundTransparency = 1; BtnArea.LayoutOrder = 5
	local baLayout = Instance.new("UIGridLayout", BtnArea); baLayout.CellSize = UDim2.new(0.48, 0, 0, 40); baLayout.CellPadding = UDim2.new(0.04, 0, 0, 10); baLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; baLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local GuideBtn = Instance.new("TextButton", BtnArea); GuideBtn.Font = Enum.Font.GothamBlack; GuideBtn.TextSize = 12; GuideBtn.Text = "TUTORIAL"; ApplyButtonGradient(GuideBtn, Color3.fromRGB(100, 100, 120), Color3.fromRGB(50, 50, 60), Color3.fromRGB(150, 150, 180)); GuideBtn.TextColor3 = Color3.fromRGB(255, 255, 255); GuideBtn.LayoutOrder = 1
	local SynBtn = Instance.new("TextButton", BtnArea); SynBtn.Font = Enum.Font.GothamBlack; SynBtn.TextSize = 12; SynBtn.Text = "SYNERGY GUIDE"; ApplyButtonGradient(SynBtn, Color3.fromRGB(120, 80, 160), Color3.fromRGB(60, 40, 80), Color3.fromRGB(160, 100, 220)); SynBtn.TextColor3 = Color3.fromRGB(255, 255, 255); SynBtn.LayoutOrder = 2
	local PlayBtn = Instance.new("TextButton", BtnArea); PlayBtn.Font = Enum.Font.GothamBlack; PlayBtn.TextSize = 14; PlayBtn.Text = "DEPLOY TO BASE"; ApplyButtonGradient(PlayBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20)); PlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255); PlayBtn.LayoutOrder = 3

	PlayBtn.Size = UDim2.new(1, 0, 0, 40)
	local fillFrame = Instance.new("Frame", BtnArea); fillFrame.BackgroundTransparency = 1; fillFrame.LayoutOrder = 4

	hpLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() HubScroll.CanvasSize = UDim2.new(0, 0, 0, hpLayout.AbsoluteContentSize.Y + 40) end)

	-- SYNERGY PANEL 
	SynergyPanel = Instance.new("Frame", MainFrame)
	SynergyPanel.Size = UDim2.new(0.95, 0, 0.9, 0)
	SynergyPanel.Position = UDim2.new(0.5, 0, 1.5, 0)
	SynergyPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	SynergyPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	SynergyPanel.ClipsDescendants = true
	SynergyPanel.Visible = false
	Instance.new("UICorner", SynergyPanel).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", SynergyPanel).Color = Color3.fromRGB(150, 100, 255)
	SynergyPanel.UIStroke.Thickness = 2

	local synPattern = bgPattern:Clone(); synPattern.Parent = SynergyPanel; synPattern.ImageColor3 = Color3.fromRGB(150, 100, 255)

	local SynScroll = Instance.new("ScrollingFrame", SynergyPanel)
	SynScroll.Size = UDim2.new(1, 0, 1, 0)
	SynScroll.BackgroundTransparency = 1
	SynScroll.ScrollBarThickness = 0
	SynScroll.ZIndex = 1

	local synLayout = Instance.new("UIListLayout", SynScroll); synLayout.Padding = UDim.new(0, 10); synLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local synPad = Instance.new("UIPadding", SynScroll); synPad.PaddingTop = UDim.new(0, 15); synPad.PaddingBottom = UDim.new(0, 20)

	local SynTitle = Instance.new("TextLabel", SynScroll); SynTitle.Size = UDim2.new(0.9, 0, 0, 30); SynTitle.BackgroundTransparency = 1; SynTitle.Font = Enum.Font.GothamBlack; SynTitle.TextColor3 = Color3.fromRGB(200, 150, 255); SynTitle.TextSize = 18; SynTitle.TextXAlignment = Enum.TextXAlignment.Center; SynTitle.Text = "SYNERGY DIRECTORY"
	ApplyGradient(SynTitle, Color3.fromRGB(220, 180, 255), Color3.fromRGB(150, 80, 255))

	local function AddSynergyRow(title, seqText, desc)
		local row = Instance.new("Frame", SynScroll); row.Size = UDim2.new(0.95, 0, 0, 85); row.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", row).Color = Color3.fromRGB(100, 80, 140)

		local rTitle = Instance.new("TextLabel", row); rTitle.Size = UDim2.new(1, -10, 0, 20); rTitle.Position = UDim2.new(0, 5, 0, 5); rTitle.BackgroundTransparency = 1; rTitle.Font = Enum.Font.GothamBlack; rTitle.TextColor3 = Color3.fromRGB(255, 215, 100); rTitle.TextSize = 14; rTitle.TextXAlignment = Enum.TextXAlignment.Left; rTitle.Text = title
		local rSeq = Instance.new("TextLabel", row); rSeq.Size = UDim2.new(1, -10, 0, 20); rSeq.Position = UDim2.new(0, 5, 0, 25); rSeq.BackgroundTransparency = 1; rSeq.Font = Enum.Font.GothamBold; rSeq.TextColor3 = Color3.fromRGB(255, 255, 255); rSeq.TextSize = 12; rSeq.TextXAlignment = Enum.TextXAlignment.Left; rSeq.RichText = true; rSeq.Text = seqText
		local rDesc = Instance.new("TextLabel", row); rDesc.Size = UDim2.new(1, -10, 0, 35); rDesc.Position = UDim2.new(0, 5, 0, 45); rDesc.BackgroundTransparency = 1; rDesc.Font = Enum.Font.GothamMedium; rDesc.TextColor3 = Color3.fromRGB(180, 180, 200); rDesc.TextSize = 11; rDesc.TextXAlignment = Enum.TextXAlignment.Left; rDesc.TextYAlignment = Enum.TextYAlignment.Top; rDesc.TextWrapped = true; rDesc.Text = desc
	end

	AddSynergyRow("UNIVERSAL ODM", "Basic Slash -> Spinning Slash -> <font color='#FF5555'>Nape Strike</font>", "A foundational 3-hit combo that inflicts Bleed on the final strike.")
	AddSynergyRow("STEEL BLADES", "Dual Slash -> Momentum Strike -> <font color='#FF5555'>Vortex Slash</font>", "A devastating whirlwind of consecutive strikes building up immense multiplier damage.")
	AddSynergyRow("THUNDER SPEARS", "Armor Piercer -> Spear Volley -> Reckless Barrage -> <font color='#FF5555'>Detonator Dive</font>", "An explosive 4-hit chain that shreds armor, burns, and ends in a suicidal stun dive.")
	AddSynergyRow("ANTI-PERSONNEL", "Buckshot Spread -> Grapple Shot -> <font color='#FF5555'>Executioner's Shot</font>", "Close the gap, stagger the target, and unleash a point-blank lethal headshot.")
	AddSynergyRow("ACKERMAN", "Ackerman Flurry -> Swift Execution -> <font color='#FF5555'>God Speed</font>", "Move faster than the eye can see, instantly shredding and stunning the target.")

	local SynBackBtn = Instance.new("TextButton", SynScroll); SynBackBtn.Size = UDim2.new(0.9, 0, 0, 40); SynBackBtn.Font = Enum.Font.GothamBlack; SynBackBtn.TextSize = 14; SynBackBtn.Text = "RETURN TO HUB"
	ApplyButtonGradient(SynBackBtn, Color3.fromRGB(80, 60, 100), Color3.fromRGB(40, 30, 50), Color3.fromRGB(120, 80, 160)); SynBackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

	synLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SynScroll.CanvasSize = UDim2.new(0, 0, 0, synLayout.AbsoluteContentSize.Y + 40) end)

	SynBackBtn.MouseButton1Click:Connect(function()
		HubPanel.Visible = true
		HubPanel.Position = UDim2.new(0.5, 0, -0.5, 0)
		TweenService:Create(SynergyPanel, TweenInfo.new(0.3), {Position = UDim2.new(0.5, 0, 1.5, 0)}):Play()
		TweenService:Create(HubPanel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
		task.delay(0.3, function() SynergyPanel.Visible = false end)
	end)

	SynBtn.MouseButton1Click:Connect(function()
		SynergyPanel.Visible = true
		SynergyPanel.Position = UDim2.new(0.5, 0, 1.5, 0)
		TweenService:Create(HubPanel, TweenInfo.new(0.3), {Position = UDim2.new(0.5, 0, -0.5, 0)}):Play()
		TweenService:Create(SynergyPanel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
		task.delay(0.3, function() HubPanel.Visible = false end)
	end)

	PlayBtn.MouseButton1Click:Connect(function()
		TweenService:Create(MainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		if HubPanel.Visible then TweenService:Create(HubPanel, TweenInfo.new(0.3), {Position = UDim2.new(0.5, 0, 1.5, 0)}):Play() end
		if SynergyPanel.Visible then TweenService:Create(SynergyPanel, TweenInfo.new(0.3), {Position = UDim2.new(0.5, 0, 1.5, 0)}):Play() end
		task.wait(0.3); MainFrame.Visible = false
	end)

	GuideBtn.MouseButton1Click:Connect(function()
		MainFrame.Visible = false
		TourOverlay.Enabled = true
		RunTourStep(1)
	end)

	task.spawn(function()
		local ls = player:WaitForChild("leaderstats", 10)
		if ls then
			local function updateUI()
				if MainFrame.Visible and HubPanel.Visible then RefreshLeaderboard(currentLBMode) end
			end
			if ls:FindFirstChild("Prestige") then ls.Prestige.Changed:Connect(updateUI) end
			if ls:FindFirstChild("Elo") then ls.Elo.Changed:Connect(updateUI) end
		end
	end)
end

function WelcomeHub.Show(force)
	if MainFrame then
		if force or not player:GetAttribute("HasSeenHub") then
			if not force and not player:GetAttribute("DataLoaded") then 
				player:GetAttributeChangedSignal("DataLoaded"):Wait() 
			end

			player:SetAttribute("HasSeenHub", true)
			MainFrame.Visible = true
			HubPanel.Visible = true
			SynergyPanel.Visible = false

			HubPanel.Position = UDim2.new(0.5, 0, 1.5, 0)
			SynergyPanel.Position = UDim2.new(0.5, 0, 1.5, 0)
			MainFrame.BackgroundTransparency = 1

			TweenService:Create(MainFrame, TweenInfo.new(0.4), {BackgroundTransparency = 0.1}):Play()
			TweenService:Create(HubPanel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
			RefreshLeaderboard(currentLBMode)
		end
	end
end

return WelcomeHub