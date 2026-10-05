-- PlaneClient (PERMANENT)
-- Passenger screen for the airport's plane. While the local player sits in a
-- plane seat it shows the cabin crew announcement and a seat belt button.
-- Pressing the button asks the server to fasten or unfasten the belt on the
-- player's own seat. With the belt fastened in flight, jumping out of the seat
-- is switched off until the plane has landed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WAIT_SECONDS = 60
local player = Players.LocalPlayer

local environment = Workspace:WaitForChild("Environment", WAIT_SECONDS)
local airport = environment and environment:WaitForChild("Airport", WAIT_SECONDS)
local plane = airport and airport:WaitForChild("Plane", WAIT_SECONDS)
local remotes = ReplicatedStorage:WaitForChild("Remotes", WAIT_SECONDS)
local beltRemote = remotes and remotes:WaitForChild("PlaneSeatBelt", WAIT_SECONDS)
if not plane or not beltRemote then
	return
end

local ORANGE = Color3.fromRGB(255, 160, 60)
local GREEN = Color3.fromRGB(90, 200, 120)
local PANEL = Color3.fromRGB(20, 22, 32)

-- ============================================================
-- Screen elements
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name = "PlaneGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Enabled = false

local banner = Instance.new("Frame")
banner.Name = "Announcement"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.fromScale(0.5, 0.13)
banner.Size = UDim2.fromScale(0.56, 0.1)
banner.BackgroundColor3 = PANEL
banner.BackgroundTransparency = 0.15
banner.BorderSizePixel = 0
banner.Parent = gui
local bannerLimit = Instance.new("UISizeConstraint")
bannerLimit.MinSize = Vector2.new(260, 46)
bannerLimit.MaxSize = Vector2.new(680, 76)
bannerLimit.Parent = banner
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0.25, 0)
bannerCorner.Parent = banner

local bannerText = Instance.new("TextLabel")
bannerText.Name = "Text"
bannerText.AnchorPoint = Vector2.new(0.5, 0.5)
bannerText.Position = UDim2.fromScale(0.5, 0.5)
bannerText.Size = UDim2.fromScale(0.94, 0.8)
bannerText.BackgroundTransparency = 1
bannerText.TextColor3 = Color3.fromRGB(255, 255, 255)
bannerText.Font = Enum.Font.GothamMedium
bannerText.TextScaled = true
bannerText.TextWrapped = true
bannerText.Text = ""
bannerText.Parent = banner

local button = Instance.new("TextButton")
button.Name = "SeatBeltButton"
button.AnchorPoint = Vector2.new(0, 0.5)
button.Position = UDim2.fromScale(0.02, 0.5)
button.Size = UDim2.fromScale(0.2, 0.11)
button.BackgroundColor3 = ORANGE
button.BorderSizePixel = 0
button.AutoButtonColor = true
button.TextColor3 = Color3.fromRGB(20, 20, 30)
button.Font = Enum.Font.GothamBold
button.TextScaled = true
button.TextWrapped = true
button.Text = "FASTEN SEAT BELT"
button.Parent = gui
local buttonLimit = Instance.new("UISizeConstraint")
buttonLimit.MinSize = Vector2.new(150, 50)
buttonLimit.MaxSize = Vector2.new(260, 76)
buttonLimit.Parent = button
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0.25, 0)
buttonCorner.Parent = button
local buttonPadding = Instance.new("UIPadding")
buttonPadding.PaddingLeft = UDim.new(0.06, 0)
buttonPadding.PaddingRight = UDim.new(0.06, 0)
buttonPadding.PaddingTop = UDim.new(0.14, 0)
buttonPadding.PaddingBottom = UDim.new(0.14, 0)
buttonPadding.Parent = button

gui.Parent = player:WaitForChild("PlayerGui")

-- ============================================================
-- State
-- ============================================================

local humanoid = nil
local currentSeat = nil
local seatConnection = nil
local savedJump = nil -- the humanoid's normal jump settings while it is locked

-- Locks or frees the passenger's jump, which is how a player leaves a seat.
local function setSeatLocked(locked)
	if not humanoid then
		return
	end
	if locked and not savedJump then
		savedJump = { Power = humanoid.JumpPower, Height = humanoid.JumpHeight }
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	elseif not locked and savedJump then
		humanoid.JumpPower = savedJump.Power
		humanoid.JumpHeight = savedJump.Height
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		savedJump = nil
	end
end

local function planeSeat()
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("Seat") and seat:IsDescendantOf(plane) then
		return seat
	end
	return nil
end

local function refresh()
	local seat = planeSeat()

	-- Follow the BeltOn attribute of whichever seat we are in.
	if seat ~= currentSeat then
		if seatConnection then
			seatConnection:Disconnect()
			seatConnection = nil
		end
		currentSeat = seat
		if seat then
			seatConnection = seat:GetAttributeChangedSignal("BeltOn"):Connect(refresh)
		end
	end

	gui.Enabled = seat ~= nil

	local phase = plane:GetAttribute("Phase")
	local beltOn = seat ~= nil and seat:GetAttribute("BeltOn") == true
	local inFlight = phase == "Flight"

	-- A fastened belt keeps the passenger seated while the plane is flying.
	setSeatLocked(beltOn and inFlight)
	if not seat then
		return
	end

	local announcement = plane:GetAttribute("Announcement")
	bannerText.Text = "CABIN CREW:  " .. (type(announcement) == "string" and announcement or "")

	if beltOn then
		button.BackgroundColor3 = GREEN
		button.Text = inFlight and "SEAT BELT FASTENED" or "UNFASTEN SEAT BELT"
	else
		button.BackgroundColor3 = ORANGE
		button.Text = "FASTEN SEAT BELT"
	end
end

button.Activated:Connect(function()
	local seat = planeSeat()
	if not seat then
		return
	end
	local beltOn = seat:GetAttribute("BeltOn") == true
	if beltOn and plane:GetAttribute("Phase") == "Flight" then
		return -- stays fastened until the plane has landed
	end
	beltRemote:FireServer(not beltOn)
end)

plane:GetAttributeChangedSignal("Phase"):Connect(refresh)
plane:GetAttributeChangedSignal("Announcement"):Connect(refresh)

local function onCharacter(character)
	savedJump = nil -- a new character starts with normal jump settings
	humanoid = character:WaitForChild("Humanoid", WAIT_SECONDS)
	if not humanoid then
		return
	end
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(refresh)
	refresh()
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
