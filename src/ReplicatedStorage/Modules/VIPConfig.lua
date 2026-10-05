-- VIPConfig (PERMANENT)
-- Central Birthday VIP Game Pass configuration. GamePassId <= 0 means
-- "not configured" -- VIPServer treats that as a safe disabled state and
-- never calls MarketplaceService with it.

local VIPConfig = {
	GamePassId = 2005977585, -- "Birthday VIP" pass on Qisya's Birthday Party
	DisplayName = "Birthday VIP",
	Benefits = {
		"Party outfit pack",
		"VIP Lounge Access",
		"VIP Tag",
	},

	-- Accounts that get VIP for free (checked on the server by username).
	-- The birthday girl and Baba should not have to buy their own party pass.
	FreeVIPUserNames = {
		"P3tani89",
		"Qisyaaaaaaa6",
	},

	-- Outfit pieces a VIP can switch on and off. Id is what the client sends;
	-- the server only accepts Ids from this list. Slot = pieces that cannot
	-- be worn together (one hat at a time).
	Outfits = {
		{ Id = "PartyHat", Label = "Party Hat", Slot = "Head" },
		{ Id = "Crown", Label = "Crown", Slot = "Head" },
		{ Id = "UnicornHorn", Label = "Unicorn Horn" },
		{ Id = "RainbowCape", Label = "Rainbow Cape" },
		{ Id = "SparkleTrail", Label = "Sparkle Trail" },
	},
}

return VIPConfig
