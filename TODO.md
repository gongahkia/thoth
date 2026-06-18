# Thoth Lua/LOVE Reboot Todo

## Current Repo State

- Previous state was C++17/raylib: deterministic core in `include/thoth` and `src/thoth`, raylib shell in `src/app`, tests in `tests/test_world.cpp`, benchmark in `benchmarks/`.
- Verified before reboot: `make test` passed with `1/1` suite in `115.05s`; one existing non-fatal unused lambda-capture warning.
- Local target runtime verified: `LOVE 11.5`, `Luajit 2.1`; `stylua`, `luacheck`, and `luarocks` were not installed.
- Known old asset mismatch: sprite README claimed `128x64`, tracked atlas was `128x80`.
- C++/raylib source, CMake build, old tests, old replay artifacts, old preview artifacts, authored `.art`/`.sfx` sources, and tracked local profile state were removed.

## Reboot Target

- Hard reboot in Lua/LOVE 11.5.
- No C++ compatibility layer.
- Current roadmap targets full gameplay/system parity with the previous C++ prototype.
- Tests are the first quality gate; formatter/linter adoption waits until tools are installed or vendored.

## Research Basis

- Factorio validates the core automation pillars: mining, logistics, power, research, blueprints, circuits, pollution/defense, and a clear endpoint.
- Mindustry validates factory plus wave-defense readability.
- shapez 2 validates visible production goals, debugging, blueprints, and low-friction building.
- Core Keeper validates biome, boss, resource, and exploration loops.
- The Riftbreaker validates base-building, defense, exploration, and outpost escalation.

## Parity Policy

- Target full old C++ gameplay/system parity, using commit `0b7fff6` as the reference.
- Do not port C++ file layout, class shapes, or API names unless they fit the Lua codebase.
- Keep Lua implementation data-driven and headless-testable.
- Prefer Lua-native optimized structures over direct C++ class ports.
- UI/playability work still precedes late-game parity because the old C++ prototype was feature-rich but still rough.

## Phase 1: Repository Reset

- Done:
  - Remove `CMakeLists.txt`, `include/`, `src/`, `tests/test_world.cpp`, `benchmarks/`, old replay/preview artifacts, and tracked `thoth_profile.txt`.
  - Keep reusable runtime assets: `assets/sprites/thoth_atlas.png` and `assets/audio/*.wav`.
  - Replace C++ CI with Lua/LOVE CI.
- Acceptance:
  - `rg --files` shows no C++ source/header/test/benchmark paths.
  - `make test` no longer invokes CMake.

## Phase 2: Minimal LOVE Shell

- Done:
  - Add `main.lua` with LOVE callbacks and a fixed 60 Hz simulation step.
  - Add `conf.lua` with `identity = "thoth"`, 1280x720 default window, and unused modules disabled.
  - Add app modules for input, rendering, and audio.
- Acceptance:
  - `make run` launches the LOVE app locally.
  - `make smoke` opens LOVE and exits after a few frames.
  - `F5`/`F9` save/load through `love.filesystem`.

## Phase 3: Deterministic Simulation MVP

- Done:
  - Add deterministic RNG/hash helpers.
  - Add seeded world generation with starter trees, stone, coal, iron, and copper.
  - Add player movement, facing, mining, inventory, hotbar, crafting, placement, and deposit commands.
  - Add machine state and deterministic tick updates.
- Acceptance:
  - Same seed plus same command sequence produces identical snapshots.
  - Mining and crafting tests pass headlessly under Luajit.

## Phase 4: Starter Factory Loop

- Done:
  - Add workbench, burner miner, belt, fast belt, inserter, furnace, chest, assembler, and lab.
  - Add ore-to-plate production through miner, belt, inserter, furnace, and chest.
  - Add minimal science pack and Logistics 1 research unlock for fast belts.
- Acceptance:
  - Headless factory test produces at least one iron plate in a chest.
  - Headless research test unlocks `fast_belt`.

## Phase 5: Save/Replay

- Done:
  - Add deterministic snapshot serialization.
  - Add plain Lua save/load text format.
  - Add replay text format and replay runner.
- Acceptance:
  - Save/load round trip preserves snapshots.
  - Replay final snapshot equals direct simulation final snapshot.

## Phase 6: Assets/UI

- Done:
  - Load retained PNG atlas where available.
  - Load retained WAV cues where available.
  - Draw world, machines, player, faced tile highlight, HUD, and hotbar.
  - Add asset sanity checks for PNG/WAV headers.
- Acceptance:
  - `make check` passes.
  - Missing optional audio cue does not crash runtime.

## Phase 7: Build/CI/Package

- Done:
  - Replace `Makefile` with `run`, `test`, `check`, `package`, and `clean`.
  - Replace GitHub Actions workflow with Luajit/LOVE/zip setup.
  - Add `.love` package target with archive integrity test.
- Acceptance:
  - `make test` passes.
  - `make check` passes.
  - `make package` creates `dist/thoth.love` with `main.lua`, `conf.lua`, `src/`, and `assets/` at archive root.

## Phase 8: Playable UI Foundation

- Acceptance:
  - Player can build ore-to-science without README or memorized hotkeys.
  - `make check` still passes.
  - `make smoke` still exits cleanly.

## Phase 11: Progression And Contracts

- Add Lua-native replay fixtures:
  - Ore-to-plate.
  - Science/research.
  - Full-flow.
- Acceptance:
  - Replay validation reaches old visible milestones: iron, copper, science, power, logistics, archive/rift prep.
  - Save/load preserves contract, tech, achievement, tutorial, and dashboard state.

