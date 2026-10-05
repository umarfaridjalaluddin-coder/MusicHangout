-- HauntedRideBuilder (PERMANENT)
-- Builds the Rumah Hantu dark ride: house, station, queue, track, seven
-- scenes and the four-seat cart. Geometry only -- HauntedRideServer runs the
-- ride. Everything is found-or-created by name under Workspace.HauntedRide,
-- so running this again never duplicates anything. No asset ids, no Toolbox
-- models; every piece is a plain Part.
--
-- Movable show pieces carry two CFrame attributes, Home and Target, and
-- hidden pieces carry Shown (their transparency when revealed). The server
-- only ever moves a piece between Home and Target and fades it to Shown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.HauntedRideConfig)

local LOG = "[HauntedRideBuilder] "
local C = Config.Colors
local H = Config.WALL_HEIGHT
local W = Config.toWorld

local BLACK = Color3.fromRGB(8, 8, 10)

-- ============================================================
-- Helpers
-- ============================================================

local function ensureFolder(parent, name, className)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new(className or "Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local ride = ensureFolder(Workspace, "HauntedRide")
if ride:GetAttribute("Built") then
	print(LOG .. "Rumah Hantu already built; nothing to do.")
	return
end

local fBuilding = ensureFolder(ride, "Building")
local fEntrance = ensureFolder(ride, "Entrance")
local fQueue = ensureFolder(ride, "Queue")
local fStation = ensureFolder(ride, "Station")
local fPlatform = ensureFolder(fStation, "LoadPlatform")
local fGates = ensureFolder(fStation, "Gates")
local fTrack = ensureFolder(ride, "Track")
local fWaypoints = ensureFolder(fTrack, "Waypoints")
local fVisualTrack = ensureFolder(fTrack, "VisualTrack")
local fScenes = ensureFolder(ride, "Scenes")
local fEffects = ensureFolder(ride, "Effects")
local fVehicles = ensureFolder(ride, "RideVehicles")
local fUnload = ensureFolder(ride, "Unload")
local fDebug = ensureFolder(ride, "Debug")

local scene = {}
for index, name in ipairs(Config.SCENES) do
	scene[index] = ensureFolder(fScenes, name)
end

local function make(parent, name, size, cframe, color, props)
	local p = parent:FindFirstChild(name)
	if not p then
		p = Instance.new("Part")
		p.Name = name
		p.Parent = parent
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	return p
end

-- A box given by its extents in house space.
local function box(parent, name, u1, u2, y1, y2, v1, v2, color, props)
	local size = Vector3.new(math.abs(u2 - u1), math.abs(y2 - y1), math.abs(v2 - v1))
	return make(parent, name, size, CFrame.new(W((u1 + u2) / 2, (y1 + y2) / 2, (v1 + v2) / 2)), color, props)
end

-- A piece given by its centre and size (size is u, y, v).
local function prop(parent, name, su, sy, sv, u, y, v, color, props)
	return make(parent, name, Vector3.new(su, sy, sv), CFrame.new(W(u, y, v)), color, props)
end

local WALL = { CanCollide = true, CastShadow = true, Material = Enum.Material.WoodPlanks }
local SOLID = { CanCollide = true }
local BALL = { Shape = Enum.PartType.Ball }
local STAND = CFrame.Angles(0, 0, math.rad(90))

local function drum(parent, name, diameter, height, u, y, v, color, props)
	local merged = { Shape = Enum.PartType.Cylinder }
	for key, value in pairs(props or {}) do
		merged[key] = value
	end
	return make(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(W(u, y, v)) * STAND, color, merged)
end

-- Faces: thin along u -> Left looks west, Right looks east.
--        thin along v -> Front looks south, Back looks north.
local function label(part, text, textColor, face, pixelsPerStud)
	local gui = part:FindFirstChild("Label")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Label"
		gui.Parent = part
	end
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	local t = gui:FindFirstChild("Text")
	if not t then
		t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Parent = gui
	end
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(0.92, 0.8)
	t.Font = Enum.Font.Creepster
	t.Text = text
	t.TextColor3 = textColor
	t.TextScaled = true
	return t
end

-- A light fitting. Base is its brightness when the ride is idle.
local function lamp(parent, name, u, y, v, color, base, range, visible)
	local holder = prop(parent, name, 0.4, 0.4, 0.4, u, y, v, color, { Shape = Enum.PartType.Ball, Transparency = visible and 0 or 1 })
	local light = holder:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
	light.Color = color
	light.Brightness = base
	light.Range = range
	light.Shadows = false
	light.Parent = holder
	holder:SetAttribute("Base", base)
	return holder
end

local function movable(instance, home, target)
	instance:SetAttribute("Home", home)
	instance:SetAttribute("Target", target)
end

local function hidden(part, shown)
	part:SetAttribute("Shown", shown or 0)
	part.Transparency = 1
end

-- A simple friendly-spooky ghost: round head, soft body, ragged hem, dark
-- eyes. base = where its feet are and which way it faces. Starts hidden.
local function ghost(parent, name, base, scale, lightColor, lightBrightness)
	local model = ensureFolder(parent, name, "Model")
	local s = scale
	local function g(partName, size, offset, color, shown, props)
		local p = make(model, partName, size * s, base * CFrame.new(offset.Position * s) * offset.Rotation, color, props)
		hidden(p, shown)
		return p
	end
	local core = make(model, "Core", Vector3.new(0.2, 0.2, 0.2), base, C.Ghost, { Transparency = 1 })
	core:SetAttribute("Shown", 1)
	model.PrimaryPart = core
	local head = g("Head", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 3.3, 0), C.Ghost, 0.25, BALL)
	g("Body", Vector3.new(1.7, 1.6, 0.9), CFrame.new(0, 2.2, 0), C.Ghost, 0.3)
	g("Skirt", Vector3.new(2.2, 1.3, 1.1), CFrame.new(0, 0.95, 0), C.Ghost, 0.35)
	g("HemLeft", Vector3.new(0.6, 0.5, 1), CFrame.new(-0.75, 0.2, 0), C.Ghost, 0.45)
	g("HemMid", Vector3.new(0.6, 0.6, 1), CFrame.new(0, 0.05, 0), C.Ghost, 0.45)
	g("HemRight", Vector3.new(0.6, 0.5, 1), CFrame.new(0.75, 0.2, 0), C.Ghost, 0.45)
	g("ArmLeft", Vector3.new(0.4, 1.3, 0.4), CFrame.new(-1.15, 2.3, -0.35) * CFrame.Angles(math.rad(-40), 0, 0), C.Ghost, 0.35)
	g("ArmRight", Vector3.new(0.4, 1.3, 0.4), CFrame.new(1.15, 2.3, -0.35) * CFrame.Angles(math.rad(-40), 0, 0), C.Ghost, 0.35)
	g("EyeLeft", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.3, 3.4, -0.64), BLACK, 0, BALL)
	g("EyeRight", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.3, 3.4, -0.64), BLACK, 0, BALL)
	g("Mouth", Vector3.new(0.3, 0.42, 0.12), CFrame.new(0, 2.92, -0.7), BLACK, 0)
	local light = head:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
	light.Color = lightColor or C.ColdLight
	light.Brightness = 0
	light.Range = 9 * s
	light.Shadows = false
	light.Parent = head
	head:SetAttribute("On", lightBrightness or 1.2)
	return model
