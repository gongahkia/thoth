local modules = {
    cache = "thoth.core.cache",
    config = "thoth.core.config",
    datetime = "thoth.core.datetime",
    deques = "thoth.core.deques",
    events = "thoth.core.events",
    graphs = "thoth.core.graphs",
    heaps = "thoth.core.heaps",
    links = "thoth.core.links",
    orderedmaps = "thoth.core.orderedmaps",
    math = "thoth.core.math",
    math2D = "thoth.core.math2D",
    logging = "thoth.core.logging",
    performance = "thoth.core.performance",
    path = "thoth.core.path",
    queues = "thoth.core.queues",
    ringbuffers = "thoth.core.ringbuffers",
    serialize = "thoth.core.serialize",
    sets = "thoth.core.sets",
    stacks = "thoth.core.stacks",
    stringify = "thoth.core.stringify",
    tables = "thoth.core.tables",
    trees = "thoth.core.trees",
    tries = "thoth.core.tries",
    unionfind = "thoth.core.unionfind",
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
