--!nonstrict
-- Obby Kit v1 | ServerScriptService > Script (обычный Script, не LocalScript)
-- Что делает: строит полосу препятствий из 11 стейджей + финиш (прыжки, лава, узкие
-- балки, движущиеся платформы, вращающаяся штанга, исчезающие плитки, подъём,
-- конвейер, лифты, ступеньки), ставит 11 чекпоинтов, считает стейдж/время/смерти,
-- ведёт leaderstats, сохраняет лучший стейдж и время через DataStore.
-- Установка: ServerScriptService > Script > вставить код целиком > Play.
-- HUD: StarterPlayer > StarterPlayerScripts > LocalScript (файл ObbyHud.luau).
-- Публикация: File > Publish to Roblox > название > Publish. Ссылка: roblox.com/games/<ID>

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local CONFIG = {
	StageCount = 11, -- всего стейджей (чекпоинтов столько же + старт)
	FallKillY = -40, -- ниже этой высоты игрок погибает (улетел в пустоту)
	RespawnTime = 2.5, -- секунд до респавна
	WalkSpeed = 20,
	JumpPower = 52,

	SkipEnabled = true, -- жёлтые кнопки SKIP на чекпоинтах (пропустить стейдж)
	SkipCooldown = 3, -- секунд между скипами

	MoverSpeed = 1.7, -- скорость платформ, катающихся влево-вправо
	ElevatorSpeed = 1.1, -- скорость лифтов
	SpinnerSpeed = 1.15, -- скорость вращающейся штанги (рад/сек)
	BlinkOn = 1.7, -- исчезающие плитки: сколько секунд плитка твёрдая
	BlinkOff = 1.2, -- и сколько секунд исчезнувшая
	BlinkStagger = 0.65, -- сдвиг фаз у соседних плиток

	ConveyorSpeed = 12, -- насколько сильно конвейер толкает назад

	SaveData = true, -- DataStore (лучший стейдж, время, победы)
	SaveInterval = 10, -- сейв не чаще, чем раз в N секунд на игрока
}

local PALETTE = {
	Color3.fromRGB(86, 178, 255), -- стейдж 1
	Color3.fromRGB(255, 138, 76), -- 2
	Color3.fromRGB(178, 122, 255), -- 3
	Color3.fromRGB(76, 220, 152), -- 4
	Color3.fromRGB(255, 104, 150), -- 5
	Color3.fromRGB(88, 214, 255), -- 6
	Color3.fromRGB(255, 196, 84), -- 7
	Color3.fromRGB(140, 150, 255), -- 8
	Color3.fromRGB(120, 230, 190), -- 9
	Color3.fromRGB(255, 122, 122), -- 10
	Color3.fromRGB(200, 220, 100), -- 11
}

local LAVA_COLOR = Color3.fromRGB(255, 62, 40)
local CHECKPOINT_COLOR = Color3.fromRGB(60, 220, 110)
local SKIP_COLOR = Color3.fromRGB(255, 214, 64)
local FINISH_COLOR = Color3.fromRGB(255, 196, 40)

-- ============================================================
--  ХЕЛПЕРЫ
-- ============================================================

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

-- чистим старую карту (baseplate, дефолтный спавн и т.п.), оставляя камеру и terrain
for _, child in ipairs(workspace:GetChildren()) do
	if not child:IsA("Camera") and not child:IsA("Terrain") then
		child:Destroy()
	end
end

-- ============================================================
--  REMOTES
-- ============================================================

local remotes = ReplicatedStorage:FindFirstChild("ObbyRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "ObbyRemotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name, className)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = remotes
	end
	return r
end

local announcer = ensureRemote("Announce", "RemoteEvent") -- сервер -> клиент: баннеры и таймер
local actionRemote = ensureRemote("Action", "RemoteEvent") -- клиент -> сервер: Reset / Restart

-- ============================================================
--  СВЕТ И АТМОСФЕРА
-- ============================================================

