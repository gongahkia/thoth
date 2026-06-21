# Phase 6 Alpha Package

Status: upload-ready local package. Public upload requires itch authentication.

Package:

- Build: `dist/thoth.love`
- Build command: `make package-build`
- Package test: `luajit tests/package.lua dist/thoth.love`
- Itch channel: `phase6-alpha`
- Feedback form: `.github/ISSUE_TEMPLATE/alpha_feedback.yml` (`Alpha feedback`)

Slice contents:

- One Buried Archive run map with visible route rewards and complications.
- Six procedural board variants.
- Four starter classes with two loadouts each.
- Objective types: protect, extract, disable.
- One elite: Shelf Knight.
- One boss: Vault Regent.

Public page copy:

- Source: `docs/itch-alpha-page.md`
- Upload file: `dist/thoth.love`
- Download label: `Download Buried Archive Alpha`

Verification:

- `make test`
- `luajit tests/replays.lua`
- `make package-build`
- `luajit tests/package.lua dist/thoth.love`
- `git diff --check`

Generate checksum after package build with `shasum -a 256 dist/thoth.love`.
