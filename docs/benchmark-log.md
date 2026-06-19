# Benchmark Log

## 2026-06-20

Suite:

- Command: `make check`
- Result: pass
- Unit tests: 165
- Replay fixtures: 4
- Package test: pass
- Benchmark smoke: `elapsed_ms=11.258`, `avg_ms_per_tick=0.046908`, `max_ms_per_tick=2.522000`

Scaled benchmark:

- Command: `THOTH_BENCH_TICKS=900 THOTH_BENCH_RUNS=24 luajit benchmarks/rpg_expedition.lua`
- Result: `elapsed_ms=114.806`, `avg_ms_per_tick=0.005315`, `max_ms_per_tick=3.105000`

Delta:

- Prior monthly baseline: unavailable.
- Phase reference: `docs/perf-pass-4.8.md` records final median `130.581` ms for the same scaled command on 2026-06-19.
- Current sample vs phase reference: `-15.775` ms (`-12.1%`).
