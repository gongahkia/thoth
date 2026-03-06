local modules = {
    frame = "thoth.game.frame",
    input = "thoth.game.input",
    pathfinding = "thoth.game.pathfinding",
    runtime = "thoth.game.runtime",
    spatial = "thoth.game.spatial",
    state = "thoth.game.state",
    tasks = "thoth.game.tasks",
    tween = "thoth.game.tween",
}

local game = {}

setmetatable(game, {
    __index = function(_, key)
        local path = modules[key]
        if not path then
            return nil
        end
        local module = require(path)
        rawset(game, key, module)
        return module
    end
})

return game
