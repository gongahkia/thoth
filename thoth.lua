local function lazyRequire(path)
    return function()
        return require(path)
    end
end

local lazy = {
    core = lazyRequire("thoth.core"),
    game = lazyRequire("thoth.game"),
    adapters = lazyRequire("thoth.adapters"),
}

local thoth = {}

setmetatable(thoth, {
    __index = function(_, key)
        local getter = lazy[key]
        if getter then
            local module = getter()
            rawset(thoth, key, module)
            return module
        end
        return nil
    end
})

return thoth
