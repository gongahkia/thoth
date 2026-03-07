# API Style

`thoth` now treats `snake_case` as the canonical public API style across `thoth.core`, `thoth.game`, and `thoth.adapters`.

## Rules

- Module names should be lowercase and use digits without extra punctuation where needed, for example `math2d`, `love2d`, and `solar2d`.
- Module-level functions should be exported in `snake_case`.
- Constructors should prefer `new`.
- Stateful objects should expose lowercase instance methods.
- Legacy CamelCase helpers remain supported as compatibility aliases and should not be used for new APIs.

## Compatibility

Older functional modules in `thoth.core` still expose names like `Clamp`, `Memoize`, and `FormatTime`. Each of those now has a canonical alias such as `clamp`, `memoize`, and `format_time`.

When adding new modules or extending existing ones, prefer the lowercase alias form in tests, examples, and documentation. Keep CamelCase only when maintaining backward compatibility for an already published symbol.
