-- PlaygroundRides (PERMANENT)
-- Two rides for the playground, under Workspace.Environment.Playground.Rides:
--   1. Mega Slide: a tower at the playground's south-west corner with a long
--      chute that runs once around the outside of the playground, mixing
--      open stretches with closed, lit rainbow tunnels. Riders sit on a sled
--      at the top; it runs down the chute, then returns to the top by itself.
--   2. Swing set: two swings on the east side that really swing. A swing
--      barely moves when empty and builds up to a big arc when someone sits.
-- Both rides move an anchored seat from the server, which carries the seated
-- player along. Idempotent: static parts are found by name or created, and
-- the moving parts are reused if they already exist. Plain parts only.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LOG = "[PlaygroundRides] "

local FLOOR_TOP = 1.5 -- top of the playground floor
local GROUND_TOP = 1

local MAT_PLASTIC = Enum.Material.SmoothPlastic
local RED = Color3.fromRGB(255, 90, 90)
local ORANGE = Color3.fromRGB(255, 160, 60)
local YELLOW = Color3.fromRGB(255, 220, 80)
local GREEN = Color3.fromRGB(90, 210, 120)
local BLUE = Color3.fromRGB(80, 160, 255)
local PURPLE = Color3.fromRGB(180, 110, 255)
local PINK = Color3.fromRGB(255, 130, 200)
local WHITE = Color3.fromRGB(240, 240, 245)
local GREY = Color3.fromRGB(170, 175, 185)
local DARK = Color3.fromRGB(10, 10, 14)
local RAINBOW = { RED, ORANGE, YELLOW, GREEN, BLUE, PURPLE }

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

local function block(parent, name, size, cframe, color, canCollide, className)
	local p = make(parent, className or "Part", name)
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = MAT_PLASTIC
	p.CanCollide = canCollide ~= false
	p.CanTouch = false
	return p
end

local function addText(part, face, text, textColor)
	local gui = make(part, "SurfaceGui", "Label")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local label = make(gui, "TextLabel", "Text")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	return label
end

local environment = ensureFolder(Workspace, "Environment")
local playground = ensureFolder(environment, "Playground")
local rides = ensureFolder(playground, "Rides")

-- If this script is ever run again, the newest copy takes over the rides.
local token = tostring(os.clock()) .. "-" .. tostring(math.random(1, 1000000))
rides:SetAttribute("Runner", token)

-- ============================================================
-- 1. MEGA SLIDE
-- ============================================================

local fSlide = ensureFolder(rides, "MegaSlide")
local fChute = ensureFolder(fSlide, "Chute")
local fTower = ensureFolder(fSlide, "Tower")

-- The slide runs once around the outside of the playground. From a tower at
-- the playground's south-west corner it heads north along the west side,
-- east along the north side, south along the east side, then back west along
-- the south side to finish beside the tower. Open stretches (floor and low
-- rails, clear view) alternate with closed, lit rainbow tunnels, and the
-- height falls steadily the whole way.
local SLIDE_TOP_Y = 56
local SLIDE_END_Y = 2.6 -- chute floor height at the end of the run-out
local SLIDE_SUBDIVISIONS = 10
local SLIDE_CRUISE_SPEED = 40
local SLIDE_START_DELAY = 3 -- seconds between sitting down and setting off
local SLIDE_END_PAUSE = 2.5 -- seconds at the bottom before the sled goes back up
local TUBE_INNER_HEIGHT = 7
local TUBE_HALF_WIDTH = 2.2

-- Each entry: X, chute floor height, Z, and whether the stretch that starts
-- there is "open" or a "tube".
local SLIDE_POINTS = {
	-- Lead-in beside the tower deck, then the west side: open, high above
	-- the playground entrance.
	{ 57, 56, 33.5, "open" },
	{ 57, 56, 24, "open" },
	{ 57, 53, 8, "open" },
	{ 57, 50, -8, "open" },
	{ 58, 47, -22, "open" },
	-- North side: a winding tunnel.
	{ 64, 45, -31, "tube" },
	{ 76, 43, -38, "tube" },
	{ 88, 41, -29, "tube" },
	{ 100, 39, -38, "tube" },
	{ 112, 37, -30, "tube" },
	-- East side: open again.
	{ 120, 34, -22, "open" },
	{ 120.5, 30, -8, "open" },
	{ 120, 25, 8, "open" },
	{ 120, 20, 22, "open" },
	-- South side: a second winding tunnel, down toward the tower.
	{ 115, 17, 30, "tube" },
	{ 104, 15, 32, "tube" },
	{ 92, 13, 42, "tube" },
	{ 80, 11, 31, "tube" },
	{ 72, 8, 42, "tube" },
	-- Open run-out, turning north to stop at the playground's corner.
	{ 66, 5, 36, "open" },
	{ 66, 3, 31, "open" },
	{ 66, 2.6, 27, "open" },
}

