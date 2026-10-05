-- VIPUI (PERMANENT)
-- Display, purchase-prompt trigger and outfit picker only. VIP status and
-- what is being worn always come from the server (GetVIPState /
-- VIPStateChanged); this script never decides either.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local LOG = "[VIPUI] "

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local VIPConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("VIPConfig"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotesFolder then
	warn(LOG .. "ReplicatedStorage.Remotes not found. VIP UI will not function.")
	return
end

local getVIPState = remotesFolder:WaitForChild("GetVIPState", 10)
local vipStateChanged = remotesFolder:WaitForChild("VIPStateChanged", 10)
local vipGateDenied = remotesFolder:WaitForChild("VIPGateDenied", 10)
local vipSetOutfit = remotesFolder:WaitForChild("VIPSetOutfit", 10)

if not (getVIPState and vipStateChanged and vipGateDenied and vipSetOutfit) then
	warn(LOG .. "Required VIP remotes not found. VIP UI will not function.")
	return
end

local GOLD = Color3.fromRGB(255, 205, 80)
local DARK = Color3.fromRGB(28, 20, 40)
local ON_COLOR = Color3.fromRGB(120, 210, 140)
local OFF_COLOR = Color3.fromRGB(70, 60, 90)

-- ============================================================
-- Build the UI (once). Left edge, above the seat-belt button: clear of MusicUI (bottom-centre),
-- the Shop button (right-centre), the player list (top-right) and chat.
-- ============================================================

local existing = playerGui:FindFirstChild("VIPUI")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VIPUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local function round(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local mainButton = Instance.new("TextButton")
mainButton.Name = "VIPButton"
mainButton.AnchorPoint = Vector2.new(0, 0.5)
mainButton.Position = UDim2.new(0, 16, 0.34, 0)
mainButton.Size = UDim2.new(0, 110, 0, 44)
mainButton.BackgroundColor3 = GOLD
mainButton.Font = Enum.Font.GothamBold
mainButton.Text = "GET VIP"
mainButton.TextColor3 = DARK
mainButton.TextSize = 16
mainButton.AutoButtonColor = true
mainButton.Parent = screenGui
round(mainButton, 10)

local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "MessageLabel"
messageLabel.AnchorPoint = Vector2.new(0.5, 0)
messageLabel.Position = UDim2.new(0.5, 0, 0, 60)
messageLabel.Size = UDim2.new(0, 360, 0, 36)
messageLabel.BackgroundColor3 = DARK
messageLabel.BackgroundTransparency = 0.2
messageLabel.Font = Enum.Font.GothamBold
messageLabel.Text = ""
messageLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
messageLabel.TextSize = 14
messageLabel.TextWrapped = true
messageLabel.Visible = false
messageLabel.Parent = screenGui
round(messageLabel, 8)

local outfits = VIPConfig.Outfits or {}
local ROW = 40

local panel = Instance.new("Frame")
panel.Name = "OutfitPanel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0, 136, 0.34, -22)
panel.Size = UDim2.new(0, 190, 0, 44 + #outfits * ROW + 8)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
round(panel, 12)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = GOLD
panelStroke.Transparency = 0.4
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 6)
title.Size = UDim2.new(1, -24, 0, 30)
title.Font = Enum.Font.GothamBold
title.Text = "PARTY OUTFIT"
title.TextColor3 = GOLD
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local outfitButtons = {} -- [id] = TextButton
local wearing = {} -- [id] = true, as last confirmed by the server

for index, outfit in ipairs(outfits) do
	local button = Instance.new("TextButton")
	button.Name = outfit.Id
	button.Position = UDim2.new(0, 10, 0, 40 + (index - 1) * ROW)
	button.Size = UDim2.new(1, -20, 0, ROW - 6)
	button.BackgroundColor3 = OFF_COLOR
	button.Font = Enum.Font.GothamBold
	button.Text = outfit.Label
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Parent = panel
	round(button, 8)
	outfitButtons[outfit.Id] = button

	button.MouseButton1Click:Connect(function()
		vipSetOutfit:FireServer(outfit.Id, not wearing[outfit.Id])
	end)
end

-- ============================================================
-- Render server state
-- ============================================================

local isVIP = false

local function render(state)
	isVIP = state.IsVIP == true
	wearing = type(state.Outfit) == "table" and state.Outfit or {}

	if isVIP then
		mainButton.Text = "VIP OUTFIT"
		mainButton.TextSize = 14
	else
		mainButton.Text = "GET VIP"
		mainButton.TextSize = 16
		panel.Visible = false
	end

	for id, button in pairs(outfitButtons) do
		button.BackgroundColor3 = wearing[id] and ON_COLOR or OFF_COLOR
	end
end

render({ IsVIP = false, Outfit = {} })

local function refresh()
	local ok, state = pcall(function()
		return getVIPState:InvokeServer()
	end)
	if ok and type(state) == "table" then
		render(state)
	elseif not ok then
		warn(LOG .. "GetVIPState failed: " .. tostring(state))
	end
end

task.spawn(refresh)

vipStateChanged.OnClientEvent:Connect(function(state)
	if type(state) == "table" then
		render(state)
	end
end)

local messageToken = 0
local function showMessage(text)
	messageToken += 1
	local token = messageToken
	messageLabel.Text = text
	messageLabel.Visible = true
	task.delay(4, function()
		if messageToken == token then
			messageLabel.Visible = false
		end
	end)
end

vipGateDenied.OnClientEvent:Connect(function(message)
	showMessage(tostring(message or "VIP required."))
end)

-- ============================================================
-- Main button: VIPs open the outfit picker; everyone else gets the
-- official Roblox purchase prompt. The server alone grants VIP.
-- ============================================================

local promptInFlight = false

mainButton.MouseButton1Click:Connect(function()
	if isVIP then
		panel.Visible = not panel.Visible
		return
	end
	if promptInFlight then
		return
	end

	local gamePassId = VIPConfig.GamePassId
	if type(gamePassId) ~= "number" or gamePassId <= 0 then
		showMessage("VIP is not available yet.")
		return
	end

	promptInFlight = true
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, gamePassId)
	end)
	if not ok then
		warn(LOG .. "PromptGamePassPurchase failed: " .. tostring(err))
	end
	task.delay(2, function()
		promptInFlight = false
	end)
end)

-- Convenience refresh after the prompt closes; the server's own handler
-- is what actually grants VIP.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_player, purchasedPassId, _wasPurchased)
	if purchasedPassId ~= VIPConfig.GamePassId then
		return
	end
	task.spawn(refresh)
end)
