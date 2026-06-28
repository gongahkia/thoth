# Thoth

Pseudo-3D terrain exploration prototype in LÖVE. The focus is deterministic terrain generation in a procedurally generated world, then plate age, subduction, rifts, island arcs, shields/cratons, uplift, rainfall, bounded regional hydrology, grouped lake fill/spillover, erosion, depositional landforms, rivers, biome colors, and dense terrain mesh inspection.

## Development

```sh
make test
make smoke
make diagnostics
make regressions
make benchmark
make render-smoke
make walk-smoke
make export-smoke
make run
```

Hydrology uses cached chunk regions, a coarse cached basin pass, Priority-Flood-style depression filling, D8 downstream routing, rainfall accumulation, basin/watershed ids, lake surfaces, and seam/uphill diagnostics. The generator default is 2x2 detail regions with an 8-cell halo plus 8-chunk basins at 4-cell stride; the interactive runtime defaults to `--hydrology-region-chunks 1 --hydrology-halo 0 --hydrology-basin-chunks 8 --hydrology-basin-stride 8` to keep first render bounded while preserving larger river corridors.

Sampled cells expose basin, watershed, ridge, and mountain-range ids for discovery labels and debug overlays.
`WorldGen:discoveriesAt(x, y, scale)` returns deterministic names for mountain ranges, watersheds, basins, coasts, ridges, passes, and rain shadows.
Press `Tab` to follow the current terrain label from local to region to continent scope while keeping sampled labels cached.
Press `M` to mark the current sampled cell and discovered terrain ids in the in-memory survey history.

Tests include a terrain-first guard that rejects runtime ruins, lore, quests, collectibles, combat, or survival systems until landform generation is coherent.

Runtime performance logging:

```sh
love . --debug-perf
love . --walk-smoke --walk-smoke-frames 240 --perf-interval 0.5
love . --preload-radius 128 --refresh-preload-radius 96
love . --cache-max-entries 512
love . --hydrology-region-chunks 2 --hydrology-halo 8
love . --hydrology-basin-chunks 8 --hydrology-basin-stride 4
love . --export-map dist/map --export-size 128
love . --save-path thoth-save.json --load-save thoth-save.json
```

`--debug-perf` prints FPS, raw/clamped dt, update/draw/preload ms, position, visible/preloaded chunks, bounded cache counts, cache hits/misses/evictions, terrain/basin cache misses, and hydrology cell counts. Press `L` in-game to toggle it. `--debug-topo` starts with the optional topographic debug map open; press `T` to toggle it. `--debug-panels` starts with plate, drainage, erosion, and biome debug panels open; press `B` to toggle them. `--export-map <prefix>` writes `<prefix>.png` plus seed/scale metadata JSON. `F5` saves seed, player, survey annotations, and display settings; `F9` loads `--save-path`. Runtime movement clamps simulation dt to reduce jitter after slow terrain loads.

Runtime initial preload defaults to 64 cells and refresh preload defaults to 72 cells; raise them when you prefer fewer walking stalls over faster first render.

Terrain diagnostics:

```sh
make diagnostics
luajit tests/run.lua --diagnostics --seed-start 1 --seed-count 32
luajit tests/run.lua --diagnostics --seeds 1,42,99,20260625 --chunk-radius 2 --sample-step 8
luajit tests/run.lua --regressions
luajit tests/run.lua --benchmark --chunk-radius 1 --scales local,region,continent
```

Diagnostics report land/water/river/lake/slope/biome ratios, seam mismatches, and uphill drainage rejects. Fixture sweeps cover ugly terrain, all-water/all-land, riverless, over-lake, over-steep, single-biome, seam, and river-continuity regressions. Bounds are broad Earth-inspired calibration gates, not strict geoscience targets.

Controls:

- `WASD`: walk / strafe
- `Shift`: sprint
- mouse or `Q` / `E`: look
- arrow up/down: pitch
- `F`: toggle mouse look
- `B`: toggle debug panels
- `T`: toggle debug topographic map
- `F5` / `F9`: save / load
- `Tab`: follow terrain scope
- `M`: mark surveyed terrain
- `R`: new seed