for _, e in ipairs(Lighting:GetChildren()) do
	if e:IsA("Atmosphere") or e:IsA("BloomEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("SunRaysEffect") then
		e:Destroy()
	end
end

Lighting.ClockTime = 14.5
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(110, 120, 142)
Lighting.OutdoorAmbient = Color3.fromRGB(130, 142, 166)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ExposureCompensation = 0.05
Lighting.GlobalShadows = true

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Haze = 1.4
atmosphere.Glare = 0.12
atmosphere.Color = Color3.fromRGB(210, 224, 240)
atmosphere.Decay = Color3.fromRGB(104, 120, 148)
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Size = 20
bloom.Threshold = 1.15
bloom.Parent = Lighting

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Contrast = 0.06
colorCorrection.Saturation = 0.1
colorCorrection.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.08
sunRays.Spread = 0.8
sunRays.Parent = Lighting

-- ============================================================
--  МАТЕРИАЛЫ ПОСТРОЙКИ
-- ============================================================

local obbyFolder = Instance.new("Folder")
obbyFolder.Name = "Obby"
obbyFolder.Parent = workspace

local updaters = {} -- { fn(t) } — движущиеся платформы, штанга, исчезающие плитки
local killParts = {} -- части, убивающие при касании (лава, штанга)
local checkpoints = {} -- SpawnLocation'ы чекпоинтов, индекс = стейдж
local finishPad = nil

-- добавить платформу: size, позиция (Vector3), цвет, материал; offset — локальный от base
local function addPart(folder, base, name, size, off, color, material, extra)
	local props = {
		Name = name,
		Size = size,
		CFrame = base * CFrame.new(off),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = folder,
	}
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	return makePart(props)
end

local function addLava(folder, base, size, off)
	local lava = addPart(folder, base, "Lava", size, off, LAVA_COLOR, Enum.Material.Neon, {
		CanCollide = true,
	})
	table.insert(killParts, lava)
	return lava
end

local function addCheckpoint(index, position)
	local pad = Instance.new("SpawnLocation")
	pad.Name = "Checkpoint" .. tostring(index)
	pad.Size = Vector3.new(8, 1, 8)
	pad.CFrame = CFrame.new(position)
	pad.Anchored = true
	pad.CanCollide = true
	pad.Color = CHECKPOINT_COLOR
	pad.Material = Enum.Material.Neon
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Neutral = false
	pad.AllowTeamChangeOnTouch = false
	pad.Duration = 0
	pad.Parent = obbyFolder
	pad:SetAttribute("Checkpoint", index)

	-- номер чекпоинта над площадкой
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(120, 60)
	label.MaxDistance = 260
	label.AlwaysOnTop = false
	label.Adornee = pad
	label.Parent = pad

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.Text = tostring(index)
	text.TextColor3 = if index > 0 then CHECKPOINT_COLOR else Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.TextStrokeTransparency = 0.4
	text.Parent = label

	checkpoints[index] = pad

	-- жёлтая кнопка SKIP рядом с чекпоинтом
	if CONFIG.SkipEnabled and index < CONFIG.StageCount + 1 then
		local skip = addPart(obbyFolder, CFrame.new(position), "Skip" .. tostring(index), Vector3.new(4, 1, 4), Vector3.new(6, 0, 0), SKIP_COLOR, Enum.Material.Neon, {})
		skip:SetAttribute("SkipIndex", index)

		local skipLabel = Instance.new("BillboardGui")
		skipLabel.Size = UDim2.fromOffset(90, 36)
		skipLabel.MaxDistance = 140
		skipLabel.Adornee = skip
		skipLabel.Parent = skip

		local skipText = Instance.new("TextLabel")
		skipText.BackgroundTransparency = 1
		skipText.Size = UDim2.fromScale(1, 1)
		skipText.Font = Enum.Font.GothamBold
		skipText.Text = "SKIP"
		skipText.TextColor3 = Color3.fromRGB(60, 50, 10)
		skipText.TextScaled = true
		skipText.Parent = skipLabel
	end

	return pad
end

-- ============================================================
--  СТРОЙКА ТРАССЫ (те же размеры, что в obby.html)
-- ============================================================

local START = Vector3.new(0, 0, 0)

local STAGES = {
	{
		Name = "Прыжки",
		Build = function(f, base)
			for _, xz in ipairs({ { 0, 10 }, { 5, 26 }, { -5, 42 } }) do
				addPart(f, base, "Pad", Vector3.new(10, 1, 10), Vector3.new(xz[1], 0, xz[2]), PALETTE[1], Enum.Material.SmoothPlastic, {})
			end
			return Vector3.new(0, 0, 54)
		end,
	},
	{
		Name = "Лава",
		Build = function(f, base)
			addLava(f, base, Vector3.new(16, 1, 60), Vector3.new(0, -1, 28))
			for _, xz in ipairs({ { 0, 8 }, { 6, 22 }, { -6, 36 } }) do
				addPart(f, base, "Pad", Vector3.new(10, 1, 10), Vector3.new(xz[1], 0, xz[2]), PALETTE[2], Enum.Material.SmoothPlastic, {})
			end
			return Vector3.new(0, 0, 52)
		end,
	},
	{
		Name = "Узкие балки",
		Build = function(f, base)
			addLava(f, base, Vector3.new(18, 1, 56), Vector3.new(0, -1, 26))
			addPart(f, base, "Beam", Vector3.new(2, 1, 14), Vector3.new(0, 0, 11), PALETTE[3], Enum.Material.Metal, {})
			addPart(f, base, "Beam", Vector3.new(2, 1, 16), Vector3.new(5, 0, 28), PALETTE[3], Enum.Material.Metal, {})
			return Vector3.new(0, 0, 47)
		end,
	},
	{
		Name = "Движущиеся платформы",
		Build = function(f, base)
			addLava(f, base, Vector3.new(18, 1, 60), Vector3.new(0, -1, 28))
			local zs = { 16, 30, 44 }
			for i, z in ipairs(zs) do
				local part = addPart(f, base, "Mover", Vector3.new(8, 1, 8), Vector3.new(0, 0, z), PALETTE[4], Enum.Material.SmoothPlastic, {})
				local basePos = part.Position
				local phase = (i - 1) * (math.pi / 2)
				table.insert(updaters, function(t)
					part.CFrame = CFrame.new(basePos + Vector3.new(math.sin(t * CONFIG.MoverSpeed + phase) * 7, 0, 0))
				end)
			end
			return Vector3.new(0, 0, 56)
		end,
	},
	{
		Name = "Вертушка",
		Build = function(f, base)
			addPart(f, base, "Pad", Vector3.new(8, 1, 8), Vector3.new(0, 0, 6), PALETTE[5], Enum.Material.SmoothPlastic, {})
			-- PartType.Cylinder: ось по X, поэтому поворот на 90° вокруг Z, чтобы лёг диском
			addPart(f, base, "Circle", Vector3.new(1, 24, 24), Vector3.new(0, 0, 26), PALETTE[5], Enum.Material.Concrete, {
				Shape = Enum.PartType.Cylinder,
				CFrame = base * CFrame.new(0, 0, 26) * CFrame.Angles(0, 0, math.rad(90)),
			})
			addPart(f, base, "Pad", Vector3.new(8, 1, 8), Vector3.new(0, 0, 46), PALETTE[5], Enum.Material.SmoothPlastic, {})

			-- вращающаяся штанга-убийца
			local bar = addPart(f, base, "Lava", Vector3.new(24, 1, 2), Vector3.new(0, 1.5, 26), LAVA_COLOR, Enum.Material.Neon, {})
			table.insert(killParts, bar)
			local barBase = CFrame.new(bar.Position)
			table.insert(updaters, function(t)
				bar.CFrame = barBase * CFrame.Angles(0, t * CONFIG.SpinnerSpeed, 0)
			end)
			return Vector3.new(0, 0, 56)
		end,
	},
	{
		Name = "Исчезающие плитки",
		Build = function(f, base)
			addLava(f, base, Vector3.new(16, 1, 56), Vector3.new(0, -1, 26))
			local spots = { { -5, 10 }, { 5, 22 }, { -5, 34 }, { 5, 46 } }
			local period = CONFIG.BlinkOn + CONFIG.BlinkOff
			for i, xz in ipairs(spots) do
				local tile = addPart(f, base, "Blink", Vector3.new(8, 1, 8), Vector3.new(xz[1], 0, xz[2]), PALETTE[6], Enum.Material.Neon, {})
				local phase = (i - 1) * CONFIG.BlinkStagger
				local visible = true
				table.insert(updaters, function(t)
					local vis = ((t + phase) % period) < CONFIG.BlinkOn
					if vis ~= visible then
						visible = vis
						tile.CanCollide = vis
						tile.Transparency = if vis then 0 else 0.85
					end
				end)
			end
			return Vector3.new(0, 0, 58)
		end,
	},
	{
		Name = "Подъём",
		Build = function(f, base)
			local spots = { { 0, 2, 8 }, { 6, 4, 16 }, { -6, 6, 24 }, { 0, 8, 32 } }
			for _, s in ipairs(spots) do
				addPart(f, base, "Pad", Vector3.new(8, 1, 8), Vector3.new(s[1], s[2], s[3]), PALETTE[7], Enum.Material.SmoothPlastic, {})
			end
			return Vector3.new(0, 10, 42)
		end,
	},
	{
		Name = "Конвейер",
		Build = function(f, base)
			addLava(f, base, Vector3.new(16, 1, 40), Vector3.new(0, -3, 20))
			local belt = addPart(f, base, "Conveyor", Vector3.new(14, 1, 26), Vector3.new(0, 0, 20), PALETTE[8], Enum.Material.Metal, {})
			belt:SetAttribute("PushZ", -CONFIG.ConveyorSpeed)

			-- неоновые бортики, чтобы видеть край
			addPart(f, base, "Rail", Vector3.new(1, 0.4, 26), Vector3.new(-7.5, 0.2, 20), PALETTE[8], Enum.Material.Neon, { CanCollide = false })
			addPart(f, base, "Rail", Vector3.new(1, 0.4, 26), Vector3.new(7.5, 0.2, 20), PALETTE[8], Enum.Material.Neon, { CanCollide = false })
			return Vector3.new(0, 0, 44)
		end,
	},
	{
		Name = "Мост",
		Build = function(f, base)
			addLava(f, base, Vector3.new(16, 1, 52), Vector3.new(0, -3, 26))
			local spots = { { 0, 8 }, { -5, 18 }, { 5, 28 }, { 0, 38 } }
			for _, xz in ipairs(spots) do
				addPart(f, base, "Pad", Vector3.new(6, 1, 6), Vector3.new(xz[1], 0, xz[2]), PALETTE[9], Enum.Material.SmoothPlastic, {})
			end
			return Vector3.new(0, 0, 52)
		end,
	},
	{
		Name = "Лифты",
		Build = function(f, base)
			addLava(f, base, Vector3.new(18, 1, 58), Vector3.new(0, -3, 28))
			local zs = { 14, 28, 42 }
			for i, z in ipairs(zs) do
				local part = addPart(f, base, "Elevator", Vector3.new(8, 1, 8), Vector3.new(0, 4, z), PALETTE[10], Enum.Material.SmoothPlastic, {})
				local basePos = part.Position
				local phase = (i - 1) * 2.1
				table.insert(updaters, function(t)
					part.CFrame = CFrame.new(basePos + Vector3.new(0, math.sin(t * CONFIG.ElevatorSpeed + phase) * 4, 0))
				end)
			end
			return Vector3.new(0, 8, 56)
		end,
	},
	{
		Name = "Лестница",
		Build = function(f, base)
			local spots = { { 0, 0, 10 }, { -4, 2, 18 }, { 4, 4, 26 }, { -4, 6, 34 }, { 0, 8, 42 } }
			for _, s in ipairs(spots) do
				addPart(f, base, "Pad", Vector3.new(6, 1, 6), Vector3.new(s[1], s[2], s[3]), PALETTE[11], Enum.Material.SmoothPlastic, {})
			end
			return Vector3.new(0, 10, 52)
		end,
	},
}

-- стартовая площадка + табличка OBBY
makePart({
	Name = "StartPad",
	Size = Vector3.new(16, 1, 16),
	CFrame = CFrame.new(START),
	Color = Color3.fromRGB(96, 104, 122),
	Material = Enum.Material.Concrete,
	Parent = obbyFolder,
})

local function addSign(text, color, position, size)
	local anchor = makePart({
		Name = "SignAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(position),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = obbyFolder,
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(size, size * 0.28)
	billboard.MaxDistance = 900
	billboard.Adornee = anchor
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard
	return anchor
end

addSign("OBBY — 11 стейджей →", Color3.fromRGB(255, 215, 94), START + Vector3.new(0, 14, 0), 620)
addCheckpoint(0, START)

-- строим стейджи друг за другом: каждый начинается с чекпоинта предыдущего
local base = CFrame.new(START)
for i, stage in ipairs(STAGES) do
	local folder = Instance.new("Folder")
	folder.Name = ("Stage%d_%s"):format(i, stage.Name)
	folder.Parent = obbyFolder

	local cpOffset = stage.Build(folder, base)
	local cp = addCheckpoint(i, base * cpOffset)

	-- табличка с названием стейджа над чекпоинтом
	addSign(("%d. %s"):format(i, stage.Name), PALETTE[i], cp.Position + Vector3.new(0, 9, 0), 420)

	base = CFrame.new(cp.Position)
end

-- финиш
local finPos = base * Vector3.new(0, 0, 18)
finishPad = makePart({
	Name = "Finish",
	Size = Vector3.new(16, 1, 16),
	CFrame = CFrame.new(finPos),
	Color = FINISH_COLOR,
	Material = Enum.Material.Neon,
	Parent = obbyFolder,
})
addSign("FINISH 🏁", FINISH_COLOR, finPos + Vector3.new(0, 16, 0), 700)

-- декоративные облака
for i = 1, 10 do
	local a = (i / 10) * math.pi * 2
	local dist = 120 + (i % 3) * 60
	makePart({
		Name = "Cloud",
		Size = Vector3.new(40 + (i % 4) * 14, 8, 26),
		CFrame = CFrame.new(math.cos(a) * dist, 90 + (i % 3) * 12, math.sin(a) * dist),
		Color = Color3.fromRGB(240, 244, 250),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = obbyFolder,
	})
end

-- ============================================================
--  ДВИЖУЩИЕСЯ ЧАСТИ (обновление каждый кадр; игроков тащат за собой)
-- ============================================================

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, fn in ipairs(updaters) do
		fn(t)
	end
end)

-- ============================================================
--  ЛАВА / ШТАНГА: касание = смерть
-- ============================================================

local function killOnTouch(part)
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character or character:GetAttribute("ObbyDead") then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			character:SetAttribute("ObbyDead", true)
			humanoid.Health = 0
		end
	end)
end

for _, part in ipairs(killParts) do
	killOnTouch(part)
end

-- падение в пустоту = смерть
task.spawn(function()
	while true do
		task.wait(0.4)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and root.Position.Y < CONFIG.FallKillY then
					humanoid.Health = 0
				end
			end
		end
	end
end)

-- ============================================================
--  КОНВЕЙЕР
-- ============================================================

task.spawn(function()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	while true do
		task.wait(0.06)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				params.FilterDescendantsInstances = { character }
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), params)
				if hit and hit.Instance.Name == "Conveyor" then
					local push = hit.Instance:GetAttribute("PushZ") or -CONFIG.ConveyorSpeed
					local vel = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y, push)
				end
			end
		end
	end
