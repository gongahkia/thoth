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
