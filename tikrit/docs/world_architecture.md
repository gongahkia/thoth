# Target World Architecture

## World Model

`run.world` remains the public runtime container. During migration it exposes both legacy fields and layered fields:

- `world.levels[depth]`: depth-indexed level table.
- `world.currentDepth`: active depth, initially `0`.
- `world.grid`, `world.data`, `world.entities`, `world.tileEntities`, `world.spawnRules`: aliases to the active level for legacy code.
- `run.player.depth`: player depth, kept in sync with `world.currentDepth`.

Each level contains:

- `depth`, `name`, `grid`, `data`
- `entities`, `tileEntities`, `spawnRules`
- `weather`, `hazards`, `discovered`
- optional legacy collections such as structures, resource nodes, wildlife, map nodes, and gates

## Tile Registry

Tiles are named behavior tables. Every tile supports default-safe methods:

- `collides(level, x, y, entity)`
- `isSolid()`
- `isDestructible()`
- `health(level, x, y)`
- `drops(level, x, y, entity)`
- `step(level, x, y, entity, run)`
- `bump(level, x, y, entity, run)`
- `hit(level, x, y, entity, run)`
- `interact(level, x, y, entity, run)`
- `randomTick(level, x, y, run)`
- `render(bundle, x, y, settings)`

String tile names stay valid, so current saved/replay data remains readable.

## Entity System

Entities are tables with `id`, `kind`, `depth`, `coord`, `width`, `height`, `solid`, and optional callbacks. The entity system owns:

- add/remove/spawn
- per-tile indexing
- AABB collision checks
- axis-separated movement
- tick/render dispatch

Existing wildlife tables are preserved until they are migrated into this entity list.

## Generation

`ProcGen.generateRunData(difficultyName, options)` remains the entry point. It returns:

- legacy surface fields for current runtime compatibility
- `levels` with depth `0`, `-1`, `-2`, and `1`
- constrained stairs/depth links
- current Tikrit macro-regions, hazards, gates, NPCs, and POIs

## Save and Replay

Replay context keeps current fields and adds `currentDepth`, player depth, and future tile interaction events. Legacy replay contexts without depth default to depth `0`.
