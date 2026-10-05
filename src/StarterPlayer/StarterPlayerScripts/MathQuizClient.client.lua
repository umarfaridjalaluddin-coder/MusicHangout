-- MathQuizClient (PERMANENT)
-- The on-screen panel for both quiz corners: the maths quiz (MathQuiz) and
-- the Bahasa Melayu quiz (MalayQuiz). Each server script sends one question
-- at a time with four choices over its own remote; this script shows it,
-- sends back the choice the player taps, and shows whether it was right. The
-- correct answer is only revealed by the server after the player has answered.
-- The panel's own wording (buttons, feedback) follows the quiz's language.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WAIT_SECONDS = 60
local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes", WAIT_SECONDS)
if not remotes then
	return
end

-- One entry per quiz: the remote's name and the panel's wording.
local QUIZZES = {
	{
		Remote = "MathQuiz",
		Header = "MATH QUIZ   Question %d of %d",
		Finished = "MATH QUIZ   Finished!",
		Close = "CLOSE",
		Again = "PLAY AGAIN",
		Checking = "Checking...",
		Correct = "Correct! Well done.",
		Wrong = "Not quite. The answer is %s.",
		Score = "You scored %d out of %d",
		Stars = "You earned %d star(s).",
		Loading = "Getting your questions...",
		StayNear = "Stay near the teacher's desk to start.",
		Praise = { "Perfect score! Amazing!", "Great work!", "Good try!", "Keep practising, you can do it!" },
	},
	{
		Remote = "MalayQuiz",
		Header = "KUIZ BAHASA MELAYU   Soalan %d daripada %d",
		Finished = "KUIZ BAHASA MELAYU   Tamat!",
		Close = "TUTUP",
		Again = "MAIN LAGI",
		Checking = "Sedang menyemak...",
		Correct = "Betul! Syabas.",
		Wrong = "Kurang tepat. Jawapannya ialah %s.",
		Score = "Markah kamu %d daripada %d",
		Stars = "Kamu mendapat %d bintang.",
		Loading = "Sedang menyediakan soalan...",
		StayNear = "Berdiri dekat meja guru untuk mula.",
		Praise = { "Markah penuh! Hebat!", "Syabas, bagus sekali!", "Cubaan yang baik!", "Teruskan berlatih, kamu boleh!" },
	},
}

local PANEL = Color3.fromRGB(24, 26, 38)
local CHOICE = Color3.fromRGB(70, 110, 200)
local RIGHT = Color3.fromRGB(70, 180, 110)
local WRONG = Color3.fromRGB(215, 80, 90)
local FADED = Color3.fromRGB(60, 64, 80)
local TEXT = Color3.fromRGB(255, 255, 255)
local LETTERS = { "A", "B", "C", "D" }

-- ============================================================
-- Screen elements
-- ============================================================

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent, name, position, size, font, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent
	return label
end

local gui = Instance.new("ScreenGui")
gui.Name = "MathQuizGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Enabled = false

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.62, 0.78)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 18)
local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MinSize = Vector2.new(300, 300)
panelLimit.MaxSize = Vector2.new(760, 560)
panelLimit.Parent = panel

local header = text(panel, "Header", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.72, 0.08), Enum.Font.GothamBold, Color3.fromRGB(255, 236, 150))
header.TextXAlignment = Enum.TextXAlignment.Left
local topic = text(panel, "Topic", UDim2.fromScale(0.05, 0.115), UDim2.fromScale(0.72, 0.055), Enum.Font.GothamMedium, Color3.fromRGB(160, 205, 255))
topic.TextXAlignment = Enum.TextXAlignment.Left
local question = text(panel, "Question", UDim2.fromScale(0.05, 0.18), UDim2.fromScale(0.9, 0.2), Enum.Font.GothamBold, TEXT)
local feedback = text(panel, "Feedback", UDim2.fromScale(0.05, 0.9), UDim2.fromScale(0.9, 0.07), Enum.Font.GothamBold, TEXT)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.fromScale(0.97, 0.03)
closeButton.Size = UDim2.fromScale(0.16, 0.09)
closeButton.BackgroundColor3 = FADED
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextColor3 = TEXT
closeButton.TextScaled = true
closeButton.Text = "CLOSE"
closeButton.Parent = panel
corner(closeButton, 10)

local choiceButtons = {}
for index = 1, 4 do
	local button = Instance.new("TextButton")
	button.Name = "Choice" .. LETTERS[index]
	button.Position = UDim2.fromScale(0.05, 0.4 + (index - 1) * 0.122)
	button.Size = UDim2.fromScale(0.9, 0.105)
	button.BackgroundColor3 = CHOICE
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextColor3 = TEXT
	button.TextScaled = true
	button.TextWrapped = true
	button.Text = ""
	button.Parent = panel
	corner(button, 12)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.PaddingTop = UDim.new(0.16, 0)
	padding.PaddingBottom = UDim.new(0.16, 0)
	padding.Parent = button
	choiceButtons[index] = button