end

-- Facing helpers for ghosts (house space).
local function facing(u, y, v, du, dv)
	local position = W(u, y, v)
	return CFrame.lookAt(position, position + Vector3.new(du, 0, dv))
end

-- A hinged door leaf. plane = the wall's u, hinge = the v of its hinge,
-- side = +1 if the leaf reaches toward +v, travel = +1 if the cart passes
-- heading east. It swings open away from the oncoming cart.
local function doorLeaf(parent, name, plane, hinge, side, travel)
	local hingeFrame = CFrame.new(W(plane, 3.85, hinge))
	local offset = CFrame.new(0, 0, side * 1.5)
	local angle = math.rad(88) * side * travel
	local leaf = make(parent, name, Vector3.new(0.35, 7.3, 3), hingeFrame * offset, C.WoodDark, { Material = Enum.Material.WoodPlanks })
	movable(leaf, hingeFrame * offset, hingeFrame * CFrame.Angles(0, angle, 0) * offset)
	return leaf
end

local function doorPair(parent, name, plane, vLow, travel)
	doorLeaf(parent, name .. "Left", plane, vLow, 1, travel)
	doorLeaf(parent, name .. "Right", plane, vLow + 6, -1, travel)
end

-- Tattered curtain across a doorway (the cart simply passes through).
local function curtain(parent, name, plane, vLow)
	for i = 1, 6 do
		local shift = (i % 2 == 0) and 0.12 or -0.12
		prop(parent, name .. i, 0.12, 7 - (i % 3) * 0.5, 0.96, plane + shift, 4 + (i % 3) * 0.25, vLow + i - 0.5, C.Cloth, { Material = Enum.Material.Fabric })
	end
end

-- ============================================================
-- House shell (interior u -4..58, v 0..30)
-- ============================================================

box(fBuilding, "Floor", -4, 58, 0, 0.2, 0, 30, C.Floor, { CanCollide = true, Material = Enum.Material.WoodPlanks })
box(fBuilding, "Roof", -6, 60, H, H + 0.6, -2, 32, C.Roof, { CanCollide = true, CastShadow = true, Material = Enum.Material.Slate })
box(fBuilding, "Ceiling", -4, 58, H - 0.15, H, 0, 30, BLACK)

box(fBuilding, "WallNorth", -5, 59, 0, H, 30, 31, C.Wood, WALL)
box(fBuilding, "WallSouth", -5, 59, 0, H, -1, 0, C.Wood, WALL)
box(fBuilding, "WallWest", -5, -4, 0, H, 0, 30, C.Wood, WALL)
-- East front: openings for the entrance (v 22..28) and the exit (v 2..8).
box(fBuilding, "WallEastA", 58, 59, 0, H, 0, 2, C.Wood, WALL)
box(fBuilding, "WallEastB", 58, 59, 0, H, 8, 22, C.Wood, WALL)
box(fBuilding, "WallEastC", 58, 59, 0, H, 28, 30, C.Wood, WALL)
box(fBuilding, "WallEastExitLintel", 58, 59, 7.5, H, 2, 8, C.Wood, WALL)
box(fBuilding, "WallEastEntranceLintel", 58, 59, 7.5, H, 22, 28, C.Wood, WALL)

-- Stone foundation, a little proud of the walls.
local STONE = { Material = Enum.Material.Slate }
box(fBuilding, "FoundationNorth", -5.3, 59.3, 0, 1.3, 30.7, 31.3, C.Stone, STONE)
box(fBuilding, "FoundationSouth", -5.3, 59.3, 0, 1.3, -1.3, -0.7, C.Stone, STONE)
box(fBuilding, "FoundationWest", -5.3, -4.7, 0, 1.3, -1, 31, C.Stone, STONE)
box(fBuilding, "FoundationEastA", 58.7, 59.3, 0, 1.3, -1, 2, C.Stone, STONE)
box(fBuilding, "FoundationEastB", 58.7, 59.3, 0, 1.3, 8, 22, C.Stone, STONE)
box(fBuilding, "FoundationEastC", 58.7, 59.3, 0, 1.3, 28, 31, C.Stone, STONE)

-- Worn roof silhouette: a stepped gable over the front and two chimneys.
box(fBuilding, "GableLow", 56.5, 59.2, H + 0.6, H + 3.8, 4.5, 25.5, C.Wood, { Material = Enum.Material.WoodPlanks })
box(fBuilding, "GableMid", 56.5, 59.2, H + 3.8, H + 5, 9.5, 20.5, C.Wood, { Material = Enum.Material.WoodPlanks })
box(fBuilding, "GablePeak", 56.5, 59.2, H + 5, H + 6, 12.8, 17.2, C.Roof, { Material = Enum.Material.Slate })
box(fBuilding, "GableCapLow", 56.2, 59.5, H + 3.8, H + 4.05, 4.2, 9.5, C.Roof)
box(fBuilding, "GableCapLow2", 56.2, 59.5, H + 3.8, H + 4.05, 20.5, 25.8, C.Roof)
box(fBuilding, "GableCapMid", 56.2, 59.5, H + 5, H + 5.25, 9.2, 12.8, C.Roof)
box(fBuilding, "GableCapMid2", 56.2, 59.5, H + 5, H + 5.25, 17.2, 20.8, C.Roof)
box(fBuilding, "ChimneyA", 20, 22.5, H + 0.6, H + 3.6, 5, 7.5, C.Stone, STONE)
box(fBuilding, "ChimneyB", 6, 8, H + 0.6, H + 2.8, 22, 24, C.Stone, STONE)

