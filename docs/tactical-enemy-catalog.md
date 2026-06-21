# Tactical Enemy Catalog

Checked: 2026-06-21

Source of truth: `src/game/tactics/enemy_catalog.lua`.

## E.1 Archive Common Enemies

The Archive family defines 10 common enemies. Each has exact intent metadata and one board verb:

- `hollow_guard`: exact attack, `brace_cover`.
- `ink_wretch`: exact debuff, `ink_tile`.
- `bone_scribe`: exact attack, `redact_mark`.
- `gutter_thing`: exact move, `hook_cargo`.
- `pale_censer`: exact debuff, `fog_claim`.
- `page_scout`: exact move, `flip_shelf`.
- `writ_bailiff`: exact destroy, `stamp_claim`.
- `seal_clerk`: exact guard, `lock_door`.
- `ledger_hound`: exact attack, `sniff_route`.
- `drawer_mite`: exact summon, `spill_records`.

Acceptance proof:

- `tests/run.lua` verifies the Archive has exactly 10 common enemies and each one has unique id, name, exact intent, and board verb metadata.

## E.2 Archive Elites

The Archive family defines 3 elites with partial intent, weak points, and terrain interaction:

- `codex_advocate`: partial debuff intent, weak point `open_register`, interaction `seal_claim_line`.
- `shelf_knight`: partial guard intent, weak point `rear_binding`, interaction `shove_shelf_wall`.
- `writ_cantor`: partial summon intent, weak point `choir_chain`, interaction `ring_audit_beam`.

Acceptance proof:

- `tests/run.lua` verifies the Archive has exactly 3 elites and each one has unique id, name, partial intent, weak point, and terrain interaction metadata.

## E.3 Archive Alpha

Archive alpha:

- `shelf_warden`: visible pre-board threat.

Effects:

- Pre-board threat: pursues the chosen archive route before board reveal.
- Route choice change: marks one adjacent archive node as audited.
- Board generation change: adds two shoveable shelf blockers and one audit beam lane.

Acceptance proof:

- `tests/run.lua` verifies the Archive alpha is visible before board reveal and defines pre-board, route-choice, and board-generation effects.

## E.4 Cistern Common Enemies

The Cistern family defines 10 common enemies. Each has exact intent metadata and one water/pressure verb:

- `drowned_acolyte`: exact debuff, `raise_mist`.
- `brine_stalker`: exact attack, `pull_current`.
- `valve_thrall`: exact destroy, `turn_valve`.
- `brine_midwife`: exact summon, `birth_brine`.
- `sluice_eel`: exact move, `ride_sluice`.
- `salt_choir`: exact buff, `ring_pressure`.
- `pearl_cyst`: exact guard, `burst_pool`.
- `halocline_tender`: exact debuff, `shift_halocline`.
- `drowned_pilgrim`: exact attack, `kneel_flood`.
- `reed_mouth_diver`: exact flee, `signal_reed`.

Acceptance proof:

- `tests/run.lua` verifies the Cistern has exactly 10 common enemies and each one has unique id, name, exact intent, and water/pressure verb metadata.

## E.5 Cistern Elites

The Cistern family defines 3 elites with partial intent, weak points, and flood/drain counterplay:

- `depth_bailiff`: partial destroy intent, weak point `depth_warrant`, counterplay drain adjacent pressure bell.
- `pearl_choir`: partial summon intent, weak point `choir_throat`, counterplay lower waterline before chorus.
- `undertow_notary`: partial move intent, weak point `tide_stamp`, counterplay open drain grate to break pull lane.

Acceptance proof:

- `tests/run.lua` verifies the Cistern has exactly 3 elites and each one has unique id, name, partial intent, weak point, and flood/drain counterplay metadata.

## E.6 Cistern Alpha

Cistern alpha:

- `depth_bailiff`: visible pre-board threat.

Effects:

- Pre-board threat: posts a depth warrant on the route map.
- Route choice change: floods one shallow route and discounts one pump route.
- Board generation change: adds one pressure bell, two flood lanes, and raised low-ground punishment.

Acceptance proof:

- `tests/run.lua` verifies the Cistern alpha is visible before board reveal and defines pre-board, route-choice, and board-generation effects.

## E.7 Warrens Common Enemies

The Warrens family defines 10 common enemies. Each has exact intent metadata and one heat/ash/glass verb:

- `ash_husk`: exact attack, `kick_ash`.
- `kiln_imp`: exact move, `spark_jump`.
- `kiln_nurse`: exact buff, `cautery_stoke`.
- `glass_penitent`: exact guard, `raise_glass`.
- `clinker_butcher`: exact attack, `hook_clinker`.
- `white_furnace`: exact destroy, `pressure_coal`.
- `glass_choirmaster`: exact debuff, `sing_reflection`.
- `cinder_penitent`: exact attack, `immolate_cinder`.
- `ember_mote`: exact summon, `seed_ember`.
- `coal_monk`: exact debuff, `chant_pressure`.

Acceptance proof:

- `tests/run.lua` verifies the Warrens has exactly 10 common enemies and each one has unique id, name, exact intent, and heat/ash/glass verb metadata.
