-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local TradeMenu = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local MainFrame
local PlayerListFrame

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

-- [[ Universal Gradient Helper (Dark Dossier Style) ]]
local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}
	grad.Rotation = 90

	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 4)

	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn)
		stroke.Color = strokeColor
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
	end

	if not btn:GetAttribute("GradientTextFixed") then
		btn:SetAttribute("GradientTextFixed", true)

		local textLbl = Instance.new("TextLabel", btn)
		textLbl.Name = "BtnTextLabel"
		textLbl.Size = UDim2.new(1, 0, 1, 0)
		textLbl.BackgroundTransparency = 1
		textLbl.Font = btn.Font
		textLbl.TextSize = btn.TextSize
		textLbl.TextScaled = btn.TextScaled
		textLbl.RichText = btn.RichText
		textLbl.TextWrapped = btn.TextWrapped
		textLbl.TextXAlignment = btn.TextXAlignment
		textLbl.TextYAlignment = btn.TextYAlignment
		textLbl.ZIndex = btn.ZIndex + 1

		local tConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint")
		if tConstraint then tConstraint.Parent = textLbl end

		btn.ChildAdded:Connect(function(child)
			if child:IsA("UITextSizeConstraint") then
				task.delay(0, function() child.Parent = textLbl end)
			end
		end)

		textLbl.Text = btn.Text
		textLbl.TextColor3 = btn.TextColor3
		btn.Text = ""

		btn:GetPropertyChangedSignal("Text"):Connect(function()
			if btn.Text ~= "" then
				textLbl.Text = btn.Text
				btn.Text = ""
			end
		end)
		btn:GetPropertyChangedSignal("TextColor3"):Connect(function()
			textLbl.TextColor3 = btn.TextColor3
		end)
	end
end

