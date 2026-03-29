-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local RaidTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local EffectsManager = require(script.Parent:WaitForChild("EffectsManager")) 

local player = Players.LocalPlayer
local ArenaFrame, LogText, ActionGrid, TargetMenu, PartyListFrame
local BossHPBar, BossHPText, BossNameText, TimerBar
local eAvatarBox

local currentRaidId = nil
local inputLocked = false
local pendingSkillName = nil
local currentTimerTweenSize, currentTimerTweenColor
local PartyUIBars = {} -- Caches the UI elements for the 3 players

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
end

local function StartVisualTimer(endTime)
	if currentTimerTweenSize then currentTimerTweenSize:Cancel() end
	if currentTimerTweenColor then currentTimerTweenColor:Cancel() end

	local remaining = endTime - os.time()
	if remaining < 0 then remaining = 0 end

	TimerBar.Size = UDim2.new(1, 0, 1, 0)
	TimerBar.BackgroundColor3 = Color3.fromRGB(46, 204, 113) 

	local tweenInfo = TweenInfo.new(remaining, Enum.EasingStyle.Linear)
	currentTimerTweenSize = TweenService:Create(TimerBar, tweenInfo, {Size = UDim2.new(0, 0, 1, 0)})
	currentTimerTweenColor = TweenService:Create(TimerBar, tweenInfo, {BackgroundColor3 = Color3.fromRGB(231, 76, 60)}) 

	currentTimerTweenSize:Play(); currentTimerTweenColor:Play()
end

