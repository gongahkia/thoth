# Tactical Core Rules

Checked: 2026-06-21

Source of truth: `src/game/tactics/state.lua`. This doc names the current tactical contracts so content work does not infer rules from legacy expedition combat.

## M.1 Tile Schema

Tactical boards are square logical grids. Each tile is addressed by `x:y` and normalizes to these fields:

| Field | Type | Rule |
| --- | --- | --- |
| `kind` | string | Tile identity. Defaults to `floor`. |
| `material` | string | Zone material language such as `archive`, `salt`, or `ember`. |
| `height` | integer | Logical height. Defaults to `0`. |
| `coverEdges` | map | `north/east/south/west`, each `none`, `half`, or `full`. |
| `blocker` | boolean | Blocks movement when true. |
| `losBlocker` | boolean | Blocks line-of-sight logic when true. |
| `destructibleHp` | integer or nil | Damage pool for destructible terrain. |
| `hazard` | map | Hazard payload for deterministic preview/resolution. |
| `objective` | map | Tile-attached objective payload. |
| `revealed` | boolean | Hidden-info state. Defaults to true. |
| `destroyed` | boolean | Persisted state after terrain destruction. |
| `rotationMarks` | map | Direction-keyed facts revealed by camera angle. |
| `tags` | list | Extra deterministic selectors for generators, UI, or tests. |

Destruction rule: when `destructibleHp` reaches zero, the tile keeps identity/history but clears `blocker`, `losBlocker`, and all cover edges, then sets `destroyed = true`.

Acceptance proof:

- `tests/run.lua` verifies schema normalization, nested hazard/objective roundtrip, LoS blockers separate from movement blockers, and destroyed terrain snapshot persistence.
- `docs/tactical-pivot-prototype.md` records the prototype result and current cuts.

## M.2 AP Baseline

Default AP is `2` per active unit unless a fixture/tool explicitly overrides `defaultAp`, `maxAp`, or command cost.

Baseline rules:

- Team-turn model is the default prototype shape.
- Movement spends AP through `moveApCost`; default move cost is `1`.
- Actions spend AP through command cost; current tactical verbs default to `1` unless passed a different explicit cost.
- `wait` costs `0` by default.
- AP spend fails fast when a unit lacks AP.
- AP cannot go negative through core commands.
- Evacuated or defeated units cannot spend AP.
- AP debt is not a core rule. It is reserved for explicit future class/tool mechanics, such as Merchant debt trades.

Acceptance proof:

- `tests/run.lua` verifies 3-unit and 5-unit squads, AP spend isolation, insufficient-AP failure, phase reset behavior, movement AP cost, and inactive-side AP preservation.

## M.3 Movement Preview

Movement preview is deterministic and side-effect free.

Preview output includes:

- Reachable tiles up to the unit's current AP or explicit `maxCost`.
- Per-tile AP cost.
- Per-tile hazard cost.
- Path directions from the starting tile.
- Cover gained and cover lost relative to the starting tile.
- Objective carry impact, including integrity delta from hazardous carry routes.
- Collision records for blocked, occupied, and out-of-bounds candidate moves.

Preview does not mutate unit position, AP, objective state, hazard state, or threat zones.

Acceptance proof:

- `tests/run.lua` verifies reachable AP cost, hazard cost, cover gained/lost, objective carry impact, blocked-tile collision, and occupied-tile collision.

## M.4 Shove, Pull, And Swap

Forced movement is deterministic.

Rules:

- `shove` moves a target along an explicit cardinal direction.
- `pull` moves a target toward the acting unit on the dominant axis.
- `swap` exchanges active unit positions.
- Blocked forced movement stops at the blocked edge and deals collision damage to the moved unit.
- Forced movement into an occupied tile stops and deals collision damage to both units.
- Forced movement into an active route-machinery objective damages objective integrity.
- Threat zones can trigger from forced movement after a successful displacement step.
- Evacuated or defeated units cannot be moved or swapped by core commands.

Acceptance proof:

- `tests/run.lua` verifies shove, pull, swap, blocked movement, collision damage, objective collision, and enemy friendly-fire collision.

## M.5 Dash, Vault, Climb, And Drop

Traversal commands are explicit. They do not create hidden LoS exceptions or mutate `losBlocker`.

Rules:

- `dash` moves multiple tiles along one cardinal direction after validating the full path.
- `vault` crosses one tile only through a half-cover edge. Full cover blocks vault.
- `climb` moves to a higher adjacent tile when the height delta is within `maxClimb`.
- `drop` moves to a lower adjacent tile when the height delta is within `maxDrop`.
- Each command spends explicit AP only after validation succeeds.
- Threat zones may trigger after each successful movement step.
- Height movement reads tile `height`; it does not alter cover edges, blockers, or LoS blockers.

Acceptance proof:

- `tests/run.lua` verifies dash distance, half-cover vault, full-cover vault rejection without AP spend, climb/drop height checks, and unchanged LoS blocker state.

## M.6 Carry And Drag

Cargo is explicit board state, separate from units and objectives.

Supported cargo kinds:

- `civilian`
- `body`
- `machinery_core`
- `loot_crate`
- `wounded_hero`

Rules:

