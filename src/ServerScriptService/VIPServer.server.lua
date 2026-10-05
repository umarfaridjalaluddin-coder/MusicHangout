-- VIPServer (PERMANENT)
-- Server-authoritative Birthday VIP Game Pass: ownership, VIP tag, party
-- outfit pieces and the VIP lounge. Ownership is checked once per player at
-- join and updated only when Roblox confirms a completed purchase
-- (PromptGamePassPurchaseFinished) -- never from anything the client claims.
-- Outfit pieces are plain Parts built in code (no asset ids), welded to the
-- character, and only ever created here on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local VIPConfig = require(ReplicatedStorage.Modules.VIPConfig)

local LOG = "[VIPServer] "

local GAME_PASS_ID = VIPConfig.GamePassId
local isConfigured = type(GAME_PASS_ID) == "number" and GAME_PASS_ID > 0

if not isConfigured then
	warn(LOG .. "VIP Game Pass is not configured (GamePassId <= 0). Only the free VIP list will work.")
end

local freeNames = {}
for _, name in ipairs(VIPConfig.FreeVIPUserNames or {}) do
	freeNames[string.lower(name)] = true
end

local outfitById = {}
for _, outfit in ipairs(VIPConfig.Outfits or {}) do
	outfitById[outfit.Id] = outfit
end

-- VIP lounge floor: X[80,120] Z[-80,-40], top Y=2.
local LOUNGE_MIN_X, LOUNGE_MAX_X = 80, 120
local LOUNGE_MIN_Z, LOUNGE_MAX_Z = -80, -40
local LOUNGE_MAX_Y = 12 -- rides passing high overhead are not "in the lounge"
local LOUNGE_EXIT = CFrame.new(72, 4, -60) -- just outside the west entrance
local LOUNGE_CHECK_SECONDS = 0.5
local DENIED_MESSAGE = "VIP lounge is for Birthday VIP. Tap GET VIP to join."

-- ============================================================
-- Remotes
-- ============================================================

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureInstance(className, name)
	local existing = remotesFolder:FindFirstChild(name)
	if existing and not existing:IsA(className) then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new(className)
		existing.Name = name
		existing.Parent = remotesFolder
	end
	return existing
end

local getVIPState = ensureInstance("RemoteFunction", "GetVIPState")
local vipStateChanged = ensureInstance("RemoteEvent", "VIPStateChanged")
local vipGateDenied = ensureInstance("RemoteEvent", "VIPGateDenied") -- server->client notice only
local vipSetOutfit = ensureInstance("RemoteEvent", "VIPSetOutfit") -- client asks, server decides

-- ============================================================
-- Per-player session state
-- ============================================================

local vipStates = {} -- [player] = { IsVIP = boolean, Outfit = { [id] = true }, LastToggle = number, LastDenied = number }

local function publicState(state)
	local outfit = {}
	for id, on in pairs(state.Outfit) do
		if on then
			outfit[id] = true
		end
	end
	return { IsVIP = state.IsVIP, Outfit = outfit }
end

local function announce(player)
	local state = vipStates[player]
	if state then
		vipStateChanged:FireClient(player, publicState(state))
	end
end

-- ============================================================
-- Outfit pieces (code-built, no asset ids)
-- ============================================================

local RAINBOW = {
	Color3.fromRGB(255, 105, 120),
	Color3.fromRGB(255, 170, 90),
	Color3.fromRGB(255, 225, 110),
	Color3.fromRGB(130, 220, 140),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(190, 140, 255),
}
local GOLD = Color3.fromRGB(255, 205, 80)
local PINK = Color3.fromRGB(255, 130, 190)

local function piece(model, anchorPart, size, cframe, color, shape, material)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	p.CFrame = anchorPart.CFrame * cframe
	p.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchorPart
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- Upright cylinder: Roblox cylinders lie along X, so turn them 90 degrees.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function disc(model, anchorPart, diameter, height, offset, color, material)
	return piece(model, anchorPart, Vector3.new(height, diameter, diameter), offset * UPRIGHT, color, Enum.PartType.Cylinder, material)
end

local builders = {}

function builders.PartyHat(model, character)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local top = head.Size.Y / 2
	-- Cone made of shrinking discs, striped pink and yellow.
	local layers = 6
	for i = 1, layers do
		local diameter = 1.1 * (1 - (i - 1) / layers)
		local color = (i % 2 == 1) and PINK or RAINBOW[3]
		disc(model, head, diameter, 0.28, CFrame.new(0, top + 0.14 + (i - 1) * 0.28, 0), color)
	end
	piece(model, head, Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, top + layers * 0.28 + 0.15, 0), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
end

