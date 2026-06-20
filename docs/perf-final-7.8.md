# Phase 7.8 Performance Final Pass

Date: 2026-06-20

Budgets:

- Cold boot: under 3s.
- Expedition load: under 1s.
- App frame CPU time p99: under 16ms.

Commands:

```sh
SDL_AUDIODRIVER=dummy /usr/bin/time -p love . --title-smoke
SDL_AUDIODRIVER=dummy love . --load-benchmark
THOTH_RENDER_BENCH_FRAMES=180 SDL_AUDIODRIVER=dummy love . --render-benchmark
```

Result:

- Cold boot: `real 0.78`, pass.
- Expedition load: `load_ms=14.830792`, pass.
- Render benchmark: `frames=180`.
- Draw time: `avg_draw_ms=2.245015`, `max_draw_ms=14.106958`, `p99_draw_ms=5.275167`.
- App frame CPU time: `avg_frame_ms=2.273956`, `max_frame_ms=14.300667`, `p99_frame_ms=5.314875`, pass.

Scope:

- Local macOS run.
- App frame CPU time measures from `love.update` start through `Render.draw` end in `--render-benchmark`.
- It does not include display present, compositor latency, or Windows/Linux runtime variance.
