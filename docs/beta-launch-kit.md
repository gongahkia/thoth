# Beta Launch Kit

Date: 2026-06-20

Status: blocked on authenticated publish.

## Blockers

- `butler` is not installed in the current shell.
- `BUTLER_API_KEY` is not set.
- No local butler/itch credential files were found.
- No authenticated itch.io session is available from CLI.

Do not remove TODO 5.14 until the beta is live and downloadable.

## Local Build

Page draft: `docs/itch-beta-page.md`

Build:

- `dist/thoth.love`

Verified content:

- 35 registry missions.
- Buried Archive: 13 missions.
- Salt Cistern: 11 missions.
- Ember Warrens: 11 missions.
- Four ending routes are implemented.

Media:

- `assets/previews/alpha-title.png`
- `assets/previews/alpha-estate.png`
- `assets/previews/alpha-combat.png`
- `assets/previews/alpha-loop.gif`

Official upload reference:

- `https://itch.io/docs/butler/pushing.html`

Command after auth:

```sh
butler push dist/thoth.love <itch-user>/thoth:love-beta --userversion phase5-beta
```

## Feedback Intake

Use a single linked form or issue template with these categories:

- Bug: crash, blocked progress, save/load failure, input issue.
- Balance: class, boss, resource, town event, faction pressure.
- Feel: readability, pacing, UI friction, route clarity.
- Scope: missing content, repeated content, ending expectations.

## Community Post Draft

Title:

```text
Thoth content beta is live - 35 missions, 4 endings, LOVE2D/Lua
```

Body:

```text
I released the content beta for Thoth, a turn-based expedition RPG built in LOVE2D/Lua.

This build expands from the earlier alpha into three full zones:
- Buried Archive
- Salt Cistern
- Ember Warrens

It includes 35 registry missions, 8 classes, class unlocks, faction pressure, town events, boss routes, and 4 ending routes.

Feedback wanted:
- bugs and blocked runs
- mission variety
- class unlock pacing
- resource pressure
- whether each ending route is understandable

Itch page: <itch-url>
Feedback form: <feedback-url>

I am the developer. No votes requested; critical feedback is useful.
```

## Completion Evidence Required

Before removing TODO 5.14:

- Itch page URL is public and downloadable.
- `dist/thoth.love` or equivalent build is attached to the itch page.
- Build channel is beta-specific, for example `love-beta`.
- Feedback intake URL is linked from the itch page.
- Public URL and upload/version evidence are recorded in this file.
