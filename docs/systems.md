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
| `DamageType` | PHYSICAL, ELECTRICITY, CORROSION, FIRE, BLEED, *(planned)* GLITCH |
| `Faction` | SAVAGE, CYBORG, ANDROID, ROBO_BEAST, *(planned)* BIO_MUTANT |
| `BiomeId` | JUNGLE, DATA_CENTER, DOWNTOWN, RESIDENTIAL, TAIGA, ALLEY, LANDFILL, MALL, WASTELAND, GATEWAY |
| `ArchitectureId` | DEFAULT (Синтетик), NANOMACHINES (Улей), ELECTRO_TRAIN (Паровоз), *(planned)* NEURO_HACKER |
| `EconomyPolicy` | ENERGY_ADRENALINE, NANO_SWARM → Blood Harvest, OVERHEAT, *(planned)* RAM_COMPUTE |
| `StyleAction` | HIT, KILL, PERFECT_DODGE, PARRY, COMBO, MULTI_KILL, ELEMENT_CASCADE, TOOK_DAMAGE |

## Damage & resists

- Final damage: `raw * (1.0 - resist)` clamped to `[0.05, 2.0]` multiplier.
- Resists live on `CharacterStats` / overrides on `EnemyDefinition` / architecture base.
- Status application: `status_chance * (1.0 - resist*0.5)` → buildup on `StatusComponent`.

| Type | Status | Target behaviour |
|------|--------|------------------|
| PHYSICAL | Stagger gauge | Interrupt + crit window on next hit |
| ELECTRICITY | Shock | Chain lightning at full buildup |
| CORROSION | Acid / armor break | +% damage taken; acid puddle on death |
| FIRE | Burn → Panic | DoT; full buildup = chaotic flee |
| BLEED | Rended wounds | Strong DoT while moving/attacking |
| GLITCH | Fault | Friendly fire or robot shutdown |

Synergies are data (`SynergyRecipe`), e.g. Acid+Shock → charged gas cloud.

## Architectures

| Id | Economy | Starter primitives |
|----|---------|-------------------|
| DEFAULT / Синтетик | ENERGY_ADRENALINE | Energy machete / disc / shield-parry |
| NANOMACHINES / Улей | Blood Harvest (HP) | Nano blade / whip / toad |
| ELECTRO_TRAIN / Паровоз | OVERHEAT + Vent | Plasma gun / blade / mortar |
| NEURO_HACKER | RAM slots | Smart pistol / holo-blades / drones |

**Upgrade rule:** one upgrade = one `UpgradeEffect` verb, not flat +% only.
Craft parts are tagged `arch` / `element` / `shape`; recipes gate on owned tags.

## Style score (Hotline-like)

- Multiplier rises on stylish actions; resets on `TOOK_DAMAGE`.
- Room rank C–S from peak multiplier + kills; influences loot quality.

## SignalBus style events

- `style_action(action, points)`
- `perfect_dodge(source)`
- `parry_success(source)`
- `style_score_changed(score, multiplier, rank)`
- `status_applied(target, status_id)`
- `architecture_changed(architecture_id)`
- `biome_changed(biome_id)`
- `upgrade_crafted(upgrade_id)`

## Biome package (`BiomeDefinition`)

`id`, palette, `wave_set`, faction weights, element bias, loot tags, neighbors.
Gateway rooms blend two biomes for smooth transitions.
Run order comes from `ActRoute` (Act1 outskirts → Act4 data core), not hardcoded room lists.

## Development order

See Phase A–F in [`systems_extensibility_plan.md`](systems_extensibility_plan.md):
Economies → Status/Synergy → UpgradeEffects/Loot → ActRoute → Enemy behaviors → Neuro-hacker + content volume.
