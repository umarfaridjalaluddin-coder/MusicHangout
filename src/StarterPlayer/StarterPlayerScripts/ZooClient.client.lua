-- ZooClient (PERMANENT)
-- Brings the mini zoo's animals to life on this player's device. The server
-- (ZooBuilder) builds each animal standing still and publishes its start
-- position and roaming limits as attributes. This script then walks each
-- animal around inside its pen: it wanders to a random spot, pauses, and picks
-- another, with swinging legs, a wagging tail and a gently nodding head.
-- Nothing is sent to the server; every player sees their own copy of the
-- movement.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WAIT_SECONDS = 60
local UPDATE_INTERVAL = 1 / 30
local TURN_SPEED = 1.4 -- radians per second
local HEAD_WORDS = { "Head", "Ear", "Eye", "Horn", "Trunk", "Tusk", "Snout", "Nose", "Muzzle", "Beak", "Neck", "Mane" }

local environment = Workspace:WaitForChild("Environment", WAIT_SECONDS)
local zoo = environment and environment:WaitForChild("MiniZoo", WAIT_SECONDS)
local animalsFolder = zoo and zoo:WaitForChild("Animals", WAIT_SECONDS)
if not animalsFolder then
	return
end

local random = Random.new()
local animals = {}

local function partKind(name)
	local legIndex = tonumber(string.match(name, "^Leg(%d)$") or string.match(name, "^Hoof(%d)$"))
	if legIndex then
		-- Diagonal pairs move together, like a real walk.
		return "leg", (legIndex == 1 or legIndex == 4) and 0 or math.pi
	end
	if string.find(name, "^Tail") then
		return "tail", 0
	end
	for _, word in ipairs(HEAD_WORDS) do
		if string.find(name, word, 1, true) then
			return "head", 0
		end
	end
	return "body", 0
end

local function setup(folder)
	-- Wait until the server has finished the animal and all its parts are here.
	local deadline = os.clock() + WAIT_SECONDS
	while true do
		local expected = folder:GetAttribute("PartCount")
		if type(expected) == "number" and #folder:GetChildren() >= expected then
			break
		end
		if os.clock() > deadline or not folder.Parent then
			return
		end
		task.wait(0.5)
	end

	local origin = folder:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return
	end

	local animal = {
		parts = {},
		offsets = {},
		kinds = {},
		legPhases = {},
		position = origin.Position,
		yaw = math.atan2(-origin.LookVector.X, -origin.LookVector.Z),
		float = folder:GetAttribute("Float") == true,
		minX = folder:GetAttribute("MinX"),
		maxX = folder:GetAttribute("MaxX"),
		minZ = folder:GetAttribute("MinZ"),
		maxZ = folder:GetAttribute("MaxZ"),
		speed = folder:GetAttribute("Speed") or 1.5,
		stride = folder:GetAttribute("Stride") or 0.3,
		seed = random:NextNumber(0, 10),
		pauseUntil = os.clock() + random:NextNumber(0.5, 4),
		target = nil,
		stepPhase = 0,
		walkBlend = 0,
	}
	if not animal.float and not (animal.minX and animal.maxX and animal.minZ and animal.maxZ) then
		return
	end

	for _, part in ipairs(folder:GetChildren()) do
		if part:IsA("BasePart") then
			local index = #animal.parts + 1
			animal.parts[index] = part
			animal.offsets[index] = origin:ToObjectSpace(part.CFrame)
			animal.kinds[index], animal.legPhases[index] = partKind(part.Name)
		end
	end
	table.insert(animals, animal)
end

for _, folder in ipairs(animalsFolder:GetChildren()) do
	task.spawn(setup, folder)
end
animalsFolder.ChildAdded:Connect(function(folder)
	task.spawn(setup, folder)
end)

local function shortestTurn(angle)
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local moveParts = {}
local moveCFrames = {}

local function step(dt, now)
	local count = 0
	for _, animal in ipairs(animals) do
		local moving = false

		if animal.float then
			-- Sitting in the pond: turn very slowly on the spot.
			animal.yaw += dt * 0.12
		elseif now >= animal.pauseUntil then
			if not animal.target then
				animal.target = Vector3.new(random:NextNumber(animal.minX, animal.maxX), animal.position.Y, random:NextNumber(animal.minZ, animal.maxZ))
			end
			local toTarget = animal.target - animal.position
			if toTarget.Magnitude < 0.6 then
				-- Arrived: stand for a while, then choose somewhere new.
				animal.target = nil
				animal.pauseUntil = now + random:NextNumber(2, 7)
			else
				local wanted = math.atan2(-toTarget.X, -toTarget.Z)
				local difference = shortestTurn(wanted - animal.yaw)
				animal.yaw += math.clamp(difference, -TURN_SPEED * dt, TURN_SPEED * dt)
				-- Walk only once roughly facing the target, so it turns first.
				if math.abs(difference) < 0.6 then
					local forward = Vector3.new(-math.sin(animal.yaw), 0, -math.cos(animal.yaw))
					animal.position += forward * math.min(animal.speed * dt, toTarget.Magnitude)
					animal.stepPhase += dt * animal.speed * 2.2
					moving = true
				end
			end
		end

		-- Ease the leg swing in and out so starts and stops are not sudden.
		animal.walkBlend += ((moving and 1 or 0) - animal.walkBlend) * math.min(1, dt * 5)

		local bodyCFrame = CFrame.new(animal.position) * CFrame.Angles(0, animal.yaw, 0)
		local breathe = math.sin(now * 1.6 + animal.seed) * (animal.float and 0.1 or 0.04)
		local nod = math.sin(now * 0.9 + animal.seed) * 0.1
		local wag = math.sin(now * 3 + animal.seed) * 0.14

		for index, part in ipairs(animal.parts) do
			local kind = animal.kinds[index]
			local shift
			if kind == "leg" then
				local phase = animal.stepPhase + animal.legPhases[index]
				shift = CFrame.new(0, math.max(0, math.cos(phase)) * animal.stride * 0.5 * animal.walkBlend, math.sin(phase) * animal.stride * animal.walkBlend)
			elseif kind == "tail" then
				shift = CFrame.new(wag, breathe, 0)
			elseif kind == "head" then
				shift = CFrame.new(0, breathe + nod, 0)
			else
				shift = CFrame.new(0, breathe, 0)
			end
			count += 1
			moveParts[count] = part
			moveCFrames[count] = bodyCFrame * shift * animal.offsets[index]
		end
	end

	-- Drop leftovers if the number of parts went down.
	for index = count + 1, #moveParts do
		moveParts[index] = nil
		moveCFrames[index] = nil
	end
	if count > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < UPDATE_INTERVAL then
		return
	end
	step(math.min(accumulated, 0.1), os.clock())
	accumulated = 0
end)