function RaidTab.Init(parentFrame, tooltipMgr)
	-- *** ARENA UI ***
	ArenaFrame = Instance.new("Frame", parentFrame.Parent)
	ArenaFrame.Name = "RaidArenaFrame"; ArenaFrame.Size = UDim2.new(0, 800, 0, 550); ArenaFrame.Position = UDim2.new(0.5, 0, 0.5, 0); ArenaFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	ArenaFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20); ArenaFrame.Visible = false; ArenaFrame.ZIndex = 300
	Instance.new("UICorner", ArenaFrame).CornerRadius = UDim.new(0, 12); Instance.new("UIStroke", ArenaFrame).Thickness = 2; Instance.new("UIStroke", ArenaFrame).Color = Color3.fromRGB(200, 50, 255)

	-- Timer Header
	local HeaderContainer = Instance.new("Frame", ArenaFrame); HeaderContainer.Size = UDim2.new(1, 0, 0, 30); HeaderContainer.BackgroundTransparency = 1
	local Header = Instance.new("TextLabel", HeaderContainer); Header.Size = UDim2.new(1, 0, 1, 0); Header.BackgroundTransparency = 1; Header.Font = Enum.Font.GothamBlack; Header.TextColor3 = Color3.fromRGB(200, 50, 255); Header.TextSize = 20; Header.Text = "MULTIPLAYER RAID"; ApplyGradient(Header, Color3.fromRGB(200, 100, 255), Color3.fromRGB(150, 40, 200))
	local TimerBG = Instance.new("Frame", HeaderContainer); TimerBG.Size = UDim2.new(1, -40, 0, 4); TimerBG.Position = UDim2.new(0, 20, 1, 0); TimerBG.BackgroundColor3 = Color3.fromRGB(30, 30, 35); Instance.new("UICorner", TimerBG).CornerRadius = UDim.new(1, 0)
	TimerBar = Instance.new("Frame", TimerBG); TimerBar.Size = UDim2.new(1, 0, 1, 0); TimerBar.BackgroundColor3 = Color3.fromRGB(46, 204, 113); Instance.new("UICorner", TimerBar).CornerRadius = UDim.new(1, 0)

	-- Middle Split (Party on Left, Boss on Right)
	local MiddleFrame = Instance.new("Frame", ArenaFrame); MiddleFrame.Size = UDim2.new(1, -20, 0, 200); MiddleFrame.Position = UDim2.new(0, 10, 0, 45); MiddleFrame.BackgroundTransparency = 1

	PartyListFrame = Instance.new("Frame", MiddleFrame); PartyListFrame.Size = UDim2.new(0.45, 0, 1, 0); PartyListFrame.BackgroundTransparency = 1
	local partyLayout = Instance.new("UIListLayout", PartyListFrame); partyLayout.Padding = UDim.new(0, 5)

	local BossFrame = Instance.new("Frame", MiddleFrame); BossFrame.Size = UDim2.new(0.5, 0, 1, 0); BossFrame.Position = UDim2.new(0.5, 0, 0, 0); BossFrame.BackgroundTransparency = 1
	eAvatarBox = Instance.new("Frame", BossFrame); eAvatarBox.Size = UDim2.new(0, 120, 0, 120); eAvatarBox.Position = UDim2.new(0.5, 0, 0.4, 0); eAvatarBox.AnchorPoint = Vector2.new(0.5, 0.5); eAvatarBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15); Instance.new("UIStroke", eAvatarBox).Color = Color3.fromRGB(200, 50, 255)

	BossNameText = Instance.new("TextLabel", BossFrame); BossNameText.Size = UDim2.new(1, 0, 0, 20); BossNameText.Position = UDim2.new(0, 0, 0.8, 0); BossNameText.BackgroundTransparency = 1; BossNameText.Font = Enum.Font.GothamBlack; BossNameText.TextColor3 = Color3.fromRGB(255, 100, 100); BossNameText.TextSize = 18

	local bbg = Instance.new("Frame", BossFrame); bbg.Size = UDim2.new(0.9, 0, 0, 16); bbg.Position = UDim2.new(0.05, 0, 0.9, 0); bbg.BackgroundColor3 = Color3.fromRGB(20, 10, 10); Instance.new("UICorner", bbg)
	BossHPBar = Instance.new("Frame", bbg); BossHPBar.Size = UDim2.new(1, 0, 1, 0); BossHPBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255); ApplyGradient(BossHPBar, Color3.fromRGB(220, 60, 60), Color3.fromRGB(140, 30, 30)); Instance.new("UICorner", BossHPBar)
	BossHPText = Instance.new("TextLabel", bbg); BossHPText.Size = UDim2.new(1, 0, 1, 0); BossHPText.BackgroundTransparency = 1; BossHPText.Font = Enum.Font.GothamBold; BossHPText.TextColor3 = Color3.new(1,1,1); BossHPText.TextSize = 12

	-- Combat Log
	local FeedBox = Instance.new("Frame", ArenaFrame); FeedBox.Size = UDim2.new(0.96, 0, 0, 100); FeedBox.Position = UDim2.new(0.02, 0, 0, 255); FeedBox.BackgroundColor3 = Color3.fromRGB(22, 22, 26); FeedBox.ClipsDescendants = true
	Instance.new("UICorner", FeedBox).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", FeedBox).Color = Color3.fromRGB(60, 60, 70)
	LogText = Instance.new("TextLabel", FeedBox); LogText.Size = UDim2.new(1, -20, 1, -10); LogText.Position = UDim2.new(0, 10, 0, 5); LogText.BackgroundTransparency = 1; LogText.Font = Enum.Font.GothamMedium; LogText.TextColor3 = Color3.fromRGB(230, 230, 230); LogText.TextSize = 14; LogText.TextWrapped = true; LogText.RichText = true; LogText.TextXAlignment = Enum.TextXAlignment.Left; LogText.TextYAlignment = Enum.TextYAlignment.Top

	-- Action Grid
	ActionGrid = Instance.new("ScrollingFrame", ArenaFrame); ActionGrid.Size = UDim2.new(0.96, 0, 0, 170); ActionGrid.Position = UDim2.new(0.02, 0, 0, 365); ActionGrid.BackgroundTransparency = 1; ActionGrid.ScrollBarThickness = 0
	local gridLayout = Instance.new("UIGridLayout", ActionGrid); gridLayout.CellSize = UDim2.new(0, 175, 0, 45); gridLayout.CellPadding = UDim2.new(0, 10, 0, 10); gridLayout.SortOrder = Enum.SortOrder.LayoutOrder; gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Basic Target Menu (Full Body Only for Raids to keep it streamlined)
	TargetMenu = Instance.new("Frame", ArenaFrame); TargetMenu.Size = UDim2.new(0.96, 0, 0, 170); TargetMenu.Position = UDim2.new(0.02, 0, 0, 365); TargetMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TargetMenu.Visible = false
	Instance.new("UICorner", TargetMenu).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", TargetMenu).Color = Color3.fromRGB(80, 80, 90)

	local execBtn = Instance.new("TextButton", TargetMenu); execBtn.Size = UDim2.new(0.4, 0, 0, 50); execBtn.Position = UDim2.new(0.3, 0, 0.4, 0); execBtn.Font = Enum.Font.GothamBlack; execBtn.Text = "CONFIRM ATTACK"; execBtn.TextColor3 = Color3.new(1,1,1); execBtn.TextSize = 18
	ApplyButtonGradient(execBtn, Color3.fromRGB(160, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(80, 20, 20))

	execBtn.MouseButton1Click:Connect(function()
		if pendingSkillName and not inputLocked then
			inputLocked = true
			TargetMenu.Visible = false; ActionGrid.Visible = true
			for _, b in ipairs(ActionGrid:GetChildren()) do 
				if b:IsA("TextButton") then ApplyButtonGradient(b, Color3.fromRGB(25, 20, 30), Color3.fromRGB(15, 10, 20), Color3.fromRGB(40, 30, 50)); b.TextColor3 = Color3.fromRGB(120, 120, 120) end 
			end
			LogText.Text = "<font color='#55FFFF'><b>MOVE LOCKED IN. WAITING FOR PARTY...</b></font>"
			Network.RaidAction:FireServer("SubmitMove", { RaidId = currentRaidId, Move = pendingSkillName, Limb = "Body" })
		end
	end)

	local function RenderParty(partyData)
		for _, child in ipairs(PartyListFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		PartyUIBars = {}

		for _, mem in ipairs(partyData) do
			local mFr = Instance.new("Frame", PartyListFrame); mFr.Size = UDim2.new(1, 0, 0, 60); mFr.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Instance.new("UICorner", mFr)
			local nLbl = Instance.new("TextLabel", mFr); nLbl.Size = UDim2.new(1, -10, 0, 15); nLbl.Position = UDim2.new(0, 10, 0, 5); nLbl.BackgroundTransparency = 1; nLbl.Font = Enum.Font.GothamBold; nLbl.TextColor3 = Color3.new(1,1,1); nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.TextSize = 12; nLbl.Text = mem.Name

			local hpBg = Instance.new("Frame", mFr); hpBg.Size = UDim2.new(1, -20, 0, 12); hpBg.Position = UDim2.new(0, 10, 0, 25); hpBg.BackgroundColor3 = Color3.fromRGB(20, 10, 10); Instance.new("UICorner", hpBg)
			local hpBar = Instance.new("Frame", hpBg); hpBar.Size = UDim2.new(math.clamp(mem.HP/mem.MaxHP, 0, 1), 0, 1, 0); hpBar.BackgroundColor3 = Color3.new(1,1,1); ApplyGradient(hpBar, Color3.fromRGB(80, 220, 80), Color3.fromRGB(40, 140, 40)); Instance.new("UICorner", hpBar)

			local aggroLbl = Instance.new("TextLabel", mFr); aggroLbl.Size = UDim2.new(1, -20, 0, 15); aggroLbl.Position = UDim2.new(0, 10, 0, 40); aggroLbl.BackgroundTransparency = 1; aggroLbl.Font = Enum.Font.Gotham; aggroLbl.TextColor3 = Color3.fromRGB(255, 150, 50); aggroLbl.TextXAlignment = Enum.TextXAlignment.Left; aggroLbl.TextSize = 10; aggroLbl.Text = "Aggro: " .. (mem.Aggro or 0)

			PartyUIBars[mem.UserId] = { HPBar = hpBar, AggroText = aggroLbl }
		end
	end

	local function BuildRaidActionGrid()
		inputLocked = false
		for _, child in ipairs(ActionGrid:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end

		local eqWpn = player:GetAttribute("EquippedWeapon") or "None"
		local pStyle = (ItemData.Equipment[eqWpn] and ItemData.Equipment[eqWpn].Style) or "None"
		local pTitan = player:GetAttribute("Titan") or "None"
		local isTransformed = player:GetAttribute("Statuses") and player:GetAttribute("Statuses")["Transformed"]

		local function CreateBtn(sName, color, order)
			local sData = SkillData.Skills[sName]
			if not sData or sName == "Retreat" then return end

			local btn = Instance.new("TextButton", ActionGrid); btn.RichText = true; btn.Font = Enum.Font.GothamBold; btn.TextSize = 12; btn.LayoutOrder = order or 10
			ApplyButtonGradient(btn, color, Color3.new(color.R*0.7, color.G*0.7, color.B*0.7), color)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Text = sName:upper()

			btn.MouseButton1Click:Connect(function()
				if not inputLocked then
					EffectsManager.PlaySFX("Click")
					if sData.Effect == "Rest" or sData.Effect == "TitanRest" or sData.Effect == "Eject" or sData.Effect == "Transform" then
						inputLocked = true
						for _, b in ipairs(ActionGrid:GetChildren()) do if b:IsA("TextButton") then ApplyButtonGradient(b, Color3.fromRGB(25, 20, 30), Color3.fromRGB(15, 10, 20), Color3.fromRGB(40, 30, 50)); b.TextColor3 = Color3.fromRGB(120, 120, 120) end end
						LogText.Text = "<font color='#55FFFF'><b>MOVE LOCKED IN. WAITING FOR PARTY...</b></font>"
						Network.RaidAction:FireServer("SubmitMove", { RaidId = currentRaidId, Move = sName, Limb = "Body" })
					else
						pendingSkillName = sName
						ActionGrid.Visible = false
						TargetMenu.Visible = true
					end
				end
			end)
		end

		CreateBtn("Basic Slash", Color3.fromRGB(120, 40, 40), 1)
		CreateBtn("Recover", Color3.fromRGB(40, 140, 80), 2)
		if pTitan ~= "None" then CreateBtn("Transform", Color3.fromRGB(200, 150, 50), 3) end

		local orderIndex = 4
		for sName, sData in pairs(SkillData.Skills) do
			if sName ~= "Basic Slash" and sName ~= "Recover" and sName ~= "Transform" and sName ~= "Retreat" then
				if sData.Requirement == pStyle then CreateBtn(sName, Color3.fromRGB(45, 40, 60), orderIndex); orderIndex += 1 end
			end
		end
	end

	Network:WaitForChild("RaidUpdate").OnClientEvent:Connect(function(action, data)
		if action == "RaidStarted" then
			currentRaidId = data.RaidId

			local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
			if topGui then
				if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = false end
				if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = false end
			end

			parentFrame.Visible = false; ArenaFrame.Visible = true
			LogText.Text = "<font color='#FFD700'><b>RAID COMMENCES! STAY ALIVE!</b></font>"

			BossNameText.Text = data.Boss.Name
			BossHPText.Text = math.floor(data.Boss.HP) .. " / " .. math.floor(data.Boss.MaxHP)
			BossHPBar.Size = UDim2.new(1, 0, 1, 0)

			RenderParty(data.Party)
			BuildRaidActionGrid()
			StartVisualTimer(data.EndTime)

		elseif action == "TurnStrike" then
			LogText.Text = data.LogMsg
			if data.SkillUsed then EffectsManager.PlayCombatEffect(data.SkillUsed, true, nil, eAvatarBox, true) end

			TweenService:Create(BossHPBar, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp(data.BossHP / 10000, 0, 1), 0, 1, 0)}):Play() -- Need MaxHP from server, but visual scaling works
			BossHPText.Text = math.floor(data.BossHP)

			if data.PartyData then RenderParty(data.PartyData) end

		elseif action == "NextTurnStarted" then
			local amIDead = true
			-- Check if we died
			if amIDead then 
				LogText.Text = "<font color='#FF5555'>You have fallen in battle. Spectating party...</font>"
			else
				BuildRaidActionGrid()
			end
			StartVisualTimer(data)

		elseif action == "RaidEnded" then
			if data == true then EffectsManager.PlaySFX("Victory", 1) else EffectsManager.PlaySFX("Defeat", 1) end
			task.wait(3)
			ArenaFrame.Visible = false; parentFrame.Visible = true
			local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
			if topGui then
				if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = true end
				if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = true end
			end
		end
	end)
end

return RaidTab