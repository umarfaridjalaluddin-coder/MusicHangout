-- HauntedRideConfig (PERMANENT)
-- Tuning for the Rumah Hantu dark ride. The builder, the ride server and the
-- small lighting client all read from here.
--
-- COORDINATES
-- The attraction is laid out in its own "house space": u = studs east of the
-- house's west scene wall, v = studs north of its south wall, y = studs above
-- the ground. ORIGIN is where (u = 0, y = 0, v = 0) sits in the world.
-- House footprint: u -4..58, v 0..30 (world X -100..-38, Z 76..106), in the
-- open north-west corner beside the Outdoor area and inside the coaster loop.

local Config = {
	DEBUG = false, -- true: show waypoint markers and print ride state changes

	TITLE = "RUMAH HANTU",
	SUBTITLE = "MALAM TERAKHIR",

	ORIGIN = Vector3.new(-96, 1, 76),
	WALL_HEIGHT = 10,

	-- Riders
	MAX_RIDERS = 4,
	MIN_RIDERS = 1,
	BOARD_DISTANCE = 14, -- how close a player must be to a seat to board it

	-- Timing (seconds)
	BOARDING_COUNTDOWN = 10,
	FULL_CART_DELAY = 3, -- when all four seats fill, leave after this instead
	DISPATCH_DELAY = 2, -- gates close, doors open, then the cart rolls
	UNLOAD_SECONDS = 4,
	RESET_DELAY = 1,

	-- Speeds (studs per second)
	RIDE_SPEED = 1.5,
	RETURN_SPEED = 4, -- empty cart going back round to the loading point
	SCENE_SPEEDS = {
		Slow = 1.1,
		Crawl = 0.7,
		Escape = 5,
	},
	ACCELERATION = 2.5, -- how quickly the cart eases to a new speed

	CART_HEIGHT = 0.55, -- centre of the cart floor above the ground

	-- The route. Each point: u, v, and optionally Speed (from here on),
	-- Pause (seconds stopped here), Scene (cue that fires when the cart
	-- reaches it) and Stop ("Unload" marks the unload position).
	-- The cart starts at the first point and the route is a closed loop.
	WAYPOINTS = {
		{ u = 48, v = 19, Speed = 1.5 }, -- loading point, facing west
		{ u = 44.5, v = 19, Speed = 1.1, Scene = "Entrance" }, -- through the front doors
		{ u = 38, v = 20 },
		{ u = 32, v = 19, Scene = "Corridor" },
		{ u = 26, v = 18.6, Scene = "CorridorEnd" }, -- small scare, dining door opens
		{ u = 21.5, v = 19 },
		{ u = 18, v = 19.2, Speed = 0.7, Scene = "Dining" },
		{ u = 14, v = 19.5, Pause = 3 },
		{ u = 8, v = 19, Speed = 1.1, Scene = "Mirrors" },
		{ u = 3, v = 18.6 },
		{ u = 0.4, v = 15 },
		{ u = 3, v = 11.4, Scene = "GhostRoomDoor" },
		{ u = 8, v = 11, Speed = 0.7, Scene = "GhostRoom" },
		{ u = 14, v = 10.6, Pause = 3.5 },
		{ u = 20, v = 11, Speed = 1.1, Scene = "Graveyard" },
		{ u = 26.5, v = 11.4, Scene = "GraveRiser" },
		{ u = 32, v = 11, Speed = 0.7, Scene = "Finale" },
		{ u = 37, v = 11, Pause = 4.5, Scene = "Blackout" },
		{ u = 39, v = 11, Speed = 5, Scene = "Escape" },
		{ u = 44.5, v = 11 },
		{ u = 48.5, v = 11, Speed = 4, Stop = "Unload" },
		{ u = 53.3, v = 12.2 },
		{ u = 54.6, v = 15 },
		{ u = 53.3, v = 17.8 },
		{ u = 50.5, v = 19 },
	},

	-- Scene list, in ride order (also the Workspace folder names).
	SCENES = {
		"Scene01_Entrance",
		"Scene02_Hallway",
		"Scene03_DiningRoom",
		"Scene04_MirrorHall",
		"Scene05_GhostRoom",
		"Scene06_Graveyard",
		"Scene07_Finale",
	},

	-- Audio. No sound IDs have been chosen and none may be guessed.
	-- 0 = silent placeholder. Replace with an approved Roblox audio asset ID.
	SOUNDS = {
		Ambience = 94720256694323, -- "Breath of the Undead" (Creator Store, chosen by the owner); loops during the ride
		Wind = 0,
		DoorCreak = 0,
		Heartbeat = 0,
		GhostWhisper = 0,
		Thunder = 0,
		Impact = 0,
		FinalScare = 0,
	},
	SOUND_VOLUME = 0.6,

	-- Inside the house each player's own screen goes dark (the map itself is
	-- never darkened), and the venue music is turned down for that player.
	DARK_AMBIENT = Color3.fromRGB(7, 7, 12),
	DARK_BRIGHTNESS = 0,
	DARK_EXPOSURE = -0.2,
	MUSIC_VOLUME_INSIDE = 0, -- fraction of the normal venue music heard inside (0 = silent)

	Colors = {
		Wood = Color3.fromRGB(58, 44, 36),
		WoodDark = Color3.fromRGB(34, 26, 24),
		Stone = Color3.fromRGB(86, 84, 88),
		Roof = Color3.fromRGB(38, 32, 38),
		Floor = Color3.fromRGB(26, 22, 22),
		Iron = Color3.fromRGB(46, 44, 50),
		Brass = Color3.fromRGB(150, 118, 62),
		Cloth = Color3.fromRGB(60, 22, 30),
		Ghost = Color3.fromRGB(214, 228, 240),
		WarmLight = Color3.fromRGB(255, 190, 120),
		ColdLight = Color3.fromRGB(140, 190, 255),
		GreenLight = Color3.fromRGB(130, 255, 160),
		PurpleLight = Color3.fromRGB(190, 120, 255),
		SignText = Color3.fromRGB(190, 255, 170),
	},
}

