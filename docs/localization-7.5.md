# Phase 7.5 Localization Scaffold

Date: 2026-06-20

Implemented:

- Runtime `i18n.t(key)` helper with English source strings in `src/game/data/i18n/en.lua`.
- Render-layer UI labels, captions, HUD text, settings labels, tutorial copy, and menu text routed through `i18n.t`.
- Static key coverage test for render-layer `i18n.t("...")` calls and settings labels.

Scope:

- English source keys intentionally use the displayed source string.
- Dynamic content from registries, logs, and save/replay data still falls back to its source text unless a matching key exists.
- Alternate locale loading is scaffolded in `src/app/i18n.lua`; no in-game language selector or live reload is added.
