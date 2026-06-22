# Tactical Procgen Grammar

Source of truth: `src/game/tactics/procgen.lua`.

## 2.1 Board Grammar

source pattern:
Into the Breach keeps tactical boards compact and fully inspectable after load; XCOM 2 map guidance emphasizes object spacing, cover density, and LoS; Invisible Inc-style procedural stealth prioritizes goal, exit, guard route, and gated-path placement over realism.

thoth transformation:
Thoth board grammar emits explicit rooms, corridors, height bands, cover fields, sight breaks, objective anchors, hazard lanes, and spawn pockets before validation.

board verb:
Carve, anchor, cover, break sight, threaten, spawn, validate.

zone fit:
The shared grammar is zone-neutral; Buried Archive, Salt Cistern, and Ember Warrens can swap material, hazard kind, terrain props, and objective copy without changing grammar parts.

counterplay:
Players should see route shape, cover edges, sight breaks, hazards, objectives, and spawn pressure before committing tactical actions.

preview/UI:
Debug preview can show each grammar component as a separate overlay layer; player-facing previews should collapse this into objective, hazard, cover, LoS, and spawn-risk facts.

test/replay proof:
`tests/run.lua` verifies generated boards contain every grammar part, validate successfully, mark objective/sight-break tiles, instantiate as tactical state, and reproduce the same board from the same seed.

## 2.2 Zone Generators

source pattern:
Procedural dungeon references combine reusable room/corridor methods with themed rules; level-design-focused generation keeps a critical path and risk/reward side pressure; prefab-like pieces can provide control while still varying connections.

thoth transformation:
Thoth zone generators wrap the shared grammar with local material, hazard, objective, and sight-break definitions for Buried Archive, Salt Cistern, and Ember Warrens.

board verb:
Dress, localize, threaten, validate.

zone fit:
Buried Archive uses archive material, audit-static lanes, protected archive shelves, and rolling-shelf sight breaks. Salt Cistern uses salt material, flood lanes, repair floodgates, and sluice gates. Ember Warrens uses ember material, burn lanes, disable-kiln anchors, and kiln-mouth sight breaks.

counterplay:
Each zone keeps the same readable room/corridor structure while changing which hazard/objective/sight-break verbs the player must answer.

preview/UI:
Route preview can show generator id, zone, material, objective kind, and hazard kind before board load.

test/replay proof:
`tests/run.lua` verifies all three zone generators exist, validate their generated boards, instantiate tactical states, apply zone dressing, and reproduce the same board from the same seed.

## 2.3 Encounter Director

source pattern:
Encounter design sources frame fights as pacing with a beginning, middle, and ending; tactical combat sources emphasize clarity, determinism, and spatial objectives; director-style spawning systems evaluate battlefield state to produce consistent pressure.

thoth transformation:
Thoth's encounter director writes enemy mix, intent density, objective pressure, reinforcement timing, optional alpha spawn timing, spawn block rules, alpha terrain, and retreat routes into generated board specs before tactical play starts.

board verb:
Compose, pressure, reinforce, retreat, preview.

zone fit:
Archive pulls from archive enemy families, Cistern from cistern families, and Warrens from warrens families while sharing the same director fields.

counterplay:
Enemy composition, objective clock, visible reinforcement warning, alpha spawn warning, spawn blocking, deterministic terrain mutations, and retreat path are inspectable before and during a mission.

preview/UI:
Route or debug preview can show director id, family, enemy count, intent cap, objective clock, reinforcement turn, alpha turn, spawn pocket, spawn blocking rule, alpha terrain, and retreat route.

test/replay proof:
`tests/run.lua` verifies directed zone boards contain enemy mix, intent density, objective pressure, visible blockable reinforcement timing, optional Shelf Warden alpha spawn timing, spawn block rules, deterministic alpha terrain, retreat routes, and deterministic serialization from the same seed.

## 2.6 Difficulty Budget

source pattern:
Procedural generation references stress completability checks, difficulty estimation, and cover/LoS/readability constraints before a generated level is accepted.

thoth transformation:
Thoth scores generated boards across enemies, objectives, hazards, cover, reinforcements, redacted intent, and boss modifiers, then rejects boards that exceed the budget or lack readable/solvable requirements.

board verb:
Score, reject, regenerate, report.

zone fit:
All zone generators share the same budget axes while local hazards, objectives, enemy mixes, and reinforcements feed the score.

counterplay:
Rejected boards never enter player flow; accepted boards preserve objective anchors, cover fields, retreat routes, and intent-density caps.

preview/UI:
Debug budget report shows total, max, contributors, grammar status, and reject reasons.

test/replay proof:
`tests/run.lua` verifies a directed board is accepted under the default budget, rejected when max budget is too low, and rejected when intent density exceeds its cap.

## 2.7 Validator Invariants

source pattern:
Procedural tactics references treat generated content as shippable only after fixed-seed replay, reachability, spawn safety, and reject-reason evidence are available.

thoth transformation:
`tools/validator.lua` runs `procgen_validator_v1` across 25 fixed Buried Archive seeds, rotates through the six route variants, writes `dist/validator-report.json`, and fails when reject count exceeds the configured budget.

board verb:
Generate, flood, reject, report, replay.

zone fit:
The first validator route is `buried_archive_vertical_slice`; Salt Cistern and Ember Warrens can join the same invariant set when they leave future-zone status.

counterplay:
Accepted boards must keep every objective and evacuation tile reachable from squad start, keep player spawns inside open non-hazard tiles with no overlaps, and place enemies on open reachable tiles with valid visible spawn-blocking rules.

preview/UI:
The report records validator id, route id, seed count, reject count, invariant ids, per-seed board/unit summaries, and a reject log keyed by seed and variant.

test/replay proof:
`make validate` runs the full 25-seed batch with a zero default reject budget. `tests/run.lua` verifies the validator module, JSON reject log, all fixed fixture seeds, route-variant coverage, invariant acceptance, and deterministic replay snapshots.

## 6.1 Buried Archive Route Variants

source pattern:
Compact tactics boards need route-level variety without hiding objective, spawn, hazard, or exit pressure; procedural references stress fixed seeds, connected spaces, and validator evidence before shipping generated content.

thoth transformation:
Thoth exposes one Buried Archive vertical-slice route with six ordered procedural mission variants: entry audit, shelf protection, proof extraction, ledger repair, sealed shortcut, and Vault Regent final. The Shelf Knight elite claim remains a callable detour fixture outside the ordered six.

board verb:
Route, vary, validate, instantiate, replay.

zone fit:
All ordered variants stay inside Buried Archive material, audit-static hazards, archive objectives, and rolling-shelf sight breaks while changing template, dimensions, route node pressure, objective family, reward, and complication metadata.

counterplay:
Each route card exposes template, node kind, reward, complication, objective, reinforcement, spawn-blocking, and retreat-route data before tactical commitment.

preview/UI:
`Procgen.archiveRoute()` exposes route metadata and ordered variant ids; `Procgen.archiveRouteVariants()` exposes template/node/reward/complication previews; generated specs carry `archiveRoute` and generator variant fields.

test/replay proof:
`tests/run.lua` verifies the route exposes exactly 6 ordered variants, each uses a distinct objective family, all templates exist, each generated board validates grammar/reinforcements/budget, each instantiates as `TacticsState`, and the validator fixture seeds replay deterministically.
