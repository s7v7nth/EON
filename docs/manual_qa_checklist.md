# EON — Manual QA Checklist

Ручной прогон вертикального среза. Обновляй этот файл при изменении механик/контента (см. правило проекта).

## Старт / архитектуры
- [ ] В начале рана есть выбор маршрута: Tutorial (3) / Campaign (Acts 1–4) / **Procedural (12)**
- [ ] Виден выбор всех 4 архитектур (Синтетик / Улей / Паровоз / Нейро-хакер)
- [ ] Синтетик открыт всегда; Улей / Паровоз / Нейро **закрыты** до Hive / Warden / remnant hub talk
- [ ] Class-select lock lines: Улей «The sweeper still has the swarm. Take it off The Hive.» · Паровоз «Roundhouse is sealed. Warden's sitting on the last heat valve.» · Нейро «Core bricked the wires. The stall has the last live node. Talk first.»
- [ ] Клавиши 2–4 и читерский клик по locked-карте **не** экипируют закрытый кит (город отказывает той же строкой)
- [ ] HUD primary/secondary меняется под каждую архитектуру (HP / Energy / Adrenaline / Style / Gold — не «Clonal Integrity»)
- [ ] **Q (special)** работает у всех 4 архитектур (Улей swarm / Паровоз Vent / Нейро drone / Синтетик Lattice Collapse)

## Синтетик
- [ ] LMB tap — взмах энергомеча; тратит Energy
- [ ] Зажать LMB → **быстрый** заряд (нога: синяя полоска заряда + луч прицела), отпустить — бросок меча к курсору; возвращается после попадания/стены; частичный заряд слабее/короче
- [ ] RMB зажат — щит; отпущен — щита нет; в блоке урон снижен
- [ ] Первые ~0.18с блока = парирование (полный null + stagger врагу); dedicated Parry остаётся ~0.22с
- [ ] Perfect parry оставляет **Energy Mirror** (cyan hard-light) между игроком и врагом; максимум 3; **без таймера** — исчезает после 3 действий (рикошет / мили по зеркалу / дэш сквозь) или сразу от Q / overflow
- [ ] Бросок меча **пробивает** врагов (не возвращается с первого хита) и долетает до Mirror; рикошет целится с упреждением по velocity; ×1.5 урон; тратит 1 действие зеркала; вспышка/партиклы
- [ ] Dash сквозь Mirror: 1–2 прохода дают мягкий stagger-пульс; **3-й** взрывает (AoE Stagger + короткий escape); мили по зеркалу тоже тратит действия
- [ ] **Q (Lattice Collapse)** тратит Energy и взрывает все активные зеркала; без зеркал Q не срабатывает
- [ ] Perfect parry **не** ставит зеркало, пока не взят Geometry craft (opt-in)
- [ ] Адреналин **не** ускоряет атаки: вне боя падает + Energy trickle; в бою baseline + Energy regen; удар/урон качают адреналин; каждое боевое действие жрёт Energy
- [ ] Комбо LMB→LMB→LMB — 3-ударная цепочка с **заметно разными** анимациями (slash → reverse → overhead); **3-й удар фиолетовый**
- [ ] Комбо LMB→RMB→LMB — круговая атака с расталкиванием
- [ ] Energy max ~50; dash стоит Energy, кулдаун заметно короче; идеальный дэш возвращает стоимость
- [ ] Вне боя адреналин со временем → 0, но **пока адреналин высокий — Energy регенится**; в бою baseline + бонус от адреналина
- [ ] Входящий урон сначала жрёт Energy (щит), остаток идёт в HP
- [ ] F без эффекта (reserved)
- [ ] Крафт **Prism Chain** (нужен Prism Shard / тег mirror) — клинок цепочкой ходит по зеркалам
- [ ] Крафт **Echo Shade** (servo) — ideal dash оставляет голо-зеркало за врагом (тот же action-budget, без таймера)
- [ ] После зачистки комнаты в Rewards (рядом с +20% Damage / +15% Speed) видны Geometry-апгрейды Синтетика (пока не взяты)
- [ ] **Kinetic Ping-Pong** — клинок отскакивает от стен (с вспышкой); дэш сквозь летящий клинок усиливает/редиректит его (яркий optic burst)
- [ ] **Prismatic Trap** — кристалл на **первом попадании** по врагу (не в конце полёта); без таймера; мили рядом → веер лучей; при лимите (3) самый старый взрывается
- [ ] **Optical Labyrinth** — больше зеркал (до 5) + враги около зеркал получают glitch/путаются
- [ ] **Focus Lens** — парирование ставит линзу (**без таймера**, action budget ×3 amplify); клинок через неё бьёт ×2.5; после 3 amplifies линза гаснет
- [ ] **Holographic Substitution** — смертельный удар один раз (с КД) меняет на голограмму-взрыв и спасает
- [ ] Вражеский мили попадает по игроку (можно парировать); красный телеграф следит во время windup
- [ ] Игрокский мили-хитбокс покрывает дугу клинка
- [ ] Комната заметно больше viewport (камера ограничена ареной)
- [ ] Бросок меча / снаряды попадают без пиксель-хантинга; мили хитбоксы покрывают модель, не только «ноги»

