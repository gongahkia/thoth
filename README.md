# Thoth

Thoth is now a Lua/LOVE 11.5 top-down automation reboot.

The previous C++17/raylib codebase was removed intentionally. The new repo starts with a compact deterministic simulation, a LOVE app shell, reusable PNG/WAV assets, headless Luajit tests, and a package target.

## Current Build

Requirements:

- LOVE 11.5
- Luajit 2.1
- `make`
- `zip`

Run the game:

```console
make run
```

Run headless tests:

```console
make test
```

Run tests plus asset sanity checks:

```console
make check
```

Run a bounded LOVE launch smoke:

```console
make smoke
```

Build a `.love` package:

```console
make package
```

## Repository Shape

```text
main.lua            LOVE callbacks and fixed-step loop
conf.lua            LOVE window, identity, and module config
src/core/           deterministic RNG, grid helpers, serialization
src/game/           world, inventory, simulation, save, replay
src/app/            input, rendering, audio
tests/              headless Luajit tests
assets/sprites/     reusable sprite atlas PNG
assets/audio/       reusable WAV cues
docs/               product notes
to do.md            reboot execution roadmap
```

## Implemented Reboot Slice

- Seeded deterministic world generation.
- Player facing, movement, mining, inventory, hotbar selection, crafting, placement, and deposit commands.
- Starter machines: workbench, burner miner, belts, inserters, furnace, chest, assembler, lab, fast belt unlock.
- Ore-to-plate starter automation.
- Minimal science/research path for Logistics 1.
- Plain Lua save/load and replay serialization.
- LOVE renderer/HUD/audio shell using existing assets.
- Headless tests for determinism, mining, crafting/placement, factory production, research, save/load, replay, and asset presence.

## Controls

- `WASD` / arrows: move
- `Space`: mine faced tile
- Number keys: select hotbar
- `P`: place selected item
- `R`: rotate build direction
- `E`: deposit selected item into faced machine
- `K/F/C/B/I/M/X/L/T`: craft known recipes
- `F5` / `F9`: save/load
- `Backspace`: pause
- `Enter`: step one tick while paused
- Hold `Shift`: fast-forward