end)

-- ============================================================
--  СТАТИСТИКА, ДАННЫЕ, ЛОГИКА СТЕЙДЖЕЙ
-- ============================================================

local store = nil
if CONFIG.SaveData then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("ObbyStats_v1")
	end)
	if ok then
		store = result
	end
end

local stageOf = {} -- [Player] = текущий стейдж
local runStart = {} -- [Player] = os.clock() старта забега (nil, пока стейдж 0)
local lastSave = {} -- [Player] = os.clock() прошлого сейва
local skipCooldown = {} -- [Player] = os.clock() последнего скипа
local continued = {} -- [Player] = уже телепортировали на сохранённый стейдж

local function announce(payload)
	announcer:FireAllClients(payload)
end

local function savePlayer(player)
	if not store then
		return
	end
	local now = os.clock()
	if now - (lastSave[player] or -math.huge) < CONFIG.SaveInterval then
		return
	end
	lastSave[player] = now
	local data = {
		BestStage = player:GetAttribute("BestStage") or 0,
		BestTime = player:GetAttribute("BestTime"),
		Wins = 0,
	}
	local wins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Wins")
	if wins then
		data.Wins = wins.Value
	end
	task.spawn(function()
		pcall(function()
			store:SetAsync("p" .. tostring(player.UserId), data)
		end)
	end)
