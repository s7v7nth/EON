# Project EON — Vertical Slice: архитектура и план задач

**Стек:** Godot 4.x, GDScript.
**Перспектива:** изометрия в стиле Hades — технически 2D (`CharacterBody2D`), «объём» создаётся Y-сортировкой, коллизиями «у ног» и визуальным артом (см. §2.7).
**Принципы:** Composition over Inheritance · данные в `Resource` (.tres), логика в компонентах-узлах · глобальный `SignalBus` (autoload) для межсистемной связи · FSM на узлах.

**Цель среза:** серый бокс — одна арена, игрок (WASD-движение без инерции, базовая атака, рывок с i-frames/энергией/кулдауном), один враг-болванчик. Архитектура готова к масштабированию (модули оружия — позже).

---

## 1. Структура директорий

```text
res://
├── project.godot
├── autoload/
│   ├── signal_bus.gd              # Event Bus (глобальные сигналы)
│   └── iso.gd                     # Константы изометрии (Y_SCALE и хелперы)
├── components/                    # Переиспользуемые компоненты-узлы
│   ├── health_component.gd
│   ├── energy_component.gd
│   ├── adrenaline_component.gd
│   ├── hitbox_component.gd        # Area2D — наносит урон
│   └── hurtbox_component.gd       # Area2D — принимает урон
├── systems/
│   └── state_machine/
│       ├── state_machine.gd       # Универсальная FSM (Node)
│       └── state.gd               # Базовый класс состояния (Node)
├── resources/                     # Скрипты Resource + .tres данные
│   ├── stats/
│   │   ├── character_stats.gd     # class_name CharacterStats
│   │   ├── player_stats.tres
│   │   └── enemy_dummy_stats.tres
│   └── attacks/
│       ├── attack_data.gd         # class_name AttackData (урон, кулдаун, длительность)
│       ├── player_basic_attack.tres
│       └── enemy_dummy_attack.tres
├── entities/
│   ├── player/
│   │   ├── player.tscn
│   │   ├── player.gd
│   │   └── states/
│   │       ├── player_idle.gd
│   │       ├── player_move.gd
│   │       ├── player_attack.gd
│   │       └── player_dash.gd
│   └── enemies/
│       └── dummy/
│           ├── enemy_dummy.tscn
│           ├── enemy_dummy.gd
│           └── states/
│               ├── enemy_idle.gd
│               ├── enemy_chase.gd
│               └── enemy_attack.gd
├── levels/
│   └── arena/
│       └── arena.tscn             # Серый бокс: пол, стены, спавны, камера
└── ui/
    └── debug_hud.tscn / debug_hud.gd   # Полоски HP / Energy / Adrenaline
```

---

## 2. Ключевые архитектурные решения

### 2.1 Слои коллизий (project.godot → Layer Names)

| # | Слой            | Кто на нём                                  |
|---|-----------------|---------------------------------------------|
| 1 | `world`         | Стены арены (StaticBody2D)                  |
| 2 | `player_body`   | CharacterBody2D игрока                      |
| 3 | `enemy_body`    | CharacterBody2D врагов                      |
| 4 | `player_hurtbox`| Hurtbox игрока (его сканирует хитбокс врага)|
| 5 | `enemy_hurtbox` | Hurtbox врага (его сканирует хитбокс игрока)|

Hitbox игрока: layer = ничего, mask = `enemy_hurtbox`. Hitbox врага: mask = `player_hurtbox`. I-frames рывка = временное отключение `monitorable`/CollisionShape у Hurtbox игрока.

### 2.2 Компоненты (все — независимые узлы, конфигурируются через `@export`)