function builders.Crown(model, character)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local top = head.Size.Y / 2
	disc(model, head, 1.15, 0.3, CFrame.new(0, top + 0.15, 0), GOLD, Enum.Material.Metal)
	local points = 6
	for i = 1, points do
		local angle = (i / points) * math.pi * 2
		local offset = CFrame.new(math.cos(angle) * 0.47, top + 0.5, math.sin(angle) * 0.47)
		piece(model, head, Vector3.new(0.2, 0.45, 0.2), offset, GOLD, Enum.PartType.Block, Enum.Material.Metal)
		piece(model, head, Vector3.new(0.2, 0.2, 0.2), offset * CFrame.new(0, 0.3, 0), RAINBOW[((i - 1) % #RAINBOW) + 1], Enum.PartType.Ball)
	end
end

function builders.UnicornHorn(model, character)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	-- Tapered horn on the forehead, tilted forward (-Z is the face).
	local base = CFrame.new(0, head.Size.Y / 2 - 0.1, -head.Size.Z / 2 + 0.15) * CFrame.Angles(math.rad(-25), 0, 0)
	local layers = 7
	for i = 1, layers do
		local diameter = 0.34 * (1 - (i - 1) / (layers + 1))
		local color = (i % 2 == 1) and GOLD or Color3.fromRGB(255, 240, 190)
		disc(model, head, diameter, 0.18, base * CFrame.new(0, 0.09 + (i - 1) * 0.18, 0), color)
	end
end

function builders.RainbowCape(model, character)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return
	end
	local width = torso.Size.X + 0.3
	local stripe = width / #RAINBOW
	local length = 2.6
	-- Hangs down the back (+Z), leaning slightly away from the body.
	local hang = CFrame.new(0, torso.Size.Y / 2 - 0.1, torso.Size.Z / 2 + 0.08) * CFrame.Angles(math.rad(8), 0, 0)
	for i, color in ipairs(RAINBOW) do
		local x = -width / 2 + stripe * (i - 0.5)
		piece(model, torso, Vector3.new(stripe, length, 0.08), hang * CFrame.new(x, -length / 2, 0), color, Enum.PartType.Block, Enum.Material.Fabric)
	end
	piece(model, torso, Vector3.new(width, 0.25, 0.14), hang * CFrame.new(0, -0.05, 0), GOLD)
end

function builders.SparkleTrail(model, character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local holder = piece(model, root, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, -1, 0.6), GOLD)
	holder.Transparency = 1

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = holder

	local keys = {}
	for i, color in ipairs(RAINBOW) do
		keys[i] = ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), color)
	end

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(keys)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 1.2
	trail.MinLength = 0.1
	trail.LightEmission = 0.3
	trail.FaceCamera = true
	trail.Parent = holder

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(keys)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Rate = 12
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.LightEmission = 0.4
	sparkles.Parent = holder
end

local function clearOutfit(character, id)
	local folder = character:FindFirstChild("VIPOutfit")
	local existing = folder and folder:FindFirstChild(id)
	if existing then
		existing:Destroy()
	end
end

local function buildOutfit(character, id)
	local builder = builders[id]
	if not builder then
		return
	end
	local folder = character:FindFirstChild("VIPOutfit")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "VIPOutfit"
		folder.Parent = character
	end
	clearOutfit(character, id)
	local model = Instance.new("Model")
	model.Name = id
	model.Parent = folder
	local ok, err = pcall(builder, model, character)
	if not ok then
		warn(LOG .. "Could not build " .. id .. ": " .. tostring(err))
		model:Destroy()
	end
end

-- ============================================================
-- VIP tag above the head
-- ============================================================

local function applyVIPTag(character, isVIP)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local existing = head:FindFirstChild("VIPTag")
	if existing then
		existing:Destroy()
	end
	if not isVIP then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "VIPTag"
	billboard.Size = UDim2.new(0, 60, 0, 20)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.MaxDistance = 80
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.Text = "VIP"
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = billboard
end

local function dressCharacter(player, character)
	local state = vipStates[player]
	if not state then
		return
	end
	character:WaitForChild("Head", 10)
	character:WaitForChild("HumanoidRootPart", 10)
	if not character.Parent then
		return
	end
	applyVIPTag(character, state.IsVIP)
	local folder = character:FindFirstChild("VIPOutfit")
	if folder then
		folder:Destroy()
	end
	if state.IsVIP then
		for id, on in pairs(state.Outfit) do
			if on then
				buildOutfit(character, id)
			end
		end
	end
end

-- ============================================================
-- Ownership
-- ============================================================

local function checkOwnership(player)
	if freeNames[string.lower(player.Name)] then
		return true
	end
	if not isConfigured then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAME_PASS_ID)
	end)
	if not ok then
		warn(LOG .. "Ownership check failed for " .. player.Name .. ": " .. tostring(owns) .. ". Defaulting to non-VIP.")
		return false
	end
	return owns == true
end

