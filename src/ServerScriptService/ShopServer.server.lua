-- ShopServer (PERMANENT)
-- Server-authoritative Coins, ownership, and equip state for the shop.
-- DEVELOPMENT CURRENCY NOTICE: Coins are a session-only development
-- currency. There is no DataStore persistence in Phase 5 -- balances,
-- ownership, and equips reset whenever the server restarts. This is
-- intentional and documented; production persistence is a later phase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(ReplicatedStorage.Modules.ShopCatalog)

local LOG = "[ShopServer] "

local STARTING_COINS = 1000 -- centrally configurable starting balance
local RATE_LIMIT_SECONDS = 0.5 -- minimum time between a player's purchase/equip calls

-- ============================================================
-- Build a lookup table from the catalog for fast, authoritative validation.
-- ============================================================

local catalogById = {}
for _, item in ipairs(ShopCatalog) do
	catalogById[item.Id] = item
end

-- ============================================================
-- Ensure ReplicatedStorage.Remotes exists (shared with MusicServer's folder)
-- ============================================================

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
	print(LOG .. "Created ReplicatedStorage.Remotes (was missing).")
end

local function ensureRemoteFunction(name)
	local existing = remotesFolder:FindFirstChild(name)
	if existing and not existing:IsA("RemoteFunction") then
		warn(LOG .. "Remotes." .. name .. " exists but is a " .. existing.ClassName .. ", not a RemoteFunction. Removing it.")
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new("RemoteFunction")
		existing.Name = name
		existing.Parent = remotesFolder
		print(LOG .. "Created " .. name .. " RemoteFunction.")
	else
		print(LOG .. "Reusing existing " .. name .. " RemoteFunction.")
	end
	return existing
end

local getShopState = ensureRemoteFunction("GetShopState")
local purchaseShopItem = ensureRemoteFunction("PurchaseShopItem")
local equipShopItem = ensureRemoteFunction("EquipShopItem")

-- ============================================================
-- Per-player session state (NOT persisted -- resets on server restart)
-- ============================================================

local sessions = {} -- [player] = { Coins, OwnedItems = {[id]=true}, Equipped = {NameColor=id/nil, Aura=id/nil}, LastActionAt }

local function newSession()
	return {
		Coins = STARTING_COINS,
		OwnedItems = {},
		Equipped = { NameColor = nil, Aura = nil },
		LastActionAt = 0,
	}
end

Players.PlayerAdded:Connect(function(player)
	sessions[player] = newSession()
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

-- Handle players already in-game if this script is running after they joined
-- (e.g. during Studio Play testing where PlayerAdded may have already fired).
for _, player in ipairs(Players:GetPlayers()) do
	if not sessions[player] then
		sessions[player] = newSession()
	end
end

-- ============================================================
-- Helpers
-- ============================================================

-- Returns a display-safe copy of a session's public state.
local function publicState(session)
	local ownedCopy = {}
	for id in pairs(session.OwnedItems) do
		ownedCopy[id] = true
	end
	return {
		Coins = session.Coins,
		OwnedItems = ownedCopy,
		Equipped = {
			NameColor = session.Equipped.NameColor,
			Aura = session.Equipped.Aura,
		},
	}
end

-- Simple per-player rate limit shared by purchase/equip. Returns true if
-- the action is allowed right now (and updates LastActionAt), false if
-- the player is calling too fast.
local function checkRateLimit(session)
	local now = os.clock()
	if now - session.LastActionAt < RATE_LIMIT_SECONDS then
		return false
	end
	session.LastActionAt = now
	return true
end

-- ============================================================
-- GetShopState: read-only snapshot.
-- ============================================================

getShopState.OnServerInvoke = function(player)
	local session = sessions[player]
	if not session then
		return { Coins = 0, OwnedItems = {}, Equipped = { NameColor = nil, Aura = nil } }
	end
	return publicState(session)
end

-- ============================================================
-- PurchaseShopItem: client sends only an itemId. Server does everything else.
-- ============================================================

purchaseShopItem.OnServerInvoke = function(player, itemId)
	local session = sessions[player]
	if not session then
		return { Success = false, Message = "Session not found." }
	end

	if not checkRateLimit(session) then
		return { Success = false, Message = "Please wait." }
	end

	if type(itemId) ~= "string" or itemId == "" or #itemId > 64 then
		warn(LOG .. player.Name .. " sent an invalid PurchaseShopItem itemId (type/shape rejected).")
		return { Success = false, Message = "Invalid item." }
	end

	local item = catalogById[itemId]
	if not item then
		warn(LOG .. player.Name .. " attempted to purchase unknown item: " .. tostring(itemId))
		return { Success = false, Message = "Item unavailable." }
	end

	if session.OwnedItems[itemId] then
		return { Success = false, Message = "Already owned.", Coins = session.Coins, ItemId = itemId }
	end

	if session.Coins < item.Price then
		return { Success = false, Message = "Not enough Coins.", Coins = session.Coins }
	end

	-- Validate fully above, then commit exactly once: deduct, then grant.
	session.Coins -= item.Price
	session.OwnedItems[itemId] = true

	print(LOG .. player.Name .. " purchased " .. item.Name .. " for " .. item.Price .. " Coins.")

	return {
		Success = true,
		Message = "Purchased " .. item.Name,
		Coins = session.Coins,
		ItemId = itemId,
	}
end

-- ============================================================
-- Minimal cosmetic application: Aura -> Highlight on the character.
-- Lightweight, native, no particles. Reapplies on respawn.
-- ============================================================

local function applyAuraHighlight(player, character, itemId)
	local existing = character:FindFirstChild("ShopAuraHighlight")
	if existing then
		existing:Destroy()
	end

	if not itemId then
		return
	end

	local item = catalogById[itemId]
	if not item or item.Type ~= "Aura" then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ShopAuraHighlight"
	highlight.FillColor = item.DisplayColor or Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = item.DisplayColor or Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local session = sessions[player]
		if session then
			applyAuraHighlight(player, character, session.Equipped.Aura)
		end
	end)
end)

