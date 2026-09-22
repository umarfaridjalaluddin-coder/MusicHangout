-- MusicUI (PERMANENT)
-- Display-only Now Playing card. Reads server-authoritative state via
-- MusicStateChanged (live updates) and GetMusicState (late-join snapshot).
-- This script never sends playback commands to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LOG = "[MusicUI] "

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Wait for the remotes MusicServer is responsible for creating.
-- Defensive: if MusicServer hasn't run yet or is missing, don't hang forever.
-- ============================================================

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotesFolder then
	warn(LOG .. "ReplicatedStorage.Remotes not found after waiting. Music UI will not function.")
	return
end

local musicStateChanged = remotesFolder:WaitForChild("MusicStateChanged", 10)
local getMusicState = remotesFolder:WaitForChild("GetMusicState", 10)

if not musicStateChanged or not getMusicState then
	warn(LOG .. "Required music remotes not found. Music UI will not function.")
	return
end

-- ============================================================
-- Build the UI (once). ScreenGui lives directly under PlayerGui.
-- ============================================================

-- Guard against duplicates if this script is somehow re-run.
local existing = playerGui:FindFirstChild("MusicUI")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MusicUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

local card = Instance.new("Frame")
card.Name = "NowPlaying"
card.AnchorPoint = Vector2.new(0.5, 1)
card.Position = UDim2.new(0.5, 0, 1, -20)
card.Size = UDim2.new(0.8, 0, 0, 92)
card.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
card.BackgroundTransparency = 0.15
card.BorderSizePixel = 0
card.Parent = screenGui

local cardSizeConstraint = Instance.new("UISizeConstraint")
cardSizeConstraint.MinSize = Vector2.new(220, 88)
cardSizeConstraint.MaxSize = Vector2.new(420, 110)
cardSizeConstraint.Parent = card

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 12)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(255, 255, 255)
cardStroke.Transparency = 0.9
cardStroke.Thickness = 1
cardStroke.Parent = card

local cardPadding = Instance.new("UIPadding")
cardPadding.PaddingLeft = UDim.new(0, 14)
cardPadding.PaddingRight = UDim.new(0, 14)
cardPadding.PaddingTop = UDim.new(0, 10)
cardPadding.PaddingBottom = UDim.new(0, 10)
cardPadding.Parent = card

local trackTitle = Instance.new("TextLabel")
trackTitle.Name = "TrackTitle"
trackTitle.BackgroundTransparency = 1
trackTitle.Size = UDim2.new(1, 0, 0, 20)
trackTitle.Position = UDim2.new(0, 0, 0, 0)
trackTitle.Font = Enum.Font.GothamBold
trackTitle.Text = "Loading..."
trackTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
trackTitle.TextXAlignment = Enum.TextXAlignment.Left
trackTitle.TextSize = 16
trackTitle.TextTruncate = Enum.TextTruncate.AtEnd
trackTitle.Parent = card

local artistLabel = Instance.new("TextLabel")
artistLabel.Name = "ArtistLabel"
artistLabel.BackgroundTransparency = 1
artistLabel.Size = UDim2.new(1, 0, 0, 16)
artistLabel.Position = UDim2.new(0, 0, 0, 22)
artistLabel.Font = Enum.Font.Gotham
artistLabel.Text = ""
artistLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
artistLabel.TextXAlignment = Enum.TextXAlignment.Left
artistLabel.TextSize = 12
artistLabel.TextTruncate = Enum.TextTruncate.AtEnd
artistLabel.Parent = card

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.BackgroundTransparency = 1
statusLabel.Size = UDim2.new(1, 0, 0, 14)
statusLabel.Position = UDim2.new(0, 0, 0, 40)
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Waiting for music..."
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextSize = 11
statusLabel.Parent = card

local progressBackground = Instance.new("Frame")
progressBackground.Name = "ProgressBackground"
progressBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
progressBackground.BorderSizePixel = 0
progressBackground.Size = UDim2.new(1, 0, 0, 6)
progressBackground.Position = UDim2.new(0, 0, 0, 58)
progressBackground.Parent = card

local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(1, 0)
progressCorner.Parent = progressBackground

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
progressFill.BorderSizePixel = 0
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.Parent = progressBackground

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(1, 0)
progressFillCorner.Parent = progressFill

local timeLabel = Instance.new("TextLabel")
timeLabel.Name = "TimeLabel"
timeLabel.BackgroundTransparency = 1
timeLabel.Size = UDim2.new(1, 0, 0, 14)
timeLabel.Position = UDim2.new(0, 0, 0, 68)
timeLabel.Font = Enum.Font.Gotham
timeLabel.Text = ""
timeLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.TextSize = 11
timeLabel.Parent = card

-- ============================================================
-- Time formatting helper: seconds -> M:SS, safe against bad input.
-- ============================================================

local function formatTime(seconds)
	if type(seconds) ~= "number" or seconds ~= seconds or seconds == math.huge or seconds == -math.huge then
		return "0:00"
	end
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

-- ============================================================
-- Local state (from server) + local progress calculation
-- ============================================================

local activeState = nil -- last-applied {TrackIndex, Title, Artist, SoundId, Duration, StartedAt}
local lastAppliedStartedAt = -1

local function applyState(state)
	if not state or type(state) ~= "table" then
		return
	end

	-- Guard against an older GetMusicState response overwriting a newer
	-- MusicStateChanged event (or vice versa): only apply if this state's
	-- StartedAt is not older than what we already have.
	if state.StartedAt and state.StartedAt < lastAppliedStartedAt then
		return
	end

	activeState = state
	if state.StartedAt then
		lastAppliedStartedAt = state.StartedAt
	end

	trackTitle.Text = (type(state.Title) == "string" and state.Title ~= "") and state.Title or "Unknown Title"
	artistLabel.Text = (type(state.Artist) == "string" and state.Artist ~= "") and state.Artist or "Unknown Artist"
	statusLabel.Text = "Playing"
end

-- Connect BEFORE requesting the snapshot, so we don't miss a track change
-- that happens while GetMusicState is in flight.
musicStateChanged.OnClientEvent:Connect(function(state)
	applyState(state)
end)

task.spawn(function()
	local ok, snapshot = pcall(function()
		return getMusicState:InvokeServer()
	end)
	if ok and snapshot then
		applyState(snapshot)
	elseif not ok then
		warn(LOG .. "GetMusicState request failed: " .. tostring(snapshot))
	end
end)

-- ============================================================
-- Local progress update loop. No remote calls here -- purely visual,
-- using the server-provided StartedAt/Duration and local server-time.
-- ============================================================

RunService.RenderStepped:Connect(function()
	if not activeState or not activeState.StartedAt then
		return
	end

	local duration = activeState.Duration
	local elapsed = Workspace:GetServerTimeNow() - activeState.StartedAt

	if type(duration) ~= "number" or duration <= 0 then
		-- Duration not known yet: show 0:00 / 0:00 and an empty bar rather
		-- than dividing by zero.
		progressFill.Size = UDim2.new(0, 0, 1, 0)
		timeLabel.Text = formatTime(math.max(0, elapsed)) .. " / 0:00"
		return
	end

	local clampedElapsed = math.clamp(elapsed, 0, duration)
	local progress = clampedElapsed / duration

	progressFill.Size = UDim2.new(progress, 0, 1, 0)
	timeLabel.Text = formatTime(clampedElapsed) .. " / " .. formatTime(duration)
end)