-- Interior walls. Scenes: north row runs west (track v=19), south row east (v=11).
box(fBuilding, "StationWallA", 44, 45, 0, H, 0, 8, C.WoodDark, WALL)
box(fBuilding, "StationWallB", 44, 45, 0, H, 14, 16, C.WoodDark, WALL)
box(fBuilding, "StationWallC", 44, 45, 0, H, 22, 30, C.WoodDark, WALL)
box(fBuilding, "StationLintelExit", 44, 45, 7.5, H, 8, 14, C.WoodDark, WALL)
box(fBuilding, "StationLintelEntrance", 44, 45, 7.5, H, 16, 22, C.WoodDark, WALL)
box(fBuilding, "CentreWall", 8, 44, 0, H, 14.5, 15.5, C.WoodDark, WALL)
for _, u in ipairs({ 32, 20, 8 }) do
	box(fBuilding, "DividerNorth" .. u, u - 0.4, u + 0.4, 0, H, 22, 30, C.WoodDark, WALL)
	box(fBuilding, "DividerNorthJamb" .. u, u - 0.4, u + 0.4, 0, H, 15.5, 16, C.WoodDark, WALL)
	box(fBuilding, "DividerNorthLintel" .. u, u - 0.4, u + 0.4, 7.5, H, 16, 22, C.WoodDark, WALL)
	box(fBuilding, "DividerSouth" .. u, u - 0.4, u + 0.4, 0, H, 0, 8, C.WoodDark, WALL)
	box(fBuilding, "DividerSouthJamb" .. u, u - 0.4, u + 0.4, 0, H, 14, 14.5, C.WoodDark, WALL)
	box(fBuilding, "DividerSouthLintel" .. u, u - 0.4, u + 0.4, 7.5, H, 8, 14, C.WoodDark, WALL)
end
-- Sightline curtains on the doorways that have no door.
curtain(fBuilding, "CurtainHall", 32, 16)
curtain(fBuilding, "CurtainMirrorIn", 8, 16)
curtain(fBuilding, "CurtainGraveyardIn", 20, 8)
curtain(fBuilding, "CurtainFinaleIn", 32, 8)

-- ============================================================
-- Front of house: sign, entrance and exit, lanterns, boarded windows
-- ============================================================

local signBoard = box(fEntrance, "HouseSign", 59.2, 59.5, H + 0.9, H + 3.6, 5.5, 24.5, BLACK)
label(signBoard, Config.TITLE, C.SignText, Enum.NormalId.Right, 30)
local subBoard = box(fEntrance, "HouseSubtitle", 59, 59.3, 8.3, 9.6, 9.5, 20.5, BLACK)
label(subBoard, Config.SUBTITLE, C.PurpleLight, Enum.NormalId.Right, 40)
local enterBoard = box(fEntrance, "EntranceSign", 59, 59.3, 7.7, 8.8, 22.4, 27.6, BLACK)
label(enterBoard, "MASUK  -  ENTER", C.WarmLight, Enum.NormalId.Right, 40)
local exitBoard = box(fEntrance, "ExitSign", 59, 59.3, 7.7, 8.8, 2.4, 7.6, BLACK)
label(exitBoard, "KELUAR  -  EXIT", C.GreenLight, Enum.NormalId.Right, 40)

-- Entrance arch posts and dim lanterns.
for index, v in ipairs({ 21.5, 28.5 }) do
	box(fEntrance, "ArchPost" .. index, 59, 59.8, 0, 7.6, v - 0.4, v + 0.4, C.WoodDark, { Material = Enum.Material.WoodPlanks })
	prop(fEntrance, "Lantern" .. index, 0.7, 0.9, 0.7, 60.1, 6, v, C.Brass)
	lamp(fEntrance, "LanternLight" .. index, 60.1, 6, v, C.WarmLight, 0.9, 10, false)
end
-- Boarded windows on the front wall, with a faint supernatural tint behind.
for index, v in ipairs({ 11.5, 18.5 }) do
	box(fEntrance, "Window" .. index, 59, 59.15, 3, 6.4, v - 1.4, v + 1.4, (index == 1) and Color3.fromRGB(34, 70, 48) or Color3.fromRGB(58, 36, 82))
	box(fEntrance, "WindowFrame" .. index, 58.95, 59.1, 2.8, 6.6, v - 1.6, v + 1.6, C.WoodDark)
	make(fEntrance, "WindowBoardA" .. index, Vector3.new(0.15, 0.45, 3.7), CFrame.new(W(59.25, 4.9, v)) * CFrame.Angles(math.rad(18), 0, 0), C.Wood, { Material = Enum.Material.WoodPlanks })
	make(fEntrance, "WindowBoardB" .. index, Vector3.new(0.15, 0.45, 3.7), CFrame.new(W(59.25, 4.2, v)) * CFrame.Angles(math.rad(-14), 0, 0), C.Wood, { Material = Enum.Material.WoodPlanks })
end

-- Forecourt linking the Outdoor area (floor is one stud higher) to the doors.
box(fQueue, "Forecourt", 59, 64, 0, 0.1, -1, 31, C.Stone, { CanCollide = true, Material = Enum.Material.Slate })
box(fQueue, "ForecourtStep", 64, 66, 0, 0.55, -1, 31, C.Stone, { CanCollide = true, Material = Enum.Material.Slate })

-- Queue rails leading into the entrance.
for index, v in ipairs({ 21.6, 28.4 }) do
	box(fQueue, "QueueRailTop" .. index, 59.6, 63.6, 1.9, 2.05, v - 0.08, v + 0.08, C.Iron)
	box(fQueue, "QueueRailMid" .. index, 59.6, 63.6, 1.1, 1.22, v - 0.06, v + 0.06, C.Iron)
	for post = 0, 2 do
		box(fQueue, "QueuePost" .. index .. "_" .. post, 59.6 + post * 2 - 0.12, 59.6 + post * 2 + 0.12, 0.1, 2.2, v - 0.12, v + 0.12, C.Iron, SOLID)
	end
end
-- Signpost on the edge of the Outdoor floor.
box(fQueue, "SignpostPole", 66.4, 66.7, 0.5, 5.6, 14.85, 15.15, C.Iron)
local signpost = box(fQueue, "SignpostBoard", 66.3, 66.5, 3.6, 5.6, 11.5, 18.5, BLACK)
label(signpost, Config.TITLE, C.SignText, Enum.NormalId.Right, 40)
local signpostSmall = box(fQueue, "SignpostRiders", 66.3, 66.5, 2.7, 3.5, 12.5, 17.5, BLACK)
label(signpostSmall, "1 - 4 RIDERS", C.WarmLight, Enum.NormalId.Right, 50)

