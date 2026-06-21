# Tactical Implementation Gates

## G.1 Mechanic Entry Gate

source pattern:
New tactics mechanics need research grounding, UI preview, and replay proof before implementation.

thoth transformation:
No Thoth mechanic enters implementation without completed research handoff, preview/UI spec, and replay acceptance test.

board verb:
Research, specify, replay, gate.

zone fit:
Applies to every zone and shared tactical mechanic.

counterplay:
Gate blocks mechanics that cannot be previewed or replayed.

preview/UI:
Required evidence includes `preview_ui_spec`.

test/replay proof:
`tests/run.lua` verifies the mechanic entry gate requires research handoff, preview/UI spec, and replay acceptance test.

## G.2 Procedural Board Ship Gate

source pattern:
Generated boards need fixed-seed validation before they are allowed into a run.

thoth transformation:
No procedural board type ships without validator results for at least 25 fixed seeds and reject reason logs.

board verb:
Generate, validate, reject, ship.

zone fit:
Applies to every generated board type in every zone.

counterplay:
Gate blocks boards that pass only anecdotal playthroughs.

preview/UI:
Validator results feed debug reports, not player-facing noise.

test/replay proof:
`tests/run.lua` verifies the procedural board gate requires validator results, fixed-seed batch, reject reason log, and 25 minimum seeds.

## G.3 Class Loadout Ship Gate

source pattern:
Loadouts need proof they create tactical tradeoffs, not universally optimal picks.

thoth transformation:
No class loadout ships without one board where it is strong and one board where it is awkward.

board verb:
Fit, strain, compare.

zone fit:
Applies to every class and loadout across all zones.

counterplay:
Gate blocks loadouts that only solve one pressure axis without a cost.

preview/UI:
Preview/UI spec remains required so the loadout's board verb is visible.

test/replay proof:
`tests/run.lua` verifies the class loadout gate requires strong board fixture, awkward board fixture, and preview/UI spec.
