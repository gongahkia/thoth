# Thoth Audio Assets

The reboot keeps the existing WAV cue files and loads them directly from LOVE.

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

Current contract:

- Runtime format: WAV
- Existing files: 16-bit mono PCM at 22050 Hz
- Missing cues are skipped at runtime

The old authored `.sfx` source format was removed with the C++/raylib reboot.
