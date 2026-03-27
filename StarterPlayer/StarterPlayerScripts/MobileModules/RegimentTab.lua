-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local RegimentTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local NotificationManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("NotificationManager"))

local player = Players.LocalPlayer
local MainFrame, ContentPanel, LockedPanel
local GarrisonCol, ScoutsCol, MPCol
local DominantLabel

local FactionColors = { ["Garrison"] = Color3.fromRGB(160, 60, 60), ["Military Police"] = Color3.fromRGB(60, 140, 60), ["Scout Regiment"] = Color3.fromRGB(60, 80, 160) }
local RegimentIcons = { ["Garrison"] = "rbxassetid://133062844", ["Military Police"] = "rbxassetid://132793466", ["Scout Regiment"] = "rbxassetid://132793532" }

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
		stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	if not btn:GetAttribute("GradientTextFixed") then
		btn:SetAttribute("GradientTextFixed", true)
		local textLbl = Instance.new("TextLabel", btn)
		textLbl.Name = "BtnTextLabel"; textLbl.Size = UDim2.new(1, 0, 1, 0); textLbl.BackgroundTransparency = 1
		textLbl.Font = btn.Font; textLbl.TextSize = btn.TextSize; textLbl.TextScaled = btn.TextScaled; textLbl.RichText = btn.RichText; textLbl.TextWrapped = btn.TextWrapped
		textLbl.TextXAlignment = btn.TextXAlignment; textLbl.TextYAlignment = btn.TextYAlignment; textLbl.ZIndex = btn.ZIndex + 1
		local tConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint")
		if tConstraint then tConstraint.Parent = textLbl end
		btn.ChildAdded:Connect(function(child) if child:IsA("UITextSizeConstraint") then task.delay(0, function() child.Parent = textLbl end) end end)
		textLbl.Text = btn.Text; textLbl.TextColor3 = btn.TextColor3; btn.Text = ""
		btn:GetPropertyChangedSignal("Text"):Connect(function() if btn.Text ~= "" then textLbl.Text = btn.Text; btn.Text = "" end end)
		btn:GetPropertyChangedSignal("TextColor3"):Connect(function() textLbl.TextColor3 = btn.TextColor3 end)
	end
end

