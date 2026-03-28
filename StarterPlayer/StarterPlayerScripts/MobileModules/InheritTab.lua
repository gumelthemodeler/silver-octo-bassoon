-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local InheritTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")
local TweenService = game:GetService("TweenService")
local TitanData = require(ReplicatedStorage:WaitForChild("TitanData"))
local EffectsManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("EffectsManager"))
local CinematicManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("CinematicManager"))

local player = Players.LocalPlayer
local MainFrame
local isRolling = { Titan = false, Clan = false }
local isAutoRolling = { Titan = false, Clan = false }

local RarityColors = {
	["Common"] = "#AAAAAA", ["Uncommon"] = "#55FF55", ["Rare"] = "#5588FF",
	["Epic"] = "#CC44FF", ["Legendary"] = "#FFD700", ["Mythical"] = "#FF3333",
	["Transcendent"] = "#FF55FF"
}

local RarityOrder = { Transcendent = 0, Mythical = 1, Legendary = 2, Epic = 3, Rare = 4, Uncommon = 5, Common = 6 }

local ClanVisualBuffs = {
	["None"] = "No inherent abilities.", 
	["Braus"] = "+10% Speed", 
	["Springer"] = "+15% Evasion",
	["Galliard"] = "+15% Speed, +5% Power\n<font color='#FFD700'>[Jaw Titan Synergy]: +25% Spd & Crit</font>", 
	["Braun"] = "+20% Defense\n<font color='#FFD700'>[Armored Titan Synergy]: +50% Armor</font>", 
	["Arlert"] = "+15% Resolve\n<font color='#FFD700'>[Colossal Titan Synergy]: +50% Max HP</font>",
	["Tybur"] = "+20% Titan Power\n<font color='#FFD700'>[War Hammer Synergy]: +30% Dmg</font>", 
	["Yeager"] = "+25% Titan Damage\n<font color='#FFD700'>[Attack Titan Synergy]: +30% Dmg</font>", 
	["Reiss"] = "+50% Base Health",
	["Ackerman"] = "+25% Weapon Damage, Immune to Memory Wipes", 

	["Awakened Galliard"] = "+30% Speed, +15% Power\n<font color='#FFD700'>[Jaw Titan Synergy]: +25% Spd & Crit</font>",
	["Awakened Braun"] = "+40% Defense\n<font color='#FFD700'>[Armored Titan Synergy]: +50% Armor</font>",
	["Awakened Tybur"] = "+40% Titan Power\n<font color='#FFD700'>[War Hammer Synergy]: +30% Dmg</font>",
	["Awakened Yeager"] = "+50% Titan Damage\n<font color='#FFD700'>[Attack Titan Synergy]: +30% Dmg</font>",
	["Awakened Ackerman"] = "+50% Weapon Damage, Extreme Agility"
}

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

local function GetRankColor(rank)
	if rank == "S" then return Color3.fromRGB(255, 215, 0)
	elseif rank == "A" then return Color3.fromRGB(85, 255, 85)
	elseif rank == "B" then return Color3.fromRGB(85, 150, 255)
	elseif rank == "C" then return Color3.fromRGB(170, 85, 255)
	else return Color3.fromRGB(170, 170, 170) end
end

