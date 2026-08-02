# EON — Systems Contracts

Design contracts for biomes, elements, enemies, architectures, and skill loop.
Implementation grows on top of components + `Resource` data + `SignalBus`.

**Extensibility roadmap (how to add content without rewriting the core):**
[`docs/systems_extensibility_plan.md`](systems_extensibility_plan.md)

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
| `Faction` | SAVAGE, CYBORG, ANDROID, ROBO_BEAST, *(planned)* BIO_MUTANT |
| `BiomeId` | JUNGLE, DATA_CENTER, DOWNTOWN, RESIDENTIAL, TAIGA, ALLEY, LANDFILL, MALL, WASTELAND, GATEWAY |
| `ArchitectureId` | DEFAULT (Синтетик), NANOMACHINES (Улей), ELECTRO_TRAIN (Паровоз), *(planned)* NEURO_HACKER |
| `EconomyPolicy` | ENERGY_ADRENALINE, BLOOD_HARVEST, OVERHEAT, *(planned)* RAM_COMPUTE |
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
| DEFAULT / Синтетик | `EconomyAdrenaline` | Energy machete / disc / shield-parry |
| NANOMACHINES / Улей | `EconomyBloodHarvest` | Nano blade / whip / toad |
| ELECTRO_TRAIN / Паровоз | `EconomyOverheat` + Vent (Q) | Plasma gun / blade / mortar |
| NEURO_HACKER | RAM slots *(planned)* | Smart pistol / holo-blades / drones |

Catalog: `resources/architectures/architecture_catalog.tres` — UI builds pick list from it.
Runtime: `ArchitectureData.economy` (`ResourceEconomy`) is duplicated on equip; Player has no `match economy_policy`.

Special input: `special` (Q) → `economy.try_special()` (reactor pulse / swarm burst / Vent).

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
- `special_triggered(source)` / `vent_triggered(source)`

## Biome package (`BiomeDefinition`)

`id`, palette, `wave_set`, faction weights, element bias, loot tags, neighbors.
Gateway rooms blend two biomes for smooth transitions.
Run order comes from `ActRoute` (Act1 outskirts → Act4 data core), not hardcoded room lists.

### ActRoute (Phase D)

- `resources/runs/act_route.gd` + `act_definition.gd`
- Default playable path: `tutorial_route.tres` — Landfill → Wasteland → Data Center
- Full campaign data: `campaign_route.tres` (Acts 1–4)
- Room scenes (`room_01/02/03`) are **geometry templates**; `ArenaController` paints biome + swaps `wave_set` from `RunState`
- Spawns: wave timing/counts stay; `faction_weights` remaps definitions via `EnemyCatalog`
- Final room still opens reward/craft, then `run_won`

## Development order

See Phase A–F in [`systems_extensibility_plan.md`](systems_extensibility_plan.md):
Economies → Status/Synergy → UpgradeEffects/Loot → ActRoute → Enemy behaviors → Neuro-hacker + content volume.
