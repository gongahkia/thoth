# Build a real showcase example game for `thoth`

## Summary

The current examples only wire the same movement scene into multiple engines. Ship a small but complete showcase game that demonstrates why the runtime exists and exercises the modules that now define the library's direction.

## Scope

- Design a compact example that uses state management, input contexts, pathfinding, spatial queries, and runtime systems.
- Prefer a structure that keeps core gameplay logic shared and engine-specific wiring thin.
- Include a debug mode that demonstrates observability features.
- Add documentation for running the example in at least one supported engine.
- Use the example as a future regression target for deterministic replay.

## Acceptance criteria

- The repository contains a playable showcase example rather than only the movement demo.
- The example uses multiple `thoth.game` modules together in a realistic way.
- The example has at least one automated smoke or replay-based test.
- README references the showcase as the primary example.

## Depends on

- Deterministic runtime workstreams.
- Capability-based adapter contract.
- Observability support.
