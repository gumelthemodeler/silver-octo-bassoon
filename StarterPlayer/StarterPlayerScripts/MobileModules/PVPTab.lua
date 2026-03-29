-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService") 
local LocalPlayer = Players.LocalPlayer 

local Network = ReplicatedStorage:WaitForChild("Network")

-- The Client ONLY waits for remotes, never creates them.
local PvPAction = Network:WaitForChild("PvPAction")
local PvPUpdate = Network:WaitForChild("PvPUpdate")
local PvPTaunt = Network:WaitForChild("PvPTaunt")

local PvPTab = {}
local ActiveMatches = {}
local CurrentViewedMatch = nil

-- UI References
local GUI, MainFrame, BettingBoard, SpectatorView, ActionPanel, MatchScroll

-- [[ 1. UI GENERATION FACTORY ]]
local function createUIElement(className, properties, parent)
	local el = Instance.new(className)
	for k, v in pairs(properties) do el[k] = v end
	if parent then el.Parent = parent end
	return el
end

function PvPTab.InitializeUI()
	if LocalPlayer.PlayerGui:FindFirstChild("PvPGui") then
		LocalPlayer.PlayerGui.PvPGui:Destroy()
	end

	GUI = createUIElement("ScreenGui", {Name = "PvPGui", ResetOnSpawn = false, IgnoreGuiInset = true}, LocalPlayer.PlayerGui)

	-- Main Background
	MainFrame = createUIElement("Frame", {
		Name = "MainFrame", Size = UDim2.new(0.6, 0, 0.7, 0), Position = UDim2.new(0.2, 0, 0.15, 0),
		BackgroundColor3 = Color3.fromRGB(30, 30, 35), BorderSizePixel = 0, Visible = false
	}, GUI)
	createUIElement("UICorner", {CornerRadius = UDim.new(0, 8)}, MainFrame)
	createUIElement("UIStroke", {Color = Color3.fromRGB(100, 100, 110), Thickness = 2}, MainFrame)

	local Title = createUIElement("TextLabel", {
		Name = "Title", Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
		Text = "UNDERGROUND ARENA", TextColor3 = Color3.fromRGB(220, 220, 220), 
		Font = Enum.Font.GothamBold, TextSize = 24
	}, MainFrame)

	-- [[ BETTING BOARD (Default View) ]]
	BettingBoard = createUIElement("Frame", {
		Name = "BettingBoard", Size = UDim2.new(1, -20, 1, -60), Position = UDim2.new(0, 10, 0, 50),
		BackgroundTransparency = 1
	}, MainFrame)

	-- [[ NEW: QUEUE BUTTON ]]
	local QueueBtn = createUIElement("TextButton", {
		Name = "QueueBtn", Size = UDim2.new(0.4, 0, 0, 40), Position = UDim2.new(0.3, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(52, 152, 219), Text = "FIND MATCH",
		TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 16
	}, BettingBoard)
	createUIElement("UICorner", {CornerRadius = UDim.new(0, 6)}, QueueBtn)

	QueueBtn.MouseButton1Click:Connect(function()
		PvPAction:FireServer("JoinQueue")
		QueueBtn.Text = "SEARCHING..."
		QueueBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
	end)

	-- We moved the MatchScroll down by 50 pixels to make room for the Queue button
	MatchScroll = createUIElement("ScrollingFrame", {
		Name = "MatchScroll", Size = UDim2.new(1, 0, 1, -50), Position = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 1, ScrollBarThickness = 6, CanvasSize = UDim2.new(0, 0, 0, 0)
	}, BettingBoard)
	createUIElement("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, MatchScroll)

	MatchScroll = createUIElement("ScrollingFrame", {
		Name = "MatchScroll", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
		ScrollBarThickness = 6, CanvasSize = UDim2.new(0, 0, 0, 0)
	}, BettingBoard)
	createUIElement("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, MatchScroll)

	-- [[ SPECTATOR VIEW (Hidden by default) ]]
	SpectatorView = createUIElement("Frame", {
		Name = "SpectatorView", Size = UDim2.new(1, -20, 1, -60), Position = UDim2.new(0, 10, 0, 50),
		BackgroundTransparency = 1, Visible = false
	}, MainFrame)

	-- Player 1 Health Bar
	local p1Container = createUIElement("Frame", {Name = "P1Container", Size = UDim2.new(0.4, 0, 0, 50), Position = UDim2.new(0.05, 0, 0.1, 0), BackgroundColor3 = Color3.fromRGB(20, 20, 20)}, SpectatorView)
	createUIElement("TextLabel", {Name = "NameLabel", Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.new(0,0,-0.6,0), BackgroundTransparency = 1, Text = "Player 1", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamSemibold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left}, p1Container)
	createUIElement("Frame", {Name = "HealthBar", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(46, 204, 113)}, p1Container)

	-- Player 2 Health Bar
	local p2Container = createUIElement("Frame", {Name = "P2Container", Size = UDim2.new(0.4, 0, 0, 50), Position = UDim2.new(0.55, 0, 0.1, 0), BackgroundColor3 = Color3.fromRGB(20, 20, 20)}, SpectatorView)
	createUIElement("TextLabel", {Name = "NameLabel", Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.new(0,0,-0.6,0), BackgroundTransparency = 1, Text = "Player 2", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamSemibold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right}, p2Container)
	createUIElement("Frame", {Name = "HealthBar", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(231, 76, 60)}, p2Container)

	-- Combat Text / VFX Area
	createUIElement("TextLabel", {Name = "CombatLog", Size = UDim2.new(0.8, 0, 0.4, 0), Position = UDim2.new(0.1, 0, 0.3, 0), BackgroundTransparency = 1, Text = "Waiting for fighters...", TextColor3 = Color3.fromRGB(255, 215, 0), Font = Enum.Font.GothamBold, TextSize = 22, TextWrapped = true}, SpectatorView)

	local LeaveBtn = createUIElement("TextButton", {Size = UDim2.new(0.2, 0, 0, 40), Position = UDim2.new(0.4, 0, 0.85, 0), BackgroundColor3 = Color3.fromRGB(192, 57, 43), Text = "Leave Match", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 16}, SpectatorView)
	LeaveBtn.MouseButton1Click:Connect(PvPTab.CloseSpectatorView)

	-- [[ ACTION PANEL (For Fighters) ]]
	ActionPanel = createUIElement("Frame", {Name = "ActionPanel", Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.new(0, 0, 0.7, 0), BackgroundTransparency = 1, Visible = false}, SpectatorView)
	createUIElement("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10)}, ActionPanel)
end

-- [[ 2. DYNAMIC MATCH GENERATION ]]
function PvPTab.RefreshBettingBoard()
	for _, child in pairs(MatchScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local yOffset = 0
	for matchId, matchInfo in pairs(ActiveMatches) do
		local matchFrame = createUIElement("Frame", {Size = UDim2.new(1, -10, 0, 80), BackgroundColor3 = Color3.fromRGB(40, 40, 45)}, MatchScroll)
		createUIElement("UICorner", {CornerRadius = UDim.new(0, 6)}, matchFrame)

		createUIElement("TextLabel", {Size = UDim2.new(0.4, 0, 0.4, 0), Position = UDim2.new(0.05, 0, 0.1, 0), BackgroundTransparency = 1, Text = matchInfo.P1 .. " VS " .. matchInfo.P2, TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left}, matchFrame)

		-- Bet Input
		local BetInput = createUIElement("TextBox", {Size = UDim2.new(0.2, 0, 0.4, 0), Position = UDim2.new(0.05, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(20, 20, 20), TextColor3 = Color3.new(1,1,1), PlaceholderText = "Dews to Bet...", Font = Enum.Font.Gotham, TextSize = 14}, matchFrame)

		-- Bet P1 Button
		local BetP1 = createUIElement("TextButton", {Size = UDim2.new(0.15, 0, 0.4, 0), Position = UDim2.new(0.28, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(46, 204, 113), Text = "Bet " .. matchInfo.P1, TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 12}, matchFrame)
		BetP1.MouseButton1Click:Connect(function() PvPAction:FireServer("PlaceBet", matchId, matchInfo.P1_Id, tonumber(BetInput.Text) or 0) end)

		-- Spectate Button
		local WatchBtn = createUIElement("TextButton", {Size = UDim2.new(0.2, 0, 0.4, 0), Position = UDim2.new(0.75, 0, 0.3, 0), BackgroundColor3 = Color3.fromRGB(52, 152, 219), Text = "Spectate", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 16}, matchFrame)
		WatchBtn.MouseButton1Click:Connect(function() PvPTab.OpenSpectatorView(matchId, matchInfo) end)

		yOffset += 90
	end
	MatchScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

-- [[ 3. VIEW MANAGEMENT ]]
function PvPTab.OpenSpectatorView(matchId, matchInfo)
	CurrentViewedMatch = matchId
	BettingBoard.Visible = false
	SpectatorView.Visible = true

	-- Setup Names 
	SpectatorView.P1Container.NameLabel.Text = matchInfo.P1
	SpectatorView.P2Container.NameLabel.Text = matchInfo.P2

	-- Reset Health Bars
	SpectatorView.P1Container.HealthBar.Size = UDim2.new(1, 0, 1, 0)
	SpectatorView.P2Container.HealthBar.Size = UDim2.new(1, 0, 1, 0)
	SpectatorView.CombatLog.Text = "Waiting for fighters..."

	-- Enable action panel if playing
	if matchInfo.P1 == LocalPlayer.Name or matchInfo.P2 == LocalPlayer.Name then
		ActionPanel.Visible = true
	else
		ActionPanel.Visible = false
	end
end

function PvPTab.CloseSpectatorView()
	CurrentViewedMatch = nil
	SpectatorView.Visible = false
	BettingBoard.Visible = true
end

-- [[ 4. NETWORKING & COMBAT ANIMATION ]]
PvPUpdate.OnClientEvent:Connect(function(updateType, matchId, data1, data2, p1Id, p2Id)
	if updateType == "MatchStarted" then
		ActiveMatches[matchId] = { P1 = data1, P2 = data2, P1_Id = p1Id, P2_Id = p2Id }

		-- Reset the Queue Button if the LocalPlayer was the one who got matched
		if data1 == LocalPlayer.Name or data2 == LocalPlayer.Name then
			local qBtn = BettingBoard:FindFirstChild("QueueBtn")
			if qBtn then
				qBtn.Text = "FIND MATCH"
				qBtn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
			end
			-- Automatically open the spectator/combat view for the fighters
			PvPTab.OpenSpectatorView(matchId, ActiveMatches[matchId])
		end

		if BettingBoard.Visible then PvPTab.RefreshBettingBoard() end

	elseif updateType == "MatchEnded" then
		ActiveMatches[matchId] = nil
		if CurrentViewedMatch == matchId then
			SpectatorView.CombatLog.Text = "Match Ended!"
			task.wait(3)
			PvPTab.CloseSpectatorView()
		end
		if BettingBoard.Visible then PvPTab.RefreshBettingBoard() end

	elseif updateType == "TurnResolved" and CurrentViewedMatch == matchId then
		local combatData = data1
		local log = SpectatorView.CombatLog

		-- First Strike
		if combatData.First.Damage > 0 then
			log.Text = combatData.First.Player .. " used " .. combatData.First.Move .. " dealing " .. combatData.First.Damage .. " damage!"
			local targetHP = math.max(0, combatData.First.NewHP / 100) 

			local targetBar = (combatData.First.Player == ActiveMatches[matchId].P1) and SpectatorView.P2Container.HealthBar or SpectatorView.P1Container.HealthBar
			TweenService:Create(targetBar, TweenInfo.new(0.5), {Size = UDim2.new(targetHP, 0, 1, 0)}):Play()
			task.wait(1.5)
		end

		-- Second Strike
		if combatData.Second.Move ~= "None" then
			log.Text = combatData.Second.Player .. " used " .. combatData.Second.Move .. " dealing " .. combatData.Second.Damage .. " damage!"
			local targetHP = math.max(0, combatData.Second.NewHP / 100)

			local targetBar = (combatData.Second.Player == ActiveMatches[matchId].P1) and SpectatorView.P2Container.HealthBar or SpectatorView.P1Container.HealthBar
			TweenService:Create(targetBar, TweenInfo.new(0.5), {Size = UDim2.new(targetHP, 0, 1, 0)}):Play()
			task.wait(1.5)
		end

		log.Text = "Waiting for next turn..."
	end
end)

function PvPTab.Toggle()
	if not GUI then PvPTab.InitializeUI() end
	MainFrame.Visible = not MainFrame.Visible
end

return PvPTab