## Улей
- [ ] HP медленно тикает вниз **только рядом с врагами**
- [ ] Хиты/киллы возвращают HP; низкий HP **не** даёт скрытый damage buff
- [ ] Space **не dash**: зажать Space = Dissipate (лужа, remnant-силуэт, i-frames, HP tick, puddle poison); отпустить = reform + часть HP назад
- [ ] Special (swarm burst) ощущается и бьёт врагов на острове (не только sibling nodes)

## Паровоз
- [ ] Heat растёт от атак, в жёлтой зоне урон выше; **Coil Overdrive** масштабирует урон по heat (yellow→red)
- [ ] **Vent (Q)** сбрасывает heat
- [ ] Крафт **Pressure Valve** (servo) — Vent сильнее и с короче lock
- [ ] Крафт **Redline Protocol** (style) — в red heat хиты вешают shock + burn
- [ ] Крафт **Plasma Afterburn** (magnet) — после Vent короткое окно бонусного урона / меньше heat gain

## Нейро-хакер
- [ ] Q спавнит дрона, RAM-слоты уменьшаются
- [ ] Дрон бьёт врагов, по истечении жизни слот освобождается
- [ ] Второй дрон блокируется, если слотов нет
- [ ] Крафт **Parallel Thread** (+1 RAM) доступен с Logic Core
- [ ] Крафт **Overclock Drones** усиливает урон/скорость дронов
- [ ] Крафт **Glitch Link** — удары дрона вешают glitch buildup
- [ ] Крафт **Holo Edge** — мили (holo slash) сильнее + glitch buildup
- [ ] Крафт **Fragment Slash** (code) — мили стреляет короткими holo-осколками
- [ ] Крафт **Sync Blade** (antenna) — мили кратко overclock'ает дронов рядом

## Статусы / синергии
- [ ] Burn / bleed / acid / shock / stagger / glitch набираются и прокают
- [ ] Acid + Shock → Chemical Short
- [ ] Fire + Bleed → Napalm Rend
- [ ] Glitch + Shock → System Crash
- [ ] Burn + Stagger → Concussive Ignition
- [ ] Саваги сильнее паникуют от fire; киборги заметно страдают от glitch

## Крафт / лут
- [ ] После clear комнаты есть loot + reward/craft UI
- [ ] Крафты Синтетика/Улья/Паровоза/Нейро открываются по тегам
- [ ] На **последней** комнате тоже craft, и только после выбора — Run Complete

## Маршрут биомов
- [ ] Tutorial: **Landfill → Wasteland → Data Center**
- [ ] Campaign: проходит Acts 1–4 (Outskirts → Habitats → Wild → Data Core), палитры/волны меняются
- [ ] **Procedural:** новый граф комнат каждый забег; после clear видны двери N/E/S/W; биомы соседствуют плавно (blend на границах)
- [ ] Procedural: debug HUD показывает Seed; босс-комната после craft даёт Run Complete
- [ ] Procedural: финал = **The Hive**; отдельная warden-комната на графе
- [ ] Procedural: встречаются **shop / treasure / secret / remnant** комнаты без волн — сразу лут + двери
- [ ] В gateway / data-center волнах встречаются **элиты** (золотистый tint, больше HP, быстрее атаки ~×1.15, «ELITE» на HP-баре)
- [ ] Procedural: **возврат в уже очищенную комнату** — врагов нет, двери сразу открыты (без респавна волны); **без повторной награды**; входная дверь не телепортирует обратно сразу
- [ ] Tutorial / Campaign / Procedural: **один физический этаж** — острова + коридоры, смещённые двери, заход с обратной стороны, walk-back, острова не перекрываются
- [ ] Мини-карта на всех маршрутах с графом: current / visited / fog; boss / shop / cache / remnant маркеры; тонкая dying-city рамка (не chrome клона рефа)
- [ ] Overlay после clear **не телепортирует** — выходишь пешком в коридор
- [ ] Quiet rooms (remnant / shop / cache): двери сразу проходимы из коридора — не нужно «войти в occupancy чтобы открыть»
- [ ] Standing on an island enters that room even if occupancy missed after a reward overlay
- [ ] Hive island keeps **Data Center · Boss** while you stand on those tiles — neighbor remnant / hallway does not steal occupancy, quiet-heal, or respawn a second butcher
- [ ] Campaign: F9 на старте → pick reward if it pops → юг Remnant (**stall just inside the door**, **E = one scrap** on a bottom banner) → восток **The Hive**
- [ ] Clerk: **E listen** only when in range; first visit — 12 sequential Hades scraps as a **bottom line** (stall stays visible, не speech dump, не auto-talk от overlap); потом node line «Fine. Drawer node…» → Нейро unlock; repeat visit — 3 scraps
- [ ] Clerk **не** выдаёт Улей; kit снимаешь с The Hive
- [ ] Улей-босс в графе (campaign/procedural); kill пишет meta unlock
- [ ] Hive tells: slam = dark floor circle then mass (выйти из круга); nano-bile = olive spit line then lasting **olive-rust slurry** (не комнатный neon drain stain); flesh-hook = **meat-nano cable with a barb** (not a clean orange laser), kiss = pull (sidestep the line); swarm chunks fall off — kill or they crawl back and the butcher gets thicker
- [ ] The Hive stands in the room, not stuffed in the door; slam circle has a rust/olive rim you can actually see on the night floor
- [ ] Комнаты — illustrated ruin (неон vs toxic, rim-lit hostiles, contrasty night) **без** Kenney-вокселей / Roblox-dim / клона улицы с clone-pod
- [ ] Переход через дверь: короткий fade (без резкого чёрного кадра / hard cut)
- [ ] У дверей есть проём в стене + рамка коридора (не сплошная стена с оверлеем); столбы стоят по бокам дыры, не в центре
- [ ] Пол/стены комнаты имеют сетку, углы и neon-акценты под цвет биома (не голый серый прямоугольник)
- [ ] Игрок и враги — illustrated силуэты с idle/walk (не воксели); по фракции/архитектуре читается силуэт
- [ ] В биомах спавнятся trap puddles (лужи с пульсом, не зелёные квадраты); урон/статус по тику при наступании
- [ ] Exit / дверь → следующая комната; стиль/модификаторы сохраняются

