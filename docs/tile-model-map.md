# Tile Model Map

Source page: `https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0`
OBJ root checked: `addons/kaykit_dungeon_remastered/Assets/obj`
Texture checked: `addons/kaykit_dungeon_remastered/Assets/texture/dungeon_texture.png`
License: CC0 1.0 Universal

`Registry.tileOrder` was absent before this task. It now exists and covers all 53 current `Registry.tiles` keys.

Semantic fit notes are [Inference] from the tile name and KayKit OBJ filename. The executable map is `assets/models/tile_model_map.lua`; this document is the review copy.

| Tile ID | Walkable | KayKit OBJ | Role | Notes |
|---|---|---|---|---|
| `archive_floor` | yes | `floor_tile_large.obj` | `base_floor` | [Inference] neutral archive floor. |
| `archive_wall` | no | `wall_shelves.obj` | `base_wall` | [Inference] shelf wall matches archive rooms. |
| `corridor` | yes | `floor_tile_small.obj` | `base_floor` | [Inference] smaller repeat tile for corridors. |
| `salt_floor` | yes | `floor_tile_big_grate.obj` | `base_floor` | [Inference] grate reads as damp cistern floor. |
| `salt_wall` | no | `wall_window_closed.obj` | `base_wall` | [Inference] closed wall variant for cistern perimeter. |
| `salt_causeway` | yes | `floor_foundation_front_and_sides.obj` | `base_floor` | [Inference] raised foundation reads as causeway. |
| `brine_pool` | no | `floor_tile_big_grate_open.obj` | `blocked_floor` | [Inference] open grate marks non-walkable pool cells. |
| `ember_floor` | yes | `floor_tile_small_broken_A.obj` | `base_floor` | [Inference] broken tile matches burned floor. |
| `ember_wall` | no | `wall_cracked.obj` | `base_wall` | [Inference] cracked wall fits heat damage. |
| `ember_corridor` | yes | `floor_dirt_large_rocky.obj` | `base_floor` | [Inference] rocky dirt differentiates warrens corridors. |
| `ash_choke` | no | `rubble_large.obj` | `blocked_prop` | [Inference] rubble blocks ash-choked paths. |
| `sealed_door` | no | `wall_doorway_door.obj` | `blocked_wall` | [Inference] door mesh for sealed blockers. |
| `camp_marker` | yes | `candle_lit.obj` | `curio_prop` | [Inference] compact camp marker. |
| `relic_cache` | yes | `chest_gold.obj` | `curio_prop` | [Inference] reward cache. |
| `whispering_idol` | yes | `pillar_decorated.obj` | `curio_prop` | [Inference] decorated vertical shrine stand-in. |
| `wire_snare` | yes | `spikes.obj` | `curio_prop` | [Inference] closest trap geometry. |
| `salt_font` | yes | `barrel_large_decorated.obj` | `curio_prop` | [Inference] basin stand-in until a font mesh exists. |
| `brine_lockbox` | yes | `chest.obj` | `curio_prop` | [Inference] lockbox stand-in. |
| `ash_vent` | yes | `floor_tile_grate_open.obj` | `curio_floor` | [Inference] vented grate floor. |
| `ember_reliquary` | yes | `chest_gold_lid.obj` | `curio_prop` | [Inference] ornate opened reliquary. |
| `lost_page` | yes | `table_small_decorated_A.obj` | `curio_prop` | [Inference] readable page needs later texture/detail. |
| `sealed_name` | yes | `key.obj` | `curio_prop` | [Inference] small quest-token stand-in. |
| `false_index` | yes | `shelves.obj` | `curio_prop` | [Inference] index shelf. |
| `page_bearer` | yes | `shelf_small.obj` | `curio_prop` | [Inference] portable page/shelf stand-in. |
| `misfiled_dead` | yes | `bed_floor.obj` | `curio_prop` | [Inference] prone body placeholder. |
| `witness_drawer` | yes | `trunk_medium_A.obj` | `curio_prop` | [Inference] drawer/chest substitute. |
| `clerk_cocoon` | yes | `barrel_large.obj` | `curio_prop` | [Inference] cocoon-shaped stand-in. |
| `name_press` | yes | `table_medium.obj` | `curio_prop` | [Inference] workbench/press base. |
| `open_register` | yes | `table_medium_decorated_A.obj` | `curio_prop` | [Inference] ledger table. |
| `stamped_confessional` | yes | `wall_arched.obj` | `curio_prop` | [Inference] arched alcove stand-in. |
| `tide_valve` | yes | `keg_decorated.obj` | `curio_prop` | [Inference] round valve stand-in. |
| `salt_register` | yes | `table_medium_tablecloth_decorated_B.obj` | `curio_prop` | [Inference] register table. |
| `tov_child` | yes | `bed_decorated.obj` | `curio_prop` | [Inference] narrative cot marker. |
| `deep_sluice_key` | yes | `keyring.obj` | `curio_prop` | [Inference] key objective. |
| `shutoff_shrine` | yes | `pillar.obj` | `curio_prop` | [Inference] compact shrine marker. |
| `silted_cradle` | yes | `bed_frame.obj` | `curio_prop` | [Inference] cradle stand-in. |
| `pressure_bell` | yes | `keyring_hanging.obj` | `curio_prop` | [Inference] hanging metal prop stand-in. |
| `brine_reliquary` | yes | `chest_gold.obj` | `curio_prop` | [Inference] ornate cache. |
| `ember_ward` | yes | `banner_patternA_red.obj` | `curio_prop` | [Inference] red ward marker. |
| `ash_name` | yes | `plate_small.obj` | `curio_prop` | [Inference] small token stand-in. |
| `warm_ledger` | yes | `table_small_decorated_B.obj` | `curio_prop` | [Inference] ledger table. |
| `aron_boy` | yes | `bed_floor.obj` | `curio_prop` | [Inference] prone narrative marker. |
| `white_furnace_key` | yes | `key.obj` | `curio_prop` | [Inference] key objective. |
| `false_vow` | yes | `banner_patternC_red.obj` | `curio_prop` | [Inference] vow marker. |
| `ash_lung_reliquary` | yes | `chest.obj` | `curio_prop` | [Inference] container stand-in. |
| `fuse_saint` | yes | `candle_triple.obj` | `curio_prop` | [Inference] votive marker. |
| `halo_vent` | yes | `floor_tile_extralarge_grates_open.obj` | `curio_floor` | [Inference] large vent grate. |
| `vitrified_cot` | yes | `bed_frame.obj` | `curio_prop` | [Inference] cot stand-in. |
| `boss_sigil` | yes | `floor_tile_small_decorated.obj` | `encounter_marker` | [Inference] archive sigil floor marker. |
| `tide_sigil` | yes | `floor_tile_big_grate.obj` | `encounter_marker` | [Inference] cistern sigil floor marker. |
| `ember_sigil` | yes | `floor_tile_big_spikes.obj` | `encounter_marker` | [Inference] dangerous ember sigil marker. |
| `exit_gate` | yes | `wall_gated.obj` | `exit_gate` | [Inference] gate mesh for exits. |
| `black_water` | no | `floor_tile_extralarge_grates_open.obj` | `blocked_floor` | [Inference] open grate marks black-water voids. |

## Import Notes

- Import only the OBJ files referenced in `assets/models/tile_model_map.lua`.
- Keep KayKit's shared `dungeon_texture.png` with the imported OBJ set.
- Walkable curio tiles should render their prop on top of the zone floor selected by mission location.
- Non-walkable floor hazards should keep collision from `Registry.tiles`; model role is visual only.
