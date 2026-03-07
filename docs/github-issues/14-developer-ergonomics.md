# Remove local developer friction from testing and module resolution

## Summary

The local development workflow still has avoidable friction. `make test` assumes a `lua` binary on `PATH`, and local module resolution currently depends on setting `LUA_PATH` so `thoth.core` and related namespaces resolve correctly.

## Scope

- Make the test workflow work in a clean checkout without manual `LUA_PATH` setup.
- Detect or configure a sensible default runner across `lua`, `lua5.x`, and `luajit` when possible.
- Ensure module resolution works consistently for local test execution.
- Add a short contributor section describing the supported local workflows.
- Keep the solution simple and shell-friendly.

## Acceptance criteria

- `make test` works in a typical local checkout when at least one supported Lua runtime is installed.
- Tests do not require manual `LUA_PATH` exports.
- Contributor documentation explains how the test runner is selected.
- CI and local usage share the same assumptions.

## Primary files

- `Makefile`
- `README.md`
