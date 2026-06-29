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

# Execution order (recommended)

```
Tier 1: T-001 → T-002 → T-005 → T-003 → T-004 → T-007 → T-006 → T-008
Tier 2: T-009 → T-010 → T-011 → T-012 → T-013 → T-014 → T-015 → T-016 → T-017
Tier 3: T-018 → T-019 → T-020 → T-022 → T-021 → T-023
Tier 4: T-024 → T-025 → T-026 → T-027 → T-028 → T-029
Tier 5: T-030, T-031, T-032 (in parallel anywhere)
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