function InheritTab.Init(parentFrame, tooltipMgr)
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "InheritFrame"
	MainFrame.Size = UDim2.new(1, 0, 1, 0)
	MainFrame.BackgroundTransparency = 1
	MainFrame.Visible = false
	MainFrame.ScrollBarThickness = 0
	MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not MainFrame.Visible then
			isAutoRolling.Titan = false
			isAutoRolling.Clan = false
		end
	end)

	local layout = Instance.new("UIListLayout", MainFrame)
	layout.Padding = UDim.new(0, 20)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local pad = Instance.new("UIPadding", MainFrame)
	pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 30)

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 40)
	Title.BackgroundTransparency = 1
	Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 255, 255); Title.TextSize = 24
	Title.Text = "THE PATHS (INHERITANCE)"
	Title.LayoutOrder = 1
	ApplyGradient(Title, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	local function CreateGachaPanel(gType, order)
		local Panel = Instance.new("Frame", MainFrame)
		Panel.Size = UDim2.new(0.95, 0, 0, 520) 
		Panel.BackgroundColor3 = Color3.fromRGB(15, 15, 18) 
		Panel.LayoutOrder = order
		Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 8)
		Instance.new("UIStroke", Panel).Color = Color3.fromRGB(120, 100, 60)

		local PTitle = Instance.new("TextLabel", Panel)
		PTitle.Size = UDim2.new(1, 0, 0, 40)
		PTitle.BackgroundTransparency = 1
		PTitle.Font = Enum.Font.GothamBlack; PTitle.TextColor3 = Color3.fromRGB(255, 215, 100); PTitle.TextSize = 20
		PTitle.Text = (gType == "Titan") and "TITAN INHERITANCE" or "CLAN LINEAGE"

		local ListContainer = Instance.new("ScrollingFrame", Panel)
		ListContainer.Size = UDim2.new(1, -20, 0, 250)
		ListContainer.Position = UDim2.new(0, 10, 0, 45)
		ListContainer.BackgroundTransparency = 1
		ListContainer.ScrollBarThickness = 4
		ListContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
		local SList = Instance.new("UIListLayout", ListContainer); SList.Padding = UDim.new(0, 8)

		if gType == "Titan" then
			local sortedTitans = {}
			for tName, tData in pairs(TitanData.Titans) do table.insert(sortedTitans, tData) end
			table.sort(sortedTitans, function(a, b) return RarityOrder[a.Rarity] < RarityOrder[b.Rarity] end)

			for _, drop in ipairs(sortedTitans) do
				local cColor = RarityColors[drop.Rarity] or "#FFFFFF"
				local rarityRGB = Color3.fromHex(cColor:gsub("#", ""))

				local card = Instance.new("Frame", ListContainer)
				card.Size = UDim2.new(1, -10, 0, 80)
				card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
				Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

				local stroke = Instance.new("UIStroke", card)
				stroke.Color = rarityRGB; stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

				local accentBar = Instance.new("Frame", card)
				accentBar.Size = UDim2.new(1, 0, 0, 3); accentBar.BackgroundColor3 = rarityRGB; accentBar.BorderSizePixel = 0

				local bgGlow = Instance.new("Frame", card)
				bgGlow.Size = UDim2.new(1, 0, 0.5, 0); bgGlow.Position = UDim2.new(0, 0, 0.5, 0); bgGlow.BackgroundColor3 = rarityRGB; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1

				local countInRarity = 0
				for _, t in pairs(TitanData.Titans) do if t.Rarity == drop.Rarity then countInRarity += 1 end end
				local pct = (TitanData.Rarities[drop.Rarity] and (TitanData.Rarities[drop.Rarity] / countInRarity)) or 0
				local pctStr = pct > 0 and (" (" .. string.format("%.1f", pct) .. "%)") or " (Fusion Exclusive)"

				local titleLbl = Instance.new("TextLabel", card)
				titleLbl.Size = UDim2.new(1, -20, 0, 20); titleLbl.Position = UDim2.new(0, 10, 0, 10); titleLbl.BackgroundTransparency = 1
				titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextColor3 = Color3.fromRGB(230, 230, 230); titleLbl.TextSize = 13; titleLbl.TextXAlignment = Enum.TextXAlignment.Left
				titleLbl.RichText = true; titleLbl.Text = "<b><font color='" .. cColor .. "'>[" .. drop.Rarity .. "] " .. drop.Name .. "</font></b><font color='#888888'>" .. pctStr .. "</font>"

				local statsArea = Instance.new("Frame", card)
				statsArea.Size = UDim2.new(1, -20, 0, 35); statsArea.Position = UDim2.new(0, 10, 0, 35); statsArea.BackgroundTransparency = 1
				local saLayout = Instance.new("UIListLayout", statsArea); saLayout.FillDirection = Enum.FillDirection.Horizontal; saLayout.Padding = UDim.new(0, 4)

				local s = drop.Stats
				local statsOrder = { {Name="POW", Val=s.Power}, {Name="SPD", Val=s.Speed}, {Name="HRD", Val=s.Hardening}, {Name="END", Val=s.Endurance}, {Name="PRE", Val=s.Precision}, {Name="POT", Val=s.Potential} }

				for _, st in ipairs(statsOrder) do
					local sBox = Instance.new("Frame", statsArea)
					sBox.Size = UDim2.new(0, 42, 1, 0); sBox.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
					Instance.new("UICorner", sBox).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", sBox).Color = Color3.fromRGB(40, 40, 50)

					local sName = Instance.new("TextLabel", sBox)
					sName.Size = UDim2.new(1, 0, 0.5, 0); sName.BackgroundTransparency = 1; sName.Font = Enum.Font.GothamMedium; sName.TextColor3 = Color3.fromRGB(150, 150, 150); sName.TextSize = 8; sName.Text = st.Name

					local sVal = Instance.new("TextLabel", sBox)
					sVal.Size = UDim2.new(1, 0, 0.5, 0); sVal.Position = UDim2.new(0, 0, 0.5, 0); sVal.BackgroundTransparency = 1; sVal.Font = Enum.Font.GothamBlack; sVal.TextColor3 = GetRankColor(st.Val); sVal.TextSize = 12; sVal.Text = st.Val
				end
			end
		else
			local sortedClans = {}
			for cName, weight in pairs(TitanData.ClanWeights) do table.insert(sortedClans, {Name = cName, Weight = weight}) end

			local awakenedClans = {"Awakened Galliard", "Awakened Braun", "Awakened Tybur", "Awakened Yeager", "Awakened Ackerman"}
			for _, cName in ipairs(awakenedClans) do
				table.insert(sortedClans, {Name = cName, Weight = 0})
			end

			table.sort(sortedClans, function(a, b) 
				if a.Weight == 0 and b.Weight ~= 0 then return true end
				if b.Weight == 0 and a.Weight ~= 0 then return false end
				return a.Weight < b.Weight 
			end)

			for _, drop in ipairs(sortedClans) do
				local rarityTag = "Common"
				if drop.Weight == 0 then rarityTag = "Transcendent"
				elseif drop.Weight <= 1.5 then rarityTag = "Mythical" 
				elseif drop.Weight <= 4.0 then rarityTag = "Legendary" 
				elseif drop.Weight <= 8.0 then rarityTag = "Epic" 
				elseif drop.Weight <= 15.0 then rarityTag = "Rare" 
				end

				local cColor = RarityColors[rarityTag] or "#FFFFFF"
				local rarityRGB = Color3.fromHex(cColor:gsub("#", ""))
				local buffText = ClanVisualBuffs[drop.Name] or "Unknown"

				local card = Instance.new("Frame", ListContainer)
				card.Size = UDim2.new(1, -10, 0, 60)
				card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
				Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

				local stroke = Instance.new("UIStroke", card)
				stroke.Color = rarityRGB; stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

				local accentBar = Instance.new("Frame", card)
				accentBar.Size = UDim2.new(1, 0, 0, 3); accentBar.BackgroundColor3 = rarityRGB; accentBar.BorderSizePixel = 0

				local bgGlow = Instance.new("Frame", card)
				bgGlow.Size = UDim2.new(1, 0, 0.5, 0); bgGlow.Position = UDim2.new(0, 0, 0.5, 0); bgGlow.BackgroundColor3 = rarityRGB; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1

				local titleLbl = Instance.new("TextLabel", card)
				titleLbl.Size = UDim2.new(1, -20, 0, 20); titleLbl.Position = UDim2.new(0, 10, 0, 10); titleLbl.BackgroundTransparency = 1
				titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextColor3 = Color3.fromRGB(230, 230, 230); titleLbl.TextSize = 13; titleLbl.TextXAlignment = Enum.TextXAlignment.Left

				local pctStr = drop.Weight > 0 and (" (" .. string.format("%.1f", drop.Weight) .. "%)") or " (Awakening Exclusive)"
				titleLbl.RichText = true; titleLbl.Text = "<b><font color='" .. cColor .. "'>[" .. rarityTag .. "] " .. drop.Name .. "</font></b><font color='#888888'>" .. pctStr .. "</font>"

				local descLbl = Instance.new("TextLabel", card)
				descLbl.Size = UDim2.new(1, -20, 0, 20); descLbl.Position = UDim2.new(0, 10, 0, 32); descLbl.BackgroundTransparency = 1
				descLbl.Font = Enum.Font.GothamMedium; descLbl.TextColor3 = Color3.fromRGB(150, 255, 150); descLbl.TextSize = 11; descLbl.TextXAlignment = Enum.TextXAlignment.Left
				descLbl.RichText = true; descLbl.Text = buffText
			end
		end

		task.delay(0.05, function() ListContainer.CanvasSize = UDim2.new(0, 0, 0, SList.AbsoluteContentSize.Y + 10) end)

		local BottomArea = Instance.new("Frame", Panel)
		BottomArea.Size = UDim2.new(1, 0, 0, 210); BottomArea.Position = UDim2.new(0, 0, 0, 305); BottomArea.BackgroundTransparency = 1

		local ResultLbl = Instance.new("TextLabel", BottomArea)
		ResultLbl.Size = UDim2.new(1, 0, 0, 30); ResultLbl.Position = UDim2.new(0, 0, 0, 0); ResultLbl.BackgroundTransparency = 1
		ResultLbl.Font = Enum.Font.GothamBlack; ResultLbl.TextColor3 = Color3.fromRGB(255, 255, 255); ResultLbl.TextSize = 18
		ResultLbl.RichText = true; ResultLbl.Text = "Current: None"

		local StorageArea = Instance.new("Frame", BottomArea)
		StorageArea.Size = UDim2.new(0.9, 0, 0, 50); StorageArea.Position = UDim2.new(0.05, 0, 0, 35); StorageArea.BackgroundTransparency = 1
		local sg = Instance.new("UIGridLayout", StorageArea); sg.CellSize = UDim2.new(0.15, 0, 1, 0); sg.CellPadding = UDim2.new(0.02, 0, 0, 0); sg.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local storageBtns = {}
		for i = 1, 6 do
			local sBtn = Instance.new("TextButton", StorageArea)
			sBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28); sBtn.Font = Enum.Font.GothamBold; sBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
			sBtn.TextScaled = true; Instance.new("UITextSizeConstraint", sBtn).MaxTextSize = 11; sBtn.TextWrapped = true
			Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 6)
			local stroke = Instance.new("UIStroke", sBtn); stroke.Color = Color3.fromRGB(60, 60, 70); stroke.Thickness = 1; stroke.LineJoinMode = Enum.LineJoinMode.Miter; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local accentBar = Instance.new("Frame", sBtn); accentBar.Size = UDim2.new(1, 0, 0, 3); accentBar.BackgroundColor3 = Color3.fromRGB(60, 60, 70); accentBar.BorderSizePixel = 0

			sBtn.MouseButton1Click:Connect(function()
				if i > 3 and not player:GetAttribute("Has" .. gType .. "Vault") then
					if tooltipMgr and type(tooltipMgr.Show) == "function" then tooltipMgr.Show("<font color='#FF5555'>Locked. Requires Vault Expansion Gamepass!</font>") end
					task.delay(1.5, function() if tooltipMgr and type(tooltipMgr.Hide) == "function" then tooltipMgr.Hide() end end)
					return
				end
				Network.ManageStorage:FireServer(gType, i)
			end)
			storageBtns[i] = { Btn = sBtn, Stroke = stroke, Accent = accentBar }
		end

		local PityLbl = Instance.new("TextLabel", BottomArea)
		PityLbl.Size = UDim2.new(1, 0, 0, 20); PityLbl.Position = UDim2.new(0, 0, 0, 100); PityLbl.BackgroundTransparency = 1
		PityLbl.Font = Enum.Font.GothamBold; PityLbl.TextColor3 = Color3.fromRGB(200, 150, 255); PityLbl.TextSize = 14; PityLbl.Text = "PITY: 0 / 100"

		local RollActions = Instance.new("Frame", BottomArea)
		RollActions.Size = UDim2.new(0.9, 0, 0, 50); RollActions.Position = UDim2.new(0.05, 0, 0, 130); RollActions.BackgroundTransparency = 1
		local raLayout = Instance.new("UIListLayout", RollActions); raLayout.FillDirection = Enum.FillDirection.Horizontal; raLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; raLayout.Padding = UDim.new(0.03, 0)

		local RollBtn = Instance.new("TextButton", RollActions)
		RollBtn.Size = UDim2.new(0.3, 0, 1, 0); RollBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40); RollBtn.Font = Enum.Font.GothamBold; RollBtn.TextColor3 = Color3.fromRGB(255, 255, 255); RollBtn.TextScaled = true
		Instance.new("UITextSizeConstraint", RollBtn).MaxTextSize = 11
		local labelPrefix = (gType == "Titan") and "Serum" or "Vial"
		RollBtn.Text = "ROLL (1x " .. labelPrefix .. ")\nOwned: 0"
		Instance.new("UICorner", RollBtn).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", RollBtn).Color = Color3.fromRGB(80, 150, 80)

		local PremiumRollBtn = Instance.new("TextButton", RollActions)
		PremiumRollBtn.Size = UDim2.new(0.3, 0, 1, 0); PremiumRollBtn.BackgroundColor3 = Color3.fromRGB(150, 120, 40); PremiumRollBtn.Font = Enum.Font.GothamBold; PremiumRollBtn.TextColor3 = Color3.fromRGB(255, 255, 255); PremiumRollBtn.TextScaled = true
		Instance.new("UITextSizeConstraint", PremiumRollBtn).MaxTextSize = 11
		Instance.new("UICorner", PremiumRollBtn).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", PremiumRollBtn).Color = Color3.fromRGB(200, 150, 50)
		if gType == "Titan" then PremiumRollBtn.Text = "PREMIUM (1x Syringe)\nOwned: 0" else PremiumRollBtn.Text = "N/A"; PremiumRollBtn.Visible = false end

		local AutoRollBtn = Instance.new("TextButton", RollActions)
		AutoRollBtn.Size = UDim2.new(0.3, 0, 1, 0); AutoRollBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 120); AutoRollBtn.Font = Enum.Font.GothamBold; AutoRollBtn.TextColor3 = Color3.fromRGB(255, 255, 255); AutoRollBtn.TextScaled = true; AutoRollBtn.Text = "ROLL TILL LEGENDARY+"
		Instance.new("UITextSizeConstraint", AutoRollBtn).MaxTextSize = 11
		Instance.new("UICorner", AutoRollBtn).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", AutoRollBtn).Color = Color3.fromRGB(150, 80, 150)

		local attrReq = (gType == "Titan") and "StandardTitanSerumCount" or "ClanBloodVialCount"

		RollBtn.MouseButton1Click:Connect(function()
			if isRolling[gType] or isAutoRolling[gType] then return end
			local count = player:GetAttribute(attrReq) or 0
			if count > 0 then
				isRolling[gType] = true
				Network.GachaRoll:FireServer(gType, false)
			else
				ResultLbl.Text = "<font color='#FF5555'>Not enough items!</font>"
				if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Error", 1) end
				task.delay(1.5, function() if not isRolling[gType] then ResultLbl.Text = "Current: " .. (player:GetAttribute(gType) or "None") end end)
			end
		end)

		PremiumRollBtn.MouseButton1Click:Connect(function()
			if isRolling[gType] or isAutoRolling[gType] then return end
			local count = player:GetAttribute("SpinalFluidSyringeCount") or 0
			if count > 0 then
				isRolling[gType] = true
				Network.GachaRoll:FireServer(gType, true)
			else
				ResultLbl.Text = "<font color='#FF5555'>Not enough items!</font>"
				if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Error", 1) end
				task.delay(1.5, function() if not isRolling[gType] then ResultLbl.Text = "Current: " .. (player:GetAttribute(gType) or "None") end end)
			end
		end)

		AutoRollBtn.MouseButton1Click:Connect(function()
			if isRolling[gType] or isAutoRolling[gType] then return end
			local count = player:GetAttribute(attrReq) or 0
			if count > 0 then
				isAutoRolling[gType] = true
				isRolling[gType] = true
				ResultLbl.Text = "<i>Auto-Rolling...</i>"
				Network.GachaRoll:FireServer(gType, false)
			else
				ResultLbl.Text = "<font color='#FF5555'>Not enough items!</font>"
				if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Error", 1) end
				task.delay(1.5, function() if not isRolling[gType] then ResultLbl.Text = "Current: " .. (player:GetAttribute(gType) or "None") end end)
			end
		end)

		return ResultLbl, PityLbl, RollBtn, PremiumRollBtn, AutoRollBtn, storageBtns
	end

	local tResult, tPity, tRoll, tPrem, tAuto, tStores = CreateGachaPanel("Titan", 1)
	local cResult, cPity, cRoll, cPrem, cAuto, cStores = CreateGachaPanel("Clan", 2)

	local function UpdateUI()
		if not isRolling.Titan and not isAutoRolling.Titan then tResult.Text = "Current: " .. (player:GetAttribute("Titan") or "None") end
		if not isRolling.Clan and not isAutoRolling.Clan then cResult.Text = "Current: " .. (player:GetAttribute("Clan") or "None") end

		for i = 1, 6 do
			local tStoreName = player:GetAttribute("Titan_Slot"..i) or "None"
			local cStoreName = player:GetAttribute("Clan_Slot"..i) or "None"

			local function styleVaultSlot(storeObj, storedName, hasVault, isTitanType)
				local btn = storeObj.Btn
				if i > 3 and not hasVault then 
					btn.Text = "🔒"; storeObj.Stroke.Color = Color3.fromRGB(80, 40, 40); storeObj.Accent.BackgroundColor3 = Color3.fromRGB(80, 40, 40); btn.TextColor3 = Color3.fromRGB(200, 100, 100)
				else 
					btn.Text = (storedName == "None" and "Empty" or storedName)
					if storedName ~= "None" then
						local rarity = "Common"
						if isTitanType then
							local tData = TitanData.Titans[storedName]
							if tData then rarity = tData.Rarity end
						else
							if string.find(storedName, "Awakened") then
								rarity = "Transcendent"
							else
								local weight = TitanData.ClanWeights[storedName] or 40
								if weight <= 1.5 then rarity = "Mythical" elseif weight <= 4.0 then rarity = "Legendary" elseif weight <= 8.0 then rarity = "Epic" elseif weight <= 15.0 then rarity = "Rare" end
							end
						end
						local cColor = Color3.fromHex((RarityColors[rarity] or "#FFFFFF"):gsub("#",""))
						storeObj.Stroke.Color = cColor; storeObj.Accent.BackgroundColor3 = cColor; btn.TextColor3 = Color3.fromRGB(230, 230, 230)
					else
						storeObj.Stroke.Color = Color3.fromRGB(60, 60, 70); storeObj.Accent.BackgroundColor3 = Color3.fromRGB(60, 60, 70); btn.TextColor3 = Color3.fromRGB(150, 150, 150)
					end
				end
			end

			styleVaultSlot(tStores[i], tStoreName, player:GetAttribute("HasTitanVault"), true)
			styleVaultSlot(cStores[i], cStoreName, player:GetAttribute("HasClanVault"), false)
		end

		tPity.Text = "PITY: " .. (player:GetAttribute("TitanPity") or 0) .. " / 100"
		cPity.Text = "PITY: " .. (player:GetAttribute("ClanPity") or 0) .. " / 100"

		tRoll.Text = "ROLL (1x Serum)\nOwned: " .. (player:GetAttribute("StandardTitanSerumCount") or 0)
		tPrem.Text = "PREMIUM (1x Syringe)\nOwned: " .. (player:GetAttribute("SpinalFluidSyringeCount") or 0)
		cRoll.Text = "ROLL (1x Vial)\nOwned: " .. (player:GetAttribute("ClanBloodVialCount") or 0)
	end

	player.AttributeChanged:Connect(UpdateUI)
	UpdateUI()

	Network.GachaResult.OnClientEvent:Connect(function(gType, resultName, resultRarity)
		local targetLbl = (gType == "Titan") and tResult or cResult
		local names = {}
		if gType == "Titan" then for tName, _ in pairs(TitanData.Titans) do table.insert(names, tName) end
		else for cName, _ in pairs(TitanData.ClanWeights) do table.insert(names, cName) end end

		for i = 1, 20 do 
			if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Spin", 1 + (i/25)) end
			targetLbl.Text = names[math.random(1, #names)]
			task.wait(0.05) 
		end

		local cColor = RarityColors[resultRarity] or "#FFFFFF"
		targetLbl.Text = "<b><font color='" .. cColor .. "'>" .. resultName:upper() .. "!</font></b>"
		if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Reveal", 1) end

		if resultRarity == "Mythical" or resultRarity == "Transcendent" then
			local cinemColor = (resultRarity == "Mythical") and "#FF3333" or "#FF55FF"
			local titleText = (gType == "Titan") and "A PRIMORDIAL POWER AWAKENS" or "AN ANCIENT BLOODLINE"
			if CinematicManager and type(CinematicManager.Show) == "function" then CinematicManager.Show(titleText, resultName, cinemColor) end
		end

		task.wait(1.5)

		if isAutoRolling[gType] and MainFrame.Visible then
			if resultRarity == "Legendary" or resultRarity == "Mythical" or resultRarity == "Transcendent" then
				isAutoRolling[gType] = false
				isRolling[gType] = false
				UpdateUI()
			else
				local attrReq = (gType == "Titan") and "StandardTitanSerumCount" or "ClanBloodVialCount"
				if (player:GetAttribute(attrReq) or 0) > 0 then
					targetLbl.Text = "<i>Auto-Rolling...</i>"
					Network.GachaRoll:FireServer(gType, false)
				else
					isAutoRolling[gType] = false
					isRolling[gType] = false
					targetLbl.Text = "<font color='#FF5555'>Out of items!</font>"
					task.delay(1.5, function() if not isRolling[gType] then UpdateUI() end end)
				end
			end
		else
			isRolling[gType] = false
			UpdateUI()
		end
	end)
end

function InheritTab.Show()
	if MainFrame then MainFrame.Visible = true end
end

return InheritTab