end

local function teleportTo(player, position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function setStage(player, stage, silent)
	stageOf[player] = stage
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Stage")
	if value then
		value.Value = stage
	end

	local best = player:GetAttribute("BestStage") or 0
	if stage > best then
		player:SetAttribute("BestStage", stage)
	end

	local cp = checkpoints[stage]
	if cp then
		player.RespawnLocation = cp
	end

	if stage >= 1 and not runStart[player] then
		runStart[player] = os.clock()
		announcer:FireClient(player, { Kind = "RunStart" })
	end

	if not silent and stage >= 1 then
		announce({
			Kind = "Checkpoint",
			Stage = stage,
			Text = ("Чекпоинт %d! %s"):format(stage, STAGES[stage] and STAGES[stage].Name or ""),
		})
	end
	savePlayer(player)
end

local function doSkip(player)
	if not CONFIG.SkipEnabled then
		return
	end
	local now = os.clock()
	if now - (skipCooldown[player] or -math.huge) < CONFIG.SkipCooldown then
		return
	end
	local stage = stageOf[player] or 0
	if stage >= CONFIG.StageCount then
		-- последний чекпоинт: скип сразу на финиш
		skipCooldown[player] = now
		teleportTo(player, finishPad.Position)
		announce({ Kind = "Skip", Stage = stage, Text = "Скип: финиш!" })
		return
	end
	skipCooldown[player] = now
	setStage(player, stage + 1)
	local cp = checkpoints[stage + 1]
	if cp then
		teleportTo(player, cp.Position)
	end
	announce({ Kind = "Skip", Stage = stage, Text = ("Скип %d → %d"):format(stage, stage + 1) })
end

-- чекпоинты: принимаем только «следующий» стейдж, назад не откатываем
for index, pad in pairs(checkpoints) do
	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local stage = stageOf[player] or 0
		if index == stage + 1 then
			setStage(player, index)
		end
	end)
