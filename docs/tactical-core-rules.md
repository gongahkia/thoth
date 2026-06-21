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

## M.2 AP Baseline

Default AP is `2` per active unit unless a fixture/tool explicitly overrides `defaultAp`, `maxAp`, or command cost.

Baseline rules:

- Team-turn model is the default prototype shape.
- Movement spends AP through `moveApCost`; default move cost is `1`.
- Actions spend AP through command cost; current tactical verbs default to `1` unless passed a different explicit cost.
- `wait` costs `0` by default.
- AP spend fails fast when a unit lacks AP.
- AP cannot go negative through core commands.
- Evacuated or defeated units cannot spend AP.
- AP debt is not a core rule. It is reserved for explicit future class/tool mechanics, such as Merchant debt trades.

Acceptance proof:

- `tests/run.lua` verifies 3-unit and 5-unit squads, AP spend isolation, insufficient-AP failure, phase reset behavior, movement AP cost, and inactive-side AP preservation.

## M.3 Movement Preview

Movement preview is deterministic and side-effect free.

Preview output includes:

- Reachable tiles up to the unit's current AP or explicit `maxCost`.
- Per-tile AP cost.
- Per-tile hazard cost.
- Path directions from the starting tile.
- Cover gained and cover lost relative to the starting tile.
- Objective carry impact, including integrity delta from hazardous carry routes.
- Collision records for blocked, occupied, and out-of-bounds candidate moves.

Preview does not mutate unit position, AP, objective state, hazard state, or threat zones.

Acceptance proof:

- `tests/run.lua` verifies reachable AP cost, hazard cost, cover gained/lost, objective carry impact, blocked-tile collision, and occupied-tile collision.
