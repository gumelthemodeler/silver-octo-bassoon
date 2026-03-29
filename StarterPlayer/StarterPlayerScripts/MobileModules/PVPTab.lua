-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local PvPTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local EffectsManager = require(script.Parent:WaitForChild("EffectsManager")) -- NOW LOADED!

local player = Players.LocalPlayer

-- UI References
local LobbyFrame, QueueBtn, MatchScroll
local ArenaFrame, LogText, ActionGrid, TargetMenu, LeaveBtn
local PlayerHPBar, PlayerHPText, PlayerNameText, PlayerGasBar, PlayerGasText, PlayerNrgBar, PlayerNrgText, PlayerNrgContainer
local EnemyHPBar, EnemyHPText, EnemyNameText
local pAvatarBox, eAvatarBox

local isQueued = false
local currentMatchId = nil
local isFighter = false
local inputLocked = false
local pendingSkillName = nil
local playerIsP1 = true
local cachedTooltipMgr

-- [[ 1. VISUAL FEEDBACK & EFFECTS ]]
local function ShakeUI(intensity)
	if not intensity or intensity == "None" then return end
	local amount = (intensity == "Heavy") and 15 or 6
	local originalPos = UDim2.new(0.5, 0, 0.5, 0)
	task.spawn(function()
		for i = 1, 10 do
			if not ArenaFrame.Visible then break end
			local xOffset = math.random(-amount, amount); local yOffset = math.random(-amount, amount)
			ArenaFrame.Position = originalPos + UDim2.new(0, xOffset, 0, yOffset)
			task.wait(0.03)
		end
		ArenaFrame.Position = originalPos
	end)
end

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
		btn:GetPropertyChangedSignal("RichText"):Connect(function() textLbl.RichText = btn.RichText end)
	end
end

local function CreateBar(parent, color1, color2, size, labelText, alignRight)
	local container = Instance.new("Frame", parent)
	container.Size = size; container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", container).Color = Color3.fromRGB(60, 60, 70)

	local fill = Instance.new("Frame", container)
	fill.Size = UDim2.new(1, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	if alignRight then fill.AnchorPoint = Vector2.new(1, 0); fill.Position = UDim2.new(1, 0, 0, 0) end
	local grad = Instance.new("UIGradient", fill); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}; grad.Rotation = 90

	local text = Instance.new("TextLabel", container)
	text.Size = UDim2.new(1, -10, 1, 0); text.Position = UDim2.new(0, alignRight and 0 or 10, 0, 0); text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold; text.TextColor3 = Color3.fromRGB(255, 255, 255); text.TextSize = 11; text.TextStrokeTransparency = 0.5; text.Text = labelText
	text.TextXAlignment = alignRight and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left; text.ZIndex = 5
	return fill, text, container
end

local function LockGridAndWait()
	inputLocked = true
	TargetMenu.Visible = false
	ActionGrid.Visible = true
	for _, b in ipairs(ActionGrid:GetChildren()) do 
		if b:IsA("TextButton") then 
			ApplyButtonGradient(b, Color3.fromRGB(25, 20, 30), Color3.fromRGB(15, 10, 20), Color3.fromRGB(40, 30, 50))
			b.TextColor3 = Color3.fromRGB(120, 120, 120) 
		end 
	end
	LogText.Text = "<font color='#55FFFF'><b>MOVE LOCKED IN. WAITING FOR OPPONENT...</b></font>"
end

