# Tactical Class Catalog

Checked: 2026-06-21

Source of truth: `src/game/tactics/class_catalog.lua`.

## CL.1 Warden

The Warden defines 3 loadouts:

- `line_guard`: frontline protector using `brace_pavise` and `route_hook`.
- `claim_anchor`: objective holder using `claim_spike` and `oath_tether`.
- `breach_shield`: cover breaker using `shelf_shove_kit` and `breach_maul`.

The Warden defines 6 tools:

- `brace_pavise`: raise mobile half cover.
- `route_hook`: pull ally or cargo one tile.
- `claim_spike`: brace on claim tile without losing LoS.
- `shelf_shove_kit`: shove full cover or blockers.
- `oath_tether`: redirect first objective hit to Warden guard.
- `breach_maul`: damage destructible cover and expose flanks.

Terrain interactions:

- `raise_mobile_cover`: turn adjacent low object into half cover.
- `shove_blocker`: move a shelf, barricade, or cart into a lane.

Weakness:

- `slow_to_pivot`: after guarding an objective, next move costs +1 AP.

Replay fixture:

- `warden_brace_line`

Acceptance proof:

- `tests/run.lua` verifies Warden loadout, tool, terrain interaction, weakness, and replay fixture counts.
- `tests/replays.lua` runs deterministic Warden shove and repair replay fixture `warden_brace_line`.

## CL.2 Duelist

The Duelist defines 3 loadouts:

- `red_line`: dash striker using `razor_dash` and `angle_step`.
- `patron_shadow`: position trader using `swap_foil` and `riposte_mark`.
- `debt_blade`: flank finisher using `cloak_pin` and `ledger_stiletto`.

The Duelist defines 6 tools:

- `razor_dash`: dash through a safe lane before attacking.
- `angle_step`: shift one tile after a flank preview.
- `swap_foil`: swap with adjacent enemy or ally.
- `riposte_mark`: mark first enemy entering adjacent tile.
- `cloak_pin`: ignore first overwatch line while flanking.
- `ledger_stiletto`: bonus damage against isolated objective guards.

Terrain interactions:

- `vault_low_cover`: vault low cover without ending movement.
- `cut_hanging_line`: drop hanging cover into a flank lane.

Weakness:

- `overextends`: after dashing, adjacent enemies add +1 incoming damage.

Replay fixture:

- `duelist_flank_dash`

Acceptance proof:

- `tests/run.lua` verifies Duelist loadout, tool, terrain interaction, weakness, and replay fixture counts.
- `tests/replays.lua` runs deterministic Duelist dash, strike, and swap replay fixture `duelist_flank_dash`.

## CL.3 Apothecary

The Apothecary defines 3 loadouts:

- `field_triage`: objective medic using `wound_clamp` and `salt_draught`.
- `smoke_binder`: LoS controller using `hush_smoke` and `salve_flare`.
- `plague_cutter`: hazard cleanser using `bitter_vial` and `sterilize_hook`.

The Apothecary defines 6 tools:

- `wound_clamp`: repair ally or civilian integrity.
- `salt_draught`: cleanse brine or blight status.
- `hush_smoke`: place short-lived obscurant.
- `salve_flare`: reveal safe rescue route through smoke.
- `bitter_vial`: apply deterministic debuff to one enemy.
- `sterilize_hook`: drag cargo or patient out of hazard.

Terrain interactions:

- `douse_brine_pool`: turn adjacent brine or burn tile inactive.
- `smoke_claim_line`: obscure claim tile without changing ownership.

Weakness:

- `triage_burden`: after repairing an objective, next carry or drag costs +1 AP.

Replay fixture:

- `apothecary_smoke_triage`

Acceptance proof:

- `tests/run.lua` verifies Apothecary loadout, tool, terrain interaction, weakness, and replay fixture counts.
- `tests/replays.lua` runs deterministic Apothecary smoke and repair replay fixture `apothecary_smoke_triage`.

## CL.4 Arcanist

The Arcanist defines 3 loadouts:

- `seal_reader`: hidden-info reader using `seal_lantern` and `syntax_hook`.
- `line_bender`: LoS manipulator using `glyph_prism` and `angle_wax`.
- `intent_breaker`: intent disruptor using `hush_formula` and `permission_key`.

The Arcanist defines 6 tools:

- `seal_lantern`: reveal class-gated marks and weak points.
- `syntax_hook`: pull one redacted intent into exact preview.
- `glyph_prism`: bend one visible LoS ray around cover.
- `angle_wax`: mark a tile as readable from current rotation.
- `hush_formula`: interrupt one ritual or category intent.
- `permission_key`: treat one sealed tile as passable for a move.

Terrain interactions:

- `read_back_seal`: reveal planning fact from reverse face.
- `bend_audit_beam`: redirect one audit or heat line preview.

Weakness:

- `overread`: after revealing hidden info, next incoming stress is +2.

Replay fixture:

- `arcanist_seal_read`

Acceptance proof:

- `tests/run.lua` verifies Arcanist loadout, tool, terrain interaction, weakness, and replay fixture counts.
- `tests/replays.lua` runs deterministic Arcanist seal and intent reveal replay fixture `arcanist_seal_read`.

