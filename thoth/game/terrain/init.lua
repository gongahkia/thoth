local serialize = require("thoth.core.serialize")
local registry = require("thoth.game.terrain.registry")

local lazy = {
    evolution = function()
        return require("thoth.game.terrain.evolution")
    end,
    export = function()
        return require("thoth.game.terrain.export")
    end,
    grid = function()
        return require("thoth.game.terrain.grid")
    end,
    palette = function()
        return require("thoth.game.terrain.palette")
    end,
    simulation = function()
        return require("thoth.game.terrain.simulation")
    end,
}

local terrain = {}

function terrain.list()
    return registry.list()
end

function terrain.describe(id)
    return registry.describe(id)
end

function terrain.generate(id, width, height, options)
    local map, metadata = registry.generate(id, width, height, options)
    return map, serialize.deepCopy(metadata)
end

setmetatable(terrain, {
    __index = function(_, key)
        local getter = lazy[key]
        if getter then
            local module = getter()
            rawset(terrain, key, module)
            return module
        end
        return nil
    end,
})

return terrain
