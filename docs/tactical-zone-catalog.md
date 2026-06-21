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
