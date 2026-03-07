local pathfinding = require("thoth.game.pathfinding")
local spatial = require("thoth.game.spatial")

local showcase = {}

local GRID = {
    {1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
    {1, 0, 0, 1, 1, 1, 0, 0, 1, 1},
    {1, 1, 1, 1, 0, 1, 1, 1, 1, 1},
    {1, 1, 0, 1, 0, 1, 0, 1, 0, 1},
    {1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
    {1, 0, 1, 0, 1, 0, 1, 0, 1, 1},
    {1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
}

local PICKUPS = {
    {id = "relic-a", x = 3, y = 3},
    {id = "relic-b", x = 8, y = 5},
    {id = "relic-c", x = 10, y = 2},
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for key, item in pairs(value) do
        out[deepCopy(key)] = deepCopy(item)
    end
    return out
end

local function makeWorld()
    return {
        grid = deepCopy(GRID),
        player = {x = 1, y = 1},
        enemy = {x = 10, y = 7},
        pickups = deepCopy(PICKUPS),
        collected = 0,
        totalPickups = #PICKUPS,
        tick = 0,
        lastPathDistance = 0,
        debug = false,
        message = "Press confirm to start.",
        outcome = nil,
        spatial = spatial.newSpatialHash(1),
    }
end

local function currentState(runtime)
    local state = runtime.state:getCurrent()
    return state and state.name or "none"
end

local function isWalkable(world, x, y)
    return world.grid[y] and world.grid[y][x] == 1
end

local function moveEntity(world, entity, dx, dy)
    if dx ~= 0 then
        local nextX = entity.x + dx
        if isWalkable(world, nextX, entity.y) then
            entity.x = nextX
        end
        return
    end

    if dy ~= 0 then
        local nextY = entity.y + dy
        if isWalkable(world, entity.x, nextY) then
            entity.y = nextY
        end
    end
end

local function rebuildSpatial(world)
    world.spatial:clear()
    world.spatial:insert("enemy", world.enemy.x - 1, world.enemy.y - 1, 1, 1, {
        kind = "enemy",
    })

    for _, pickup in ipairs(world.pickups) do
        if not pickup.collected then
            world.spatial:insert(pickup.id, pickup.x - 1, pickup.y - 1, 1, 1, {
                kind = "pickup",
                pickup = pickup,
            })
        end
    end
end

local function collectAtPlayer(world)
    rebuildSpatial(world)
    local matches = world.spatial:queryRange(world.player.x - 1, world.player.y - 1, 1, 1)
    local touchedEnemy = false

    for _, match in ipairs(matches) do
        if match.data.kind == "pickup" and not match.data.pickup.collected then
            match.data.pickup.collected = true
            world.collected = world.collected + 1
        elseif match.data.kind == "enemy" then
            touchedEnemy = true
        end
    end

    return touchedEnemy
end

local function updateEnemy(world)
    local path, distance = pathfinding.findPathGrid(world.grid, {
        x = world.enemy.x,
        y = world.enemy.y,
    }, {
        x = world.player.x,
        y = world.player.y,
    })

    world.lastPathDistance = distance
    if path and #path > 1 then
        world.enemy.x = path[2].x
        world.enemy.y = path[2].y
    end
end

local function resetWorld(runtime)
    runtime.context.world = makeWorld()
    return runtime.context.world
end

function showcase.attach(runtime)
    local input = runtime.input
    local world = resetWorld(runtime)

    input:setContext("menu")
    input:bind("confirm", {keys = {"space", "return"}})
    input:bind("pause", "escape")
    input:bind("toggle_debug", "tab")
    input:pushContext("gameplay")
    input:bind("move_x", {axis = {positive = "right", negative = "left"}})
    input:bind("move_y", {axis = {positive = "down", negative = "up"}})
    input:bind("pause", "escape")
    input:bind("toggle_debug", "tab")
    input:setContext("menu")

    runtime.state:add("menu", {
        name = "menu",
        enter = function(self)
            input:setContext("menu")
            runtime.context.world.message = "Press confirm to start."
            runtime.context.world.outcome = nil
        end,
    })

    runtime.state:add("play", {
        name = "play",
        enter = function(self, previous)
            if not previous or previous.name == "menu" or previous.name == "gameover" then
                resetWorld(runtime)
            end
            input:setContext("gameplay")
            runtime.context.world.message = "Collect every relic before the seeker reaches you."
        end,
    })

    runtime.state:add("pause", {
        name = "pause",
        enter = function(self)
            input:pushContext("menu")
            runtime.context.world.message = "Paused. Confirm to resume."
        end,
        exit = function(self, nextState)
            if nextState and nextState.name == "play" then
                input:popContext()
                runtime.context.world.message = "Collect every relic before the seeker reaches you."
            end
        end,
    })

    runtime.state:add("gameover", {
        name = "gameover",
        enter = function(self, previous, outcome)
            input:setContext("menu")
            runtime.context.world.outcome = outcome
            if outcome == "win" then
                runtime.context.world.message = "You escaped with every relic. Confirm to return to menu."
            else
                runtime.context.world.message = "The seeker caught you. Confirm to return to menu."
            end
        end,
    })

    runtime.state:switch("menu")

    runtime:registerSystem({
        name = "showcase_controls",
        priority = 1,
        update = function(rt)
            local stateName = currentState(rt)
            local liveWorld = rt.context.world

            if rt.input:pressed("toggle_debug") then
                liveWorld.debug = not liveWorld.debug
            end

            if stateName == "menu" and rt.input:pressed("confirm") then
                rt.state:switch("play")
            elseif stateName == "play" and rt.input:pressed("pause") then
                rt.state:push("pause")
            elseif stateName == "pause" and (rt.input:pressed("confirm") or rt.input:pressed("pause")) then
                rt.state:pop()
            elseif stateName == "gameover" and rt.input:pressed("confirm") then
                rt.state:switch("menu")
            end
        end,
    })

    runtime:registerSystem({
        name = "showcase_gameplay",
        priority = 10,
        fixedUpdate = function(rt)
            if currentState(rt) ~= "play" then
                return
            end

            local liveWorld = rt.context.world
            liveWorld.tick = liveWorld.tick + 1

            local dx = rt.input:axis("move_x")
            local dy = rt.input:axis("move_y")
            if math.abs(dx) >= math.abs(dy) and dx ~= 0 then
                moveEntity(liveWorld, liveWorld.player, dx > 0 and 1 or -1, 0)
            elseif dy ~= 0 then
                moveEntity(liveWorld, liveWorld.player, 0, dy > 0 and 1 or -1)
            end

            updateEnemy(liveWorld)
            local touchedEnemy = collectAtPlayer(liveWorld)
            if touchedEnemy or (liveWorld.enemy.x == liveWorld.player.x and liveWorld.enemy.y == liveWorld.player.y) then
                rt.state:switch("gameover", "lose")
                return
            end

            if liveWorld.collected >= liveWorld.totalPickups then
                rt.state:switch("gameover", "win")
            end
        end,
    })

    local game = {}

    function game:getWorld()
        return runtime.context.world
    end

    function game:renderLines()
        local liveWorld = runtime.context.world
        local lines = {
            string.format("state=%s collected=%d/%d path=%.1f", currentState(runtime), liveWorld.collected, liveWorld.totalPickups, liveWorld.lastPathDistance or 0),
            liveWorld.message,
        }

        for y, row in ipairs(liveWorld.grid) do
            local chars = {}
            for x, cell in ipairs(row) do
                local char = cell == 1 and "." or "#"
                for _, pickup in ipairs(liveWorld.pickups) do
                    if not pickup.collected and pickup.x == x and pickup.y == y then
                        char = "*"
                    end
                end
                if liveWorld.enemy.x == x and liveWorld.enemy.y == y then
                    char = "S"
                end
                if liveWorld.player.x == x and liveWorld.player.y == y then
                    char = "P"
                end
                chars[#chars + 1] = char
            end
            lines[#lines + 1] = table.concat(chars)
        end

        if liveWorld.debug then
            lines[#lines + 1] = string.format("debug tick=%d enemy=(%d,%d) player=(%d,%d)", liveWorld.tick, liveWorld.enemy.x, liveWorld.enemy.y, liveWorld.player.x, liveWorld.player.y)
        end

        return lines
    end

    return game
end

return showcase
