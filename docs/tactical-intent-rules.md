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

## I.3 Redacted Footprint Intent

Redacted footprint intent exposes category while withholding exact affected tiles.

Reveal gates:

- explicit reveal flag
- matching camera rotation
- matching class reveal
- matching reveal action

Rules:

- Hidden-footprint intent must store at least one private target tile.
- Default preview exposes category and marks `footprintHidden`.
- Default preview withholds target tiles and path.
- Matching reveal gates expose the stored footprint without changing the authored intent.

Acceptance proof:

- `tests/run.lua` verifies category-visible redaction, nonmatching rotation hiding, explicit reveal, matching rotation reveal, and class/action reveal.

## I.4 Delayed Fuse Intent

Delayed fuse intent exposes a countdown anchored to a tile, object, objective, unit, or enemy.

Fields:

- `countdown`: deterministic turns/ticks before trigger.
- `anchor`: visible countdown anchor.
- `targetTiles`: exact affected tiles when tile-based.
- `trigger`: deterministic result payload.

Trigger kinds:

- `damage`: damages target unit, tile occupants, objectives, and cargo on target tiles.
- `damageObjective`: damages a named objective.
- `convertTile`: applies a deterministic terrain conversion to target tiles.
- `status`: applies a deterministic status to a named unit.

Rules:

- Fuse countdown must be non-negative.
- Fuse preview always exposes countdown, anchor, trigger, and target tiles.
- Ticking a fuse decrements countdown without side effects until it reaches zero.
- A zero-count fuse resolves once, applies its deterministic trigger, and removes the intent.

Acceptance proof:

- `tests/run.lua` verifies tile, object, and enemy anchors, visible countdown, delayed trigger, deterministic damage/status effects, and snapshot stability.

## I.5 Conditional Intent

Conditional intent declares multiple visible branches and resolves the first true branch.

Supported conditions:

- `targetMoved`: target unit left its declaration tile.
- `targetOnTile`: target unit is on a declared tile.
- `otherwise`: fallback branch.

Rules:

- Conditional intent must include at least two branches.
- Conditional intent must include an `otherwise` branch.
- `targetMoved` records the target source tile when intent is declared.
- Preview exposes all branches, conditions, and deterministic branch payloads.
- Resolution selects the first true condition, applies its deterministic trigger, and removes the intent.

Acceptance proof:

- `tests/run.lua` verifies `targetMoved`/`otherwise` branch preview, repair fallback, movement-triggered attack branch, and snapshot stability.

## I.6 Interrupt Rules

Interrupts are deterministic counters to declared intent.

Supported interrupts:

- `stun`: cancels intent and applies `stunned`.
- `shove`: moves the source and cancels intent.
- `losBreak`: cancels intent after line break.
- `coverRaise`: raises cover and cancels intent.
- `seal`: cancels intent and applies `sealed`.
- `hack`: cancels intent.
- `douse`: clears a burning hazard and cancels intent.
- `drain`: drains a flood tile and cancels intent.
- `exposeWeakPoint`: reveals masked/redacted intent without cancelling it.

Rules:

- Interrupt kind must be supported.
- Cancelling interrupts remove the declared intent.
- Expose-weak-point keeps the intent active and reveals the footprint.
- Interrupt commands are logged and replayable.

Acceptance proof:

- `tests/run.lua` verifies all supported interrupt kinds, side effects, prevention, weak-point reveal, and snapshot stability.
