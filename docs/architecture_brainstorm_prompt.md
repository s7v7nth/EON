# EON — Architecture brainstorm prompt

Готовый контекст для внешних ИИ / брейншторма улучшений **архитектур** (player builds).
Копируй блок ниже целиком; в конце замени секцию «МОЙ ЗАПРОС».

При значимых изменениях геймплея/контента обновляй этот файл в том же change set
(см. `.cursor/rules/architecture-brainstorm-prompt.mdc`).

---

```text
Ты — геймдизайнер-консультант по action-roguelike. Помогаешь брейнштормить улучшения «архитектур» (player builds) для игры EON. Не пиши код, если не попросят. Опирайся только на контекст ниже; где чего-то нет — помечай как предположение.

═══════════════════════════════════════
ЧТО ТАКОЕ EON
═══════════════════════════════════════
- Жанр: isometric action-roguelike / run-based arena combat.
- Референсы ощущения: Hades (изометрия, «ноги на полу», Y-sort) + Hotline Miami (style score / ранг комнаты).
- Combat feel (P0): вес удара через move_mult/recovery/lunge, per-attack HitStop + camera trauma, poise→flinch на врагах (отдельно от stagger crit-окна). Энкаунтеры/элиты/боссы — отдельный слой, не feel.
- Стек: Godot 4, GDScript. Контент data-driven (.tres + плагины эффектов).
- Стадия: playable vertical slice; каркас расширяемости уже есть (Phase A–F).
- Feel-тюнинг: `levels/feel_arena.tscn` + `docs/combat_feel.md`.

ФИЛОСОФИЯ ДИЗАЙНА (4 столпа)
1. Architecture — язык действий игрока + своя ResourceEconomy.
2. Elements — накопительные статусы + synergy recipes (не просто tint урона).
3. Faction — идентичность врагов (резисты + behavior modules).
4. Biome — «pressure pack» внутри ActRoute (веса фракций, bias стихий, loot tags, палитра, traps).

ПРАВИЛО РАСШИРЯЕМОСТИ
Новый контент = Resource (.tres) + маленький скрипт эффекта/экономики/behavior.
Ядро (Hitbox/Hurtbox, FSM, SignalBus, Player facade) не должно обрастать match/bool под каждый билд.
Одна архитектура = ArchitectureData + economy plugin + стартовые weapons/primitives + starting_tags + base resists.
Один апгрейд = UpgradeData (required_tags → effects[]) + UpgradeEffect плагины.
Один статус = StatusDefinition + StatusEffect; синергия = SynergyRecipe.

═══════════════════════════════════════
СЕТТИНГ И МАРШРУТ (то, что зафиксировано в данных)
═══════════════════════════════════════
Мир — постапокалиптический / техно-биологический упадок. Забег идёт «с окраин к ядру данных»:

Campaign Acts:
1. Outskirts — Landfill → Wasteland → Alley
2. Dead Habitats — Mall → Downtown → Residential
3. Wild Growth — Jungle → Taiga
4. Data Core — Gateway (blend) → Data Center

Режимы маршрута:
- Tutorial: Landfill → Wasteland → Data Center (3 комнаты)
- Campaign: Acts 1–4
- Procedural: Isaac-style сетка ~12 комнат, seed, двери N/E/S/W, соседние биомы + blend, финал = boss room + craft → win

Биомы (BiomeId): JUNGLE, DATA_CENTER, DOWNTOWN, RESIDENTIAL, TAIGA, ALLEY, LANDFILL, MALL, WASTELAND, GATEWAY.

Тон: scrap / nano / plasma / glitch / заражение / «сборка ядра» из лут-партов. Глубокого лора персонажа в доках мало — игрок = носитель сменной боевой «архитектуры» (операционная система тела/боя), а не фиксированный класс.

═══════════════════════════════════════
ПЕРСОНАЖ И БОЕВОЙ СКЕЛЕТ (общий для всех архитектур)
═══════════════════════════════════════
- Управление: WASD, LMB/RMB атаки/блок (зависит от архитектуры), Space dash с i-frames, Q = special (economy.try_special).
- Движение мгновенное, без инерции; вертикаль сжата Iso.Y_SCALE.
- Style Score: множитель растёт от HIT/KILL/PERFECT_DODGE/PARRY/COMBO/MULTI_KILL/ELEMENT_CASCADE; сбрасывается на TOOK_DAMAGE. Ранг комнаты C–S влияет на качество лута.
- После clear комнаты: loot parts + reward/craft UI. На финальной комнате craft тоже есть, win только после выбора.
- Урон: raw * (1 - resist), clamp множителя [0.05, 2.0].
- Типы урона / статусы:
  PHYSICAL → Stagger (interrupt + crit window)
  ELECTRICITY → Shock (chain lightning на полном buildup)
  CORROSION → Acid / armor break (+% dmg taken; acid puddle on death)
  FIRE → Burn → Panic (DoT; хаотичный flee на полном buildup)
  BLEED → Rended wounds (сильный DoT при движении/атаке)
  GLITCH → Fault (роботы shutdown / органика slow)

Синергии статусов (уже есть):
- Acid + Shock → Chemical Short
- Fire + Bleed → Napalm Rend
- Glitch + Shock → System Crash
- Burn + Stagger → Concussive Ignition

Фракции врагов: SAVAGE, CYBORG, ANDROID, ROBO_BEAST, BIO_MUTANT.
Behaviors: aggro swarm, erratic dodge, tactical support, hyper chase, death burst.
Уязвимости (примерно): savages↔burn, beasts↔bleed, androids↔shock, cyborgs↔glitch; bio-mutant death cloud.

═══════════════════════════════════════
АРХИТЕКТУРЫ (главный объект брейншторма)
═══════════════════════════════════════
Архитектура выбирается в начале рана. Это не «класс с деревом скиллов», а:
- уникальная экономика ресурса (как платишь за силу и чем рискуешь),
- набор стартовых примитивов оружия,
- starting_tags для крафта,
- base resists / visual tint,
- особый special (Q), если экономика его реализует.

--- 1) СИНТЕТИК (DEFAULT) ---
Fantasy: сбалансированный энерго-мечник / «дефолтный» боец стиля.
Economy: ENERGY_ADRENALINE (EconomyAdrenaline)
- Energy pool ~50. Атаки/dash тратят Energy. Входящий урон сначала жрёт Energy, остаток → HP.
- Ideal dash возвращает стоимость. Вне боя adrenaline → 0; в бою baseline + ~3 Energy/s; растёт от хитов, HP-урона, parry, ideal dash.
- Адреналин даёт attack speed bonus (до ~+35%).
Combat:
- LMB tap — melee swing (combo). LMB hold — charge returning blade throw.
- RMB hold — energy shield (−50% dmg); первые ~0.5s = parry (full negate + stagger).
- Combos: LMB×3 string; LMB→RMB→LMB circle AoE.
- Q / F — reserved (no-op). Это сознательный gap / место для будущей идентичности.
Tags: default, style
Resists: slight physical/bleed
Primitives: energy blade
Crafts:
- Counter Charge (default+style+magnet+servo) — perfect dodge → counter window
- Parry Reactor (default+servo) — parries flood adrenaline

Дизайн-напряжение: самый «честный» скилл-ориентированный билд; сейчас слабее уникальности Q/identity по сравнению с остальными.

--- 2) УЛЕЙ (NANOMACHINES) ---
Fantasy: нано-рой / биологический паразит-носитель.
Economy: BLOOD_HARVEST (EconomyBloodHarvest)
- Нет Energy. Пассивный HP drain (~4% max HP/s, floor 1 HP).
- Life steal ~14% + heal on kill. Dash/special стоят % HP.
- Q = swarm burst (AoE за % HP).
Combat primitives: nano blade / whip / toad
Tags: nano, whip, toad, swarm, proximity
Resists: +corrosion/bleed/elec; −fire; чуть слабее physical
Crafts:
- Hookshot Strand (nano+whip) — pull to enemy
- Room Infection (nano+toad+swarm) — room tick damage cascade
- Proximity Bloom (nano+proximity) — melee → corrosion pulse
- Bioreactor Graft (nano+bioreactor) — stronger vamp + passive regen

Дизайн-напряжение: агрессивный «держись в бою или умри»; риск/награда через HP как ресурс.

--- 3) ПАРОВОЗ (ELECTRO_TRAIN) ---
Fantasy: плазменный overheat-танк/artillery.
Economy: OVERHEAT (EconomyOverheat)
- Heat 0–100 от атак; decay вне пика.
- Yellow ≥50 → ×1.5 dmg; Red → ×2 + self-burn DPS.
- Q = Vent: AoE dump по накопленному Heat + weapon cooldown.
Combat primitives: plasma blade / gun / mortar
Tags: train, plasma
Resists: +electricity/fire/bleed; −corrosion
Crafts:
- Coil Overdrive (train+plasma) — raw damage while riding heat curve
(пул крафтов тоньше, чем у Улья/Синтетика)

Дизайн-напряжение: risk-management шкалы; сейчас мало mid/late craft identity.

--- 4) НЕЙРО-ХАКЕР (NEURO_HACKER) ---
Fantasy: хакер/оператор дронов, glitch kit.
Economy: RAM_COMPUTE (EconomyRam)
- N RAM slots (start 2). Q = spawn ally drone (занимает слот; frees on death/lifetime ~18s).
- Без слотов — второй дрон блокируется.
Tags: neuro, glitch, drone
Resists: +glitch/+elec
Primitives: smart pistol (holo blades/drones в fantasy; в данных сейчас pistol + drone special)
Crafts:
- Parallel Thread (neuro+drone+logic) — +1 RAM
- Overclock Drones (neuro+drone+logic+antenna) — drone dmg/speed
- Glitch Link (neuro+drone+glitch) — drone hits apply glitch buildup

Дизайн-напряжение: summoner/control; меньше melee identity, сильнее через pets + glitch synergies.

═══════════════════════════════════════
КРАФТ / ЛУТ («Сборка ядра»)
═══════════════════════════════════════
LootPart даёт tags. Upgrade открывается, если у игрока есть required_tags (архитектурные + лут).
Примеры партов: Rusty Magnet, Servo Motor, Bioreactor, Plasma Coil, Logic Core, Signal Antenna, Scrap Code.
Биом loot_tags + room style rank влияют на дроп.
Важно для идей: новые силы архитектуры лучше выражать через (a) economy verbs, (b) primitives, (c) tag recipes — а не через уникальные hardcode-флаги на Player.

═══════════════════════════════════════
ЧЕГО ХОТИМ ОТ БРЕЙНШТОРМА
═══════════════════════════════════════
Фокус: улучшения АРХИТЕКТУР (существующих и/или новых), чтобы каждая читалась за 10 секунд боя и имела:
1) ясный fantasy / fantasy-verb («что я делаю лучше всех»),
2) уникальный ресурсный риск (economy),
3) 2–3 стартовых примитива / петли ввода,
4) special (Q) с характером (кроме случаев, где reserved осознанно),
5) 3–6 craft upgrades, завязанных на tags и синергии стихий/фракций,
6) контрплей и слабости (резисты, биомы где больно, анти-синергии),
7) совместимость с style score и elemental cascade,
8) реализуемость в текущей модели (ResourceEconomy / UpgradeEffect / Status / tags) без переписывания ядра.

ОГРАНИЧЕНИЯ
- Не предлагай MMO-таланты, огромные skill trees, инвентарь-тетрадь.
- Не ломай data-driven правило «контент без match в Player».
- Не делай все архитектуры «ещё один DoT caster».
- Учитывай asymmetric fun: Синтетик = skill ceiling; Улей = blood risk; Паровоз = heat gambling; Нейро = slots/pets.
- Предпочтай идеи, которые усиливают уже заложенные verbs (parry, vent, swarm, drone, hookshot, infect, cascade), а не случайный power creep.
- Если предлагаешь 5-ю архитектуру — сначала докажи нишу, которой нет у четырёх текущих.

ФОРМАТ ОТВЕТА
1. Краткий вердикт: где сейчас самые слабые места identity у 4 архитектур.
2. Таблица или список идей по приоритету (P0/P1/P2) с колонками: идея · для какой архитектуры · fantasy · механика · economy/tags/craft · риск/контрплей · почему это fit EON.
3. 1–2 «вертикальных среза» (минимальный набор изменений, который сильнее всего поднимает feel за маленький контент-бюджет).
4. Вопросы ко мне только если без ответа нельзя выбрать направление.
5. Без воды и без кода, пока не попрошу.

═══════════════════════════════════════
МОЙ ЗАПРОС СЕЙЧАС
═══════════════════════════════════════
[СЮДА ВСТАВЬ ЗАДАЧУ, например:
«Усиль identity Синтетика: придумай Q или альтернативу reserved-слоту + 3 крафта, не копируя Vent/Swarm/Drone»
или
«Предложи 5-ю архитектуру под пустую нишу»
или
«Сбалансируй mid-run power fantasy Паровоза через crafts и heat curve»
]
```

## Примеры хвостов запроса

1. «Сравни 4 архитектуры по clarity fantasy / risk / build depth. Дай P0 улучшения только для самых слабых двух.»
2. «Придумай 5-ю архитектуру. Ниша не должна пересекаться с Energy/HP/Heat/RAM.»
3. «Развей крафт-деревья: по 5 рецептов на каждую, с mid и late spikes.»