function TradeMenu.Init(parentFrame, tooltipMgr)
	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "TradeMenuFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(150, 200, 255); Title.TextSize = 24; Title.Text = "SECURE TRADE HUB"
	ApplyGradient(Title, Color3.fromRGB(150, 200, 255), Color3.fromRGB(50, 150, 255))

	-- [[ THE FIX: Rebuilt Player List into a Sleek 2-Column Grid ]]
	PlayerListFrame = Instance.new("ScrollingFrame", MainFrame)
	PlayerListFrame.Size = UDim2.new(0.96, 0, 1, -80); PlayerListFrame.Position = UDim2.new(0.02, 0, 0, 80); PlayerListFrame.BackgroundTransparency = 1; PlayerListFrame.ScrollBarThickness = 4; PlayerListFrame.BorderSizePixel = 0

	local plLayout = Instance.new("UIGridLayout", PlayerListFrame)
	plLayout.CellSize = UDim2.new(0.49, 0, 0, 90); plLayout.CellPadding = UDim2.new(0.02, 0, 0, 15); plLayout.SortOrder = Enum.SortOrder.Name; plLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local plPad = Instance.new("UIPadding", PlayerListFrame); plPad.PaddingTop = UDim.new(0, 5); plPad.PaddingBottom = UDim.new(0, 20)

	local function RefreshPlayers()
		for _, child in ipairs(PlayerListFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local row = Instance.new("Frame", PlayerListFrame)
				row.Name = p.Name; row.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
				local stroke = Instance.new("UIStroke", row); stroke.Color = Color3.fromRGB(50, 50, 60); stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

				local accentBar = Instance.new("Frame", row); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(80, 140, 220); accentBar.BorderSizePixel = 0
				Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

				local avatar = Instance.new("ImageLabel", row)
				avatar.Size = UDim2.new(0, 60, 0, 60); avatar.Position = UDim2.new(0, 15, 0.5, 0); avatar.AnchorPoint = Vector2.new(0, 0.5); avatar.BackgroundColor3 = Color3.fromRGB(15, 15, 20); avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..p.UserId.."&w=150&h=150"
				Instance.new("UIStroke", avatar).Color = Color3.fromRGB(80, 140, 220); Instance.new("UIStroke", avatar).Thickness = 2; Instance.new("UIStroke", avatar).LineJoinMode = Enum.LineJoinMode.Miter

				local nLbl = Instance.new("TextLabel", row)
				nLbl.Size = UDim2.new(1, -210, 1, 0); nLbl.Position = UDim2.new(0, 90, 0, 0); nLbl.BackgroundTransparency = 1; nLbl.Font = Enum.Font.GothamBlack; nLbl.TextColor3 = Color3.fromRGB(230, 230, 240); nLbl.TextSize = 16; nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.Text = string.upper(p.Name)

				local reqBtn = Instance.new("TextButton", row)
				reqBtn.Size = UDim2.new(0, 110, 0, 35); reqBtn.Position = UDim2.new(1, -15, 0.5, 0); reqBtn.AnchorPoint = Vector2.new(1, 0.5); reqBtn.Font = Enum.Font.GothamBlack; reqBtn.TextColor3 = Color3.fromRGB(150, 200, 255); reqBtn.TextSize = 13; reqBtn.Text = "REQUEST"
				ApplyButtonGradient(reqBtn, Color3.fromRGB(20, 25, 35), Color3.fromRGB(10, 15, 25), Color3.fromRGB(80, 140, 220))

				reqBtn.MouseButton1Click:Connect(function()
					Network.TradeRequest:FireServer(p.Name)
					reqBtn.Text = "SENT"; reqBtn.TextColor3 = Color3.fromRGB(150, 255, 150)
					ApplyButtonGradient(reqBtn, Color3.fromRGB(25, 35, 25), Color3.fromRGB(15, 20, 15), Color3.fromRGB(80, 180, 80))

					task.delay(3, function() 
						reqBtn.Text = "REQUEST"; reqBtn.TextColor3 = Color3.fromRGB(150, 200, 255)
						ApplyButtonGradient(reqBtn, Color3.fromRGB(20, 25, 35), Color3.fromRGB(10, 15, 25), Color3.fromRGB(80, 140, 220)) 
					end)
				end)
			end
		end
		task.delay(0.05, function() PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, math.ceil((#Players:GetPlayers() - 1) / 2) * 105 + 30) end)
	end

	MainFrame:GetPropertyChangedSignal("Visible"):Connect(function() if MainFrame.Visible then RefreshPlayers() end end)
	Players.PlayerAdded:Connect(function() if MainFrame.Visible then RefreshPlayers() end end)
	Players.PlayerRemoving:Connect(function() if MainFrame.Visible then RefreshPlayers() end end)

	-- [[ THE FIX: Applying the Dark PC Aesthetic to the Global Trade Overlay ]]
	Network.TradeUpdate.OnClientEvent:Connect(function(action, data)
		local AOT_UI = playerGui:WaitForChild("AOT_Interface")

		if action == "Open" then
			if AOT_UI:FindFirstChild("TradeOverlay") then AOT_UI.TradeOverlay:Destroy() end

			local overlay = Instance.new("Frame", AOT_UI)
			overlay.Name = "TradeOverlay"; overlay.Size = UDim2.new(1, 0, 1, 0); overlay.BackgroundColor3 = Color3.new(0,0,0); overlay.BackgroundTransparency = 0.6; overlay.Active = true

			local mainPanel = Instance.new("Frame", overlay)
			mainPanel.Size = UDim2.new(0, 600, 0, 450); mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0); mainPanel.AnchorPoint = Vector2.new(0.5, 0.5); mainPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
			Instance.new("UICorner", mainPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", mainPanel).Color = Color3.fromRGB(80, 140, 220); mainPanel.UIStroke.Thickness = 2

			local title = Instance.new("TextLabel", mainPanel)
			title.Size = UDim2.new(1, 0, 0, 50); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextColor3 = Color3.fromRGB(150, 200, 255); title.TextSize = 22; title.Text = "SECURE SESSION: " .. string.upper(data.OtherPlayer)
			ApplyGradient(title, Color3.fromRGB(150, 200, 255), Color3.fromRGB(50, 150, 255))

			-- Separator Line
			local sep = Instance.new("Frame", mainPanel)
			sep.Size = UDim2.new(0.9, 0, 0, 1); sep.Position = UDim2.new(0.05, 0, 0, 55); sep.BackgroundColor3 = Color3.fromRGB(80, 140, 220); sep.BackgroundTransparency = 0.5; sep.BorderSizePixel = 0

			-- The container where trade items would go (handled by your other systems)
			local tradeContentArea = Instance.new("Frame", mainPanel)
			tradeContentArea.Name = "TradeContentArea"
			tradeContentArea.Size = UDim2.new(1, -20, 1, -140); tradeContentArea.Position = UDim2.new(0, 10, 0, 65); tradeContentArea.BackgroundTransparency = 1

			local cancelBtn = Instance.new("TextButton", mainPanel)
			cancelBtn.Size = UDim2.new(0, 200, 0, 45); cancelBtn.Position = UDim2.new(0.5, 0, 1, -55); cancelBtn.AnchorPoint = Vector2.new(0.5, 0); cancelBtn.Font = Enum.Font.GothamBlack; cancelBtn.TextColor3 = Color3.fromRGB(255, 150, 150); cancelBtn.TextSize = 14; cancelBtn.Text = "ABORT TRANSACTION"
			ApplyButtonGradient(cancelBtn, Color3.fromRGB(35, 20, 20), Color3.fromRGB(20, 10, 10), Color3.fromRGB(180, 60, 60))

			cancelBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("Cancel") end)

		elseif action == "Close" then
			if AOT_UI:FindFirstChild("TradeOverlay") then AOT_UI.TradeOverlay:Destroy() end
		end
	end)
end

function TradeMenu.Show()
	if MainFrame then MainFrame.Visible = true end
end

return TradeMenu