# Thoth Audio Cues

The raylib app looks for optional WAV cue files in `assets/audio/`.
Missing files are generated from the reviewable authored cue source at `assets/audio/thoth_cues.sfx`. If that source is missing or invalid, the app falls back to deterministic built-in tones, so partial audio packs are supported.

Run `make cpp-export-authored-audio`, or `./build/app/thoth_raylib --export-authored-audio`, to validate `thoth_cues.sfx` and export the authored WAV cue pack directly into `assets/audio/`.

Run `make cpp-export-audio`, or `./build/app/thoth_raylib --export-audio`, to export built-in fallback WAVs to `assets/audio/generated/`. Use those files only as fallback/reference.

Run `make cpp-validate-assets`, or `./build/app/thoth_raylib --validate-assets`, after exporting to verify the cue source and direct runtime WAV files.

Cue contract:

- Authored format: `THOTH_AUDIO_CUES 1` text file, `cue <filename> <start_hz> <end_hz> <seconds> <volume>` lines
- Runtime/export format: WAV, 16-bit mono at 22050 Hz
- Suggested length: 30-150 ms for UI cues, up to 300 ms for production cues
- Suggested loudness: leave headroom; the app does not normalize assets
- Current mix: low downward sweeps for physical work/errors, short mid cues for placement/ticks, and brighter upward sweeps for craft/save/load/production confirmations

Cue filenames:

```text
mine.wav
place.wav
craft.wav
invalid.wav
save.wav
load.wav
tick.wav
produce.wav
```
