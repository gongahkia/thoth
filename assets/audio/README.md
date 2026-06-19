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
hit_slash.wav
hit_blunt.wav
hit_burn.wav
hit_affliction.wav
hit_stress.wav
footstep_stone.wav
footstep_wet.wav
footstep_ash.wav
ui_click.wav
ui_confirm.wav
ui_back.wav
ui_error.wav
dialogue_chirp_low.wav
dialogue_chirp_high.wav
```

Current contract:

- Runtime format: WAV
- Existing files: 16-bit mono PCM at 22050 Hz
- Missing cues are skipped at runtime
- Combat cues are routed from skill metadata.
- Footstep cues are routed from tile IDs.
- Dialogue chirps are routed from dialogue-like log messages.
- Critical combat events duck music and ambient layers behind SFX.

The old authored `.sfx` source format was removed with the C++/raylib reboot.
