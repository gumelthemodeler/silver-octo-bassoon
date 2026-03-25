-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local BattleTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))

local player = Players.LocalPlayer
local MainFrame
local ContentArea
local SubTabs = {}
local SubBtns = {}
local cBtns = {}
local rBtns = {}
local CompletionBanner

-- [[ THE PATHS UI VARS ]]
local pBtn, pStats, pShopPanel, pShopBtn

local expeditionList = {
	{ Id = 1, Name = "The Fall of Shiganshina", Req = 0, Desc = "The breach of Wall Maria. Survival is the only objective." },
	{ Id = 2, Name = "104th Cadet Corps Training", Req = 0, Desc = "Prove your worth as a cadet. Master your balance." },
	{ Id = 3, Name = "Clash of the Titans", Req = 0, Desc = "Battle at Utgard Castle and the treacherous betrayal." },
	{ Id = 4, Name = "The Uprising", Req = 0, Desc = "Fight the Interior MP and uncover the royal bloodline." },
	{ Id = 5, Name = "Marleyan Assault", Req = 0, Desc = "Infiltrate Liberio. Strike at the heart of the enemy." },
	{ Id = 6, Name = "Return to Shiganshina", Req = 0, Desc = "Reclaim Wall Maria. Beware the beast's pitch." },
	{ Id = 7, Name = "War for Paradis", Req = 0, Desc = "Marley's counterattack. A desperate struggle for the Founder." },
	{ Id = 8, Name = "The Rumbling", Req = 0, Desc = "March of the Wall Titans. The end of all things." }
}

local raidList = {
	{ Id = "Raid_Part1", Name = "Female Titan", Req = 1, Desc = "A deadly raid against a highly intelligent shifter." },
	{ Id = "Raid_Part2", Name = "Armored Titan", Req = 2, Desc = "Pierce the Bastion's armor. Bring Thunder Spears!" },
	{ Id = "Raid_Part3", Name = "Beast Titan", Req = 3, Desc = "Avoid the crushed boulders. A terrifying intellect." },
	{ Id = "Raid_Part5", Name = "Founding Titan (Eren)", Req = 5, Desc = "The Coordinate commands all. Survive the Rumbling." }
}

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