end

-- кнопки SKIP
for _, part in ipairs(obbyFolder:GetChildren()) do
	if part:IsA("BasePart") and part:GetAttribute("SkipIndex") then
		local index = part:GetAttribute("SkipIndex")
		part.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end
			if (stageOf[player] or 0) == index then
				doSkip(player)
			end
		end)
	end
end

-- финиш
finishPad.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or player:GetAttribute("ObbyFinished") then
		return
	end
	player:SetAttribute("ObbyFinished", true)

	local elapsed = nil
	if runStart[player] then
		elapsed = os.clock() - runStart[player]
	end

	local bestTime = player:GetAttribute("BestTime")
	if elapsed and (not bestTime or elapsed < bestTime) then
		player:SetAttribute("BestTime", elapsed)
	end

	local stats = player:FindFirstChild("leaderstats")
	local wins = stats and stats:FindFirstChild("Wins")
	if wins then
		wins.Value += 1
	end

	if elapsed then
		announce({
			Kind = "Win",
			Stage = CONFIG.StageCount,
			Time = elapsed,
			Text = ("%s прошёл обби! Время %s"):format(player.DisplayName, ("%d:%05.2f"):format(math.floor(elapsed / 60), elapsed % 60)),
		})
	else
		announce({ Kind = "Win", Stage = CONFIG.StageCount, Time = 0, Text = ("%s добрался до финиша!"):format(player.DisplayName) })
	end
	savePlayer(player)

	-- через 5 секунд возвращаем на старт для нового забега
	task.delay(5, function()
		if not player.Parent then
			return
		end
		player:SetAttribute("ObbyFinished", false)
		runStart[player] = nil
		setStage(player, 0, true)
		local startPad = checkpoints[0]
		if startPad then
			player.RespawnLocation = startPad
			teleportTo(player, startPad.Position)
		end
		announcer:FireClient(player, { Kind = "Restarted" })
	end)
