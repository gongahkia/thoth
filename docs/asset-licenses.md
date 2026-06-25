# Asset Licenses

## Imported Assets

| File | Source | Author | License | Notes |
|---|---|---|---|---|
| `spike/assets/george.png` | `https://opengameart.org/content/alternate-lpc-character-sprites-george` | sheep | CC-BY 3.0 | OGA asset is multi-licensed; used here under CC-BY 3.0 for the Phase 0 billboard spike. |
| `assets/sprites/oga_700_sprites.png` | `https://opengameart.org/content/700-sprites` | JPhilipp / Philipp Lenssen | CC-BY 3.0 | Generated atlas from selected `700 sprites` GIF frames; credit Philipp Lenssen and `outer-court.com`. |
| `assets/sprites/oga_700_sprites.lua` | Project-authored atlas metadata for `https://opengameart.org/content/700-sprites` | Thoth contributors / JPhilipp | Original project metadata + CC-BY 3.0 source trace | Maps selected OGA sprite frames to runtime names; source art remains credited to Philipp Lenssen and `outer-court.com`. |
| `assets/sprites/README.md` | Project-authored documentation | Thoth contributors | Original project documentation | Documents the OGA sprite import contract and regeneration source. |
| `assets/tiles/kenney_tiny_dungeon.png` | `https://kenney.nl/assets/tiny-dungeon` | Kenney | CC0 1.0 Universal | Packed 12x11 Tiny Dungeon tilemap sheet used by tactical tile atlas rendering. |
| `assets/audio/*.wav` | Project-authored procedural waveforms | Thoth contributors | Original project asset | Generated locally as 16-bit mono PCM; no third-party samples or AI-generated source material. |
| `assets/audio/README.md` | Project-authored documentation | Thoth contributors | Original project documentation | Documents runtime cue names and WAV format contract. |
| `assets/music/tracks.lua` | Project-authored metadata from Pixabay Music pages | Thoth contributors / listed Pixabay creators | Original project metadata; referenced tracks use Pixabay Content License | No raw music files are committed; certificate capture remains required before importing track binaries. |
| `assets/music/README.md` | Project-authored documentation | Thoth contributors | Original project documentation | Documents planned music filenames and certificate requirement. |
| `assets/models/tile_model_map.lua` | `https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0` | Kay Lousberg / KayKit | CC0 1.0 Universal | Project-authored runtime map references external KayKit OBJ paths; no KayKit model binaries are committed. |
| `assets/models/README.md` | Project-authored documentation | Thoth contributors | Original project documentation | Documents model import contract; no external model files are committed. |
| `assets/previews/*.png` | Project-authored gameplay captures | Thoth contributors / embedded JPhilipp sprite art | Original project capture + CC-BY 3.0 embedded sprite art | Screenshots contain generated game UI plus the OGA `700 sprites` atlas; credit Philipp Lenssen and `outer-court.com`. |
| `assets/previews/*.gif` | Project-authored gameplay capture | Thoth contributors / embedded JPhilipp sprite art | Original project capture + CC-BY 3.0 embedded sprite art | Animated preview contains generated game UI plus the OGA `700 sprites` atlas; credit Philipp Lenssen and `outer-court.com`. |
| `assets/press/*` | Project-authored press/logo assets | Thoth contributors | Original project asset | Logo source and generated PNG exports for press kit and store-page use; no third-party art or AI-generated source material. |

## Phase 3 Primary Character Pack

Selected: `700 sprites`
Source: `https://opengameart.org/content/700-sprites`
Author: JPhilipp / Philipp Lenssen
License: CC-BY 3.0
Attribution plan: credit Philipp Lenssen, `outer-court.com`, the OGA source URL, and CC-BY 3.0.
Status: selected as the primary character pack; selected frames are imported into `assets/sprites/oga_700_sprites.png`.

## Tactical Tile Atlas

Selected: `Tiny Dungeon`
Source: `https://kenney.nl/assets/tiny-dungeon`
Author: Kenney
License: CC0 1.0 Universal
Attribution plan: attribution not required by license; keep source URL and author in credits for traceability.
Status: selected as the primary tactical tile atlas; packed sheet imported into `assets/tiles/kenney_tiny_dungeon.png`.

## Phase 3 Primary 3D Model Pack

Selected: `KayKit Dungeon Remastered`
Source: `https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0`
Author: Kay Lousberg / KayKit
License: CC0 1.0 Universal
Attribution plan: attribution not required by license; keep source URL and author in credits for traceability.
Status: selected as the primary 3D dungeon model pack; no local files imported yet.
