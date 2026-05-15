# Pivot ASAP: Lua Block Automation Sandbox

Date: 2026-05-15
Status: brainstorming direction, ready to turn into an implementation plan

## Working Assumption

"More like Factorio/Minecraft" means an open-ended block-world automation sandbox:

- Minecraft influence: explore, mine, chop, place, craft, reshape a blocky world, build a base, survive light world pressure.
- Factorio influence: automate extraction, routing, processing, storage, power, research, expansion, and throughput.
- Microcraft influence: compact systems, clear registries, tile/entity architecture, simple menus, small-scope charm.

This does not mean building a full first-person 3D Minecraft engine first. For a Lua-only project, the stronger and more realistic direction is a polished top-down or 2.5D block world with chunked terrain, z/depth layers, and a deep automation loop.

## One-Sentence Pitch

A Lua-first block automation sandbox where the player carves a procedural world by hand, then bootstraps that world into a growing factory of miners, belts, furnaces, assemblers, power grids, storage, and research.

## Direction Change From The Earlier Plan

The previous Infinifactory-like direction centered on bounded puzzle rooms and target-output validation. This pivot should instead center on:

- Persistent procedural world, not isolated puzzles.
- Resource extraction and factory growth, not one-off assembly challenges.
- Player-authored bases and terrain shaping, not fixed puzzle arenas.
- Progression through recipes and tech, not level unlocks alone.
- Emergent goals, with optional milestones, not only pass/fail solutions.

Infinifactory can still inform placement tools, simulation previews, and debugging UX, but it should no longer be the product model.

## Why This Fits Thoth

The current repo is a framework, not a game, but the useful parts are already aligned with this pivot:

- `thoth.game.runtime`: deterministic fixed-step loop, ordered systems, snapshots, replay, rollback, metrics, debug HUD.
- `thoth.game.input`: action bindings, layered contexts, capture/replay.
- `thoth.game.tilemap`: layered tile storage and cell/world conversion.
- `thoth.game.terrain`: deterministic grid generation helpers.
- `thoth.game.spatial`: broad-phase spatial indexing for entities and dropped items.
- `thoth.core.serialize`: saves, snapshots, JSON/Lua table serialization.
- `thoth.core.events`: event bus for machine state, UI updates, combat, resource changes.

The pivot should build a game layer on top of Thoth rather than mutating every Thoth module into game-specific code.

## Competitive Context

Relevant references:

