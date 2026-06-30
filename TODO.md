# TODO

## 0. Project context (one screen)

**What Thoth is today:** A LÖVE 11.5 (Lua) prototype of a first-person, endlessly-explored procedural terrain. ~7.3 kLOC. Deterministic seed-driven, with an optional `--geologic-time` plate-drift parameter. Three nested view scales (local/region/continent, factors 1/4/16). Geomorphology vocabulary (plates, subduction, rifts, cratons, deltas, lakes, watersheds), OpenSimplex2 noise + iterative stream-power and glacial erosion, Priority-Flood + D8 hydrology with an async worker, geometry-clipmap LOD terrain with persistent streamed meshes, terrain/billboard shaders, a low-res palette-quantized canvas, atmosphere day/season cycling driving sun direction and palette tint, per-chunk LRU caches, and a benchmark/baseline gate.

**Three north-star goals (from the user):**
1. Rendering style similar to *Proteus* (Ed Key / Twisted Tree, 2013): pixel-art look, 2D sprite flora/fauna against 3D terrain, mood-driven palette, low-poly chunky hills.
2. Realistic terrain generation that is true-to-real-world geomorphology — i.e. iterative physically-based simulation, not just additive noise.
3. High FPS in an endlessly generated world.

**File map (verified):**
- `main.lua` — LÖVE entrypoint, perf log harness, CLI flags, save/load, debug-panel toggles
- `conf.lua` — window 1280×720, physics+video off
- `src/worldgen.lua` — plates (`geologicTime`-aware), OpenSimplex base, biome classifier, chunk/billboard caches, `heightAt`/`normalAt`
- `src/hydrology.lua` — Priority-Flood, D8, basin pre-pass, lake grouping
- `src/worker.lua` — async hydrology worker thread
- `src/erosion.lua` — stream-power + glacial + isostatic rebound
- `src/climate.lua` — orographic precipitation
- `src/biomes.lua` — Whittaker lookup
- `src/coast.lua` — coastal erosion + beaches
- `src/aeolian.lua` — dune deltas
- `src/noise.lua` — OpenSimplex2 + FBM + ridge + domain warp
- `src/rng.lua` — BitOp-mixed deterministic hash
- `src/lru.lua` — bounded LRU cache
- `src/render.lua` — clipmap terrain + persistent mesh streams + shader pipeline
- `src/clipmap.lua` — geometry clipmap LOD
- `src/postfx.lua` — low-res canvas + palette quantization
- `src/atmosphere.lua` — day/season cycle + palette tint + `sunDirection`
- `src/viewscale.lua` — three-scale easing transitions
- `src/player.lua` — WASD movement + slope/water slowdown
- `src/survey.lua` — marked-cell history
- `src/save.lua` — JSON-ish save/load
- `src/diagnostics.lua` — seed sweeps + regression fixtures
- `src/export.lua` — PNG/PPM map export
- `src/benchmark.lua` — headless terrain benchmark + baseline gate
- `tests/run.lua` — 52 deterministic tests + diagnostics/benchmark/regressions CLI
- `tests/bench.baseline.json` — committed benchmark baseline
- `Makefile` — `run`, `test`, `smoke`, `diagnostics`, `regressions`, `benchmark`, `bench`, `bench-update`, `render-smoke`, `walk-smoke`, `export-smoke`

**House rules (from CLAUDE.md, must follow):**
- Extreme terseness in code and prose. Inline comments lowercase, after code, only when WHY is non-obvious.
- Fail fast. Stick to the diff of the task at hand. Do not auto-refactor outside scope.
- Label unverified claims `[Inference]` / `[Speculation]` / `[Unverified]`.
- LuaJIT is the test runtime (`Makefile: LUAJIT ?= luajit`); LÖVE ships LuaJIT-compatible.

**Determinism contract:** Every task that touches worldgen MUST preserve identical output for the same seed across runs. The encoder in `tests/run.lua:encodeCell` is the contract — if you must extend it, add fields, do not break ordering. The `testDeterminism` test gates this.

