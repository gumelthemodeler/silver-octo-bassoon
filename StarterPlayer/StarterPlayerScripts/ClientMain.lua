-- @ScriptType: LocalScript
-- @ScriptType: LocalScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function() 
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) 
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
end)

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local AOT_Interface = Instance.new("ScreenGui")
AOT_Interface.Name = "AOT_Interface"
AOT_Interface.ResetOnSpawn = false
AOT_Interface.IgnoreGuiInset = true
AOT_Interface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
AOT_Interface.Parent = playerGui

local WorldBlocker = Instance.new("Frame")
WorldBlocker.Size = UDim2.new(1, 0, 1, 0); WorldBlocker.BackgroundColor3 = Color3.fromRGB(10, 10, 12); WorldBlocker.BorderSizePixel = 0; WorldBlocker.ZIndex = -10; WorldBlocker.Parent = AOT_Interface

local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}; grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 4)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn)
		stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
		btn:GetPropertyChangedSignal("RichText"):Connect(function() textLbl.RichText = btn.RichText end)
	end
end

local function TweenGradient(grad, targetTop, targetBot, duration)
	local startTop = grad.Color.Keypoints[1].Value
	local startBot = grad.Color.Keypoints[#grad.Color.Keypoints].Value
	local val = Instance.new("NumberValue"); val.Value = 0
	local tween = TweenService:Create(val, TweenInfo.new(duration), {Value = 1})
	val.Changed:Connect(function(v)
		grad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, startTop:Lerp(targetTop, v)), ColorSequenceKeypoint.new(1, startBot:Lerp(targetBot, v))
		}
	end)
	tween:Play(); tween.Completed:Connect(function() val:Destroy() end)
end

-- [[ TOP BAR ]]
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 50); TopBar.Position = UDim2.new(0, 0, 0, -50); TopBar.BackgroundColor3 = Color3.fromRGB(15, 15, 18); TopBar.BorderSizePixel = 0; TopBar.ZIndex = 100; TopBar.Parent = AOT_Interface
Instance.new("UIStroke", TopBar).Color = Color3.fromRGB(120, 100, 60); TopBar.UIStroke.Thickness = 2; TopBar.UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local tbl = Instance.new("UIListLayout", TopBar); tbl.FillDirection = Enum.FillDirection.Horizontal; tbl.HorizontalAlignment = Enum.HorizontalAlignment.Right; tbl.VerticalAlignment = Enum.VerticalAlignment.Center; tbl.Padding = UDim.new(0, 20)
local tbp = Instance.new("UIPadding", TopBar); tbp.PaddingRight = UDim.new(0, 20)

local function CreateStatDisplay(name, prefixText, color)
	local container = Instance.new("Frame", TopBar)
	container.Name = name .. "Container"; container.Size = UDim2.new(0, isMobile and 100 or 150, 0, 35); container.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", container).Color = Color3.fromRGB(60, 60, 65)
	local label = Instance.new("TextLabel", container)
	label.Size = UDim2.new(1, -15, 1, 0); label.Position = UDim2.new(0, 5, 0, 0); label.BackgroundTransparency = 1; label.Font = Enum.Font.GothamBold; label.TextColor3 = color; label.TextScaled = true; label.TextXAlignment = Enum.TextXAlignment.Right; label.Text = prefixText .. " 0"
	Instance.new("UITextSizeConstraint", label).MaxTextSize = 16; return label
end

local dewsLabel = CreateStatDisplay("Dews", isMobile and "" or "DEWS:", Color3.fromRGB(180, 220, 255))
local xpLabel = CreateStatDisplay("XP", isMobile and "" or "XP:", Color3.fromRGB(100, 255, 100))
local titanXpLabel = CreateStatDisplay("TitanXP", isMobile and "" or "TITAN XP:", Color3.fromRGB(255, 100, 100))
local prestigeLabel = CreateStatDisplay("Prestige", isMobile and "P:" or "PRESTIGE:", Color3.fromRGB(255, 215, 100))

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"; ContentFrame.BackgroundTransparency = 1; ContentFrame.Parent = AOT_Interface