- **HealthComponent** (`Node`): `@export stats: CharacterStats`; `current_health`; методы `take_damage(amount)`, `heal(amount)`; сигналы `health_changed(current, max)`, `died`. Ничего не знает о владельце — владелец подписывается на `died`.
- **EnergyComponent** (`Node`): `current_energy`, пассивная регенерация в `_process` (`regen_rate * regen_multiplier * delta`); методы `try_spend(amount) -> bool`, `set_regen_multiplier(mult)`; сигнал `energy_changed(current, max)`.
- **AdrenalineComponent** (`Node`): копится при нанесении/получении урона (`add(amount)`), распадается вне боя после задержки; по порогам выставляет множитель регенерации в связанный `EnergyComponent`; сигнал `adrenaline_changed(current, max)`.
- **HitboxComponent** (`Area2D`): `@export attack_data: AttackData`; по умолчанию выключен (`monitoring = false` + disabled shape); метод `activate()/deactivate()`; при `area_entered` вызывает `hurtbox.receive_hit(attack_data, owner)`; сигнал `hit_landed(target)` (питает адреналин атакующего).
- **HurtboxComponent** (`Area2D`): `@export health_component: HealthComponent`; метод `receive_hit(attack_data, source)` → `health_component.take_damage(...)`; методы `set_invincible(on)` для i-frames; сигнал `hit_received(attack_data, source)`.

Связь hitbox → hurtbox идёт напрямую (контактная логика), а глобальные события (`entity_died`, `player_health_changed` и т.п.) — через `SignalBus`.

### 2.3 SignalBus (autoload)

Минимальный набор сигналов среза:
`player_health_changed(current, max)`, `player_energy_changed(current, max)`, `player_adrenaline_changed(current, max)`, `entity_died(entity)`, `player_died`, `enemy_died(enemy)`.
UI и системы подписываются на шину, не зная о сценах-источниках.

### 2.4 FSM

- `state.gd` (`class_name State extends Node`): виртуальные `enter(msg := {})`, `exit()`, `update(delta)`, `physics_update(delta)`, `handle_input(event)`; метод `transition_to(state_name, msg)` — делегирует родителю.
- `state_machine.gd` (`class_name StateMachine extends Node`): хранит текущее состояние, `@export initial_state`, диспатчит `_process/_physics_process/_unhandled_input` в активное состояние, метод `transition_to(name, msg)`.
- Состояния — дочерние узлы StateMachine; каждое в своём скрипте. Добавление нового состояния = добавление узла, без правки существующих.

### 2.5 Ресурсы данных

- **CharacterStats** (`Resource`): `max_health`, `move_speed`, `max_energy`, `energy_regen_rate`, `dash_speed`, `dash_duration`, `dash_cost`, `dash_cooldown`, `max_adrenaline`, `adrenaline_decay_*`.
- **AttackData** (`Resource`): `damage`, `cooldown`, `active_duration` (окно активного хитбокса), `windup` (замах), `knockback_force` (заложить поле, можно не использовать в срезе). Модули оружия в будущем = новые `AttackData`-ресурсы (или наследники) без правки кода компонентов.

### 2.6 Game Feel

- Движение: `velocity = input_dir * stats.move_speed` каждый физический кадр — мгновенный старт/стоп, никаких `lerp`/ускорений. Вертикальная ось дополнительно умножается на `Iso.Y_SCALE` (см. §2.7).
- Dash: фиксированные `dash_speed`+`dash_duration` из stats; на входе — `energy.try_spend(dash_cost)` и проверка кулдауна (Timer); на время рывка `hurtbox.set_invincible(true)`; ввод рывка имеет приоритет над атакой.

### 2.7 Изометрия в стиле Hades (техника 2D)

Как и в Hades, геймплей идёт на плоской 2D-плоскости («полу»), а изометрия — это подача:

- **Коллизии и бой — «у ног».** `CollisionShape2D` тела, Hurtbox, Hitbox и DetectionArea — маленькие эллипсы/капсулы у основания сущности (на «полу»). Это даёт честную дистанцию боя по плоскости пола, как в Hades.
- **Визуал — «стоит» над точкой ног.** Placeholder-визуал (серый прямоугольник «в рост») смещён вверх от origin сущности; origin узла = точка ног = точка Y-сортировки.
- **Y-сортировка.** Контейнер сущностей в арене и сами сущности — `y_sort_enabled = true`: кто ниже по Y (ближе к камере), тот рисуется поверх.
- **Перспективное сжатие вертикали.** Константа `Iso.Y_SCALE` (например `0.7`, в `autoload/iso.gd` или как константа в общем скрипте): движение по экранной вертикали медленнее горизонтали, что создаёт ощущение наклонной плоскости пола. Применяется ко всем перемещениям (игрок, dash, враг): `velocity = dir.normalized() * speed; velocity.y *= Iso.Y_SCALE`.
- **Арена.** Для серого бокса пол остаётся прямоугольным (ромб/арт — позже); стены — обычные `StaticBody2D`, южная стена может быть визуально «ниже», это вопрос арта, не среза.

