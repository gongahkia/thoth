local modules = {
    animation = "thoth.game.animation",
    camera = "thoth.game.camera",
    collision = "thoth.game.collision",
    frame = "thoth.game.frame",
    input = "thoth.game.input",
    navigation = "thoth.game.navigation",
    pathfinding = "thoth.game.pathfinding",
    tilemap = "thoth.game.tilemap",
    random = "thoth.game.random",
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