local NavWrapper = Instance.new("Frame")
NavWrapper.Name = "NavWrapper"; NavWrapper.BackgroundColor3 = Color3.fromRGB(15, 15, 18); NavWrapper.BorderSizePixel = 0; NavWrapper.ZIndex = 100; NavWrapper.Parent = AOT_Interface
Instance.new("UIStroke", NavWrapper).Color = Color3.fromRGB(120, 100, 60); NavWrapper.UIStroke.Thickness = 2; NavWrapper.UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local NavBar = Instance.new("ScrollingFrame")
NavBar.Name = "NavBar"; NavBar.Size = UDim2.new(1, 0, 1, 0); NavBar.BackgroundTransparency = 1; NavBar.BorderSizePixel = 0; NavBar.Parent = NavWrapper; NavBar.ScrollBarThickness = 0; NavBar.CanvasSize = UDim2.new(0, 0, 0, 0)
local nbl = Instance.new("UIListLayout", NavBar); nbl.HorizontalAlignment = Enum.HorizontalAlignment.Center; nbl.Padding = UDim.new(0, 10); local nbp = Instance.new("UIPadding", NavBar)

if isMobile then
	NavWrapper.Size = UDim2.new(1, 0, 0, 90); NavWrapper.Position = UDim2.new(0, 0, 1, 0)
	NavBar.AutomaticCanvasSize = Enum.AutomaticSize.X; NavBar.ScrollingDirection = Enum.ScrollingDirection.X
	nbl.FillDirection = Enum.FillDirection.Horizontal; nbl.HorizontalAlignment = Enum.HorizontalAlignment.Left; nbl.VerticalAlignment = Enum.VerticalAlignment.Center
	nbp.PaddingLeft = UDim.new(0, 10); nbp.PaddingRight = UDim.new(0, 10)
	ContentFrame.Size = UDim2.new(1, -20, 1, -160); ContentFrame.Position = UDim2.new(0, 10, 0, 60)
else
	NavWrapper.Size = UDim2.new(0, 130, 1, -50); NavWrapper.Position = UDim2.new(0, -130, 0, 50) 
	NavBar.AutomaticCanvasSize = Enum.AutomaticSize.Y; NavBar.ScrollingDirection = Enum.ScrollingDirection.Y
	nbl.FillDirection = Enum.FillDirection.Vertical; nbl.HorizontalAlignment = Enum.HorizontalAlignment.Center; nbl.VerticalAlignment = Enum.VerticalAlignment.Top
	nbp.PaddingTop = UDim.new(0, 15); nbp.PaddingBottom = UDim.new(0, 15)
	ContentFrame.Size = UDim2.new(1, -160, 1, -70); ContentFrame.Position = UDim2.new(0, 145, 0, 60)
end

-- [[ FIXED: Added PVP to Operations Menu ]]
local NavStructure = {
	["PLAYER"] = { {Id="Profile", Name="PROFILE"}, {Id="Stats", Name="STATS"}, {Id="Inherit", Name="INHERIT"} },
	["OPERATIONS"] = { {Id="Battle", Name="COMBAT"}, {Id="Bounties", Name="BOUNTIES"}, {Id="Dispatch", Name="EXPEDITIONS"}, {Id="PVP", Name="PVP"} },
	["SUPPLY"] = { {Id="Shop", Name="SHOP"}, {Id="Forge", Name="FORGE"}, {Id="Trade", Name="TRADE"} }
}

local RegimentColors = { ["Garrison"] = Color3.fromRGB(160, 60, 60), ["Military Police"] = Color3.fromRGB(60, 140, 60), ["Scout Regiment"] = Color3.fromRGB(60, 80, 160), ["Cadet Corps"] = Color3.fromRGB(120, 120, 130) }
local RegimentIcons = { ["Garrison"] = "rbxassetid://133062844", ["Military Police"] = "rbxassetid://132793466", ["Scout Regiment"] = "rbxassetid://132793532", ["Cadet Corps"] = "rbxassetid://132795247" }
local CategoryIcons = { ["PLAYER"] = "rbxassetid://106161709171988", ["OPERATIONS"] = "rbxassetid://115407261158495", ["SUPPLY"] = "rbxassetid://108619507999123" }