-- ============================================================
-- Station (u 45..58): load on the north side, unload on the south
-- ============================================================

box(fPlatform, "BoardingLine", 45.2, 52, 0.2, 0.24, 21.5, 21.8, Color3.fromRGB(190, 150, 50))
local riders = box(fPlatform, "RidersSign", 46.5, 56.5, 6.4, 8, 29.7, 29.95, BLACK)
label(riders, "1 - 4 RIDERS", C.WarmLight, Enum.NormalId.Front, 40)
local please = box(fPlatform, "BoardSign", 46.5, 56.5, 4.9, 6.1, 29.7, 29.95, BLACK)
label(please, "Please board the cart", C.Ghost, Enum.NormalId.Front, 40)
-- Low rail between the waiting area and the cart's turning loop.
box(fPlatform, "LoopRailTop", 52.6, 52.8, 1.8, 1.95, 21.6, 29.6, C.Iron)
for post = 0, 2 do
	box(fPlatform, "LoopRailPost" .. post, 52.55, 52.85, 0.2, 2, 21.6 + post * 4 - 0.12, 21.6 + post * 4 + 0.12, C.Iron, SOLID)
end

local dispatch = box(fStation, "DispatchSign", 45, 45.3, 7.75, 9.6, 15, 23, BLACK)
label(dispatch, "WAITING FOR RIDERS", C.SignText, Enum.NormalId.Right, 40).Font = Enum.Font.GothamBold

-- Loading gate: a bar over the boarding edge, lifted while riders may board.
local loadGate = box(fGates, "LoadGate", 45.4, 51.6, 2.5, 2.7, 21.55, 21.75, C.Brass)
movable(loadGate, loadGate.CFrame + Vector3.new(0, 4.2, 0), loadGate.CFrame)
loadGate.CFrame = loadGate:GetAttribute("Home")
-- Exit gate across the way out, opened when the cart unloads.
local exitGate = box(fGates, "ExitGate", 57.2, 57.4, 0.2, 2.4, 2.2, 7.8, C.Iron)
movable(exitGate, exitGate.CFrame, exitGate.CFrame + Vector3.new(0, 5.2, 0))

box(fUnload, "UnloadLine", 45.2, 52, 0.2, 0.24, 8.2, 8.5, Color3.fromRGB(60, 150, 90))
local exitInside = box(fUnload, "ExitInsideSign", 57.6, 57.9, 7.7, 8.8, 2.4, 7.6, BLACK)
label(exitInside, "KELUAR  -  EXIT", C.GreenLight, Enum.NormalId.Left, 40)
-- Where riders are set down, one spot per seat.
for index, spot in ipairs({ { 47, 5.5 }, { 49.5, 5.5 }, { 47, 3.5 }, { 49.5, 3.5 } }) do
	prop(fUnload, "UnloadSpot" .. index, 1, 0.1, 1, spot[1], 0.25, spot[2], C.Floor, { Transparency = 1 })
end
-- Where a rider who leaves the cart mid-ride is taken (outside the exit).
prop(fUnload, "SafeSpot", 1, 0.1, 1, 61.5, 0.2, 5, C.Floor, { Transparency = 1 })

lamp(fStation, "StationLampA", 51, 8.6, 25, C.WarmLight, 1, 16, true)
lamp(fStation, "StationLampB", 51, 8.6, 5, C.WarmLight, 0.8, 16, true)
lamp(fStation, "StationLampC", 55.5, 8.6, 15, C.PurpleLight, 0.5, 12, true)

-- ============================================================
-- Track: waypoints (data the server reads) and visible rails
-- ============================================================

local points = {}
for index, waypoint in ipairs(Config.WAYPOINTS) do
	local position = W(waypoint.u, 0.2, waypoint.v)
	points[index] = position
	local marker = make(fWaypoints, string.format("WP%03d", index), Vector3.new(0.6, 0.6, 0.6), CFrame.new(position + Vector3.new(0, 1, 0)), Color3.fromRGB(255, 80, 80), { Shape = Enum.PartType.Ball, Transparency = Config.DEBUG and 0.2 or 1 })
	marker:SetAttribute("Speed", waypoint.Speed)
	marker:SetAttribute("Pause", waypoint.Pause)
	marker:SetAttribute("SceneId", waypoint.Scene)
	marker:SetAttribute("Stop", waypoint.Stop)
end

local path = Config.buildPath(points)
local SLEEPER_GAP = 2.4
local sleeperCount = math.floor(path.Length / SLEEPER_GAP)
for i = 0, sleeperCount - 1 do
	local position, direction = Config.pointAt(path, i * SLEEPER_GAP)
	local frame = CFrame.lookAt(position, position + direction)
	make(fVisualTrack, "Sleeper" .. i, Vector3.new(3.6, 0.12, 0.45), frame * CFrame.new(0, 0.06, 0), C.Wood, { Material = Enum.Material.WoodPlanks })
	local nextPosition = Config.pointAt(path, (i + 1) * SLEEPER_GAP)
	local mid = (position + nextPosition) / 2
	local span = (nextPosition - position).Magnitude
	if span > 0.05 then
		local railFrame = CFrame.lookAt(mid, nextPosition)
		make(fVisualTrack, "RailLeft" .. i, Vector3.new(0.18, 0.2, span + 0.1), railFrame * CFrame.new(-1.35, 0.2, 0), C.Iron, { Material = Enum.Material.Metal })
		make(fVisualTrack, "RailRight" .. i, Vector3.new(0.18, 0.2, span + 0.1), railFrame * CFrame.new(1.35, 0.2, 0), C.Iron, { Material = Enum.Material.Metal })
	end
end

