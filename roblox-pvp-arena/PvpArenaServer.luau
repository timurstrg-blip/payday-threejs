--!strict
-- PvP Arena Kit v1 | ServerScriptService > Script (обычный Script, не LocalScript)
-- Что делает: строит арену (круг, центральная платформа, 4 трапа, колонны, ящики, 8 спавнов),
-- выдаёт мечи, считает убийства/смерти/серии, показывает killfeed, регенерирует HP.
-- Установка: ServerScriptService > Script > вставить код целиком > Play.
-- HUD: StarterPlayer > StarterPlayerScripts > LocalScript (файл PvpArenaHud.luau).
-- Публикация: File > Publish to Roblox > название > Publish. Ссылка: roblox.com/games/<ID>

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local CONFIG = {
	ArenaRadius = 70, -- радиус арены
	SpawnCount = 8, -- сколько спавн-площадок
	SpawnRadius = 55, -- на каком радиусе стоят спавны
	FallKillY = -45, -- ниже этой высоты игрок погибает
	RespawnTime = 3, -- секунд до респавна

	SwordDamage = 24, -- урон меча
	SwordRange = 10, -- дальность удара (студы)
	SwordArc = 0.35, -- ширина конуса удара (dot product чем больше, тем уже)
	SwordCooldown = 0.45, -- перезарядка удара

	RegenDelay = 6, -- через сколько секунд без урона начинается реген
	RegenRate = 2, -- HP в секунду
	WalkSpeed = 18,
	JumpPower = 52,

	AssistWindow = 8, -- сколько секунд урон считается "своим" для убийства
	StreakAnnounce = { 3, 5, 7, 10, 15, 20, 30 },
}

-- ============================================================
--  ХЕЛПЕРЫ
-- ============================================================

local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
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
--  REMOTES (клиент и сервер общаются через них)
-- ============================================================

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
remotes = remotes :: Folder

local function ensureRemote(name: string, className: string): Instance
	local r = (remotes :: Folder):FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = remotes
	end
	return r :: Instance
end

local killFeedRemote = ensureRemote("KillFeed", "RemoteEvent") :: RemoteEvent
local hitmarkerRemote = ensureRemote("Hitmarker", "RemoteEvent") :: RemoteEvent

-- ============================================================
--  СВЕТ И АТМОСФЕРА
-- ============================================================

for _, e in ipairs(Lighting:GetChildren()) do
	if e:IsA("Atmosphere") or e:IsA("BloomEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("SunRaysEffect") then
		e:Destroy()
	end
end

Lighting.ClockTime = 15.2
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(96, 106, 128)
Lighting.OutdoorAmbient = Color3.fromRGB(118, 130, 152)
Lighting.EnvironmentDiffuseScale = 0.35
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ExposureCompensation = 0.1
Lighting.GlobalShadows = true

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.32
atmosphere.Haze = 1.6
atmosphere.Glare = 0.15
atmosphere.Color = Color3.fromRGB(199, 211, 226)
atmosphere.Decay = Color3.fromRGB(96, 110, 134)
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.55
bloom.Size = 22
bloom.Threshold = 1.1
bloom.Parent = Lighting

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Contrast = 0.06
colorCorrection.Saturation = 0.07
colorCorrection.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.08
sunRays.Spread = 0.8
sunRays.Parent = Lighting

-- ============================================================
--  АРЕНА (та же карта, что в pvp.html)
-- ============================================================

local R = CONFIG.ArenaRadius
local arenaFolder = Instance.new("Folder")
arenaFolder.Name = "Arena"
arenaFolder.Parent = workspace

-- круглый пол
makePart({
	Name = "Platform",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(4, R * 2, R * 2),
	CFrame = CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(72, 79, 95),
	Material = Enum.Material.Slate,
	Parent = arenaFolder,
})

-- неоновый бортик по краю
local SEGS = 36
local segLen = 2 * R * math.sin(math.pi / SEGS)
for i = 0, SEGS - 1 do
	local a = (i / SEGS) * math.pi * 2
	local pos = Vector3.new(math.cos(a) * (R - 1), 0.75, math.sin(a) * (R - 1))
	makePart({
		Name = "Border",
		Size = Vector3.new(2, 1.5, segLen + 0.6),
		CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)),
		Color = Color3.fromRGB(255, 90, 90),
		Material = Enum.Material.Neon,
		Parent = arenaFolder,
	})