---

## 3. Иерархии сцен

### 3.1 Player (`entities/player/player.tscn`)

```text
Player (CharacterBody2D, y_sort_enabled)  [player.gd; @export stats: CharacterStats]
│   # origin узла = точка ног (точка Y-сортировки)
├── Visual (Polygon2D / ColorRect — серый бокс «в рост», смещён вверх от ног)
├── CollisionShape2D (эллипс/капсула «у ног»)
├── StateMachine (Node) [state_machine.gd]
│   ├── Idle   [player_idle.gd]
│   ├── Move   [player_move.gd]
│   ├── Attack [player_attack.gd]
│   └── Dash   [player_dash.gd]
├── HealthComponent (Node)
├── EnergyComponent (Node)
├── AdrenalineComponent (Node)
├── HurtboxComponent (Area2D, layer=player_hurtbox)
│   └── CollisionShape2D (эллипс «у ног», чуть больше тела)
├── HitboxPivot (Node2D — на уровне ног, поворачивается к направлению атаки)
│   └── HitboxComponent (Area2D, mask=enemy_hurtbox) [@export attack_data]
│       └── CollisionShape2D (disabled по умолчанию)
├── DashCooldownTimer (Timer, one_shot)
└── AttackCooldownTimer (Timer, one_shot)
```

### 3.2 EnemyDummy (`entities/enemies/dummy/enemy_dummy.tscn`)

```text
EnemyDummy (CharacterBody2D, y_sort_enabled)  [enemy_dummy.gd; @export stats: CharacterStats]
│   # origin узла = точка ног, как у игрока
├── Visual (Polygon2D — серый бокс «в рост» другого цвета, смещён вверх)
├── CollisionShape2D (эллипс «у ног»)
├── StateMachine (Node)
│   ├── Idle   [enemy_idle.gd — стоит, ждёт игрока в радиусе]
│   ├── Chase  [enemy_chase.gd — идёт к игроку]
│   └── Attack [enemy_attack.gd — удар вблизи, кулдаун]
├── HealthComponent (Node)
├── HurtboxComponent (Area2D, layer=enemy_hurtbox)
│   └── CollisionShape2D
├── HitboxComponent (Area2D, mask=player_hurtbox)
│   └── CollisionShape2D (disabled)
├── DetectionArea (Area2D, mask=player_body — агро-радиус)
│   └── CollisionShape2D
└── AttackCooldownTimer (Timer, one_shot)
```

### 3.3 Arena (`levels/arena/arena.tscn`)

```text
Arena (Node2D)
├── Floor (ColorRect / TileMapLayer — серый)
├── Walls (StaticBody2D, layer=world)
│   └── CollisionShape2D × 4
├── Entities (Node2D, y_sort_enabled = true)
│   ├── Player (instance)
│   └── EnemyDummy (instance)
├── Camera2D (следует за игроком)
└── DebugHUD (CanvasLayer instance)
```

---

## 4. Пошаговый план (атомарные задачи для AI-агентов)

Каждая задача самодостаточна, выполняется в одном контекстном окне и завершается проверяемым результатом. Порядок обязателен — задачи ссылаются на артефакты предыдущих.

