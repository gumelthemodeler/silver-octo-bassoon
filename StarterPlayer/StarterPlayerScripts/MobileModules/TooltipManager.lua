-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local TooltipManager = {}
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local tooltipFrame
local tooltipText

function TooltipManager.Init(parentGui)
	tooltipFrame = Instance.new("Frame")
	tooltipFrame.Name = "TooltipFrame"
	tooltipFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	tooltipFrame.Visible = false
	tooltipFrame.ZIndex = 1000
	tooltipFrame.Parent = parentGui

	Instance.new("UICorner", tooltipFrame).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", tooltipFrame).Color = Color3.fromRGB(120, 100, 60)

	tooltipText = Instance.new("TextLabel")
	tooltipText.Size = UDim2.new(1, -10, 1, -10)
	tooltipText.Position = UDim2.new(0, 5, 0, 5)
	tooltipText.BackgroundTransparency = 1
	tooltipText.Font = Enum.Font.GothamMedium
	tooltipText.TextColor3 = Color3.fromRGB(200, 200, 200)
	tooltipText.TextSize = 12
	tooltipText.RichText = true
	tooltipText.TextWrapped = true
	tooltipText.TextXAlignment = Enum.TextXAlignment.Left
	tooltipText.TextYAlignment = Enum.TextYAlignment.Top
	tooltipText.Parent = tooltipFrame

	RunService.RenderStepped:Connect(function()
		if tooltipFrame.Visible then
			-- Offset so the mouse cursor doesn't block the text
			tooltipFrame.Position = UDim2.new(0, mouse.X + 15, 0, mouse.Y + 15)
		end
	end)
end

function TooltipManager.Show(text)
	if not tooltipFrame then return end
	tooltipText.Text = text

	-- Approximate size based on text length and line breaks
	local lines = select(2, string.gsub(text, "\n", "")) + 1
	local height = math.max(40, lines * 18 + 10)
	tooltipFrame.Size = UDim2.new(0, 200, 0, height)

	tooltipFrame.Visible = true
end

function TooltipManager.Hide()
	if tooltipFrame then tooltipFrame.Visible = false end
end

return TooltipManager