# Translation Onboarding

Status: contributor workflow and sample format. Runtime extraction remains tracked by TODO 7.5.

## Scope

Translate player-facing text only:

- UI labels and menu text.
- Tutorial, journal, credits, and settings copy.
- Combat log and narration once those strings are extracted.
- Store-page content warnings when localized store pages exist.

Do not translate:

- Lua table keys.
- Save/replay headers.
- Asset paths.
- Registry IDs such as `archive_scout`, `mender`, or `nar_archive_voice_v2_01`.
- License names, author names, or URLs.

## File Pattern

Use one Lua file per locale:

```text
src/game/data/i18n/<locale>.lua
```

Until runtime i18n lands, use the sample file:

```text
docs/i18n/es-419.sample.lua
```

Each file returns a table:

```lua
return {
    locale = "es-419",
    name = "Spanish (Latin America)",
    strings = {
        ["ui.title.new_game"] = "Nueva partida",
    },
}
```

## Key Rules

- Keep every source key present.
- Do not add new keys without an English source string.
- Preserve placeholders exactly: `{hero}`, `{count}`, `{item}`.
- Preserve punctuation that drives UI state, such as `%`, `+`, `/`, and `:`.
- Keep translated strings concise enough for buttons and narrow panels.
- Use UTF-8.

## Tone Rules

- Prefer institutional, procedural language over melodrama.
- Keep body horror brief and functional.
- Do not intensify gore beyond the English source.
- Preserve class names unless a locale glossary explicitly replaces them.
- Preserve content warnings plainly; do not soften them.

## Review Checklist

- Run `make check`.
- Compare long strings against the UI area where they appear.
- Search for missing placeholders.
- Search for untranslated English in the locale file.
- Add translator credit in the pull request body.

## Pull Request Template

```text
Locale:
Source base commit:
Files changed:
Translator credit:
Checked placeholders: yes/no
Checked UI fit: yes/no
Notes:
```
