--!nonstrict
-- Obby HUD | StarterPlayer > StarterPlayerScripts > LocalScript
-- Ставится вместе с ObbyServer.luau (ServerScriptService > Script).
-- Рисует: панель стейджа/времени/рекорда, баннеры чекпоинтов, кнопки «Сброс» и «С начала».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("ObbyRemotes")
local announcer = remotes:WaitForChild("Announce") :: RemoteEvent
local actionRemote = remotes:WaitForChild("Action") :: RemoteEvent

local COL = {
	panel = Color3.fromRGB(10, 14, 22),
	text = Color3.fromRGB(232, 236, 241),
	dim = Color3.fromRGB(159, 176, 200),
	accent = Color3.fromRGB(255, 215, 94),
	good = Color3.fromRGB(60, 220, 110),
	danger = Color3.fromRGB(255, 92, 92),
}

local STAGE_COUNT = 11

local function fmtTime(t)
	t = math.max(0, tonumber(t) or 0)
	return ("%d:%05.2f"):format(math.floor(t / 60), t % 60)
end

local gui = Instance.new("ScreenGui")
gui.Name = "ObbyHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- ---------- панель (слева сверху) ----------
local panel = Instance.new("Frame")
panel.BackgroundColor3 = COL.panel
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Position = UDim2.fromOffset(14, 14)
panel.Size = UDim2.fromOffset(236, 158)
panel.Parent = gui
corner(panel, 10)

local function row(y, color, size, bold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(14, y)
	l.Size = UDim2.new(1, -28, 0, size + 8)
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.65
	l.Text = ""
	l.Parent = panel
	return l
end

local title = row(8, COL.accent, 17, true)
title.Text = "OBBY"
local stageLabel = row(36, COL.text, 16, true)
local timeLabel = row(60, COL.text, 15)
local recordLabel = row(84, COL.dim, 13)
local bestStageLabel = row(104, COL.dim, 13)
local deathsLabel = row(124, COL.dim, 13)

-- ---------- баннер по центру ----------
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 96)
banner.Size = UDim2.fromOffset(720, 44)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 30
banner.TextColor3 = COL.accent
banner.TextStrokeColor3 = Color3.fromRGB(20, 24, 34)
banner.TextStrokeTransparency = 0.45
banner.TextTransparency = 1
banner.Text = ""
banner.ZIndex = 7
banner.Parent = gui

local function announce(text, color, big)
	banner.Text = text
	banner.TextColor3 = color or COL.accent
	banner.TextSize = big and 40 or 30
	banner.TextTransparency = 0
	task.delay(2.4, function()
		TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end)
end

-- ---------- маленькие всплывашки снизу ----------
local toastBox = Instance.new("Frame")
toastBox.AnchorPoint = Vector2.new(0.5, 1)
toastBox.Position = UDim2.new(0.5, 0, 1, -70)
toastBox.Size = UDim2.fromOffset(420, 60)
toastBox.BackgroundTransparency = 1
toastBox.Parent = gui

local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 6)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastBox

local toastOrder = 0

