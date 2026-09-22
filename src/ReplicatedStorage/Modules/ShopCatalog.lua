-- ShopCatalog (PERMANENT)
-- Configuration only. No purchase logic here. ShopServer is the sole
-- authority on price/validity -- this module is read by both client
-- (for display) and server (for validation), but only the server's
-- read of it is trusted.

local ShopCatalog = {
	{
		Id = "neon_blue",
		Name = "Neon Blue",
		Description = "A cool blue name glow.",
		Type = "NameColor",
		Price = 100,
		DisplayColor = Color3.fromRGB(80, 170, 255),
	},
	{
		Id = "neon_purple",
		Name = "Neon Purple",
		Description = "A vivid purple name glow.",
		Type = "NameColor",
		Price = 150,
		DisplayColor = Color3.fromRGB(190, 100, 255),
	},
	{
		Id = "dance_glow",
		Name = "Dance Glow",
		Description = "A soft glow that follows you on the floor.",
		Type = "Aura",
		Price = 250,
		DisplayColor = Color3.fromRGB(255, 255, 255),
	},
	{
		Id = "golden_vibe",
		Name = "Golden Vibe",
		Description = "A warm golden aura for VIP energy.",
		Type = "Aura",
		Price = 400,
		DisplayColor = Color3.fromRGB(255, 200, 80),
	},
}

return ShopCatalog