**Test contract:** Tasks must keep `make test` green. Tasks may extend the suite, must not delete existing assertions without reason.

---

## How to read a task

```
T-NNN — Title                                     [tier] [risk]

GOAL: one-line "definition of done".
WHY: what gap this closes; impact.
WHERE: file:line anchors to edit.
DEPENDS ON: prior tasks that must land first.
ACCEPTANCE:
  - testable bullet
  - ...
NOTES / IMPL HINTS: free-form.
REFERENCES: URLs with one-line annotations.
```

`[risk]` is: **low** (local refactor), **med** (touches multiple modules / determinism-adjacent), **high** (overhauls core path).

---

# TIER 1 — Performance: stop wasting frames

These are the biggest measurable FPS wins. Land them before geomorphology work because they make later tasks measurable.

---

# TIER 2 — Realistic terrain (geomorphology)

These bring the world closer to actual landscape evolution physics. They are the heart of "true-to-real-world."

---

# TIER 3 — Proteus aesthetic

These convert the current "low-poly muted realism" look into something closer to Ed Key's Proteus: pixel-snapped framebuffer, 2D sprite flora against 3D terrain, palette-driven mood.

---

# TIER 4 — Endless world infrastructure

These extend the world's reach and the engine's ability to handle long sessions.

---

### T-025 — Struct-of-arrays cell storage via LuaJIT FFI         [tier 4] [high]

STATUS: **Partial**. `chunk.arrays = { elevation, slope, flow, temperature, rainfall, sediment, glacialDelta, isostaticRebound, streamPowerDelta }` are now `ffi.new("double[?]", size²)` flat arrays populated alongside `chunk.cells` at chunk finalization (sync + async hydrology paths). `WorldGen.soaFields()` enumerates the available SoA fields. `testChunkSoAArrays` gates array/table consistency.

REMAINING:
- Migrate hot read sites in `src/render.lua`, `src/hydrology.lua`, `src/erosion.lua`, `src/climate.lua` to read `chunk.arrays.field[index]` instead of `cell.field`. This is the actual perf win — currently arrays are populated but consumers still read tables.
- Extend SoA to booleans (water, river, lake, talus, etc.) as `int8` arrays.
- Move string-keyed IDs (biome, basinId, watershedId, etc.) into a parallel sparse ref table per chunk; or accept that strings stay in `cell` tables.
- Remove `chunk.cells` table allocation once consumers are migrated, so memory per chunk actually drops.
- Update encoder in `tests/run.lua:encodeCell` to read from arrays.

ACCEPTANCE (full):
- A `Chunk` is a set of parallel FFI arrays (`elevation`, `temperature`, `rainfall`, `slope`, `flow`, etc.) of size `chunkSize²`. *(double fields landed; boolean + string fields pending.)*
- `cell.field` access replaced with `chunk.field[index]`. *(arrays exposed but consumers not migrated.)*
- Tests still pass (encoder updated to iterate FFI arrays). *(test added but encoder still uses cell tables.)*
- Memory per chunk drops measurably. *(currently goes up because arrays are duplicated; will drop once `chunk.cells` is removed.)*

