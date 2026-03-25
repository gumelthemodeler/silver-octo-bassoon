-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local CombatTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local EffectsManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("EffectsManager"))

local player = Players.LocalPlayer
local MainFrame
local AmbientContainer 
local LogText, ActionGrid
local PlayerHPBar, PlayerHPText, PlayerNameText, PlayerStatusBox, PlayerGasBar, PlayerGasText
local EnemyHPBar, EnemyHPText, EnemyNameText, EnemyStatusBox, EnemyShieldBar
local PlayerNrgBar, PlayerNrgText, PlayerNrgContainer
local WaveLabel, LeaveBtn
local pAvatarBox, eAvatarBox

local TargetMenu
local pendingSkillName = nil
local isBattleActive = false
local inputLocked = false
local logMessages = {}
local MAX_LOG_MESSAGES = 2 

local cachedTooltipMgr

local function AddLogMessage(msgText, append)
	if not msgText or msgText == "" then return end
	if append then table.insert(logMessages, msgText); if #logMessages > MAX_LOG_MESSAGES then table.remove(logMessages, 1) end
	else logMessages = {msgText} end
	LogText.Text = table.concat(logMessages, "\n\n")
end

local function ShakeUI(intensity)
	if not intensity or intensity == "None" then return end
	local amount = (intensity == "Heavy") and 15 or 6
	local originalPos = UDim2.new(0.5, 0, 0.5, 0)
	task.spawn(function()
		for i = 1, 10 do
			if not MainFrame.Visible then break end
			local xOffset = math.random(-amount, amount); local yOffset = math.random(-amount, amount)
			MainFrame.Position = originalPos + UDim2.new(0, xOffset, 0, yOffset)
			task.wait(0.03)
		end
		MainFrame.Position = originalPos
	end)
end

local function CreateBar(parent, color1, color2, size, labelText)
	local container = Instance.new("Frame", parent)
	container.Size = size; container.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", container).Color = Color3.fromRGB(80, 80, 90)

	local fill = Instance.new("Frame", container)
	fill.Size = UDim2.new(1, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	local grad = Instance.new("UIGradient", fill); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}; grad.Rotation = 90

	local text = Instance.new("TextLabel", container)
	text.Size = UDim2.new(1, -10, 1, 0); text.Position = UDim2.new(0, 5, 0, 0); text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold; text.TextColor3 = Color3.fromRGB(255, 255, 255); text.TextSize = 11; text.TextStrokeTransparency = 0.5; text.Text = labelText
	return fill, text, container
end

local function RenderStatuses(container, combatant)
	for _, child in ipairs(container:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
	local function addIcon(iconTxt, bgColor, strokeColor, tooltipText)
		local f = Instance.new("Frame", container)
		f.Size = UDim2.new(0, 24, 0, 18); f.BackgroundColor3 = bgColor; Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", f).Color = strokeColor
		local t = Instance.new("TextLabel", f)
		t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBlack; t.Text = iconTxt; t.TextColor3 = Color3.fromRGB(255,255,255); t.TextScaled = true

		local hoverBtn = Instance.new("TextButton", f)
		hoverBtn.Size = UDim2.new(1, 0, 1, 0); hoverBtn.BackgroundTransparency = 1; hoverBtn.Text = ""; hoverBtn.ZIndex = 500
		hoverBtn.MouseEnter:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Show(tooltipText) end end)
		hoverBtn.MouseLeave:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Hide() end end)
	end

	if combatant.Statuses then
		if combatant.Statuses.Dodge and combatant.Statuses.Dodge > 0 then addIcon("DGE", Color3.fromRGB(30, 60, 120), Color3.fromRGB(60, 100, 200), "Dodge Active: Evades Next Attack") end
		if combatant.Statuses.Transformed and combatant.Statuses.Transformed > 0 then addIcon("TTN", Color3.fromRGB(150, 40, 40), Color3.fromRGB(200, 60, 60), "Titan Form Active") end
		for sName, duration in pairs(combatant.Statuses) do
			if duration > 0 then
				if sName == "Crippled" then addIcon("CRP", Color3.fromRGB(80, 80, 80), Color3.fromRGB(120, 120, 120), "Crippled: Speed & Dodge Halved (" .. duration .. " turns)")
				elseif sName == "Immobilized" then addIcon("IMB", Color3.fromRGB(40, 120, 40), Color3.fromRGB(80, 200, 80), "Immobilized: 0 Speed & 0 Dodge (" .. duration .. " turns)")
				elseif sName == "Weakened" then addIcon("WEK", Color3.fromRGB(120, 80, 40), Color3.fromRGB(200, 120, 60), "Weakened: Damage Halved (" .. duration .. " turns)")
				elseif sName == "Blinded" then addIcon("BLD", Color3.fromRGB(40, 40, 40), Color3.fromRGB(80, 80, 80), "Blinded: Target loses their turn! (" .. duration .. " turns)")
				elseif sName == "TrueBlind" then addIcon("TBL", Color3.fromRGB(20, 20, 20), Color3.fromRGB(50, 50, 50), "True Blindness: Target loses their turn! (" .. duration .. " turns)")
				elseif sName == "Buff_Strength" or sName == "Buff_Defense" then addIcon("BUF", Color3.fromRGB(20, 120, 20), Color3.fromRGB(40, 200, 40), "Stat Buff Active (" .. duration .. " turns)")
				end
			end
		end
	end
