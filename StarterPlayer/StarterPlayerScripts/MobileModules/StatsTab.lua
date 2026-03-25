-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local StatsTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local NotificationManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("NotificationManager"))

local player = Players.LocalPlayer
local MainFrame
local cachedTooltipMgr

local playerStatsList = {"Health", "Strength", "Defense", "Speed", "Gas", "Resolve"}
local titanStatsList = {"Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val"}
local statRowRefs = {}
local humanCombo = 0
local titanCombo = 0

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

local function CreateStatRow(statName, parent, isTitan, layoutOrder, amtInput)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1, 0, 0, 35); row.BackgroundTransparency = 1; row.LayoutOrder = layoutOrder

	local statLabel = Instance.new("TextLabel", row)
	statLabel.Size = UDim2.new(0.38, 0, 1, 0); statLabel.BackgroundTransparency = 1; statLabel.Font = Enum.Font.GothamBold; statLabel.TextColor3 = isTitan and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(220, 220, 220); statLabel.TextXAlignment = Enum.TextXAlignment.Left; statLabel.TextSize = 13; statLabel.RichText = true; statLabel.TextScaled = true; Instance.new("UITextSizeConstraint", statLabel).MaxTextSize = 13

	local btnContainer = Instance.new("Frame", row)
	btnContainer.Size = UDim2.new(0.62, 0, 1, 0); btnContainer.Position = UDim2.new(1, 0, 0, 0); btnContainer.AnchorPoint = Vector2.new(1, 0); btnContainer.BackgroundTransparency = 1
	local blL = Instance.new("UIListLayout", btnContainer); blL.FillDirection = Enum.FillDirection.Horizontal; blL.HorizontalAlignment = Enum.HorizontalAlignment.Right; blL.VerticalAlignment = Enum.VerticalAlignment.Center; blL.Padding = UDim.new(0.04, 0)

	local function makeBtn(text, scaleW)
		local b = Instance.new("TextButton", btnContainer); b.Size = UDim2.new(scaleW, 0, 0.85, 0); b.BackgroundColor3 = Color3.fromRGB(30, 25, 35); b.Text = text; b.Font = Enum.Font.GothamBold; b.TextColor3 = Color3.new(1,1,1); b.TextSize = 12; Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", b).Color = Color3.fromRGB(80, 60, 120)
		return b
	end
	local bAdd = makeBtn("+", 0.35)
	local bMax = makeBtn("MAX", 0.55)

	-- [[ THE FIX: Debounce protection ]]
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

		if added > 0 then
			Network:WaitForChild("UpgradeStat"):FireServer(statName, added)
			if NotificationManager then NotificationManager.Show(cleanName:upper() .. " upgraded by +" .. added .. "!", "Success") end
		else
			if NotificationManager then NotificationManager.Show("Not enough XP!", "Error") end
		end

		task.wait(0.15)
		isUpgrading = false
	end

	bAdd.MouseButton1Click:Connect(function() local customAmt = tonumber(amtInput.Text) or 1; if customAmt < 1 then customAmt = 1 end; TryUpgrade(math.floor(customAmt)) end)
	bMax.MouseButton1Click:Connect(function() TryUpgrade("MAX") end)
	statRowRefs[statName] = { Label = statLabel, BtnContainer = btnContainer, BtnAdd = bAdd, BtnMax = bMax }
end

