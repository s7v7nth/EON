# EON — Systems Contracts

Design contracts for biomes, elements, enemies, architectures, and skill loop.
Implementation grows on top of components + `Resource` data + `SignalBus`.

**Extensibility roadmap (how to add content without rewriting the core):**
[`docs/systems_extensibility_plan.md`](systems_extensibility_plan.md)

**External-AI architecture brainstorm context** (keep in sync on significant design changes):
[`docs/architecture_brainstorm_prompt.md`](architecture_brainstorm_prompt.md)

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
| DEFAULT / Синтетик | `EconomyAdrenaline` | Energy blade · hold-block shield · charge-throw · combos; Q/F reserved |
| NANOMACHINES / Улей | `EconomyBloodHarvest` | Nano blade / whip / toad |
| ELECTRO_TRAIN / Паровоз | `EconomyOverheat` + Vent (Q) | Plasma gun / blade / mortar |
| NEURO_HACKER | `EconomyRam` (Q = drone slot) | Smart pistol / holo blades / drones |

Catalog: `resources/architectures/architecture_catalog.tres` — UI builds pick list from it.
Runtime: `ArchitectureData.economy` (`ResourceEconomy`) is duplicated on equip; Player has no `match economy_policy`.

### Синтетик — combat contract

- **LMB tap** — melee swing (combo module). **LMB hold** — charge returning blade throw.
- **RMB hold** — energy shield (−50% damage); first **0.5s** = parry (full negate + stagger).
- **Combos** (`systems/combat/ComboRecognizer`): LMB×3 string; LMB→RMB→LMB circle AoE.
- **Energy** — pool ~50; spent on attacks/dash; absorbs damage before HP; ideal dash refunds cost.
- **Adrenaline** — 0 out of combat; baseline in combat → **3 Energy/s**; rises from hits, HP damage, parry, ideal dash; decays to floor.
- **Engagement** — `CombatEngagementComponent` (enemy aggro and/or recent exchange).
- **Q / F** — reserved (no-op for Synthetic).

Special input: `special` (Q) → `economy.try_special()` (swarm / Vent / drone; Synthetic reserved).

**Upgrade rule:** one upgrade = one or more `UpgradeEffect` verbs (`systems/upgrades/`), not Player bool flags.
Craft parts (`LootPart` in `resources/loot/`) grant tags; recipes gate on `owned_tags`.
Catalog: `resources/upgrades/upgrade_catalog.tres`.

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
- Room scenes (`room_01/02/03`) are **geometry templates** (pool for procedural picks); `ArenaController` paints biome + swaps `wave_set` from `RunState`
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
