# Thoth

Thoth is the C++17/raylib top-down block automation sandbox in this repository.

The deterministic simulation lives in `include/thoth` and `src/thoth`. The raylib desktop app lives in focused modules under `src/app`, with `src/app/main.cpp` kept as the small executable entry point.

## Game Direction

Thoth is a compact deterministic automation-survival game:

- Explore a deterministic block world.
- Mine trees, stone, coal, iron ore, and copper ore by hand.
- Craft a workbench, then use it to build belts, inserters, chests, furnaces, miners, assemblers, labs, and power machines.
- Build an ore-to-plate factory line.
- Automate iron-plus-copper science packs and unlock faster logistics, electric power, circuit inserters, advanced science, and logistic drones.
- Charge powered archive terminals with beacon cores, then open rift gates to a resource-rich outer dimension band.
- Fulfill visible supply contracts that turn the sandbox into a clear plate-to-rift objective chain.
- Push into biome lairs, prepare boss summons with factory output, and defend against pressure with powered guard towers, repair pylons, pressure relays, and arc towers.
- Use biome and boss rewards to widen the factory plan instead of only stockpiling items.
- Stabilize remote outposts with sustained deliveries, recover archive fragments, and unlock alternate recipes that change factory layouts.
- Save, load, and replay deterministic simulation state.

The renderer is intentionally simple. The product focus is a Steam-demo vertical slice where a player can build a starter factory, follow visible contracts, conquer biome lairs, and stabilize a rift. The engineering focus is a headless deterministic simulation with a practical raylib front end.

## Current MVP Status

Implemented in C++:

- Chunked deterministic terrain.
- Validated data registries for tiles, items, machines, recipes, and technologies.
- Player movement, mining, placing, inventory, hotbar, and workbench-gated machine crafting.
- Belts with deterministic item transport and fast belts after research.
- Chests, provider/requester chests, inserters, circuit inserters, burner miners, furnaces, assemblers, labs, generators, power poles, electric miners, logistic ports, logistic drones, and guard towers.
- Splitters, train stops, offshore pumps, pipes, water barrels, beacon cores, archive terminals, and rift gates.
- Finite iron, copper, and coal resource tiles that deplete through miners, with richer ore farther from spawn to create expansion pressure.
- Iron and copper ore-to-plate resource chains through miners, furnaces, inserters, belts, and chests.
- Small tech tree with iron-plus-copper science, advanced science, circuit inserters, logistic networks, and copper-dependent power machines.
- Circuit inserter filters/thresholds and powered provider/requester drone deliveries.
- Powered archive charging, archive-fragment alternate recipe unlocks, train-stop cargo hops, pump-to-pipe water movement, and rift-gate travel to a deterministic high-resource outer band.
- Supply contracts for iron, copper, science, powered mining, logistics, advanced science, archive charging, and rift travel, with an explicit main-objective completion state.
- Biome contracts, deterministic Marsh/Desert/Badlands/Snowfield/Crystal lairs, lair-specific hostile pressure, and five prepared boss summons: Marsh Broodheart, Glass Maw, Badlands Warden, Frost Nullifier, and Rift Signal Tyrant.
- Seeded procedural lairs beyond the authored starter ladder, with deterministic surface entrances, interior chambers, biome caches, lair hearth recovery points, recovery crates, and repeat boss/relic opportunities outside the protected early ring.
- Boss relic rewards that unlock or craft factory-relevant defense and support tools.
- Powered outpost beacons that consume biome-specific inputs, require sustained delivery routes for full stability, and extend biome contracts beyond inventory stockpiles.
- Factory pressure readouts, pressure hotspot maps, and deterministic hostile probe spawns once science production makes the factory visible enough to defend, with waves anchoring around the factory footprint and pressure enemies pathing toward infrastructure.
- Powered guard towers and arc towers that target hostile entities deterministically, consume optional ammo for stronger/specialized shots, and remain weak fallback defenses when unfed.
- Powered repair pylons that rebuild adjacent wall gaps and pressure relays that mitigate future factory pressure.
- Drone construction jobs from ghost builds, plus planning mode for rapid blueprint-style placement without material consumption.
- Remote logistic-port scouting that prioritizes the port's local biome, returns route-bonus materials and biome fragments, names discovered regions, and feeds post-victory cartography goals.
- Production-rate panels for plates, science, ammo, and sustained route progress.
- A repeatable post-victory expedition board covering scouting, boss relics, rift storms, stable outpost routes, pressure rewards, lair caches, train freight, scrap recycling, and powered mining.
- Deterministic power network recomputation.
- Plain-text save/load and replay foundation.
- Headless tests for world generation, registries, automation, chunk-boundary factory lines, rich save/load state, replay, research, power, workbench gating, circuit inserter config, and logistic delivery persistence.
- A headless representative factory benchmark for simulation cost checks.
- Packaged deterministic ore-to-plate, science/research, and 60-second full-flow replay artifacts under `assets/replays/`, validated by `make cpp-validate-replays`.
- Raylib UI panels, guided first-line, science/research, and power-progression checklists with reactive next-step hints, interactive build-menu recipe cards with ready/need states, faced-machine deposit/take controls with item labels, counts, and 1x/5x/all batch transfer amounts, explicit furnace/assembler recipe selection plus circuit/requester config buttons, machine state/process/action chips, actionable recipe/input/resource/power troubleshooting, compact machine process-flow strips, inventory role badges for materials/buildables/tiles/tech items, a reviewable authored pixel atlas source with PNG export plus generated fallback sprites, deterministic terrain variation, belt/machine motion accents, finite-resource richness pips, status dots with on-world issue badges, ghost placement preview with invalid-reason labels, target and production feedback, reviewable authored audio cue source with WAV export plus fallback tones for actions, production, and severe machine issues, per-machine issue diagnostics, tick-cost debug readouts, pause/step/fast-forward, and replay-backed demo factories.

