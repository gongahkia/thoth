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