### Задача 1 — Каркас проекта и SignalBus
- Создать `project.godot` (Godot 4.x, окно 1280×720, `viewport` stretch).
- Input Map: `move_up/down/left/right` (WASD), `dash` (Space), `attack` (ЛКМ).
- Именованные слои коллизий 1–5 (см. §2.1).
- Physics: гравитация не используется (движение по плоскости пола), `CharacterBody2D` в режиме `motion_mode = FLOATING` (задаётся в сценах).
- Создать структуру директорий (пустые папки через `.gitkeep` не нужны — создадутся с файлами).
- `autoload/signal_bus.gd` со списком сигналов из §2.3, зарегистрировать как autoload `SignalBus`.
- `autoload/iso.gd` с константой `Y_SCALE` (см. §2.7), зарегистрировать как autoload `Iso`.
- **Готово, когда:** проект открывается в Godot без ошибок, оба автолоада видны, инпуты и слои названы.

### Задача 2 — Ресурсы данных
- `resources/stats/character_stats.gd` (`class_name CharacterStats extends Resource`) — поля из §2.5 с дефолтами.
- `resources/attacks/attack_data.gd` (`class_name AttackData extends Resource`) — поля из §2.5.
- Создать `.tres`: `player_stats.tres`, `enemy_dummy_stats.tres`, `player_basic_attack.tres`, `enemy_dummy_attack.tres` с разумными стартовыми значениями (напр. игрок: 100 HP, 300 speed, dash 900/0.15s/25 энергии/1.5s КД; враг: 50 HP, 120 speed; атака игрока: 10 урона / 0.5s КД / 0.15s актив).
- **Готово, когда:** ресурсы открываются в инспекторе, значения редактируются без кода.

### Задача 3 — HealthComponent, EnergyComponent, AdrenalineComponent
- Три скрипта в `components/` по контрактам §2.2. Каждый — `class_name`, полностью автономен, конфигурация через `@export` (stats-ресурс и/или числа).
- AdrenalineComponent держит `@export energy_component: EnergyComponent` и меняет его `regen_multiplier` по мере накопления; распад после `decay_delay` вне боя.
- **Готово, когда:** скрипты компилируются; мини-тест в изоляции (временная сцена или `SceneTree`-скрипт): урон уменьшает HP и эмитит сигналы, энергия тратится и регенерирует, адреналин ускоряет реген и распадается.

### Задача 4 — HitboxComponent и HurtboxComponent
- `components/hitbox_component.gd`, `components/hurtbox_component.gd` (оба `Area2D`) по контрактам §2.2.
- Hitbox: `activate()/deactivate()`, урон из `attack_data`, сигнал `hit_landed`; защита от повторного удара по той же цели за одну активацию.
- Hurtbox: `receive_hit()`, `set_invincible()`, проксирует урон в `HealthComponent`, сигнал `hit_received`.
- **Готово, когда:** тестовая сцена из двух Area2D показывает: активный хитбокс снимает HP через hurtbox ровно один раз; при `invincible` урон не проходит.

### Задача 5 — Универсальная FSM
- `systems/state_machine/state.gd` и `state_machine.gd` по §2.4.
- **Готово, когда:** тестовая сцена с двумя dummy-состояниями переключается по `transition_to`, вызывая `enter/exit` в правильном порядке.

### Задача 6 — Сцена игрока: Idle + Move
- Собрать `player.tscn` по иерархии §3.1: origin = точка ног, визуал смещён вверх, коллизии «у ног» (Dash/Attack-состояния добавить как узлы-заглушки или добавить в задачах 7–8).
- `player.gd`: читает `stats`, отдаёт состояниям хелперы `get_input_direction()` (с учётом `Iso.Y_SCALE`), ссылки на компоненты; `motion_mode = FLOATING`.
- `player_idle.gd` / `player_move.gd`: мгновенное движение `velocity = dir * move_speed` c вертикалью, умноженной на `Iso.Y_SCALE`; `move_and_slide()`; переходы Idle↔Move по наличию ввода. Ретрансляция сигналов компонентов в SignalBus (`player_health_changed` и т.д.).
- Временная тест-сцена: игрок на пустом Node2D.
- **Готово, когда:** WASD двигает бокс резко, без скольжения; диагональ нормализована; движение по вертикали экрана заметно медленнее горизонтали (эффект наклонного пола).

