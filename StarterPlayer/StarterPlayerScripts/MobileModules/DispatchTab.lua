-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local DispatchTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Network = ReplicatedStorage:WaitForChild("Network")

local player = Players.LocalPlayer
local MainFrame, RosterList, RosterTitle, MapPanel, StatusOverlay, TotalDewsLbl, TotalXPLbl

local Allies = {
	{Name = "Armin Arlert", ReqPart = 1, Cost = 1000, Color = Color3.fromRGB(255, 215, 100), Icon = "rbxassetid://99009166931575"},
	{Name = "Sasha Braus", ReqPart = 2, Cost = 2500, Color = Color3.fromRGB(180, 100, 80), Icon = "rbxassetid://74069077964164"},
	{Name = "Connie Springer", ReqPart = 2, Cost = 2500, Color = Color3.fromRGB(150, 150, 150), Icon = "rbxassetid://80661189472482"},
	{Name = "Jean Kirstein", ReqPart = 3, Cost = 5000, Color = Color3.fromRGB(120, 100, 80), Icon = "rbxassetid://107359332104986"},
	{Name = "Hange Zoe", ReqPart = 5, Cost = 10000, Color = Color3.fromRGB(180, 80, 180), Icon = "rbxassetid://71066662959593"},
	{Name = "Erwin Smith", ReqPart = 6, Cost = 20000, Color = Color3.fromRGB(220, 180, 50), Icon = "rbxassetid://116122082480103"},
	{Name = "Mikasa Ackerman", ReqPart = 7, Cost = 50000, Color = Color3.fromRGB(200, 50, 50), Icon = "rbxassetid://113777388050871"},
	{Name = "Levi Ackerman", ReqPart = 8, Cost = 100000, Color = Color3.fromRGB(100, 150, 255), Icon = "rbxassetid://120198409378661"}
}

local LootNodes = { UDim2.new(0.5, 0, 0.45, 0), UDim2.new(0.45, 0, 0.55, 0), UDim2.new(0.35, 0, 0.45, 0), UDim2.new(0.65, 0, 0.65, 0), UDim2.new(0.6, 0, 0.4, 0), UDim2.new(0.2, 0, 0.4, 0), UDim2.new(0.8, 0, 0.8, 0), UDim2.new(0.2, 0, 0.8, 0), UDim2.new(0.1, 0, 0.6, 0), UDim2.new(0.9, 0, 0.5, 0), UDim2.new(0.5, 0, 0.9, 0) }

local activeAvatars = {}
local function GetDispatchData() local r = player:GetAttribute("DispatchData") if not r or r=="" then return {} end local s, d = pcall(function() return HttpService:JSONDecode(r) end) return s and d or {} end
local function GetAllyLevels() local r = player:GetAttribute("AllyLevels") if not r or r=="" then return {} end local s, d = pcall(function() return HttpService:JSONDecode(r) end) return s and d or {} end

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}; grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 4)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn)
		stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.LineJoinMode = Enum.LineJoinMode.Miter
	end
	if not btn:GetAttribute("GradientTextFixed") then
		btn:SetAttribute("GradientTextFixed", true)
		local textLbl = Instance.new("TextLabel", btn); textLbl.Name = "BtnTextLabel"; textLbl.Size = UDim2.new(1, 0, 1, 0); textLbl.BackgroundTransparency = 1
		textLbl.Font = btn.Font; textLbl.TextSize = btn.TextSize; textLbl.TextScaled = btn.TextScaled; textLbl.RichText = btn.RichText; textLbl.TextWrapped = btn.TextWrapped
		textLbl.TextXAlignment = btn.TextXAlignment; textLbl.TextYAlignment = btn.TextYAlignment; textLbl.ZIndex = btn.ZIndex + 1
		local tConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint"); if tConstraint then tConstraint.Parent = textLbl end
		btn.ChildAdded:Connect(function(child) if child:IsA("UITextSizeConstraint") then task.delay(0, function() child.Parent = textLbl end) end end)
		textLbl.Text = btn.Text; textLbl.TextColor3 = btn.TextColor3; btn.Text = ""
		btn:GetPropertyChangedSignal("Text"):Connect(function() if btn.Text ~= "" then textLbl.Text = btn.Text; btn.Text = "" end end)
		btn:GetPropertyChangedSignal("TextColor3"):Connect(function() textLbl.TextColor3 = btn.TextColor3 end)
	end
