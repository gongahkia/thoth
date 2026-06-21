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

## L.4 Height Effects

Height modifies LoS and cover deterministically.

Rules:

- LoS blockers stop sight only when blocker height reaches the higher of source and target height.
- High ground can see over lower LoS blockers.
- High ground of 2 or more ignores half cover.
- Attacking uphill by 2 or more adds 1 deterministic damage reduction.
- Height never changes hit chance.

Acceptance proof:

- `tests/run.lua` verifies high-ground sight over low blockers, high-ground half-cover ignore, high blockers stopping LoS, and uphill damage reduction.

## L.5 Obscurant LoS Modifiers

Smoke, salt mist, and ash cloud are visible LoS modifiers with countdowns.

Kinds:

- `smoke`
- `salt_mist`
- `ash_cloud`

Rules:

- Obscurants are stored as active tile hazards.
- LoS preview reports obscurant modifiers on the traced line.
- Obscurants do not add hit chance; they expose deterministic `obscured` state.
- Countdown ticks are deterministic.
- Expired obscurants clear their LoS modifier.

Acceptance proof:

- `tests/run.lua` verifies all three obscurant kinds, LoS modifier reporting, countdown ticks, and expiry.
