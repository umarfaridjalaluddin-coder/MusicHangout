-- BirthdayVIPWardrobe (PERMANENT)
-- Dress-up panel for the Birthday VIP wardrobe. Display only: it sends the
-- server one fixed word per tap ("BirthdayStar", "RoyalVIP", "NeonPartyKid"
-- or "Restore") and shows whatever the server says is selected.
-- Everything is drawn with Frames, corners and gradients -- no image assets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local LOG = "[BirthdayVIPWardrobe] "
local PROMPT_NAME = "BirthdayVIPWardrobePrompt"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Outfits = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BirthdayVIPOutfits"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local requestOutfit = remotesFolder and remotesFolder:WaitForChild("RequestBirthdayVIPOutfit", 10)
local outfitState = remotesFolder and remotesFolder:WaitForChild("BirthdayVIPOutfitState", 10)
if not (requestOutfit and outfitState) then
	warn(LOG .. "Wardrobe remotes not found. The dress-up panel will not open.")
	return
end

-- ============================================================
-- Palette
-- ============================================================

local C = {
	Plum = Color3.fromRGB(91, 58, 132),
	Purple = Color3.fromRGB(138, 103, 178),
	Muted = Color3.fromRGB(143, 127, 166),
	Blush = Color3.fromRGB(251, 232, 237),
	Pink = Color3.fromRGB(245, 185, 213),
	Rose = Color3.fromRGB(236, 150, 195),
	Lavender = Color3.fromRGB(214, 194, 240),
	Champagne = Color3.fromRGB(244, 213, 138),
	ChampagneLight = Color3.fromRGB(251, 234, 190),
	Cream = Color3.fromRGB(255, 247, 235),
	Cyan = Color3.fromRGB(157, 219, 239),
	White = Color3.fromRGB(255, 255, 255),
	PanelTop = Color3.fromRGB(255, 244, 247),
	PanelBottom = Color3.fromRGB(247, 236, 249),
}

local TITLE_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamMedium

-- Per-style look for the preview and the Select button.
local STYLE = {
	BirthdayStar = { Gradient = { C.Pink, C.Lavender, C.Cream }, Button = Color3.fromRGB(224, 176, 232), ButtonText = C.White },
	RoyalVIP = { Gradient = { C.Cream, C.ChampagneLight, C.Lavender }, Button = Color3.fromRGB(205, 180, 232), ButtonText = C.White },
	NeonPartyKid = { Gradient = { C.Cyan, C.Lavender, C.Pink }, Button = Color3.fromRGB(150, 200, 235), ButtonText = C.White },
}

-- ============================================================
-- Small builders
-- ============================================================

local function corner(instance, radius, scale)
	local c = Instance.new("UICorner")
	c.CornerRadius = scale and UDim.new(radius, 0) or UDim.new(0, radius)
	c.Parent = instance
	return c
end

local function stroke(instance, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
	return s
end

local function gradient(instance, colors, rotation)
	local g = Instance.new("UIGradient")
	local keys = {}
	for i, color in ipairs(colors) do
		keys[i] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color)
	end
	g.Color = ColorSequence.new(keys)
	g.Rotation = rotation or 90
	g.Parent = instance
	return g
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = props.Color or C.White
	f.BackgroundTransparency = props.Transparency or 0
	f.AnchorPoint = props.Anchor or Vector2.zero
	f.Position = props.Position or UDim2.new()
	f.Size = props.Size or UDim2.fromScale(1, 1)
	f.Rotation = props.Rotation or 0
	f.ZIndex = props.ZIndex or 1
	f.Name = props.Name or "Frame"
	f.Parent = parent
	return f
end

local function text(parent, props)
	local label = Instance.new(props.Button and "TextButton" or "TextLabel")
	label.Name = props.Name or "Text"
	label.BorderSizePixel = 0
	label.BackgroundTransparency = props.Background and (props.BackgroundTransparency or 0) or 1
	if props.Background then
		label.BackgroundColor3 = props.Background
	end
	if props.Button then
		label.AutoButtonColor = false
	end
	label.Font = props.Font or TITLE_FONT
	label.Text = props.Text
	label.TextColor3 = props.Color or C.Plum
	label.TextScaled = true
	label.AnchorPoint = props.Anchor or Vector2.zero
	label.Position = props.Position
	label.Size = props.Size
	label.ZIndex = props.ZIndex or 1
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = props.Max or 22
	limit.MinTextSize = props.Min or 9
	limit.Parent = label
	return label