end

function DispatchTab.Init(parentFrame)
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "DispatchFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false
	MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local mainLayout = Instance.new("UIListLayout", MainFrame)
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; mainLayout.Padding = UDim.new(0, 15)
	local mainPad = Instance.new("UIPadding", MainFrame); mainPad.PaddingTop = UDim.new(0, 15); mainPad.PaddingBottom = UDim.new(0, 40)

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 45); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 255, 255); Title.TextSize = 24; Title.Text = "EXPEDITIONS (AFK)"
	Title.LayoutOrder = 1
	ApplyGradient(Title, Color3.fromRGB(150, 255, 150), Color3.fromRGB(50, 150, 50))

	-- [[ THE FIX: Flawless Native Square Map ]]
	MapPanel = Instance.new("Frame", MainFrame)
	MapPanel.Size = UDim2.new(0.95, 0, 0.95, 0) -- By using RelativeXX, the Y scale (0.95) pulls from the X Width!
	MapPanel.SizeConstraint = Enum.SizeConstraint.RelativeXX -- Forces perfect square natively
	MapPanel.BackgroundColor3 = Color3.fromRGB(15, 18, 22); MapPanel.ClipsDescendants = true; MapPanel.LayoutOrder = 2
	Instance.new("UICorner", MapPanel).CornerRadius = UDim.new(0, 10)
	Instance.new("UIStroke", MapPanel).Color = Color3.fromRGB(80, 80, 90); MapPanel.UIStroke.Thickness = 2

	local MapGraphics = Instance.new("Frame", MapPanel); MapGraphics.Size = UDim2.new(1, 0, 1, 0); MapGraphics.BackgroundTransparency = 1; MapGraphics.ZIndex = 1

	-- Large Grid
	for i = 1, 9 do
		local vLine = Instance.new("Frame", MapGraphics); vLine.Size = UDim2.new(0, 1, 1, 0); vLine.Position = UDim2.new(i/10, 0, 0, 0); vLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255); vLine.BackgroundTransparency = 0.94; vLine.BorderSizePixel = 0
		local hLine = Instance.new("Frame", MapGraphics); hLine.Size = UDim2.new(1, 0, 0, 1); hLine.Position = UDim2.new(0, 0, i/10, 0); hLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255); hLine.BackgroundTransparency = 0.94; hLine.BorderSizePixel = 0
	end

	local function DrawWall(name, scale, color, thick)
		local w = Instance.new("Frame", MapGraphics); w.Size = UDim2.new(scale, 0, scale, 0); w.Position = UDim2.new(0.5, 0, 0.5, 0); w.AnchorPoint = Vector2.new(0.5, 0.5); w.BackgroundTransparency = 1; Instance.new("UICorner", w).CornerRadius = UDim.new(1, 0); local stroke = Instance.new("UIStroke", w); stroke.Color = color; stroke.Thickness = thick; stroke.Transparency = 0.5; local aspect = Instance.new("UIAspectRatioConstraint", w); aspect.AspectRatio = 1
		local lbl = Instance.new("TextLabel", w); lbl.Size = UDim2.new(1, 0, 0, 15); lbl.Position = UDim2.new(0, 0, 0, -20); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBlack; lbl.TextColor3 = color; lbl.TextTransparency = 0.3; lbl.TextSize = 12; lbl.Text = name
	end

	local capital = Instance.new("Frame", MapGraphics); capital.Size = UDim2.new(0, 14, 0, 14); capital.Position = UDim2.new(0.5, 0, 0.5, 0); capital.AnchorPoint = Vector2.new(0.5, 0.5); capital.BackgroundColor3 = Color3.fromRGB(200, 200, 255); capital.BackgroundTransparency = 0.3; Instance.new("UICorner", capital).CornerRadius = UDim.new(1, 0)
	DrawWall("WALL SINA", 0.35, Color3.fromRGB(150, 180, 255), 3); DrawWall("WALL ROSE", 0.65, Color3.fromRGB(200, 150, 150), 3); DrawWall("WALL MARIA", 0.95, Color3.fromRGB(255, 100, 100), 4)

	-- Decorations (Trees)
	for i = 1, 20 do
		local tree = Instance.new("Frame", MapGraphics); local s = math.random(15, 30); tree.Size = UDim2.new(0, s, 0, s)
		local angle = math.random() * math.pi * 2; local dist = 0.4 + (math.random() * 0.45) 
		tree.Position = UDim2.new(0.5 + math.cos(angle)*dist, 0, 0.5 + math.sin(angle)*dist, 0); tree.AnchorPoint = Vector2.new(0.5, 0.5); tree.BackgroundColor3 = Color3.fromRGB(30, 60, 40); tree.BackgroundTransparency = 0.6; Instance.new("UICorner", tree).CornerRadius = UDim.new(1, 0); tree.ZIndex = 0
	end

	-- Nodes
	for _, pos in ipairs(LootNodes) do
		local node = Instance.new("Frame", MapGraphics); node.Size = UDim2.new(0, 12, 0, 12); node.Position = pos; node.AnchorPoint = Vector2.new(0.5, 0.5); node.BackgroundColor3 = Color3.fromRGB(255, 215, 100); node.BackgroundTransparency = 0.1; node.ZIndex = 2; Instance.new("UICorner", node).CornerRadius = UDim.new(1, 0); local glow = Instance.new("UIStroke", node); glow.Color = Color3.fromRGB(255, 215, 100); glow.Thickness = 3; glow.Transparency = 0.5
	end

	local TopDashboard = Instance.new("Frame", MapPanel)
	TopDashboard.Size = UDim2.new(1, 0, 0, 45); TopDashboard.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TopDashboard.BackgroundTransparency = 0.1; TopDashboard.ZIndex = 20
	Instance.new("UIStroke", TopDashboard).Color = Color3.fromRGB(120, 100, 50); TopDashboard.UIStroke.Thickness = 1.5

	TotalDewsLbl = Instance.new("TextLabel", TopDashboard); TotalDewsLbl.Size = UDim2.new(0.3, 0, 1, 0); TotalDewsLbl.Position = UDim2.new(0.05, 0, 0, 0); TotalDewsLbl.BackgroundTransparency = 1; TotalDewsLbl.Font = Enum.Font.GothamBold; TotalDewsLbl.TextColor3 = Color3.fromRGB(150, 220, 255); TotalDewsLbl.TextSize = 13; TotalDewsLbl.TextXAlignment = Enum.TextXAlignment.Left; TotalDewsLbl.Text = "0 DEWS"
	TotalXPLbl = Instance.new("TextLabel", TopDashboard); TotalXPLbl.Size = UDim2.new(0.3, 0, 1, 0); TotalXPLbl.Position = UDim2.new(0.4, 0, 0, 0); TotalXPLbl.BackgroundTransparency = 1; TotalXPLbl.Font = Enum.Font.GothamBold; TotalXPLbl.TextColor3 = Color3.fromRGB(100, 255, 100); TotalXPLbl.TextSize = 13; TotalXPLbl.TextXAlignment = Enum.TextXAlignment.Left; TotalXPLbl.Text = "0 XP"

	local RecallAllBtn = Instance.new("TextButton", TopDashboard)
	RecallAllBtn.Size = UDim2.new(0, 110, 0, 34); RecallAllBtn.AnchorPoint = Vector2.new(1, 0.5); RecallAllBtn.Position = UDim2.new(0.98, 0, 0.5, 0); RecallAllBtn.Font = Enum.Font.GothamBlack; RecallAllBtn.TextSize = 10; RecallAllBtn.Text = "RECALL ALL"; RecallAllBtn.ZIndex = 21
	ApplyButtonGradient(RecallAllBtn, Color3.fromRGB(180, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(60, 20, 20)); RecallAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	RecallAllBtn.MouseButton1Click:Connect(function() local dData = GetDispatchData(); for name, _ in pairs(dData) do Network:WaitForChild("DispatchAction"):FireServer("Recall", name) end end)

	StatusOverlay = Instance.new("Frame", MapPanel)
	StatusOverlay.Size = UDim2.new(0.8, 0, 0, 110); StatusOverlay.Position = UDim2.new(0.5, 0, 0.5, 0); StatusOverlay.AnchorPoint = Vector2.new(0.5, 0.5); StatusOverlay.BackgroundColor3 = Color3.fromRGB(15, 15, 18); StatusOverlay.Visible = false; StatusOverlay.ZIndex = 35; Instance.new("UICorner", StatusOverlay).CornerRadius = UDim.new(0, 10); Instance.new("UIStroke", StatusOverlay).Color = Color3.fromRGB(200, 200, 200); StatusOverlay.UIStroke.Thickness = 2
	local sName = Instance.new("TextLabel", StatusOverlay); sName.Size = UDim2.new(1, 0, 0, 30); sName.BackgroundTransparency = 1; sName.Font = Enum.Font.GothamBlack; sName.TextColor3 = Color3.fromRGB(255, 255, 255); sName.TextSize = 15; sName.Text = "ALLY NAME"; sName.ZIndex = 36
	local sLoot = Instance.new("TextLabel", StatusOverlay); sLoot.Size = UDim2.new(1, 0, 0, 25); sLoot.Position = UDim2.new(0, 0, 0, 30); sLoot.BackgroundTransparency = 1; sLoot.Font = Enum.Font.GothamBold; sLoot.TextColor3 = Color3.fromRGB(255, 215, 100); sLoot.TextSize = 13; sLoot.Text = "Loot: 0 Dews | 0 XP"; sLoot.ZIndex = 36
	local sRecallBtn = Instance.new("TextButton", StatusOverlay); sRecallBtn.Size = UDim2.new(0.8, 0, 0, 38); sRecallBtn.Position = UDim2.new(0.1, 0, 1, -45); sRecallBtn.Font = Enum.Font.GothamBlack; sRecallBtn.TextSize = 12; sRecallBtn.Text = "RECALL & CLAIM"; sRecallBtn.ZIndex = 36
	ApplyButtonGradient(sRecallBtn, Color3.fromRGB(180, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(60, 20, 20)); sRecallBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

	local selectedAlly = nil
	sRecallBtn.MouseButton1Click:Connect(function() if selectedAlly then Network:WaitForChild("DispatchAction"):FireServer("Recall", selectedAlly); StatusOverlay.Visible = false end end)

	-- [[ ROSTER PANEL ]]
	local RosterPanel = Instance.new("Frame", MainFrame)
	RosterPanel.Size = UDim2.new(0.95, 0, 0, 0); RosterPanel.AutomaticSize = Enum.AutomaticSize.Y; RosterPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); RosterPanel.LayoutOrder = 3
	Instance.new("UICorner", RosterPanel).CornerRadius = UDim.new(0, 10); Instance.new("UIStroke", RosterPanel).Color = Color3.fromRGB(80, 80, 90)

	local rpLayout = Instance.new("UIListLayout", RosterPanel); rpLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local HeaderArea = Instance.new("Frame", RosterPanel); HeaderArea.Size = UDim2.new(1, 0, 0, 45); HeaderArea.BackgroundTransparency = 1; HeaderArea.LayoutOrder = 1
	RosterTitle = Instance.new("TextLabel", HeaderArea); RosterTitle.Size = UDim2.new(0.7, 0, 1, 0); RosterTitle.Position = UDim2.new(0.05, 0, 0, 0); RosterTitle.BackgroundTransparency = 1; RosterTitle.Font = Enum.Font.GothamBlack; RosterTitle.TextColor3 = Color3.fromRGB(255, 255, 255); RosterTitle.TextSize = 16; RosterTitle.TextXAlignment = Enum.TextXAlignment.Left; RosterTitle.Text = "ALLY ROSTER"

	local AddSlotBtn = Instance.new("TextButton", HeaderArea); AddSlotBtn.Size = UDim2.new(0, 34, 0, 34); AddSlotBtn.AnchorPoint = Vector2.new(1, 0.5); AddSlotBtn.Position = UDim2.new(0.95, 0, 0.5, 0); AddSlotBtn.Font = Enum.Font.GothamBlack; AddSlotBtn.TextSize = 20; AddSlotBtn.Text = "+"
	ApplyButtonGradient(AddSlotBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20)); AddSlotBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	AddSlotBtn.MouseButton1Click:Connect(function()
		local max = player:GetAttribute("MaxDeployments") or 2; if max >= 8 then return end
		if player.leaderstats and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value >= 100000 then Network:WaitForChild("DispatchAction"):FireServer("UpgradeCapacity") else game:GetService("MarketplaceService"):PromptProductPurchase(player, 0) end
	end)

	RosterList = Instance.new("Frame", RosterPanel)
	RosterList.Size = UDim2.new(1, 0, 0, 0); RosterList.AutomaticSize = Enum.AutomaticSize.Y; RosterList.BackgroundTransparency = 1; RosterList.LayoutOrder = 2
	local rlLayout = Instance.new("UIListLayout", RosterList); rlLayout.Padding = UDim.new(0, 10); rlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local rlPad = Instance.new("UIPadding", RosterList); rlPad.PaddingBottom = UDim.new(0, 20)

	local function RenderRoster()
		for _, child in ipairs(RosterList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		local dData = GetDispatchData(); local allyLevels = GetAllyLevels(); local curPart = player:GetAttribute("CurrentPart") or 1; local maxDeployments = player:GetAttribute("MaxDeployments") or 2; local unlockedStr = player:GetAttribute("UnlockedAllies") or ""
		local activeCount = 0; for _, _ in pairs(dData) do activeCount += 1 end; RosterTitle.Text = "ROSTER (" .. activeCount .. "/" .. maxDeployments .. ")"

		for _, ally in ipairs(Allies) do
			local isUnlocked = string.find(unlockedStr, "%[" .. ally.Name .. "%]") ~= nil

			local row = Instance.new("Frame", RosterList); row.Size = UDim2.new(0.94, 0, 0, 90); row.BackgroundColor3 = Color3.fromRGB(22, 22, 28); Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
			local stroke = Instance.new("UIStroke", row); stroke.Color = ally.Color; stroke.Thickness = 1.5; stroke.Transparency = 0.5; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local accent = Instance.new("Frame", row); accent.Size = UDim2.new(0, 5, 1, 0); accent.BackgroundColor3 = ally.Color; accent.BorderSizePixel = 0; Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 4)

			local lvl = allyLevels[ally.Name] or 1; local lvlMult = 1 + ((lvl - 1) * 0.20)

			local nLbl = Instance.new("TextLabel", row); nLbl.Size = UDim2.new(0.6, 0, 0, 22); nLbl.Position = UDim2.new(0, 18, 0, 12); nLbl.BackgroundTransparency = 1; nLbl.Font = Enum.Font.GothamBold; nLbl.TextColor3 = ally.Color; nLbl.TextSize = 15; nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.Text = ally.Name
			local lvlLbl = Instance.new("TextLabel", row); lvlLbl.Size = UDim2.new(0.3, 0, 0, 22); lvlLbl.AnchorPoint = Vector2.new(1, 0); lvlLbl.Position = UDim2.new(1, -12, 0, 12); lvlLbl.BackgroundTransparency = 1; lvlLbl.Font = Enum.Font.GothamBlack; lvlLbl.TextColor3 = Color3.fromRGB(255, 215, 100); lvlLbl.TextSize = 13; lvlLbl.TextXAlignment = Enum.TextXAlignment.Right; lvlLbl.Text = "Lvl " .. lvl .. " (".. math.floor(lvlMult*100) .."%)"; if not isUnlocked then lvlLbl.Visible = false end
			local sLbl = Instance.new("TextLabel", row); sLbl.Size = UDim2.new(1, -30, 0, 18); sLbl.Position = UDim2.new(0, 18, 0, 34); sLbl.BackgroundTransparency = 1; sLbl.Font = Enum.Font.GothamMedium; sLbl.TextColor3 = Color3.fromRGB(160, 160, 160); sLbl.TextSize = 12; sLbl.TextXAlignment = Enum.TextXAlignment.Left

			local btn = Instance.new("TextButton", row); btn.Size = UDim2.new(0.44, 0, 0, 32); btn.Position = UDim2.new(0, 18, 1, -38); btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
			local upgBtn = Instance.new("TextButton", row); upgBtn.Size = UDim2.new(0.44, 0, 0, 32); upgBtn.AnchorPoint = Vector2.new(1, 0); upgBtn.Position = UDim2.new(1, -12, 1, -38); upgBtn.Font = Enum.Font.GothamBold; upgBtn.TextSize = 12; upgBtn.Visible = false

			if not isUnlocked then
				if curPart < ally.ReqPart then 
					sLbl.Text = "Requirement: Part " .. ally.ReqPart; btn.Text = "LOCKED"
					ApplyButtonGradient(btn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(70, 70, 80)); btn.TextColor3 = Color3.fromRGB(130, 130, 130)
				else 
					sLbl.Text = "Ready for Hire!"; btn.Text = "UNLOCK (" .. (ally.Cost or 0) .. ")"
					ApplyButtonGradient(btn, Color3.fromRGB(200, 150, 50), Color3.fromRGB(120, 80, 20), Color3.fromRGB(255, 215, 100)); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					btn.MouseButton1Click:Connect(function() Network:WaitForChild("DispatchAction"):FireServer("UnlockAlly", ally.Name) end) 
				end
			else
				upgBtn.Visible = true
				if lvl >= 10 then 
					upgBtn.Text = "MAX LVL"
					ApplyButtonGradient(upgBtn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(60, 60, 70)); upgBtn.TextColor3 = Color3.fromRGB(140, 140, 140)
				else 
					upgBtn.Text = "UPGRADE (" .. (lvl * 5000) .. ")"
					ApplyButtonGradient(upgBtn, Color3.fromRGB(200, 150, 50), Color3.fromRGB(120, 80, 20), Color3.fromRGB(255, 215, 100)); upgBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
					upgBtn.MouseButton1Click:Connect(function() Network:WaitForChild("DispatchAction"):FireServer("UpgradeAlly", ally.Name) end) 
				end

				if dData[ally.Name] then 
					local startTime = dData[ally.Name].StartTime or os.time()
					local mins = math.floor((os.time() - startTime) / 60)
					sLbl.Text = "Exploring... (" .. mins .. " mins)"
					btn.Text = "RECALL"
					ApplyButtonGradient(btn, Color3.fromRGB(160, 50, 50), Color3.fromRGB(80, 20, 20), Color3.fromRGB(200, 80, 80)); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					btn.MouseButton1Click:Connect(function() Network:WaitForChild("DispatchAction"):FireServer("Recall", ally.Name) end)
				else 
					sLbl.Text = "Status: Idle"
					btn.Text = "DEPLOY"
					ApplyButtonGradient(btn, Color3.fromRGB(50, 100, 160), Color3.fromRGB(20, 50, 100), Color3.fromRGB(80, 150, 220)); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					btn.MouseButton1Click:Connect(function() Network:WaitForChild("DispatchAction"):FireServer("Deploy", ally.Name) end) 
				end
			end
		end

		task.delay(0.05, function() MainFrame.CanvasSize = UDim2.new(0, 0, 0, mainLayout.AbsoluteContentSize.Y + 60) end)
	end

	local function SyncAvatars()
		local dData = GetDispatchData(); local allyLevels = GetAllyLevels()
		local usedNodes = {}
		for name, card in pairs(activeAvatars) do if not dData[name] then card:Destroy(); activeAvatars[name] = nil else local idx = card:GetAttribute("NodeIndex"); if idx then usedNodes[idx] = true end end end

		for name, info in pairs(dData) do
			local charColor = Color3.new(1,1,1); local allyIcon = ""; local isValid = false
			for _, a in ipairs(Allies) do if a.Name == name then charColor = a.Color; allyIcon = a.Icon; isValid = true; break end end
			if not isValid then continue end

			if not activeAvatars[name] then
				local availableNodes = {}
				for i = 1, #LootNodes do if not usedNodes[i] then table.insert(availableNodes, i) end end
				local chosenIdx = #availableNodes > 0 and availableNodes[math.random(1, #availableNodes)] or math.random(1, #LootNodes)
				local targetNode = LootNodes[chosenIdx]; usedNodes[chosenIdx] = true

				local card = Instance.new("TextButton", MapGraphics)
				card.Size = UDim2.new(0, 44, 0, 44); -- Super Enlarged Avatar
				card.Position = UDim2.new(0.5, 0, 1.1, 0); card.AnchorPoint = Vector2.new(0.5, 0.5); card.BackgroundColor3 = Color3.fromRGB(22, 22, 28); card.Text = ""; card.ZIndex = 5
				Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8); local stroke = Instance.new("UIStroke", card); stroke.Color = charColor; stroke.Thickness = 2.5; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; card:SetAttribute("NodeIndex", chosenIdx)

				local img = Instance.new("ImageLabel", card); img.Size = UDim2.new(1, -4, 1, -4); img.Position = UDim2.new(0, 2, 0, 2); img.BackgroundTransparency = 1; img.Image = allyIcon; img.ScaleType = Enum.ScaleType.Fit; img.ZIndex = 6; Instance.new("UICorner", img).CornerRadius = UDim.new(0, 6)

				task.spawn(function()
					local walkTween = TweenService:Create(card, TweenInfo.new(3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = targetNode}); walkTween:Play(); walkTween.Completed:Wait()
					if card.Parent then local bobTween = TweenService:Create(card, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = UDim2.new(targetNode.X.Scale, 0, targetNode.Y.Scale - 0.03, 0)}); bobTween:Play() end
				end)

				card.MouseButton1Click:Connect(function()
					selectedAlly = name; sName.Text = name:upper()
					local startTime = info.StartTime or os.time()
					local mins = math.floor((os.time() - startTime) / 60)
					local lvl = allyLevels[name] or 1; local lvlMult = 1 + ((lvl - 1) * 0.20)
					sLoot.Text = "Loot: " .. math.floor((mins * 12) * lvlMult) .. " Dews | " .. math.floor((mins * 5) * lvlMult) .. " XP"
					StatusOverlay.Visible = true
				end)

				activeAvatars[name] = card
			end
		end
	end

	player.AttributeChanged:Connect(function(attr) if attr == "DispatchData" or attr == "AllyLevels" or attr == "MaxDeployments" or attr == "UnlockedAllies" then RenderRoster(); SyncAvatars() end end)

	task.spawn(function()
		while true do
			task.wait(2)
			if MainFrame.Visible then
				RenderRoster(); local dData = GetDispatchData(); local allyLevels = GetAllyLevels(); local tDews, tXp = 0, 0
				for name, info in pairs(dData) do
					local isValid = false; for _, a in ipairs(Allies) do if a.Name == name then isValid = true; break end end; if not isValid then continue end
					local startTime = info.StartTime or os.time()
					local mins = math.floor((os.time() - startTime) / 60)
					local lvl = allyLevels[name] or 1; local lvlMult = 1 + ((lvl - 1) * 0.20)
					tDews += math.floor((mins * 12) * lvlMult); tXp += math.floor((mins * 5) * lvlMult)
				end
				TotalDewsLbl.Text = tDews .. " DEWS"; TotalXPLbl.Text = tXp .. " XP"

				if StatusOverlay.Visible and selectedAlly then
					if dData[selectedAlly] then
						local startTime = dData[selectedAlly].StartTime or os.time()
						local mins = math.floor((os.time() - startTime) / 60)
						local lvl = allyLevels[selectedAlly] or 1; local lvlMult = 1 + ((lvl - 1) * 0.20)
						sLoot.Text = "Loot: " .. math.floor((mins * 12) * lvlMult) .. " Dews | " .. math.floor((mins * 5) * lvlMult) .. " XP"
					else StatusOverlay.Visible = false end
				end
			end
		end
	end)
	RenderRoster(); SyncAvatars()
end

function DispatchTab.Show() if MainFrame then MainFrame.Visible = true end end

return DispatchTab