-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local CinematicManager = {}

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

function CinematicManager.Show(titleText, subText, colorHex)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Clean up any existing cinematics just in case
	if playerGui:FindFirstChild("CinematicPopup") then
		playerGui.CinematicPopup:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CinematicPopup"
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local cColor = colorHex and Color3.fromHex(colorHex:gsub("#", "")) or Color3.fromRGB(255, 215, 100)

	-- Dark Overlay
	local bg = Instance.new("Frame", gui)
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 1

	-- Center container
	local container = Instance.new("Frame", gui)
	container.Size = UDim2.new(1, 0, 0, 200)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1

	-- Top and Bottom Glowing Lines
	local topLine = Instance.new("Frame", container)
	topLine.Size = UDim2.new(0, 0, 0, 2)
	topLine.Position = UDim2.new(0.5, 0, 0.2, 0)
	topLine.AnchorPoint = Vector2.new(0.5, 0.5)
	topLine.BackgroundColor3 = cColor
	topLine.BackgroundTransparency = 1
	topLine.BorderSizePixel = 0

	-- Fades the edges of the lines into darkness
	local grad1 = Instance.new("UIGradient", topLine)
	grad1.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1)
	}

	local bottomLine = topLine:Clone()
	bottomLine.Position = UDim2.new(0.5, 0, 0.8, 0)
	bottomLine.Parent = container

	-- Expands text with spaces for that dramatic, wide fantasy letter-spacing
	local spacedTitle = ""
	for i = 1, #titleText do spacedTitle = spacedTitle .. titleText:sub(i,i) .. " " end

	-- Main Title
	local title = Instance.new("TextLabel", container)
	title.Size = UDim2.new(1, 0, 0, 80)
	title.Position = UDim2.new(0.5, 0, 0.5, -15)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Bodoni -- Extremely elegant, Souls-like font
	title.Text = spacedTitle
	title.TextColor3 = cColor
	title.TextSize = 48
	title.TextTransparency = 1

	local uiScale = Instance.new("UIScale", title)
	uiScale.Scale = 0.8

	-- Subtext (The specific titan)
	local sub = Instance.new("TextLabel", container)
	sub.Size = UDim2.new(1, 0, 0, 40)
	sub.Position = UDim2.new(0.5, 0, 0.5, 30)
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamMedium
	sub.Text = subText or ""
	sub.TextColor3 = Color3.fromRGB(220, 220, 220)
	sub.TextSize = 18
	sub.TextTransparency = 1

	-- [[ THE ANIMATION SEQUENCE ]]
	TweenService:Create(bg, TweenInfo.new(2, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.4}):Play()

	TweenService:Create(topLine, TweenInfo.new(2.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0.65, 0, 0, 2), BackgroundTransparency = 0}):Play()
	TweenService:Create(bottomLine, TweenInfo.new(2.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0.65, 0, 0, 2), BackgroundTransparency = 0}):Play()

	task.wait(0.3)
	TweenService:Create(title, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
	TweenService:Create(uiScale, TweenInfo.new(6, Enum.EasingStyle.Linear), {Scale = 1.05}):Play()

	task.wait(1.2)
	TweenService:Create(sub, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()

	-- Hold the screen for the player to read
	task.wait(3.5)

	-- Fade out everything gracefully
	TweenService:Create(bg, TweenInfo.new(2, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
	TweenService:Create(topLine, TweenInfo.new(2, Enum.EasingStyle.Sine), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
	TweenService:Create(bottomLine, TweenInfo.new(2, Enum.EasingStyle.Sine), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
	TweenService:Create(title, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()
	TweenService:Create(sub, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()

	task.wait(2)
	gui:Destroy()
end

return CinematicManager