end

local function tween(instance, seconds, goal)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- A drawing surface that stays square, so preview shapes keep their proportions.
-- Shapes are placed by centre (x, y) and size (w, h), all 0..1 of the square.
local function shape(stage, x, y, w, h, color, opts)
	opts = opts or {}
	local f = frame(stage, {
		Color = color,
		Transparency = opts.Transparency,
		Anchor = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		Rotation = opts.Rotation,
		ZIndex = opts.ZIndex or 2,
	})
	corner(f, opts.Round or 0.5, true)
	return f
end

local function sparkle(stage, x, y, size, color, transparency)
	local label = text(stage, { Text = "✦", Color = color or C.White, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(size, size), Max = 40, ZIndex = 4 })
	label.TextTransparency = transparency or 0
	return label
end

-- Simple party doll: soft white head, body and arms. Each style dresses it.
local function doll(stage)
	shape(stage, 0.27, 0.72, 0.1, 0.3, C.White, { Transparency = 0.1 })
	shape(stage, 0.73, 0.72, 0.1, 0.3, C.White, { Transparency = 0.1 })
	shape(stage, 0.5, 0.76, 0.36, 0.42, C.White, { Round = 0.28, Transparency = 0.02, ZIndex = 3 })
	shape(stage, 0.5, 0.38, 0.3, 0.3, C.White, { ZIndex = 3 })
end

local previews = {}

function previews.BirthdayStar(stage)
	doll(stage)
	-- Sash across the body with a small rosette.
	shape(stage, 0.5, 0.76, 0.075, 0.5, C.Lavender, { Rotation = 38, Round = 0.4, ZIndex = 4 })
	shape(stage, 0.5, 0.76, 0.022, 0.5, C.Pink, { Rotation = 38, Round = 0.4, ZIndex = 4 })
	shape(stage, 0.62, 0.9, 0.07, 0.07, C.Champagne, { ZIndex = 5 })
	-- Tiara: a thin band, three points, a pink gem.
	shape(stage, 0.5, 0.245, 0.24, 0.028, C.Champagne, { ZIndex = 5 })
	shape(stage, 0.42, 0.215, 0.045, 0.045, C.Champagne, { Rotation = 45, Round = 0.15, ZIndex = 4 })
	shape(stage, 0.58, 0.215, 0.045, 0.045, C.Champagne, { Rotation = 45, Round = 0.15, ZIndex = 4 })
	shape(stage, 0.5, 0.195, 0.065, 0.065, C.Champagne, { Rotation = 45, Round = 0.15, ZIndex = 4 })
	shape(stage, 0.5, 0.185, 0.036, 0.036, C.Rose, { ZIndex = 5 })
	-- Tiny bow.
	shape(stage, 0.655, 0.27, 0.075, 0.05, C.Rose, { Rotation = 25, ZIndex = 5 })
	shape(stage, 0.715, 0.27, 0.075, 0.05, C.Rose, { Rotation = -25, ZIndex = 5 })
	shape(stage, 0.685, 0.272, 0.032, 0.032, C.White, { ZIndex = 6 })
	sparkle(stage, 0.16, 0.2, 0.14, C.White)
	sparkle(stage, 0.86, 0.5, 0.09, C.White, 0.2)
	sparkle(stage, 0.14, 0.58, 0.07, C.Champagne)
end

