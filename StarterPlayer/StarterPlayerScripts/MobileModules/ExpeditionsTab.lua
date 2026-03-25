-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local ExpeditionsTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")
local SFXManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("SFXManager")) 

local player = Players.LocalPlayer
local MainFrame
local MenuFrame

local expeditionList = {
	{ Id = 1, Name = "The Fall of Shiganshina", Req = 0, Desc = "The breach of Wall Maria. Survival is the only objective." },
	{ Id = 2, Name = "104th Cadet Corps Training", Req = 0, Desc = "Prove your worth as a cadet. Master your balance." },
	{ Id = 3, Name = "Clash of the Titans", Req = 1, Desc = "Battle at Utgard Castle and the treacherous betrayal." },
	{ Id = 4, Name = "The Uprising", Req = 2, Desc = "Fight the Interior MP and uncover the royal bloodline." },
	{ Id = 5, Name = "Marleyan Assault", Req = 3, Desc = "Infiltrate Liberio. Strike at the heart of the enemy." },
	{ Id = 6, Name = "Return to Shiganshina", Req = 4, Desc = "Reclaim Wall Maria. Beware the beast's pitch." },
	{ Id = 7, Name = "War for Paradis", Req = 5, Desc = "Marley's counterattack. A desperate struggle for the Founder." },
	{ Id = 8, Name = "The Rumbling", Req = 6, Desc = "March of the Wall Titans. The end of all things." },
	{ Id = "Endless", Name = "Endless Expedition", Req = 2, Desc = "Venture beyond the walls. Survive as long as possible for massive rewards." }
}

function ExpeditionsTab.Init(parentFrame)
	MainFrame = Instance.new("Frame")
	MainFrame.Name = "ExpeditionsFrame"
	MainFrame.Size = UDim2.new(1, 0, 1, 0)
	MainFrame.BackgroundTransparency = 1
	MainFrame.Visible = false
	MainFrame.Parent = parentFrame

	local Title = Instance.new("TextLabel")
	Title.Size = UDim2.new(1, 0, 0, 40)
	Title.BackgroundTransparency = 1
	Title.Font = Enum.Font.GothamBlack
	Title.TextColor3 = Color3.fromRGB(255, 215, 100)
	Title.TextSize = 24
	Title.Text = "DEPLOYMENT MISSIONS"
	Title.Parent = MainFrame

	MenuFrame = Instance.new("ScrollingFrame")
	MenuFrame.Size = UDim2.new(1, 0, 1, -50)
	MenuFrame.Position = UDim2.new(0, 0, 0, 50)
	MenuFrame.BackgroundTransparency = 1
	MenuFrame.BorderSizePixel = 0
	MenuFrame.ScrollBarThickness = 6
	MenuFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 100, 60)
	MenuFrame.Parent = MainFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 15)
	layout.Parent = MenuFrame

	local uiElements = {}

	for _, dInfo in ipairs(expeditionList) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.98, 0, 0, 110)
		row.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		row.Parent = MenuFrame

		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
		Instance.new("UIStroke", row).Color = Color3.fromRGB(80, 80, 90)

		local infoContainer = Instance.new("Frame")
		infoContainer.Size = UDim2.new(1, 0, 1, 0)
		infoContainer.BackgroundTransparency = 1
		infoContainer.Parent = row

		local infoLayout = Instance.new("UIListLayout")
		infoLayout.Padding = UDim.new(0, 4)
		infoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		infoLayout.Parent = infoContainer

		local infoPad = Instance.new("UIPadding")
		infoPad.PaddingLeft = UDim.new(0, 15)
		infoPad.Parent = infoContainer

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(0.95, 0, 0, 30)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		titleLabel.TextSize = 18
		titleLabel.TextScaled = true
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Text = dInfo.Name
		titleLabel.Parent = infoContainer
		Instance.new("UITextSizeConstraint", titleLabel).MaxTextSize = 18

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.95, 0, 0, 35)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.GothamMedium
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		descLabel.TextSize = 12
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Text = dInfo.Desc
		descLabel.Parent = infoContainer

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(0.6, 0, 0, 20)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.GothamMedium
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		statusLabel.TextSize = 12
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.RichText = true
		statusLabel.Text = "Checking status..."
		statusLabel.Parent = infoContainer

		local deployBtn = Instance.new("TextButton")
		deployBtn.Size = UDim2.new(0.35, 0, 0, 40)
		deployBtn.Position = UDim2.new(1, -15, 1, -10)
		deployBtn.AnchorPoint = Vector2.new(1, 1)
		deployBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
		deployBtn.Font = Enum.Font.GothamBold
		deployBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		deployBtn.TextSize = 14
		deployBtn.Text = "DEPLOY"
		deployBtn.Parent = row

		Instance.new("UICorner", deployBtn).CornerRadius = UDim.new(0, 6)
		Instance.new("UIStroke", deployBtn).Color = Color3.fromRGB(60, 100, 60)

		deployBtn.MouseButton1Click:Connect(function()
			if deployBtn.Active then
				if SFXManager then pcall(function() SFXManager.Play("Click") end) end
				Network:WaitForChild("DungeonAction"):FireServer("StartDungeon", dInfo.Id)
			end
		end)

		uiElements[dInfo.Id] = { Status = statusLabel, Btn = deployBtn, Info = dInfo }
	end

	local function UpdateLocks()
		local prestigeObj = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige")
		local prestige = prestigeObj and prestigeObj.Value or 0

		for id, data in pairs(uiElements) do
			if prestige < data.Info.Req then
				data.Btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
				data.Btn.Text = "LOCKED"
				data.Btn.Active = false
				data.Status.Text = "<font color='#FF5555'>Requires Prestige " .. data.Info.Req .. "</font>"
			else
				data.Btn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
				data.Btn.Text = "DEPLOY"
				data.Btn.Active = true

				if id == "Endless" then
					local hs = player:GetAttribute("EndlessHighScore") or 0
					data.Status.Text = "High Score: <font color='#55FF55'>Floor " .. hs .. "</font>"
				else
					local cleared = player:GetAttribute("CampaignClear_Part" .. id)
					if cleared then
						data.Status.Text = "Status: <font color='#55FF55'>Cleared</font>"
					else
						data.Status.Text = "Status: <font color='#AAAAAA'>Uncleared</font> (Rewards Founder's Memory Wipe)"
					end
				end
			end
		end
		task.delay(0.05, function() MenuFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20) end)
	end

	player.AttributeChanged:Connect(UpdateLocks)
	task.spawn(function()
		local prestigeObj = player:WaitForChild("leaderstats", 10) and player.leaderstats:WaitForChild("Prestige", 10)
		if prestigeObj then prestigeObj.Changed:Connect(UpdateLocks) end
		UpdateLocks()
	end)
end

function ExpeditionsTab.Show()
	if MainFrame then MainFrame.Visible = true end
end

return ExpeditionsTab