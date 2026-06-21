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
