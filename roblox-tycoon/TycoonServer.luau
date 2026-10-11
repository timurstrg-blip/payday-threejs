--!strict
-- Tycoon Kit v1 | ServerScriptService > Script (обычный Script, не LocalScript)
-- Как установить: Roblox Studio > ServerScriptService > вставь этот Script > вставь код целиком > Play

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local CashStore = DataStoreService:GetDataStore("TycoonCashV1")

local CONFIG = {
	TycoonCount = 2, -- сколько баз создать
	TycoonSize = Vector3.new(36, 1, 36),
	Spacing = 50,
	StartCash = 0,
	BaseIncome = 5, -- $ каждые 2 сек со старта
	IncomeInterval = 2,
	SaveInterval = 60,
}

type Tycoon = {
	Model: Model,
	Owner: ObjectValue,
	Income: IntValue,
	DropperLevel: IntValue,
	Buttons: Folder,
}

local tycoons: { Tycoon } = {}

-- ---------- leaderstats + save/load ----------
local function setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = CONFIG.StartCash
	cash.Parent = stats

	-- загрузка
	local ok, saved = pcall(function()
		return CashStore:GetAsync("cash_" .. player.UserId)
	end)
	if ok and typeof(saved) == "number" then
		cash.Value = saved
	end
	return cash
end