local ActiveCategory = nil; local ActiveTab = nil; local TabModules = {}; local SubButtons = {}
local CategoryCallbacks = {}

local function SwitchTab(tabName)
	if ActiveTab == tabName then return end; ActiveTab = tabName
	for _, btn in ipairs(SubButtons) do
		if btn.Name == tabName .. "Btn" then
			btn:SetAttribute("IsActive", true); local grad = btn:FindFirstChildOfClass("UIGradient")
			if grad then TweenGradient(grad, Color3.fromRGB(220, 160, 40), Color3.fromRGB(140, 90, 15), 0.2) end
			TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		else
			btn:SetAttribute("IsActive", false); local grad = btn:FindFirstChildOfClass("UIGradient")
			if grad then TweenGradient(grad, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), 0.2) end
			TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play()
		end
	end
	for _, child in ipairs(ContentFrame:GetChildren()) do if child:IsA("Frame") or child:IsA("ScrollingFrame") then child.Visible = false end end
	if AOT_Interface:FindFirstChild("TradeOverlay") then AOT_Interface.TradeOverlay.Visible = false end

	-- [[ FIXED: Safely hide the custom PvP UI when switching tabs ]]
	if player.PlayerGui:FindFirstChild("PvPGui") then 
		player.PlayerGui.PvPGui.MainFrame.Visible = false 
	end

	if TabModules[tabName] and TabModules[tabName].Show then TabModules[tabName].Show() end
end

_G.AOT_OpenCategory = function(name) if CategoryCallbacks[name] and ActiveCategory ~= name then CategoryCallbacks[name]() end end
_G.AOT_SwitchTab = SwitchTab

