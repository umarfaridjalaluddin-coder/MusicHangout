-- MusicServer (PERMANENT)
-- Server-authoritative music playback: creates/reuses MainSound, MusicStateChanged and
-- GetMusicState, plays the SongList playlist in order, and advances automatically when
-- a track ends. Clients never choose the SoundId; this script is the only writer of state.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SongList = require(ReplicatedStorage.Modules.SongList)

local LOG = "[MusicServer] "

-- ============================================================
-- Ensure MainSound exists under SoundService.Music
-- ============================================================

local musicFolder = SoundService:FindFirstChild("Music")
if not musicFolder then
	musicFolder = Instance.new("Folder")
	musicFolder.Name = "Music"
	musicFolder.Parent = SoundService
	print(LOG .. "Created SoundService.Music (was missing).")
end

local mainSound = musicFolder:FindFirstChild("MainSound")
if mainSound and not mainSound:IsA("Sound") then
	warn(LOG .. "SoundService.Music.MainSound exists but is a " .. mainSound.ClassName .. ", not a Sound. Removing it.")
	mainSound:Destroy()
	mainSound = nil
end
if not mainSound then
	mainSound = Instance.new("Sound")
	mainSound.Name = "MainSound"
	mainSound.Parent = musicFolder
	print(LOG .. "Created MainSound.")
else
	print(LOG .. "Reusing existing MainSound.")
end

mainSound.Looped = false
mainSound.Volume = 0.5

-- ============================================================
-- Ensure ReplicatedStorage.Remotes exists
-- ============================================================

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
	print(LOG .. "Created ReplicatedStorage.Remotes (was missing).")
end

-- ---- MusicStateChanged (RemoteEvent, outbound only) ----

local musicStateChanged = remotesFolder:FindFirstChild("MusicStateChanged")
if musicStateChanged and not musicStateChanged:IsA("RemoteEvent") then
	warn(LOG .. "Remotes.MusicStateChanged exists but is a " .. musicStateChanged.ClassName .. ", not a RemoteEvent. Removing it.")
	musicStateChanged:Destroy()
	musicStateChanged = nil
end
if not musicStateChanged then
	musicStateChanged = Instance.new("RemoteEvent")
	musicStateChanged.Name = "MusicStateChanged"
	musicStateChanged.Parent = remotesFolder
	print(LOG .. "Created MusicStateChanged RemoteEvent.")
else
	print(LOG .. "Reusing existing MusicStateChanged RemoteEvent.")
end

-- ---- GetMusicState (RemoteFunction, read-only snapshot for late joiners) ----

local getMusicState = remotesFolder:FindFirstChild("GetMusicState")
if getMusicState and not getMusicState:IsA("RemoteFunction") then
	warn(LOG .. "Remotes.GetMusicState exists but is a " .. getMusicState.ClassName .. ", not a RemoteFunction. Removing it.")
	getMusicState:Destroy()
	getMusicState = nil
end
if not getMusicState then
	getMusicState = Instance.new("RemoteFunction")
	getMusicState.Name = "GetMusicState"
	getMusicState.Parent = remotesFolder
	print(LOG .. "Created GetMusicState RemoteFunction.")
else
	print(LOG .. "Reusing existing GetMusicState RemoteFunction.")
end

-- ============================================================
-- Playlist state (server-authoritative)
-- ============================================================

local currentIndex = 0 -- 0 means "nothing has played yet"

-- Public snapshot exposed to clients via MusicStateChanged and GetMusicState.
-- Contains only display metadata -- no internal server details.
local currentState = nil

local function isValidTrack(track)
	if type(track) ~= "table" then
		return false
	end
	if type(track.SoundId) ~= "string" or track.SoundId == "" then
		return false
	end
	return true
end

local function findNextValidIndex(fromIndex)
	local count = #SongList
	if count == 0 then
		return nil
	end
	for step = 1, count do
		local index = ((fromIndex + step - 1) % count) + 1
		if isValidTrack(SongList[index]) then
			return index
		end
	end
	return nil
end

local playNextTrack -- forward declaration

local function onTrackEnded()
	print(LOG .. "Track ended: " .. (currentState and currentState.Title or "unknown"))
	playNextTrack()
end

local endedConnection = nil

-- Once the newly-selected Sound finishes loading, its TimeLength becomes
-- accurate. We wait for that once per track and then patch Duration into
-- the state and re-announce it, so the UI's progress bar has a real total
-- to divide by. This does NOT fire every frame -- once per track, at most.
local function announceDurationOnceLoaded(forTrackIndex, forSoundId)
	if mainSound.IsLoaded and mainSound.TimeLength > 0 then
		if currentState and currentState.TrackIndex == forTrackIndex and currentState.SoundId == forSoundId then
			currentState.Duration = mainSound.TimeLength
			musicStateChanged:FireAllClients(currentState)
		end
		return
	end

	local connection
	connection = mainSound:GetPropertyChangedSignal("IsLoaded"):Connect(function()
		if not mainSound.IsLoaded then
			return
		end
		connection:Disconnect()
		-- Only apply if this is still the current track (avoids a stale
		-- late update overwriting a track that has since changed).
		if currentState and currentState.TrackIndex == forTrackIndex and currentState.SoundId == forSoundId and mainSound.TimeLength > 0 then
			currentState.Duration = mainSound.TimeLength
			musicStateChanged:FireAllClients(currentState)
		end
	end)
end

function playNextTrack()
	local nextIndex = findNextValidIndex(currentIndex)
	if not nextIndex then
		warn(LOG .. "No valid tracks in SongList. Playback stopped.")
		currentState = nil
		return
	end

	local track = SongList[nextIndex]
	currentIndex = nextIndex

	if endedConnection then
		endedConnection:Disconnect()
		endedConnection = nil
	end

	mainSound:Stop()
	mainSound.SoundId = track.SoundId

	local playedOk, playErr = pcall(function()
		mainSound:Play()
	end)

	if not playedOk then
		warn(LOG .. "Failed to play '" .. tostring(track.Title) .. "': " .. tostring(playErr) .. ". Advancing to next track.")
		task.defer(function()
			playNextTrack()
		end)
		return
	end

	currentState = {
		TrackIndex = currentIndex,
		Title = track.Title,
		Artist = track.Artist,
		SoundId = track.SoundId,
		Duration = (mainSound.IsLoaded and mainSound.TimeLength > 0) and mainSound.TimeLength or 0,
		StartedAt = Workspace:GetServerTimeNow(),
	}

	print(LOG .. "Now playing: " .. tostring(track.Title))
	musicStateChanged:FireAllClients(currentState)

	announceDurationOnceLoaded(currentIndex, track.SoundId)

	endedConnection = mainSound.Ended:Connect(onTrackEnded)
end

-- ============================================================
-- GetMusicState: read-only snapshot for late-joining clients.
-- Never accepts or trusts anything from the client beyond the call itself.
-- ============================================================

getMusicState.OnServerInvoke = function(_player)
	return currentState
end

-- ============================================================
-- Start playback
-- ============================================================

if #SongList == 0 then
	warn(LOG .. "SongList is empty. Nothing to play.")
else
	playNextTrack()
end