local function slidePoint(index)
	local entry = SLIDE_POINTS[index]
	return Vector3.new(entry[1], entry[2], entry[3])
end

local function spline(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

-- The slide is an open path, so extend one invisible point past each end.
local slideCount = #SLIDE_POINTS
local function slideControl(index)
	if index < 1 then
		return slidePoint(1) * 2 - slidePoint(2)
	elseif index > slideCount then
		return slidePoint(slideCount) * 2 - slidePoint(slideCount - 1)
	end
	return slidePoint(index)
end

-- slideKinds[i] says whether piece i (from sample i to sample i + 1) is open
-- or part of a tunnel.
local slidePath = {}
local slideKinds = {}
local previousY = SLIDE_TOP_Y
for stretch = 1, slideCount - 1 do
	for k = 0, SLIDE_SUBDIVISIONS - 1 do
		local point = spline(slideControl(stretch - 1), slideControl(stretch), slideControl(stretch + 1), slideControl(stretch + 2), k / SLIDE_SUBDIVISIONS)
		-- Always level or downhill, and never below the run-out height.
		local y = math.clamp(point.Y, SLIDE_END_Y, previousY)
		previousY = y
		table.insert(slidePath, Vector3.new(point.X, y, point.Z))
		table.insert(slideKinds, SLIDE_POINTS[stretch][4])
	end
end
table.insert(slidePath, slidePoint(slideCount))
table.insert(slideKinds, "open")

local slideLengths = {}
local slideCumulative = { 0 }
for i = 1, #slidePath - 1 do
	slideLengths[i] = (slidePath[i + 1] - slidePath[i]).Magnitude
	slideCumulative[i + 1] = slideCumulative[i] + slideLengths[i]
end
local slideTotal = slideCumulative[#slidePath]
-- The sled waits a little way along the lead-in, just off the tower deck.
local SLED_START = 3

local function slidePositionAt(distance)
	distance = math.clamp(distance, 0, slideTotal)
	local low, high = 1, #slidePath - 1
	while low < high do
		local mid = math.floor((low + high + 1) / 2)
		if slideCumulative[mid] <= distance then
			low = mid
		else
			high = mid - 1
		end
	end
	local t = math.clamp((distance - slideCumulative[low]) / slideLengths[low], 0, 1)
	return slidePath[low]:Lerp(slidePath[low + 1], t)
end

local function sledCFrame(distance)
	local lift = Vector3.new(0, 0.45, 0)
	local here = slidePositionAt(distance)
	local ahead = slidePositionAt(distance + 3)
	if (ahead - here).Magnitude < 0.05 then
		-- At the very end: keep pointing the way it arrived.
		here = slidePositionAt(distance - 3)
		ahead = slidePositionAt(distance)
		return CFrame.lookAt(ahead + lift, ahead + lift + (ahead - here))
	end
	return CFrame.lookAt(here + lift, ahead + lift)
end

-- Chute pieces. Open pieces are a floor with low side rails. Tube pieces add
-- see-through rainbow walls and a roof, with a glowing strip along the
-- ceiling and a small coloured light every few pieces. The walls and roof do
-- not collide, so they never trap a player or block the camera.
local TUBE_TRANSPARENCY = 0.35
for i = 1, #slidePath - 1 do
	local a, b = slidePath[i], slidePath[i + 1]
	local direction = (b - a).Unit
	local mid = (a + b) / 2
	local length = slideLengths[i] + 0.6
	local along = CFrame.lookAt(mid, mid + direction)
	-- The rainbow runs along the slide and repeats every 30 pieces.
	local hue = ((i - 1) % 30) / 30
	local color = Color3.fromHSV(hue, 0.7, 1)

	block(fChute, "Floor" .. i, Vector3.new(TUBE_HALF_WIDTH * 2 + 0.4, 0.4, length), along * CFrame.new(0, -0.2, 0), color)

	if slideKinds[i] == "tube" then
		local wallY = TUBE_INNER_HEIGHT / 2
		local left = block(fChute, "WallLeft" .. i, Vector3.new(0.3, TUBE_INNER_HEIGHT, length), along * CFrame.new(-TUBE_HALF_WIDTH - 0.05, wallY, 0), color, false)
		local right = block(fChute, "WallRight" .. i, Vector3.new(0.3, TUBE_INNER_HEIGHT, length), along * CFrame.new(TUBE_HALF_WIDTH + 0.05, wallY, 0), color, false)
		local roof = block(fChute, "Roof" .. i, Vector3.new(TUBE_HALF_WIDTH * 2 + 0.4, 0.3, length), along * CFrame.new(0, TUBE_INNER_HEIGHT + 0.15, 0), color, false)
		left.Transparency = TUBE_TRANSPARENCY
		right.Transparency = TUBE_TRANSPARENCY
		roof.Transparency = TUBE_TRANSPARENCY

		if i % 2 == 0 then
			local strip = block(fChute, "Light" .. i, Vector3.new(0.5, 0.15, length), along * CFrame.new(0, TUBE_INNER_HEIGHT - 0.1, 0), Color3.fromHSV(hue, 0.25, 1), false)
			strip.Material = Enum.Material.Neon
			if i % 6 == 0 then
				local light = make(strip, "PointLight", "Glow")
				light.Color = Color3.fromHSV(hue, 0.5, 1)
				light.Range = 14
				light.Brightness = 0.8
			end
		end
	else
		block(fChute, "RailLeft" .. i, Vector3.new(0.3, 1, length), along * CFrame.new(-TUBE_HALF_WIDTH - 0.05, 0.5, 0), WHITE, false)
		block(fChute, "RailRight" .. i, Vector3.new(0.3, 1, length), along * CFrame.new(TUBE_HALF_WIDTH + 0.05, 0.5, 0), WHITE, false)
	end
end
-- End stop at the bottom of the run-out.
do
	local last = slidePath[#slidePath]
	local direction = (last - slidePath[#slidePath - 1]).Unit
	local stopAt = last + direction * 2.8 + Vector3.new(0, 0.7, 0)
	block(fChute, "EndStop", Vector3.new(TUBE_HALF_WIDTH * 2 + 0.8, 1.8, 0.4), CFrame.lookAt(stopAt, stopAt + direction), WHITE)
end

-- A support under the chute at each bend (not under the tower end or where
-- the chute is close to the ground).
for index = 3, slideCount - 2 do
	local top = slidePoint(index)
	local height = top.Y - 0.5 - GROUND_TOP
	if height >= 4 then
		block(fChute, "Support" .. index, Vector3.new(1, height, 1), CFrame.new(top.X, GROUND_TOP + height / 2, top.Z), GREY)
	end
end

-- Tower at the playground's south-west corner: a deck behind the start of the
-- chute, on four legs, with a ladder, rails and a sign.
local slideStart = slidePoint(1)
local DECK_X = slideStart.X
local DECK_Z = slideStart.Z + 2.5
block(fTower, "Deck", Vector3.new(7, 1, 5), CFrame.new(DECK_X, SLIDE_TOP_Y - 0.5, DECK_Z), BLUE)
for index, corner in ipairs({ { -3, -2 }, { 3, -2 }, { -3, 2 }, { 3, 2 } }) do
	local height = SLIDE_TOP_Y - 1 - GROUND_TOP
	block(fTower, "Leg" .. index, Vector3.new(1, height, 1), CFrame.new(DECK_X + corner[1], GROUND_TOP + height / 2, DECK_Z + corner[2]), RAINBOW[index])
end
-- Climbable ladder on the west side, from the ground to just above the deck.
do
	local height = SLIDE_TOP_Y + 2 - GROUND_TOP
	block(fTower, "Ladder", Vector3.new(2, height, 2), CFrame.new(DECK_X - 4.5, GROUND_TOP + height / 2, DECK_Z), ORANGE, true, "TrussPart")
end
-- Rails on the south and east sides; the west is open for the ladder and the
-- north for the sled.
block(fTower, "RailSouth", Vector3.new(7, 3, 0.4), CFrame.new(DECK_X, SLIDE_TOP_Y + 1.5, DECK_Z + 2.3), YELLOW)
block(fTower, "RailEast", Vector3.new(0.4, 3, 5), CFrame.new(DECK_X + 3.3, SLIDE_TOP_Y + 1.5, DECK_Z), YELLOW)

-- Name sign on the east rail, read from the playground (+X side).
local slideSignPosition = Vector3.new(DECK_X + 3.3, SLIDE_TOP_Y + 4.6, DECK_Z)
local slideSign = block(fTower, "Sign", Vector3.new(8, 2.4, 0.3), CFrame.lookAt(slideSignPosition, slideSignPosition + Vector3.xAxis), DARK, false)
addText(slideSign, Enum.NormalId.Front, "MEGA SLIDE", YELLOW)
-- Small board on the south rail, facing riders on the deck (-Z side).
local slideStatusBoard = block(fTower, "StatusBoard", Vector3.new(4, 1.6, 0.3), CFrame.new(DECK_X, SLIDE_TOP_Y + 4.2, DECK_Z + 2.3), DARK, false)
local slideStatus = addText(slideStatusBoard, Enum.NormalId.Front, "SIT TO START", GREEN)

-- Sled: anchored base with two seats welded to it.
local sled = fSlide:FindFirstChild("Sled")
local sledBase
if sled and sled:IsA("Model") and sled:GetAttribute("Built") and sled:FindFirstChild("Base") then
	sledBase = sled.Base
else
	sled = Instance.new("Model")
	sled.Name = "Sled"

	sledBase = Instance.new("Part")
	sledBase.Name = "Base"
	sledBase.Size = Vector3.new(3.4, 0.5, 5)
	sledBase.Color = PINK
	sledBase.Material = MAT_PLASTIC
	sledBase.Anchored = true
	sledBase.CFrame = sledCFrame(SLED_START)
	sledBase.Parent = sled
	sled.PrimaryPart = sledBase

	local function attach(className, name, size, offset, color)
		local p = Instance.new(className)
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = MAT_PLASTIC
		p.Anchored = false
		p.Massless = true
		p.CFrame = sledBase.CFrame * offset
		p.Parent = sled
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = sledBase
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	attach("Seat", "SeatFront", Vector3.new(2, 0.4, 2), CFrame.new(0, 0.45, -1.2), YELLOW)
	attach("Seat", "SeatBack", Vector3.new(2, 0.4, 2), CFrame.new(0, 0.45, 1.2), YELLOW)
	attach("Part", "Nose", Vector3.new(3.4, 1.2, 0.4), CFrame.new(0, 0.6, -2.7), PURPLE)

	sled:SetAttribute("Built", true)
	sled.Parent = fSlide
end

local sledSeats = {}
for _, child in ipairs(sled:GetChildren()) do
	if child:IsA("Seat") then
		table.insert(sledSeats, child)
	end
end

local function sledOccupied()
	for _, seat in ipairs(sledSeats) do
		if seat.Occupant then
			return true
		end
	end
	return false
end

local function ejectRiders()
	for _, seat in ipairs(sledSeats) do
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end
end

local sledState = "waiting" -- waiting, countdown, running, ended
local sledTimer = 0
local sledDistance = SLED_START
sledBase.CFrame = sledCFrame(SLED_START)

local lastSlideStatus
local function setSlideStatus(text)
	if text ~= lastSlideStatus then
		lastSlideStatus = text
		slideStatus.Text = text
	end
end

local function stepSled(dt, now)
	if sledState == "waiting" then
		setSlideStatus("SIT TO START")
		if sledOccupied() then
			sledState = "countdown"
			sledTimer = now + SLIDE_START_DELAY
		end
	elseif sledState == "countdown" then
		if not sledOccupied() then
			sledState = "waiting"
		elseif now >= sledTimer then
			sledState = "running"
			setSlideStatus("GO!")
		else
			setSlideStatus("GO IN " .. math.ceil(sledTimer - now))
		end
	elseif sledState == "running" then
		-- Pick up speed over the first stretch, then hold a steady pace.
		local speed = math.min(SLIDE_CRUISE_SPEED, 10 + (sledDistance - SLED_START) * 0.6)
		-- Brake on the flat run-out at the bottom.
		local remaining = slideTotal - sledDistance
		if remaining < 14 then
			speed = math.min(speed, 6 + remaining * 4)
		end
		sledDistance = math.min(sledDistance + speed * dt, slideTotal)
		sledBase.CFrame = sledCFrame(sledDistance)
		if sledDistance >= slideTotal then
			sledState = "ended"
			sledTimer = now + SLIDE_END_PAUSE
		end
	elseif sledState == "ended" then
		if now >= sledTimer then
			-- Let go of anyone still seated, then go back to the top.
			ejectRiders()
			sledDistance = SLED_START
			sledBase.CFrame = sledCFrame(SLED_START)
			sledState = "waiting"
		end
	end
end

-- ============================================================
-- 2. SWING SET
-- ============================================================

local fSwings = ensureFolder(rides, "SwingSet")

local SWING_X = 112
local SWING_ZS = { -15, -9 }
local SWING_PIVOT_Y = FLOOR_TOP + 11
local SWING_LENGTH = 8.5
local SWING_IDLE = math.rad(6) -- how far an empty swing drifts
local SWING_FULL = math.rad(48) -- how far a ridden swing goes
local SWING_RATE = 1.95 -- radians per second; one full swing takes about 3.2 s

-- Frame: a bar along Z on two posts.
block(fSwings, "PostNorth", Vector3.new(1, 11.5, 1), CFrame.new(SWING_X, FLOOR_TOP + 5.75, -19.5), GREEN)
block(fSwings, "PostSouth", Vector3.new(1, 11.5, 1), CFrame.new(SWING_X, FLOOR_TOP + 5.75, -4.5), GREEN)
block(fSwings, "Bar", Vector3.new(1, 1, 16), CFrame.new(SWING_X, SWING_PIVOT_Y + 0.5, -12), GREEN)

local swings = {}
for index, z in ipairs(SWING_ZS) do
	local seat = make(fSwings, "Seat", "Swing" .. index)
	seat.Size = Vector3.new(3, 0.4, 2)
	seat.Anchored = true
	seat.Color = (index == 1) and PINK or BLUE
	seat.Material = MAT_PLASTIC
	local chainA = block(fSwings, "Chain" .. index .. "A", Vector3.new(0.15, SWING_LENGTH, 0.15), CFrame.new(), WHITE, false)
	local chainB = block(fSwings, "Chain" .. index .. "B", Vector3.new(0.15, SWING_LENGTH, 0.15), CFrame.new(), WHITE, false)
	swings[index] = {
		seat = seat,
		chainA = chainA,
		chainB = chainB,
		pivot = CFrame.new(SWING_X, SWING_PIVOT_Y, z),
		amplitude = SWING_IDLE,
		phase = (index - 1) * 1.3,
	}
end

-- The seat is turned so a rider faces the middle of the playground (-X).
local SEAT_TURN = CFrame.Angles(0, math.rad(90), 0)

local function stepSwing(swing, dt)
	local target = swing.seat.Occupant and SWING_FULL or SWING_IDLE
	-- Build up and die down gradually.
	swing.amplitude += (target - swing.amplitude) * math.min(1, dt * 0.45)
	swing.phase += dt * SWING_RATE
	local arm = swing.pivot * CFrame.Angles(0, 0, math.sin(swing.phase) * swing.amplitude)
	swing.seat.CFrame = arm * CFrame.new(0, -SWING_LENGTH, 0) * SEAT_TURN
	swing.chainA.CFrame = arm * CFrame.new(0, -SWING_LENGTH / 2, -1.3)
	swing.chainB.CFrame = arm * CFrame.new(0, -SWING_LENGTH / 2, 1.3)
end

for _, swing in ipairs(swings) do
	stepSwing(swing, 0)
end

-- ============================================================
-- Run both rides
-- ============================================================

local connection
connection = RunService.Heartbeat:Connect(function(dt)
	if not rides.Parent or rides:GetAttribute("Runner") ~= token then
		connection:Disconnect()
		return
	end
	dt = math.min(dt, 0.1)
	stepSled(dt, os.clock())
	for _, swing in ipairs(swings) do
		stepSwing(swing, dt)
	end
end)

print(LOG .. string.format("Playground rides complete. Mega slide is %d studs long.", math.floor(slideTotal)))
