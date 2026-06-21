# Tactical Zone Catalog

Checked: 2026-06-21

Source of truth: `src/game/tactics/zone_catalog.lua`.

## Z.1 Buried Archive Tile Mechanics

The Buried Archive defines 12 deterministic tile mechanics:

- `archive_shelf_shift`: shelves shove full cover and can crush lanes.
- `archive_claim_desk`: desks become half-cover claim tiles for hold objectives.
- `archive_claim_line`: claim lines score presence while intents escalate.
- `archive_sealed_door`: sealed doors block movement and LoS until opened.
- `archive_witness_drawer`: witness drawers reveal redacted intent or hidden tile marks.
- `archive_falling_records`: falling records run a delayed fuse that creates blocker and damage.
- `archive_name_lock`: name locks spend AP/tool actions to open a route or objective.
- `archive_audit_beam`: audit beams create visible LoS lanes that pressure movement.
- `archive_misfile_pit`: misfile pits apply forced movement and elevation changes.
- `archive_ledger_bridge`: ledger bridges toggle split-squad crossing dependencies.
- `archive_paper_swarm`: paper swarms create visible obscurants with countdowns.
- `archive_back_face_seal`: back-face seals expose rotation-only planning facts.

Acceptance proof:

- `tests/run.lua` verifies the Buried Archive exposes exactly 12 tile mechanics and each has subject, verb, and effect metadata.

## Z.2 Buried Archive Objects

The Buried Archive defines 8 destructible or interactable objects:

- `rolling_shelf`: 2 AP, 5 HP, full cover, blocks LoS until shoved or broken, reverse side marks a crush lane.
- `oath_desk`: 1 AP, 3 HP, half cover after tipped, reverse side marks a claim desk.
- `sealed_stacks_door`: 2 AP, 4 HP, opaque while sealed, reverse side marks an alternate hinge.
- `witness_drawer_bank`: 1 AP, 2 HP, no cover, reveal action source, reverse side marks a hidden witness.
- `record_crate`: 1 AP, 2 HP, half blocker after spilled, reverse side marks a falling-record arc.
- `name_lock_plinth`: 2 AP, 3 HP, route-node blocker, reverse side marks the true-name socket.
- `audit_lens_stand`: 1 AP, 2 HP, projects a visible straight lane, reverse side marks beam bearing.
- `ledger_bridge_winch`: 2 AP, 4 HP, toggles a crossing, reverse side marks bridge latch.

Acceptance proof:

- `tests/run.lua` verifies the Buried Archive exposes exactly 8 objects and each has AP cost, HP, LoS effect, cover state, and rotation metadata.

## Z.3 Salt Cistern Tile Mechanics

The Salt Cistern defines 12 deterministic tile mechanics:

- `cistern_valve_turn`: valves raise or drain declared water bands.
- `cistern_sluice_current`: sluice currents push units along previewed arrows after actions.
- `cistern_flood_lane`: flood lanes surge as delayed line hazards.
- `cistern_brine_pool`: brine pools slow movement and threaten blight damage.
- `cistern_salt_mist`: salt mist visibly obscures LoS and reveal ranges.
- `cistern_pressure_bell`: pressure bells escalate enemy intent on flooded rows.
- `cistern_pearl_cyst`: pearl cysts burst into blocker shards and brine splash.
- `cistern_pump_bridge`: pump bridges toggle crossings by waterline state.
- `cistern_undertow_tile`: undertow tiles drag exposed units toward drains.
- `cistern_drain_grate`: drain grates remove nearby flood lanes and create pit risk.
- `cistern_floating_cover`: floating cover drifts with currents as half cover.
- `cistern_waterline_height`: waterline height changes movement cost and LoS height bands.

Acceptance proof:

- `tests/run.lua` verifies the Salt Cistern exposes exactly 12 tile mechanics and each has subject, verb, and effect metadata.

## Z.4 Salt Cistern Objects

The Salt Cistern defines 8 destructible or interactable objects:

- `tide_valve`: 2 AP, 4 HP, drains one flood band and repairs floodgate integrity.
- `sluice_gate`: 2 AP, 5 HP, full cover while shut, opens delayed flood lanes, can damage route machinery when broken.
- `pressure_bell_frame`: 1 AP, 3 HP, calls surge on wet rows and pressures protect nodes.
- `pearl_cyst_cluster`: 1 AP, 4 HP, half cover, adds brine splash and can damage civilian cells.
- `pump_bridge_wheel`: 2 AP, 4 HP, raises a bridge while lowering adjacent water, opening extract routes.
- `drain_grate_cap`: 1 AP, 3 HP, drains adjacent flood tiles but risks repair target integrity.
- `floating_barricade`: 1 AP, 3 HP, drifting half cover that can shield machinery cores.
- `waterline_gauge`: 1 AP, 2 HP, previews next rise or drain and prevents objective integrity surprises.

