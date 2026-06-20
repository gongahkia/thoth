# Asset Survey

Survey date: 2026-06-19

## Billboard Character Criteria

- Transparent PNG/GIF spritesheet or easily extracted frames.
- 3/4, top-down, or isometric views that can sit on camera-facing billboards.
- Idle or standing frame required; walk and attack frames preferred.
- Cohesive enough to cover 8 hero classes and 59 enemy types without heavy repainting.
- Prefer CC0; CC-BY is usable with attribution; CC-BY-SA/GPL needs explicit approval before import.

## OGA Character Candidates

| Candidate | Source | Author shown | License shown | Coverage | Fit |
|---|---|---|---|---|---|
| 2DPIXX isometric Warrior/Wizard/Archer | `https://opengameart.org/users/2dpixx` | 2DPIXX / Jana Ochse | CC-BY 3.0 on checked character pages | 3 fantasy classes, 128x160, 4 directions, idle/walk/attack | Best billboard scale and style; too few archetypes for full roster without paid/custom expansion. |
| 32x32 RPG Character Sprites | `https://opengameart.org/content/32x32-rpg-character-sprites` | Eldiran | CC0 | 20 class-like sprites, standing/walk/charge; incomplete E/W walk for half | Strong CC0 hero-class base; lower resolution than desired but easy atlas input. |
| 700 sprites | `https://opengameart.org/content/700-sprites` | JPhilipp | CC-BY 3.0 | 700+ 32x32 fantasy sprites, front/back/left/right, gender/skin variants | Broadest single-pack roster fill; no rich combat animation. |
| DawnLike 16x16 Universal Rogue-like Tileset | `https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181` | DragonDePlatino | CC-BY 4.0 | Large roguelike set with characters, monsters, weapons, items | Good enemy/object fallback; very small sprites need scaling and style acceptance. |
| Tiny Characters Set | `https://opengameart.org/content/tiny-characters-set` | Fleurman | CC0 | 32 tiny characters based on GrafxKid's CC0 RPG sprites | Good CC0 NPC/low-detail fallback; too small for primary HD-2D billboards. |
| RPG character sprites | `https://opengameart.org/content/rpg-character-sprites` | GrafxKid | CC0 | Small templates plus short-hair, long-hair, dress variants | Useful base/source for edits; not enough as a primary pack. |
| LPC Medieval Fantasy Character Sprites | `https://opengameart.org/content/lpc-medieval-fantasy-character-sprites` | wulax | CC-BY-SA 3.0, GPL 3.0, OGA-BY 3.0 | Modular fantasy bodies, armor, weapons, skeleton, combat dummy | High coverage and animation depth; provenance/license complexity needs review before use. |
| Mostly 16x18 Characters and 48x48 Portraits Repack | `https://opengameart.org/content/mostly-16x18-characters-and-48x48-portraits-repack` | Jorhlok / CharlesGabriel | CC-BY 3.0 | 53 characters plus portraits, walk/punch/cast frames | Useful if portraits matter; tiny scale and missing flipped-left frames add pipeline work. |
| Isometric Painted Game Assets | `https://opengameart.org/content/isometric-painted-game-assets` | laetissima | CC0 | One cartoon knight with 4-direction walk plus tiles/UI | CC0 isometric proof asset; not enough character coverage. |
| Hero character sprite sheet | `https://opengameart.org/content/hero-character-sprite-sheet` | Fry | CC0 | One 40x64 hero, idle/walk all directions | Good prototype billboard source; not a pack. |
| Characters, Zombies, and Weapons. Oh My! | `https://opengameart.org/content/characters-zombies-and-weapons-oh-my` | Curt | CC0 | Characters, zombies, weapons | Enemy fallback; survival-horror tone may clash with fantasy roster. |
| Sideview Fantasy Patreon Collection | `https://opengameart.org/content/sideview-fantasy-patreon-collection` | ansimuz | CC0 | Sideview fantasy sprites/environments | Good art, poor camera-angle fit for top-down/isometric billboards. |

## Notes For 3.2

- I cannot verify this: the TODO note that "2DPIXX fantasy isometric" is CC0 on OGA. The checked 2DPIXX Warrior, Wizard, and Archer pages list CC-BY 3.0. A separate non-2DPIXX isometric pack by laetissima lists CC0.
- [Inference] Best visual direction is 2DPIXX if CC-BY attribution and limited class coverage are acceptable.
- [Inference] Best low-risk complete direction is Eldiran + Tiny Characters + GrafxKid CC0 for heroes/NPCs, with DawnLike or JPhilipp used for enemy breadth after attribution review.
- [Inference] LPC should stay backup-only until a file-level license/provenance audit confirms the exact license path for every imported sprite.
