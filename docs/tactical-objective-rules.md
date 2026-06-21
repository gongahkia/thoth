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
