# Tactical Core Rules

Checked: 2026-06-21

Source of truth: `src/game/tactics/state.lua`. This doc names the current tactical contracts so content work does not infer rules from legacy expedition combat.

## M.1 Tile Schema

Tactical boards are square logical grids. Each tile is addressed by `x:y` and normalizes to these fields:

| Field | Type | Rule |
| --- | --- | --- |
| `kind` | string | Tile identity. Defaults to `floor`. |
| `material` | string | Zone material language such as `archive`, `salt`, or `ember`. |
| `height` | integer | Logical height. Defaults to `0`. |
| `coverEdges` | map | `north/east/south/west`, each `none`, `half`, or `full`. |
| `blocker` | boolean | Blocks movement when true. |
| `losBlocker` | boolean | Blocks line-of-sight logic when true. |
| `destructibleHp` | integer or nil | Damage pool for destructible terrain. |
| `hazard` | map | Hazard payload for deterministic preview/resolution. |
| `objective` | map | Tile-attached objective payload. |
| `revealed` | boolean | Hidden-info state. Defaults to true. |
| `destroyed` | boolean | Persisted state after terrain destruction. |
| `rotationMarks` | map | Direction-keyed facts revealed by camera angle. |
| `tags` | list | Extra deterministic selectors for generators, UI, or tests. |

Destruction rule: when `destructibleHp` reaches zero, the tile keeps identity/history but clears `blocker`, `losBlocker`, and all cover edges, then sets `destroyed = true`.

Acceptance proof:

- `tests/run.lua` verifies schema normalization, nested hazard/objective roundtrip, LoS blockers separate from movement blockers, and destroyed terrain snapshot persistence.
- `docs/tactical-pivot-prototype.md` records the prototype result and current cuts.
