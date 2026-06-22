# Tactical Class Catalog

Checked: 2026-06-21

Source of truth: `src/game/tactics/class_catalog.lua`.

## CL.0 Board-Verb Contract

Every class defines `boardVerbs`, `loadoutSlots = 2`, 3-5 tools, and at least one terrain interaction. Every loadout defines exactly one `boardVerb`, spends exactly two class tools, and carries unlock metadata.

Loadout unlock rules:

- Default loadouts use `scope = default`.
- Run-earned loadouts use `scope = run`.
- Unlock rewards use `rewardKind = class_option`.
- Unlocks must not use `stat`, `statBonus`, or `permanentStat`.

Acceptance proof:

- `tests/run.lua` calls `ClassCatalog.auditBoardVerbs()` and verifies every class/loadout uses board verbs.
- `tests/run.lua` calls `ClassCatalog.auditLoadoutShape()` and verifies 2 slots, 3-5 tools, terrain interactions, and loadout tool refs.
- `tests/run.lua` calls `ClassCatalog.auditLoadoutUnlocks()` and verifies every class has a run-sourced loadout unlock.
- `tests/run.lua` calls `ClassCatalog.auditStarterRoster()` and verifies exactly six starter classes with two vertical-slice loadouts each.

## CL.0b Starter Roster

The vertical slice exposes six starter classes:

- `warden`: `line_guard` and `claim_anchor`.
- `duelist`: `red_line` and `patron_shadow`.
- `mender`: `field_triage` and `smoke_binder`.
- `harrier`: `ghost_route` and `courier_cut`.
- `arcanist`: `seal_reader` and `line_bender`.
- `lamplighter`: `beacon_runner` and `cone_keeper`.

Rules:

- Starter roster order is Warden, Duelist, Apothecary, Thief, Arcanist, Lamplighter.
- Each starter class exposes exactly two loadouts for the slice.
- Each starter loadout spends two class tools, exposes one board verb, and carries preview text.
- Each starter class records one strong board fixture and one awkward board fixture for loadout QA.
- Mission 1 uses one unit from each implemented slice class. Duplicate classes are disabled and rejected because the slice ships six distinct tactical role implementations.

Acceptance proof:

- `tests/run.lua` verifies starter roster count, order, two-loadout coverage, tool references, preview metadata, strong/awkward fixtures, and excludes non-slice classes from the starter roster.
- `tests/run.lua` verifies the squad-loadout screen model, duplicate policy, disabled start state for fewer than six selected classes, and runtime payload instantiation.

## CL.1 Warden

The Warden defines 3 loadouts:

- `line_guard`: `brace_line` using `brace_pavise` and `route_hook`.
- `claim_anchor`: `hold_claim` using `claim_spike` and `oath_tether`.
- `breach_shield`: `break_cover` using `route_hook` and `breach_maul`.

The Warden defines 5 tools:

- `brace_pavise`: raise mobile half cover.
- `route_hook`: pull ally or cargo one tile.
- `claim_spike`: brace on claim tile without losing LoS.
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

- `red_line`: `dash_strike` using `razor_dash` and `angle_step`.
- `patron_shadow`: `swap_position` using `swap_foil` and `riposte_mark`.
- `debt_blade`: `convert_flank` using `cloak_pin` and `angle_step`.

The Duelist defines 5 tools:

- `razor_dash`: dash through a safe lane before attacking.
- `angle_step`: shift one tile after a flank preview.
- `swap_foil`: swap with adjacent enemy or ally.
- `riposte_mark`: mark first enemy entering adjacent tile.
- `cloak_pin`: ignore first overwatch line while flanking.

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

- `field_triage`: `stabilize_objective` using `wound_clamp` and `salt_draught`.
- `smoke_binder`: `place_smoke` using `hush_smoke` and `salve_flare`.
- `plague_cutter`: `cleanse_hazard` using `salt_draught` and `sterilize_hook`.

The Apothecary defines 5 tools:

- `wound_clamp`: repair ally or civilian integrity.
- `salt_draught`: cleanse brine or blight status.
- `hush_smoke`: place short-lived obscurant.
- `salve_flare`: reveal safe rescue route through smoke.
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

- `seal_reader`: `reveal_hidden_mark` using `seal_lantern` and `syntax_hook`.
- `line_bender`: `bend_los` using `glyph_prism` and `syntax_hook`.
- `intent_breaker`: `interrupt_intent` using `hush_formula` and `permission_key`.

