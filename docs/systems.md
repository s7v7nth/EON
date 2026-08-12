# EON — Systems Contracts

Design contracts for biomes, elements, enemies, architectures, and skill loop.
Implementation grows on top of components + `Resource` data + `SignalBus`.

**Extensibility roadmap (how to add content without rewriting the core):**
[`docs/systems_extensibility_plan.md`](systems_extensibility_plan.md)

**External-AI architecture brainstorm context** (keep in sync on significant design changes):
[`docs/architecture_brainstorm_prompt.md`](architecture_brainstorm_prompt.md)

**Combat feel contract** (weight / impact / poise-flinch):
[`docs/combat_feel.md`](combat_feel.md)

**Encounter pressure** (density / signature patterns / phased boss): denser mixed waves, `AttackData.pattern_kind` movesets, Warden boss phases — player verbs stay strong; mistakes cost more.

## Pillars

1. **Architecture** — language of actions + pluggable `ResourceEconomy`.
2. **Elements** — buildup statuses + synergy recipes, not just a tint.
3. **Faction** — enemy identity (resists + behavior modules).
4. **Biome** — pressure pack (enemy weights, element bias, loot tags, palette) inside an `ActRoute`.

Skill actions feed **Adrenaline** + **Style Score** + craft tags / loot parts.

## Enums (`GameplayEnums`)

| Enum | Values |
|------|--------|
| `DamageType` | PHYSICAL, ELECTRICITY, CORROSION, FIRE, BLEED, GLITCH |
| `Faction` | SAVAGE, CYBORG, ANDROID, ROBO_BEAST, BIO_MUTANT |
| `BiomeId` | JUNGLE, DATA_CENTER, DOWNTOWN, RESIDENTIAL, TAIGA, ALLEY, LANDFILL, MALL, WASTELAND, GATEWAY |
| `ArchitectureId` | DEFAULT (Синтетик), NANOMACHINES (Улей), ELECTRO_TRAIN (Паровоз), NEURO_HACKER |
| `EconomyPolicy` | ENERGY_ADRENALINE, BLOOD_HARVEST, OVERHEAT, RAM_COMPUTE |
| `StyleAction` | HIT, KILL, PERFECT_DODGE, PARRY, COMBO, MULTI_KILL, ELEMENT_CASCADE, TOOK_DAMAGE |

## Damage & resists

- Final damage: `raw * (1.0 - resist)` clamped to `[0.05, 2.0]` multiplier.
- Resists live on `CharacterStats` / overrides on `EnemyDefinition` / architecture base.
- Status application: `status_chance * (1.0 - resist*0.5)` → `StatusComponent.add_buildup`.

| Type | Status | Target behaviour |
|------|--------|------------------|
| PHYSICAL | Stagger gauge | Interrupt + crit window on next hit |
| ELECTRICITY | Shock | Chain lightning at full buildup |
| CORROSION | Acid / armor break | +% damage taken; acid puddle on death |
| FIRE | Burn → Panic | DoT; full buildup = chaotic flee |
| BLEED | Rended wounds | Strong DoT while moving/attacking |
| GLITCH | Fault | Robot shutdown / organic slow |

## Status / Synergy (Phase B)

- Definitions: `resources/statuses/*.tres` via `StatusCatalog`
- Effects: `systems/status/effects/*` (`StatusEffect` plugins)
- Runtime: `StatusComponent` stores buildup + active window; **no `match` on status ids**
- Synergies: `resources/synergies/*.tres` (`SynergyRecipe`) — e.g. Acid+Shock → Chemical Short
- New status = `StatusDefinition` + `StatusEffect` + catalog entry
- New synergy = one `SynergyRecipe.tres`

## Architectures

| Id | Economy | Starter primitives |
|----|---------|-------------------|
| DEFAULT / Синтетик | `EconomyAdrenaline` | Energy blade · Geometry mirrors · charge-throw · combos; Q = Lattice Collapse |
| NANOMACHINES / Улей | `EconomyBloodHarvest` | Nano blade / whip / toad |
| ELECTRO_TRAIN / Паровоз | `EconomyOverheat` + Vent (Q) | Plasma gun / blade / mortar |
| NEURO_HACKER | `EconomyRam` (Q = drone slot) | Smart pistol / holo blades / drones |

Catalog: `resources/architectures/architecture_catalog.tres` — UI builds pick list from it.
Runtime: `ArchitectureData.economy` (`ResourceEconomy`) is duplicated on equip; Player has no `match economy_policy`.

### Синтетик — combat contract

- **LMB tap** — melee swing (combo module). **LMB hold** — charge returning blade throw (snappy charge; blue feet charge bar + aim beam).
- **RMB hold** — energy shield (−50% damage); first **~0.18s** raise-parry (full negate + stagger); dedicated Parry ~0.22s.
- **Geometry of Reflections** — perfect parry spawns an Energy Mirror (cap 3; **action budget 3**, no timer) at the player↔attacker midpoint.
- **Throw ↔ Mirror** — returning blade **pierces** foes then ricochets off a mirror with **lead aim** (×1.5; default 1 bounce). Each ricochet spends 1 mirror action. Prism Chain craft raises bounce budget.
- **Dash / melee ↔ Mirror** — dash-through or melee clip spends 1 action (soft pulse); on the 3rd action the mirror fades/detonates (dash-final = AoE Stagger + short i-frame refresh). Cap overflow removes oldest. **Q** fully consumes via Lattice Collapse.
- **Combos** (`systems/combat/ComboRecognizer`): LMB×3 string; LMB→RMB→LMB circle AoE.
- **Energy** — pool ~50; spent on attacks/dash/Q Collapse; absorbs damage before HP; ideal dash refunds cost.
- **Adrenaline** — baseline floor in combat → Energy regen; rises from hits, HP damage, parry, ideal dash; decays toward 0 out of combat, but **leftover adrenaline still regenerates Energy** until gone.
- **Engagement** — `CombatEngagementComponent` (enemy aggro and/or recent exchange).
- **Q** — Lattice Collapse (detonate all mirrors for Energy). **F** — reserved (no-op).
- **Post-room Rewards** — Synthetic Geometry upgrades (`reward_offerable`) appear beside +damage/+speed/-dash cost; granted via `RunState.grant_upgrade` (no loot tags). Loot crafts stay in the Craft column. Focus Lens uses the same **action budget 3** (amplifies) as mirrors — no timer.

