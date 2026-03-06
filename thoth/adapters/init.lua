local modules = {
    contract = "thoth.adapters.contract",
    love2d = "thoth.adapters.love2d",
    defold = "thoth.adapters.defold",
    solar2d = "thoth.adapters.solar2d",
}

local adapters = {}

setmetatable(adapters, {
    __index = function(_, key)
        local path = modules[key]
        if not path then
            return nil
        end
        local module = require(path)
        rawset(adapters, key, module)
        return module
    end
})

return adapters
