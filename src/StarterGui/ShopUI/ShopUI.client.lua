-- ShopUI (PERMANENT)
-- Display + interaction only. All purchase/equip decisions are made by
-- ShopServer; this script only requests actions and renders results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LOG = "[ShopUI] "

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotesFolder then
	warn(LOG .. "ReplicatedStorage.Remotes not found. Shop UI will not function.")
	return
end

local getShopState = remotesFolder:WaitForChild("GetShopState", 10)
local purchaseShopItem = remotesFolder:WaitForChild("PurchaseShopItem", 10)
local equipShopItem = remotesFolder:WaitForChild("EquipShopItem", 10)

if not (getShopState and purchaseShopItem and equipShopItem) then
	warn(LOG .. "Required shop remotes not found. Shop UI will not function.")
	return
end

local ShopCatalog = require(ReplicatedStorage.Modules.ShopCatalog)

-- ============================================================
-- Build the UI (once). Guard against duplicates.
-- ============================================================

local existing = playerGui:FindFirstChild("ShopUI")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- ---- Shop open button ----

local shopButton = Instance.new("TextButton")
shopButton.Name = "ShopButton"
shopButton.AnchorPoint = Vector2.new(1, 0.5)
shopButton.Position = UDim2.new(1, -16, 0.5, 0)
shopButton.Size = UDim2.new(0, 64, 0, 64)
shopButton.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
shopButton.BackgroundTransparency = 0.1
shopButton.Font = Enum.Font.GothamBold
shopButton.Text = "SHOP"
shopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
shopButton.TextSize = 14
shopButton.AutoButtonColor = true
shopButton.Parent = screenGui

local shopButtonCorner = Instance.new("UICorner")
shopButtonCorner.CornerRadius = UDim.new(0, 12)
shopButtonCorner.Parent = shopButton

local shopButtonStroke = Instance.new("UIStroke")
shopButtonStroke.Color = Color3.fromRGB(255, 255, 255)
shopButtonStroke.Transparency = 0.85
shopButtonStroke.Parent = shopButton

-- ---- Shop panel (hidden by default) ----

local panel = Instance.new("Frame")
panel.Name = "ShopPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0.85, 0, 0.75, 0)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local panelSizeConstraint = Instance.new("UISizeConstraint")
panelSizeConstraint.MinSize = Vector2.new(260, 320)
panelSizeConstraint.MaxSize = Vector2.new(460, 560)
panelSizeConstraint.Parent = panel

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.9
panelStroke.Parent = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingLeft = UDim.new(0, 16)
panelPadding.PaddingRight = UDim.new(0, 16)
panelPadding.PaddingTop = UDim.new(0, 14)
panelPadding.PaddingBottom = UDim.new(0, 14)
panelPadding.Parent = panel

-- Header row: "SHOP" + Coins balance + Close button

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 32)
header.Position = UDim2.new(0, 0, 0, 0)
header.Parent = panel

local headerTitle = Instance.new("TextLabel")
headerTitle.Name = "HeaderTitle"
headerTitle.BackgroundTransparency = 1
headerTitle.Size = UDim2.new(0.5, 0, 1, 0)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.Text = "SHOP"
headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.TextSize = 18
headerTitle.Parent = header

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.BackgroundTransparency = 1
coinsLabel.AnchorPoint = Vector2.new(1, 0)
coinsLabel.Position = UDim2.new(1, -40, 0, 0)
coinsLabel.Size = UDim2.new(0.4, 0, 1, 0)
coinsLabel.Font = Enum.Font.Gotham
coinsLabel.Text = "0 Coins"
coinsLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
coinsLabel.TextSize = 14
coinsLabel.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 14
closeButton.Parent = header

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 8)
closeButtonCorner.Parent = closeButton

-- Status/feedback label

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.BackgroundTransparency = 1
statusLabel.Size = UDim2.new(1, 0, 0, 18)
statusLabel.Position = UDim2.new(0, 0, 0, 36)
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(150, 220, 150)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextSize = 12
statusLabel.Parent = panel

-- Scrolling item list

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "ItemList"
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.new(0, 0, 0, 58)
scroll.Size = UDim2.new(1, 0, 1, -58)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

-- ---- Build one card per catalog item ----

local itemCards = {} -- [itemId] = { card, actionButton, statusText }

