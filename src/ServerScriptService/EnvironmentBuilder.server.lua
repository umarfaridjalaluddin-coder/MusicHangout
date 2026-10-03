-- EnvironmentBuilder (PERMANENT)
-- Idempotent, code-driven visual upgrade of the Music Hangout venue.
-- Creates/updates ONLY objects it owns (under Workspace.Environment, plus
-- recoloring a small set of known existing structural parts by name).
-- Never deletes anything it doesn't recognize. Safe to rerun any number
-- of times -- reruns update existing objects in place rather than
-- duplicating them.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LOG = "[EnvironmentBuilder] "

-- ============================================================
-- Palette / constants
-- ============================================================

local COLOR_CHARCOAL = Color3.fromRGB(28, 28, 32)
local COLOR_DARKGREY = Color3.fromRGB(45, 45, 52)
local COLOR_METAL = Color3.fromRGB(60, 62, 68)
local COLOR_CYAN = Color3.fromRGB(60, 220, 255)
local COLOR_MAGENTA = Color3.fromRGB(230, 70, 220)
local COLOR_WARM = Color3.fromRGB(255, 190, 120)

local MAT_STRUCTURE = Enum.Material.Metal
local MAT_PANEL = Enum.Material.SmoothPlastic
local MAT_NEON = Enum.Material.Neon

-- ============================================================
-- Helpers
-- ============================================================

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if f and not f:IsA("Folder") then
		warn(LOG .. parent:GetFullName() .. "." .. name .. " exists but is a " .. f.ClassName .. ". Removing it.")
		f:Destroy()
		f = nil
	end
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- Creates or updates a decorative Part by name under `parent`. Idempotent:
-- a second run with the same name updates properties instead of duplicating.
local function part(parent, name, size, pos, props)
	local p = parent:FindFirstChild(name)
	if p and not p:IsA("BasePart") then
		warn(LOG .. "Replacing non-Part " .. parent:GetFullName() .. "." .. name)
		p:Destroy()
		p = nil
	end
	if not p then
		p = Instance.new("Part")
		p.Name = name
		p.Parent = parent
	end
	p.Size = size
	p.Position = pos
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = props and props.CastShadow ~= false
	p.Material = (props and props.Material) or MAT_PANEL
	p.Color = (props and props.Color) or COLOR_DARKGREY
	p.CanCollide = (props and props.CanCollide) == true
	if props and props.Transparency then
		p.Transparency = props.Transparency
	end
	if props and props.Orientation then
		p.Orientation = props.Orientation
	end
	return p
end

-- Recolors/re-materials an EXISTING structural part by name, without
-- touching its Size/Position/CanCollide. Used only on known Phase 1/2
-- objects that must keep their original geometry.
local function restyleExisting(parent, name, material, color)
	local p = parent and parent:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		p.Material = material
		p.Color = color
	else
		warn(LOG .. "Expected existing part not found for restyle: " .. tostring(parent and parent:GetFullName()) .. "." .. name)
	end
end

