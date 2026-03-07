# Add platform-neutral utilities for logging, filesystem/path, config/env, and time/date

## Summary

Many Lua projects need the same non-game-specific helpers, and `thoth` is already positioned as a general-purpose toolkit. Add a focused set of platform-neutral utility modules that complement the current core library.

## Scope

- Add a lightweight logging module with levels and pluggable sinks.
- Add filesystem and path helpers that degrade gracefully across host environments.
- Add config and environment-loading helpers where the runtime permits them.
- Add time/date utilities that avoid depending on game-engine globals.
- Keep these modules pragmatic and avoid overbuilding a full standard library replacement.

## Acceptance criteria

- The utilities fit under `thoth.core` and are documented in the README.
- File and environment helpers make capability limitations explicit.
- Tests cover path normalization, logging behavior, and config/env loading edge cases.
- The modules feel like a natural extension of the current `thoth.core` surface.