### Задача 7 — Dash с энергией, кулдауном и i-frames
- `player_dash.gd`: вход по `dash` из Idle/Move; условия — `DashCooldownTimer.is_stopped()` и `energy.try_spend(dash_cost)`; направление = текущий ввод (или последнее направление взгляда, если ввода нет).
- В `enter()`: `hurtbox.set_invincible(true)`, фиксированная `velocity = dir * dash_speed`; выход по таймеру `dash_duration` → возврат в Idle/Move; в `exit()`: снять неуязвимость, запустить кулдаун.
- **Готово, когда:** рывок срабатывает по Пробелу, жрёт энергию (видно по сигналу/принту), не срабатывает без энергии или на кулдауне; во время рывка `hurtbox` неактивен.

### Задача 8 — Базовая атака игрока
- `player_attack.gd`: вход по `attack` из Idle/Move, если `AttackCooldownTimer.is_stopped()`.
- `HitboxPivot` поворачивается к курсору мыши; тайминги из `AttackData`: `windup` → `hitbox.activate()` на `active_duration` → `deactivate()` → возврат в Idle/Move, старт кулдауна.
- `hit_landed` хитбокса → `adrenaline.add(...)`.
- Движение во время атаки заблокировано (velocity = ZERO) — простейший вариант для среза.
- **Готово, когда:** по ЛКМ хитбокс включается в сторону курсора на нужное окно, кулдаун соблюдается.

### Задача 9 — Враг-болванчик
- Собрать `enemy_dummy.tscn` по §3.2, `enemy_dummy.gd` + три состояния:
  - Idle: стоит; игрок вошёл в `DetectionArea` → Chase.
  - Chase: `velocity` к игроку с `move_speed` (вертикаль × `Iso.Y_SCALE`); в радиусе удара → Attack.
  - Attack: замах → активация хитбокса → кулдаун → Chase.
- Смерть: `HealthComponent.died` → эмит `SignalBus.enemy_died`, `queue_free()`.
- Получение урона игроком: hurtbox игрока → `HealthComponent`, плюс `adrenaline.add(...)` за полученный удар.
- **Готово, когда:** враг преследует, бьёт, умирает от 5 ударов игрока (50 HP / 10 урона); при смерти исчезает.

### Задача 10 — Арена и main-сцена
- `levels/arena/arena.tscn` по §3.3: пол, 4 стены (layer `world`), контейнер `Entities` с `y_sort_enabled = true` и инстансами игрока и врага, `Camera2D` (привязана к игроку, position smoothing допустимо для камеры — это не движение персонажа).
- Назначить main scene в `project.godot`. Удалить временные тест-сцены задач 3–6.
- **Готово, когда:** F5 запускает арену; игрок не проходит сквозь стены; Y-сортировка работает (игрок выше врага по экрану → рисуется позади него, и наоборот); полный цикл боя работает.

### Задача 11 — Debug HUD и адреналиновая петля
- `ui/debug_hud.tscn` (CanvasLayer): три `ProgressBar` — HP (красный), Energy (синий), Adrenaline (жёлтый) — подписка только на `SignalBus`.
- Проверить и добить петлю: удары (нанесённые и полученные) → адреналин ↑ → множитель регена энергии ↑ → вне боя адреналин распадается → реген нормальный.
- **Готово, когда:** все три полоски живут корректно; видно ускорение регена энергии при высоком адреналине.

### Задача 12 — Финальная проверка среза (чек-лист)
- WASD: резкий старт/стоп, нормализованная диагональ, вертикаль медленнее горизонтали (`Iso.Y_SCALE`).
- Изометрия: Y-сортировка игрока и врага корректна; коллизии и бой считаются «по ногам», а не по визуалу.
- Dash: энергия, кулдаун, i-frames (враг бьёт «сквозь» рывок без урона).
- Атака: урон по врагу, кулдаун, направление на курсор.
- Враг: агро → погоня → удар → урон игроку; смерть врага; смерть игрока → `player_died` (пока достаточно принта/паузы).
- Все числа берутся из `.tres`; правка ресурса меняет поведение без правки кода.
- **Готово, когда:** чек-лист пройден; известные проблемы записаны в конец `plan.md`.

