-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local ForgeTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local NotificationManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("NotificationManager"))
local CinematicManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("CinematicManager"))

local player = Players.LocalPlayer
local MainFrame
local ContentArea
local SubTabs = {}
local SubBtns = {}

local selectedCraftingRecipe = nil
local selectedWeapon = nil
local selectedFusionSlot = nil
local expectedFusionResult = nil

-- UI References
local ingBoxName, ingBoxCount, ingStroke, ingTagBox, ingTagTxt
local dewsBoxCount, dewsStroke, dewsTagBox
local resBoxName, resStroke, resTagBox, resTagTxt
local craftBtn
local rightPanelName, rightPanelStats, awakenBtn, extractCountLbl
local fusionBaseLbl, fusionSacrificeLbl, fusionResultLbl, fuseBtn
local RecipeList, CraftInvGrid

local RarityColors = { ["Common"] = "#AAAAAA", ["Uncommon"] = "#55FF55", ["Rare"] = "#5588FF", ["Epic"] = "#CC44FF", ["Legendary"] = "#FFD700", ["Mythical"] = "#FF3333", ["Transcendent"] = "#FF55FF" }
local RarityOrder = { Transcendent = 0, Mythical = 1, Legendary = 2, Epic = 3, Rare = 4, Uncommon = 5, Common = 6 }

local FusionRecipes = { 
	["Female Titan"] = { ["Founding Titan"] = "Founding Female Titan" }, 
	["Founding Titan"] = { ["Female Titan"] = "Founding Female Titan" }, 
	["Attack Titan"] = { ["Armored Titan"] = "Armored Attack Titan", ["War Hammer Titan"] = "War Hammer Attack Titan" }, 
	["Armored Titan"] = { ["Attack Titan"] = "Armored Attack Titan" }, 
	["War Hammer Titan"] = { ["Attack Titan"] = "War Hammer Attack Titan" }, 
	["Colossal Titan"] = { ["Jaw Titan"] = "Colossal Jaw Titan" }, 
	["Jaw Titan"] = { ["Colossal Titan"] = "Colossal Jaw Titan" } 
}

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

-- [[ Premium Dark Gradient Helper ]]
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
		btn:GetPropertyChangedSignal("RichText"):Connect(function() textLbl.RichText = btn.RichText end)
		btn:GetPropertyChangedSignal("TextSize"):Connect(function() textLbl.TextSize = btn.TextSize end)
	end
end

local function TweenGradient(grad, targetTop, targetBot, duration)
	local startTop = grad.Color.Keypoints[1].Value
	local startBot = grad.Color.Keypoints[#grad.Color.Keypoints].Value
	local val = Instance.new("NumberValue")
	val.Value = 0
	local tween = TweenService:Create(val, TweenInfo.new(duration), {Value = 1})
	val.Changed:Connect(function(v)
		grad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, startTop:Lerp(targetTop, v)),
			ColorSequenceKeypoint.new(1, startBot:Lerp(targetBot, v))
		}
	end)
	tween:Play()
	tween.Completed:Connect(function() val:Destroy() end)
end

