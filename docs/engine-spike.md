# Engine Spike

Date: 2026-06-19

Status: Day 1 bake-off complete.

Local runtime: LOVE 11.5.

## Candidates

- `g3d`
  - Upstream: `https://github.com/groverburger/g3d.git`
  - Rev: `639120acd754dc5c34402e41eb1687b1a5a3ffa8`
  - README fit: small API, `require "g3d"`, textured models, OBJ loading, perspective and orthographic cameras.
  - Run check: `timeout 5s love vendor/g3d`; no stderr before timeout.

- `3DreamEngine`
  - Upstream: `https://github.com/3dreamengine/3DreamEngine.git`
  - Rev: `bdaa095a38be91107647966851eb3dd5379e0e61`
  - README fit: richer renderer with PBR, glTF/OBJ/DAE/VOX support, shadows, particles, HDR, fog, and loader systems.
  - Run check: `examples/monkey` launched via temporary `default`; `timeout 5s love vendor/3DreamEngine`; stdout emitted `material Color is unknown`, no crash before timeout.

## Choice

Use `g3d` for Phase 0.

Rationale:

- The Phase 0 question is narrow: cube, 20x20 grid, orthographic iso camera, 90-degree yaw snaps, billboard sprites, FPS overlay.
- `g3d` directly covers that scope with fewer renderer subsystems to configure.
- `3DreamEngine` has better production-rendering breadth, but its PBR/light/resource pipeline is extra surface area for this throwaway proof.
- [Inference] `g3d` is the lower-risk first spike because the README demo and API match the needed proof with less setup.

This does not lock the Phase 1 production renderer. Phase 0 can still switch if `g3d` misses the perf, camera, or billboard exit criteria.
