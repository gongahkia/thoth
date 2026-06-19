# Render Interface

Date: 2026-06-20

Source command:

```sh
rg "Render\." -n src main.lua tests benchmarks --glob '!src/app/render.lua'
```

## External Callers

| Function | Callers | Contract |
|---|---|---|
| `Render.load()` | `main.lua` | Initialize render-only caches/resources. Current implementation resets iso terrain canvas cache and tile-order cache. Must be safe to call once at app boot. |
| `Render.draw(sim, app)` | `main.lua` | Clear the frame, reset UI hitbox tables, draw world/HUD/panels/combat/camp/estate/cutscene layers. Mutates `app.ui` and `app.worldView`. |
| `Render.advanceCutscene(app, dt)` | `main.lua`, `tests/run.lua` | Increment `app.cutscene.elapsed`; clear `app.cutscene` when elapsed reaches scene duration. No-op when no active cutscene. |
| `Render.cutsceneForEvent(event, sim)` | `main.lua`, `tests/run.lua` | Convert a simulation event table/string into a cutscene table or `nil`. Returned scene fields include `kind`, `title`, `elapsed`, `duration`, `side`, and optional metadata such as `actor`, `skill`, `caption`, `beat`, `mood`, `camera`, `boss`, `encounter`, `enemies`. |
| `Render.cutsceneForStatus(message, sim)` | `tests/run.lua` | Convenience wrapper over `cutsceneForEvent({ message = message }, sim)`. Returns same scene shape or `nil`. |
| `Render.idleCombatScene(sim)` | `tests/run.lua` | Return ambient combat scene table when `sim.mode == "combat"` and `sim.combat` exists; otherwise `nil`. |
| `Render.projectIso(view, x, y)` | `tests/run.lua` | Convert world tile coordinates to screen coordinates using `view.centerX`, `view.centerY`, `view.halfW`, `view.halfH`, `view.originX`, `view.originY`, and `view.rotation`. |
| `Render.screenToWorld(view, x, y)` | `tests/run.lua` | Inverse of `projectIso`; returns rounded world tile `x, y` for a screen position. Must round-trip tested coordinates for rotations. |
| `Render.prepareUi(app)` | `tests/run.lua`, indirectly `Render.draw` | Initialize and clear `app.ui` hitbox arrays: `skillButtons`, `heroButtons`, `enemyButtons`, `itemButtons`, `missionButtons`, `recruitButtons`, `provisionButtons`, `estateActionButtons`, `rosterButtons`. |

## Data Contracts

`app` fields read or mutated by render:

- `camera`: `{ x, y, zoom }`; legacy 2D camera data.
- `viewRotation`: integer snap rotation, expected modulo 4.
- `worldView`: written by `drawWorld`; read by input/tests for hit projection.
- `ui`: written by `prepareUi` and per-layer draw methods for mouse hitboxes.
- `cutscene`: active scene table, mutated by `advanceCutscene` and drawn by `drawCutscene`.
- `eventFlash`, `status`, `renderBenchmark`: read during draw paths.

`sim` expectations:

- World render requires `sim.world`, `sim.player.x`, `sim.player.y`, `sim.player.z`.
- UI/combat render reads party, expedition, estate, combat, and helper methods on `Simulation`.
- Cutscene mapping reads event metadata and may call `sim:activeHero()`.

## Internal Render Methods

These are defined as `Render.*` in `src/app/render.lua` but have no external callers in the current tree:

- `Render.rotateDelta(dx, dy, rotation)`
- `Render.unrotateDelta(rx, ry, rotation)`
- `Render.drawWorld(sim, app)`
- `Render.drawHud(sim, app)`
- `Render.drawSidePanel(sim, app)`
- `Render.drawCutscene(sim, app)`
- `Render.drawCombatStage(sim, app)`
- `Render.drawCombatOverlay(sim, app)`
- `Render.drawCampOverlay(sim)`
- `Render.drawEstatePanel(sim, app)`

Phase 1 should keep external compatibility for the functions in `External Callers`. Internal methods can move or become locals unless tests or callers are added before the port.
