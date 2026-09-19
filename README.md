# EON

Isometric Hades-like action roguelike (Godot 4.7). Four architectures, dash/attack/special/cast, statuses, and **48 shared artifacts** plus Geometry crafts.

## Run

```bash
godot --path .
```

Main scene is class select (`res://ui/class_select.tscn`). Pick a route and an architecture, then **Begin Run**.

- **WASD** move
- **LMB** attack (hold to charge-throw on Синтетик)
- **RMB** special / shield
- **Space** dash (i-frames)
- **Q** architecture special (Lattice Collapse / swarm / Vent / drone)
- **R** new run (same class) after death
- **C** class select after death

Godot 4.7.1+ required. Headless smokes:

```bash
godot --headless --path . res://tools/validate_artifacts.tscn
godot --headless --path . res://tools/validate_geometry_rewards.tscn
```

Vulkan issues on some VMs: `godot --rendering-driver opengl3 --path .`

## What you can do

- Choose **Синтетик / Улей / Паровоз / Нейро-хакер**
- Clear rooms, then pick **one of three artifacts** (rarity + house)
- Elite kills can drop a walk-over **artifact orb**
- Pair artifacts to unlock named **combos** (Storm Step, Mercy Kill, …)

See `CREDITS.md` for third-party assets.