end

-- центральная платформа (высота 8)
local CENTER_Y = 8
local CENTER_R = 18
makePart({
	Name = "CenterPlatform",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(1.5, CENTER_R * 2, CENTER_R * 2),
	CFrame = CFrame.new(0, CENTER_Y - 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(96, 104, 122),
	Material = Enum.Material.Concrete,
	Parent = arenaFolder,
})

-- 4 трапа: от земли (радиус 30) к центру (радиус 16, высота 8)
for k = 0, 3 do
	local a = math.rad(45 + 90 * k)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local p1 = dir * 30 + Vector3.new(0, 0.5, 0)
	local p2 = dir * 16 + Vector3.new(0, CENTER_Y, 0)
	local mid = (p1 + p2) * 0.5
	local span = (p2 - p1).Magnitude
	makePart({
		Name = "Ramp",
		Size = Vector3.new(9, 1, span + 1),
		CFrame = CFrame.lookAt(mid, p2),
		Color = Color3.fromRGB(88, 95, 112),
		Material = Enum.Material.Metal,
		Parent = arenaFolder,
	})
end

-- неоновое кольцо-метка в центре
makePart({
	Name = "CenterRing",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.8, 7, 7),
	CFrame = CFrame.new(0, CENTER_Y + 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(255, 215, 94),
	Material = Enum.Material.Neon,
	CanCollide = false,
	Parent = arenaFolder,
})

-- колонны-укрытия (между трапами)
for k = 0, 7 do
	local a = math.rad(22.5 + 45 * k)
	makePart({
		Name = "Pillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 6, 6),
		CFrame = CFrame.new(math.cos(a) * 38, 7, math.sin(a) * 38) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 128, 148),
		Material = Enum.Material.Concrete,
		Parent = arenaFolder,
	})
end

-- ящики
local crateData = {
	{ pos = Vector3.new(-52, 3, 12), rot = 15 },
	{ pos = Vector3.new(34, 3, -48), rot = -20 },
	{ pos = Vector3.new(56, 3, 26), rot = 35 },
	{ pos = Vector3.new(-24, 3, -58), rot = -10 },
	{ pos = Vector3.new(-62, 3, -18), rot = 40 },
	{ pos = Vector3.new(8, 3, 56), rot = 25 },
	{ pos = Vector3.new(-10, 3, -34), rot = 5 },
	{ pos = Vector3.new(38, 3, 40), rot = -30 },
}
for _, c in ipairs(crateData) do
	makePart({
		Name = "Crate",
		Size = Vector3.new(6, 6, 6),
		CFrame = CFrame.new(c.pos) * CFrame.Angles(0, math.rad(c.rot), 0),
		Color = Color3.fromRGB(150, 106, 66),
		Material = Enum.Material.WoodPlanks,
		Parent = arenaFolder,
	})
end

-- парящие камни для красоты
local rockData = {
	{ r = 95, a = 20, y = 16, s = 7 },
	{ r = 105, a = 70, y = 26, s = 10 },
	{ r = 92, a = 130, y = 12, s = 5 },
	{ r = 110, a = 190, y = 30, s = 12 },
	{ r = 98, a = 250, y = 18, s = 6 },
	{ r = 104, a = 310, y = 24, s = 9 },
}
for _, rock in ipairs(rockData) do
	local a = math.rad(rock.a)
	makePart({
		Name = "Rock",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(rock.s, rock.s * 0.8, rock.s),
		CFrame = CFrame.new(math.cos(a) * rock.r, rock.y, math.sin(a) * rock.r),
		Color = Color3.fromRGB(66, 70, 84),
		Material = Enum.Material.Basalt,
		Parent = arenaFolder,
	})
end

-- табличка над центром
local sign = makePart({
	Name = "ArenaSign",
	Size = Vector3.new(1, 1, 1),
	CFrame = CFrame.new(0, 42, 0),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Parent = arenaFolder,
})
local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.fromOffset(520, 110)
billboard.MaxDistance = 600
billboard.Adornee = sign
billboard.Parent = sign