end

local function StartPathsAmbient()
	if _G.PathsAmbientConnection then _G.PathsAmbientConnection:Disconnect() end
	if AmbientContainer then AmbientContainer.Visible = true end

	_G.PathsAmbientConnection = game:GetService("RunService").RenderStepped:Connect(function()
		if not isBattleActive or not MainFrame.Visible then 
			_G.PathsAmbientConnection:Disconnect()
			if AmbientContainer then 
				AmbientContainer.Visible = false
				for _, c in ipairs(AmbientContainer:GetChildren()) do c:Destroy() end
			end
			return 
		end

		if math.random(1, 15) == 1 then
			local orb = Instance.new("Frame", AmbientContainer)
			local size = math.random(4, 12)
			orb.Size = UDim2.new(0, size, 0, size)
			orb.Position = UDim2.new(math.random(0, 100)/100, 0, 1.05, 0)
			orb.BackgroundColor3 = Color3.fromRGB(150, 220, 255)
			orb.BackgroundTransparency = 0.4
			Instance.new("UICorner", orb).CornerRadius = UDim.new(1, 0)
			orb.ZIndex = 50 

			local t = math.random(5, 10)
			local sway = math.random(-10, 10)/100
			local tween = TweenService:Create(orb, TweenInfo.new(t, Enum.EasingStyle.Linear), {Position = UDim2.new(orb.Position.X.Scale + sway, 0, -0.1, 0), BackgroundTransparency = 1})
			tween:Play()
			game.Debris:AddItem(orb, t)
		end
	end)
end

