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
- No direct feature-parity requirement with the previous prototype.
- Tests are the first quality gate; formatter/linter adoption waits until tools are installed or vendored.

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

## Phase 8: Next Product Work

- Tighten first 10 minutes: visible starter goal, readable resource locations, fewer hidden assumptions.
- Add build menu UI instead of hotkey-only crafting.
- Add explicit machine panel for recipe selection, deposit/withdraw, status, and progress.
- Add copper automation to the default player-facing progression.
- Add authored Lua-native replays for starter factory and science.
- Add screenshot/render smoke once CI has stable headless LOVE graphics support.
- Re-evaluate late C++ prototype systems only after the starter loop is fun and testable.