REFERENCES:
- [LuaJIT FFI Semantics](https://luajit.org/ext_ffi_semantics.html)
- [LuaJIT FFI API](https://luajit.org/ext_ffi_api.html)
- [FFI array performance — luajit mailing list](https://www.freelists.org/post/luajit/FFI-array-performance)

---

# TIER 5 — Engineering hygiene

Small targeted fixes for issues spotted during the audit. Land any time after Tier 1.

---

# TIER 6 — Earth-fidelity geomorphic expansion

These add real-world geomorphic, climatic, lithologic, and biotic processes missing from current Thoth. Substrate tasks (T-034 through T-038) must land first; downstream process passes (T-039+) consume their fields. Tasks reference `[Author Year](url)` for primary sources; formulas and parameter defaults inline so an independent agent can implement from this file + repo state alone.

Current pass order (verified at `src/hydrology.lua:237-294, 612`): `baseSample` (worldgen.lua:633) → `Climate.solveRegion` (hydrology.lua:237) → priority-flood D8 (lines 242-274) → `Erosion.relax` (line 278) → `Erosion.glaciate` (line 288) → river/basin labelling (line 309-321) → `Coast.apply` (line 612) → per-cell `classifyBiome` + `Aeolian.applyCell` (worldgen.lua:828-830) → `buildChunkArrays` (worldgen.lua:841). New passes plug in at the call sites named per task.

---

## Stretch — lower-priority extensions

These provide further fidelity gains but are not gating realism wins. Land after the substrate (T-034 — T-038) when bandwidth allows.

---

### T-055 — Vegetation succession + treeline + riparian + fire    [tier 6] [med]

GOAL: Extend `Biomes.lookup` (biomes.lua:42-55) into multi-pass classifier: (a) climate base via Whittaker, (b) treeline via growing-degree-day proxy, (c) riparian galleries along rivers, (d) fire-shaped savanna/chaparral in seasonal-dry biomes, (e) ecotone blending at boundaries.

WHY: Current biome assignment is a hard LUT — no ecotones, no treeline, no riparian, no fire-shaped biomes. Adding these gives recognizable real biome boundaries.

WHERE: Replace `src/biomes.lua` with multi-pass version. New per-cell `treeline:int8`, `riparian:int8`, `fireFrequency:double`.

DEPENDS ON: T-042 (3-cell climate provides seasonality), T-038.

ACCEPTANCE: River corridors in arid regions show riparian biome; alpine treeline visible as elevation ring; savanna spans seasonal-dry regions. `testBiomeRefinement` gates.

NOTES / IMPL HINTS:
- Treeline: `treeline = (growingDegreeDays < 1100) || (windSpeed > threshold)`. Approximate `GDD ≈ temperature · (1 - latitudeUnit) · 4000`; treeline at `GDD < 1100`.
- Riparian: 1-cell buffer along rivers in non-water cells; assigns `riparian = 1`. In arid regions, biome overlay → `temperate_forest` even if surrounding is `desert`.
- Fire: high in summer-dry climates (Mediterranean-type at 30–40° lat with `monsoonIndex < 0`). Reduce forest cover by `fireFrequency`.
- Ecotone blending: at biome boundary cells, set `cell.biomeSecondary` for transition rendering.

REFERENCES:
- [Whittaker biome diagram — Wikipedia](https://en.wikipedia.org/wiki/Biome).
- [Palubicki Ecoclimates 2022](https://history.siggraph.org/learning/ecoclimates-climate-response-modeling-of-vegetation-by-palubicki-makowski-gajda-hadrich-michels-et-al/).
- [Makowski Synthetic Silviculture 2019](https://www.researchgate.net/publication/334438882_Synthetic_silviculture_multi-scale_modeling_of_plant_ecosystems).

---

### T-056 — Regression fixture rebake + encodeCell append-only    [tier 6] [low]

GOAL: After each TIER 6 task lands, append its new cell fields to `tests/run.lua:encodeCell` (line 37-110) in stated order, and rebake `tests/bench.baseline.json`.

WHY: Test determinism contract requires `encodeCell` to cover all per-cell state. Each new field that affects geometry must enter the encoder; else two seeds-equal worlds could diverge undetected on a non-encoded field.

WHERE: `tests/run.lua:37-110`. Append-only — never reorder existing fields.

DEPENDS ON: Each TIER 6 task above. Run T-056 once per landed task.

ACCEPTANCE: `make test`, `make smoke`, `make diagnostics`, `make regressions`, `make bench-update` all green after each rebake.

NOTES / IMPL HINTS — append in this exact order (one block per landed task):
- T-034: `tostring(cell.lithology), round(cell.erodibilityK), round(cell.lithologyAge)`.
- T-035: `round(cell.regolithDepth), round(cell.bedrockElevation)`.
- T-036: `round(cell.marineTerrace), round(cell.fluvialTerrace), tostring(cell.paleoShoreline)`.
- T-037: `round(cell.latitudeRadians), round(cell.coriolisF)`.
- T-038: (no encoder change — infra only).
- T-039: `round(cell.hillslopeDelta)`.
- T-040: `round(cell.debrisFlowDelta), tostring(cell.debrisFlow)`.
- T-041: `round(cell.iceThickness)` (existing `glacialDelta, glacialErosion, glaciated` already encoded).
- T-042: `tostring(cell.pressureCellId), round(cell.monsoonIndex)`.
- T-043: `round(cell.hotspotContribution), round(cell.hotspotAgeMy), tostring(cell.hotspotId), tostring(cell.isFloodBasalt)`.
- T-044: `round(cell.meanderBend), tostring(cell.oxbowLake)`.
- T-045: `tostring(cell.shorelineNode)`.
- T-046: (folds into existing `cell.elevation` — no new field).
- T-047: (replaces dune fields — no new encoder entries).
- T-048: `tostring(cell.karstType), round(cell.karstDepth), round(cell.cavePresence)`.
- T-049: `tostring(cell.reefStage), round(cell.reefAccretion), round(cell.reefAgeMy)`.
- T-050: `tostring(cell.archetypeId), round(cell.archetypeBlend)`.
- T-051: `tostring(cell.volcanicForm), round(cell.volcanicAgeMy)`.
- T-052: `tostring(cell.periglacialFeature)`.
- T-053: `tostring(cell.submarineCanyon), round(cell.shelfDistance)`.
- T-054: `tostring(cell.soilOrder)`.
- T-055: `tostring(cell.treeline), tostring(cell.riparian), round(cell.fireFrequency)`.

REFERENCES: (none).

---

# Execution order (recommended)

```
Tier 1: T-001 → T-002 → T-005 → T-003 → T-004 → T-007 → T-006 → T-008
Tier 2: T-009 → T-010 → T-011 → T-012 → T-013 → T-014 → T-015 → T-016 → T-017
Tier 3: T-018 → T-019 → T-020 → T-022 → T-021 → T-023
Tier 4: T-024 → T-025 → T-026 → T-027 → T-028 → T-029
Tier 5: T-030, T-031, T-032 (in parallel anywhere)
Tier 6 substrate (must land first, in this order):
  T-038 (FFI int8 SoA infra)
  → T-037 (geographic latitude + Coriolis)
  → T-036 (eustatic sea level)
  → T-035 (regolith + bedrock surface)
  → T-034 (lithology classifier)
Tier 6 process passes (any order subject to listed DEPENDS ON):
  T-046 (GDH1 bathymetry) — independent
  T-042 (3-cell climate) — after T-037, T-038
  T-039 (Roering hillslope) — after T-034, T-035
  T-040 (Jain debris-flow) — after T-039
  T-041 (SIA glaciers) — after T-035
  T-043 (hotspots) — after T-034, T-038
  T-044 (meandering rivers) — independent
  T-045 (Ashton shoreline) — after T-038, T-046
  T-047 (Werner dunes) — independent (climate winds preferred)
  T-048 (karst) — after T-034, T-038
  T-049 (reef succession) — after T-036, T-043
  T-050 (orometry priors) — after T-038
Tier 6 stretch (any order, after substrate):
  T-051 (volcanic landforms) — after T-038, T-043
  T-052 (periglacial) — after T-038
  T-053 (marine bathymetry) — after T-046
  T-054 (CLORPT soil) — after T-034, T-035
  T-055 (vegetation succession) — after T-042
T-056 (regression rebake + encodeCell append) — after each Tier 6 task closes.
T-033 after each tier closes.
```

Rationale: Tier 1 makes everything else measurable. T-009 (noise upgrade) before T-010 (erosion) so the input terrain to erosion is already isotropic. T-018 before T-019 because sprite art must be authored for the target pixel scale. T-024 (clipmap) is the highest-risk refactor and depends on persistent meshes (T-001) and fragment shader (T-002) being stable.

# Definition of Done — global

For any task:
1. `make test` is green.
2. `make smoke` is green.
3. `make diagnostics` is green on default seeds.
4. Determinism preserved (same seed → same world).
5. README + TODO updated if user-facing.
6. Manual visual check via `make run` for any rendering change.
7. Performance no worse than baseline for non-Tier-1 work; Tier-1 work must demonstrably improve baseline.

# Aggregated reference index

**Proteus**
- [Proteus — Wikipedia](https://en.wikipedia.org/wiki/Proteus_(video_game))
- [Proteus — Twisted Tree](https://twistedtreegames.com/proteus/)

**Terrain — physics-based simulation**
- [Cordonnier et al. 2016 — Tectonic Uplift + Fluvial Erosion (PDF)](https://www.cs.purdue.edu/cgvlab/www/resources/papers/Cordonnier-Computer_Graphics_Forum-2016-Large_Scale_Terrain_Generation_from_Tectonic_Uplift_and_Fluvial_.pdf)
- [Braun & Willett 2013 — O(n) implicit stream power](https://www.researchgate.net/publication/236741975_A_very_efficient_On_implicit_and_parallel_method_to_solve_the_stream_power_equation_governing_fluvial_incision_and_landscape_evolution)
- [Yuan/Braun/Guerit/Rouby/Cordonnier 2019 — Sediment deposition (JGR)](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2018JF004867)
- [Cordonnier et al. SIGGRAPH 2023 — Glacial Erosion (HAL)](https://inria.hal.science/hal-04090644/file/Sigg23_Glacial_Erosion__author.pdf)
- [Krištof 2009 — Hydraulic Erosion via SPH](https://cgg.mff.cuni.cz/~jaroslav/papers/2009-eg-sph/eg09-krystof-sph_erosion.pdf)
- [Barnes/Lehman/Mulla 2014 — Priority-Flood (PDF)](https://rbarnes.org/sci/2014_depressions.pdf)
- [Smith & Barstad 2004 — Linear Theory of Orographic Precipitation (JAS)](https://journals.ametsoc.org/view/journals/atsc/61/12/1520-0469_2004_061_1377_altoop_2.0.co_2.xml)
- [Inigo Quilez — Domain Warping](https://iquilezles.org/articles/warp/)
- [Visually Improved Erosion Algorithm (arXiv 2210.14496)](https://arxiv.org/pdf/2210.14496)
- [nickmcd.me — Procedural Weather Patterns](https://nickmcd.me/2018/07/10/procedural-weather-patterns/)
- [nickmcd.me — Clustered Convection (Plate Tectonics)](https://nickmcd.me/2020/12/03/clustered-convection-for-simulating-plate-tectonics/)
- [Whittaker biome diagram — Wikipedia "Biome"](https://en.wikipedia.org/wiki/Biome)
- [AutoBiomes (Springer)](https://link.springer.com/article/10.1007/s00371-020-01920-7)

**Rendering & engine**
- [Losasso & Hoppe — Geometry Clipmaps](https://hhoppe.com/proj/geomclipmap/)
- [GPU Gems 2 Ch. 2 — Terrain via Geometry Clipmaps](https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-2-terrain-rendering-using-gpu-based-geometry)
- [Aokana 2025 — GPU-Driven Voxel Rendering (arXiv 2505.02017)](https://arxiv.org/abs/2505.02017)
- [LÖVE Mesh:setVertices](https://love2d.org/wiki/Mesh:setVertices)
- [LÖVE love.graphics.newMesh](https://love2d.org/wiki/love.graphics.newMesh)
- [LÖVE Beginner's Guide to Shaders](https://blogs.love2d.org/content/beginners-guide-shaders)
- [LÖVE SpriteBatch](https://love2d.org/wiki/SpriteBatch)
- [LÖVE love.thread](https://love2d.org/wiki/love.thread)
- [LÖVE love.filesystem](https://love2d.org/wiki/love.filesystem)
- [LuaJIT FFI Semantics](https://luajit.org/ext_ffi_semantics.html)
- [LuaJIT FFI API](https://luajit.org/ext_ffi_api.html)
- [LuaJIT `bit` API](https://bitop.luajit.org/api.html)
- [openresty/lua-resty-lrucache](https://github.com/openresty/lua-resty-lrucache)
- [starius/lua-lru](https://github.com/starius/lua-lru)
- [behreajj/AsepriteOpenSimplex (Lua OpenSimplex2 port)](https://github.com/behreajj/AsepriteOpenSimplex)
- [KdotJPG/OpenSimplex2 (reference)](https://github.com/KdotJPG/OpenSimplex2)

**Aesthetic / palette / pixel-art**
- [Angled pixelation with palette quantization (Godot Shaders)](https://godotshaders.com/shader/angled-pixelation-with-color-palette-quantization-and-fog/)
- [LÖVE pixel-perfect rendering thread](https://love2d.org/forums/viewtopic.php?t=91869)
- [LÖVE pixel-art scaling thread](https://love2d.org/forums/viewtopic.php?t=9374)

**Tier 6 — tectonics & volcanism**
- [Cortial et al. 2019 — Procedural Tectonic Planets (CGF)](https://onlinelibrary.wiley.com/doi/abs/10.1111/cgf.13614)
- [Tectonics.js — davidson16807](https://davidson16807.github.io/tectonics.js/blog/)
- [Wessel & Kroenke 2024 — Hawaii-Emperor hotspot chain (Nature Comms)](https://www.nature.com/articles/s41467-024-51055-9)
- [Stein & Stein 1992 — GDH1 crust-age bathymetry (Nature)](https://doi.org/10.1038/359123a0)
- [Crosby & McKenzie 2009 — thermal subsidence (GJI)](https://doi.org/10.1111/j.1365-246X.2009.04085.x)
- [Anbar & Knoll 2002 — lithology distribution (Science)](https://www.science.org/doi/10.1126/science.1069651)
- [Flowy 2024 — probabilistic lava emplacement (arXiv)](https://arxiv.org/pdf/2405.20144)
- [Pretorius et al. 2024 — Volcanic Skies (CGF)](https://onlinelibrary.wiley.com/doi/full/10.1111/cgf.15034)

**Tier 6 — hillslope, debris, fluvial geomorphology**
- [Roering, Kirchner & Dietrich 1999 — nonlinear hillslope (WRR)](https://doi.org/10.1029/1998WR900090)
- [Roering, Kirchner & Dietrich 2001 — Gabilan Mesa calibration (JGR)](https://doi.org/10.1029/2001JB000323)
- [Roering 2008 — review (GSA Bull)](https://doi.org/10.1130/B26283.1)
- [Heimsath et al. 1997 — bedrock production (Nature)](https://doi.org/10.1038/41056)
- [Heimsath 2001 — Oregon coast calibration (ESPL)](https://doi.org/10.1002/esp.260)
- [Yoo & Mudd 2008 — bulking ratio (JGR)](https://doi.org/10.1029/2007JF000846)
- [Jain et al. 2024 — Debris-flow erosion (TOG)](https://www.cs.purdue.edu/cgvlab/www/resources/papers/Arymaan-ToG-2024-efficient.pdf)
- [Iverson 1997 — debris-flow physics (Rev Geophys)](https://doi.org/10.1029/97RG00426)
- [Howard & Knutson 1984 — curvature-driven meander migration (WRR)](https://doi.org/10.1029/WR020i011p01659)
- [Ikeda, Parker & Sawai 1981 — upstream influence kernel (JFM)](https://doi.org/10.1017/S0022112081002231)
- [Vimont et al. 2023 — Authoring meandering rivers (TOG)](https://dl.acm.org/doi/10.1145/3618350)

**Tier 6 — glacial & periglacial**
- [Cordonnier et al. SIGGRAPH 2023 — Glacial Erosion (HAL)](https://inria.hal.science/hal-04090644/file/Sigg23_Glacial_Erosion__author.pdf)
- [Hallet 1979 — glacial abrasion law (J Glaciol)](https://doi.org/10.3189/S0022143000029798)
- [Herman et al. 2015 — sliding-velocity² (EPSL)](https://doi.org/10.1016/j.epsl.2015.06.035)
- [Cuffey & Paterson — Physics of Glaciers 4e](https://www.elsevier.com/books/the-physics-of-glaciers/cuffey/978-0-12-369461-4)
- [Periglacial landforms — AntarcticGlaciers.org](https://www.antarcticglaciers.org/glacial-geology/glacial-landforms/periglaciation/periglacial-landforms/)

**Tier 6 — aeolian, karst, coastal**
- [Werner 1995 — cellular dune model (Geology)](https://doi.org/10.1130/0091-7613(1995)023%3C1107:EDCSAA%3E2.3.CO;2)
- [Real-Time Sand Dune Simulation ACM 2023](https://dl.acm.org/doi/abs/10.1145/3585510)
- [Parteli et al. 2013 — barchan asymmetry (arXiv)](https://arxiv.org/pdf/1304.6573)
- [Paris et al. 2021 — Cave network synthesis (CGF)](https://onlinelibrary.wiley.com/doi/10.1111/cgf.14420)
- [Peytavie/Galin — Arches framework (Semantic Scholar)](https://www.semanticscholar.org/paper/Arches:-a-Framework-for-Modeling-Complex-Terrains-Peytavie-Galin/e8b83d99ea6121c13df3570b4f8d3697257b1c2b)
- [Ford & Williams 2007 — Karst Hydrogeology](https://onlinelibrary.wiley.com/doi/book/10.1002/9781118684986)
- [Ashton, Murray & Arnoult 2001 — shoreline instability (Nature)](https://doi.org/10.1038/35104541)
- [Ashton & Murray 2006a — high/low-angle (JGR)](https://doi.org/10.1029/2005JF000422)
- [ShorelineS framework (Frontiers 2020)](https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2020.00535/full)
- [Darwin 1842 — Coral Reef succession](https://www.gutenberg.org/files/2690/2690-h/2690-h.htm)
- [Toomey, Ashton & Perron 2013 — modern reef dynamics (Geology)](https://pubs.geoscienceworld.org/gsa/geology/article/41/7/731/130911)
- [Harris & Whiteway 2011 — submarine canyon morphology (Marine Geol)](https://doi.org/10.1016/j.margeo.2011.05.008)

**Tier 6 — climate, soils, vegetation**
- [Hadley cell — Wikipedia](https://en.wikipedia.org/wiki/Hadley_cell)
- [Schneider, Bischoff & Haug 2014 — ITCZ migration (Nature)](https://www.nature.com/articles/nature13636)
- [Palubicki et al. 2022 — Ecoclimates (SIGGRAPH)](https://history.siggraph.org/learning/ecoclimates-climate-response-modeling-of-vegetation-by-palubicki-makowski-gajda-hadrich-michels-et-al/)
- [Makowski et al. 2019 — Synthetic Silviculture](https://www.researchgate.net/publication/334438882_Synthetic_silviculture_multi-scale_modeling_of_plant_ecosystems)
- [USDA Soil Taxonomy](https://www.nrcs.usda.gov/resources/guides-and-instructions/keys-to-soil-taxonomy)
- [Soil formation / CLORPT — Wikipedia](https://en.wikipedia.org/wiki/Soil_formation)
- [Weigert SoilMachine](https://github.com/weigert/SoilMachine)

**Tier 6 — eustatic sea level**
- [Haq, Hardenbol & Vail 1987 — eustatic curve (Science)](https://www.science.org/doi/10.1126/science.235.4793.1156)
- [Miller et al. 2005 — Phanerozoic sea level (Science)](https://www.science.org/doi/10.1126/science.1116412)

**Tier 6 — orometry priors / real-world data fusion**
- [Argudo & Galin 2019 — Orometry-based terrain (HAL)](https://hal.science/hal-02326472/file/2019-orometry.pdf)
- [oargudo/orometry-terrains GitHub](https://github.com/oargudo/orometry-terrains)
- [USGS EarthExplorer SRTM](https://earthexplorer.usgs.gov/)
