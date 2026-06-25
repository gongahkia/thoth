# Thoth

Pseudo-3D terrain exploration prototype in LÖVE. The focus is deterministic terrain generation: plates, uplift, rainfall, bounded regional hydrology, lake fill/spillover, erosion, rivers, and biomes.

## Development

```sh
make test
make smoke
make render-smoke
make run
```

Hydrology currently uses cached 2x2 chunk regions with an 8-cell halo, Priority-Flood-style depression filling, D8 downstream routing, rainfall accumulation, basin/watershed ids, lake surfaces, and seam/uphill diagnostics.

Controls:

- `WASD`: walk / strafe
- `Shift`: sprint
- mouse or `Q` / `E`: look
- arrow up/down: pitch
- `F`: toggle mouse look
- `R`: new seed
