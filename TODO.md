# Thoth TODO

Independent agent brief. Follow `CLAUDE.md` (terse, min tokens, fail-fast, no auto-refactor outside task scope, in-line comments only, use `[Inference]`/`[Speculation]`/`[Unverified]` labels for non-sourced claims).

## Conventions

- **One commit per task.** Commit message: `todo(<n>): <one-line summary>`.
- **Partial work:** leave `STATUS: in_progress`, fill `REMAINING:` with exact next steps and current stuck point.
- **Determinism contract:** `(seed, geologicTime, worldOptions)` — any new world-affecting field must be added to `worldOptions` and to `Save.snapshot` / `applySnapshot` (main.lua:332–371).
- **Tests:** every task that changes generation/rendering must (a) run `make smoke render-smoke walk-smoke` and (b) either update `tests/bench.baseline.json` via `make bench-update` (with justification in commit body) or explain why baseline is unchanged.
- **Scope discipline:** no drive-by refactors; if you must touch code outside FILES, note it in REMAINING.

---

## Research (front-loaded)

### R1. Terrain-gen extensions worth adding

`[Verified]` Existing: OpenSimplex2 base + stream-power fluvial + hillslope diffusion + glacial SIA + periglacial + aeolian dunes + karst + volcanism + coastlines + reefs + meander migration + plate tectonics + hotspots + orometry archetypes.

`[Inference]` Gaps versus current literature (2024–2025):
- **Sediment transport ledger** — track deposition vs incision per cell, feeds floodplain thickness and terrace formation. Cheap addition on top of existing stream-power.
- **Debris flow / landslides** — mass wasting events on steep saturated slopes; produces talus cones and dammed lakes.
- **Sinkholes & tower karst** — karst.lua currently has dissolution; extend to discrete collapse cells + cenote/tower morphology.
- **Salt tectonics / diapirs** — rare but visually striking in arid basins.
- **Loess deposits** — wind-blown silt downwind of glacial/desert margins; complements existing aeolian.
- **Alluvial terraces** — stepped valleys from base-level drops; requires sea-level history (already present via `seaLevelOscillation`).
- **Fluvial fans (multi-lobe)** — current `alluvialFan` is single-cell; multi-lobe distributary networks look better.
- **Braided rivers** — where slope × sediment load exceeds threshold; visual variant of existing river cells.
- **Solifluction lobes / stone stripes** — periglacial already tracked; render as landform variants.
- **Coral atoll rings / seamounts** — extend reef.lua for open-ocean features.
- **Playa / salt flat** — endorheic basins with high evaporation; renders as bright reflective flat.
- **Ice shelves / iceberg-calving fronts** — cold-coast glacial termini.

`[Speculation]` Highest visual ROI per effort: braided rivers, alluvial terraces, multi-lobe fans, playas, sinkholes.

### R2. Full biome set (Task 5 input)

`[Verified]` WWF: 14 terrestrial biome major types across 8 realms × 867 ecoregions; Global 200 includes 142 terrestrial + 53 freshwater + 43 marine. Köppen-Geiger: 5 major (A/B/C/D/E) × 30 sub-types.

**Target biome set** (dedupe against current biomes.lua):
- Tropical: rainforest, seasonal/monsoon forest, dry broadleaf, savanna, thorn scrub, mangrove, cloud forest.
- Temperate: broadleaf, mixed, coniferous, rainforest (Pacific NW / Valdivian), grassland/prairie/steppe, chaparral/Mediterranean, wetland/marsh, bog/mire, heathland.
- Boreal: taiga, muskeg, subalpine forest, krummholz zone.
- Xeric: hot desert, cold desert, semiarid shrubland, salt flat/playa, dune sea/erg, badland/hoodoo, oasis.
- Polar: tundra, polar desert, ice sheet, permafrost polygon field.
- Alpine: alpine meadow, scree, nival zone, glacier tongue.
- Fluvial/lacustrine: riparian gallery forest, floodplain, delta, oxbow marsh, karst poljé.
- Coastal: beach/dune, estuary/lagoon, saltmarsh, mangrove (dup), rocky cliff, kelp forest fringe.
- Marine (surface-visible only, no seafloor): reef, atoll ring, seamount cap.
- Volcanic/geothermal: lava flow, fumarole field, ash plain, hot spring travertine.
- Fantastical/extreme (opt-in via worldOption `allowExoticBiomes`): bioluminescent grove, red algal shore, salt cathedral, blue-ice field.