local function saveCash(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	if cash and typeof((cash :: IntValue).Value) == "number" then
		pcall(function()
			CashStore:SetAsync("cash_" .. player.UserId, (cash :: IntValue).Value)
		end)
	end
end

Players.PlayerAdded:Connect(setupLeaderstats)
Players.PlayerRemoving:Connect(function(player)
	saveCash(player)
	-- освободить тайкун
	for _, t in tycoons do
		if t.Owner.Value == player then
			t.Owner.Value = nil
			t.Income.Value = CONFIG.BaseIncome
			t.DropperLevel.Value = 1
			-- показать кнопки заново, удалить купленное
			for _, b in t.Buttons:GetChildren() do
				if b:IsA("BasePart") then
					b.Transparency = 0
					b.CanCollide = false
					b.CanTouch = true
					local flag = b:FindFirstChild("Purchased")
					if flag and flag:IsA("BoolValue") then
						flag.Value = false
					end
					for _, g in b:GetChildren() do
						if g:IsA("BillboardGui") then
							g.Enabled = true
						end
					end
				end
			end
			local bought = t.Model:FindFirstChild("Bought")
			if bought then bought:ClearAllChildren() end
			t.Model.Name = "FreeTycoon"
		end
	end
end)

-- автосейв
task.spawn(function()
	while true do
		task.wait(CONFIG.SaveInterval)
		for _, p in Players:GetPlayers() do
			saveCash(p)
		end
	end
end)

-- ---------- helpers ----------
local function makeBillboard(text: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 220, 0, 60)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.TextColor3 = Color3.fromRGB(255, 215, 90)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
	return gui
end

local function buildWall(parent: Instance, size: Vector3, pos: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Size = size
	p.Position = pos
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Кнопка покупки: наступает владелец, списывается Cash, вызывается onBuy один раз
local function createButton(tycoon: Tycoon, name: string, cost: number, offset: Vector3, onBuy: (player: Player) -> ())
	local btn = Instance.new("Part")
	btn.Name = name
	btn.Size = Vector3.new(6, 1, 6)
	btn.Position = tycoon.Model:GetPivot().Position + offset
	btn.Anchored = true
	btn.Color = Color3.fromRGB(60, 180, 80)
	btn.Material = Enum.Material.Neon
	btn.Parent = tycoon.Buttons

	local gui = makeBillboard(name .. "\n$" .. cost)
	gui.Parent = btn

	local purchased = Instance.new("BoolValue")
	purchased.Name = "Purchased"
	purchased.Value = false
	purchased.Parent = btn

	local db = false
	btn.Touched:Connect(function(hit)
		if db or purchased.Value then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		if tycoon.Owner.Value ~= player then return end
		local stats = player:FindFirstChild("leaderstats")
		local cash = stats and stats:FindFirstChild("Cash") :: IntValue?
		if not cash or cash.Value < cost then return end
		db = true
		cash.Value -= cost
		purchased.Value = true
		gui.Enabled = false
		btn.Transparency = 1
		btn.CanCollide = false
		btn.CanTouch = false
		onBuy(player)
		task.wait(1)
		db = false
	end)
end

-- ---------- создание тайкуна ----------
local function createTycoon(index: number): Tycoon
	local rootPos = Vector3.new(index * CONFIG.Spacing, 1, 0)

	local model = Instance.new("Model")
	model.Name = "FreeTycoon"
	model.Parent = workspace

	-- пол базы
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = CONFIG.TycoonSize
	base.Position = rootPos
	base.Anchored = true
	base.Color = Color3.fromRGB(45, 55, 80)
	base.Material = Enum.Material.Concrete
	base.Parent = model
	model.PrimaryPart = base

	-- спавн владельца
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = rootPos + Vector3.new(0, 2, 12)
	spawn.Anchored = true
	spawn.Neutral = false
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = model
	task.spawn(function()
		task.wait(1)
		spawn.BrickColor = BrickColor.new("Bright blue")
	end)

	local owner = Instance.new("ObjectValue")
	owner.Name = "Owner"
	owner.Parent = model

	local income = Instance.new("IntValue")
	income.Name = "Income"
	income.Value = CONFIG.BaseIncome
	income.Parent = model

	local level = Instance.new("IntValue")
	level.Name = "DropperLevel"
	level.Value = 1
	level.Parent = model

	local buttons = Instance.new("Folder")
	buttons.Name = "Buttons"
	buttons.Parent = model

	local bought = Instance.new("Folder")
	bought.Name = "Bought"
	bought.Parent = model

	local tycoon: Tycoon = {
		Model = model,
		Owner = owner,
		Income = income,
		DropperLevel = level,
		Buttons = buttons,
	}

	-- ClaimPad: встань чтобы занять базу
	local pad = Instance.new("Part")
	pad.Name = "ClaimPad"
	pad.Size = Vector3.new(8, 1, 8)
	pad.Position = rootPos + Vector3.new(0, 1.5, -12)
	pad.Anchored = true
	pad.Color = Color3.fromRGB(255, 215, 90)
	pad.Material = Enum.Material.Neon
	pad.Parent = model
	local padGui = makeBillboard("ВСТАНЬ\nЗанять базу")
	padGui.Parent = pad

	local claimDb = false
	pad.Touched:Connect(function(hit)
		if claimDb or owner.Value ~= nil then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		-- уже есть база у игрока?
		for _, t in tycoons do
			if t.Owner.Value == player then return end
		end
		claimDb = true
		owner.Value = player
		model.Name = player.Name .. "_Tycoon"
		padGui:Destroy()
		pad.Transparency = 1
		pad.CanCollide = false
		pad.CanTouch = false
		-- дроппер-визуал: фабрика денег
		buildWall(bought, Vector3.new(8, 4, 8), rootPos + Vector3.new(-8, 3, 0), Color3.fromRGB(120, 60, 20))
		task.wait(1)
		pad:Destroy()
	end)

	-- Товары цепочкой
	createButton(tycoon, "Стены", 50, Vector3.new(8, 1.5, 0), function(_)
		local c = rootPos
		buildWall(bought, Vector3.new(36, 6, 1), c + Vector3.new(0, 3, -18), Color3.fromRGB(80, 90, 130))
		buildWall(bought, Vector3.new(36, 6, 1), c + Vector3.new(0, 3, 18), Color3.fromRGB(80, 90, 130))
		buildWall(bought, Vector3.new(1, 6, 36), c + Vector3.new(-18, 3, 0), Color3.fromRGB(80, 90, 130))
		buildWall(bought, Vector3.new(1, 6, 36), c + Vector3.new(18, 3, 0), Color3.fromRGB(80, 90, 130))
	end)

	createButton(tycoon, "Дроппер LVL2 +$10", 100, Vector3.new(8, 1.5, 8), function(_)
		tycoon.Income.Value += 10
		tycoon.DropperLevel.Value = 2
		buildWall(bought, Vector3.new(4, 6, 4), rootPos + Vector3.new(-8, 5, 0), Color3.fromRGB(55, 224, 91))
	end)

	createButton(tycoon, "Дроппер LVL3 +$25", 300, Vector3.new(0, 1.5, 8), function(_)
		tycoon.Income.Value += 25
		tycoon.DropperLevel.Value = 3
		buildWall(bought, Vector3.new(4, 9, 4), rootPos + Vector3.new(-8, 6.5, 0), Color3.fromRGB(255, 176, 32))
	end)

	createButton(tycoon, "Декор Крыша", 200, Vector3.new(-8, 1.5, 8), function(_)
		buildWall(bought, Vector3.new(14, 1, 14), rootPos + Vector3.new(-8, 8, 0), Color3.fromRGB(30, 30, 40))
	end)

	-- доход каждые N сек
	task.spawn(function()
		while true do
			task.wait(CONFIG.IncomeInterval)
			local plr = tycoon.Owner.Value
			if plr and plr.Parent then
				local stats = plr:FindFirstChild("leaderstats")
				local cash = stats and stats:FindFirstChild("Cash") :: IntValue?
				if cash then
					cash.Value += tycoon.Income.Value
				end
			end
		end
	end)

	return tycoon
end

for i = 0, CONFIG.TycoonCount - 1 do
	table.insert(tycoons, createTycoon(i))
end

print("[TycoonKit] Готово: " .. #tycoons .. " баз. Займи ClaimPad чтобы начать.")
