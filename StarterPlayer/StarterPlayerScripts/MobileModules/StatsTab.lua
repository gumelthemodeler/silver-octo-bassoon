-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local StatsTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local player = Players.LocalPlayer
local MainFrame

local playerStatsList = {"Health", "Strength", "Defense", "Speed", "Gas", "Resolve"}
local titanStatsList = {"Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val"}
local statRowRefs = {}
local humanCombo = 0
local titanCombo = 0

local Suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx"}
local function AbbreviateNumber(n)
	if not n then return "0" end; n = tonumber(n) or 0
	if n < 1000 then return tostring(math.floor(n)) end
	local suffixIndex = math.floor(math.log10(n) / 3); local value = n / (10 ^ (suffixIndex * 3))
	local str = string.format("%.1f", value); str = str:gsub("%.0$", "")
	return str .. (Suffixes[suffixIndex + 1] or "")
end

local function GetCombinedBonus(statName)
	local wpn = player:GetAttribute("EquippedWeapon") or "None"
	local acc = player:GetAttribute("EquippedAccessory") or "None"
	local style = player:GetAttribute("FightingStyle") or "None"
	local bonus = 0
	if ItemData.Equipment[wpn] and ItemData.Equipment[wpn].Bonus[statName] then bonus += ItemData.Equipment[wpn].Bonus[statName] end
	if ItemData.Equipment[acc] and ItemData.Equipment[acc].Bonus[statName] then bonus += ItemData.Equipment[acc].Bonus[statName] end
	if GameData.WeaponBonuses and GameData.WeaponBonuses[style] and GameData.WeaponBonuses[style][statName] then bonus += GameData.WeaponBonuses[style][statName] end
	return bonus
end

local function GetUpgradeCosts(currentStat, cleanName, prestige)
	local base = (prestige == 0) and (GameData.BaseStats[cleanName] or 10) or (prestige * 5)
	return GameData.CalculateStatCost(currentStat, base, prestige)
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

local function CreateStatRow(statName, parent, isTitan, layoutOrder, amtInput)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1, 0, 0, 35); row.BackgroundTransparency = 1; row.LayoutOrder = layoutOrder

	local statLabel = Instance.new("TextLabel", row)
	statLabel.Size = UDim2.new(0.4, 0, 1, 0); statLabel.BackgroundTransparency = 1; statLabel.Font = Enum.Font.GothamBold; statLabel.TextColor3 = isTitan and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(220, 220, 220); statLabel.TextXAlignment = Enum.TextXAlignment.Left; statLabel.TextSize = 12; statLabel.RichText = true; statLabel.TextScaled = true; Instance.new("UITextSizeConstraint", statLabel).MaxTextSize = 12

	local btnContainer = Instance.new("Frame", row)
	btnContainer.Size = UDim2.new(0.6, 0, 1, 0); btnContainer.Position = UDim2.new(1, 0, 0, 0); btnContainer.AnchorPoint = Vector2.new(1, 0); btnContainer.BackgroundTransparency = 1
	local blL = Instance.new("UIListLayout", btnContainer); blL.FillDirection = Enum.FillDirection.Horizontal; blL.HorizontalAlignment = Enum.HorizontalAlignment.Right; blL.VerticalAlignment = Enum.VerticalAlignment.Center; blL.Padding = UDim.new(0.04, 0)

	local function makeBtn(text, scaleW)
		local b = Instance.new("TextButton", btnContainer)
		b.Size = UDim2.new(scaleW, 0, 0.85, 0); b.Text = text; b.Font = Enum.Font.GothamBold; b.TextColor3 = Color3.fromRGB(255, 255, 255); b.TextSize = 11
		ApplyButtonGradient(b, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(140, 60, 200))
		return b
	end
	local bAdd = makeBtn("+", 0.35)
	local bMax = makeBtn("MAX", 0.55)

	local isUpgrading = false
	local function TryUpgrade(amt)
		if isUpgrading then return end
		isUpgrading = true
		local prestige = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
		local statCap = GameData.GetStatCap(prestige)
		local currentStat = player:GetAttribute(statName) or 10; if type(currentStat) == "string" then currentStat = GameData.TitanRanks[currentStat] or 10 end
		local currentXP = isTitan and (player:GetAttribute("TitanXP") or 0) or (player:GetAttribute("XP") or 0)
		local cleanName = statName:gsub("_Val", ""):gsub("Titan_", "")
		local base = (prestige == 0) and (GameData.BaseStats[cleanName] or 10) or (prestige * 5)
		if currentStat >= statCap then isUpgrading = false; return end
		local cost, added, simulatedXP = 0, 0, currentXP
		local target = (amt == "MAX") and 9999 or amt
		for i = 0, target - 1 do
			if currentStat + added >= statCap then break end
			local stepCost = GameData.CalculateStatCost(currentStat + added, base, prestige)
			if simulatedXP >= stepCost then simulatedXP -= stepCost; cost += stepCost; added += 1 else break end
		end
		if added > 0 then Network:WaitForChild("UpgradeStat"):FireServer(statName, added) end
		task.wait(0.15); isUpgrading = false
	end

	bAdd.MouseButton1Down:Connect(function() local customAmt = tonumber(amtInput.Text) or 1; if customAmt < 1 then customAmt = 1 end; TryUpgrade(math.floor(customAmt)) end)
	bMax.MouseButton1Down:Connect(function() TryUpgrade("MAX") end)
	statRowRefs[statName] = { Label = statLabel, BtnContainer = btnContainer, BtnAdd = bAdd, BtnMax = bMax }
