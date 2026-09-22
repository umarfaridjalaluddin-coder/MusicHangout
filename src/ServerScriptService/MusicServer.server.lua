-- MusicServer (PERMANENT)
-- Server-authoritative music playback: creates/reuses MainSound and MusicStateChanged,
-- plays the SongList playlist in order, and advances automatically when a track ends.
-- Clients never choose the SoundId; this script is the only writer of playback state.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- Playlist looping is controlled by this script, not the Sound object.
mainSound.Looped = false
mainSound.Volume = 0.5

-- ============================================================
-- Ensure MusicStateChanged RemoteEvent exists under ReplicatedStorage.Remotes
-- ============================================================

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
	print(LOG .. "Created ReplicatedStorage.Remotes (was missing).")
end

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

-- ============================================================
-- Playlist state (server-authoritative)
-- ============================================================

local currentIndex = 0 -- 0 means "nothing has played yet"

-- A minimal snapshot of the current track, kept for any future
-- "request current state on join" mechanism (Phase 4). We are not
-- building that request/response system yet, but keeping this table
-- up to date now means Phase 4 can read it without touching MusicServer's
-- playback logic.
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

-- Finds the next valid track index after `fromIndex`, wrapping around the
-- playlist. Returns nil if no valid track exists anywhere in the playlist
-- (e.g. every entry is malformed), so the caller can fail safely instead
-- of looping forever.
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

local playNextTrack -- forward declaration; playNextTrack and onTrackEnded call each other

local function onTrackEnded()
	print(LOG .. "Track ended: " .. (currentState and currentState.Title or "unknown"))
	playNextTrack()
end

-- Play() returns a promise-like object in newer Sound APIs is not guaranteed here,
-- so we rely on the Ended event (fires when playback finishes naturally) rather
-- than polling TimePosition. This is event-driven, not a busy loop.
local endedConnection = nil

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

	local loadedOk, loadErr = pcall(function()
		mainSound:Play()
	end)

	if not loadedOk then
		warn(LOG .. "Failed to play '" .. tostring(track.Title) .. "': " .. tostring(loadErr) .. ". Advancing to next track.")
		-- Defer so we don't recurse synchronously inside pcall's error path,
		-- and don't hammer a broken asset in a tight loop.
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
	}

	print(LOG .. "Now playing: " .. tostring(track.Title))
	musicStateChanged:FireAllClients(currentState)

	endedConnection = mainSound.Ended:Connect(onTrackEnded)
end

-- ============================================================
-- Start playback
-- ============================================================

if #SongList == 0 then
	warn(LOG .. "SongList is empty. Nothing to play.")
else
	playNextTrack()
end