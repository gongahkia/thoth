# Thoth

Pseudo-3D terrain exploration prototype in LÖVE. The focus is deterministic terrain generation: plate age, subduction, rifts, island arcs, shields/cratons, uplift, rainfall, bounded regional hydrology, lake fill/spillover, erosion, depositional landforms, rivers, and biomes.

## Development

```sh
make test
make smoke
make diagnostics
make render-smoke
make walk-smoke
make run
```

Hydrology uses cached chunk regions, a coarse cached basin pass, Priority-Flood-style depression filling, D8 downstream routing, rainfall accumulation, basin/watershed ids, lake surfaces, and seam/uphill diagnostics. The generator default is 2x2 detail regions with an 8-cell halo plus 8-chunk basins at 4-cell stride; the interactive runtime defaults to `--hydrology-region-chunks 1 --hydrology-halo 0 --hydrology-basin-chunks 8 --hydrology-basin-stride 8` to keep first render bounded while preserving larger river corridors.

Runtime performance logging:

```sh
love . --debug-perf
love . --walk-smoke --walk-smoke-frames 240 --perf-interval 0.5
love . --preload-radius 128 --refresh-preload-radius 96
love . --hydrology-region-chunks 2 --hydrology-halo 8
love . --hydrology-basin-chunks 8 --hydrology-basin-stride 4
```

`--debug-perf` prints FPS, raw/clamped dt, update/draw/preload ms, position, visible/preloaded chunks, cache counts, terrain/basin cache misses, and hydrology cell counts. Press `L` in-game to toggle it. Runtime movement clamps simulation dt to reduce jitter after slow terrain loads.

Runtime initial preload defaults to 64 cells and refresh preload defaults to 72 cells; raise them when you prefer fewer walking stalls over faster first render.

Terrain diagnostics:

```sh
make diagnostics
luajit tests/run.lua --diagnostics --seed-start 1 --seed-count 32
luajit tests/run.lua --diagnostics --seeds 1,42,99,20260625 --chunk-radius 2 --sample-step 8
```

Diagnostics report land/water/river/lake/slope/biome ratios and fail fixture sweeps on extreme all-water/all-land, riverless, over-lake, over-steep, or single-biome seeds. Bounds are intentionally broad; they are sanity gates, not Earth calibration.

Controls:

- `WASD`: walk / strafe
- `Shift`: sprint
- mouse or `Q` / `E`: look
- arrow up/down: pitch
- `F`: toggle mouse look
- `R`: new seed