-- ============================================================
-- Scene 1 -- Abandoned entrance hall (u 32..44, north row)
-- ============================================================
do
	local f = scene[1]
	doorPair(f, "EntranceDoor", 43.7, 16, -1)
	lamp(f, "HallLampA", 41, 6.5, 16.2, C.WarmLight, 0.9, 10, true)
	lamp(f, "HallLampB", 35, 6.5, 16.2, C.WarmLight, 0.9, 10, true)
	box(f, "Runner", 33, 43.5, 0.2, 0.23, 23, 26, C.Cloth, { Material = Enum.Material.Fabric })
	for index, u in ipairs({ 35, 38.5, 42 }) do
		box(f, "PortraitFrame" .. index, u - 1.1, u + 1.1, 3.6, 6.6, 29.75, 29.95, C.Brass)
		box(f, "PortraitCanvas" .. index, u - 0.9, u + 0.9, 3.8, 6.4, 29.65, 29.8, Color3.fromRGB(30, 28, 34))
		prop(f, "PortraitFace" .. index, 0.7, 0.9, 0.08, u, 5.4, 29.6, Color3.fromRGB(150, 145, 135))
	end
	-- Boarded window that glows with far-off lightning.
	local window = box(f, "LightningWindow", 32.4, 32.55, 3, 7, 24, 28, Color3.fromRGB(26, 34, 54))
	local glow = window:FindFirstChildOfClass("SurfaceLight") or Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Right
	glow.Color = C.ColdLight
	glow.Brightness = 0
	glow.Range = 18
	glow.Angle = 120
	glow.Parent = window
	window:SetAttribute("Base", 0)
	make(f, "WindowBoardA", Vector3.new(0.15, 0.5, 4.6), CFrame.new(W(32.68, 5.6, 26)) * CFrame.Angles(math.rad(20), 0, 0), C.Wood, { Material = Enum.Material.WoodPlanks })
	make(f, "WindowBoardB", Vector3.new(0.15, 0.5, 4.6), CFrame.new(W(32.68, 4.3, 26)) * CFrame.Angles(math.rad(-16), 0, 0), C.Wood, { Material = Enum.Material.WoodPlanks })
	prop(f, "Trunk", 2.6, 1.4, 1.6, 40, 0.9, 27.5, C.Wood, { Material = Enum.Material.WoodPlanks })
	prop(f, "TrunkBand", 2.7, 0.2, 1.7, 40, 1.3, 27.5, C.Brass)
	box(f, "CoatStand", 36.9, 37.1, 0.2, 6, 27.9, 28.1, C.WoodDark)
	prop(f, "CoatStandTop", 1.4, 0.15, 0.15, 37, 5.6, 28, C.WoodDark)
	prop(f, "OldCoat", 0.3, 2.6, 1.1, 37.5, 4.2, 28, C.Cloth, { Material = Enum.Material.Fabric })
end

-- ============================================================
-- Scene 2 -- Haunted corridor (u 20..32)
-- ============================================================
do
	local f = scene[2]
	box(f, "CorridorWall", 20.4, 31.6, 0, H, 23.5, 24.1, C.WoodDark, WALL)
	for index, u in ipairs({ 30, 26, 22.5 }) do
		prop(f, "Sconce" .. index, 0.5, 0.7, 0.3, u, 6.2, 23.3, C.Brass)
		lamp(f, "CorridorLamp" .. index, u, 6.3, 23, C.WarmLight, 0.8, 8, true)
	end
	box(f, "PortraitFrame", 27.2, 29, 3.4, 6, 23.3, 23.5, C.Brass)
	local canvas = box(f, "TiltingPortrait", 27.35, 28.85, 3.55, 5.85, 23.2, 23.35, Color3.fromRGB(32, 28, 36))
	movable(canvas, canvas.CFrame, canvas.CFrame * CFrame.Angles(0, 0, math.rad(14)))
	for index, du in ipairs({ -0.28, 0.28 }) do
		local eye = prop(f, "PortraitEye" .. index, 0.2, 0.2, 0.2, 28.1 + du, 5.1, 23.12, C.GreenLight, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon })
		hidden(eye, 0)
	end
	-- A flat shadow that slides along the wall beside the cart.
	local shadow = ensureFolder(f, "ShadowFigure", "Model")
	local shadowBody = prop(shadow, "Body", 1.8, 4.2, 0.08, 31, 2.5, 23.4, BLACK)
	local shadowHead = prop(shadow, "Head", 1.3, 1.3, 0.08, 31, 5.2, 23.4, BLACK)
	hidden(shadowBody, 0.3)
	hidden(shadowHead, 0.3)
	shadow.PrimaryPart = shadowBody
	movable(shadow, shadowBody.CFrame, shadowBody.CFrame + Vector3.new(-8.5, 0, 0))
	-- Small scare at the end: a ghost leans out by the dining-room door.
	local pop = ghost(f, "PopGhost", facing(21.4, 0.3, 22.9, 0, -1), 0.75, C.ColdLight, 1)
	movable(pop, facing(21.4, 0.3, 22.9, 0, -1), facing(21.4, 0.3, 21.9, 0, -1))
end

