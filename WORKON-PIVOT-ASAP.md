# Pivot ASAP: C++/raylib Block Automation Sandbox

Date: 2026-05-15
Updated: 2026-06-11
Status: implementation direction settled on C++17/raylib; legacy Lua/Love2D source and scaffold plans are obsolete for this active repo

GitHub issue triage on 2026-06-11: `#35` and `#36` are resolved by keeping `Thoth` as the C++/raylib game repo and closing the stale Lua/Love2D scaffold path. `#37`, `#38`, `#39`, `#40`, and `#41` through `#47` are closed as implemented in the C++17/raylib codebase. Remaining active planning tracks: `#48` for final polish and `#49` for ongoing tests/performance guardrails.

## Working Assumption

"More like Factorio/Minecraft" means an open-ended block-world automation sandbox:

- Minecraft influence: explore, mine, chop, place, craft, reshape a blocky world, build a base, survive light world pressure.
- Factorio influence: automate extraction, routing, processing, storage, power, research, expansion, and throughput.
- Microcraft influence: compact systems, clear registries, tile/entity architecture, simple menus, small-scope charm.

This does not mean building a full first-person 3D Minecraft engine first. For a C++/raylib project, the stronger and more realistic direction is still a polished top-down or 2.5D block world with chunked terrain, z/depth layers, and a deep automation loop.

## One-Sentence Pitch

A C++/raylib block automation sandbox where the player carves a procedural world by hand, then bootstraps that world into a growing factory of miners, belts, furnaces, assemblers, power grids, storage, and research.

## Direction Change From The Earlier Plan

The previous Infinifactory-like direction centered on bounded puzzle rooms and target-output validation. This pivot should instead center on:

- Persistent procedural world, not isolated puzzles.
- Resource extraction and factory growth, not one-off assembly challenges.
- Player-authored bases and terrain shaping, not fixed puzzle arenas.
- Progression through recipes and tech, not level unlocks alone.
- Emergent goals, with optional milestones, not only pass/fail solutions.

Infinifactory can still inform placement tools, simulation previews, and debugging UX, but it should no longer be the product model.

## Why This Still Fits Thoth

The old Lua repo was a framework, not a game. That implementation path has been discarded; keep the useful architecture ideas in the C++ codebase instead of porting line-by-line:

- Fixed-step simulation with ordered systems.
- Input commands recorded separately from rendering.
- Chunked tile storage and deterministic terrain generation.
- Spatial indexing for entities and dropped items once needed.
- Save/snapshot/replay support from serializable game state.
- Event or message queues for machine state, UI updates, combat, and resource changes.

The pivot should make the C++ game the main codebase. Keep raylib in the platform/render layer and keep the core simulation headless so tests, saves, replay, and benchmarks do not need a window.

## Competitive Context

Relevant references:

