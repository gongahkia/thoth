# Tikrit Migration Phases

## Current Status

- Phases 0-5 now have working vertical slices on the Lua/LÖVE codebase: layered depths, tile behavior hooks, entity-indexed levels, facing interactions, richer procgen, station-filtered crafting, furniture containers, entity-backed wildlife, random simulation ticks, and the ridge Weather Station finale.
- The current hardening pass is tightening the bridge between old compatibility lists and the new entity/world systems. Legacy lists remain available for save/replay/UI compatibility, but runtime rendering and interaction should prefer `EntitySystem`, `World`, `TileRegistry`, and furniture/wildlife entity mirrors.
- Phase 8 has mostly retired duplicate legacy rendering for mirrored furniture, wildlife, fires, traps, carcasses, loot markers, and world markers. Rendering now prefers `EntitySystem.render`; legacy fallback remains for true non-mirrored compatibility surfaces such as ordinary resource nodes and run-level overlays.
- Phase 9 hardens replay context restoration for depth, active aliases, Weather Station success state, and audit-only runtime object summaries.
- Phase 10 targets the remaining Microcraft-style object lifecycle gap: entity-first tool hits, damageable/pickup-capable furniture, and item-use definitions.
- Phase 11 closes the main Microcraft-style ecology gap: active-depth wildlife populations are driven by per-depth spawn rules with caps, cooldowns, tile/hazard constraints, and entity actor movement/facing/AI state.
- Phase 12 adds an entity-safe save snapshot/restore path: save files preserve layered legacy storage and runtime state, strip transient entity mirrors/functions, and rebuild active aliases/mirrors through `World.attachRun`.
- Phase 13 wires save/load into the runtime UI: pause can autosave, title/pause can open a save list, loading restores a run through the save backend, and replay saving stays separate.
- Phase 14 narrows the legacy storage surface: active-depth wildlife, grid, curing, fire, mapping, combat, bow, trap, fish, and carcass paths now prefer `World.currentLevel`, `World.activeCollection`, `World.readActiveCollection`, and `World.activeWildlife` instead of assuming top-level active aliases.
- Phase 15 adds save-slot management: save snapshots can carry slot labels, manual saves use distinct generated slots, save lists expose friendly metadata, and selected saves can be deleted.
- Phase 16 tightens the compatibility boundary: runtime setup, POI/biome discovery/rendering, hazard/temperature reads, and runtime smoke coverage now use active-level helpers rather than top-level collection aliases.
- Phase 17 deepens entity ecology without new assets: actors keep awareness, home-zone patrol state, flee/forage/graze/passive state, and hostiles can watch or stalk from awareness range before charging.
- Phase 18 expands tile simulation hooks: snow drift cover is weather-aware, paths/ash clear cover, weak ice refreezes deterministically in cold conditions, thermal fissures track warmth pockets, fires record tick hooks, and regrowing loot records depth metadata.
- Phase 19 hardens tile simulation persistence: all active simulation tables alias through `World`, save/load preserves tile tick state, and replay records audit summaries without recreating simulation state.
- Phase 20 is a conservative boundary cleanup: compatibility aliases remain supported for save/replay/UI storage, but new and touched runtime code should read or mutate active-depth collections through `World` helper APIs; tests should assert direct aliases only when alias compatibility is the behavior under test.
- Remaining cleanup debt: add more content variety, continue shrinking test-only alias assumptions, and eventually remove compatibility list storage once entity-first persistence paths are proven stable.

## Phase 0: Stabilize

- Restore a passing baseline for the current macro-world branch.
- Keep the expanded regions, traversal gates, NPC rumors, hidden POIs, and survey mechanics already in progress.
- Acceptance: `make test` passes and procgen reachability covers every critical route.

## Phase 1: Engine Foundation

- Add `TileRegistry`, `EntitySystem`, and `World` modules.
- Keep existing top-level world fields as compatibility aliases while adding `world.levels` and `world.currentDepth`.
- Route walkability and basic tile behavior through the tile registry.
- Acceptance: unit tests cover tile lookup, tile hit/drops, entity movement/collision, level aliases, depth changes, and random ticks.

