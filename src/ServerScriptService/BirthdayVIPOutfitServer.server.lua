-- BirthdayVIPOutfitServer (PERMANENT)
-- Birthday VIP dress-up wardrobe in the VIP lounge. Server-authoritative:
-- the client sends one of four fixed words and nothing else. A style is a
-- temporary, session-only look -- the player's real Roblox avatar is never
-- saved over, and "Restore" (or leaving) brings back the original.
--
-- A style has three layers:
--   1. Marketplace clothing/accessories from BirthdayVIPOutfits (all empty
--      for now; an empty slot leaves the player's own item in place).
--   2. Costume pieces built here from plain Parts (no asset ids).
--   3. A small sparkle aura.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Outfits = require(ReplicatedStorage.Modules.BirthdayVIPOutfits)

local LOG = "[BirthdayVIPOutfit] "

local RESTORE = "Restore"
local WARDROBE_POSITION = Vector3.new(116, 3, -60) -- east side of the VIP lounge
local MAX_SELECT_DISTANCE = 30 -- must be at the wardrobe to pick a style
local REQUEST_COOLDOWN = 0.4
local LOOK_FOLDER = "BirthdayVIPLook"

-- Fixed allowlist: only keys listed in Outfits.Order are ever accepted.
local allowed = {}
for _, key in ipairs(Outfits.Order) do
	if type(Outfits[key]) == "table" then
		allowed[key] = true
	end
end

-- ============================================================
-- Remotes
-- ============================================================

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local existing = remotesFolder:FindFirstChild(name)
	if existing and not existing:IsA("RemoteEvent") then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new("RemoteEvent")
		existing.Name = name
		existing.Parent = remotesFolder
	end
	return existing
end

local requestOutfit = ensureRemote("RequestBirthdayVIPOutfit") -- client -> server: one key string
local outfitState = ensureRemote("BirthdayVIPOutfitState") -- server -> client: { Selected, Message }

-- ============================================================
-- Wardrobe (built once under Workspace.Environment)
-- ============================================================

local WHITE = Color3.fromRGB(255, 255, 255)

local function buildWardrobe()
	-- EnvironmentBuilder may start after this script: wait for its folder,
	-- and only make one ourselves if it never appears.
	local environment = Workspace:WaitForChild("Environment", 15)
	if not environment then
		environment = Instance.new("Folder")
		environment.Name = "Environment"
		environment.Parent = Workspace
	end

	-- Earlier flat version of this booth (same builder, older name).
	local old = environment:FindFirstChild("BirthdayVIPWardrobe")
	if old then
		old:Destroy()
	end

	local booth = environment:FindFirstChild("BirthdayVIPDressUp")
	if booth and booth:GetAttribute("Built") then
		return
	end
	if not booth then
		booth = Instance.new("Folder")
		booth.Name = "BirthdayVIPDressUp"
		booth.Parent = environment
	end

	local function sub(parent, name)
		local f = parent:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		return f
	end

	local fArchitecture = sub(booth, "Architecture")
	local fMirror = sub(booth, "Mirror")
	local fStations = sub(booth, "Stations")
	local fLighting = sub(booth, "Lighting")
	local fDecor = sub(booth, "Decor")

	-- Palette
	local WALL = Color3.fromRGB(190, 168, 228)
	local WALL_DEEP = Color3.fromRGB(160, 136, 208)
	local TRIM = Color3.fromRGB(226, 190, 110) -- champagne
	local IVORY = Color3.fromRGB(232, 218, 208)
	local DEEP = Color3.fromRGB(91, 58, 132)
	local GLASS = Color3.fromRGB(176, 200, 232)
	local BULB = Color3.fromRGB(246, 214, 150)
	local SKIN = Color3.fromRGB(226, 212, 204) -- neutral mannequin ivory

	-- The booth stands on the east edge of the lounge and faces west (-X).
	-- Every piece is placed in "section space": f = studs toward the player,
	-- y = studs above the lounge floor, z = studs to the player's right.
	-- Part sizes are therefore (depth, height, width).
	local FLOOR_Y = 2
	local REAR_X = 119
	local CENTRE_Z = -60
	local STEP = 0.3 -- height of the raised boutique floor

	local function section(z, yawDegrees, forward)
		return CFrame.new(REAR_X - (forward or 0), FLOOR_Y, CENTRE_Z + z) * CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
	end

	local function at(sec, f, y, z)
		return sec * CFrame.new(-f, y, z)
	end

	local function part(folder, name, size, cframe, color, props)
		local p = folder:FindFirstChild(name)
		if not p then
			p = Instance.new("Part")
			p.Name = name
			p.Parent = folder
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Shape = Enum.PartType.Block
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		for key, value in pairs(props or {}) do
			p[key] = value
		end
		return p
	end

	local STAND = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder upright
	local CYLINDER = { Shape = Enum.PartType.Cylinder }
	local BALL = { Shape = Enum.PartType.Ball }

	-- Upright cylinder (pedestals, columns).
	local function drum(folder, name, diameter, height, cframe, color, props)
		local merged = { Shape = Enum.PartType.Cylinder }
		for key, value in pairs(props or {}) do
			merged[key] = value
		end
		return part(folder, name, Vector3.new(height, diameter, diameter), cframe * STAND, color, merged)
	end

	-- Disc facing the player (arched tops, rounded sign ends).
	local function disc(folder, name, diameter, thickness, cframe, color, props)
		local merged = { Shape = Enum.PartType.Cylinder }
		for key, value in pairs(props or {}) do
			merged[key] = value
		end
		return part(folder, name, Vector3.new(thickness, diameter, diameter), cframe, color, merged)
	end

	-- Text on the face that looks toward the player (-X in section space).
	local function label(p, textValue, textColor, pixelsPerStud, face)
		local gui = p:FindFirstChild("Label")
		if not gui then
			gui = Instance.new("SurfaceGui")
			gui.Name = "Label"
			gui.Parent = p
		end
		gui.Face = face or Enum.NormalId.Left
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixelsPerStud or 50
		gui.LightInfluence = 0.3
		local t = gui:FindFirstChild("Text")
		if not t then
			t = Instance.new("TextLabel")
			t.Name = "Text"
			t.Parent = gui
		end
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.5)
		t.Size = UDim2.fromScale(0.9, 0.78)
		t.Font = Enum.Font.FredokaOne
		t.Text = textValue
		t.TextColor3 = textColor
		t.TextScaled = true
		return gui
	end

	-- ------------------------------------------------------------
	-- Floor: low raised platform, gold border, rug and photo star
	-- ------------------------------------------------------------
	local centre = section(0, 0)
	part(fArchitecture, "PlatformBorder", Vector3.new(7.9, STEP - 0.06, 25.6), at(centre, 3.55, (STEP - 0.06) / 2, 0), TRIM, { CanCollide = true })
	part(fArchitecture, "Platform", Vector3.new(7.6, STEP, 25.3), at(centre, 3.5, STEP / 2, 0), Color3.fromRGB(176, 156, 216), { CanCollide = true })
	drum(fDecor, "RugEdge", 6.6, 0.04, at(centre, 4.3, STEP + 0.02, 0), TRIM)
	drum(fDecor, "Rug", 6.3, 0.06, at(centre, 4.3, STEP + 0.03, 0), Color3.fromRGB(226, 160, 195))
	drum(fDecor, "RugInner", 4.4, 0.08, at(centre, 4.3, STEP + 0.04, 0), Color3.fromRGB(232, 214, 204))
	local photoSpot = drum(fDecor, "PhotoSpot", 1.3, 0.1, at(centre, 4.3, STEP + 0.05, 0), TRIM)
	local star = part(fDecor, "PhotoSpotStar", Vector3.new(1, 0.02, 1), at(centre, 4.3, STEP + 0.11, 0), TRIM, { Transparency = 1 })
	label(star, "★", IVORY, 60, Enum.NormalId.Top)
	photoSpot.Material = Enum.Material.SmoothPlastic

	-- ------------------------------------------------------------
	-- Architecture: centre bay, two inner bays, two angled wings
	-- ------------------------------------------------------------
	local BAYS = {
		-- name, centre z, width, wall height, yaw, forward shift
		{ "Centre", 0, 6.8, 10.6, 0, 0 },
		{ "InnerLeft", -5.4, 4, 8.4, 0, 0 },
		{ "InnerRight", 5.4, 4, 8.4, 0, 0 },
		{ "LeftWing", -9.55, 4.5, 7.6, 10, 0.45 },
		{ "RightWing", 9.55, 4.5, 7.6, -10, 0.45 },
	}
	local bay = {}
	for _, info in ipairs(BAYS) do
		local name, z, width, height, yaw, forward = info[1], info[2], info[3], info[4], info[5], info[6]
		local sec = section(z, yaw, forward)
		bay[name] = { Section = sec, Width = width, Height = height }
		part(fArchitecture, name .. "Wall", Vector3.new(0.9, height, width), at(sec, -0.45, height / 2, 0), WALL, { CanCollide = true })
		-- Cornice: a slim projecting cap with a champagne edge.
		part(fArchitecture, name .. "Cornice", Vector3.new(1.5, 0.3, width + 0.3), at(sec, 0.05, height + 0.15, 0), IVORY)
		part(fArchitecture, name .. "CorniceTrim", Vector3.new(1.6, 0.1, width + 0.4), at(sec, 0.05, height + 0.34, 0), TRIM)
		part(fArchitecture, name .. "Skirting", Vector3.new(0.2, 0.5, width), at(sec, 0.1, STEP + 0.25, 0), WALL_DEEP)
	end

	-- Slim columns where the bays meet and at the outer ends.
	local function column(name, sec, f, z, height)
		part(fArchitecture, name .. "Base", Vector3.new(1, 0.4, 1), at(sec, f, STEP + 0.2, z), IVORY)
		drum(fArchitecture, name .. "Shaft", 0.6, height - 0.8, at(sec, f, STEP + 0.4 + (height - 0.8) / 2, z), WALL_DEEP)
		part(fArchitecture, name .. "Cap", Vector3.new(1, 0.3, 1), at(sec, f, STEP + height - 0.25, z), TRIM)
		part(fArchitecture, name .. "Finial", Vector3.new(0.55, 0.55, 0.55), at(sec, f, STEP + height + 0.15, z), IVORY, BALL)
	end
	column("ColumnInnerLeft", centre, 0.55, -7.4, 8.2)
	column("ColumnInnerRight", centre, 0.55, 7.4, 8.2)
	column("ColumnOuterLeft", bay.LeftWing.Section, 0.55, -2.3, 7.2)
	column("ColumnOuterRight", bay.RightWing.Section, 0.55, 2.3, 7.2)

	-- ------------------------------------------------------------
	-- Header: pill-shaped sign on the centre bay, subtitle plaque below
	-- ------------------------------------------------------------
	local signY = bay.Centre.Height + 1.75
	local SIGN_W, SIGN_H = 8.2, 2.1
	part(fArchitecture, "SignEdge", Vector3.new(0.5, SIGN_H + 0.3, SIGN_W), at(centre, 0.1, signY, 0), TRIM)
	disc(fArchitecture, "SignEdgeLeft", SIGN_H + 0.3, 0.5, at(centre, 0.1, signY, -SIGN_W / 2), TRIM)
	disc(fArchitecture, "SignEdgeRight", SIGN_H + 0.3, 0.5, at(centre, 0.1, signY, SIGN_W / 2), TRIM)
	local sign = part(fArchitecture, "Sign", Vector3.new(0.7, SIGN_H, SIGN_W), at(centre, 0.25, signY, 0), DEEP)
	disc(fArchitecture, "SignLeft", SIGN_H, 0.7, at(centre, 0.25, signY, -SIGN_W / 2), DEEP)
	disc(fArchitecture, "SignRight", SIGN_H, 0.7, at(centre, 0.25, signY, SIGN_W / 2), DEEP)
	label(sign, "VIP DRESS UP", TRIM, 45)
	-- Soft backlight under the sign.
	part(fLighting, "SignGlow", Vector3.new(0.3, 0.12, SIGN_W - 0.6), at(centre, 0.2, signY - SIGN_H / 2 - 0.22, 0), Color3.fromRGB(200, 170, 240), nil)
	-- Small crown emblem above the sign.
	local crownY = signY + SIGN_H / 2 + 0.3
	part(fDecor, "CrownBand", Vector3.new(0.3, 0.22, 1.3), at(centre, 0.25, crownY, 0), TRIM)
	for i, z in ipairs({ -0.5, 0, 0.5 }) do
		part(fDecor, "CrownPoint" .. i, Vector3.new(0.3, (i == 2) and 0.6 or 0.42, 0.22), at(centre, 0.25, crownY + ((i == 2) and 0.36 or 0.28), z), TRIM)
		part(fDecor, "CrownGem" .. i, Vector3.new(0.28, 0.28, 0.28), at(centre, 0.25, crownY + ((i == 2) and 0.76 or 0.58), z), (i == 2) and Color3.fromRGB(245, 170, 205) or IVORY, BALL)
	end

	local subtitle = part(fArchitecture, "Subtitle", Vector3.new(0.2, 0.8, 5.6), at(centre, 0.12, bay.Centre.Height - 0.75, 0), IVORY)
	part(fArchitecture, "SubtitleTrim", Vector3.new(0.16, 0.92, 5.72), at(centre, 0.06, bay.Centre.Height - 0.75, 0), TRIM)
	label(subtitle, "Choose Your Birthday Look ✦", DEEP, 55)

	-- ------------------------------------------------------------
	-- Vanity mirror: arched, gold frame, light strips, shelf
	-- ------------------------------------------------------------
	local MIRROR_W, MIRROR_H = 3.8, 5
	local mirrorBottom = STEP + 1
	local mirrorMid = mirrorBottom + MIRROR_H / 2
	local mirrorTop = mirrorBottom + MIRROR_H
	part(fMirror, "MirrorFrame", Vector3.new(0.3, MIRROR_H + 0.3, MIRROR_W + 0.6), at(centre, 0.15, mirrorMid - 0.15, 0), TRIM)
	disc(fMirror, "TopArch", MIRROR_W + 0.6, 0.3, at(centre, 0.15, mirrorTop, 0), TRIM)
	local mirror = part(fMirror, "MirrorSurface", Vector3.new(0.3, MIRROR_H, MIRROR_W), at(centre, 0.22, mirrorMid, 0), GLASS,  { Reflectance = 0.12 })
	disc(fMirror, "MirrorSurfaceArch", MIRROR_W, 0.3, at(centre, 0.22, mirrorTop, 0), GLASS,  { Reflectance = 0.12 })
	-- A soft diagonal sheen so the glass does not read as a flat panel.
	part(fMirror, "MirrorSheen", Vector3.new(0.02, 5.2, 0.5), at(centre, 0.38, mirrorMid + 0.3, -0.5) * CFrame.Angles(math.rad(18), 0, 0), Color3.fromRGB(255, 255, 255), { Transparency = 0.72 })

	part(fMirror, "BottomShelf", Vector3.new(1.2, 0.25, MIRROR_W + 1.6), at(centre, 0.6, mirrorBottom - 0.3, 0), IVORY)
	part(fMirror, "BottomShelfTrim", Vector3.new(1.3, 0.08, MIRROR_W + 1.7), at(centre, 0.6, mirrorBottom - 0.14, 0), TRIM)
	part(fMirror, "ShelfLeg", Vector3.new(0.8, mirrorBottom - 0.4 - STEP, MIRROR_W + 0.8), at(centre, 0.4, STEP + (mirrorBottom - 0.4 - STEP) / 2, 0), WALL_DEEP)

	for _, side in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
		local name, s = side[1], side[2]
		local z = s * (MIRROR_W / 2 + 0.75)
		part(fMirror, name .. "LightStrip", Vector3.new(0.7, MIRROR_H + 0.6, 0.55), at(centre, 0.35, mirrorMid, z), IVORY)
		part(fMirror, name .. "LightStripCap", Vector3.new(0.8, 0.2, 0.7), at(centre, 0.35, mirrorTop + 0.4, z), TRIM)
		for i = 1, 3 do
			part(fLighting, name .. "Bulb" .. i, Vector3.new(0.42, 0.42, 0.42), at(centre, 0.75, mirrorBottom + 0.3 + i * 1.25, z), BULB, { Shape = Enum.PartType.Ball })
		end
		part(fLighting, name .. "TopBulb", Vector3.new(0.42, 0.42, 0.42), at(centre, 0.5, mirrorTop + MIRROR_W / 2 * 0.72 + 0.35, s * (MIRROR_W / 2 * 0.72 + 0.3)), BULB, { Shape = Enum.PartType.Ball })
		-- One real light per side is enough; the bulbs themselves just glow.
		local holder = part(fLighting, name .. "VanityLight", Vector3.new(0.2, 0.2, 0.2), at(centre, 1.6, mirrorMid + 0.5, z), BULB, { Transparency = 1 })
		local light = holder:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 236, 214)
		light.Brightness = 0.3
		light.Range = 12
		light.Shadows = false
		light.Parent = holder
	end
	-- Small star cluster over the mirror.
	for i, spot in ipairs({ { -1.1, 0.25 }, { 0, 0.6 }, { 1.1, 0.25 } }) do
		part(fDecor, "MirrorStar" .. i, Vector3.new(0.2, 0.26, 0.26), at(centre, 0.3, mirrorTop + MIRROR_W / 2 + 0.3 + spot[2], spot[1]) * CFrame.Angles(math.rad(45), 0, 0), TRIM)
	end

	local prompt = mirror:FindFirstChild("BirthdayVIPWardrobePrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BirthdayVIPWardrobePrompt"
		prompt.Parent = mirror
	end
	prompt.ActionText = "Dress Up"
	prompt.ObjectText = "Birthday VIP Wardrobe"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, -90) -- keep the prompt off the player's face

	-- ------------------------------------------------------------
	-- Mannequins: simple R15-style display figures, one per station
	-- ------------------------------------------------------------
	local function mannequin(folder, base, look)
		local body = base * CFrame.Angles(0, math.rad(look.Turn or 0), 0)
		local function m(name, size, offset, color, props)
			return part(folder, name, size, body * offset, color, props)
		end
		for _, leg in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
			m(leg[1] .. "Leg", Vector3.new(0.4, 1.25, 0.38), CFrame.new(0, 0.625, leg[2] * 0.24), SKIN)
		end
		m("LowerTorso", Vector3.new(0.5, 0.45, 0.88), CFrame.new(0, 1.45, 0), look.Second)
		m("Waist", Vector3.new(0.48, 0.5, 0.8), CFrame.new(0, 1.9, 0), look.Main)
		m("UpperTorso", Vector3.new(0.56, 0.62, 1.02), CFrame.new(0, 2.42, 0), look.Main)
		drum(folder, "Neck", 0.3, 0.22, body * CFrame.new(0, 2.82, 0), SKIN)
		m("Head", Vector3.new(0.92, 0.92, 0.92), CFrame.new(0, 3.32, 0), SKIN, BALL)
		local arms = {}
		for index, arm in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
			local name, s = arm[1], arm[2]
			local angle = look.Arms[index]
			local shoulder = body * CFrame.new(0, 2.58, s * 0.62)
			m(name .. "Shoulder", Vector3.new(0.36, 0.36, 0.36), CFrame.new(0, 2.58, s * 0.6), look.Main, BALL)
			local armFrame = shoulder * CFrame.Angles(math.rad(-s * angle), 0, 0)
			part(folder, name .. "Arm", Vector3.new(0.27, 1.1, 0.27), armFrame * CFrame.new(0, -0.6, 0), SKIN)
			part(folder, name .. "Hand", Vector3.new(0.3, 0.3, 0.3), armFrame * CFrame.new(0, -1.2, 0), SKIN, BALL)
			arms[index] = armFrame
		end
		return body, arms
	end

	local dress = {}

	function dress.BirthdayStar(folder, body)
		drum(folder, "Skirt", 1.3, 0.42, body * CFrame.new(0, 1.36, 0), Color3.fromRGB(247, 200, 222))
		part(folder, "Sash", Vector3.new(0.04, 1.45, 0.17), body * CFrame.new(-0.3, 2.15, 0) * CFrame.Angles(math.rad(38), 0, 0), Color3.fromRGB(214, 194, 240))
		part(folder, "Rosette", Vector3.new(0.2, 0.2, 0.2), body * CFrame.new(-0.3, 1.66, 0.38), TRIM, BALL)
		for i, z in ipairs({ -0.22, 0, 0.22 }) do
			part(folder, "Tiara" .. i, Vector3.new(0.18, 0.18, 0.18), body * CFrame.new(-0.18, 3.74 + ((i == 2) and 0.1 or 0), z), (i == 2) and Color3.fromRGB(245, 170, 205) or TRIM, BALL)
		end
	end

	function dress.RoyalVIP(folder, body)
		part(folder, "Cape", Vector3.new(0.06, 2, 1.2), body * CFrame.new(0.38, 1.75, 0) * CFrame.Angles(0, 0, math.rad(7)), Color3.fromRGB(214, 194, 240))
		part(folder, "Collar", Vector3.new(0.62, 0.12, 1.06), body * CFrame.new(0, 2.74, 0), TRIM)
		part(folder, "Sash", Vector3.new(0.04, 1.1, 0.1), body * CFrame.new(-0.3, 2.15, 0), TRIM)
		drum(folder, "Crown", 0.52, 0.16, body * CFrame.new(0, 3.8, 0), TRIM)
		for i, z in ipairs({ -0.17, 0, 0.17 }) do
			part(folder, "CrownTip" .. i, Vector3.new(0.14, 0.14, 0.14), body * CFrame.new(-0.1, 3.95, z), (i == 2) and Color3.fromRGB(200, 170, 255) or TRIM, BALL)
		end
	end

	function dress.NeonPartyKid(folder, body, arms)
		local purple = Color3.fromRGB(160, 125, 225)
		for _, ear in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
			part(folder, ear[1] .. "EarCup", Vector3.new(0.14, 0.42, 0.42), body * CFrame.new(0, 3.3, ear[2] * 0.5) * CFrame.Angles(0, math.rad(90), 0), purple, CYLINDER)
		end
		-- Headband: short segments along an arch over the head.
		local previous = nil
		for step = 0, 6 do
			local t = math.pi * step / 6
			local point = Vector3.new(0, 3.34 + math.sin(t) * 0.56, math.cos(t) * 0.52)
			if previous then
				local mid = (previous + point) / 2
				part(folder, "Headband" .. step, Vector3.new(0.07, (point - previous).Magnitude + 0.03, 0.12), body * (CFrame.lookAt(mid, point, Vector3.new(1, 0, 0)) * CFrame.Angles(math.rad(90), 0, 0)), purple)
			end
			previous = point
		end
		for index, armFrame in ipairs(arms) do
			drum(folder, "Bracelet" .. index, 0.4, 0.1, armFrame * CFrame.new(0, -0.95, 0), (index == 1) and Color3.fromRGB(90, 200, 235) or Color3.fromRGB(245, 130, 195))
		end
		part(folder, "JacketTrim", Vector3.new(0.04, 1, 0.08), body * CFrame.new(-0.3, 2.15, 0), Color3.fromRGB(90, 200, 235))
	end

	function dress.MyAvatar(folder, body)
		part(folder, "Heart", Vector3.new(0.12, 0.22, 0.22), body * CFrame.new(-0.3, 2.45, 0.22) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(245, 170, 205))
	end

	-- ------------------------------------------------------------
	-- Stations: arched alcove, pilasters, pedestal, name plate, mannequin
	-- ------------------------------------------------------------
	local STATIONS = {
		{ Key = "BirthdayStar", Bay = "LeftWing", Title = "Birthday Star", Panel = Color3.fromRGB(236, 190, 212), Accent = Color3.fromRGB(245, 170, 205),
			Look = { Main = Color3.fromRGB(232, 140, 185), Second = Color3.fromRGB(170, 140, 220), Arms = { 12, 38 }, Turn = -8 } },
		{ Key = "RoyalVIP", Bay = "InnerLeft", Title = "Royal VIP", Panel = Color3.fromRGB(236, 218, 176), Accent = TRIM,
			Look = { Main = IVORY, Second = TRIM, Arms = { 7, 7 }, Turn = 0 } },
		{ Key = "NeonPartyKid", Bay = "InnerRight", Title = "Neon Party Kid", Panel = Color3.fromRGB(160, 208, 228), Accent = Color3.fromRGB(120, 205, 235),
			Look = { Main = Color3.fromRGB(90, 190, 225), Second = Color3.fromRGB(150, 115, 215), Arms = { 34, 28 }, Turn = 12 } },
		{ Key = "MyAvatar", Bay = "RightWing", Title = "My Avatar", Panel = Color3.fromRGB(206, 190, 236), Accent = Color3.fromRGB(205, 188, 238),
			Look = { Main = Color3.fromRGB(226, 216, 240), Second = Color3.fromRGB(176, 152, 220), Arms = { 9, 9 }, Turn = 0 } },
	}

	local ALCOVE_W, ALCOVE_H = 3, 4.1 -- straight part of the niche; the arch adds half the width
	for _, station in ipairs(STATIONS) do
		local folder = sub(fStations, station.Key)
		local sec = bay[station.Bay].Section
		local bottom = STEP + 0.55
		local top = bottom + ALCOVE_H

		-- Niche: gold outline, then the tinted inset panel with an arched top.
		part(folder, "FrameOuter", Vector3.new(0.14, ALCOVE_H + 0.12, ALCOVE_W + 0.3), at(sec, 0.07, bottom + ALCOVE_H / 2 - 0.06, 0), TRIM)
		disc(folder, "FrameOuterArch", ALCOVE_W + 0.3, 0.14, at(sec, 0.07, top, 0), TRIM)
		part(folder, "BackPanel", Vector3.new(0.14, ALCOVE_H, ALCOVE_W), at(sec, 0.13, bottom + ALCOVE_H / 2, 0), station.Panel)
		disc(folder, "BackPanelArch", ALCOVE_W, 0.14, at(sec, 0.13, top, 0), station.Panel)

		-- Pilasters framing the niche give it real depth.
		for _, side in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
			local z = side[2] * (ALCOVE_W / 2 + 0.32)
			part(folder, "SideFrame" .. side[1], Vector3.new(0.9, ALCOVE_H + 0.5, 0.32), at(sec, 0.45, bottom + (ALCOVE_H + 0.5) / 2 - 0.5, z), IVORY)
			part(folder, "SideFrame" .. side[1] .. "Cap", Vector3.new(1, 0.16, 0.42), at(sec, 0.45, top + 0.08, z), TRIM)
		end

		-- Name plate above the arch: cream panel on a thin champagne backing.
		local plateY = top + ALCOVE_W / 2 + 0.75
		part(folder, "NamePlateTrim", Vector3.new(0.12, 0.74, 3.16), at(sec, 0.06, plateY, 0), TRIM)
		local plate = part(folder, "NamePlate", Vector3.new(0.14, 0.62, 3.04), at(sec, 0.12, plateY, 0), IVORY)
		label(plate, station.Title, DEEP, 60)

		-- Two-level pedestal with a champagne band.
		local pedestal = at(sec, 1.55, STEP, 0)
		drum(folder, "PedestalBase", 2.6, 0.26, pedestal * CFrame.new(0, 0.13, 0), IVORY, { CanCollide = true })
		drum(folder, "PedestalTrim", 2.14, 0.08, pedestal * CFrame.new(0, 0.3, 0), TRIM)
		drum(folder, "Pedestal", 2, 0.26, pedestal * CFrame.new(0, 0.47, 0), IVORY, { CanCollide = true })
		-- Soft accent strip at the foot of the niche.
		part(fLighting, station.Key .. "Footlight", Vector3.new(0.12, 0.1, ALCOVE_W - 0.3), at(sec, 0.26, bottom + 0.08, 0), station.Accent, nil)

		local figure = sub(folder, "Mannequin")
		local body, arms = mannequin(figure, pedestal * CFrame.new(0, 0.6, 0), station.Look)
		dress[station.Key](figure, body, arms)

		-- "Wearing" markers. Hidden here; each player's own client shows the
		-- one that matches what they have on, so only they see it.
		drum(folder, "SelectedGlow", 2.95, 0.05, pedestal * CFrame.new(0, 0.03, 0), TRIM, { Transparency = 1 })
		local badge = part(folder, "WearingBadge", Vector3.new(0.1, 0.42, 1.7), at(sec, 2.95, STEP + 0.3, 0), TRIM, { Transparency = 1 })
		local badgeGui = label(badge, "WEARING", DEEP, 60)
		badgeGui.Enabled = false
	end

	booth:SetAttribute("Built", true)