-- ============================================================
-- Scene 3 -- Dining room (u 8..20)
-- ============================================================
do
	local f = scene[3]
	doorPair(f, "DiningDoor", 20.6, 16, -1)
	box(f, "TableTop", 10.8, 17.2, 2.6, 2.9, 24.2, 27, C.Wood, { Material = Enum.Material.WoodPlanks })
	for index, corner in ipairs({ { 11.2, 24.6 }, { 16.8, 24.6 }, { 11.2, 26.6 }, { 16.8, 26.6 } }) do
		box(f, "TableLeg" .. index, corner[1] - 0.2, corner[1] + 0.2, 0.2, 2.6, corner[2] - 0.2, corner[2] + 0.2, C.WoodDark)
	end
	box(f, "TableCloth", 12, 16, 2.9, 2.94, 24.4, 26.8, C.Cloth, { Material = Enum.Material.Fabric })
	for index, u in ipairs({ 12.4, 14, 15.6 }) do
		drum(f, "Plate" .. index, 0.9, 0.06, u, 2.98, 25.6, Color3.fromRGB(190, 186, 176))
	end
	box(f, "Candlestick", 13.9, 14.1, 2.94, 3.9, 24.9, 25.1, C.Brass)

	local function chair(name, u, v, back)
		local model = ensureFolder(f, name, "Model")
		local seat = prop(model, "Seat", 1.4, 0.25, 1.4, u, 1.5, v, C.WoodDark)
		prop(model, "Back", 1.4, 2.4, 0.2, u, 2.8, v + back * 0.6, C.WoodDark)
		for index, corner in ipairs({ { -0.55, -0.55 }, { 0.55, -0.55 }, { -0.55, 0.55 }, { 0.55, 0.55 } }) do
			prop(model, "Leg" .. index, 0.18, 1.3, 0.18, u + corner[1], 0.85, v + corner[2], C.WoodDark)
		end
		model.PrimaryPart = seat
		return model, seat
	end
	chair("ChairNorthA", 12.5, 28, 1)
	chair("ChairNorthB", 15.5, 28, 1)
	chair("ChairSouthA", 15.5, 23.2, -1)
	local sliding, slidingSeat = chair("SlidingChair", 12.5, 23.2, -1)
	movable(sliding, slidingSeat.CFrame, slidingSeat.CFrame * CFrame.new(-0.5, 0, -0.8) * CFrame.Angles(0, math.rad(24), 0))

	local chandelier = ensureFolder(f, "Chandelier", "Model")
	local hub = prop(chandelier, "Hub", 0.5, 0.5, 0.5, 14, 7.4, 25.6, C.Brass, BALL)
	box(chandelier, "Chain", 13.94, 14.06, 7.6, H - 0.15, 25.54, 25.66, C.Iron)
	drum(chandelier, "Ring", 3, 0.16, 14, 7.2, 25.6, C.Brass)
	for index, offset in ipairs({ { 1.4, 0 }, { -1.4, 0 }, { 0, 1.4 }, { 0, -1.4 } }) do
		prop(chandelier, "Candle" .. index, 0.2, 0.6, 0.2, 14 + offset[1], 7.55, 25.6 + offset[2], Color3.fromRGB(220, 210, 180))
	end
	chandelier.PrimaryPart = hub
	movable(chandelier, hub.CFrame, hub.CFrame * CFrame.Angles(math.rad(10), 0, math.rad(8)))
	lamp(f, "ChandelierLight", 14, 6.9, 25.6, C.WarmLight, 1, 15, false)

	local guest = ghost(f, "DiningGhost", facing(14, 0.3, 28.7, 0, -1), 0.9, C.ColdLight, 1.4)
	movable(guest, facing(14, 0.3, 28.7, 0, -1), facing(14, 0.3, 28.7, 0, -1))
end

-- ============================================================
-- Scene 4 -- Mirror hall (u -4..8, the turn at the west end)
-- ============================================================
do
	local f = scene[4]
	for index, v in ipairs({ 5, 10, 20, 25 }) do
		box(f, "MirrorFrame" .. index, -3.95, -3.8, 1.3, 7.7, v - 1.7, v + 1.7, C.Brass)
		box(f, "MirrorPanel" .. index, -3.85, -3.7, 1.5, 7.5, v - 1.5, v + 1.5, Color3.fromRGB(58, 72, 88), { Reflectance = 0.35 })
	end
	for _, pair in ipairs({ { "A", 10 }, { "B", 20 } }) do
		for index, dv in ipairs({ -0.3, 0.3 }) do
			local eye = prop(f, "MirrorEye" .. pair[1] .. index, 0.22, 0.22, 0.22, -3.6, 5.3, pair[2] + dv, C.GreenLight, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon })
			hidden(eye, 0)
		end
	end
	-- Centre cabinet: dark glass that clears to show the figure behind it.
	box(f, "CabinetFrame", -3.95, -2.4, 1.2, 7.8, 13.2, 13.5, C.Brass)
	box(f, "CabinetFrame2", -3.95, -2.4, 1.2, 7.8, 16.5, 16.8, C.Brass)
	box(f, "CabinetTop", -3.95, -2.4, 7.5, 7.8, 13.2, 16.8, C.Brass)
	local glass = box(f, "ApparitionPanel", -2.6, -2.45, 1.5, 7.5, 13.5, 16.5, Color3.fromRGB(40, 52, 66), { Reflectance = 0.3, Transparency = 0.04 })
	glass:SetAttribute("Base", 0.04)
	glass:SetAttribute("Reveal", 0.8)
	local figure = ghost(f, "MirrorGhost", facing(-3.3, 1.6, 15, 1, 0), 0.8, C.GreenLight, 1.6)
	movable(figure, facing(-3.3, 1.6, 15, 1, 0), facing(-3.3, 1.6, 15, 1, 0))
	lamp(f, "MirrorLamp", 2, 8.6, 15, C.PurpleLight, 0.45, 16, false)
end

-- ============================================================
-- Scene 5 -- Ghost room (u 8..20, south row)
-- ============================================================
do
	local f = scene[5]
	doorPair(f, "GhostRoomDoor", 8.6, 8, 1)
	box(f, "BedFrame", 9.2, 12.8, 0.2, 1.3, 0.8, 5, C.WoodDark)
	box(f, "Bedding", 9.4, 12.6, 1.3, 1.6, 1, 4.8, Color3.fromRGB(96, 92, 100), { Material = Enum.Material.Fabric })
	box(f, "Headboard", 9.2, 12.8, 0.2, 3.6, 0.3, 0.7, C.WoodDark)
	for index, u in ipairs({ 15.5, 17, 18.5 }) do
		box(f, "Drape" .. index, u - 0.55, u + 0.55, 1 + (index % 2) * 0.6, 8.6, 0.25, 0.4, C.Cloth, { Material = Enum.Material.Fabric })
	end
	prop(f, "SideTable", 1.2, 1.6, 1.2, 13.8, 1, 1.2, C.WoodDark)
	lamp(f, "GhostRoomLight", 14, 8.4, 6, C.ColdLight, 0.15, 18, false)
	local spirit = ghost(f, "RoomGhost", facing(14, 0.4, 2.4, 0, 1), 1.15, C.ColdLight, 1.8)
	movable(spirit, facing(14, 0.4, 2.4, 0, 1), facing(14, 0.4, 7.2, 0, 1))
	local mist = prop(f, "GhostMist", 6, 0.2, 5, 14, 0.4, 4.5, C.Ghost, { Transparency = 1 })
	local emitter = mist:FindFirstChildOfClass("ParticleEmitter") or Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(C.ColdLight)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3.5) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(3, 4)
	emitter.Speed = NumberRange.new(0.3, 0.7)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Rate = 0
	emitter.Parent = mist
	mist:SetAttribute("Rate", 5)
end

