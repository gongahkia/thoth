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
