# License Audit

Audit date: 2026-06-20

## Scope

- Git-tracked files under `assets/`
- Git-tracked files under `spike/assets/`
- Packaged `vendor/g3d/g3d/` code and `vendor/g3d/LICENSE`
- `docs/asset-licenses.md`
- Preview screenshots and GIFs under `assets/previews/`
- Music candidate metadata in `assets/music/tracks.lua`

## Verification

- Local inventory: `git ls-files assets spike/assets vendor/g3d`
- Binary formats: `file assets/audio/*.wav assets/sprites/oga_700_sprites.png assets/previews/* spike/assets/george.png`
- OGA `700 sprites`: `https://opengameart.org/content/700-sprites`
- OGA `George`: `https://opengameart.org/content/alternate-lpc-character-sprites-george`
- KayKit Dungeon Remastered: `https://kaylousberg.itch.io/kaykit-dungeon-remastered`
- Local g3d license: `vendor/g3d/LICENSE`

## Findings

- `assets/sprites/oga_700_sprites.png` is derived from OGA `700 sprites`; source page lists JPhilipp as author, CC-BY 3.0, and attribution instructions naming Philipp Lenssen and `outer-court.com`.
- `spike/assets/george.png` is from OGA `Alternate LPC character sprites -- George`; source page lists sheep as author and CC-BY 3.0 among available licenses.
- `assets/audio/*.wav` files are project-authored procedural waveforms; no third-party samples are present.
- Asset READMEs are project-authored documentation and are now tracked in `docs/asset-licenses.md`.
- `assets/music/tracks.lua` contains source metadata only. No Pixabay music files are packaged yet, so certificate capture remains a pre-import requirement.
- `assets/models/tile_model_map.lua` references KayKit Dungeon Remastered paths only; no KayKit model files are imported yet. KayKit source page lists CC0.
- `assets/previews/*` files are project-authored gameplay captures containing game UI and embedded OGA `700 sprites` art; the CC-BY attribution path is covered by the OGA sprite row.
- `vendor/g3d/g3d/` is packaged with `vendor/g3d/LICENSE`, which is MIT.

## Result

Pass.

- No CC-NC assets found in the audited git-tracked asset set.
- CC-BY assets have attribution rows in `docs/asset-licenses.md`.
- Every git-tracked file under `assets/` has a matching license trace in `docs/asset-licenses.md`.
- No raw AI-generated asset content found.