function previews.RoyalVIP(stage)
	-- Cape first, so it sits behind the doll.
	shape(stage, 0.5, 0.8, 0.56, 0.44, C.Lavender, { Round = 0.22 })
	shape(stage, 0.5, 0.985, 0.56, 0.04, C.Champagne, { Round = 0.5 })
	doll(stage)
	shape(stage, 0.5, 0.585, 0.36, 0.035, C.Champagne, { ZIndex = 4 })
	shape(stage, 0.5, 0.78, 0.022, 0.34, C.Champagne, { ZIndex = 4 })
	shape(stage, 0.34, 0.585, 0.055, 0.055, C.Champagne, { ZIndex = 5 })
	shape(stage, 0.66, 0.585, 0.055, 0.055, C.Champagne, { ZIndex = 5 })
	-- Little crown: band, three points, one lavender gem.
	shape(stage, 0.5, 0.235, 0.19, 0.045, C.Champagne, { Round = 0.3, ZIndex = 5 })
	shape(stage, 0.43, 0.2, 0.05, 0.05, C.Champagne, { Rotation = 45, Round = 0.15, ZIndex = 4 })
	shape(stage, 0.57, 0.2, 0.05, 0.05, C.Champagne, { Rotation = 45, Round = 0.15, ZIndex = 4 })
	shape(stage, 0.5, 0.185, 0.065, 0.065, C.Champagne, { Rotation = 45, Round = 0.15, ZIndex = 4 })
	shape(stage, 0.5, 0.235, 0.032, 0.032, C.Purple, { ZIndex = 6 })
	sparkle(stage, 0.84, 0.2, 0.13, C.Champagne)
	sparkle(stage, 0.15, 0.36, 0.08, C.White)
end

function previews.NeonPartyKid(stage)
	-- Soft glow dots.
	shape(stage, 0.16, 0.24, 0.16, 0.16, C.White, { Transparency = 0.65 })
	shape(stage, 0.86, 0.66, 0.12, 0.12, C.White, { Transparency = 0.7 })
	doll(stage)
	-- Headphone band: the top half of a ring, then two ear cups.
	local clip = frame(stage, { Transparency = 1, Anchor = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.37), Size = UDim2.fromScale(0.5, 0.25), ZIndex = 4 })
	clip.ClipsDescendants = true
	local ring = frame(clip, { Transparency = 1, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.68, 1.36), ZIndex = 4 })
	corner(ring, 0.5, true)
	stroke(ring, C.Purple, 3, 0)
	shape(stage, 0.33, 0.39, 0.07, 0.12, C.Purple, { Round = 0.4, ZIndex = 5 })
	shape(stage, 0.67, 0.39, 0.07, 0.12, C.Purple, { Round = 0.4, ZIndex = 5 })
	-- Glow bracelets and a jacket trim.
	shape(stage, 0.27, 0.8, 0.115, 0.03, C.Cyan, { ZIndex = 5 })
	shape(stage, 0.27, 0.835, 0.115, 0.03, C.Rose, { ZIndex = 5 })
	shape(stage, 0.73, 0.8, 0.115, 0.03, C.Rose, { ZIndex = 5 })
	shape(stage, 0.73, 0.835, 0.115, 0.03, C.Cyan, { ZIndex = 5 })
	shape(stage, 0.5, 0.78, 0.02, 0.34, C.Cyan, { ZIndex = 4 })
	local star = text(stage, { Text = "★", Color = C.White, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.85, 0.22), Size = UDim2.fromScale(0.15, 0.15), Max = 40, ZIndex = 4 })
	star.Rotation = 12
end

-- ============================================================
-- Screen, dim layer and floating panel
-- ============================================================

local existing = playerGui:FindFirstChild("BirthdayVIPWardrobe")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BirthdayVIPWardrobe"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global -- layers below are numbered for this mode
screenGui.Enabled = false
screenGui.Parent = playerGui

local dim = frame(screenGui, { Name = "Dim", Color = Color3.fromRGB(40, 24, 62), Transparency = 1 })

-- Root holds the shadow and the card, and is what scales on open/close.
local root = frame(screenGui, { Name = "Root", Transparency = 1, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.9) })
local rootLimit = Instance.new("UISizeConstraint")
rootLimit.MaxSize = Vector2.new(840, 520)
rootLimit.Parent = root
local rootScale = Instance.new("UIScale")
rootScale.Scale = 0.97
rootScale.Parent = root

local shadow = frame(root, { Name = "Shadow", Color = C.Plum, Transparency = 0.86, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.new(1, 10, 1, 6) })
corner(shadow, 34)

local main = frame(root, { Name = "MainFrame", Color = C.White, Transparency = 0.04, ZIndex = 2 })
corner(main, 28)
gradient(main, { C.PanelTop, C.PanelBottom }, 90)
stroke(main, C.Champagne, 1.5, 0.45)

-- Soft light across the top of the card.
local highlight = frame(main, { Name = "SoftHighlight", Color = C.White, Transparency = 0, Size = UDim2.fromScale(1, 0.4), ZIndex = 2 })
corner(highlight, 28)
local highlightFade = Instance.new("UIGradient")
highlightFade.Rotation = 90
highlightFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
highlightFade.Parent = highlight

