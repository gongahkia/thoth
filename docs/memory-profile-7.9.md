# Phase 7.9 Memory Profile

Date: 2026-06-20

Budget: resident memory under 500 MB.

Command:

```sh
THOTH_RENDER_BENCH_FRAMES=180 SDL_AUDIODRIVER=dummy /usr/bin/time -l love . --render-benchmark
```

Render result:

- `frames=180`
- `avg_draw_ms=1.987580`
- `max_draw_ms=11.946167`

Memory result:

- Maximum resident set size: `116441088` bytes, 111.05 MiB.
- Peak memory footprint: `181191568` bytes, 172.80 MiB.

Verdict: pass. Maximum resident set size is below 500 MB.

Scope:

- Profiled on macOS with LOVE render benchmark mode.
- Fixed benchmark termination so `--render-benchmark` prints once and exits instead of being intercepted by the expedition quit confirmation.
