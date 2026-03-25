-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local AdminTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService") -- [[ THE FIX: Added TweenService here! ]]
local Network = ReplicatedStorage:WaitForChild("Network")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local player = Players.LocalPlayer
local MainFrame

local Colors = {
	Background = Color3.fromRGB(15, 15, 18), 
	Panel = Color3.fromRGB(22, 22, 26),
	Accent = Color3.fromRGB(255, 80, 80), 
	Text = Color3.fromRGB(240, 240, 245),
	Subtext = Color3.fromRGB(130, 130, 140), 
	Border = Color3.fromRGB(45, 45, 55), 
	Success = Color3.fromRGB(80, 200, 120),
	Warning = Color3.fromRGB(220, 150, 50)
}

function AdminTab.Init(parentFrame)
	if player.UserId ~= 4068160397 and player.Name ~= "girthbender1209" then return end

	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "AdminFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Colors.Accent; Title.TextSize = 24; Title.Text = "SYSTEM OVERRIDE CONSOLE"

	local TargetContainer = Instance.new("Frame", MainFrame)
	TargetContainer.Size = UDim2.new(0.4, 0, 0, 45); TargetContainer.Position = UDim2.new(0.3, 0, 0.08, 0); TargetContainer.BackgroundColor3 = Colors.Panel
	Instance.new("UICorner", TargetContainer).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", TargetContainer).Color = Colors.Border

	local TargetLabel = Instance.new("TextLabel", TargetContainer)
	TargetLabel.Size = UDim2.new(0.35, 0, 1, 0); TargetLabel.BackgroundTransparency = 1; TargetLabel.Font = Enum.Font.GothamBold; TargetLabel.TextColor3 = Colors.Subtext; TargetLabel.TextSize = 14; TargetLabel.Text = "TARGET ID:"

	local TargetInput = Instance.new("TextBox", TargetContainer)
	TargetInput.Size = UDim2.new(0.6, 0, 0.7, 0); TargetInput.Position = UDim2.new(0.35, 0, 0.15, 0); TargetInput.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	TargetInput.Font = Enum.Font.GothamBold; TargetInput.TextColor3 = Colors.Text; TargetInput.TextSize = 16; TargetInput.Text = "me"
	Instance.new("UICorner", TargetInput).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", TargetInput).Color = Colors.Border

	local function GetTarget()
		local txt = TargetInput.Text; if txt == "" then return "me" end return txt
	end

	local function PlaySuccessAnim(btn, originalText)
		local oldColor = btn.BackgroundColor3; btn.Text = "EXECUTED"; btn.BackgroundColor3 = Colors.Success
		task.delay(0.8, function() btn.Text = originalText; btn.BackgroundColor3 = oldColor end)
	end

	local Col1 = Instance.new("Frame", MainFrame)
	Col1.Size = UDim2.new(0.3, 0, 0.75, 0); Col1.Position = UDim2.new(0.025, 0, 0.18, 0); Col1.BackgroundColor3 = Colors.Panel
	Instance.new("UICorner", Col1).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", Col1).Color = Colors.Border
	local C1Title = Instance.new("TextLabel", Col1); C1Title.Size = UDim2.new(1,0,0,40); C1Title.BackgroundTransparency = 1; C1Title.Font = Enum.Font.GothamBlack; C1Title.TextColor3 = Colors.Text; C1Title.Text = "ATTRIBUTES"
	local C1List = Instance.new("UIListLayout", Col1); C1List.Padding = UDim.new(0, 15); C1List.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local C1Pad = Instance.new("UIPadding", Col1); C1Pad.PaddingTop = UDim.new(0, 10)

	local function CreateInputRow(parent, placeholderTxt, cmd, isNumber)
		local title = Instance.new("TextLabel", parent)
		title.Size = UDim2.new(0.9, 0, 0, 15); title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold; title.TextColor3 = Colors.Subtext; title.TextSize = 11; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = placeholderTxt:upper()

		local row = Instance.new("Frame", parent); row.Size = UDim2.new(0.9, 0, 0, 35); row.BackgroundTransparency = 1
		local box = Instance.new("TextBox", row); box.Size = UDim2.new(0.7, -5, 1, 0); box.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		box.Font = Enum.Font.GothamMedium; box.TextColor3 = Colors.Text; box.TextSize = 13; box.PlaceholderText = placeholderTxt; box.Text = ""; box.TextXAlignment = Enum.TextXAlignment.Left
		local pad = Instance.new("UIPadding", box); pad.PaddingLeft = UDim.new(0, 10); Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", box).Color = Colors.Border
		local btn = Instance.new("TextButton", row); btn.Size = UDim2.new(0.3, 0, 1, 0); btn.Position = UDim2.new(0.7, 5, 0, 0); btn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
		btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Colors.Text; btn.TextSize = 12; btn.Text = "SET"; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

		btn.MouseButton1Click:Connect(function()
			local val = isNumber and (tonumber(box.Text) or 0) or box.Text
			if val ~= "" then Network.AdminCommand:FireServer(cmd, GetTarget(), val); PlaySuccessAnim(btn, "SET") end
		end)
	end

	CreateInputRow(Col1, "Override Titan Name", "SetTitan", false)
	CreateInputRow(Col1, "Override Clan Name", "SetClan", false)
	CreateInputRow(Col1, "Set Exact XP", "SetXP", true)
	CreateInputRow(Col1, "Set Exact Dews", "SetDews", true)

	local Col2 = Instance.new("Frame", MainFrame)
	Col2.Size = UDim2.new(0.3, 0, 0.75, 0); Col2.Position = UDim2.new(0.35, 0, 0.18, 0); Col2.BackgroundColor3 = Colors.Panel
	Instance.new("UICorner", Col2).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", Col2).Color = Colors.Border
	local C2Title = Instance.new("TextLabel", Col2); C2Title.Size = UDim2.new(1,0,0,40); C2Title.BackgroundTransparency = 1; C2Title.Font = Enum.Font.GothamBlack; C2Title.TextColor3 = Colors.Text; C2Title.Text = "MACROS"
	local C2List = Instance.new("UIListLayout", Col2); C2List.Padding = UDim.new(0, 10); C2List.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local C2Pad = Instance.new("UIPadding", Col2); C2Pad.PaddingTop = UDim.new(0, 5)

	local function CreateMacroBtn(parent, text, cmd, args, color)
		local btn = Instance.new("TextButton", parent); btn.Size = UDim2.new(0.9, 0, 0, 35)
		btn.BackgroundColor3 = color or Color3.fromRGB(40, 40, 45); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Colors.Text; btn.TextSize = 12; btn.Text = text
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", btn).Color = Colors.Border

		btn.MouseButton1Click:Connect(function() Network.AdminCommand:FireServer(cmd, GetTarget(), args); PlaySuccessAnim(btn, text) end)
	end

	CreateMacroBtn(Col2, "Max All Player Stats", "MaxStats")
	CreateMacroBtn(Col2, "Set Max Prestige", "MaxPrestige")
	CreateMacroBtn(Col2, "Unlock Full Campaign", "UnlockAllParts")
	CreateMacroBtn(Col2, "Give 50x Titan Serums", "GiveItem", {Item = "Standard Titan Serum", Amount = 50})
	CreateMacroBtn(Col2, "Give 50x Clan Vials", "GiveItem", {Item = "Clan Blood Vial", Amount = 50})

	-- [[ NEW: Targeted Recovery Code generation ]]
	CreateMacroBtn(Col2, "Generate Recovery Code", "GenerateRecovery", nil, Color3.fromRGB(40, 80, 140))

	local wipeBtn = Instance.new("TextButton", Col2); wipeBtn.Size = UDim2.new(0.9, 0, 0, 35)
	wipeBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40); wipeBtn.Font = Enum.Font.GothamBlack; wipeBtn.TextColor3 = Colors.Text; wipeBtn.TextSize = 12; wipeBtn.Text = "WIPE TARGET (KEEPS ITEMS)"
	Instance.new("UICorner", wipeBtn).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", wipeBtn).Color = Color3.fromRGB(200, 50, 50)

	local wipeConfirm = false
	wipeBtn.MouseButton1Click:Connect(function() 
		if not wipeConfirm then
			wipeConfirm = true
			wipeBtn.Text = "ARE YOU SURE?"; wipeBtn.BackgroundColor3 = Colors.Warning
			task.delay(3, function() wipeConfirm = false; wipeBtn.Text = "WIPE TARGET (KEEPS ITEMS)"; wipeBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40) end)
		else
			wipeConfirm = false
			Network.AdminCommand:FireServer("WipePlayer", GetTarget(), nil)
			wipeBtn.Text = "DATA WIPED"; wipeBtn.BackgroundColor3 = Colors.Success
			task.delay(1.5, function() wipeBtn.Text = "WIPE TARGET (KEEPS ITEMS)"; wipeBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40) end)
		end
	end)

	-- [[ NEW: Global Rollback Button ]]
	local globalBtn = Instance.new("TextButton", Col2); globalBtn.Size = UDim2.new(0.9, 0, 0, 40)
	globalBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0); globalBtn.Font = Enum.Font.GothamBlack; globalBtn.TextColor3 = Colors.Text; globalBtn.TextSize = 12; globalBtn.Text = "GLOBAL ROLLBACK (ALL SERVERS)"
	Instance.new("UICorner", globalBtn).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", globalBtn).Color = Color3.fromRGB(255, 0, 0); globalBtn.UIStroke.Thickness = 2

	local globConfirm = false
	globalBtn.MouseButton1Click:Connect(function() 
		if not globConfirm then
			globConfirm = true
			globalBtn.Text = "DOUBLE CLICK TO CONFIRM"; globalBtn.BackgroundColor3 = Colors.Warning
			task.delay(4, function() globConfirm = false; globalBtn.Text = "GLOBAL ROLLBACK (ALL SERVERS)"; globalBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0) end)
		else
			globConfirm = false
			Network.AdminCommand:FireServer("GlobalRollback", nil, nil)
			globalBtn.Text = "ROLLBACK SENT"; globalBtn.BackgroundColor3 = Colors.Success
			task.delay(2, function() globalBtn.Text = "GLOBAL ROLLBACK (ALL SERVERS)"; globalBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0) end)
		end
	end)

	local Col3 = Instance.new("Frame", MainFrame)
	Col3.Size = UDim2.new(0.3, 0, 0.75, 0); Col3.Position = UDim2.new(0.675, 0, 0.18, 0); Col3.BackgroundColor3 = Colors.Panel
	Instance.new("UICorner", Col3).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", Col3).Color = Colors.Border
	local C3Title = Instance.new("TextLabel", Col3); C3Title.Size = UDim2.new(1,0,0,40); C3Title.BackgroundTransparency = 1; C3Title.Font = Enum.Font.GothamBlack; C3Title.TextColor3 = Colors.Text; C3Title.Text = "VAULT SPAWNER"

	local SpawnControls = Instance.new("Frame", Col3)
	SpawnControls.Size = UDim2.new(0.9, 0, 0, 70); SpawnControls.Position = UDim2.new(0.05, 0, 0, 40); SpawnControls.BackgroundTransparency = 1

	local sNameBox = Instance.new("TextBox", SpawnControls); sNameBox.Size = UDim2.new(0.7, -5, 0, 35); sNameBox.BackgroundColor3 = Color3.fromRGB(15, 15, 18); sNameBox.Font = Enum.Font.GothamMedium; sNameBox.TextColor3 = Colors.Text; sNameBox.TextSize = 13; sNameBox.PlaceholderText = "Item Name"; sNameBox.Text = ""
	Instance.new("UICorner", sNameBox).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", sNameBox).Color = Colors.Border

	local sAmtBox = Instance.new("TextBox", SpawnControls); sAmtBox.Size = UDim2.new(0.3, 0, 0, 35); sAmtBox.Position = UDim2.new(0.7, 5, 0, 0); sAmtBox.BackgroundColor3 = Color3.fromRGB(15, 15, 18); sAmtBox.Font = Enum.Font.GothamBlack; sAmtBox.TextColor3 = Colors.Accent; sAmtBox.TextSize = 14; sAmtBox.Text = "1"
	Instance.new("UICorner", sAmtBox).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", sAmtBox).Color = Colors.Border

	local sBtn = Instance.new("TextButton", SpawnControls); sBtn.Size = UDim2.new(1, 0, 0, 35); sBtn.Position = UDim2.new(0, 0, 0, 45); sBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60); sBtn.Font = Enum.Font.GothamBold; sBtn.TextColor3 = Colors.Text; sBtn.TextSize = 13; sBtn.Text = "INJECT ITEM"
	Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 4)

	sBtn.MouseButton1Click:Connect(function()
		local amt = tonumber(sAmtBox.Text) or 1
		if sNameBox.Text ~= "" then Network.AdminCommand:FireServer("GiveItem", GetTarget(), {Item = sNameBox.Text, Amount = amt}); PlaySuccessAnim(sBtn, "INJECT ITEM") end
	end)

	local DictLabel = Instance.new("TextLabel", Col3); DictLabel.Size = UDim2.new(0.9, 0, 0, 20); DictLabel.Position = UDim2.new(0.05, 0, 0, 130); DictLabel.BackgroundTransparency = 1; DictLabel.Font = Enum.Font.GothamBold; DictLabel.TextColor3 = Colors.Subtext; DictLabel.TextSize = 11; DictLabel.TextXAlignment = Enum.TextXAlignment.Left; DictLabel.Text = "DATABASE (CLICK TO FILL):"
	local ItemDict = Instance.new("ScrollingFrame", Col3); ItemDict.Size = UDim2.new(0.9, 0, 1, -160); ItemDict.Position = UDim2.new(0.05, 0, 0, 150); ItemDict.BackgroundTransparency = 1; ItemDict.BorderSizePixel = 0; ItemDict.ScrollBarThickness = 4
	local IDList = Instance.new("UIListLayout", ItemDict); IDList.Padding = UDim.new(0, 6)

	local function PopulateDictionary()
		local allItems = {}
		for k, _ in pairs(ItemData.Equipment) do table.insert(allItems, k) end
		for k, _ in pairs(ItemData.Consumables) do table.insert(allItems, k) end
		table.sort(allItems)

		for _, name in ipairs(allItems) do
			local dictBtn = Instance.new("TextButton", ItemDict); dictBtn.Size = UDim2.new(1, -10, 0, 25); dictBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
			dictBtn.Font = Enum.Font.GothamMedium; dictBtn.TextColor3 = Colors.Subtext; dictBtn.TextSize = 12; dictBtn.Text = name
			Instance.new("UICorner", dictBtn).CornerRadius = UDim.new(0, 4)
			dictBtn.MouseButton1Click:Connect(function() sNameBox.Text = name end)
			dictBtn.MouseEnter:Connect(function() TweenService:Create(dictBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(50, 50, 60), TextColor3 = Colors.Text}):Play() end)
			dictBtn.MouseLeave:Connect(function() TweenService:Create(dictBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 35), TextColor3 = Colors.Subtext}):Play() end)
		end

		task.delay(0.1, function() ItemDict.CanvasSize = UDim2.new(0, 0, 0, IDList.AbsoluteContentSize.Y + 10) end)
	end
	PopulateDictionary()
end

function AdminTab.Show() if MainFrame then MainFrame.Visible = true end end

return AdminTab