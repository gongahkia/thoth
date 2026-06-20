# Phase 7.3 Audio Mix Pass

Date: 2026-06-20

Implemented:

- Primary music layer, ambient layer, and SFX cue layer in `src/app/audio.lua`.
- Ambient context routing in `assets/music/tracks.lua`.
- `Ambient Volume` setting alongside master/music/SFX volume.
- Sidechain ducking for crits, boss events, death-door, death-save, hero death, stress breaks, and combat loss.

Scope:

- Raw music files are still optional runtime assets; missing tracks are skipped.
- Ambient routing uses the existing sourced music slots as low-volume beds.
- Ducking is event-driven and verified with fake sources in tests.
