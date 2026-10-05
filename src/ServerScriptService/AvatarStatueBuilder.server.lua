-- AvatarStatueBuilder (PERMANENT)
-- Builds giant statues of Roblox avatars, each on its own plinth, under
-- Workspace.Environment.AvatarStatues. The look comes from the account's own
-- Roblox avatar, loaded from Roblox at runtime; nothing is uploaded.
-- Idempotent: a statue that already exists for the same account is left alone.
-- To add another statue, copy a line in STATUES and change its values.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LOG = "[AvatarStatueBuilder] "

-- The ground's top surface is at Y=1. Statues face FACE_TOWARD (the lobby).
local GROUND_TOP = 1
local FACE_TOWARD = Vector3.new(-20, 0, 20)

-- Empty on purpose: no avatar statues are built. To add one, put a line here
-- like: { Username = "RobloxName", Label = "NAME", Scale = 3, X = -40, Z = 62 },
local STATUES = {}

local CREAM = Color3.fromRGB(250, 246, 240)
local LILAC = Color3.fromRGB(200, 175, 255)
local LEMON = Color3.fromRGB(255, 236, 150)
local DARK = Color3.fromRGB(10, 10, 14)

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

local function cylinder(parent, name, diameter, height, x, bottomY, z, color)
	local p = make(parent, "Part", name)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(x, bottomY + height / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanTouch = false
	return p
end

-- Roblox web calls can fail briefly, so try a few times.
local function retry(description, callback)
	for attempt = 1, 3 do
		local ok, result = pcall(callback)
		if ok then
			return result
		end
		warn(LOG .. description .. " failed (attempt " .. attempt .. "): " .. tostring(result))
		task.wait(2)
	end
	return nil
end

local environment = ensureFolder(Workspace, "Environment")
local statues = ensureFolder(environment, "AvatarStatues")

local function buildStatue(spec)
	local folder = ensureFolder(statues, spec.Username)
	local plinthTop = GROUND_TOP + 2
	local base = Vector3.new(spec.X, 0, spec.Z)
	local facing = (FACE_TOWARD - base).Unit

	cylinder(folder, "PlinthRim", 11, 0.3, spec.X, GROUND_TOP, spec.Z, LILAC)
	cylinder(folder, "Plinth", 10, 2, spec.X, GROUND_TOP, spec.Z, CREAM)

	-- Name plate on a short stand in front of the plinth, facing the lobby.
	local platePosition = base + facing * 6.5 + Vector3.new(0, GROUND_TOP + 2.2, 0)
	local plate = make(folder, "Part", "NamePlate")
	plate.Size = Vector3.new(6, 2, 0.4)
	plate.CFrame = CFrame.lookAt(platePosition, platePosition + facing)
	plate.Anchored = true
	plate.Color = DARK
	plate.Material = Enum.Material.SmoothPlastic
	plate.CanTouch = false
	local stand = make(folder, "Part", "NamePlateStand")
	stand.Size = Vector3.new(0.5, 1.4, 0.5)
	stand.CFrame = plate.CFrame * CFrame.new(0, -1.6, 0)
	stand.Anchored = true
	stand.Color = CREAM
	stand.Material = Enum.Material.SmoothPlastic
	stand.CanTouch = false

	local gui = make(plate, "SurfaceGui", "Label")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	local label = make(gui, "TextLabel", "Text")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = spec.Label
	label.TextColor3 = LEMON
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true

	local existing = folder:FindFirstChild("Statue")
	if existing and existing:GetAttribute("Username") == spec.Username then
		return true
	end

	local userId = retry("Looking up " .. spec.Username, function()
		return Players:GetUserIdFromNameAsync(spec.Username)
	end)
	local description = userId and retry("Loading the avatar of " .. spec.Username, function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	local model = description and retry("Building the avatar of " .. spec.Username, function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not model then
		warn(LOG .. "No statue built for " .. spec.Username .. ".")
		return false
	end

	model.Name = "Statue"
	model:SetAttribute("Username", spec.Username)

	-- A statue stands still: no scripts, no name tag, every part anchored.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	model:ScaleTo(spec.Scale)

	-- Stand it on the plinth, facing the lobby.
	local _, size = model:GetBoundingBox()
	local standAt = base + Vector3.new(0, plinthTop + size.Y / 2, 0)
	model:PivotTo(CFrame.lookAt(standAt, standAt + facing))
	local boxCFrame = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, plinthTop + size.Y / 2 - boxCFrame.Position.Y, 0))

	model.Parent = folder
	return true
end

local built = 0
for _, spec in ipairs(STATUES) do
	if buildStatue(spec) then
		built += 1
	end
end

print(LOG .. "Avatar statues complete: " .. built .. " of " .. #STATUES .. ".")
