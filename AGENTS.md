# AGENTS.md

## Cursor Cloud specific instructions

### Project overview
`EON` is a single-product **Godot 4.x game** (isometric action RPG, vertical slice/greybox). It is written entirely in **GDScript** — there is no backend, database, package manager, or external service. The only runtime dependency is the Godot engine binary itself. Main scene: `res://levels/rooms/room_01.tscn`. Architecture/design notes live in `plan.md`.

### Engine / running
- The project targets Godot **4.7** (see `config/features` in `project.godot`). The environment provides the `godot` binary (Godot `4.7.1-stable`) on `PATH` at `/usr/local/bin/godot`.
- Run the game (GUI): `DISPLAY=:1 godot --path /workspace`. `:1` is the desktop/display used for manual testing.
- This VM has **no Vulkan support**, so Godot automatically falls back to the OpenGL 3 (Compatibility) renderer. This is expected and fine for this 2D game — the `VK_KHR_surface not found` error and the OpenGL fallback warning are harmless.
- There is **no audio device**; Godot falls back to the dummy audio driver (harmless ALSA errors on startup are expected).
- The `.godot/` import cache is gitignored. On a fresh checkout Godot imports assets automatically on first run; you can also pre-import headlessly with `godot --headless --path /workspace --import`.

### Testing (headless smoke tests)
Automated tests are Godot scene runners under `tools/` (`tools/validate_*.tscn`). Run one headlessly, e.g.:
`godot --headless --path /workspace tools/validate_step_a.tscn`
Each runner prints an `*_OK` line and exits 0 on success. Known-good runners include: `validate_step_a`..`validate_step_e`, `validate_ranged`, `validate_task6`..`validate_task9`.
- Note: `tools/validate_arena.tscn` (the older Task 10-11 smoke test) currently fails because it expects a static `Entities/EnemyDummy` node in `levels/arena/arena.tscn`, but the arena now spawns enemies via waves (as `validate_step_a` verifies). This is a pre-existing test/scene mismatch, not an environment issue.

### Lint / build
There is no separate lint or build step for development — GDScript is parsed by the engine. Running the headless test scenes (or opening the project) surfaces any script/parse errors.

### Manual-testing gotchas
- On the "You Died" screen the scene tree is paused (`get_tree().paused = true`); press `R` (the `restart` action) to restart. Input still reaches the game while paused.
- Controls: `WASD` move, left mouse = melee attack (aimed at cursor), right mouse = ranged attack, `Space` = dash, `1/2/3` = switch weapon (Blade/Hammer/Bow), `R` = restart. Enemy contact damage is high, so ranged attacks are the safer way to demo defeating an enemy.
