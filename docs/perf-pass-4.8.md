# Phase 4.8 Performance Pass

Date: 2026-06-19

Profile command: call/return `debug.sethook` profiler over 30 runs x 1200 ticks of `benchmarks/rpg_expedition.lua` command mix.

Baseline slowest Lua functions by self time in profile mode:

| Rank | Self ms | Calls | Function |
|---|---:|---:|---|
| 1 | 260.584 | 225344 | `src/game/world.lua:32 inCorridor` |
| 2 | 129.160 | 71185 | `src/game/defs.lua:144 trinketSet` |
| 3 | 67.450 | 64014 | `src/game/world.lua:135 layout` |
| 4 | 65.098 | 64164 | `src/game/defs.lua:188 location` |
| 5 | 48.891 | 36000 | `src/game/simulation.lua:434 queue` |
| 6 | 42.476 | 30720 | `src/game/world.lua:9 generatedTile` |
| 7 | 38.787 | 29466 | `src/game/defs.lua:148 quirk` |
| 8 | 32.626 | 9232 | `src/game/defs.lua:136 heroClass` |
| 9 | 26.612 | 21614 | `src/game/simulation.lua:2546 apply` |
| 10 | 19.041 | 13891 | `src/game/defs.lua:168 enemy` |

Final slowest Lua functions by self time in profile mode:

| Rank | Self ms | Calls | Function |
|---|---:|---:|---|
| 1 | 299.927 | 225344 | `src/game/world.lua:32 inCorridor` |
| 2 | 58.515 | 64014 | `src/game/world.lua:135 layout` |
| 3 | 41.901 | 30720 | `src/game/world.lua:9 generatedTile` |
| 4 | 37.715 | 36000 | `src/game/simulation.lua:443 queue` |
| 5 | 20.416 | 21614 | `src/game/simulation.lua:2562 apply` |
| 6 | 11.549 | 9232 | `src/game/simulation.lua:874 classDef` |
| 7 | 8.886 | 7333 | `src/game/simulation.lua:3048 actorSpeed` |
| 8 | 8.636 | 6558 | `src/game/defs.lua:168 enemy` |
| 9 | 6.504 | 3522 | `src/game/simulation.lua:553 pushLog` |
| 10 | 6.171 | 4380 | `src/game/simulation.lua:2911 apply` |

Changes kept:

- Skip trinket-set scans when the hero has no equipped trinkets.
- Use direct definition tables in `heroModifier`, `classDef`, `actorSpeed`, and `World:layout` for profiled wrapper hot paths.

Rejected:

- Precomputing corridor bounds and layout lookup tables increased benchmark median in this workload, so it was not kept.

Benchmark samples, `THOTH_BENCH_TICKS=900 THOTH_BENCH_RUNS=24 luajit benchmarks/rpg_expedition.lua`:

| Build | Samples ms | Median ms |
|---|---|---:|
| 4.7 baseline `c3adfa6` | 223.236, 63.218, 121.934, 143.587, 135.986 | 135.986 |
| 4.8 final | 130.581, 200.094, 55.416, 68.110, 176.403 | 130.581 |
