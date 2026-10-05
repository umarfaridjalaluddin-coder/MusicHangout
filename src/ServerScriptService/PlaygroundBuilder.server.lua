-- PlaygroundBuilder (PERMANENT)
-- Builds a small playground east of the lobby, under
-- Workspace.Environment.Playground. Idempotent: every object is found by name
-- or created, so a rerun updates in place and never duplicates. Adds only its
-- own objects and never touches or deletes anything else in the map.
-- Trampolines are marked with a BouncePower attribute; the bounce itself is
-- applied by PlaygroundClient in StarterPlayerScripts.

local Workspace = game:GetService("Workspace")

local LOG = "[PlaygroundBuilder] "

local MAT_PLASTIC = Enum.Material.SmoothPlastic
local MAT_NEON = Enum.Material.Neon

local RED = Color3.fromRGB(255, 90, 90)
local ORANGE = Color3.fromRGB(255, 160, 60)
local YELLOW = Color3.fromRGB(255, 220, 80)
local GREEN = Color3.fromRGB(90, 210, 120)
local BLUE = Color3.fromRGB(80, 160, 255)
local PURPLE = Color3.fromRGB(180, 110, 255)
local PINK = Color3.fromRGB(255, 130, 200)
local WHITE = Color3.fromRGB(240, 240, 245)
local FLOOR = Color3.fromRGB(45, 95, 75)
local DARK = Color3.fromRGB(10, 10, 14)
local RAINBOW = { RED, ORANGE, YELLOW, GREEN, BLUE, PURPLE }

-- Playground floor: centre X=90, Z=0, 50 x 50 studs, top surface at Y=1.5.
local CX, CZ = 90, 0
local FLOOR_TOP = 1.5

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

-- Creates or updates an anchored part. props: ClassName, Material, CanCollide,
-- CanTouch, Shape.
local function block(parent, name, size, cframe, color, props)
	props = props or {}
	local p = make(parent, props.ClassName or "Part", name)
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = props.Material or MAT_PLASTIC
	p.CanCollide = props.CanCollide ~= false
	p.CanTouch = props.CanTouch == true
	return p
end

local function at(x, y, z)
	return CFrame.new(x, y, z)
end

