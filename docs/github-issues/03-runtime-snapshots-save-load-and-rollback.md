# Add runtime snapshots, save/load hooks, and rollback-friendly helpers

## Summary

To support deterministic debugging, save systems, and rollback workflows, the runtime needs a formal snapshot and restore contract. Add snapshot APIs for runtime-owned services and opt-in hooks for systems and states, then layer save/load and rollback helpers on top.

## Scope

- Add `runtime:snapshot()` and `runtime:restore(snapshot)`.
- Define opt-in snapshot/restore hooks for systems, current state, tasks, tween timeline, and input manager.
- Add save/load helpers that serialize snapshots through `thoth.core.serialize`.
- Add rollback helpers that restore a snapshot and replay a frame log from that point.
- Version the snapshot format so future migrations are manageable.

## Acceptance criteria

- Runtime snapshots capture enough state to reproduce a headless run from a prior frame.
- Save/load hooks work without relying on adapter-specific globals.
- Rollback helpers can restore an earlier frame and replay subsequent recorded inputs.
- Tests cover snapshot fidelity, save/load round-trips, and rollback replay.

## Depends on

- Deterministic runtime foundation.
- Input recording and replay.
