# Thoth Sprite Atlas

The raylib app looks for `assets/sprites/thoth_atlas.art` first. This is the reviewable authored sprite source used by the C++/raylib prototype. If that file is missing or invalid, the app looks for `assets/sprites/thoth_atlas.png`. If that is missing or has the wrong dimensions, the app falls back to the generated pixel atlas in code.

Run `make cpp-export-authored-atlas` to validate `thoth_atlas.art` and export the runtime PNG to `assets/sprites/thoth_atlas.png` without opening a window.

Run `make cpp-export-atlas`, or press `F6` in the app, to export the generated fallback to `assets/sprites/thoth_generated_atlas.png`. Use that file only as a fallback/reference; the authored baseline should live in `thoth_atlas.art`.

Run `make cpp-validate-assets`, or `./build/app/thoth_raylib --validate-assets`, after exporting to verify the authored source and runtime PNG dimensions.

Atlas contract:

- Authored format: `THOTH_ATLAS_ART 1` text file, `sprite <Name>` blocks, 16 rows of 16 palette glyphs per sprite
- Runtime/export format: PNG
- Sprite size: 16x16 pixels
- Atlas size: 128x64 pixels
- Layout: 8 columns, row-major order
- Runtime terrain rendering applies deterministic coordinate-based tint/flip variation to grass, dirt, water, stone, ore, and floor tiles so repeated atlas sprites read less tiled in the raylib view and media preview.
- Runtime machine rendering adds tick-based belt travel dashes and working-machine pulse overlays on top of the atlas, keeping motion polish in code while preserving the compact authored sprite sheet.
- Newer gameplay objects that do not have dedicated authored cells yet reuse existing atlas sprites with code-side colors/glyph fallbacks.

Sprite order:

```text
TileGrass        TileDirt         TileWater        TileTree         TileStone        TileIronOre      TileCopperOre    TileCoalOre
TileFloor        ItemWood         ItemStone        ItemCoal         ItemIronOre      ItemIronPlate    ItemCopperOre    ItemCopperPlate
ItemSciencePack  MachineBelt      MachineFastBelt  MachineInserter  MachineBurnerMiner MachineFurnace MachineChest   MachineWorkbench
MachineAssembler MachineLab       MachineGenerator MachinePowerPole MachineElectricMiner Player
```
