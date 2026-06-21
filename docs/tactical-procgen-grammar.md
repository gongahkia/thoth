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
