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

### T-043 — Hotspot point-set + flood-basalt provinces            [tier 6] [med]

GOAL: Static Poisson-disk-distributed hotspot set in mantle reference frame (deterministic from seed). As plates drift over hotspots via existing `geologicTime`, shield-volcano elevation + lava-biome contributions accumulate, producing volcanic chains.

WHY: No intra-plate volcanism currently modelled (only convergent island arcs at worldgen.lua:651-654). Hawaii-Emperor-style trails fall out of existing plate drift mechanics with negligible cost — highest ROI tectonic feature.

WHERE:
- `src/worldgen.lua:314-378` `WorldGen.new` — add `world.hotspots = []` (Poisson-disk sampled) and `world.hotspotGrid` (spatial index).
- `src/worldgen.lua:636-637` `baseSample` — after `plate = self:plateAt(wx, wy)`, compute `mantleCell = (wx, wy) - integratedPlateDrift(plate, geologicTime)`, query nearby hotspots from grid, accumulate kernel-weighted contribution.
- `src/worldgen.lua:656` — add `hotspotContribution` to elevation sum (cap at +0.45).
- `src/worldgen.lua:10` — append `hotspotContribution:double, hotspotAgeMy:double` to `soaFieldList`; `hotspotId:int32` to `soaInt32FieldList`; `isFloodBasalt:int8` to `soaInt8FieldList`.
- `src/biomes.lua:42-55` — add `lava_flow`, `shield` biomes when `hotspotContribution > 0.25 && slope < 0.2`.

DEPENDS ON: T-038 (int8/int32 SoA).

ACCEPTANCE:
- 64 hotspots default; positions deterministic from seed.
- As `geologicTime` advances, a chain of shields traces back along the plate drift path (Hawaiian-Emperor signature).
- Flood-basalt cells (`isFloodBasalt = 1`) appear at high-intensity hotspots when `plate.boundary < 0.18`.
- `testHotspotTrails` runs three geologicTime steps and verifies trail emergence (chain of decreasing elevation).
- `make test` green after T-056.

NOTES / IMPL HINTS:
- Poisson-disk sample 64 hotspots in `[0, mantleExtent)²` with `minSeparation = 4096` world units.
- `world.hotspotGrid[bucketX][bucketY] = [hotspotIds...]` with bucket size 8192 for O(1) candidate lookup.
- Per cell: `contribution = Σ_{k=0..7} kernel(dist(mantleCell, hotspot - plateVelocity·k·dt)) · decay(k)` summing over 8 past timesteps. `kernel(d) = exp(-d²/σ²), σ = 1024`. `decay(k) = exp(-k/τ), τ = 3`.
- Use same `tanh`-clamped velocity integration as `plateDrift` (worldgen.lua:154-157) for consistency.
- `isFloodBasalt = (intensity > floodThreshold) && (plate.boundary < 0.18)`.
- Existing volcanic-island-arc (worldgen.lua:651-654) stays — hotspots are intra-plate, island arcs are convergent-boundary; they're independent.

