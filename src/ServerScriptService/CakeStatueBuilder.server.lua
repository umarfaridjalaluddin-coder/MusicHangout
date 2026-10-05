-- CakeStatueBuilder (PERMANENT)
-- Builds a giant three-tier birthday cake statue on its own round plaza,
-- south-west of the lobby, under Workspace.Environment.CakeStatue.
-- Idempotent: every part is found by name or created, so a rerun updates in
-- place and never duplicates. Adds only its own objects. Plain parts only.

local Workspace = game:GetService("Workspace")

local LOG = "[CakeStatueBuilder] "

local SIGN_TEXT = "HAPPY BIRTHDAY QISYA"

-- Centre of the plaza. The ground's top surface is at Y=1.
local CX, CZ = -65, 55
local GROUND_TOP = 1
-- The corner of the lobby floor the path and the sign point toward.
local LOBBY_CORNER = Vector3.new(-20, 0, 20)

local MAT_PLASTIC = Enum.Material.SmoothPlastic
local MAT_NEON = Enum.Material.Neon

local ROSE = Color3.fromRGB(255, 150, 170)
local PEACH = Color3.fromRGB(255, 195, 150)
local LEMON = Color3.fromRGB(255, 236, 150)
local MINT = Color3.fromRGB(160, 232, 190)
local SKY = Color3.fromRGB(160, 205, 255)
local LILAC = Color3.fromRGB(200, 175, 255)
local PINK = Color3.fromRGB(255, 170, 215)
local CREAM = Color3.fromRGB(250, 246, 240)
local CHERRY = Color3.fromRGB(225, 60, 85)
local FLAME = Color3.fromRGB(255, 190, 80)
local DARK = Color3.fromRGB(10, 10, 14)
local RAINBOW = { ROSE, PEACH, LEMON, MINT, SKY, LILAC }

