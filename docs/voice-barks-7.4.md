# Phase 7.4 Voice Barks

Date: 2026-06-20

Decision: skip voiced class barks for 1.0.

Reason:

- Current repo audio assets include UI, hit, footstep, production, invalid, and two nonverbal dialogue chirps.
- No licensed spoken/TTS bark assets are present under `assets/audio/`.
- Project policy for this release: generated or sampled spoken barks need separate license review, subtitle parity, content review, and per-class recording/editing.

Runtime policy:

- Keep existing text barks and narration in the registry/simulation layer.
- Keep existing `dialogue_chirp_low` and `dialogue_chirp_high` routing for dialogue-like log messages.
- Do not add spoken voice files for class arrivals, deaths, or crits before 1.0 unless each file has an asset-license entry and matching subtitle text.

Revisit:

- Re-open after 1.0 only if a license-safe voice source exists and `docs/asset-licenses.md` is updated with every voice asset.
