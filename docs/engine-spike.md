# Engine Spike

Date: 2026-06-19

Status: Day 1-4 spike checks complete; Phase 1 approach drafted.

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

## Billboard Verification

Date: 2026-06-20

Command:

```sh
timeout 12s love spike --verify-billboard
```

Output:

```text
verify-output=/Users/gongahkia/Library/Application Support/LOVE/thoth-spike
captured billboard-snap-1.png
captured billboard-snap-2.png
captured billboard-snap-3.png
captured billboard-snap-4.png
```

Result: visually inspected all four captures. The colored axis tiles rotate between snap states, and the OGA sprite remains upright and front-facing in snaps 1/4 through 4/4.

[Inference] The current yaw-cancel billboard math is correct for the four Phase 0 snap positions.

## FPS Verification

Date: 2026-06-20

Command:

```sh
timeout 10s love spike --verify-fps
```

Output:

```text
fps-min=60
```

Result: the 20x20 tile grid plus 34 OGA billboards met the Phase 0 Day 4 60 FPS floor after a 2s startup warmup and a 3s measurement window.

## Simulation Verification

Date: 2026-06-20

Command:

```sh
timeout 10s love spike --verify-sim
```

Output:

```text
sim-verify-start ticks=180
sim-verify-ticks=180
sim-verify-match=true
```

Result: the spike scene advanced a live `src.game.simulation` instance one command per render frame for 180 ticks. Its final serialized snapshot matched the headless baseline snapshot for the same command stream.

## Save Roundtrip Verification

Date: 2026-06-20

Command:

```sh
timeout 10s love spike --verify-save
```

Output:

```text
save-roundtrip-path=/Users/gongahkia/Library/Application Support/LOVE/thoth-spike/spike-save-roundtrip.thoth
save-roundtrip-match=true
```

Result: `Save.write` and `Save.read` roundtripped a stepped simulation through LOVE filesystem state, then removed the temporary save file.

## Phase 1 Integration Approach

Use `g3d` as the Phase 1 render candidate.

Port order:

1. Add `src/app/render3d.lua` behind the existing `Render.*` interface.
2. Keep `src/game/simulation.lua` untouched; rendering reads snapshots/app state only.
3. Move the spike camera math into the render layer as explicit state: `baseYaw`, `snapIndex`, `targetYaw`, and interpolated `cameraYaw`.
4. Render map geometry as batched tile meshes first. Start with one mesh per visible floor layer; split by material only if needed.
5. Render heroes/enemies as billboard models using yaw cancellation from the spike: `sprite:setRotation(0, 0, math.pi / 2 - cameraYaw)`.
6. Keep the spike verifier commands as parity checks while porting: `--verify-fps`, `--verify-sim`, `--verify-save`, and `--verify-billboard`.

Initial performance result: `fps-min=60` with 400 flat tiles and 34 billboards on local LOVE 11.5 after warmup.

[Inference] The current prototype is sufficient to open Phase 1 because it covers the required camera, grid, billboard, FPS, simulation, and save/load checks without touching game logic.

## Failure Fallback

Day 1-4 checks passed with `g3d`; the `3DreamEngine` fallback retry path was not triggered.

The both-libraries-failed STOP condition was not triggered.
