# Thoth

Pseudo-3D terrain exploration prototype in LÖVE. The focus is deterministic terrain generation: plates, uplift, rainfall, bounded regional hydrology, lake fill/spillover, erosion, rivers, and biomes.

## Development

```sh
make test
make smoke
make render-smoke
make walk-smoke
make run
```

Hydrology uses cached chunk regions, Priority-Flood-style depression filling, D8 downstream routing, rainfall accumulation, basin/watershed ids, lake surfaces, and seam/uphill diagnostics. The generator default is 2x2 regions with an 8-cell halo; the interactive runtime defaults to `--hydrology-region-chunks 1 --hydrology-halo 0` to reduce walking stalls.

Runtime performance logging:

```sh
love . --debug-perf
love . --walk-smoke --walk-smoke-frames 240 --perf-interval 0.5
love . --preload-radius 128 --refresh-preload-radius 96
love . --hydrology-region-chunks 2 --hydrology-halo 8
```

`--debug-perf` prints FPS, raw/clamped dt, update/draw/preload ms, position, visible/preloaded chunks, cache counts, and terrain cache misses. Press `L` in-game to toggle it. Runtime movement clamps simulation dt to reduce jitter after slow terrain loads.

Controls:

- `WASD`: walk / strafe
- `Shift`: sprint
- mouse or `Q` / `E`: look
- arrow up/down: pitch
- `F`: toggle mouse look
- `R`: new seed