## CL.5 Thief

The Thief defines 3 loadouts:

- `ghost_route`: stealth runner using `quiet_pick` and `route_chalk`.
- `trap_lifter`: hazard disarmer using `tripwire_spool` and `pocket_lantern`.
- `courier_cut`: objective extractor using `false_warrant` and `escape_hook`.

The Thief defines 6 tools:

- `quiet_pick`: open adjacent lock without raising exposure.
- `tripwire_spool`: mark and disarm one trap lane.
- `route_chalk`: reveal hidden safe tile on current path.
- `pocket_lantern`: reveal one nearby hidden pickup.
- `false_warrant`: carry objective cargo at normal move cost.
- `escape_hook`: pull self or cargo to extraction edge.

Terrain interactions:

- `disarm_name_lock`: disable adjacent lock without breaking cover.
- `slip_drain_grate`: move through a low drain or shelf gap.

Weakness:

- `thin_loyalty`: while carrying loot, guard effects on allies cost +1 AP.

Replay fixture:

- `thief_route_lift`

Acceptance proof:

- `tests/run.lua` verifies Thief loadout, tool, terrain interaction, weakness, and replay fixture counts.
- `tests/replays.lua` runs deterministic Thief cargo lift and extraction replay fixture `thief_route_lift`.

## CL.6 Chirurgeon

The Chirurgeon defines 3 loadouts:

- `bone_setter`: injury stabilizer using `nerve_suture` and `pain_contract`.
- `cautery_engineer`: burn controller using `cautery_lamp` and `machine_splint`.
- `preservationist`: body-objective repair using `preservation_saw` and `mercy_clamp`.

The Chirurgeon defines 6 tools:

- `nerve_suture`: convert injury penalty into timed AP cost.
- `pain_contract`: brace ally with deterministic stress debt.
- `cautery_lamp`: douse bleed or burn lane around patient.
- `machine_splint`: repair machinery objective integrity.
- `preservation_saw`: extract body cargo without integrity loss.
- `mercy_clamp`: prevent one civilian objective damage tick.

Terrain interactions:

- `repair_machinery`: restore objective machinery integrity.
- `cauterize_burn_lane`: turn adjacent burn hazard inactive.

Weakness:

- `clinical_delay`: after stabilizing an ally, next attack costs +1 AP.

Replay fixture:

- `chirurgeon_stabilize_machine`

Acceptance proof:

- `tests/run.lua` verifies Chirurgeon loadout, tool, terrain interaction, weakness, and replay fixture counts.
- `tests/replays.lua` runs deterministic Chirurgeon brace and machinery repair replay fixture `chirurgeon_stabilize_machine`.

## CL.7 Exile

The Exile defines 3 loadouts:

- `faultbreaker`: terrain breaker using `ruin_maul` and `fault_step`.
- `borderless`: hazard brawler using `hazard_hide` and `spite_breath`.
- `thrown_oath`: forced-move bruiser using `exile_throw` and `broken_oath_grip`.

The Exile defines 6 tools:

- `ruin_maul`: destroy adjacent cover or brittle floor.
- `fault_step`: move through one broken terrain tile.
- `hazard_hide`: ignore first hazard tick this turn.
- `spite_breath`: gain AP now and take deterministic self damage.
- `exile_throw`: throw enemy or cargo one tile.
- `broken_oath_grip`: pin target against blocker after shove.

Terrain interactions:

- `break_cover`: destroy adjacent cover and expose line.
- `stand_in_hazard`: hold hazard tile without random action loss.

Weakness:

- `self_risk_spike`: AP spikes deal 1 deterministic self damage.

Replay fixture:

- `exile_break_cover`

Acceptance proof:

- `tests/run.lua` verifies Exile loadout, tool, terrain interaction, weakness, and replay fixture counts.
- `tests/replays.lua` runs deterministic Exile cover break and attack replay fixture `exile_break_cover`.

## CL.8 Lamplighter

The Lamplighter defines 3 loadouts:

- `beacon_runner`: route revealer using `route_beacon` and `white_flare`.
- `cone_keeper`: overwatch controller using `mirror_lantern` and `wick_line`.
- `ash_lamp`: hidden-intent reducer using `smoke_gel` and `safe_cinder`.

The Lamplighter defines 6 tools:

- `route_beacon`: reveal hidden route tile and extraction edge.
- `white_flare`: force redacted intent into exact preview.
- `mirror_lantern`: project overwatch cone around cover.
- `wick_line`: connect two lit tiles for ally movement.
- `smoke_gel`: turn smoke into light-blocking obscurant.
- `safe_cinder`: mark one hazard tile safe for this turn.

Terrain interactions:

- `light_back_seal`: reveal back-face planning fact at range.
- `anchor_beacon`: make extraction route visible through obscurant.

Weakness:

- `bright_target`: after placing a beacon, exact intents against Lamplighter deal +1 damage.

Replay fixture:

- `lamplighter_beacon_reveal`

Acceptance proof:

- `tests/run.lua` verifies Lamplighter loadout, tool, terrain interaction, weakness, and replay fixture counts.
- `tests/replays.lua` runs deterministic Lamplighter beacon and intent reveal replay fixture `lamplighter_beacon_reveal`.