function BattleTab.Init(parentFrame)
	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "BattleFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 30); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 100, 100); Title.TextSize = 20; Title.Text = "COMBAT OPERATIONS"

	-- [[ THE FIX: Removed AutomaticCanvasSize and hardcoded a wide CanvasSize to stop the swallowing bug ]]
	local TopNav = Instance.new("ScrollingFrame", MainFrame)
	TopNav.Size = UDim2.new(1, 0, 0, 45); TopNav.Position = UDim2.new(0, 0, 0, 35); TopNav.BackgroundColor3 = Color3.fromRGB(15, 15, 18); TopNav.ScrollBarThickness = 0
	TopNav.ScrollingDirection = Enum.ScrollingDirection.X
	TopNav.CanvasSize = UDim2.new(0, 800, 0, 0) -- Forces the internal canvas to be wide enough!
	Instance.new("UICorner", TopNav).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", TopNav).Color = Color3.fromRGB(120, 100, 60)

	local navLayout = Instance.new("UIListLayout", TopNav); navLayout.FillDirection = Enum.FillDirection.Horizontal; navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left; navLayout.VerticalAlignment = Enum.VerticalAlignment.Center; navLayout.Padding = UDim.new(0, 8)
	local navPad = Instance.new("UIPadding", TopNav); navPad.PaddingLeft = UDim.new(0, 10); navPad.PaddingRight = UDim.new(0, 10)

	-- Secondary dynamic sizing check just to be perfectly safe
	navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		TopNav.CanvasSize = UDim2.new(0, navLayout.AbsoluteContentSize.X + 20, 0, 0)
	end)

	ContentArea = Instance.new("Frame", MainFrame)
	ContentArea.Size = UDim2.new(1, 0, 1, -90); ContentArea.Position = UDim2.new(0, 0, 0, 90); ContentArea.BackgroundTransparency = 1

	local function CreateSubNavBtn(name, text)
		local btn = Instance.new("TextButton", TopNav)
		btn.Size = UDim2.new(0, 140, 0, 30); btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(200, 200, 200); btn.TextSize = 11; btn.Text = text
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", btn).Color = Color3.fromRGB(60, 60, 65)

		btn.MouseButton1Click:Connect(function()
			for k, v in pairs(SubBtns) do TweenService:Create(v, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 35), TextColor3 = Color3.fromRGB(200, 200, 200)}):Play() end
			TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(120, 100, 60), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			for k, frame in pairs(SubTabs) do frame.Visible = (k == name) end
		end)
		SubBtns[name] = btn
		return btn
	end

	CreateSubNavBtn("Campaign", "CAMPAIGN")
	CreateSubNavBtn("Endless", "ENDLESS EXPEDITION")
	CreateSubNavBtn("Paths", "THE PATHS")
	CreateSubNavBtn("Raids", "MULTIPLAYER RAIDS")
	CreateSubNavBtn("World", "WORLD BOSSES")

	-- [[ 1. CAMPAIGN TAB ]]
	SubTabs["Campaign"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Campaign"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Campaign"].BackgroundTransparency = 1; SubTabs["Campaign"].BorderSizePixel = 0; SubTabs["Campaign"].ScrollBarThickness = 2; SubTabs["Campaign"].Visible = true
	local cLayout = Instance.new("UIListLayout", SubTabs["Campaign"]); cLayout.Padding = UDim.new(0, 10); cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; cLayout.SortOrder = Enum.SortOrder.LayoutOrder

	CompletionBanner = Instance.new("TextLabel", SubTabs["Campaign"])
	CompletionBanner.Size = UDim2.new(1, -10, 0, 50); CompletionBanner.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
	CompletionBanner.Font = Enum.Font.GothamBlack; CompletionBanner.TextColor3 = Color3.fromRGB(255, 215, 100); CompletionBanner.TextSize = 11; CompletionBanner.TextWrapped = true
	CompletionBanner.Text = "STORY COMPLETE! Replay missions to max your stats and Prestige."
	CompletionBanner.LayoutOrder = 0
	Instance.new("UICorner", CompletionBanner).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", CompletionBanner).Color = Color3.fromRGB(200, 150, 50)
	CompletionBanner.Visible = false

	for _, dInfo in ipairs(expeditionList) do
		local row = Instance.new("Frame", SubTabs["Campaign"])
		row.Size = UDim2.new(1, -10, 0, 90); row.BackgroundColor3 = Color3.fromRGB(25, 25, 30); row.LayoutOrder = dInfo.Id
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", row).Color = Color3.fromRGB(60, 60, 65)

		local title = Instance.new("TextLabel", row)
		title.Size = UDim2.new(1, -20, 0, 20); title.Position = UDim2.new(0, 10, 0, 5); title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold; title.TextColor3 = Color3.fromRGB(255, 255, 255); title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = dInfo.Name

		local desc = Instance.new("TextLabel", row)
		desc.Size = UDim2.new(1, -20, 0, 30); desc.Position = UDim2.new(0, 10, 0, 25); desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(180, 180, 180); desc.TextSize = 11; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = dInfo.Desc

		local btn = Instance.new("TextButton", row)
		btn.Size = UDim2.new(0.95, 0, 0, 25); btn.AnchorPoint = Vector2.new(0.5, 0); btn.Position = UDim2.new(0.5, 0, 1, -30); btn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
		btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 12; btn.Text = "DEPLOY"
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		btn.MouseButton1Click:Connect(function() if btn.Active then Network:WaitForChild("CombatAction"):FireServer("EngageStory", {PartId = dInfo.Id}) end end)
		cBtns[dInfo.Id] = { Btn = btn }
	end

	-- [[ 2. ENDLESS EXPEDITION TAB ]]
	SubTabs["Endless"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Endless"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Endless"].BackgroundTransparency = 1; SubTabs["Endless"].BorderSizePixel = 0; SubTabs["Endless"].Visible = false

	local eBox = Instance.new("Frame", SubTabs["Endless"])
	eBox.Size = UDim2.new(1, -10, 0, 200); eBox.Position = UDim2.new(0, 5, 0, 10); eBox.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
	Instance.new("UICorner", eBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", eBox).Color = Color3.fromRGB(100, 60, 120)

	local eTitle = Instance.new("TextLabel", eBox)
	eTitle.Size = UDim2.new(1, 0, 0, 40); eTitle.BackgroundTransparency = 1; eTitle.Font = Enum.Font.GothamBlack; eTitle.TextColor3 = Color3.fromRGB(220, 150, 255); eTitle.TextSize = 18; eTitle.Text = "ENDLESS EXPEDITION"

	local eDesc = Instance.new("TextLabel", eBox)
	eDesc.Size = UDim2.new(0.9, 0, 0, 80); eDesc.Position = UDim2.new(0.05, 0, 0, 40); eDesc.BackgroundTransparency = 1
	eDesc.Font = Enum.Font.GothamMedium; eDesc.TextColor3 = Color3.fromRGB(200, 200, 200); eDesc.TextSize = 12; eDesc.TextWrapped = true; eDesc.Text = "Venture beyond the walls continuously. You will fight random enemies matching your highest unlocked Campaign Part. Drops are permanently multiplied by 1.2x. How long can you survive?"

	local eBtn = Instance.new("TextButton", eBox)
	eBtn.Size = UDim2.new(0.8, 0, 0, 40); eBtn.AnchorPoint = Vector2.new(0.5, 0); eBtn.Position = UDim2.new(0.5, 0, 1, -50); eBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 140)
	eBtn.Font = Enum.Font.GothamBlack; eBtn.TextColor3 = Color3.fromRGB(255, 255, 255); eBtn.TextSize = 16; eBtn.Text = "DEPART"
	Instance.new("UICorner", eBtn).CornerRadius = UDim.new(0, 8)
	eBtn.MouseButton1Click:Connect(function() Network:WaitForChild("CombatAction"):FireServer("EngageEndless") end)

	-- [[ 3. THE PATHS TAB & SHOP ]]
	SubTabs["Paths"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Paths"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Paths"].BackgroundTransparency = 1; SubTabs["Paths"].BorderSizePixel = 0; SubTabs["Paths"].ScrollBarThickness = 0; SubTabs["Paths"].Visible = false
	local pLayout = Instance.new("UIListLayout", SubTabs["Paths"]); pLayout.Padding = UDim.new(0, 15); pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local pBox = Instance.new("Frame", SubTabs["Paths"])
	pBox.Size = UDim2.new(1, -10, 0, 250); pBox.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
	Instance.new("UICorner", pBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", pBox).Color = Color3.fromRGB(100, 200, 255); pBox.UIStroke.Thickness = 2

	local pTitleLbl = Instance.new("TextLabel", pBox)
	pTitleLbl.Size = UDim2.new(1, 0, 0, 40); pTitleLbl.BackgroundTransparency = 1; pTitleLbl.Font = Enum.Font.GothamBlack; pTitleLbl.TextColor3 = Color3.fromRGB(255, 255, 255); pTitleLbl.TextSize = 24; pTitleLbl.Text = "THE PATHS"
	ApplyGradient(pTitleLbl, Color3.fromRGB(150, 200, 255), Color3.fromRGB(200, 100, 255))

	local pDesc = Instance.new("TextLabel", pBox)
	pDesc.Size = UDim2.new(0.9, 0, 0, 80); pDesc.Position = UDim2.new(0.05, 0, 0, 40); pDesc.BackgroundTransparency = 1
	pDesc.Font = Enum.Font.GothamMedium; pDesc.TextColor3 = Color3.fromRGB(200, 220, 255); pDesc.TextSize = 12; pDesc.TextWrapped = true
	pDesc.Text = "A realm of infinite sand where time holds no meaning. Face brutally mutated memories that scale infinitely in power to earn <font color='#55FFFF'>Path Dust</font>.\n\n<font color='#AA55FF'>Only those who have stopped The Rumbling may enter.</font>"; pDesc.RichText = true

	pStats = Instance.new("TextLabel", pBox)
	pStats.Size = UDim2.new(1, 0, 0, 20); pStats.Position = UDim2.new(0, 0, 0, 125); pStats.BackgroundTransparency = 1
	pStats.Font = Enum.Font.GothamBlack; pStats.TextColor3 = Color3.fromRGB(150, 255, 255); pStats.TextSize = 12
	pStats.Text = "CURRENT MEMORY: 1   |   PATH DUST: 0"

	pBtn = Instance.new("TextButton", pBox)
	pBtn.Size = UDim2.new(0.8, 0, 0, 35); pBtn.AnchorPoint = Vector2.new(0.5, 0); pBtn.Position = UDim2.new(0.5, 0, 0, 155); pBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
	pBtn.Font = Enum.Font.GothamBlack; pBtn.TextColor3 = Color3.fromRGB(255, 255, 255); pBtn.TextSize = 14; pBtn.Text = "ENTER THE PATHS"
	Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", pBtn).Color = Color3.fromRGB(100, 200, 255)
	pBtn.MouseButton1Click:Connect(function() if pBtn.Active then Network:WaitForChild("CombatAction"):FireServer("EngagePaths") end end)

	pShopBtn = Instance.new("TextButton", pBox)
	pShopBtn.Size = UDim2.new(0.8, 0, 0, 35); pShopBtn.AnchorPoint = Vector2.new(0.5, 0); pShopBtn.Position = UDim2.new(0.5, 0, 0, 200); pShopBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 100)
	pShopBtn.Font = Enum.Font.GothamBlack; pShopBtn.TextColor3 = Color3.fromRGB(255, 255, 255); pShopBtn.TextSize = 14; pShopBtn.Text = "PATHS SHOP"
	Instance.new("UICorner", pShopBtn).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", pShopBtn).Color = Color3.fromRGB(100, 255, 255)

	-- PATHS SHOP PANEL (Mobile Stacked)
	pShopPanel = Instance.new("Frame", SubTabs["Paths"])
	pShopPanel.Size = UDim2.new(1, -10, 0, 150); pShopPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	Instance.new("UICorner", pShopPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", pShopPanel).Color = Color3.fromRGB(100, 255, 255)
	pShopPanel.Visible = false

	local function CreateShopItem(parent, itemName, cost, posY, isSand)
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, 0, 0, 40); row.Position = UDim2.new(0, 0, 0, posY); row.BackgroundTransparency = 1

		local nameLbl = Instance.new("TextLabel", row)
		nameLbl.Size = UDim2.new(0.65, 0, 1, 0); nameLbl.Position = UDim2.new(0.05, 0, 0, 0); nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255); nameLbl.TextSize = 11; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Text = itemName

		local buyBtn = Instance.new("TextButton", row)
		buyBtn.Size = UDim2.new(0.25, 0, 0.7, 0); buyBtn.AnchorPoint = Vector2.new(1, 0.5); buyBtn.Position = UDim2.new(0.95, 0, 0.5, 0); buyBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 80)
		buyBtn.Font = Enum.Font.GothamBold; buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255); buyBtn.TextSize = 10; buyBtn.Text = "BUY (" .. cost .. ")"
		Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 4)

		buyBtn.MouseButton1Click:Connect(function()
			if isSand then Network:WaitForChild("PathsShopBuy"):FireServer("Sand")
			elseif itemName:find("Extract") then Network:WaitForChild("PathsShopBuy"):FireServer("Extract")
			else Network:WaitForChild("PathsShopBuy"):FireServer("Serum") end
		end)
	end

	CreateShopItem(pShopPanel, "Ancestral Serum", 100, 15, false)
	CreateShopItem(pShopPanel, "Titan Extract", 25, 60, false)
	CreateShopItem(pShopPanel, "Coordinate's Sand", 500, 105, true)

	pShopBtn.MouseButton1Click:Connect(function()
		pShopPanel.Visible = not pShopPanel.Visible
		task.delay(0.05, function() SubTabs["Paths"].CanvasSize = UDim2.new(0, 0, 0, pLayout.AbsoluteContentSize.Y + 20) end)
	end)

	-- [[ 4. RAIDS TAB ]]
	SubTabs["Raids"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Raids"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Raids"].BackgroundTransparency = 1; SubTabs["Raids"].BorderSizePixel = 0; SubTabs["Raids"].ScrollBarThickness = 2; SubTabs["Raids"].Visible = false
	local rLayout = Instance.new("UIListLayout", SubTabs["Raids"]); rLayout.Padding = UDim.new(0, 10); rLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	for _, rInfo in ipairs(raidList) do
		local row = Instance.new("Frame", SubTabs["Raids"])
		row.Size = UDim2.new(1, -10, 0, 90); row.BackgroundColor3 = Color3.fromRGB(30, 20, 25)
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", row).Color = Color3.fromRGB(90, 40, 40)

		local title = Instance.new("TextLabel", row)
		title.Size = UDim2.new(1, -20, 0, 20); title.Position = UDim2.new(0, 10, 0, 5); title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold; title.TextColor3 = Color3.fromRGB(255, 100, 100); title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = rInfo.Name

		local desc = Instance.new("TextLabel", row)
		desc.Size = UDim2.new(1, -20, 0, 30); desc.Position = UDim2.new(0, 10, 0, 25); desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(180, 180, 180); desc.TextSize = 11; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = rInfo.Desc

		local btn = Instance.new("TextButton", row)
		btn.Size = UDim2.new(0.95, 0, 0, 25); btn.AnchorPoint = Vector2.new(0.5, 0); btn.Position = UDim2.new(0.5, 0, 1, -30); btn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
		btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 12; btn.Text = "HOST LOBBY"
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		btn.MouseButton1Click:Connect(function() if btn.Active then Network:WaitForChild("RaidAction"):FireServer("CreateLobby", {RaidId = rInfo.Id, FriendsOnly = false}) end end)
		rBtns[rInfo.Id] = { Btn = btn, Req = rInfo.Req }
	end

	-- [[ 5. WORLD EVENTS TAB ]]
	SubTabs["World"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["World"].Size = UDim2.new(1, 0, 1, 0); SubTabs["World"].BackgroundTransparency = 1; SubTabs["World"].BorderSizePixel = 0; SubTabs["World"].ScrollBarThickness = 2; SubTabs["World"].Visible = false
	local wLayout = Instance.new("UIListLayout", SubTabs["World"]); wLayout.Padding = UDim.new(0, 10); wLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local sortedBosses = {}
	for bId, bData in pairs(EnemyData.WorldBosses) do table.insert(sortedBosses, {Id = bId, Data = bData}) end
	table.sort(sortedBosses, function(a, b) return (a.Data.Health or 0) < (b.Data.Health or 0) end)

	for _, bInfo in ipairs(sortedBosses) do
		local bId = bInfo.Id; local bData = bInfo.Data

		local row = Instance.new("Frame", SubTabs["World"])
		row.Size = UDim2.new(1, -10, 0, 90); row.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", row).Color = Color3.fromRGB(120, 80, 40)

		local title = Instance.new("TextLabel", row)
		title.Size = UDim2.new(1, -20, 0, 20); title.Position = UDim2.new(0, 10, 0, 5); title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold; title.TextColor3 = Color3.fromRGB(255, 180, 50); title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = bData.Name

		local desc = Instance.new("TextLabel", row)
		desc.Size = UDim2.new(1, -20, 0, 30); desc.Position = UDim2.new(0, 10, 0, 25); desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(180, 180, 180); desc.TextSize = 11; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = bData.Desc or "A massive world boss event."

		local btn = Instance.new("TextButton", row)
		btn.Size = UDim2.new(0.95, 0, 0, 25); btn.AnchorPoint = Vector2.new(0.5, 0); btn.Position = UDim2.new(0.5, 0, 1, -30); btn.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
		btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 12; btn.Text = "ENGAGE"
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		btn.MouseButton1Click:Connect(function() Network:WaitForChild("CombatAction"):FireServer("EngageWorldBoss", {BossId = bId}) end)
	end


	local function UpdateLocks()
		local currentPart = player:GetAttribute("CurrentPart") or 1
		local prestigeObj = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige")
		local prestige = prestigeObj and prestigeObj.Value or 0

		local floor = player:GetAttribute("PathsFloor") or 1
		local dust = player:GetAttribute("PathDust") or 0
		if pStats then pStats.Text = "CURRENT MEMORY: " .. floor .. "   |   PATH DUST: " .. dust end

		if currentPart > 8 then
			if CompletionBanner then CompletionBanner.Visible = true end
			if pBtn then pBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 100); pBtn.Text = "ENTER THE PATHS"; pBtn.Active = true end
		else
			if CompletionBanner then CompletionBanner.Visible = false end
			if pBtn then pBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45); pBtn.Text = "LOCKED (BEAT CAMPAIGN)"; pBtn.Active = false end
		end

		for id, data in pairs(cBtns) do
			if currentPart > id then
				data.Btn.BackgroundColor3 = Color3.fromRGB(30, 80, 120); data.Btn.Text = "REPLAY"; data.Btn.Active = true 
			elseif currentPart == id then
				data.Btn.BackgroundColor3 = Color3.fromRGB(40, 80, 40); data.Btn.Text = "DEPLOY"; data.Btn.Active = true
			else
				data.Btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45); data.Btn.Text = "LOCKED"; data.Btn.Active = false
			end
		end

		for _, data in pairs(rBtns) do
			if prestige < data.Req then
				data.Btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45); data.Btn.Text = "LOCKED"; data.Btn.Active = false
			else
				data.Btn.BackgroundColor3 = Color3.fromRGB(80, 40, 40); data.Btn.Text = "HOST LOBBY"; data.Btn.Active = true
			end
		end

		task.delay(0.05, function() SubTabs["Campaign"].CanvasSize = UDim2.new(0, 0, 0, cLayout.AbsoluteContentSize.Y + 20) end)
		task.delay(0.05, function() SubTabs["Paths"].CanvasSize = UDim2.new(0, 0, 0, pLayout.AbsoluteContentSize.Y + 20) end)
		task.delay(0.05, function() SubTabs["Raids"].CanvasSize = UDim2.new(0, 0, 0, rLayout.AbsoluteContentSize.Y + 20) end)
		task.delay(0.05, function() SubTabs["World"].CanvasSize = UDim2.new(0, 0, 0, wLayout.AbsoluteContentSize.Y + 20) end)
	end

	local lastKnownPart = player:GetAttribute("CurrentPart") or 1
	player.AttributeChanged:Connect(function(attr)
		if attr == "CurrentPart" then
			local newPart = player:GetAttribute("CurrentPart") or 1
			lastKnownPart = newPart
			UpdateLocks()
		elseif attr == "PathsFloor" or attr == "PathDust" then UpdateLocks() end
	end)

	task.spawn(function()
		local pObj = player:WaitForChild("leaderstats", 10) and player.leaderstats:WaitForChild("Prestige", 10)
		if pObj then pObj.Changed:Connect(UpdateLocks) end
		UpdateLocks()
		TweenService:Create(SubBtns["Campaign"], TweenInfo.new(0), {BackgroundColor3 = Color3.fromRGB(120, 100, 60), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)

	Network:WaitForChild("CombatUpdate").OnClientEvent:Connect(function(action, data)
		if (action == "Defeat" or action == "Fled") and data.Battle and data.Battle.Context.IsPaths then
			for k, frame in pairs(SubTabs) do frame.Visible = (k == "Paths") end
			for k, v in pairs(SubBtns) do TweenService:Create(v, TweenInfo.new(0), {BackgroundColor3 = Color3.fromRGB(30, 30, 35), TextColor3 = Color3.fromRGB(200, 200, 200)}):Play() end
			TweenService:Create(SubBtns["Paths"], TweenInfo.new(0), {BackgroundColor3 = Color3.fromRGB(120, 100, 60), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			pShopPanel.Visible = true
		end
	end)
end

function BattleTab.Show() if MainFrame then MainFrame.Visible = true end end

return BattleTab