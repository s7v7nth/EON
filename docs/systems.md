# EON — Systems Contracts

Design contracts for biomes, elements, enemies, architectures, and skill loop.
Implementation grows on top of components + `Resource` data + `SignalBus`.

## Pillars

1. **Architecture** — language of actions + resource economy policy.
2. **Elements** — how damage behaves (type + status), not just a tint.
3. **Faction** — enemy identity (resists + preferred behaviours).
4. **Biome** — pressure pack (enemy weights, element bias, loot tags, palette).

Skill actions feed **Adrenaline** + **Style Score** + optional craft tokens.

## Enums (`GameplayEnums`)

| Enum | Values |
|------|--------|
| `DamageType` | PHYSICAL, ELECTRICITY, CORROSION, FIRE, BLEED |
| `Faction` | SAVAGE, CYBORG, ANDROID, ROBO_BEAST |
| `BiomeId` | JUNGLE, DATA_CENTER, DOWNTOWN, RESIDENTIAL, TAIGA, ALLEY, LANDFILL, MALL, WASTELAND, GATEWAY |
| `ArchitectureId` | DEFAULT, NANOMACHINES, ELECTRO_TRAIN |
| `EconomyPolicy` | ENERGY_ADRENALINE, NANO_SWARM, OVERHEAT |
| `StyleAction` | HIT, KILL, PERFECT_DODGE, PARRY, COMBO, MULTI_KILL, ELEMENT_CASCADE, TOOK_DAMAGE |

## Damage & resists

- Final damage: `raw * (1.0 - resist)` clamped to `[0.05, 2.0]` multiplier.
- Resists live on `CharacterStats` / overrides on `EnemyDefinition` / architecture base.
- Status application: `status_chance * (1.0 - resist*0.5)` → `StatusComponent`.

| Type | Status | Notes |
|------|--------|-------|
| PHYSICAL | Stagger (short) | Armor-break flavour |
| ELECTRICITY | Shock | Slow actions; arc chance later |
| CORROSION | Acid | DoT + resist shred |
| FIRE | Burn | Strong DoT |
| BLEED | Bleed | DoT scaled by target movement |

## Architectures

| Id | Economy | Starter primitives |
|----|---------|-------------------|
| DEFAULT | ENERGY_ADRENALINE | Machete / Toss / Shield-parry |
| NANOMACHINES | NANO_SWARM | Blade / Whip / Toad |
| ELECTRO_TRAIN | OVERHEAT | Plasma gun / blade / mortar (skeleton) |

**Upgrade rule:** one upgrade = one new verb or rule, not flat +% only.
Craft parts are tagged `arch` / `element` / `shape`.

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

## Development order

0 Contracts → 1 Elements → 2 Skill (dodge/parry/combo/score) → 3 Architecture Default →
4 Two biomes + gateway → 5 Nanomachines + craft → 6 Content volume / Electro-Train skeleton.