## Враги / behaviors
- [ ] Если один враг заметил игрока — **все враги в комнате** идут в агр
- [ ] Попадание мили / ренж / броском меча по врагу тоже агрит комнату
- [ ] Перед атакой врага виден вайнд-ап с **разным силуэтом**: slash / overhead slam (круг) / lunge (линия) / charge shot (луч) / fan (веер) — можно таймить уклонение
- [ ] Swarm/Beast делают gap-close lunge; Bruiser — slam; Sniper/Android — charge + fan; Bio — combo; Cyborg — melee+fan
- [ ] Комнаты давят плотностью (часто 5–8 в mid/late волне) и миксом ролей (medic + swarm + sniper)
- [ ] Room reward **+20% Damage**: первые 2 пика полные; дальше soft-cap (~+8%)
- [ ] Прерывание LMB×3 блоком не оставляет фиолетовую дугу на экране
- [ ] У врагов появляется полоска HP над головой после урона; обновляется и скрывается при полном HP / смерти
- [ ] Рядом с полоской HP видно имя/тип врага (Bruiser, Swarm, …)
- [ ] Вверху экрана видно название текущей локации (биом)
- [ ] Debug HUD показывает последний нанесённый урон и сумму за жизнь (Dmg)
- [ ] Swarm/bruiser быстрее в толпе
- [ ] Киборг иногда игнорит снаряд
- [ ] Android подлечивает союзников
- [ ] Robo-beast догоняет агрессивнее
- [ ] Bio-mutant при смерти взрывается кислотным облаком

## Combat feel
- [ ] На `levels/feel_arena.tscn`: light / mid / finisher ощущаются разным весом (hitstop + shake)
- [ ] Во время свинга движение заметно замедлено; после конца строки есть короткий endlag (recovery)
- [ ] Dash всё ещё отменяет атаку
- [ ] Floating damage numbers всплывают на хит; stagger-crit заметно желтее/крупнее
- [ ] Glass (Swarm) flinch почти от каждого удара; Tank (Bruiser) не дёргается от light 1
- [ ] Finisher / circle slash даёт заметный camera shake и жирнее VFX
- [ ] Parry / perfect dodge дают усиленный freeze + shake
- [ ] **Parry** — жёсткий «BAM»: длинный hitstop, flash, сильный отброс, стан со **звёздами** над головой
- [ ] Stagger / hard stun показывают крутящиеся звёзды (Tom & Jerry)
- [ ] Hitstop / camera shake / knockback масштабируются от % HP урона; hit flash на попадании
- [ ] Смерть врага: кровь/лужи + куски тела остаются валяться на арене
- [ ] Input buffer (~0.22с): можно нажать следующую атаку/блок/dash до конца recovery
- [ ] Комбо **LMB→RMB→LMB** даёт круговую атаку; RMB **сразу** отменяет атаку в щит (block priority)
- [ ] Щит по RMB встаёт сразу (без долгого «подъёма»); raise-parry окно короткое (~0.18с)
- [ ] Третий LMB комбо можно добить из щита (не обязательно сначала отпускать RMB)
- [ ] Длинный бой / мульти-хиты не зависают (time_scale возвращается в 1)
- [ ] **Feel P2 SFX/rumble**: хиты / parry / perfect dodge / Q / смерть врага дают короткий procedural beep + gamepad rumble (если пад подключён)

## Стабильность
- [ ] Death → R restart не закрывает окно
- [ ] Tutorial (3 комнаты) и короткий кусок Campaign / Procedural без краша
- [ ] Feel Arena открывается и тюнится без кампании
- [ ] Пауза оверлеев (route / arch / reward / death / win) не ломает ввод