-- ============================================================
-- Scene 6 -- Haunted graveyard (u 20..32)
-- ============================================================
do
	local f = scene[6]
	box(f, "Turf", 20.4, 31.6, 0.2, 0.3, 0, 8.3, Color3.fromRGB(28, 44, 32), { Material = Enum.Material.Grass })
	local graves = { { 22.5, 3 }, { 25, 5.5 }, { 27.5, 2.5 }, { 29.8, 5 }, { 24, 1.2 } }
	for index, spot in ipairs(graves) do
		local u, v = spot[1], spot[2]
		box(f, "Grave" .. index, u - 0.7, u + 0.7, 0.3, 1.9, v - 0.18, v + 0.18, C.Stone, STONE)
		make(f, "GraveTop" .. index, Vector3.new(0.36, 1.4, 1.4), CFrame.new(W(u, 1.9, v)) * CFrame.Angles(0, math.rad(90), 0), C.Stone, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate })
	end
	for index, spot in ipairs({ { 21.6, 6.3 }, { 30.6, 1.6 } }) do
		local u, v = spot[1], spot[2]
		box(f, "TreeTrunk" .. index, u - 0.3, u + 0.3, 0.3, 6.2, v - 0.3, v + 0.3, Color3.fromRGB(34, 28, 26))
		make(f, "TreeBranchA" .. index, Vector3.new(0.25, 3, 0.25), CFrame.new(W(u + 0.9, 6.2, v)) * CFrame.Angles(0, 0, math.rad(-40)), Color3.fromRGB(34, 28, 26))
		make(f, "TreeBranchB" .. index, Vector3.new(0.22, 2.6, 0.22), CFrame.new(W(u - 0.8, 5.6, v + 0.3)) * CFrame.Angles(math.rad(20), 0, math.rad(48)), Color3.fromRGB(34, 28, 26))
		make(f, "TreeBranchC" .. index, Vector3.new(0.2, 2, 0.2), CFrame.new(W(u, 6.9, v - 0.6)) * CFrame.Angles(math.rad(-35), 0, math.rad(8)), Color3.fromRGB(34, 28, 26))
	end
	box(f, "FenceRail", 20.6, 31.4, 2.1, 2.22, 8.35, 8.45, C.Iron)
	for i = 0, 6 do
		box(f, "FencePost" .. i, 20.8 + i * 1.75 - 0.08, 20.8 + i * 1.75 + 0.08, 0.3, 2.6, 8.32, 8.48, C.Iron)
	end
	-- Moon on the far wall, with a pale wash of light.
	make(f, "Moon", Vector3.new(0.2, 3.2, 3.2), CFrame.new(W(26, 7.2, 0.25)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(196, 204, 190), { Shape = Enum.PartType.Cylinder })
	lamp(f, "MoonLight", 26, 7, 3, C.ColdLight, 0.55, 20, false)
	-- Faint figures among the graves (always there, barely visible).
	prop(f, "FarFigureA", 1.3, 3.6, 0.1, 23.5, 2.2, 0.5, C.Ghost, { Transparency = 0.86 })
	prop(f, "FarFigureB", 1.1, 3.2, 0.1, 29, 2, 0.5, C.Ghost, { Transparency = 0.9 })
	for index, u in ipairs({ 23, 29 }) do
		local fog = prop(f, "Fog" .. index, 5, 0.2, 6, u, 0.4, 4, C.Ghost, { Transparency = 1 })
		local emitter = fog:FindFirstChildOfClass("ParticleEmitter") or Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(170, 190, 180))
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 4) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.85), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(4, 5)
		emitter.Speed = NumberRange.new(0.2, 0.5)
		emitter.SpreadAngle = Vector2.new(80, 80)
		emitter.Rate = 2
		emitter.Parent = fog
	end
	-- The sudden movement: a small ghost rises from behind the nearest grave.
	local riser = ghost(f, "GraveRiser", facing(26.8, -3.4, 7.3, 0, 1), 0.7, C.GreenLight, 1.4)
	movable(riser, facing(26.8, -3.4, 7.3, 0, 1), facing(26.8, 0.5, 7.3, 0, 1))
end

-- ============================================================
-- Scene 7 -- Finale (u 32..44): false exit, blackout, big ghost, escape
-- ============================================================
do
	local f = scene[7]
	doorPair(f, "ExitDoor", 44.3, 8, 1)
	local falseExit = box(f, "FalseExitSign", 43.5, 43.7, 7.7, 8.9, 8.5, 13.5, BLACK)
	label(falseExit, "KELUAR", C.GreenLight, Enum.NormalId.Left, 40)
	lamp(f, "FinaleLampA", 35, 8.6, 7, C.WarmLight, 0.2, 16, false)
	lamp(f, "FinaleLampB", 41, 8.6, 7, C.WarmLight, 0.2, 16, false)
	for index, u in ipairs({ 34, 37.5, 41 }) do
		box(f, "Drape" .. index, u - 0.7, u + 0.7, 1.2 + (index % 2) * 0.7, 8.8, 0.25, 0.4, C.Cloth, { Material = Enum.Material.Fabric })
	end
	prop(f, "Crate", 2, 2, 2, 35, 1.2, 2, C.Wood, { Material = Enum.Material.WoodPlanks })
	prop(f, "CrateSmall", 1.3, 1.3, 1.3, 37.2, 0.85, 1.6, C.Wood, { Material = Enum.Material.WoodPlanks })
	local big = ghost(f, "BigGhost", facing(41.5, 0.3, 11, -1, 0), 2, C.PurpleLight, 2.2)
	movable(big, facing(43, 0.3, 11, -1, 0), facing(40.6, 0.3, 11, -1, 0))
	-- Seen from the cart as it bursts out into the station.
	local escape = box(f, "EscapeSign", 57.55, 57.8, 4.6, 7.2, 9, 21, BLACK)
	local escapeText = label(escape, "ANDA BERJAYA KELUAR!", C.SignText, Enum.NormalId.Left, 40)
	escapeText.TextTransparency = 1
end

