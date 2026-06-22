# Phase 7.7 Accessibility Final Pass

Date: 2026-06-20

Implemented:

- Colorblind palettes through `Render.accessibleColor`.
- High-contrast color transform through `Settings.highContrast`.
- Tactical high-contrast tile mode, intent icon scale, cover edge palette, and intent text duplication through the settings panel.
- Font scaling through `Settings.fontScale` and `Render.applyFont`.
- Reduced-motion suppression for title motion, UI pulses, and queued cutscenes.
- Subtitles for event/audio feedback.
- Screen-reader-friendly text export via `src/app/accessibility.lua`.

Export command:

```sh
love . --accessibility-export accessibility.txt
```

Export includes:

- UI state, status, mode, tick, and current accessibility settings, including tactical readability controls.
- Estate week/resources.
- Mission, objective, next step, torch, room, progress, and position during expeditions.
- Party HP/stress/alive state.
- Combat round/enemy state when combat is active.
- Current subtitle cue and keyboard controls.

Validation:

- `tests/run.lua` covers color transform, tactical tile contrast, intent scale/text metadata, cover edge palette switching, font scale, subtitles, reduced motion, settings persistence, and text export content.
- `make check` covers smoke tests, package contents, registry checks, asset checks, replay fixtures, and benchmark smoke.
