-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local RegimentTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")

local player = Players.LocalPlayer
local MainFrame, ContentPanel, LockedPanel
local GarrisonCol, ScoutsCol, MPCol
local DominantLabel

local FactionColors = { ["Garrison"] = Color3.fromRGB(160, 60, 60), ["Military Police"] = Color3.fromRGB(60, 140, 60), ["Scout Regiment"] = Color3.fromRGB(60, 80, 160) }
local RegimentIcons = { ["Garrison"] = "rbxassetid://133062844", ["Military Police"] = "rbxassetid://132793466", ["Scout Regiment"] = "rbxassetid://132793532" }

function RegimentTab.Init(parentFrame)
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "RegimentFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false
	MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 215, 100); Title.TextSize = 20; Title.Text = "REGIMENT WARS"

	local mainLayout = Instance.new("UIListLayout", MainFrame); mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.Padding = UDim.new(0, 15)
	local mainPad = Instance.new("UIPadding", MainFrame); mainPad.PaddingTop = UDim.new(0, 10); mainPad.PaddingBottom = UDim.new(0, 30)
	Title.LayoutOrder = 1

	LockedPanel = Instance.new("Frame", MainFrame)
	LockedPanel.Size = UDim2.new(1, 0, 0, 200); LockedPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); LockedPanel.LayoutOrder = 2
	Instance.new("UICorner", LockedPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", LockedPanel).Color = Color3.fromRGB(80, 40, 40)
	local lockTxt = Instance.new("TextLabel", LockedPanel); lockTxt.Size = UDim2.new(0.9, 0, 1, 0); lockTxt.Position = UDim2.new(0.05, 0, 0, 0); lockTxt.BackgroundTransparency = 1; lockTxt.Font = Enum.Font.GothamMedium; lockTxt.TextColor3 = Color3.fromRGB(200, 200, 200); lockTxt.TextSize = 14; lockTxt.TextWrapped = true; lockTxt.Text = "Complete '104th Cadet Corps Training' (Campaign Part 2) to pledge to a Regiment."

	ContentPanel = Instance.new("Frame", MainFrame)
	ContentPanel.Size = UDim2.new(1, 0, 0, 0); ContentPanel.AutomaticSize = Enum.AutomaticSize.Y; ContentPanel.BackgroundTransparency = 1; ContentPanel.LayoutOrder = 3

	local ContentLayout = Instance.new("UIListLayout", ContentPanel); ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder; ContentLayout.Padding = UDim.new(0, 15)

	DominantLabel = Instance.new("TextLabel", ContentPanel)
	DominantLabel.Size = UDim2.new(1, 0, 0, 40); DominantLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 30); DominantLabel.Font = Enum.Font.GothamBlack; DominantLabel.TextColor3 = Color3.fromRGB(255, 255, 255); DominantLabel.TextSize = 16; DominantLabel.Text = "AWAITING INTEL..."; DominantLabel.LayoutOrder = 1
	Instance.new("UICorner", DominantLabel).CornerRadius = UDim.new(0, 6)

	local CardsContainer = Instance.new("Frame", ContentPanel)
	CardsContainer.Size = UDim2.new(1, 0, 0, 0); CardsContainer.AutomaticSize = Enum.AutomaticSize.Y; CardsContainer.BackgroundTransparency = 1; CardsContainer.LayoutOrder = 2
	local cLayout = Instance.new("UIListLayout", CardsContainer); cLayout.FillDirection = Enum.FillDirection.Vertical; cLayout.Padding = UDim.new(0, 15)

	local function CreateMobileCard(name, color, imageId, subtext)
		local col = Instance.new("Frame", CardsContainer)
		col.Size = UDim2.new(1, 0, 0, 100); col.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
		Instance.new("UICorner", col).CornerRadius = UDim.new(0, 8); local stroke = Instance.new("UIStroke", col); stroke.Color = color; stroke.Thickness = 2

		local logo = Instance.new("ImageLabel", col)
		logo.Size = UDim2.new(0, 80, 0, 80); logo.Position = UDim2.new(0, 10, 0.5, 0); logo.AnchorPoint = Vector2.new(0, 0.5); logo.BackgroundTransparency = 1; logo.Image = imageId; logo.ScaleType = Enum.ScaleType.Fit; logo.ImageTransparency = 0.8; logo.ImageColor3 = color

		local title = Instance.new("TextLabel", col)
		title.Size = UDim2.new(0.6, 0, 0, 20); title.Position = UDim2.new(0, 100, 0, 10); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextColor3 = color; title.TextSize = 16; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = string.upper(name)

		local vpLbl = Instance.new("TextLabel", col)
		vpLbl.Size = UDim2.new(0.6, 0, 0, 30); vpLbl.Position = UDim2.new(0, 100, 0, 30); vpLbl.BackgroundTransparency = 1; vpLbl.Font = Enum.Font.GothamBlack; vpLbl.TextColor3 = Color3.fromRGB(255, 255, 255); vpLbl.TextSize = 20; vpLbl.TextXAlignment = Enum.TextXAlignment.Left; vpLbl.Text = "0 VP"

		local barBg = Instance.new("Frame", col)
		barBg.Size = UDim2.new(0.6, 0, 0, 10); barBg.Position = UDim2.new(0, 100, 1, -25); barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35); Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 6)
		local fill = Instance.new("Frame", barBg); fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = color; Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

		return fill, vpLbl
	end

	local gFill, gVp = CreateMobileCard("Garrison", FactionColors["Garrison"], RegimentIcons["Garrison"], "THE STATIONED CORPS")
	local mFill, mVp = CreateMobileCard("Military Police", FactionColors["Military Police"], RegimentIcons["Military Police"], "THE KING'S GUARD")
	local sFill, sVp = CreateMobileCard("Scout Regiment", FactionColors["Scout Regiment"], RegimentIcons["Scout Regiment"], "THE WINGS OF FREEDOM")
	GarrisonCol = {Fill = gFill, Vp = gVp}; MPCol = {Fill = mFill, Vp = mVp}; ScoutsCol = {Fill = sFill, Vp = sVp}

	local BtnContainer = Instance.new("Frame", ContentPanel)
	BtnContainer.Size = UDim2.new(1, 0, 0, 0); BtnContainer.AutomaticSize = Enum.AutomaticSize.Y; BtnContainer.BackgroundTransparency = 1; BtnContainer.LayoutOrder = 3
	local btnLayout = Instance.new("UIListLayout", BtnContainer); btnLayout.FillDirection = Enum.FillDirection.Vertical; btnLayout.Padding = UDim.new(0, 10)

	local function CreateJoinBtn(name, color)
		local btn = Instance.new("TextButton", BtnContainer)
		btn.Size = UDim2.new(1, 0, 0, 45); btn.BackgroundColor3 = color; btn.Font = Enum.Font.GothamBlack; btn.TextColor3 = Color3.new(1,1,1); btn.TextSize = 14; btn.Text = "JOIN " .. string.upper(name)
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		btn.MouseButton1Click:Connect(function() Network:WaitForChild("JoinRegiment"):FireServer(name) end)
	end

	CreateJoinBtn("Garrison", FactionColors["Garrison"])
	CreateJoinBtn("Military Police", FactionColors["Military Police"])
	CreateJoinBtn("Scout Regiment", FactionColors["Scout Regiment"])

	local function UpdateLocks()
		local part = player:GetAttribute("CurrentPart") or 1
		local prestige = (player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige")) and player.leaderstats.Prestige.Value or 0
		if part > 2 or prestige > 0 then LockedPanel.Visible = false; ContentPanel.Visible = true else LockedPanel.Visible = true; ContentPanel.Visible = false end
	end
	player.AttributeChanged:Connect(function(attr) if attr == "CurrentPart" then UpdateLocks() end end)
	UpdateLocks()

	task.spawn(function()
		while true do
			task.wait(5)
			if MainFrame.Visible and ContentPanel.Visible then
				pcall(function()
					local vpData = Network:WaitForChild("GetRegimentVP"):InvokeServer()
					local total = math.max(1, vpData["Garrison"] + vpData["Scout Regiment"] + vpData["Military Police"])

					local highest = 0; local dom = "NO CLEAR LEADER"
					for reg, vp in pairs(vpData) do if reg ~= "Week" and reg ~= "Winner" and vp > highest then highest = vp; dom = string.upper(reg) .. " DOMINATING!" end end
					DominantLabel.Text = dom

					TweenService:Create(GarrisonCol.Fill, TweenInfo.new(1), {Size = UDim2.new(vpData["Garrison"] / total, 0, 1, 0)}):Play(); GarrisonCol.Vp.Text = vpData["Garrison"] .. " VP"
					TweenService:Create(MPCol.Fill, TweenInfo.new(1), {Size = UDim2.new(vpData["Military Police"] / total, 0, 1, 0)}):Play(); MPCol.Vp.Text = vpData["Military Police"] .. " VP"
					TweenService:Create(ScoutsCol.Fill, TweenInfo.new(1), {Size = UDim2.new(vpData["Scout Regiment"] / total, 0, 1, 0)}):Play(); ScoutsCol.Vp.Text = vpData["Scout Regiment"] .. " VP"
				end)
			end
		end
	end)
end

function RegimentTab.Show() if MainFrame then MainFrame.Visible = true end end

return RegimentTab