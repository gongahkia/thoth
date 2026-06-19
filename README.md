# Thoth

Institutional-horror tactical RPG in LOVE2D/Lua.

## Development

```sh
make check
```

Useful targets:

- `make run`
- `make test`
- `make package-build`
- `make benchmark-scaled`

Roadmap source of truth: `TODO.md`.

## Community Translation

Translation onboarding lives in `docs/translation-onboarding.md`.

Current status:

- Runtime localization scaffolding lives in `src/app/i18n.lua` and `src/game/data/i18n/en.lua`.
- Translation contributors should start from `docs/i18n/es-419.sample.lua`.
- New translations must preserve IDs, placeholders, tone, and content warnings.
