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

local ScreenGui = Instance.new("ScreenGui", PlayerGui)
ScreenGui.Name = "MinigameGUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = false

local Overlay = Instance.new("Frame", ScreenGui)
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Overlay.BackgroundTransparency = 0.05
Overlay.ZIndex = 100 
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

local Track = Instance.new("Frame", Overlay)
Track.Size = UDim2.new(0, 400, 0, 60)
Track.Position = UDim2.new(0.5, 0, 0.5, 0)
Track.AnchorPoint = Vector2.new(0.5, 0.5)
Track.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Instance.new("UICorner", Track).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", Track).Color = Color3.fromRGB(60, 60, 70)
Track.ZIndex = 101

local SafeZone = Instance.new("Frame", Track)
SafeZone.Size = UDim2.new(0.25, 0, 1, 0)
SafeZone.Position = UDim2.new(0.375, 0, 0, 0)
SafeZone.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SafeZone.BackgroundTransparency = 0.8
Instance.new("UICorner", SafeZone).CornerRadius = UDim.new(0, 4)
local SZStroke = Instance.new("UIStroke", SafeZone)
SZStroke.Color = Color3.fromRGB(255, 255, 255)
SZStroke.Thickness = 2
SafeZone.ZIndex = 102

local Indicator = Instance.new("Frame", Track)
Indicator.Size = UDim2.new(0.05, 0, 1.4, 0)
Indicator.AnchorPoint = Vector2.new(0.5, 0.5)
Indicator.Position = UDim2.new(0.5, 0, 0.5, 0)
Indicator.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
Instance.new("UICorner", Indicator).CornerRadius = UDim.new(0, 4)
Indicator.ZIndex = 103

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

local isActive = false
local loopConnection = nil
local isPressing = false

local position = 0.1
local velocity = 0
local progress = 0
local timeElapsed = 0

local PULL_LEFT = -2.0 
local PUSH_RIGHT = 4.0 
local DAMPING = 0.90

local ClickCatcher = Instance.new("TextButton", Overlay)
ClickCatcher.Size = UDim2.new(1, 0, 1, 0)
ClickCatcher.BackgroundTransparency = 1
ClickCatcher.Text = ""
ClickCatcher.ZIndex = 150
ClickCatcher.Active = true 

ClickCatcher.InputBegan:Connect(function(input)
	if isActive and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		isPressing = true
	end
end)
ClickCatcher.InputEnded:Connect(function(input)
	if isActive and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		isPressing = false
	end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if isActive and not gpe then if input.KeyCode == Enum.KeyCode.Space then isPressing = true end end
end)
UserInputService.InputEnded:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.Space then isPressing = false end
end)

local function StopMinigame(success)
	isActive = false
	if loopConnection then loopConnection:Disconnect() end
	ScreenGui.Enabled = false
	CombatAction:FireServer("MinigameResult", { Success = success, MinigameType = "Balance" })
end

