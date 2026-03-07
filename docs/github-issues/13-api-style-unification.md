# Unify public API style across `thoth.core`, `thoth.game`, and `thoth.adapters`

## Summary

Older `thoth.core` modules mostly use CamelCase functional APIs, while newer runtime and adapter modules lean on object-style methods. That inconsistency is already visible and will become harder to manage as the library grows.

## Scope

- Define the preferred public API style for new and existing modules.
- Decide where backward-compatibility shims are needed and where breaking changes are acceptable.
- Normalize constructor names, method names, and namespacing conventions.
- Update README examples and tests to reflect the chosen style.
- Provide a migration guide for any renamed public APIs.

## Acceptance criteria

- A documented style guide exists for future modules.
- New modules follow the chosen style consistently.
- Existing modules either conform or expose a deliberate compatibility layer.
- Migration notes are explicit for any user-facing renames.