The Arcanist defines 5 tools:

- `seal_lantern`: reveal class-gated marks and weak points.
- `syntax_hook`: pull one redacted intent into exact preview.
- `glyph_prism`: bend one visible LoS ray around cover.
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

- `ghost_route`: `sneak_route` using `quiet_pick` and `route_chalk`.
- `trap_lifter`: `disarm_hazard` using `tripwire_spool` and `route_chalk`.
- `courier_cut`: `extract_cargo` using `false_warrant` and `escape_hook`.

The Thief defines 5 tools:

- `quiet_pick`: open adjacent lock without raising exposure.
- `tripwire_spool`: mark and disarm one trap lane.
- `route_chalk`: reveal hidden safe tile on current path.
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

- `bone_setter`: `stabilize_injury` using `nerve_suture` and `mercy_clamp`.
- `cautery_engineer`: `douse_burn` using `cautery_lamp` and `machine_splint`.
- `preservationist`: `preserve_body` using `preservation_saw` and `mercy_clamp`.

The Chirurgeon defines 5 tools:

- `nerve_suture`: convert injury penalty into timed AP cost.
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

- `faultbreaker`: `break_terrain` using `ruin_maul` and `fault_step`.
- `borderless`: `hold_hazard` using `hazard_hide` and `spite_breath`.
- `thrown_oath`: `throw_unit` using `exile_throw` and `ruin_maul`.

The Exile defines 5 tools:

- `ruin_maul`: destroy adjacent cover or brittle floor.
- `fault_step`: move through one broken terrain tile.
- `hazard_hide`: ignore first hazard tick this turn.
- `spite_breath`: gain AP now and take deterministic self damage.
- `exile_throw`: throw enemy or cargo one tile.

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

- `beacon_runner`: `anchor_beacon` using `route_beacon` and `smoke_gel`.
- `cone_keeper`: `project_overwatch` using `mirror_lantern` and `wick_line`.
- `ash_lamp`: `reduce_hidden_intent` using `smoke_gel` and `safe_cinder`.

The Lamplighter defines 5 tools:

- `route_beacon`: reveal hidden route tile and extraction edge.
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

## CL.9 Merchant

The Merchant defines 3 loadouts:

- `debt_broker`: `convert_debt_to_ap` using `debt_note` and `risk_ledger`.
- `salvage_factor`: `insure_salvage` using `salvage_drone` and `risk_ledger`.
- `mercy_accountant`: `insure_objective` using `appraisal_lens` and `mercy_clause`.

The Merchant defines 5 tools:

- `debt_note`: gain AP now and record deterministic debt.
- `risk_ledger`: convert incoming objective damage into future cost.
- `salvage_drone`: carry small loot without occupying a unit.
- `appraisal_lens`: mark enemy weak point or objective value.
- `mercy_clause`: repair ally or civilian now, pay later.

Terrain interactions:

- `appraise_weak_point`: reveal and mark one weak point for profit.
- `escrow_objective`: insure objective integrity before damage.

Weakness:

- `compounding_debt`: each debt tool adds a future AP tax.

Replay fixture:

- `merchant_appraise_debt`

Acceptance proof:

- `tests/run.lua` verifies Merchant loadout, tool, terrain interaction, weakness, and replay fixture counts.
- `tests/replays.lua` runs deterministic Merchant appraise and objective insurance replay fixture `merchant_appraise_debt`.

## CL.10 Character Traits

The catalog defines 20 deterministic character traits:

Required tactical domains:

- AP.
- Movement.
- LoS.
- Cooldown.
- Cover.
- Objective repair.

- `quick_account`: AP, +1 AP on first objective interaction.
- `slow_oath`: AP, first attack costs +1 AP.
- `sure_stride`: movement, ignore first rough-terrain move cost.
- `salt_limp`: movement, water or brine movement costs +1 AP.
- `beam_reader`: LoS, preview audit and heat lanes one tile farther.
- `smoke_shy`: LoS, cannot reveal through obscurant.
- `cover_drilled`: cover, first claimed cover improves by one step.
- `flank_careless`: cover, flanked damage against this unit is +1.
- `porter_arms`: carry, first cargo carry costs 0 AP.
- `fragile_grip`: carry, dragging cargo through hazard deals +1 cargo damage.
- `seal_literate`: reveal, rotation marks reveal at adjacent range.
- `mark_blind`: reveal, class reveal actions cost +1 AP.
- `short_fuse`: cooldown, first tool cooldown is reduced by one tick.
- `long_recovery`: cooldown, next cooldown gains one tick after a tool use.
- `repair_hands`: objective repair, first objective repair restores +1 integrity.
- `clumsy_patch`: objective repair, repairing destructible cover costs +1 AP.
- `enclave_favor`: event outcome, enclave events start one step friendlier.
- `debt_shadow`: event outcome, Merchant debt events add one pressure.
- `ledger_memory`: event outcome, audit events reveal one extra route clause.
- `cold_focus`: AP, ignore first AP tax from stress debt.

