-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local ShopTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local NotificationManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("NotificationManager"))

local player = Players.LocalPlayer
local MainFrame
local SupplyPanel, PremiumPanel, CodePanel
local TimeLabel, RRBtn, DewsRRBtn

local currentShopData = nil
local isFetching = false
local REROLL_ID = 3557925572 

for _, dp in ipairs(ItemData.Products) do if dp.IsReroll then REROLL_ID = dp.ID; break end end

local RarityColors = { ["Common"] = "#AAAAAA", ["Uncommon"] = "#55FF55", ["Rare"] = "#5555FF", ["Epic"] = "#AA00FF", ["Legendary"] = "#FFD700", ["Mythical"] = "#FF3333", ["Transcendent"] = "#FF55FF" }

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

local function FormatTime(seconds)
	local m = math.floor(seconds / 60); local s = seconds % 60
	return string.format("%02d:%02d", m, s)
end

function ShopTab.Init(parentFrame, tooltipMgr)
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "ShopFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false
	MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local mainLayout = Instance.new("UIListLayout", MainFrame)
	mainLayout.Padding = UDim.new(0, 15); mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; mainLayout.FillDirection = Enum.FillDirection.Vertical; mainLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(0.95, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 255, 255); Title.TextSize = 22; Title.Text = "MARKETPLACE & SUPPLY"; Title.TextXAlignment = Enum.TextXAlignment.Center
	ApplyGradient(Title, Color3.fromRGB(150, 200, 255), Color3.fromRGB(50, 150, 255))
	Title.LayoutOrder = 0

	-- [[ 1. PREMIUM PANEL ]]
	PremiumPanel = Instance.new("Frame", MainFrame)
	PremiumPanel.Size = UDim2.new(0.95, 0, 0, 0); PremiumPanel.AutomaticSize = Enum.AutomaticSize.Y
	PremiumPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	PremiumPanel.LayoutOrder = 1
	Instance.new("UICorner", PremiumPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", PremiumPanel).Color = Color3.fromRGB(80, 80, 90)

	local pListLayout = Instance.new("UIListLayout", PremiumPanel)
	pListLayout.Padding = UDim.new(0, 10); pListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; pListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local pPad = Instance.new("UIPadding", PremiumPanel); pPad.PaddingTop = UDim.new(0, 10); pPad.PaddingBottom = UDim.new(0, 15)

	local PTitle = Instance.new("TextLabel", PremiumPanel)
	PTitle.Size = UDim2.new(1, 0, 0, 30); PTitle.BackgroundTransparency = 1; PTitle.Font = Enum.Font.GothamBlack; PTitle.TextColor3 = Color3.fromRGB(255, 215, 100); PTitle.TextSize = 16; PTitle.Text = "PREMIUM STORE"; PTitle.LayoutOrder = 1

	local PremList = Instance.new("Frame", PremiumPanel)
	PremList.Size = UDim2.new(1, -20, 0, 0); PremList.AutomaticSize = Enum.AutomaticSize.Y; PremList.BackgroundTransparency = 1; PremList.LayoutOrder = 2
	local plLayout = Instance.new("UIListLayout", PremList); plLayout.Padding = UDim.new(0, 10)

	for _, gp in ipairs(ItemData.Gamepasses) do
		local row = Instance.new("Frame", PremList)
		row.Size = UDim2.new(1, 0, 0, 110); row.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", row); stroke.Color = Color3.fromRGB(150, 100, 200); stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local accentBar = Instance.new("Frame", row); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(150, 100, 200); accentBar.BorderSizePixel = 0; Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local rTitle = Instance.new("TextLabel", row); rTitle.Size = UDim2.new(1, -20, 0, 20); rTitle.Position = UDim2.new(0, 15, 0, 10); rTitle.BackgroundTransparency = 1; rTitle.Font = Enum.Font.GothamBlack; rTitle.TextColor3 = Color3.fromRGB(255, 215, 100); rTitle.TextSize = 14; rTitle.TextXAlignment = Enum.TextXAlignment.Left; rTitle.Text = gp.Name
		local rDesc = Instance.new("TextLabel", row); rDesc.Size = UDim2.new(1, -20, 0, 35); rDesc.Position = UDim2.new(0, 15, 0, 30); rDesc.BackgroundTransparency = 1; rDesc.Font = Enum.Font.GothamMedium; rDesc.TextColor3 = Color3.fromRGB(180, 180, 190); rDesc.TextSize = 11; rDesc.TextWrapped = true; rDesc.TextXAlignment = Enum.TextXAlignment.Left; rDesc.Text = gp.Desc

		local btnArea = Instance.new("Frame", row)
		btnArea.Size = UDim2.new(1, -20, 0, 30); btnArea.Position = UDim2.new(0, 10, 1, -35); btnArea.BackgroundTransparency = 1
		local baLayout = Instance.new("UIListLayout", btnArea); baLayout.FillDirection = Enum.FillDirection.Horizontal; baLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; baLayout.Padding = UDim.new(0, 10)

		local buyBtn = Instance.new("TextButton", btnArea)
		buyBtn.Size = UDim2.new(0.48, 0, 1, 0); buyBtn.Font = Enum.Font.GothamBold; buyBtn.TextColor3 = Color3.new(1,1,1); buyBtn.TextSize = 11; buyBtn.Text = "BUY"
		ApplyButtonGradient(buyBtn, Color3.fromRGB(40, 80, 40), Color3.fromRGB(20, 40, 20), Color3.fromRGB(80, 180, 80))
		buyBtn.MouseButton1Click:Connect(function() MarketplaceService:PromptGamePassPurchase(player, gp.ID) end)

		local giftBtn = Instance.new("TextButton", btnArea)
		giftBtn.Size = UDim2.new(0.48, 0, 1, 0); giftBtn.Font = Enum.Font.GothamBold; giftBtn.TextColor3 = Color3.new(1,1,1); giftBtn.TextSize = 11; giftBtn.Text = "GIFT"
		ApplyButtonGradient(giftBtn, Color3.fromRGB(120, 40, 140), Color3.fromRGB(60, 20, 70), Color3.fromRGB(180, 80, 200))
		giftBtn.MouseButton1Click:Connect(function() if gp.GiftID and gp.GiftID ~= 0 then MarketplaceService:PromptProductPurchase(player, gp.GiftID) end end)
	end

	for _, dp in ipairs(ItemData.Products) do
		if dp.IsReroll or string.find(string.lower(dp.Name), "gift") then continue end 

		local row = Instance.new("Frame", PremList)
		row.Size = UDim2.new(1, 0, 0, 110); row.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", row); stroke.Color = Color3.fromRGB(100, 150, 100); stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local accentBar = Instance.new("Frame", row); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(100, 150, 100); accentBar.BorderSizePixel = 0; Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local rTitle = Instance.new("TextLabel", row); rTitle.Size = UDim2.new(1, -20, 0, 20); rTitle.Position = UDim2.new(0, 15, 0, 10); rTitle.BackgroundTransparency = 1; rTitle.Font = Enum.Font.GothamBlack; rTitle.TextColor3 = Color3.fromRGB(150, 255, 150); rTitle.TextSize = 14; rTitle.TextXAlignment = Enum.TextXAlignment.Left; rTitle.Text = dp.Name
		local rDesc = Instance.new("TextLabel", row); rDesc.Size = UDim2.new(1, -20, 0, 35); rDesc.Position = UDim2.new(0, 15, 0, 30); rDesc.BackgroundTransparency = 1; rDesc.Font = Enum.Font.GothamMedium; rDesc.TextColor3 = Color3.fromRGB(180, 180, 190); rDesc.TextSize = 11; rDesc.TextWrapped = true; rDesc.TextXAlignment = Enum.TextXAlignment.Left; rDesc.Text = dp.Desc

		local btnArea = Instance.new("Frame", row)
		btnArea.Size = UDim2.new(1, -20, 0, 30); btnArea.Position = UDim2.new(0, 10, 1, -35); btnArea.BackgroundTransparency = 1
		local baLayout = Instance.new("UIListLayout", btnArea); baLayout.FillDirection = Enum.FillDirection.Horizontal; baLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

		local btn = Instance.new("TextButton", btnArea); btn.Size = UDim2.new(0.5, 0, 1, 0); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.new(1,1,1); btn.TextSize = 12; btn.Text = "BUY"
		ApplyButtonGradient(btn, Color3.fromRGB(40, 80, 40), Color3.fromRGB(20, 40, 20), Color3.fromRGB(80, 180, 80))
		btn.MouseButton1Click:Connect(function() MarketplaceService:PromptProductPurchase(player, dp.ID) end)
	end

	-- [[ 2. SUPPLY PANEL ]]
	SupplyPanel = Instance.new("Frame", MainFrame)
	SupplyPanel.Size = UDim2.new(0.95, 0, 0, 0); SupplyPanel.AutomaticSize = Enum.AutomaticSize.Y
	SupplyPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	SupplyPanel.LayoutOrder = 2
	Instance.new("UICorner", SupplyPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", SupplyPanel).Color = Color3.fromRGB(80, 80, 90)

	local sListLayout = Instance.new("UIListLayout", SupplyPanel)
	sListLayout.Padding = UDim.new(0, 10); sListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; sListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local sPad = Instance.new("UIPadding", SupplyPanel); sPad.PaddingTop = UDim.new(0, 15); sPad.PaddingBottom = UDim.new(0, 15)

	local Header = Instance.new("Frame", SupplyPanel)
	Header.Size = UDim2.new(1, -20, 0, 0); Header.AutomaticSize = Enum.AutomaticSize.Y; Header.BackgroundTransparency = 1; Header.LayoutOrder = 1
	local hLayout = Instance.new("UIListLayout", Header)
	hLayout.Padding = UDim.new(0, 8); hLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; hLayout.FillDirection = Enum.FillDirection.Vertical

	TimeLabel = Instance.new("TextLabel", Header)
	TimeLabel.Size = UDim2.new(1, 0, 0, 25); TimeLabel.BackgroundTransparency = 1; TimeLabel.Font = Enum.Font.GothamBlack; TimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255); TimeLabel.TextSize = 14; TimeLabel.TextXAlignment = Enum.TextXAlignment.Center
	ApplyGradient(TimeLabel, Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 200, 100))

	DewsRRBtn = Instance.new("TextButton", Header)
	DewsRRBtn.Size = UDim2.new(1, 0, 0, 35); DewsRRBtn.Font = Enum.Font.GothamBold; DewsRRBtn.TextColor3 = Color3.fromRGB(255,255,255); DewsRRBtn.TextSize = 12; DewsRRBtn.Text = "RESTOCK (100K Dews)"
	ApplyButtonGradient(DewsRRBtn, Color3.fromRGB(30, 60, 90), Color3.fromRGB(15, 30, 45), Color3.fromRGB(60, 120, 180))

	RRBtn = Instance.new("TextButton", Header)
	RRBtn.Size = UDim2.new(1, 0, 0, 35); RRBtn.Font = Enum.Font.GothamBold; RRBtn.TextColor3 = Color3.fromRGB(255,255,255); RRBtn.TextSize = 12; RRBtn.Text = "RESTOCK (15 R$)"
	ApplyButtonGradient(RRBtn, Color3.fromRGB(100, 60, 20), Color3.fromRGB(50, 30, 10), Color3.fromRGB(200, 120, 40))

	local function CheckVIPReroll()
		local hasVIP = player:GetAttribute("HasVIP")
		local lastRoll = player:GetAttribute("LastFreeReroll") or 0
		if hasVIP and os.time() - lastRoll >= 86400 then
			RRBtn.Text = "FREE RESTOCK (VIP)"; ApplyButtonGradient(RRBtn, Color3.fromRGB(120, 40, 120), Color3.fromRGB(60, 20, 60), Color3.fromRGB(200, 80, 200)); return true
		else
			RRBtn.Text = "RESTOCK (15 R$)"; ApplyButtonGradient(RRBtn, Color3.fromRGB(100, 60, 20), Color3.fromRGB(50, 30, 10), Color3.fromRGB(200, 120, 40)); return false
		end
	end

	local ShopGrid = Instance.new("Frame", SupplyPanel)
	ShopGrid.Size = UDim2.new(1, -20, 0, 0); ShopGrid.AutomaticSize = Enum.AutomaticSize.Y
	ShopGrid.BackgroundTransparency = 1; ShopGrid.BorderSizePixel = 0; ShopGrid.LayoutOrder = 2
	local sgLayout = Instance.new("UIListLayout", ShopGrid); sgLayout.Padding = UDim.new(0, 10)

	local function FetchAndRenderShop()
		if isFetching then return end
		isFetching = true
		currentShopData = Network.GetShopData:InvokeServer()
		isFetching = false
		if not currentShopData then return end

		CheckVIPReroll()
		for _, child in ipairs(ShopGrid:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end

		for _, item in ipairs(currentShopData.Items) do
			local iData = ItemData.Equipment[item.Name] or ItemData.Consumables[item.Name]
			local rarityTag = iData and iData.Rarity or "Common"
			local cColor = RarityColors[rarityTag] or "#FFFFFF"
			local rarityRGB = Color3.fromHex(cColor:gsub("#", ""))

			local row = Instance.new("Frame", ShopGrid)
			row.Size = UDim2.new(1, 0, 0, 85); row.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
			Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
			local stroke = Instance.new("UIStroke", row); stroke.Color = rarityRGB; stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local accentBar = Instance.new("Frame", row); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = rarityRGB; accentBar.BorderSizePixel = 0; Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)
			local bgGlow = Instance.new("Frame", row); bgGlow.Size = UDim2.new(1, 0, 0.5, 0); bgGlow.Position = UDim2.new(0, 0, 0.5, 0); bgGlow.BackgroundColor3 = rarityRGB; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1

			local tagBox = Instance.new("Frame", row); tagBox.Size = UDim2.new(0, 16, 0, 16); tagBox.Position = UDim2.new(0, 10, 0, 12); tagBox.BackgroundColor3 = rarityRGB; Instance.new("UICorner", tagBox).CornerRadius = UDim.new(0, 4)
			local tagTxt = Instance.new("TextLabel", tagBox); tagTxt.Size = UDim2.new(1, 0, 1, 0); tagTxt.BackgroundTransparency = 1; tagTxt.Font = Enum.Font.GothamBlack; tagTxt.TextColor3 = Color3.new(0,0,0); tagTxt.TextSize = 10; tagTxt.Text = string.sub(rarityTag, 1, 1)

			local nLbl = Instance.new("TextLabel", row)
			nLbl.Size = UDim2.new(1, -40, 0, 35); nLbl.Position = UDim2.new(0, 35, 0, 5); nLbl.BackgroundTransparency = 1; nLbl.Font = Enum.Font.GothamBold; nLbl.TextColor3 = Color3.fromRGB(255,255,255); nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.RichText = true; nLbl.TextSize = 12

			local bonusStr = ""
			if iData and iData.Bonus then
				local bList = {}
				for k, v in pairs(iData.Bonus) do table.insert(bList, "+"..v.." "..string.sub(k, 1, 3):upper()) end
				bonusStr = "\n<font color='#55FF55' size='10'>" .. table.concat(bList, " | ") .. "</font>"
			end

			nLbl.Text = "<b><font color='" .. cColor .. "'>" .. item.Name .. "</font></b>" .. bonusStr

			local cLbl = Instance.new("TextLabel", row); cLbl.Size = UDim2.new(0.5, 0, 0, 20); cLbl.Position = UDim2.new(0, 15, 1, -30); cLbl.BackgroundTransparency = 1; cLbl.Font = Enum.Font.GothamMedium; cLbl.TextColor3 = Color3.fromRGB(150, 255, 150); cLbl.TextXAlignment = Enum.TextXAlignment.Left; cLbl.TextSize = 11
			cLbl.Text = "Cost: " .. item.Cost .. " Dews"

			local bBtn = Instance.new("TextButton", row); bBtn.Size = UDim2.new(0.35, 0, 0, 30); bBtn.AnchorPoint = Vector2.new(1, 0); bBtn.Position = UDim2.new(1, -15, 1, -35); 
			bBtn.Font = Enum.Font.GothamBold; bBtn.TextColor3 = Color3.fromRGB(255, 255, 255); bBtn.TextSize = 11

			if item.SoldOut then
				bBtn.Text = "SOLD OUT"
				ApplyButtonGradient(bBtn, Color3.fromRGB(30, 30, 35), Color3.fromRGB(15, 15, 20), Color3.fromRGB(60, 60, 70))
				bBtn.TextColor3 = Color3.fromRGB(120, 120, 120)
			else
				bBtn.Text = "BUY"
				ApplyButtonGradient(bBtn, Color3.fromRGB(40, 80, 40), Color3.fromRGB(20, 40, 20), Color3.fromRGB(80, 180, 80))
				bBtn.MouseButton1Click:Connect(function()
					if item.SoldOut then return end 

					if player.leaderstats and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value >= item.Cost then
						item.SoldOut = true 
						Network.ShopAction:FireServer(item.Name)
						bBtn.Text = "SOLD OUT"; bBtn.TextColor3 = Color3.fromRGB(120, 120, 120)
						ApplyButtonGradient(bBtn, Color3.fromRGB(30, 30, 35), Color3.fromRGB(15, 15, 20), Color3.fromRGB(60, 60, 70))
					else
						if NotificationManager then NotificationManager.Show("Not enough Dews! Complete Bounties.", "Error") end
					end
				end)
			end
		end
	end

	DewsRRBtn.MouseButton1Click:Connect(function()
		if player.leaderstats and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value >= 100000 then
			Network.VIPFreeReroll:FireServer(true)
			DewsRRBtn.Text = "REROLLING..."; task.wait(0.5)
			FetchAndRenderShop()
			DewsRRBtn.Text = "RESTOCK (100K Dews)"
		else
			if NotificationManager then NotificationManager.Show("You need 100,000 Dews to force a restock!", "Error") end
		end
	end)

	RRBtn.MouseButton1Click:Connect(function()
		if CheckVIPReroll() then
			Network.VIPFreeReroll:FireServer(false)
			RRBtn.Text = "REROLLING..."; task.wait(0.5)
			FetchAndRenderShop()
		else
			MarketplaceService:PromptProductPurchase(player, REROLL_ID)
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if isPurchased and productId == REROLL_ID then
			RRBtn.Text = "REROLLING..."
			task.wait(1.5)
			FetchAndRenderShop()
		end
	end)

	-- [[ 3. PROMO CODE PANEL ]]
	CodePanel = Instance.new("Frame", MainFrame)
	CodePanel.Size = UDim2.new(0.95, 0, 0, 140); CodePanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	CodePanel.LayoutOrder = 3
	Instance.new("UICorner", CodePanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", CodePanel).Color = Color3.fromRGB(60, 60, 70)

	local cLayout = Instance.new("UIListLayout", CodePanel)
	cLayout.Padding = UDim.new(0, 8); cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; cLayout.FillDirection = Enum.FillDirection.Vertical
	local cPad = Instance.new("UIPadding", CodePanel); cPad.PaddingTop = UDim.new(0, 15); cPad.PaddingBottom = UDim.new(0, 15)

	local cTitle = Instance.new("TextLabel", CodePanel)
	cTitle.Size = UDim2.new(0.9, 0, 0, 25); cTitle.BackgroundTransparency = 1; cTitle.Font = Enum.Font.GothamBlack; cTitle.TextColor3 = Color3.fromRGB(200, 200, 200); cTitle.TextSize = 14; cTitle.TextXAlignment = Enum.TextXAlignment.Center; cTitle.Text = "ENTER PROMO CODE:"

	local cInput = Instance.new("TextBox", CodePanel)
	cInput.Size = UDim2.new(0.9, 0, 0, 40); cInput.BackgroundColor3 = Color3.fromRGB(15, 15, 18); cInput.Font = Enum.Font.GothamBold; cInput.TextColor3 = Color3.fromRGB(255, 255, 255); cInput.TextSize = 13; cInput.PlaceholderText = "Type code here..."
	Instance.new("UICorner", cInput).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", cInput).Color = Color3.fromRGB(80, 80, 90)

	local cBtn = Instance.new("TextButton", CodePanel)
	cBtn.Size = UDim2.new(0.9, 0, 0, 40); cBtn.Font = Enum.Font.GothamBlack; cBtn.TextColor3 = Color3.fromRGB(255, 255, 255); cBtn.TextSize = 14; cBtn.Text = "REDEEM"
	ApplyButtonGradient(cBtn, Color3.fromRGB(60, 100, 160), Color3.fromRGB(30, 50, 80), Color3.fromRGB(80, 140, 220))

	cBtn.MouseButton1Click:Connect(function()
		local codeStr = cInput.Text
		if codeStr ~= "" then
			Network.RedeemCode:FireServer(codeStr)
			cBtn.Text = "APPLIED"; ApplyButtonGradient(cBtn, Color3.fromRGB(40, 120, 40), Color3.fromRGB(20, 60, 20), Color3.fromRGB(80, 180, 80))
			task.delay(1, function() cBtn.Text = "REDEEM"; ApplyButtonGradient(cBtn, Color3.fromRGB(60, 100, 160), Color3.fromRGB(30, 50, 80), Color3.fromRGB(80, 140, 220)); cInput.Text = "" end)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if currentShopData then
				currentShopData.TimeLeft -= 1
				if currentShopData.TimeLeft <= 0 then 
					FetchAndRenderShop()
				elseif MainFrame.Visible then
					TimeLabel.Text = "RESTOCKS IN: " .. FormatTime(currentShopData.TimeLeft) 
				end
			else
				FetchAndRenderShop()
			end
		end
	end)
end

function ShopTab.Show()
	if MainFrame then MainFrame.Visible = true end
end

return ShopTab