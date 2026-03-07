# Add runtime observability, tracing, and an optional debug HUD

## Summary

`thoth.core.performance` already has timers and profiling utilities, but the runtime does not expose enough observability to explain what happened during a frame. Add first-class runtime inspection so simulation bugs and performance regressions are easier to diagnose.

## Scope

- Collect per-system timing for fixed-update, variable-update, and draw phases.
- Add event tracing for frame steps, input dispatch, task execution, tween completion, and state transitions.
- Add task and timeline inspection APIs so callers can list active jobs and tweens.
- Add an optional debug HUD or debug dump helper that surfaces the collected data.
- Keep observability optional so it can be disabled in production usage.

## Acceptance criteria

- The runtime can return system timing summaries for recent frames.
- The runtime can emit a bounded trace log for debugging.
- Active tasks, tweens, and current state information are inspectable.
- The showcase example can enable a debug overlay without special-case glue code.

## Depends on

- Deterministic runtime foundation.