Acceptance proof:

- `tests/run.lua` verifies there are exactly 20 traits, every trait has id/domain/effect metadata, ids are unique, and all required domains are covered.
- `tests/run.lua` calls `ClassCatalog.auditTraitDomains()` to verify required trait domain coverage.

## CL.11 Injuries And Debts

The catalog defines 15 deterministic injuries/debts:

- `cracked_ribs`: injury/movement, climb and vault cost +1 AP.
- `salt_cough`: injury/LoS, LoS reveal range is reduced by one tile in mist.
- `burned_hand`: injury/cover, first cover interaction each board costs +1 AP.
- `glass_eye`: injury/reveal, class reveal actions require LoS to target tile.
- `brine_rot`: injury/objective repair, objective repair restores one less integrity.
- `torn_shoulder`: injury/carry, carry and drag actions cost +1 AP.
- `ash_tremor`: injury/cooldown, first tool cooldown gains one tick.
- `nerve_burn`: injury/movement, dash distance is capped at two tiles.
- `paper_lung`: injury/LoS, obscurant entry costs +1 AP.
- `ledger_debt`: debt/AP, first AP refund each board is cancelled.
- `oath_lien`: debt/objective repair, protect objective failure adds faction loss.
- `marked_warrant`: debt/event pressure, Survey Office events start at +1 pressure.
- `pawned_tool`: debt/cooldown, one chosen tool starts on cooldown.
- `witness_guilt`: debt/stress, civilian objective damage adds stress debt.
- `lamp_debt`: debt/reveal, Lamplighter reveal costs +1 AP until paid.

Rules:

- Constraints are deterministic.
- Constraints never cause random action loss.

Acceptance proof:

- `tests/run.lua` verifies there are exactly 15 constraints, ids are unique, both injury and debt types are present, and every constraint sets `noRandomActionLoss = true`.
- `tests/run.lua` calls `ClassCatalog.auditInjuryDebtConstraints()` to verify tactical domains and reject random action-loss fields.

## CL.12 Squad-Size Scaling

The catalog defines deterministic scaling for squad sizes 2 through 6:

- 2 units: 6 AP, 2 deployment slots, 0.65 enemy budget, single objective pressure, 1 reinforcement, compact 7x6 board, pair deployment, 1 lane, 2 cover fields, 1 hazard budget.
- 3 units: 9 AP, 3 deployment slots, 0.85 enemy budget, light objective pressure, 1 reinforcement, small 8x7 board, triangle deployment, 1 lane, 3 cover fields, 2 hazard budget.
- 4 units: 12 AP, 4 deployment slots, 1.00 enemy budget, standard objective pressure, 2 reinforcements, standard 10x8 board, diamond deployment, 2 lanes, 4 cover fields, 3 hazard budget.
- 5 units: 15 AP, 5 deployment slots, 1.20 enemy budget, split objective pressure, 2 reinforcements, wide 12x9 board, split deployment, 2 lanes, 5 cover fields, 4 hazard budget.
- 6 units: 18 AP, 6 deployment slots, 1.40 enemy budget, multi-front objective pressure, 3 reinforcements, large 14x10 board, two-front deployment, 3 lanes, 6 cover fields, 5 hazard budget.

Rules:

- AP budget is always `squadSize * 3`.
- Deployment slots equal squad size.
- Board area, enemy budget, and reinforcement cap are monotonic.
- Scaling covers only 2, 3, 4, 5, and 6 unit squads.

Acceptance proof:

- `tests/run.lua` verifies every supported squad size has AP, enemy budget, objective pressure, reinforcement, and board-scale metadata.
- `tests/run.lua` calls `ClassCatalog.auditSquadScaling()` to verify monotonic board variance rules.