function CombatTab.Init(parentFrame, tooltipMgr, switchTabFunc)
	cachedTooltipMgr = tooltipMgr
	EffectsManager.Init()

	AmbientContainer = Instance.new("Frame", parentFrame.Parent)
	AmbientContainer.Name = "PathsAmbientContainer"
	AmbientContainer.Size = UDim2.new(1, 0, 1, 0)
	AmbientContainer.BackgroundTransparency = 1
	AmbientContainer.ZIndex = 50 
	AmbientContainer.Visible = false

	MainFrame = Instance.new("ScrollingFrame", parentFrame.Parent)
	MainFrame.Name = "CombatFrame"; MainFrame.Size = UDim2.new(0.98, 0, 0.95, 0); MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0); MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20); MainFrame.Visible = false; MainFrame.ZIndex = 200; MainFrame.ScrollBarThickness = 0
	MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
	local outerStroke = Instance.new("UIStroke", MainFrame); outerStroke.Thickness = 3; outerStroke.Color = Color3.fromRGB(255, 210, 60)

	local mainLayout = Instance.new("UIListLayout", MainFrame)
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.Padding = UDim.new(0, 10); mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local mainPadding = Instance.new("UIPadding", MainFrame)
	mainPadding.PaddingTop = UDim.new(0, 10); mainPadding.PaddingBottom = UDim.new(0, 10)

	WaveLabel = Instance.new("TextLabel", MainFrame)
	WaveLabel.Size = UDim2.new(1, 0, 0, 20); WaveLabel.BackgroundTransparency = 1
	WaveLabel.Font = Enum.Font.GothamBlack; WaveLabel.TextColor3 = Color3.fromRGB(255, 215, 100); WaveLabel.TextSize = 18; WaveLabel.Text = "WAVE 1/1"
	WaveLabel.LayoutOrder = 1

	local CombatantsFrame = Instance.new("Frame", MainFrame)
	CombatantsFrame.Size = UDim2.new(0.96, 0, 0, 170); CombatantsFrame.BackgroundTransparency = 1
	CombatantsFrame.LayoutOrder = 2

	local listLayout = Instance.new("UIListLayout", CombatantsFrame)
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.Padding = UDim.new(0, 10)

	local PlayerPanel = Instance.new("Frame", CombatantsFrame)
	PlayerPanel.Size = UDim2.new(1, 0, 0, 80); PlayerPanel.BackgroundTransparency = 1

	pAvatarBox = Instance.new("Frame", PlayerPanel)
	pAvatarBox.Size = UDim2.new(0, 70, 0, 70); pAvatarBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	Instance.new("UIStroke", pAvatarBox).Color = Color3.fromRGB(255, 255, 255); Instance.new("UIStroke", pAvatarBox).Thickness = 2
	local pAvatarImg = Instance.new("ImageLabel", pAvatarBox); pAvatarImg.Size = UDim2.new(1, 0, 1, 0); pAvatarImg.BackgroundTransparency = 1; pAvatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"

	local pStatsArea = Instance.new("Frame", PlayerPanel)
	pStatsArea.Size = UDim2.new(1, -80, 1, 0); pStatsArea.Position = UDim2.new(0, 80, 0, 0); pStatsArea.BackgroundTransparency = 1
	local pLayout = Instance.new("UIListLayout", pStatsArea); pLayout.SortOrder = Enum.SortOrder.LayoutOrder; pLayout.Padding = UDim.new(0, 4)

	PlayerNameText = Instance.new("TextLabel", pStatsArea)
	PlayerNameText.Size = UDim2.new(1, 0, 0, 15); PlayerNameText.BackgroundTransparency = 1; PlayerNameText.Font = Enum.Font.GothamBlack; PlayerNameText.TextColor3 = Color3.fromRGB(255, 255, 255); PlayerNameText.TextSize = 14; PlayerNameText.TextXAlignment = Enum.TextXAlignment.Left; PlayerNameText.TextScaled = true; PlayerNameText.Text = player.Name

	PlayerHPBar, PlayerHPText = CreateBar(pStatsArea, Color3.fromRGB(220, 40, 40), Color3.fromRGB(120, 20, 20), UDim2.new(1, 0, 0, 16), "HP: 100")
	PlayerGasBar, PlayerGasText = CreateBar(pStatsArea, Color3.fromRGB(150, 220, 255), Color3.fromRGB(60, 140, 200), UDim2.new(1, 0, 0, 12), "GAS: 100")
	PlayerNrgBar, PlayerNrgText, PlayerNrgContainer = CreateBar(pStatsArea, Color3.fromRGB(255, 150, 50), Color3.fromRGB(180, 80, 20), UDim2.new(1, 0, 0, 12), "HEAT: 0"); PlayerNrgContainer.Visible = false

	PlayerStatusBox = Instance.new("Frame", pStatsArea)
	PlayerStatusBox.Size = UDim2.new(1, 0, 0, 18); PlayerStatusBox.BackgroundTransparency = 1
	local pStatusLayout = Instance.new("UIListLayout", PlayerStatusBox); pStatusLayout.FillDirection = Enum.FillDirection.Horizontal; pStatusLayout.Padding = UDim.new(0, 2)

	local EnemyPanel = Instance.new("Frame", CombatantsFrame)
	EnemyPanel.Size = UDim2.new(1, 0, 0, 80); EnemyPanel.BackgroundTransparency = 1

	eAvatarBox = Instance.new("Frame", EnemyPanel)
	eAvatarBox.Size = UDim2.new(0, 70, 0, 70); eAvatarBox.Position = UDim2.new(1, 0, 0, 0); eAvatarBox.AnchorPoint = Vector2.new(1, 0); eAvatarBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Instance.new("UIStroke", eAvatarBox).Color = Color3.fromRGB(255, 255, 255); Instance.new("UIStroke", eAvatarBox).Thickness = 2
	local eAvatarIcon = Instance.new("TextLabel", eAvatarBox); eAvatarIcon.Size = UDim2.new(1, 0, 1, 0); eAvatarIcon.BackgroundTransparency = 1; eAvatarIcon.Font = Enum.Font.GothamBlack; eAvatarIcon.TextColor3 = Color3.fromRGB(255, 0, 0); eAvatarIcon.TextScaled = true; eAvatarIcon.Text = "?"

	local eStatsArea = Instance.new("Frame", EnemyPanel)
	eStatsArea.Size = UDim2.new(1, -80, 1, 0); eStatsArea.BackgroundTransparency = 1
	local eStatsLayout = Instance.new("UIListLayout", eStatsArea); eStatsLayout.SortOrder = Enum.SortOrder.LayoutOrder; eStatsLayout.Padding = UDim.new(0, 4); eStatsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	EnemyNameText = Instance.new("TextLabel", eStatsArea)
	EnemyNameText.Size = UDim2.new(1, 0, 0, 15); EnemyNameText.BackgroundTransparency = 1; EnemyNameText.Font = Enum.Font.GothamBlack; EnemyNameText.TextColor3 = Color3.fromRGB(255, 80, 80); EnemyNameText.TextSize = 14; EnemyNameText.TextScaled = true; EnemyNameText.TextXAlignment = Enum.TextXAlignment.Right

	local eHpCont
	EnemyHPBar, EnemyHPText, eHpCont = CreateBar(eStatsArea, Color3.fromRGB(220, 40, 40), Color3.fromRGB(120, 20, 20), UDim2.new(1, 0, 0, 16), "HP: 100")
	EnemyShieldBar = Instance.new("Frame", eHpCont); EnemyShieldBar.Size = UDim2.new(0, 0, 1, 0); EnemyShieldBar.BackgroundColor3 = Color3.fromRGB(220, 230, 240); Instance.new("UICorner", EnemyShieldBar).CornerRadius = UDim.new(0, 4); EnemyShieldBar.ZIndex = 5; EnemyHPText.ZIndex = 6

	EnemyStatusBox = Instance.new("Frame", eStatsArea)
	EnemyStatusBox.Size = UDim2.new(1, 0, 0, 18); EnemyStatusBox.BackgroundTransparency = 1
	local eStatusLayout = Instance.new("UIListLayout", EnemyStatusBox); eStatusLayout.FillDirection = Enum.FillDirection.Horizontal; eStatusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; eStatusLayout.Padding = UDim.new(0, 2)

	local FeedBox = Instance.new("Frame", MainFrame)
	FeedBox.Size = UDim2.new(0.96, 0, 0, 80); FeedBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25); FeedBox.ClipsDescendants = true; FeedBox.LayoutOrder = 3
	Instance.new("UICorner", FeedBox).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", FeedBox).Color = Color3.fromRGB(0, 0, 0); Instance.new("UIStroke", FeedBox).Thickness = 2

	LogText = Instance.new("TextLabel", FeedBox)
	LogText.Size = UDim2.new(1, -10, 1, -10); LogText.Position = UDim2.new(0, 5, 0, 5); LogText.BackgroundTransparency = 1; LogText.Font = Enum.Font.GothamMedium; LogText.TextColor3 = Color3.fromRGB(230, 230, 230); LogText.TextSize = 12; LogText.TextXAlignment = Enum.TextXAlignment.Left; LogText.TextYAlignment = Enum.TextYAlignment.Bottom; LogText.TextWrapped = true; LogText.RichText = true; LogText.Text = ""

	local BottomArea = Instance.new("Frame", MainFrame)
	BottomArea.Size = UDim2.new(0.96, 0, 0, 180); BottomArea.BackgroundColor3 = Color3.fromRGB(20, 20, 25); BottomArea.LayoutOrder = 4
	Instance.new("UICorner", BottomArea).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", BottomArea).Color = Color3.fromRGB(0, 0, 0); Instance.new("UIStroke", BottomArea).Thickness = 2

	ActionGrid = Instance.new("ScrollingFrame", BottomArea)
	ActionGrid.Size = UDim2.new(1, -10, 1, -10); ActionGrid.Position = UDim2.new(0, 5, 0, 5); ActionGrid.BackgroundTransparency = 1; ActionGrid.ScrollBarThickness = 4; ActionGrid.BorderSizePixel = 0; ActionGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y; ActionGrid.CanvasSize = UDim2.new(0,0,0,0)
	local gridLayout = Instance.new("UIGridLayout", ActionGrid)
	gridLayout.CellSize = UDim2.new(0.48, 0, 0, 40); gridLayout.CellPadding = UDim2.new(0.04, 0, 0, 10); gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

	TargetMenu = Instance.new("Frame", BottomArea)
	TargetMenu.Size = UDim2.new(1, 0, 1, 0); TargetMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TargetMenu.Visible = false
	Instance.new("UICorner", TargetMenu).CornerRadius = UDim.new(0, 4)

	local InfoPanel = Instance.new("Frame", TargetMenu)
	InfoPanel.Size = UDim2.new(0.45, 0, 1, 0); InfoPanel.BackgroundTransparency = 1

	local tHoverTitle = Instance.new("TextLabel", InfoPanel)
	tHoverTitle.Size = UDim2.new(1, -20, 0, 30); tHoverTitle.Position = UDim2.new(0, 10, 0, 10); tHoverTitle.BackgroundTransparency = 1; tHoverTitle.Font = Enum.Font.GothamBlack; tHoverTitle.TextColor3 = Color3.fromRGB(255, 215, 100); tHoverTitle.TextSize = 16; tHoverTitle.TextXAlignment = Enum.TextXAlignment.Left; tHoverTitle.Text = "SELECT TARGET"

	local tHoverDesc = Instance.new("TextLabel", InfoPanel)
	tHoverDesc.Size = UDim2.new(1, -20, 0, 100); tHoverDesc.Position = UDim2.new(0, 10, 0, 40); tHoverDesc.BackgroundTransparency = 1; tHoverDesc.Font = Enum.Font.GothamMedium; tHoverDesc.TextColor3 = Color3.fromRGB(200, 200, 200); tHoverDesc.TextSize = 12; tHoverDesc.TextXAlignment = Enum.TextXAlignment.Left; tHoverDesc.TextYAlignment = Enum.TextYAlignment.Top; tHoverDesc.TextWrapped = true; tHoverDesc.Text = "Hover over a limb to see its tactical advantage."

	local CancelBtn = Instance.new("TextButton", InfoPanel)
	CancelBtn.Size = UDim2.new(0.8, 0, 0, 40); CancelBtn.Position = UDim2.new(0.1, 0, 1, -50); CancelBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40); CancelBtn.Font = Enum.Font.GothamBlack; CancelBtn.TextColor3 = Color3.fromRGB(255, 150, 150); CancelBtn.TextSize = 14; CancelBtn.Text = "CANCEL"
	Instance.new("UICorner", CancelBtn).CornerRadius = UDim.new(0, 6)
	CancelBtn.MouseButton1Click:Connect(function() TargetMenu.Visible = false; ActionGrid.Visible = true; pendingSkillName = nil end)

	local BodyContainer = Instance.new("Frame", TargetMenu)
	BodyContainer.Size = UDim2.new(0.5, 0, 1, 0); BodyContainer.Position = UDim2.new(0.5, 0, 0, 0); BodyContainer.BackgroundTransparency = 1

	local function CreateLimb(name, size, pos, hoverText, color)
		local limb = Instance.new("TextButton", BodyContainer)
		limb.Size = size; limb.Position = pos; limb.BackgroundColor3 = color; limb.BackgroundTransparency = 0.6; limb.Text = name:upper(); limb.Font = Enum.Font.GothamBlack; limb.TextColor3 = Color3.fromRGB(255, 255, 255); limb.TextSize = 12
		Instance.new("UICorner", limb).CornerRadius = UDim.new(0, 12); Instance.new("UIStroke", limb).Color = color; limb.UIStroke.Thickness = 2

		limb.MouseEnter:Connect(function()
			TweenService:Create(limb, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()
			tHoverTitle.Text = name:upper()
			tHoverDesc.Text = hoverText
		end)
		limb.MouseLeave:Connect(function()
			TweenService:Create(limb, TweenInfo.new(0.1), {BackgroundTransparency = 0.6}):Play()
			tHoverTitle.Text = "SELECT TARGET"
			tHoverDesc.Text = "Hover over a limb to see its tactical advantage."
		end)
		limb.MouseButton1Click:Connect(function()
			if pendingSkillName and not inputLocked then
				inputLocked = true
				if cachedTooltipMgr then cachedTooltipMgr.Hide() end
				TargetMenu.Visible = false; ActionGrid.Visible = true
				Network:WaitForChild("CombatAction"):FireServer("Attack", {SkillName = pendingSkillName, TargetLimb = name})
			end
		end)
	end

	local aspect = Instance.new("UIAspectRatioConstraint", BodyContainer); aspect.AspectRatio = 0.8
	CreateLimb("Eyes", UDim2.new(0.24, 0, 0.18, 0), UDim2.new(0.5, 0, 0.08, 0), "Deals 20% Damage. Inflicts Blinded.", Color3.fromRGB(100, 100, 150))
	CreateLimb("Nape", UDim2.new(0.24, 0, 0.06, 0), UDim2.new(0.5, 0, 0.22, 0), "Deals 150% Damage. Low accuracy.", Color3.fromRGB(200, 50, 50))
	CreateLimb("Body", UDim2.new(0.48, 0, 0.38, 0), UDim2.new(0.5, 0, 0.45, 0), "Deals 100% Damage. Standard accuracy.", Color3.fromRGB(80, 120, 80))
	CreateLimb("Arms", UDim2.new(0.22, 0, 0.38, 0), UDim2.new(0.14, 0, 0.45, 0), "Deals 50% Damage. Inflicts Weakened.", Color3.fromRGB(150, 120, 50))
	CreateLimb("Arms", UDim2.new(0.22, 0, 0.38, 0), UDim2.new(0.86, 0, 0.45, 0), "Deals 50% Damage. Inflicts Weakened.", Color3.fromRGB(150, 120, 50))
	CreateLimb("Legs", UDim2.new(0.23, 0, 0.32, 0), UDim2.new(0.37, 0, 0.81, 0), "Deals 50% Damage. Inflicts Crippled.", Color3.fromRGB(60, 100, 140))
	CreateLimb("Legs", UDim2.new(0.23, 0, 0.32, 0), UDim2.new(0.63, 0, 0.81, 0), "Deals 50% Damage. Inflicts Crippled.", Color3.fromRGB(60, 100, 140))

	for _, child in ipairs(BodyContainer:GetChildren()) do if child:IsA("TextButton") then child.AnchorPoint = Vector2.new(0.5, 0.5) end end

	LeaveBtn = Instance.new("TextButton", MainFrame); LeaveBtn.Size = UDim2.new(0.6, 0, 0, 40); LeaveBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 80); LeaveBtn.Font = Enum.Font.GothamBlack; LeaveBtn.TextColor3 = Color3.fromRGB(25, 25, 30); LeaveBtn.TextSize = 16; LeaveBtn.Text = "RETURN TO BASE"; LeaveBtn.Visible = false; LeaveBtn.LayoutOrder = 5
	Instance.new("UICorner", LeaveBtn).CornerRadius = UDim.new(0, 6)

	LeaveBtn.MouseButton1Click:Connect(function()
		EffectsManager.PlaySFX("Click")
		MainFrame.Visible = false; isBattleActive = false; parentFrame.Visible = true 
		local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
		if topGui then
			if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = true end
			if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = true end
		end
	end)

	local function LockGrid()
		inputLocked = true
		for _, btn in ipairs(ActionGrid:GetChildren()) do
			if btn:IsA("TextButton") then
				btn.BackgroundColor3 = Color3.fromRGB(15, 15, 20); btn.UIStroke.Color = Color3.fromRGB(30, 30, 35); btn.TextColor3 = Color3.fromRGB(100, 100, 100)
			end
		end
	end

	local function UpdateActionGrid(battleState)
		inputLocked = false
		for _, child in ipairs(ActionGrid:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end

		local p = battleState.Player
		local pStyle = p.Style or "None"
		local pTitan = p.Titan or "None"
		local pClan = p.Clan or "None"
		local isTransformed = p.Statuses and p.Statuses["Transformed"]
		local isODM = (pStyle == "Ultrahard Steel Blades" or pStyle == "Thunder Spears" or pStyle == "Anti-Personnel")

		local function CreateBtn(sName, color, order)
			local sData = SkillData.Skills[sName]
			if not sData then return end

			if sName == "Transform" and (pClan == "Ackerman" or pClan == "Awakened Ackerman") then return end

			local cd = p.Cooldowns and p.Cooldowns[sName] or 0
			local energyCost = sData.EnergyCost or 0
			local gasCost = sData.GasCost or 0

			local hasGas = (p.Gas or 0) >= gasCost
			local hasEnergy = (p.TitanEnergy or 0) >= energyCost
			local isReady = (cd == 0) and hasGas and hasEnergy

			local btn = Instance.new("TextButton", ActionGrid)
			btn.BackgroundColor3 = isReady and (color or Color3.fromRGB(30, 30, 35)) or Color3.fromRGB(20, 20, 25)
			btn.Font = Enum.Font.GothamBold; btn.TextColor3 = isReady and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 120); btn.TextSize = 11; btn.LayoutOrder = order or 10
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
			Instance.new("UIStroke", btn).Color = isReady and Color3.fromRGB(120, 100, 60) or Color3.fromRGB(50, 50, 55)

			local cdStr = isReady and "READY" or "CD: " .. cd
			if cd == 0 then if not hasGas then cdStr = "NO GAS" elseif not hasEnergy then cdStr = "NO HEAT" end end

			btn.Text = sName:upper() .. "\n<font size='9' color='" .. (isReady and "#AAAAAA" or "#FF5555") .. "'>[" .. cdStr .. "]</font>"; btn.RichText = true

			-- [[ THE FIX: Correctly opens TargetMenu again instead of skipping it ]]
			btn.MouseButton1Click:Connect(function()
				if isBattleActive and not inputLocked and isReady then
					if sName == "Retreat" or sData.Effect == "Rest" or sData.Effect == "TitanRest" or sData.Effect == "Eject" or sData.Effect == "Transform" or sData.Effect == "Block" or sData.Effect == "Flee" then
						if cachedTooltipMgr then cachedTooltipMgr.Hide() end
						LockGrid()
						Network:WaitForChild("CombatAction"):FireServer("Attack", {SkillName = sName})
					else
						if cachedTooltipMgr then cachedTooltipMgr.Hide() end
						pendingSkillName = sName
						ActionGrid.Visible = false
						TargetMenu.Visible = true
					end
				end
			end)

			btn.MouseEnter:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Show(sData.Description or sName) end end)
			btn.MouseLeave:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Hide() end end)
		end

		if isTransformed then
			CreateBtn("Titan Recover", Color3.fromRGB(40, 140, 80), 1)
			CreateBtn("Titan Punch", Color3.fromRGB(120, 40, 40), 2)
			CreateBtn("Titan Kick", Color3.fromRGB(140, 60, 40), 3)
			CreateBtn("Eject", Color3.fromRGB(140, 40, 40), 4)

			local orderIndex = 5
			for sName, sData in pairs(SkillData.Skills) do
				if sName == "Titan Recover" or sName == "Eject" or sName == "Titan Punch" or sName == "Titan Kick" or sName == "Transform" then continue end
				if sData.Requirement == pTitan or sData.Requirement == "AnyTitan" or sData.Requirement == "Transformed" then
					CreateBtn(sName, Color3.fromRGB(60, 40, 60), sData.Order or orderIndex)
					orderIndex += 1
				end
			end
		else
			CreateBtn("Basic Slash", Color3.fromRGB(120, 40, 40), 1)
			CreateBtn("Maneuver", Color3.fromRGB(40, 80, 140), 2)
			CreateBtn("Recover", Color3.fromRGB(40, 140, 80), 3)
			CreateBtn("Retreat", Color3.fromRGB(60, 60, 70), 4)

			if pTitan ~= "None" and pClan ~= "Ackerman" and pClan ~= "Awakened Ackerman" then
				CreateBtn("Transform", Color3.fromRGB(200, 150, 50), 5)
			end

			local orderIndex = 6
			for sName, sData in pairs(SkillData.Skills) do
				if sName == "Basic Slash" or sName == "Maneuver" or sName == "Recover" or sName == "Retreat" or sName == "Transform" then continue end
				local req = sData.Requirement
				if req == pStyle or req == pClan or (req == "Ackerman" and pClan == "Awakened Ackerman") or (req == "ODM" and isODM) then
					CreateBtn(sName, Color3.fromRGB(45, 40, 60), sData.Order or orderIndex)
					orderIndex += 1
				end
			end
		end

		task.delay(0.05, function() ActionGrid.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20) end)
	end

	local function SyncBars(battleState)
		local p = battleState.Player
		local e = battleState.Enemy
		local tInfo = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

		TweenService:Create(PlayerHPBar, tInfo, {Size = UDim2.new(math.clamp(p.HP / p.MaxHP, 0, 1), 0, 1, 0)}):Play()
		PlayerHPText.Text = "HP: " .. math.floor(p.HP) .. " / " .. math.floor(p.MaxHP)
		PlayerNameText.Text = player.Name

		TweenService:Create(PlayerGasBar, tInfo, {Size = UDim2.new(math.clamp(p.Gas / p.MaxGas, 0, 1), 0, 1, 0)}):Play()
		PlayerGasText.Text = "GAS: " .. math.floor(p.Gas) .. " / " .. math.floor(p.MaxGas)

		if p.Titan and p.Titan ~= "None" and p.Clan ~= "Ackerman" and p.Clan ~= "Awakened Ackerman" then
			PlayerNrgContainer.Visible = true
			local pNrg = p.TitanEnergy or 0
			TweenService:Create(PlayerNrgBar, tInfo, {Size = UDim2.new(math.clamp(pNrg / 100, 0, 1), 0, 1, 0)}):Play()
			PlayerNrgText.Text = "HEAT: " .. math.floor(pNrg) .. " / 100"
		else
			PlayerNrgContainer.Visible = false
		end

		EnemyNameText.Text = e.Name:upper()

		if e.MaxGateHP and e.MaxGateHP > 0 then
			EnemyShieldBar.Visible = true
			TweenService:Create(EnemyShieldBar, tInfo, {Size = UDim2.new(math.clamp(e.GateHP / e.MaxGateHP, 0, 1), 0, 1, 0)}):Play()
			if e.GateHP > 0 then
				if e.GateType == "Steam" then EnemyHPText.Text = e.GateType:upper() .. ": " .. math.floor(e.GateHP) .. " TURNS LEFT"
				else EnemyHPText.Text = e.GateType:upper() .. ": " .. math.floor(e.GateHP) .. " / " .. math.floor(e.MaxGateHP) end
			else EnemyHPText.Text = "HP: " .. math.floor(e.HP) .. " / " .. math.floor(e.MaxHP) end
		else
			EnemyShieldBar.Visible = false
			EnemyHPText.Text = "HP: " .. math.floor(e.HP) .. " / " .. math.floor(e.MaxHP)
		end

		TweenService:Create(EnemyHPBar, tInfo, {Size = UDim2.new(math.clamp(e.HP / e.MaxHP, 0, 1), 0, 1, 0)}):Play()

		RenderStatuses(PlayerStatusBox, p)
		RenderStatuses(EnemyStatusBox, e)

		if battleState.Context.IsStoryMission then WaveLabel.Text = "WAVE " .. battleState.Context.CurrentWave .. " / " .. battleState.Context.TotalWaves
		elseif battleState.Context.IsPaths then WaveLabel.Text = "MEMORY " .. (player:GetAttribute("PathsFloor") or 1)
		else WaveLabel.Text = "RANDOM ENCOUNTER" end
	end

	Network:WaitForChild("CombatUpdate").OnClientEvent:Connect(function(action, data)
		if action == "Start" then
			MainFrame.Visible = true
			parentFrame.Visible = false 
			TargetMenu.Visible = false; ActionGrid.Visible = true; pendingSkillName = nil
			local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
			if topGui then
				if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = false end
				if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = false end
			end
			LeaveBtn.Visible = false; BottomArea.Visible = true; isBattleActive = true

			if data.Battle and data.Battle.Context.IsPaths then StartPathsAmbient() end

			SyncBars(data.Battle); UpdateActionGrid(data.Battle); AddLogMessage(data.LogMsg, false)

		elseif action == "TurnStrike" then
			ShakeUI(data.ShakeType); SyncBars(data.Battle); AddLogMessage(data.LogMsg, true)
			if data.SkillUsed then EffectsManager.PlayCombatEffect(data.SkillUsed, data.IsPlayerAttacking, pAvatarBox, eAvatarBox, data.DidHit) end

		elseif action == "Update" then
			SyncBars(data.Battle); UpdateActionGrid(data.Battle)

		elseif action == "WaveComplete" then
			SyncBars(data.Battle); AddLogMessage(data.LogMsg, false)
			local xpAmt = data.XP or 0; local dewsAmt = data.Dews or 0
			local rewardStr = "<font color='#55FF55'>Rewards: +" .. xpAmt .. " XP | +" .. dewsAmt .. " Dews</font>"
			if data.Items and #data.Items > 0 then rewardStr = rewardStr .. "<br/><font color='#AA55FF'>Drops: " .. table.concat(data.Items, ", ") .. "</font>" end
			if data.ExtraLog then rewardStr = rewardStr .. "<br/>" .. data.ExtraLog end
			AddLogMessage(rewardStr, true); UpdateActionGrid(data.Battle)

		elseif action == "Victory" then
			EffectsManager.PlaySFX("Victory", 1)
			SyncBars(data.Battle); isBattleActive = false; LockGrid()
			BottomArea.Visible = false; LeaveBtn.Visible = true; LeaveBtn.Text = "VICTORY - RETURN"; LeaveBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
			AddLogMessage("<b><font color='#55FF55'>ENEMY DEFEATED!</font></b>", false)
			local xpAmt = data.XP or 0; local dewsAmt = data.Dews or 0
			local rewardStr = "<font color='#55FF55'>Rewards: +" .. xpAmt .. " XP | +" .. dewsAmt .. " Dews</font>"
			if data.Items and #data.Items > 0 then rewardStr = rewardStr .. "<br/><font color='#AA55FF'>Drops: " .. table.concat(data.Items, ", ") .. "</font>" end
			if data.ExtraLog then rewardStr = rewardStr .. "<br/>" .. data.ExtraLog end
			AddLogMessage(rewardStr, true)

		elseif action == "Defeat" then
			EffectsManager.PlaySFX("Defeat", 1)
			SyncBars(data.Battle); isBattleActive = false; LockGrid()
			BottomArea.Visible = false; LeaveBtn.Visible = true; LeaveBtn.Text = "DEFEAT - RETREAT"; LeaveBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
			AddLogMessage("<b><font color='#FF5555'>YOU WERE SLAUGHTERED.</font></b>", false)

		elseif action == "Fled" then
			EffectsManager.PlaySFX("Flee", 1)
			isBattleActive = false; LockGrid()
			BottomArea.Visible = false; LeaveBtn.Visible = true; LeaveBtn.Text = "COWARD - RETURN"; LeaveBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
			AddLogMessage("<b><font color='#AAAAAA'>You fired a smoke signal and fled.</font></b>", false)
		end
	end)
end

function CombatTab.Show()
end

return CombatTab