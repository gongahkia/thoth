# Add ECS query helpers and behavior trees for runtime-driven gameplay

## Summary

The runtime already supports ordered systems, but it does not yet offer lightweight helpers for entity querying or AI decision flow. Add ECS query helpers and behavior trees that complement the runtime without turning `thoth` into a monolithic engine.

## Scope

- Add small ECS-friendly query helpers for filtering, grouping, and iterating entity tables.
- Add behavior tree primitives such as selectors, sequences, decorators, and blackboard support.
- Ensure behavior trees integrate cleanly with runtime systems and deterministic replay.
- Keep the APIs lightweight and composable rather than imposing a full entity framework.
- Add examples that pair behavior trees with pathfinding and input/state transitions.

## Acceptance criteria

- Query helpers reduce common system boilerplate without forcing a new entity storage format.
- Behavior trees are deterministic under seeded runtime conditions.
- Tests cover tree execution order, decorator behavior, and query-helper filtering.
- The new APIs feel consistent with the rest of `thoth.game`.
