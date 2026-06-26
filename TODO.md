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

### T-009 — Replace value-noise with OpenSimplex2         [tier 2] [med]

GOAL: `src/noise.lua` returns OpenSimplex2 noise (gradient-based, isotropic). FBM, ridge, warp all wrap the new primitive.

WHY: `noise.lua:17–25` is corner-lerped value noise. Visible square grid artifacts at low octaves, especially in domain-warped fields. Modern standard is Simplex / OpenSimplex2: visually isotropic, no axis-aligned bias, similar cost.

WHERE: `src/noise.lua` entirely.

DEPENDS ON: T-008 if you change the seed hash, otherwise none. Snapshot diffs expected.

ACCEPTANCE:
- `Noise.value(seed, x, y, salt)` returns 0–1 gradient noise from OpenSimplex2.
- All existing call sites (`fbm`, `ridge`, `warp`) unchanged.
- Manual screenshot review confirms no axis-aligned banding in low-octave fields.
- All tests re-blessed; `testDeterminism` and `testSeedVariance` still meaningful.

NOTES / IMPL HINTS:
- Port `behreajj/AsepriteOpenSimplex` (Lua port of KdotJPG's reference) — `OpenSimplex2S` variant. It's MIT/CC0.
- For 2D only; you don't need 3D/4D yet. ~150 LOC.
- Keep the existing function names and signatures; this is an internal swap.

REFERENCES:
- [KdotJPG/OpenSimplex2 — GitHub](https://github.com/KdotJPG/OpenSimplex2) — reference impl, multiple language ports.
- [behreajj/AsepriteOpenSimplex — GitHub](https://github.com/behreajj/AsepriteOpenSimplex) — Lua port of OpenSimplex2S.

---

### T-010 — Iterative Stream Power Law (Braun-Willett O(n))         [tier 2] [high]

GOAL: New module `src/erosion.lua`. On the coarse basin grid, iterate dh/dt = U − K·A^m·S^n with implicit O(n) ordering from Braun & Willett (2013). Output goes back into `cell.elevation`, not just `cell.erosion`.

WHY: Current `hydrology.lua:472–504` applies erosion as a single multiplicative factor that doesn't feed back into elevation iteratively. Real river valleys form from the equilibrium between uplift (U) and stream-power incision (K·A^m·S^n). Cordonnier et al. 2016 introduced this to CG; FastScape (Braun-Willett) is the O(n) implicit solver. ~100–300 iterations on coarse grid converges visually.

WHERE:
- New `src/erosion.lua`.
- `src/hydrology.lua:170–275` (`solveBasin`) — extend to call `Erosion.relax(region)` after the flow-accumulation step.
- `src/worldgen.lua:301–374` (`baseSample`) — read post-erosion elevation if available.

DEPENDS ON: T-005 (cache).

ACCEPTANCE:
- New `Erosion.relax(region, { iterations = 80, K = 0.0006, m = 0.5, n = 1.0, uplift = "plateBased" })` mutates `cell.elevation` in-place.
- Visual: ridge lines sharpen, valleys deepen, drainage networks become dendritic instead of straight downhill.
- Diagnostics: mean slope in non-mountain biomes drops; mean slope in plate-boundary regions increases.
- New test `testStreamPowerConvergence` — after N iterations, max-elevation delta between iterations falls below `1e-4`.
- Determinism preserved.

NOTES / IMPL HINTS:
- Braun-Willett ordering: build a list of nodes sorted by elevation (Priority-Flood already produces `visitOrder` from low to high). Iterate from highest to lowest; for each node compute `h_new = (h_old + dt·U + K·dt·A^m·h_down / dx^n) / (1 + K·dt·A^m / dx^n)` (the implicit step).
- `A` is upstream drainage area = `cell.flow` (already accumulated).
- `U` (uplift rate) comes from `cell.uplift` + `plate.convergent * plate.boundary`.
- `dt` controls convergence speed; tune so that 80 iterations are visually stable.
- Run on the coarse basin grid only (stride 4–8) — that's where it pays off; detail grid stays one-shot to keep solve time bounded.

REFERENCES:
- [Braun & Willett 2013 — O(n) implicit method (Geomorphology)](https://www.researchgate.net/publication/236741975_A_very_efficient_On_implicit_and_parallel_method_to_solve_the_stream_power_equation_governing_fluvial_incision_and_landscape_evolution)
- [Cordonnier et al. 2016 — Large Scale Terrain Generation from Tectonic Uplift and Fluvial Erosion (PDF)](https://www.cs.purdue.edu/cgvlab/www/resources/papers/Cordonnier-Computer_Graphics_Forum-2016-Large_Scale_Terrain_Generation_from_Tectonic_Uplift_and_Fluvial_.pdf)
- [Cordonnier preview — Semantic Scholar](https://www.semanticscholar.org/paper/Large-Scale-Terrain-Generation-from-Tectonic-Uplift-Cordonnier-Braun/edfae1a0c5e58a3bb2c97255d43e3b48e902ee27)
- [Terrain Erosion on the GPU — aparis69](https://aparis69.github.io/public_html/posts/terrain_erosion.html) — practical CG perspective.

---

### T-011 — Sediment-aware deposition (Yuan-Braun-Guerit-Rouby-Cordonnier 2019)         [tier 2] [high]

GOAL: Erosion solver advects a sediment field; rivers deposit when transport capacity is exceeded, building floodplains and alluvial fans from physics, not thresholds.

WHY: `hydrology.lua:498–504` paints `floodplain` / `alluvialFan` / `delta` from threshold checks on flow+slope. That's labeling, not deposition. Real floodplains form where stream-power drops below sediment carrying capacity.

WHERE:
- `src/erosion.lua` (from T-010), add `sediment` field per cell.
- `src/hydrology.lua:472–504` — replace threshold-tag landform code with sediment-thickness-derived tags.

DEPENDS ON: T-010.

ACCEPTANCE:
- Each basin cell tracks `sediment` (>=0); erosion adds, deposition removes.
- `floodplain`/`alluvialFan`/`delta` flags derived from `sediment > threshold` *and* topographic context (slope, distance to channel).
- Visual: alluvial fans appear at break-of-slope below mountains; floodplains widen downstream; deltas grow where rivers hit standing water.
- `testErosionLandforms` updated assertions (still must produce >0 of each type).

NOTES / IMPL HINTS:
- Yuan et al. 2019 formula: deposition rate ∝ G·Q_s / Q (where Q is water discharge, Q_s is sediment flux, G is dimensionless deposition coefficient). When solver finds Q_s > capacity, dump excess as sediment.

REFERENCES:
- [Yuan, Braun, Guerit, Rouby, Cordonnier 2019 (JGR)](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2018JF004867)
- [HAL preprint](https://hal.science/hal-02136641)

---

### T-012 — Orographic precipitation (Smith-Barstad linear theory, lite)         [tier 2] [high]

GOAL: Rainfall on the coarse basin grid is computed from a wind field and the terrain's windward/leeward orientation. Replaces current latitude+noise rainfall.

WHY: `worldgen.lua:325–328` computes rainfall from `latitude + FBM − tiny uplift penalty`. No physical relationship to wind direction → mountains. Rain shadows are *labeled* (in `discoveriesAt`) but not *generated*. Smith & Barstad 2004 is the standard linearized model.

WHERE:
- New `src/climate.lua`.
- `src/worldgen.lua:325–328` — `rainfall` read from `climate.precipitationAt(...)` rather than computed inline.

DEPENDS ON: T-009 (good noise primitive), T-010 (coarse grid already in place).

ACCEPTANCE:
- `Climate.solveRegion(world, basinRegion)` produces a `precipitation` field per basin cell.
- Wind direction is a function of latitude (trade-easterlies, westerlies, polar easterlies — three bands).
- Visible rain shadow: leeward side of mountain ranges has measurably lower precipitation than windward side (diagnostics check: `precipitation(windward) > 1.5 × precipitation(leeward)` for steep ranges).
- `rain_shadow` discovery overlay now lights up the *actual* dry side, not just any high+dry cell.

NOTES / IMPL HINTS:
- Lite version: advect a moisture quantity `m` along the wind direction. At each cell, condensation rate is proportional to upslope velocity component (wind · ∇h). Subtract condensed amount from `m`; add to `precipitation[cell]`. Continue advecting downstream.
- Full Smith-Barstad uses FFT-based linear-wave solution; overkill here. The simple upslope/advection scheme captures the rain-shadow phenomenon well enough.
- Latitude wind direction: e.g. `windX = cos(latitude_band_angle)`, `windY = sin(...)`. Three bands: 0–30 lat (easterlies), 30–60 (westerlies), 60–90 (easterlies).
- Coriolis-like deflection: optional ±15° rotation; ship without it first.

REFERENCES:
- [Smith & Barstad 2004 — A Linear Theory of Orographic Precipitation (JAS)](https://journals.ametsoc.org/view/journals/atsc/61/12/1520-0469_2004_061_1377_altoop_2.0.co_2.xml)
- [Nick McDonald — Procedural Weather Patterns blog](https://nickmcd.me/2018/07/10/procedural-weather-patterns/) — practical games-engineering approach.
- [orographic_precipitation Python package — PyPI](https://pypi.org/project/orographic_precipitation/) — reference implementation of Smith-Barstad you can read.

---

### T-013 — Whittaker biome lookup table         [tier 2] [low]

GOAL: `classifyBiome(elevation, water, river, T, P, slope, lake)` switches from rule-chain to a 2D lookup table `biome[T_bin][P_bin]`.

WHY: `worldgen.lua:161–176` is a 9-line if/elif tower. Visible step-changes at thresholds; biome boundaries look gridded. Whittaker's classification uses mean annual T × mean annual P → biome. Cleaner, smoother, and matches real ecology.

WHERE: `src/worldgen.lua:161–176`.

DEPENDS ON: T-012 (better moisture field gives Whittaker better signal).

ACCEPTANCE:
- New `src/biomes.lua` with a `lookup(temperature, precipitation, elevation, water, slope) -> biomeId` function.
- Lookup is a precomputed 2D grid (e.g. 16×16 bins covering normalized T,P). Cells map to biome IDs.
- Border cells optionally blend (return weighted neighbor) for smoother transitions.
- The 15 existing biome IDs in `worldgen.lua:20–36` are preserved.
- Diagnostics: `biomeCount` increases; `singleBiomeMax` ratio decreases for default seeds.
- `testBiomes` still passes; new `testWhittakerBins` asserts each combination of (cold/temperate/hot) × (arid/mesic/wet) maps to a sensible biome.

NOTES / IMPL HINTS:
- Whittaker's diagram: x = precipitation (cm/yr, 0 to ~450), y = temperature (°C, −15 to +30). Map your normalized 0..1 ranges into those.
- Reference table: Wikipedia "Biome" diagram has the classic Whittaker chart; the Springer AutoBiomes paper has a CG-ready discretization.
- Water/lake/river/coast cases short-circuit before lookup (those are not climate-driven biomes).

REFERENCES:
- [Whittaker biome diagram — Wikipedia "Biome"](https://en.wikipedia.org/wiki/Biome)
- [AutoBiomes paper (Visual Computer)](https://link.springer.com/article/10.1007/s00371-020-01920-7) — game-suitable Whittaker variant.

---

### T-014 — Glacial erosion mask + U-valley carving         [tier 2] [med]

GOAL: A glacial-erosion pass runs on cells above an elevation+latitude threshold; it widens valleys (U-shape) where ice once flowed.

WHY: No glacial features today. U-valleys and fjords are signature high-latitude landforms; their absence makes Thoth's snowy zones look like rocky deserts.

WHERE:
- `src/erosion.lua` (or new `src/glaciers.lua`) — apply after stream-power converges.
- `src/worldgen.lua` biome rules — fjord/glacier biome ids optionally added (keep id set lean if undesired).

DEPENDS ON: T-010.

ACCEPTANCE:
- Cells flagged "glaciated" where `temperature < t_freeze` AND `elevation > h_snowline` AND drainage area > threshold.
- For glaciated cells, apply lateral widening: lower neighbors within radius R, slight terrace effect on valley walls.
- Visual: clear U-shaped cross-sections in alpine valleys; flat valley floors with steep sides.
- New `testGlacialFeatures` seeds an alpine fixture and asserts at least one glaciated reach exists.

NOTES / IMPL HINTS:
- Shallow Ice Approximation is the rigorous approach. For a procgen prototype, a heightfield filter that takes the max of `(h, neighbor_h - flat_offset)` over a radius proportional to drainage area gives the visual signature.
- See Cordonnier et al. SIGGRAPH 2023 glacial work for the modern reference.

REFERENCES:
- [Cordonnier et al. — Forming Terrains by Glacial Erosion (HAL)](https://inria.hal.science/hal-04090644/file/Sigg23_Glacial_Erosion__author.pdf)
- [Terrain generation using glacial and tectonic models — ResearchGate](https://www.researchgate.net/publication/317267554_Terrain_generation_using_glacial_and_tectonic_models)

---

### T-015 — Coastal wave erosion + beach deposition         [tier 2] [med]

GOAL: At the land-water boundary, cells experience a wave-power pass: high-wave-exposure cliffs steepen, sheltered cells accumulate beach sediment.

WHY: Coasts today are just `elevation <= seaLevel` cliffs. No beaches, no sea cliffs, no headlands/bays differentiation.

WHERE:
- New `src/coast.lua`, or extend `src/erosion.lua`.
- `src/worldgen.lua` biome rules — extend `coast` biome with cliff/beach sub-tags.

DEPENDS ON: T-010 (stable elevation field), T-012 (wind direction available — drives wave direction).

ACCEPTANCE:
- Cells flagged `coastCliff` or `coastBeach`.
- Visual: windward shores have steep cliffs; leeward shores have flatter beaches with sediment.
- Render colors differ for cliff vs beach (palette extension).
- `testCoastlines` asserts both cliff and beach cells exist across a 4-seed sweep.

NOTES / IMPL HINTS:
- Wave exposure = `dot(windDirection, coastNormal)`. Where `coastNormal` is the outward normal at the land-water edge.
- High exposure → erode (lower `elevation` near edge); low exposure → deposit (add sediment thickness).
- This is qualitative, not geophysics-rigorous. That's fine.

REFERENCES: none specific; geomorphology textbook chapter on coastal processes suffices. The Visually Improved Erosion paper covers tile-based coastline tactics:
- [Visually Improved Erosion Algorithm — arXiv 2210.14496](https://arxiv.org/pdf/2210.14496)

---

### T-016 — Aeolian erosion (dunes) in arid biomes         [tier 2] [low]

GOAL: A pass on `desert` biome cells that builds dune patterns from wind direction and noise.

WHY: Deserts today are uniform pale-yellow. Real dunes have barchan/transverse/longitudinal structure that's a clear visual win.

WHERE: New `src/aeolian.lua`. Called from worldgen after biome assignment, modifies `elevation` by small amounts.

DEPENDS ON: T-012 (wind direction), T-013 (Whittaker biomes — gives stable desert mask).

ACCEPTANCE:
- Dune crests are visible at local scale, perpendicular to wind in transverse setting.
- Elevation deltas are small (< 0.04) so they don't shift biome classification.
- `testAeolianDunes` asserts dune cells have non-zero `duneAmplitude` field.

NOTES / IMPL HINTS:
- Cheap effect: `h += A * sin((x * windX + y * windY) * f) * desertMask`. Add noise-modulated phase for irregularity.
- More accurate: lattice-Boltzmann or sand-slab models — overkill here.

REFERENCES: none required; standard procgen trick.

---

### T-017 — Isostatic rebound coupling         [tier 2] [med]

GOAL: After erosion strips mass from a mountain, surrounding crust rises slightly. Mountains stay tall longer than naive erosion would predict.

WHY: Real Earth: 5 m eroded → 4 m rebound (verified by web research). Without this, eroded mountains flatten too aggressively. [Inference] hard to notice in static seeds but matters once T-027 (plate motion over time) lands.

WHERE: `src/erosion.lua` — between stream-power iterations.

DEPENDS ON: T-010.

ACCEPTANCE:
- After each erosion iteration, eroded mass × 0.8 is added back to a Gaussian-smoothed support region around each cell.
- Diagnostics: mean elevation at plate-boundary regions is higher than without rebound, given the same iteration count.
- `testIsostasy` checks conservation: total mass added back ≈ 0.8 × total mass eroded.

NOTES / IMPL HINTS:
- Smoothing kernel radius ~ crust elastic length scale; in arbitrary units pick ~stride * 4 cells.
- Skip if performance is a concern; this is the lowest-value Tier-2 task.

REFERENCES:
- [Biology Insights — Do Mountains Have Roots? (Isostasy explainer)](https://biologyinsights.com/do-mountains-have-roots-the-science-of-isostasy/)
- [Numerical models of ductile rebound of crustal roots (GJI)](https://academic.oup.com/gji/article/139/2/556/553427)

---

# TIER 3 — Proteus aesthetic

These convert the current "low-poly muted realism" look into something closer to Ed Key's Proteus: pixel-snapped framebuffer, 2D sprite flora against 3D terrain, palette-driven mood.

---

### T-018 — Low-res Canvas + nearest upscale framebuffer         [tier 3] [med]

GOAL: All scene rendering targets a Canvas at, e.g. 640×360 (half-window). On present, that Canvas is upscaled with nearest-neighbor to the window. HUD draws on top at native resolution.

WHY: Proteus's chunky pixel look comes from a low-res framebuffer scaled up. You already set `setDefaultFilter("nearest","nearest")` (`main.lua:281`) but never use a Canvas, so individual primitives are smooth at native res.

WHERE:
- `src/render.lua:511–547` — `Render.draw`.
- New `src/postfx.lua` or inline — Canvas allocation, draw-to-canvas, present.

DEPENDS ON: T-002 if you want fog/shading on the Canvas pass.

ACCEPTANCE:
- A new `app.lowResCanvas` of dimensions `floor(window.w / scale)` × `floor(window.h / scale)` with `scale ∈ {2, 3, 4}` configurable via CLI `--pixel-scale`.
- Scene draws to this Canvas; HUD draws to default after presenting.
- Visible pixelation; no per-frame Canvas allocation.
- Resize-safe (re-create on `love.resize`).

NOTES / IMPL HINTS:
- `love.graphics.setCanvas(canvas)`; draw scene; `setCanvas()` (default); `draw(canvas, 0, 0, 0, scale, scale)`.
- Pre-set `setDefaultFilter("nearest","nearest")` (already done) ensures upscale is hard-edged.

REFERENCES:
- [How to do pixel-perfect rendering in löve? — forums](https://love2d.org/forums/viewtopic.php?t=91869)
- [Pixel-art scaling — LÖVE forums](https://love2d.org/forums/viewtopic.php?t=9374)
- [Pixelart - Canvas rendering question — LÖVE forums](https://love2d.org/forums/viewtopic.php?t=83702)

---

### T-019 — 2D sprite atlas for flora and fauna         [tier 3] [med]

GOAL: Trees, shrubs, peaks, reeds, etc. are real pixel-art sprites in a single atlas image, drawn via SpriteBatch (see T-003) instead of polygonal primitives.

WHY: Proteus is built on 2D sprite vegetation contrasted with 3D terrain. Your current vector polygons (`render.lua:391–406`) read as low-poly debug shapes, not pixel-art flora.

WHERE:
- New `assets/billboards.png` — texture atlas.
- `src/render.lua:309–407` — billboard pipeline.
- `src/worldgen.lua:566–601` (`billboardSpecFor`) — `kind` already returns the right enum; render side maps to atlas quad.

DEPENDS ON: T-003 (SpriteBatch), T-018 (low-res Canvas — sprites must look right at the target pixel scale).

ACCEPTANCE:
- Atlas exists with at minimum: tree (deciduous + conifer + dead variant), shrub, reed, rock, outcrop, peak, snow-tuft. 32×32 or 64×64 cells.
- Each `billboard.kind` maps to a quad in the atlas.
- Sprites are billboarded (always face camera; rotate only around z-axis if at all).
- Tinting per-instance still works (via `SpriteBatch:setColor` before each `add`).

NOTES / IMPL HINTS:
- Don't draw sprites yourself; this is asset work. Either commission/source CC0 sprites, or generate them programmatically once (a `tools/make-billboards.lua` script that draws to a Canvas, saves PNG, then is never run again).
- If you can't commit a binary, document the procedural generation script and check it in instead of the PNG.

REFERENCES: same as T-003.

---

### T-020 — Palette quantization post-process         [tier 3] [med]

GOAL: A fragment shader applied on Canvas present quantizes scene colors to a small palette (16–32 colors). Per-region palette LUT enables Proteus-style mood shifts.

WHY: Proteus's color grading is unmistakable — a curated narrow palette per season/region. You currently have a 15-color biome palette but full RGB lighting interpolation between them, so the screen has thousands of colors.

WHERE:
- New shader file or inline GLSL in `src/postfx.lua`.
- Applied between Canvas-render and window-present.

DEPENDS ON: T-018.

ACCEPTANCE:
- A 1D palette texture (e.g. 32×1 RGB) bound as shader uniform.
- Fragment shader picks nearest palette color (`min ||rgb - palette[i]||`).
- Visible color banding; chunkier feel.
- Palette swappable at runtime — different palette per scope (local/region/continent) or per season (see T-022).

NOTES / IMPL HINTS:
- Naive nearest-color is O(palette_size) per fragment. At 32-color palette × 800k fragments = 25M ops/frame — fine on any GPU.
- For ordered dithering, multiply distance by a Bayer matrix value before nearest.

REFERENCES:
- [Angled pixelation with palette quantization & fog — Godot Shaders](https://godotshaders.com/shader/angled-pixelation-with-color-palette-quantization-and-fog/) — port-able GLSL.
- [Creating pixel-art shader for Unity (palette technique)](https://tante.hashnode.dev/creating-a-lot-of-variations-of-your-pixelart-quickly)

---

### T-021 — Skybox dome + horizon haze         [tier 3] [low]

GOAL: Replace the three flat-rectangle sky in `drawSky` with a gradient dome rendered via a full-screen shader (or two stacked stripes + a noise band).

WHY: Current sky reads as a flat painted backdrop; Proteus's sky is part of the world's mood.

WHERE: `src/render.lua:370–377` (`drawSky`).

DEPENDS ON: T-018 (canvas), T-020 (palette).

ACCEPTANCE:
- Gradient from `skyTop` to `skyHorizon` over the full upper half, hazing into `fogColor` at the terrain horizon.
- Optional: a noise-driven cloud band.
- Sky reacts to time-of-day uniform (see T-022).

NOTES / IMPL HINTS:
- Easiest: one full-screen quad with a fragment shader that interpolates colors by `y`.

REFERENCES: none needed.

---

### T-022 — Time-of-day and season palette LUT         [tier 3] [med]

GOAL: A `time` and `season` value modulate the active palette and sky colors. Day/dusk/night cycle and four-season cycle.

WHY: Proteus's mood comes from time + season palette swaps. None of that exists today.

WHERE:
- New `src/atmosphere.lua` — owns `time` (0–1) and `season` (spring/summer/autumn/winter).
- `src/render.lua:6–38` — palette tables become functions returning the current palette.
- `main.lua` — advance `time` in `love.update`.

DEPENDS ON: T-020 (palette LUT mechanic).

ACCEPTANCE:
- Walking a full day cycle in 60s of wall clock (configurable) visibly shifts palette and sky.
- Seasonal shift accessible via a key (e.g. `[`/`]`) for testing without waiting.
- `testAtmosphereCycle` asserts palette at noon ≠ palette at midnight.

NOTES / IMPL HINTS:
- Define 4 palettes × 4 times-of-day = 16 LUTs. Mix between adjacent ones.

REFERENCES: none required.

---

### T-023 — Animated billboards (wind sway)         [tier 3] [low]

GOAL: Trees and reeds gently sway via per-instance time-offset uniform passed to the billboard shader.

WHY: Static billboards feel dead. Proteus has subtle motion.

WHERE:
- `src/render.lua` billboard draw path.
- New shader uniform `time`.

DEPENDS ON: T-003, T-019, T-022.

ACCEPTANCE:
- Sway is per-instance phase-offset (use `Rng.signed(seed, x, y)` for the phase).
- Magnitude scales with billboard kind (trees more, rocks zero).
- No FPS regression.

NOTES / IMPL HINTS:
- Vertex shader displacement: `pos.x += A * sin(time * freq + phase) * (vertex.y / height)` — top sways, base doesn't.

REFERENCES: none required.

---

# TIER 4 — Endless world infrastructure

These extend the world's reach and the engine's ability to handle long sessions.

---

### T-024 — Geometry clipmap LOD inside local scale         [tier 4] [high]

GOAL: Replace the three discrete view-scales (local/region/continent) — or augment them — with a continuous LOD via geometry clipmaps. Nested rings of decreasing resolution centered on the camera.

WHY: Current `viewscale.lua` only switches between 3 fixed factors with eased transitions. A real geometry clipmap (Losasso & Hoppe 2004) keeps vertex count constant while extending the visible radius arbitrarily far. The user wants "endlessly generated world" — clipmaps are the canonical solution.

WHERE:
- Major rewrite of `src/render.lua:198–303`.
- Possibly new `src/clipmap.lua`.

DEPENDS ON: T-001, T-002, T-007.

ACCEPTANCE:
- N concentric rings (e.g. 5) at decreasing sample density (1 cell, 2, 4, 8, 16).
- Each ring's grid is a constant-size vertex/index buffer reused frame to frame.
- Transition morphing between rings hides seams.
- Visible terrain extends to e.g. 500 cells without per-frame regenerated mesh.

NOTES / IMPL HINTS:
- LÖVE doesn't expose vertex textures the way the GPU Gems chapter does, but you can still do clipmap-style nested vertex buffers, refilling sub-windows as the camera moves.
- Start with the wandering-clipmap pattern (advance the clipmap origin in grid-step increments; only refill the L-shaped strip that scrolled in).
- Optional: skip the texture path and just keep a 2D array of heights per ring; vertex shader reads from a uniform array.

REFERENCES:
- [Losasso & Hoppe — Geometry Clipmaps project page](https://hhoppe.com/proj/geomclipmap/)
- [GPU Gems 2 Ch. 2 — Terrain Rendering Using GPU-Based Geometry Clipmaps (NVIDIA)](https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-2-terrain-rendering-using-gpu-based-geometry)
- [Infinite Terrain in Godot 4 — Wandering Clipmap (YouTube)](https://www.youtube.com/watch?v=rcsIMlet7Fw) — good intuition pump even though Godot.
- [Olluo/geometry-clipmaps-demo — GitHub](https://github.com/Olluo/geometry-clipmaps-demo)

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

### T-026 — Plate motion over geologic time         [tier 4] [med]

GOAL: Plates drift; their positions are a function of `(seed, geologicTime)`. A user-controllable `--time-step` exposes terrain snapshots at different epochs.

WHY: `worldgen.lua:121–140` defines plates as static. Real continents drift. This is mostly an aesthetic / curiosity feature (the world won't change at runtime), but it unlocks the "true-to-real-world" feel by making terrain a snapshot of an ongoing process.

WHERE: `src/worldgen.lua:121–159`.

DEPENDS ON: none.

ACCEPTANCE:
- `plateCenter(seed, gx, gy, cellSize, time)` interpolates position along the velocity vector by `time`.
- Default `time = 0` keeps current behavior; `--geologic-time 0.5` shifts plates noticeably.
- Determinism still holds: `(seed, time)` is the new contract.
- The CLI flag is documented in README.

NOTES / IMPL HINTS:
- This necessitates re-running tectonics-derived elevation contributions. The good news: `plateCenter` already exposes velocity. New: clamp drift so plates don't run into each other.

REFERENCES:
- [nickmcd.me — Clustered Convection for Procedural Plate Tectonics](https://nickmcd.me/2020/12/03/clustered-convection-for-simulating-plate-tectonics/) — full plate-motion sim, good inspiration.

---

### T-027 — Headless walk benchmark + perf snapshot         [tier 4] [low]

GOAL: A `make bench` target runs a fixed seed + fixed walk path + fixed duration headless; prints per-frame perf snapshot to stdout; CI-friendly machine-readable output.

WHY: `TODO.md` lists "headless terrain benchmark over many chunks and scales." Currently `make walk-smoke` exists but it's not a benchmark — it just runs LÖVE with `SDL_AUDIODRIVER=dummy`. Need a reproducible perf number to gate regressions against.

WHERE:
- `Makefile` new `bench` target.
- New `tests/bench.lua` driver that uses `WorldGen` + `Render.visibleStats` without LÖVE (mock window dims, no actual draw).

DEPENDS ON: none.

ACCEPTANCE:
- `make bench` prints lines like `bench seed=20260625 step=42 ms=8.4 fps=119 cache=...` to stdout.
- Output is parseable by a follow-up CI script (T-029).
- A "baseline" file `tests/bench.baseline.json` committed; bench compares current run to baseline; non-zero exit on >10% regression.

NOTES / IMPL HINTS:
- For pure-Lua benchmark you can omit `love.graphics.newMesh` calls and just exercise `buildTerrainMeshData` for its CPU cost. Confirm the perf numbers track real frame time.

REFERENCES: none required.

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

### T-029 — CI workflow         [tier 4] [low]

GOAL: GitHub Actions workflow runs `make test`, `make smoke`, `make diagnostics`, `make bench` on every push.

WHY: `.github/` exists (verified `ls -la`) but contents not inspected here. Whether CI runs currently or not, the bench gating in T-027 needs a CI job to be useful.

WHERE: `.github/workflows/ci.yml` (create or update).

DEPENDS ON: T-027.

ACCEPTANCE:
- Workflow installs `luajit` and `love` on ubuntu-latest.
- Runs all `make` targets that don't need a display (skip `run`).
- Bench result is uploaded as a workflow artifact.

NOTES / IMPL HINTS:
- For LÖVE headless graphics, use `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy` per existing `Makefile` patterns.

REFERENCES: none required.

---

# TIER 5 — Engineering hygiene

Small targeted fixes for issues spotted during the audit. Land any time after Tier 1.

---

### T-030 — Use `normalAt` for terrain lighting         [tier 5] [low]

GOAL: Replace `slopeLight` (derived from quad-corner z-deltas at `render.lua:257`) with a dot product between the cell's surface normal (`world:normalAt(x, y)`) and a sun direction uniform.

WHY: `worldgen.lua:556–564` (`normalAt`) exists and is unit-length, but is never called. The current `slopeLight` is direction-agnostic — light comes from above, which is unphysical and bland.

WHERE: `src/render.lua:257–267`.

DEPENDS ON: T-002 (shader pass — sun direction is a uniform).

ACCEPTANCE:
- A `sun = { x, y, z }` direction (configurable) shades the terrain.
- Slopes facing the sun are visibly brighter; opposite slopes darker.
- Sun direction couples to time-of-day (T-022) once landed.

REFERENCES: none required.

---

### T-031 — Regression seed fixtures (TODO entry)         [tier 5] [low]

GOAL: A test that generates terrain from a curated list of known-bad and known-ugly seeds and asserts they still fail diagnostics in the documented way (locked-in failure mode).

WHY: `TODO.md` lists "Add regression seeds for ugly terrain, all-water/all-land maps, broken seams, and river discontinuities." Without these, future refactors might silently mask edge cases.

WHERE: `src/diagnostics.lua:6–11` already has 4 known-bad seeds; extend.

DEPENDS ON: none.

ACCEPTANCE:
- ≥10 known-bad / known-ugly seeds covering: all-water, all-land, riverless, lake-flooded, single-biome, broken seam (if one exists), uphill river (which is currently rejected by the algorithm).
- Each fixture documents its failure mode in a comment.
- `make diagnostics --seeds <list>` exercises them.

REFERENCES: none required.

---

### T-032 — Debug panels for plate vectors, drainage, biome inputs (TODO entry)         [tier 5] [low]

GOAL: Toggleable debug overlays drawing plate-velocity arrows, drainage-arrow flow, erosion deltas, and biome classifier inputs.

WHY: `TODO.md` lists this. Useful for verifying T-010 and T-012 outputs.

WHERE: `src/render.lua` — new debug draw functions; new key bindings.

DEPENDS ON: none.

ACCEPTANCE:
- Keys `1`–`5` toggle distinct debug overlays.
- Each overlay reads existing cell fields; no new computation cost when off.

REFERENCES: none required.

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