end

function StatsTab.Init(parentFrame)
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "StatsFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false; MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local mainLayout = Instance.new("UIListLayout", MainFrame); mainLayout.Padding = UDim.new(0, 15); mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.FillDirection = Enum.FillDirection.Vertical 
	local padding = Instance.new("UIPadding", MainFrame); padding.PaddingTop = UDim.new(0, 10); padding.PaddingBottom = UDim.new(0, 20)

	local function CreateFloatingText(textStr, color, parentBox, startPos)
		local fTxt = Instance.new("TextLabel", parentBox)
		fTxt.Size = UDim2.new(0, 100, 0, 30); fTxt.Position = startPos; fTxt.AnchorPoint = Vector2.new(0.5, 0.5); fTxt.BackgroundTransparency = 1; fTxt.Font = Enum.Font.GothamBlack; fTxt.TextColor3 = color; fTxt.TextSize = 20; fTxt.Text = textStr; fTxt.ZIndex = 4
		TweenService:Create(fTxt, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = fTxt.Position - UDim2.new(0, 0, 0.3, 0), TextTransparency = 1}):Play(); game.Debris:AddItem(fTxt, 0.6)
	end

	local function SetupPanel(titleTxt, statList, isTitan, layoutOrd)
		local panel = Instance.new("Frame", MainFrame)
		panel.Size = UDim2.new(0.95, 0, 0, 0); panel.AutomaticSize = Enum.AutomaticSize.Y; panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); panel.LayoutOrder = layoutOrd
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", panel).Color = Color3.fromRGB(80, 80, 90)
		local pLayout = Instance.new("UIListLayout", panel); pLayout.SortOrder = Enum.SortOrder.LayoutOrder; pLayout.Padding = UDim.new(0, 5); pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local pPad = Instance.new("UIPadding", panel); pPad.PaddingTop = UDim.new(0, 10); pPad.PaddingBottom = UDim.new(0, 15)

		local header = Instance.new("Frame", panel); header.Size = UDim2.new(1, -10, 0, 30); header.BackgroundTransparency = 1; header.LayoutOrder = 1
		local title = Instance.new("TextLabel", header); title.Size = UDim2.new(0.5, 0, 1, 0); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextSize = 14; title.Text = titleTxt; title.TextColor3 = isTitan and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(200, 200, 220); title.TextXAlignment = Enum.TextXAlignment.Left; title.TextScaled = true; Instance.new("UITextSizeConstraint", title).MaxTextSize = 14

		local controls = Instance.new("Frame", header); controls.Size = UDim2.new(0.5, 0, 1, 0); controls.Position = UDim2.new(0.5, 0, 0, 0); controls.BackgroundTransparency = 1
		local cLayout = Instance.new("UIListLayout", controls); cLayout.FillDirection = Enum.FillDirection.Horizontal; cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; cLayout.VerticalAlignment = Enum.VerticalAlignment.Center; cLayout.Padding = UDim.new(0, 5)

		local allBtn = Instance.new("TextButton", controls)
		allBtn.Size = UDim2.new(0.4, 0, 0.8, 0); allBtn.Text = "ALL"; allBtn.Font = Enum.Font.GothamBold; allBtn.TextColor3 = Color3.fromRGB(255, 255, 255); allBtn.TextSize = 10
		ApplyButtonGradient(allBtn, Color3.fromRGB(200, 120, 30), Color3.fromRGB(120, 60, 15), Color3.fromRGB(220, 150, 50))

		local amtInput = Instance.new("TextBox", controls); amtInput.Size = UDim2.new(0.3, 0, 0.8, 0); amtInput.BackgroundColor3 = Color3.fromRGB(15, 15, 20); amtInput.Text = "1"; amtInput.Font = Enum.Font.GothamBold; amtInput.TextColor3 = Color3.new(1,1,1); amtInput.TextSize = 11; Instance.new("UICorner", amtInput).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", amtInput).Color = Color3.fromRGB(100, 60, 140)

		local ptsLbl = Instance.new("TextLabel", controls); ptsLbl.Size = UDim2.new(0.4, 0, 0.8, 0); ptsLbl.BackgroundTransparency = 1; ptsLbl.Text = "0 XP"; ptsLbl.Font = Enum.Font.GothamMedium; ptsLbl.TextColor3 = isTitan and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100); ptsLbl.TextSize = 11; ptsLbl.TextXAlignment = Enum.TextXAlignment.Right

		local list = Instance.new("Frame", panel); list.Size = UDim2.new(1, -20, 0, 0); list.AutomaticSize = Enum.AutomaticSize.Y; list.BackgroundTransparency = 1; list.LayoutOrder = 2
		local lLayout = Instance.new("UIListLayout", list); lLayout.SortOrder = Enum.SortOrder.LayoutOrder; lLayout.Padding = UDim.new(0, 8)

		for i, s in ipairs(statList) do CreateStatRow(s, list, isTitan, i, amtInput) end

		local trainBox = Instance.new("Frame", panel)
		trainBox.Size = UDim2.new(1, -10, 0, 110); trainBox.BackgroundColor3 = Color3.fromRGB(15, 15, 20); trainBox.LayoutOrder = 3; trainBox.ClipsDescendants = true
		Instance.new("UICorner", trainBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", trainBox).Color = Color3.fromRGB(120, 100, 60)

		local comboLbl = Instance.new("TextLabel", trainBox)
		comboLbl.Size = UDim2.new(1, -20, 0, 30); comboLbl.Position = UDim2.new(0, 10, 0, 10); comboLbl.BackgroundTransparency = 1; comboLbl.Font = Enum.Font.GothamBlack; comboLbl.TextColor3 = isTitan and Color3.fromRGB(255, 150, 100) or Color3.fromRGB(150, 255, 100); comboLbl.TextSize = 16; comboLbl.TextXAlignment = Enum.TextXAlignment.Left; comboLbl.Text = ""
		comboLbl.Visible = false
		comboLbl.RichText = true -- [[ THE FIX: Resolves the String rendering issue! ]]
		comboLbl.ZIndex = 2

		local missBtn = Instance.new("TextButton", trainBox); missBtn.Size = UDim2.new(1, 0, 1, 0); missBtn.BackgroundTransparency = 1; missBtn.Text = ""; missBtn.ZIndex = 1 

		local tBtn = Instance.new("TextButton", trainBox)
		tBtn.Size = UDim2.new(0.4, 0, 0, 45); tBtn.AnchorPoint = Vector2.new(0.5, 0.5); tBtn.Position = UDim2.new(0.5, 0, 0.6, 0)
		tBtn.Font = Enum.Font.GothamBlack; tBtn.TextColor3 = Color3.fromRGB(255, 255, 255); tBtn.TextScaled = true; tBtn.Text = isTitan and "TRAIN TITAN" or "TRAIN SOLDIER"; tBtn.ZIndex = 3 
		Instance.new("UITextSizeConstraint", tBtn).MaxTextSize = 13

		if isTitan then ApplyButtonGradient(tBtn, Color3.fromRGB(200, 60, 60), Color3.fromRGB(120, 30, 30), Color3.fromRGB(80, 20, 20))
		else ApplyButtonGradient(tBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20)) end

		-- [[ THE FIX: Use MouseButton1Down for perfectly responsive, ghost-touch-free aim training ]]
		tBtn.MouseButton1Down:Connect(function()
			local currentPos = tBtn.Position
			if isTitan then titanCombo += 1 else humanCombo += 1 end
			local activeCombo = isTitan and titanCombo or humanCombo

			if activeCombo > 1 then 
				comboLbl.TextColor3 = isTitan and Color3.fromRGB(255, 150, 100) or Color3.fromRGB(150, 255, 100)
				comboLbl.Visible = true
				comboLbl.Text = "x" .. activeCombo .. " COMBO!" 
			end

			local prestige = player:WaitForChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
			local totalStats = (player:GetAttribute("Strength") or 10) + (player:GetAttribute("Defense") or 10) + (player:GetAttribute("Speed") or 10) + (player:GetAttribute("Resolve") or 10)
			local baseXP = 1 + (prestige * 50) + math.floor(totalStats / 4)
			local xpGain = math.floor(baseXP * (1.0 + (activeCombo * 0.1)))

			CreateFloatingText("+" .. xpGain .. (isTitan and " T-XP" or " XP"), Color3.fromRGB(100, 255, 100), trainBox, currentPos)
			tBtn.Position = UDim2.new(math.random(25, 75)/100, 0, math.random(30, 80)/100, 0)
			Network.TrainAction:FireServer(activeCombo, isTitan)
		end)

		missBtn.MouseButton1Down:Connect(function()
			if isTitan and titanCombo > 0 then
				titanCombo = 0
				comboLbl.Visible = true
				comboLbl.Text = "<font color='#FF5555'>COMBO DROPPED!</font>"
				task.delay(1.5, function() if titanCombo == 0 then comboLbl.Visible = false end end)
			elseif not isTitan and humanCombo > 0 then
				humanCombo = 0
				comboLbl.Visible = true
				comboLbl.Text = "<font color='#FF5555'>COMBO DROPPED!</font>"
				task.delay(1.5, function() if humanCombo == 0 then comboLbl.Visible = false end end)
			end
		end)

		local isSpammingAll = false
		allBtn.MouseButton1Down:Connect(function()
			if isSpammingAll then return end
			isSpammingAll = true

			local prestige = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
			local statCap = GameData.GetStatCap(prestige)
			local currentXP = isTitan and (player:GetAttribute("TitanXP") or 0) or (player:GetAttribute("XP") or 0)
			local simXP = currentXP

			local tallies = {}; local simStats = {}
			for _, s in ipairs(statList) do
				tallies[s] = 0
				local val = player:GetAttribute(s) or 10; if type(val) == "string" then val = GameData.TitanRanks[val] or 10 end
				simStats[s] = val
			end

			local totalUpgrades = 0
			while true do
				local upgradedAny = false
				for _, s in ipairs(statList) do
					local cleanName = s:gsub("_Val", ""):gsub("Titan_", "")
					local base = (prestige == 0) and (GameData.BaseStats[cleanName] or 10) or (prestige * 5)
					if simStats[s] < statCap then
						local cost = GameData.CalculateStatCost(simStats[s], base, prestige)
						if simXP >= cost then simXP -= cost; simStats[s] += 1; tallies[s] += 1; upgradedAny = true; totalUpgrades += 1 end
					end
				end
				if not upgradedAny then break end
			end

			if totalUpgrades > 0 then
				for s, amt in pairs(tallies) do if amt > 0 then Network:WaitForChild("UpgradeStat"):FireServer(s, amt) end end
			end
			task.wait(0.25); isSpammingAll = false
		end)

		return { Panel = panel, PtsLbl = ptsLbl }
	end

	local soldierData = SetupPanel("SOLDIER VITALITY", playerStatsList, false, 1)
	local titanData = SetupPanel("TITAN POTENTIAL", titanStatsList, true, 2)

	local function UpdateStats()
		local prestigeObj = player:WaitForChild("leaderstats", 5) and player.leaderstats:FindFirstChild("Prestige")
		local prestige = prestigeObj and prestigeObj.Value or 0
		local hXP = player:GetAttribute("XP") or 0; local tXP = player:GetAttribute("TitanXP") or 0
		local statCap = GameData.GetStatCap(prestige)

		soldierData.PtsLbl.Text = AbbreviateNumber(hXP) .. " XP"
		titanData.PtsLbl.Text = AbbreviateNumber(tXP) .. " T-XP"

		local allStats = {}
		for _, s in ipairs(playerStatsList) do table.insert(allStats, s) end
		for _, s in ipairs(titanStatsList) do table.insert(allStats, s) end

		for _, statName in ipairs(allStats) do
			local cleanName = statName:gsub("_Val", ""):gsub("Titan_", "")
			local data = statRowRefs[statName]
			local isTitanStat = table.find(titanStatsList, statName) ~= nil
			local val = player:GetAttribute(statName) or 10; if type(val) == "string" then val = 10 end 
			local cost1 = GetUpgradeCosts(val, cleanName, prestige)
			local bonusAmount = GetCombinedBonus(cleanName)
			local bonusText = bonusAmount > 0 and " <font color='#55FF55'>(+" .. bonusAmount .. ")</font>" or ""

			if val >= statCap then
				data.Label.Text = cleanName .. ": <font color='" .. (isTitanStat and "#FF5555" or "#FFFFFF") .. "'>" .. val .. "</font>" .. bonusText .. " <font color='#FF5555'>[MAX]</font>"
				ApplyButtonGradient(data.BtnAdd, Color3.fromRGB(20, 15, 25), Color3.fromRGB(10, 8, 15), Color3.fromRGB(40, 30, 60))
				data.BtnAdd.TextColor3 = Color3.fromRGB(100, 100, 100)

				ApplyButtonGradient(data.BtnMax, Color3.fromRGB(20, 15, 25), Color3.fromRGB(10, 8, 15), Color3.fromRGB(40, 30, 60))
				data.BtnMax.TextColor3 = Color3.fromRGB(100, 100, 100)
			else
				data.Label.Text = cleanName .. ": <font color='" .. (isTitanStat and "#FF5555" or "#FFFFFF") .. "'>" .. val .. "</font>" .. bonusText
				local function toggle(btn, canAfford)
					if canAfford then
						ApplyButtonGradient(btn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(140, 60, 200))
						btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					else
						ApplyButtonGradient(btn, Color3.fromRGB(20, 15, 25), Color3.fromRGB(10, 8, 15), Color3.fromRGB(50, 40, 70))
						btn.TextColor3 = Color3.fromRGB(100, 100, 100)
					end
				end
				toggle(data.BtnAdd, (isTitanStat and tXP or hXP) >= cost1)
				toggle(data.BtnMax, (isTitanStat and tXP or hXP) >= cost1)
			end
		end
		task.delay(0.05, function() MainFrame.CanvasSize = UDim2.new(0, 0, 0, mainLayout.AbsoluteContentSize.Y + 20) end)
	end

	player.AttributeChanged:Connect(function(attr) if table.find(playerStatsList, attr) or table.find(titanStatsList, attr) or attr == "XP" or attr == "TitanXP" or attr == "Titan" then UpdateStats() end end)

	task.spawn(function()
		local ls = player:WaitForChild("leaderstats", 10)
		if ls and ls:FindFirstChild("Prestige") then
			ls.Prestige.Changed:Connect(UpdateStats)
		end
	end)

	UpdateStats()
end

function StatsTab.Show() if MainFrame then MainFrame.Visible = true end end
return StatsTab