REFERENCES:
- [Hawaii-Emperor chain Nature Comms 2024](https://www.nature.com/articles/s41467-024-51055-9).
- [Tectonics.js davidson16807](https://davidson16807.github.io/tectonics.js/blog/) — hotspots in procgen.
- [Flowy 2024 — lava emplacement (optional for T-051)](https://arxiv.org/pdf/2405.20144).

---

### T-044 — Howard-Knutson meandering rivers + oxbow cutoffs      [tier 6] [med]

GOAL: For each river segment above flow threshold, convert grid-locked D8 polyline to a curvature-driven meandering centerline migrating per Howard & Knutson 1984. Detect neck cutoffs to form oxbow lakes.

WHY: Rivers currently lock to 8 D8 directions and never meander. Adding curvature-driven migration transforms planforms into recognizably-real river shapes; oxbows accumulate in floodplain bands.

WHERE:
- New `src/meander.lua` exposing `Meander.applyRegion(region, options)`.
- `src/hydrology.lua:553-567` river labelling — for each `cell.river`, group into segments by `channelId`. Build polyline per segment.
- `src/hydrology.lua:594-605` deltas/floodplain — extend to mark `cell.oxbowLake = true` and `cell.meanderBend` along migrated centerline.
- New per-cell field `meanderBend:double`; `oxbowLake:int8`. New per-region `region.oxbowPolygons[]` for render.

DEPENDS ON: none new.

ACCEPTANCE:
- Sinuosity (channel length / valley length) > 1.2 for lowland rivers after migration.
- Oxbow lakes appear in floodplain band ~3–5·W wide where W = channel width.
- Same seed → same meander positions.
- `testMeanderSinuosity` gates expected sinuosity range.

NOTES / IMPL HINTS:
- Channel width `W = sqrt(flow) · widthScale` (Leopold-Maddock `W ∝ Q^0.5`).
- Polyline nodes at uniform arc length `ds_target = W/2`.
- Curvature: `κ_i = 2·cross(r_{i-1}-r_i, r_{i+1}-r_i) / (|r_{i-1}-r_i|·|r_i-r_{i+1}|·|r_{i-1}-r_{i+1}|)`.
- Smoothed curvature: `ω_i = Σ_j w_{i-j}·κ_j`, `w_k = (ds/L_d)·exp(-k·ds/L_d)`, `L_d = 10·W`, truncate at `5·L_d`.
- Migration: `r_i += dt · E₀ · ω_i · n_i` (n = outward normal). Tune `E₀` so peak migration ≈ 1% of W per step.
- Resample to uniform arc length after migration; 3-point moving-average smoothing every 5 steps.
- Neck cutoff: scan node pairs `(i,j)` with `|i-j|·ds > 5·W`; if `|r_i - r_j| < 1.0·W`, splice — remove nodes between, store removed polyline as oxbow polygon.
- Pin endpoints at chunk-boundary entry/exit.
- `dt ≈ 1–5 yr` per step; run once per geologicTime advance, not per frame.

REFERENCES:
- [Howard & Knutson 1984 WRR](https://doi.org/10.1029/WR020i011p01659).
- [Ikeda, Parker & Sawai 1981 JFM](https://doi.org/10.1017/S0022112081002231) — upstream influence kernel.
- [Vimont et al. 2023 TOG](https://dl.acm.org/doi/10.1145/3618350) — modern authoring.

---

### T-045 — Ashton-Murray-Arnoult shoreline instability           [tier 6] [med]

GOAL: Replace exposure-only coast logic (coast.lua:39-80) with AMA 2001 shoreline-instability solver. Run after T-046 GDH1. High-angle wave climate produces capes, spits, cuspate forelands; low-angle smooths.

WHY: Current coast generates only per-cell cliffs and beaches — no spit/tombolo/cape/barrier-island morphology. AMA is a 1D polyline solver, cheap, produces recognizable real coast features.

WHERE:
- Extend `src/coast.lua:39-80` `Coast.apply` — extract shoreline polyline from `cell.water` transitions, run shoreline-flux divergence per node, advance shoreline normal.
- New per-region fields `region.shorelines[]`, `region.spits[]`, `region.lagoons[]`.
- New per-cell `shorelineNode:int32` (index into polyline).

DEPENDS ON: T-038 (int32 SoA), T-046 (GDH1 — depth-of-closure scales with bathymetry).

ACCEPTANCE:
- High-angle wave fraction `U_hi > 0.5` produces cape spacing 10–100 km.
- Strongly asymmetric high-angle produces downcoast-migrating spits.
- Low-angle (`U_hi < 0.3`) smooths perturbations.
- Lagoons appear behind spits.
- `testShorelineCapes` runs synthetic straight-coast + perturbation; checks cape emergence under high-angle climate.

NOTES / IMPL HINTS:
- Shoreline extraction: walk water/land cell boundaries, build ordered polyline per connected component.
- Resample to uniform alongshore spacing `ds = 4·stride`.
- Per node: `φ_i = atan2(y_{i+1} - y_{i-1}, x_{i+1} - x_{i-1})`.
- Sample wave-approach angle `θ_t` per step from climate PDF; `U_hi` per region from latitude band (storm tracks higher at 45–55°).
- Longshore flux: `Q_s = K · H_b^(12/5) · cos(θ_b)^(6/5) · sin(θ_b)`, `θ_b = θ - φ`. `K = 0.39`, `H_b = 1.5 m`.
- Shadow zone: walk along shoreline, sweep along wave direction, O(N).
- Advance: `Δη_i = -(Q_{i+1/2} - Q_{i-1/2}) / (D · ds) · dt`. `D = 10 m`.
- Self-intersection → splice; new island + lagoon.
- Stochastic event-based update: 1 storm per step, `dt = days`. Aggregate over geologicTime.

REFERENCES:
- [Ashton, Murray & Arnoult 2001 Nature](https://doi.org/10.1038/35104541).
- [Ashton & Murray 2006a JGR](https://doi.org/10.1029/2005JF000422).
- [ShorelineS Frontiers 2020](https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2020.00535/full).

---

### T-046 — GDH1 crust-age bathymetry                             [tier 6] [low]

GOAL: Replace per-cell `oceanAgeCooling` proxy with Stein & Stein 1992 GDH1: `d(t) = 2600 + 365·√t` for `t < 20 Myr`, `5651 - 2473·exp(-t/36)` for older. Produces canonical mid-ocean-ridge → abyssal-plain depth gradient.

WHY: Current ocean is uniform-depth proxy. GDH1 gives the canonical depth-vs-age curve with no additional state (plate.age already tracked at worldgen.lua:644).

WHERE:
- `src/worldgen.lua:644-656` `baseSample` — for ocean cells (`plate.crust == "oceanic"`), compute `d_phys = GDH1(plate.age · world.maxOceanAgeMyr)`, convert to elevation contribution `e_age = currentSeaLevel - d_phys / world.zScale`, blend with tectonic `e_tect`.
- New options `world.zScale` (default 10000 m), `world.maxOceanAgeMyr` (default 180).

DEPENDS ON: none.

ACCEPTANCE:
- Mid-ocean ridges shallow (~2.6 km below surface); abyssal plains uniform ~5.5 km.
- Symmetric depth-vs-distance from ridge on both flanks.
- `testGDH1Profile` samples ocean cells along plate-age gradient, gates against analytical curve within 5%.

NOTES / IMPL HINTS:
- `plate.age ∈ [0, 1]` → `t_Ma = plate.age · world.maxOceanAgeMyr`.
- `GDH1(t_Ma) = t_Ma < 20 ? 2600 + 365·√t_Ma : 5651 - 2473·exp(-t_Ma/36)` (continuous at t=20).
- `e_age = currentSeaLevel - d_phys / world.zScale`.
- Blend with tectonic elevation: `e_final = (1 - w_ocean) · e_tect + w_ocean · e_age`, `w_ocean = smoothstep(0, 1, oceanicCrustWeight)`.
- For continental cells: skip (GDH1 oceanic-only).
- Continental shelf transition: smooth blend over passive margin (~30 cells at continent scale).

REFERENCES:
- [Stein & Stein 1992 Nature](https://doi.org/10.1038/359123a0) — GDH1 model.
- [Crosby & McKenzie 2009 GJI](https://doi.org/10.1111/j.1365-246X.2009.04085.x) — thermal subsidence updates.

---

### T-047 — Werner cellular dune CA (replaces aeolian.lua)        [tier 6] [med]

GOAL: Replace sinusoidal dune proxy (aeolian.lua:21-37) with Werner 1995 cellular automaton: random pick → erode if not in shadow → transport L cells downwind → deposit with `p_sand=0.6, p_rock=0.4` → repose-angle slumping at 33°. Wind regime determines morphology (barchan / transverse / seif / star / parabolic).

WHY: Current sinusoid produces only wind-aligned ripples; cannot generate barchans, seif, star, or parabolic dunes. Werner CA reproduces all from a single rule set with deterministic seeding.

WHERE:
- Replace body of `src/aeolian.lua:17-37` with new `Aeolian.applyRegion(region, options)` iterating `K · cellCount` times.
- `src/worldgen.lua:830` call site — change from per-cell `applyCell` to per-region invocation after `classifyBiome` for the region (move call into hydrology pipeline post-coast, before per-cell biome finalization).

DEPENDS ON: none. Climate winds available from `cell.windX, windY` (climate.lua:144-145).

ACCEPTANCE:
- 30% sand cover + unimodal wind + 50k iterations → discrete barchans with horns downwind, wavelength ~10–30 cells.
- 80% cover + unimodal → transverse ridges, axes perpendicular to wind, wavelength ~20 cells.
- Bimodal 60/40 split at 90° → linear seifs along resultant.
- Multimodal wind (3+ directions sampled) → star dunes.
- `testWernerDuneRegimes` runs 4 wind regimes and gates morphology classifier output.

NOTES / IMPL HINTS:
- `slabHeight = 0.005` (internal unit, ~0.5% of biome relief).
- Iterations per "step": `10 · cellCount` for visible morphology.
- Shadow check: scan upwind cells `(i - k·wx, j - k·wy)` for k=1..k_max=12; cell shadowed if any upwind `n[u] - n[i] > k · tan(15°)`.
- Repose: BFS from modified cell; if `|n[a] - n[b]| > 1` slab-unit, transfer one slab; iterate until stable.
- Transport jump `L = 3` cells. If deposition fails (`Rng.unit ≥ p`), continue another L; bound retries at 5 hops.
- Wind regime: read `(cell.windX, cell.windY)` from climate. Bimodal/multimodal modeled by alternating wind direction across iterations per climate distribution.
- Determinism: `Rng.unitAt(seed, gx, gy, iteration)` for cell pick — not `math.random`.

REFERENCES:
- [Werner 1995 Geology](https://doi.org/10.1130/0091-7613(1995)023%3C1107:EDCSAA%3E2.3.CO;2) — cellular dune model.
- [Real-Time Sand Dune Simulation ACM 2023](https://dl.acm.org/doi/abs/10.1145/3585510) — extended morphologies.
- [Parteli et al. 2013 arXiv](https://arxiv.org/pdf/1304.6573) — barchan asymmetry.

---

### T-048 — Karst surface overlay (lithology-gated)               [tier 6] [med]

GOAL: For cells with `lithology == carbonate` (T-034), stamp sinkhole (doline), polje (closed depression), and tower-karst pillar features. Modifies elevation; assigns new `karst` biome.

WHY: No karst landforms currently. Distinctive real-world morphology (cone karst, tower karst, sinkhole plains) absent. Cheap stamp-based overlay with high visual ROI.

WHERE:
- New `src/karst.lua` exposing `Karst.applyRegion(region, options)`.
- `src/hydrology.lua:282-292` between `Erosion.relax` and `Erosion.glaciate` — call `Karst.applyRegion`.
- `src/worldgen.lua:10` — append `karstDepth:double, cavePresence:double` to `soaFieldList`; `karstType:int8` to `soaInt8FieldList`.
- `src/biomes.lua:42-55` — add `karst` biome when `karstType > 0`.

DEPENDS ON: T-034 (lithology), T-038 (int8 SoA).

ACCEPTANCE:
- Carbonate regions show non-zero doline density (~1–5 per chunk).
- Humid tropical carbonate regions show tower karst (positive relief inversion).
- Sinkholes create closed depressions that priority-flood fills as small lakes.
- `testKarstStamp` asserts non-zero karst-feature count in synthetic carbonate region.

NOTES / IMPL HINTS:
- Stamp kinds int8: 0=none, 1=doline (sinkhole, negative dz), 2=polje (broad depression), 3=towerKarst (positive dz), 4=karstPlain (flat).
- Per cell: if `lithology == carbonate`, hash `r = Rng.unitAt(seed, gx, gy, 1009)`; if `r < density · climateMod`, candidate stamp center. Density default 0.04; climateMod = `(rainfall · (1 - latitudeUnit · 0.5))`.
- Sort candidates by `Rng.hash(seed, gx, gy, 1019)`; Poisson-disk-prune with radius `2·stride`.
- Per surviving stamp pick kind by context:
  - Upland (`elevation > seaLevel + 0.2 && rainfall > 0.3`) → doline. Radius 1–2 cells. `elevation -= (0.04 + Rng.unit · 0.06) · cos(π · r / R)`.
  - Basin (`slope < 0.05 && elevation < 0.3`) → polje. Polygon 3–5 cells. Uniform `elevation -= 0.02`.
  - Tropical humid (`rainfall > 0.7 && latitudeUnit < 0.35`) → tower. Radius 1 cell. `elevation += 0.18 · (1 - r/R)`.
- `cavePresence` per carbonate cell uniform 0.2–0.6 from `Rng.unit`.
- Halo: 2 cells (stamps from neighbor chunks reach into edge cells).

REFERENCES:
- [Paris et al. 2021 CGF](https://onlinelibrary.wiley.com/doi/10.1111/cgf.14420) — cave network synthesis.
- [Peytavie/Galin Arches](https://www.semanticscholar.org/paper/Arches:-a-Framework-for-Modeling-Complex-Terrains-Peytavie-Galin/e8b83d99ea6121c13df3570b4f8d3697257b1c2b).
- [Ford & Williams Karst Hydrogeology 2007](https://onlinelibrary.wiley.com/doi/book/10.1002/9781118684986).

---

### T-049 — Coral reef succession (Darwin 1842)                   [tier 6] [med]

GOAL: For warm shallow tropical coastlines and submerging seamounts, grow fringing → barrier → atoll reef per Darwin 1842 subsidence model. Adds `reef`, `lagoon` biomes.

WHY: No coral reefs currently. Distinctive shallow-tropical morphology — fringing reefs near land, barrier reefs offshore, atolls over subsiding seamounts. Emerges from existing plate.age + hotspot subsidence (T-043).

WHERE:
- New `src/reef.lua` exposing `Reef.applyRegion(region, options)`.
- `src/hydrology.lua:608-612` after `Coast.apply` — call `Reef.applyRegion`.
- `src/worldgen.lua:10` — append `reefAccretion:double, reefAgeMy:double` to `soaFieldList`; `reefStage:int8` to `soaInt8FieldList`.
- `src/biomes.lua` — add `reef`, `lagoon` biomes.

DEPENDS ON: T-043 (hotspot subsidence drives atoll progression), T-036 (eustatic sea level — subsidence is sea-level relative), T-038.

ACCEPTANCE:
- Tropical (`latitudeUnit < 0.4 && temperature > 0.62`) shallow coasts develop fringing reefs (`reefStage = 1`).
- Seamounts subsided since `reefStartTime > 0` show barrier (`reefStage = 2`) or atoll (`reefStage = 3`) geometry.
- Atolls have central lagoon (`reefStage = 4`).
- `testReefSuccession` runs synthetic subsiding seamount over geologicTime, asserts fringing → barrier → atoll.

NOTES / IMPL HINTS:
- Candidate filter: `water && latitudeUnit < 0.4 && temperature > 0.62 && elevation > seaLevel - 0.08`.
- Reef seed: local elevation max in candidate region. `reefStartTime = Rng.unitAt(seed, seedGx, seedGy, 1061) · geologicTime`.
- `reefAgeMy = max(0, geologicTime - reefStartTime)`.
- `accretion = reefAgeMy · reefGrowthRate`; default `reefGrowthRate = 0.05` per Ma in normalized coords.
- Subsidence `Δsub = thermalSubsidence(plate.age) + hotspotSubsidence(hotspotAgeMy)`. Thermal via GDH1 (T-046); hotspot via `exp` decay over ~30 Ma.
- Stage rules (Darwin):
  - `accretion < Δsub - 0.02` → submerged (stage 5).
  - `Δsub < 0.005` → fringing (stage 1).
  - `0.005 ≤ Δsub < 0.04` && accretion keeps pace → barrier (stage 2).
  - `Δsub ≥ 0.04` && accretion keeps pace, substrate well below → atoll ring (stage 3); interior = lagoon (stage 4).
- Write biome `reef` to ring; `lagoon` to atoll interior. Accreting reef cells: `elevation = max(elevation, currentSeaLevel + 0.002)`.

REFERENCES:
- [Darwin 1842 Structure & Distribution of Coral Reefs](https://www.gutenberg.org/files/2690/2690-h/2690-h.htm).
- [Toomey, Ashton & Perron 2013 Geology](https://pubs.geoscienceworld.org/gsa/geology/article/41/7/731/130911).

---

### T-050 — Orometry-conditioned regional priors                  [tier 6] [med]

GOAL: Offline-bake (one-time, `tools/bake_orometry.lua`) per-archetype statistics from SRTM tiles for ~6 mountain archetypes (Alps, Appalachians, Himalaya, Andes, Fjordland, Basin&Range). At runtime, each continental chunk picks an archetype deterministically; noise+plate generator parameters scale toward that archetype.

WHY: Current global noise+plate machinery produces homogeneous mountains everywhere. Real ranges differ dramatically — Alps sharp/glaciated, Appalachians rounded/old, Himalaya extreme/young. Orometry priors keep procedural infinity but eliminate global homogeneity.

WHERE:
- New `tools/bake_orometry.lua` — offline script (LuaJIT) ingesting SRTM GeoTIFF tiles, writing `assets/orometry/archetypes.lua` as a plain Lua return table.
- New `src/orometry.lua` — runtime accessor.
- `src/worldgen.lua:633-712` `baseSample` — at noise contribution step (lines 638-639), multiply `Noise.ridge` and `Noise.fbm` parameters by archetype-derived scales.
- `src/worldgen.lua:10` — append `archetypeBlend:double` to `soaFieldList`; `archetypeId:int8` to `soaInt8FieldList`.

DEPENDS ON: T-038 (int8 SoA).

ACCEPTANCE:
- 6 archetype entries baked into `assets/orometry/archetypes.lua`.
- Chunks in different "regions" of the world have visually distinct mountain morphology.
- `testOrometryArchetypes` asserts mean slope/relief differ > 30% between two distinct-archetype chunks of the same seed.

NOTES / IMPL HINTS:
- Per-archetype stats: `{ peakProminenceHist[16], saddleProminenceHist[16], peakDensityPerKm2, ridgelineSpacingMean, ridgelineSpacingStd, meanSlope, reliefP95, reliefP50, peakAmpScale, ridgeFreqScale, slopeBias, reliefScale }`.
- File format: Lua `return { alps = {...}, appalachians = {...}, himalaya = {...}, andes = {...}, fjordland = {...}, basinrange = {...} }`. Loaded via `dofile()` at world ctor — no JSON parser cost on hot path.
- Archetype pick: `archetypeIndex = Rng.hash(seed, floorDiv(cx, 4), floorDiv(cy, 4), 1091) % nArchetypes`. Quadrant-stable (4×4 chunks share archetype).
- Halo 8 cells for blending across 4×4 quadrant boundaries with smoothstep transition.
- SRTM source: 1° tiles (~3 arcsec), public-domain USGS EarthExplorer; downsample to 30 arcsec before stats.

REFERENCES:
- [Argudo & Galin 2019 TOG](https://hal.science/hal-02326472/file/2019-orometry.pdf) — orometry-based terrain.
- [oargudo/orometry-terrains GitHub](https://github.com/oargudo/orometry-terrains) — reference implementation.
- [USGS EarthExplorer SRTM](https://earthexplorer.usgs.gov/).

---

## Stretch — lower-priority extensions

These provide further fidelity gains but are not gating realism wins. Land after the substrate (T-034 — T-038) when bandwidth allows.

---

### T-051 — Volcanic landform expansion (cones, calderas, lava)   [tier 6] [med]

GOAL: For cells flagged by `volcanicIslandArc > 0.4` (subduction arcs at worldgen.lua:651) or `hotspotContribution > 0.25` (T-043), stamp distinctive volcanic landforms — stratovolcano cones, calderas (collapse depressions), lava-flow tongues following D8 steepest descent.

WHY: Current model produces volcanic *terrain* (uplift) but no distinct volcanic *landforms* (cones, calderas, flows). Stratovolcanoes and shield volcanoes are iconic and emerge naturally from existing tectonic flags + stamp pass.

WHERE: New `src/volcano.lua`. Call site `src/hydrology.lua` after T-048 karst, before T-049 reef. New per-cell `volcanicForm:int8` (0=none,1=stratoCone,2=caldera,3=lavaFlow,4=shield,5=cinderCone), `volcanicAgeMy:double`.

DEPENDS ON: T-038, T-043.

ACCEPTANCE: Volcanic chunks contain visible cones + lava-flow signatures. `testVolcanicLandforms` gates.

NOTES / IMPL HINTS:
- Cone elevation: `Δz = h_peak · exp(-r/r_scale)`; `h_peak ∈ [0.18, 0.32]`, `r_scale ∈ [2, 4]` cells.
- Caldera: subtract `0.14 · cos(r·π/R)` at summit if `Rng.unit < 0.3` (collapse probability).
- Lava flow: D8 steepest descent from summit for `N = 8–16` cells, add `+0.01` thickness per cell, decaying.
- Strato vs shield: arc + andesitic → strato (steep, `h/r > 0.15`); hotspot + basaltic → shield (gentle, `h/r < 0.05`).
- Cinder cone: small (`h_peak = 0.04`, `r_scale = 1.5`), in monogenetic fields (cluster of 5–10 stamps).

REFERENCES:
- [Flowy 2024 arXiv](https://arxiv.org/pdf/2405.20144) — probabilistic lava emplacement.
- [Volcanic Skies CGF 2024](https://onlinelibrary.wiley.com/doi/full/10.1111/cgf.15034).

---

### T-052 — Periglacial features (pingos, palsas, polygonal)      [tier 6] [low]

GOAL: For cells in cold non-glaciated zones (`temperature < 0.25 && !cell.glaciated`), stamp pingos (ice-cored mounds), palsas (peat mounds), polygonal-patterned-ground texture, solifluction lobes on slopes.

WHY: Tundra biome is currently visually uniform. Periglacial features give Arctic terrain its characteristic surface texture.

WHERE: New `src/periglacial.lua`. Call in chunk-build after biome classification. New per-cell `periglacialFeature:int8`.

DEPENDS ON: T-038.

ACCEPTANCE: Tundra/boreal cells have non-zero periglacial-feature density. `testPeriglacialStamps` gates.

NOTES / IMPL HINTS:
- Pingo: small mound `Δz = 0.005 + 0.01 · Rng.unit`, `r=1` cell, density ~1 per 20 cells in tundra.
- Palsa: smaller, in waterlogged wetland-tundra.
- Polygonal ground: deterministic Voronoi pattern at `~3-cell` cell size, `Δz=0` (texture-only — render hint).
- Solifluction: on slopes 0.05–0.2 in tundra, add downslope-aligned ridges (small amplitude `±0.003`).

REFERENCES:
- [Periglacial landforms — AntarcticGlaciers](https://www.antarcticglaciers.org/glacial-geology/glacial-landforms/periglaciation/periglacial-landforms/).

---

### T-053 — Marine bathymetry features                            [tier 6] [med]

GOAL: Populate abyssal-plain noise floor, hadal trenches, seamounts (hotspot residual outside the trail), and submarine canyons (D8 routing extended below sea level seeded at shelf-break).

WHY: Ocean rendering currently shows uniform-depth water. Real ocean has structure — continental shelves, slopes, abyssal plains, mid-ocean ridges (T-046), trenches, seamounts, submarine canyons.

WHERE: Extensions to `src/worldgen.lua:644-656` (abyssal noise, seamount stamps) and `src/hydrology.lua` (submarine-canyon D8 on bathymetry).

DEPENDS ON: T-046 (GDH1).

ACCEPTANCE: Ocean cells exhibit varied depth, recognisable shelf/slope/abyss profile, occasional seamounts. `testBathymetryProfile`.

NOTES / IMPL HINTS:
- Continental shelf: `+0.02 · plate.continental_distance_within_50_cells` added to ocean elevation.
- Continental slope: smoothstep from shelf to abyss at 30–60 cells offshore.
- Seamounts: jittered-grid stamps on oceanic cells, `Δz = 0.08 · exp(-r²/r²_scale)`, `r_scale = 1.5` cells, density ~1 per 100 cells.
- Submarine canyon: at continental-slope cells, D8-route downhill on bathymetry, incise `-0.015` per path cell.
- Hadal trench: clamp existing `trench` at worldgen.lua:648 to GDH1 + 1-2 km extra.

REFERENCES:
- [Stein & Stein 1992](https://doi.org/10.1038/359123a0) (T-046 reference).
- [Harris & Whiteway 2011 Marine Geology](https://doi.org/10.1016/j.margeo.2011.05.008) — submarine canyon morphology.

---

### T-054 — CLORPT soil classifier + horizons                     [tier 6] [med]

GOAL: After lithology (T-034) and regolith (T-035), classify USDA soil order (Entisol, Inceptisol, Mollisol, Vertisol, Aridisol, Histosol, Spodosol, Oxisol, Andisol, Ultisol) via CLORPT factors (climate, organisms, relief, parent, time).

WHY: Current biomes use Whittaker climate-only LUT. Soil determines vegetation just as much as climate (e.g., serpentine soils host distinct flora; peat blocks tree roots). Adds depth without significant per-cell footprint increase.

WHERE: New `src/soil_classify.lua`. Call in chunk pipeline after biome classification. New per-cell `soilOrder:int8`.

DEPENDS ON: T-034, T-035, T-038.

ACCEPTANCE: Soil-order distribution matches global frequency ±20%. `testSoilOrderDistribution` gates.

NOTES / IMPL HINTS:
- 10 USDA soil orders → int8.
- Decision tree using climate (temp, precip), parent lithology (T-034), relief (slope), drainage (flow accumulation), age (`plate.age`).
- Examples: humid tropical + intense weathering → Oxisol; cool boreal conifer → Spodosol; arid endorheic → Aridisol; volcanic ash parent → Andisol; waterlogged organic → Histosol.
- Optional layered horizons (O/A/E/B/C/R) as additional SoA fields — defer to v2 unless render uses horizon colors.

REFERENCES:
- [USDA Soil Taxonomy](https://www.nrcs.usda.gov/resources/guides-and-instructions/keys-to-soil-taxonomy).
- [Soil formation / CLORPT — Wikipedia](https://en.wikipedia.org/wiki/Soil_formation).
- [Weigert SoilMachine](https://github.com/weigert/SoilMachine) — particle-transport soil simulator.

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