-- House space -> world position.
function Config.toWorld(u, y, v)
	return Vector3.new(Config.ORIGIN.X + u, Config.ORIGIN.Y + y, Config.ORIGIN.Z + v)
end

-- Turns an ordered, closed list of points into a smooth route.
-- Returns { Samples = { { Position, Distance } ... }, WaypointDistance = { ... }, Length }.
-- Used by the builder (to lay rails) and the server (to move the cart), so
-- the rails and the cart always follow exactly the same curve.
function Config.buildPath(points)
	local count = #points
	local STEPS = 14
	local samples = {}
	local waypointDistance = {}
	local distance = 0
	local previous = nil

	local function spline(p0, p1, p2, p3, t)
		local t2, t3 = t * t, t * t * t
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	end

	for i = 1, count do
		local p0 = points[(i - 2) % count + 1]
		local p1 = points[i]
		local p2 = points[i % count + 1]
		local p3 = points[(i + 1) % count + 1]
		for step = 0, STEPS - 1 do
			local position = spline(p0, p1, p2, p3, step / STEPS)
			if previous then
				distance += (position - previous).Magnitude
			end
			if step == 0 then
				waypointDistance[i] = distance
			end
			table.insert(samples, { Position = position, Distance = distance })
			previous = position
		end
	end
	-- Close the loop back to the first point.
	distance += (points[1] - previous).Magnitude
	table.insert(samples, { Position = points[1], Distance = distance })

	return { Samples = samples, WaypointDistance = waypointDistance, Length = distance }
end

-- Position and travel direction at a distance along a route from buildPath.
function Config.pointAt(path, distance)
	local samples = path.Samples
	distance = distance % path.Length
	local low, high = 1, #samples
	while high - low > 1 do
		local mid = math.floor((low + high) / 2)
		if samples[mid].Distance <= distance then
			low = mid
		else
			high = mid
		end
	end
	local a, b = samples[low], samples[high]
	local span = b.Distance - a.Distance
	local alpha = span > 0 and (distance - a.Distance) / span or 0
	local position = a.Position:Lerp(b.Position, alpha)
	local direction = b.Position - a.Position
	if direction.Magnitude < 1e-4 then
		direction = Vector3.new(-1, 0, 0)
	end
	return position, direction.Unit
end

return Config