`[Inference]` Total ~50 biomes; current `biomes.lua` grid is 16×16 = 256 slots so headroom exists.

### R3. Weather system design (Task 10)

`[Verified]` Existing: `atmosphere.lua` handles day/season palette + sun direction; `climate.lua` computes rainfall/temperature/wind/pressure cells at generation time. No runtime weather events found in grep.

**Proposed model** — three coupled state machines per view region:
1. **Front layer** — advected low/high pressure cells drifting along `climate.lua` wind field; when a low crosses the region, precipitation probability rises.
2. **Precipitation state** — {clear, drizzle, rain, downpour, sleet, snow, hail, freezing_rain}. Selection = f(temperature at cell, front intensity, orographic uplift from local slope).
3. **Storm state** — rare extreme events (thunderstorm, blizzard, sandstorm, hurricane over warm ocean); scheduled by climate zone.

Persist per-region weather to keep determinism: seed(x, y, geologicTime, wallclock_bucket) → same weather at same time.

`[Inference]` Cloud cover, wind speed, visibility, ambient sound cue are the four minimum runtime signals.

### R4. Palette 32 → 64 (Task 13)

`[Verified]` `postfx.lua` quantizes to 32-color biome palette. Search consensus: 32–64 both acceptable for pixel art; 64 preserves more detail with ~2–5 dB PSNR gain vs 32. No hard technical blocker; LUT/shader constant array size doubles.

`[Inference]` Palette selection per active biome/scale — will need re-tuning of biome palette tables (`render.lua:10–56`). Consider OkLab distance for palette build if artifacts appear.

### R5. FPS controller (Task 1)

`[Verified]` Current `player.lua`: instantaneous velocity, no acceleration, no head-bob, no elevation, no collision.

**Design decisions:**
- **Acceleration model:** exponential approach — `v += (target_v − v) * (1 − exp(−k·dt))` with `k ≈ 8` for walk, `k ≈ 5` for sprint start, `k ≈ 12` for stop. `[Inference]` Feels responsive without snappy.
- **Head-bob:** curve-based, not sine — two-key spline per step; magnitude scales with speed. Bob dip triggers footstep event.
- **Footstep cadence:** ~2.1 Hz walk, ~3.4 Hz sprint. Surface tag from `cell.biome` selects sound (currently no audio pipeline — Task 1.5 stubs the hook).
- **Body elevation:** camera y-offset = `cell.elevation + eyeHeight` where `eyeHeight ≈ 1.7`. Sample the terrain per frame.
- **Collision:** vertical only — clamp movement into water below waterline and above cliffs beyond slope threshold. `[Inference]` No jump; do not "teleport up cliff" — reject move if elevation delta > `maxStepUp = 0.5`.
- **Camera sway:** optional, tied to setting; ±0.5° roll on stride, 0 on standstill.

### R6. GUI toolkit (Tasks 3, 6, 12, 14)

`[Verified]` Options: **Slab** (fuller-featured, menubars/list-boxes/dialogs) vs **SUIT** (minimal, immediate-mode).

`[Speculation]` Prototype aesthetic is retro/Proteus; a heavy modern GUI (Slab) will clash. Recommend **custom immediate-mode UI in ~300 LOC** using existing `love.graphics` primitives + BigBlue Terminal font already bundled. Fallback to SUIT if custom exceeds 500 LOC.

**Decision required before Task 3:** pick custom vs SUIT vs Slab. Document choice in commit body.

### R7. Menu/world-creation reference (Task 14)

User attached two Minecraft "Create World" screenshots (Bedrock modern + Pocket Edition alpha). Take: **left sidebar (General/Advanced/Multiplayer/Cheats/Packs) + right main panel (name/seed/game mode/difficulty)** from modern; **Proteus-style muted palette + BigBlue Terminal font** from Thoth aesthetic. Result: title screen → [Play | Create World | Load World | Settings | Quit] → each opens a subpage.

---

## Tasks

