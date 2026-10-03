-- BirthdayScreen (PERMANENT)
-- Drives Workspace.Environment.Architecture.BirthdayScreen, which
-- EnvironmentBuilder creates. Two modes, chosen from BirthdaySlides:
--   1. Image slideshow, when Slides lists at least one image.
--   2. Code-only birthday show (animated text and balloons), when Slides is
--      empty and Messages has at least one line. Nothing is uploaded.
-- No VideoFrame, no Robux spend. Find-or-create throughout, so a rerun updates
-- in place and never duplicates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LOG = "[BirthdayScreen] "
local WAIT_SECONDS = 30

local COLOR_CYAN = Color3.fromRGB(60, 220, 255)
local COLOR_MAGENTA = Color3.fromRGB(230, 70, 220)
local COLOR_WARM = Color3.fromRGB(255, 190, 120)
local COLOR_STRING = Color3.fromRGB(200, 200, 210)

local config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BirthdaySlides"))

-- Keep only well-formed slides so one bad entry cannot stop the show.
local slides = {}
for index, slide in ipairs(config.Slides or {}) do
	if type(slide) == "table" and type(slide.ImageId) == "string" and slide.ImageId ~= "" then
		table.insert(slides, slide)
	else
		warn(LOG .. "Skipping slide " .. index .. ": missing ImageId.")
	end
end

local messages = {}
for _, line in ipairs(config.Messages or {}) do
	if type(line) == "string" and line ~= "" then
		table.insert(messages, line)
	end
end

if #slides == 0 and #messages == 0 then
	print(LOG .. "No slides and no messages configured. Screen keeps its title.")
	return
end

local function waitFor(parent, name)
	local child = parent:WaitForChild(name, WAIT_SECONDS)
	if not child then
		warn(LOG .. "Timed out waiting for " .. parent:GetFullName() .. "." .. name)
	end
	return child
end

local function findOrCreate(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and child:IsA(className) then
		return child
	end
	child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local environment = waitFor(Workspace, "Environment")
local architecture = environment and waitFor(environment, "Architecture")
local screen = architecture and waitFor(architecture, "BirthdayScreen")
local gui = screen and waitFor(screen, "Label")
if not gui then
	warn(LOG .. "BirthdayScreen not found. Nothing started.")
	return
end

-- The title is hidden while either mode plays so it does not overlap it.
local title = gui:FindFirstChild("Text")
if title then
	title.Visible = false
end

-- ============================================================
-- Mode 1: image slideshow
-- ============================================================

local function runSlideshow()
	local image = findOrCreate(gui, "ImageLabel", "SlideImage")
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.ImageTransparency = 1
	image.ZIndex = 2

	local caption = findOrCreate(gui, "TextLabel", "SlideCaption")
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.fromScale(0.5, 0.97)
	caption.Size = UDim2.fromScale(0.7, 0.16)
	caption.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	caption.BackgroundTransparency = 0.35
	caption.TextColor3 = Color3.fromRGB(255, 255, 255)
	caption.Font = Enum.Font.GothamBold
	caption.TextScaled = true
	caption.ZIndex = 3

	local secondsPerSlide = tonumber(config.SecondsPerSlide) or 5
	local fadeInfo = TweenInfo.new(tonumber(config.FadeSeconds) or 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local function fade(transparency)
		local tween = TweenService:Create(image, fadeInfo, { ImageTransparency = transparency })
		tween:Play()
		tween.Completed:Wait()
	end

	print(LOG .. "Slideshow started with " .. #slides .. " slide(s).")

	while screen.Parent do
		for _, slide in ipairs(slides) do
			image.Image = slide.ImageId
			local text = type(slide.Caption) == "string" and slide.Caption or ""
			caption.Text = text
			caption.Visible = text ~= ""
			fade(0)
			task.wait(secondsPerSlide)
			fade(1)
		end
	end
end

-- ============================================================
-- Mode 2: code-only birthday show
-- ============================================================

-- Balloons rise in the left and right thirds of the screen. The middle of the
-- lower screen is left empty because the DJ booth stands in front of it.
local BALLOONS = {
	{ X = 0.06, Seconds = 9, Delay = 0, Color = COLOR_CYAN },
	{ X = 0.16, Seconds = 7, Delay = 2.5, Color = COLOR_MAGENTA },
	{ X = 0.26, Seconds = 8, Delay = 5, Color = COLOR_WARM },
	{ X = 0.74, Seconds = 8, Delay = 1, Color = COLOR_WARM },
	{ X = 0.84, Seconds = 9, Delay = 4, Color = COLOR_CYAN },
	{ X = 0.94, Seconds = 7, Delay = 6, Color = COLOR_MAGENTA },
}

local function runBirthdayShow()
	local show = findOrCreate(gui, "Frame", "BirthdayShow")
	show.Size = UDim2.fromScale(1, 1)
	show.BackgroundTransparency = 1
	show.ClipsDescendants = true
	show.ZIndex = 2

	for index, spec in ipairs(BALLOONS) do
		local balloon = findOrCreate(show, "Frame", "Balloon" .. index)
		balloon.AnchorPoint = Vector2.new(0.5, 0.5)
		balloon.Size = UDim2.fromScale(0.08, 0.36)
		balloon.Position = UDim2.fromScale(spec.X, 1.3)
		balloon.BackgroundColor3 = spec.Color
		balloon.BorderSizePixel = 0
		balloon.ZIndex = 2
		findOrCreate(balloon, "UICorner", "Round").CornerRadius = UDim.new(0.5, 0)

		local cord = findOrCreate(balloon, "Frame", "Cord")
		cord.AnchorPoint = Vector2.new(0.5, 0)
		cord.Position = UDim2.fromScale(0.5, 1)
		cord.Size = UDim2.fromScale(0.06, 0.6)
		cord.BackgroundColor3 = COLOR_STRING
		cord.BorderSizePixel = 0
		cord.ZIndex = 2

		local riseInfo = TweenInfo.new(spec.Seconds, Enum.EasingStyle.Linear)
		task.spawn(function()
			task.wait(spec.Delay)
			while balloon.Parent do
				balloon.Position = UDim2.fromScale(spec.X, 1.3)
				local tween = TweenService:Create(balloon, riseInfo, { Position = UDim2.fromScale(spec.X, -0.45) })
				tween:Play()
				tween.Completed:Wait()
			end
		end)
	end

	-- Text sits in the top band of the screen, above the DJ booth.
	local message = findOrCreate(show, "TextLabel", "Message")
	message.AnchorPoint = Vector2.new(0.5, 0)
	message.Position = UDim2.fromScale(0.5, 0.02)
	message.Size = UDim2.fromScale(0.96, 0.3)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.GothamBold
	message.TextScaled = true
	message.TextTransparency = 1
	message.ZIndex = 3

	local colors = { COLOR_CYAN, COLOR_MAGENTA, COLOR_WARM }
	local messageSeconds = tonumber(config.MessageSeconds) or 4
	local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local function fadeText(transparency)
		local tween = TweenService:Create(message, fadeInfo, { TextTransparency = transparency })
		tween:Play()
		tween.Completed:Wait()
	end

	print(LOG .. "Birthday show started with " .. #messages .. " message(s).")

	local step = 0
	while screen.Parent do
		message.Text = messages[step % #messages + 1]
		message.TextColor3 = colors[step % #colors + 1]
		fadeText(0)
		task.wait(messageSeconds)
		fadeText(1)
		step += 1
	end
end

if #slides > 0 then
	runSlideshow()
else
	runBirthdayShow()
end
