-- ZooBuilder (PERMANENT)
-- Turns the old shop corner into a mini zoo, under
-- Workspace.Environment.MiniZoo. Six fenced pens line a central walkway:
-- elephant, giraffe and lion on the north side; zebra, capybaras and flamingos
-- on the south side. The animals are simple original designs made only from
-- plain parts. Idempotent: every part is found by name or created, so a rerun
-- updates in place and never duplicates.
-- The animals walk around their pens: this script builds them and publishes
-- movement settings as attributes; ZooClient does the moving on each player's
-- device.
-- The only existing map object touched is the text on ShopArea.ShopSign, which
-- is changed from "SHOP" to "MINI ZOO". Nothing is moved or deleted.

local Workspace = game:GetService("Workspace")

local LOG = "[ZooBuilder] "

local ENTRANCE_TEXT = "QISYA'S MINI ZOO"

-- Zoo footprint. The old ShopFloor (X -105..-75, Z -15..15, top Y=2) lies
-- underneath the grass.
local WEST, EAST = -122, -78
local NORTH, SOUTH = -24, 24
local WALK = 3.5 -- half the width of the walkway along Z=0
local GRASS_TOP = 2.1
local DIVIDERS = { -108, -93 }

local MAT_PLASTIC = Enum.Material.SmoothPlastic

local GRASS = Color3.fromRGB(70, 140, 85)
local SAND = Color3.fromRGB(225, 205, 160)
local WOOD = Color3.fromRGB(150, 110, 75)
local CREAM = Color3.fromRGB(250, 246, 240)
local DARK = Color3.fromRGB(10, 10, 14)
local LEMON = Color3.fromRGB(255, 236, 150)
local WATER = Color3.fromRGB(120, 195, 240)
local ROCK = Color3.fromRGB(135, 135, 140)
local BLACK = Color3.fromRGB(30, 30, 36)
local WHITE = Color3.fromRGB(245, 245, 245)
local GREY = Color3.fromRGB(150, 155, 165)
local GREY_DARK = Color3.fromRGB(120, 125, 135)
local GIRAFFE = Color3.fromRGB(245, 205, 110)
local BROWN = Color3.fromRGB(140, 90, 50)
local TAN = Color3.fromRGB(225, 175, 105)
local CAPYBARA = Color3.fromRGB(165, 115, 70)
local CAPYBARA_DARK = Color3.fromRGB(125, 85, 50)
local PINK = Color3.fromRGB(255, 150, 190)
local PINK_DARK = Color3.fromRGB(230, 110, 150)

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
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = MAT_PLASTIC
	p.CanCollide = canCollide ~= false
	p.CanTouch = false
	return p
end