end)

-- кнопки из HUD: Reset (к чекпоинту) / Restart (с начала)
actionRemote.OnServerEvent:Connect(function(player, action)
	if typeof(action) ~= "string" then
		return
	end
	local stage = stageOf[player] or 0
	if action == "Reset" then
		local cp = checkpoints[stage]
		if cp then
			teleportTo(player, cp.Position)
		end
		announcer:FireClient(player, { Kind = "Reset", Stage = stage, Text = ("Сброс: чекпоинт %d"):format(stage) })
	elseif action == "Restart" then
		runStart[player] = nil
		setStage(player, 0, true)
		local startPad = checkpoints[0]
		if startPad then
			player.RespawnLocation = startPad
			teleportTo(player, startPad.Position)
		end
		announcer:FireClient(player, { Kind = "Restarted" })
	end
end)

-- ============================================================
--  ИГРОКИ
-- ============================================================

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = CONFIG.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = CONFIG.JumpPower

	character:SetAttribute("ObbyDead", false)

	-- респавн на текущем чекпоинте
	local stage = stageOf[player] or 0
	local cp = checkpoints[stage]
	if cp then
		player.RespawnLocation = cp
	end

	-- первый спавн: если есть сохранённый прогресс — продолжаем с него
	if not continued[player] then
		continued[player] = true
		local best = player:GetAttribute("BestStage") or 0
		if best >= 1 and checkpoints[best] then
			task.delay(0.6, function()
				if player.Character ~= character then
					return
				end
				setStage(player, best)
				teleportTo(player, checkpoints[best].Position)
				announcer:FireClient(player, { Kind = "Welcome", Stage = best, Text = ("Продолжаем со стейджа %d"):format(best) })
			end)
		end
	end

	humanoid.Died:Connect(function()
		local deaths = player:GetAttribute("Deaths") or 0
		player:SetAttribute("Deaths", deaths + 1)
	end)
