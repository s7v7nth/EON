# EON

Isometric Hades-like action roguelike (Godot 4.7). Four architectures, dash/attack/special/cast, statuses, and **57 shared artifacts** plus Geometry crafts.

## Run

```bash
godot --path .
```

Main scene is class select (`res://ui/class_select.tscn`). Pick a route and an architecture, then **Begin Run**.

- **WASD** move
- **LMB** attack (hold to charge-throw on Синтетик)
- **RMB** special / shield
- **Space** dash (Hive: hold Dissipate)
- **Q** architecture special (Lattice Collapse / swarm / Vent / drone)
- **R** new run (same class) after death
- **C** class select after death

Godot 4.7.1+ required. Headless smokes:

```bash
godot --headless --path . res://tools/validate_artifacts.tscn
godot --headless --path . res://tools/validate_geometry_rewards.tscn
godot --headless --path . res://tools/validate_encounters_rooms.tscn
godot --headless --path . res://tools/validate_hud_chrome.tscn
```

Vulkan issues on some VMs: `godot --rendering-driver opengl3 --path .`

## What you can do

- Choose **Синтетик / Улей / Паровоз / Нейро-хакер** (1–4 + Enter on class select)
- Clear rooms, then pick **one of three artifacts** (click or press 1/2/3)
- Shop / treasure / secret rooms spawn walk-over **artifact orbs**. Shops charge **gold** (rarer = more); caches and elite drops stay free.
- Enemies drop **gold** on kill (HUD, top-left).
- Pair artifacts to unlock named **combos** (Storm Step, Mercy Kill, Ion Phase, …). Pairings toast when they fire.

See `CREDITS.md` for Kenney / OpenGameArt CC0 packs (sprites + SFX).
