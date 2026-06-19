# Thoth Open Todo

This file tracks remaining work only. `TODO-CONTENT.md` is the detailed backlog with task metadata and exact content IDs.

## Immediate Priorities

- [ ] Implement Tests and Validation backlog: 18 open tasks covering content registry, layout grammar, visible threats, weak points, injuries, campaign timer, wardens, tiers, factions, trinket sets, documents, fixture barks, endings, and late-week pressure.

## Verification Gate

- [ ] Run `luajit tests/run.lua`.
- [ ] Run `luajit tests/replays.lua`.
- [ ] Run `luajit tests/assets.lua`.
- [ ] Run `luajit tests/registry.lua`.
- [ ] Run `THOTH_BENCH_TICKS=60 THOTH_BENCH_RUNS=4 luajit benchmarks/rpg_expedition.lua`.
- [ ] Run package verification when write output is acceptable: `make check`.