## Phase 2: Interaction and Movement

- Move player collision to axis-separated world movement.
- Add facing tile helpers and prefer faced entity/tile interaction before proximity fallback.
- Convert ropes, caves, stairs, and gates to tile/entity interactions.
- Acceptance: runtime smoke tests cover movement into blocked tiles, facing-tile interaction, and depth transitions.

## Phase 3: Layered Procedural World

- Generate surface, ice cave, deep mine, and ridge/weather-station levels.
- Use seeded noise-like passes: base terrain, erosion/smoothing, flora/resources, hazards, and constrained stairs.
- Keep Tikrit biomes and unforgiving hazards instead of Microcraft fantasy biomes.
- Acceptance: deterministic seeds, valid stairs, reachable endgame route, and sensible biome/resource distribution.

## Phase 4: Crafting, Furniture, and Tools

- Expand item definitions with tool metadata, stamina cost, damage, station, light, and use hooks.
- Add furniture entities for workbench, stove, chest/cache, lantern, shelter, and bedroll.
- Add tool-driven tile harvesting for trees, rocks, weak ice, snow, and carcasses.
- Acceptance: station-filtered recipes, tile drops, furniture placement, and inventory/chest flows are tested.

## Phase 5: Simulation and Endgame

- Move wildlife and raiders into the entity system with depth spawn rules and offscreen spawning.
- Add random tile ticks for snow cover, weak ice, thermal fissures, shelter decay, and forage regrowth.
- Replace Air Wizard parity with a Tikrit finale: reach and activate the Weather Station.
- Acceptance: survival clocks, hostile AI, random ticks, and endgame activation work across depths.

## Phase 6: Entity-First Runtime Cleanup

- Mirror fires, snare traps, carcasses, and lightweight loot markers into entity-indexed runtime objects.
- Keep legacy collections as compatibility storage while routing rendering through `EntitySystem`.
- Use active-depth collection helpers for new fire, trap, carcass, and hostile loot writes.
- Acceptance: object mirroring is idempotent, stale entities are pruned, active-depth writes are tested, and replay context includes runtime object counts.

## Phase 7: Entity-Backed World Markers

- Mirror fishing holes, rope climbs, map/survey nodes, traversal gates, and NPC encounters into entity-indexed world markers.
- Prefer faced marker entity interaction for fishing, climbing, mapping/surveying, gate traversal, and NPC dialogue while keeping proximity fallbacks.
- Route marker rendering through `EntitySystem` with duplicate-safe legacy draw fallback.
- Acceptance: marker mirroring/rendering is idempotent, marker interactions reuse existing systems, and runtime smoke confirms marker rendering.

## Phase 8: Entity-First Rendering and Active-Level Cleanup

- Route mirrored runtime objects and markers through one `EntitySystem.render` pass in the active level.
- Add non-mutating active-depth collection reads for lookups and replay summaries.
- Snapshot active-depth object and marker counts in replay context, including opened caches, marker counts, resolved NPCs, opened gates, and endgame/weather-station flags.
- Keep legacy collection aliases intact for save/replay compatibility while avoiding duplicate draw and interaction handling for mirrored entries.
- Acceptance: helper tests prove read/write active collection behavior, entity render tests prove mirrored entries draw once, replay tests cover summary fields, and runtime smoke remains green.

## Phase 9: Save/Replay Persistence Hardening

- Extract replay context application so playback restores depth, player depth, active aliases, weather/time, player equipment, and Weather Station success state consistently.
- Keep runtime object and marker counts as replay audit summaries only; they do not recreate fires, traps, caches, or markers.
- Preserve legacy replay compatibility by defaulting missing depth fields to surface depth `0` and ignoring unknown context fields.
- Tighten replay parsing for empty values, zeroes, booleans, nested fields, and underscore-bearing diagnostic fields.
- Acceptance: replay unit tests cover supported depths and defensive context fields, runtime smoke starts restored non-surface/endgame playback contexts, and the full suite passes.

## Phase 10: Microcraft-Style Object Lifecycle and Item Use