Ordering rationale: menu/world-creation infrastructure (Tasks 14 → 6 → 12) unblocks the settings page (Task 3) and the fixed-scale change; traversal + zoom (Tasks 1, 2) are independent; HUD + labels + banner (Tasks 8, 9, 11) sit above the new UI; biomes/weather/palette (Tasks 5, 10, 13) extend generation; content additions (Task 4) piggyback on generation. Numbered per user request; execution order recommended below each.

---

### Task 6 — World creation page + fix scale at gen time

**STATUS:** pending
**RECOMMENDED ORDER:** 2nd (blocks Tasks 8, 9, 11 assumptions; removes `Tab` UX).

**SCOPE:** Replace runtime `Tab` scale-cycling with a **world-scope** picked once at generation. Add a Minecraft-style "Create World" page.

**FILES:**
- `src/menu.lua` — new `create` subpage.
- `src/worldgen.lua` — accept `worldOptions.scope` ∈ `{local, region, continent}` and treat it as the sole active scale; keep the other scales as internal LOD tiers if render.lua needs them, else compile out.
- `src/viewscale.lua` — collapse cycle behavior: `advanceDiegetic` becomes no-op or removed; `activeScale` returns `worldOptions.scope`. Keep multi-scale sampling as an internal LOD helper only.
- `main.lua` — remove `Tab` key handler (main.lua:598–602); remove `--geologic-time` cycling assumptions if any; keep `ViewScale.new` for label caching.
- `src/save.lua` — persist `scope` in `world` snapshot block.

