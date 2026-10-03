-- SongList (PERMANENT)
-- Central playlist configuration. Playback logic lives in MusicServer, not here.
-- To add a track later: copy a table below and fill in Title/Artist/SoundId.

local SongList = {
	{
		Title = "Happy Birthday Ballad", -- Roblox Creator Store asset 9043578323 (30-second version)
		Artist = "", -- fill in the creator name shown in the Toolbox; blank shows "Unknown Artist"
		SoundId = "rbxassetid://9043578323",
	},
	{
		Title = "City Lights", -- DEVELOPMENT PLACEHOLDER TRACK. Replace with owned/licensed audio before release.
		Artist = "Lofi na Varanda",
		SoundId = "rbxassetid://135929322091355",
	},
}

return SongList