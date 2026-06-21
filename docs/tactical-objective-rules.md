# Tactical Objective Rules

Checked: 2026-06-21

Source of truth: `src/game/tactics/state.lua`.

## O.1 Protect Objectives

Protect objectives track deterministic integrity.

Kinds:

- `protect_route_machine`
- `protect_route_machinery`
- `protect_enclave_shelter`
- `protect_archive_shelf`
- `protect_civilian_cell`
- `protect_pressure_node`

Rules:

- Protect objectives belong to family `protect`.
- Integrity damage is deterministic.
- Integrity at zero fails the objective.

Acceptance proof:

- `tests/run.lua` verifies every protect kind is accepted and zero integrity fails pressure-node protection.

## O.2 Extract Objectives

Extract objectives and cargo use deterministic carry/extract state.

Objective kinds:

- `extract_record`
- `extract_civilian`
- `extract_body`
- `extract_machine_core`
- `extract_ledger`
- `extract_fuel`
- `extract_medicine`
- `extract_witness`

Cargo kinds:

- `record`
- `civilian`
- `body`
- `machine_core`
- `machinery_core`
- `ledger`
- `fuel`
- `medicine`
- `witness`

Rules:

- Extract objectives belong to family `extract`.
- `extractObjective` completes extraction deterministically.
- Cargo kind controls carry weight; no extraction roll exists.

Acceptance proof:

- `tests/run.lua` verifies all listed cargo kinds, extract objective family, and deterministic extraction completion.

## O.3 Disable Objectives

Disable objectives complete when their target is neutralized.

Kinds:

- `disable_seal`
- `disable_bell`
- `disable_valve`
- `disable_kiln`
- `disable_audit_lens`

Rules:

- Disable objectives belong to family `disable`.
- `disableObjective` marks the objective disabled and complete.
- Disable reason is recorded for result context.

Acceptance proof:

- `tests/run.lua` verifies every disable kind is accepted and disabling an audit lens completes the objective.

## O.4 Repair Objectives

Repair objectives restore deterministic integrity through AP/tool actions.

Kinds:

- `repair_cover`
- `repair_machinery`
- `repair_floodgate`
- `repair_bridge`
- `repair_ward`

Rules:

- Repair objectives belong to family `repair`.
- `repairObjective` spends AP and restores integrity.
- Integrity cannot exceed `maxIntegrity`.

Acceptance proof:

- `tests/run.lua` verifies every repair kind, AP spend, and max-integrity cap.

## O.5 Hold Objectives

Hold objectives require player presence on a claim tile for N ticks.

Kind:

- `hold_claim`

Rules:

- Hold objectives belong to family `hold`.
- A hold tick increments only when an active player unit occupies the claim tile.
- Completion occurs when `heldTurns >= requiredTurns`.
- Hold ticks can escalate active intents via ignored-threat pressure.

Acceptance proof:

- `tests/run.lua` verifies presence ticking, intent escalation, and completion after required turns.

## O.6 Evacuate Objectives

Evacuate objectives require leaving before board collapse.

Kind:

- `evacuate_board`

Rules:

- Evacuate objectives belong to family `evacuate`.
- `minUnits` defines minimum evacuated units.
- `minObjectives` is tracked in evacuation progress for boards that require other objectives first.
- `boardCollapseIn` ticks down deterministically.
- Collapse at zero fails an incomplete evacuation.

Acceptance proof:

- `tests/run.lua` verifies minimum unit evacuation and board-collapse failure carryover.

## O.7 Split-Squad Objectives

Split objectives require simultaneous or distributed switch progress.

Kind:

- `split_switch`

Rules:

- Split objectives belong to family `split`.
- Switches are declared with ids and board tiles.
- Switch dependencies may be hidden until matching rotation.
- Activating all switches completes the objective.

Acceptance proof:

- `tests/run.lua` verifies rotation-hidden dependency preview, switch activation, and completion after all switches are active.

## O.8 Stealth-Read Objectives

Stealth-read objectives require gathering information and leaving under exposure cap.

Kind:

- `stealth_read`

Rules:

- Stealth objectives belong to family `stealth`.
- `requiredReads` defines information required.
- `exposureCap` fails the objective when exceeded before reading.
- Completion requires enough reads and required evacuation.

Acceptance proof:

- `tests/run.lua` verifies read progress, evacuation completion, and exposure-cap failure.
