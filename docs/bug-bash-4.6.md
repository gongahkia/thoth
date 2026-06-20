# Phase 4.6 Bug Bash

Date: 2026-06-19

Source: deterministic playtest fixture in `tests/run.lua` from task 4.5.

| ID | Severity | Area | Defect | Evidence | Suggested owner |
|---|---|---|---|---|---|
| P4-001 | high | starter roster | New campaign starter party is Warden / Duelist / Apothecary / Arcanist, but Phase 4 target starter party is Warden / Duelist / Apothecary / Thief. | `Simulation.new` seeds the first four `Defs.heroClassOrder` entries; Thief is fifth. | 4.7 |
| P4-002 | medium | campaign boot flow | Pure simulation starts inside `archive_scout`, so title-to-estate flow cannot be represented without app/UI state. | `Simulation.new` calls `self:startExpedition("buried_archive")` before returning. | 4.7 |
| P4-003 | medium | camping rules | Camp can be started anywhere in an expedition, despite UI copy pointing players to a cold camp. | `Simulation:camp()` only checks mode, `campUsed`, and `camping`; it does not check current tile/room. | 4.7 |
| P4-004 | low | playtest fidelity | The 4.5 fixture completes scout objective by setting `roomsScouted` directly instead of walking the map. | `tests/run.lua` sets `sim.expedition.roomsScouted = 3` before `sim:updateObjective()`. | 4.7 |

No crash or save corruption observed in the fixture.
