-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local NotificationManager = {}
local TweenService = game:GetService("TweenService")

local container

function NotificationManager.Init(parentGui)
	if container then return end

	-- Creates the invisible holding box at the top of the screen
	container = Instance.new("Frame", parentGui)
	container.Name = "NotificationContainer"
	container.Size = UDim2.new(0, 300, 0.8, 0)
	container.Position = UDim2.new(0.5, 0, 0, 70)
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.BackgroundTransparency = 1
	container.ZIndex = 1000

	-- Automatically stacks them if multiple happen at once
	local layout = Instance.new("UIListLayout", container)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
end

function NotificationManager.Show(message, msgType)
	if not container then return end

	local color = Color3.fromRGB(255, 255, 255)
	if msgType == "Error" then color = Color3.fromRGB(255, 100, 100)
	elseif msgType == "Success" then color = Color3.fromRGB(100, 255, 100)
	elseif msgType == "Info" then color = Color3.fromRGB(100, 200, 255) end

	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(0, 280, 0, 40)
	notif.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	notif.BackgroundTransparency = 1
	Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 6)

	local stroke = Instance.new("UIStroke", notif)
	stroke.Color = color
	stroke.Transparency = 1
	stroke.Thickness = 1.5

	local label = Instance.new("TextLabel", notif)
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = color
	label.TextTransparency = 1
	label.TextWrapped = true
	label.Text = message

	notif.Parent = container

	-- Slide/Fade in
	TweenService:Create(notif, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
	TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()

	-- Wait 3.5 seconds, then fade out and delete
	task.delay(3.5, function()
		local fadeOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
		TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
		TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
		fadeOut:Play()
		fadeOut.Completed:Connect(function() notif:Destroy() end)
	end)
end

return NotificationManager