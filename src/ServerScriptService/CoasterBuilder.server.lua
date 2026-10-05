-- CoasterBuilder (PERMANENT)
-- Builds a mini rollercoaster that circles the map and drives its cart.
-- Everything lives under Workspace.Environment.Coaster. Idempotent: track and
-- station parts are found by name or created, and an existing cart is reused,
-- so a rerun never duplicates anything. Adds only its own objects.
--
-- Unicorn theme: pastel rainbow rails, a rainbow arch at the queue entrance,
-- and a cart shaped like a white unicorn (head, golden horn, rainbow mane and
-- tail), built only from plain parts.
--
-- The track is a closed loop through CONTROL_POINTS (a smooth spline). The cart
-- has one anchored base; its seats, walls and billboard are welded to it, so
-- moving the base carries seated players along. The cart waits at the station
-- south of the Outdoor zone, then runs one lap, faster in the dips. The
-- station has a railed queue lane, a boarding gap, an exit ramp and a sign
-- that counts down to departure.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LOG = "[CoasterBuilder] "

local BILLBOARD_TEXT = "HAPPY BIRTHDAY QISYA"
local STATION_TEXT = "QISYA'S UNICORN COASTER"

local STATION_SECONDS = 15 -- how long the cart waits for riders
local MIN_SPEED = 16 -- studs per second at the top of the highest hill
local SPEED_PER_STUD = 1 -- extra speed for each stud below TOP_Y
local TOP_Y = 38
local SUBDIVISIONS = 14 -- track pieces between two control points
local RAIL_OFFSET = 1.5

local MAT_PLASTIC = Enum.Material.SmoothPlastic
-- Pastel unicorn palette.
local RED = Color3.fromRGB(255, 150, 170)
local ORANGE = Color3.fromRGB(255, 195, 150)
local YELLOW = Color3.fromRGB(255, 236, 150)
local GREEN = Color3.fromRGB(160, 232, 190)
local BLUE = Color3.fromRGB(160, 205, 255)
local PURPLE = Color3.fromRGB(200, 175, 255)
local PINK = Color3.fromRGB(255, 170, 215)
local WHITE = Color3.fromRGB(245, 243, 250)
local GREY = Color3.fromRGB(225, 220, 240)
local GOLD = Color3.fromRGB(255, 205, 90)
local EYE = Color3.fromRGB(35, 30, 50)
local DARK = Color3.fromRGB(10, 10, 14)
local RAINBOW = { RED, ORANGE, YELLOW, GREEN, BLUE, PURPLE }

