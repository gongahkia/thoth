# 3D Model Survey

Survey date: 2026-06-19

## Criteria

- CC0 license, or equivalent public-domain grant.
- Dungeon-ready modular walls, floors, doors, stairs, and props.
- Prefer OBJ or glTF/GLB because the current renderer already vendors `g3d` OBJ loading.
- Low-poly geometry and shared textures/materials for simple batching.

## Candidates

| Pack | Source | Author | License | Verified contents/formats | Fit |
|---|---|---|---|---|---|
| KayKit Dungeon Remastered | `https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0` | Kay Lousberg / KayKit | CC0 1.0 Universal | 200+ stylized dungeon props; walls, floors, stairs, doors, chests, barrels, chairs, tables, crates, traps, banners; FBX, GLTF, OBJ; single gradient atlas texture. | [Inference] Strongest primary candidate: broad coverage, OBJ now, glTF later, cohesive style. |
| Quaternius LowPoly Modular Dungeon Pack | `https://quaternius.itch.io/lowpoly-modular-dungeon-pack` | Quaternius | CC0 | 45+ modular dungeon assets; FBX, OBJ, Blend. | [Inference] Best small OBJ-first fallback; lower coverage than KayKit but simpler. |
| Quaternius Modular Dungeons Pack | `https://quaternius.com/packs/modulardungeon.html` | Quaternius | Free personal/commercial use; Quaternius site states assets use CC0 | Modular dungeon assets; FBX, OBJ, Blend. Poly Pizza mirror lists FBX/GLB and CC0. | [Inference] Useful if GLB import becomes preferable; verify source package before import. |
| Kenney Modular Dungeon Kit | `https://kenney.nl/assets/modular-dungeon-kit` | Kenney | Creative Commons CC0 | 40 files; 3D modular dungeon tiles; animation variations. I cannot verify exact file formats from the asset page alone. | [Inference] Strong clean modular fallback; needs download inspection for importer planning. |
| Kenney Mini Dungeon | `https://kenney.nl/assets/mini-dungeon` | Kenney | Creative Commons CC0 | 25 files; 3D mini dungeon/RPG/roguelike/medieval; animation variations; weapons/shields and character rigs noted in changelog. I cannot verify exact file formats from the asset page alone. | [Inference] Better for props/miniatures than full room construction. |

## Notes For 3.7

- [Inference] Pick KayKit Dungeon Remastered if the next task prioritizes one cohesive primary dungeon kit.
- [Inference] Pick Quaternius LowPoly Modular Dungeon Pack if the import work must stay OBJ-only and small.
- [Inference] Keep Kenney packs as CC0 alternates after direct zip inspection confirms formats and scale.
