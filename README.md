# thoth v4

Functional Lua pocket knife with a framework-agnostic game runtime.

## Install

### LuaRocks

```bash
luarocks install thoth
```

### Git

```bash
git clone https://github.com/gongahkia/thoth
cd thoth
make test
```

## Import modes

```lua
local thoth = require("thoth")
local graphs = require("thoth.core.graphs")
local runtime = require("thoth.game.runtime")
local love2d = require("thoth.adapters.love2d")
```

## Namespaces

- `thoth.core.*`: data structures, algorithms, validation, serialization, events, caching, profiling
- `thoth.game.*`: frame scheduler, runtime orchestration, input action map, state stack, tween/timer, pathfinding, spatial indexing, task scheduler
- `thoth.adapters.*`: framework adapters (`love2d`, `defold`, `solar2d`)

## Runtime quick start

```lua
local runtimeModule = require("thoth.game.runtime")
local love2d = require("thoth.adapters.love2d")

local adapter = love2d.new(love)
local runtime = runtimeModule.new(adapter)

runtime.input:bind("jump", "space")
runtime:registerSystem({
  name = "example",
  update = function(rt, dt)
    if rt.input:pressed("jump") then
      print("jump")
    end
  end
})

local hooks = adapter:registerLifecycle(runtime)

function love.update(dt)
  hooks.update(dt)
end

function love.draw()
  hooks.draw()
end
```

## Migration from v3

Direct `src.*` imports are intentionally removed in v4.

- `require("src.math")` -> `require("thoth.core.math")`
- `require("src.graphs")` -> `require("thoth.core.graphs")`
- `require("src.events")` -> `require("thoth.core.events")`
- `require("src.Love2DInput")` -> `require("thoth.game.input")` + `require("thoth.adapters.love2d")`
- `require("src.Love2DStates")` -> `require("thoth.game.state")` + `require("thoth.game.runtime")`

## Examples

- `examples/love2d/main.lua`
- `examples/defold/main.lua`
- `examples/solar2d/main.lua`

All examples share gameplay logic from `examples/shared/movement_scene.lua`.