-- ---------- Header ----------
local header = frame(main, { Name = "Header", Transparency = 1, Position = UDim2.fromScale(0.08, 0.045), Size = UDim2.fromScale(0.84, 0.17), ZIndex = 3 })
text(header, { Name = "Title", Text = "BIRTHDAY VIP DRESS UP", Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.8, 0.58), Anchor = Vector2.new(0.5, 0), Max = 34, ZIndex = 3 })
text(header, { Text = "✦", Color = C.Champagne, Position = UDim2.fromScale(0.07, 0.3), Size = UDim2.fromScale(0.06, 0.34), Anchor = Vector2.new(0.5, 0.5), Max = 26, ZIndex = 3 })
text(header, { Text = "✦", Color = C.Champagne, Position = UDim2.fromScale(0.93, 0.3), Size = UDim2.fromScale(0.06, 0.34), Anchor = Vector2.new(0.5, 0.5), Max = 26, ZIndex = 3 })
local subtitle = text(header, { Name = "Subtitle", Text = "Choose your birthday look", Font = BODY_FONT, Color = C.Purple, Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.8, 0.3), Anchor = Vector2.new(0.5, 0), Max = 17, ZIndex = 3 })

-- ---------- Close ----------
-- The tap area is 44px; the visible circle inside it is smaller and softer.
local closeButton = text(main, { Name = "Close", Button = true, Text = "", Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(44, 44), Anchor = Vector2.new(1, 0), ZIndex = 6 })
local closeDot = frame(closeButton, { Color = C.Rose, Transparency = 0.12, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32), ZIndex = 6 })
corner(closeDot, 0.5, true)
local closeX = text(closeDot, { Text = "X", Font = Enum.Font.GothamBold, Color = C.White, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.44, 0.44), Anchor = Vector2.new(0.5, 0.5), Max = 15, ZIndex = 7 })
closeX.Active = false

-- ---------- Content ----------
local content = frame(main, { Name = "Content", Color = C.White, Transparency = 0.55, Position = UDim2.fromScale(0.04, 0.235), Size = UDim2.fromScale(0.92, 0.61), ZIndex = 3 })
corner(content, 22)

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingLeft = UDim.new(0.022, 0)
contentPadding.PaddingRight = UDim.new(0.022, 0)
contentPadding.PaddingTop = UDim.new(0.045, 0)
contentPadding.PaddingBottom = UDim.new(0.045, 0)
contentPadding.Parent = content

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.Padding = UDim.new(0.026, 0)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = content

local cards = {} -- [key] = { Body, Scale, Stroke, Glow, Badge, Button, ButtonGradient }

