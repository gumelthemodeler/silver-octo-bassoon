-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local BountiesTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")

local player = Players.LocalPlayer
local MainFrame
local DailiesList, WeekliesList
local activeTweens = {}

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

-- [[ Premium Dark Gradient Helper ]]
local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}
	grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 4)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn)
		stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.LineJoinMode = Enum.LineJoinMode.Miter
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
		btn:GetPropertyChangedSignal("RichText"):Connect(function() textLbl.RichText = btn.RichText end)
		btn:GetPropertyChangedSignal("TextSize"):Connect(function() textLbl.TextSize = btn.TextSize end)
	end
end

function BountiesTab.Init(parentFrame)
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "BountiesFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false
	MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local mainLayout = Instance.new("UIListLayout", MainFrame); mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; mainLayout.Padding = UDim.new(0, 15)
	local mainPad = Instance.new("UIPadding", MainFrame); mainPad.PaddingTop = UDim.new(0, 10); mainPad.PaddingBottom = UDim.new(0, 30)

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 255, 255); Title.TextSize = 22; Title.Text = "REGIMENT CONTRACTS"
	Title.LayoutOrder = 0
	ApplyGradient(Title, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	-- [[ MOBILE: Vertically Stacked Lists ]]
	DailiesList = Instance.new("Frame", MainFrame)
	DailiesList.Size = UDim2.new(0.95, 0, 0, 0); DailiesList.AutomaticSize = Enum.AutomaticSize.Y; DailiesList.BackgroundColor3 = Color3.fromRGB(20, 20, 25); DailiesList.LayoutOrder = 1
	Instance.new("UICorner", DailiesList).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", DailiesList).Color = Color3.fromRGB(80, 80, 90)
	local dLayout = Instance.new("UIListLayout", DailiesList); dLayout.Padding = UDim.new(0, 10); dLayout.SortOrder = Enum.SortOrder.LayoutOrder; dLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local dPad = Instance.new("UIPadding", DailiesList); dPad.PaddingTop = UDim.new(0, 10); dPad.PaddingBottom = UDim.new(0, 15)

	local dHeader = Instance.new("TextLabel", DailiesList)
	dHeader.Size = UDim2.new(0.9, 0, 0, 30); dHeader.BackgroundTransparency = 1; dHeader.Font = Enum.Font.GothamBlack; dHeader.TextColor3 = Color3.fromRGB(255, 215, 100); dHeader.TextScaled = true; dHeader.TextXAlignment = Enum.TextXAlignment.Left; dHeader.Text = "DAILY BOUNTIES"
	dHeader.LayoutOrder = 0; Instance.new("UITextSizeConstraint", dHeader).MaxTextSize = 16

	WeekliesList = Instance.new("Frame", MainFrame)
	WeekliesList.Size = UDim2.new(0.95, 0, 0, 0); WeekliesList.AutomaticSize = Enum.AutomaticSize.Y; WeekliesList.BackgroundColor3 = Color3.fromRGB(20, 20, 25); WeekliesList.LayoutOrder = 2
	Instance.new("UICorner", WeekliesList).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", WeekliesList).Color = Color3.fromRGB(80, 80, 90)
	local wLayout = Instance.new("UIListLayout", WeekliesList); wLayout.Padding = UDim.new(0, 10); wLayout.SortOrder = Enum.SortOrder.LayoutOrder; wLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local wPad = Instance.new("UIPadding", WeekliesList); wPad.PaddingTop = UDim.new(0, 10); wPad.PaddingBottom = UDim.new(0, 15)

	local wHeader = Instance.new("TextLabel", WeekliesList)
	wHeader.Size = UDim2.new(0.9, 0, 0, 30); wHeader.BackgroundTransparency = 1; wHeader.Font = Enum.Font.GothamBlack; wHeader.TextColor3 = Color3.fromRGB(200, 150, 255); wHeader.TextScaled = true; wHeader.TextXAlignment = Enum.TextXAlignment.Left; wHeader.Text = "WEEKLY DIRECTIVE"
	wHeader.LayoutOrder = 0; Instance.new("UITextSizeConstraint", wHeader).MaxTextSize = 16

	local function CreateBountyRow(parent, idKey, isWeekly, order)
		local row = Instance.new("Frame", parent)
		row.Name = idKey; row.Size = UDim2.new(0.95, 0, 0, 110); row.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
		row.LayoutOrder = order
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", row)
		stroke.Color = Color3.fromRGB(60, 60, 70); stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.LineJoinMode = Enum.LineJoinMode.Miter

		local accentBar = Instance.new("Frame", row)
		accentBar.Size = UDim2.new(0, 4, 1, 0)
		accentBar.BackgroundColor3 = isWeekly and Color3.fromRGB(200, 150, 255) or Color3.fromRGB(255, 215, 100)
		Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local infoLbl = Instance.new("TextLabel", row)
		infoLbl.Name = "Info"; infoLbl.Size = UDim2.new(1, -25, 0, 45); infoLbl.Position = UDim2.new(0, 15, 0, 10); infoLbl.BackgroundTransparency = 1; infoLbl.Font = Enum.Font.GothamMedium; infoLbl.TextColor3 = Color3.fromRGB(230, 230, 230); infoLbl.TextScaled = true; infoLbl.TextXAlignment = Enum.TextXAlignment.Left; infoLbl.TextYAlignment = Enum.TextYAlignment.Top; infoLbl.TextWrapped = true; infoLbl.RichText = true
		infoLbl.Text = "Loading contract data..."; Instance.new("UITextSizeConstraint", infoLbl).MaxTextSize = 12

		local barCont = Instance.new("Frame", row)
		barCont.Name = "BarCont"
		barCont.Size = UDim2.new(1, -25, 0, 12); barCont.Position = UDim2.new(0, 15, 0, 60); barCont.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Instance.new("UICorner", barCont).CornerRadius = UDim.new(0, 6)
		local barStroke = Instance.new("UIStroke", barCont); barStroke.Color = Color3.fromRGB(40, 40, 50)

		local fill = Instance.new("Frame", barCont)
		fill.Name = "Fill"; fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(80, 200, 80); Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

		local btn = Instance.new("TextButton", row)
		btn.Name = "ActionBtn"; btn.Size = UDim2.new(1, -25, 0, 26); btn.Position = UDim2.new(0, 15, 1, -10); btn.AnchorPoint = Vector2.new(0, 1); btn.Font = Enum.Font.GothamBlack; btn.TextSize = 11; btn.Text = "IN PROGRESS"
		ApplyButtonGradient(btn, Color3.fromRGB(30, 30, 35), Color3.fromRGB(15, 15, 20), Color3.fromRGB(50, 50, 60))
		btn.TextColor3 = Color3.fromRGB(150, 150, 150)

		btn.MouseButton1Click:Connect(function()
			local prog = player:GetAttribute(idKey .. "_Prog") or 0
			local max = player:GetAttribute(idKey .. "_Max") or 1
			local claimed = player:GetAttribute(idKey .. "_Claimed")
			if prog >= max and not claimed then Network.ClaimBounty:FireServer(idKey) end
		end)
	end

	CreateBountyRow(DailiesList, "D1", false, 1)
	CreateBountyRow(DailiesList, "D2", false, 2)
	CreateBountyRow(DailiesList, "D3", false, 3)
	CreateBountyRow(WeekliesList, "W1", true, 1)

	local function UpdateUI()
		local function UpdateRow(row, idKey, isWeekly)
			if not row then return end
			local desc = player:GetAttribute(idKey .. "_Desc") or "Loading..."
			local prog = player:GetAttribute(idKey .. "_Prog") or 0
			local max = player:GetAttribute(idKey .. "_Max") or 1
			local claimed = player:GetAttribute(idKey .. "_Claimed") or false

			local rewardStr = ""
			if isWeekly then
				local rType = player:GetAttribute(idKey .. "_RewardType") or "Item"
				local rAmt = player:GetAttribute(idKey .. "_RewardAmt") or 1
				rewardStr = "\n<font color='#FF55FF'>[Reward: " .. rAmt .. "x " .. rType .. "]</font>"
			else
				local dews = player:GetAttribute(idKey .. "_Reward") or 0
				rewardStr = "\n<font color='#55FF55'>[Reward: " .. dews .. " Dews]</font>"
			end

			if row:FindFirstChild("Info") then
				row.Info.Text = "<b>" .. desc .. " (" .. prog .. "/" .. max .. ")</b>" .. rewardStr
			end

			local barCont = row:FindFirstChild("BarCont")
			if barCont and barCont:FindFirstChild("Fill") then
				TweenService:Create(barCont.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.new(math.clamp(prog / max, 0, 1), 0, 1, 0)}):Play()
			end

			local btn = row:FindFirstChild("ActionBtn")
			if btn then
				if claimed then
					ApplyButtonGradient(btn, Color3.fromRGB(30, 30, 35), Color3.fromRGB(15, 15, 20), Color3.fromRGB(50, 50, 60))
					btn.TextColor3 = Color3.fromRGB(100, 100, 100)
					btn.Text = "CLAIMED"
					if activeTweens[btn] then activeTweens[btn]:Cancel(); activeTweens[btn] = nil end
				elseif prog >= max then
					ApplyButtonGradient(btn, Color3.fromRGB(220, 160, 40), Color3.fromRGB(140, 90, 15), Color3.fromRGB(255, 215, 100))
					btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					btn.Text = "CLAIM REWARD"

					if not activeTweens[btn] then
						local grad = btn:FindFirstChildOfClass("UIGradient")
						if grad then
							local pulse = TweenService:Create(grad, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Offset = Vector2.new(0, 0.2)})
							pulse:Play(); activeTweens[btn] = pulse
						end
					end
				else
					ApplyButtonGradient(btn, Color3.fromRGB(30, 30, 35), Color3.fromRGB(15, 15, 20), Color3.fromRGB(50, 50, 60))
					btn.TextColor3 = Color3.fromRGB(150, 150, 150)
					btn.Text = "IN PROGRESS"
					if activeTweens[btn] then activeTweens[btn]:Cancel(); activeTweens[btn] = nil end
					local grad = btn:FindFirstChildOfClass("UIGradient")
					if grad then grad.Offset = Vector2.new(0,0) end
				end
			end
		end

		UpdateRow(DailiesList:FindFirstChild("D1"), "D1", false)
		UpdateRow(DailiesList:FindFirstChild("D2"), "D2", false)
		UpdateRow(DailiesList:FindFirstChild("D3"), "D3", false)
		UpdateRow(WeekliesList:FindFirstChild("W1"), "W1", true)

		task.delay(0.05, function() MainFrame.CanvasSize = UDim2.new(0, 0, 0, mainLayout.AbsoluteContentSize.Y + 40) end)
	end

	player.AttributeChanged:Connect(UpdateUI)
	UpdateUI()
	task.spawn(function() task.wait(1); UpdateUI(); task.wait(2); UpdateUI() end)
end

function BountiesTab.Show()
	if MainFrame then MainFrame.Visible = true end
end

return BountiesTab