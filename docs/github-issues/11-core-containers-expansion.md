# Add foundational core containers: sets, deques, ring buffers, ordered maps, and union-find

## Summary

`thoth.core` already has several data structures, but some common foundational containers are still missing. Add the next wave of structures that are broadly useful for both general Lua code and gameplay systems.

## Scope

- Add a set implementation with common operations such as union, intersection, and difference.
- Add a deque for efficient push/pop at both ends.
- Add a ring buffer for bounded history and rolling-window workloads.
- Add an ordered map or ordered dictionary.
- Add a union-find or disjoint-set structure.

## Acceptance criteria

- New containers live under `thoth.core` and are exposed through the lazy namespace loader.
- Each container has basic API documentation and tests.
- The APIs support both general-purpose use and runtime-oriented workloads.
- Naming and construction style align with the broader API unification plan.
