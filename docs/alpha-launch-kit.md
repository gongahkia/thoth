# Alpha Launch Kit

Date: 2026-06-20

Status: ready for authenticated publish.

## Blockers

- `butler` is not installed in the current shell.
- `BUTLER_API_KEY` is not set.
- No local butler/itch credential files were found.
- No authenticated Reddit or Discord session is available from CLI.

Do not remove TODO 4.11 until the alpha is live and all three community posts are actually submitted.

## Itch.io Upload

Page draft: `docs/itch-alpha-page.md`

Build:

- `dist/thoth.love`

Media:

- `assets/previews/alpha-title.png`
- `assets/previews/alpha-estate.png`
- `assets/previews/alpha-combat.png`
- `assets/previews/alpha-loop.gif`

Official upload reference:

- `https://itch.io/docs/butler/pushing.html`

Command after auth:

```sh
butler push dist/thoth.love <itch-user>/thoth:love-alpha --userversion phase4-alpha
```

Notes from source:

- `butler push` accepts a directory or `.zip` file; `.love` is a zip-format archive.
- Channel name should be lowercase kebab-case.
- A new visible channel appears on the game page after push unless `--hidden` is used.

## Reddit Guardrails

References:

- Reddit self-promotion guide: `https://www.reddit.com/r/reddit.com/wiki/selfpromotion/`
- r/IndieDev meta thread: `https://www.reddit.com/r/IndieDev/comments/1erfu0e/if_you_want_to_promote_your_game_just_promote_it/`

Rules to follow:

- Be transparent that this is the author/dev posting.
- Do not ask for votes.
- Do not mass-post identical copy.
- Prefer a release milestone post over fake feedback bait.
- Read each community sidebar immediately before posting.

## r/love2d Draft

Title:

```text
Released a free LOVE2D alpha for Thoth, a turn-based expedition RPG
```

Body:

```text
Hi, I built this in LOVE2D/Lua and just put up a free alpha.

Thoth is a compact expedition RPG: four specialists enter a hostile archive, manage torchlight/provisions, fight turn-based encounters, camp at cold markers, and retreat before the route collapses.

This alpha is mainly for feedback on:
- LOVE2D/HD-2D readability
- keyboard/controller flow
- combat HUD clarity
- accessibility toggles

Itch page: <itch-url>
GIF: attach assets/previews/alpha-loop.gif

I am the developer. No votes requested; criticism is useful.
```

## r/IndieDev Draft

Title:

```text
I released a free alpha for my expedition RPG, Thoth
```

Body:

```text
I released the first free alpha for Thoth, a turn-based expedition RPG about debt, light, and getting out before the dungeon prices your names.

Current slice:
- Buried Archive Tier I mission chain
- Warden / Duelist / Apothecary / Thief starter party
- estate prep, provisions, camping, combat, boss route
- save/load, keyboard/controller, colorblind/high-contrast/subtitle/reduced-motion settings

Itch page: <itch-url>
GIF: attach assets/previews/alpha-loop.gif

I am the developer. I am looking for feedback on whether the expedition loop is readable and tense, not wishlists or votes.
```

## RPG Maker Horror Discord Draft

Channel: use the server's promotion/showcase channel only.

```text
I released a free alpha for Thoth, a turn-based institutional-horror expedition RPG.

It is not RPG Maker; posting here only if non-RPG-Maker horror projects are allowed in this channel. If not, delete/ignore.

Pitch: four specialists enter the Buried Archive, manage light/provisions/stress, camp at cold markers, and retreat before the route turns hostile.

Itch page: <itch-url>
GIF: assets/previews/alpha-loop.gif

Feedback wanted: horror tone, UI readability, and whether the pressure loop feels tense.
```

## Completion Evidence Required

Before removing TODO 4.11:

- Itch page URL is public and downloadable for free.
- `dist/thoth.love` or equivalent build is attached to the itch page.
- Posts are submitted to r/love2d, r/IndieDev, and the Discord channel.
- URLs or screenshots of the three posts are recorded in this file.