end

task.spawn(function()
	local ok, err = pcall(buildWardrobe)
	if ok then
		print(LOG .. "Wardrobe built in the VIP lounge.")
	else
		warn(LOG .. "Wardrobe build failed: " .. tostring(err))
	end
end)

-- ============================================================
-- Costume pieces (plain Parts welded to the character)
-- ============================================================

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X by default

local function piece(model, anchorPart, size, offset, color, shape, material)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = anchorPart.CFrame * offset
	p.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchorPart
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function torsoOf(character)
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function armOf(character, side)
	return character:FindFirstChild(side .. "LowerArm") or character:FindFirstChild(side .. " Arm")
end

-- Rounded piece: a built-in sphere mesh stretched to the part size, so
-- costume pieces read as soft shapes instead of boxes. No asset id involved.
local function blob(model, anchorPart, size, offset, color, material)
	local p = piece(model, anchorPart, size, offset, color, nil, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Height (in head space) of the top of the head including hair and hats, so
-- headwear rests on the hair instead of hiding inside it or floating above.
local function headTop(character, head)
	local top = head.Size.Y / 2
	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and (handle:FindFirstChild("HairAttachment") or handle:FindFirstChild("HatAttachment")) then
				local localY = head.CFrame:PointToObjectSpace(handle.Position).Y + handle.Size.Y / 2
				top = math.max(top, localY)
			end
		end
	end
	-- Never more than a modest lift, whatever the hairstyle.
	return math.min(top, head.Size.Y / 2 + 0.6)
end

-- Half-width (in head space) of the head including hair, so ear pieces sit
-- outside the hair instead of inside it.
local function headSide(character, head)
	local side = head.Size.X / 2
	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and handle:FindFirstChild("HairAttachment") then
				local localX = math.abs(head.CFrame:PointToObjectSpace(handle.Position).X) + handle.Size.X / 2
				side = math.max(side, localX)
			end
		end
	end
	return math.min(side, head.Size.X / 2 + 0.45)
end

local CHAMPAGNE = Color3.fromRGB(244, 213, 138)
local SOFT_PINK = Color3.fromRGB(245, 185, 213)
local SOFT_LAVENDER = Color3.fromRGB(214, 194, 240)

-- A thin upright crown point: slim stem with a round tip.
local function crownPoint(model, head, base, height, tipColor, tipSize)
	piece(model, head, Vector3.new(height, 0.13, 0.13), base * CFrame.new(0, height / 2, 0) * UPRIGHT, CHAMPAGNE, Enum.PartType.Cylinder)
	blob(model, head, Vector3.new(tipSize, tipSize, tipSize), base * CFrame.new(0, height + tipSize * 0.3, 0), tipColor)
end

local costumes = {}

function costumes.BirthdayStar(model, character)
	local head = character:FindFirstChild("Head")
	if head then
		local top = headTop(character, head) - 0.06
		-- Tiara: a slim arc of gold pearls across the front, three fine points,
		-- one pastel gem in the middle. Sits back from the face.
		local radius = 0.44
		for i = -3, 3 do
			local angle = math.rad(i * 20)
			blob(model, head, Vector3.new(0.18, 0.16, 0.18), CFrame.new(math.sin(angle) * radius, top, -math.cos(angle) * radius + 0.12), CHAMPAGNE)
		end
		for _, i in ipairs({ -1, 0, 1 }) do
			local angle = math.rad(i * 34)
			local base = CFrame.new(math.sin(angle) * radius, top + 0.04, -math.cos(angle) * radius + 0.12)
			if i == 0 then
				crownPoint(model, head, base, 0.2, SOFT_PINK, 0.2)
			else
				crownPoint(model, head, base, 0.12, CHAMPAGNE, 0.14)
			end
		end
		-- Small rounded bow beside the tiara.
		local bow = CFrame.new(0.42, top + 0.06, 0.16) * CFrame.Angles(0, math.rad(-25), 0)
		blob(model, head, Vector3.new(0.3, 0.22, 0.12), bow * CFrame.new(-0.15, 0.02, 0) * CFrame.Angles(0, 0, math.rad(20)), SOFT_PINK)
		blob(model, head, Vector3.new(0.3, 0.22, 0.12), bow * CFrame.new(0.15, 0.02, 0) * CFrame.Angles(0, 0, math.rad(-20)), SOFT_PINK)
		blob(model, head, Vector3.new(0.13, 0.13, 0.13), bow, SOFT_LAVENDER)
	end
	local torso = torsoOf(character)
	if torso then
		-- Party sash: a thin flat ribbon lying on the torso, shoulder to hip,
		-- with a small rosette where it meets the hip.
		local width, height = torso.Size.X, torso.Size.Y
		local length = math.sqrt(width ^ 2 + height ^ 2) * 0.96
		local tilt = CFrame.Angles(0, 0, math.atan2(width, height))
		local depth = torso.Size.Z / 2 + 0.02
		piece(model, torso, Vector3.new(0.24, length, 0.03), CFrame.new(0, 0, -depth) * tilt, SOFT_LAVENDER, nil, Enum.Material.Fabric)
		piece(model, torso, Vector3.new(0.24, length, 0.03), CFrame.new(0, 0, depth) * tilt, SOFT_LAVENDER, nil, Enum.Material.Fabric)
		piece(model, torso, Vector3.new(0.07, length, 0.034), CFrame.new(0, 0, -depth) * tilt, SOFT_PINK, nil, Enum.Material.Fabric)
		local hip = CFrame.new(width / 2 - 0.12, -height / 2 + 0.16, -depth - 0.02)
		blob(model, torso, Vector3.new(0.3, 0.3, 0.08), hip, CHAMPAGNE)
		blob(model, torso, Vector3.new(0.14, 0.14, 0.1), hip, SOFT_PINK)
	end
end

function costumes.RoyalVIP(model, character)
	local head = character:FindFirstChild("Head")
	if head then
		-- A small round crown resting on the hair, a little to the back.
		local centre = CFrame.new(0, headTop(character, head) - 0.05, 0.08)
		local radius = 0.3
		piece(model, head, Vector3.new(0.12, radius * 2 + 0.08, radius * 2 + 0.08), centre * CFrame.new(0, 0.06, 0) * UPRIGHT, CHAMPAGNE, Enum.PartType.Cylinder)
		for i = 0, 4 do
			-- i = 0 is the front point (toward the face, -Z) and stands tallest.
			local angle = (i / 5) * math.pi * 2
			local base = centre * CFrame.new(math.sin(angle) * radius, 0.1, -math.cos(angle) * radius)
			if i == 0 then
				crownPoint(model, head, base, 0.24, SOFT_LAVENDER, 0.15)
			else
				crownPoint(model, head, base, 0.16, CHAMPAGNE, 0.1)
			end
		end
	end
	local torso = torsoOf(character)
	if torso then
		-- Cape in three thin panels, each leaning out a little more than the
		-- last and a little wider, so it drapes instead of hanging as a slab.
		local width = torso.Size.X * 0.92
		local start = CFrame.new(0, torso.Size.Y / 2 - 0.08, torso.Size.Z / 2 + 0.2)
		local panels = { { 0.9, 6, 0 }, { 0.9, 11, 0.16 }, { 0.8, 16, 0.34 } }
		for index, panel in ipairs(panels) do
			local length, lean, extra = panel[1], panel[2], panel[3]
			local frame = start * CFrame.Angles(math.rad(lean), 0, 0)
			piece(model, torso, Vector3.new(width + extra, length + 0.04, 0.04), frame * CFrame.new(0, -length / 2, 0), Color3.fromRGB(250, 246, 255))
			if index == #panels then
				piece(model, torso, Vector3.new(width + extra, 0.12, 0.05), frame * CFrame.new(0, -length + 0.06, 0), SOFT_LAVENDER)
			end
			start = CFrame.new((frame * CFrame.new(0, -length, 0)).Position)
		end
		-- Slim gold collar with a round clasp on each shoulder.
		piece(model, torso, Vector3.new(torso.Size.X * 0.9, 0.09, 0.07), CFrame.new(0, torso.Size.Y / 2 - 0.06, torso.Size.Z / 2 + 0.2), CHAMPAGNE)
		for _, side in ipairs({ -1, 1 }) do
			blob(model, torso, Vector3.new(0.2, 0.2, 0.2), CFrame.new(side * torso.Size.X * 0.42, torso.Size.Y / 2 - 0.03, torso.Size.Z / 2 - 0.02), CHAMPAGNE)
		end
	end
end

function costumes.NeonPartyKid(model, character)
	local CYAN = Color3.fromRGB(90, 200, 235)
	local PURPLE = Color3.fromRGB(160, 125, 225)
	local HOTPINK = Color3.fromRGB(245, 130, 195)
	local head = character:FindFirstChild("Head")
	if head then
		local side = headSide(character, head) + 0.04
		local top = headTop(character, head) + 0.02
		-- Headphones: small round ear cups and a thin band over the hair.
		for _, s in ipairs({ -1, 1 }) do
			piece(model, head, Vector3.new(0.14, 0.44, 0.44), CFrame.new(s * side, -0.02, 0), PURPLE, Enum.PartType.Cylinder)
			piece(model, head, Vector3.new(0.04, 0.26, 0.26), CFrame.new(s * (side + 0.08), -0.02, 0), CYAN, Enum.PartType.Cylinder)
		end
		-- Band: a smooth arch from ear to ear over the hair, in short segments.
		local earY = 0.1
		local rise = math.max(top - earY, 0.4)
		local steps = 9
		local previous = nil
		for step = 0, steps do
			local t = math.pi * step / steps
			local point = Vector3.new(math.cos(t) * side, earY + math.sin(t) * rise, 0)
			if previous then
				local mid = (previous + point) / 2
				local length = (point - previous).Magnitude
				piece(model, head, Vector3.new(0.07, length + 0.03, 0.13), CFrame.lookAt(mid, point, Vector3.new(0, 0, 1)) * CFrame.Angles(math.rad(90), 0, 0), PURPLE)
			end
			previous = point
		end
	end
	-- Glow bracelets: two slim rings near each wrist.
	for index, name in ipairs({ "Left", "Right" }) do
		local arm = armOf(character, name)
		if arm then
			local diameter = math.max(arm.Size.X, arm.Size.Z) + 0.1
			local y = -arm.Size.Y / 2 + 0.26
			piece(model, arm, Vector3.new(0.08, diameter, diameter), CFrame.new(0, y, 0) * UPRIGHT, index == 1 and CYAN or HOTPINK, Enum.PartType.Cylinder)
			piece(model, arm, Vector3.new(0.08, diameter, diameter), CFrame.new(0, y + 0.14, 0) * UPRIGHT, index == 1 and HOTPINK or CYAN, Enum.PartType.Cylinder)
		end
	end
end

local function buildAura(model, character, aura)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not aura then
		return
	end
	local holder = piece(model, root, Vector3.new(2.5, 3, 2), CFrame.new(0, 0.3, 0), WHITE)
	holder.Name = "Aura"
	holder.Transparency = 1

	local keys = {}
	for i, color in ipairs(aura.Colors) do
		keys[i] = ColorSequenceKeypoint.new((i - 1) / math.max(#aura.Colors - 1, 1), color)
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(keys)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.22), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.8, 1.3)
	emitter.Rate = math.clamp(aura.Rate or 3, 1, 5)
	emitter.Speed = NumberRange.new(0.4, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.35
	emitter.Parent = holder
end

local function clearLook(character)
	local old = character:FindFirstChild(LOOK_FOLDER)
	if old then
		old:Destroy()
	end
end

local function buildLook(character, outfit)
	clearLook(character) -- always start clean: no stacked pieces or particles
	local model = Instance.new("Model")
	model.Name = LOOK_FOLDER
	model.Parent = character
	local builder = costumes[outfit.Costume]
	if builder then
		local ok, err = pcall(builder, model, character)
		if not ok then
			warn(LOG .. "Costume pieces failed: " .. tostring(err))
		end
	end
	local ok, err = pcall(buildAura, model, character, outfit.Aura)
	if not ok then
		warn(LOG .. "Aura failed: " .. tostring(err))
	end
end

-- ============================================================
-- Marketplace layer (HumanoidDescription). Empty slots are left alone.
-- ============================================================

local function validId(value)
	return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function idList(list)
	local out = {}
	if type(list) == "table" then
		for _, value in ipairs(list) do
			if validId(value) then
				table.insert(out, tostring(value))
			end
		end
	end
	return table.concat(out, ",")
end

-- Returns a description to apply, plus whether the style changes anything
-- beyond the player's own look.
local function describe(original, outfit)
	local description = original:Clone()
	local changed = false
	if validId(outfit.Shirt) then
		description.Shirt = outfit.Shirt
		changed = true
	end
	if validId(outfit.Pants) then
		description.Pants = outfit.Pants
		changed = true
	end
	local slots = {
		HatAccessory = outfit.HatAccessories,
		HairAccessory = outfit.HairAccessories,
		BackAccessory = outfit.BackAccessories,
		FrontAccessory = outfit.FrontAccessories,
		NeckAccessory = outfit.NeckAccessories,
	}
	for property, list in pairs(slots) do
		local ids = idList(list)
		if ids ~= "" then
			description[property] = ids
			changed = true
		end
	end
	return description, changed
end

-- ============================================================
-- Per-player session state
-- ============================================================

-- [player] = { Selected = key|nil, Original = HumanoidDescription|nil,
--              Wearing = bool (a Marketplace layer is applied), Busy, Pending, LastRequest }
local states = {}

local function tell(player, message)
	local state = states[player]
	outfitState:FireClient(player, { Selected = state and state.Selected or nil, Message = message })
end

local function applyTo(player, character, key)
	local state = states[player]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not state or not humanoid or humanoid.Health <= 0 then
		return false
	end

	-- Keep one safe copy of the real avatar, taken before any style goes on.
	if not state.Original then
		local ok, original = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if ok and original then
			state.Original = original
		end
	end

	if key == RESTORE then
		clearLook(character)
		if state.Wearing and state.Original then
			local ok, err = pcall(function()
				humanoid:ApplyDescription(state.Original:Clone())
			end)
			if not ok then
				warn(LOG .. "Restore failed for " .. player.Name .. ": " .. tostring(err))
				return false
			end
		end
		state.Wearing = false
		return true
	end

	local outfit = Outfits[key]
	if state.Original then
		local description, changed = describe(state.Original, outfit)
		if changed or state.Wearing then
			local ok, err = pcall(function()
				humanoid:ApplyDescription(description)
			end)
			if ok then
				state.Wearing = changed
			else
				-- e.g. an asset Roblox will not allow: keep the player's own look.
				warn(LOG .. "Could not apply " .. key .. " assets for " .. player.Name .. ": " .. tostring(err))
				pcall(function()
					humanoid:ApplyDescription(state.Original:Clone())
				end)
				state.Wearing = false
			end
		end
	end

	if character.Parent then
		buildLook(character, outfit)
	end
	return true
end

-- One change at a time per player; if more arrive meanwhile, only the latest runs.
local function request(player, key)
	local state = states[player]
	if not state then
		return
	end
	if state.Busy then
		state.Pending = key
		return
	end
	state.Busy = true
	while key do
		state.Pending = nil
		local character = player.Character
		local ok = false
		if character then
			ok = applyTo(player, character, key)
		end
		if not states[player] then
			return
		end
		if ok then
			state.Selected = (key ~= RESTORE) and key or nil
			tell(player, key == RESTORE and "Your avatar is back!" or (Outfits[key].DisplayName .. " is on!"))
		else
			tell(player, "Please try again in a moment.")
		end
		key = state.Pending
	end
	state.Busy = false
end

requestOutfit.OnServerEvent:Connect(function(player, key)
	local state = states[player]
	if not state then
		return
	end
	-- The only accepted input: one of four fixed words.
	if type(key) ~= "string" or not (key == RESTORE or allowed[key]) then
		return
	end
	local now = os.clock()
	if now - state.LastRequest < REQUEST_COOLDOWN then
		return
	end
	state.LastRequest = now

	if key ~= RESTORE then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - WARDROBE_POSITION).Magnitude > MAX_SELECT_DISTANCE then
			tell(player, "Come to the VIP wardrobe to dress up.")
			return
		end
	end
	request(player, key)
end)

local function onCharacterAdded(player, character)
	local state = states[player]
	if not state or not state.Selected then
		return
	end
	-- A fresh character already has the real avatar; put the chosen style back on.
	state.Wearing = false
	character:WaitForChild("HumanoidRootPart", 10)
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	if player.Character == character and state.Selected then
		request(player, state.Selected)
	end
end

local function onPlayerAdded(player)
	if states[player] then
		return
	end
	states[player] = { Selected = nil, Original = nil, Wearing = false, Busy = false, Pending = nil, LastRequest = 0 }
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	local state = states[player]
	if state and state.Original then
		state.Original:Destroy()
	end
	states[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

print(LOG .. "Wardrobe ready with " .. #Outfits.Order .. " styles.")
