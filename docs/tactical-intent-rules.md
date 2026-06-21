# Tactical Intent Rules

Checked: 2026-06-21

Source of truth: `src/game/tactics/state.lua`.

## I.1 Exact Intent

Exact intent is a fully previewable enemy promise.

Fields:

- `source`: source unit id.
- `sourceTile`: source tile at declaration.
- `targetTiles`: exact affected tiles.
- `path`: exact path or trace.
- `damage`: deterministic damage value.
- `effect`: deterministic effect label.
- `collision`: deterministic collision payload.
- `objectiveImpact`: objective affected by the intent.

Rules:

- Exact intent must include at least one target tile.
- Missing source tile is filled from the source unit position at declaration.
- Preview exposes source tile, target tiles, path, damage, effect, collision, and objective impact.

Acceptance proof:

- `tests/run.lua` verifies exact intent source tile, path, target footprint, damage/effect, collision, and objective impact preview.