-- ============================================================
-- Cart: four seats in two rows, built at the loading point facing west
-- ============================================================
do
	local start = W(Config.WAYPOINTS[1].u, Config.CART_HEIGHT, Config.WAYPOINTS[1].v)
	local frame = CFrame.lookAt(start, start + Vector3.new(-1, 0, 0))
	local cart = ensureFolder(fVehicles, "HauntedCart", "Model")
	local root = make(cart, "Root", Vector3.new(4.4, 0.5, 6.6), frame, C.Iron, { CanCollide = true, Material = Enum.Material.Metal })
	cart.PrimaryPart = root

	local body = ensureFolder(cart, "Body")
	local front = ensureFolder(cart, "FrontDecoration")
	local lights = ensureFolder(cart, "CartLights")
	local bars = ensureFolder(cart, "SafetyBar")

	-- Everything except Root rides along on a weld.
	local function attach(part)
		part.Anchored = false
		part.Massless = true
		local weld = part:FindFirstChild("RootWeld") or Instance.new("WeldConstraint")
		weld.Name = "RootWeld"
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end
	local function c(parent, name, size, offset, color, props)
		return attach(make(parent, name, size, frame * offset, color, props))
	end

	local RED = Color3.fromRGB(74, 26, 30)
	c(body, "SideLeft", Vector3.new(0.3, 1.5, 6.4), CFrame.new(-2.05, 1, 0), RED, { Material = Enum.Material.WoodPlanks })
	c(body, "SideRight", Vector3.new(0.3, 1.5, 6.4), CFrame.new(2.05, 1, 0), RED, { Material = Enum.Material.WoodPlanks })
	c(body, "FrontWall", Vector3.new(4.4, 1.8, 0.3), CFrame.new(0, 1.15, -3.15), RED, { Material = Enum.Material.WoodPlanks })
	c(body, "BackWall", Vector3.new(4.4, 2.4, 0.3), CFrame.new(0, 1.45, 3.15), RED, { Material = Enum.Material.WoodPlanks })
	c(body, "TrimLeft", Vector3.new(0.4, 0.14, 6.5), CFrame.new(-2.05, 1.8, 0), C.Brass)
	c(body, "TrimRight", Vector3.new(0.4, 0.14, 6.5), CFrame.new(2.05, 1.8, 0), C.Brass)
	c(body, "BackRowRiser", Vector3.new(3.8, 0.35, 2.2), CFrame.new(0, 0.42, 1.5), C.WoodDark)
	c(body, "FrontRowBack", Vector3.new(3.8, 1.5, 0.25), CFrame.new(0, 1.25, -0.2), RED, { Material = Enum.Material.WoodPlanks })
	c(body, "BackRowBack", Vector3.new(3.8, 1.5, 0.25), CFrame.new(0, 1.6, 2.6), RED, { Material = Enum.Material.WoodPlanks })
	for index, wheel in ipairs({ { -2.3, -2.2 }, { 2.3, -2.2 }, { -2.3, 2.2 }, { 2.3, 2.2 } }) do
		c(body, "Wheel" .. index, Vector3.new(0.3, 1, 1), CFrame.new(wheel[1], -0.05, wheel[2]), C.Iron, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	end

	-- Old ghost-train nose: brass crest, two dim lanterns.
	c(front, "Crest", Vector3.new(2.2, 1, 0.2), CFrame.new(0, 1.3, -3.35), C.Brass)
	c(front, "CrestGemLeft", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.5, 1.4, -3.48), C.PurpleLight, BALL)
	c(front, "CrestGemRight", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.5, 1.4, -3.48), C.PurpleLight, BALL)
	c(front, "Bumper", Vector3.new(4.6, 0.3, 0.4), CFrame.new(0, 0.35, -3.4), C.Iron, { Material = Enum.Material.Metal })
	for index, x in ipairs({ -1.8, 1.8 }) do
		local lantern = c(lights, "Lantern" .. index, Vector3.new(0.5, 0.7, 0.5), CFrame.new(x, 2.3, -3.1), C.Brass)
		local light = lantern:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
		light.Color = C.WarmLight
		light.Brightness = 0.7
		light.Range = 9
		light.Shadows = false
		light.Parent = lantern
	end

	c(bars, "FrontBar", Vector3.new(3.9, 0.18, 0.18), CFrame.new(0, 2.05, -2.3), C.Brass, { Shape = Enum.PartType.Cylinder })
	c(bars, "BackBar", Vector3.new(3.9, 0.18, 0.18), CFrame.new(0, 2.4, 0.5), C.Brass, { Shape = Enum.PartType.Cylinder })

	local seats = {
		{ "Seat01", "FrontLeft", -1.05, 0.5, -1.2 },
		{ "Seat02", "FrontRight", 1.05, 0.5, -1.2 },
		{ "Seat03", "BackLeft", -1.05, 0.85, 1.5 },
		{ "Seat04", "BackRight", 1.05, 0.85, 1.5 },
	}
	for _, info in ipairs(seats) do
		local seat = cart:FindFirstChild(info[1])
		if not seat then
			seat = Instance.new("Seat")
			seat.Name = info[1]
			seat.Parent = cart
		end
		seat.Size = Vector3.new(1.8, 0.4, 1.8)
		seat.CFrame = frame * CFrame.new(info[3], info[4], info[5])
		seat.Color = C.Cloth
		seat.Material = Enum.Material.Fabric
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.CanCollide = false
		seat.CanTouch = false -- no sitting by bumping into it; boarding is by prompt only
		seat.Disabled = false
		seat:SetAttribute("Position", info[2])
		attach(seat)

		local prompt = seat:FindFirstChild("BoardPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BoardPrompt"
			prompt.Parent = seat
		end
		prompt.ActionText = "Board"
		prompt.ObjectText = "Rumah Hantu Cart"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Enabled = false -- the server switches these on when boarding opens
	end
end

-- ============================================================
-- Shared data for the server and the lighting client
-- ============================================================

-- The dark zone: the scene rooms, not the open-fronted station.
ride:SetAttribute("InsideMin", W(-5, -1, -1))
ride:SetAttribute("InsideMax", W(44.6, H + 0.6, 31))
ride:SetAttribute("State", "IDLE")

if Config.DEBUG then
	for index, name in ipairs(Config.SCENES) do
		local sceneFolder = scene[index]
		local first = sceneFolder:FindFirstChildWhichIsA("BasePart", true)
		if first then
			local tag = make(fDebug, "SceneTag" .. index, Vector3.new(0.2, 1.2, 6), CFrame.new(first.Position.X, Config.ORIGIN.Y + 9, first.Position.Z), BLACK)
			label(tag, name, Color3.fromRGB(255, 255, 255), Enum.NormalId.Left, 30).Font = Enum.Font.GothamBold
		end
	end
end

local _ = fEffects -- reserved for shared effects (sounds are created by the server)

local count = 0
for _, descendant in ipairs(ride:GetDescendants()) do
	if descendant:IsA("BasePart") then
		count += 1
	end
end
ride:SetAttribute("Built", true)
print(LOG .. "Rumah Hantu built: " .. count .. " parts, track " .. math.floor(path.Length) .. " studs, " .. #Config.WAYPOINTS .. " waypoints.")
