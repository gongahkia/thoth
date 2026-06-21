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
