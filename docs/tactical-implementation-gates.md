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

## G.4 Enemy Ship Gate

source pattern:
Readable tactics enemies need visible intent and deterministic counterplay before they enter encounters.

thoth transformation:
No enemy ships without intent preview, counterplay path, and no-damage utility behavior.

board verb:
Preview, answer, utility.

zone fit:
Applies to common enemies, elites, alphas, and global pressure enemies.

counterplay:
Gate blocks enemies whose only answer is damage racing.

preview/UI:
Required intent preview must be inspectable before resolution.

test/replay proof:
`tests/run.lua` verifies the enemy ship gate requires intent preview, counterplay path, and no-damage utility behavior.

## G.5 Boss Ship Gate

source pattern:
Boss encounters need phase evidence, arena readability, objective pressure, and replay proof before shipping.

thoth transformation:
No boss ships without phase chart, arena diagram, objective pressure, and replay proof.

board verb:
Phase, diagram, pressure, replay.

zone fit:
Applies to all boss and boss-variant boards.

counterplay:
Gate blocks bosses that rely on surprise phases or unreadable arenas.

preview/UI:
Phase chart and arena diagram must support the boss phase card and overlay preview.

test/replay proof:
`tests/run.lua` verifies the boss ship gate requires phase chart, arena diagram, objective pressure, and replay proof.

## G.6 Borrowed Pattern Ship Gate

source pattern:
Borrowed design patterns must be transformed into Thoth's rules and language before shipping.

thoth transformation:
No borrowed pattern ships without documented Thoth transformation in `docs/tactical-research-index.md`.

board verb:
Source, transform, document, gate.

zone fit:
Applies to mechanics, UI, procgen, classes, enemies, bosses, and run events.

counterplay:
Gate blocks copied mechanics that lack Thoth-specific board verbs and preview contracts.

preview/UI:
Research index must tie the source pattern to a Thoth transformation before implementation.

test/replay proof:
`tests/run.lua` verifies the borrowed-pattern gate points to `docs/tactical-research-index.md`, requires transformation evidence, and the index contains `Thoth transformation`.