- `carryCargo` attaches adjacent or same-tile cargo to one active unit.
- A unit can carry only one cargo item.
- Carried cargo follows the unit on movement, dash, climb, drop, and vault.
- Hazard `carryDamage` reduces carried cargo integrity.
- `dropCargo` detaches carried cargo on the unit tile or a chosen adjacent tile.
- `dragCargo` moves adjacent uncarried cargo one tile in a cardinal direction.
- Hazard `dragDamage` or `carryDamage` reduces dragged cargo integrity.
- Cargo with integrity reduced to zero fails and detaches from any carrier.
- Cargo state snapshots and replays deterministically.

Acceptance proof:

- `tests/run.lua` verifies carrying civilians, bodies/loot-crate schema, machinery-core drag, wounded-hero drag, carried cargo hazard damage, cargo-aware movement preview, drop rules, and snapshot roundtrip.

## M.7 Overwatch And Threat Zones

Threat zones are authored as explicit tile lists or generated shapes.

Supported shapes:

- `line`: straight cardinal lane from the source.
- `cone`: forward lane that widens by step up to `width`.
- `arc`: forward and side lanes around the source.

Rules:

- Threat zones store source unit, side, target tiles, damage, label, and trigger limit.
- A zone triggers when an opposing active unit enters one of its tiles.
- Triggering applies deterministic damage and decrements `remaining`.
- Zones expire when `remaining` reaches zero or the source unit is defeated.
- Shape helpers clip to board bounds.

Acceptance proof:

- `tests/run.lua` verifies line, cone, and arc geometry, shape-created threat zones, one-trigger limit expiry, and no retrigger after expiry.

## M.8 Interactions

Tile interactions are driven by `tile.interact.kind` or tile `kind`.

Supported interactions:

- `valve`: toggles open/closed and sets a flood hazard active state.
- `door`: opens movement and LoS blockers.
- `seal`: closes movement and LoS blockers.
- `shelf`: braces into cover and LoS blocking terrain.
- `furnace`: toggles heat hazard.
- `bridge`: lowers route blockers and tags the tile.
- `terminal`: reveals hidden board tiles.
- `bell`: raises exposure.
- `extraction`: extracts carried cargo, then evacuates the unit if no cargo remains.

Rules:

- Interaction requires an active unit on or adjacent to the tile.
- Interaction validates target/kind before spending AP.
- Unsupported interactions fail fast.
- Effects are deterministic tile/unit/cargo state changes.

Acceptance proof:

- `tests/run.lua` verifies all supported interaction kinds, blocker/LoS changes, exposure, reveal, cargo extraction, and unit evacuation.

## M.9 Terrain Conversion

Terrain conversion is a direct deterministic tile mutation.

Supported conversions:

- `flood`: activates flood hazard.
- `drain`: deactivates flood hazard.
- `burn`: activates burn hazard.
- `ash_choke`: creates ash material and LoS blocking hazard.
- `glassify`: changes material to glass and clears cover.
- `collapse`: creates blocker, LoS blocker, and minimum height 1.
- `raise_cover`: creates half cover on all edges.
- `lower_cover`: clears cover on all edges.
- `seal_tile`: blocks movement and LoS.
- `open_tile`: clears movement and LoS blockers.

Rules:

- Conversion validates kind and bounds before AP spend.
- Conversion does not roll random outcomes.
- Conversion effects are stored on the tile snapshot.

Acceptance proof:

- `tests/run.lua` verifies every supported conversion and its tile-state side effects.

## M.10 Statuses

Statuses are deterministic unit state. Supported kinds:

- `marked`: increases incoming damage by status amount.
- `exposed`: increases incoming damage by status amount.
- `pinned`: blocks voluntary movement.
- `bound`: blocks voluntary movement.
- `burning`: deals deterministic tick damage.
- `flooded`: deals deterministic tick damage.
- `corroded`: deals deterministic tick damage.
- `filed`: accepted deterministic state flag for procedure effects.
- `redacted`: accepted deterministic state flag for reveal/intent systems.
- `sealed`: blocks voluntary movement.
- `blinded`: blocks threat-zone creation.
- `braced`: reduces collision damage by status amount.

Rules:

- Status application validates status kind and target before AP spend.
- Status ticks decrement finite durations and remove expired statuses.
- Tick damage ignores marked/exposed incoming-damage bonuses.
- No status causes random action loss.

Acceptance proof:

- `tests/run.lua` verifies all supported status kinds, incoming damage bonuses, movement blocking, blinded threat-zone blocking, deterministic tick damage/expiry, and braced collision reduction.

## M.11 Objective Integrity

Objectives have deterministic integrity and result state.

Rules:

- `damageObjective` lowers integrity and fails the objective at zero.
- `repairObjective` restores integrity up to `maxIntegrity`.
- `relocateObjective` moves an objective to an unblocked tile.
- `extractObjective` completes an objective.
- `sacrificeObjective` fails an objective and records carryover reason.
- `objectiveResult` reports status, integrity ratio, partial success, extraction, relocation, sacrifice, and failure carryover.
- Objectives with `allowPartial` report partial success while active with integrity above zero.
- Integrity-zero failure records `failureCarryover.reason = integrity_zero` unless another reason already exists.

Acceptance proof:

- `tests/run.lua` verifies damage, repair, relocation, blocked relocation rejection, sacrifice, partial success, extraction completion, and failure carryover.