local signLabel = Instance.new("TextLabel")
signLabel.BackgroundTransparency = 1
signLabel.Size = UDim2.fromScale(1, 1)
signLabel.Font = Enum.Font.GothamBlack
signLabel.Text = "PVP ARENA"
signLabel.TextColor3 = Color3.fromRGB(255, 215, 94)
signLabel.TextScaled = true
signLabel.TextStrokeTransparency = 0.35
signLabel.Parent = billboard

-- 8 спавн-площадок по кругу
local spawnPads: { SpawnLocation } = {}
for i = 0, CONFIG.SpawnCount - 1 do
	local a = (i / CONFIG.SpawnCount) * math.pi * 2
	local pos = Vector3.new(math.cos(a) * CONFIG.SpawnRadius, 0.2, math.sin(a) * CONFIG.SpawnRadius)
	local pad = Instance.new("SpawnLocation")
	pad.Name = "SpawnPad" .. tostring(i + 1)
	pad.Size = Vector3.new(9, 0.6, 9)
	pad.CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	pad.Anchored = true
	pad.CanCollide = true
	pad.Color = Color3.fromRGB(90, 220, 120)
	pad.Material = Enum.Material.Neon
	pad.Neutral = true
	pad.Duration = 3
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = arenaFolder
	table.insert(spawnPads, pad)
end

-- ============================================================
--  СТАТИСТИКА И KILLFEED
-- ============================================================

local function statValue(player: Player, name: string): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return nil
	end
	local v = stats:FindFirstChild(name)
	if v and v:IsA("IntValue") then
		return v
	end
	return nil
end

local function setupStats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = stats

	local deaths = Instance.new("IntValue")
	deaths.Name = "Deaths"
	deaths.Parent = stats

	stats.Parent = player

	local streak = Instance.new("IntValue")
	streak.Name = "Streak"
	streak.Parent = player

	player:SetAttribute("BestStreak", 0)
end

local function feed(payload: { [string]: any })
	killFeedRemote:FireAllClients(payload)
end

local function recordKill(attacker: Player?, victim: Player)
	local deaths = statValue(victim, "Deaths")
	if deaths then
		deaths.Value += 1
	end

	local victimStreak = victim:FindFirstChild("Streak")
	if victimStreak and victimStreak:IsA("IntValue") then
		victimStreak.Value = 0
	end

	local credited = attacker ~= nil and attacker ~= victim and attacker:IsDescendantOf(Players)
	if credited then
		local a = attacker :: Player
		local kills = statValue(a, "Kills")
		if kills then
			kills.Value += 1
		end

		local s = 0
		local streak = a:FindFirstChild("Streak")
		if streak and streak:IsA("IntValue") then
			streak.Value += 1
			s = streak.Value
		end

		local best = a:GetAttribute("BestStreak")
		if typeof(best) ~= "number" or s > best then
			a:SetAttribute("BestStreak", s)
		end

		if table.find(CONFIG.StreakAnnounce, s) then
			feed({ Kind = "Announce", Text = ("%s — серия %d убийств!"):format(a.DisplayName, s) })
		end

		feed({ Kind = "Kill", Text = ("%s → %s"):format(a.DisplayName, victim.DisplayName) })
	else
		feed({ Kind = "Kill", Text = ("%s погиб"):format(victim.DisplayName) })
	end
end

-- ============================================================
--  БОЙ
-- ============================================================

local lastSwing: { [Player]: number } = {}

