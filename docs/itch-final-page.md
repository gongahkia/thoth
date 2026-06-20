# Thoth Itch.io Final Page

Date: 2026-06-20

Status: draft. Do not remove TODO 8.6 until the public itch page has the final copy, 5 screenshots, and a public trailer URL attached.

## Source Checks

- itch.io page design docs: https://itch.io/docs/creators/design
- itch.io creator quality guidelines: https://itch.io/docs/creators/quality-guidelines

Relevant requirements from source:

- Downloadable project pages default to a two-column layout where screenshots and video appear beside the main description.
- A video URL or trailer is recommended for games, and supported public links include YouTube and Vimeo.
- The trailer must be publicly accessible; verify with an incognito browser.
- The description should include controls, supported input devices, status/plans, links, story summary, and features.
- Metadata and tags must accurately represent the project.
- Screenshots should be provided for games and must not mislead users about included content.

## Page Metadata

Page title:

```text
Thoth
```

Short description:

```text
Turn-based expedition RPG about debt, light, extraction, and the institutions that keep records after bodies fail.
```

Download button label:

```text
Download Thoth
```

Suggested price:

```text
$0-5 suggested donation for RC; final price TBD before launch.
```

Classification:

```text
Game, downloadable, singleplayer, English text.
```

Platforms:

```text
Do not mark Windows/macOS/Linux until TODO 8.4 has verified clean installs for native packages. If only `dist/thoth.love` is uploaded, classify the file as a LOVE2D package/download, not an OS executable.
```

## Tags

Use relevant tags only:

```text
rpg, turn-based, dungeon-crawler, horror, dark-fantasy, tactical-rpg, singleplayer, love2d, lua, story-rich
```

## Media Plan

Final screenshots required:

- `assets/previews/final-title.png` - title screen with final menu state.
- `assets/previews/final-estate.png` - Estate management with roster, missions, provisions, and trinkets visible.
- `assets/previews/final-expedition.png` - HD-2D expedition view with HUD, party, torch, supplies, and room state.
- `assets/previews/final-combat.png` - combat stage with skills, target affordances, turn order, and readable enemies.
- `assets/previews/final-gameover.png` - ending summary or campaign-sealed state.

Local capture status:

- 2026-06-20: all five files above generated at 1280x720 with `love . --preview-capture`.
- Visual spot check passed locally.
- TODO 8.6 remains open because the public itch page and trailer are not published.

Trailer required:

- 60-90 seconds.
- Public YouTube or Vimeo URL.
- Verify in incognito before publishing.
- Must show title, Estate prep, expedition movement, combat, camping/pressure, route outcome, and release CTA.

Existing alpha media is not enough for TODO 8.6:

- `assets/previews/alpha-title.png`
- `assets/previews/alpha-estate.png`
- `assets/previews/alpha-combat.png`
- `assets/previews/alpha-loop.gif`

## Description

Thoth is a turn-based expedition RPG built in LOVE2D. Lead a roster of specialists through hostile institutional spaces, manage torchlight, provisions, stress, and debt, then decide when to extract before the route prices the party out of returning.

The dungeon is not a monster nest. It is an archive, a cistern, a furnace, and a ledger. Every expedition asks the same practical question: what can you afford to lose, and who records the loss?

## Features

- Tactical rank-based combat with hero skills, enemy parts, target rules, crit pressure, stress, death's door, afflictions, virtues, and retreat pressure.
- Three zones: Buried Archive, Salt Cistern, and Ember Warrens.
- Estate management with recruitment, recovery, provisions, trinkets, class unlocks, town events, faction pressure, and campaign dread.
- Nine classes including Warden, Duelist, Apothecary, Thief, Arcanist, Chirurgeon, Exile, Lamplighter, and Merchant.
- Campaign routes for sealing, repair, extraction, and failure states.
- Save/load, deterministic replay support, keyboard and controller input.
- Accessibility settings for high contrast, colorblind modes, font scale, subtitles, reduced motion, and screen shake.

## Controls

- Move: `WASD`
- Interact/confirm: `Space` / `Enter`
- Pause/back: `Escape`
- Settings: title and pause menu
- Controller: supported through the input mapping smoke tests

## Content Notes

Thoth contains institutional horror, fantasy violence, body horror references, injury, disease, character death, psychological stress, and sustained dread. It does not use explicit sexual content.

## Build Upload

Primary upload command after final package exists and itch auth is configured:

```sh
butler push dist/thoth.love <itch-user>/thoth:love --userversion 1.0.0
```

If native packages are added after TODO 8.4, use separate channels:

```sh
butler push dist/thoth-windows.zip <itch-user>/thoth:windows --userversion 1.0.0
butler push dist/thoth-macos.zip <itch-user>/thoth:macos --userversion 1.0.0
butler push dist/thoth-linux.zip <itch-user>/thoth:linux --userversion 1.0.0
```

## Completion Evidence Required

Before removing TODO 8.6:

- Public itch URL recorded here.
- Final page copy pasted into itch.
- Five final screenshots uploaded and visible on the public page.
- Public trailer URL attached and visible on the public page.
- Page checked in incognito desktop and mobile widths.
- Tags and metadata match the actual uploaded build.
- Screenshot and trailer filenames/URLs recorded here.
