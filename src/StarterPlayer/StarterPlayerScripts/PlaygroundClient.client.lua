-- PlaygroundClient (PERMANENT)
-- Makes the playground trampolines bouncy for the local player. The server
-- (PlaygroundBuilder) marks each trampoline pad with a BouncePower attribute;
-- this script launches the local character upward when it touches one. Done on
-- the client because the player's own device controls their character's movement.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WAIT_SECONDS = 60
local COOLDOWN = 0.35

local player = Players.LocalPlayer

local environment = Workspace:WaitForChild("Environment", WAIT_SECONDS)
local playground = environment and environment:WaitForChild("Playground", WAIT_SECONDS)
if not playground then
	return
end

local hooked = {}
local lastBounce = 0

local function hook(pad)
	if hooked[pad] or not pad:IsA("BasePart") then
		return
	end
	if type(pad:GetAttribute("BouncePower")) ~= "number" then
		return
	end
	hooked[pad] = true

	pad.Touched:Connect(function(hit)
		local character = player.Character
		if not character or not hit:IsDescendantOf(character) then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		local now = os.clock()
		if now - lastBounce < COOLDOWN then
			return
		end
		lastBounce = now
		local power = pad:GetAttribute("BouncePower")
		if type(power) ~= "number" then
			return
		end
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, power, velocity.Z)
	end)
end

local function watch(instance)
	if not instance:IsA("BasePart") then
		return
	end
	hook(instance)
	-- The attribute can arrive just after the part does.
	instance:GetAttributeChangedSignal("BouncePower"):Connect(function()
		hook(instance)
	end)
end

for _, descendant in ipairs(playground:GetDescendants()) do
	watch(descendant)
end
playground.DescendantAdded:Connect(watch)