-- [[ 2. CORE UI INITIALIZATION ]]
function PvPTab.Init(parentFrame, tooltipMgr)
	cachedTooltipMgr = tooltipMgr
	EffectsManager.Init() -- Initialize SFX/VFX Manager

	-- *** LOBBY UI ***
	LobbyFrame = Instance.new("Frame", parentFrame)
	LobbyFrame.Name = "PvPLobby"; LobbyFrame.Size = UDim2.new(1, 0, 1, 0); LobbyFrame.BackgroundTransparency = 1; LobbyFrame.Visible = false

	local QueuePanel = Instance.new("Frame", LobbyFrame)
	QueuePanel.Size = UDim2.new(1, 0, 0, 100); QueuePanel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	Instance.new("UICorner", QueuePanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", QueuePanel).Color = Color3.fromRGB(100, 80, 40)

	local QueueTitle = Instance.new("TextLabel", QueuePanel)
	QueueTitle.Size = UDim2.new(1, 0, 0, 30); QueueTitle.Position = UDim2.new(0, 0, 0, 10); QueueTitle.BackgroundTransparency = 1
	QueueTitle.Font = Enum.Font.GothamBlack; QueueTitle.Text = "UNDERGROUND ARENA"; QueueTitle.TextColor3 = Color3.fromRGB(255, 215, 100); QueueTitle.TextSize = 22

	QueueBtn = Instance.new("TextButton", QueuePanel)
	QueueBtn.Size = UDim2.new(0.4, 0, 0, 40); QueueBtn.Position = UDim2.new(0.3, 0, 0.5, 0); QueueBtn.Font = Enum.Font.GothamBlack; QueueBtn.Text = "ENTER MATCHMAKING"; QueueBtn.TextColor3 = Color3.new(1,1,1); QueueBtn.TextSize = 16
	ApplyButtonGradient(QueueBtn, Color3.fromRGB(60, 120, 200), Color3.fromRGB(30, 60, 100), Color3.fromRGB(40, 80, 140))

	QueueBtn.MouseButton1Click:Connect(function()
		EffectsManager.PlaySFX("Click")
		if isQueued then
			Network.PvPAction:FireServer("LeaveQueue"); isQueued = false; QueueBtn.Text = "ENTER MATCHMAKING"
			ApplyButtonGradient(QueueBtn, Color3.fromRGB(60, 120, 200), Color3.fromRGB(30, 60, 100), Color3.fromRGB(40, 80, 140))
		else
			Network.PvPAction:FireServer("JoinQueue"); isQueued = true; QueueBtn.Text = "SEARCHING FOR OPPONENT..."
			ApplyButtonGradient(QueueBtn, Color3.fromRGB(200, 120, 40), Color3.fromRGB(100, 60, 20), Color3.fromRGB(140, 80, 30))
		end
	end)

	MatchScroll = Instance.new("ScrollingFrame", LobbyFrame)
	MatchScroll.Size = UDim2.new(1, 0, 1, -120); MatchScroll.Position = UDim2.new(0, 0, 0, 120); MatchScroll.BackgroundTransparency = 1; MatchScroll.ScrollBarThickness = 4; MatchScroll.BorderSizePixel = 0
	local mLayout = Instance.new("UIListLayout", MatchScroll); mLayout.Padding = UDim.new(0, 10); mLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- *** ARENA UI ***
	ArenaFrame = Instance.new("Frame", parentFrame.Parent)
	ArenaFrame.Name = "PvPArenaFrame"; ArenaFrame.Size = UDim2.new(0, 750, 0, 520); ArenaFrame.Position = UDim2.new(0.5, 0, 0.5, 0); ArenaFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	ArenaFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20); ArenaFrame.Visible = false; ArenaFrame.ZIndex = 200
	Instance.new("UICorner", ArenaFrame).CornerRadius = UDim.new(0, 12)
	local outerStroke = Instance.new("UIStroke", ArenaFrame); outerStroke.Thickness = 2; outerStroke.Color = Color3.fromRGB(255, 50, 50); outerStroke.LineJoinMode = Enum.LineJoinMode.Miter

	local arenaLayout = Instance.new("UIListLayout", ArenaFrame); arenaLayout.SortOrder = Enum.SortOrder.LayoutOrder; arenaLayout.Padding = UDim.new(0, 10); arenaLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local arenaPadding = Instance.new("UIPadding", ArenaFrame); arenaPadding.PaddingTop = UDim.new(0, 10); arenaPadding.PaddingBottom = UDim.new(0, 10)

	local Header = Instance.new("TextLabel", ArenaFrame)
	Header.Size = UDim2.new(1, 0, 0, 20); Header.BackgroundTransparency = 1; Header.Font = Enum.Font.GothamBlack; Header.TextColor3 = Color3.fromRGB(255, 50, 50); Header.TextSize = 18; Header.Text = "PVP COMBAT"; Header.LayoutOrder = 1
	ApplyGradient(Header, Color3.fromRGB(255, 100, 100), Color3.fromRGB(200, 40, 40))

	-- Avatars and Stats
	local CombatantsFrame = Instance.new("Frame", ArenaFrame)
	CombatantsFrame.Size = UDim2.new(0.96, 0, 0, 100); CombatantsFrame.BackgroundTransparency = 1; CombatantsFrame.LayoutOrder = 2

	local PlayerPanel = Instance.new("Frame", CombatantsFrame)
	PlayerPanel.Size = UDim2.new(0.46, 0, 1, 0); PlayerPanel.BackgroundTransparency = 1
	pAvatarBox = Instance.new("Frame", PlayerPanel); pAvatarBox.Size = UDim2.new(0, 80, 0, 80); pAvatarBox.Position = UDim2.new(0, 0, 0.5, 0); pAvatarBox.AnchorPoint = Vector2.new(0, 0.5); pAvatarBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15); Instance.new("UIStroke", pAvatarBox).Color = Color3.fromRGB(80, 120, 200)

	local pStatsArea = Instance.new("Frame", PlayerPanel); pStatsArea.Size = UDim2.new(1, -90, 1, 0); pStatsArea.Position = UDim2.new(0, 90, 0, 0); pStatsArea.BackgroundTransparency = 1; local pLayout = Instance.new("UIListLayout", pStatsArea); pLayout.Padding = UDim.new(0, 4); pLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	PlayerNameText = Instance.new("TextLabel", pStatsArea); PlayerNameText.Size = UDim2.new(1, 0, 0, 15); PlayerNameText.BackgroundTransparency = 1; PlayerNameText.Font = Enum.Font.GothamBlack; PlayerNameText.TextColor3 = Color3.fromRGB(200, 220, 255); PlayerNameText.TextSize = 14; PlayerNameText.TextXAlignment = Enum.TextXAlignment.Left
	PlayerHPBar, PlayerHPText = CreateBar(pStatsArea, Color3.fromRGB(220, 60, 60), Color3.fromRGB(140, 30, 30), UDim2.new(1, 0, 0, 14), "HP: 100", false)

	local vsLbl = Instance.new("TextLabel", CombatantsFrame); vsLbl.Size = UDim2.new(0.08, 0, 1, 0); vsLbl.Position = UDim2.new(0.46, 0, 0, 0); vsLbl.BackgroundTransparency = 1; vsLbl.Font = Enum.Font.GothamBlack; vsLbl.TextColor3 = Color3.fromRGB(100, 100, 110); vsLbl.TextSize = 24; vsLbl.Text = "VS"

	local EnemyPanel = Instance.new("Frame", CombatantsFrame)
	EnemyPanel.Size = UDim2.new(0.46, 0, 1, 0); EnemyPanel.Position = UDim2.new(0.54, 0, 0, 0); EnemyPanel.BackgroundTransparency = 1
	eAvatarBox = Instance.new("Frame", EnemyPanel); eAvatarBox.Size = UDim2.new(0, 80, 0, 80); eAvatarBox.Position = UDim2.new(1, 0, 0.5, 0); eAvatarBox.AnchorPoint = Vector2.new(1, 0.5); eAvatarBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15); Instance.new("UIStroke", eAvatarBox).Color = Color3.fromRGB(255, 100, 100)

	local eStatsArea = Instance.new("Frame", EnemyPanel); eStatsArea.Size = UDim2.new(1, -90, 1, 0); eStatsArea.BackgroundTransparency = 1; local eStatsLayout = Instance.new("UIListLayout", eStatsArea); eStatsLayout.Padding = UDim.new(0, 4); eStatsLayout.VerticalAlignment = Enum.VerticalAlignment.Center; eStatsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	EnemyNameText = Instance.new("TextLabel", eStatsArea); EnemyNameText.Size = UDim2.new(1, 0, 0, 15); EnemyNameText.BackgroundTransparency = 1; EnemyNameText.Font = Enum.Font.GothamBlack; EnemyNameText.TextColor3 = Color3.fromRGB(255, 120, 120); EnemyNameText.TextSize = 14; EnemyNameText.TextXAlignment = Enum.TextXAlignment.Right
	EnemyHPBar, EnemyHPText = CreateBar(eStatsArea, Color3.fromRGB(220, 60, 60), Color3.fromRGB(140, 30, 30), UDim2.new(1, 0, 0, 14), "HP: 100", true)

	-- Combat Log
	local FeedBox = Instance.new("Frame", ArenaFrame)
	FeedBox.Size = UDim2.new(0.96, 0, 0, 90); FeedBox.BackgroundColor3 = Color3.fromRGB(22, 22, 26); FeedBox.ClipsDescendants = true; FeedBox.LayoutOrder = 3
	Instance.new("UICorner", FeedBox).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", FeedBox).Color = Color3.fromRGB(60, 60, 70)
	LogText = Instance.new("TextLabel", FeedBox); LogText.Size = UDim2.new(1, -20, 1, -10); LogText.Position = UDim2.new(0, 10, 0, 5); LogText.BackgroundTransparency = 1; LogText.Font = Enum.Font.GothamMedium; LogText.TextColor3 = Color3.fromRGB(230, 230, 230); LogText.TextSize = 14; LogText.TextWrapped = true; LogText.RichText = true; LogText.TextXAlignment = Enum.TextXAlignment.Left; LogText.TextYAlignment = Enum.TextYAlignment.Top

	-- Bottom Area
	local BottomArea = Instance.new("Frame", ArenaFrame)
	BottomArea.Size = UDim2.new(0.96, 0, 0, 180); BottomArea.BackgroundTransparency = 1; BottomArea.LayoutOrder = 4

	ActionGrid = Instance.new("ScrollingFrame", BottomArea)
	ActionGrid.Size = UDim2.new(1, 0, 1, 0); ActionGrid.BackgroundTransparency = 1; ActionGrid.ScrollBarThickness = 0; ActionGrid.BorderSizePixel = 0
	local gridLayout = Instance.new("UIGridLayout", ActionGrid); gridLayout.CellSize = UDim2.new(0, 170, 0, 45); gridLayout.CellPadding = UDim2.new(0, 8, 0, 12); gridLayout.SortOrder = Enum.SortOrder.LayoutOrder; gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- [[ 3. YOUR EXACT TARGETING SYSTEM ]]
	TargetMenu = Instance.new("Frame", BottomArea)
	TargetMenu.Size = UDim2.new(1, 0, 1, -10); TargetMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TargetMenu.Visible = false
	Instance.new("UICorner", TargetMenu).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", TargetMenu).Color = Color3.fromRGB(80, 80, 90)

	local InfoPanel = Instance.new("Frame", TargetMenu)
	InfoPanel.Size = UDim2.new(0.45, 0, 1, 0); InfoPanel.BackgroundTransparency = 1

	local tHoverTitle = Instance.new("TextLabel", InfoPanel)
	tHoverTitle.Size = UDim2.new(1, -20, 0, 30); tHoverTitle.Position = UDim2.new(0, 20, 0, 15); tHoverTitle.BackgroundTransparency = 1; tHoverTitle.Font = Enum.Font.GothamBlack; tHoverTitle.TextColor3 = Color3.fromRGB(255, 215, 100); tHoverTitle.TextSize = 20; tHoverTitle.TextXAlignment = Enum.TextXAlignment.Left; tHoverTitle.Text = "SELECT TARGET"
	ApplyGradient(tHoverTitle, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	local tHoverDesc = Instance.new("TextLabel", InfoPanel)
	tHoverDesc.Size = UDim2.new(1, -20, 0, 100); tHoverDesc.Position = UDim2.new(0, 20, 0, 60); tHoverDesc.BackgroundTransparency = 1; tHoverDesc.Font = Enum.Font.GothamMedium; tHoverDesc.TextColor3 = Color3.fromRGB(200, 200, 200); tHoverDesc.TextSize = 13; tHoverDesc.TextXAlignment = Enum.TextXAlignment.Left; tHoverDesc.TextYAlignment = Enum.TextYAlignment.Top; tHoverDesc.TextWrapped = true; tHoverDesc.Text = "Hover over a limb to see its tactical advantage."

	local CancelBtn = Instance.new("TextButton", InfoPanel)
	CancelBtn.Size = UDim2.new(0.7, 0, 0, 40); CancelBtn.Position = UDim2.new(0, 20, 1, -55); CancelBtn.Font = Enum.Font.GothamBlack; CancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255); CancelBtn.TextSize = 14; CancelBtn.Text = "CANCEL"
	ApplyButtonGradient(CancelBtn, Color3.fromRGB(160, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(60, 20, 20))
	CancelBtn.MouseButton1Click:Connect(function() TargetMenu.Visible = false; ActionGrid.Visible = true; pendingSkillName = nil end)

	local BodyContainer = Instance.new("Frame", TargetMenu)
	BodyContainer.Size = UDim2.new(0.5, 0, 1, -20); BodyContainer.Position = UDim2.new(0.5, 0, 0, 10); BodyContainer.BackgroundTransparency = 1

	local function CreateLimb(name, size, pos, hoverText, baseColor)
		local limb = Instance.new("TextButton", BodyContainer)
		limb.Size = size; limb.Position = pos; limb.Text = name:upper(); limb.Font = Enum.Font.GothamBlack; limb.TextColor3 = Color3.fromRGB(255, 255, 255); limb.TextSize = 12

		local mTop = Color3.new(math.clamp(baseColor.R * 0.6, 0, 1), math.clamp(baseColor.G * 0.6, 0, 1), math.clamp(baseColor.B * 0.6, 0, 1))
		local mBot = Color3.new(math.clamp(baseColor.R * 0.3, 0, 1), math.clamp(baseColor.G * 0.3, 0, 1), math.clamp(baseColor.B * 0.3, 0, 1))
		ApplyButtonGradient(limb, mTop, mBot, baseColor)

		limb.MouseEnter:Connect(function()
			local hTop = Color3.new(math.clamp(baseColor.R * 1.2, 0, 1), math.clamp(baseColor.G * 1.2, 0, 1), math.clamp(baseColor.B * 1.2, 0, 1))
			local hBot = Color3.new(math.clamp(baseColor.R * 0.8, 0, 1), math.clamp(baseColor.G * 0.8, 0, 1), math.clamp(baseColor.B * 0.8, 0, 1))
			ApplyButtonGradient(limb, hTop, hBot, baseColor)

			tHoverTitle.Text = name:upper(); tHoverTitle.TextColor3 = baseColor
			local grad = tHoverTitle:FindFirstChildOfClass("UIGradient")
			if grad then grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, hTop), ColorSequenceKeypoint.new(1, hBot)} end
			tHoverDesc.Text = hoverText
		end)

		limb.MouseLeave:Connect(function()
			ApplyButtonGradient(limb, mTop, mBot, baseColor)
			tHoverTitle.Text = "SELECT TARGET"; tHoverTitle.TextColor3 = Color3.fromRGB(255, 215, 100)
			local grad = tHoverTitle:FindFirstChildOfClass("UIGradient")
			if grad then grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 100)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 50))} end
			tHoverDesc.Text = "Hover over a limb to see its tactical advantage."
		end)

		limb.MouseButton1Click:Connect(function()
			if pendingSkillName and not inputLocked then
				EffectsManager.PlaySFX("Click")
				LockGridAndWait()
				Network.PvPAction:FireServer("SubmitMove", currentMatchId, pendingSkillName, name)
			end
		end)
	end

	local aspect = Instance.new("UIAspectRatioConstraint", BodyContainer); aspect.AspectRatio = 0.8
	CreateLimb("Eyes", UDim2.new(0.24, 0, 0.18, 0), UDim2.new(0.5, 0, 0.08, 0), "Deals 20% Damage. Inflicts Blinded.", Color3.fromRGB(120, 120, 180))
	CreateLimb("Nape", UDim2.new(0.24, 0, 0.06, 0), UDim2.new(0.5, 0, 0.22, 0), "Deals 150% Damage. Low accuracy.", Color3.fromRGB(220, 80, 80))
	CreateLimb("Body", UDim2.new(0.48, 0, 0.38, 0), UDim2.new(0.5, 0, 0.45, 0), "Deals 100% Damage. Standard accuracy.", Color3.fromRGB(80, 160, 80))
	CreateLimb("Arms", UDim2.new(0.22, 0, 0.38, 0), UDim2.new(0.14, 0, 0.45, 0), "Deals 50% Damage. Inflicts Weakened.", Color3.fromRGB(180, 140, 60))
	CreateLimb("Arms", UDim2.new(0.22, 0, 0.38, 0), UDim2.new(0.86, 0, 0.45, 0), "Deals 50% Damage. Inflicts Weakened.", Color3.fromRGB(180, 140, 60))
	CreateLimb("Legs", UDim2.new(0.23, 0, 0.32, 0), UDim2.new(0.37, 0, 0.81, 0), "Deals 50% Damage. Inflicts Crippled.", Color3.fromRGB(80, 140, 180))
	CreateLimb("Legs", UDim2.new(0.23, 0, 0.32, 0), UDim2.new(0.63, 0, 0.81, 0), "Deals 50% Damage. Inflicts Crippled.", Color3.fromRGB(80, 140, 180))

	for _, child in ipairs(BodyContainer:GetChildren()) do if child:IsA("TextButton") then child.AnchorPoint = Vector2.new(0.5, 0.5) end end

	LeaveBtn = Instance.new("TextButton", ArenaFrame); LeaveBtn.Size = UDim2.new(0.6, 0, 0, 45); LeaveBtn.LayoutOrder = 5; LeaveBtn.Font = Enum.Font.GothamBlack; LeaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255); LeaveBtn.TextSize = 16; LeaveBtn.Text = "LEAVE ARENA"; LeaveBtn.Visible = false
	ApplyButtonGradient(LeaveBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))

	LeaveBtn.MouseButton1Click:Connect(function()
		EffectsManager.PlaySFX("Click")
		ArenaFrame.Visible = false
		parentFrame.Visible = true 
		local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
		if topGui then
			if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = true end
			if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = true end
		end
	end)

	local function UpdatePvPActionGrid()
		inputLocked = false
		for _, child in ipairs(ActionGrid:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end

		local eqWpn = player:GetAttribute("EquippedWeapon") or "None"
		local pStyle = (ItemData.Equipment[eqWpn] and ItemData.Equipment[eqWpn].Style) or "None"
		local pTitan = player:GetAttribute("Titan") or "None"
		local pClan = player:GetAttribute("Clan") or "None"
		local isTransformed = player:GetAttribute("Statuses") and player:GetAttribute("Statuses")["Transformed"]
		local isODM = (pStyle == "Ultrahard Steel Blades" or pStyle == "Thunder Spears" or pStyle == "Anti-Personnel")

		local function CreateBtn(sName, color, order)
			local sData = SkillData.Skills[sName]
			if not sData then return end
			if sName == "Transform" and (pClan == "Ackerman" or pClan == "Awakened Ackerman") then return end

			local btn = Instance.new("TextButton", ActionGrid); btn.RichText = true; btn.Font = Enum.Font.GothamBold; btn.TextSize = 12; btn.LayoutOrder = order or 10
			ApplyButtonGradient(btn, color, Color3.new(color.R*0.7, color.G*0.7, color.B*0.7), color)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.Text = sName:upper()

			btn.MouseButton1Click:Connect(function()
				if not inputLocked then
					EffectsManager.PlaySFX("Click")
					if sName == "Retreat" or sData.Effect == "Rest" or sData.Effect == "TitanRest" or sData.Effect == "Eject" or sData.Effect == "Transform" or sData.Effect == "Block" then
						LockGridAndWait()
						Network.PvPAction:FireServer("SubmitMove", currentMatchId, sName, "Body")
					else
						pendingSkillName = sName
						ActionGrid.Visible = false
						TargetMenu.Visible = true
					end
				end
			end)
		end

		if isTransformed then
			CreateBtn("Titan Recover", Color3.fromRGB(40, 140, 80), 1); CreateBtn("Titan Punch", Color3.fromRGB(120, 40, 40), 2); CreateBtn("Titan Kick", Color3.fromRGB(140, 60, 40), 3); CreateBtn("Eject", Color3.fromRGB(140, 40, 40), 4)
			local orderIndex = 5
			for sName, sData in pairs(SkillData.Skills) do
				if sData.Requirement == pTitan or sData.Requirement == "AnyTitan" or sData.Requirement == "Transformed" then
					if sName ~= "Titan Recover" and sName ~= "Eject" and sName ~= "Titan Punch" and sName ~= "Titan Kick" and sName ~= "Transform" then
						CreateBtn(sName, Color3.fromRGB(60, 40, 60), sData.Order or orderIndex); orderIndex += 1
					end
				end
			end
		else
			CreateBtn("Basic Slash", Color3.fromRGB(120, 40, 40), 1); CreateBtn("Maneuver", Color3.fromRGB(40, 80, 140), 2); CreateBtn("Recover", Color3.fromRGB(40, 140, 80), 3); CreateBtn("Retreat", Color3.fromRGB(60, 60, 70), 4)
			if pTitan ~= "None" and pClan ~= "Ackerman" and pClan ~= "Awakened Ackerman" then CreateBtn("Transform", Color3.fromRGB(200, 150, 50), 5) end
			local orderIndex = 6
			for sName, sData in pairs(SkillData.Skills) do
				if sName == "Basic Slash" or sName == "Maneuver" or sName == "Recover" or sName == "Retreat" or sName == "Transform" then continue end
				local req = sData.Requirement
				if req == pStyle or req == pClan or (req == "Ackerman" and pClan == "Awakened Ackerman") or (req == "ODM" and isODM) then
					CreateBtn(sName, Color3.fromRGB(45, 40, 60), sData.Order or orderIndex); orderIndex += 1
				end
			end
		end
	end

	-- [[ 4. NETWORK EVENT LISTENERS ]]
	Network:WaitForChild("PvPUpdate").OnClientEvent:Connect(function(action, matchId, data1, data2)
		if action == "MatchStarted" then
			if data1 == player.Name or data2 == player.Name then
				isQueued = false; QueueBtn.Text = "ENTER MATCHMAKING"
				ApplyButtonGradient(QueueBtn, Color3.fromRGB(60, 120, 200), Color3.fromRGB(30, 60, 100), Color3.fromRGB(40, 80, 140))

				currentMatchId = matchId; isFighter = true; playerIsP1 = (data1 == player.Name)

				local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
				if topGui then
					if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = false end
					if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = false end
				end

				parentFrame.Visible = false; ArenaFrame.Visible = true; TargetMenu.Visible = false; ActionGrid.Visible = true; LeaveBtn.Visible = false

				PlayerNameText.Text = playerIsP1 and data1 or data2
				EnemyNameText.Text = playerIsP1 and data2 or data1
				PlayerHPBar.Size = UDim2.new(1, 0, 1, 0); EnemyHPBar.Size = UDim2.new(1, 0, 1, 0)

				LogText.Text = "<font color='#FFD700'><b>THE MATCH HAS BEGUN!</b></font>"
				UpdatePvPActionGrid()
			end

		elseif action == "TurnStrike" and currentMatchId == matchId then
			-- Ensure UI shakes to impact
			ShakeUI(data1.ShakeType)
			LogText.Text = data1.LogMsg

			-- Ensure Visual FX slash across the screen correctly
			if data1.SkillUsed then
				-- Did the left side attack, or the right side? 
				-- If the attacker is P1, and we are P1, then we are on the left.
				local attackerIsLeft = false
				if playerIsP1 then attackerIsLeft = (data1.Attacker == PlayerNameText.Text) 
				else attackerIsLeft = (data1.Attacker ~= PlayerNameText.Text) end

				EffectsManager.PlayCombatEffect(data1.SkillUsed, attackerIsLeft, pAvatarBox, eAvatarBox, data1.DidHit)
			end

			local myHP = playerIsP1 and data1.P1_HP or data1.P2_HP
			local myMax = playerIsP1 and data1.P1_Max or data1.P2_Max
			local enemyHP = playerIsP1 and data1.P2_HP or data1.P1_HP
			local enemyMax = playerIsP1 and data1.P2_Max or data1.P1_Max

			TweenService:Create(PlayerHPBar, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp(myHP / myMax, 0, 1), 0, 1, 0)}):Play()
			TweenService:Create(EnemyHPBar, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp(enemyHP / enemyMax, 0, 1), 0, 1, 0)}):Play()

			PlayerHPText.Text = "HP: " .. math.floor(myHP) .. " / " .. math.floor(myMax)
			EnemyHPText.Text = "HP: " .. math.floor(enemyHP) .. " / " .. math.floor(enemyMax)

		elseif action == "NextTurnStarted" and currentMatchId == matchId then
			if isFighter then UpdatePvPActionGrid() end

		elseif action == "MatchEnded" and currentMatchId == matchId then
			if data1 == player.UserId then EffectsManager.PlaySFX("Victory", 1) else EffectsManager.PlaySFX("Defeat", 1) end
			LogText.Text = "<font color='#FF5555'><b>MATCH CONCLUDED.</b></font>"
			ActionGrid.Visible = false
			LeaveBtn.Visible = true
			isFighter = false
		end
	end)
end

function PvPTab.Show()
	LobbyFrame.Visible = true
end

return PvPTab