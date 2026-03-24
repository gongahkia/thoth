local modules = {
    gameplay = "thoth.addons.gameplay",
}

local addons = {}

setmetatable(addons, {
    __index = function(_, key)
        local path = modules[key]
        if not path then
            return nil
        end
        local module = require(path)
        rawset(addons, key, module)
        return module
    end
})

return addons
