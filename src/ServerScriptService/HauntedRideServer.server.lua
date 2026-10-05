-- HauntedRideServer (PERMANENT)
-- Runs the Rumah Hantu dark ride. The server owns everything that matters:
-- who is seated, when the cart leaves, where the cart is, which scene cue
-- fires and when the ride resets. Riders never steer and no client request
-- is trusted -- boarding is a ProximityPrompt the server validates.
--
-- States: IDLE -> BOARDING -> DISPATCHING -> RIDING -> UNLOADING -> RESETTING -> IDLE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.HauntedRideConfig)

local LOG = "[HauntedRide] "

-- ============================================================
-- Wait for the builder, then collect what it made
-- ============================================================

local ride = Workspace:WaitForChild("HauntedRide", 60)
if not ride then
	warn(LOG .. "Workspace.HauntedRide never appeared. The ride is disabled.")
	return
end
do
	local waited = 0
	while not ride:GetAttribute("Built") and waited < 60 do
		waited += task.wait(0.25)
	end
	if not ride:GetAttribute("Built") then
		warn(LOG .. "The Rumah Hantu builder did not finish. The ride is disabled.")
		return
	end
end

local cart = ride.RideVehicles:FindFirstChild("HauntedCart")
local fScenes = ride.Scenes
local station = ride.Station
local dispatchSign = station:FindFirstChild("DispatchSign")
local signText = dispatchSign and dispatchSign:FindFirstChild("Text", true)
local loadGate = station.Gates:FindFirstChild("LoadGate")
local exitGate = station.Gates:FindFirstChild("ExitGate")
local safeSpot = ride.Unload:FindFirstChild("SafeSpot")

if not (cart and cart.PrimaryPart) then
	warn(LOG .. "HauntedCart is missing. The ride is disabled.")
	return
end

local seats = {}
for index = 1, Config.MAX_RIDERS do
	local seat = cart:FindFirstChild(string.format("Seat%02d", index))
	if seat and seat:IsA("Seat") then
		table.insert(seats, seat)
	end
end
if #seats == 0 then
	warn(LOG .. "The cart has no seats. The ride is disabled.")
	return
end

local unloadSpots = {}
for index = 1, #seats do
	unloadSpots[index] = ride.Unload:FindFirstChild("UnloadSpot" .. index)
end

-- Route: read the waypoint parts in name order (WP001, WP002, ...).
local waypoints = ride.Track.Waypoints:GetChildren()
table.sort(waypoints, function(a, b)
	return a.Name < b.Name
end)
local points = {}
for index, marker in ipairs(waypoints) do
	points[index] = marker.Position - Vector3.new(0, 1, 0)
end
if #points < 4 then
	warn(LOG .. "Not enough waypoints for a route. The ride is disabled.")
	return
end
local path = Config.buildPath(points)

local unloadDistance = path.Length
for index, marker in ipairs(waypoints) do
	if marker:GetAttribute("Stop") == "Unload" then
		unloadDistance = path.WaypointDistance[index]
	end
end

local function log(message)
	if Config.DEBUG then
		print(LOG .. message)
	end
end

-- ============================================================
-- Cart placement
-- ============================================================

local cartLift = Vector3.new(0, Config.CART_HEIGHT - 0.2, 0)

local function placeCart(distance)
	local position, direction = Config.pointAt(path, distance)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	position += cartLift
	cart:PivotTo(CFrame.lookAt(position, position + flat.Unit))
end

-- ============================================================
-- Show control: fade, move, lights. Every helper is safe on a missing piece.
-- ============================================================

local showToken = 0 -- bumped on reset; running cues and moves stop themselves

local function tween(instance, seconds, goal)
	if not instance then
		return
	end
	if seconds <= 0 then
		for key, value in pairs(goal) do
			instance[key] = value
		end
		return
	end
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal):Play()
end

local function eachPart(object, callback)
	if not object then
		return
	end
	if object:IsA("BasePart") then
		callback(object)
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			callback(descendant)
		end
	end
