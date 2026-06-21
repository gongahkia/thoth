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