-- Rail height at each point. The first three and the last are level so the
-- station stretch (X -20 to 20, Z 124) is flat.
local CONTROL_POINTS = {
	Vector3.new(-20, 4, 124),
	Vector3.new(20, 4, 124),
	Vector3.new(50, 4, 124),
	Vector3.new(95, 14, 118),
	Vector3.new(130, 30, 85),
	Vector3.new(136, 38, 20),
	Vector3.new(128, 20, -50),
	Vector3.new(98, 34, -112),
	Vector3.new(30, 14, -130),
	Vector3.new(-40, 36, -126),
	Vector3.new(-105, 18, -112),
	Vector3.new(-134, 38, -50),
	Vector3.new(-136, 16, 20),
	Vector3.new(-122, 34, 85),
	Vector3.new(-90, 14, 118),
	Vector3.new(-50, 4, 124),
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
	local faceSize = (face == Enum.NormalId.Left or face == Enum.NormalId.Right) and Vector2.new(part.Size.Z, part.Size.Y) or Vector2.new(part.Size.X, part.Size.Y)
	local gui = make(part, "SurfaceGui", guiName)
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local emStuds = math.min(0.85 * faceSize.X / (0.6 * math.max(#text, 1)), 0.7 * faceSize.Y)
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
-- Track path: sample the spline, then measure it
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
		table.insert(points, spline(p0, p1, p2, p3, k / SUBDIVISIONS))
	end
end

local pointCount = #points
local lengths = {}
local cumulative = { 0 }
for i = 1, pointCount do
	local nextPoint = points[i % pointCount + 1]
	lengths[i] = (nextPoint - points[i]).Magnitude
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

local function cartCFrame(distance)
	local lift = Vector3.new(0, 1, 0)
	return CFrame.lookAt(positionAt(distance) + lift, positionAt(distance + 3) + lift)
end

-- The cart stops halfway along the flat stretch between the first two points.
local stopIndex = math.floor(SUBDIVISIONS / 2) + 1
local stopDistance = cumulative[stopIndex]
local stopPosition = points[stopIndex]

-- ============================================================
-- Folders
-- ============================================================

local environment = ensureFolder(Workspace, "Environment")
local coaster = ensureFolder(environment, "Coaster")
local fTrack = ensureFolder(coaster, "Track")
local fSupports = ensureFolder(coaster, "Supports")
local fStation = ensureFolder(coaster, "Station")

-- ============================================================
-- Rails, ties and supports
-- ============================================================

for i = 1, pointCount do
	local a = points[i]
	local b = points[i % pointCount + 1]
	local direction = (b - a).Unit
	local right = direction:Cross(Vector3.yAxis).Unit
	local mid = (a + b) / 2
	local railSize = Vector3.new(0.4, 0.5, lengths[i] + 0.3)
	local color = RAINBOW[math.floor((i - 1) / SUBDIVISIONS) % #RAINBOW + 1]

	for _, side in ipairs({ -1, 1 }) do
		local center = mid + right * (side * RAIL_OFFSET) - Vector3.new(0, 0.25, 0)
		block(fTrack, (side < 0 and "RailLeft" or "RailRight") .. i, railSize, CFrame.lookAt(center, center + direction), color)
	end

	if i % 2 == 1 then
		local center = mid - Vector3.new(0, 0.65, 0)
		block(fTrack, "Tie" .. i, Vector3.new(4, 0.3, 0.6), CFrame.lookAt(center, center + direction), WHITE, false)
	end
end

for s = 1, controlCount do
	local top = CONTROL_POINTS[s]
	local height = top.Y - 0.8 - 1 -- from the ground (top Y=1) to just under the ties
	if height >= 3 then
		block(fSupports, "Support" .. s, Vector3.new(1.2, height, 1.2), CFrame.new(top.X, 1 + height / 2, top.Z), GREY)
	end
end

-- ============================================================
-- Station: roofed platform beside the track, with a railed queue lane, a
-- boarding gap at the cart, an exit ramp and a status sign
-- ============================================================

local SX, SZ = stopPosition.X, stopPosition.Z
local platformTop = stopPosition.Y + 1.5 -- level with the cart floor
local platformHeight = platformTop - 1
local BACK_Z = SZ - 13 -- back edge of the platform
local FRONT_Z = SZ - 3 -- front edge, beside the cart
local MID_Z = (BACK_Z + FRONT_Z) / 2

block(fStation, "Platform", Vector3.new(36, platformHeight, FRONT_Z - BACK_Z), CFrame.new(SX, 1 + platformHeight / 2, MID_Z), PURPLE)
-- Yellow line marking where the cart doors stop.
block(fStation, "PlatformEdge", Vector3.new(10, 0.2, 0.6), CFrame.new(SX, platformTop + 0.1, FRONT_Z - 0.4), YELLOW, false)

local function ramp(name, bottom, top, width, color)
	local mid = (bottom + top) / 2 - Vector3.new(0, 0.5, 0)
	block(fStation, name, Vector3.new(width, 1, (top - bottom).Magnitude + 0.5), CFrame.lookAt(mid, mid + (top - bottom)), color)
end

-- Entrance ramp from the Outdoor floor (top Y=2), clear of the planter and bench.
ramp("Ramp", Vector3.new(SX + 10, 2, BACK_Z - 11), Vector3.new(SX + 10, platformTop, BACK_Z), 8, PINK)
-- Exit ramp down to the ground on the east side.
ramp("ExitRamp", Vector3.new(SX + 30, 1, FRONT_Z - 2.5), Vector3.new(SX + 18, platformTop, FRONT_Z - 2.5), 5, GREEN)

-- A two-bar railing between two points on the platform.
local function fence(name, x1, z1, x2, z2)
	local from = Vector3.new(x1, platformTop, z1)
	local to = Vector3.new(x2, platformTop, z2)
	local length = (to - from).Magnitude
	local along = CFrame.lookAt((from + to) / 2, to)
	block(fStation, name .. "Top", Vector3.new(0.3, 0.3, length), along + Vector3.new(0, 2.6, 0), WHITE)
	block(fStation, name .. "Mid", Vector3.new(0.3, 0.3, length), along + Vector3.new(0, 1.4, 0), WHITE)
	local gaps = math.max(1, math.floor(length / 4 + 0.5))
	for i = 0, gaps do
		local at = from:Lerp(to, i / gaps)
		block(fStation, name .. "Post" .. i, Vector3.new(0.4, 2.8, 0.4), CFrame.new(at + Vector3.new(0, 1.4, 0)), BLUE)
	end
end

-- Queue route: up the entrance ramp, west along the back lane, round the end
-- of the divider, east along the front lane to the boarding gap. Riders leave
-- by the front lane's east end and the exit ramp.
fence("FenceBackWest", SX - 18, BACK_Z, SX + 6, BACK_Z)
fence("FenceBackEast", SX + 14, BACK_Z, SX + 18, BACK_Z)
fence("FenceWestEnd", SX - 18, BACK_Z, SX - 18, FRONT_Z)
fence("FenceEastEnd", SX + 18, BACK_Z, SX + 18, MID_Z)
fence("FenceDivider", SX - 12, MID_Z, SX + 18, MID_Z)
fence("FenceFrontWest", SX - 18, FRONT_Z, SX - 5, FRONT_Z)
fence("FenceFrontEast", SX + 5, FRONT_Z, SX + 18, FRONT_Z)

-- Roof on four posts.
local roofY = platformTop + 10
block(fStation, "Roof", Vector3.new(38, 0.6, FRONT_Z - BACK_Z + 2), CFrame.new(SX, roofY, MID_Z), PINK)
for index, corner in ipairs({ Vector3.new(-17.6, 0, BACK_Z + 0.4), Vector3.new(17.6, 0, BACK_Z + 0.4), Vector3.new(-17.6, 0, FRONT_Z - 1.4), Vector3.new(17.6, 0, FRONT_Z - 1.4) }) do
	block(fStation, "RoofPost" .. index, Vector3.new(0.8, 10, 0.8), CFrame.new(SX + corner.X, platformTop + 5, corner.Z), BLUE)
end

-- Name sign on the back edge of the roof, read from the Outdoor zone (-Z side).
local stationSign = block(fStation, "StationSign", Vector3.new(33, 3, 0.4), CFrame.new(SX, roofY + 1.8, BACK_Z - 1.2), DARK)
addText(stationSign, "Label", Enum.NormalId.Front, STATION_TEXT, YELLOW)

-- Rainbow arch over the foot of the entrance ramp: six bands, each a half
-- circle of short straight pieces.
local ARCH_CENTER = Vector3.new(SX + 10, 2, BACK_Z - 12.5)
local ARCH_PIECES = 12
for band, color in ipairs(RAINBOW) do
	local radius = 7.5 - band * 0.5
	local pieceLength = 2 * radius * math.sin(math.pi / ARCH_PIECES / 2) + 0.1
	for piece = 1, ARCH_PIECES do
		local angle = (piece - 0.5) * math.pi / ARCH_PIECES
		local position = ARCH_CENTER + Vector3.new(radius * math.cos(angle), radius * math.sin(angle), 0)
		block(fStation, "Arch" .. band .. "_" .. piece, Vector3.new(pieceLength, 0.5, 0.6), CFrame.new(position) * CFrame.Angles(0, 0, angle + math.pi / 2), color, false)
	end
end

-- "Queue here" sign sitting on top of the arch.
local queueSign = block(fStation, "QueueSign", Vector3.new(9.2, 1.8, 0.3), CFrame.new(SX + 10, 10.4, BACK_Z - 12.5), DARK)
addText(queueSign, "Label", Enum.NormalId.Front, "QUEUE HERE", GREEN)

-- Status sign above the boarding gap, read from the platform.
local statusSign = block(fStation, "StatusSign", Vector3.new(16, 2, 0.3), CFrame.new(SX, platformTop + 8.4, FRONT_Z - 0.6), DARK)
addText(statusSign, "Label", Enum.NormalId.Front, "BOARDING", GREEN)
local statusLabel = statusSign:FindFirstChild("Label"):FindFirstChild("Text")

for index, x in ipairs({ SX - 9, SX + 9 }) do
	local lamp = block(fStation, "Lamp" .. index, Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, roofY - 1, MID_Z), YELLOW, false)
	lamp.Shape = Enum.PartType.Ball
	lamp.Material = Enum.Material.Neon
	local light = make(lamp, "PointLight", "Glow")
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Range = 24
	light.Brightness = 0.6
end

-- ============================================================
-- Cart: anchored base with everything else welded to it
-- ============================================================

local cart = coaster:FindFirstChild("Cart")
local base
if cart and cart:IsA("Model") and cart:GetAttribute("Built") and cart:FindFirstChild("Base") then
	base = cart.Base
else
	cart = Instance.new("Model")
	cart.Name = "Cart"

	base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5, 1, 8)
	base.Color = WHITE
	base.Material = MAT_PLASTIC
	base.Anchored = true
	base.CFrame = cartCFrame(stopDistance)
	base.Parent = cart
	cart.PrimaryPart = base

	local function attach(className, name, size, offset, color)
		local p = Instance.new(className)
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = MAT_PLASTIC
		p.Anchored = false
		p.Massless = true
		p.CFrame = base.CFrame * offset
		p.Parent = cart
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	-- Forward is the base's -Z. Two rows of two seats, all facing forward.
	attach("Seat", "SeatFrontLeft", Vector3.new(2, 0.5, 2), CFrame.new(-1.2, 0.75, -1.6), PURPLE)
	attach("Seat", "SeatFrontRight", Vector3.new(2, 0.5, 2), CFrame.new(1.2, 0.75, -1.6), PURPLE)
	attach("Seat", "SeatBackLeft", Vector3.new(2, 0.5, 2), CFrame.new(-1.2, 0.75, 1.6), PURPLE)
	attach("Seat", "SeatBackRight", Vector3.new(2, 0.5, 2), CFrame.new(1.2, 0.75, 1.6), PURPLE)

	attach("Part", "WallLeft", Vector3.new(0.4, 0.8, 8), CFrame.new(-2.7, 0.9, 0), PINK)
	attach("Part", "WallRight", Vector3.new(0.4, 0.8, 8), CFrame.new(2.7, 0.9, 0), PINK)
	attach("Part", "Nose", Vector3.new(5.8, 1.6, 0.4), CFrame.new(0, 1.3, -4.2), WHITE)
	attach("Part", "Tail", Vector3.new(5.8, 2.4, 0.4), CFrame.new(0, 1.7, 4.2), WHITE)

	-- Unicorn shape. Decorative only, so players never snag on it.
	local function decor(name, size, offset, color)
		local p = attach("Part", name, size, offset, color)
		p.CanCollide = false
		return p
	end
	local leanForward = CFrame.Angles(math.rad(-25), 0, 0)

	decor("Neck", Vector3.new(1.6, 3.4, 1.6), CFrame.new(0, 2.9, -4.9) * leanForward, WHITE)
	decor("Head", Vector3.new(1.8, 1.8, 2.8), CFrame.new(0, 4.6, -6.1), WHITE)
	decor("Snout", Vector3.new(1.4, 1.2, 1.2), CFrame.new(0, 4.3, -7.9), PINK)
	decor("EarLeft", Vector3.new(0.35, 0.8, 0.35), CFrame.new(-0.6, 5.8, -5.3), PINK)
	decor("EarRight", Vector3.new(0.35, 0.8, 0.35), CFrame.new(0.6, 5.8, -5.3), PINK)
	decor("EyeLeft", Vector3.new(0.4, 0.4, 0.4), CFrame.new(-0.92, 4.9, -6.7), EYE).Shape = Enum.PartType.Ball
	decor("EyeRight", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0.92, 4.9, -6.7), EYE).Shape = Enum.PartType.Ball

	-- Golden horn: three stacked pieces that get thinner toward the tip.
	for i = 0, 2 do
		local width = 0.5 - i * 0.13
		local horn = decor("Horn" .. (i + 1), Vector3.new(width, 0.85, width), CFrame.new(0, 5.9 + i * 0.75, -6.5 - i * 0.3) * CFrame.Angles(math.rad(-20), 0, 0), GOLD)
		horn.Material = Enum.Material.Neon
	end

	-- Rainbow mane down the back of the neck, and a rainbow tail.
	for i, color in ipairs(RAINBOW) do
		decor("Mane" .. i, Vector3.new(0.6, 0.95, 0.8), CFrame.new(0, 5.9 - (i - 1) * 0.72, -4.9 + (i - 1) * 0.34) * leanForward, color)
		decor("TailHair" .. i, Vector3.new(0.7, 0.7, 1.1), CFrame.new(0, 2.9 - (i - 1) * 0.34, 4.8 + (i - 1) * 0.75) * CFrame.Angles(math.rad(-20), 0, 0), color)
	end

	-- Billboard carried above the riders, readable from both sides of the track.
	attach("Part", "BoardPostFront", Vector3.new(0.4, 7, 0.4), CFrame.new(0, 4, -3.6), WHITE)
	attach("Part", "BoardPostBack", Vector3.new(0.4, 7, 0.4), CFrame.new(0, 4, 3.6), WHITE)
	local board = attach("Part", "Billboard", Vector3.new(0.3, 3, 12), CFrame.new(0, 9, 0), DARK)
	addText(board, "LabelRight", Enum.NormalId.Right, BILLBOARD_TEXT, YELLOW)
	addText(board, "LabelLeft", Enum.NormalId.Left, BILLBOARD_TEXT, PINK)

	cart:SetAttribute("Built", true)
	cart.Parent = coaster
end

-- ============================================================
-- Drive the cart
-- ============================================================

-- If this script is ever run again, the newest copy takes over the cart.
local driverToken = tostring(os.clock()) .. "-" .. tostring(math.random(1, 1e6))
base:SetAttribute("Driver", driverToken)

local distance = stopDistance
local waitUntil = os.clock() + STATION_SECONDS
local departedAt = os.clock()

base.CFrame = cartCFrame(distance)

local lastStatus
local function setStatus(text)
	if text ~= lastStatus then
		lastStatus = text
		statusLabel.Text = text
	end
end

local connection
connection = RunService.Heartbeat:Connect(function(dt)
	if not base.Parent or base:GetAttribute("Driver") ~= driverToken then
		connection:Disconnect()
		return
	end

	local now = os.clock()
	if waitUntil then
		if now < waitUntil then
			setStatus("BOARDING - LEAVES IN " .. math.ceil(waitUntil - now))
			return
		end
		waitUntil = nil
		departedAt = now
		setStatus("RIDE IN PROGRESS")
	end

	local sinceDeparture = now - departedAt
	local speed = MIN_SPEED + SPEED_PER_STUD * math.max(0, TOP_Y - positionAt(distance).Y)
	-- Ease out of the station.
	speed *= math.clamp(sinceDeparture / 4, 0.15, 1)

	local ahead = (stopDistance - distance) % totalLength
	local approaching = sinceDeparture > 6 and ahead < 45
	if approaching then
		-- Brake into the station.
		speed = math.min(speed, 6 + ahead * 0.5)
	end

	local step = speed * math.min(dt, 0.1)
	if approaching and ahead <= step then
		distance = stopDistance
		waitUntil = now + STATION_SECONDS
	else
		distance = (distance + step) % totalLength
	end

	base.CFrame = cartCFrame(distance)
end)

print(LOG .. string.format("Coaster complete. Track length %d studs.", math.floor(totalLength)))
