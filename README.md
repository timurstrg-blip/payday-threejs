# PAYDAY: Block Heist + Block Tycoon — Three.js

- `index.html` — PAYDAY top-down/FPS heist (WASD, drill vault, bags, van escape).
- `minecraft.html` — BlockCraft: мини-Minecraft (Three.js воксели 64×64, процедурная генерация, деревья/пещеры, ЛКМ ломать / ПКМ ставить, полёт F, новый мир R).
- `tycoon.html` — Three.js-версия роблокс-тайкуна из `roblox-tycoon/` (ClaimPad, Cash каждые 2 сек, 4 покупки, сейв в localStorage).
- `pvp.html` — PvP Arena: Three.js-версия роблокс-арены из `roblox-pvp-arena/` (мечи, 5 ботов, killfeed, серии убийств, реген HP).
- `roblox-pvp-arena/PvpArenaServer.luau` + `PvpArenaHud.luau` — оригиналы для Roblox Studio; `RobloxPvpArena.rbxlx` — готовый place-файл (открыть в Studio → Publish → ссылка roblox.com/games/<ID>).
- `roblox-tycoon/TycoonServer.luau` — оригинал для Roblox Studio (ServerScriptService Script).

Play: drill vault → grab bags → secure in van → escape.

Controls: WASD move, mouse aim, click shoot, R reload, Shift sprint, E grab/drop, F drill/secure/escape.

Hosted via GitHub Pages from `main` / root.
