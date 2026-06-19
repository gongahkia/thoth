# Thoth Open Todo

This file tracks remaining work only. `TODO-CONTENT.md` is the detailed backlog with task metadata and exact content IDs.

## Immediate Priorities

- [ ] Implement Estate and Campaign expansion: 51 open tasks covering Estate fixtures, enclave leaders, faction meters, twin timer, dread rules, ending router, town events, trinket sets, quirks, and camp rituals.
- [ ] Implement Exploration and Encounter expansion: 16 open tasks covering visible-threat AI, alpha markers, scout/ambush UI, stealth approach, bait, noise decay, injuries, weak-point v2, support repair, and alpha rewards.
- [ ] Implement Found Documents and Lore Fragments: 7 open tasks covering document registry, Estate journal panel, drop rules, zone document banks, and fixture document barks.
- [ ] Implement Narrative and UI Text expansion: 16 open tasks covering mission intros, curio copy fields, bestiary hints, loading/torch/camp/victory lines, glossary, faction/timer/ending copy, fixture/enclave barks, warden voice, document popups, and origin barks.
- [ ] Implement Tests and Validation backlog: 18 open tasks covering content registry, layout grammar, visible threats, weak points, injuries, campaign timer, wardens, tiers, factions, trinket sets, documents, fixture barks, endings, and late-week pressure.

## Verification Gate

- [ ] Run `luajit tests/run.lua`.
- [ ] Run `luajit tests/replays.lua`.
- [ ] Run `luajit tests/assets.lua`.
- [ ] Run `luajit tests/registry.lua`.
- [ ] Run `THOTH_BENCH_TICKS=60 THOTH_BENCH_RUNS=4 luajit benchmarks/rpg_expedition.lua`.
- [ ] Run package verification when write output is acceptable: `make check`.