local function sign(parent, name, size, cframe, text, textColor, face)
	local p = block(parent, name, size, cframe, DARK)
	local gui = make(p, "SurfaceGui", "Label")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local emStuds = math.min(0.85 * size.X / (0.6 * math.max(#text, 1)), 0.7 * size.Y)
	gui.PixelsPerStud = math.clamp(math.floor(100 / emStuds), 12, 50)
	local label = make(gui, "TextLabel", "Text")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	return p
end

-- ============================================================
-- Folders
-- ============================================================

local environment = ensureFolder(Workspace, "Environment")
local playground = ensureFolder(environment, "Playground")
local fGround = ensureFolder(playground, "Ground")
local fEntrance = ensureFolder(playground, "Entrance")
local fTrampolines = ensureFolder(playground, "Trampolines")
local fSlide = ensureFolder(playground, "Slide")
local fObby = ensureFolder(playground, "Obby")
local fSwings = ensureFolder(playground, "Swings")
local fLamps = ensureFolder(playground, "Lamps")

-- ============================================================
-- Ground, border and path from the lobby
-- ============================================================

block(fGround, "PlaygroundFloor", Vector3.new(50, 0.5, 50), at(CX, FLOOR_TOP - 0.25, CZ), FLOOR)

local trim = { CanCollide = false, Material = MAT_NEON }
block(fGround, "BorderNorth", Vector3.new(50, 0.2, 0.5), at(CX, FLOOR_TOP + 0.1, CZ - 25), YELLOW, trim)
block(fGround, "BorderSouth", Vector3.new(50, 0.2, 0.5), at(CX, FLOOR_TOP + 0.1, CZ + 25), PINK, trim)
block(fGround, "BorderEast", Vector3.new(0.5, 0.2, 50), at(CX + 25, FLOOR_TOP + 0.1, CZ), BLUE, trim)
block(fGround, "BorderWest", Vector3.new(0.5, 0.2, 50), at(CX - 25, FLOOR_TOP + 0.1, CZ), GREEN, trim)

-- Lobby floor ends at X=20; the playground floor starts at X=65.
block(fGround, "PathToPlayground", Vector3.new(45, 0.1, 4), at(42.5, 1.05, 0), YELLOW, trim)

-- ============================================================
-- Entrance gateway on the west edge, facing the lobby
-- ============================================================

block(fEntrance, "PostLeft", Vector3.new(1.5, 10, 1.5), at(CX - 25, FLOOR_TOP + 5, -8), PINK)
block(fEntrance, "PostRight", Vector3.new(1.5, 10, 1.5), at(CX - 25, FLOOR_TOP + 5, 8), BLUE)
-- Turned 90 degrees so its Front face points toward the lobby (-X).
sign(
	fEntrance,
	"PlaygroundSign",
	Vector3.new(14, 3, 0.4),
	at(CX - 25, FLOOR_TOP + 9, 0) * CFrame.Angles(0, math.rad(90), 0),
	"PLAYGROUND",
	YELLOW,
	Enum.NormalId.Front
)

for index, color in ipairs({ RED, YELLOW, GREEN, PURPLE }) do
	local z = (index <= 2) and (-11 - (index - 1) * 2.5) or (11 + (index - 3) * 2.5)
	local height = 5 + (index % 2) * 1.5
	block(fEntrance, "BalloonString" .. index, Vector3.new(0.15, height, 0.15), at(CX - 24, FLOOR_TOP + height / 2, z), WHITE, { CanCollide = false })
	block(fEntrance, "Balloon" .. index, Vector3.new(2.4, 2.4, 2.4), at(CX - 24, FLOOR_TOP + height + 1, z), color, { CanCollide = false, Shape = Enum.PartType.Ball })
end

-- ============================================================
-- Trampolines (bounce is applied on the client)
-- ============================================================

local function trampoline(name, x, z, color, power)
	block(fTrampolines, name .. "Frame", Vector3.new(11, 0.8, 11), at(x, FLOOR_TOP + 0.4, z), WHITE)
	local pad = block(fTrampolines, name .. "Pad", Vector3.new(9, 0.4, 9), at(x, FLOOR_TOP + 1, z), color, { CanTouch = true })
	pad:SetAttribute("BouncePower", power)
end

trampoline("TrampolineA", 78, -14, YELLOW, 80)
trampoline("TrampolineB", 78, 14, PINK, 110)

-- ============================================================
-- Slide: ladder up to a tower, ramp down toward +Z
-- ============================================================

local TOWER_X, TOWER_Z = 100, -12
local DECK_TOP = 12

block(fSlide, "Deck", Vector3.new(8, 1, 8), at(TOWER_X, DECK_TOP - 0.5, TOWER_Z), BLUE)
for index, offset in ipairs({ Vector3.new(-3.5, 0, -3.5), Vector3.new(3.5, 0, -3.5), Vector3.new(-3.5, 0, 3.5), Vector3.new(3.5, 0, 3.5) }) do
	local postHeight = DECK_TOP - 1 - FLOOR_TOP
	block(fSlide, "DeckPost" .. index, Vector3.new(1, postHeight, 1), at(TOWER_X + offset.X, FLOOR_TOP + postHeight / 2, TOWER_Z + offset.Z), RAINBOW[index])
end

-- Climbable ladder on the west side of the deck.
block(fSlide, "Ladder", Vector3.new(2, 12, 2), at(TOWER_X - 5, FLOOR_TOP + 6, TOWER_Z), ORANGE, { ClassName = "TrussPart" })

-- Safety rails on the three sides without the ramp.
block(fSlide, "RailNorth", Vector3.new(8, 3, 0.4), at(TOWER_X, DECK_TOP + 1.5, TOWER_Z - 3.8), YELLOW)
block(fSlide, "RailEast", Vector3.new(0.4, 3, 8), at(TOWER_X + 3.8, DECK_TOP + 1.5, TOWER_Z), YELLOW)

-- Ramp from the south edge of the deck down to the floor.
local rampTop = Vector3.new(TOWER_X, DECK_TOP, TOWER_Z + 4)
local rampBottom = Vector3.new(TOWER_X, FLOOR_TOP, TOWER_Z + 22)
local rampLength = (rampBottom - rampTop).Magnitude
local rampMid = (rampTop + rampBottom) / 2 - Vector3.new(0, 0.5, 0)
local rampCFrame = CFrame.lookAt(rampMid, rampMid + (rampBottom - rampTop))
block(fSlide, "Ramp", Vector3.new(6, 1, rampLength), rampCFrame, RED)
block(fSlide, "RampRailLeft", Vector3.new(0.5, 2, rampLength), rampCFrame * CFrame.new(-3.25, 1, 0), YELLOW)
block(fSlide, "RampRailRight", Vector3.new(0.5, 2, rampLength), rampCFrame * CFrame.new(3.25, 1, 0), YELLOW)

-- ============================================================
-- Obby: rainbow steps up to a finish platform
-- ============================================================

for index = 1, 4 do
	local x = 78 + index * 6
	local z = 20 + ((index % 2 == 0) and 2 or -2)
	block(fObby, "Step" .. index, Vector3.new(5, 1, 5), at(x, FLOOR_TOP + 2 * index - 0.5, z), RAINBOW[index])
end
block(fObby, "FinishPlatform", Vector3.new(8, 1, 8), at(109, FLOOR_TOP + 9.5, 20), PURPLE)
block(fObby, "FinishGlow", Vector3.new(8.4, 0.2, 8.4), at(109, FLOOR_TOP + 9.4, 20), YELLOW, { CanCollide = false })
-- Read from the steps side (-Z), so the text is on the Front face.
sign(fObby, "FinishSign", Vector3.new(8, 3, 0.4), at(109, FLOOR_TOP + 13.5, 23.8), "YOU DID IT!", YELLOW, Enum.NormalId.Front)

-- ============================================================
-- Swings: the swing set is built by PlaygroundRides.server.lua, where it
-- really swings. Nothing is built for it here.
-- ============================================================

-- ============================================================
-- Lamps so the playground is bright at night
-- ============================================================

for index, corner in ipairs({ Vector3.new(-23, 0, -23), Vector3.new(23, 0, -23), Vector3.new(-23, 0, 23), Vector3.new(23, 0, 23), Vector3.new(0, 0, 0) }) do
	local x, z = CX + corner.X, CZ + corner.Z
	block(fLamps, "LampPost" .. index, Vector3.new(0.6, 12, 0.6), at(x, FLOOR_TOP + 6, z), WHITE)
	local bulb = block(fLamps, "LampBulb" .. index, Vector3.new(2, 2, 2), at(x, FLOOR_TOP + 13, z), YELLOW, { CanCollide = false, Material = MAT_NEON, Shape = Enum.PartType.Ball })
	local light = make(bulb, "PointLight", "Glow")
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Range = 26
	light.Brightness = 0.5
end

print(LOG .. "Playground complete.")
