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
local EffectsManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("EffectsManager"))

local player = Players.LocalPlayer
local MainFrame
local ColumnsContainer, PathsContainer
local SupplyPanel, PremiumPanel, CodePanel
local TimeLabel, RRBtn, DewsRRBtn, VIPTimerLbl

local currentShopData = nil
local isFetching = false
local isProcessingReroll = false
local REROLL_ID = 3557925572 

for _, dp in ipairs(ItemData.Products) do if dp.IsReroll then REROLL_ID = dp.ID; break end end

local RarityColors = { ["Common"] = "#AAAAAA", ["Uncommon"] = "#55FF55", ["Rare"] = "#5555FF", ["Epic"] = "#AA00FF", ["Legendary"] = "#FFD700", ["Mythical"] = "#FF3333", ["Transcendent"] = "#FF55FF" }

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}
	grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 4)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn)
		stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	if not btn:GetAttribute("GradientTextFixed") then
		btn:SetAttribute("GradientTextFixed", true)
		local textLbl = Instance.new("TextLabel", btn)
		textLbl.Name = "BtnTextLabel"; textLbl.Size = UDim2.new(1, 0, 1, 0); textLbl.BackgroundTransparency = 1
		textLbl.Font = btn.Font; textLbl.TextSize = btn.TextSize; textLbl.TextScaled = btn.TextScaled; textLbl.RichText = btn.RichText; textLbl.TextWrapped = btn.TextWrapped
		textLbl.TextXAlignment = btn.TextXAlignment; textLbl.TextYAlignment = btn.TextYAlignment; textLbl.ZIndex = btn.ZIndex + 1
		local tConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint"); if tConstraint then tConstraint.Parent = textLbl end
		btn.ChildAdded:Connect(function(child) if child:IsA("UITextSizeConstraint") then task.delay(0, function() child.Parent = textLbl end) end end)
		textLbl.Text = btn.Text; textLbl.TextColor3 = btn.TextColor3; btn.Text = ""
		btn:GetPropertyChangedSignal("Text"):Connect(function() if btn.Text ~= "" then textLbl.Text = btn.Text; btn.Text = "" end end)
		btn:GetPropertyChangedSignal("TextColor3"):Connect(function() textLbl.TextColor3 = btn.TextColor3 end)
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

	local TopNav = Instance.new("ScrollingFrame", MainFrame)
	TopNav.Size = UDim2.new(0.95, 0, 0, 45); TopNav.BackgroundColor3 = Color3.fromRGB(15, 15, 18); TopNav.LayoutOrder = 1
	TopNav.ScrollBarThickness = 0; TopNav.ScrollingDirection = Enum.ScrollingDirection.X; TopNav.AutomaticCanvasSize = Enum.AutomaticSize.X
	Instance.new("UICorner", TopNav).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", TopNav).Color = Color3.fromRGB(120, 100, 60)

	local navLayout = Instance.new("UIListLayout", TopNav); navLayout.FillDirection = Enum.FillDirection.Horizontal; navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left; navLayout.VerticalAlignment = Enum.VerticalAlignment.Center; navLayout.Padding = UDim.new(0, 10)
	local navPad = Instance.new("UIPadding", TopNav); navPad.PaddingLeft = UDim.new(0, 10); navPad.PaddingRight = UDim.new(0, 10)

	local StandardBtn = Instance.new("TextButton", TopNav)
	StandardBtn.Size = UDim2.new(0, 150, 0, 30); StandardBtn.Text = "STANDARD SUPPLY"; StandardBtn.Font = Enum.Font.GothamBold; StandardBtn.TextSize = 11
	ApplyButtonGradient(StandardBtn, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), Color3.fromRGB(60, 60, 65))
	StandardBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

	local PathsBtn = Instance.new("TextButton", TopNav)
	PathsBtn.Size = UDim2.new(0, 120, 0, 30); PathsBtn.Text = "THE PATHS"; PathsBtn.Font = Enum.Font.GothamBold; PathsBtn.TextSize = 11
	ApplyButtonGradient(PathsBtn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 65))
	PathsBtn.TextColor3 = Color3.fromRGB(180, 180, 180)

	local ContentArea = Instance.new("Frame", MainFrame)
	ContentArea.Size = UDim2.new(1, 0, 0, 0); ContentArea.AutomaticSize = Enum.AutomaticSize.Y; ContentArea.BackgroundTransparency = 1; ContentArea.LayoutOrder = 2

	ColumnsContainer = Instance.new("Frame", ContentArea)
	ColumnsContainer.Size = UDim2.new(1, 0, 0, 0); ColumnsContainer.AutomaticSize = Enum.AutomaticSize.Y; ColumnsContainer.BackgroundTransparency = 1

	local ccLayout = Instance.new("UIListLayout", ColumnsContainer); ccLayout.FillDirection = Enum.FillDirection.Vertical; ccLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; ccLayout.Padding = UDim.new(0, 15)

	PathsContainer = Instance.new("Frame", ContentArea)
	PathsContainer.Size = UDim2.new(0.95, 0, 0, 0); PathsContainer.AutomaticSize = Enum.AutomaticSize.Y; PathsContainer.Position = UDim2.new(0.025, 0, 0, 0); PathsContainer.BackgroundTransparency = 1; PathsContainer.Visible = false
	local pcLayout = Instance.new("UIListLayout", PathsContainer); pcLayout.SortOrder = Enum.SortOrder.LayoutOrder; pcLayout.Padding = UDim.new(0, 15)

	-- [[ PATHS SHOP UI ]]
	local PHeader = Instance.new("Frame", PathsContainer)
	PHeader.Size = UDim2.new(1, 0, 0, 45); PHeader.BackgroundColor3 = Color3.fromRGB(20, 20, 25); PHeader.LayoutOrder = 1
	Instance.new("UICorner", PHeader).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", PHeader).Color = Color3.fromRGB(85, 255, 255)

	local pTitle = Instance.new("TextLabel", PHeader)
	pTitle.Size = UDim2.new(0.5, 0, 1, 0); pTitle.Position = UDim2.new(0, 10, 0, 0); pTitle.BackgroundTransparency = 1; pTitle.Font = Enum.Font.GothamBlack; pTitle.TextColor3 = Color3.fromRGB(255, 255, 255); pTitle.TextSize = 12; pTitle.TextXAlignment = Enum.TextXAlignment.Left; pTitle.Text = "MEMORY NODES"

	local pDustLbl = Instance.new("TextLabel", PHeader)
	pDustLbl.Size = UDim2.new(0.5, 0, 1, 0); pDustLbl.Position = UDim2.new(0.5, -10, 0, 0); pDustLbl.BackgroundTransparency = 1; pDustLbl.Font = Enum.Font.GothamBlack; pDustLbl.TextColor3 = Color3.fromRGB(85, 255, 255); pDustLbl.TextSize = 12; pDustLbl.TextXAlignment = Enum.TextXAlignment.Right; pDustLbl.Text = "PATH DUST: 0"

	local NodeGrid = Instance.new("Frame", PathsContainer)
	NodeGrid.Size = UDim2.new(1, 0, 0, 0); NodeGrid.AutomaticSize = Enum.AutomaticSize.Y; NodeGrid.BackgroundTransparency = 1; NodeGrid.LayoutOrder = 2
	local ngLayout = Instance.new("UIGridLayout", NodeGrid); ngLayout.CellSize = UDim2.new(1, 0, 0, 120); ngLayout.CellPadding = UDim2.new(0, 0, 0, 10); ngLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local LeaveBtn = Instance.new("TextButton", PathsContainer)
	LeaveBtn.Size = UDim2.new(1, 0, 0, 45); LeaveBtn.Font = Enum.Font.GothamBlack; LeaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255); LeaveBtn.TextSize = 13; LeaveBtn.Text = "SCATTER REMAINING DUST & LEAVE"; LeaveBtn.LayoutOrder = 3
	ApplyButtonGradient(LeaveBtn, Color3.fromRGB(150, 50, 50), Color3.fromRGB(80, 20, 20), Color3.fromRGB(100, 30, 30))

	local function FetchAndRenderPaths()
		local data = Network.GetShopData:InvokeServer("PathsShop")
		if not data then return end
		pDustLbl.Text = "PATH DUST: " .. tostring(data.Dust)

		for _, c in ipairs(NodeGrid:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end

		for _, node in ipairs(data.Nodes) do
			local card = Instance.new("Frame", NodeGrid)
			card.BackgroundColor3 = Color3.fromRGB(22, 22, 28); Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
			local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(85, 255, 255); stroke.Thickness = 1; stroke.Transparency = 0.5; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

			local nTitle = Instance.new("TextLabel", card)
			nTitle.Size = UDim2.new(1, -20, 0, 20); nTitle.Position = UDim2.new(0, 10, 0, 5); nTitle.BackgroundTransparency = 1; nTitle.Font = Enum.Font.GothamBlack; nTitle.TextColor3 = Color3.fromRGB(255, 215, 100); nTitle.TextSize = 14; nTitle.TextXAlignment = Enum.TextXAlignment.Left; nTitle.Text = node.Name

			local nDesc = Instance.new("TextLabel", card)
			nDesc.Size = UDim2.new(1, -20, 0, 40); nDesc.Position = UDim2.new(0, 10, 0, 25); nDesc.BackgroundTransparency = 1; nDesc.Font = Enum.Font.GothamMedium; nDesc.TextColor3 = Color3.fromRGB(200, 200, 200); nDesc.TextSize = 11; nDesc.TextWrapped = true; nDesc.TextXAlignment = Enum.TextXAlignment.Left; nDesc.TextYAlignment = Enum.TextYAlignment.Top; nDesc.Text = node.Desc

			local nLvl = Instance.new("TextLabel", card)
			nLvl.Size = UDim2.new(0.5, 0, 0, 20); nLvl.Position = UDim2.new(0, 10, 1, -35); nLvl.BackgroundTransparency = 1; nLvl.Font = Enum.Font.GothamBold; nLvl.TextColor3 = Color3.fromRGB(100, 255, 100); nLvl.TextSize = 12; nLvl.TextXAlignment = Enum.TextXAlignment.Left; nLvl.Text = "LEVEL: " .. node.CurrentLevel .. " / " .. node.MaxLevel

			local btn = Instance.new("TextButton", card)
			btn.Size = UDim2.new(0.45, 0, 0, 30); btn.Position = UDim2.new(1, -10, 1, -38); btn.AnchorPoint = Vector2.new(1, 0); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 11
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

			if type(node.Cost) == "number" then
				btn.Text = "AWAKEN (" .. node.Cost .. ")"
				ApplyButtonGradient(btn, Color3.fromRGB(40, 120, 120), Color3.fromRGB(20, 60, 60), Color3.fromRGB(30, 80, 80))
				btn.MouseButton1Click:Connect(function()
					if data.Dust >= node.Cost then
						Network.ShopAction:FireServer("BuyPathNode", node.Name)
						task.delay(0.2, FetchAndRenderPaths)
					else
						if NotificationManager then NotificationManager.Show("Not enough Path Dust!", "Error") end
					end
				end)
			else
				btn.Text = "MAX LEVEL"
				ApplyButtonGradient(btn, Color3.fromRGB(60, 60, 65), Color3.fromRGB(30, 30, 35), Color3.fromRGB(80, 80, 90))
				btn.TextColor3 = Color3.fromRGB(150, 150, 150)
			end
		end
	end

	local function SwitchSubTab(tabName)
		if tabName == "Standard" then
			ColumnsContainer.Visible = true; PathsContainer.Visible = false
			local sGrad = StandardBtn:FindFirstChildOfClass("UIGradient"); if sGrad then TweenGradient(sGrad, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), 0.2) end
			TweenService:Create(StandardBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			local pGrad = PathsBtn:FindFirstChildOfClass("UIGradient"); if pGrad then TweenGradient(pGrad, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), 0.2) end
			TweenService:Create(PathsBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play()
		else
			ColumnsContainer.Visible = false; PathsContainer.Visible = true
			local pGrad = PathsBtn:FindFirstChildOfClass("UIGradient"); if pGrad then TweenGradient(pGrad, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), 0.2) end
			TweenService:Create(PathsBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			local sGrad = StandardBtn:FindFirstChildOfClass("UIGradient"); if sGrad then TweenGradient(sGrad, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), 0.2) end
			TweenService:Create(StandardBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play()
			FetchAndRenderPaths()
		end
	end

	StandardBtn.MouseButton1Click:Connect(function() SwitchSubTab("Standard") end)
	PathsBtn.MouseButton1Click:Connect(function() SwitchSubTab("Paths") end)

	-- [[ THE FIX: Smooth return to Profile UI state after scattering Path Dust ]]
	LeaveBtn.MouseButton1Click:Connect(function() 
		if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Click") end
		Network.ShopAction:FireServer("ClosePathsShop")
		SwitchSubTab("Standard")

		if _G.AOT_OpenCategory and _G.AOT_SwitchTab then
			_G.AOT_OpenCategory("PLAYER")
			_G.AOT_SwitchTab("Profile")
		else
			MainFrame.Visible = false
		end
	end)

	_G.AOT_OpenPathsShop = function() SwitchSubTab("Paths") end

	local LeftCol = Instance.new("Frame", ColumnsContainer)
	LeftCol.Size = UDim2.new(0.95, 0, 0, 0); LeftCol.AutomaticSize = Enum.AutomaticSize.Y; LeftCol.BackgroundTransparency = 1
	local lcLayout = Instance.new("UIListLayout", LeftCol); lcLayout.Padding = UDim.new(0, 15); lcLayout.SortOrder = Enum.SortOrder.LayoutOrder

	PremiumPanel = Instance.new("Frame", LeftCol)
	PremiumPanel.Size = UDim2.new(1, 0, 0, 450); PremiumPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); PremiumPanel.LayoutOrder = 1
	Instance.new("UICorner", PremiumPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", PremiumPanel).Color = Color3.fromRGB(80, 80, 90)

	local pListLayout = Instance.new("UIListLayout", PremiumPanel); pListLayout.Padding = UDim.new(0, 10); pListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; pListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local pPad = Instance.new("UIPadding", PremiumPanel); pPad.PaddingTop = UDim.new(0, 10); pPad.PaddingBottom = UDim.new(0, 15)

	local PTitle = Instance.new("TextLabel", PremiumPanel)
	PTitle.Size = UDim2.new(1, 0, 0, 30); PTitle.BackgroundTransparency = 1; PTitle.Font = Enum.Font.GothamBlack; PTitle.TextColor3 = Color3.fromRGB(255, 215, 100); PTitle.TextSize = 16; PTitle.Text = "PREMIUM STORE"; PTitle.LayoutOrder = 1

	local PremList = Instance.new("ScrollingFrame", PremiumPanel)
	PremList.Size = UDim2.new(1, -10, 1, -45); PremList.BackgroundTransparency = 1; PremList.LayoutOrder = 2; PremList.ScrollBarThickness = 4; PremList.BorderSizePixel = 0
	local plLayout = Instance.new("UIListLayout", PremList); plLayout.Padding = UDim.new(0, 10)
	plLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() PremList.CanvasSize = UDim2.new(0, 0, 0, plLayout.AbsoluteContentSize.Y + 10) end)

	for _, gp in ipairs(ItemData.Gamepasses) do
		local row = Instance.new("Frame", PremList)
		row.Size = UDim2.new(1, -10, 0, 105); row.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", row); stroke.Color = Color3.fromRGB(150, 100, 200); stroke.Thickness = 1; stroke.Transparency = 0.4; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local accentBar = Instance.new("Frame", row); accentBar.Size = UDim2.new(1, 0, 0, 3); accentBar.BackgroundColor3 = Color3.fromRGB(150, 100, 200); accentBar.BorderSizePixel = 0

		local rTitle = Instance.new("TextLabel", row); rTitle.Size = UDim2.new(1, -20, 0, 20); rTitle.Position = UDim2.new(0, 10, 0, 10); rTitle.BackgroundTransparency = 1; rTitle.Font = Enum.Font.GothamBlack; rTitle.TextColor3 = Color3.fromRGB(255, 215, 100); rTitle.TextSize = 14; rTitle.TextXAlignment = Enum.TextXAlignment.Left; rTitle.Text = gp.Name
		local rDesc = Instance.new("TextLabel", row); rDesc.Size = UDim2.new(1, -20, 0, 35); rDesc.Position = UDim2.new(0, 10, 0, 30); rDesc.BackgroundTransparency = 1; rDesc.Font = Enum.Font.GothamMedium; rDesc.TextColor3 = Color3.fromRGB(200, 200, 200); rDesc.TextSize = 11; rDesc.TextWrapped = true; rDesc.TextXAlignment = Enum.TextXAlignment.Left; rDesc.Text = gp.Desc

		local btnArea = Instance.new("Frame", row)
		btnArea.Size = UDim2.new(1, -20, 0, 30); btnArea.Position = UDim2.new(0, 10, 1, -35); btnArea.BackgroundTransparency = 1
		local baLayout = Instance.new("UIListLayout", btnArea); baLayout.FillDirection = Enum.FillDirection.Horizontal; baLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; baLayout.Padding = UDim.new(0, 10)

		local buyBtn = Instance.new("TextButton", btnArea)
		buyBtn.Size = UDim2.new(0.48, 0, 1, 0); buyBtn.Font = Enum.Font.GothamBold; buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255); buyBtn.TextSize = 12; buyBtn.Text = "BUY"
		ApplyButtonGradient(buyBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))
		buyBtn.MouseButton1Click:Connect(function() MarketplaceService:PromptGamePassPurchase(player, gp.ID) end)

		local giftBtn = Instance.new("TextButton", btnArea)
		giftBtn.Size = UDim2.new(0.48, 0, 1, 0); giftBtn.Font = Enum.Font.GothamBold; giftBtn.TextColor3 = Color3.fromRGB(255, 255, 255); giftBtn.TextSize = 12; giftBtn.Text = "GIFT"
		ApplyButtonGradient(giftBtn, Color3.fromRGB(160, 80, 200), Color3.fromRGB(100, 40, 140), Color3.fromRGB(80, 20, 100))
		giftBtn.MouseButton1Click:Connect(function() if gp.GiftID and gp.GiftID ~= 0 then MarketplaceService:PromptProductPurchase(player, gp.GiftID) end end)
	end

	for _, dp in ipairs(ItemData.Products) do
		if dp.IsReroll or string.find(string.lower(dp.Name), "gift") then continue end 

		local row = Instance.new("Frame", PremList)
		row.Size = UDim2.new(1, -10, 0, 105); row.BackgroundColor3 = Color3.fromRGB(22, 22, 28); Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", row); stroke.Color = Color3.fromRGB(100, 150, 100); stroke.Thickness = 1; stroke.Transparency = 0.4; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local accentBar = Instance.new("Frame", row); accentBar.Size = UDim2.new(1, 0, 0, 3); accentBar.BackgroundColor3 = Color3.fromRGB(100, 150, 100); accentBar.BorderSizePixel = 0

		local rTitle = Instance.new("TextLabel", row); rTitle.Size = UDim2.new(1, -20, 0, 20); rTitle.Position = UDim2.new(0, 10, 0, 10); rTitle.BackgroundTransparency = 1; rTitle.Font = Enum.Font.GothamBlack; rTitle.TextColor3 = Color3.fromRGB(150, 255, 150); rTitle.TextSize = 14; rTitle.TextXAlignment = Enum.TextXAlignment.Left; rTitle.Text = dp.Name
		local rDesc = Instance.new("TextLabel", row); rDesc.Size = UDim2.new(1, -20, 0, 35); rDesc.Position = UDim2.new(0, 10, 0, 30); rDesc.BackgroundTransparency = 1; rDesc.Font = Enum.Font.GothamMedium; rDesc.TextColor3 = Color3.fromRGB(200, 200, 200); rDesc.TextSize = 11; rDesc.TextWrapped = true; rDesc.TextXAlignment = Enum.TextXAlignment.Left; rDesc.Text = dp.Desc

		local btnArea = Instance.new("Frame", row)
		btnArea.Size = UDim2.new(1, -20, 0, 30); btnArea.Position = UDim2.new(0, 10, 1, -35); btnArea.BackgroundTransparency = 1
		local baLayout = Instance.new("UIListLayout", btnArea); baLayout.FillDirection = Enum.FillDirection.Horizontal; baLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

		local btn = Instance.new("TextButton", btnArea); btn.Size = UDim2.new(0.5, 0, 1, 0); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 12; btn.Text = "BUY"
		ApplyButtonGradient(btn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))
		btn.MouseButton1Click:Connect(function() MarketplaceService:PromptProductPurchase(player, dp.ID) end)
	end

	CodePanel = Instance.new("Frame", LeftCol)
	CodePanel.Size = UDim2.new(1, 0, 0, 140); CodePanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); CodePanel.LayoutOrder = 2
	Instance.new("UICorner", CodePanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", CodePanel).Color = Color3.fromRGB(60, 60, 70)

	local cLayout = Instance.new("UIListLayout", CodePanel); cLayout.Padding = UDim.new(0, 8); cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; cLayout.FillDirection = Enum.FillDirection.Vertical
	local cPad = Instance.new("UIPadding", CodePanel); cPad.PaddingTop = UDim.new(0, 15); cPad.PaddingBottom = UDim.new(0, 15)

	local cTitle = Instance.new("TextLabel", CodePanel)
	cTitle.Size = UDim2.new(0.9, 0, 0, 25); cTitle.BackgroundTransparency = 1; cTitle.Font = Enum.Font.GothamBlack; cTitle.TextColor3 = Color3.fromRGB(200, 200, 200); cTitle.TextSize = 14; cTitle.TextXAlignment = Enum.TextXAlignment.Center; cTitle.Text = "ENTER PROMO CODE:"

	local cInput = Instance.new("TextBox", CodePanel)
	cInput.Size = UDim2.new(0.9, 0, 0, 40); cInput.BackgroundColor3 = Color3.fromRGB(15, 15, 18); cInput.Font = Enum.Font.GothamBold; cInput.TextColor3 = Color3.fromRGB(255, 255, 255); cInput.TextSize = 13; cInput.PlaceholderText = "Type code here..."
	Instance.new("UICorner", cInput).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", cInput).Color = Color3.fromRGB(80, 80, 90)

	local cBtn = Instance.new("TextButton", CodePanel)
	cBtn.Size = UDim2.new(0.9, 0, 0, 40); cBtn.Font = Enum.Font.GothamBlack; cBtn.TextColor3 = Color3.fromRGB(255, 255, 255); cBtn.TextSize = 14; cBtn.Text = "REDEEM"
	ApplyButtonGradient(cBtn, Color3.fromRGB(80, 140, 220), Color3.fromRGB(40, 80, 140), Color3.fromRGB(60, 120, 200))

	cBtn.MouseButton1Click:Connect(function()
		local codeStr = cInput.Text
		if codeStr ~= "" then
			Network.RedeemCode:FireServer(codeStr)
			cBtn.Text = "APPLIED"; ApplyButtonGradient(cBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))
			task.delay(1, function() cBtn.Text = "REDEEM"; ApplyButtonGradient(cBtn, Color3.fromRGB(80, 140, 220), Color3.fromRGB(40, 80, 140), Color3.fromRGB(60, 120, 200)); cInput.Text = "" end)
		end
	end)

	local RightCol = Instance.new("Frame", ColumnsContainer)
	RightCol.Size = UDim2.new(0.95, 0, 0, 0); RightCol.AutomaticSize = Enum.AutomaticSize.Y; RightCol.BackgroundTransparency = 1; RightCol.LayoutOrder = 3

	SupplyPanel = Instance.new("Frame", RightCol)
	SupplyPanel.Size = UDim2.new(1, 0, 0, 0); SupplyPanel.AutomaticSize = Enum.AutomaticSize.Y; SupplyPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	Instance.new("UICorner", SupplyPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", SupplyPanel).Color = Color3.fromRGB(80, 80, 90)

	local sListLayout = Instance.new("UIListLayout", SupplyPanel); sListLayout.Padding = UDim.new(0, 15); sListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; sListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local sPad = Instance.new("UIPadding", SupplyPanel); sPad.PaddingTop = UDim.new(0, 15); sPad.PaddingBottom = UDim.new(0, 15)

	local Header = Instance.new("Frame", SupplyPanel)
	Header.Size = UDim2.new(1, -20, 0, 0); Header.AutomaticSize = Enum.AutomaticSize.Y; Header.BackgroundTransparency = 1; Header.LayoutOrder = 1
	local hLayout = Instance.new("UIListLayout", Header); hLayout.Padding = UDim.new(0, 5); hLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; hLayout.FillDirection = Enum.FillDirection.Vertical

	TimeLabel = Instance.new("TextLabel", Header)
	TimeLabel.Size = UDim2.new(1, 0, 0, 25); TimeLabel.BackgroundTransparency = 1; TimeLabel.Font = Enum.Font.GothamBlack; TimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255); TimeLabel.TextSize = 16; TimeLabel.TextXAlignment = Enum.TextXAlignment.Center
	ApplyGradient(TimeLabel, Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 200, 100))

	local RRArea = Instance.new("Frame", Header)
	RRArea.Size = UDim2.new(1, 0, 0, 45); RRArea.BackgroundTransparency = 1
	local rrLayout = Instance.new("UIListLayout", RRArea); rrLayout.FillDirection = Enum.FillDirection.Horizontal; rrLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; rrLayout.Padding = UDim.new(0.04, 0)

	DewsRRBtn = Instance.new("TextButton", RRArea)
	DewsRRBtn.Size = UDim2.new(0.48, 0, 1, 0); DewsRRBtn.Font = Enum.Font.GothamBold; DewsRRBtn.TextColor3 = Color3.fromRGB(255,255,255); DewsRRBtn.TextSize = 12; DewsRRBtn.Text = "RESTOCK (100K Dews)"
	ApplyButtonGradient(DewsRRBtn, Color3.fromRGB(80, 140, 200), Color3.fromRGB(40, 80, 120), Color3.fromRGB(60, 100, 160))

	RRBtn = Instance.new("TextButton", RRArea)
	RRBtn.Size = UDim2.new(0.48, 0, 1, 0); RRBtn.Font = Enum.Font.GothamBold; RRBtn.TextColor3 = Color3.fromRGB(255,255,255); RRBtn.TextSize = 12; RRBtn.Text = "RESTOCK (15 R$)"
	ApplyButtonGradient(RRBtn, Color3.fromRGB(220, 160, 50), Color3.fromRGB(140, 90, 20), Color3.fromRGB(255, 200, 80))

	VIPTimerLbl = Instance.new("TextLabel", Header)
	VIPTimerLbl.Size = UDim2.new(1, 0, 0, 15)
	VIPTimerLbl.BackgroundTransparency = 1
	VIPTimerLbl.Font = Enum.Font.GothamMedium
	VIPTimerLbl.TextColor3 = Color3.fromRGB(200, 150, 255)
	VIPTimerLbl.TextSize = 11
	VIPTimerLbl.Text = ""
	VIPTimerLbl.Visible = false

	local function CheckVIPReroll()
		local hasVIP = player:GetAttribute("HasVIP")
		local lastRoll = player:GetAttribute("LastFreeReroll") or 0

		if hasVIP then
			if os.time() - lastRoll >= 86400 then
				if not isProcessingReroll then
					RRBtn.Text = "FREE RESTOCK (VIP)"
					ApplyButtonGradient(RRBtn, Color3.fromRGB(200, 80, 200), Color3.fromRGB(120, 40, 120), Color3.fromRGB(160, 60, 160))
				end
				if VIPTimerLbl then VIPTimerLbl.Visible = false end
				return true
			else
				if not isProcessingReroll then
					RRBtn.Text = "RESTOCK (15 R$)"
					ApplyButtonGradient(RRBtn, Color3.fromRGB(220, 160, 50), Color3.fromRGB(140, 90, 20), Color3.fromRGB(255, 200, 80))
				end
				if VIPTimerLbl then
					local timeLeft = 86400 - (os.time() - lastRoll)
					local h = math.floor(timeLeft / 3600)
					local m = math.floor((timeLeft % 3600) / 60)
					local s = timeLeft % 60
					VIPTimerLbl.Text = string.format("Free VIP Restock in: %02d:%02d:%02d", h, m, s)
					VIPTimerLbl.Visible = true
				end
				return false
			end
		else
			if not isProcessingReroll then
				RRBtn.Text = "RESTOCK (15 R$)"
				ApplyButtonGradient(RRBtn, Color3.fromRGB(220, 160, 50), Color3.fromRGB(140, 90, 20), Color3.fromRGB(255, 200, 80))
			end
			if VIPTimerLbl then VIPTimerLbl.Visible = false end
			return false
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

		if DewsRRBtn and not isProcessingReroll then DewsRRBtn.Text = "RESTOCK (100K Dews)" end
		CheckVIPReroll()

		if not currentShopData then return end

		for _, child in ipairs(ShopGrid:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end

		for _, item in ipairs(currentShopData.Items) do
			local iData = ItemData.Equipment[item.Name] or ItemData.Consumables[item.Name]
			local rarityTag = iData and iData.Rarity or "Common"
			local cColor = RarityColors[rarityTag] or "#FFFFFF"
			local rarityRGB = Color3.fromHex(cColor:gsub("#", ""))

			local row = Instance.new("Frame", ShopGrid)
			row.Size = UDim2.new(1, 0, 0, 85); row.BackgroundColor3 = Color3.fromRGB(22, 22, 28); Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
			local stroke = Instance.new("UIStroke", row); stroke.Color = rarityRGB; stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local accentBar = Instance.new("Frame", row); accentBar.Size = UDim2.new(1, 0, 0, 3); accentBar.BackgroundColor3 = rarityRGB; accentBar.BorderSizePixel = 0
			local bgGlow = Instance.new("Frame", row); bgGlow.Size = UDim2.new(1, 0, 0.5, 0); bgGlow.Position = UDim2.new(0, 0, 0.5, 0); bgGlow.BackgroundColor3 = rarityRGB; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1

			local tagBox = Instance.new("Frame", row); tagBox.Size = UDim2.new(0, 16, 0, 16); tagBox.Position = UDim2.new(0, 8, 0, 12); tagBox.BackgroundColor3 = rarityRGB; Instance.new("UICorner", tagBox).CornerRadius = UDim.new(0, 4)
			local tagTxt = Instance.new("TextLabel", tagBox); tagTxt.Size = UDim2.new(1, 0, 1, 0); tagTxt.BackgroundTransparency = 1; tagTxt.Font = Enum.Font.GothamBlack; tagTxt.TextColor3 = Color3.new(0,0,0); tagTxt.TextSize = 10; tagTxt.Text = string.sub(rarityTag, 1, 1)

			local nLbl = Instance.new("TextLabel", row)
			nLbl.Size = UDim2.new(1, -35, 0, 35); nLbl.Position = UDim2.new(0, 30, 0, 5); nLbl.BackgroundTransparency = 1; nLbl.Font = Enum.Font.GothamBold; nLbl.TextColor3 = Color3.fromRGB(255,255,255); nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.RichText = true; nLbl.TextSize = 13

			local bonusStr = ""
			if iData and iData.Bonus then
				local bList = {}
				for k, v in pairs(iData.Bonus) do table.insert(bList, "+"..v.." "..string.sub(k, 1, 3):upper()) end
				bonusStr = "\n<font color='#55FF55' size='11'>" .. table.concat(bList, " | ") .. "</font>"
			end

			nLbl.Text = "<b><font color='" .. cColor .. "'>" .. item.Name .. "</font></b>" .. bonusStr

			local cLbl = Instance.new("TextLabel", row); cLbl.Size = UDim2.new(0.5, 0, 0, 20); cLbl.Position = UDim2.new(0, 15, 1, -30); cLbl.BackgroundTransparency = 1; cLbl.Font = Enum.Font.GothamMedium; cLbl.TextColor3 = Color3.fromRGB(150, 255, 150); cLbl.TextXAlignment = Enum.TextXAlignment.Left; cLbl.TextSize = 12
			cLbl.Text = "Cost: " .. item.Cost .. " Dews"

			local bBtn = Instance.new("TextButton", row); bBtn.Size = UDim2.new(0.35, 0, 0, 35); bBtn.AnchorPoint = Vector2.new(1, 0); bBtn.Position = UDim2.new(1, -15, 1, -40); 
			bBtn.Font = Enum.Font.GothamBold; bBtn.TextColor3 = Color3.fromRGB(255, 255, 255); bBtn.TextSize = 12

			if item.SoldOut then
				bBtn.Text = "SOLD OUT"
				ApplyButtonGradient(bBtn, Color3.fromRGB(60, 60, 65), Color3.fromRGB(30, 30, 35), Color3.fromRGB(80, 80, 90))
				bBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
			else
				bBtn.Text = "BUY"
				ApplyButtonGradient(bBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))
				bBtn.MouseButton1Click:Connect(function()
					if item.SoldOut then return end 

					if player.leaderstats and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value >= item.Cost then
						item.SoldOut = true 
						Network.ShopAction:FireServer(item.Name)
						bBtn.Text = "SOLD OUT"; bBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
						ApplyButtonGradient(bBtn, Color3.fromRGB(60, 60, 65), Color3.fromRGB(30, 30, 35), Color3.fromRGB(80, 80, 90))
					else
						if NotificationManager then NotificationManager.Show("Not enough Dews! Complete Bounties to earn more.", "Error") end
					end
				end)
			end
		end
	end

	DewsRRBtn.MouseButton1Click:Connect(function()
		if isProcessingReroll then return end
		if player.leaderstats and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value >= 950000 then
			isProcessingReroll = true
			DewsRRBtn.Text = "REROLLING..."
			Network.VIPFreeReroll:FireServer(true)
			task.delay(3, function() 
				isProcessingReroll = false
				FetchAndRenderShop()
				if DewsRRBtn then DewsRRBtn.Text = "RESTOCK (950K Dews)" end
			end)
		else
			if NotificationManager then NotificationManager.Show("You need 950,000 Dews to force a restock!", "Error") end
		end
	end)

	RRBtn.MouseButton1Click:Connect(function()
		if isProcessingReroll then return end
		if CheckVIPReroll() then
			isProcessingReroll = true
			RRBtn.Text = "REROLLING..."
			Network.VIPFreeReroll:FireServer(false)
			task.delay(3, function() 
				isProcessingReroll = false
				FetchAndRenderShop()
				CheckVIPReroll()
			end)
		else
			isProcessingReroll = true
			RRBtn.Text = "WAITING..."
			MarketplaceService:PromptProductPurchase(player, REROLL_ID)
			task.delay(5, function() 
				isProcessingReroll = false
				CheckVIPReroll() 
			end)
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if productId == REROLL_ID then
			if isPurchased then
				RRBtn.Text = "REROLLING..."
				task.delay(1.5, function()
					isProcessingReroll = false
					FetchAndRenderShop()
					CheckVIPReroll()
				end)
			else
				isProcessingReroll = false
				CheckVIPReroll()
			end
		end
	end)

	player:GetAttributeChangedSignal("PersonalShopSeed"):Connect(function()
		if MainFrame and MainFrame.Visible then
			FetchAndRenderShop()
			if DewsRRBtn and not isProcessingReroll then DewsRRBtn.Text = "RESTOCK (100K Dews)" end
			CheckVIPReroll() 
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
				if MainFrame.Visible and player:GetAttribute("HasVIP") then CheckVIPReroll() end
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