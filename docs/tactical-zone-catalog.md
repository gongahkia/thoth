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
