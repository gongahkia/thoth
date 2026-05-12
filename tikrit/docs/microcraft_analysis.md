# Microcraft Architecture Analysis

Microcraft is a Java top-down survival-crafting game inspired by Minicraft. This document records the system ideas Tikrit can adapt without copying code or assets.

## Runtime Shape

- A `GameState` owns every generated level, the active depth, the player, global IDs, HUD, and menu state.
- Each `Level` is a fixed-size tile map with parallel tile data, an entity list, per-tile entity buckets, spawn rules, and random tile ticks.
- The active level updates and renders through camera bounds; only visible tiles and entities inside the viewport are drawn.
- Depth is structural: surface, underground layers, and an endgame layer are separate maps connected by stair tiles.

## Generation

- Generation is depth-specific. The overworld uses layered noise for height, rockiness, trees, beaches, and flora.
- Underground layers use noise for rock/ground/dirt, then add ores and liquid pools.
- Stairs are placed after levels are generated, with constraints such as no liquids, required rock/open surroundings, and fallbacks if no valid site exists.
- Entity populations are seeded by per-depth spawn rules with chance and cap scaling.

## Tiles

- Tiles are behavior objects, not just strings. They can collide, render, receive hits, return drops, react to steps, handle interaction, emit light, and random tick.
- Tile health and damage live in per-tile data, so one tile instance definition can govern many coordinates.
- Terrain changes are local and simulation-friendly: trees become grass when chopped, rocks become stone, farmland dries out, stairs change depth.

## Entities

- Entities have pixel positions, bounding boxes, current tile coordinates, depth, direction, movement flags, and optional AI.
- Movement is axis-separated. Each axis move checks map bounds, entity collisions, and tile collisions, then rolls back only the blocked axis.
- Entities are indexed into per-tile buckets so nearby collision, interaction, and rendering stay bounded.
- Furniture is an entity type: it collides, can be pushed or hit, drops its item, and opens station-specific menus.

## Player Interaction

- The player tracks facing direction independently of movement.
- Interact first targets entities on the player/facing tile, then the facing tile, then falls back to inventory.
- Hit/use first targets entities, then consumables, tools against ideal/usable tile types, and finally item use on tiles.
- Crafting is station-filtered: inventory, workbench, oven, furnace, and anvil expose different recipe sets.

## Tikrit Adaptation Boundaries

- Adapt system shape, not implementation text, sprites, sounds, palettes, or names.
- Keep Tikrit's survival identity: exposure, weather, hunger, thirst, fatigue, shelter, hunting, mapping, and hostile wilderness.
- Replace Microcraft fantasy progression with Tikrit-specific depths: frozen surface, ice caves, deep mine/ruins, and weather-station endgame.