local function toast(text)
	toastOrder -= 1
	local entry = Instance.new("TextLabel")
	entry.LayoutOrder = toastOrder
	entry.AutomaticSize = Enum.AutomaticSize.X
	entry.Size = UDim2.fromOffset(0, 26)
	entry.BackgroundColor3 = COL.panel
	entry.BackgroundTransparency = 0.25
	entry.BorderSizePixel = 0
	entry.Font = Enum.Font.GothamBold
	entry.TextSize = 14
	entry.TextColor3 = COL.text
	entry.Text = text
	entry.Parent = toastBox
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = entry
	corner(entry, 8)
	task.delay(4, function()
		TweenService:Create(entry, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
	task.delay(4.5, function()
		entry:Destroy()
	end)
end

-- ---------- кнопки справа снизу ----------
local function makeButton(text, y, color)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = COL.panel
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.Position = UDim2.new(1, -14 - 168, 1, y)
	b.Size = UDim2.fromOffset(168, 40)
	b.AnchorPoint = Vector2.new(0, 1)
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = color or COL.text
	b.TextStrokeTransparency = 0.6
	b.Text = text
	b.Parent = gui
	corner(b, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(58, 74, 107)
	stroke.Thickness = 1
	stroke.Parent = b

	b.MouseButton1Click:Connect(function()
		actionRemote:FireServer(text:find("Сброс") and "Reset" or "Restart")
	end)
	return b
end

makeButton("⟲ Сброс к чекпоинту", -62)
makeButton("⏮ С начала", -14, COL.dim)

-- ---------- таймер ----------
local running = false
local runStartClock = 0
local frozenTime = nil

local function renderTime()
	local t
	if frozenTime then
		t = frozenTime
	elseif running then
		t = os.clock() - runStartClock
	else
		t = 0
	end
	timeLabel.Text = ("ВРЕМЯ  %s"):format(fmtTime(t))
end

task.spawn(function()
	while true do
		renderTime()
		task.wait(0.1)
	end
end)

-- ---------- статистика ----------
local function renderStats()
	local stats = player:FindFirstChild("leaderstats")
	local stage = 0
	local stageValue = stats and stats:FindFirstChild("Stage")
	if stageValue and stageValue:IsA("IntValue") then
		stage = stageValue.Value
	end
	stageLabel.Text = ("СТЕЙДЖ  %d / %d"):format(stage, STAGE_COUNT)

	local bestTime = player:GetAttribute("BestTime")
	recordLabel.Text = ("РЕКОРД  %s"):format(if typeof(bestTime) == "number" and bestTime > 0 then fmtTime(bestTime) else "—")

	local bestStage = player:GetAttribute("BestStage") or 0
	bestStageLabel.Text = ("ЛУЧШИЙ СТЕЙДЖ  %d / %d"):format(bestStage, STAGE_COUNT)

	local deaths = player:GetAttribute("Deaths") or 0
	deathsLabel.Text = ("СМЕРТИ  %d"):format(deaths)
end

task.spawn(function()
	local stats = player:WaitForChild("leaderstats")
	local stageValue = stats:WaitForChild("Stage") :: IntValue
	stageValue:GetPropertyChangedSignal("Value"):Connect(renderStats)
	player:GetAttributeChangedSignal("BestTime"):Connect(renderStats)
	player:GetAttributeChangedSignal("BestStage"):Connect(renderStats)
	player:GetAttributeChangedSignal("Deaths"):Connect(renderStats)
	renderStats()
end)

-- ---------- сообщения от сервера ----------
announcer.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local kind = payload.Kind
	if kind == "Checkpoint" then
		announce(payload.Text or ("Чекпоинт %d!"):format(payload.Stage or 0), COL.good)
	elseif kind == "Skip" then
		announce(payload.Text or "Скип!", COL.accent)
	elseif kind == "Win" then
		announce(payload.Text or "🏁 ФИНИШ!", COL.accent, true)
		if typeof(payload.Time) == "number" and payload.Time > 0 then
			frozenTime = payload.Time
			running = false
		end
	elseif kind == "RunStart" then
		running = true
		frozenTime = nil
		runStartClock = os.clock()
	elseif kind == "Restarted" then
		running = false
		frozenTime = nil
		toast("Новый забег! Время сброшено")
	elseif kind == "Reset" then
		toast(payload.Text or "Сброс к чекпоинту")
	elseif kind == "Welcome" then
		toast(payload.Text or "Продолжаем!")
	end
end)

-- ---------- подсказка управления ----------
local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -16)
hint.Size = UDim2.fromOffset(680, 20)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextSize = 14
hint.TextColor3 = COL.text
hint.TextStrokeTransparency = 0.7
hint.TextTransparency = 1
hint.Text = "WASD — бег · Пробел — прыжок · жёлтая кнопка SKIP — пропустить стейдж · зелёный чекпоинт — сохранение"
hint.ZIndex = 4
hint.Parent = gui

TweenService:Create(hint, TweenInfo.new(0.6), { TextTransparency = 0.25 }):Play()
task.delay(15, function()
	TweenService:Create(hint, TweenInfo.new(1), { TextTransparency = 1 }):Play()
end)