Special input: `special` (Q) → `economy.try_special()` (swarm / Vent / drone / Lattice Collapse).

**Upgrade rule:** one upgrade = one or more `UpgradeEffect` verbs (`systems/upgrades/`), not Player bool flags.
Craft parts (`LootPart` in `resources/loot/`) grant tags; recipes gate on `owned_tags`.
Catalog: `resources/upgrades/upgrade_catalog.tres`. Reward-only Geometry picks use `UpgradeData.reward_offerable = true`.

## Style score (Hotline-like)

- Multiplier rises on stylish actions; resets on `TOOK_DAMAGE`.
- Room rank C–S from peak multiplier + kills; influences loot quality.

## SignalBus style events

- `style_action(action, points)`
- `perfect_dodge(source)`
- `parry_success(source)`
- `style_score_changed(score, multiplier, rank)`
- `status_applied(target, status_id)`
- `synergy_triggered(target, recipe_id)`
- `architecture_changed(architecture_id)`
- `biome_changed(biome_id)`
- `upgrade_crafted(upgrade_id)`
- `loot_gained(summary)`
- `player_economy_hud_changed(primary, secondary)`
- `damage_dealt(amount, target, source)` — финальный урон через Hurtbox (debug HUD / combat log)
- `special_triggered(source)` / `vent_triggered(source)`

## Biome package (`BiomeDefinition`)

`id`, palette, `wave_set`, faction weights, element bias, loot tags, neighbors.
Gateway rooms blend two biomes for smooth transitions.
Run order comes from `ActRoute` (Act1 outskirts → Act4 data core), not hardcoded room lists.

### ActRoute (Phase D)

- `resources/runs/act_route.gd` + `act_definition.gd`
- Default playable path: `tutorial_route.tres` — Landfill → Wasteland → Data Center
- Full campaign data: `campaign_route.tres` (Acts 1–4)
- Procedural: `procedural_route.tres` → `DungeonGenerator` builds an Isaac-style grid from `run_seed` (`systems/worldgen/`); doors N/E/S/W; biomes follow `neighbor_biomes` + blend; win on boss room after craft
- Seed streams: `RunRng` map / spawn / loot (VFX stays on global rand)
- Room scenes (`room_01`–`room_05`) are **geometry templates** (pool for procedural picks); `ArenaController` paints biome + swaps `wave_set` from `RunState`
- Special kinds: `SHOP` / `TREASURE` / `SECRET` skip waves and call `RunState.grant_special_room_loot`; boss rooms use `boss_encounter_waves.tres` (**Warden** phased boss)
- Elites: `WaveSpawnGroup.is_elite` → `EnemyDummy.apply_elite` (HP / move / **action speed** / tint / slight damage pressure)
- Enemies: `EnemyDefinition.moveset` + `AttackData.pattern_kind` (SLASH / OVERHEAD_SLAM / LUNGE / COMBO / CHARGE_SHOT / FAN_SHOT); AI picks by range/weight; distinct telegraphs on `CombatVisualComponent`
- Boss: `boss_warden.tres` (`is_boss`) → phase 2 at HP ratio summons adds via `SignalBus.enemy_spawned`
- Room `+damage` boon soft-caps after 2 picks (`RunState.damage_boon_picks`)
- Room polish: `RoomDresser` adds floor grid / neon rails / doorway carving; `RoomTransition` fades scene swaps; HUD `Minimap` (procedural only) reads `DungeonGraph` + `explored` / `cleared` / boss/shop/treasure/secret via `room_entered`
- **Cleared rooms stay empty on revisit** — `DungeonRoom.cleared` is set on clear; `ArenaController` skips waves and keeps doors open when re-entering
- Characters: `StylizedBodyVisual` (`_draw` silhouettes + idle/walk) replaces greybox rects; combat FX stay on `CombatVisualComponent`
- Feel P2: `FeelAudio` autoload — procedural SFX + rumble on combat SignalBus events
- Spawns: wave timing/counts stay; `faction_weights` remaps definitions via `EnemyCatalog`
- Final room still opens reward/craft, then `run_won`

### Enemy behaviors (Phase E)

- `EnemyBehavior` plugins on `EnemyDefinition.behavior_modules`
- Modules: aggro swarm, erratic dodge, tactical support, hyper chase, death burst
- `status_vulnerabilities` scales buildup (savages↔burn, beasts↔bleed, androids↔shock, cyborgs↔glitch)
- `BIO_MUTANT` + death cloud; Neuro-hacker `EconomyRam` + ally drone + RAM crafts
- Signal: `ram_slots_changed(used, max_slots)`
- Route pick: `tutorial_route` / `campaign_route` / `procedural_route`
- Synergies: Chemical Short, Napalm Rend, System Crash, Concussive Ignition
- Biome traps: `BiomeDefinition.trap_*` → `BiomeTrap` props in arena

## Development order

See Phase A–F in [`systems_extensibility_plan.md`](systems_extensibility_plan.md):
Economies → Status/Synergy → UpgradeEffects/Loot → ActRoute → Enemy behaviors → Neuro-hacker + content volume.
