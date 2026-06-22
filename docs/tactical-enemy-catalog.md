# Tactical Enemy Catalog

Checked: 2026-06-21

Source of truth: `src/game/tactics/enemy_catalog.lua`.

## E.0 Vertical Slice Elite

The content slice selects one elite:

- `shelf_knight`: Archive elite, partial guard intent, hidden-footprint mask, weak point `rear_binding`, terrain interaction `shove_shelf_wall`.

Rules:

- `EnemyCatalog.sliceEliteSpec()` returns the selected family, elite id, route fixture, role, and preview.
- `EnemyCatalog.sliceElite()` resolves to the catalog elite.
- The Archive elite route fixture includes the selected elite in the encounter director.

Acceptance proof:

- `tests/run.lua` calls `EnemyCatalog.auditSliceElite()`, verifies masked intent and weak point metadata, and checks that `archive_elite_claim` generates the selected elite.

## E.1 Archive Common Enemies

The Archive family defines 10 common enemies. Each has exact intent metadata, one distinct intent type, and one board verb:

- `hollow_guard`: `archive_overwatch_lane`, `brace_cover`.
- `ink_wretch`: `ink_line_splash`, `ink_tile`.
- `bone_scribe`: `redaction_shot`, `redact_mark`.
- `gutter_thing`: `cargo_hook_pull`, `hook_cargo`.
- `pale_censer`: `claim_fog_block`, `fog_claim`.
- `page_scout`: `flank_reposition`, `flip_shelf`.
- `writ_bailiff`: `objective_stamp`, `stamp_claim`.
- `seal_clerk`: `door_seal_guard`, `lock_door`.
- `ledger_hound`: `carrier_pursuit`, `sniff_route`.
- `drawer_mite`: `record_spill_summon`, `spill_records`.

Acceptance proof:

- `tests/run.lua` verifies the Archive has exactly 10 common enemies and each one has unique id, name, exact intent type, and board verb metadata.
- `tests/run.lua` verifies default Archive route procgen deploys catalog enemy units from `encounterDirector.enemyMix`, carries intent metadata into runtime, and covers all 10 common enemies through opening mixes or reinforcements.

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
- `salt_choir`: exact repair, `ring_pressure`.
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
- `kiln_nurse`: exact repair, `cautery_stoke`.
- `glass_penitent`: exact guard, `raise_glass`.
- `clinker_butcher`: exact attack, `hook_clinker`.
- `white_furnace`: exact destroy, `pressure_coal`.
- `glass_choirmaster`: exact debuff, `sing_reflection`.
- `cinder_penitent`: exact attack, `immolate_cinder`.
- `ember_mote`: exact summon, `seed_ember`.
- `coal_monk`: exact debuff, `chant_pressure`.

Acceptance proof:

- `tests/run.lua` verifies the Warrens has exactly 10 common enemies and each one has unique id, name, exact intent, and heat/ash/glass verb metadata.

## E.8 Warrens Elites

The Warrens family defines 3 elites with partial intent, weak points, and burn/douse/glass counterplay:

- `halo_deacon`: partial destroy intent, weak point `halo_vent`, counterplay douse halo vent before vitrify.
- `glass_cantor`: partial debuff intent, weak point `glass_throat`, counterplay shatter reflector then douse shards.
- `coal_prioress`: partial buff intent, weak point `white_coal_notch`, counterplay glassify fuel line to starve pressure.

Acceptance proof:

- `tests/run.lua` verifies the Warrens has exactly 3 elites and each one has unique id, name, partial intent, weak point, and burn/douse/glass counterplay metadata.

## E.9 Warrens Alpha

Warrens alpha:

- `white_furnace`: visible pre-board threat.

Effects:

- Pre-board threat: lights white coal on one route before entry.
- Route choice change: burns one fuel branch and opens one ash shortcut.
- Board generation change: adds heat lanes, a fuel-store fuse, and one meltable bridge.

Acceptance proof:

- `tests/run.lua` verifies the Warrens alpha is visible before board reveal and defines pre-board, route-choice, and board-generation effects.

## E.10 Global Pressure Enemies

The catalog defines 8 cross-zone pressure units for rare events:

- `survey_auditor`: Survey Office, audit route, adds redacted intent to next board.
- `survey_levy_guard`: Survey Office, asset seizure, guards extraction cargo.
- `survey_map_burner`: Survey Office, map confiscation, removes one route preview.
- `lamplighter_defector`: Lamplighter, stolen beacon, moves hidden-intent reveal farther away.
- `lamp_claimant`: Lamplighter, claimed light, adds overwatch cone to lit routes.
- `merchant_collector`: Merchant, debt collection, adds AP tax until cargo is paid.
- `debt_drone`: Merchant, salvage escrow, steals unclaimed loot on timer.
- `contract_knight`: Merchant, called collateral, protects enemy objective with legal cover.

Acceptance proof:

- `tests/run.lua` verifies there are exactly 8 global pressure enemies, ids are unique, required metadata is present, and Survey Office, Lamplighter, and Merchant factions are represented.

## E.11 No-Damage Utility Behavior

Every catalog enemy has a deterministic no-damage utility behavior:

- Archive enemies can claim, reveal, seal, or reposition records without damage.
- Cistern enemies can shift water, bell pressure, or drain state without damage.
- Warrens enemies can alter heat, ash, glass, or fuel state without damage.
- Global pressure enemies can apply rare-event pressure without damage.

Rules:

- Utility behavior has an id, effect, and `damage = 0`.
- Enemy ids are deduplicated when auditing all enemies.

Acceptance proof:

- `tests/run.lua` audits every enemy returned by `EnemyCatalog.allEnemies()` and verifies each has a no-damage utility behavior.

## E.12 Common Enemy Archetypes

Common enemies use 11 canonical archetypes:

- `mover`: changes position pressure; represented by `page_scout`, `sluice_eel`, and `kiln_imp`.
- `shooter`: direct previewed harm; represented by `bone_scribe`, `ledger_hound`, `drowned_pilgrim`, and `cinder_penitent`.
- `artillery`: area or lane pressure; represented by `ink_wretch`, `drowned_acolyte`, and `glass_choirmaster`.
- `pusher`: forced displacement; represented by `halocline_tender` and `ash_husk`.
- `puller`: hook/current displacement; represented by `gutter_thing`, `brine_stalker`, and `clinker_butcher`.
- `blocker`: denies tiles, edges, or claims; represented by `pale_censer`, `seal_clerk`, and `pearl_cyst`.
- `summoner`: creates spawn pressure; represented by `drawer_mite`, `brine_midwife`, and `ember_mote`.
- `repairer`: sustains or restores enemy board state; represented by `salt_choir` and `kiln_nurse`.
- `saboteur`: pressures objectives or route state; represented by `writ_bailiff`, `reed_mouth_diver`, and `coal_monk`.
- `overwatch`: posts reaction lanes; represented by `hollow_guard` and `glass_penitent`.
- `terrain-breaker`: converts or destroys terrain; represented by `valve_thrall` and `white_furnace`.

Rules:

- Every archetype declares intent, board verb, counterplay, and preview text.
- Every common enemy must reference one known archetype.
- Every zone family must keep 8-12 common enemies.
- Required archetypes must be represented by at least one common enemy.

Acceptance proof:

- `EnemyCatalog.auditArchetypes()` rejects missing archetypes, missing archetype metadata, invalid common enemy references, missing exact intents, missing zone verbs, out-of-range family counts, and uncovered required archetypes.
- `tests/run.lua` verifies every required archetype has metadata and common-enemy coverage.

## E.13 Basic Enemy Exact Intents

Every common enemy has an exact intent blueprint.

Fields:

- `source`: always `self` at catalog level.
- `category`: exact category used by intent preview.
- `target`: named target rule.
- `targetPattern`: footprint rule before board coordinates are known.
- `pathPattern`: trace rule before board coordinates are known.
- `damage`: deterministic damage value.
- `effect`: deterministic effect label.
- `objectiveImpact`: objective pressure label, or `none`.
- `counterplay`: one or more legal answers.
- `preview`: inspector-facing preview cue.
- `deterministic`: always `true`.

Rules:

- Runtime declarations still supply board-specific `targetTiles` and `path`; catalog blueprints never fake coordinates.
- Push and pull archetypes must include collision metadata.
- Every zone family must have exact-intent coverage for all common enemies.

Acceptance proof:

- `EnemyCatalog.auditExactBasicIntents()` rejects missing exact intents, non-exact modes, missing source/category/target/damage, missing target/path/effect/preview metadata, missing counterplay, missing objective impact, nondeterministic flags, forced-movement intents without collision, and incomplete family coverage.
- `tests/run.lua` verifies exact-intent coverage and metadata for every common enemy in Archive, Cistern, and Warrens.

## E.14 Elite Partial And Masked Intents

Every elite keeps a category-visible partial intent and gains a hidden-footprint masked intent blueprint.

Fields:

- `partialIntent`: category-only preview used by encounter generation.
- `maskedIntent`: hidden-footprint preview blueprint.
- `mask`: zone mask such as seal, waterline, or ash/glass.
- `targetPattern`: hidden footprint rule before board coordinates are known.
- `pathPattern`: hidden trace rule before board coordinates are known.
- `revealGate`: weak point, reveal class, and reveal action.
- `counterplay`: weak-point exposure plus zone counterplay.
- `preview`: inspector-facing masked preview cue.
- `deterministic`: always `true`.
- `footprintHidden`: always `true` until reveal.

Rules:

- Masked intent category must match partial intent category.
- Reveal gate weak point must be the elite's first listed weak point.
- Runtime hidden-footprint declarations still supply board-specific private `targetTiles`.
- Every elite must keep zone counterplay metadata.

Acceptance proof:

- `EnemyCatalog.auditEliteMaskedIntents()` rejects missing partial intents, non-category partials, missing masked intents, non-hidden-footprint masks, category mismatch, missing preview metadata, missing reveal gates, weak-point mismatch, missing counterplay, nondeterministic flags, unhidden footprint flags, missing zone counterplay, and incomplete family coverage.
- `tests/run.lua` verifies masked-intent coverage and weak-point reveal metadata for every elite in Archive, Cistern, and Warrens.