end

local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local stageValue = Instance.new("IntValue")
	stageValue.Name = "Stage"
	stageValue.Parent = stats

	local winsValue = Instance.new("IntValue")
	winsValue.Name = "Wins"
	winsValue.Parent = stats

	stats.Parent = player

	player:SetAttribute("BestStage", 0)
	player:SetAttribute("Deaths", 0)
	player:SetAttribute("BestTime", nil)
	stageOf[player] = 0

	-- загрузка сохранения
	if store then
		task.spawn(function()
			local ok, data = pcall(function()
				return store:GetAsync("p" .. tostring(player.UserId))
			end)
			if ok and typeof(data) == "table" then
				player:SetAttribute("BestStage", tonumber(data.BestStage) or 0)
				if typeof(data.BestTime) == "number" then
					player:SetAttribute("BestTime", data.BestTime)
				end
				if winsValue.Parent and tonumber(data.Wins) then
					winsValue.Value = math.floor(tonumber(data.Wins))
				end
			end
			announcer:FireClient(player, { Kind = "Loaded" })
		end)
	end

	local startPad = checkpoints[0]
	if startPad then
		player.RespawnLocation = startPad
	end
	Players.RespawnTime = CONFIG.RespawnTime

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	-- финальный сейв без троттлинга
	if store then
		local data = {
			BestStage = player:GetAttribute("BestStage") or 0,
			BestTime = player:GetAttribute("BestTime"),
			Wins = 0,
		}
		local wins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Wins")
		if wins then
			data.Wins = wins.Value
		end
		pcall(function()
			store:SetAsync("p" .. tostring(player.UserId), data)
		end)
	end
	stageOf[player] = nil
	runStart[player] = nil
	lastSave[player] = nil
	skipCooldown[player] = nil
	continued[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print(("[Obby] Трасса готова: %d стейджей, %d чекпоинтов, скип %s, сохранение %s"):format(
	#STAGES,
	CONFIG.StageCount + 1,
	CONFIG.SkipEnabled and "вкл" or "выкл",
	store and "вкл" or "выкл (API Services выключен)"
))
