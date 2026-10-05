-- PlaygroundGames (PERMANENT)
-- Adds games to the playground, under Workspace.Environment.Playground.Games:
--   1. Star hunt: glowing stars to collect, on the ground and on the
--      equipment. Each one adds to the player's "Stars" score in the player
--      list, then comes back after a few seconds.
--   2. Obby race: step on START, climb the rainbow steps, reach the finish
--      platform. A board shows the last run and the best time this session.
--   3. Launch pad and Cloud Club: a strong bounce pad throws players up to a
--      cloud platform high above the playground, with more stars on it.
-- Idempotent: every part is found by name or created, so a rerun updates in
-- place and never duplicates. Adds only its own objects. Scores last for the
-- session only and are separate from the shop's coins.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LOG = "[PlaygroundGames] "

local FLOOR_TOP = 1.5 -- top of the playground floor
local STAR_RESPAWN_SECONDS = 10
local RACE_FINISH_STARS = 3
local LAUNCH_POWER = 130

local MAT_PLASTIC = Enum.Material.SmoothPlastic
local MAT_NEON = Enum.Material.Neon
local YELLOW = Color3.fromRGB(255, 220, 80)
local ORANGE = Color3.fromRGB(255, 160, 60)
local GREEN = Color3.fromRGB(90, 210, 120)
local WHITE = Color3.fromRGB(245, 245, 250)
local SKY = Color3.fromRGB(160, 205, 255)
local DARK = Color3.fromRGB(10, 10, 14)

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

local function playerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player
	end
	return nil
end

-- ============================================================
-- Folders and the "newest copy wins" token
-- ============================================================

local environment = ensureFolder(Workspace, "Environment")
local playground = ensureFolder(environment, "Playground")
local games = ensureFolder(playground, "Games")
local fStars = ensureFolder(games, "Stars")
local fRace = ensureFolder(games, "ObbyRace")
local fCloud = ensureFolder(games, "CloudClub")

-- If this script is ever run again, only the newest copy reacts to touches,
-- so nothing is counted twice.
local token = tostring(os.clock()) .. "-" .. tostring(math.random(1, 1000000))
games:SetAttribute("Runner", token)
local function isCurrent()
	return games:GetAttribute("Runner") == token
end

-- ============================================================
-- Scores: a "Stars" number in the player list
-- ============================================================

local function starsValue(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local value = stats:FindFirstChild("Stars")
	if not (value and value:IsA("IntValue")) then
		value = Instance.new("IntValue")
		value.Name = "Stars"
		value.Parent = stats
	end
	return value
end

for _, player in ipairs(Players:GetPlayers()) do
	starsValue(player)
end
Players.PlayerAdded:Connect(function(player)
	if isCurrent() then
		starsValue(player)
	end
end)

-- ============================================================
-- 1. Star hunt
-- ============================================================

local function star(index, x, y, z)
	local p = make(fStars, "Part", "Star" .. index)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.5, 1.5, 1.5)
	p.CFrame = CFrame.new(x, y, z)
	p.Anchored = true
	p.CanCollide = false
	p.Color = YELLOW
	p.Material = MAT_NEON
	p.Transparency = 0
	p.CanTouch = true

	-- A star symbol that always faces the player.
	local gui = make(p, "BillboardGui", "Icon")
	gui.Size = UDim2.fromScale(3.2, 3.2)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Enabled = true
	local icon = make(gui, "TextLabel", "Symbol")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Text = utf8.char(9733) -- a solid star
	icon.TextColor3 = YELLOW
	icon.TextStrokeColor3 = ORANGE
	icon.TextStrokeTransparency = 0.2
	icon.Font = Enum.Font.GothamBold
	icon.TextScaled = true

	local available = true
	p.Touched:Connect(function(hit)
		if not available or not isCurrent() then
			return
		end
		local player = playerFromHit(hit)
		if not player then
			return
		end
		available = false
		starsValue(player).Value += 1
		p.Transparency = 1
		p.CanTouch = false
		gui.Enabled = false
		task.delay(STAR_RESPAWN_SECONDS, function()
			if p.Parent and isCurrent() then
				p.Transparency = 0
				p.CanTouch = true
				gui.Enabled = true
				available = true
			end
		end)
	end)
end

local STAR_SPOTS = {
	-- On the ground.
	{ 72, 4.5, -7 },
	{ 72, 4.5, 7 },
	{ 88, 4.5, -20 },
	{ 90, 4.5, 9 },
	{ 107, 4.5, 0 },
	{ 110, 4.5, 9 },
	-- Above the trampolines: a normal bounce reaches the first, the pink
	-- trampoline's big bounce is needed for the second.
	{ 78, 14, -14 },
	{ 78, 25, 14 },
	-- On the slide deck and the obby finish platform.
	{ 100, 15.5, -12 },
	{ 109, 15, 18 },
	-- On the cloud.
	{ 81, 33.5, -9 },
	{ 84, 33.5, -12 },
	{ 87, 33.5, -9 },
}
for index, spot in ipairs(STAR_SPOTS) do
	star(index, spot[1], spot[2], spot[3])
end