for index, key in ipairs(Outfits.Order) do
	local outfit = Outfits[key]
	local style = STYLE[key] or STYLE.BirthdayStar

	-- Slot keeps the layout steady; Body inside it is what brightens and pulses.
	local slot = frame(content, { Name = key, Transparency = 1, Size = UDim2.fromScale(0.316, 1), ZIndex = 3 })
	slot.LayoutOrder = index

	local glow = frame(slot, { Name = "Glow", Color = C.Champagne, Transparency = 1, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 10, 1, 10), ZIndex = 3 })
	corner(glow, 24)

	local softShadow = frame(slot, { Name = "Shadow", Color = C.Plum, Transparency = 0.9, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 4), Size = UDim2.new(1, 2, 1, 2), ZIndex = 3 })
	corner(softShadow, 20)

	local body = frame(slot, { Name = "Body", Color = Color3.fromRGB(255, 253, 251), Transparency = 0.06, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })
	corner(body, 20)
	local bodyStroke = stroke(body, C.Lavender, 1, 0.7)
	local bodyScale = Instance.new("UIScale")
	bodyScale.Parent = body

	-- Preview: a tall display window with the dressed doll.
	local preview = frame(body, { Name = "Preview", Position = UDim2.fromScale(0.07, 0.045), Size = UDim2.fromScale(0.86, 0.5), ZIndex = 4 })
	corner(preview, 16)
	gradient(preview, style.Gradient, 40)
	preview.ClipsDescendants = true

	local stage = frame(preview, { Name = "Stage", Transparency = 1, Anchor = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.Parent = stage
	local draw = previews[key]
	if draw then
		draw(stage)
		for _, child in ipairs(stage:GetDescendants()) do
			if child:IsA("GuiObject") then
				child.ZIndex += 3 -- lift the drawing above the card layers
			end
		end
	end

	local badge = text(body, { Name = "Badge", Text = "WEARING", Background = C.Champagne, Color = C.Plum, Position = UDim2.new(1, -8, 0, 8), Size = UDim2.new(0.42, 0, 0.075, 0), Anchor = Vector2.new(1, 0), Max = 12, ZIndex = 12 })
	corner(badge, 0.5, true)
	badge.Visible = false
	local badgePadding = Instance.new("UIPadding")
	badgePadding.PaddingLeft = UDim.new(0.1, 0)
	badgePadding.PaddingRight = UDim.new(0.1, 0)
	badgePadding.PaddingTop = UDim.new(0.14, 0)
	badgePadding.PaddingBottom = UDim.new(0.14, 0)
	badgePadding.Parent = badge
	local badgeMin = Instance.new("UISizeConstraint")
	badgeMin.MinSize = Vector2.new(54, 16)
	badgeMin.Parent = badge

	text(body, { Name = "OutfitName", Text = outfit.DisplayName, Position = UDim2.fromScale(0.06, 0.575), Size = UDim2.fromScale(0.88, 0.1), Max = 22, ZIndex = 5 })
	text(body, { Name = "Description", Text = outfit.Description, Font = BODY_FONT, Color = C.Muted, Position = UDim2.fromScale(0.06, 0.685), Size = UDim2.fromScale(0.88, 0.075), Max = 14, ZIndex = 5 })

	local button = text(body, { Name = "Select", Button = true, Text = "SELECT", Background = style.Button, Color = style.ButtonText, Position = UDim2.fromScale(0.5, 0.955), Size = UDim2.fromScale(0.78, 0.15), Anchor = Vector2.new(0.5, 1), Max = 17, ZIndex = 5 })
	corner(button, 12)
	local buttonMin = Instance.new("UISizeConstraint")
	buttonMin.MinSize = Vector2.new(0, 30)
	buttonMin.Parent = button
	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingTop = UDim.new(0.22, 0)
	buttonPadding.PaddingBottom = UDim.new(0.22, 0)
	buttonPadding.Parent = button
	local buttonGradient = gradient(button, { C.White, C.White }, 90)

	button.MouseButton1Click:Connect(function()
		requestOutfit:FireServer(key)
	end)

	-- Hover (desktop only; touch never depends on it).
	slot.MouseEnter:Connect(function()
		tween(body, 0.12, { BackgroundTransparency = 0 })
		tween(bodyScale, 0.12, { Scale = 1.015 })
	end)
	slot.MouseLeave:Connect(function()
		tween(body, 0.15, { BackgroundTransparency = 0.06 })
		tween(bodyScale, 0.15, { Scale = 1 })
	end)
	button.MouseEnter:Connect(function()
		tween(button, 0.1, { BackgroundTransparency = 0.12 })
	end)
	button.MouseLeave:Connect(function()
		tween(button, 0.12, { BackgroundTransparency = 0 })
	end)

	cards[key] = { Body = body, Scale = bodyScale, Stroke = bodyStroke, Glow = glow, Badge = badge, Button = button, ButtonGradient = buttonGradient, Style = style }
end

-- ---------- Footer ----------
local restoreButton = text(main, { Name = "Restore", Button = true, Text = "RESTORE MY AVATAR", Background = C.Lavender, BackgroundTransparency = 0.25, Color = C.Plum, Position = UDim2.fromScale(0.5, 0.955), Size = UDim2.fromScale(0.34, 0.075), Anchor = Vector2.new(0.5, 1), Max = 15, ZIndex = 4 })
corner(restoreButton, 12)
local restoreMin = Instance.new("UISizeConstraint")
restoreMin.MinSize = Vector2.new(170, 32)
restoreMin.Parent = restoreButton
local restorePadding = Instance.new("UIPadding")
restorePadding.PaddingTop = UDim.new(0.22, 0)
restorePadding.PaddingBottom = UDim.new(0.22, 0)
restorePadding.Parent = restoreButton

restoreButton.MouseButton1Click:Connect(function()
	requestOutfit:FireServer("Restore")
end)
restoreButton.MouseEnter:Connect(function()
	tween(restoreButton, 0.1, { BackgroundTransparency = 0.05 })
end)
restoreButton.MouseLeave:Connect(function()
	tween(restoreButton, 0.12, { BackgroundTransparency = 0.25 })
end)

-- ============================================================
-- State from the server
-- ============================================================

-- The booth's "wearing" markers are shown here, on this player's screen only,
-- so each child sees their own station lit and nobody else's.
local function showStation(selected)
	local wearing = selected or "MyAvatar"
	local environment = workspace:FindFirstChild("Environment")
	local booth = environment and environment:FindFirstChild("BirthdayVIPDressUp")
	local stations = booth and booth:FindFirstChild("Stations")
	if not stations then
		return
	end
	for _, station in ipairs(stations:GetChildren()) do
		local on = (station.Name == wearing)
		local glow = station:FindFirstChild("SelectedGlow")
		if glow then
			glow.Transparency = on and 0.15 or 1
		end
		local badge = station:FindFirstChild("WearingBadge")
		if badge then
			badge.Transparency = on and 0 or 1
			local gui = badge:FindFirstChild("Label")
			if gui then
				gui.Enabled = on
			end
		end
	end
end

local currentSelected = nil

local function render(selected)
	for key, card in pairs(cards) do
		local on = (key == selected)
		card.Badge.Visible = on
		card.Stroke.Color = on and C.Champagne or C.Lavender
		card.Stroke.Thickness = on and 2 or 1
		card.Stroke.Transparency = on and 0.1 or 0.7
		card.Glow.BackgroundTransparency = on and 0.78 or 1
		card.Body.BackgroundTransparency = on and 0 or 0.06
		card.Button.Text = on and "✓  WEARING" or "SELECT"
		card.Button.TextColor3 = on and C.Plum or card.Style.ButtonText
		card.Button.BackgroundColor3 = on and C.White or card.Style.Button
		card.ButtonGradient.Color = on and ColorSequence.new(C.ChampagneLight, C.Champagne) or ColorSequence.new(C.White, C.White)
		if on and currentSelected ~= selected then
			-- Small pulse on the card that was just chosen.
			card.Scale.Scale = 1.03
			tween(card.Scale, 0.25, { Scale = 1 })
		end
	end
	currentSelected = selected
	showStation(selected)
end

local function stateLine(selected, message)
	-- Polite notices from the server (for example "come to the wardrobe") are
	-- shown as they are; the ordinary confirmations get a calmer line.
	if type(message) == "string" and not string.find(message, "is on!", 1, true) and message ~= "Your avatar is back!" then
		return message
	end
	if selected and Outfits[selected] then
		return "You're wearing " .. Outfits[selected].DisplayName .. " ✨"
	end
	if message == "Your avatar is back!" then
		return "Your own avatar is back"
	end
	return "Choose your birthday look"
end

render(nil)
task.spawn(function()
	for _ = 1, 20 do
		task.wait(1)
		showStation(currentSelected)
	end
end)

outfitState.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then
		return
	end
	local selected = (type(state.Selected) == "string" and cards[state.Selected]) and state.Selected or nil
	render(selected)
	subtitle.Text = stateLine(selected, state.Message)
end)

-- ============================================================
-- Open / close
-- ============================================================

local openToken = 0

local function open()
	openToken += 1
	screenGui.Enabled = true
	rootScale.Scale = 0.97
	dim.BackgroundTransparency = 1
	tween(rootScale, 0.22, { Scale = 1 })
	tween(dim, 0.22, { BackgroundTransparency = 0.6 })
end

local function close()
	openToken += 1
	local token = openToken
	tween(rootScale, 0.12, { Scale = 0.97 })
	tween(dim, 0.12, { BackgroundTransparency = 1 })
	task.delay(0.12, function()
		if openToken == token then
			screenGui.Enabled = false
		end
	end)
end

closeButton.MouseButton1Click:Connect(close)
closeButton.MouseEnter:Connect(function()
	tween(closeDot, 0.1, { BackgroundTransparency = 0 })
end)
closeButton.MouseLeave:Connect(function()
	tween(closeDot, 0.12, { BackgroundTransparency = 0.12 })
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if prompt.Name == PROMPT_NAME and who == player then
		open()
	end
end)
