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
local MAX_LOG_MESSAGES = 3 

local cachedTooltipMgr

local PathsShopOverlay
local PSModal
local psDust
local psScroll
local PopulatePathsShop

local function AddLogMessage(msgText, append)
	if not msgText or msgText == "" then return end
	if append then 
		table.insert(logMessages, msgText)
		if #logMessages > MAX_LOG_MESSAGES then table.remove(logMessages, 1) end
	else 
		logMessages = {msgText} 
	end
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
		btn:GetPropertyChangedSignal("TextSize"):Connect(function() textLbl.TextSize = btn.TextSize end)
	end
end

local function CreateBar(parent, color1, color2, size, labelText, alignRight)
	local container = Instance.new("Frame", parent)
	container.Size = size; container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", container).Color = Color3.fromRGB(60, 60, 70)

	local fill = Instance.new("Frame", container)
	fill.Size = UDim2.new(1, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	if alignRight then
		fill.AnchorPoint = Vector2.new(1, 0); fill.Position = UDim2.new(1, 0, 0, 0)
	end

	local grad = Instance.new("UIGradient", fill); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}; grad.Rotation = 90

	local text = Instance.new("TextLabel", container)
	text.Size = UDim2.new(1, alignRight and -10 or -10, 1, 0); text.Position = UDim2.new(0, alignRight and 0 or 10, 0, 0); text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold; text.TextColor3 = Color3.fromRGB(255, 255, 255); text.TextSize = 10; text.TextStrokeTransparency = 0.5; text.Text = labelText
	text.TextXAlignment = alignRight and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	text.ZIndex = 5
	return fill, text, container
end