function ForgeTab.Init(parentFrame, tooltipMgr)
	local cachedTooltipMgr = tooltipMgr
	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "ForgeFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local TopNav = Instance.new("ScrollingFrame", MainFrame)
	TopNav.Size = UDim2.new(1, 0, 0, 45); TopNav.BackgroundColor3 = Color3.fromRGB(15, 15, 18); TopNav.ScrollBarThickness = 0; TopNav.ScrollingDirection = Enum.ScrollingDirection.X
	Instance.new("UICorner", TopNav).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", TopNav).Color = Color3.fromRGB(120, 100, 60)
	local navLayout = Instance.new("UIListLayout", TopNav); navLayout.FillDirection = Enum.FillDirection.Horizontal; navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left; navLayout.VerticalAlignment = Enum.VerticalAlignment.Center; navLayout.Padding = UDim.new(0, 10)
	local navPad = Instance.new("UIPadding", TopNav); navPad.PaddingLeft = UDim.new(0, 10); navPad.PaddingRight = UDim.new(0, 10)

	navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TopNav.CanvasSize = UDim2.new(0, navLayout.AbsoluteContentSize.X + 20, 0, 0) end)

	ContentArea = Instance.new("Frame", MainFrame)
	ContentArea.Size = UDim2.new(1, 0, 1, -55); ContentArea.Position = UDim2.new(0, 0, 0, 55); ContentArea.BackgroundTransparency = 1

	local function CreateSubNavBtn(name, text)
		local btn = Instance.new("TextButton", TopNav)
		btn.Size = UDim2.new(0, 130, 0, 30); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(180, 180, 180); btn.TextSize = 11; btn.Text = text
		ApplyButtonGradient(btn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 65))

		btn.MouseButton1Click:Connect(function()
			for k, v in pairs(SubBtns) do 
				local cGrad = v:FindFirstChildOfClass("UIGradient")
				if cGrad then TweenGradient(cGrad, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), 0.2) end
				TweenService:Create(v, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play() 
			end
			local grad = btn:FindFirstChildOfClass("UIGradient")
			if grad then TweenGradient(grad, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), 0.2) end
			TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()

			for k, frame in pairs(SubTabs) do frame.Visible = (k == name) end
		end)
		SubBtns[name] = btn
		return btn
	end

	CreateSubNavBtn("Crafting", "CRAFTING")
	CreateSubNavBtn("Awakening", "AWAKENING")
	CreateSubNavBtn("Fusion", "TITAN FUSION")

	-- ==========================================
	-- [[ 1. CRAFTING TAB ]]
	-- ==========================================
	SubTabs["Crafting"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Crafting"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Crafting"].BackgroundTransparency = 1; SubTabs["Crafting"].Visible = true; SubTabs["Crafting"].ScrollBarThickness = 0
	local cMasterLayout = Instance.new("UIListLayout", SubTabs["Crafting"]); cMasterLayout.Padding = UDim.new(0, 15); cMasterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; cMasterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local cMasterPad = Instance.new("UIPadding", SubTabs["Crafting"]); cMasterPad.PaddingBottom = UDim.new(0, 20)

	local WorkbenchPanel = Instance.new("Frame", SubTabs["Crafting"])
	WorkbenchPanel.Size = UDim2.new(0.95, 0, 0, 170); WorkbenchPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); WorkbenchPanel.LayoutOrder = 1
	Instance.new("UICorner", WorkbenchPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", WorkbenchPanel).Color = Color3.fromRGB(100, 150, 255)

	local wbTitle = Instance.new("TextLabel", WorkbenchPanel)
	wbTitle.Size = UDim2.new(1, 0, 0, 25); wbTitle.Position = UDim2.new(0, 0, 0, 5); wbTitle.BackgroundTransparency = 1; wbTitle.Font = Enum.Font.GothamBlack; wbTitle.TextColor3 = Color3.fromRGB(150, 200, 255); wbTitle.TextSize = 14; wbTitle.Text = "WORKBENCH"

	local FormulaArea = Instance.new("Frame", WorkbenchPanel)
	FormulaArea.Size = UDim2.new(1, 0, 0, 75); FormulaArea.Position = UDim2.new(0, 0, 0, 30); FormulaArea.BackgroundTransparency = 1
	local fLayout = Instance.new("UIListLayout", FormulaArea); fLayout.FillDirection = Enum.FillDirection.Horizontal; fLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; fLayout.VerticalAlignment = Enum.VerticalAlignment.Center; fLayout.Padding = UDim.new(0, 5)
	fLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local function CreateStationSquare(parent, rarityColor, isDews, lOrder)
		local sq = Instance.new("Frame", parent)
		sq.Size = UDim2.new(0, 70, 0, 70); sq.BackgroundColor3 = Color3.fromRGB(22, 22, 28); sq.LayoutOrder = lOrder
		local stroke = Instance.new("UIStroke", sq); stroke.Color = Color3.fromHex(rarityColor:gsub("#","")); stroke.Thickness = 2; stroke.LineJoinMode = Enum.LineJoinMode.Miter; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local tBox, tTxt
		if not isDews then
			tBox = Instance.new("Frame", sq); tBox.Size = UDim2.new(0, 14, 0, 14); tBox.Position = UDim2.new(0, 4, 0, 4); tBox.BackgroundColor3 = stroke.Color
			Instance.new("UICorner", tBox).CornerRadius = UDim.new(0, 4)
			tTxt = Instance.new("TextLabel", tBox); tTxt.Size = UDim2.new(1, 0, 1, 0); tTxt.BackgroundTransparency = 1; tTxt.Font = Enum.Font.GothamBlack; tTxt.TextColor3 = Color3.new(0,0,0); tTxt.TextSize = 9; tTxt.Text = "?"
		end

		local nameLbl = Instance.new("TextLabel", sq); nameLbl.Size = UDim2.new(0.9, 0, 0.45, 0); nameLbl.Position = UDim2.new(0.5, 0, 0.5, 0); nameLbl.AnchorPoint = Vector2.new(0.5, 0.5); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230); nameLbl.TextScaled = true; nameLbl.TextWrapped = true; nameLbl.Text = isDews and "DEWS" or "???"
		if isDews then nameLbl.TextColor3 = Color3.fromRGB(255, 215, 100); nameLbl.Font = Enum.Font.GothamBlack end
		local tCon = Instance.new("UITextSizeConstraint", nameLbl); tCon.MaxTextSize = isDews and 16 or 10; tCon.MinTextSize = 6

		local cntLbl = Instance.new("TextLabel", sq); cntLbl.Size = UDim2.new(1, -4, 0, 15); cntLbl.Position = UDim2.new(0, 2, 1, -15); cntLbl.BackgroundTransparency = 1; cntLbl.Font = Enum.Font.GothamBold; cntLbl.TextColor3 = Color3.fromRGB(150, 150, 150); cntLbl.TextSize = 8; cntLbl.TextXAlignment = Enum.TextXAlignment.Center; cntLbl.Text = isDews and "Cost: 0" or "Req: 0"; cntLbl.RichText = true

		return sq, nameLbl, cntLbl, stroke, tBox, tTxt
	end

	local function CreateMathSym(parent, sym, lOrder)
		local lbl = Instance.new("TextLabel", parent); lbl.Size = UDim2.new(0, 15, 0, 70); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBlack; lbl.TextColor3 = Color3.fromRGB(150, 150, 150); lbl.TextSize = 20; lbl.Text = sym; lbl.LayoutOrder = lOrder
		return lbl
	end

	local IngBox; IngBox, ingBoxName, ingBoxCount, ingStroke, ingTagBox, ingTagTxt = CreateStationSquare(FormulaArea, "#FFFFFF", false, 1)
	CreateMathSym(FormulaArea, "+", 2)
	local DewsBox; DewsBox, _, dewsBoxCount, dewsStroke = CreateStationSquare(FormulaArea, "#FFD700", true, 3)
	CreateMathSym(FormulaArea, "=", 4)
	local ResBox; ResBox, resBoxName, _, resStroke, resTagBox, resTagTxt = CreateStationSquare(FormulaArea, "#FFFFFF", false, 5)
	ResBox.BackgroundColor3 = Color3.fromRGB(35, 30, 30)

	craftBtn = Instance.new("TextButton", WorkbenchPanel)
	craftBtn.Size = UDim2.new(0.8, 0, 0, 35); craftBtn.Position = UDim2.new(0.1, 0, 1, -45); craftBtn.Font = Enum.Font.GothamBlack; craftBtn.TextColor3 = Color3.fromRGB(255, 255, 255); craftBtn.TextSize = 14; craftBtn.Text = "SELECT BLUEPRINT"
	ApplyButtonGradient(craftBtn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(80, 80, 90))

	craftBtn.MouseButton1Click:Connect(function()
		if selectedCraftingRecipe then Network:WaitForChild("ForgeItem"):FireServer(selectedCraftingRecipe) end
	end)

	local listTitle = Instance.new("TextLabel", SubTabs["Crafting"])
	listTitle.Size = UDim2.new(0.95, 0, 0, 30); listTitle.BackgroundTransparency = 1; listTitle.Font = Enum.Font.GothamBlack; listTitle.TextColor3 = Color3.fromRGB(255, 215, 100); listTitle.TextSize = 16; listTitle.Text = "BLUEPRINTS"; listTitle.LayoutOrder = 2
	ApplyGradient(listTitle, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	RecipeList = Instance.new("Frame", SubTabs["Crafting"])
	RecipeList.Size = UDim2.new(0.95, 0, 0, 0); RecipeList.BackgroundTransparency = 1; RecipeList.LayoutOrder = 3
	local recLayout = Instance.new("UIListLayout", RecipeList); recLayout.Padding = UDim.new(0, 8); recLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	recLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RecipeList.Size = UDim2.new(0.95, 0, 0, recLayout.AbsoluteContentSize.Y) end)

	local InvTitleLbl = Instance.new("TextLabel", SubTabs["Crafting"])
	InvTitleLbl.Size = UDim2.new(0.95, 0, 0, 30); InvTitleLbl.BackgroundTransparency = 1; InvTitleLbl.Font = Enum.Font.GothamBlack; InvTitleLbl.TextColor3 = Color3.fromRGB(255, 215, 100); InvTitleLbl.TextSize = 16; InvTitleLbl.Text = "YOUR INVENTORY"; InvTitleLbl.LayoutOrder = 4

	CraftInvGrid = Instance.new("Frame", SubTabs["Crafting"])
	CraftInvGrid.Size = UDim2.new(0.95, 0, 0, 0); CraftInvGrid.BackgroundColor3 = Color3.fromRGB(20, 20, 25); CraftInvGrid.LayoutOrder = 5
	local cigLayout = Instance.new("UIGridLayout", CraftInvGrid); cigLayout.CellSize = UDim2.new(0.22, 0, 0, 75); cigLayout.CellPadding = UDim2.new(0.04, 0, 0, 10); cigLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; cigLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local cigPad = Instance.new("UIPadding", CraftInvGrid); cigPad.PaddingTop = UDim.new(0, 15); cigPad.PaddingBottom = UDim.new(0, 15)
	Instance.new("UICorner", CraftInvGrid).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", CraftInvGrid).Color = Color3.fromRGB(80, 80, 90)

	cigLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() CraftInvGrid.Size = UDim2.new(0.95, 0, 0, cigLayout.AbsoluteContentSize.Y + 30) end)

	local function RenderCrafting()
		for _, child in ipairs(RecipeList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
		for reqItem, recipe in pairs(ItemData.ForgeRecipes) do
			local resData = ItemData.Equipment[recipe.Result] or ItemData.Consumables[recipe.Result]
			if not resData then continue end

			local rColor = RarityColors[resData.Rarity or "Common"] or "#FFFFFF"
			local safeReq = reqItem:gsub("[^%w]", "") .. "Count"
			local pHas = player:GetAttribute(safeReq) or 0

			local btn = Instance.new("TextButton", RecipeList)
			btn.Size = UDim2.new(1, 0, 0, 45); btn.Text = ""
			ApplyButtonGradient(btn, Color3.fromRGB(35, 35, 40), Color3.fromRGB(20, 20, 25), Color3.fromRGB(60, 60, 70))

			local tagBox = Instance.new("Frame", btn); tagBox.Size = UDim2.new(0, 14, 0, 14); tagBox.Position = UDim2.new(0, 6, 0, 6); tagBox.BackgroundColor3 = Color3.fromHex(rColor:gsub("#","")); Instance.new("UICorner", tagBox).CornerRadius = UDim.new(0, 4)
			local tagTxt = Instance.new("TextLabel", tagBox); tagTxt.Size = UDim2.new(1, 0, 1, 0); tagTxt.BackgroundTransparency = 1; tagTxt.Font = Enum.Font.GothamBlack; tagTxt.TextColor3 = Color3.new(0,0,0); tagTxt.TextSize = 9; tagTxt.Text = string.sub(resData.Rarity or "C", 1, 1)

			local lbl = Instance.new("TextLabel", btn); lbl.Size = UDim2.new(0.6, 0, 1, 0); lbl.Position = UDim2.new(0, 26, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(230,230,230); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextSize = 11
			lbl.Text = recipe.Result

			local statusLbl = Instance.new("TextLabel", btn); statusLbl.Size = UDim2.new(0, 50, 1, 0); statusLbl.Position = UDim2.new(1, -60, 0, 0); statusLbl.BackgroundTransparency = 1; statusLbl.Font = Enum.Font.GothamMedium; statusLbl.TextColor3 = (pHas >= recipe.ReqAmt) and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100); statusLbl.TextXAlignment = Enum.TextXAlignment.Right; statusLbl.TextSize = 11; statusLbl.Text = pHas .. "/" .. recipe.ReqAmt

			btn.MouseButton1Click:Connect(function()
				selectedCraftingRecipe = reqItem

				local reqData = ItemData.Equipment[reqItem] or ItemData.Consumables[reqItem]
				local reqColor = RarityColors[reqData and reqData.Rarity or "Common"] or "#FFFFFF"

				ingStroke.Color = Color3.fromHex(reqColor:gsub("#","")); ingTagBox.BackgroundColor3 = ingStroke.Color; ingTagTxt.Text = string.sub(reqData and reqData.Rarity or "C", 1, 1)
				ingBoxName.Text = reqItem

				local pDews = player.leaderstats and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
				local hasReqColor = (pHas >= recipe.ReqAmt) and "#55FF55" or "#FF5555"
				local hasDewColor = (pDews >= recipe.DewCost) and "#55FF55" or "#FF5555"

				ingBoxCount.Text = "Req: <font color='"..hasReqColor.."'>" .. pHas .. "/" .. recipe.ReqAmt .. "</font>"
				dewsBoxCount.Text = "Cost:<br/><font color='"..hasDewColor.."'>" .. recipe.DewCost .. "</font>"

				resStroke.Color = Color3.fromHex(rColor:gsub("#","")); resTagBox.BackgroundColor3 = resStroke.Color; resTagTxt.Text = string.sub(resData.Rarity or "C", 1, 1)
				resBoxName.Text = recipe.Result

				if pHas >= recipe.ReqAmt and pDews >= recipe.DewCost then
					ApplyButtonGradient(craftBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20)); craftBtn.Text = "CRAFT ITEM"
				else
					ApplyButtonGradient(craftBtn, Color3.fromRGB(180, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(60, 20, 20)); craftBtn.Text = "MISSING MATERIALS"
				end
			end)
		end

		if selectedCraftingRecipe then
			local recipe = ItemData.ForgeRecipes[selectedCraftingRecipe]
			local safeReq = selectedCraftingRecipe:gsub("[^%w]", "") .. "Count"
			local pHas = player:GetAttribute(safeReq) or 0
			local pDews = player.leaderstats and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
			local hasReqColor = (pHas >= recipe.ReqAmt) and "#55FF55" or "#FF5555"
			local hasDewColor = (pDews >= recipe.DewCost) and "#55FF55" or "#FF5555"

			ingBoxCount.Text = "Req: <font color='"..hasReqColor.."'>" .. pHas .. "/" .. recipe.ReqAmt .. "</font>"
			dewsBoxCount.Text = "Cost:<br/><font color='"..hasDewColor.."'>" .. recipe.DewCost .. "</font>"

			if pHas >= recipe.ReqAmt and pDews >= recipe.DewCost then
				ApplyButtonGradient(craftBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20)); craftBtn.Text = "CRAFT ITEM"
			else
				ApplyButtonGradient(craftBtn, Color3.fromRGB(180, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(60, 20, 20)); craftBtn.Text = "MISSING MATERIALS"
			end
		end

		for _, child in ipairs(CraftInvGrid:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		local invItems = {}
		for iName, iData in pairs(ItemData.Equipment) do table.insert(invItems, {Name = iName, Data = iData}) end
		for iName, iData in pairs(ItemData.Consumables) do table.insert(invItems, {Name = iName, Data = iData}) end
		table.sort(invItems, function(a, b) local rA = RarityOrder[a.Data.Rarity or "Common"] or 7; local rB = RarityOrder[b.Data.Rarity or "Common"] or 7; if rA == rB then return a.Name < b.Name else return rA < rB end end)

		local lOrder = 1
		for _, item in ipairs(invItems) do
			local safeNameBase = item.Name:gsub("[^%w]", "")
			local count = player:GetAttribute(safeNameBase .. "Count") or 0
			if count > 0 then
				local rKey = item.Data.Rarity or "Common"
				local awakened = player:GetAttribute(safeNameBase .. "_Awakened")
				if awakened then rKey = "Transcendent" end
				local cColor = RarityColors[rKey] or "#FFFFFF"
				local rarityRGB = Color3.fromHex(cColor:gsub("#", ""))

				local card = Instance.new("Frame", CraftInvGrid)
				card.Size = UDim2.new(1, 0, 1, 0); card.BackgroundColor3 = Color3.fromRGB(22, 22, 28); card.LayoutOrder = lOrder; card.ClipsDescendants = true; lOrder += 1
				Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
				local stroke = Instance.new("UIStroke", card); stroke.Color = rarityRGB; stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

				local accentBar = Instance.new("Frame", card); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = rarityRGB; accentBar.BorderSizePixel = 0; Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)
				local bgGlow = Instance.new("Frame", card); bgGlow.Size = UDim2.new(1, 0, 0.5, 0); bgGlow.Position = UDim2.new(0, 0, 0.5, 0); bgGlow.BackgroundColor3 = rarityRGB; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1

				local countBadge = Instance.new("Frame", card); countBadge.Size = UDim2.new(0, 20, 0, 12); countBadge.AnchorPoint = Vector2.new(1, 0); countBadge.Position = UDim2.new(1, -3, 0, 6); countBadge.BackgroundColor3 = Color3.fromRGB(12, 12, 16); countBadge.BorderSizePixel = 0; countBadge.ZIndex = 3; Instance.new("UICorner", countBadge).CornerRadius = UDim.new(0, 3)
				local countTag = Instance.new("TextLabel", countBadge); countTag.Size = UDim2.new(1, 0, 1, 0); countTag.BackgroundTransparency = 1; countTag.Font = Enum.Font.GothamBlack; countTag.TextColor3 = Color3.fromRGB(210, 210, 210); countTag.TextSize = 8; countTag.Text = "x" .. count; countTag.ZIndex = 4

				local nameLbl = Instance.new("TextLabel", card); nameLbl.Size = UDim2.new(0.88, 0, 0.5, 0); nameLbl.Position = UDim2.new(0.5, 0, 0.5, 2); nameLbl.AnchorPoint = Vector2.new(0.5, 0.5); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = Color3.fromRGB(235, 235, 235); nameLbl.TextScaled = true; nameLbl.TextWrapped = true; nameLbl.Text = item.Name; nameLbl.ZIndex = 3
				local tConstraint = Instance.new("UITextSizeConstraint", nameLbl); tConstraint.MaxTextSize = 10; tConstraint.MinTextSize = 6

				local rarityTag = Instance.new("TextLabel", card); rarityTag.Size = UDim2.new(0, 14, 0, 14); rarityTag.Position = UDim2.new(0, 4, 1, -18); rarityTag.BackgroundTransparency = 1; rarityTag.Font = Enum.Font.GothamBlack; rarityTag.TextColor3 = rarityRGB; rarityTag.TextTransparency = 0.3; rarityTag.TextSize = 9; rarityTag.Text = string.sub(rKey, 1, 1); rarityTag.ZIndex = 3

				local tTipStr = "<b><font color='" .. cColor .. "'>[" .. rKey .. "] " .. item.Name .. "</font></b>"
				if item.Data.Bonus then for k, v in pairs(item.Data.Bonus) do tTipStr ..= "\n<font color='#55FF55'>+" .. v .. " " .. k:sub(1,3):upper() .. "</font>" end end
				if awakened then tTipStr ..= "\n<font color='#AA55FF'>[AWAKENED]:\n" .. awakened .. "</font>" end

				local btnCover = Instance.new("TextButton", card); btnCover.Size = UDim2.new(1,0,1,0); btnCover.BackgroundTransparency = 1; btnCover.Text = ""; btnCover.ZIndex = 5
				btnCover.MouseEnter:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Show(tTipStr) end end)
				btnCover.MouseLeave:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Hide() end end)
			end
		end

		task.delay(0.05, function() SubTabs["Crafting"].CanvasSize = UDim2.new(0, 0, 0, 170 + recLayout.AbsoluteContentSize.Y + cigLayout.AbsoluteContentSize.Y + 120) end)
	end


	-- ==========================================
	-- [[ 2. AWAKENING TAB ]]
	-- ==========================================
	SubTabs["Awakening"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Awakening"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Awakening"].BackgroundTransparency = 1; SubTabs["Awakening"].Visible = false; SubTabs["Awakening"].ScrollBarThickness = 0
	local aMasterLayout = Instance.new("UIListLayout", SubTabs["Awakening"]); aMasterLayout.Padding = UDim.new(0, 15); aMasterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; aMasterLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local AWTopPanel = Instance.new("Frame", SubTabs["Awakening"])
	AWTopPanel.Size = UDim2.new(0.95, 0, 0, 190); AWTopPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); AWTopPanel.LayoutOrder = 1
	Instance.new("UICorner", AWTopPanel).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", AWTopPanel).Color = Color3.fromRGB(150, 100, 255)

	rightPanelName = Instance.new("TextLabel", AWTopPanel)
	rightPanelName.Size = UDim2.new(1, 0, 0, 30); rightPanelName.Position = UDim2.new(0, 0, 0, 10); rightPanelName.BackgroundTransparency = 1; rightPanelName.Font = Enum.Font.GothamBlack; rightPanelName.TextColor3 = Color3.fromRGB(255, 255, 255); rightPanelName.TextSize = 18; rightPanelName.Text = "SELECT A WEAPON"

	rightPanelStats = Instance.new("TextLabel", AWTopPanel)
	rightPanelStats.Size = UDim2.new(0.9, 0, 0, 60); rightPanelStats.Position = UDim2.new(0.05, 0, 0, 45); rightPanelStats.BackgroundTransparency = 1; rightPanelStats.Font = Enum.Font.GothamBold; rightPanelStats.TextColor3 = Color3.fromRGB(150, 255, 150); rightPanelStats.TextSize = 14; rightPanelStats.TextWrapped = true; rightPanelStats.Text = "No Awakened Stats"

	extractCountLbl = Instance.new("TextLabel", AWTopPanel)
	extractCountLbl.Size = UDim2.new(1, 0, 0, 20); extractCountLbl.Position = UDim2.new(0, 0, 0, 110); extractCountLbl.BackgroundTransparency = 1; extractCountLbl.Font = Enum.Font.GothamMedium; extractCountLbl.TextColor3 = Color3.fromRGB(200, 200, 200); extractCountLbl.TextSize = 12; extractCountLbl.Text = "Titan Hardening Extracts Owned: 0"

	awakenBtn = Instance.new("TextButton", AWTopPanel)
	awakenBtn.Size = UDim2.new(0.8, 0, 0, 40); awakenBtn.Position = UDim2.new(0.1, 0, 0, 140); awakenBtn.Font = Enum.Font.GothamBlack; awakenBtn.TextColor3 = Color3.fromRGB(255, 255, 255); awakenBtn.TextSize = 14; awakenBtn.Text = "AWAKEN (Cost: 1x Extract)"
	ApplyButtonGradient(awakenBtn, Color3.fromRGB(160, 80, 200), Color3.fromRGB(100, 40, 140), Color3.fromRGB(80, 20, 100)); awakenBtn.Visible = false

	awakenBtn.MouseButton1Click:Connect(function()
		if selectedWeapon then Network:WaitForChild("AwakenWeapon"):FireServer(selectedWeapon) end
	end)

	local WpnList = Instance.new("Frame", SubTabs["Awakening"])
	WpnList.Size = UDim2.new(0.95, 0, 0, 0); WpnList.BackgroundTransparency = 1; WpnList.LayoutOrder = 2
	local wLayout = Instance.new("UIListLayout", WpnList); wLayout.Padding = UDim.new(0, 10)
	wLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() WpnList.Size = UDim2.new(0.95, 0, 0, wLayout.AbsoluteContentSize.Y) end)

	local function RenderAwakening()
		for _, child in ipairs(WpnList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
		local eCount = player:GetAttribute("TitanHardeningExtractCount") or 0
		extractCountLbl.Text = "Titan Hardening Extracts Owned: " .. eCount

		local ownedWpns = {}
		for iName, iData in pairs(ItemData.Equipment) do
			local safeName = iName:gsub("[^%w]", "") .. "Count"
			if (player:GetAttribute(safeName) or 0) > 0 and (iData.Type == "Weapon" or iData.Type == "Accessory") then
				table.insert(ownedWpns, {Name = iName, Rarity = iData.Rarity})
			end
		end

		for _, wpn in ipairs(ownedWpns) do
			local cColor = RarityColors[wpn.Rarity or "Common"] or "#FFFFFF"
			local btn = Instance.new("TextButton", WpnList)
			btn.Size = UDim2.new(1, 0, 0, 45); btn.Font = Enum.Font.GothamBold; btn.Text = ""
			ApplyButtonGradient(btn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(60, 60, 70))

			local glow = Instance.new("Frame", btn); glow.Size = UDim2.new(0, 4, 1, -4); glow.Position = UDim2.new(0, 2, 0, 2); glow.BackgroundColor3 = Color3.fromHex(cColor:gsub("#","")); Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 2)

			local lbl = Instance.new("TextLabel", btn); lbl.Size = UDim2.new(1, -20, 1, 0); lbl.Position = UDim2.new(0, 15, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(230,230,230); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextSize = 13
			lbl.Text = "<b><font color='"..cColor.."'>["..(wpn.Rarity or "Common").."]</font></b> " .. wpn.Name; lbl.RichText = true

			btn.MouseButton1Click:Connect(function()
				selectedWeapon = wpn.Name
				rightPanelName.Text = wpn.Name:upper()

				local safeWpnName = wpn.Name:gsub("[^%w]", "")
				local aStats = player:GetAttribute(safeWpnName .. "_Awakened")

				rightPanelStats.Text = aStats and ("<font color='#AA55FF'>CURRENT AWAKENING:</font>\n" .. aStats) or "NO AWAKENED STATS"
				rightPanelStats.RichText = true
				awakenBtn.Visible = true
			end)
		end

		if selectedWeapon then
			local safeWpnName = selectedWeapon:gsub("[^%w]", "")
			local aStats = player:GetAttribute(safeWpnName .. "_Awakened")
			rightPanelStats.Text = aStats and ("<font color='#AA55FF'>CURRENT AWAKENING:</font>\n" .. aStats) or "NO AWAKENED STATS"
		end

		task.delay(0.05, function() SubTabs["Awakening"].CanvasSize = UDim2.new(0, 0, 0, 190 + wLayout.AbsoluteContentSize.Y + 30) end)
	end


	-- ==========================================
	-- [[ 3. FUSION TAB ]]
	-- ==========================================
	SubTabs["Fusion"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Fusion"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Fusion"].BackgroundTransparency = 1; SubTabs["Fusion"].Visible = false; SubTabs["Fusion"].ScrollBarThickness = 0
	local fMasterLayout = Instance.new("UIListLayout", SubTabs["Fusion"]); fMasterLayout.Padding = UDim.new(0, 15); fMasterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; fMasterLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local FusTopPanel = Instance.new("Frame", SubTabs["Fusion"])
	FusTopPanel.Size = UDim2.new(0.95, 0, 0, 240); FusTopPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); FusTopPanel.LayoutOrder = 1
	Instance.new("UICorner", FusTopPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", FusTopPanel).Color = Color3.fromRGB(255, 100, 100)
	local ftLayout = Instance.new("UIListLayout", FusTopPanel); ftLayout.Padding = UDim.new(0, 5); ftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; ftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local ftPad = Instance.new("UIPadding", FusTopPanel); ftPad.PaddingTop = UDim.new(0, 10); ftPad.PaddingBottom = UDim.new(0, 10)

	local function CreateFusLbl(parent, text, height, bgColor, lOrder)
		local l = Instance.new("TextLabel", parent); l.Size = UDim2.new(0.9, 0, 0, height); l.Font = Enum.Font.GothamBold; l.TextColor3 = Color3.fromRGB(200, 200, 200); l.TextSize = 12; l.Text = text; l.LayoutOrder = lOrder
		if bgColor then l.BackgroundColor3 = bgColor; Instance.new("UICorner", l).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", l).Color = Color3.fromRGB(60, 60, 70) else l.BackgroundTransparency = 1 end
		return l
	end

	fusionBaseLbl = CreateFusLbl(FusTopPanel, "Base: None", 35, Color3.fromRGB(30, 30, 35), 1)
	local plusLbl = CreateFusLbl(FusTopPanel, "+", 20, nil, 2); plusLbl.Font = Enum.Font.GothamBlack; plusLbl.TextColor3 = Color3.fromRGB(150, 150, 150); plusLbl.TextSize = 20
	fusionSacrificeLbl = CreateFusLbl(FusTopPanel, "Sacrifice: Select from Vault", 35, Color3.fromRGB(30, 30, 35), 3)
	local equalsLbl = CreateFusLbl(FusTopPanel, "=", 20, nil, 4); equalsLbl.Font = Enum.Font.GothamBlack; equalsLbl.TextColor3 = Color3.fromRGB(150, 150, 150); equalsLbl.TextSize = 20
	fusionResultLbl = CreateFusLbl(FusTopPanel, "Result: Unknown", 35, nil, 5); fusionResultLbl.Font = Enum.Font.GothamBlack; fusionResultLbl.TextColor3 = Color3.fromRGB(255, 215, 100); fusionResultLbl.TextSize = 14

	fuseBtn = Instance.new("TextButton", FusTopPanel)
	fuseBtn.Size = UDim2.new(0.9, 0, 0, 45); fuseBtn.Font = Enum.Font.GothamBlack; fuseBtn.TextColor3 = Color3.fromRGB(255, 255, 255); fuseBtn.TextSize = 14; fuseBtn.Text = "FUSE (50,000 Dews)"; fuseBtn.LayoutOrder = 6
	ApplyButtonGradient(fuseBtn, Color3.fromRGB(180, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(80, 20, 20)); fuseBtn.Visible = false

	fuseBtn.MouseButton1Click:Connect(function()
		if selectedFusionSlot then 
			local currentTitan = player:GetAttribute("Titan") or "None"
			local storedTitan = player:GetAttribute("Titan_Slot" .. selectedFusionSlot) or "None"
			expectedFusionResult = FusionRecipes[currentTitan] and FusionRecipes[currentTitan][storedTitan]
			Network:WaitForChild("FuseTitan"):FireServer(selectedFusionSlot) 
		end
	end)

	local fusListTitle = Instance.new("TextLabel", SubTabs["Fusion"])
	fusListTitle.Size = UDim2.new(0.95, 0, 0, 30); fusListTitle.BackgroundTransparency = 1; fusListTitle.Font = Enum.Font.GothamBlack; fusListTitle.TextColor3 = Color3.fromRGB(255, 100, 100); fusListTitle.TextSize = 16; fusListTitle.Text = "SELECT SACRIFICE"; fusListTitle.LayoutOrder = 2

	local VaultList = Instance.new("Frame", SubTabs["Fusion"])
	VaultList.Size = UDim2.new(0.95, 0, 0, 0); VaultList.BackgroundTransparency = 1; VaultList.LayoutOrder = 3
	local vLayout = Instance.new("UIListLayout", VaultList); vLayout.Padding = UDim.new(0, 10)
	vLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() VaultList.Size = UDim2.new(0.95, 0, 0, vLayout.AbsoluteContentSize.Y) end)

	local function RenderFusion()
		for _, child in ipairs(VaultList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end

		local currentTitan = player:GetAttribute("Titan") or "None"
		fusionBaseLbl.Text = "Base: <font color='#FF5555'>" .. currentTitan .. "</font>"
		fusionBaseLbl.RichText = true

		for i = 1, 6 do
			local storedTitan = player:GetAttribute("Titan_Slot" .. i) or "None"
			if storedTitan ~= "None" then
				local btn = Instance.new("TextButton", VaultList)
				btn.Size = UDim2.new(1, 0, 0, 45); btn.Font = Enum.Font.GothamBold; btn.Text = ""
				ApplyButtonGradient(btn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(60, 60, 70))

				local lbl = Instance.new("TextLabel", btn); lbl.Size = UDim2.new(1, -20, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(200,200,200); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextSize = 13
				lbl.Text = "[Slot " .. i .. "] " .. storedTitan

				btn.MouseButton1Click:Connect(function()
					selectedFusionSlot = i
					fusionSacrificeLbl.Text = "Sacrifice: <font color='#AAAAAA'>" .. storedTitan .. "</font>"
					fusionSacrificeLbl.RichText = true

					local result = FusionRecipes[currentTitan] and FusionRecipes[currentTitan][storedTitan]
					if result then
						fusionResultLbl.Text = "Result: <font color='#FFD700'>" .. result .. "</font>"
						fusionResultLbl.RichText = true
						fuseBtn.Visible = true
						if player.leaderstats and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value >= 50000 then
							ApplyButtonGradient(fuseBtn, Color3.fromRGB(180, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(80, 20, 20))
						else
							ApplyButtonGradient(fuseBtn, Color3.fromRGB(100, 40, 40), Color3.fromRGB(60, 20, 20), Color3.fromRGB(50, 15, 15))
						end
					else
						fusionResultLbl.Text = "<font color='#FF5555'>INCOMPATIBLE</font>"
						fusionResultLbl.RichText = true
						fuseBtn.Visible = false
					end
				end)
			end
		end

		if selectedFusionSlot then
			local storedTitan = player:GetAttribute("Titan_Slot" .. selectedFusionSlot) or "None"
			if storedTitan == "None" then
				selectedFusionSlot = nil
				fusionSacrificeLbl.Text = "Sacrifice: Select from Vault"
				fusionResultLbl.Text = "Result: Unknown"
				fuseBtn.Visible = false
			else
				local result = FusionRecipes[currentTitan] and FusionRecipes[currentTitan][storedTitan]
				if result then
					if player.leaderstats and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value >= 50000 then
						ApplyButtonGradient(fuseBtn, Color3.fromRGB(180, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(80, 20, 20))
					else
						ApplyButtonGradient(fuseBtn, Color3.fromRGB(100, 40, 40), Color3.fromRGB(60, 20, 20), Color3.fromRGB(50, 15, 15))
					end
				end
			end
		end

		task.delay(0.05, function() SubTabs["Fusion"].CanvasSize = UDim2.new(0, 0, 0, 240 + 30 + vLayout.AbsoluteContentSize.Y + 40) end)
	end


	-- ==========================================
	-- [[ GLOBAL REFRESH LOGIC ]]
	-- ==========================================
	player.AttributeChanged:Connect(function(attr)
		if attr == "Titan" and expectedFusionResult then
			local newTitan = player:GetAttribute("Titan")
			if newTitan == expectedFusionResult then
				CinematicManager.Show("TITAN FUSED", newTitan, "#FFD700")
			end
			expectedFusionResult = nil
		end

		if string.match(attr, "Count$") or string.match(attr, "_Awakened$") or string.match(attr, "^Titan") then
			RenderCrafting()
			RenderAwakening()
			RenderFusion()
		end
	end)

	local function WatchDews()
		local ls = player:WaitForChild("leaderstats", 10)
		if ls and ls:FindFirstChild("Dews") then
			ls.Dews.Changed:Connect(function()
				RenderCrafting()
				RenderFusion()
			end)
		end
	end

	task.spawn(function()
		WatchDews()
		RenderCrafting()
		RenderAwakening()
		RenderFusion()
		local cGrad = SubBtns["Crafting"]:FindFirstChildOfClass("UIGradient")
		if cGrad then TweenGradient(cGrad, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), 0) end
		TweenService:Create(SubBtns["Crafting"], TweenInfo.new(0), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)
end

function ForgeTab.Show()
	if MainFrame then MainFrame.Visible = true end
end

return ForgeTab