local function findTarget(character: Model, attacker: Player): (Model?, Humanoid?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil, nil
	end
	local origin = root.Position
	local look = root.CFrame.LookVector

	local bestModel: Model? = nil
	local bestHumanoid: Humanoid? = nil
	local bestDist = CONFIG.SwordRange

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= attacker then
			local oc = other.Character
			if oc and oc ~= character then
				local oh = oc:FindFirstChildOfClass("Humanoid")
				local oroot = oc:FindFirstChild("HumanoidRootPart")
				if oh and oroot and oroot:IsA("BasePart") and oh.Health > 0 then
					local to = oroot.Position - origin
					local dist = to.Magnitude
					if dist > 0.01 and dist <= CONFIG.SwordRange then
						local dir = to / dist
						if look:Dot(dir) >= CONFIG.SwordArc then
							local clear = true
							if dist > 2 then
								local rp = RaycastParams.new()
								rp.FilterType = Enum.RaycastFilterType.Exclude
								rp.FilterDescendantsInstances = { character }
								local hit = workspace:Raycast(origin, dir * (dist - 1.5), rp)
								if hit then
									local hitModel = hit.Instance:FindFirstAncestorOfClass("Model")
									if hitModel ~= oc then
										clear = false
									end
								end
							end
							if clear and dist < bestDist then
								bestDist = dist
								bestModel = oc
								bestHumanoid = oh
							end
						end
					end
				end
			end
		end
	end

	return bestModel, bestHumanoid
end

local function makeSword(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = ("Меч: урон %d, ЛКМ — удар"):format(CONFIG.SwordDamage)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 3.4, 0.35)
	handle.Color = Color3.fromRGB(90, 220, 255)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(0.9, 0.25, 0.9)
	guard.Color = Color3.fromRGB(60, 66, 80)
	guard.Material = Enum.Material.Metal
	guard.CanCollide = false
	guard.Massless = true
	guard.Parent = tool

	tool.Grip = CFrame.new(0, -1.2, 0)
	return tool
end

local function connectSword(tool: Tool, player: Player)
	tool.Activated:Connect(function()
		local now = os.clock()
		if (lastSwing[player] or 0) + CONFIG.SwordCooldown > now then
			return
		end
		lastSwing[player] = now

		local character = player.Character
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local target, targetHumanoid = findTarget(character, player)
		if target and targetHumanoid then
			target:SetAttribute("LastAttackerUserId", player.UserId)
			target:SetAttribute("LastAttackerTime", os.clock())
			target:SetAttribute("LastDamageTime", os.clock())
			targetHumanoid:TakeDamage(CONFIG.SwordDamage)
			hitmarkerRemote:FireClient(player)
		end
	end)
end

-- ============================================================
--  ИГРОКИ
-- ============================================================

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = CONFIG.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = CONFIG.JumpPower
	character:SetAttribute("LastDamageTime", os.clock())

	-- реген HP
	task.spawn(function()
		while character.Parent and humanoid.Health > 0 do
			task.wait(0.5)
			local last = character:GetAttribute("LastDamageTime")
			local since = os.clock() - (if typeof(last) == "number" then last else 0)
			if since >= CONFIG.RegenDelay and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + CONFIG.RegenRate * 0.5)
			end
		end
	end)

	-- смерть: записать убийство и выбрать новый спавн
	humanoid.Died:Connect(function()
		local lastUserId = character:GetAttribute("LastAttackerUserId")
		local lastTime = character:GetAttribute("LastAttackerTime")
		local attacker: Player? = nil
		if typeof(lastUserId) == "number" and typeof(lastTime) == "number" and os.clock() - lastTime <= CONFIG.AssistWindow then
			attacker = Players:GetPlayerByUserId(lastUserId)
		end
		recordKill(attacker, player)

		if #spawnPads > 0 then
			task.defer(function()
				player.RespawnLocation = spawnPads[math.random(1, #spawnPads)]
			end)
		end
	end)

	-- меч
	local backpack = player:FindFirstChild("Backpack")
	local hasSword = character:FindFirstChild("Sword") or (backpack and backpack:FindFirstChild("Sword"))
	if not hasSword and backpack then
		local tool = makeSword()
		connectSword(tool, player)
		tool.Parent = backpack
		task.defer(function()
			if humanoid.Health > 0 and tool.Parent == backpack then
				pcall(function()
					humanoid:EquipTool(tool)
				end)
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	setupStats(player)
	if #spawnPads > 0 then
		player.RespawnLocation = spawnPads[math.random(1, #spawnPads)]
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.RespawnTime = CONFIG.RespawnTime
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	lastSwing[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- падение с арены = смерть
task.spawn(function()
	while true do
		task.wait(0.5)
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

print(("[PvP Arena] Арена готова: %d спавнов, урон %d, респавн %d сек"):format(#spawnPads, CONFIG.SwordDamage, CONFIG.RespawnTime))