-- ============================================================
-- 2. Obby race: START pad, finish zone, scoreboard
-- ============================================================

local startPad = block(fRace, "StartPad", Vector3.new(4, 0.2, 4), CFrame.new(79.5, FLOOR_TOP + 0.1, 21.5), GREEN, false)
startPad.Material = MAT_NEON
startPad.CanTouch = true
addText(startPad, Enum.NormalId.Top, "START", DARK)

-- Invisible zone just above the finish platform (centre X=109, Z=20, top Y=11.5).
local finishZone = block(fRace, "FinishZone", Vector3.new(8, 4, 8), CFrame.new(109, FLOOR_TOP + 12, 20), GREEN, false)
finishZone.Transparency = 1
finishZone.CanTouch = true

-- Board on the south edge of the playground, read from inside it (-Z side).
block(fRace, "BoardPostLeft", Vector3.new(0.4, 5, 0.4), CFrame.new(74.8, FLOOR_TOP + 2.5, 24.5), WHITE, false)
block(fRace, "BoardPostRight", Vector3.new(0.4, 5, 0.4), CFrame.new(84.2, FLOOR_TOP + 2.5, 24.5), WHITE, false)
local board = block(fRace, "RaceBoard", Vector3.new(10, 3.6, 0.3), CFrame.new(79.5, FLOOR_TOP + 6, 24.5), DARK, false)
local boardLabel = addText(board, Enum.NormalId.Front, "", YELLOW)

local bestTime = nil
local bestName = nil
local lastLine = "Step on START to race!"

local function refreshBoard()
	local bestLine = bestTime and string.format("BEST: %s  %.1fs", bestName, bestTime) or "BEST: nobody yet"
	boardLabel.Text = "OBBY RACE\n" .. lastLine .. "\n" .. bestLine
end
refreshBoard()

local raceStart = setmetatable({}, { __mode = "k" })

startPad.Touched:Connect(function(hit)
	if not isCurrent() then
		return
	end
	local player = playerFromHit(hit)
	if not player then
		return
	end
	local now = os.clock()
	-- Standing on the pad keeps touching it; only restart after a moment away.
	if raceStart[player] and now - raceStart[player] < 1.5 then
		raceStart[player] = now
		return
	end
	raceStart[player] = now
end)

finishZone.Touched:Connect(function(hit)
	if not isCurrent() then
		return
	end
	local player = playerFromHit(hit)
	local startedAt = player and raceStart[player]
	if not startedAt then
		return
	end
	raceStart[player] = nil
	local elapsed = os.clock() - startedAt
	if elapsed < 1 or elapsed > 300 then
		return
	end

	starsValue(player).Value += RACE_FINISH_STARS
	lastLine = string.format("LAST: %s  %.1fs", player.DisplayName, elapsed)
	if not bestTime or elapsed < bestTime then
		bestTime = elapsed
		bestName = player.DisplayName
	end
	refreshBoard()
end)

Players.PlayerRemoving:Connect(function(player)
	raceStart[player] = nil
end)

-- ============================================================
-- 3. Launch pad and Cloud Club
-- ============================================================

-- The pad carries a BouncePower attribute; PlaygroundClient does the bounce.
block(fCloud, "LaunchBase", Vector3.new(7, 0.5, 7), CFrame.new(84, FLOOR_TOP + 0.25, 0), WHITE)
local launchPad = block(fCloud, "LaunchPad", Vector3.new(5.5, 0.4, 5.5), CFrame.new(84, FLOOR_TOP + 0.7, 0), ORANGE)
launchPad.CanTouch = true
launchPad:SetAttribute("BouncePower", LAUNCH_POWER)
addText(launchPad, Enum.NormalId.Top, "LAUNCH", DARK)

-- Cloud platform, top at Y=30, just north of the launch pad's flight path.
local CLOUD_TOP = 30
block(fCloud, "Cloud", Vector3.new(12, 1, 10), CFrame.new(84, CLOUD_TOP - 0.5, -9), WHITE)
local PUFFS = {
	{ 78, -9, 4 }, { 90, -9, 4 }, { 84, -14, 4.5 }, { 80, -13.5, 3.2 }, { 88, -13.5, 3.2 },
	{ 80, -4.5, 3 }, { 88, -4.5, 3 }, { 84, -9, 3.4 },
}
for index, puff in ipairs(PUFFS) do
	local p = block(fCloud, "Puff" .. index, Vector3.new(puff[3], puff[3], puff[3]), CFrame.new(puff[1], CLOUD_TOP - 1.4, puff[2]), WHITE, false)
	p.Shape = Enum.PartType.Ball
end

-- Sign at the back of the cloud, read from the launch pad side (+Z).
local cloudSignPosition = Vector3.new(84, CLOUD_TOP + 3, -13.6)
local cloudSign = block(fCloud, "CloudSign", Vector3.new(9, 2, 0.3), CFrame.lookAt(cloudSignPosition, cloudSignPosition + Vector3.zAxis), DARK, false)
addText(cloudSign, Enum.NormalId.Front, "CLOUD CLUB", SKY)

print(LOG .. string.format("Playground games complete: %d stars, obby race, launch pad.", #STAR_SPOTS))