- Prefer faced entity hits before tile hits through `World.hitFacing`, while keeping tile harvesting compatibility.
- Give furniture health, drops, pickup metadata, and tool-hit behavior; fixed cabin tile stations remain interactable but not portable.
- Route non-combat item use through item definitions for equipment, consumables, treatments, lights, and bedroll placement.
- Keep per-tile damage in level data and per-furniture damage on entity/source state so partial work survives attach/depth changes.
- Acceptance: entity-first hit routing, furniture break/pickup, fixed station protection, item use parity, tile harvesting regression, and runtime smoke all pass.

## Phase 11: Depth Ecology and Entity AI Parity

- Treat `level.spawnRules` as the source of truth for active-depth wildlife populations, including kind, list, cap, chance, cooldown, valid tiles, blocked tiles, hazard exclusions, and offscreen distance.
- Spawn only on the active level through `World.spawnOffscreen`, while preserving legacy `world.wildlife.*` lists as compatibility views.
- Extend entity-backed wildlife and raiders with Microcraft-style runtime state: facing vector, moving flag, AI state, home zone, and spawn rule ID.
- Keep movement tile-aware through `EntitySystem.moveEntity` and `TileRegistry` collision, without changing combat, hunting, trapping, carcass, bow, or melee balance.
- Acceptance: fixed-seed spawns are deterministic, caps/cooldowns/visibility/tile/hazard constraints are tested, active-depth spawning is isolated, duplicate mirroring remains stable, and `make test` passes.

## Phase 12: Entity-Safe Save Persistence

- Add a save-game module that snapshots runs into versioned save files with layered world state, current depth, player state, stats, endgame flags, runtime success state, spawn state, opened caches, furniture damage, and legacy storage collections.
- Strip transient runtime mirrors before serialization: entity lists, tile buckets, source backrefs, render/interact/hit callbacks, and generated mirror keys are rebuilt instead of persisted.
- Restore save snapshots by deep-copying storage state, clearing transient level state, calling `World.attachRun`, and applying `World.changeDepth` so aliases and player depth are correct.
- Keep replay as input playback plus context metadata; save files are the explicit save-state path and do not change replay format.
- Acceptance: save snapshots omit transient mirrors, save/load round-trips layered active depth and runtime state, restored mirrors are idempotent after repeated attach, and `make test` passes.

## Phase 13: Save/Load UI Integration

- Add Save Game and Load Game actions to the pause flow, and Load Game to the title flow.
- Save Game writes the current non-replay run to the autosave slot through `SaveGame.saveRun`; replay playback remains blocked from save-state writes.
- Load Game lists `SaveGame.listSaves()` entries with date, mode, difficulty, depth, and day, then restores the selected slot through `SaveGame.loadRun`.
- Loaded runs refresh camera, visibility, crafting, active aliases, weather audio, and replay recording context so gameplay resumes immediately.
- Acceptance: runtime smoke saves a non-surface run, loads it, preserves depth/aliases/message state, and verifies repeated `World.attachRun` does not duplicate restored entity mirrors.

## Phase 14: Active-Level Access and Legacy Storage Reduction

- Add targeted active-level helpers for runtime code that still needs compatibility storage, especially `World.activeWildlife(run)` and `World.activeGrid(run)`.
- Refactor combat, bow hunting, trap/fish/carcass paths, fire shelter checks, curing updates, visibility, and mapping reads to use active-level helpers where they represent depth-local state.
- Keep direct `run.world.*` access for true run-level metadata such as weather, time, goals, discovered POIs, regions, traversal requirements, and save/replay summaries.
- Acceptance: active-depth wildlife combat and bow hunting affect only the current level, existing trap/carcass/fishing/fire/cache/station regressions remain green, restored saves rebuild aliases and mirrors idempotently, and `make syntax` plus `make test` pass.

## Phase 15: Save Slot Management