Acceptance proof:

- `tests/run.lua` verifies the Salt Cistern exposes exactly 8 objects and each has AP cost, HP, LoS effect, cover state, rotation, flood, and objective metadata.

## Z.5 Ember Warrens Tile Mechanics

The Ember Warrens defines 12 deterministic tile mechanics:

- `warrens_kiln_heat`: kilns create declared heat around kiln mouths.
- `warrens_ash_choke`: ash choke slows movement and obscures low LoS.
- `warrens_bellows_cone`: bellows cones push heat and units through previewed cones.
- `warrens_glass_floor`: glass floors reveal fragile paths and shard hazards.
- `warrens_vitrified_cover`: vitrified cover reflects the first line effect until shattered.
- `warrens_heat_lane`: heat lanes burn marked rows after a delay.
- `warrens_fuel_store`: fuel stores ignite into timed fire bursts and smoke.
- `warrens_ember_oil`: ember oil spreads burn tiles until doused.
- `warrens_furnace_door`: furnace doors toggle blocker and vent states.
- `warrens_cinder_vent`: cinder vents spawn ash choke after heat ticks.
- `warrens_white_coal_pressure`: white-coal pressure escalates heat intent unless released.
- `warrens_meltable_bridge`: meltable bridges turn crossings into hazards after countdowns.

Acceptance proof:

- `tests/run.lua` verifies the Ember Warrens exposes exactly 12 tile mechanics and each has subject, verb, and effect metadata.

## Z.6 Ember Warrens Objects

The Ember Warrens defines 8 destructible or interactable objects:

- `kiln_mouth`: 2 AP, 5 HP, full cover, burns heat lanes, douses next heat tick, glassifies into cover lips.
- `ash_heap`: 1 AP, 3 HP, half cover, burns into smoke, douses into rough tile, glassifies into brittle cover.
- `bellows_spine`: 2 AP, 4 HP, extends heat cones, douses for one tick, glassifies to lock cone bearing.
- `glass_screen`: 1 AP, 2 HP, reflective half cover, burns adjacent lanes, douses to reveal marks, glassifies to full reflective cover.
- `fuel_cart`: 1 AP, 3 HP, mobile half cover, burns after fuse, douses into safe cover, glassifies as full blocker.
- `ember_oil_cask`: 1 AP, 2 HP, spreads burn tiles, douses oil trails, glassifies into slick floor.
- `furnace_door_chain`: 2 AP, 4 HP, toggles opaque door, burns heat bursts, douses safe seals, glassifies jammed open.
- `white_coal_cradle`: 2 AP, 4 HP, half cover, raises pressure, douses safely, glassifies into permanent hazard.

Acceptance proof:

- `tests/run.lua` verifies the Ember Warrens exposes exactly 8 objects and each has AP cost, HP, LoS effect, cover state, rotation, burn, douse, and glassify metadata.

## Z.7 Rotation-Revealed Facts

Each zone defines at least 4 rotation-revealed facts that change planning information only:

- Buried Archive: shelf weight, claim stamp, audit bearing, name order.
- Salt Cistern: valve sequence, current arrow, bell radius, safe waterline.
- Ember Warrens: bellows bearing, glass reflection, fuel spill, white-coal notch.

Rules:

- Rotation facts have ids, fact text, and planning impact text.
- Rotation facts set `changesState = false`.
- Rotation facts expose information without mutating board state.

Acceptance proof:

- `tests/run.lua` verifies every zone has at least 4 rotation facts and each one is metadata-only.

## Z.8 Double-Edged Terrain Mechanics

Each zone defines at least 3 terrain mechanics marked `helpsEitherSide = true`:

- Buried Archive: shelf shift, audit beam, paper swarm.
- Salt Cistern: sluice current, brine pool, floating cover.
- Ember Warrens: ash choke, bellows cone, vitrified cover.

Rules:

- Double-edged mechanics can help player or enemy depending on positioning.
- The preview data stays deterministic.

Acceptance proof:

- `tests/run.lua` verifies every zone has at least 3 mechanics marked `helpsEitherSide`.
