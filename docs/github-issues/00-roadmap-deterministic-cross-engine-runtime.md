# Roadmap: make `thoth` a deterministic, cross-engine gameplay runtime

## Summary

`thoth` already has the bones of a useful gameplay runtime: fixed-step scheduling, system ordering, input abstraction, state management, tweening, tasks, pathfinding, and spatial queries. The next roadmap should turn that foundation into the product's main differentiator: a deterministic, portable runtime that works across multiple Lua game frameworks.

## Why this matters

The current repository is strongest where `thoth.core`, `thoth.game`, and `thoth.adapters` meet. A focused roadmap around deterministic simulation, deeper adapter capabilities, better observability, and stronger gameplay primitives will make the library more coherent and more distinctive than simply adding unrelated helpers.

## Workstreams

- Build a deterministic runtime foundation with runtime-owned seeded RNG and stable frame metadata.
- Add input recording and replay for reproducible headless runs.
- Add snapshot, restore, save/load, and rollback-friendly helpers.
- Replace the minimal adapter contract with a capability-based contract.
- Extend input and platform coverage for gamepad, touch, deadzones, rebinding, and profile persistence.
- Expose system timings, event traces, task inspection, and a debug HUD.
- Ship a real showcase example that uses the runtime as intended.
- Expand gameplay primitives around camera, collision, animation, tilemaps, navigation, ECS queries, and AI behavior trees.
- Broaden `thoth.core` with more containers and platform-neutral utilities.
- Unify API style and harden the test suite.
- Remove local developer friction from the test and module-resolution workflow.

## Acceptance criteria

- The linked issues are opened and tracked from this roadmap issue.
- The implementation order preserves the deterministic-runtime work as the main throughline.
- The repository documentation and examples reflect the new product direction once the work lands.
