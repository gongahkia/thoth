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

### R6. GUI toolkit (Tasks 3, 6, 12, 14)

`[Verified]` Options: **Slab** (fuller-featured, menubars/list-boxes/dialogs) vs **SUIT** (minimal, immediate-mode).

`[Speculation]` Prototype aesthetic is retro/Proteus; a heavy modern GUI (Slab) will clash. Recommend **custom immediate-mode UI in ~300 LOC** using existing `love.graphics` primitives + BigBlue Terminal font already bundled. Fallback to SUIT if custom exceeds 500 LOC.

**Decision required before Task 3:** pick custom vs SUIT vs Slab. Document choice in commit body.

### R7. Menu/world-creation reference (Task 14)

User attached two Minecraft "Create World" screenshots (Bedrock modern + Pocket Edition alpha). Take: **left sidebar (General/Advanced/Multiplayer/Cheats/Packs) + right main panel (name/seed/game mode/difficulty)** from modern; **Proteus-style muted palette + BigBlue Terminal font** from Thoth aesthetic. Result: title screen → [Play | Create World | Load World | Settings | Quit] → each opens a subpage.

---

## Tasks

Ordering rationale: menu/world-creation infrastructure (Tasks 14 → 6 → 12) unblocks the settings page (Task 3) and the fixed-scale change; HUD + labels + banner (Tasks 8, 9, 11) sit above the new UI; biomes/weather (Tasks 5, 10) extend generation; content additions (Task 4) piggyback on generation. Numbered per user request; execution order recommended below each.

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

**REMAINING:** —

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
