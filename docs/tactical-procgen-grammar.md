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
Thoth's encounter director writes enemy mix, intent density, objective pressure, reinforcement timing, spawn block rules, and retreat routes into generated board specs before tactical play starts.

board verb:
Compose, pressure, reinforce, retreat, preview.

zone fit:
Archive pulls from archive enemy families, Cistern from cistern families, and Warrens from warrens families while sharing the same director fields.

counterplay:
Enemy composition, objective clock, visible reinforcement warning, spawn blocking, and retreat path are inspectable before and during a mission.

preview/UI:
Route or debug preview can show director id, family, enemy count, intent cap, objective clock, reinforcement turn, spawn pocket, spawn blocking rule, and retreat route.

test/replay proof:
`tests/run.lua` verifies directed zone boards contain enemy mix, intent density, objective pressure, visible blockable reinforcement timing, spawn block rules, retreat routes, and deterministic serialization from the same seed.

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
