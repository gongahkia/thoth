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
