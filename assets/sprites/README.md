# Thoth Sprite Assets

`oga_700_sprites.png` is generated from selected `700 sprites` GIF frames from OpenGameArt.

Current contract:

- Runtime format: PNG
- Current checked-in size: 512x608
- Logical sprite size: 32x32
- Layout: 16 columns, row-major
- Runtime manifest: `oga_700_sprites.lua`
- LOVE draw scale: 2x by default

Import pipeline:

- CLI: `love . --sprite-import --sprite-source <source.png> --sprite-atlas <atlas.png> --sprite-manifest <atlas.lua> --sprite-frame 32x32`
- Smoke: `make sprite-import-smoke`

Source GIFs are not committed. Regenerate from `https://opengameart.org/sites/default/files/last-guardian-sprites.zip`.
