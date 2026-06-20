# Phase 7.12 Replay Viewer

Date: 2026-06-20

Scope:

- `Replay.write(path, data)` writes the same v2 replay text produced by `Replay.toText`.
- `Replay.read(path)` loads v2 replay text and validates seed, frame list, and final tick.
- Title screen now exposes a `Replay` menu item when `replay.thoth` exists.
- Activating `Replay` loads `replay.thoth`, runs it through `ReplayViewer`, enters the final replay simulation state, and queues cutscenes derived from replay events.

Default path:

- `replay.thoth`

Verification:

- Unit tests cover replay write/read round trip.
- Unit tests cover replay viewer final-state load.
- Unit tests cover replay viewer cutscene queueing from a combat replay.
- `make check` covers the title menu smoke and package contents.
