local runtimeModule = require("thoth.game.runtime")
local love2d = require("thoth.adapters.love2d")
local showcase = require("examples.shared.showcase_game")

local adapter = love2d.new(nil)
local runtime = runtimeModule.new(adapter, {fixedDelta = 0.1, maxFrameDelta = 1})
local game = showcase.attach(runtime)

assert(runtime.state:getCurrent().name == "menu", "Showcase should start in the menu state")

adapter.state.keys.space = true
runtime:update(0.1)
adapter.state.keys.space = false
runtime:update(0.1)
assert(runtime.state:getCurrent().name == "play", "Confirm should transition the showcase into play")

local world = game:getWorld()
local startX = world.player.x
adapter.state.keys.right = true
runtime:update(0.1)
adapter.state.keys.right = false
assert(world.player.x >= startX, "Gameplay state should react to axis bindings")

local previousEnemyX, previousEnemyY = world.enemy.x, world.enemy.y
runtime:update(0.1)
assert(world.lastPathDistance ~= nil, "Showcase should run pathfinding during play")
assert(world.enemy.x ~= previousEnemyX or world.enemy.y ~= previousEnemyY, "Enemy should advance along the path toward the player")

adapter.state.keys.tab = true
runtime:update(0.1)
adapter.state.keys.tab = false
assert(world.debug == true, "Debug toggle should work through the shared input context")

adapter.state.keys.escape = true
runtime:update(0.1)
adapter.state.keys.escape = false
assert(runtime.state:getCurrent().name == "pause", "Pause should push a pause state")

adapter.state.keys.space = true
runtime:update(0.1)
adapter.state.keys.space = false
assert(runtime.state:getCurrent().name == "play", "Confirm should pop the pause state")

world = game:getWorld()
local pickup
for _, item in ipairs(world.pickups) do
    if not item.collected then
        pickup = item
        break
    end
end
assert(pickup ~= nil)
world.player.x = pickup.x
world.player.y = pickup.y
runtime:update(0.1)
assert(pickup.collected == true, "Spatial queries should collect pickups when the player overlaps them")

local lines = game:renderLines()
assert(#lines > 3, "Showcase should render a readable board summary")
