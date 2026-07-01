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

Ordering rationale: menu/world-creation infrastructure (Tasks 14 → 6 → 12) unblocks the settings page (Task 3) and the fixed-scale change; HUD + labels + banner (Tasks 8, 9, 11) sit above the new UI. Numbered per user request; execution order recommended below each.

All listed tasks are complete.

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