function RegimentTab.Init(parentFrame, tooltipMgr)
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "RegimentFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false
	MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 255, 255); Title.TextSize = 22; Title.Text = "REGIMENT WARS"
	ApplyGradient(Title, Color3.fromRGB(200, 200, 255), Color3.fromRGB(100, 150, 255))

	local mainLayout = Instance.new("UIListLayout", MainFrame); mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.Padding = UDim.new(0, 10); mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local mainPad = Instance.new("UIPadding", MainFrame); mainPad.PaddingTop = UDim.new(0, 10); mainPad.PaddingBottom = UDim.new(0, 30)
	Title.LayoutOrder = 1

	LockedPanel = Instance.new("Frame", MainFrame)
	LockedPanel.Size = UDim2.new(0.95, 0, 0, 150); LockedPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); LockedPanel.LayoutOrder = 2
	Instance.new("UICorner", LockedPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", LockedPanel).Color = Color3.fromRGB(80, 40, 40)
	local lockTxt = Instance.new("TextLabel", LockedPanel); lockTxt.Size = UDim2.new(0.9, 0, 1, 0); lockTxt.Position = UDim2.new(0.05, 0, 0, 0); lockTxt.BackgroundTransparency = 1; lockTxt.Font = Enum.Font.GothamMedium; lockTxt.TextColor3 = Color3.fromRGB(200, 200, 200); lockTxt.TextSize = 14; lockTxt.TextWrapped = true; lockTxt.Text = "Complete '104th Cadet Corps Training' (Campaign Part 2) to pledge to a Regiment."

	ContentPanel = Instance.new("Frame", MainFrame)
	ContentPanel.Size = UDim2.new(0.95, 0, 0, 0); ContentPanel.AutomaticSize = Enum.AutomaticSize.Y; ContentPanel.BackgroundTransparency = 1; ContentPanel.LayoutOrder = 3

	local ContentLayout = Instance.new("UIListLayout", ContentPanel); ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder; ContentLayout.Padding = UDim.new(0, 10)

	DominantLabel = Instance.new("TextLabel", ContentPanel)
	DominantLabel.Size = UDim2.new(1, 0, 0, 35); DominantLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 30); DominantLabel.Font = Enum.Font.GothamBlack; DominantLabel.TextColor3 = Color3.fromRGB(255, 255, 255); DominantLabel.TextSize = 14; DominantLabel.Text = "AWAITING INTEL..."; DominantLabel.LayoutOrder = 1
	Instance.new("UICorner", DominantLabel).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", DominantLabel).Color = Color3.fromRGB(60, 60, 70)

	local CardsContainer = Instance.new("Frame", ContentPanel)
	CardsContainer.Size = UDim2.new(1, 0, 0, 0); CardsContainer.AutomaticSize = Enum.AutomaticSize.Y; CardsContainer.BackgroundTransparency = 1; CardsContainer.LayoutOrder = 2
	local cLayout = Instance.new("UIListLayout", CardsContainer); cLayout.FillDirection = Enum.FillDirection.Vertical; cLayout.Padding = UDim.new(0, 10)

	local function CreateRegimentCard(name, color, imageId, subtext)
		local card = Instance.new("Frame", CardsContainer)
		-- Scaled for Mobile 
		card.Size = UDim2.new(1, 0, 0, 95); card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

		local stroke = Instance.new("UIStroke", card)
		stroke.Color = color; stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.LineJoinMode = Enum.LineJoinMode.Miter; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local accentBar = Instance.new("Frame", card)
		accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = color; accentBar.BorderSizePixel = 0; accentBar.ZIndex = 2
		Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local bgGlow = Instance.new("Frame", card)
		bgGlow.Size = UDim2.new(1, 0, 0.6, 0); bgGlow.Position = UDim2.new(0, 0, 0.4, 0); bgGlow.BackgroundColor3 = color; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1

		local logo = Instance.new("ImageLabel", card)
		logo.Size = UDim2.new(0, 70, 0, 70); logo.Position = UDim2.new(0, 10, 0.5, 0); logo.AnchorPoint = Vector2.new(0, 0.5); logo.BackgroundTransparency = 1; logo.Image = imageId; logo.ScaleType = Enum.ScaleType.Fit; logo.ImageTransparency = 0.8; logo.ImageColor3 = color

		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(0.5, 0, 0, 20); title.Position = UDim2.new(0, 90, 0, 10); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextColor3 = color; title.TextSize = 16; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = string.upper(name); title.ZIndex = 3
		local tConstraint = Instance.new("UITextSizeConstraint", title); tConstraint.MaxTextSize = 16

		local vpLbl = Instance.new("TextLabel", card)
		vpLbl.Size = UDim2.new(0.5, 0, 0, 25); vpLbl.Position = UDim2.new(0, 90, 0, 30); vpLbl.BackgroundTransparency = 1; vpLbl.Font = Enum.Font.GothamBlack; vpLbl.TextColor3 = Color3.fromRGB(255, 255, 255); vpLbl.TextSize = 14; vpLbl.TextXAlignment = Enum.TextXAlignment.Left; vpLbl.Text = "0 VP"; vpLbl.ZIndex = 3

		local barBg = Instance.new("Frame", card)
		barBg.Size = UDim2.new(0.5, 0, 0, 10); barBg.Position = UDim2.new(0, 90, 1, -20); barBg.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 6); barBg.ZIndex = 2
		local barStroke = Instance.new("UIStroke", barBg); barStroke.Color = Color3.fromRGB(40, 40, 50)
		local fill = Instance.new("Frame", barBg); fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = color; Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6); fill.ZIndex = 2

		local joinBtn = Instance.new("TextButton", card)
		-- Scaled for Mobile 
		joinBtn.Size = UDim2.new(0, 100, 0, 35); joinBtn.Position = UDim2.new(1, -10, 0.5, 0); joinBtn.AnchorPoint = Vector2.new(1, 0.5); joinBtn.Font = Enum.Font.GothamBlack; joinBtn.TextSize = 9; joinBtn.ZIndex = 4
		joinBtn.Text = "" -- Ensure it doesn't say "Button" before init

		joinBtn.MouseButton1Click:Connect(function()
			local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
			if currentReg == name then return end

			local cost = (currentReg == "Cadet Corps") and 0 or 50000
			if cost > 0 then
				local currentDews = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
				if currentDews >= cost then
					Network:WaitForChild("JoinRegiment"):FireServer(name)
				else
					if NotificationManager then NotificationManager.Show("Not enough Dews! You need 50,000 to swap regiments.", "Error") end
				end
			else
				Network:WaitForChild("JoinRegiment"):FireServer(name)
			end
		end)

		-- [[ THE FIX: Separate Initialization function called immediately! ]]
		local function UpdateBtnState()
			local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
			if currentReg == name then
				joinBtn.Text = "CURRENT"
				ApplyButtonGradient(joinBtn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(60, 60, 70))
				joinBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
			else
				joinBtn.Text = (currentReg == "Cadet Corps") and "JOIN (FREE)" or "SWAP (50k DEWS)"
				local rTop = Color3.new(color.R * 0.8, color.G * 0.8, color.B * 0.8)
				local rBot = Color3.new(color.R * 0.4, color.G * 0.4, color.B * 0.4)
				ApplyButtonGradient(joinBtn, rTop, rBot, color)
				joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end

		player:GetAttributeChangedSignal("Regiment"):Connect(UpdateBtnState)
		UpdateBtnState() -- Execute immediately

		return fill, vpLbl, joinBtn
	end

	local gFill, gVp, gBtn = CreateRegimentCard("Garrison", FactionColors["Garrison"], RegimentIcons["Garrison"], "THE STATIONED CORPS")
	local mFill, mVp, mBtn = CreateRegimentCard("Military Police", FactionColors["Military Police"], RegimentIcons["Military Police"], "THE KING'S GUARD")
	local sFill, sVp, sBtn = CreateRegimentCard("Scout Regiment", FactionColors["Scout Regiment"], RegimentIcons["Scout Regiment"], "THE WINGS OF FREEDOM")
	GarrisonCol = {Fill = gFill, Vp = gVp}; MPCol = {Fill = mFill, Vp = mVp}; ScoutsCol = {Fill = sFill, Vp = sVp}

	local function UpdateLocks()
		local part = player:GetAttribute("CurrentPart") or 1
		local prestige = (player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige")) and player.leaderstats.Prestige.Value or 0
		if part > 2 or prestige > 0 then LockedPanel.Visible = false; ContentPanel.Visible = true else LockedPanel.Visible = true; ContentPanel.Visible = false end
	end
	player:GetAttributeChangedSignal("CurrentPart"):Connect(UpdateLocks)
	UpdateLocks()

	-- Trigger initial value to ensure everything is set (just in case)
	if not player:GetAttribute("Regiment") then player:SetAttribute("Regiment", "Cadet Corps") end

	task.spawn(function()
		while true do
			task.wait(5)
			if MainFrame.Visible and ContentPanel.Visible then
				pcall(function()
					local vpData = Network:WaitForChild("GetRegimentVP"):InvokeServer()
					local total = math.max(1, vpData["Garrison"] + vpData["Scout Regiment"] + vpData["Military Police"])

					local highest = 0; local dom = "NO CLEAR LEADER"
					for reg, vp in pairs(vpData) do if reg ~= "Week" and reg ~= "Winner" and vp > highest then highest = vp; dom = string.upper(reg) .. " DOMINATING!" end end
					DominantLabel.Text = dom

					TweenService:Create(GarrisonCol.Fill, TweenInfo.new(1), {Size = UDim2.new(vpData["Garrison"] / total, 0, 1, 0)}):Play(); GarrisonCol.Vp.Text = vpData["Garrison"] .. " VP"
					TweenService:Create(MPCol.Fill, TweenInfo.new(1), {Size = UDim2.new(vpData["Military Police"] / total, 0, 1, 0)}):Play(); MPCol.Vp.Text = vpData["Military Police"] .. " VP"
					TweenService:Create(ScoutsCol.Fill, TweenInfo.new(1), {Size = UDim2.new(vpData["Scout Regiment"] / total, 0, 1, 0)}):Play(); ScoutsCol.Vp.Text = vpData["Scout Regiment"] .. " VP"
				end)
			end
		end
	end)
end

function RegimentTab.Show() if MainFrame then MainFrame.Visible = true end end

return RegimentTab