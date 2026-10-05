-- HauntedRideClient (PERMANENT)
-- Presentation only. While this player's camera is inside the Rumah Hantu
-- scene rooms, their own screen is darkened and the venue music is turned
-- down for them. Nothing here affects the ride, other players or the map's
-- real lighting -- leave the house and everything returns to how it was.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("HauntedRideConfig"))

local ride = Workspace:WaitForChild("HauntedRide", 60)
if not ride then
	return
end

local FADE = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local inside = false -- camera is in the dark scene rooms
local saved = nil -- the map's own lighting, captured the moment we step in

local function findMusic()
	local folder = SoundService:FindFirstChild("Music")
	local sound = folder and folder:FindFirstChild("MainSound")
	return (sound and sound:IsA("Sound")) and sound or nil
end

local function enter()
	saved = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
	TweenService:Create(Lighting, FADE, {
		Ambient = Config.DARK_AMBIENT,
		OutdoorAmbient = Config.DARK_AMBIENT,
		Brightness = Config.DARK_BRIGHTNESS,
		ExposureCompensation = Config.DARK_EXPOSURE,
	}):Play()
end

local function leave()
	if saved then
		TweenService:Create(Lighting, FADE, saved):Play()
		saved = nil
	end
end

-- Venue music: quiet while this player is in the scene rooms, or seated in
-- the cart while it is running (so it is already gone as the cart sets off).
local quiet = false
local normalVolume = nil -- what the music server wants the volume to be
local fadeUntil = 0

local function ridingNow()
	local state = ride:GetAttribute("State")
	if state ~= "DISPATCHING" and state ~= "RIDING" then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat:IsDescendantOf(ride)
end

local function updateMusic(wantQuiet)
	local music = findMusic()
	if not music then
		return
	end
	if wantQuiet ~= quiet then
		quiet = wantQuiet
		fadeUntil = os.clock() + FADE.Time + 0.1
		if quiet then
			normalVolume = music.Volume
			TweenService:Create(music, FADE, { Volume = normalVolume * Config.MUSIC_VOLUME_INSIDE }):Play()
		elseif normalVolume then
			TweenService:Create(music, FADE, { Volume = normalVolume }):Play()
		end
		return
	end
	-- The music server sets the volume again whenever a track starts; while
	-- we are meant to be quiet, note the new value and turn it back down.
	if quiet and normalVolume and os.clock() > fadeUntil then
		local target = normalVolume * Config.MUSIC_VOLUME_INSIDE
		if math.abs(music.Volume - target) > 0.001 then
			normalVolume = music.Volume
			music.Volume = normalVolume * Config.MUSIC_VOLUME_INSIDE
		end
	end
end

while true do
	task.wait(0.2)
	local low = ride:GetAttribute("InsideMin")
	local high = ride:GetAttribute("InsideMax")
	local camera = Workspace.CurrentCamera
	if typeof(low) == "Vector3" and typeof(high) == "Vector3" and camera then
		local p = camera.CFrame.Position
		local now = p.X > low.X and p.X < high.X and p.Y > low.Y and p.Y < high.Y and p.Z > low.Z and p.Z < high.Z
		if now ~= inside then
			inside = now
			if inside then
				enter()
			else
				leave()
			end
		end
		updateMusic(inside or ridingNow())
	end
end
