# Roblox Tycoon Kit — установка за 2 минуты

Готовый тайкун: занял базу → капает Cash → покупаешь стены и апгрейды дроппера → сейв через DataStore.

## 1. Создание места
1. Открой **Roblox Studio** → New → **Baseplate**
2. Удали лишний спавн если мешает (Workspace → SpawnLocation — можно оставить, скрипт создаст свои)
3. Включи API для сейвов (иначе деньги не сохранятся, но играть можно):
   Home → Game Settings → Security → **Enable Studio Access to API Services: ON**

## 2. Установка скрипта
1. В Studio: View → **Explorer** + **Properties**
2. Наведи на **ServerScriptService** → `+` → **Script** (обычный Script, НЕ LocalScript)
3. Удали всё внутри, вставь целиком код из `TycoonServer.luau`
4. Нажми **Play** — появятся 2 базы с жёлтым ClaimPad

## 3. Как играть (тест)
- Встань на жёлтый **ClaimPad** → база станет твоей
- Каждые 2 сек в `leaderstats → Cash` капает доход (старт $5)
- Наступай на зелёные кнопки чтобы купить:
  - Стены — $50
  - Дроппер LVL2 +$10 — $100
  - Декор Крыша — $200
  - Дроппер LVL3 +$25 — $300
- Недостаточно денег — кнопка не сработает

## 4. Настройки
В начале скрипта `CONFIG`:
```lua
TycoonCount = 2 -- 4 для игры на четверых
BaseIncome = 5
IncomeInterval = 2
StartCash = 0
```

## 5. Публикация
File → Publish to Roblox → создай Experience → Play с другом (нужен доступ + опубликованная игра для DataStore).

## Частые ошибки
- `DataStore can't be accessed` в Studio — включи API Services (п.1.3), в опубликованной игре работает само.
- Кнопка не покупается — ты не владелец базы, или не хватает Cash.
- Нет leaderstats — Script должен лежать в ServerScriptService, а не в Workspace.
- Хочешь больше баз — поменяй TycoonCount и перезапусти Play.

Файл: `TycoonServer.luau` — один Script, без моделей и плагинов.