function StatsTab.Init(parentFrame, tooltipMgr)
	cachedTooltipMgr = tooltipMgr
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "StatsFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false; MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local mainLayout = Instance.new("UIListLayout", MainFrame); mainLayout.Padding = UDim.new(0, 15); mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; mainLayout.SortOrder = Enum.SortOrder.LayoutOrder; mainLayout.FillDirection = Enum.FillDirection.Vertical 
	local padding = Instance.new("UIPadding", MainFrame); padding.PaddingTop = UDim.new(0, 10); padding.PaddingBottom = UDim.new(0, 20)

	local function SetupPanel(titleTxt, statList, isTitan, layoutOrd)
		local panel = Instance.new("Frame", MainFrame)
		panel.Size = UDim2.new(0.95, 0, 0, 0); panel.AutomaticSize = Enum.AutomaticSize.Y; panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); panel.LayoutOrder = layoutOrd
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", panel).Color = Color3.fromRGB(80, 80, 90)
		local pLayout = Instance.new("UIListLayout", panel); pLayout.SortOrder = Enum.SortOrder.LayoutOrder; pLayout.Padding = UDim.new(0, 5); pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local pPad = Instance.new("UIPadding", panel); pPad.PaddingTop = UDim.new(0, 10); pPad.PaddingBottom = UDim.new(0, 15)

		local header = Instance.new("Frame", panel); header.Size = UDim2.new(1, -10, 0, 30); header.BackgroundTransparency = 1; header.LayoutOrder = 1
		local title = Instance.new("TextLabel", header); title.Size = UDim2.new(0.5, 0, 1, 0); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextSize = 16; title.Text = titleTxt; title.TextColor3 = isTitan and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(200, 200, 220); title.TextXAlignment = Enum.TextXAlignment.Left
		local controls = Instance.new("Frame", header); controls.Size = UDim2.new(0.5, 0, 1, 0); controls.Position = UDim2.new(0.5, 0, 0, 0); controls.BackgroundTransparency = 1
		local cLayout = Instance.new("UIListLayout", controls); cLayout.FillDirection = Enum.FillDirection.Horizontal; cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; cLayout.VerticalAlignment = Enum.VerticalAlignment.Center; cLayout.Padding = UDim.new(0, 5)
		local allBtn = Instance.new("TextButton", controls); allBtn.Size = UDim2.new(0.4, 0, 0.8, 0); allBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 20); allBtn.Text = "ALL"; allBtn.Font = Enum.Font.GothamBold; allBtn.TextColor3 = Color3.new(1,1,1); allBtn.TextSize = 11; Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", allBtn).Color = Color3.fromRGB(220, 150, 50)
		local amtInput = Instance.new("TextBox", controls); amtInput.Size = UDim2.new(0.3, 0, 0.8, 0); amtInput.BackgroundColor3 = Color3.fromRGB(15, 15, 20); amtInput.Text = "1"; amtInput.Font = Enum.Font.GothamBold; amtInput.TextColor3 = Color3.new(1,1,1); amtInput.TextSize = 11; Instance.new("UICorner", amtInput).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", amtInput).Color = Color3.fromRGB(100, 60, 140)
		local ptsLbl = Instance.new("TextLabel", controls); ptsLbl.Size = UDim2.new(0.2, 0, 0.8, 0); ptsLbl.BackgroundTransparency = 1; ptsLbl.Text = "Pts:"; ptsLbl.Font = Enum.Font.GothamMedium; ptsLbl.TextColor3 = Color3.fromRGB(180, 180, 180); ptsLbl.TextSize = 11; ptsLbl.TextXAlignment = Enum.TextXAlignment.Right

		local list = Instance.new("Frame", panel); list.Size = UDim2.new(1, -20, 0, 0); list.AutomaticSize = Enum.AutomaticSize.Y; list.BackgroundTransparency = 1; list.LayoutOrder = 2
		local lLayout = Instance.new("UIListLayout", list); lLayout.SortOrder = Enum.SortOrder.LayoutOrder; lLayout.Padding = UDim.new(0, 8)

		for i, s in ipairs(statList) do CreateStatRow(s, list, isTitan, i, amtInput) end

		local isSpammingAll = false
		allBtn.MouseButton1Click:Connect(function()
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
				if NotificationManager then NotificationManager.Show("Distributed " .. totalUpgrades .. " points evenly!", "Success") end
			else
				if NotificationManager then NotificationManager.Show("Not enough XP to upgrade anything!", "Error") end
			end
			task.wait(0.25); isSpammingAll = false
		end)

		return panel
	end

	local soldierColumn = SetupPanel("SOLDIER VITALITY", playerStatsList, false, 1)
	local titanColumn = SetupPanel("TITAN POTENTIAL", titanStatsList, true, 2)

	local TrainArea = Instance.new("Frame", MainFrame)
	TrainArea.Size = UDim2.new(0.95, 0, 0, 180); TrainArea.BackgroundColor3 = Color3.fromRGB(15, 15, 20); TrainArea.LayoutOrder = 3; TrainArea.ClipsDescendants = true
	Instance.new("UICorner", TrainArea).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", TrainArea).Color = Color3.fromRGB(120, 100, 60)

	local ComboLabel = Instance.new("TextLabel", TrainArea)
	ComboLabel.Size = UDim2.new(1, -20, 0.4, 0); ComboLabel.Position = UDim2.new(0, 10, 0, 10); ComboLabel.BackgroundTransparency = 1; ComboLabel.Font = Enum.Font.GothamBlack; ComboLabel.TextColor3 = isTitan and Color3.fromRGB(255, 150, 100) or Color3.fromRGB(255, 215, 100); ComboLabel.TextSize = 18; ComboLabel.TextXAlignment = Enum.TextXAlignment.Right; ComboLabel.Text = ""; ComboLabel.Visible = false; ComboLabel.RichText = true; ComboLabel.ZIndex = 2
	local MissBtn = Instance.new("TextButton", TrainArea); MissBtn.Size = UDim2.new(1, 0, 1, 0); MissBtn.BackgroundTransparency = 1; MissBtn.Text = ""; MissBtn.ZIndex = 1 
	local BtnContainer = Instance.new("Frame", TrainArea); BtnContainer.Size = UDim2.new(1, 0, 1, 0); BtnContainer.BackgroundTransparency = 1; BtnContainer.ZIndex = 2

	local function CreateFloatingText(textStr, color, startPos)
		local fTxt = Instance.new("TextLabel", TrainArea)
		fTxt.Size = UDim2.new(0, 100, 0, 30); fTxt.Position = startPos; fTxt.AnchorPoint = Vector2.new(0.5, 0.5); fTxt.BackgroundTransparency = 1; fTxt.Font = Enum.Font.GothamBlack; fTxt.TextColor3 = color; fTxt.TextSize = 20; fTxt.Text = textStr; fTxt.ZIndex = 4
		TweenService:Create(fTxt, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = fTxt.Position - UDim2.new(0, 0, 0.3, 0), TextTransparency = 1}):Play(); game.Debris:AddItem(fTxt, 0.6)
	end

	local function CreateTrainBtn(isTitan)
		local tBtn = Instance.new("TextButton", BtnContainer)
		tBtn.Size = UDim2.new(0.25, 0, 0, 45); tBtn.AnchorPoint = Vector2.new(0.5, 0.5); tBtn.Position = isTitan and UDim2.new(0.75, 0, 0.6, 0) or UDim2.new(0.25, 0, 0.6, 0); tBtn.BackgroundColor3 = isTitan and Color3.fromRGB(220, 80, 80) or Color3.fromRGB(80, 220, 80)
		tBtn.Font = Enum.Font.GothamBlack; tBtn.TextColor3 = Color3.fromRGB(20, 20, 20); tBtn.TextScaled = true; tBtn.Text = isTitan and "TITAN" or "SOLDIER"; tBtn.ZIndex = 3 
		Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", tBtn).Color = isTitan and Color3.fromRGB(120, 40, 40) or Color3.fromRGB(40, 120, 40); tBtn.UIStroke.Thickness = 2
		Instance.new("UITextSizeConstraint", tBtn).MaxTextSize = 12

		tBtn.MouseButton1Down:Connect(function()
			local currentPos = tBtn.Position
			if isTitan then titanCombo += 1 else humanCombo += 1 end
			local activeCombo = isTitan and titanCombo or humanCombo

			if activeCombo > 1 then ComboLabel.Visible = true; ComboLabel.Text = "x" .. activeCombo .. " COMBO!" end

			local prestige = player:WaitForChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
			local totalStats = (player:GetAttribute("Strength") or 10) + (player:GetAttribute("Defense") or 10) + (player:GetAttribute("Speed") or 10) + (player:GetAttribute("Resolve") or 10)
			local baseXP = 1 + (prestige * 50) + math.floor(totalStats / 4)
			local xpGain = math.floor(baseXP * (1.0 + (activeCombo * 0.02)))

			CreateFloatingText("+" .. xpGain .. (isTitan and " T-XP" or " XP"), Color3.fromRGB(100, 255, 100), currentPos + UDim2.new(0, 0, 0, 0))
			tBtn.Position = UDim2.new(math.random(10, 90)/100, 0, math.random(15, 85)/100, 0)
			Network.TrainAction:FireServer(activeCombo, isTitan)
		end)
		return tBtn
	end

	local soldierTrainBtn = CreateTrainBtn(false)
	local titanTrainBtn = CreateTrainBtn(true)

	MissBtn.MouseButton1Down:Connect(function()
		if humanCombo > 0 or titanCombo > 0 then
			humanCombo = 0; titanCombo = 0; ComboLabel.Visible = true; ComboLabel.Text = "<font color='#FF5555'>COMBO DROPPED!</font>"
			task.delay(1.5, function() if humanCombo == 0 and titanCombo == 0 then ComboLabel.Visible = false end end)
		end
	end)

	local function UpdateStats()
		local prestigeObj = player:WaitForChild("leaderstats", 5) and player.leaderstats:FindFirstChild("Prestige")
		local prestige = prestigeObj and prestigeObj.Value or 0
		local hXP = player:GetAttribute("XP") or 0; local tXP = player:GetAttribute("TitanXP") or 0
		local statCap = GameData.GetStatCap(prestige)

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
				data.BtnAdd.BackgroundColor3 = Color3.fromRGB(30, 30, 35); data.BtnAdd.TextColor3 = Color3.fromRGB(100, 100, 100); data.BtnAdd.UIStroke.Color = Color3.fromRGB(40, 40, 50)
				data.BtnMax.BackgroundColor3 = Color3.fromRGB(30, 30, 35); data.BtnMax.TextColor3 = Color3.fromRGB(100, 100, 100); data.BtnMax.UIStroke.Color = Color3.fromRGB(40, 40, 50)
			else
				data.Label.Text = cleanName .. ": <font color='" .. (isTitanStat and "#FF5555" or "#FFFFFF") .. "'>" .. val .. "</font>" .. bonusText
				local function toggle(btn, canAfford)
					btn.BackgroundColor3 = canAfford and Color3.fromRGB(30, 25, 35) or Color3.fromRGB(20, 15, 25)
					btn.TextColor3 = canAfford and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)
					btn.UIStroke.Color = canAfford and Color3.fromRGB(140, 60, 200) or Color3.fromRGB(50, 40, 70)
				end
				toggle(data.BtnAdd, (isTitanStat and tXP or hXP) >= cost1)
				toggle(data.BtnMax, (isTitanStat and tXP or hXP) >= cost1)
			end
		end
		task.delay(0.05, function() MainFrame.CanvasSize = UDim2.new(0, 0, 0, mainLayout.AbsoluteContentSize.Y + 20) end)
	end

	player.AttributeChanged:Connect(function(attr) if table.find(playerStatsList, attr) or table.find(titanStatsList, attr) or attr == "XP" or attr == "TitanXP" or attr == "Titan" then UpdateStats() end end)
	UpdateStats()
end

function StatsTab.Show() if MainFrame then MainFrame.Visible = true end end
return StatsTab