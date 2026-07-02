[![](https://img.shields.io/badge/thoth_1.0-passing-dark_green)](https://github.com/gongahkia/thoth/releases/tag/1.0)
![](https://github.com/gongahkia/thoth/actions/workflows/ci.yml/badge.svg)
![](https://github.com/gongahkia/thoth/actions/workflows/release-build.yml/badge.svg)

# `Thoth`

Infinite walking simulator in a 
[procedurally generated world](#terrain-generation-techniques) written in [LÖVE2D](https://love2d.org/).

## Stack

* *Scripting*: [Lua](https://www.lua.org/), [LÖVE2D](https://love2d.org/)
* *Test*: 

## Assets

* *Font*: [BigBlue Terminal](https://int10h.org/blog/2015/12/bigblue-terminal-oldschool-fixed-width-font/)
* *Sprites*: [Custom billboard texture atlas](./assets/billboards.png)

## Screenshots / GIFs

...

## Usage

The below commands are for locally running `Thoth`.

1. First install `Thoth` on your current machine.

```console
$ git clone https://github.com/gongahkia/thoth && cd thoth
```

2. Then run any of the below to start `Thoth`.

```console
make run
```

3. Finally, optionally execute the below to interact with `Thoth`'s functionality.

```console
make test
make smoke
make diagnostics
make regressions
make benchmark
make bench
make bench-update
make render-smoke
make walk-smoke
make export-smoke
```


Controls:

- `WASD`: walk / strafe
- `Shift`: sprint
- mouse or `E` / left arrow: look
- arrow up/down: pitch
- `F`: toggle mouse look
- `B`: toggle all debug panels
- `1` / `2` / `3` / `4`: toggle plate / drainage / erosion / biome overlay
- `5`: toggle topographic map overlay
- `T`: toggle debug topographic map
- `M`: toggle minimap
- `N`: mark surveyed terrain
- `F5` / `F9`: save / load
- `Q` / `Esc`: quit
- `R`: new seed

## Nerd stuff 

### Terrain generation techniques

...

Pseudo-3D terrain exploration prototype in LÖVE. The focus is deterministic terrain generation in a procedurally generated world, then plate age, subduction, rifts, island arcs, shields/cratons, uplift, rainfall, bounded regional hydrology, grouped lake fill/spillover, erosion, depositional landforms, rivers, biome colors, and dense terrain mesh inspection.

Rendering pipeline: OpenSimplex2 noise + iterative stream-power and glacial erosion drive a heightfield that's drawn via geometry-clipmap terrain tiles + persistent streamed meshes + per-cell sun-direction lighting. A low-resolution canvas + palette-quantization post-process and pixel sprite billboards provide the Proteus-style look. Atmosphere cycles tint the palette and drive sun direction across dawn/noon/dusk/night. An async hydrology worker (`--no-async` to disable) keeps Priority-Flood + D8 routing off the render thread.

### Performance optimisation

Hydrology uses cached chunk regions, a coarse cached basin pass, Priority-Flood-style depression filling, D8 downstream routing, rainfall accumulation, basin/watershed ids, lake surfaces, and seam/uphill diagnostics. The generator default is 2x2 detail regions with an 8-cell halo plus 8-chunk basins at 4-cell stride; the interactive runtime defaults to `--hydrology-region-chunks 1 --hydrology-halo 0 --hydrology-basin-chunks 8 --hydrology-basin-stride 8` to keep first render bounded while preserving larger river corridors.

Sampled cells expose basin, watershed, ridge, and mountain-range ids for discovery labels and debug overlays.
`WorldGen:discoveriesAt(x, y, scale)` returns deterministic names for mountain ranges, watersheds, basins, coasts, ridges, passes, and rain shadows.
World scope is fixed at generation with `--scope local|region|continent`.
Press `M` to mark the current sampled cell and discovered terrain ids in the in-memory survey history.

Tests include a terrain-first guard that rejects runtime ruins, lore, quests, collectibles, combat, or survival systems until landform generation is coherent.

Runtime performance logging:

```sh
love . --skip-menu
love . --debug-perf
love . --walk-smoke --walk-smoke-frames 240 --perf-interval 0.5
love . --preload-radius 128 --refresh-preload-radius 96
love . --cache-max-entries 512
love . --hydrology-region-chunks 2 --hydrology-halo 8
love . --hydrology-basin-chunks 8 --hydrology-basin-stride 4
love . --export-map dist/map --export-size 128
love . --save-path thoth-save.json --load-save thoth-save.json
love . --scope continent
love . --geologic-time 0.5
love . --pixel-scale 2 --time-of-day 0.25 --season summer --day-length 60
love . --no-async
```

`love .` opens the title menu. Use `--skip-menu` to launch directly into the current default world.
Settings persist to `settings.json` in the LOVE save directory; deleting it restores defaults.

`--geologic-time` drifts every plate along its velocity vector (clamped via tanh below 80% of half plate-cell, so plates never collide). `0` keeps the static contract; the `(seed, geologicTime)` pair is the new determinism contract.

`--pixel-scale` controls the low-resolution canvas downsample (2, 3, or 4); palette quantization snaps the result to a 32-color biome palette swapped per active view scope. `--time-of-day`, `--season`, and `--day-length` configure the atmosphere day cycle that drives both palette tint and sun direction for terrain lighting; press `[` / `]` in-game to step seasons. `--no-async` runs hydrology on the render thread (useful when debugging determinism).

`make bench` runs the headless terrain benchmark and gates against `tests/bench.baseline.json`; `make bench-update` rewrites the baseline. Non-zero exit on regressions below tolerance (50% in the default `make bench`; 10% for direct `--baseline-tolerance` runs per CI gating). The `bench-baseline` artifact is uploaded by the CI workflow.

`--debug-perf` prints FPS, raw/clamped dt, update/draw/preload ms, position, visible/preloaded chunks, bounded cache counts, cache hits/misses/evictions, terrain/basin cache misses, and hydrology cell counts. Press `L` in-game to toggle it. `--debug-topo` starts with the optional topographic debug map open; press `T` to toggle it. `M` toggles the minimap; `N` marks surveyed terrain. `--debug-panels` starts with plate, drainage, erosion, and biome debug panels open; press `B` to toggle them. `--export-map <prefix>` writes `<prefix>.png` plus seed/scale metadata JSON. New worlds save into the LOVE save directory under `worlds/` with PNG thumbnails; `F5` updates the active world slot and `F9` reloads it. `--save-path` / `--load-save` still support legacy single-file saves. Runtime movement clamps simulation dt to reduce jitter after slow terrain loads.

Runtime initial preload defaults to 64 cells and refresh preload defaults to 72 cells; raise them when you prefer fewer walking stalls over faster first render.

Biome entry banners use BigBlue Terminal by VileR, bundled under CC BY-SA 4.0 in `assets/fonts/`.

Terrain diagnostics:

```sh
make diagnostics
luajit tests/run.lua --diagnostics --seed-start 1 --seed-count 32
luajit tests/run.lua --diagnostics --seeds 1,42,99,20260625 --chunk-radius 2 --sample-step 8
luajit tests/run.lua --regressions
luajit tests/bench.lua --chunk-radius 1 --scales local,region,continent
```

Diagnostics report land/water/river/lake/slope/biome ratios, seam mismatches, and uphill drainage rejects. Fixture sweeps cover ten regression categories: ugly_terrain, all_water, all_land, riverless, single_biome, biome_count_low, steep_slopes, drowned_basin, broken_seams, and river_discontinuities. Bounds are broad Earth-inspired calibration gates, not strict geoscience targets.

### Benchmarks

...

## Research

...

## References

Visually, `Thoth` takes a lot of reference from the 2013 game [Proteus](https://store.steampowered.com/app/219680/Proteus/).

<div align="center">
    <img src="./assets/reference/proteus.jpg" width="65%">
</div>