local function RenderStatuses(container, combatant, isRight)
	for _, child in ipairs(container:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
	local function addIcon(iconTxt, bgColor, strokeColor, tooltipText)
		local f = Instance.new("Frame", container)
		f.Size = UDim2.new(0, 22, 0, 16); f.BackgroundColor3 = bgColor; Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", f).Color = strokeColor
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
			if sName == "Telegraphing" and type(duration) == "string" then
				addIcon("WRN", Color3.fromRGB(200, 100, 0), Color3.fromRGB(255, 150, 0), "Charging Attack: " .. duration)
			elseif type(duration) == "number" and duration > 0 then
				if sName == "Bleed" then addIcon("BLD", Color3.fromRGB(150, 20, 20), Color3.fromRGB(255, 50, 50), "Bleeding (" .. duration .. ")")
				elseif sName == "Burn" then addIcon("BRN", Color3.fromRGB(200, 80, 20), Color3.fromRGB(255, 120, 50), "Burning (" .. duration .. ")")
				elseif sName == "Stun" then addIcon("STN", Color3.fromRGB(200, 200, 80), Color3.fromRGB(255, 255, 150), "Stunned (" .. duration .. ")")
				elseif sName == "NapeGuard" then addIcon("GRD", Color3.fromRGB(100, 60, 150), Color3.fromRGB(150, 100, 200), "Nape Guard (" .. duration .. ")")
				elseif sName == "Confusion" then addIcon("CNF", Color3.fromRGB(150, 80, 150), Color3.fromRGB(200, 100, 200), "Confused (" .. duration .. ")")
				elseif sName == "Debuff_Defense" then addIcon("BRK", Color3.fromRGB(120, 60, 60), Color3.fromRGB(200, 100, 100), "Defense Broken (" .. duration .. ")")
				elseif sName == "Crippled" then addIcon("CRP", Color3.fromRGB(80, 80, 80), Color3.fromRGB(120, 120, 120), "Crippled (" .. duration .. ")")
				elseif sName == "Immobilized" then addIcon("IMB", Color3.fromRGB(40, 120, 40), Color3.fromRGB(80, 200, 80), "Immobilized (" .. duration .. ")")
				elseif sName == "Weakened" then addIcon("WEK", Color3.fromRGB(120, 80, 40), Color3.fromRGB(200, 120, 60), "Weakened (" .. duration .. ")")
				elseif sName == "Blinded" then addIcon("BLN", Color3.fromRGB(40, 40, 40), Color3.fromRGB(80, 80, 80), "Blinded (" .. duration .. ")")
				elseif sName == "TrueBlind" then addIcon("TBL", Color3.fromRGB(20, 20, 20), Color3.fromRGB(50, 50, 50), "True Blind (" .. duration .. ")")
				elseif sName == "Buff_Strength" or sName == "Buff_Defense" then addIcon("BUF", Color3.fromRGB(20, 120, 20), Color3.fromRGB(40, 200, 40), "Buff Active (" .. duration .. ")")
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

function CombatTab.Init(parentFrame, tooltipMgr)
	cachedTooltipMgr = tooltipMgr
	if EffectsManager and type(EffectsManager.Init) == "function" then EffectsManager.Init() end

	AmbientContainer = Instance.new("Frame", parentFrame.Parent)
	AmbientContainer.Name = "PathsAmbientContainer"
	AmbientContainer.Size = UDim2.new(1, 0, 1, 0)
	AmbientContainer.BackgroundTransparency = 1
	AmbientContainer.ZIndex = 50 
	AmbientContainer.Visible = false

	MainFrame = Instance.new("Frame", parentFrame.Parent)
	MainFrame.Name = "CombatFrame"
	MainFrame.Size = UDim2.new(0.95, 0, 0.95, 0) 
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	MainFrame.Visible = false
	MainFrame.ZIndex = 200
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
	local outerStroke = Instance.new("UIStroke", MainFrame); outerStroke.Thickness = 2; outerStroke.Color = Color3.fromRGB(200, 160, 50); outerStroke.LineJoinMode = Enum.LineJoinMode.Miter

	PathsShopOverlay = Instance.new("TextButton", parentFrame.Parent)
	PathsShopOverlay.Name = "PathsShopOverlay"
	PathsShopOverlay.Size = UDim2.new(1, 0, 1, 0)
	PathsShopOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	PathsShopOverlay.BackgroundTransparency = 1
	PathsShopOverlay.Text = ""
	PathsShopOverlay.AutoButtonColor = false
	PathsShopOverlay.ZIndex = 1000
	PathsShopOverlay.Visible = false

	PSModal = Instance.new("Frame", PathsShopOverlay)
	PSModal.Size = UDim2.new(0.95, 0, 0.95, 0)
	PSModal.Position = UDim2.new(0.5, 0, 0.5, 0)
	PSModal.AnchorPoint = Vector2.new(0.5, 0.5)
	PSModal.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	PSModal.Visible = false
	Instance.new("UICorner", PSModal).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", PSModal).Color = Color3.fromRGB(85, 255, 255)

	local modalBlocker = Instance.new("TextButton", PSModal)
	modalBlocker.Size = UDim2.new(1, 0, 1, 0); modalBlocker.BackgroundTransparency = 1; modalBlocker.Text = ""; modalBlocker.ZIndex = 1

	local psHeader = Instance.new("Frame", PSModal)
	psHeader.Size = UDim2.new(1, 0, 0, 40); psHeader.BackgroundColor3 = Color3.fromRGB(20, 20, 25); psHeader.ZIndex = 2
	Instance.new("UICorner", psHeader).CornerRadius = UDim.new(0, 12)

	local psTitle = Instance.new("TextLabel", psHeader)
	psTitle.Size = UDim2.new(0.5, 0, 1, 0); psTitle.Position = UDim2.new(0, 10, 0, 0); psTitle.BackgroundTransparency = 1; psTitle.Font = Enum.Font.GothamBlack; psTitle.TextColor3 = Color3.fromRGB(85, 255, 255); psTitle.TextSize = 14; psTitle.TextXAlignment = Enum.TextXAlignment.Left; psTitle.Text = "THE PATHS"
	psTitle.ZIndex = 2

	psDust = Instance.new("TextLabel", psHeader)
	psDust.Size = UDim2.new(0.5, 0, 1, 0); psDust.Position = UDim2.new(0.5, -10, 0, 0); psDust.BackgroundTransparency = 1; psDust.Font = Enum.Font.GothamBlack; psDust.TextColor3 = Color3.fromRGB(255, 255, 255); psDust.TextSize = 14; psDust.TextXAlignment = Enum.TextXAlignment.Right; psDust.Text = "PATH DUST: 0"
	psDust.ZIndex = 2

	local psLeaveBtn = Instance.new("TextButton", PSModal)
	psLeaveBtn.Size = UDim2.new(1, -20, 0, 45); psLeaveBtn.Position = UDim2.new(0, 10, 1, -55)
	psLeaveBtn.Font = Enum.Font.GothamBlack; psLeaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255); psLeaveBtn.TextSize = 14; psLeaveBtn.Text = "SCATTER DUST & LEAVE"; psLeaveBtn.ZIndex = 3
	ApplyButtonGradient(psLeaveBtn, Color3.fromRGB(150, 50, 50), Color3.fromRGB(80, 20, 20), Color3.fromRGB(100, 30, 30))

	psScroll = Instance.new("ScrollingFrame", PSModal)
	psScroll.Size = UDim2.new(1, -10, 1, -110); psScroll.Position = UDim2.new(0, 5, 0, 45); psScroll.BackgroundTransparency = 1; psScroll.ScrollBarThickness = 0; psScroll.ZIndex = 2
	local psLayout = Instance.new("UIListLayout", psScroll); psLayout.Padding = UDim.new(0, 10); psLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local function ClosePathsShop()
		Network.ShopAction:FireServer("ClosePathsShop")
		TweenService:Create(PathsShopOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
		PSModal.Visible = false
		task.wait(0.5)
		TweenService:Create(PathsShopOverlay, TweenInfo.new(1.0), {BackgroundTransparency = 1}):Play()
		task.wait(1.0)
		PathsShopOverlay.Visible = false

		if _G.AOT_OpenCategory and _G.AOT_SwitchTab then
			_G.AOT_OpenCategory("PLAYER")
			_G.AOT_SwitchTab("Profile")
		end
	end

	PathsShopOverlay.MouseButton1Click:Connect(ClosePathsShop)
	psLeaveBtn.MouseButton1Click:Connect(ClosePathsShop)

	PopulatePathsShop = function(data)
		psDust.Text = "PATH DUST: " .. tostring(data.Dust)
		for _, c in ipairs(psScroll:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end

		local nLbl = Instance.new("TextLabel", psScroll)
		nLbl.Size = UDim2.new(1, 0, 0, 25); nLbl.BackgroundTransparency = 1; nLbl.Font = Enum.Font.GothamBlack; nLbl.TextColor3 = Color3.fromRGB(200, 200, 200); nLbl.TextSize = 14; nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.Text = "MEMORY NODES (Stat Upgrades)"

		local nGrid = Instance.new("Frame", psScroll)
		nGrid.Size = UDim2.new(1, 0, 0, 0); nGrid.AutomaticSize = Enum.AutomaticSize.Y; nGrid.BackgroundTransparency = 1
		local ngl = Instance.new("UIGridLayout", nGrid); ngl.CellSize = UDim2.new(1, 0, 0, 90); ngl.CellPadding = UDim2.new(0, 0, 0, 10); ngl.SortOrder = Enum.SortOrder.LayoutOrder

		for _, node in ipairs(data.Nodes) do
			local card = Instance.new("Frame", nGrid)
			card.BackgroundColor3 = Color3.fromRGB(22, 22, 28); Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6); local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(85, 255, 255); stroke.Thickness = 1; stroke.Transparency = 0.5

			local cTitle = Instance.new("TextLabel", card); cTitle.Size = UDim2.new(1, -20, 0, 20); cTitle.Position = UDim2.new(0, 10, 0, 5); cTitle.BackgroundTransparency = 1; cTitle.Font = Enum.Font.GothamBlack; cTitle.TextColor3 = Color3.fromRGB(255, 215, 100); cTitle.TextSize = 13; cTitle.TextXAlignment = Enum.TextXAlignment.Left; cTitle.Text = node.Name
			local cDesc = Instance.new("TextLabel", card); cDesc.Size = UDim2.new(1, -20, 0, 30); cDesc.Position = UDim2.new(0, 10, 0, 25); cDesc.BackgroundTransparency = 1; cDesc.Font = Enum.Font.GothamMedium; cDesc.TextColor3 = Color3.fromRGB(200, 200, 200); cDesc.TextSize = 10; cDesc.TextWrapped = true; cDesc.TextXAlignment = Enum.TextXAlignment.Left; cDesc.TextYAlignment = Enum.TextYAlignment.Top; cDesc.Text = node.Desc

			local btn = Instance.new("TextButton", card); btn.Size = UDim2.new(0.45, 0, 0, 25); btn.Position = UDim2.new(1, -10, 1, -30); btn.AnchorPoint = Vector2.new(1, 0); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 10; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
			if type(node.Cost) == "number" then
				btn.Text = "AWAKEN (" .. node.Cost .. ")"
				ApplyButtonGradient(btn, Color3.fromRGB(40, 120, 120), Color3.fromRGB(20, 60, 60), Color3.fromRGB(30, 80, 80))
				btn.MouseButton1Click:Connect(function()
					if data.Dust >= node.Cost then
						Network.ShopAction:FireServer("BuyPathNode", node.Name)
						task.delay(0.2, function()
							local nd = Network.GetShopData:InvokeServer("PathsShop")
							if nd then PopulatePathsShop(nd) end
						end)
					end
				end)
			else
				btn.Text = "MAX LEVEL"
				ApplyButtonGradient(btn, Color3.fromRGB(60, 60, 65), Color3.fromRGB(30, 30, 35), Color3.fromRGB(80, 80, 90)); btn.TextColor3 = Color3.fromRGB(150, 150, 150)
			end
		end

		local rLbl = Instance.new("TextLabel", psScroll)
		rLbl.Size = UDim2.new(1, 0, 0, 30); rLbl.BackgroundTransparency = 1; rLbl.Font = Enum.Font.GothamBlack; rLbl.TextColor3 = Color3.fromRGB(255, 100, 100); rLbl.TextSize = 14; rLbl.TextXAlignment = Enum.TextXAlignment.Left; rLbl.Text = "ANCIENT RELICS (Rare Items)"

		local rGrid = Instance.new("Frame", psScroll)
		rGrid.Size = UDim2.new(1, 0, 0, 0); rGrid.AutomaticSize = Enum.AutomaticSize.Y; rGrid.BackgroundTransparency = 1
		local rgl = Instance.new("UIGridLayout", rGrid); rgl.CellSize = UDim2.new(1, 0, 0, 90); rgl.CellPadding = UDim2.new(0, 0, 0, 10); rgl.SortOrder = Enum.SortOrder.LayoutOrder

		for _, item in ipairs(data.Items) do
			local card = Instance.new("Frame", rGrid)
			card.BackgroundColor3 = Color3.fromRGB(22, 22, 28); Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6); local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(255, 100, 100); stroke.Thickness = 1; stroke.Transparency = 0.5

			local cTitle = Instance.new("TextLabel", card); cTitle.Size = UDim2.new(1, -20, 0, 20); cTitle.Position = UDim2.new(0, 10, 0, 5); cTitle.BackgroundTransparency = 1; cTitle.Font = Enum.Font.GothamBlack; cTitle.TextColor3 = Color3.fromRGB(255, 150, 150); cTitle.TextSize = 13; cTitle.TextXAlignment = Enum.TextXAlignment.Left; cTitle.Text = item.Name
			local cDesc = Instance.new("TextLabel", card); cDesc.Size = UDim2.new(1, -20, 0, 30); cDesc.Position = UDim2.new(0, 10, 0, 25); cDesc.BackgroundTransparency = 1; cDesc.Font = Enum.Font.GothamMedium; cDesc.TextColor3 = Color3.fromRGB(200, 200, 200); cDesc.TextSize = 10; cDesc.TextWrapped = true; cDesc.TextXAlignment = Enum.TextXAlignment.Left; cDesc.TextYAlignment = Enum.TextYAlignment.Top; cDesc.Text = item.Desc

			local btn = Instance.new("TextButton", card); btn.Size = UDim2.new(0.5, 0, 0, 25); btn.Position = UDim2.new(0.5, -10, 1, -30); btn.AnchorPoint = Vector2.new(0, 0); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 10; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
			btn.Text = "BUY (" .. item.Cost .. ")"
			ApplyButtonGradient(btn, Color3.fromRGB(150, 50, 50), Color3.fromRGB(80, 20, 20), Color3.fromRGB(100, 30, 30))

			btn.MouseButton1Click:Connect(function()
				if data.Dust >= item.Cost then
					Network.ShopAction:FireServer("BuyPathsItem", item.Name)
					task.delay(0.2, function()
						local nd = Network.GetShopData:InvokeServer("PathsShop")
						if nd then PopulatePathsShop(nd) end
					end)
				end
			end)
		end

		task.delay(0.05, function() psScroll.CanvasSize = UDim2.new(0, 0, 0, psLayout.AbsoluteContentSize.Y + 20) end)
	end

	local mainLayout = Instance.new("UIListLayout", MainFrame)
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.Padding = UDim.new(0, 5); mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local mainPadding = Instance.new("UIPadding", MainFrame)
	mainPadding.PaddingTop = UDim.new(0, 5); mainPadding.PaddingBottom = UDim.new(0, 5)

	WaveLabel = Instance.new("TextLabel", MainFrame)
	WaveLabel.Size = UDim2.new(1, 0, 0, 18); WaveLabel.BackgroundTransparency = 1
	WaveLabel.Font = Enum.Font.GothamBlack; WaveLabel.TextColor3 = Color3.fromRGB(255, 215, 100); WaveLabel.TextSize = 14; WaveLabel.Text = "WAVE 1/1"
	WaveLabel.LayoutOrder = 1
	local grad = Instance.new("UIGradient", WaveLabel); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 100)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 50))}

	local CombatantsFrame = Instance.new("Frame", MainFrame)
	CombatantsFrame.Size = UDim2.new(0.98, 0, 0, 95); CombatantsFrame.BackgroundTransparency = 1
	CombatantsFrame.LayoutOrder = 2

	local PlayerPanel = Instance.new("Frame", CombatantsFrame)
	PlayerPanel.Size = UDim2.new(0.46, 0, 1, 0); PlayerPanel.Position = UDim2.new(0, 0, 0, 0); PlayerPanel.BackgroundTransparency = 1

	pAvatarBox = Instance.new("Frame", PlayerPanel)
	pAvatarBox.Size = UDim2.new(0, 65, 0, 65); pAvatarBox.Position = UDim2.new(0, 0, 0.5, 0); pAvatarBox.AnchorPoint = Vector2.new(0, 0.5); pAvatarBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	Instance.new("UIStroke", pAvatarBox).Color = Color3.fromRGB(80, 120, 200); Instance.new("UIStroke", pAvatarBox).Thickness = 2; Instance.new("UIStroke", pAvatarBox).LineJoinMode = Enum.LineJoinMode.Miter
	local pAvatarImg = Instance.new("ImageLabel", pAvatarBox); pAvatarImg.Size = UDim2.new(1, 0, 1, 0); pAvatarImg.BackgroundTransparency = 1; pAvatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"

	local pStatsArea = Instance.new("Frame", PlayerPanel)
	pStatsArea.Size = UDim2.new(1, -70, 1, 0); pStatsArea.Position = UDim2.new(0, 70, 0, 0); pStatsArea.BackgroundTransparency = 1
	local pLayout = Instance.new("UIListLayout", pStatsArea); pLayout.SortOrder = Enum.SortOrder.LayoutOrder; pLayout.Padding = UDim.new(0, 2); pLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	PlayerNameText = Instance.new("TextLabel", pStatsArea)
	PlayerNameText.Size = UDim2.new(1, 0, 0, 12); PlayerNameText.BackgroundTransparency = 1; PlayerNameText.Font = Enum.Font.GothamBlack; PlayerNameText.TextColor3 = Color3.fromRGB(200, 220, 255); PlayerNameText.TextSize = 11; PlayerNameText.TextXAlignment = Enum.TextXAlignment.Left; PlayerNameText.TextScaled = true; PlayerNameText.Text = player.Name

	PlayerHPBar, PlayerHPText = CreateBar(pStatsArea, Color3.fromRGB(220, 60, 60), Color3.fromRGB(140, 30, 30), UDim2.new(1, 0, 0, 10), "HP: 100", false)
	PlayerGasBar, PlayerGasText = CreateBar(pStatsArea, Color3.fromRGB(150, 220, 255), Color3.fromRGB(60, 140, 200), UDim2.new(1, 0, 0, 8), "GAS: 100", false)
	PlayerNrgBar, PlayerNrgText, PlayerNrgContainer = CreateBar(pStatsArea, Color3.fromRGB(255, 150, 50), Color3.fromRGB(180, 80, 20), UDim2.new(1, 0, 0, 8), "HEAT: 0", false); PlayerNrgContainer.Visible = false

	PlayerStatusBox = Instance.new("Frame", pStatsArea)
	PlayerStatusBox.Size = UDim2.new(1, 0, 0, 16); PlayerStatusBox.BackgroundTransparency = 1
	local pStatusLayout = Instance.new("UIListLayout", PlayerStatusBox); pStatusLayout.FillDirection = Enum.FillDirection.Horizontal; pStatusLayout.Padding = UDim.new(0, 2)

	local vsLbl = Instance.new("TextLabel", CombatantsFrame)
	vsLbl.Size = UDim2.new(0.08, 0, 1, 0); vsLbl.Position = UDim2.new(0.46, 0, 0, 0); vsLbl.BackgroundTransparency = 1
	vsLbl.Font = Enum.Font.GothamBlack; vsLbl.TextColor3 = Color3.fromRGB(100, 100, 110); vsLbl.TextSize = 16; vsLbl.Text = "VS"

	local EnemyPanel = Instance.new("Frame", CombatantsFrame)
	EnemyPanel.Size = UDim2.new(0.46, 0, 1, 0); EnemyPanel.Position = UDim2.new(0.54, 0, 0, 0); EnemyPanel.BackgroundTransparency = 1

	eAvatarBox = Instance.new("Frame", EnemyPanel)
	eAvatarBox.Size = UDim2.new(0, 65, 0, 65); eAvatarBox.Position = UDim2.new(1, 0, 0.5, 0); eAvatarBox.AnchorPoint = Vector2.new(1, 0.5); eAvatarBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Instance.new("UIStroke", eAvatarBox).Color = Color3.fromRGB(255, 100, 100); Instance.new("UIStroke", eAvatarBox).Thickness = 2; Instance.new("UIStroke", eAvatarBox).LineJoinMode = Enum.LineJoinMode.Miter
	local eAvatarIcon = Instance.new("TextLabel", eAvatarBox); eAvatarIcon.Size = UDim2.new(1, 0, 1, 0); eAvatarIcon.BackgroundTransparency = 1; eAvatarIcon.Font = Enum.Font.GothamBlack; eAvatarIcon.TextColor3 = Color3.fromRGB(200, 50, 50); eAvatarIcon.TextScaled = true; eAvatarIcon.Text = "?"

	local eStatsArea = Instance.new("Frame", EnemyPanel)
	eStatsArea.Size = UDim2.new(1, -70, 1, 0); eStatsArea.Position = UDim2.new(0, 0, 0, 0); eStatsArea.BackgroundTransparency = 1
	local eStatsLayout = Instance.new("UIListLayout", eStatsArea); eStatsLayout.SortOrder = Enum.SortOrder.LayoutOrder; eStatsLayout.Padding = UDim.new(0, 2); eStatsLayout.VerticalAlignment = Enum.VerticalAlignment.Center; eStatsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	EnemyNameText = Instance.new("TextLabel", eStatsArea)
	EnemyNameText.Size = UDim2.new(1, 0, 0, 12); EnemyNameText.BackgroundTransparency = 1; EnemyNameText.Font = Enum.Font.GothamBlack; EnemyNameText.TextColor3 = Color3.fromRGB(255, 120, 120); EnemyNameText.TextSize = 11; EnemyNameText.TextScaled = true; EnemyNameText.TextXAlignment = Enum.TextXAlignment.Right

	local eHpCont
	EnemyHPBar, EnemyHPText, eHpCont = CreateBar(eStatsArea, Color3.fromRGB(220, 60, 60), Color3.fromRGB(140, 30, 30), UDim2.new(1, 0, 0, 10), "HP: 100", true)
	EnemyShieldBar = Instance.new("Frame", eHpCont); EnemyShieldBar.Size = UDim2.new(0, 0, 1, 0); EnemyShieldBar.AnchorPoint = Vector2.new(1,0); EnemyShieldBar.Position = UDim2.new(1,0,0,0); EnemyShieldBar.BackgroundColor3 = Color3.fromRGB(220, 230, 240); Instance.new("UICorner", EnemyShieldBar).CornerRadius = UDim.new(0, 4); EnemyShieldBar.ZIndex = 5; EnemyHPText.ZIndex = 6

	EnemyStatusBox = Instance.new("Frame", eStatsArea)
	EnemyStatusBox.Size = UDim2.new(1, 0, 0, 16); EnemyStatusBox.BackgroundTransparency = 1
	local eStatusLayout = Instance.new("UIListLayout", EnemyStatusBox); eStatusLayout.FillDirection = Enum.FillDirection.Horizontal; eStatusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; eStatusLayout.Padding = UDim.new(0, 2)

	local FeedBox = Instance.new("Frame", MainFrame)
	FeedBox.Size = UDim2.new(0.98, 0, 0, 50); FeedBox.BackgroundColor3 = Color3.fromRGB(22, 22, 26); FeedBox.ClipsDescendants = true; FeedBox.LayoutOrder = 3
	Instance.new("UICorner", FeedBox).CornerRadius = UDim.new(0, 6); local fbStroke = Instance.new("UIStroke", FeedBox); fbStroke.Color = Color3.fromRGB(60, 60, 70); fbStroke.Thickness = 1; fbStroke.LineJoinMode = Enum.LineJoinMode.Miter

	LogText = Instance.new("TextLabel", FeedBox)
	LogText.Size = UDim2.new(1, -10, 1, -10); LogText.Position = UDim2.new(0, 5, 0, 5); LogText.BackgroundTransparency = 1; LogText.Font = Enum.Font.GothamMedium; LogText.TextColor3 = Color3.fromRGB(230, 230, 230); LogText.TextSize = 10; LogText.TextXAlignment = Enum.TextXAlignment.Left; LogText.TextYAlignment = Enum.TextYAlignment.Bottom; LogText.TextWrapped = true; LogText.RichText = true; LogText.Text = ""

	local BottomArea = Instance.new("Frame", MainFrame)
	BottomArea.Size = UDim2.new(0.98, 0, 1, -190) 
	BottomArea.BackgroundTransparency = 1
	BottomArea.LayoutOrder = 4

	ActionGrid = Instance.new("ScrollingFrame", BottomArea)
	ActionGrid.Size = UDim2.new(1, 0, 1, 0); ActionGrid.BackgroundTransparency = 1; ActionGrid.ScrollBarThickness = 0; ActionGrid.BorderSizePixel = 0
	local gridLayout = Instance.new("UIGridLayout", ActionGrid)

	gridLayout.CellSize = UDim2.new(0.48, 0, 0, 38)
	gridLayout.CellPadding = UDim2.new(0.03, 0, 0, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder; gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		ActionGrid.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 10)
	end)

	TargetMenu = Instance.new("Frame", BottomArea)
	TargetMenu.Size = UDim2.new(1, 0, 1, 0); TargetMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TargetMenu.Visible = false
	Instance.new("UICorner", TargetMenu).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", TargetMenu).Color = Color3.fromRGB(80, 80, 90)

	local InfoPanel = Instance.new("Frame", TargetMenu)
	InfoPanel.Size = UDim2.new(0.45, 0, 1, 0); InfoPanel.BackgroundTransparency = 1

	local tHoverTitle = Instance.new("TextLabel", InfoPanel)
	tHoverTitle.Size = UDim2.new(1, -10, 0, 20); tHoverTitle.Position = UDim2.new(0, 10, 0, 5); tHoverTitle.BackgroundTransparency = 1; tHoverTitle.Font = Enum.Font.GothamBlack; tHoverTitle.TextColor3 = Color3.fromRGB(255, 215, 100); tHoverTitle.TextSize = 13; tHoverTitle.TextXAlignment = Enum.TextXAlignment.Left; tHoverTitle.Text = "SELECT TARGET"
	ApplyGradient(tHoverTitle, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	local tHoverDesc = Instance.new("TextLabel", InfoPanel)
	tHoverDesc.Size = UDim2.new(1, -10, 0, 80); tHoverDesc.Position = UDim2.new(0, 10, 0, 25); tHoverDesc.BackgroundTransparency = 1; tHoverDesc.Font = Enum.Font.GothamMedium; tHoverDesc.TextColor3 = Color3.fromRGB(200, 200, 200); tHoverDesc.TextSize = 10; tHoverDesc.TextXAlignment = Enum.TextXAlignment.Left; tHoverDesc.TextYAlignment = Enum.TextYAlignment.Top; tHoverDesc.TextWrapped = true; tHoverDesc.Text = "Select a limb to attack."

	local CancelBtn = Instance.new("TextButton", InfoPanel)
	CancelBtn.Size = UDim2.new(0.8, 0, 0, 30); CancelBtn.Position = UDim2.new(0, 10, 1, -35); CancelBtn.Font = Enum.Font.GothamBlack; CancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255); CancelBtn.TextSize = 11; CancelBtn.Text = "CANCEL"
	ApplyButtonGradient(CancelBtn, Color3.fromRGB(160, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(60, 20, 20))
	CancelBtn.MouseButton1Click:Connect(function() TargetMenu.Visible = false; ActionGrid.Visible = true; pendingSkillName = nil end)

	local BodyContainer = Instance.new("Frame", TargetMenu)
	BodyContainer.Size = UDim2.new(0.5, 0, 1, -10); BodyContainer.Position = UDim2.new(0.5, 0, 0, 5); BodyContainer.BackgroundTransparency = 1

	local function CreateLimb(name, size, pos, hoverText, baseColor)
		local limb = Instance.new("TextButton", BodyContainer)
		limb.Size = size; limb.Position = pos; limb.Text = name:upper(); limb.Font = Enum.Font.GothamBlack; limb.TextColor3 = Color3.fromRGB(255, 255, 255); limb.TextSize = 9

		local mTop = Color3.new(math.clamp(baseColor.R * 0.6, 0, 1), math.clamp(baseColor.G * 0.6, 0, 1), math.clamp(baseColor.B * 0.6, 0, 1))
		local mBot = Color3.new(math.clamp(baseColor.R * 0.3, 0, 1), math.clamp(baseColor.G * 0.3, 0, 1), math.clamp(baseColor.B * 0.3, 0, 1))
		ApplyButtonGradient(limb, mTop, mBot, baseColor)

		limb.MouseEnter:Connect(function()
			local hTop = Color3.new(math.clamp(baseColor.R * 1.2, 0, 1), math.clamp(baseColor.G * 1.2, 0, 1), math.clamp(baseColor.B * 1.2, 0, 1))
			local hBot = Color3.new(math.clamp(baseColor.R * 0.8, 0, 1), math.clamp(baseColor.G * 0.8, 0, 1), math.clamp(baseColor.B * 0.8, 0, 1))
			ApplyButtonGradient(limb, hTop, hBot, baseColor)

			tHoverTitle.Text = name:upper()
			tHoverTitle.TextColor3 = baseColor
			local grad = tHoverTitle:FindFirstChildOfClass("UIGradient")
			if grad then grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, hTop), ColorSequenceKeypoint.new(1, hBot)} end

			tHoverDesc.Text = hoverText
		end)
		limb.MouseLeave:Connect(function()
			ApplyButtonGradient(limb, mTop, mBot, baseColor)
			tHoverTitle.Text = "SELECT TARGET"
			tHoverTitle.TextColor3 = Color3.fromRGB(255, 215, 100)
			local grad = tHoverTitle:FindFirstChildOfClass("UIGradient")
			if grad then grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 100)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 50))} end

			tHoverDesc.Text = "Select a limb to attack."
		end)
		limb.MouseButton1Click:Connect(function()
			if pendingSkillName and not inputLocked then
				inputLocked = true
				if cachedTooltipMgr and type(cachedTooltipMgr.Hide) == "function" then cachedTooltipMgr.Hide() end
				TargetMenu.Visible = false; ActionGrid.Visible = true
				Network:WaitForChild("CombatAction"):FireServer("Attack", {SkillName = pendingSkillName, TargetLimb = name})
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

	LeaveBtn = Instance.new("TextButton", MainFrame); LeaveBtn.Size = UDim2.new(0.8, 0, 0, 45); LeaveBtn.LayoutOrder = 5; LeaveBtn.Font = Enum.Font.GothamBlack; LeaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255); LeaveBtn.TextSize = 14; LeaveBtn.Text = "RETURN TO BASE"; LeaveBtn.Visible = false
	ApplyButtonGradient(LeaveBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))

	LeaveBtn.MouseButton1Click:Connect(function()
		if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Click") end
		MainFrame.Visible = false; isBattleActive = false; parentFrame.Visible = true 
		local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
		if topGui then
			if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = true end
			if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = true end
			if topGui:FindFirstChild("ContentFrame") then
				for _, c in ipairs(topGui.ContentFrame:GetChildren()) do
					if c.Name == "BattleFrame" then c.Visible = true end
				end
			end
		end
	end)

	local function LockGrid()
		inputLocked = true
		for _, btn in ipairs(ActionGrid:GetChildren()) do
			if btn:IsA("TextButton") then
				ApplyButtonGradient(btn, Color3.fromRGB(25, 20, 30), Color3.fromRGB(15, 10, 20), Color3.fromRGB(40, 30, 50))
				btn.TextColor3 = Color3.fromRGB(120, 120, 120)
			end
		end
	end

	local function UpdateActionGrid(battleState)
		local success, err = pcall(function()
			inputLocked = false
			ActionGrid.Visible = true
			TargetMenu.Visible = false

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

				local sRange = sData.Range or "Close"
				local isWrongRange = (sRange ~= "Any" and sRange ~= battleState.Context.Range)

				local hasGas = (p.Gas or 0) >= gasCost
				local hasEnergy = (p.TitanEnergy or 0) >= energyCost
				local isReady = (cd == 0) and hasGas and hasEnergy and not isWrongRange

				local btn = Instance.new("TextButton", ActionGrid)
				btn.RichText = true 
				btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.LayoutOrder = order or 10

				local baseColor = color or Color3.fromRGB(60, 60, 70)
				if isReady then
					local topC = Color3.new(math.clamp(baseColor.R * 1.2, 0, 1), math.clamp(baseColor.G * 1.2, 0, 1), math.clamp(baseColor.B * 1.2, 0, 1))
					local botC = Color3.new(math.clamp(baseColor.R * 0.7, 0, 1), math.clamp(baseColor.G * 0.7, 0, 1), math.clamp(baseColor.B * 0.7, 0, 1))
					ApplyButtonGradient(btn, topC, botC, baseColor)
					btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				else
					ApplyButtonGradient(btn, Color3.fromRGB(25, 20, 30), Color3.fromRGB(15, 10, 20), Color3.fromRGB(40, 30, 50))
					btn.TextColor3 = Color3.fromRGB(120, 120, 120)
				end

				local cdStr = isReady and "READY" or "CD: " .. cd
				if isWrongRange then cdStr = "OUT OF RANGE"
				elseif cd == 0 then 
					if not hasGas then cdStr = "NO GAS" 
					elseif not hasEnergy then cdStr = "NO HEAT" 
					end 
				end

				btn.Text = sName:upper() .. "\n<font size='9' color='" .. (isReady and "#AAAAAA" or "#FF5555") .. "'>[" .. cdStr .. "]</font>"

				btn.MouseButton1Click:Connect(function()
					if isBattleActive and not inputLocked and isReady then
						if sName == "Retreat" or sName == "Fall Back" or sName == "Close In" or sData.Effect == "Rest" or sData.Effect == "TitanRest" or sData.Effect == "Eject" or sData.Effect == "Transform" or sData.Effect == "Block" or sData.Effect == "Flee" then
							if cachedTooltipMgr and type(cachedTooltipMgr.Hide) == "function" then cachedTooltipMgr.Hide() end
							LockGrid()
							Network:WaitForChild("CombatAction"):FireServer("Attack", {SkillName = sName})
						else
							if cachedTooltipMgr and type(cachedTooltipMgr.Hide) == "function" then cachedTooltipMgr.Hide() end
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

				if battleState.Context.Range == "Long" then
					CreateBtn("Close In", Color3.fromRGB(80, 140, 100), 3)
				else
					CreateBtn("Fall Back", Color3.fromRGB(80, 100, 140), 3)
				end

				CreateBtn("Recover", Color3.fromRGB(40, 140, 80), 4)
				CreateBtn("Retreat", Color3.fromRGB(60, 60, 70), 5)

				if pTitan ~= "None" and pClan ~= "Ackerman" and pClan ~= "Awakened Ackerman" then
					CreateBtn("Transform", Color3.fromRGB(200, 150, 50), 6)
				end

				local orderIndex = 7
				for sName, sData in pairs(SkillData.Skills) do
					if sName == "Basic Slash" or sName == "Maneuver" or sName == "Fall Back" or sName == "Close In" or sName == "Recover" or sName == "Retreat" or sName == "Transform" then continue end
					if sName == "Anti-Titan Rifle" and battleState.Context.Range ~= "Long" then continue end

					local req = sData.Requirement
					if req == pStyle or req == pClan or (req == "Ackerman" and pClan == "Awakened Ackerman") or (req == "ODM" and isODM) then
						CreateBtn(sName, Color3.fromRGB(45, 40, 60), sData.Order or orderIndex)
						orderIndex += 1
					end
				end
			end
		end)
		if not success then warn("ActionGrid Rendering Failed: " .. tostring(err)) end
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

		RenderStatuses(PlayerStatusBox, p, false)
		RenderStatuses(EnemyStatusBox, e, true)

		local rText = battleState.Context.Range == "Long" and "LONG RANGE" or "MELEE RANGE"
		if battleState.Context.IsStoryMission then WaveLabel.Text = "WAVE " .. battleState.Context.CurrentWave .. " / " .. battleState.Context.TotalWaves .. " - [" .. rText .. "]"
		elseif battleState.Context.IsPaths then WaveLabel.Text = "MEMORY " .. (player:GetAttribute("PathsFloor") or 1) .. " - [" .. rText .. "]"
		else WaveLabel.Text = "RANDOM ENCOUNTER - [" .. rText .. "]" end
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

		elseif action == "StartMinigame" then
			ActionGrid.Visible = false
			TargetMenu.Visible = false
			AddLogMessage(data.LogMsg, true)
			LockGrid()

		elseif action == "TurnStrike" then
			ShakeUI(data.ShakeType); SyncBars(data.Battle); AddLogMessage(data.LogMsg, true)
			if data.SkillUsed then 
				if EffectsManager and type(EffectsManager.PlayCombatEffect) == "function" then
					EffectsManager.PlayCombatEffect(data.SkillUsed, data.IsPlayerAttacking, pAvatarBox, eAvatarBox, data.DidHit) 
				end
			end

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
			if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Victory", 1) end
			SyncBars(data.Battle); isBattleActive = false; LockGrid()
			BottomArea.Visible = false; LeaveBtn.Visible = true; LeaveBtn.Text = "VICTORY - RETURN"; ApplyButtonGradient(LeaveBtn, Color3.fromRGB(80, 200, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))
			AddLogMessage("<b><font color='#55FF55'>ENEMY DEFEATED!</font></b>", false)
			local xpAmt = data.XP or 0; local dewsAmt = data.Dews or 0
			local rewardStr = "<font color='#55FF55'>Rewards: +" .. xpAmt .. " XP | +" .. dewsAmt .. " Dews</font>"
			if data.Items and #data.Items > 0 then rewardStr = rewardStr .. "<br/><font color='#AA55FF'>Drops: " .. table.concat(data.Items, ", ") .. "</font>" end
			if data.ExtraLog then rewardStr = rewardStr .. "<br/>" .. data.ExtraLog end
			AddLogMessage(rewardStr, true)

		elseif action == "Defeat" then
			if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Defeat", 1) end
			SyncBars(data.Battle); isBattleActive = false; LockGrid()
			BottomArea.Visible = false; LeaveBtn.Visible = true; LeaveBtn.Text = "DEFEAT - RETREAT"; ApplyButtonGradient(LeaveBtn, Color3.fromRGB(200, 80, 80), Color3.fromRGB(100, 40, 40), Color3.fromRGB(80, 20, 20))
			AddLogMessage("<b><font color='#FF5555'>YOU WERE SLAUGHTERED.</font></b>", false)

		elseif action == "PathsDeath" then
			if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Defeat", 1) end
			isBattleActive = false

			PathsShopOverlay.Visible = true
			TweenService:Create(PathsShopOverlay, TweenInfo.new(1.5), {BackgroundTransparency = 0}):Play()
			task.wait(1.5)

			MainFrame.Visible = false
			parentFrame.Visible = true 
			local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
			if topGui then
				if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = true end
				if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = true end
				if topGui:FindFirstChild("ContentFrame") then
					for _, c in ipairs(topGui.ContentFrame:GetChildren()) do
						if c.Name == "BattleFrame" then c.Visible = true end
					end
				end
			end

			local shopData = Network.GetShopData:InvokeServer("PathsShop")
			if shopData then
				PopulatePathsShop(shopData)
				PSModal.Visible = true
				TweenService:Create(PathsShopOverlay, TweenInfo.new(1.0), {BackgroundTransparency = 0.5}):Play()
			else
				PathsShopOverlay.Visible = false
			end

		elseif action == "Fled" then
			if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Flee", 1) end
			isBattleActive = false; LockGrid()

			if data.Battle and data.Battle.Context.IsPaths then
				PathsShopOverlay.Visible = true
				TweenService:Create(PathsShopOverlay, TweenInfo.new(1.5), {BackgroundTransparency = 0}):Play()
				task.wait(1.5)

				MainFrame.Visible = false
				parentFrame.Visible = true 
				local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
				if topGui then
					if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = true end
					if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = true end
				end

				local shopData = Network.GetShopData:InvokeServer("PathsShop")
				if shopData then
					PopulatePathsShop(shopData)
					PSModal.Visible = true
					TweenService:Create(PathsShopOverlay, TweenInfo.new(1.0), {BackgroundTransparency = 0.5}):Play()
				else
					PathsShopOverlay.Visible = false
				end
			else
				BottomArea.Visible = false; LeaveBtn.Visible = true; LeaveBtn.Text = "COWARD - RETURN"; ApplyButtonGradient(LeaveBtn, Color3.fromRGB(150, 150, 150), Color3.fromRGB(80, 80, 80), Color3.fromRGB(50, 50, 50))
				AddLogMessage("<b><font color='#AAAAAA'>You fired a smoke signal and fled.</font></b>", false)
			end
		end
	end)
end

function CombatTab.Show()
	-- Handled via remote events
end

return CombatTab