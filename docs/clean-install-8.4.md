# Clean Install Verification 8.4

Status: partial local evidence. Do not remove TODO 8.4 until Windows, macOS, and Linux are each verified from a clean install.

## Matrix

| Platform | Artifact | Status | Evidence |
|---|---|---|---|
| macOS | `dist/thoth.love` | partial pass | Homebrew LOVE 11.5, temp HOME, title smoke passed on 2026-06-20 |
| Windows | native package | No access. | Not verified |
| Linux | native package/AppImage | No access. | Not verified |

## Local macOS Command

```sh
make package-title-smoke
```

Observed output:

```text
title-smoke-state=title
title-smoke-buttons=new,continue,replay,settings,credits,quit
title-smoke-continue=false
title-smoke-replay=false
```

## Full Verification Requirements

- Start from a clean user profile or VM snapshot.
- Install only documented runtime prerequisites.
- Download the release artifact, not a working-tree build.
- Launch the game.
- Confirm title menu renders.
- Start a new game.
- Enter Estate.
- Enter first expedition.
- Trigger one combat.
- Quit and relaunch.
- Confirm save/continue behavior.
- Record OS version, artifact filename, checksum, and result.

## Completion Evidence Required

Before removing TODO 8.4:

- Windows clean install result recorded here.
- macOS clean install result recorded here.
- Linux clean install result recorded here.
- Artifact checksums recorded for each tested package.
- Any prerequisite installation steps documented.
- Failures filed as bugs or fixed before launch.
