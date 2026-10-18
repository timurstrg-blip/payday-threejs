# Roblox PvP Arena Kit — установка за 2 минуты

Готовая PvP-арена: круглый остров, центральная платформа с 4 трапами, колонны и ящики-укрытия,
8 спавнов, мечи, killfeed, серии убийств (3/5/7/10/15/20/30), реген HP через 6 сек без урона,
статистика Kills/Deaths/Streak в leaderstats. Та же карта, что в веб-версии `pvp.html`.

Файлы:
- `RobloxPvpArena.rbxlx` — **готовый place-файл**: двойной клик → откроется в Roblox Studio → Play.
- `PvpArenaServer.luau` — серверный скрипт (карта, бой, статистика).
- `PvpArenaHud.luau` — клиентский HUD (панель, прицел, killfeed, баннеры).
- `build.ps1` — пересобирает `RobloxPvpArena.rbxlx` из двух `.luau`.

## 1. Открыть готовый файл (вариант А)
1. Двойной клик по **`RobloxPvpArena.rbxlx`** (или Studio → File → Open from File).
2. Нажми **Play** — арена соберётся сама, меч выдастся сам.
3. Проверить бой с ботами-игроками в Studio: Test → **Clients and Servers** → 2 players.

## 2. Установка вручную (вариант Б)
1. Studio → New → Baseplate.
2. Explorer: **ServerScriptService** → `+` → **Script** → вставь целиком `PvpArenaServer.luau`.
3. Explorer: **StarterPlayer → StarterPlayerScripts** → `+` → **LocalScript** → вставь `PvpArenaHud.luau`.
4. Play. (Baseplate и дефолтный спавн скрипт сам удалит.)

## 3. Как играть
- WASD — движение, Пробел — прыжок, ПКМ — камера, **ЛКМ — удар мечом** (24 урона, дальность 10, кд 0.45).
- Попал — прицел мигает красным крестиком. Убил — в killfeed справа сверху появится «Ты → Ник», серия растёт.
- Не получаешь урон 6 секунд — HP регенерируется (+2/сек).
- Упал с арены — смерть. Респавн через 3 сек на случайной зелёной площадке (3 сек щит).
- Мобильные игроки получают меч автоматически (кнопка инструмента внизу).

## 4. Настройки
В начале `PvpArenaServer.luau` (и в HUD для текстов) — таблица `CONFIG`:
```lua
SwordDamage = 24     -- урон меча
SwordRange = 10      -- дальность
SwordCooldown = 0.45 -- перезарядка
RegenDelay = 6       -- через сколько секунд без урона включается реген
WalkSpeed = 18       -- скорость бега
RespawnTime = 3      -- секунд до респавна
SpawnCount = 8       -- число спавнов (по кругу)
```
После правок: `powershell -ExecutionPolicy Bypass -File build.ps1`, чтобы обновить `.rbxlx`.

## 5. Публикация → ссылка
1. File → **Publish to Roblox** → New Experience → название (например «PvP Arena») → Create.
2. Ещё раз **Publish**. Игра появится в твоём аккаунте: **roblox.com/games/<ID>** — это и есть ссылка на твою игру.
3. Чтобы играли другие: Studio → Game Settings → Permissions → Public, либо отправь приглашение друзьям.

## Частые ошибки
- `Script` должен лежать именно в **ServerScriptService**, а HUD — в **StarterPlayerScripts** (иначе карты и меча не будет).
- Меч не видно — нажми цифру `1` внизу экрана (или кнопку инструмента на телефоне).
- Хочешь быстрее бой — уменьши `SwordCooldown` и `RegenDelay` в `CONFIG`.
- Арена не появилась — посмотри Output (View → Output) на красные ошибки: обычно это опечатка при ручной вставке кода.

Веб-версия той же арены: `pvp.html` в корне проекта.