- [Minecraft](https://www.minecraft.net/en-us/about-minecraft): own-world exploration, building, survival, cross-platform social ecosystem, huge creator economy.
- [Factorio](https://factorio.com/game/content): automation, procedural maps, resource extraction, production goals, defense, scenarios, map editor, Lua scripting for custom scenarios.
- [Luanti](https://docs.luanti.org/about/luanti/): formerly Minetest, an open-source voxel engine with a Lua API. This is the closest "Lua plus voxel sandbox" comparison.
- [Vintage Story](https://www.vintagestory.at/): deeper survival/crafting in a voxel world.
- [Satisfactory](https://www.satisfactorygame.com/), [shapez 2](https://store.steampowered.com/app/2162800/shapez_2/), and [Modulus](https://store.steampowered.com/app/2779120/Modulus_Factory_Automation/) cover the high-polish factory-building space.

The separation should not be "we are bigger than Minecraft or Factorio." The separation should be:

- A complete, small-scope factory sandbox written in Lua.
- Deterministic simulation with save/replay/debug tooling as a visible portfolio strength.
- A block world that is tactile and editable, but with factory automation as the core loop.
- A clean source-available codebase that reads like a serious systems project.
- A focused solo-developer scope: 2D/2.5D, compact recipe ladder, carefully polished interactions.

## Product Pillars

### 1. Block World That Matters

The world should be a destructible grid with resources, terrain, obstacles, water, caves/depth layers, and player-built structures.

Minimum version:

- Chunked 2D world, for example 32x32 tile chunks.
- Surface layer plus optional cave/depth layers.
- Biomes: grassland, forest, stone, desert, water, ore patches.
- Tile registry with hardness, drops, collision, walkability, buildability, light, and minimap color.
- Deterministic world generation from seed.

### 2. Manual To Automatic Progression

The early loop should feel Minecraft-like, then quickly become Factorio-like.

Early ladder:

1. Gather wood/stone/ore manually.
2. Craft workbench, furnace, chest.
3. Craft belts and burner miner.
4. Automate ore into furnace into chest.
5. Craft lab and science pack.
6. Unlock electric miner, assembler, power poles.
7. Expand to multi-resource chains.

### 3. Factory First

Automation must become the main game, not a side system.

Core machines:

- Belts: directional item transport.
- Inserters: move items between adjacent belts, machines, and chests.
- Miners: extract from resource tiles.
- Furnaces: convert ore to plates.
- Assemblers: consume recipe inputs over time.
- Chests: storage.
- Generators: produce power from fuel.
- Power poles: connect machines into networks.
- Labs: consume science to unlock tech.

Later machines:

- Splitters and filters.
- Underground belts.
- Pumps and fluids.
- Trains or carts.
- Logistic drones.
- Circuit signals.

### 4. Lua-Native Determinism

The game should use deterministic ticks as a signature feature.

Target properties:

- Same seed plus same input replay produces same world state.
- Headless tests can run factory simulations without Love2D.
- Replay files can become portfolio artifacts.
- Save files are readable Lua or JSON tables.
- Debug HUD can show tick cost, active chunks, belt item count, machine count, power demand, and pending events.

### 5. Compact Polish

The first playable version should be small and refined:

- Good camera, hotbar, placement preview, rotation, mining feedback, item pickup, and UI sounds.
- Clear item icons and tile visuals.
- Readable belts and machine states.
- Pause, step, fast-forward, and maybe ghost placement.
- Save/load from the start.

## Non-Goals For MVP

Avoid these until the core loop is fun:

- Full first-person 3D voxel renderer.
- Multiplayer.
- Infinite vertical 3D terrain.
- Large mob/ecology simulation.
- Huge survival system with hunger, thirst, weather, temperature.
- Dozens of ores and hundreds of recipes.
- Trains, fluids, and circuits in the first milestone.
- A general-purpose mod platform.

## Proposed Repo Shape

Keep `thoth/` as the engine/library layer. Add a game layer beside it.

Suggested structure:

```text
thothcraft/
  bootstrap.lua
  main.lua
  data/
    tiles.lua
    items.lua
    recipes.lua
    tech.lua
    machines.lua
  world/
    chunk.lua
    chunks.lua
    terrain.lua
    tile_registry.lua
    resources.lua
    save.lua
  player/
    controller.lua
    inventory.lua
    crafting.lua
    build.lua
  factory/
    belts.lua
    inserters.lua
    machines.lua
    power.lua
    logistics.lua
    research.lua
  sim/
    systems.lua
    commands.lua
    snapshot.lua
    replay.lua
  render/
    love2d.lua
    sprites.lua
    camera.lua
    debug.lua
  ui/
    hud.lua
    hotbar.lua
    inventory.lua
    crafting.lua
    machine_panel.lua
```

This keeps the product isolated while still using Thoth primitives.

## Data Model Sketch

```lua
world = {
    seed = 12345,
    tick = 0,
    chunks = {},
    entities = {},
    player = {},
    nextEntityId = 1,
    nextItemId = 1,
}

chunk = {
    cx = 0,
    cy = 0,
    tiles = {},
    machines = {},
    droppedItems = {},
    active = true,
}

tile = {
    id = "iron_ore",
    data = 0,
}

machine = {
    id = 42,
    kind = "furnace",
    x = 10,
    y = 14,
    direction = "east",
    inventory = {},
    recipe = "iron_plate",
    progress = 0,
    powerNetwork = nil,
}
```

Suggested deterministic tick order:

1. Apply queued player commands.
2. Update active chunks.
3. Resolve terrain mutations.
4. Update miners and resource extraction.
5. Update belts and logistics.
6. Update inserters.
7. Update machine recipes.
8. Update power networks.
9. Update entities and item pickups.
10. Emit events and update UI-facing state.

## MVP Milestone

The first real milestone should prove the game loop, not the whole dream.

Target demo:

- Start in a seeded top-down block world.
- Move, mine trees/stone/ore, place blocks.
- Craft workbench, furnace, chest, belts, burner miner.
- Place a miner on iron ore.
- Route ore on belts into a furnace.
- Route plates into a chest.
- Save, reload, and replay a short deterministic session.

This is the minimum "Factorio meets Minecraft in Lua" proof.

## Phase Plan

### Phase 0: Lock Direction

- Pick working title, probably not `Thoth` if this becomes a game.
- Decide whether this repo becomes the game repo or keeps Thoth as a library with a bundled game.
- Keep Love2D as the first target.
- Define the MVP item list and recipe list.

### Phase 1: World And Player Prototype

- Chunked world storage.
- Seeded terrain generation.
- Player movement and camera.
- Mine/place interaction.
- Inventory and hotbar.
- Save/load.
- Basic Love2D renderer with placeholder tiles.

Success condition: walking around, mining, placing, collecting, and saving feels stable.

### Phase 2: Automation Prototype

- Tile-based belts with deterministic item slots.
- Chests and item insertion/extraction.
- Burner miner.
- Furnace.
- Basic crafting recipes.
- Machine placement preview and rotation.
- Debug overlay for active machines and item count.

Success condition: an ore-to-plate-to-chest line works without manual babysitting.

### Phase 3: Progression Prototype

- Workbench and assembler.
- Lab and science.
- Small tech tree.
- Electric miner, generator, power poles.
- More resources: copper, coal, stone.
- First expansion pressure: bigger ore patch, distance, or hostile territory.

Success condition: the player has a reason to scale beyond the first belt line.

### Phase 4: Game Feel And Portfolio Polish

- Pixel/block art pass.
- UI pass for hotbar, inventory, crafting, machine panel, and build menu.
- Audio pass for mining, placing, pickup, belt motion, machine states.
- Tutorial prompts or guided first objective.
- Deterministic replay demo.
- Trailer-worthy 60-second flow.
- README rewrite that presents the project as a game, not a utility library.

Success condition: a viewer can understand the game in one minute and trust the engineering in five.

## Testing Strategy

Tests should sell the systems quality:

- Terrain generation is deterministic by seed.
- Save/load round-trips world state.
- Input replay reproduces the same simulation state.
- Belts preserve item order.
- Inserters never duplicate or delete items except by recipe consumption.
- Machines consume exact inputs and produce exact outputs.
- Power networks produce stable supply/demand results.
- Chunk activation does not change simulation results near active boundaries.

## Main Risks

### Risk: "Lua-only Minecraft" Becomes Too Large

Mitigation: keep the first game top-down/2.5D. Use block-world mechanics without a full first-person 3D renderer.

### Risk: Factory Simulation Becomes Slow

Mitigation: use chunk activation, compact arrays for belt state, deterministic system order, and benchmark from Phase 2.

### Risk: The Product Feels Like A Tech Demo

Mitigation: include progression, visual feedback, sound, and a complete ore-to-science loop early.

### Risk: Scope Creep From Survival Features

Mitigation: survival pressure should support automation. If a system does not push the player toward building better factories, defer it.

### Risk: Competing Directly With Luanti

Mitigation: do not pitch this as a general voxel engine. Pitch it as a complete automation game written in Lua with readable systems and deterministic tooling.

## Immediate Next Actions

1. Create `thothcraft/` skeleton.
2. Add a Love2D entry point that boots Thoth runtime.
3. Implement chunked tile world and placeholder renderer.
4. Add player movement, mining, placing, inventory, and hotbar.
5. Add deterministic save/load test before factory logic.
6. Build the first ore-to-furnace-to-chest automation loop.

## Confidence

This direction is stronger than the Infinifactory-like plan for the stated preference because it turns Thoth into a persistent systems sandbox, which better matches the existing deterministic runtime, terrain, serialization, and adapter work. The key discipline is to make it Factorio/Minecraft in loop and feel, not in total feature count.
