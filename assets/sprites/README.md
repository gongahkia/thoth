# Thoth Sprite Assets

`thoth_atlas.png` is the retained sprite atlas from the C++ prototype.

Current contract:

- Runtime format: PNG
- Current checked-in size: 128x80
- Logical sprite size: 16x16
- Layout: 8 columns, row-major
- Runtime manifest: `thoth_atlas.lua`
- LOVE draw scale: 2x by default

Import pipeline:

- CLI: `love . --sprite-import --sprite-source <source.png> --sprite-atlas <atlas.png> --sprite-manifest <atlas.lua> --sprite-frame 16x16`
- Smoke: `make sprite-import-smoke`

The old authored `.art` source format was removed with the C++/raylib reboot.