end

-- Shown on the last screen only.
local againButton = Instance.new("TextButton")
againButton.Name = "PlayAgain"
againButton.AnchorPoint = Vector2.new(0.5, 0)
againButton.Position = UDim2.fromScale(0.5, 0.62)
againButton.Size = UDim2.fromScale(0.5, 0.12)
againButton.BackgroundColor3 = RIGHT
againButton.BorderSizePixel = 0
againButton.Font = Enum.Font.GothamBold
againButton.TextColor3 = TEXT
againButton.TextScaled = true
againButton.Text = "PLAY AGAIN"
againButton.Visible = false
againButton.Parent = panel
corner(againButton, 12)

gui.Parent = player:WaitForChild("PlayerGui")

-- ============================================================
-- Behaviour. `active` is the quiz the panel is currently showing.
-- ============================================================

local active = nil -- { words = entry from QUIZZES, remote = RemoteEvent }
local canAnswer = false
local chosen = nil

local function showChoices(visible)
	for _, button in ipairs(choiceButtons) do
		button.Visible = visible
	end
end

local function onQuestion(quiz, data)
	active = quiz
	local words = quiz.words
	gui.Enabled = true
	againButton.Visible = false
	closeButton.Text = words.Close
	againButton.Text = words.Again
	showChoices(true)
	header.Text = string.format(words.Header, data.Number, data.Total)
	topic.Text = tostring(data.Topic or "")
	question.Text = tostring(data.Text or "")
	feedback.Text = ""
	for index, button in ipairs(choiceButtons) do
		button.BackgroundColor3 = CHOICE
		button.Text = LETTERS[index] .. ".   " .. tostring(data.Choices[index] or "")
	end
	chosen = nil
	canAnswer = true
end

local function onResult(quiz, data)
	if active ~= quiz then
		return
	end
	local words = quiz.words
	for index, button in ipairs(choiceButtons) do
		if index == data.CorrectIndex then
			button.BackgroundColor3 = RIGHT
		elseif index == chosen then
			button.BackgroundColor3 = WRONG
		else
			button.BackgroundColor3 = FADED
		end
	end
	if data.Correct then
		feedback.TextColor3 = RIGHT
		feedback.Text = words.Correct
	else
		feedback.TextColor3 = WRONG
		feedback.Text = string.format(words.Wrong, LETTERS[data.CorrectIndex] or "?")
	end
end

local function onFinished(quiz, data)
	if active ~= quiz then
		return
	end
	local words = quiz.words
	canAnswer = false
	showChoices(false)
	header.Text = words.Finished
	topic.Text = ""
	local praise = words.Praise[4]
	if data.Score == data.Total then
		praise = words.Praise[1]
	elseif data.Score >= data.Total * 0.7 then
		praise = words.Praise[2]
	elseif data.Score >= data.Total * 0.5 then
		praise = words.Praise[3]
	end
	question.Text = string.format(words.Score, data.Score, data.Total) .. "\n" .. praise
	feedback.TextColor3 = Color3.fromRGB(255, 236, 150)
	feedback.Text = string.format(words.Stars, data.Stars)
	againButton.Visible = true
end

for index, button in ipairs(choiceButtons) do
	button.Activated:Connect(function()
		if not canAnswer or not active then
			return
		end
		canAnswer = false
		chosen = index
		button.BackgroundColor3 = FADED
		feedback.TextColor3 = TEXT
		feedback.Text = active.words.Checking
		active.remote:FireServer("Answer", index)
	end)
end

closeButton.Activated:Connect(function()
	canAnswer = false
	gui.Enabled = false
	if active then
		active.remote:FireServer("Quit")
	end
end)

againButton.Activated:Connect(function()
	if not active then
		return
	end
	againButton.Visible = false
	question.Text = active.words.Loading
	feedback.Text = active.words.StayNear
	active.remote:FireServer("Start")
end)

-- Connect each quiz as its remote appears. A quiz whose server script is not
-- in the game is simply skipped.
for _, words in ipairs(QUIZZES) do
	task.spawn(function()
		local remote = remotes:WaitForChild(words.Remote, WAIT_SECONDS)
		if not remote then
			return
		end
		local quiz = { words = words, remote = remote }
		remote.OnClientEvent:Connect(function(kind, data)
			if type(data) ~= "table" then
				return
			end
			if kind == "Question" then
				onQuestion(quiz, data)
			elseif kind == "Result" then
				onResult(quiz, data)
			elseif kind == "Finished" then
				onFinished(quiz, data)
			end
		end)
	end)
end
