# EON

Isometric Hades-like action roguelike (Godot 4.7). Four architectures, dash/attack/special/cast, statuses, and **57 shared artifacts** plus Geometry crafts.

## Run

```bash
godot --path .
```

Main scene boots a dark splash then class select (`res://ui/class_select.tscn`). Renderer is **GL Compatibility** for both the Godot **app / editor** and Play (not Forward+). macOS uses native `opengl3`, not ANGLE. Unused Kenney packs are skipped at editor import. Pick a route and an architecture, then **Begin Run**.

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
godot --headless --path . res://tools/validate_hub_hive.tscn
```

Open the Godot **app** (editor) with Compatibility, then F5 / Play. On macOS:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --rendering-method gl_compatibility --rendering-driver opengl3 --editor --path .
# F5 equivalent:
/Applications/Godot.app/Contents/MacOS/Godot --rendering-method gl_compatibility --rendering-driver opengl3 --path .
```

`godot --path .` already uses Compatibility from `project.godot` (`rendering_method` and `rendering_method.editor`). On some VMs also pass `--rendering-driver opengl3`.

## What you can do

- Choose **Синтетик / Улей / Паровоз / Нейро-хакер** (1–4 + Enter on class select)
- Clear rooms, then pick **one of three artifacts** (click or press 1/2/3)
- Shop / treasure / secret rooms spawn walk-over **artifact orbs**. Shops charge **gold** (rarer = more); caches and elite drops stay free.
- Enemies drop **gold** on kill (HUD, top-left).
- Pair artifacts to unlock named **combos** (Storm Step, Mercy Kill, Ion Phase, …). Pairings toast when they fire.

See `CREDITS.md` for Kenney / OpenGameArt CC0 packs (sprites + SFX).
