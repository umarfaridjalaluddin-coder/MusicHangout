-- BirthdaySlides (PERMANENT)
-- Slideshow configuration for the stage BirthdayScreen. Playback logic lives in
-- BirthdayScreen.server.lua, not here.
-- To add a slide: copy the example line into Slides and fill in ImageId/Caption.
-- ImageId must be an image you uploaded to Roblox that has passed moderation.
-- With no slides listed, the screen plays the code-only birthday show below
-- (animated text and balloons, nothing uploaded). Empty the Messages list to
-- keep the plain "MUSIC HANGOUT" title instead.

local BirthdaySlides = {
	-- Lines of the code-only show, displayed one at a time in this order.
	Messages = {
		"HAPPY BIRTHDAY",
		"QISYA AZ-ZAHRA",
		"DARIPADA BABA",
	},
	MessageSeconds = 4, -- how long each line stays on screen
	SecondsPerSlide = 5, -- how long each image stays fully visible
	FadeSeconds = 0.6, -- fade out / fade in time between images
	Slides = {
		-- { ImageId = "rbxassetid://0000000000", Caption = "Happy Birthday!" },
		-- (moderated by Roblox) { ImageId = "rbxassetid://131263657977823", Caption = "" },
		-- (moderated by Roblox) { ImageId = "rbxassetid://121566497838102", Caption = "" },
		-- (moderated by Roblox) { ImageId = "rbxassetid://98892334637491", Caption = "" },
		-- (moderated by Roblox) { ImageId = "rbxassetid://72294684242164", Caption = "" },
	},
}

return BirthdaySlides
