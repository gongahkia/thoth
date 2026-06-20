# Hero Sprite Map

Source page: `https://opengameart.org/content/700-sprites`
Source zip checked: `https://opengameart.org/sites/default/files/last-guardian-sprites.zip`
License: CC-BY 3.0

The zip groups below were verified from filenames in `last-guardian-sprites.zip`. Each group has 32x32 GIF frames using this pattern: `<group>_<direction><frame>.gif`, where directions are `fr`, `bk`, `lf`, and `rt`, with frames `1` and `2`.

Class-fit notes are [Inference] from class skills/lore plus the visible front-frame silhouette.

| Class ID | Class | Needed silhouette | Primary OGA group | Alternate OGA group | Notes |
|---|---|---|---|---|---|
| `warden` | Warden | Shielded frontliner | `gsd1_*` | `knt1_*` | [Inference] `gsd1` reads as the clearest shield guard; `knt1` is the cleaner knight fallback. |
| `duelist` | Duelist | Light melee blade | `ftr1_*` | `thf3_*` | [Inference] `ftr1` gives a readable blade-first fighter; `thf3` fits a faster rogue-like variant. |
| `mender` | Apothecary | Field healer/medic | `wmg3_*` | `mnt1_*` | [Inference] `wmg3` gives the clearest light-robed support silhouette; `mnt1` works if the class should read less magical. |
| `arcanist` | Arcanist | Staff/arcane caster | `amg3_*` | `bmg3_*` | [Inference] `amg3` has the strongest wizard staff read; `bmg3` is the colder-color caster fallback. |
| `harrier` | Thief | Ranged scout | `wnv1_*` | `thf1_*` | [Inference] `wnv1` is the best ranger/scout read available in the pack; `thf1` works if speed matters more than ranged read. |
| `chirurgeon` | Chirurgeon | Hooded physician/alchemist | `wmg4_*` | `smr1_*` | [Inference] `wmg4` gives a hooded clinical support read; `smr1` works for a vial/staff alchemist read. |
| `exile` | Exile | Rough outcast/bruiser | `mst4_*` | `trk1_*` | [Inference] `mst4` reads as an outsider/bandit; `trk1` is the heavier exile fallback. |
| `lamplighter` | Lamplighter | Staff and light source | `smr3_*` | `amg1_*` | [Inference] `smr3` has the strongest staff/light silhouette; `amg1` keeps the same staff role with a warmer palette. |
| `merchant` | Merchant | Ledger clerk/contract broker | `man3_*` | `scr4_*` | [Inference] `man3` reads as the clearest plain official silhouette; `scr4` is the scribe fallback. |

## Import Notes

- Keep all 8 directional/walk frames per selected group.
- Import as 32x32 frames into the sprite pipeline.
- Preserve original group IDs in the generated manifest so future class swaps do not require atlas index archaeology.
- Do not commit source GIFs until the asset-attribution generator can include the CC-BY 3.0 credit line.
