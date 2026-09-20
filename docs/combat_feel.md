# EON — Combat Feel Contract

Контракт **feel-слоя** боя. Не описывает дизайн энкаунтеров (волны, элиты, боссы) — это отдельный слой.

## Цель

Удары игрока должны **регистрироваться по клику**, как в первом прототипе: light-attack `windup = 0` (хитбокс живой в том же enter), visual swing = `AttackData` (без искусственных 0.22/0.28). Clone не рисует второй меч — только короткий energy arc. Synthetic hold-throw начинается с того же press, но сам удар не ждёт release.

Вес остаётся через `move_mult` / короткий recovery / lunge / HitStop. «Пластик» = нет: скольжение на полной скорости, нулевой endlag, одинаковый микро-hitstop, враг-скользящий hitbox без flinch. «Медуза» = нет: floaty bob, late swing vs click, второй полигон-меч поверх нарисованного клинка, Kenney-кубы в миксе с city pack, PointLight2D grain на Compatibility.

**Гипотеза тюнинга:** если 30 секунд на dummy-арене «мясные» — тот же feel переносится на любой контент. Давление арены / паттерны / элиты **не** переносятся сами и делаются позже.

## Пиллары

1. **Weight (commitment)** — свинг сажает движение (`move_mult`), есть `recovery` на конце строки, lunge в прицел. Dash-cancel остаётся (Hades-escape).
2. **Impact** — per-attack HitStop from `AttackData.hit_stop_scale` / `hit_stop_duration` / `camera_trauma`, with a mild boost only on hard hits. No victim-max-HP floor (that froze swarms longest). Hits the player takes use a shorter freeze; shake + flash still fire.
3. **Reaction (poise / flinch)** — враг «съедает» хит: короткий interrupt AI + поза. Stagger gauge = большое crit-окно, не замена flinch.
4. **Readability** — telegraphs уже есть; floating damage pops; finisher/parry/perfect dodge заметно сильнее light.

## Тюнинг-тиры (ориентиры)

| Tier | Примеры | move_mult | recovery | hit_stop (scale / dur) | trauma | kb_duration | poise_damage |
|------|---------|-----------|----------|------------------------|--------|-------------|--------------|
| Soft / light | basic 1 | ~0.45 | 0.08–0.12 | 0.15 / 0.04 | 0.08 | 0.12 | ~12 |
| Mid | basic 2 | ~0.40 | ~0.10 | 0.12 / 0.05 | 0.12 | 0.14 | ~18 |
| Hard / finisher | basic 3, circle | 0.20–0.25 | 0.18–0.25 | 0.08 / 0.08 | 0.28–0.35 | 0.18–0.22 | 35–45 |
| Parry | on success | — | — | hard | ~0.30 | — | — |
| Perfect dodge | on success | — | — | hard (+ slow-mo) | ~0.22 | — | — |

Между хитами комбо-строки recovery **пропускается** (chain сразу); endlag играет на конце строки / whiff.

## Poise vs Stagger

| | Poise / Flinch | Stagger status |
|--|----------------|----------------|
| Роль | микро-реакция на каждый «пробитый» хит | punish window + crit |
| Длительность | ~0.08–0.22 с | ~1.2–1.4 с active |
| Interrupt | да (сброс windup/атаки) | да + slow actions |
| Порог | `max_poise` на `EnemyDefinition`; bruiser высокий, swarm низкий | buildup 100 (status) |

Лёгкий тычок не трясёт bruiser; swarm flinch почти всегда. Finisher ломает poise чаще.

## Out of scope (Feel P0)

- Encounter design lives in waves / movesets / boss phases (see `docs/systems.md` Encounter pressure) — feel layer still owns weight/impact/poise only
- Новые скелетные анимации / финальный арт
- **SFX / rumble** — Feel P2 shipped via `autoload/feel_audio.gd` (procedural AudioStreamGenerator blips + `Input.start_joy_vibration`). Hooked to `damage_dealt` / parry / perfect dodge / special / vent / enemy_died. Replace with authored WAV/OGG later without changing call sites.

## Критерий готовности

На `levels/feel_arena.tscn`: light ≠ heavy на руках; whiff чувствуется; tank не дёргается от тычка, swarm — дёргается; finisher даёт заметный hitstop + shake; dash спасает, но свинг не «коньки». Melee magnet is a ~70° cone toward the cursor and **locks at swing start**. Attack input buffers on every kit. Neuro aim is from body center (`global_position + (0,-22)`). Hive HP: red trailing chip on damage, amber on self-spent fuel, green flash on heals. Enemies collide with the player and each other; physics interpolation is on.