-- `face` is the part face the text is drawn on. Defaults to Front (-Z at
-- orientation 0); pass Enum.NormalId.Back for signs viewed from the +Z side.
local function surfaceLabel(parent, name, size, pos, orientation, text, textColor, bgColor, face)
	local p = part(parent, name, size, pos, { Material = MAT_PANEL, Color = bgColor or COLOR_CHARCOAL, Orientation = orientation })

	local gui = p:FindFirstChild("Label")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Label"
		gui.Parent = p
	end
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- TextScaled caps text at 100px, so choose a pixel density that lets the
	-- text fill about 85% of the panel width (or 70% of its height) at that cap.
	local emStuds = math.min(0.85 * size.X / (0.6 * math.max(#text, 1)), 0.7 * size.Y)
	gui.PixelsPerStud = math.clamp(math.floor(100 / emStuds), 12, 50)

	local label = gui:FindFirstChild("Text")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Parent = gui
	end
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or COLOR_CYAN
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true

	return p
end

-- ============================================================
-- Root environment folder
-- ============================================================

local environment = ensureFolder(Workspace, "Environment")
local fArchitecture = ensureFolder(environment, "Architecture")
local fStageDecor = ensureFolder(environment, "StageDecor")
local fDJDecor = ensureFolder(environment, "DJBoothDecor")
local fDanceDecor = ensureFolder(environment, "DanceFloorDecor")
local fVIPDecor = ensureFolder(environment, "VIPDecor")
local fShopDecor = ensureFolder(environment, "ShopDecor")
local fOutdoorDecor = ensureFolder(environment, "OutdoorDecor")
local fPhotoDecor = ensureFolder(environment, "PhotoSpotDecor")
local fLobbyDecor = ensureFolder(environment, "LobbyDecor")
local fPaths = ensureFolder(environment, "Paths")

-- ============================================================
-- Restyle known existing structural parts (same geometry, new materials)
-- ============================================================

local stageZone = Workspace:FindFirstChild("Stage")
local djZone = Workspace:FindFirstChild("DJBooth")
local danceZone = Workspace:FindFirstChild("DanceFloor")
local vipZone = Workspace:FindFirstChild("VIPArea")
local shopZone = Workspace:FindFirstChild("ShopArea")
local outdoorZone = Workspace:FindFirstChild("Outdoor")
local photoZone = Workspace:FindFirstChild("PhotoSpot")
local lobbyZone = Workspace:FindFirstChild("Lobby")

if stageZone then
	restyleExisting(stageZone, "StageFloor", MAT_STRUCTURE, COLOR_CHARCOAL)
	restyleExisting(stageZone, "StageBackWall", MAT_STRUCTURE, COLOR_CHARCOAL)
	restyleExisting(stageZone, "StageRoof", MAT_STRUCTURE, COLOR_DARKGREY)
	restyleExisting(stageZone, "StageLeftSupport", MAT_STRUCTURE, COLOR_METAL)
	restyleExisting(stageZone, "StageRightSupport", MAT_STRUCTURE, COLOR_METAL)
	restyleExisting(stageZone, "StageLeftFrontSupport", MAT_STRUCTURE, COLOR_METAL)
	restyleExisting(stageZone, "StageRightFrontSupport", MAT_STRUCTURE, COLOR_METAL)
end
if djZone then
	restyleExisting(djZone, "DJBoothBase", MAT_STRUCTURE, COLOR_CHARCOAL)
	restyleExisting(djZone, "DJDeskTop", MAT_STRUCTURE, COLOR_METAL)
end
if vipZone then
	restyleExisting(vipZone, "VIPFloor", MAT_PANEL, COLOR_DARKGREY)
end
if shopZone then
	restyleExisting(shopZone, "ShopFloor", MAT_PANEL, COLOR_DARKGREY)
end

-- ============================================================
-- STAGE: trusses, LED panels, edge lighting, BirthdayScreen
-- ============================================================

if stageZone then
	-- Horizontal trusses along the roof's front and side edges (decorative, non-colliding)
	part(fStageDecor, "TrussFront", Vector3.new(60, 1, 1), Vector3.new(0, 20, -75.5), { Material = MAT_STRUCTURE, Color = COLOR_METAL })
	part(fStageDecor, "TrussLeft", Vector3.new(1, 1, 30), Vector3.new(-30, 20, -90), { Material = MAT_STRUCTURE, Color = COLOR_METAL })
	part(fStageDecor, "TrussRight", Vector3.new(1, 1, 30), Vector3.new(30, 20, -90), { Material = MAT_STRUCTURE, Color = COLOR_METAL })

	-- Neon LED accent strips on the back wall
	part(fStageDecor, "LEDStripLeft", Vector3.new(1, 14, 0.2), Vector3.new(-25, 12, -102.9), { Material = MAT_NEON, Color = COLOR_CYAN })
	part(fStageDecor, "LEDStripRight", Vector3.new(1, 14, 0.2), Vector3.new(25, 12, -102.9), { Material = MAT_NEON, Color = COLOR_MAGENTA })

	-- Stage floor edge lighting (thin neon strip along the front edge, non-colliding)
	part(fStageDecor, "StageEdgeLight", Vector3.new(60, 0.2, 0.5), Vector3.new(0, 5.1, -75.2), { Material = MAT_NEON, Color = COLOR_CYAN })

	-- Large BirthdayScreen: physical display only, no video yet.
	-- Mounted on the stage back wall, facing the dance floor (+Z direction).
	-- Sized to fit the back wall between the stage floor (top Y=5) and the
	-- roof (bottom Y=20): spans Y 5.5 to 19.5.
	local birthdayScreen = surfaceLabel(
		fArchitecture,
		"BirthdayScreen",
		Vector3.new(40, 14, 0.5),
		Vector3.new(0, 12.5, -102.7),
		Vector3.new(0, 0, 0),
		"MUSIC HANGOUT",
		COLOR_CYAN,
		Color3.fromRGB(10, 10, 14),
		Enum.NormalId.Back
	)
	-- Keep the title in the top band of the screen so the DJ booth and its
	-- display panel (up to Y=14.5) do not cover it.
	local screenText = birthdayScreen.Label.Text
	screenText.Size = UDim2.fromScale(1, 0.3)
	screenText.Position = UDim2.fromScale(0, 0.02)
end

-- ============================================================
-- DJ BOOTH: trim, small display panel
-- ============================================================

if djZone then
	part(fDJDecor, "DeskTrim", Vector3.new(10.2, 0.2, 5.2), Vector3.new(0, 12.1, -100), { Material = MAT_NEON, Color = COLOR_MAGENTA })
	surfaceLabel(
		fDJDecor,
		"DJDisplayPanel",
		Vector3.new(6, 2, 0.3),
		Vector3.new(0, 13.5, -100),
		Vector3.new(0, 0, 0),
		"DJ",
		COLOR_MAGENTA,
		Color3.fromRGB(10, 10, 14),
		Enum.NormalId.Back
	)
end

-- ============================================================
-- DANCE FLOOR: neon border + center emblem
-- ============================================================

if danceZone then
	-- Border strips framing DanceFloorPad (center 0,1.5,-55, size 50x1x40 -> edges at X=-25/25, Z=-75/-35)
	part(fDanceDecor, "BorderNorth", Vector3.new(50, 0.2, 0.5), Vector3.new(0, 2.1, -75), { Material = MAT_NEON, Color = COLOR_CYAN })
	part(fDanceDecor, "BorderSouth", Vector3.new(50, 0.2, 0.5), Vector3.new(0, 2.1, -35), { Material = MAT_NEON, Color = COLOR_CYAN })
	part(fDanceDecor, "BorderWest", Vector3.new(0.5, 0.2, 40), Vector3.new(-25, 2.1, -55), { Material = MAT_NEON, Color = COLOR_MAGENTA })
	part(fDanceDecor, "BorderEast", Vector3.new(0.5, 0.2, 40), Vector3.new(25, 2.1, -55), { Material = MAT_NEON, Color = COLOR_MAGENTA })

	-- Center emblem (flat, walkable-over, flush with floor top)
	part(fDanceDecor, "CenterEmblem", Vector3.new(10, 0.05, 10), Vector3.new(0, 2.03, -55), { Material = MAT_NEON, Color = COLOR_CYAN, CanCollide = false })
end

-- ============================================================
-- VIP LOUNGE: raised platform, simple sofas/table, trim
-- ============================================================

if vipZone then
	-- VIPFloor spans X[80,120] Z[-80,-40], top Y=2. Raised inner platform:
	part(fVIPDecor, "VIPPlatform", Vector3.new(24, 1, 24), Vector3.new(100, 2.5, -60), { Material = MAT_PANEL, Color = COLOR_CHARCOAL, CanCollide = true })

	-- Simple two-part sofas (seat + back) on two sides of a central table
	local function sofa(name, pos, orientationY)
		local seat = part(fVIPDecor, name .. "Seat", Vector3.new(6, 1.2, 2.5), pos, { Material = MAT_PANEL, Color = COLOR_METAL, CanCollide = true })
		seat.Orientation = Vector3.new(0, orientationY, 0)
		local backPos = pos + (CFrame.Angles(0, math.rad(orientationY), 0) * Vector3.new(0, 1.2, -1.1))
		local back = part(fVIPDecor, name .. "Back", Vector3.new(6, 2.2, 0.3), backPos, { Material = MAT_PANEL, Color = COLOR_METAL, CanCollide = true })
		back.Orientation = Vector3.new(0, orientationY, 0)
	end

	sofa("SofaNorth", Vector3.new(100, 3.6, -70), 0)
	sofa("SofaSouth", Vector3.new(100, 3.6, -50), 180)

	part(fVIPDecor, "VIPTable", Vector3.new(4, 1.5, 4), Vector3.new(100, 3.75, -60), { Material = MAT_STRUCTURE, Color = COLOR_DARKGREY, CanCollide = true })

	-- Perimeter accent trim on the VIP floor edge
	part(fVIPDecor, "VIPTrim", Vector3.new(40, 0.2, 0.5), Vector3.new(100, 2.1, -80), { Material = MAT_NEON, Color = COLOR_WARM })
end

-- ============================================================
-- SHOP: kiosk counter, display wall
-- ============================================================

if shopZone then
	-- ShopFloor center (-90,1.5,0), spans X[-105,-75] Z[-15,15]
	part(fShopDecor, "KioskCounter", Vector3.new(10, 3, 2), Vector3.new(-90, 3, 8), { Material = MAT_STRUCTURE, Color = COLOR_CHARCOAL, CanCollide = true })
	surfaceLabel(
		fShopDecor,
		"ShopDisplayWall",
		Vector3.new(14, 6, 0.5),
		Vector3.new(-90, 6, 12),
		Vector3.new(0, 0, 0),
		"SHOP",
		COLOR_WARM,
		Color3.fromRGB(10, 10, 14)
	)
	part(fShopDecor, "DisplayBlockA", Vector3.new(2, 2, 2), Vector3.new(-95, 3, 4), { Material = MAT_PANEL, Color = COLOR_METAL, CanCollide = false })
	part(fShopDecor, "DisplayBlockB", Vector3.new(2, 2, 2), Vector3.new(-85, 3, 4), { Material = MAT_PANEL, Color = COLOR_METAL, CanCollide = false })
end

-- ============================================================
-- OUTDOOR: benches, simple trees, planters, railing
-- ============================================================

if outdoorZone then
	-- OutdoorFloor center (0,1.5,80), spans X[-30,30] Z[50,110]
	local function bench(name, pos)
		part(fOutdoorDecor, name, Vector3.new(5, 1, 1.5), pos, { Material = MAT_PANEL, Color = COLOR_METAL, CanCollide = true })
	end
	bench("Bench1", Vector3.new(-15, 2.5, 70))
	bench("Bench2", Vector3.new(15, 2.5, 70))
	bench("Bench3", Vector3.new(-15, 2.5, 95))
	bench("Bench4", Vector3.new(15, 2.5, 95))

	local function tree(name, pos)
		local trunk = part(fOutdoorDecor, name .. "Trunk", Vector3.new(1.2, 6, 1.2), pos, { Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 50, 35), CanCollide = true })
		local foliage = fOutdoorDecor:FindFirstChild(name .. "Foliage")
		if not foliage then
			foliage = Instance.new("Part")
			foliage.Name = name .. "Foliage"
			foliage.Shape = Enum.PartType.Ball
			foliage.Parent = fOutdoorDecor
		end
		foliage.Size = Vector3.new(6, 6, 6)
		foliage.Position = pos + Vector3.new(0, 4.5, 0)
		foliage.Anchored = true
		foliage.CanCollide = false
		foliage.Material = Enum.Material.Grass
		foliage.Color = Color3.fromRGB(50, 110, 60)
	end
	tree("TreeA", Vector3.new(-25, 2, 55))
	tree("TreeB", Vector3.new(25, 2, 105))
	tree("TreeC", Vector3.new(-25, 2, 105))

	local function planter(name, pos)
		part(fOutdoorDecor, name, Vector3.new(2, 1.5, 2), pos, { Material = MAT_PANEL, Color = COLOR_DARKGREY, CanCollide = true })
	end
	planter("Planter1", Vector3.new(0, 2.75, 55))
	planter("Planter2", Vector3.new(0, 2.75, 105))

	-- Perimeter railing (decorative, thin, non-colliding so it can't trap players)
	part(fOutdoorDecor, "RailingNorth", Vector3.new(60, 2, 0.3), Vector3.new(0, 3, 50.2), { Material = MAT_STRUCTURE, Color = COLOR_METAL, CanCollide = false })
end

-- ============================================================
-- PHOTO SPOT: neon backdrop wall + frame
-- ============================================================

if photoZone then
	-- PhotoSpotFloor center (-90,1.5,-70), spans X[-97.5,-82.5] Z[-77.5,-62.5]
	surfaceLabel(
		fPhotoDecor,
		"PhotoBackdrop",
		Vector3.new(15, 10, 0.5),
		Vector3.new(-90, 7, -77.5),
		Vector3.new(0, 0, 0),
		"HAPPY BIRTHDAY QISYA",
		COLOR_MAGENTA,
		Color3.fromRGB(10, 10, 14),
		Enum.NormalId.Back
	)
	part(fPhotoDecor, "FrameLeft", Vector3.new(0.5, 10, 0.5), Vector3.new(-97.5, 7, -77.5), { Material = MAT_STRUCTURE, Color = COLOR_METAL })
	part(fPhotoDecor, "FrameRight", Vector3.new(0.5, 10, 0.5), Vector3.new(-82.5, 7, -77.5), { Material = MAT_STRUCTURE, Color = COLOR_METAL })
end

-- ============================================================
-- LOBBY: entrance pylons facing the stage/dance floor direction
-- ============================================================

if lobbyZone then
	-- LobbyFloor spans X[-20,20] Z[-20,20]. Pylons at the -Z edge, facing
	-- toward the dance floor/stage, flanking the natural walking path.
	-- Pylons sit just outside the 14-wide WelcomeSign so they do not cover its text.
	part(fLobbyDecor, "PylonLeft", Vector3.new(1.5, 10, 1.5), Vector3.new(-8, 7, -19), { Material = MAT_STRUCTURE, Color = COLOR_METAL })
	part(fLobbyDecor, "PylonRight", Vector3.new(1.5, 10, 1.5), Vector3.new(8, 7, -19), { Material = MAT_STRUCTURE, Color = COLOR_METAL })
	surfaceLabel(
		fLobbyDecor,
		"WelcomeSign",
		Vector3.new(14, 3, 0.4),
		Vector3.new(0, 11, -19),
		Vector3.new(0, 0, 0),
		"QISYA'S PARTY",
		COLOR_CYAN,
		Color3.fromRGB(10, 10, 14),
		Enum.NormalId.Back
	)
end

-- ============================================================
-- PATHS: thin neon strips guiding players from the lobby toward each zone
-- ============================================================

local function pathStrip(name, pos, size)
	part(fPaths, name, size, pos, { Material = MAT_NEON, Color = COLOR_CYAN, CanCollide = false })
end

-- Lobby -> Stage/DanceFloor (straight ahead, -Z)
pathStrip("PathToStage", Vector3.new(0, 1.05, -37.5), Vector3.new(4, 0.1, 35))
-- Lobby -> VIP (toward +X, -Z)
pathStrip("PathToVIP", Vector3.new(50, 1.05, -40), Vector3.new(60, 0.1, 4))
-- Lobby -> Shop (toward -X)
pathStrip("PathToShop", Vector3.new(-55, 1.05, 0), Vector3.new(70, 0.1, 4))
-- Lobby -> Outdoor (toward +Z)
pathStrip("PathToOutdoor", Vector3.new(0, 1.05, 35), Vector3.new(4, 0.1, 30))
-- Lobby -> Photo Spot (toward -X, -Z)
pathStrip("PathToPhotoSpot", Vector3.new(-55, 1.05, -45), Vector3.new(4, 0.1, 50))

-- ============================================================
-- LIGHTING: evening venue atmosphere, ensured idempotently
-- ============================================================

Lighting.ClockTime = 20
Lighting.Brightness = 1.5
-- Ambient raised so dark floors and furniture stay readable at night.
Lighting.Ambient = Color3.fromRGB(80, 80, 100)
Lighting.OutdoorAmbient = Color3.fromRGB(90, 90, 115)
Lighting.ExposureCompensation = 0.2
Lighting.FogEnd = 1500

local atmosphere = Lighting:FindFirstChild("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "Atmosphere"
	atmosphere.Parent = Lighting
	print(LOG .. "Created Lighting.Atmosphere.")
end
atmosphere.Density = 0.25
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(180, 190, 210)
atmosphere.Decay = Color3.fromRGB(60, 65, 80)
atmosphere.Glare = 0.1
atmosphere.Haze = 1.2

local colorCorrection = Lighting:FindFirstChild("Atmosphere_ColorCorrection")
if not colorCorrection then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "Atmosphere_ColorCorrection"
	colorCorrection.Parent = Lighting
	print(LOG .. "Created Lighting.ColorCorrectionEffect.")
end
colorCorrection.Brightness = 0
colorCorrection.Contrast = 0.1
colorCorrection.Saturation = 0.1
colorCorrection.TintColor = Color3.fromRGB(240, 245, 255)

local bloom = Lighting:FindFirstChild("Atmosphere_Bloom")
if not bloom then
	bloom = Instance.new("BloomEffect")
	bloom.Name = "Atmosphere_Bloom"
	bloom.Parent = Lighting
	print(LOG .. "Created Lighting.BloomEffect.")
end
bloom.Intensity = 0.6
bloom.Size = 24
bloom.Threshold = 1.5 -- keeps bloom restrained to bright neon, not everything

print(LOG .. "EnvironmentBuilder complete.")