local function BuildNavigation()
	for _, child in ipairs(NavBar:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	SubButtons = {}

	local regBtn = Instance.new("TextButton", NavBar)
	regBtn.Name = "RegimentsBtn"; regBtn.Size = isMobile and UDim2.new(0, 100, 1, -15) or UDim2.new(1, -15, 0, 110); regBtn.Text = ""
	ApplyButtonGradient(regBtn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(80, 80, 90))
	local regLogo = Instance.new("ImageLabel", regBtn); regLogo.Size = UDim2.new(0.6, 0, 0.6, 0); regLogo.Position = UDim2.new(0.2, 0, 0.05, 0); regLogo.BackgroundTransparency = 1; regLogo.ScaleType = Enum.ScaleType.Fit
	local regText = Instance.new("TextLabel", regBtn); regText.Size = UDim2.new(1, -10, 0.3, 0); regText.Position = UDim2.new(0, 5, 0.65, 0); regText.BackgroundTransparency = 1; regText.Font = Enum.Font.GothamBlack; regText.TextScaled = true; Instance.new("UITextSizeConstraint", regText).MaxTextSize = 12

	local function UpdateRegimentBtn()
		local rName = player:GetAttribute("Regiment") or "Cadet Corps"; local rColor = RegimentColors[rName] or Color3.fromRGB(120, 120, 130); local rIcon = RegimentIcons[rName] or ""
		local stroke = regBtn:FindFirstChildOfClass("UIStroke"); if stroke then stroke.Color = rColor end
		regLogo.ImageColor3 = rColor; regText.TextColor3 = rColor; regText.Text = string.upper(rName); regLogo.Image = rIcon
	end
	player.AttributeChanged:Connect(function(attr) if attr == "Regiment" then UpdateRegimentBtn() end end); UpdateRegimentBtn()
	regBtn.MouseButton1Click:Connect(function() SwitchTab("Regiments") end); table.insert(SubButtons, regBtn)

	local hubBtn = Instance.new("TextButton", NavBar)
	hubBtn.Name = "HubBtn"; hubBtn.Size = isMobile and UDim2.new(0, 90, 1, -15) or UDim2.new(1, -15, 0, 90); hubBtn.Text = ""
	ApplyButtonGradient(hubBtn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(200, 160, 50))
	local hubLogo = Instance.new("ImageLabel", hubBtn); hubLogo.Size = UDim2.new(0.5, 0, 0.5, 0); hubLogo.Position = UDim2.new(0.25, 0, 0.1, 0); hubLogo.BackgroundTransparency = 1; hubLogo.ScaleType = Enum.ScaleType.Fit; hubLogo.Image = "rbxassetid://129528574378357"; hubLogo.ImageColor3 = Color3.fromRGB(255, 215, 100)
	local hubText = Instance.new("TextLabel", hubBtn); hubText.Size = UDim2.new(1, -10, 0.3, 0); hubText.Position = UDim2.new(0, 5, 0.65, 0); hubText.BackgroundTransparency = 1; hubText.Font = Enum.Font.GothamBlack; hubText.TextColor3 = Color3.fromRGB(255, 215, 100); hubText.TextScaled = true; Instance.new("UITextSizeConstraint", hubText).MaxTextSize = 11; hubText.Text = "GUIDE"

	hubBtn.MouseButton1Click:Connect(function()
		local folderName = isMobile and "MobileModules" or "UIModules"
		local uiFolder = script.Parent:WaitForChild(folderName, 3) or script.Parent:WaitForChild("UIModules")
		require(uiFolder:WaitForChild("WelcomeHub")).Show(true)
	end)

	local OrderedKeys = {"PLAYER", "OPERATIONS", "SUPPLY"}

	for _, catName in ipairs(OrderedKeys) do
		local subTabs = NavStructure[catName]
		local catBtn = Instance.new("TextButton", NavBar)
		catBtn.Size = isMobile and UDim2.new(0, 90, 1, -15) or UDim2.new(1, -15, 0, 90); catBtn.Text = ""
		ApplyButtonGradient(catBtn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(80, 70, 40))

		local catIcon = Instance.new("ImageLabel", catBtn); catIcon.Size = UDim2.new(0, 40, 0, 40); catIcon.Position = UDim2.new(0.5, 0, 0.4, 0); catIcon.AnchorPoint = Vector2.new(0.5, 0.5); catIcon.BackgroundTransparency = 1; catIcon.ScaleType = Enum.ScaleType.Fit; catIcon.Image = CategoryIcons[catName]; catIcon.ImageColor3 = Color3.fromRGB(255, 215, 100)
		local catLbl = Instance.new("TextLabel", catBtn); catLbl.Size = UDim2.new(1, -10, 0, 25); catLbl.Position = UDim2.new(0, 5, 0.65, 0); catLbl.BackgroundTransparency = 1; catLbl.Font = Enum.Font.GothamBlack; catLbl.TextColor3 = Color3.fromRGB(200, 180, 100); catLbl.TextScaled = true; catLbl.Text = catName; Instance.new("UITextSizeConstraint", catLbl).MaxTextSize = 11

		local SubContainer = Instance.new("Frame", NavBar); SubContainer.BackgroundTransparency = 1; SubContainer.ClipsDescendants = true
		local scLayout = Instance.new("UIListLayout", SubContainer); scLayout.Padding = UDim.new(0, 8); scLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		if isMobile then scLayout.FillDirection = Enum.FillDirection.Horizontal; SubContainer.Size = UDim2.new(0, 0, 1, 0) else scLayout.FillDirection = Enum.FillDirection.Vertical; SubContainer.Size = UDim2.new(1, 0, 0, 0) end

		for _, tabInfo in ipairs(subTabs) do
			local sBtn = Instance.new("TextButton", SubContainer)
			sBtn.Name = tabInfo.Id .. "Btn"; sBtn.Size = isMobile and UDim2.new(0, 85, 1, -25) or UDim2.new(1, -25, 0, 45); sBtn.Font = Enum.Font.GothamBold; sBtn.TextColor3 = Color3.fromRGB(180, 180, 180); sBtn.TextScaled = true; sBtn.Text = tabInfo.Name; Instance.new("UITextSizeConstraint", sBtn).MaxTextSize = 11
			ApplyButtonGradient(sBtn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(50, 50, 55)); table.insert(SubButtons, sBtn)
			sBtn.MouseButton1Click:Connect(function() SwitchTab(tabInfo.Id) end)
		end

		CategoryCallbacks[catName] = function()
			local grad = catBtn:FindFirstChildOfClass("UIGradient")
			if ActiveCategory == catName then
				ActiveCategory = nil
				TweenService:Create(SubContainer, TweenInfo.new(0.3), {Size = isMobile and UDim2.new(0, 0, 1, 0) or UDim2.new(1, 0, 0, 0)}):Play()
				if grad then TweenGradient(grad, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), 0.2) end
				TweenService:Create(catIcon, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 215, 100)}):Play()
				TweenService:Create(catLbl, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(200, 180, 100)}):Play()
			else
				ActiveCategory = catName
				for _, child in ipairs(NavBar:GetChildren()) do
					if child:IsA("Frame") and child ~= SubContainer then TweenService:Create(child, TweenInfo.new(0.3), {Size = isMobile and UDim2.new(0, 0, 1, 0) or UDim2.new(1, 0, 0, 0)}):Play() end
					if child:IsA("TextButton") and child ~= catBtn and child.Name ~= "RegimentsBtn" and child.Name ~= "AdminBtn" and child.Name ~= "HubBtn" then 
						local cGrad = child:FindFirstChildOfClass("UIGradient")
						if cGrad then TweenGradient(cGrad, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), 0.2) end
						local ic = child:FindFirstChildOfClass("ImageLabel"); if ic then TweenService:Create(ic, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 215, 100)}):Play() end
						local tx = child:FindFirstChildOfClass("TextLabel"); if tx then TweenService:Create(tx, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(200, 180, 100)}):Play() end
					end
				end
				local targetSize = isMobile and UDim2.new(0, #subTabs * 95, 1, 0) or UDim2.new(1, 0, 0, #subTabs * 55)
				TweenService:Create(SubContainer, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = targetSize}):Play()
				if grad then TweenGradient(grad, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), 0.2) end
				TweenService:Create(catIcon, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
				TweenService:Create(catLbl, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			end
		end
		catBtn.MouseButton1Click:Connect(CategoryCallbacks[catName])
	end

	if (player.UserId == 4068160397 or player.Name == "girthbender1209") then
		local adminBtn = Instance.new("TextButton", NavBar)
		adminBtn.Name = "AdminBtn"; adminBtn.Size = isMobile and UDim2.new(0, 90, 1, -15) or UDim2.new(1, -15, 0, 45)
		adminBtn.Font = Enum.Font.GothamBlack; adminBtn.TextColor3 = Color3.fromRGB(255, 100, 100); adminBtn.TextScaled = true; adminBtn.Text = "ADMIN"; Instance.new("UITextSizeConstraint", adminBtn).MaxTextSize = 12
		ApplyButtonGradient(adminBtn, Color3.fromRGB(80, 30, 30), Color3.fromRGB(40, 15, 15), Color3.fromRGB(150, 50, 50))
		table.insert(SubButtons, adminBtn)
		adminBtn.MouseButton1Click:Connect(function() SwitchTab("Admin") end)
	end
end

BuildNavigation()

task.spawn(function()
	task.wait(0.5)
	TweenService:Create(TopBar, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
	task.wait(0.2)
	local targetPos = isMobile and UDim2.new(0, 0, 1, -90) or UDim2.new(0, 0, 0, 50)
	TweenService:Create(NavWrapper, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = targetPos}):Play()
end)

local Suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx"}
local function AbbreviateNumber(n)
	if not n then return "0" end; n = tonumber(n) or 0
	if n < 1000 then return tostring(math.floor(n)) end
	local suffixIndex = math.floor(math.log10(n) / 3); local value = n / (10 ^ (suffixIndex * 3))
	local str = string.format("%.1f", value); str = str:gsub("%.0$", "")
	return str .. (Suffixes[suffixIndex + 1] or "")
end

local function UpdateStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		if leaderstats:FindFirstChild("Dews") then dewsLabel.Text = (isMobile and "" or "DEWS: ") .. AbbreviateNumber(leaderstats.Dews.Value) end
		if leaderstats:FindFirstChild("Prestige") then prestigeLabel.Text = (isMobile and "P:" or "PRESTIGE: ") .. leaderstats.Prestige.Value end
	end
	xpLabel.Text = (isMobile and "" or "XP: ") .. AbbreviateNumber(player:GetAttribute("XP"))
	titanXpLabel.Text = (isMobile and "" or "TITAN XP: ") .. AbbreviateNumber(player:GetAttribute("TitanXP"))
end
player.AttributeChanged:Connect(function(attr) if attr == "XP" or attr == "TitanXP" or attr == "Titan" then UpdateStats() end end)
task.spawn(function() local leaderstats = player:WaitForChild("leaderstats", 10) if leaderstats then for _, child in ipairs(leaderstats:GetChildren()) do if child:IsA("IntValue") then child.Changed:Connect(UpdateStats) end end end UpdateStats() end)

task.spawn(function()
	local folderName = isMobile and "MobileModules" or "UIModules"
	local uiModulesFolder = script.Parent:WaitForChild(folderName, 5) or script.Parent:WaitForChild("UIModules", 5)

	if uiModulesFolder then
		local rootModules = script.Parent:WaitForChild("UIModules", 5)
		local TooltipManager = require(uiModulesFolder:WaitForChild("TooltipManager")); TooltipManager.Init(AOT_Interface)
		local NotificationManager = require(rootModules:WaitForChild("NotificationManager")); NotificationManager.Init(AOT_Interface)

		ReplicatedStorage:WaitForChild("Network"):WaitForChild("NotificationEvent").OnClientEvent:Connect(function(msg, msgType)
			if NotificationManager then NotificationManager.Show(msg, msgType) end
		end)

		TabModules["Profile"] = require(uiModulesFolder:WaitForChild("ProfileTab")); TabModules["Profile"].Init(ContentFrame, TooltipManager)
		TabModules["Inherit"] = require(uiModulesFolder:WaitForChild("InheritTab")); TabModules["Inherit"].Init(ContentFrame, TooltipManager)
		TabModules["Stats"] = require(uiModulesFolder:WaitForChild("StatsTab")); TabModules["Stats"].Init(ContentFrame, TooltipManager)
		TabModules["Battle"] = require(uiModulesFolder:WaitForChild("BattleTab")); TabModules["Battle"].Init(ContentFrame, TooltipManager)
		TabModules["Shop"] = require(uiModulesFolder:WaitForChild("ShopTab")); TabModules["Shop"].Init(ContentFrame, TooltipManager)
		TabModules["Bounties"] = require(uiModulesFolder:WaitForChild("BountiesTab")); TabModules["Bounties"].Init(ContentFrame, TooltipManager)
		TabModules["Forge"] = require(uiModulesFolder:WaitForChild("ForgeTab")); TabModules["Forge"].Init(ContentFrame, TooltipManager)
		TabModules["Trade"] = require(uiModulesFolder:WaitForChild("TradeMenu")); TabModules["Trade"].Init(ContentFrame, TooltipManager)
		TabModules["Regiments"] = require(uiModulesFolder:WaitForChild("RegimentTab")); TabModules["Regiments"].Init(ContentFrame, TooltipManager)
		TabModules["Dispatch"] = require(uiModulesFolder:WaitForChild("DispatchTab")); TabModules["Dispatch"].Init(ContentFrame, TooltipManager)
		TabModules["Combat"] = require(uiModulesFolder:WaitForChild("CombatTab")); TabModules["Combat"].Init(ContentFrame, TooltipManager)

		-- [[ STANDARD INITIALIZATION ]]
		TabModules["PVP"] = require(uiModulesFolder:WaitForChild("PVPTab"))
		TabModules["PVP"].Init(ContentFrame, TooltipManager)
		TabModules["RaidCombat"] = require(uiModulesFolder:WaitForChild("RaidTab"))
		TabModules["RaidCombat"].Init(ContentFrame, TooltipManager)

		pcall(function()
			if (player.UserId == 4068160397 or player.Name == "girthbender1209") then
				TabModules["Admin"] = require(rootModules:WaitForChild("AdminTab")); TabModules["Admin"].Init(ContentFrame)
			end
		end)

		local WelcomeHub = require(uiModulesFolder:WaitForChild("WelcomeHub"))
		WelcomeHub.Init(ContentFrame)
		WelcomeHub.Show()

		SwitchTab("Profile")
	end
end)