-- ============================================================
-- EquipShopItem: client sends only an itemId. Server validates ownership/type,
-- updates equipped state, and reapplies the Aura highlight in one place.
-- ============================================================

equipShopItem.OnServerInvoke = function(player, itemId)
	local session = sessions[player]
	if not session then
		return { Success = false, Message = "Session not found." }
	end

	if not checkRateLimit(session) then
		return { Success = false, Message = "Please wait." }
	end

	if type(itemId) ~= "string" or itemId == "" or #itemId > 64 then
		warn(LOG .. player.Name .. " sent an invalid EquipShopItem itemId (type/shape rejected).")
		return { Success = false, Message = "Invalid item." }
	end

	local item = catalogById[itemId]
	if not item then
		warn(LOG .. player.Name .. " attempted to equip unknown item: " .. tostring(itemId))
		return { Success = false, Message = "Item unavailable." }
	end

	if not session.OwnedItems[itemId] then
		return { Success = false, Message = "You don't own this item." }
	end

	if item.Type ~= "NameColor" and item.Type ~= "Aura" then
		warn(LOG .. "Item " .. itemId .. " has an unrecognized Type: " .. tostring(item.Type))
		return { Success = false, Message = "Item unavailable." }
	end

	-- One equipped item per category: this simply overwrites the previous
	-- equipped id in that category, if any.
	session.Equipped[item.Type] = itemId

	print(LOG .. player.Name .. " equipped " .. item.Name .. " (" .. item.Type .. ").")

	local character = player.Character
	if character then
		applyAuraHighlight(player, character, session.Equipped.Aura)
	end

	return {
		Success = true,
		Message = "Equipped " .. item.Name,
		Equipped = {
			NameColor = session.Equipped.NameColor,
			Aura = session.Equipped.Aura,
		},
	}
end

print(LOG .. "ShopServer ready. Starting balance: " .. STARTING_COINS .. " Coins (session only, not persisted).")