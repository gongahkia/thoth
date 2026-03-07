# Strengthen testing for serializer, quadtree, pathfinding, adapters, and property-style coverage

## Summary

The repository already has decent smoke coverage, but the highest-risk modules still need deeper edge-case testing. Expand the test suite around serialization, spatial indexing, heuristics, and adapter behavior, and add property-style checks where deterministic invariants are important.

## Scope

- Add deeper serializer tests for malformed input, circular references, and save/load safety.
- Add quadtree and spatial-hash tests for boundary conditions, duplicate retrieval, and update/remove behavior.
- Add pathfinding tests for heuristic correctness, weighted paths, and no-path scenarios.
- Add adapter tests for capability declarations and degraded host features.
- Add property-style or generated tests for deterministic invariants where feasible.

## Acceptance criteria

- The test suite covers the current edge-heavy modules substantially better than today.
- Deterministic runtime features ship with regression tests that prove reproducibility.
- Adapter tests cover both happy paths and missing-capability behavior.
- Test organization remains easy to run from the repository root.
