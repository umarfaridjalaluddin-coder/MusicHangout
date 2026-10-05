-- MalayQuiz (PERMANENT)
-- A Bahasa Melayu quiz corner south-west of the lobby, under
-- Workspace.Environment.MalayCorner. It works exactly like the maths corner
-- (MathQuiz): a player walks to the teacher's desk and starts a quiz of 10
-- multiple-choice questions drawn at random from MalayQuestions (Tahun 5).
-- The questions appear on that player's screen through the same on-screen
-- panel (MathQuizClient), in Malay. The server chooses the questions, keeps
-- the answers and does the marking. Each correct answer earns 1 Star, with a
-- bonus for a perfect score, and a board shows the last and best scores.
-- Idempotent: every part is found by name or created. Adds only its own objects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local QUESTIONS = require(script.Parent:WaitForChild("MalayQuestions"))

local LOG = "[MalayQuiz] "

local QUESTIONS_PER_QUIZ = 10
local PERFECT_BONUS = 5
local NEXT_QUESTION_DELAY = 1.8
local START_DISTANCE = 30 -- how close to the desk a player must be to start

-- Centre of the corner. The ground's top surface is at Y=1.
local CX, CZ = -42, 15
local FLOOR_TOP = 1.3

local MAT_PLASTIC = Enum.Material.SmoothPlastic
local FLOOR = Color3.fromRGB(235, 225, 200)
local WOOD = Color3.fromRGB(150, 110, 75)
local BOARD = Color3.fromRGB(60, 45, 90)
local DARK = Color3.fromRGB(10, 10, 14)
local WHITE = Color3.fromRGB(245, 245, 250)
local LEMON = Color3.fromRGB(255, 236, 150)
local SKY = Color3.fromRGB(160, 205, 255)
local PINK = Color3.fromRGB(255, 170, 215)
local MINT = Color3.fromRGB(160, 232, 190)