- Preserve save-file compatibility while adding optional `slot` and `slotLabel` metadata to new snapshots.
- Add backend helpers for normalized slot names, default manual slot generation, friendly save-list entries, and deletion.
- Keep autosave support for debug/runtime compatibility, but make the pause Save Game action write a distinct manual slot so multiple runs can be retained.
- Update the load screen to show friendly labels, file metadata, and a delete key for selected saves.
- Acceptance: named slots save/load/inspect, save entries expose labels and depth metadata, selected saves delete cleanly, save/load runtime smoke remains green, and `make syntax` plus `make test` pass.

## Phase 16: Legacy Storage Boundary Cleanup

- Add a batch helper for active-level collection initialization so run creation no longer seeds depth-local collections through repeated top-level alias writes.
- Route active-level biome, POI, hazard, temperature-band, resource-node, structure, and grid reads through `World.currentLevel`, `World.activeGrid`, `World.activeCollection`, and `World.readActiveCollection`.
- Keep direct `run.world.*` access only where the field is true run-level state or an intentional compatibility alias maintained inside `World`.
- Update runtime smoke and world helper tests so active-depth behavior is asserted through the helper APIs rather than top-level collection assumptions.
- Acceptance: source-level direct active-collection reads outside `World` are reduced to intentional alias maintenance, compatibility setup remains stable, and `make syntax` plus `make test` pass.

## Phase 17: Depth Ecology and AI Behavior Pass

- Preserve existing wildlife, raider, combat, trap, bow, and carcass behavior while making entity actor state richer.
- Add per-actor awareness fields: `awarenessRadiusTiles`, `awareness.seesPlayer`, `awareness.distanceToPlayer`, `awareness.lastSeenCoord`, and `awareness.alertness`.
- Use home zones to derive simple patrol points for hostiles; outside aggro range, raiders can watch and wolves can stalk before committing to a charge.
- Give passive animals explicit flee/forage/graze state and short fear memory while retaining current hunting and trap compatibility.
- Acceptance: awareness/rule metadata persists on spawned actors, hostiles watch/patrol outside aggro range, passive animals flee with awareness state, existing combat and spawn tests remain green, and `make syntax` plus `make test` pass.

## Phase 18: Tile Simulation Expansion

- Expand random tile ticks while preserving existing survival balance and assets.
- Make snow-cover ticks respond to weather, with blizzards building cover faster and clear weather/path/ash tiles reducing cover.
- Make weak ice track tile-local refreeze state and reliably return to ice under sustained cold conditions.
- Track thermal fissure warmth and warm only nearby players instead of globally warming on any fissure tick.
- Add lightweight fire decay/regrowth hooks so future fire, forage, and cache systems have deterministic per-depth metadata.
- Acceptance: tile-registry tests cover weather-aware snow, weak-ice refreeze, and thermal warmth; world tests cover fire/cache tick metadata; `make syntax` and `make test` pass.

## Phase 19: Tile Simulation Persistence and Replay Diagnostics

- Treat depth-local simulation tables as first-class active-level aliases: `snowCover`, `iceState`, `shelterWear`, `warmthPockets`, and `thermalWarmth`.
- Preserve tile simulation state through save snapshots and restore the active aliases after load/depth restoration.
- Add compact replay diagnostics for active tile simulation counts while keeping replay audit-only, not a full world-state save.
- Keep gameplay balance unchanged; this phase only makes the Phase 18 simulation state safer and easier to inspect.
- Acceptance: save/load tests preserve simulation tables, replay/runtime smoke tests round-trip audit summaries, active-level summary helpers are covered, and `make syntax` plus `make test` pass.

## Phase 20: Conservative Compatibility Boundary Cleanup

- Preserve `run.world.*` compatibility aliases and save/replay formats while moving touched production reads to `World.currentLevel`, `World.activeGrid`, `World.activeCollection`, `World.readActiveCollection`, and `World.activeWildlife`.
- Treat direct active-depth alias reads in tests as compatibility assertions only; gameplay and runtime smoke tests should set up and inspect active collections through helper APIs.
- Keep tile behavior source-of-truth mutations on the level tables, relying on active alias identity rather than duplicate top-level writes.
- Acceptance: production active-depth reads avoid direct aliases outside intentional `World` maintenance, helper-based tests cover the same behavior, and `make syntax` plus `make test` pass.
