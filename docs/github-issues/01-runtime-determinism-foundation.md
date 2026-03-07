# Create a deterministic runtime foundation for `thoth.game.runtime`

## Summary

`thoth.game.runtime` already has fixed-step scheduling, but it does not yet own the deterministic services needed for reproducible simulation. Introduce runtime-owned seeded RNG, frame metadata, and deterministic helpers so the runtime can become the authoritative source of simulation state.

## Scope

- Add a runtime-owned RNG service with explicit seeding.
- Expose frame index, accumulated fixed-step count, and deterministic timing metadata.
- Make the RNG service available to systems, tasks, states, and examples through the runtime.
- Ensure deterministic services are injectable for headless tests.
- Document which runtime APIs are deterministic and which are adapter- or wall-clock-dependent.

## Acceptance criteria

- `runtime.new(adapter, { seed = 1234 })` produces a reproducible RNG stream.
- Two headless runs with the same seed and the same inputs produce identical state transitions.
- Tests cover seeded RNG behavior and frame metadata updates.
- README and examples show the recommended deterministic usage pattern.

## Primary files

- `thoth/game/runtime.lua`
- `thoth/game/frame.lua`
- `thoth/adapters/contract.lua`