**CREATE-WORLD FIELDS** (mirror screenshot 1's left-sidebar / right-main layout):
- General: `name` (text), `seed` (text, blank = random), `scope` (radio: Local / Region / Continent), `allowExoticBiomes` (checkbox, gates R2 fantastical set), `geologicTime` (slider 0.0–1.0).
- Advanced: `hydrologyRegionChunks`, `hydrologyHaloCells`, `hydrologyBasinChunks`, `hydrologyBasinStride`, `cacheMaxEntries`, `pixelScale`, `dayLength`, `startSeason`.
- Preview: live 128×128 `Export.renderMap` regenerated on-change (debounce 500 ms).
- Buttons: `Create` (persists via Task 12 library, launches game), `Back`.

**DETERMINISM UPDATE:** contract becomes `(seed, geologicTime, scope, allowExoticBiomes, advanced_hydrology_fields)`. Add hash to save snapshot for detecting mismatch on load.

**ACCEPTANCE:**
- No `Tab` in-game action.
- Creating a world at `scope = continent` produces continent-factor sampling from frame 1; player never sees `local` unless created there.
- `make regressions` still passes (fixtures may need scope pinned in test harness).
- Snapshot round-trip preserves all creation fields.

**REMAINING:** — decide if internal multi-scale LOD is retained for render distance falloff or fully removed; recommend retained but not player-visible.

---

### Task 12 — "My Worlds" library + multi-slot save

**STATUS:** pending
**RECOMMENDED ORDER:** 3rd.

**SCOPE:** Replace single-slot `thoth-save.json` with a directory of named saves; add library page listing them with thumbnails.

**FILES:**
- `src/save.lua` — support directory (default `~/.local/share/love/thoth/worlds/` via `love.filesystem`), one JSON per world, metadata (name, seed, scope, created-at, last-played, thumbnail path).
- `src/menu.lua` — new `library` subpage: scrollable list, per-entry buttons `Play`, `Rename`, `Delete`, `Export`.
- `main.lua` — deprecate `--save-path`/`--load-save` as single-file flags; keep them working (import single-file into library on first launch).
- New `src/thumbnail.lua` — snapshot mini-map PNG on world creation via `Export.renderMap` at 128×128.

**ACCEPTANCE:**
- Create → world appears in list with thumbnail.
- Delete asks confirmation, removes JSON + thumbnail.
- Existing `thoth-save.json` migrates on first run.
- Export button writes a portable `.thoth-world` bundle (JSON + PNG in a zip via `love.data.compress`).

**REMAINING:** — thumbnail generation must be deterministic and cheap (< 200 ms); if too slow, defer to first `Play`.

---

### Task 3 — Settings page + reconfigurable keybinds

**STATUS:** pending
**RECOMMENDED ORDER:** 4th (needs Task 14 infra).

**SCOPE:** Settings subpage under menu. Persists to `settings.json` (LOVE save dir). Rebindable keys.

**FILES:**
- `src/menu.lua` — `settings` subpage (tabs: Controls / Display / Audio / Debug).
- New `src/settings.lua` — load/save `settings.json`; schema with defaults; validation.
- New `src/keybinds.lua` — action → key map; `keybinds.isDown("forward")` replaces raw `love.keyboard.isDown("w")` in `main.lua:463–468` and `player.lua`.
- `main.lua` — swap key checks to `Keybinds.isDown`; `love.keypressed` dispatches through action lookup.

**DEFAULT BINDINGS:** mirror current README controls table.

**CONTROLS TAB:** each action row shows current binding + `Rebind` button that enters capture mode (next key press assigns; Esc cancels; conflict warns).

**DISPLAY TAB:** pixel-scale, day-length, start-season, mouse-look sensitivity, head-bob toggle, camera-sway toggle (feeds Task 1).

**AUDIO TAB:** master/sfx/ambient sliders (stubs OK if no audio yet).

**DEBUG TAB:** toggles for perf HUD, topo overlay, minimap, debug panels — same set currently keybound.

**ACCEPTANCE:**
- Rebinding `W` to `Z` reflects in-game immediately and persists across restart.
- Invalid bindings (duplicate) surface a warning.
- Deleting `settings.json` restores defaults on next launch.

**REMAINING:** —

---

### Task 1 — Traversal physics (accel / stumble / footsteps / elevation / collision / sway)

**STATUS:** pending
**RECOMMENDED ORDER:** 5th (independent, can parallel with 2, 3).

**SCOPE:** Replace `player.lua` instantaneous movement with a fuller controller. Design per R5.

**FILES:**
- `src/player.lua` — expand from 33 → ~120 LOC. Add `player.vx`, `player.vy`, `player.eyeHeight`, `player.footstepPhase`, `player.bobOffset`.
- `main.lua` — pass camera struct + settings toggles to `Player.update`.
- `src/render.lua` — apply `bobOffset` and optional roll `swayAngle` to camera transform.

**IMPLEMENTATION NOTES:**
- **Acceleration:** `v += (targetV − v) * (1 − exp(−k*dt))`; k table by state (walk-start 8, sprint-start 5, stop 12, water 3).
- **Elevation:** sample `world:sample(floor(x), floor(y), scope)` each frame; camera y = `cell.elevation + eyeHeight`.
- **Collision:** compute prospective cell; if `newCell.elevation − currentCell.elevation > maxStepUp` (0.5), reject horizontal component into blocked direction (slide along tangent). If `cell.water` and depth > `wadeMax` (0.3), reject or slow to 0.15×.
- **Stumble:** if attempted step-up between 0.25 and 0.5, apply `stumbleCooldown = 0.4 s` where speed × 0.5. `[Speculation]` Feels like tripping without full ragdoll.
- **Head-bob:** two-key spline peak-to-peak amplitude `walkBob = 0.08`, `sprintBob = 0.14`; phase increments at `bobHz * speed / walkSpeed`.
- **Footstep:** phase crossing `π` and `2π` fire `player.onFootstep(cell)` event; consumer is a stub logging surface tag until audio ships.
- **Camera sway:** optional roll ±0.5° tied to bob phase, gated by setting.

**ACCEPTANCE:**
- Player cannot cross a cliff face of Δelev > 0.5 in one step.
- Walking into water above `wadeMax` stops the player.
- Footstep phase increments visibly when `--debug-perf` is on (add `bob=` field to perf line).
- Bob and sway disable cleanly via Task 3 settings toggles.

**REMAINING:** — audio pipeline (out of scope; footstep event is a stub).

---

### Task 2 — Mouse-scroll camera zoom

**STATUS:** pending
**RECOMMENDED ORDER:** 6th (independent).

**SCOPE:** Scroll wheel adjusts camera zoom (FOV or render radius). **Not** scale-switch — Task 6 removes runtime scale change.

**FILES:**
- `main.lua` — implement `love.wheelmoved(x, y)`; adjust `app.camera.zoom` (new field, default 1.0, range [0.5, 2.5]).
- `src/render.lua` — `defaultCamera()` includes `zoom`; scene draw multiplies effective render radius / vertical FOV factor by zoom.

**ACCEPTANCE:**
- Scroll up → tighter view (higher effective FOV or closer clip radius).
- Zoom persists across a session; not saved to world (session-only).
- Min/max clamped; wheel outside range is no-op.

**REMAINING:** — decide FOV vs render-radius as the zoom axis; `[Inference]` render-radius simpler in current clipmap.

---

### Task 13 — Palette 32 → 64

**STATUS:** pending
**RECOMMENDED ORDER:** 7th (small, unblocks visual work).

**SCOPE:** Widen palette quantization from 32 to 64 colors.

**FILES:**
- `src/postfx.lua` — palette LUT + shader constant.
- `src/render.lua:10–56` — biome + landform palette tables extended.
- `assets/orometry/archetypes.lua` — verify no palette-index-bound values; unlikely but check.

**STEPS:**
1. Bump `PALETTE_SIZE = 64`.
2. Extend palette per active scope: sample OkLab-distance-farthest 32 additional colors from a superset drawn from biome + weather + atmosphere tints.
3. Update `render-smoke` output line `palette=` assertion in `tests/run.lua` if hardcoded.

**ACCEPTANCE:**
- `make render-smoke` prints `palette=<id>:64`.
- Visual A/B (pixel-perfect diff or manual) shows finer gradients on sunset skies and water depth.
- Regression fixtures unchanged (palette does not affect generation).

**REMAINING:** —

---

### Task 5 — Expand biomes (WWF + Köppen + extreme)

**STATUS:** pending
**RECOMMENDED ORDER:** 8th (depends on Task 6 for `allowExoticBiomes` gate).

**SCOPE:** Grow biome set from current inventory (~20–25) to ~50 per R2. Include fantastical biomes behind a world-option gate.

**FILES:**
- `src/biomes.lua` — expand Whittaker grid + special-case block. Add Köppen subtype hinting from `climate.lua` outputs (add subtype field to cell struct).
- `src/render.lua:10–31` — colors for new biomes.
- `src/worldgen.lua` — surface `allowExoticBiomes` flag to biome resolver.
- `tests/run.lua` — extend biome-count bounds and diagnostic fixtures.

**MINIMUM NEW BIOMES** (verify each does not already exist):
- Cloud forest, monsoon forest, thorn scrub, Mediterranean chaparral, temperate rainforest, subalpine krummholz, muskeg, cold desert, semiarid shrubland, playa/salt flat, badland, oasis, polar desert, permafrost polygon, alpine scree, nival zone, kelp forest fringe, atoll ring, seamount cap, fumarole field, hot spring travertine, ash plain.
- **Exotic (gated):** bioluminescent grove, red algal shore, salt cathedral, blue-ice field.

**ACCEPTANCE:**
- `make diagnostics` reports >= 30 distinct biomes across 32-seed sweep.
- Exotic biomes appear only when `allowExoticBiomes = true`.
- `make regressions` `single_biome`/`biome_count_low` fixtures still pass with adjusted bounds.

**REMAINING:** — palette re-tuning may spill into Task 13; if Task 13 lands first this is cleaner.

---

### Task 4 — Terrain generation additions

**STATUS:** pending
**RECOMMENDED ORDER:** 9th (piggybacks on Task 5's cell-struct changes).

**SCOPE:** Add high-ROI features from R1: braided rivers, alluvial terraces, multi-lobe fans, playas, sinkholes.

**FILES:**
- `src/hydrology.lua` — braided-river flag when `slope > s_braid AND sedimentLoad > l_braid`.
- `src/erosion.lua` — alluvial terrace shelves at sea-level drop events (needs sea-level history buffer; already in `seaLevelOscillation`).
- `src/hydrology.lua` (or new `src/fans.lua`) — multi-lobe fan geometry at mountain-front cells.
- `src/climate.lua` + `src/hydrology.lua` — playa detection: endorheic basin + rainfall < threshold + evaporation > inflow.
- `src/karst.lua` — sinkhole discrete-collapse cell type + cenote water pool.
- `tests/run.lua` — smoke asserts non-zero counts for each new landform when seeded on a fixture that should exhibit it.

**ACCEPTANCE:**
- `make smoke` prints new counters: `braided_rivers=`, `terraces=`, `fan_lobes=`, `playas=`, `sinkholes=`.
- No regression on existing `broken_seams` or `river_discontinuities` fixtures.
- Bench delta < +15% or explain in commit body.

**REMAINING:** — debris flow / loess / salt tectonics postponed unless time permits.

---

### Task 10 — Weather + realistic day/night

**STATUS:** pending — day/night partly present via `atmosphere.lua`; weather absent.
**RECOMMENDED ORDER:** 10th.

**SCOPE:** Add weather state machine per R3. Verify day/night cycle is realistic (sun angle latitude-aware, twilight length).

**FILES:**
- New `src/weather.lua` — front + precipitation + storm state per active region; deterministic from `(seed, geologicTime, wallclock_bucket)`.
- `src/atmosphere.lua` — accept weather state as tint modifier (overcast dulls palette, storm reduces sun intensity, night moon-phase adjusts ambient).
- `src/render.lua` — rain streaks / snow particles / fog volume as post-fx layer; visibility falloff.
- `src/climate.lua` — expose Köppen zone per cell (add `cell.koppen`).
- `main.lua` — poll weather each frame; expose to HUD (Task 11) and audio hook.

**DAY/NIGHT REALISM CHECKLIST:**
- Sun elevation = f(latitude proxy from world y, day-of-year, hour). Currently `[Inference]` sun direction is fixed per phase — verify.
- Civil / nautical / astronomical twilight durations distinct.
- Moon phase varies over in-game days.
- Season affects day length by latitude proxy.

**ACCEPTANCE:**
- `--debug-perf` shows current weather + Köppen zone.
- Rain persists 30 s – 20 min bounded per event; storms rarer than rain.
- Visibility drops in storms; verify perf HUD `visible_tiles` doesn't need increase because of new draw layers.
- Same `(seed, geologicTime, wallclock_bucket)` → same weather.

**REMAINING:** — sound cues stub only.

---

### Task 8 — Discovery labels rendered at world scale

**STATUS:** pending
**RECOMMENDED ORDER:** 11th.

**SCOPE:** Currently `WorldGen:discoveriesAt` produces named features but they are not billboarded into the world. Render them as world-space text (billboarded, palette-quantized) at feature centroids.

**FILES:**
- `src/render.lua` — new `drawWorldLabels(app, meshData)` pass after billboard pass; iterates `ViewScale.visibleLabels` restricted to visible bounds; projects centroid to screen, draws BigBlue Terminal text with 1px outline.
- `src/viewscale.lua` — expose `label.x, label.y` (already collected) plus a `priority` field (already exists as `anchorRanks`).
- `main.lua` — new setting `showWorldLabels` (Task 3 Display tab).

**ACCEPTANCE:**
- Standing near a labeled mountain range shows its name floating above the peak.
- Label z-orders by priority + distance; deduplication prevents overlap.
- `--render-smoke` prints `world-labels=<count>` line.

**REMAINING:** — label style (all-caps? subtitle biome?) is a design choice; propose all-caps for major (mountain_range, ridge) + title-case for others.

---

### Task 9 — Expanded biome banner + area name over minimap

**STATUS:** pending
**RECOMMENDED ORDER:** 12th.

**SCOPE:** Banner currently fires only on biome change. Extend triggers + surface persistent "current area" label above the minimap.

**FILES:**
- `main.lua:35–55` (`updateBiomeBanner`) — add triggers: entering named feature (watershed, basin, mountain range), elevation-zone crossings (montane → subalpine → alpine → nival), Köppen-zone crossings (via Task 10).
- `src/render.lua:1091–1113` — minimap header: two lines: (1) largest-scope feature name (mountain range or watershed), (2) current biome + Köppen shorthand.
- `src/render.lua` banner draw — layered lines: primary (biome), secondary (feature entered, if any this frame).

**ACCEPTANCE:**
- Walking into a named mountain range shows both a banner and a persistent header label.
- Header updates without flicker (debounce 250 ms).
- Off-toggle via Task 3.

**REMAINING:** —

---

### Task 7 — List UI + map pins + teleport + expanded minimap

**STATUS:** pending
**RECOMMENDED ORDER:** 13th.

**SCOPE:** In-game journal listing surveyed features and dropped pins; click-to-teleport; minimap shows pins.

**FILES:**
- New `src/journal.lua` — in-game overlay listing `app.survey.discoveries` + user-dropped pins; scrollable; per-entry `Teleport` and `Delete pin`.
- `src/survey.lua` — extend with `pins` collection (user-placed, distinct from `discoveries`); persist via `Save.snapshot`.
- `main.lua` — new key (default `J`) toggles journal; new key (default `P`) drops pin at current location.
- `src/render.lua` (`minimapData`) — draw pin markers + discovery markers with distinct glyphs; hover tooltip when journal open.

**TELEPORT:**
- Set `app.player.x = pin.x`, `.y = pin.y`; camera snaps; call `preloadApp(app, "teleport")`; reset velocity to 0 to avoid stumble artifacts.
- Optional confirmation dialog behind a setting (default off).

**ACCEPTANCE:**
- Drop 3 pins, open journal, teleport to first → position matches, minimap centers.
- Pins persist through save/load.
- Journal shows counts matching `--debug-perf`'s `survey` line.

**REMAINING:** — hotkey conflict check with Task 3 rebindings.

---

### Task 11 — Player-facing HUD (distinct from debug HUD)

**STATUS:** pending
**RECOMMENDED ORDER:** 14th (last — depends on Tasks 8, 9, 10 signals).

**SCOPE:** Minimal diegetic HUD for players. Explicitly not a debug panel.

**FILES:**
- New `src/hud.lua` — draws: compass ribbon (top-center), area name (top-left, from Task 9), biome banner (existing, top-center below compass), weather glyph + temperature (top-right, from Task 10), minimap (bottom-right, existing), pin count / discovery count (bottom-left).
- `src/render.lua:1251` (`drawHud`) — call `HUD.draw` alongside existing debug draws; HUD.draw gated by `app.showPlayerHud` (default true).

**RULES:**
- **No numeric perf data** (that's debug HUD's job).
- **No hex coords** (world-space labels serve that need).
- Palette-quantize consistently with world (postfx applies uniformly).
- Toggle via setting + hotkey (default `H`).

**ACCEPTANCE:**
- Debug HUD (`L`) and player HUD (`H`) toggle independently; both visible does not overlap.
- Compass ticks show cardinal directions; needle points to yaw.
- Weather glyph matches Task 10 state.

**REMAINING:** —

---

## Global acceptance gates (run after every task)

```sh
make test smoke render-smoke walk-smoke regressions bench
```

If bench regresses > 10%, either optimize or run `make bench-update` and justify in commit body.

## Sources (research pass)

- [Procedural Terrain Generation Techniques](https://howik.com/procedural-terrain-generation-techniques)
- [GPU-Optimized Terrain Erosion Models](https://www.daydreamsoft.com/blog/gpu-optimized-terrain-erosion-models-for-procedural-worlds-building-hyper-realistic-landscapes-at-scale)
- [Real-time Terrain Enhancement with Controlled Procedural Patterns (2024)](https://onlinelibrary.wiley.com/doi/10.1111/cgf.14992)
- [Procedural Planetary Multi-resolution Terrain Generation](https://arxiv.org/abs/1803.04612)
- [WWF Terrestrial Ecoregions](https://en.wikipedia.org/wiki/List_of_terrestrial_ecoregions_(WWF))
- [WWF Global 200](https://en.wikipedia.org/wiki/Global_200)
- [Köppen-Geiger Climate Classification](https://en.wikipedia.org/wiki/K%C3%B6ppen_climate_classification)
- [Köppen-Geiger 1-km Present/Future Maps (Nature Scientific Data)](https://www.nature.com/articles/sdata2018214)
- [ClimateGS: Real-Time Climate Simulation](https://arxiv.org/pdf/2503.14845)
- [Color Quantization](https://grokipedia.com/page/Color_quantization)
- [Improving Color Quantization Heuristics (OkLab)](http://blog.pkh.me/p/39-improving-color-quantization-heuristics.html)
- [Slab GUI for LÖVE](https://github.com/flamendless/Slab)
- [SUIT for LÖVE](https://github.com/vrld/suit)
- [FPS Character Controller (headbob, footsteps)](https://mocaponline.com/blogs/mocap-news/first-person-animation-guide)
- [Character Foot Effects — Opsive](https://opsive.com/support/documentation/ultimate-character-controller/surface-system/character-foot-effects/)