local function addText(part, text, textColor)
	local gui = make(part, "SurfaceGui", "Label")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local emStuds = math.min(0.85 * part.Size.X / (0.6 * math.max(#text, 1)), 0.7 * part.Size.Y)
	gui.PixelsPerStud = math.clamp(math.floor(100 / emStuds), 12, 50)
	local label = make(gui, "TextLabel", "Text")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
end

-- ============================================================
-- Folders
-- ============================================================

local environment = ensureFolder(Workspace, "Environment")
local zoo = ensureFolder(environment, "MiniZoo")
local fGround = ensureFolder(zoo, "Ground")
local fFences = ensureFolder(zoo, "Fences")
local fSigns = ensureFolder(zoo, "Signs")
local fAnimals = ensureFolder(zoo, "Animals")

-- ============================================================
-- Ground and walkway
-- ============================================================

local midX = (WEST + EAST) / 2
block(fGround, "Grass", Vector3.new(EAST - WEST, GRASS_TOP - 1, SOUTH - NORTH), CFrame.new(midX, (GRASS_TOP + 1) / 2, 0), GRASS).Material = Enum.Material.Grass
block(fGround, "Walkway", Vector3.new(EAST - WEST, 0.1, WALK * 2), CFrame.new(midX, GRASS_TOP + 0.05, 0), SAND)

-- ============================================================
-- Fences: a two-bar wooden rail between two ground points
-- ============================================================

local function fence(name, x1, z1, x2, z2)
	local from = Vector3.new(x1, GRASS_TOP, z1)
	local to = Vector3.new(x2, GRASS_TOP, z2)
	local length = (to - from).Magnitude
	local along = CFrame.lookAt((from + to) / 2, to)
	block(fFences, name .. "Top", Vector3.new(0.3, 0.3, length), along + Vector3.new(0, 2.1, 0), WOOD)
	block(fFences, name .. "Mid", Vector3.new(0.3, 0.3, length), along + Vector3.new(0, 1.1, 0), WOOD)
	local gaps = math.max(1, math.floor(length / 4 + 0.5))
	for i = 0, gaps do
		local at = from:Lerp(to, i / gaps)
		block(fFences, name .. "Post" .. i, Vector3.new(0.5, 2.4, 0.5), CFrame.new(at + Vector3.new(0, 1.2, 0)), WOOD)
	end
end

fence("North", WEST, NORTH, EAST, NORTH)
fence("South", WEST, SOUTH, EAST, SOUTH)
fence("West", WEST, NORTH, WEST, SOUTH)
fence("EastNorth", EAST, NORTH, EAST, -WALK)
fence("EastSouth", EAST, WALK, EAST, SOUTH)
fence("WalkNorth", WEST, -WALK, EAST, -WALK)
fence("WalkSouth", WEST, WALK, EAST, WALK)
for index, x in ipairs(DIVIDERS) do
	fence("DividerNorth" .. index, x, NORTH, x, -WALK)
	fence("DividerSouth" .. index, x, WALK, x, SOUTH)
end

-- ============================================================
-- Entrance arch facing the lobby (+X), and the old shop sign's new text
-- ============================================================

block(fSigns, "EntrancePostLeft", Vector3.new(0.8, 9, 0.8), CFrame.new(EAST, GRASS_TOP + 4.5, -WALK - 1), WOOD)
block(fSigns, "EntrancePostRight", Vector3.new(0.8, 9, 0.8), CFrame.new(EAST, GRASS_TOP + 4.5, WALK + 1), WOOD)
local archPosition = Vector3.new(EAST, GRASS_TOP + 8, 0)
local arch = block(fSigns, "EntranceSign", Vector3.new(11, 2.4, 0.4), CFrame.lookAt(archPosition, archPosition + Vector3.xAxis), DARK)
addText(arch, ENTRANCE_TEXT, LEMON)

local shopArea = Workspace:FindFirstChild("ShopArea")
local shopSign = shopArea and shopArea:FindFirstChild("ShopSign")
local shopGui = shopSign and shopSign:FindFirstChild("SignGui")
local shopText = shopGui and shopGui:FindFirstChild("SignText")
if shopText and shopText:IsA("TextLabel") then
	shopText.Text = "MINI ZOO"
else
	warn(LOG .. "ShopArea.ShopSign text not found; its wording was left as it is.")
end

-- ============================================================
-- Animals. Each is drawn around an origin on the grass; forward is -Z of the
-- origin, and the origin is turned so the animal faces the walkway.
-- ============================================================

local function penOrigin(x, z)
	local position = Vector3.new(x, GRASS_TOP, z)
	local towardWalkway = Vector3.new(0, 0, z < 0 and 1 or -1)
	return CFrame.lookAt(position, position + towardWalkway)
end

-- Returns a function that adds one piece to an animal.
local function builder(folderName, origin)
	local folder = ensureFolder(fAnimals, folderName)
	-- ZooClient animates the animal around this starting position.
	folder:SetAttribute("Origin", origin)
	return function(name, size, offset, color, shape)
		local p = block(folder, name, size, origin * offset, color)
		if shape then
			p.Shape = shape
		end
		return p
	end
end

local BALL = Enum.PartType.Ball
local at = CFrame.new
local function tilt(degrees)
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

local function elephant(origin)
	local add = builder("Elephant", origin)
	add("Body", Vector3.new(5, 4, 7), at(0, 4.5, 0), GREY)
	for i, leg in ipairs({ { -1.6, -2.4 }, { 1.6, -2.4 }, { -1.6, 2.4 }, { 1.6, 2.4 } }) do
		add("Leg" .. i, Vector3.new(1.4, 2.5, 1.4), at(leg[1], 1.25, leg[2]), GREY_DARK)
	end
	add("Head", Vector3.new(3.6, 3.4, 3), at(0, 5, -4.6), GREY)
	add("EarLeft", Vector3.new(0.4, 3, 2.4), at(-2.1, 5.2, -4.2), GREY_DARK)
	add("EarRight", Vector3.new(0.4, 3, 2.4), at(2.1, 5.2, -4.2), GREY_DARK)
	add("TrunkUpper", Vector3.new(1, 2.6, 1), at(0, 3.2, -6.4), GREY)
	add("TrunkLower", Vector3.new(0.85, 1.4, 0.85), at(0, 1.6, -6.9) * tilt(-25), GREY)
	add("TuskLeft", Vector3.new(0.3, 0.3, 1.5), at(-0.95, 3.9, -6.6), CREAM)
	add("TuskRight", Vector3.new(0.3, 0.3, 1.5), at(0.95, 3.9, -6.6), CREAM)
	add("EyeLeft", Vector3.new(0.4, 0.4, 0.4), at(-1.3, 5.8, -6.1), BLACK, BALL)
	add("EyeRight", Vector3.new(0.4, 0.4, 0.4), at(1.3, 5.8, -6.1), BLACK, BALL)
	add("Tail", Vector3.new(0.3, 2.2, 0.3), at(0, 4.6, 3.7), GREY_DARK)
end

local function giraffe(origin)
	local add = builder("Giraffe", origin)
	add("Body", Vector3.new(2.6, 2.8, 5), at(0, 6.4, 0), GIRAFFE)
	for i, leg in ipairs({ { -0.9, -1.9 }, { 0.9, -1.9 }, { -0.9, 1.9 }, { 0.9, 1.9 } }) do
		add("Leg" .. i, Vector3.new(0.7, 5, 0.7), at(leg[1], 2.5, leg[2]), GIRAFFE)
		add("Hoof" .. i, Vector3.new(0.8, 0.5, 0.8), at(leg[1], 0.25, leg[2]), BROWN)
	end
	add("Neck", Vector3.new(1.2, 7.2, 1.2), at(0, 10.6, -3) * tilt(-12), GIRAFFE)
	add("Head", Vector3.new(1.3, 1.3, 2.4), at(0, 14.4, -4.3), GIRAFFE)
	add("HornLeft", Vector3.new(0.25, 0.8, 0.25), at(-0.35, 15.4, -3.7), BROWN)
	add("HornRight", Vector3.new(0.25, 0.8, 0.25), at(0.35, 15.4, -3.7), BROWN)
	add("EyeLeft", Vector3.new(0.3, 0.3, 0.3), at(-0.68, 14.6, -4.6), BLACK, BALL)
	add("EyeRight", Vector3.new(0.3, 0.3, 0.3), at(0.68, 14.6, -4.6), BLACK, BALL)
	for i, spot in ipairs({ { 6.9, -1.4 }, { 5.9, 0.2 }, { 6.8, 1.5 } }) do
		add("SpotLeft" .. i, Vector3.new(0.1, 0.9, 1), at(-1.33, spot[1], spot[2]), BROWN)
		add("SpotRight" .. i, Vector3.new(0.1, 0.9, 1), at(1.33, spot[1], spot[2]), BROWN)
	end
	add("Tail", Vector3.new(0.25, 2.4, 0.25), at(0, 5.6, 2.7), BROWN)
end

local function lion(origin)
	local add = builder("Lion", origin)
	add("Body", Vector3.new(2.6, 2.4, 5), at(0, 3, 0), TAN)
	for i, leg in ipairs({ { -0.9, -1.9 }, { 0.9, -1.9 }, { -0.9, 1.9 }, { 0.9, 1.9 } }) do
		add("Leg" .. i, Vector3.new(0.8, 1.8, 0.8), at(leg[1], 0.9, leg[2]), TAN)
	end
	add("Mane", Vector3.new(3.8, 3.8, 1.6), at(0, 3.8, -2.9), BROWN)
	add("Head", Vector3.new(2.2, 2.2, 1.6), at(0, 3.8, -3.9), TAN)
	add("Nose", Vector3.new(0.6, 0.4, 0.3), at(0, 3.6, -4.8), BROWN)
	add("EyeLeft", Vector3.new(0.35, 0.35, 0.35), at(-0.6, 4.3, -4.7), BLACK, BALL)
	add("EyeRight", Vector3.new(0.35, 0.35, 0.35), at(0.6, 4.3, -4.7), BLACK, BALL)
	add("Tail", Vector3.new(0.3, 0.3, 2.4), at(0, 3.5, 3.6), TAN)
	add("TailTuft", Vector3.new(0.8, 0.8, 0.8), at(0, 3.5, 4.9), BROWN, BALL)
end

local function zebra(origin)
	local add = builder("Zebra", origin)
	add("Body", Vector3.new(2.2, 2.4, 4.6), at(0, 3.6, 0), WHITE)
	for i, z in ipairs({ -1.6, -0.55, 0.5, 1.55 }) do
		add("Stripe" .. i, Vector3.new(2.3, 2.5, 0.4), at(0, 3.6, z), BLACK)
	end
	for i, leg in ipairs({ { -0.75, -1.8 }, { 0.75, -1.8 }, { -0.75, 1.8 }, { 0.75, 1.8 } }) do
		add("Leg" .. i, Vector3.new(0.6, 2.4, 0.6), at(leg[1], 1.2, leg[2]), WHITE)
		add("Hoof" .. i, Vector3.new(0.7, 0.5, 0.7), at(leg[1], 0.25, leg[2]), BLACK)
	end
	add("Neck", Vector3.new(1, 2.8, 1), at(0, 5.3, -2.5) * tilt(-25), WHITE)
	add("NeckStripe", Vector3.new(1.1, 0.4, 1.1), at(0, 5.3, -2.5) * tilt(-25), BLACK)
	add("Head", Vector3.new(1, 1.1, 2), at(0, 6.5, -3.6), WHITE)
	add("Muzzle", Vector3.new(1.05, 0.9, 0.6), at(0, 6.4, -4.4), BLACK)
	add("Mane", Vector3.new(0.3, 2.4, 0.5), at(0, 5.9, -2) * tilt(-25), BLACK)
	add("EyeLeft", Vector3.new(0.3, 0.3, 0.3), at(-0.53, 6.8, -3.4), BLACK, BALL)
	add("EyeRight", Vector3.new(0.3, 0.3, 0.3), at(0.53, 6.8, -3.4), BLACK, BALL)
	add("Tail", Vector3.new(0.25, 2, 0.25), at(0, 3.6, 2.45), BLACK)
end

local function capybara(folderName, origin)
	local add = builder(folderName, origin)
	add("Body", Vector3.new(2.2, 2, 3.8), at(0, 1.7, 0), CAPYBARA)
	for i, leg in ipairs({ { -0.75, -1.3 }, { 0.75, -1.3 }, { -0.75, 1.3 }, { 0.75, 1.3 } }) do
		add("Leg" .. i, Vector3.new(0.6, 0.8, 0.6), at(leg[1], 0.4, leg[2]), CAPYBARA_DARK)
	end
	add("Head", Vector3.new(1.7, 1.6, 2), at(0, 2.5, -2.5), CAPYBARA)
	add("Snout", Vector3.new(1.4, 1.1, 0.7), at(0, 2.3, -3.7), CAPYBARA_DARK)
	add("Nose", Vector3.new(0.5, 0.3, 0.2), at(0, 2.6, -4.1), BLACK)
	add("EarLeft", Vector3.new(0.4, 0.4, 0.3), at(-0.6, 3.4, -1.9), CAPYBARA_DARK)
	add("EarRight", Vector3.new(0.4, 0.4, 0.3), at(0.6, 3.4, -1.9), CAPYBARA_DARK)
	add("EyeLeft", Vector3.new(0.25, 0.25, 0.25), at(-0.87, 2.9, -2.9), BLACK, BALL)
	add("EyeRight", Vector3.new(0.25, 0.25, 0.25), at(0.87, 2.9, -2.9), BLACK, BALL)
end

local function flamingo(folderName, origin)
	local add = builder(folderName, origin)
	add("Leg", Vector3.new(0.2, 3, 0.2), at(0, 1.5, 0), PINK_DARK)
	add("Body", Vector3.new(1.6, 1.3, 2.2), at(0, 3.5, 0), PINK)
	add("Tail", Vector3.new(1, 0.6, 0.8), at(0, 3.7, 1.4), PINK_DARK)
	add("Neck", Vector3.new(0.4, 2.4, 0.4), at(0, 5, -1.1) * tilt(-15), PINK)
	add("Head", Vector3.new(0.7, 0.7, 0.9), at(0, 6.3, -1.6), PINK)
	add("Beak", Vector3.new(0.3, 0.3, 0.7), at(0, 6.1, -2.3), BLACK)
	add("EyeLeft", Vector3.new(0.2, 0.2, 0.2), at(-0.36, 6.4, -1.8), BLACK, BALL)
	add("EyeRight", Vector3.new(0.2, 0.2, 0.2), at(0.36, 6.4, -1.8), BLACK, BALL)
end

-- ============================================================
-- Pens: animal, name sign on the walkway fence, and any scenery
-- ============================================================

local PEN_X = { -115, -100.5, -85.5 }
local NORTH_Z, SOUTH_Z = -14, 14

local function penSign(name, text, x, north)
	local z = north and (-WALK + 0.45) or (WALK - 0.45)
	local position = Vector3.new(x, GRASS_TOP + 3.3, z)
	local facing = Vector3.new(0, 0, north and 1 or -1)
	local sign = block(fSigns, name, Vector3.new(7, 1.6, 0.3), CFrame.lookAt(position, position + facing), DARK, false)
	addText(sign, text, LEMON)
	block(fSigns, name .. "Post", Vector3.new(0.3, 2.6, 0.3), CFrame.new(x, GRASS_TOP + 1.3, north and -WALK or WALK), WOOD, false)
end

giraffe(penOrigin(PEN_X[1], NORTH_Z))
penSign("GiraffeSign", "GIRAFFE", PEN_X[1], true)

elephant(penOrigin(PEN_X[2], NORTH_Z))
penSign("ElephantSign", "ELEPHANT", PEN_X[2], true)

lion(penOrigin(PEN_X[3], NORTH_Z))
penSign("LionSign", "LION", PEN_X[3], true)

-- Flamingo pond.
block(fGround, "FlamingoPond", Vector3.new(10, 0.1, 12), CFrame.new(PEN_X[1], GRASS_TOP + 0.05, SOUTH_Z + 1), WATER, false)
flamingo("Flamingo1", penOrigin(PEN_X[1] - 2.5, SOUTH_Z - 1))
flamingo("Flamingo2", penOrigin(PEN_X[1] + 2, SOUTH_Z + 2) * CFrame.Angles(0, math.rad(30), 0))
flamingo("Flamingo3", penOrigin(PEN_X[1] - 0.5, SOUTH_Z + 5) * CFrame.Angles(0, math.rad(-35), 0))
penSign("FlamingoSign", "FLAMINGOS", PEN_X[1], false)

-- Capybara pond with a sandy bank and two rocks.
block(fGround, "CapybaraPond", Vector3.new(10, 0.1, 8), CFrame.new(PEN_X[2], GRASS_TOP + 0.05, SOUTH_Z + 4), WATER, false)
block(fGround, "CapybaraBank", Vector3.new(11, 0.12, 5), CFrame.new(PEN_X[2], GRASS_TOP + 0.06, SOUTH_Z - 2.5), SAND, false)
block(fGround, "RockLarge", Vector3.new(2.6, 1.6, 2.2), CFrame.new(PEN_X[2] + 4.5, GRASS_TOP + 0.8, SOUTH_Z + 1), ROCK)
block(fGround, "RockSmall", Vector3.new(1.6, 1, 1.4), CFrame.new(PEN_X[2] - 4.8, GRASS_TOP + 0.5, SOUTH_Z + 6), ROCK)
capybara("Capybara1", penOrigin(PEN_X[2] - 2.5, SOUTH_Z - 3))
capybara("Capybara2", penOrigin(PEN_X[2] + 1.5, SOUTH_Z - 1.5) * CFrame.Angles(0, math.rad(30), 0))
-- This one sits in the pond, half under the water.
capybara("Capybara3", penOrigin(PEN_X[2] - 0.5, SOUTH_Z + 4.5) * CFrame.new(0, -0.9, 0) * CFrame.Angles(0, math.rad(-40), 0))
penSign("CapybaraSign", "CAPYBARAS", PEN_X[2], false)

zebra(penOrigin(PEN_X[3], SOUTH_Z))
penSign("ZebraSign", "ZEBRA", PEN_X[3], false)

-- ============================================================
-- Soft lamps along the walkway
-- ============================================================

for index, x in ipairs({ -112, -100, -88 }) do
	local lamp = block(fGround, "Lamp" .. index, Vector3.new(1.2, 1.2, 1.2), CFrame.new(x, GRASS_TOP + 9, 0), LEMON, false)
	lamp.Shape = BALL
	lamp.Material = Enum.Material.Neon
	local light = make(lamp, "PointLight", "Glow")
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Range = 30
	light.Brightness = 0.6
end

-- ============================================================
-- Movement settings, read by ZooClient in StarterPlayerScripts. The animals
-- are built here standing still; each player's own device walks them around
-- inside these limits, so the movement is smooth and costs the server nothing.
-- Each entry: MinX, MaxX, MinZ, MaxZ, walking speed, leg stride.
-- ============================================================

local ROAM = {
	Giraffe = { -117, -113, -19, -8.5, 2, 0.6 },
	Elephant = { -101.5, -99.5, -17.5, -11, 1.5, 0.5 },
	Lion = { -88.5, -82.5, -19.5, -8, 2.2, 0.4 },
	Zebra = { -88.5, -82.5, 8, 19.5, 2.5, 0.45 },
	Capybara1 = { -104.5, -96.5, 7, 13, 1.6, 0.2 },
	Capybara2 = { -104.5, -96.5, 7, 13, 1.6, 0.2 },
	Flamingo1 = { -119, -111, 10, 20, 0.9, 0 },
	Flamingo2 = { -119, -111, 10, 20, 0.9, 0 },
	Flamingo3 = { -119, -111, 10, 20, 0.9, 0 },
}

for _, folder in ipairs(fAnimals:GetChildren()) do
	local roam = ROAM[folder.Name]
	if roam then
		folder:SetAttribute("MinX", roam[1])
		folder:SetAttribute("MaxX", roam[2])
		folder:SetAttribute("MinZ", roam[3])
		folder:SetAttribute("MaxZ", roam[4])
		folder:SetAttribute("Speed", roam[5])
		folder:SetAttribute("Stride", roam[6])
	else
		-- No roaming limits: the animal stays where it is and only bobs and
		-- turns slowly (the capybara sitting in the pond).
		folder:SetAttribute("Float", true)
	end
	-- Set last, so the client knows how many parts to wait for.
	folder:SetAttribute("PartCount", #folder:GetChildren())
end

print(LOG .. "Mini zoo complete.")
