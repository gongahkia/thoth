# Thoth Itch.io Final Page

Date: 2026-06-22

Status: draft. Do not publish until the public itch page has current tactical screenshots, a public trailer or gameplay GIF, and a verified uploaded build.

## Source Checks

- itch.io page design docs: https://itch.io/docs/creators/design
- itch.io creator quality guidelines: https://itch.io/docs/creators/quality-guidelines

Relevant requirements from source, checked 2026-06-22:

- Downloadable project pages use a screenshot/video sidebar by default.
- Descriptions should include controls, supported input devices, status/plans, links, story summary, and feature list.
- Games should provide screenshots; GIFs are acceptable when they better represent the project.
- Metadata, platform flags, and tags must accurately represent the uploaded build.
- Screenshots and trailers must not show content that is not in the uploaded build.
- Public video/trailer links should be verified in an incognito browser.

## Page Metadata

Page title:

```text
Thoth
```

Short description:

```text
Deterministic XCOM-lite tactics in a cursed archive: six auditors read intent, bend cover, and survive without hit-roll RNG.
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
Do not mark Windows/macOS/Linux until native packages are verified. If only `dist/thoth.love` is uploaded, classify the file as a LOVE package/download, not an OS executable.
```

## Tags

Use relevant tags only:

```text
strategy, turn-based, turn-based-tactics, tactical-rpg, roguelite, horror, love2d, lua, singleplayer
```

## Media Plan

Current local media:

- `assets/previews/readme-tactical.png` - current 1280x720 tactical view with six-unit AP HUD, intent legend, tile inspector, objective pressure, and route board.
- `assets/previews/readme-tactical-loop.gif` - current 640x360 tactical GIF preview derived from the current tactical smoke capture.

Storefront screenshots still required before public release:

- Fog-of-war reveal on a Buried Archive board.
- Overwatch cone declaration with affected tiles visible.
- Intent legend hover/selection with tile inspector populated.

Trailer or gameplay GIF required:

- 30-90 seconds.
- Public YouTube/Vimeo URL or downloadable GIF/MP4.
- Must show title, Buried Archive route, six-class squad, AP movement, cover/flank, fog reveal, overwatch cone, hidden/revealed intent, objective pressure, and release CTA.
- Verify public access in incognito before publishing.

Do not use legacy `alpha-*` or `final-*` RPG captures for the tactical storefront.

## Description

Thoth is a compact XCOM-lite tactics game built in LOVE/Lua. Six auditors enter the Buried Archive, a hostile institution of sealed shelves, audit beams, debt records, and claim machinery. Each mission asks you to read the board before spending AP: enemy intent is previewable, cover is directional, fog hides information until revealed, and overwatch/LoS/flanks decide whether the route machine survives.

There are no hit-rolls after the board loads. RNG can choose the board and enemy pressure before deployment; once the mission starts, movement, damage, cover, intent, objective pressure, and failure are deterministic.

## Features

- Six-class tactical squad: Warden, Duelist, Apothecary, Thief, Arcanist, Lamplighter.
- Buried Archive vertical-slice route with six ordered procedural mission variants.
- AP movement, directional cover, flanking, LoS previews, fog-of-war, overwatch cones, and tile inspector.
- Enemy intent legend with exact, hidden-footprint, and revealed intent states.
- Objective families for protection, extraction, repair, disable, entry audit, and boss procedure pressure.
- Shelf Knight elite pressure and Vault Regent final-board procedure.
- Fixed-seed procgen validator, reject logs, deterministic replay support, keyboard/controller input.
- Accessibility settings for high contrast, colorblind modes, intent scaling/text, font scale, subtitles, reduced motion, and screen shake.

## Controls

- Cursor / aim tile: `WASD`, D-pad, or left stick.
- Select / commit: mouse left click, `Enter`, or controller `A`.
- Inspect preview: `Space` or controller `X`.
- Rotate view: `[` / `]` or controller shoulders.
- End turn: `E`.
- Pause/back: `Escape` or controller back.
- Settings: title and pause menu.

## Content Notes

Thoth contains institutional horror, fantasy violence, body horror references, injury, debt, character death, psychological pressure, and sustained dread. It does not use explicit sexual content.

## Build Upload

Primary upload command after final package exists and itch auth is configured:

```sh
butler push dist/thoth.love <itch-user>/thoth:love --userversion 1.0.0
```

If native packages are added after verification, use separate channels:

```sh
butler push dist/thoth-windows.zip <itch-user>/thoth:windows --userversion 1.0.0
butler push dist/thoth-macos.zip <itch-user>/thoth:macos --userversion 1.0.0
butler push dist/thoth-linux.zip <itch-user>/thoth:linux --userversion 1.0.0
```

## Completion Evidence Required

Before publishing:

- Public itch URL recorded here.
- Final page copy pasted into itch.
- Current tactical screenshots uploaded and visible on the public page.
- Public trailer/GIF URL attached and visible on the public page.
- Page checked in incognito desktop and mobile widths.
- Tags and metadata match the actual uploaded build.
- Screenshot and trailer filenames/URLs recorded here.