-- ============================================================
-- Helpers
-- ============================================================

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function make(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and child:IsA(className) then
		return child
	end
	child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function block(parent, name, size, cframe, color, canCollide)
	local p = make(parent, "Part", name)
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = MAT_PLASTIC
	p.CanCollide = canCollide ~= false
	p.CanTouch = false
	return p
end

local function addText(part, text, textColor)
	local gui = make(part, "SurfaceGui", "Label")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local label = make(gui, "TextLabel", "Text")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	return label
end

-- ============================================================
-- The corner: floor, blackboard, teacher's desk, benches, canopy
-- ============================================================

local environment = ensureFolder(Workspace, "Environment")
local corner = ensureFolder(environment, "MalayCorner")

block(corner, "Floor", Vector3.new(22, 0.3, 18), CFrame.new(CX, FLOOR_TOP - 0.15, CZ), FLOOR)

-- Short path strip from the lobby's west edge.
do
	local from = Vector3.new(-20, 1.05, 12)
	local to = Vector3.new(CX + 11, 1.05, CZ + 3)
	local strip = block(corner, "PathToMalayCorner", Vector3.new(4, 0.1, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), LEMON, false)
	strip.Material = Enum.Material.Neon
end

-- Blackboard at the west end, facing the lobby (+X).
local boardPosition = Vector3.new(CX - 10.5, FLOOR_TOP + 6, CZ)
local facingLobby = CFrame.lookAt(boardPosition, boardPosition + Vector3.xAxis)
block(corner, "BlackboardFrame", Vector3.new(15, 7, 0.4), facingLobby * CFrame.new(0, 0, 0.25), WOOD)
local blackboard = block(corner, "Blackboard", Vector3.new(14, 6, 0.3), facingLobby, BOARD, false)
addText(blackboard, "KUIZ BAHASA MELAYU\nTahun 5  -  10 soalan\nPergi ke meja guru untuk mula", WHITE)
block(corner, "BoardPostNorth", Vector3.new(0.6, 9.5, 0.6), CFrame.new(CX - 10.7, FLOOR_TOP + 4.75, CZ - 7.2), WOOD)
block(corner, "BoardPostSouth", Vector3.new(0.6, 9.5, 0.6), CFrame.new(CX - 10.7, FLOOR_TOP + 4.75, CZ + 7.2), WOOD)

-- Scoreboard beside the blackboard.
local scorePosition = Vector3.new(CX - 10.5, FLOOR_TOP + 11.2, CZ)
local scoreBoard = block(corner, "ScoreBoard", Vector3.new(14, 2.6, 0.3), CFrame.lookAt(scorePosition, scorePosition + Vector3.xAxis), DARK, false)
local scoreLabel = addText(scoreBoard, "", LEMON)

-- Teacher's desk in front of the blackboard; the quiz starts here.
local desk = block(corner, "TeacherDesk", Vector3.new(2.5, 3, 6), CFrame.new(CX - 6, FLOOR_TOP + 1.5, CZ), SKY)
block(corner, "DeskTop", Vector3.new(3, 0.3, 6.5), CFrame.new(CX - 6, FLOOR_TOP + 3.15, CZ), WOOD)

local prompt = make(desk, "ProximityPrompt", "StartQuiz")
prompt.ObjectText = "Kuiz Bahasa Melayu"
prompt.ActionText = "Mula kuiz"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false

-- Benches for the class.
for row = 1, 3 do
	for side, z in ipairs({ CZ - 4, CZ + 4 }) do
		block(corner, "Bench" .. row .. "_" .. side, Vector3.new(1.6, 1.2, 6), CFrame.new(CX - 1 + row * 3.4, FLOOR_TOP + 0.6, z), (row % 2 == 0) and SKY or MINT)
	end
end

-- Canopy on four posts, with one soft light.
local canopyY = FLOOR_TOP + 13.5
block(corner, "Canopy", Vector3.new(24, 0.5, 20), CFrame.new(CX, canopyY, CZ), PINK)
for index, offset in ipairs({ { -11, -9 }, { 11, -9 }, { -11, 9 }, { 11, 9 } }) do
	local height = canopyY - FLOOR_TOP
	block(corner, "CanopyPost" .. index, Vector3.new(0.6, height, 0.6), CFrame.new(CX + offset[1], FLOOR_TOP + height / 2, CZ + offset[2]), WHITE)
end
local lamp = block(corner, "Lamp", Vector3.new(1.4, 1.4, 1.4), CFrame.new(CX, canopyY - 1.2, CZ), LEMON, false)
lamp.Shape = Enum.PartType.Ball
lamp.Material = Enum.Material.Neon
local light = make(lamp, "PointLight", "Glow")
light.Color = Color3.fromRGB(255, 240, 215)
light.Range = 30
light.Brightness = 0.7

-- ============================================================
-- Scores
-- ============================================================

local function starsValue(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local value = stats:FindFirstChild("Stars")
	if not (value and value:IsA("IntValue")) then
		value = Instance.new("IntValue")
		value.Name = "Stars"
		value.Parent = stats
	end
	return value
end

local lastLine = "Jadilah yang pertama mencuba kuiz ini!"
local bestScore = nil
local bestName = nil

local function refreshScoreBoard()
	local bestLine = bestScore and string.format("TERBAIK: %s  %d/%d", bestName, bestScore, QUESTIONS_PER_QUIZ) or "TERBAIK: belum ada"
	scoreLabel.Text = lastLine .. "\n" .. bestLine
end
refreshScoreBoard()

-- ============================================================
-- Quiz sessions
-- ============================================================

local remotes = ensureFolder(ReplicatedStorage, "Remotes")
local quizRemote = make(remotes, "RemoteEvent", "MalayQuiz")

-- If this script is ever run again, only the newest copy answers players.
local token = tostring(os.clock()) .. "-" .. tostring(math.random(1, 1000000))
corner:SetAttribute("Runner", token)
local function isCurrent()
	return corner:GetAttribute("Runner") == token
end

local random = Random.new()
local sessions = {} -- [player] = { order, number, score, correctIndex, awaiting }

local function nearDesk(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - desk.Position).Magnitude <= START_DISTANCE
end

local function sendQuestion(player)
	local session = sessions[player]
	if not session then
		return
	end
	local entry = QUESTIONS[session.order[session.number]]

	-- Shuffle the four choices; the correct one is first in the bank.
	local slots = { 1, 2, 3, 4 }
	for i = #slots, 2, -1 do
		local j = random:NextInteger(1, i)
		slots[i], slots[j] = slots[j], slots[i]
	end
	local choices = {}
	for position, source in ipairs(slots) do
		choices[position] = entry.Choices[source]
		if source == 1 then
			session.correctIndex = position
		end
	end

	session.awaiting = true
	quizRemote:FireClient(player, "Question", {
		Number = session.number,
		Total = QUESTIONS_PER_QUIZ,
		Topic = entry.Topic,
		Text = entry.Question,
		Choices = choices,
	})
end

local function startQuiz(player)
	if not isCurrent() or not nearDesk(player) then
		return
	end
	-- Pick 10 different questions.
	local pool = {}
	for index = 1, #QUESTIONS do
		pool[index] = index
	end
	local order = {}
	for _ = 1, math.min(QUESTIONS_PER_QUIZ, #pool) do
		order[#order + 1] = table.remove(pool, random:NextInteger(1, #pool))
	end
	sessions[player] = { order = order, number = 1, score = 0, correctIndex = 0, awaiting = false }
	sendQuestion(player)
end

local function finishQuiz(player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil

	local total = #session.order
	local stars = session.score + ((session.score == total) and PERFECT_BONUS or 0)
	if stars > 0 then
		starsValue(player).Value += stars
	end

	lastLine = string.format("TERKINI: %s  %d/%d", player.DisplayName, session.score, total)
	if not bestScore or session.score > bestScore then
		bestScore = session.score
		bestName = player.DisplayName
	end
	refreshScoreBoard()

	quizRemote:FireClient(player, "Finished", { Score = session.score, Total = total, Stars = stars })
end

prompt.Triggered:Connect(startQuiz)

quizRemote.OnServerEvent:Connect(function(player, action, value)
	if not isCurrent() then
		return
	end
	if action == "Start" then
		if not sessions[player] then
			startQuiz(player)
		end
	elseif action == "Quit" then
		sessions[player] = nil
	elseif action == "Answer" then
		local session = sessions[player]
		if not session or not session.awaiting then
			return
		end
		if type(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > 4 then
			return
		end
		session.awaiting = false
		local correct = value == session.correctIndex
		if correct then
			session.score += 1
		end
		quizRemote:FireClient(player, "Result", { Correct = correct, CorrectIndex = session.correctIndex, Score = session.score })

		task.delay(NEXT_QUESTION_DELAY, function()
			-- The player may have quit or left in the meantime.
			if sessions[player] ~= session or not isCurrent() then
				return
			end
			if session.number >= #session.order then
				finishQuiz(player)
			else
				session.number += 1
				sendQuestion(player)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

print(LOG .. string.format("Malay corner complete: %d questions in the bank, %d per quiz.", #QUESTIONS, QUESTIONS_PER_QUIZ))
