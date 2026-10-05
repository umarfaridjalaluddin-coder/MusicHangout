-- BirthdayVIPOutfits (PERMANENT)
-- The three Birthday VIP dress-up styles. Everything a style can change is
-- listed here; the client only ever sends a style KEY ("BirthdayStar",
-- "RoyalVIP", "NeonPartyKid" or "Restore") and the server looks the rest up.
--
-- MARKETPLACE ASSETS
-- Every asset slot below is 0 or an empty table on purpose. No IDs have been
-- chosen yet, and none may be guessed. While a slot is empty the player keeps
-- whatever they are already wearing in that slot -- nothing is taken off.
-- To use a real item: replace the 0 (or add to the table) with an approved,
-- child-appropriate Roblox Marketplace asset ID.
--
-- Until then each style still shows: code-built costume pieces (Costume) and
-- a small sparkle (Aura), neither of which needs any asset.

local Outfits = {
	-- Card order in the wardrobe.
	Order = { "BirthdayStar", "RoyalVIP", "NeonPartyKid" },

	BirthdayStar = {
		DisplayName = "Birthday Star",
		Description = "Tiara, bow & party sash",
		Colors = {
			Color3.fromRGB(255, 182, 213), -- pastel pink
			Color3.fromRGB(205, 180, 255), -- lavender
			Color3.fromRGB(255, 221, 130), -- soft gold
		},
		Shirt = 0, -- Replace with approved Roblox Marketplace asset ID
		Pants = 0, -- Replace with approved Roblox Marketplace asset ID
		HatAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		HairAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		BackAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		FrontAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		NeckAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		Costume = "BirthdayStar",
		Aura = { Rate = 3, Colors = { Color3.fromRGB(255, 200, 225), Color3.fromRGB(255, 240, 180) } },
	},

	RoyalVIP = {
		DisplayName = "Royal VIP",
		Description = "Little crown & royal cape",
		Colors = {
			Color3.fromRGB(255, 255, 255), -- white
			Color3.fromRGB(255, 215, 110), -- gold
			Color3.fromRGB(200, 170, 255), -- soft purple
		},
		Shirt = 0, -- Replace with approved Roblox Marketplace asset ID
		Pants = 0, -- Replace with approved Roblox Marketplace asset ID
		HatAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		HairAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		BackAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		FrontAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		NeckAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		Costume = "RoyalVIP",
		Aura = { Rate = 3, Colors = { Color3.fromRGB(255, 225, 130), Color3.fromRGB(255, 250, 220) } },
	},

	NeonPartyKid = {
		DisplayName = "Neon Party Kid",
		Description = "Headphones & glow bracelets",
		Colors = {
			Color3.fromRGB(150, 235, 255), -- pastel cyan
			Color3.fromRGB(190, 150, 255), -- purple
			Color3.fromRGB(255, 160, 215), -- pink
		},
		Shirt = 0, -- Replace with approved Roblox Marketplace asset ID
		Pants = 0, -- Replace with approved Roblox Marketplace asset ID
		HatAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		HairAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		BackAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		FrontAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		NeckAccessories = {}, -- Replace with approved Roblox Marketplace asset IDs
		Costume = "NeonPartyKid",
		Aura = { Rate = 3, Colors = { Color3.fromRGB(150, 235, 255), Color3.fromRGB(215, 160, 255) } },
	},
}

return Outfits
