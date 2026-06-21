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

## I.2 Category Intent

Category intent exposes only threat type when exact footprint is not knowable yet.

Supported categories:

- `attack`
- `move`
- `guard`
- `summon`
- `repair`
- `destroy`
- `buff`
- `debuff`
- `flee`
- `redacted`

Rules:

- Category intent must use one of the supported categories.
- Preview marks category intent as `categoryOnly`.
- Preview withholds target tiles and path even if private target tiles were stored.

Acceptance proof:

- `tests/run.lua` verifies all supported categories are accepted and previewed without footprint disclosure.