CombatUpdate.OnClientEvent:Connect(function(action, data)
	if action == "StartMinigame" then
		if data.MinigameType == "Balance" then
			position = 0.1; velocity = 0; progress = 0; timeElapsed = 0; isPressing = false
			ProgressFill.Size = UDim2.new(0, 0, 1, 0)
			Indicator.Position = UDim2.new(position, 0, 0.5, 0)
			Indicator.BackgroundColor3 = Color3.fromRGB(255, 100, 100)

			ScreenGui.Enabled = true
			isActive = true

			loopConnection = RunService.RenderStepped:Connect(function(dt)
				if not isActive then return end
				timeElapsed += dt

				if timeElapsed >= 30 then StopMinigame(true); return end

				local szCenterOffset = math.sin(timeElapsed * 1.3) * 0.2 + math.sin(timeElapsed * 0.8) * 0.175
				local szPos = 0.375 + szCenterOffset
				SafeZone.Position = UDim2.new(szPos, 0, 0, 0)

				if isPressing then velocity += PUSH_RIGHT * dt else velocity += PULL_LEFT * dt end
				velocity *= DAMPING
				position = math.clamp(position + velocity * dt, 0, 1)
				if position <= 0 or position >= 1 then velocity = 0 end
				Indicator.Position = UDim2.new(position, 0, 0.5, 0)

				local safeLeft = szPos
				local safeRight = szPos + 0.25

				if position >= safeLeft and position <= safeRight then
					Indicator.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
					SZStroke.Color = Color3.fromRGB(100, 255, 100)
					progress = math.clamp(progress + (dt / 4), 0, 1) 
				else
					Indicator.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
					SZStroke.Color = Color3.fromRGB(255, 255, 255)
					progress = math.clamp(progress - (dt / 3), 0, 1) 
				end
				ProgressFill.Size = UDim2.new(progress, 0, 1, 0)

				if progress >= 1 then StopMinigame(true) end
			end)

		elseif data.MinigameType == "GapClose" then
			ScreenGui.Enabled = true
			isActive = true

			if Overlay:FindFirstChild("GapCloseContainer") then Overlay.GapCloseContainer:Destroy() end

			local gcContainer = Instance.new("Frame", Overlay)
			gcContainer.Name = "GapCloseContainer"
			gcContainer.Size = UDim2.new(1,0,1,0)
			gcContainer.BackgroundTransparency = 1

			Title.Text = "EVADE THE ATTACKS!"
			Subtitle.Text = "Tap the warning zones before they strike you!"

			Track.Visible = false
			ProgressContainer.Visible = false
			ClickCatcher.Visible = false

			local targetsToHit = 3
			local hits = 0

			local function SpawnTarget()
				if not isActive then return end

				local target = Instance.new("TextButton", gcContainer)
				target.Size = UDim2.new(0, 80, 0, 80)
				target.Position = UDim2.new(math.random(20, 80)/100, 0, math.random(30, 70)/100, 0)
				target.AnchorPoint = Vector2.new(0.5, 0.5)
				target.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
				target.Text = "DODGE!"
				target.Font = Enum.Font.GothamBlack; target.TextSize = 14; target.TextColor3 = Color3.fromRGB(255, 255, 255)
				Instance.new("UICorner", target).CornerRadius = UDim.new(0, 40)

				local inner = Instance.new("Frame", target)
				inner.Size = UDim2.new(1.5, 0, 1.5, 0); inner.AnchorPoint = Vector2.new(0.5, 0.5); inner.Position = UDim2.new(0.5, 0, 0.5, 0)
				inner.BackgroundTransparency = 1; Instance.new("UICorner", inner).CornerRadius = UDim.new(0, 60)
				local stroke = Instance.new("UIStroke", inner); stroke.Color = Color3.fromRGB(255, 200, 200); stroke.Thickness = 4

				local tInfo = TweenInfo.new(1.2, Enum.EasingStyle.Linear)
				local t = game:GetService("TweenService"):Create(inner, tInfo, {Size = UDim2.new(0, 0, 0, 0)})
				t:Play()

				local clicked = false

				-- [[ THE FIX: Replaced MouseButton1Click with InputBegan to perfectly capture Mobile touches ]]
				target.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if clicked or not isActive then return end
						clicked = true; hits += 1
						target.BackgroundColor3 = Color3.fromRGB(50, 255, 50); target.Text = "SAFE"
						task.wait(0.15); target:Destroy()

						if hits >= targetsToHit then
							Title.Text = "SUCCESS!"
							Title.TextColor3 = Color3.fromRGB(50, 255, 50)
							task.wait(1)
							gcContainer:Destroy()
							Track.Visible = true; ProgressContainer.Visible = true; ClickCatcher.Visible = true
							Title.TextColor3 = Color3.fromRGB(255, 215, 100)
							isActive = false
							ScreenGui.Enabled = false
							CombatAction:FireServer("MinigameResult", { Success = true, MinigameType = "GapClose" })
						else
							SpawnTarget()
						end
					end
				end)

				t.Completed:Connect(function()
					if not clicked and isActive then
						isActive = false
						target.BackgroundColor3 = Color3.fromRGB(100, 100, 100); target.Text = "HIT"
						Title.Text = "FAILED!"
						Title.TextColor3 = Color3.fromRGB(255, 50, 50)
						task.wait(1)
						gcContainer:Destroy()
						Track.Visible = true; ProgressContainer.Visible = true; ClickCatcher.Visible = true
						Title.TextColor3 = Color3.fromRGB(255, 215, 100)
						ScreenGui.Enabled = false
						CombatAction:FireServer("MinigameResult", { Success = false, MinigameType = "GapClose" })
					end
				end)
			end

			SpawnTarget()

		elseif data.MinigameType == "RegimentChoice" then
			StopMinigame(true)
		end
	end
end)