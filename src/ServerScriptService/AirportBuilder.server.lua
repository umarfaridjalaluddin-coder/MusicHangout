-- AirportBuilder (PERMANENT)
-- Builds a small airport in the south-east of the map and flies its plane.
-- Everything lives under Workspace.Environment.Airport. Idempotent: runway and
-- terminal parts are found by name or created, and an existing plane is
-- reused, so a rerun never duplicates anything. Adds only its own objects.
--
-- The flight is a ride, not a free-flying plane: the plane follows a closed
-- path through CONTROL_POINTS (a smooth spline). It waits at the gate, rolls
-- west down the runway, takes off, circles the whole map above everything
-- else, comes back in over the playground side and lands at the gate again.
-- The plane has one anchored base with its seats and body welded to it, so
-- moving the base carries seated players along. Plain parts only.
--
-- Cabin service: a flight attendant stands at the front of the cabin and
-- speaks the crew announcements. Before departure she asks passengers to
-- fasten their seat belts; each seated player gets an on-screen button for it
-- (see PlaneClient in StarterPlayerScripts), which reaches the server through
-- the PlaneSeatBelt remote. The plane holds a little for unfastened belts.
-- Clients read the plane's Phase and Announcement attributes and each seat's
-- BeltOn attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LOG = "[AirportBuilder] "

local AIRLINE_TEXT = "QISYA AIR"
local TERMINAL_TEXT = "QISYA AIRPORT"

local GATE_SECONDS = 30 -- how long the plane waits for passengers
local BELT_CALL_SECONDS = 10 -- the seat belt call starts this long before departure
local MAX_BELT_HOLD = 15 -- extra seconds the plane will wait for unfastened belts
local CRUISE_SPEED = 48 -- studs per second
local SUBDIVISIONS = 14
local GROUND_PATH_Y = 3 -- path height while rolling on the runway
local BASE_LIFT = 2 -- cabin floor centre sits this far above the path

local MAT_PLASTIC = Enum.Material.SmoothPlastic
local WHITE = Color3.fromRGB(245, 245, 248)
local PINK = Color3.fromRGB(255, 170, 215)
local LILAC = Color3.fromRGB(200, 175, 255)
local SKY = Color3.fromRGB(160, 205, 255)
local LEMON = Color3.fromRGB(255, 236, 150)
local MINT = Color3.fromRGB(160, 232, 190)
local GREY = Color3.fromRGB(150, 155, 165)
local ASPHALT = Color3.fromRGB(60, 62, 70)
local TILE = Color3.fromRGB(205, 205, 215)
local DARK = Color3.fromRGB(10, 10, 14)
local RED = Color3.fromRGB(235, 80, 90)
local GREEN = Color3.fromRGB(90, 220, 130)

-- Gate stop first. The plane heads west (-X) on the ground.
local CONTROL_POINTS = {
	Vector3.new(84, 3, 78),
	Vector3.new(70, 3, 78),
	Vector3.new(58, 3, 78),
	Vector3.new(30, 15, 78),
	Vector3.new(-15, 36, 74),
	Vector3.new(-70, 56, 50),
	Vector3.new(-112, 68, 0),
	Vector3.new(-100, 72, -70),
	Vector3.new(-30, 74, -112),
	Vector3.new(55, 74, -104),
	Vector3.new(106, 70, -55),
	Vector3.new(110, 58, 0),
	Vector3.new(114, 36, 36),
	Vector3.new(112, 14, 63),
	Vector3.new(104, 4.5, 76),
	Vector3.new(94, 3, 78),
}

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

