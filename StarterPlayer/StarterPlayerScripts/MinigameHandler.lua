-- @ScriptType: LocalScript
-- @ScriptType: LocalScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Network = ReplicatedStorage:WaitForChild("Network")
local CombatUpdate = Network:WaitForChild("CombatUpdate")
local CombatAction = Network:WaitForChild("CombatAction")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Create the robust UI Frame
local ScreenGui = Instance.new("ScreenGui", PlayerGui)
ScreenGui.Name = "MinigameGUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = false

local Overlay = Instance.new("Frame", ScreenGui)
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Overlay.BackgroundTransparency = 0.05 -- Nearly opaque to hide combat UI behind it
Overlay.ZIndex = 100 
-- [[ THE FIX: Active = true prevents all clicks from passing through to buttons behind it ]]
Overlay.Active = true 

local Title = Instance.new("TextLabel", Overlay)
Title.Size = UDim2.new(1, 0, 0, 60)
Title.Position = UDim2.new(0, 0, 0.1, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBlack
Title.TextColor3 = Color3.fromRGB(255, 215, 100)
Title.TextSize = 28
Title.Text = "ODM BALANCE TRAINING"
Title.ZIndex = 101

local Subtitle = Instance.new("TextLabel", Overlay)
Subtitle.Size = UDim2.new(1, 0, 0, 30)
Subtitle.Position = UDim2.new(0, 0, 0.1, 60)
Subtitle.BackgroundTransparency = 1
Subtitle.Font = Enum.Font.GothamBold
Subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
Subtitle.TextSize = 16
Subtitle.Text = "Hold the screen/spacebar to boost right. Chase the white zone!"
Subtitle.ZIndex = 101

-- [[ THE FIX: Horizontal Track ]]
local Track = Instance.new("Frame", Overlay)
Track.Size = UDim2.new(0, 400, 0, 60) -- Wide and short
Track.Position = UDim2.new(0.5, 0, 0.5, 0)
Track.AnchorPoint = Vector2.new(0.5, 0.5)
Track.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Instance.new("UICorner", Track).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", Track).Color = Color3.fromRGB(60, 60, 70)
Track.ZIndex = 101

-- [[ THE FIX: Horizontal Moving Safe Zone ]]
local SafeZone = Instance.new("Frame", Track)
SafeZone.Size = UDim2.new(0.25, 0, 1, 0) -- Takes up 25% of the width
SafeZone.Position = UDim2.new(0.375, 0, 0, 0)
SafeZone.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SafeZone.BackgroundTransparency = 0.8
Instance.new("UICorner", SafeZone).CornerRadius = UDim.new(0, 4)
local SZStroke = Instance.new("UIStroke", SafeZone)
SZStroke.Color = Color3.fromRGB(255, 255, 255)
SZStroke.Thickness = 2
SafeZone.ZIndex = 102

-- Horizontal Player Indicator
local Indicator = Instance.new("Frame", Track)
Indicator.Size = UDim2.new(0.05, 0, 1.4, 0) -- Taller than the track, thin width
Indicator.AnchorPoint = Vector2.new(0.5, 0.5)
Indicator.Position = UDim2.new(0.5, 0, 0.5, 0)
Indicator.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
Instance.new("UICorner", Indicator).CornerRadius = UDim.new(0, 4)
Indicator.ZIndex = 103

-- Progress Bar
local ProgressContainer = Instance.new("Frame", Overlay)
ProgressContainer.Size = UDim2.new(0, 300, 0, 20)
ProgressContainer.Position = UDim2.new(0.5, 0, 0.8, 0)
ProgressContainer.AnchorPoint = Vector2.new(0.5, 0.5)
ProgressContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Instance.new("UICorner", ProgressContainer).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", ProgressContainer).Color = Color3.fromRGB(80, 80, 80)
ProgressContainer.ZIndex = 101

local ProgressFill = Instance.new("Frame", ProgressContainer)
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(0, 4)
ProgressFill.ZIndex = 102

-- Variables
local isActive = false
local loopConnection = nil
local isPressing = false

local position = 0.1
local velocity = 0
local progress = 0
local timeElapsed = 0

-- Horizontal Physics Tuning
local PULL_LEFT = -2.0 -- Naturally slides left
local PUSH_RIGHT = 4.0 -- Pressing moves right
local DAMPING = 0.90

-- Invisible Button covering entire screen to reliably catch clicks/taps
local ClickCatcher = Instance.new("TextButton", Overlay)
ClickCatcher.Size = UDim2.new(1, 0, 1, 0)
ClickCatcher.BackgroundTransparency = 1
ClickCatcher.Text = ""
ClickCatcher.ZIndex = 150
ClickCatcher.Active = true -- Blocks clicks

ClickCatcher.MouseButton1Down:Connect(function() if isActive then isPressing = true end end)
ClickCatcher.MouseButton1Up:Connect(function() isPressing = false end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if isActive and not gpe then
		if input.KeyCode == Enum.KeyCode.Space then isPressing = true end
	end
end)
UserInputService.InputEnded:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.Space then isPressing = false end
end)

local function StopMinigame(success)
	isActive = false
	if loopConnection then loopConnection:Disconnect() end
	ScreenGui.Enabled = false
	CombatAction:FireServer("MinigameResult", { Success = success })
end

CombatUpdate.OnClientEvent:Connect(function(action, data)
	if action == "StartMinigame" and data.MinigameType == "Balance" then
		-- Reset values
		position = 0.1
		velocity = 0
		progress = 0
		timeElapsed = 0
		isPressing = false

		ProgressFill.Size = UDim2.new(0, 0, 1, 0)
		Indicator.Position = UDim2.new(position, 0, 0.5, 0)
		Indicator.BackgroundColor3 = Color3.fromRGB(255, 100, 100)

		ScreenGui.Enabled = true
		isActive = true

		loopConnection = RunService.RenderStepped:Connect(function(dt)
			if not isActive then return end
			timeElapsed += dt

			-- [[ THE FIX: Moving Safe Zone Logic ]]
			-- Uses two sine waves combined to make the movement organic and unpredictable
			local szCenterOffset = math.sin(timeElapsed * 1.3) * 0.2 + math.sin(timeElapsed * 0.8) * 0.175
			local szPos = 0.375 + szCenterOffset
			-- szPos will naturally drift between ~0.0 and 0.75.
			SafeZone.Position = UDim2.new(szPos, 0, 0, 0)

			-- Apply Horizontal Physics
			if isPressing then
				velocity += PUSH_RIGHT * dt
			else
				velocity += PULL_LEFT * dt
			end
			velocity *= DAMPING

			position = math.clamp(position + velocity * dt, 0, 1)

			-- Clamp Velocity if hitting edges
			if position <= 0 or position >= 1 then velocity = 0 end
			Indicator.Position = UDim2.new(position, 0, 0.5, 0)

			-- Logic Check: Indicator safe zone bounds
			local safeLeft = szPos
			local safeRight = szPos + 0.25

			if position >= safeLeft and position <= safeRight then
				Indicator.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
				SZStroke.Color = Color3.fromRGB(100, 255, 100)
				progress = math.clamp(progress + (dt / 4), 0, 1) -- Requires 4 seconds inside
			else
				Indicator.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
				SZStroke.Color = Color3.fromRGB(255, 255, 255)
				progress = math.clamp(progress - (dt / 3), 0, 1) -- Lose progress faster than gained
			end

			ProgressFill.Size = UDim2.new(progress, 0, 1, 0)

			if progress >= 1 then
				StopMinigame(true)
			end
		end)
	end
end)