Still rough:

- Authored pixel/block sprite atlas is present as `assets/sprites/thoth_atlas.art`, with a second-pass readability sweep for terrain, items, machines, and the player, plus deterministic per-tile tint/flip variation and tick-based belt/machine motion accents in the renderer; later art work should focus on final live tuning and style polish.
- Generated sprite atlas fallback remains available for reference and recovery.
- Inventory, machine, and build menus have scan-first state labels now, but still need a final visual design pass.
- Authored audio cue source is present as `assets/audio/thoth_cues.sfx`, with tuned deterministic WAV exports for core work, UI, error, save/load, and production feedback; final live-listening mix polish is still pending.
- The game now has an explicit completion state, a five-boss ladder, relic-gated support machines, outpost contracts, stable routes, generated lairs, route-aware scouting, archive alternates, construction ghosts, factory-anchored pressure, and a repeatable post-victory expedition board, but the expanded loop still needs live tuning.

## Build And Run

Requirements:

- CMake 3.24+
- A C++17 compiler
- `make`
- raylib installed, or network access so CMake can fetch raylib 6.0

Run the C++ game:

```console
make cpp-run
```

Run the C++ build and headless tests:

```console
make test
```

Run the C++ representative factory benchmark:

```console
make cpp-benchmark
```

Run a larger local benchmark:

```console
make cpp-benchmark-large
```

Run a local stress benchmark:

```console
make cpp-benchmark-stress
```

The default benchmark simulates 48 burner ore-to-plate lines and 16 powered mining lines for 900 ticks. The larger target doubles that to 96 burner lines and 32 powered lines. The stress target simulates 512 burner lines plus 128 powered lines, or 4,096 machines, for 600 ticks. The benchmark reports average, p95, and max observed tick cost, plus machine-tick throughput. It fails if `us_per_tick` exceeds `THOTH_BENCHMARK_MAX_US_PER_TICK` or `us_per_machine_tick` exceeds `THOTH_BENCHMARK_MAX_US_PER_MACHINE_TICK`; when unset, it uses conservative defaults. You can also set `THOTH_BENCHMARK_TICKS`, `THOTH_BENCHMARK_BURNER_LINES`, and `THOTH_BENCHMARK_POWERED_LINES` to scale the deterministic headless factory without opening raylib.

Validate the packaged deterministic replay demos without opening a window:

```console
make cpp-validate-replays
```

Validate authored sprite/audio sources plus exported runtime PNG/WAV assets without opening a window:

```console
make cpp-validate-assets
```

Export the generated sprite atlas without opening a window:

```console
make cpp-export-atlas
```

Validate and export the authored sprite atlas without opening a window:

```console
make cpp-export-authored-atlas
```

Export generated starter audio cues without opening a window:

```console
make cpp-export-audio
```

Validate and export the authored audio cue pack without opening a window:

```console
make cpp-export-authored-audio
```

Export the deterministic full-flow preview image without opening a window:

```console
make cpp-export-media-preview
```

Export deterministic full-flow playtest telemetry JSON without opening a window:

```console
make cpp-export-playtest-telemetry
```

The telemetry export writes `assets/previews/thoth_playtest_telemetry.json` with replay-backed contract progress, pressure-wave timing, pressure hotspots, archive choices, construction state, sustained outpost routes, production-rate panels, region/scout reports, machine counts, structure damage, and current guidance text.

Run a bounded raylib window smoke and save a screenshot:

```console
make cpp-smoke-window
```

On headless Linux CI, run it under Xvfb:

```console
xvfb-run -a -s "-screen 0 1280x720x24" make cpp-smoke-window
```

Build and run the raylib app:

```console
make cpp-run
```

## In-Game Controls

- `WASD` / arrow keys: move and face target direction
- Number keys: select hotbar slot
- `Space`: mine target tile
- `P`: place selected item
- `R`: rotate machine output direction before placing
- `E`: deposit selected item into faced machine
- Mouse click a machine panel `+`/`-` item button: deposit or take one item
- `V`: show/hide inventory grid
- Mouse click an inventory hotbar slot: select that slot
- Mouse click an inventory stack: assign it to the selected hotbar slot
- Right-click an inventory hotbar slot: clear that slot
- Mouse click an assembler recipe button: set its active recipe
- `Q`: show/hide build menu
- `[` / `]`: select build-menu recipe
- `Z`: craft selected build-menu recipe
- Mouse click a build-menu card: craft that recipe
- `K/C/F/B/I/M/X/L/T/G/O/N`: craft known recipes
- Build-menu click or `[ ]` plus `Z`: craft selected later recipes such as circuit/logistic parts
- `F5` / `F9`: save/load `thoth_save.txt`
- `F6`: export the generated sprite atlas to `assets/sprites/thoth_generated_atlas.png`
- `F7`: load the packaged deterministic science/research replay
- `F8`: load the packaged deterministic ore-to-plate factory replay
- `F10`: load the packaged 60-second full-flow replay
- `F11`: audition the next audio cue for live mix checks
- `Backspace`: pause/resume
- `Enter`: step one tick while paused
- Hold `Shift`: fast-forward simulation
- `Tab`: toggle debug detail

## Portfolio Highlights

- Core simulation is independent from raylib.
- Same seed plus same replay inputs should reproduce the same state, including packaged ore, science, and full-flow demo replays.
- Power networks are recomputed deterministically from placed machines after save/load.
- Tests exercise the factory loop rather than only rendering.
- `make cpp-benchmark`, `make cpp-benchmark-large`, and `make cpp-benchmark-stress` run deterministic mixed factories without opening a window.
- `make cpp-smoke-window` opens the raylib app, loads the authored atlas and WAV cues, renders the full-flow replay state, saves `assets/previews/thoth_window_smoke.png`, and runs in CI through Xvfb.
- The app is a thin UI shell over the deterministic game model, split into focused asset, CLI, input, preview, runtime, and UI/render modules.

## Repository Shape

```text
include/thoth/
  core/
  game/
src/
  app/                 raylib desktop app modules and executable entry point
  thoth/core/          deterministic utilities
  thoth/game/          headless simulation, registry, save, replay, world
tests/                 C++ simulation tests
benchmarks/            C++ headless simulation benchmark
assets/replays/        packaged deterministic replay demos
assets/previews/       deterministic full-flow preview export
assets/sprites/        authored sprite atlas source, runtime PNG export, and atlas layout notes
assets/audio/          authored audio cue source, WAV cue exports, and generated fallback notes
```

## Roadmap

Competitive positioning lives in `docs/market-audit.md`. The old Lua/Love2D pivot questions in GitHub issues `#35` and `#36` are obsolete now that this repo is settled as the C++/raylib game codebase.

Near-term work:

- Playtest the expanded biome ladder, relic costs, outpost activation cadence, and defense-machine power demands in one continuous run.
- Playtest the repeatable post-victory expedition board across boss relics, stable outpost routes, pressure rewards, rift freight, scrap recycling, and powered mining.
- Add bespoke sprite/audio/UI polish for the new lairs, enemies, bosses, fragments, outpost beacons, construction ghosts, repair pylons, pressure relays, and arc towers.
- Polish final atlas styling and authored WAV cues after the expanded content loop is playable.
- Strengthen performance guardrails as larger factories and pressure waves land.