local function addText(part, guiName, face, text, textColor)
	local sideways = face == Enum.NormalId.Left or face == Enum.NormalId.Right
	local width = sideways and part.Size.Z or part.Size.X
	local gui = make(part, "SurfaceGui", guiName)
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local emStuds = math.min(0.85 * width / (0.6 * math.max(#text, 1)), 0.7 * part.Size.Y)
	gui.PixelsPerStud = math.clamp(math.floor(100 / emStuds), 12, 50)
	local label = make(gui, "TextLabel", "Text")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	return label
end

-- ============================================================
-- Flight path: sample the spline, keep it above the runway, measure it
-- ============================================================

local function spline(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

local controlCount = #CONTROL_POINTS
local points = {}
for s = 1, controlCount do
	local p0 = CONTROL_POINTS[(s - 2) % controlCount + 1]
	local p1 = CONTROL_POINTS[s]
	local p2 = CONTROL_POINTS[s % controlCount + 1]
	local p3 = CONTROL_POINTS[(s + 1) % controlCount + 1]
	for k = 0, SUBDIVISIONS - 1 do
		local point = spline(p0, p1, p2, p3, k / SUBDIVISIONS)
		-- A smooth curve dips slightly before a climb; never go below the runway.
		table.insert(points, Vector3.new(point.X, math.max(point.Y, GROUND_PATH_Y), point.Z))
	end
end

local pointCount = #points
local lengths = {}
local cumulative = { 0 }
for i = 1, pointCount do
	lengths[i] = (points[i % pointCount + 1] - points[i]).Magnitude
	cumulative[i + 1] = cumulative[i] + lengths[i]
end
local totalLength = cumulative[pointCount + 1]

local function positionAt(distance)
	distance = distance % totalLength
	local low, high = 1, pointCount
	while low < high do
		local mid = math.floor((low + high + 1) / 2)
		if cumulative[mid] <= distance then
			low = mid
		else
			high = mid - 1
		end
	end
	local t = (distance - cumulative[low]) / lengths[low]
	return points[low]:Lerp(points[low % pointCount + 1], t)
end

local function planeCFrame(distance)
	local lift = Vector3.new(0, BASE_LIFT, 0)
	return CFrame.lookAt(positionAt(distance) + lift, positionAt(distance + 6) + lift)
end

-- The gate stop is the first control point, which is the first sample.
local stopDistance = 0
local stopPosition = points[1]
local floorTop = stopPosition.Y + BASE_LIFT + 0.3 -- top of the cabin floor at the gate

-- ============================================================
-- Folders
-- ============================================================

local environment = ensureFolder(Workspace, "Environment")
local airport = ensureFolder(environment, "Airport")
local fRunway = ensureFolder(airport, "Runway")
local fTerminal = ensureFolder(airport, "Terminal")

-- ============================================================
-- Runway (X 44..122, Z 72..84) and path strips from the lobby side
-- ============================================================

local RUNWAY_TOP = 1.3
block(fRunway, "Runway", Vector3.new(78, 0.3, 12), CFrame.new(83, RUNWAY_TOP - 0.15, 78), ASPHALT)
for i = 1, 9 do
	block(fRunway, "CentreLine" .. i, Vector3.new(4, 0.05, 0.5), CFrame.new(44 + i * 8 - 3, RUNWAY_TOP + 0.03, 78), WHITE, false)
end
for i = 0, 6 do
	for side, z in ipairs({ 71.6, 84.4 }) do
		local lamp = block(fRunway, "EdgeLight" .. side .. "_" .. i, Vector3.new(0.5, 0.5, 0.5), CFrame.new(46 + i * 12.5, RUNWAY_TOP + 0.2, z), SKY, false)
		lamp.Shape = Enum.PartType.Ball
		lamp.Material = Enum.Material.Neon
	end
end

-- Route that stays clear of the runway: from the playground path, south past
-- the runway's west end, then east to the terminal.
local function strip(name, from, to)
	local mid = (from + to) / 2
	local p = block(fRunway, name, Vector3.new(4, 0.1, (to - from).Magnitude), CFrame.lookAt(mid, to), SKY, false)
	p.Material = Enum.Material.Neon
end
strip("PathToAirportA", Vector3.new(44, 1.05, 2), Vector3.new(36, 1.05, 94))
strip("PathToAirportB", Vector3.new(36, 1.05, 94), Vector3.new(68, 1.05, 105))

-- ============================================================
-- Terminal: hall, ramp up to a boarding bridge beside the plane's door
-- ============================================================

local SX = stopPosition.X -- the cabin door is level with this X at the gate
local BRIDGE_FROM_Z = stopPosition.Z + 3.1 -- just outside the plane's left side
local BRIDGE_TO_Z = BRIDGE_FROM_Z + 7
local RAMP_FOOT_Z = BRIDGE_TO_Z + 12
local HALL_BACK_Z = RAMP_FOOT_Z + 10

-- Hall floor and roof.
block(fTerminal, "HallFloor", Vector3.new(34, 0.3, HALL_BACK_Z - BRIDGE_TO_Z), CFrame.new(SX, RUNWAY_TOP - 0.15, (BRIDGE_TO_Z + HALL_BACK_Z) / 2), TILE)
local roofY = floorTop + 7
block(fTerminal, "HallRoof", Vector3.new(36, 0.6, HALL_BACK_Z - BRIDGE_TO_Z + 2), CFrame.new(SX, roofY, (BRIDGE_TO_Z + HALL_BACK_Z) / 2), LILAC)
for index, corner in ipairs({ { -17, BRIDGE_TO_Z + 0.5 }, { 17, BRIDGE_TO_Z + 0.5 }, { -17, HALL_BACK_Z - 0.5 }, { 17, HALL_BACK_Z - 0.5 } }) do
	local height = roofY - RUNWAY_TOP
	block(fTerminal, "RoofPost" .. index, Vector3.new(0.8, height, 0.8), CFrame.new(SX + corner[1], RUNWAY_TOP + height / 2, corner[2]), WHITE)
end

-- Name sign on the roof edge, read from the runway and lobby side (-Z).
local terminalSign = block(fTerminal, "TerminalSign", Vector3.new(30, 3, 0.4), CFrame.new(SX, roofY + 1.8, BRIDGE_TO_Z - 1.2), DARK)
addText(terminalSign, "Label", Enum.NormalId.Front, TERMINAL_TEXT, LEMON)

-- Check-in desk and waiting benches.
block(fTerminal, "CheckInDesk", Vector3.new(8, 3, 2), CFrame.new(SX - 10, RUNWAY_TOP + 1.5, HALL_BACK_Z - 3), PINK)
local deskSign = block(fTerminal, "CheckInSign", Vector3.new(8, 1.4, 0.3), CFrame.new(SX - 10, RUNWAY_TOP + 5, HALL_BACK_Z - 3), DARK, false)
addText(deskSign, "Label", Enum.NormalId.Front, "CHECK-IN", MINT)
for i = 1, 2 do
	block(fTerminal, "Bench" .. i, Vector3.new(7, 1, 2), CFrame.new(SX + 10, RUNWAY_TOP + 0.5, HALL_BACK_Z - 2 - i * 4), SKY)
end

-- Boarding bridge (level with the cabin floor) and the ramp up to it.
local bridgeMidZ = (BRIDGE_FROM_Z + BRIDGE_TO_Z) / 2
block(fTerminal, "Bridge", Vector3.new(4, 0.5, BRIDGE_TO_Z - BRIDGE_FROM_Z), CFrame.new(SX, floorTop - 0.25, bridgeMidZ), WHITE)
local rampTop = Vector3.new(SX, floorTop, BRIDGE_TO_Z)
local rampFoot = Vector3.new(SX, RUNWAY_TOP, RAMP_FOOT_Z)
local rampMid = (rampTop + rampFoot) / 2 - Vector3.new(0, 0.25, 0)
block(fTerminal, "Ramp", Vector3.new(4, 0.5, (rampFoot - rampTop).Magnitude + 0.4), CFrame.lookAt(rampMid, rampMid + (rampFoot - rampTop)), PINK)

-- Side rails along the bridge and ramp.
local function rail(name, x, fromPoint, toPoint)
	local from = Vector3.new(x, fromPoint.Y, fromPoint.Z)
	local to = Vector3.new(x, toPoint.Y, toPoint.Z)
	local along = CFrame.lookAt((from + to) / 2, to)
	block(fTerminal, name .. "Top", Vector3.new(0.3, 0.3, (to - from).Magnitude), along + Vector3.new(0, 2.2, 0), WHITE)
	block(fTerminal, name .. "Mid", Vector3.new(0.3, 0.3, (to - from).Magnitude), along + Vector3.new(0, 1.1, 0), WHITE)
end
local bridgeStart = Vector3.new(SX, floorTop, BRIDGE_FROM_Z)
for _, side in ipairs({ -1, 1 }) do
	local x = SX + side * 2.15
	local tag = side < 0 and "West" or "East"
	rail("BridgeRail" .. tag, x, bridgeStart, rampTop)
	rail("RampRail" .. tag, x, rampTop, rampFoot)
	block(fTerminal, "RailPost" .. tag .. "1", Vector3.new(0.4, 2.4, 0.4), CFrame.new(x, floorTop + 1.2, BRIDGE_FROM_Z + 0.2), SKY)
	block(fTerminal, "RailPost" .. tag .. "2", Vector3.new(0.4, 2.4, 0.4), CFrame.new(x, floorTop + 1.2, BRIDGE_TO_Z), SKY)
	block(fTerminal, "RailPost" .. tag .. "3", Vector3.new(0.4, 2.4, 0.4), CFrame.new(x, RUNWAY_TOP + 1.2, RAMP_FOOT_Z), SKY)
end

-- Gate sign and departure board over the top of the ramp, read from the hall (+Z).
local boardPosition = Vector3.new(SX, floorTop + 5.2, BRIDGE_TO_Z + 0.6)
local statusSign = block(fTerminal, "DepartureBoard", Vector3.new(14, 2, 0.3), CFrame.lookAt(boardPosition, boardPosition + Vector3.zAxis), DARK, false)
local statusLabel = addText(statusSign, "Label", Enum.NormalId.Front, "GATE 1 - BOARDING", GREEN)
-- Posts stand on the ground, just behind the reach of the plane's wingtip.
local boardPostHeight = floorTop + 6.2 - RUNWAY_TOP
block(fTerminal, "BoardPostWest", Vector3.new(0.4, boardPostHeight, 0.4), CFrame.new(SX - 6.8, RUNWAY_TOP + boardPostHeight / 2, BRIDGE_TO_Z + 0.6), SKY, false)
block(fTerminal, "BoardPostEast", Vector3.new(0.4, boardPostHeight, 0.4), CFrame.new(SX + 6.8, RUNWAY_TOP + boardPostHeight / 2, BRIDGE_TO_Z + 0.6), SKY, false)

for index, x in ipairs({ SX - 9, SX + 9 }) do
	local lamp = block(fTerminal, "Lamp" .. index, Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, roofY - 1, (BRIDGE_TO_Z + HALL_BACK_Z) / 2), LEMON, false)
	lamp.Shape = Enum.PartType.Ball
	lamp.Material = Enum.Material.Neon
	local light = make(lamp, "PointLight", "Glow")
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Range = 26
	light.Brightness = 0.6
end

-- ============================================================
-- Plane: anchored cabin floor with everything else welded to it.
-- Forward is the floor's -Z. On the ground the plane heads west, so its left
-- side (-X of the floor) faces the terminal; the door gap is on that side.
-- ============================================================

local plane = airport:FindFirstChild("Plane")
local base
if plane and plane:IsA("Model") and plane:GetAttribute("Built") and plane:FindFirstChild("Base") then
	base = plane.Base
else
	plane = Instance.new("Model")
	plane.Name = "Plane"

	base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5.6, 0.6, 24)
	base.Color = TILE
	base.Material = MAT_PLASTIC
	base.Anchored = true
	base.CFrame = planeCFrame(stopDistance)
	base.Parent = plane
	plane.PrimaryPart = base

	local function attach(className, name, size, offset, color, canCollide)
		local p = Instance.new(className)
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = MAT_PLASTIC
		p.Anchored = false
		p.Massless = true
		p.CanCollide = canCollide ~= false
		p.CFrame = base.CFrame * offset
		p.Parent = plane
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	local at = CFrame.new

	-- Body.
	attach("Part", "Hull", Vector3.new(6, 2, 24), at(0, -1.3, 0), WHITE)
	attach("Part", "StripeLeft", Vector3.new(0.1, 0.5, 24), at(-3.03, -0.7, 0), PINK, false)
	attach("Part", "StripeRight", Vector3.new(0.1, 0.5, 24), at(3.03, -0.7, 0), PINK, false)
	-- Left wall has a door gap from Z -1.5 to 1.5.
	attach("Part", "WallLeftFront", Vector3.new(0.3, 1.4, 10.5), at(-2.9, 1, -6.75), WHITE)
	attach("Part", "WallLeftBack", Vector3.new(0.3, 1.4, 10.5), at(-2.9, 1, 6.75), WHITE)
	attach("Part", "WallRight", Vector3.new(0.3, 1.4, 24), at(2.9, 1, 0), WHITE)
	attach("Part", "Roof", Vector3.new(6, 0.4, 24), at(0, 6.4, 0), WHITE)
	for i, z in ipairs({ -11.5, -4, 4, 11.5 }) do
		attach("Part", "PillarLeft" .. i, Vector3.new(0.3, 4.5, 0.3), at(-2.9, 3.95, z), WHITE)
		attach("Part", "PillarRight" .. i, Vector3.new(0.3, 4.5, 0.3), at(2.9, 3.95, z), WHITE)
	end
	attach("Part", "RearWall", Vector3.new(5.6, 5.9, 0.3), at(0, 3.25, 12), WHITE)

	-- Cockpit and nose.
	attach("Part", "FrontLower", Vector3.new(5.6, 1.6, 0.3), at(0, 1.1, -12), WHITE)
	local windshield = attach("Part", "Windshield", Vector3.new(5.6, 3, 0.3), at(0, 3.4, -12), SKY)
	windshield.Material = Enum.Material.Glass
	windshield.Transparency = 0.5
	attach("Part", "FrontUpper", Vector3.new(5.6, 1.3, 0.3), at(0, 5.55, -12), WHITE)
	attach("Part", "Nose", Vector3.new(5, 3, 3), at(0, -0.6, -13.5), WHITE, false)
	attach("Part", "NoseTip", Vector3.new(3.4, 2.2, 2.4), at(0, -0.8, -16), PINK, false)

	-- Tail.
	attach("Part", "TailCone", Vector3.new(4, 3, 4), at(0, 0.2, 14), WHITE, false)
	attach("Part", "Fin", Vector3.new(0.5, 5.5, 4), at(0, 4.4, 14.5), PINK, false)
	attach("Part", "Tailplane", Vector3.new(8, 0.4, 3), at(0, 3.4, 15), WHITE, false)

	-- Wings, engines and wheels.
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "Left" or "Right"
		attach("Part", "Wing" .. tag, Vector3.new(6, 0.5, 5), at(side * 6, -1.2, 0.5), WHITE, false)
		attach("Part", "WingTip" .. tag, Vector3.new(0.6, 0.6, 5), at(side * 9.3, -1.2, 0.5), PINK, false)
		local tipLight = attach("Part", "TipLight" .. tag, Vector3.new(0.5, 0.5, 0.5), at(side * 9.6, -1.2, -2), side < 0 and RED or GREEN, false)
		tipLight.Shape = Enum.PartType.Ball
		tipLight.Material = Enum.Material.Neon
		-- Cylinders lie along X, so turn the engine to point forward.
		local engine = attach("Part", "Engine" .. tag, Vector3.new(4, 1.8, 1.8), at(side * 5.5, -2.2, -0.5) * CFrame.Angles(0, math.rad(90), 0), GREY, false)
		engine.Shape = Enum.PartType.Cylinder
		local wheel = attach("Part", "Wheel" .. tag, Vector3.new(0.6, 1.4, 1.4), at(side * 2, -3, 3), DARK, false)
		wheel.Shape = Enum.PartType.Cylinder
	end
	local noseWheel = attach("Part", "WheelNose", Vector3.new(0.6, 1.4, 1.4), at(0, -3, -9), DARK, false)
	noseWheel.Shape = Enum.PartType.Cylinder

	-- Airline name on both sides of the hull.
	local nameLeft = attach("Part", "NameLeft", Vector3.new(0.1, 1.3, 9), at(-3.06, -1.6, -5), WHITE, false)
	addText(nameLeft, "Label", Enum.NormalId.Left, AIRLINE_TEXT, Color3.fromRGB(220, 90, 160))
	local nameRight = attach("Part", "NameRight", Vector3.new(0.1, 1.3, 9), at(3.06, -1.6, -5), WHITE, false)
	addText(nameRight, "Label", Enum.NormalId.Right, AIRLINE_TEXT, Color3.fromRGB(220, 90, 160))

	-- Seats: a captain's seat, then four rows of two with an aisle between.
	attach("Seat", "SeatCaptain", Vector3.new(2, 0.5, 2), at(0, 0.55, -10.3), LEMON)
	for row, z in ipairs({ -7, -3.6, 3.6, 7 }) do
		attach("Seat", "SeatLeft" .. row, Vector3.new(2, 0.5, 2), at(-1.6, 0.55, z), LILAC)
		attach("Seat", "SeatRight" .. row, Vector3.new(2, 0.5, 2), at(1.6, 0.55, z), LILAC)
	end

	-- Seat belt straps across each seat, hidden until a passenger fastens them.
	for _, child in ipairs(plane:GetChildren()) do
		if child:IsA("Seat") then
			local belt = attach("Part", "Belt_" .. child.Name, Vector3.new(2.1, 0.15, 0.4), base.CFrame:ToObjectSpace(child.CFrame) * at(0, 1.25, -0.35), DARK, false)
			belt.Transparency = 1
		end
	end

	-- Flight attendant: an original block figure in the aisle behind the
	-- captain's seat, turned to face the passengers. Players walk through her.
	local NAVY = Color3.fromRGB(45, 60, 110)
	local SKIN = Color3.fromRGB(240, 200, 170)
	local HAIR = Color3.fromRGB(70, 45, 30)
	local stand = at(0, 0, -8.6) * CFrame.Angles(0, math.pi, 0)
	local function crew(name, size, offset, color)
		return attach("Part", "Attendant" .. name, size, stand * offset, color, false)
	end
	crew("LegLeft", Vector3.new(0.35, 1.6, 0.35), at(-0.25, 1.1, 0), SKIN)
	crew("LegRight", Vector3.new(0.35, 1.6, 0.35), at(0.25, 1.1, 0), SKIN)
	crew("Skirt", Vector3.new(1.2, 1.1, 0.7), at(0, 2.35, 0), NAVY)
	crew("Torso", Vector3.new(1.2, 1.5, 0.7), at(0, 3.6, 0), NAVY)
	crew("ArmLeft", Vector3.new(0.35, 1.4, 0.35), at(-0.8, 3.6, 0), NAVY)
	crew("ArmRight", Vector3.new(0.35, 1.4, 0.35), at(0.8, 3.6, 0), NAVY)
	crew("Scarf", Vector3.new(0.9, 0.25, 0.75), at(0, 4.3, 0), PINK)
	local head = crew("Head", Vector3.new(1.1, 1.1, 1.1), at(0, 5, 0), SKIN)
	head.Shape = Enum.PartType.Ball
	crew("Hair", Vector3.new(1.15, 0.5, 1.15), at(0, 5.42, 0.08), HAIR)
	crew("Bun", Vector3.new(0.5, 0.5, 0.5), at(0, 5.3, 0.65), HAIR).Shape = Enum.PartType.Ball
	crew("Hat", Vector3.new(0.7, 0.3, 0.7), at(0, 5.78, 0), PINK)
	crew("EyeLeft", Vector3.new(0.16, 0.16, 0.16), at(-0.22, 5.08, -0.5), DARK).Shape = Enum.PartType.Ball
	crew("EyeRight", Vector3.new(0.16, 0.16, 0.16), at(0.22, 5.08, -0.5), DARK).Shape = Enum.PartType.Ball
	crew("Smile", Vector3.new(0.4, 0.08, 0.06), at(0, 4.78, -0.52), Color3.fromRGB(200, 80, 110))

	-- Speech bubble over her head; the text is set by the flight loop below.
	local speech = Instance.new("BillboardGui")
	speech.Name = "Speech"
	speech.Size = UDim2.fromScale(11, 2.8)
	speech.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	speech.AlwaysOnTop = true
	speech.MaxDistance = 45
	speech.LightInfluence = 0
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.Size = UDim2.fromScale(1, 1)
	line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	line.BackgroundTransparency = 0.1
	line.TextColor3 = Color3.fromRGB(40, 40, 60)
	line.Font = Enum.Font.GothamBold
	line.TextScaled = true
	line.TextWrapped = true
	line.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = line
	line.Parent = speech
	speech.Parent = head

	plane:SetAttribute("Built", true)
	plane.Parent = airport
end

-- ============================================================
-- Fly the plane
-- ============================================================

-- If this script is ever run again, the newest copy takes over the plane.
local driverToken = tostring(os.clock()) .. "-" .. tostring(math.random(1, 1000000))
base:SetAttribute("Driver", driverToken)

local distance = stopDistance
local waitUntil = os.clock() + GATE_SECONDS
local departedAt = os.clock()
local arrivedAt = 0 -- 0 until the plane has landed once
local holdUntil = nil

base.CFrame = planeCFrame(distance)

local lastStatus
local function setStatus(text)
	if text ~= lastStatus then
		lastStatus = text
		statusLabel.Text = text
	end
end

-- Crew announcements: shown in the attendant's speech bubble and published as
-- attributes for each passenger's on-screen banner.
local attendantHead = plane:FindFirstChild("AttendantHead")
local speech = attendantHead and attendantHead:FindFirstChild("Speech")
local speechLine = speech and speech:FindFirstChild("Line")

local function announce(phase, text)
	if plane:GetAttribute("Phase") ~= phase then
		plane:SetAttribute("Phase", phase)
	end
	if plane:GetAttribute("Announcement") ~= text then
		plane:SetAttribute("Announcement", text)
		if speechLine then
			speechLine.Text = text
		end
	end
end

-- Seat belts.
local seats = {}
for _, child in ipairs(plane:GetChildren()) do
	if child:IsA("Seat") then
		table.insert(seats, child)
	end
end

local function setBelt(seat, fastened)
	seat:SetAttribute("BeltOn", fastened)
	local belt = plane:FindFirstChild("Belt_" .. seat.Name)
	if belt then
		belt.Transparency = fastened and 0 or 1
	end
end

for _, seat in ipairs(seats) do
	if not seat.Occupant then
		setBelt(seat, false)
	end
	-- A belt never stays fastened on an empty seat.
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not seat.Occupant then
			setBelt(seat, false)
		end
	end)
end

local function everyoneBelted()
	for _, seat in ipairs(seats) do
		if seat.Occupant and seat:GetAttribute("BeltOn") ~= true then
			return false
		end
	end
	return true
end

-- The button on a passenger's screen asks the server to fasten or unfasten.
-- The server only acts for the seat that player is really sitting in, and
-- never unfastens a belt in the air.
local remotes = ensureFolder(ReplicatedStorage, "Remotes")
local beltRemote = make(remotes, "RemoteEvent", "PlaneSeatBelt")
local lastRequest = setmetatable({}, { __mode = "k" })
beltRemote.OnServerEvent:Connect(function(player, fasten)
	if type(fasten) ~= "boolean" then
		return
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.3 then
		return
	end
	lastRequest[player] = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat or seat.Parent ~= plane or not seat:IsA("Seat") then
		return
	end
	if not fasten and plane:GetAttribute("Phase") == "Flight" then
		return
	end
	setBelt(seat, fasten)
end)

local connection
connection = RunService.Heartbeat:Connect(function(dt)
	if not base.Parent or base:GetAttribute("Driver") ~= driverToken then
		connection:Disconnect()
		return
	end

	local now = os.clock()
	if waitUntil then
		local remaining = waitUntil - now
		if remaining > 0 then
			if arrivedAt > 0 and now - arrivedAt < 7 then
				announce("Boarding", "We have landed. You may unfasten your seat belt. Thank you for flying Qisya Air!")
			elseif remaining > BELT_CALL_SECONDS then
				announce("Boarding", "Welcome aboard Qisya Air! Please take a seat.")
			else
				announce("SeatBelts", "We are about to depart. Please fasten your seat belt.")
			end
			setStatus("GATE 1 - DEPARTS IN " .. math.ceil(remaining))
			return
		end

		-- Time is up. Hold a little if a seated passenger has no belt on.
		if not everyoneBelted() then
			holdUntil = holdUntil or (now + MAX_BELT_HOLD)
			if now < holdUntil then
				announce("SeatBelts", "Waiting for all passengers to fasten their seat belts.")
				setStatus("GATE 1 - FINAL CALL")
				return
			end
		end

		holdUntil = nil
		waitUntil = nil
		departedAt = now
		setStatus("FLIGHT IN PROGRESS")
	end

	local sinceDeparture = now - departedAt
	-- Speed up along the runway.
	local speed = CRUISE_SPEED * math.clamp(sinceDeparture / 6, 0.08, 1)

	local ahead = (stopDistance - distance) % totalLength
	local approaching = sinceDeparture > 8 and ahead < 90
	if approaching then
		-- Slow down for the landing and the roll to the gate.
		speed = math.min(speed, 5 + ahead * 0.45)
	end

	if sinceDeparture < 7 then
		announce("Flight", "Cabin crew, prepare for take-off.")
	elseif sinceDeparture > 8 and ahead < 220 then
		announce("Flight", "We are landing soon. Please stay seated with your seat belt fastened.")
	else
		announce("Flight", "Enjoy the flight! Happy Birthday Qisya!")
	end

	local step = speed * math.min(dt, 0.1)
	if approaching and ahead <= step then
		distance = stopDistance
		waitUntil = now + GATE_SECONDS
		arrivedAt = now
	else
		distance = (distance + step) % totalLength
	end

	base.CFrame = planeCFrame(distance)
end)

print(LOG .. string.format("Airport complete. Flight path %d studs.", math.floor(totalLength)))
