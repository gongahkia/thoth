# Target World Architecture

## World Model

`run.world` remains the public runtime container. During migration it exposes both legacy fields and layered fields:

- `world.levels[depth]`: depth-indexed level table.
- `world.currentDepth`: active depth, initially `0`.
- `world.grid`, `world.data`, `world.entities`, `world.tileEntities`, `world.spawnRules`: aliases to the active level for legacy code.
- `run.player.depth`: player depth, kept in sync with `world.currentDepth`.

Runtime code should treat those aliases as compatibility surfaces. New or touched depth-local logic should use `World.currentLevel(run)`, `World.activeGrid(run)`, `World.activeCollection(run, key)`, `World.readActiveCollection(run, key)`, and `World.activeWildlife(run)` so combat, harvesting, markers, fires, curing, and rendering operate on the current depth even after save/load or replay restoration.

When several depth-local lists must be prepared together, runtime setup uses `World.ensureActiveCollections(run, keys)` so collection creation happens on the active level and the legacy top-level aliases are refreshed in one place. Direct `run.world.*` access remains appropriate for run-level state such as weather, time, discovered POIs, landmarks, regions, traversal requirements, replay/save summaries, and the alias maintenance code inside `World`.

Each level contains:

- `depth`, `name`, `grid`, `data`
- `entities`, `tileEntities`, `spawnRules`
- `weather`, `hazards`, `discovered`
- optional legacy collections such as structures, resource nodes, wildlife, map nodes, and gates

`spawnRules` are the depth-local ecology source of truth. Rules can define `id`, `kind`, `listName`, `cap`, `chancePerHour`, `cooldownHours`, `zone`, `minDistanceTiles`, `allowedTiles`, `blockedTiles`, and `blockedHazards`. Runtime counters and cooldowns live in `level.spawnState`; legacy wildlife lists remain the public compatibility storage.

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

Tile random ticks own conservative depth-local simulation state rather than broad balance changes. Current tick state is stored on the active level in small keyed tables such as `snowCover`, `iceState`, `shelterWear`, `warmthPockets`, and `thermalWarmth`; `World` aliases all of these tables to the active level for compatibility. World-level tick hooks also annotate active fires and regrowing loot/resource nodes with depth metadata. These tables are treated as simulation/cache state: save-game snapshots preserve them, while replay records compact audit counts and does not recreate simulation state from those counts.

## Entity System

Entities are tables with `id`, `kind`, `depth`, `coord`, `width`, `height`, `solid`, and optional callbacks. Entity-backed wildlife also carries `facingX`, `facingY`, `moving`, `aiState`, `homeZone`, `spawnRuleId`, `patrolPoints`, `patrolIndex`, and awareness state so actors update like first-class depth-local runtime objects. Hostiles can patrol home zones, watch/stalk from awareness range, charge inside aggro range, and retreat from deterrents. Passive wildlife records flee/forage/graze state and short fear memory while keeping the existing hunting/trapping surface. The entity system owns:

- add/remove/spawn
- per-tile indexing
- AABB collision checks
- axis-separated movement
- tick/render dispatch

Existing wildlife tables are preserved as compatibility views until entity-first persistence can replace them fully.

As of the active-level cleanup pass, wildlife combat, bow targeting, hostile loot, and AI ticking use `World.activeWildlife(run)` as their compatibility view. Direct `run.world.wildlife.*` access is intentionally retained only in older tests, save/replay summaries, or setup code where it represents serialized compatibility storage rather than live depth-local simulation.

## Generation

`ProcGen.generateRunData(difficultyName, options)` remains the entry point. It returns:

- legacy surface fields for current runtime compatibility
- `levels` with depth `0`, `-1`, `-2`, and `1`
- constrained stairs/depth links
- current Tikrit macro-regions, hazards, gates, NPCs, and POIs

## Save and Replay

Replay context keeps current fields and adds `currentDepth`, player depth, and future tile interaction events. Legacy replay contexts without depth default to depth `0`.

Save-game persistence is separate from replay. `SaveGame.snapshotRun(run)` captures a deterministic storage snapshot of the layered world, player, stats, and success/endgame runtime flags. It preserves legacy collections as the public storage shape, but strips transient entity mirrors, tile buckets, function callbacks, source backrefs, and mirror keys. `SaveGame.restoreRun(snapshot)` rebuilds aliases and entity mirrors through `World.attachRun` and `World.changeDepth`.

The runtime UI uses this save path directly: debug/runtime autosave remains available, pause writes manual saves to generated named slots, title/pause can list saves with friendly labels and metadata, selected saves can be deleted, and selected saves restore into live gameplay with camera, visibility, crafting, weather audio, and replay recording context refreshed.