## Phase 12: World, Biomes, And Exploration

- Restore deterministic chunked terrain.
- Restore biome selection:
  - Grassland.
  - Desert.
  - Snowfield.
  - Marsh.
  - Badlands.
  - Crystal field.
  - Rift.
- Restore finite richer ore farther from spawn.
- Restore authored lairs:
  - Marsh Hive.
  - Glass Spire.
  - Badlands Foundry.
  - Frost Vault.
  - Crystal Vault.
- Restore seeded procedural lairs beyond the starter ring.
- Restore exploration systems:
  - Boat traversal.
  - Stairs and layers.
  - Dungeon/lair interiors.
  - Biome materials.
  - Biome caches.
  - Lair hearths.
  - Recovery crates.
- Add Lua-native chunk cache:
  - Cache chunks by `z:cx:cy`.
  - Snapshot only loaded/modified tiles.
  - Keep generation deterministic from seed and coordinates.
- Acceptance:
  - Tests cover deterministic chunks, chunk boundary mutation, starter resources, early biome tiles, biome/lair generation, generated lairs, lair cache persistence, boat traversal, stairs/layers, and dungeon save/load.

## Phase 13: Combat, Bosses, Relics

- Restore entities:
  - Player HP.
  - Entity HP.
  - Entity attack cooldowns.
  - Hostile pathing toward player or infrastructure.
  - Local biome enemy spawns.
- Restore boss ladder:
  - Marsh Broodheart.
  - Glass Maw.
  - Badlands Warden.
  - Frost Nullifier.
  - Rift Signal Tyrant.
- Restore summon gates:
  - Biome/lair location requirements.
  - Factory-output exam requirements.
  - Item costs.
  - Archive/rift requirements for rift boss.
- Restore rewards:
  - Boss relic drops.
  - Factory-relevant support-machine unlocks.
  - Relic socketing and persistence.
- Acceptance:
  - Tests cover entity combat, entity save/load, boss summon requirements, boss phase behavior, reward persistence, boss relic claiming, and relic-socketed machines.

## Phase 14: Pressure, Defense, Outposts

- Restore factory pressure:
  - Pressure score from production and factory footprint.
  - Pressure hotspots.
  - Wave alerts.
  - Deterministic hostile probe spawns.
  - Pressure rewards.
- Restore defense systems:
  - Guard tower targeting.
  - Arc tower targeting.
  - Ammo-fed stronger shots.
  - Wall and structure damage.
  - Repair pylon wall/structure repair.
  - Pressure relay mitigation.
- Restore outposts:
  - Outpost beacons.
  - Biome-specific input consumption.
  - Sustained delivery windows.
  - Route stability.
  - Local-biome scouting.
  - Route-bonus materials and fragments.
- Acceptance:
  - Tests cover pressure wave spawn/reward, pressure hotspot map, tower targeting, structure damage, repair pylon effects, pressure relay effects, outpost activation, outpost delivery contracts, stable outpost routes, local-biome scouting, and scout rewards.

## Phase 15: Archive, Rift, Post-Victory

- Restore archive systems:
  - Powered archive terminal charging.
  - Beacon core consumption.
  - Archive fragment alternate recipes.
  - Archive choice UI/data.
- Restore rift systems:
  - Rift gate construction and charging.
  - Rift outer band travel.
  - Richer rift resources.
  - Rift storms and storm modifiers.
- Restore post-victory expedition board:
  - Scouting.
  - Boss relics.
  - Rift storms.
  - Stable outpost routes.
  - Pressure rewards.
  - Lair caches.
  - Train freight.
  - Scrap recycling.
  - Powered mining.
- Acceptance:
  - Tests cover archive charging, archive unlocks, rift travel, rift storm effects, outer band resources, post-victory board progress, and save/load persistence.

## Phase 16: Planning, Construction, Performance

- Restore planning mode:
  - Toggle planning mode.
  - Ghost builds.
  - Cancel ghosts.
  - Invalid-reason labels.
  - No material consumption while planning.
- Restore construction:
  - Drone construction jobs.
  - Provider-source material pickup.
  - Port-powered delivery requirement.
  - Ghost fulfillment state.
- Add Lua-native performance guardrails:
  - Mixed-factory benchmark target.
  - Larger scaled benchmark target.
  - Avoid per-tick global scans.
  - Use deterministic id ordering for same-tick jobs.
  - Track production counters by event increments, not derived full scans.
- Add render/CI checks:
  - Package contents test.
  - Optional screenshot/render smoke once CI display support is stable.
- Acceptance:
  - `make check` includes simulation tests, replay tests, registry tests, asset checks, package checks, and benchmark smoke.
  - Benchmark output reports ticks, machine count, elapsed time, average tick cost, and max tick cost.
  - Construction ghosts persist across save/load.

## Lua-Native Implementation Notes

- Use table-driven registries in `src/game/defs.lua`; split large content into `src/game/data/*.lua` once tables grow.
- Maintain machine spatial index keyed by `z:x:y`; rebuild only on placement/removal/load.
- Keep command queue and fixed tick deterministic; sort ids before resolving same-tick jobs.
- Store production counters as event increments, not derived full scans.
- Add focused test files by subsystem rather than one huge `tests/run.lua`.
- Keep LOVE-only APIs out of simulation modules so headless Luajit tests remain fast.
- Use plain Lua data serialization until save format pressure justifies a stricter parser.
