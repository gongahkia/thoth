# Add input recording and replay to the runtime

## Summary

A deterministic runtime is not very useful without the ability to capture and replay the exact input stream that drove a simulation. Add recording and replay support to the runtime and input manager so bugs, tests, and showcase scenarios can be reproduced exactly.

## Scope

- Define a stable frame log format for recorded input.
- Add APIs to start, stop, export, import, and replay input sessions.
- Decide whether the log should capture raw adapter events, resolved action states, or both.
- Support headless replay without live adapter state.
- Integrate with serialization helpers for saving recordings.

## Acceptance criteria

- A recorded session can be replayed headlessly through `thoth.game.runtime`.
- Replaying the same recording against the same seed yields the same final state.
- Tests cover record, replay, and replay-without-live-input scenarios.
- The showcase example can run from a bundled recording for regression checks.

## Depends on

- Deterministic runtime foundation.