end

-- Reveal or hide a piece (parts with a Shown value, ghost lights with On).
local function fade(object, visible, seconds)
	eachPart(object, function(part)
		local shown = part:GetAttribute("Shown")
		if shown ~= nil then
			tween(part, seconds or 0.4, { Transparency = visible and shown or 1 })
		end
		local on = part:GetAttribute("On")
		if on ~= nil then
			tween(part:FindFirstChildWhichIsA("Light"), seconds or 0.4, { Brightness = visible and on or 0 })
		end
	end)
end

local function setLight(holder, brightness, seconds)
	if holder then
		tween(holder:FindFirstChildWhichIsA("Light"), seconds or 0.5, { Brightness = brightness })
	end
end

-- Move a part or model to its Home or Target pose.
local function move(object, key, seconds)
	if not object then
		return
	end
	local goal = object:GetAttribute(key)
	if typeof(goal) ~= "CFrame" then
		return
	end
	if object:IsA("BasePart") then
		tween(object, seconds, { CFrame = goal })
		return
	end
	if seconds <= 0 then
		object:PivotTo(goal)
		return
	end
	local token = showToken
	local start = object:GetPivot()
	local began = os.clock()
	task.spawn(function()
		while token == showToken do
			local alpha = math.min((os.clock() - began) / seconds, 1)
			local eased = alpha * alpha * (3 - 2 * alpha)
			object:PivotTo(start:Lerp(goal, eased))
			if alpha >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local function find(sceneIndex, name)
	local folder = fScenes:FindFirstChild(Config.SCENES[sceneIndex])
	return folder and folder:FindFirstChild(name)
end

local function setEmitter(holder, rate)
	local emitter = holder and holder:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter.Rate = rate
	end
end

-- Sounds: only created for IDs that have actually been filled in.
local sounds = {}
for name, id in pairs(Config.SOUNDS) do
	if type(id) == "number" and id > 0 then
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = "rbxassetid://" .. id
		sound.Volume = Config.SOUND_VOLUME
		sound.RollOffMaxDistance = 60
		sound.Looped = (name == "Ambience")
		sound.Parent = cart.PrimaryPart
		sounds[name] = sound
	end
end
local function play(name)
	local sound = sounds[name]
	if sound then
		sound:Play()
	end
end

-- Put every show piece back exactly as the builder left it.
local function resetScenes()
	showToken += 1
	for _, object in ipairs(fScenes:GetDescendants()) do
		if object:IsA("BasePart") then
			if object:GetAttribute("Shown") ~= nil then
				object.Transparency = 1
			end
			local light = object:FindFirstChildWhichIsA("Light")
			if light then
				local base = object:GetAttribute("Base")
				if object:GetAttribute("On") ~= nil then
					light.Brightness = 0
				elseif base ~= nil then
					light.Brightness = base
				end
			end
			if object:GetAttribute("Rate") ~= nil then
				setEmitter(object, 0)
			end
			local home = object:GetAttribute("Home")
			if typeof(home) == "CFrame" then
				object.CFrame = home
			end
		elseif object:IsA("Model") then
			local home = object:GetAttribute("Home")
			if typeof(home) == "CFrame" then
				object:PivotTo(home)
			end
		end
	end
	local glass = find(4, "ApparitionPanel")
	if glass then
		glass.Transparency = glass:GetAttribute("Base") or 0.04
	end
	local escape = find(7, "EscapeSign")
	local escapeText = escape and escape:FindFirstChild("Text", true)
	if escapeText then
		escapeText.TextTransparency = 1
	end
	for index = 1, 2 do
		setEmitter(find(6, "Fog" .. index), 2)
	end
	for _, sound in pairs(sounds) do
		sound:Stop()
	end
end

-- ============================================================
-- Scene cues. Each runs on its own thread and stops if the ride resets.
-- ============================================================

local cues = {}

local function runCue(name)
	local cue = cues[name]
	if not cue then
		return
	end
	log("cue " .. name)
	local token = showToken
	-- pause(seconds) returns false if the ride was reset meanwhile.
	local function pause(seconds)
		task.wait(seconds)
		return token == showToken
	end
	task.spawn(function()
		local ok, err = pcall(cue, pause)
		if not ok then
			warn(LOG .. "Scene cue " .. name .. " failed: " .. tostring(err))
		end
	end)
end

-- Scene 1: lights dim, far-off lightning at the boarded window, doors shut behind.
function cues.Entrance(pause)
	play("DoorCreak")
	setLight(find(1, "HallLampA"), 0.25, 2)
	setLight(find(1, "HallLampB"), 0.25, 2)
	if not pause(1.6) then return end
	local window = find(1, "LightningWindow")
	play("Thunder")
	setLight(window, 2.4, 0.15)
	if not pause(0.5) then return end
	setLight(window, 0, 0.6)
	if not pause(1.6) then return end
	setLight(window, 1.4, 0.2)
	if not pause(0.6) then return end
	setLight(window, 0, 0.9)
	if not pause(1.4) then return end
	move(find(1, "EntranceDoorLeft"), "Home", 1.2)
	move(find(1, "EntranceDoorRight"), "Home", 1.2)
end

-- Scene 2: lamps gutter slowly, a shadow walks the wall, the portrait turns to look.
function cues.Corridor(pause)
	play("Wind")
	local shadow = find(2, "ShadowFigure")
	fade(shadow, true, 0.8)
	move(shadow, "Target", 5)
	local levels = { 0.3, 0.7, 0.15, 0.6, 0.2, 0.8 }
	for step = 1, #levels do
		for index = 1, 3 do
			-- Each lamp follows the pattern one step apart: slow and uneven, never a strobe.
			setLight(find(2, "CorridorLamp" .. index), levels[(step + index - 2) % #levels + 1], 0.45)
		end
		if step == 3 then
			move(find(2, "TiltingPortrait"), "Target", 0.8)
			fade(find(2, "PortraitEye1"), true, 0.6)
			fade(find(2, "PortraitEye2"), true, 0.6)
		end
		if not pause(0.6) then return end
	end
	for index = 1, 3 do
		setLight(find(2, "CorridorLamp" .. index), 0.35, 0.8)
	end
	if not pause(1.4) then return end
	fade(shadow, false, 0.8)
end

-- Scene 2 ending: a small ghost leans out, and the dining-room doors open.
function cues.CorridorEnd(pause)
	local pop = find(2, "PopGhost")
	play("GhostWhisper")
	fade(pop, true, 0.25)
	move(pop, "Target", 0.35)
	move(find(3, "DiningDoorLeft"), "Target", 0.9)
	move(find(3, "DiningDoorRight"), "Target", 0.9)
	if not pause(2.2) then return end
	fade(pop, false, 0.5)
	if not pause(0.6) then return end
	move(pop, "Home", 0)
end

-- Scene 3: a chair moves, the chandelier sways, the light dies -- and when it
-- comes back there is one more guest at the table.
function cues.Dining(pause)
	local chandelier = find(3, "Chandelier")
	local light = find(3, "ChandelierLight")
	local guest = find(3, "DiningGhost")
	if not pause(1) then return end
	move(find(3, "SlidingChair"), "Target", 1.2)
	if not pause(1.2) then return end
	move(chandelier, "Target", 1.1)
	if not pause(1.1) then return end
	move(chandelier, "Home", 1.1)
	if not pause(1.5) then return end
	move(find(3, "DiningDoorLeft"), "Home", 1)
	move(find(3, "DiningDoorRight"), "Home", 1)
	if not pause(1) then return end
	play("Heartbeat")
	setLight(light, 0, 0.25)
	if not pause(0.9) then return end
	fade(guest, true, 0.2)
	if not pause(0.5) then return end
	setLight(light, 0.9, 0.3)
	if not pause(1.8) then return end
	fade(guest, false, 0.9)
	if not pause(2) then return end
	move(find(3, "SlidingChair"), "Home", 1.5)
end

-- Scene 4: eyes in the dark glass, then the centre cabinet clears.
function cues.Mirrors(pause)
	if not pause(2) then return end
	fade(find(4, "MirrorEyeA1"), true, 0.5)
	fade(find(4, "MirrorEyeA2"), true, 0.5)
	if not pause(2.5) then return end
	fade(find(4, "MirrorEyeA1"), false, 0.5)
	fade(find(4, "MirrorEyeA2"), false, 0.5)
	fade(find(4, "MirrorEyeB1"), true, 0.5)
	fade(find(4, "MirrorEyeB2"), true, 0.5)
	if not pause(2.6) then return end
	local glass = find(4, "ApparitionPanel")
	local figure = find(4, "MirrorGhost")
	play("GhostWhisper")
	if glass then
		tween(glass, 0.8, { Transparency = glass:GetAttribute("Reveal") or 0.8 })
	end
	fade(figure, true, 0.8)
	if not pause(2.6) then return end
	fade(figure, false, 0.6)
	if glass then
		tween(glass, 0.8, { Transparency = glass:GetAttribute("Base") or 0.04 })
	end
	fade(find(4, "MirrorEyeB1"), false, 0.5)
	fade(find(4, "MirrorEyeB2"), false, 0.5)
end

function cues.GhostRoomDoor(_pause)
	play("DoorCreak")
	move(find(5, "GhostRoomDoorLeft"), "Target", 0.8)
	move(find(5, "GhostRoomDoorRight"), "Target", 0.8)
end

-- Scene 5: cold light rises, mist gathers, the ghost drifts up to the cart and is gone.
function cues.GhostRoom(pause)
	local light = find(5, "GhostRoomLight")
	local mist = find(5, "GhostMist")
	local spirit = find(5, "RoomGhost")
	setLight(light, 1, 3)
	setEmitter(mist, mist and mist:GetAttribute("Rate") or 5)
	if not pause(5) then return end
	move(find(5, "GhostRoomDoorLeft"), "Home", 1)
	move(find(5, "GhostRoomDoorRight"), "Home", 1)
	if not pause(2.5) then return end
	play("GhostWhisper")
	fade(spirit, true, 1.2)
	if not pause(1.5) then return end
	move(spirit, "Target", 2.4)
	if not pause(2.6) then return end
	fade(spirit, false, 0.3)
	setLight(light, 0.15, 0.4)
	setEmitter(mist, 0)
	if not pause(1) then return end
	move(spirit, "Home", 0)
end

-- Scene 6: thicker fog under the moon.
function cues.Graveyard(pause)
	play("Wind")
	for index = 1, 2 do
		setEmitter(find(6, "Fog" .. index), 5)
	end
	if not pause(9) then return end
	for index = 1, 2 do
		setEmitter(find(6, "Fog" .. index), 2)
	end
end

-- Scene 6 scare: something rises from behind the nearest grave.
function cues.GraveRiser(pause)
	local riser = find(6, "GraveRiser")
	play("Impact")
	fade(riser, true, 0.2)
	move(riser, "Target", 0.35)
	if not pause(1.6) then return end
	move(riser, "Home", 0.9)
	fade(riser, false, 0.7)
end

-- Scene 7: the way out seems to be right there, and the lights come up...
function cues.Finale(_pause)
	setLight(find(7, "FinaleLampA"), 1.6, 3)
	setLight(find(7, "FinaleLampB"), 1.6, 3)
end

-- ...then a blackout, a very large ghost, and the doors burst open.
function cues.Blackout(pause)
	if not pause(0.6) then return end
	setLight(find(7, "FinaleLampA"), 0, 0.15)
	setLight(find(7, "FinaleLampB"), 0, 0.15)
	if not pause(0.7) then return end
	local big = find(7, "BigGhost")
	play("FinalScare")
	fade(big, true, 0.25)
	move(big, "Target", 1.3)
	if not pause(1.9) then return end
	fade(big, false, 0.3)
	if not pause(0.5) then return end
	play("Impact")
	move(find(7, "ExitDoorLeft"), "Target", 0.35)
	move(find(7, "ExitDoorRight"), "Target", 0.35)
	setLight(find(7, "FinaleLampA"), 0.4, 0.4)
	if not pause(0.5) then return end
	move(big, "Home", 0)
end

function cues.Escape(pause)
	local escape = find(7, "EscapeSign")
	local escapeText = escape and escape:FindFirstChild("Text", true)
	tween(escapeText, 0.4, { TextTransparency = 0 })
	if not pause(4) then return end
	move(find(7, "ExitDoorLeft"), "Home", 1)
	move(find(7, "ExitDoorRight"), "Home", 1)
end

-- ============================================================
-- Riders
-- ============================================================

local state = "IDLE"
local riders = {} -- [seat] = player
local approved = {} -- [player] = seat the server agreed to

local function riderCount()
	local count = 0
	for _, seat in ipairs(seats) do
		if riders[seat] then
			count += 1
		end
	end
	return count
end

local function boardingOpen()
	return state == "IDLE" or state == "BOARDING"
end

local function updatePrompts()
	for _, seat in ipairs(seats) do
		local prompt = seat:FindFirstChild("BoardPrompt")
		if prompt then
			prompt.Enabled = boardingOpen() and seat.Occupant == nil
		end
	end
end

local function setSign(text)
	if signText then
		signText.Text = text
	end
end

local function setState(newState)
	state = newState
	ride:SetAttribute("State", newState)
	updatePrompts()
	log("state " .. newState)
end

local insideMin = Config.toWorld(-6, -2, -2)
local insideMax = Config.toWorld(59, Config.WALL_HEIGHT + 1, 32)

-- A rider who leaves the cart mid-ride is walked out, never left in the dark.
local function rescue(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and safeSpot) then
		return
	end
	local p = root.Position
	if p.X > insideMin.X and p.X < insideMax.X and p.Z > insideMin.Z and p.Z < insideMax.Z and p.Y < insideMax.Y then
		character:PivotTo(safeSpot.CFrame + Vector3.new(0, 3.5, 0))
	end
end

for _, seat in ipairs(seats) do
	local prompt = seat:FindFirstChild("BoardPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			-- Every check is repeated here on the server.
			if not boardingOpen() or seat.Occupant ~= nil or riderCount() >= Config.MAX_RIDERS then
				return
			end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (humanoid and root) or humanoid.Health <= 0 or humanoid.SeatPart ~= nil then
				return
			end
			if (root.Position - seat.Position).Magnitude > Config.BOARD_DISTANCE then
				return
			end
			approved[player] = seat
			seat:Sit(humanoid)
		end)
	end

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if occupant then
			local player = Players:GetPlayerFromCharacter(occupant.Parent)
			if not player or approved[player] ~= seat or not boardingOpen() then
				-- Not a boarding the server agreed to: stand them straight back up.
				occupant.Sit = false
				return
			end
			riders[seat] = player
		else
			local previous = riders[seat]
			riders[seat] = nil
			if previous then
				approved[previous] = nil
				if state == "DISPATCHING" or state == "RIDING" then
					task.delay(1, function()
						if previous.Parent then
							rescue(previous)
						end
					end)
				end
			end
		end
		updatePrompts()
	end)
end

Players.PlayerRemoving:Connect(function(player)
	approved[player] = nil
end)

local function unloadRiders()
	for index, seat in ipairs(seats) do
		local player = riders[seat]
		local occupant = seat.Occupant
		if occupant then
			occupant.Sit = false
		end
		if player then
			local spot = unloadSpots[index]
			task.delay(0.35, function()
				local character = player.Character
				if character and character:FindFirstChild("HumanoidRootPart") and spot then
					character:PivotTo(spot.CFrame + Vector3.new(0, 3.5, 0))
				end
			end)
		end
	end
end

-- ============================================================
-- Movement along the route
-- ============================================================

local function travel(fromDistance, toDistance, withCues)
	local distance = fromDistance
	local speed = 0
	local target = withCues and Config.RIDE_SPEED or Config.RETURN_SPEED
	local nextIndex = #waypoints + 1
	for index = 1, #waypoints do
		if path.WaypointDistance[index] >= fromDistance then
			nextIndex = index
			break
		end
	end

	while distance < toDistance do
		local dt = math.min(RunService.Heartbeat:Wait(), 0.1)
		local change = math.clamp(target - speed, -Config.ACCELERATION * dt, Config.ACCELERATION * dt)
		speed += change
		distance = math.min(distance + speed * dt, toDistance)

		while nextIndex <= #waypoints and path.WaypointDistance[nextIndex] <= distance do
			local marker = waypoints[nextIndex]
			nextIndex += 1
			if withCues then
				local newSpeed = marker:GetAttribute("Speed")
				if newSpeed then
					target = newSpeed
				end
				local cue = marker:GetAttribute("SceneId")
				if cue then
					runCue(cue)
				end
				local hold = marker:GetAttribute("Pause")
				if hold then
					placeCart(distance)
					speed = 0
					task.wait(hold)
				end
			end
		end
		placeCart(distance)
	end
end

-- ============================================================
-- The ride loop
-- ============================================================

local function cycle()
	setState("IDLE")
	setSign("WAITING FOR RIDERS")
	move(loadGate, "Home", 0.8)
	move(exitGate, "Home", 0.8)
	while riderCount() < Config.MIN_RIDERS do
		task.wait(0.2)
	end

	setState("BOARDING")
	local remaining = Config.BOARDING_COUNTDOWN
	while remaining > 0 do
		local count = riderCount()
		if count == 0 then
			return -- everyone got off again: back to IDLE
		end
		if count >= #seats and remaining > Config.FULL_CART_DELAY then
			remaining = Config.FULL_CART_DELAY
		end
		setSign("DEPARTURE IN " .. math.ceil(remaining))
		remaining -= task.wait(0.2)
	end
	if riderCount() == 0 then
		return
	end

	setState("DISPATCHING") -- boarding prompts are off from here
	setSign("BOARDING CLOSED")
	move(loadGate, "Target", 0.8)
	move(find(1, "EntranceDoorLeft"), "Target", 1.6)
	move(find(1, "EntranceDoorRight"), "Target", 1.6)
	play("Ambience")
	task.wait(Config.DISPATCH_DELAY)

	setState("RIDING")
	setSign("RIDE IN PROGRESS")
	travel(0, unloadDistance, true)

	setState("UNLOADING")
	setSign("PLEASE EXIT")
	move(exitGate, "Target", 0.8)
	unloadRiders()
	task.wait(Config.UNLOAD_SECONDS)

	setState("RESETTING")
	setSign("RETURNING")
	resetScenes()
	task.wait(Config.RESET_DELAY)
	travel(unloadDistance, path.Length, false)
	placeCart(0)
end

resetScenes()
placeCart(0)
updatePrompts()

print(LOG .. "Ride ready: " .. #seats .. " seats, " .. #waypoints .. " waypoints, " .. math.floor(unloadDistance) .. " studs to unload.")

while true do
	local ok, err = pcall(cycle)
	if not ok then
		-- Fail safe: let everyone off, tidy the scenes, send the cart home.
		warn(LOG .. "Ride cycle error: " .. tostring(err))
		pcall(function()
			state = "UNLOADING"
			unloadRiders()
			resetScenes()
			placeCart(0)
		end)
		task.wait(3)
	end
end
