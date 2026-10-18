--!strict
-- PvP Arena HUD | StarterPlayer > StarterPlayerScripts > LocalScript
-- Ставится вместе с PvpArenaServer.luau (ServerScriptService > Script).
-- Рисует: панель статистики, прицел, хитмаркер, killfeed, баннеры серий убийств.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local killFeedRemote = remotes:WaitForChild("KillFeed") :: RemoteEvent
local hitmarkerRemote = remotes:WaitForChild("Hitmarker") :: RemoteEvent

local COL = {
	panel = Color3.fromRGB(10, 14, 22),
	text = Color3.fromRGB(232, 236, 241),
	accent = Color3.fromRGB(255, 215, 94),
	danger = Color3.fromRGB(255, 92, 92),
}

local gui = Instance.new("ScreenGui")
gui.Name = "PvpHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- ---------- статистика (слева сверху) ----------
local statsPanel = Instance.new("Frame")
statsPanel.BackgroundColor3 = COL.panel
statsPanel.BackgroundTransparency = 0.2
statsPanel.BorderSizePixel = 0
statsPanel.Position = UDim2.fromOffset(14, 14)
statsPanel.Size = UDim2.fromOffset(250, 122)
statsPanel.Parent = gui
corner(statsPanel, 10)

local function row(y: number, color: Color3, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(14, y)
	l.Size = UDim2.new(1, -28, 0, size + 8)
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.65
	l.Text = ""
	l.Parent = statsPanel
	return l
end

local titleLabel = row(8, COL.accent, 16)
titleLabel.Text = "PVP ARENA"
local killsLabel = row(38, COL.text, 15)
local deathsLabel = row(62, COL.text, 15)
local streakLabel = row(86, COL.danger, 15)

-- ---------- прицел ----------
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(5, 5)
dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dot.BackgroundTransparency = 0.1
dot.BorderSizePixel = 0
dot.ZIndex = 5
dot.Parent = gui
corner(dot, 3)

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromOffset(26, 26)
ring.BackgroundTransparency = 1
ring.ZIndex = 5
ring.Parent = gui
corner(ring, 13)
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 2
ringStroke.Color = Color3.fromRGB(255, 255, 255)
ringStroke.Transparency = 0.55
ringStroke.Parent = ring

-- ---------- хитмаркер ----------
local hitmarker = Instance.new("Frame")
hitmarker.AnchorPoint = Vector2.new(0.5, 0.5)
hitmarker.Position = UDim2.fromScale(0.5, 0.5)
hitmarker.Size = UDim2.fromOffset(40, 40)
hitmarker.BackgroundTransparency = 1
hitmarker.Visible = false
hitmarker.ZIndex = 6
hitmarker.Parent = gui

for _, spec in ipairs({ { 7, 7, 45 }, { 7, -7, -45 }, { -7, -7, 45 }, { -7, 7, -45 } }) do
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.new(0.5, spec[1], 0.5, spec[2])
	line.Size = UDim2.fromOffset(11, 2)
	line.BackgroundColor3 = COL.danger
	line.BorderSizePixel = 0
	line.Rotation = spec[3]
	line.Parent = hitmarker
end

local function flashHitmarker()
	hitmarker.Visible = true
	for _, child in ipairs(hitmarker:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundTransparency = 0
			TweenService:Create(child, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end
	end
	task.delay(0.35, function()
		hitmarker.Visible = false
	end)
end

hitmarkerRemote.OnClientEvent:Connect(flashHitmarker)

-- ---------- killfeed (справа сверху) ----------
local feedFrame = Instance.new("Frame")
feedFrame.AnchorPoint = Vector2.new(1, 0)
feedFrame.Position = UDim2.new(1, -14, 0, 14)
feedFrame.Size = UDim2.fromOffset(340, 300)
feedFrame.BackgroundTransparency = 1
feedFrame.ZIndex = 4
feedFrame.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = feedFrame

local feedOrder = 0

local function pushFeed(text: string, highlight: boolean)
	feedOrder -= 1

	local entry = Instance.new("TextLabel")
	entry.LayoutOrder = feedOrder
	entry.AutomaticSize = Enum.AutomaticSize.X
	entry.Size = UDim2.fromOffset(0, 28)
	entry.BackgroundColor3 = if highlight then COL.accent else COL.panel
	entry.BackgroundTransparency = if highlight then 0.05 else 0.2
	entry.BorderSizePixel = 0
	entry.Font = Enum.Font.GothamBold
	entry.TextSize = 15
	entry.TextColor3 = if highlight then Color3.fromRGB(20, 24, 34) else COL.text
	entry.Text = text
	entry.Parent = feedFrame
	corner(entry, 8)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = entry

	task.delay(5, function()
		TweenService:Create(entry, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
	task.delay(5.5, function()
		entry:Destroy()
	end)

	-- лента не должна разрастаться бесконечно
	local count = 0
	local oldest: TextLabel? = nil
	for _, child in ipairs(feedFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			count += 1
			if not oldest or child.LayoutOrder > oldest.LayoutOrder then
				oldest = child
			end
		end
	end
	if count > 7 and oldest then
		oldest:Destroy()
	end
end

-- ---------- баннер серий убийств ----------
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 108)
banner.Size = UDim2.fromOffset(640, 40)
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

local function announce(text: string)
	banner.Text = text
	banner.TextTransparency = 0
	task.delay(2.6, function()
		TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end)
end

killFeedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local text = payload.Text
	if typeof(text) ~= "string" then
		return
	end
	if payload.Kind == "Announce" then
		announce(text)
		pushFeed(text, true)
	else
		pushFeed(text, false)
	end
end)

-- ---------- статистика -> текст ----------
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local kills = leaderstats:WaitForChild("Kills") :: IntValue
	local deaths = leaderstats:WaitForChild("Deaths") :: IntValue
	local streak = player:WaitForChild("Streak") :: IntValue

	local function render()
		killsLabel.Text = ("УБИЙСТВА  %d"):format(kills.Value)
		deathsLabel.Text = ("СМЕРТИ  %d"):format(deaths.Value)
		local best = player:GetAttribute("BestStreak")
		streakLabel.Text = ("СЕРИЯ  %d  рекорд %d"):format(streak.Value, if typeof(best) == "number" then best else 0)
	end

	kills:GetPropertyChangedSignal("Value"):Connect(render)
	deaths:GetPropertyChangedSignal("Value"):Connect(render)
	streak:GetPropertyChangedSignal("Value"):Connect(render)
	player:GetAttributeChangedSignal("BestStreak"):Connect(render)
	render()
end)

-- ---------- подсказка управления ----------
local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -16)
hint.Size = UDim2.fromOffset(660, 20)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextSize = 14
hint.TextColor3 = COL.text
hint.TextStrokeTransparency = 0.7
hint.TextTransparency = 1
hint.Text = "WASD — движение · ЛКМ — удар · Пробел — прыжок · ПКМ — поворот камеры · меч выдаётся сам"
hint.ZIndex = 4
hint.Parent = gui

TweenService:Create(hint, TweenInfo.new(0.6), { TextTransparency = 0.25 }):Play()
task.delay(14, function()
	TweenService:Create(hint, TweenInfo.new(1), { TextTransparency = 1 }):Play()
end)