- [Minecraft](https://www.minecraft.net/en-us/about-minecraft): own-world exploration, building, survival, cross-platform social ecosystem, huge creator economy.
- [Factorio](https://factorio.com/game/content): automation, procedural maps, resource extraction, production goals, defense, scenarios, map editor, Lua scripting for custom scenarios.
- [Luanti](https://docs.luanti.org/about/luanti/): formerly Minetest, an open-source voxel engine with a Lua API. This is the closest "Lua plus voxel sandbox" comparison.
- [Vintage Story](https://www.vintagestory.at/): deeper survival/crafting in a voxel world.
- [Satisfactory](https://www.satisfactorygame.com/), [shapez 2](https://store.steampowered.com/app/2162800/shapez_2/), and [Modulus](https://store.steampowered.com/app/2779120/Modulus_Factory_Automation/) cover the high-polish factory-building space.

The separation should not be "we are bigger than Minecraft or Factorio." The separation should be:

- A complete, small-scope factory sandbox written in C++ with raylib.
- Deterministic simulation with save/replay/debug tooling as a visible portfolio strength.
- A block world that is tactile and editable, but with factory automation as the core loop.
- A clean source-available codebase that reads like a serious systems project.
- A focused solo-developer scope: 2D/2.5D, compact recipe ladder, carefully polished interactions.

## Product Pillars

### 1. Block World That Matters

The world should be a destructible grid with resources, terrain, obstacles, water, caves/depth layers, and player-built structures.

Minimum version:

- Chunked 2D world, for example 32x32 tile chunks.
- Surface layer plus optional cave/depth layers.
- Biomes: grassland, forest, stone, desert, water, ore patches.
- Tile registry with hardness, drops, collision, walkability, buildability, light, and minimap color.
- Deterministic world generation from seed.

### 2. Manual To Automatic Progression

The early loop should feel Minecraft-like, then quickly become Factorio-like.

Early ladder:

1. Gather wood/stone/ore manually.
2. Craft workbench, furnace, chest.
3. Craft belts and burner miner.
4. Automate ore into furnace into chest.
5. Craft lab and science pack.
6. Unlock electric miner, assembler, power poles.
7. Expand to multi-resource chains.

### 3. Factory First

Automation must become the main game, not a side system.

Core machines:

- Belts: directional item transport.
- Inserters: move items between adjacent belts, machines, and chests.
- Miners: extract from resource tiles.
- Furnaces: convert ore to plates.
- Assemblers: consume recipe inputs over time.
- Chests: storage.
- Generators: produce power from fuel.
- Power poles: connect machines into networks.
- Labs: consume science to unlock tech.

Later or extended machines:

- Splitters and filters.
- Underground belts.
- Pumps and fluids.
- Trains or carts.
- Larger logistic networks beyond the current drone-port MVP.
- Richer circuit signals beyond the current filtered/threshold inserter MVP.

### 4. C++-Native Determinism

The game should use deterministic ticks as a signature feature.

Target properties:

- Same seed plus same input replay produces same world state.
- Headless tests can run factory simulations without raylib.
- Replay files can become portfolio artifacts.
- Save files are readable JSON or another documented plain data format.
- Debug HUD can show tick cost, active chunks, belt item count, machine count, power demand, and pending events.

### 5. Compact Polish

The first playable version should be small and refined:

- Good camera, hotbar, placement preview, rotation, mining feedback, item pickup, and UI sounds.
- Clear item icons and tile visuals.
- Readable belts and machine states.
- Pause, step, fast-forward, and maybe ghost placement.
- Save/load from the start.

## Non-Goals For MVP

Avoid these until the core loop is fun:

- Full first-person 3D voxel renderer.
- Multiplayer.
- Infinite vertical 3D terrain.
- Large mob/ecology simulation.
- Huge survival system with hunger, thirst, weather, temperature.
- Dozens of ores and hundreds of recipes.
- Trains and fluids in the first milestone.
- A general-purpose mod platform.

## Proposed Repo Shape

Make the C++ game the primary implementation. The legacy Lua framework code has been removed now that the C++ path covers the playable MVP loop.

Suggested structure:

```text
CMakeLists.txt
include/thoth/
  core/
    deterministic_random.hpp
  game/
    registry.hpp
    simulation.hpp
    world.hpp
src/
  app/
    app_assets.cpp
    app_cli.cpp
    app_input.cpp
    app_preview.cpp
    app_runtime.cpp
    app_ui.cpp
    app_internal.hpp
    main.cpp
  thoth/
    core/
    game/
tests/
  test_world.cpp
```

This keeps the simulation library independent from raylib while giving the desktop app a focused set of raylib-facing modules and a thin executable entry point.

## Data Model Sketch

```cpp
struct World {
    uint64_t seed;
    uint64_t tick;
    ChunkMap chunks;
    EntityMap entities;
    Player player;
    uint32_t nextEntityId;
    uint32_t nextItemId;
};

struct Chunk {
    int cx;
    int cy;
    std::array<Tile, 32 * 32> tiles;
    std::vector<MachineId> machines;
    std::vector<DroppedItemId> droppedItems;
    bool active;
};

struct Tile {
    TileId id;
    int data;
};

struct Machine {
    uint32_t id;
    MachineKind kind;
    int x;
    int y;
    Direction direction;
    Inventory inventory;
    RecipeId recipe;
    int progress;
    uint32_t powerNetwork;
};
```

Suggested deterministic tick order:

1. Apply queued player commands.
2. Update active chunks.
3. Resolve terrain mutations.
4. Update miners and resource extraction.
5. Update belts and logistics.
6. Update inserters.
7. Update machine recipes.
8. Update power networks.
9. Update entities and item pickups.
10. Emit events and update UI-facing state.

## MVP Milestone

The first real milestone should prove the game loop, not the whole dream.

Target demo:

- Start in a seeded top-down block world.
- Move, mine trees/stone/ore, place blocks.
- Craft workbench, furnace, chest, belts, burner miner.
- Place a miner on iron ore.
- Route ore on belts into a furnace.
- Route plates into a chest.
- Save, reload, and replay short deterministic ore-to-plate and science/research sessions.

This is the minimum "Factorio meets Minecraft in C++/raylib" proof.

## Phase Plan

### Phase 0: Lock Direction

Resolved direction:

- Keep `Thoth` as the working product/repo name for now.
- Treat this repository as the C++/raylib game repo, with the reusable headless simulation kept in `thoth_core`.
- Keep raylib as the first desktop target.
- Treat Lua/Love2D scaffold work as obsolete unless a future separate port is explicitly opened.

Current C++ registry status:

- Tile, item, recipe, tech, and machine definitions live in C++ registries and are validated by headless tests.
- Machine definitions expose stable keys, display names, 1x1 MVP footprints, placement surface rules, inventory-slot metadata, and behavior kinds.
- Simulation placement and raylib placement preview use the machine registry instead of hard-coded miner/buildable checks.
- `#37` is implemented and closed.

### Phase 1: World And Player Prototype

- Chunked world storage.
- Seeded terrain generation.
- Player movement and camera.
- Mine/place interaction.
- Inventory and hotbar.
- Save/load.
- Basic raylib renderer with placeholder tiles.

Success condition: walking around, mining, placing, collecting, and saving feels stable.

Current C++ Phase 1 status:

- Chunked world storage, deterministic terrain, raylib camera/player movement, collision, mining, placing, inventory, hotbar, save/load, and replay are implemented.
- `Workbench` is craftable by hand, placeable as a machine, and required as the adjacent station for machine crafting.
- `#38`, `#39`, `#40`, and `#41` are implemented and closed.

### Phase 2: Automation Prototype

- Tile-based belts with deterministic item slots.
- Chests and item insertion/extraction.
- Burner miner.
- Furnace.
- Basic crafting recipes.
- Machine placement preview and rotation.
- Debug overlay for active machines and item count.

Success condition: an ore-to-plate-to-chest line works without manual babysitting.

Current C++ Phase 2 status:

- Deterministic belts, chests, inserters, burner miners, furnaces, placement rotation/preview, the ore-to-plate-to-chest slice, save/load preservation, and replay coverage are implemented.
- `#42`, `#43`, `#44`, and `#45` are implemented and closed.

### Phase 3: Progression Prototype

- Workbench and assembler.
- Lab and science.
- Small tech tree.
- Electric miner, generator, power poles.
- More resources: copper, coal, stone.
- First expansion pressure: bigger ore patch, distance, or hostile territory.

Current C++ prototype resource-chain status:

- Iron ore, copper ore, coal, and stone are registered items or terrain resources in the active C++ prototype.
- Copper ore patches now generate in the deterministic world and a starter copper patch appears near spawn.
- Burner/electric miners can extract copper ore from copper resource tiles.
- Ore and coal resource tiles have finite deterministic richness; miners consume one richness per successful output and leave floor when depleted.
- Furnaces can smelt iron ore or copper ore into the matching plate while preserving the active recipe across save/load.
- Science packs now require both iron plates and copper plates, making the second ore chain part of progression.
- Generator, power pole, and electric miner recipes also consume copper plates after research unlocks them.

Current C++ prototype power rules:

- Power poles connect into one network when their Manhattan distance is 4 or less.
- Generators and electric consumers connect to any pole within Manhattan distance 2.
- Each fueled generator supplies 2 power and each electric miner demands 1 power.
- Underpowered networks stop all electric consumers in that network for the tick.
- Power network topology is recomputed deterministically from placed machines after load.
- `#46` and `#47` are implemented and closed.

Current C++ prototype progression/logistics status:

- Research now advances past `logistics_1` into `automation_control` and `logistic_network`.
- `automation_control` unlocks circuit boards, advanced science packs, and circuit inserters.
- `logistic_network` unlocks provider chests, requester chests, logistic ports, and logistic drones.
- Circuit inserters support item filters plus less/equal/greater threshold checks against their output target, and their configuration persists through save/load.
- Powered logistic ports consume stored drones, reserve items from provider chests, deliver to requester chests, persist in-flight jobs through save/load, and increment production totals.
- Objective/milestone text, craft menu entries, machine panels, process chips, stats, and tutorial hints expose the workbench, circuit, and logistic systems in the raylib app.
- Ore richness now increases with distance from spawn, so expansion has a stronger resource payoff than the starter patch.

Success condition: the player has a reason to scale beyond the first belt line.

### Phase 4: Game Feel And Portfolio Polish

- Pixel/block art pass.
- UI pass for hotbar, inventory, crafting, machine panel, and build menu.
- Audio pass for mining, placing, pickup, belt motion, machine states.
- Tutorial prompts or guided first objective.
- Deterministic replay demo.
- Trailer-worthy 60-second flow.
- README rewrite that presents the project as a game, not a utility library.

Current C++ prototype polish:

- Raylib world view uses a reviewable authored pixel sprite source at `assets/sprites/thoth_atlas.art`, now with second-pass readability polish for terrain, item, machine, and player silhouettes plus deterministic per-coordinate tile tint/flip variants to reduce repeated terrain patterns. It can export to `assets/sprites/thoth_atlas.png` with `make cpp-export-authored-atlas`, still supports `assets/sprites/thoth_atlas.png` as an external override, can export the generated fallback atlas with `F6` or `make cpp-export-atlas`, validates source/exported dimensions with `make cpp-validate-assets`, and layers tick-based belt travel dashes, working-machine pulses, finite-resource richness pips, status dots, on-world issue badges, direction arrows, and progress bars over sprites.
- HUD shows objective text, guided first-line, science/research, and power-progression checklists with reactive next-step hints, compact inventory status, an expandable inventory grid with hotbar assignment and role badges, an interactive build-menu card grid with ready/need states, faced-machine deposit/take controls with item labels/counts plus 1x/5x/all batch transfer amounts, explicit furnace and assembler recipe selection, compact state/process/action chips, compact recipe/input/resource/power diagnostics and actionable troubleshooting text, machine process-flow strips, ghost placement previews with invalid-reason labels, production milestone feedback, authored audio cue source at `assets/audio/thoth_cues.sfx` with tuned low/mid/bright cue roles, `make cpp-export-authored-audio` WAV export, `make cpp-validate-assets` source/WAV validation, F11 in-app cue audition, generated fallback tones, machine/debug, power, status counts, per-machine issue summaries, simulation tick cost, and hotbar item counts.
- Gameplay now has supply contracts from first plates through rift travel, a deterministic factory-pressure score with hostile probes after meaningful science production, and an explicit main-objective completion state.
- The raylib app shell is split into focused app modules for assets/audio, CLI validation/export, input, deterministic preview/window smoke, runtime loop, and UI/rendering, with `src/app/main.cpp` kept as a small dispatch entry point.
- `assets/replays/ore_to_plate.thothreplay` is a packaged deterministic demo replay for the first automation line, `assets/replays/science_research.thothreplay` proves assembler-to-lab science/research progression, and `assets/replays/full_flow.thothreplay` runs a 60-second mining-to-research-to-electric-mining flow; `make cpp-validate-replays` validates all packaged replays without opening a raylib window.
- `make cpp-export-media-preview` writes `assets/previews/thoth_full_flow_preview.png` from the full-flow replay without opening a raylib window, giving the project a deterministic screenshot-style artifact for review. `make cpp-smoke-window` opens the actual raylib app, loads the authored visual/audio assets, renders the full-flow replay state, captures `assets/previews/thoth_window_smoke.png`, verifies the capture dimensions, and runs in CI through Xvfb.
- Simulation machine lookups use a rebuilt coordinate index for stationary machines, improving the local 4,096-machine benchmark sample from about 9.57 ms/tick to 7.27 ms/tick while preserving save/load and replay determinism.
- Final live animation tuning, live-listening audio mix polish, first-session onboarding friction, and deeper recipe/configuration polish for future machine recipes beyond the current furnace/assembler/logistics selectors are still pending.

Success condition: a viewer can understand the game in one minute and trust the engineering in five.

## Remaining Work Before Calling This Complete

Current vertical-slice blockers:

- Finish `#48`: do a live-play visual pass, final UI pass, authored audio mix pass, and any readability fixes that only show up in motion.
- Keep `#49` open: add focused tests/benchmarks as new systems land, and extend stress coverage past the current 4,096-machine sample when needed.

Beyond-MVP completeness candidates:

- Turn supply contracts into a richer campaign spine: optional timed quotas, contract tiers tied to biomes/outposts, and repeatable post-victory optimization targets.
- Extend progression past the current short ladder with more tech tiers, more intermediate parts, and stronger late-game reasons to keep expanding after electric mining/logistics.
- Add fair defense tools to match factory pressure: turret-like machines, wall repair loops, pressure reducers, alert UI, and tests proving raids stay deterministic.
- Add deeper factory tools only after the current loop is polished: underground belts, richer filters, richer circuit network behavior, larger fluid constraints, carts/trains, or larger logistic-network constraints.
- Make exploration pay off mechanically: rift-only resources, contracts that require remote outposts, and archive secrets that alter factory planning instead of only increasing ore density.

## Testing Strategy

Tests should sell the systems quality:

- Terrain generation is deterministic by seed.
- Registry validation fails loudly for broken content references.
- Save/load round-trips world state.
- A rich persisted-state signature covers player inventory, hotbar, tiles, machine internals, and research across save/load.
- Input replay reproduces the same simulation state.
- Belts preserve item order.
- Inserters never duplicate or delete items except by recipe consumption.
- Machines consume exact inputs and produce exact outputs.
- Power networks produce stable supply/demand results.
- Chunk activation does not change simulation results near active boundaries.
- Cross-chunk ore-to-plate automation is covered by a headless save/load regression at the 31/32 tile boundary.
- `make cpp-benchmark` runs a headless representative factory benchmark without raylib and enforces configurable average and per-machine tick-cost guardrails.
- `make cpp-benchmark-large` runs an 800-machine scaled factory benchmark, `make cpp-benchmark-stress` runs a 4,096-machine stress benchmark, and the same benchmark binary reports average/p95/max tick costs while remaining scalable with `THOTH_BENCHMARK_TICKS`, `THOTH_BENCHMARK_BURNER_LINES`, `THOTH_BENCHMARK_POWERED_LINES`, `THOTH_BENCHMARK_MAX_US_PER_TICK`, and `THOTH_BENCHMARK_MAX_US_PER_MACHINE_TICK`.
- CI runs `make cpp-smoke-window` under Xvfb so the real raylib window path, authored visual atlas load, replay render, HUD draw, and screenshot export are covered outside local manual play.

Local verification on 2026-06-10 passed `make test`, `make cpp-validate-replays`, `make cpp-validate-assets`, `make cpp-benchmark`, and a non-mutating `/tmp` media preview export.

Local verification on 2026-06-11 passed `make test`, `make cpp-validate-replays`, `make cpp-validate-assets`, `/tmp` media preview export, headless app-off CMake build/test, `make cpp-benchmark`, `make cpp-benchmark-large`, and `make cpp-benchmark-stress` after the raylib app shell was split into focused modules. Local `xvfb-run` was unavailable for the window-smoke command; CI still covers that path with Xvfb.

## Main Risks

### Risk: "C++ Minecraft" Becomes Too Large

Mitigation: keep the first game top-down/2.5D. Use block-world mechanics without a full first-person 3D renderer.

### Risk: Factory Simulation Becomes Slow

Mitigation: use chunk activation, compact arrays for belt state, deterministic system order, and benchmark from Phase 2.

### Risk: The Product Feels Like A Tech Demo

Mitigation: include progression, visual feedback, sound, and a complete ore-to-science loop early.

### Risk: Scope Creep From Survival Features

Mitigation: survival pressure should support automation. If a system does not push the player toward building better factories, defer it.

### Risk: Competing Directly With Luanti

Mitigation: do not pitch this as a general voxel engine. Pitch it as a complete automation game written in C++ with readable systems and deterministic tooling.

## Immediate Next Actions

1. Use manual live play after the Xvfb-backed window smoke to validate authored sprite/audio readability in motion and adjust mix issues that only show up interactively.
2. Playtest the new supply-contract and pressure loops for pacing: contract thresholds, pressure cadence, spawn distance, and whether walls/terrain make defense readable.
3. Prototype one matching defense machine before increasing pressure intensity.
4. Keep scaling past the current 4,096-machine stress benchmark and optimize the first bottleneck that appears in larger factories.
5. Add focused tests and benchmarks as new late-game systems land.

## Confidence

This direction is stronger than the Infinifactory-like plan for the stated preference because it turns Thoth into a persistent systems sandbox. The key discipline is to make it Factorio/Minecraft in loop and feel, not in total feature count.
