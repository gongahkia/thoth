# TODO

## 0. Project context (one screen)

**What Thoth is today:** A LÖVE 11.5 (Lua) prototype of a first-person, endlessly-explored procedural terrain. ~3.2 kLOC. Deterministic seed-driven. Three nested view scales (local/region/continent, factors 1/4/16). Solid geomorphology vocabulary (plates, subduction, rifts, cratons, deltas, lakes, watersheds) and a real Priority-Flood depression-fill + D8 flow hydrology layer. CPU-only rendering via per-frame `love.graphics.newMesh(..., "stream")`. No shaders, no canvases, no threads.

**Three north-star goals (from the user):**
1. Rendering style similar to *Proteus* (Ed Key / Twisted Tree, 2013): pixel-art look, 2D sprite flora/fauna against 3D terrain, mood-driven palette, low-poly chunky hills.
2. Realistic terrain generation that is true-to-real-world geomorphology — i.e. iterative physically-based simulation, not just additive noise.
3. High FPS in an endlessly generated world.

**File map (verified):**
- `main.lua` — LÖVE entrypoint, perf log harness, CLI flags
- `conf.lua` — window 1280×720, physics+video off
- `src/worldgen.lua` (622 LOC) — plates, biome classifier, chunk/billboard caches, `heightAt`/`normalAt`
- `src/hydrology.lua` (629 LOC) — Priority-Flood, D8, basin pre-pass, lake grouping
- `src/noise.lua` (58 LOC) — value-noise + FBM + ridge + domain warp
- `src/rng.lua` (50 LOC) — deterministic hash
- `src/render.lua` (549 LOC) — pseudo-3D CPU mesh build + draw
- `src/viewscale.lua` (235 LOC) — three-scale easing transitions
- `src/player.lua` (31 LOC) — WASD movement + slope/water slowdown
- `src/survey.lua` (49 LOC) — marked-cell history
- `src/diagnostics.lua` (224 LOC) — seed sweep with bound thresholds
- `src/export.lua` (100 LOC) — PNG/PPM map export
- `tests/run.lua` (689 LOC) — 25 deterministic tests, smoke harness, diagnostics CLI
- `Makefile` — `run`, `test`, `smoke`, `diagnostics`, `render-smoke`, `walk-smoke`, `export-smoke`

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

GOAL: Per-chunk cell data lives in FFI `ctype` arrays of doubles, not 4096 tables × ~30 keys each. SoA layout for cache-friendliness.

WHY: `worldgen.lua` cells are tables with 30+ string-keyed fields (encoder dumps 47). Iteration cost is dominated by hash lookups in Lua. The FFI-array benchmark cited in the LuaJIT docs shows 1.27 ns/element (double array) vs 75 ns/element (struct of one double) — i.e. native double arrays are dramatically faster.

WHERE: All of `src/worldgen.lua` and `src/hydrology.lua` consumer/producer sites.

DEPENDS ON: T-001 (so mesh layer can also benefit), T-005 (cache eviction must free FFI memory cleanly).

ACCEPTANCE:
- A `Chunk` is a set of parallel FFI arrays (`elevation`, `temperature`, `rainfall`, `slope`, `flow`, etc.) of size `chunkSize²`.
- `cell.field` access replaced with `chunk.field[index]`.
- Tests still pass (encoder updated to iterate FFI arrays).
- Memory per chunk drops measurably (LuaJIT docs cite 35× reduction in a similar case).

NOTES / IMPL HINTS:
- Use `ffi.new("double[?]", size)` for each field array; or one big struct array if you prefer AoS. SoA is better for the hot inner loops.
- Caveat from research: nested struct init is not JIT-compiled in inner loops — keep types flat.
- This is a large refactor. Schedule it after Tier 1–3 ship; otherwise everything else has to be rewritten on top.

REFERENCES:
- [LuaJIT FFI Semantics](https://luajit.org/ext_ffi_semantics.html)
- [LuaJIT FFI API](https://luajit.org/ext_ffi_api.html)
- [FFI array performance — luajit mailing list](https://www.freelists.org/post/luajit/FFI-array-performance)

---

### T-028 — Save / load state         [tier 4] [low]

GOAL: `F5` saves seed, player position, view scale, survey, options to `love.filesystem.getSaveDirectory()`. `F9` restores.

WHY: `TODO.md` lists this. Without save/load no long-session play.

WHERE: `main.lua` (key handler), new `src/save.lua`.

DEPENDS ON: none.

ACCEPTANCE:
- `F5` writes JSON (or Lua-table-string) save file with: seed, player x/y, view scale, survey history.
- `F9` reads back; world resumes at saved location with identical terrain (determinism).
- New `testSaveRoundtrip` re-loads and asserts state equality.

NOTES / IMPL HINTS:
- LÖVE's `love.filesystem` provides safe write/read.
- Don't bother serializing caches; they re-warm.

REFERENCES:
- [love.filesystem — LÖVE wiki](https://love2d.org/wiki/love.filesystem)

---

# TIER 5 — Engineering hygiene

Small targeted fixes for issues spotted during the audit. Land any time after Tier 1.

---

### T-033 — Document everything: README sync         [tier 5] [low]

GOAL: README and TODO updated to reflect all Tier-1..3 changes. Adopted CLI flags documented.

WHY: README will drift as tasks land. Keep it sync'd.

WHERE: `README.md`, `TODO.md`.

DEPENDS ON: after each tier is complete.

ACCEPTANCE:
- README mentions: pixel-perfect canvas, async hydrology, palette swap, save/load, geometry clipmap (if landed), bench harness.
- TODO has resolved items struck out or removed.

REFERENCES: none required.

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
