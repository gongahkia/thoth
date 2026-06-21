# Tactical Run Catalog

## P.1 Board Templates

source pattern:
Invisible Inc-style procedural boards need dependable templates before generation variance.

thoth transformation:
Thoth board templates define the objective, layout shape, pressure axis, and validation focus for each tactical board family.

board verb:
Template, anchor, pressure, validate.

zone fit:
All zones can map their local terrain onto kill-light, protect-heavy, extraction, repair, stealth, split-squad, holdout, and boss-route templates.

counterplay:
Route preview should tell the player which pressure axis the template uses before they commit.

preview/UI:
Route card shows template id, objective family, pressure axis, and primary validation focus.

test/replay proof:
`tests/run.lua` verifies all eight board templates exist and each defines objective, layout, pressure, and validation focus.

## P.2 Board Validators

source pattern:
Procedural tactics boards need validator discipline to reject unfair or unreadable generated spaces.

thoth transformation:
Thoth validates reachability, LoS sanity, cover density, objective feasibility, enemy intent density, and exit access before a board can enter a run.

board verb:
Validate, reject, regenerate, report.

zone fit:
All generated zone boards use the same validator families, with zone-specific terrain feeding the checks.

counterplay:
Rejected boards never reach the player; accepted boards keep objective and exit paths inspectable.

preview/UI:
Debug validator report shows check id, input, and reject reason; player route card stays concise.

test/replay proof:
`tests/run.lua` verifies all six validator checks exist and each defines its input and reject reason.

## P.3 Difficulty Budget Weights

source pattern:
Procedural tactics generators need budget weights so encounter pressure can be compared before play.

thoth transformation:
Thoth prices enemies, objectives, hazards, reinforcements, redacted intent, and boss modifiers as pressure, while cover offsets pressure.

board verb:
Budget, price, offset, reject.

zone fit:
All zones feed local threats into the same budget axes.

counterplay:
Route previews can expose high-pressure axes without showing hidden seed math.

preview/UI:
Debug report shows weighted pressure total, pressure contributors, and cover offset.

test/replay proof:
`tests/run.lua` verifies all seven budget weights exist, pressure weights are positive, cover offsets pressure, and boss modifiers cost more than hazards.

## P.4 Route Node Types

source pattern:
Roguelite route maps need node previews that state risk, reward, and run timing.

thoth transformation:
Thoth route nodes cover combat, repair, enclave, market, event, elite, boss, rest, cursed shortcut, and high-reward extraction.

board verb:
Route, preview, choose, pay, collect.

zone fit:
All zones reuse these node types with local enemy families, objectives, hazards, and faction pressure.

counterplay:
Players can avoid or accept a pressure axis by reading the node preview before choosing a route.

preview/UI:
Node card shows risk, reward, and the information preview field for that node type.

test/replay proof:
`tests/run.lua` verifies all ten route node types exist and each defines risk, reward, and preview text.

## P.4b Run Map Graph

source pattern:
Roguelite map screens create agency by showing branching paths, risk/reward node types, route length, elites/events, and boss endpoints before commitment.

thoth transformation:
Thoth run maps generate a small node graph with route choices, risk/reward previews, enclave requests, event nodes, repair/elite routes, and a boss gate.

board verb:
Route, preview, request, gate, choose.

zone fit:
Each zone supplies local enclave, hazard, and boss-gate metadata while sharing the same graph shape.

counterplay:
Players can avoid or accept combat, enclave, event, repair, elite, and boss pressure based on visible previews.

preview/UI:
Route map can show node kind, risk, reward, detail text, event id, enclave request, and boss gate requirement.

test/replay proof:
`tests/run.lua` verifies a generated run map validates, exposes two route choices, includes enclave/event/boss nodes, carries risk/reward previews, and serializes deterministically from the same seed.

## P.5 Event RNG Rules

source pattern:
Roguelite event variance can happen around tactical boards without making declared tactical resolution random.

thoth transformation:
Thoth event RNG is restricted to pre-board and post-board windows; once board state and intents are declared, tactical resolution remains deterministic.

board verb:
Roll before, lock board, resolve deterministically, roll after.

zone fit:
All zone events can alter route choice, board modifier, squad state, objective reward, or faction standing only outside declared tactical resolution.

counterplay:
Players see event timing and board modifier before committing to a route or deployment.

preview/UI:
Event card labels timing as pre-board or post-board and describes the board/run effect.

test/replay proof:
`tests/run.lua` verifies every event RNG rule runs only pre-board or post-board and covers both timing windows.

## P.5b Event RNG Layer

source pattern:
Pre-randomness gives the player varied conditions to assess before action; post-action randomness inside tactical resolution reduces agency if it changes committed outcomes.

thoth transformation:
Thoth rolls event complications before board load and after board resolution, records both rolls, and marks tactical resolution RNG as disabled once the board starts.

board verb:
Roll, preview, lock, resolve, record.

zone fit:
All zones can use pre-board board modifiers, offers, squad state changes, and post-board rewards/consequences without randomizing declared attacks.

counterplay:
Players see event prompts before deployment or after extraction; no event roll changes an already declared tactical hit, miss, cover result, or damage number.

preview/UI:
Event layer shows timing, event id, altered system, prompt, rule id, and whether board-start RNG lock is active.

test/replay proof:
`tests/run.lua` verifies event layers contain pre-board and post-board rolls, validate the tactical RNG lock, and serialize deterministically from the same seed.

## P.6 Seeded Full-Run Export

source pattern:
Fixed seeds and replay hashes make procedural runs inspectable and reproducible.

thoth transformation:
Thoth full-run export records run seed, board seeds, route choices, squad/loadout, event rolls, and replay hashes.

board verb:
Seed, choose, roll, hash, export.

zone fit:
All generated boards and routes write into the same export schema.

counterplay:
Export lets QA replay the exact board sequence and compare declared outcomes.

preview/UI:
Debug export view shows schema version and field list; player-facing replay sharing can hide raw internals later.

test/replay proof:
`tests/run.lua` verifies the seeded export schema version and all six required fields.

## P.7 Event Prompts

source pattern:
Run events alter route risk, board modifiers, squad condition, rewards, or faction standing outside deterministic tactical resolution.

thoth transformation:
Thoth defines 50 event prompts split across route choice, board modifier, squad state, objective reward, and faction standing.

board verb:
Offer, alter, choose, pay, record.

zone fit:
Prompts use archive claims, cistern pressure, ember ash/glass, Estate factions, and route machinery.

counterplay:
Each prompt states the altered axis before commitment so the player can accept or avoid the pressure.

preview/UI:
Event card shows prompt text and alteration category.

test/replay proof:
`tests/run.lua` verifies exactly 50 event prompts, unique ids, and coverage for route choice, board modifier, squad state, objective reward, and faction standing.
