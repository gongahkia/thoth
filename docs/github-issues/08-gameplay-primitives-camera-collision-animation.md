# Add gameplay primitives for camera, collision, and animation state machines

## Summary

The runtime layer needs a tighter set of gameplay primitives around movement and simulation. Add a camera module, collision shapes with narrow-phase helpers, and animation state machines that fit the existing runtime and adapter architecture.

## Scope

- Add camera helpers for follow, bounds clamping, world/screen transforms, and screen shake.
- Add collision shapes and narrow-phase queries such as AABB, circle, point, segment, and ray tests.
- Add animation state machines with named states, transitions, timers, and callbacks.
- Keep rendering engine-specific while exposing runtime-friendly data and update APIs.
- Provide examples that show these primitives working with systems and states.

## Acceptance criteria

- New modules fit under `thoth.game` and are usable from runtime systems.
- Collision helpers go beyond the current broad-phase spatial helpers.
- Animation state transitions can be driven by runtime systems and input.
- Tests cover camera transforms, collision queries, and animation transitions.