for i, item in ipairs(ShopCatalog) do
	local card = Instance.new("Frame")
	card.Name = "Card_" .. item.Id
	card.LayoutOrder = i
	card.Size = UDim2.new(1, 0, 0, 70)
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	card.BorderSizePixel = 0
	card.Parent = scroll

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingLeft = UDim.new(0, 10)
	cardPadding.PaddingRight = UDim.new(0, 10)
	cardPadding.PaddingTop = UDim.new(0, 8)
	cardPadding.PaddingBottom = UDim.new(0, 8)
	cardPadding.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(0.65, 0, 0, 18)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = item.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextSize = 14
	nameLabel.Parent = card

	local descLabel = Instance.new("TextLabel")
	descLabel.BackgroundTransparency = 1
	descLabel.Size = UDim2.new(0.65, 0, 0, 16)
	descLabel.Position = UDim2.new(0, 0, 0, 20)
	descLabel.Font = Enum.Font.Gotham
	descLabel.Text = item.Description or ""
	descLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextSize = 11
	descLabel.TextWrapped = true
	descLabel.Parent = card

	local priceLabel = Instance.new("TextLabel")
	priceLabel.BackgroundTransparency = 1
	priceLabel.Size = UDim2.new(0.65, 0, 0, 14)
	priceLabel.Position = UDim2.new(0, 0, 0, 38)
	priceLabel.Font = Enum.Font.Gotham
	priceLabel.Text = tostring(item.Price) .. " Coins"
	priceLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.TextSize = 11
	priceLabel.Parent = card

	local actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.AnchorPoint = Vector2.new(1, 0.5)
	actionButton.Position = UDim2.new(1, 0, 0.5, 0)
	actionButton.Size = UDim2.new(0, 84, 0, 36)
	actionButton.BackgroundColor3 = Color3.fromRGB(70, 130, 230)
	actionButton.Font = Enum.Font.GothamBold
	actionButton.Text = "BUY"
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.TextSize = 12
	actionButton.Parent = card

	local actionCorner = Instance.new("UICorner")
	actionCorner.CornerRadius = UDim.new(0, 8)
	actionCorner.Parent = actionButton

	itemCards[item.Id] = {
		card = card,
		actionButton = actionButton,
	}
end

-- ============================================================
-- State rendering
-- ============================================================

local lastState = nil

local function setStatus(text, isError)
	statusLabel.Text = text or ""
	statusLabel.TextColor3 = isError and Color3.fromRGB(230, 130, 130) or Color3.fromRGB(150, 220, 150)
end

local function renderState(state)
	if not state then
		return
	end
	lastState = state

	coinsLabel.Text = tostring(state.Coins or 0) .. " Coins"

	for _, item in ipairs(ShopCatalog) do
		local ui = itemCards[item.Id]
		if ui then
			local owned = state.OwnedItems and state.OwnedItems[item.Id]
			local equipped = state.Equipped and state.Equipped[item.Type] == item.Id

			if equipped then
				ui.actionButton.Text = "EQUIPPED"
				ui.actionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
			elseif owned then
				ui.actionButton.Text = "EQUIP"
				ui.actionButton.BackgroundColor3 = Color3.fromRGB(80, 170, 100)
			else
				ui.actionButton.Text = "BUY"
				ui.actionButton.BackgroundColor3 = Color3.fromRGB(70, 130, 230)
			end
		end
	end
end

-- ============================================================
-- Actions (client debounce is UX only; server enforces real rate limiting)
-- ============================================================

local actionInFlight = false

local function handleAction(item)
	if actionInFlight then
		return
	end

	local owned = lastState and lastState.OwnedItems and lastState.OwnedItems[item.Id]
	local equipped = lastState and lastState.Equipped and lastState.Equipped[item.Type] == item.Id

	if equipped then
		return -- nothing to do
	end

	actionInFlight = true
	setStatus("Please wait...", false)

	task.spawn(function()
		local ok, result

		if owned then
			ok, result = pcall(function()
				return equipShopItem:InvokeServer(item.Id)
			end)
		else
			ok, result = pcall(function()
				return purchaseShopItem:InvokeServer(item.Id)
			end)
		end

		if ok and result then
			setStatus(result.Message or "", not result.Success)
		else
			setStatus("Request failed.", true)
			warn(LOG .. "Action request failed: " .. tostring(result))
		end

		-- Refresh authoritative state after any purchase/equip attempt,
		-- success or failure, so the UI never trusts its own guess.
		local refreshOk, refreshed = pcall(function()
			return getShopState:InvokeServer()
		end)
		if refreshOk and refreshed then
			renderState(refreshed)
		end

		actionInFlight = false
	end)
end

for _, item in ipairs(ShopCatalog) do
	local ui = itemCards[item.Id]
	ui.actionButton.MouseButton1Click:Connect(function()
		handleAction(item)
	end)
end

-- ============================================================
-- Open / close
-- ============================================================

shopButton.MouseButton1Click:Connect(function()
	panel.Visible = true
	setStatus("", false)
	task.spawn(function()
		local ok, state = pcall(function()
			return getShopState:InvokeServer()
		end)
		if ok and state then
			renderState(state)
		else
			warn(LOG .. "GetShopState failed: " .. tostring(state))
		end
	end)
end)

closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)