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