-- ============================================================
-- Helpers
-- ============================================================

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function make(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and child:IsA(className) then
		return child
	end
	child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function block(parent, name, size, cframe, color, canCollide)
	local p = make(parent, "Part", name)
	p.Shape = Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = MAT_PLASTIC
	p.CanCollide = canCollide ~= false
	p.CanTouch = false
	return p
end

-- An upright cylinder. Roblox cylinders lie along X, so it is turned on its end.
local function cylinder(parent, name, diameter, height, x, bottomY, z, color, canCollide)
	local p = make(parent, "Part", name)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(x, bottomY + height / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.Color = color
	p.Material = MAT_PLASTIC
	p.CanCollide = canCollide ~= false
	p.CanTouch = false
	return p
end

local function ball(parent, name, diameter, position, color)
	local p = make(parent, "Part", name)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.CFrame = CFrame.new(position)
	p.Anchored = true
	p.Color = color
	p.Material = MAT_PLASTIC
	p.CanCollide = false
	p.CanTouch = false
	return p
end

-- ============================================================
-- Folders
-- ============================================================

local environment = ensureFolder(Workspace, "Environment")
local statue = ensureFolder(environment, "CakeStatue")
local fPlaza = ensureFolder(statue, "Plaza")
local fCake = ensureFolder(statue, "Cake")
local fCandles = ensureFolder(statue, "Candles")
local fGifts = ensureFolder(statue, "Gifts")

-- ============================================================
-- Plaza, plinth and path from the lobby
-- ============================================================

cylinder(fPlaza, "PlazaRim", 37, 0.3, CX, GROUND_TOP, CZ, PINK)
cylinder(fPlaza, "PlazaFloor", 36, 0.5, CX, GROUND_TOP, CZ, LILAC)
local plazaTop = GROUND_TOP + 0.5
cylinder(fPlaza, "Plinth", 24, 2, CX, plazaTop, CZ, CREAM)
local cakeBottom = plazaTop + 2

local center = Vector3.new(CX, 0, CZ)
local toLobby = (LOBBY_CORNER - center).Unit
local pathStart = center + toLobby * 18.5
local pathMid = (pathStart + LOBBY_CORNER) / 2 + Vector3.new(0, GROUND_TOP + 0.05, 0)
local pathStrip = block(fPlaza, "PathToCake", Vector3.new(4, 0.1, (LOBBY_CORNER - pathStart).Magnitude), CFrame.lookAt(pathMid, pathMid + toLobby), PINK, false)
pathStrip.Material = MAT_NEON

-- ============================================================
-- Cake: three tiers, each with icing, drips and cherries
-- ============================================================

local function tier(index, diameter, height, bottomY, color, dripCount, cherryCount)
	local radius = diameter / 2
	local topY = bottomY + height
	cylinder(fCake, "Tier" .. index, diameter, height, CX, bottomY, CZ, color)
	cylinder(fCake, "Icing" .. index, diameter + 0.6, 0.8, CX, topY - 0.4, CZ, CREAM)

	for i = 1, dripCount do
		local angle = (i - 1) / dripCount * math.pi * 2
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = 1.4 + ((i * 7) % 5) * 0.45
		local position = Vector3.new(CX, topY - length / 2, CZ) + outward * (radius + 0.1)
		block(fCake, "Drip" .. index .. "_" .. i, Vector3.new(1.3, length, 0.5), CFrame.lookAt(position, position + outward), CREAM, false)
	end

	for i = 1, cherryCount do
		local angle = (i - 0.5) / cherryCount * math.pi * 2
		local position = Vector3.new(CX + math.cos(angle) * (radius - 1.1), topY + 1, CZ + math.sin(angle) * (radius - 1.1))
		ball(fCake, "Cherry" .. index .. "_" .. i, 1.3, position, CHERRY)
	end

	return topY
end

local top1 = tier(1, 20, 7, cakeBottom, PINK, 14, 12)
local top2 = tier(2, 14, 6, top1, LEMON, 10, 8)
local top3 = tier(3, 9, 5, top2, SKY, 7, 0)

-- ============================================================
-- Candles with flames; one soft light in the middle
-- ============================================================

local candleBottom = top3 + 0.4
for i, color in ipairs(RAINBOW) do
	local angle = (i - 1) / #RAINBOW * math.pi * 2
	local x, z = CX + math.cos(angle) * 2.8, CZ + math.sin(angle) * 2.8
	cylinder(fCandles, "Candle" .. i, 0.7, 3, x, candleBottom, z, color, false)
	local flame = ball(fCandles, "Flame" .. i, 0.9, Vector3.new(x, candleBottom + 3.5, z), FLAME)
	flame.Material = MAT_NEON
end

local glow = ball(fCandles, "CandleGlow", 0.4, Vector3.new(CX, candleBottom + 3.5, CZ), FLAME)
glow.Transparency = 1
local light = make(glow, "PointLight", "Glow")
light.Color = Color3.fromRGB(255, 220, 170)
light.Range = 30
light.Brightness = 0.6

-- ============================================================
-- Sign facing the lobby
-- ============================================================

local signPosition = center + toLobby * 14 + Vector3.new(0, plazaTop + 4.5, 0)
local signCFrame = CFrame.lookAt(signPosition, signPosition + toLobby)
local sign = block(fPlaza, "Sign", Vector3.new(16, 3, 0.4), signCFrame, DARK)
block(fPlaza, "SignPostLeft", Vector3.new(0.5, 4.5, 0.5), signCFrame * CFrame.new(-7, -3.2, 0), CREAM)
block(fPlaza, "SignPostRight", Vector3.new(0.5, 4.5, 0.5), signCFrame * CFrame.new(7, -3.2, 0), CREAM)

local gui = make(sign, "SurfaceGui", "Label")
-- CFrame.lookAt points the part's Front face at the lobby.
gui.Face = Enum.NormalId.Front
gui.LightInfluence = 0
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
local emStuds = math.min(0.85 * 16 / (0.6 * #SIGN_TEXT), 0.7 * 3)
gui.PixelsPerStud = math.clamp(math.floor(100 / emStuds), 12, 50)
local label = make(gui, "TextLabel", "Text")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = SIGN_TEXT
label.TextColor3 = LEMON
label.Font = Enum.Font.GothamBold
label.TextScaled = true

-- ============================================================
-- Gift boxes around the plaza
-- ============================================================

local function gift(index, angleDegrees, size, color, ribbon)
	local angle = math.rad(angleDegrees)
	local x, z = CX + math.cos(angle) * 14.5, CZ + math.sin(angle) * 14.5
	local spin = CFrame.Angles(0, angle, 0)
	local boxCFrame = CFrame.new(x, plazaTop + size / 2, z) * spin
	block(fGifts, "Gift" .. index, Vector3.new(size, size, size), boxCFrame, color)
	block(fGifts, "Gift" .. index .. "RibbonA", Vector3.new(size + 0.1, size + 0.1, size * 0.2), boxCFrame, ribbon, false)
	block(fGifts, "Gift" .. index .. "RibbonB", Vector3.new(size * 0.2, size + 0.1, size + 0.1), boxCFrame, ribbon, false)
	ball(fGifts, "Gift" .. index .. "Bow", size * 0.35, Vector3.new(x, plazaTop + size + size * 0.12, z), ribbon)
end

gift(1, 40, 3.2, MINT, CREAM)
gift(2, 130, 4, ROSE, LEMON)
gift(3, 220, 2.8, SKY, PINK)

print(LOG .. string.format("Cake statue complete. Top of the candles at Y=%.1f.", candleBottom + 4))
