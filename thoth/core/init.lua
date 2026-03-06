local modules = {
    cache = "thoth.core.cache",
    events = "thoth.core.events",
    graphs = "thoth.core.graphs",
    heaps = "thoth.core.heaps",
    links = "thoth.core.links",
    math = "thoth.core.math",
    math2D = "thoth.core.math2D",
    performance = "thoth.core.performance",
    queues = "thoth.core.queues",
    serialize = "thoth.core.serialize",
    stacks = "thoth.core.stacks",
    stringify = "thoth.core.stringify",
    tables = "thoth.core.tables",
    trees = "thoth.core.trees",
    tries = "thoth.core.tries",
    validate = "thoth.core.validate",
}

local core = {}

setmetatable(core, {
    __index = function(_, key)
        local path = modules[key]
        if not path then
            return nil
        end
        local module = require(path)
        rawset(core, key, module)
        return module
    end
})

return core