---

## 5. Принятые решения по умолчанию (можно поменять)

- Базовая атака — **ближняя** (melee-хитбокс перед персонажем, поворот к курсору мыши). Модули оружия позже лягут в `AttackData`/наследников.
- Враг-болванчик — не чисто статичный манекен: минимальный AI (агро-радиус → погоня → удар вблизи), чтобы проверить весь боевой цикл (i-frames, адреналин, урон игроку).
- Адреналин: копится и за нанесённые, и за полученные удары; влияет только на скорость регена энергии (пороговый множитель).
- Изометрия — Hades-style 2D (не настоящее 3D): `Iso.Y_SCALE = 0.7` по умолчанию (подбирается на ощупь); прыжков/высоты в срезе нет, «пол» — единственная плоскость геймплея.

---

## 6. Статус реализации (2026-08-01)

Задачи 1–11 реализованы и прогнаны headless-смоками. Main scene: `res://levels/rooms/room_01.tscn`.

### Чек-лист Task 12
- WASD + `Iso.Y_SCALE` — реализовано (`Player.apply_movement` / `Iso.apply_velocity`).
- Y-sort + коллизии «у ног» — в сценах игрока/врага/арены.
- Dash: энергия / кулдаун / i-frames — `player_dash.gd`.
- Атака: курсор / кулдаун / урон через Hitbox→Hurtbox — `player_attack.gd`.
- Враг: Idle→Chase→Attack, смерть через `SignalBus.enemy_died`.
- Числа в `.tres` — `player_stats`, `enemy_dummy_stats`, attack resources.
- Debug HUD на SignalBus — HP / Energy / Adrenaline.

### Пост-срез: game feel и ренж (2026-08-01, вечер)
- Физика 120 Гц + `physics_jitter_fix = 0`, снято сглаживание камеры — резкое, отзывчивое движение без «инерции».
- Dash оставляет затухающие блики-остаточные образы (`player_dash.gd`, спавн Polygon2D-призраков).
- Общий снаряд `entities/projectiles/projectile.tscn` (`Projectile`): урон через Hurtbox, гибнет о стены, уважает i-frames.
- Ренж-атака игрока: ПКМ, кулдаун 0.8s, снаряд к курсору (`player_ranged_attack.tres`, состояние `RangedAttack`).
- Ренж-атака врага: на средней дистанции (до 260px) с виндапом 0.35s и кулдауном 2s (`enemy_dummy_ranged_attack.tres`); вблизи — по-прежнему мили. Агро-радиус поднят до 340.
- В `AttackData` добавлены `projectile_speed` / `projectile_lifetime` (0 = мили-атака).

### Известные ограничения
- Временные валидаторы лежат в `tools/` (не мешают запуску).
- `levels/bootstrap.tscn` / `player_move_test.tscn` могут ещё оставаться как черновики — main уже `room_01`.
- NodePath-экспорты `health_component` в `.tscn` ненадёжны; компоненты связываются в `_configure_from_stats()`.
- Нет арта/анимаций — чистый серый бокс (архетипы/оружие отличаются цветом).
- Нет ветвящейся карты и мета-прогрессии между ранами — только линейный ран из 3 комнат.

### Пост-срез A–E (2026-08-01, ночь)
- **A — Arena loop:** `ArenaController` + `WaveSet`, `RunOverlay` (смерть/победа, R=restart), волны.
- **B — Combat feel:** knockback через Hurtbox, `HitStop` autoload, `knockback_force` в `.tres`, `player_heavy_attack.tres`.
- **C — Архетипы:** `EnemyDefinition` (bruiser / sniper / swarm), kite у sniper, микс в волнах.
- **D — Оружие:** `WeaponData` Blade/Hammer/Bow, хоткеи 1/2/3, метка в HUD.
- **E — Ран:** `RunState` autoload, `room_01/02/03`, exit → выбор баффа → следующая комната, финальный win. Main: `res://levels/rooms/room_01.tscn`.
