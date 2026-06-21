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
