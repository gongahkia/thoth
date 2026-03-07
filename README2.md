<h1 align='center'><code>thoth</code></h1>
<div align='center'>
<p>
  <i>Deterministic Lua runtime and toolkit for real-time systems.</i>
</p>
</div>

`thoth` is a small Lua library with two strong layers:

- `thoth.core`: data structures, validation, serialization, events, caching, graphs, tries, math, strings, and profiling utilities.
- `thoth.game` + `thoth.adapters`: a lightweight runtime for fixed-step simulation, ordered systems, input contexts, tasks, tweens, pathfinding, spatial queries, and cross-framework adapter wiring.

The project is strongest when those layers are used together: headless simulation in tests, shared gameplay logic, and thin engine-specific integration.

## Why `thoth`

- Deterministic-friendly runtime foundation with fixed timesteps and ordered systems.
- Cross-framework game loop integration for Love2D, Defold, and Solar2D.
- Broad core utility surface without pulling in external dependencies.
- Lightweight module boundaries that stay usable in plain Lua scripts.

## Installation

```console
luarocks install thoth
```

Or from source:

```console
git clone https://github.com/gongahkia/thoth
cd thoth
make test
```

## Package layout

### `thoth.core`

- `cache`: memoization, LRU caches, TTL caches
- `events`: event emitter, event bus, event queue, signals
- `graphs`: traversal, shortest paths, connectivity helpers
- `heaps`: min/max heaps and priority queues
- `links`, `queues`, `stacks`, `trees`, `tries`: foundational data structures
- `math`, `math2D`: scalar and 2D math helpers
- `performance`: timers, benchmarking, profiling, FPS helpers
- `serialize`: JSON/Lua encode/decode, deep copy, save/load helpers
- `stringify`: string processing helpers
- `tables`: functional table helpers
- `validate`: schema validation and contracts

### `thoth.game`

- `frame`: fixed-step scheduler with accumulator/interpolation alpha
- `runtime`: ordered systems, runtime context, input, tasks, tween timeline, and state manager composition
- `input`: action bindings, axes, contexts, import/export of profiles
- `state`: stack-based scene/state management
- `tasks`: coroutine scheduler for delayed and repeating jobs
- `tween`: tweens, timers, and timelines
- `pathfinding`: A* for graph and grid use cases
- `spatial`: spatial hash and quadtree helpers

### `thoth.adapters`

- `love2d`
- `defold`
- `solar2d`
- `contract`

## Quick start

Use a single module directly:

```lua
local stringify = require("thoth.core.stringify")
print(stringify.Lstrip("###watermelon", "#"))
```

Or load the lazy namespace:

```lua
local thoth = require("thoth")
local runtime = thoth.game.runtime.new(thoth.adapters.contract.nullAdapter(), {
    fixedDelta = 1 / 60,
    context = {
        mode = "headless"
    }
})

runtime:registerSystem({
    name = "tick",
    fixedUpdate = function(rt, dt, stepIndex)
        rt.context.lastStep = stepIndex
        rt.context.elapsed = (rt.context.elapsed or 0) + dt
    end
})

runtime:update(0.2)
print(runtime.context.elapsed)
```

## Cross-framework usage

The recommended pattern is:

1. Put gameplay logic in `thoth.game` systems, states, and helpers.
2. Use an adapter only to translate host framework lifecycle and input events.
3. Keep rendering and engine-specific resources inside the host framework.

Love2D example:

```lua
local thoth = require("thoth")
local adapter = thoth.adapters.love2d.new(love)
local runtime = thoth.game.runtime.new(adapter, { fixedDelta = 1 / 60 })
local hooks = adapter:registerLifecycle(runtime)

runtime.input:bind("jump", "space")

function love.update(dt)
    hooks.update(dt)
end

function love.draw()
    hooks.draw()
end

function love.keypressed(key)
    hooks.keypressed(key)
end

function love.keyreleased(key)
    hooks.keyreleased(key)
end
```

## Testing

The repository includes headless tests for:

- core modules
- runtime scheduling
- adapter validation
- framework smoke behavior
- migration errors for removed `src.*` imports

Run them from the repository root:

```console
make test
```

## Versioning direction

`thoth` v4 moved the public surface to:

- `thoth.core.*`
- `thoth.game.*`
- `thoth.adapters.*`

Legacy `src.*` imports intentionally fail with explicit migration messages.

## Project direction

The best long-term direction for `thoth` is to lean harder into being a deterministic, cross-engine gameplay runtime backed by a practical Lua core library.

That means investing in:

- reproducible runtime services
- richer adapter capabilities
- stronger gameplay primitives
- better observability
- better examples and tests

## Repository map

- Source modules: `thoth/`
- Legacy migration shims: `src/`
- Examples: `examples/`
- Tests: `test/`
- Packaging: `thoth-4.0.0-1.rockspec`

## License

MIT
