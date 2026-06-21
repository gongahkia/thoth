# Tactical LoS And Cover Rules

Checked: 2026-06-21

Source of truth: `src/game/tactics/state.lua`.

## L.1 Directional Cover

Cover is stored on tile edges.

Edge values:

- `none`: no mitigation.
- `half`: deterministic damage reduction of 1.
- `full`: blocks direct attack from that edge.

Rules:

- Attack direction is derived from attacker tile to target tile.
- The target tile edge facing the attacker determines cover.
- Cover never changes hit chance; it only reduces damage or blocks direct attack.

Acceptance proof:

- `tests/run.lua` verifies half cover, full cover, and uncovered attack vectors.

## L.2 Blocker Kinds

Blocker kind describes movement and LoS behavior.

Kinds:

- `hard`: blocks movement and LoS.
- `low`: blocks movement, not LoS.
- `transparent`: blocks movement, not LoS.
- `destructible`: blocks movement and LoS until HP reaches zero.

Rules:

- Explicit `blockerKind` sets default movement and LoS booleans.
- Explicit `blocker` or `losBlocker` booleans can override kind defaults.
- Destructible blockers expose HP.
- Destroyed blockers become `none`, clear movement/LoS blockers, and clear cover.

Acceptance proof:

- `tests/run.lua` verifies hard, low, transparent, and destructible blockers plus destruction cleanup.

## L.3 Flanking

Flanking is deterministic cover invalidation from attack vector.

Rules:

- Attack direction is derived from attacker tile to target tile.
- If the target has any cover but not on the attacked edge, the target is flanked.
- Flanking invalidates existing cover for that attack only.
- Flanking does not use hit chance math.

Acceptance proof:

- `tests/run.lua` verifies covered attacks do not flank and uncovered attack vectors invalidate existing cover.
