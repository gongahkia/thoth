# Translation Onboarding

Status: contributor workflow, sample format, and runtime English source table.

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

Use the sample file for a small locale-shaped reference:

```text
docs/i18n/es-419.sample.lua
```

Runtime string files may return either a plain source-string table or a metadata wrapper with `strings`.
The English source file uses a plain table:

```lua
return {
    ["New Game"] = "New Game",
    ["Settings"] = "Settings",
}
```

## Key Rules

- Keep every English source key present.
- Do not add new keys without adding the English source string first.
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
