# Tikrit Migration Phases

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