local function onPlayerAdded(player)
	if vipStates[player] then
		return
	end
	local state = { IsVIP = false, Outfit = {}, LastToggle = 0, LastDenied = 0 }
	vipStates[player] = state
	state.IsVIP = checkOwnership(player)
	if not player.Parent then
		vipStates[player] = nil
		return
	end
	announce(player)

	player.CharacterAdded:Connect(function(character)
		dressCharacter(player, character)
	end)
	if player.Character then
		task.spawn(dressCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	vipStates[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- The ONLY place a purchase turns VIP on. Fires on the server.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedPassId, wasPurchased)
	if not isConfigured then
		return
	end
	if not (wasPurchased and purchasedPassId == GAME_PASS_ID) then
		return
	end
	local state = vipStates[player]
	if not state then
		return
	end
	print(LOG .. player.Name .. " completed Birthday VIP purchase.")
	state.IsVIP = true
	announce(player)
	if player.Character then
		applyVIPTag(player.Character, true)
	end
end)

getVIPState.OnServerInvoke = function(player)
	local state = vipStates[player]
	if not state then
		return { IsVIP = false, Outfit = {} }
	end
	return publicState(state)
end

-- ============================================================
-- Outfit toggles. The client only sends an Id and on/off; the server
-- checks VIP, checks the Id is in the config list, and rate-limits.
-- ============================================================

vipSetOutfit.OnServerEvent:Connect(function(player, id, wantOn)
	local state = vipStates[player]
	if not state or not state.IsVIP then
		return
	end
	if type(id) ~= "string" or type(wantOn) ~= "boolean" then
		return
	end
	local outfit = outfitById[id]
	if not outfit then
		return
	end
	local now = os.clock()
	if now - state.LastToggle < 0.3 then
		return
	end
	state.LastToggle = now

	local character = player.Character

	if wantOn and outfit.Slot then
		-- One piece per slot: take off whatever else shares it.
		for otherId, on in pairs(state.Outfit) do
			local other = outfitById[otherId]
			if on and otherId ~= id and other and other.Slot == outfit.Slot then
				state.Outfit[otherId] = nil
				if character then
					clearOutfit(character, otherId)
				end
			end
		end
	end

	state.Outfit[id] = wantOn or nil
	if character then
		if wantOn then
			buildOutfit(character, id)
		else
			clearOutfit(character, id)
		end
	end
	announce(player)
end)

-- ============================================================
-- VIP lounge. The floor has no walls, so instead of a physical gate the
-- server walks non-VIP visitors back to the entrance. Riders (seated) and
-- anything high overhead are left alone.
-- ============================================================

local function ensureLoungeSign()
	-- EnvironmentBuilder may start after this script: wait for its folder,
	-- and only make one ourselves if it never appears.
	local environment = Workspace:WaitForChild("Environment", 15)
	if not environment then
		environment = Instance.new("Folder")
		environment.Name = "Environment"
		environment.Parent = Workspace
	end
	local folder = environment:FindFirstChild("VIPEntrance")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "VIPEntrance"
		folder.Parent = environment
	end
	if folder:FindFirstChild("VIPArchBeam") then
		return
	end

	local function post(name, z)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(0.8, 9, 0.8)
		p.Position = Vector3.new(79, 6.5, z)
		p.Material = Enum.Material.Metal
		p.Color = GOLD
		p.Parent = folder
	end
	post("VIPArchPostLeft", -66)
	post("VIPArchPostRight", -54)

	local beam = Instance.new("Part")
	beam.Name = "VIPArchBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.Size = Vector3.new(0.6, 2.4, 13)
	beam.Position = Vector3.new(79, 12, -60)
	beam.Material = Enum.Material.SmoothPlastic
	beam.Color = Color3.fromRGB(60, 30, 80)
	beam.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left -- faces -X, toward the lobby path
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = beam

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.Text = "BIRTHDAY VIP LOUNGE"
	label.TextColor3 = GOLD
	label.TextScaled = true
	label.Parent = gui
end

task.spawn(ensureLoungeSign)

task.spawn(function()
	while true do
		task.wait(LOUNGE_CHECK_SECONDS)
		for player, state in pairs(vipStates) do
			if not state.IsVIP then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 and not humanoid.SeatPart then
					local pos = root.Position
					if pos.X > LOUNGE_MIN_X and pos.X < LOUNGE_MAX_X and pos.Z > LOUNGE_MIN_Z and pos.Z < LOUNGE_MAX_Z and pos.Y < LOUNGE_MAX_Y then
						root.AssemblyLinearVelocity = Vector3.zero
						root.CFrame = LOUNGE_EXIT
						local now = os.clock()
						if now - state.LastDenied > 3 then
							state.LastDenied = now
							vipGateDenied:FireClient(player, DENIED_MESSAGE)
						end
					end
				end
			end
		end
	end
end)

print(LOG .. "VIPServer ready. Game Pass " .. (isConfigured and ("ID " .. GAME_PASS_ID .. " configured.") or "NOT configured.") .. " Outfit pieces: " .. #(VIPConfig.Outfits or {}) .. ".")
