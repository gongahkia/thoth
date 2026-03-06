local contract = {}

local REQUIRED_METHODS = {
    "now",
    "isDown",
    "getAxis",
}

local function hasMethod(adapter, methodName)
    return adapter and type(adapter[methodName]) == "function"
end

function contract.validate(adapter)
    if type(adapter) ~= "table" then
        return false, "Adapter must be a table"
    end

    for _, methodName in ipairs(REQUIRED_METHODS) do
        if not hasMethod(adapter, methodName) then
            return false, "Adapter missing required method '" .. methodName .. "'"
        end
    end

    return true
end

function contract.assertValid(adapter)
    local ok, err = contract.validate(adapter)
    if not ok then
        error("Invalid adapter: " .. err)
    end
end

function contract.nullAdapter()
    local adapter = {
        capabilities = {
            lifecycle = false,
            rendering = false,
            input = true
        }
    }

    function adapter:now()
        return os.clock()
    end

    function adapter:delta()
        return nil
    end

    function adapter:isDown(_)
        return false
    end

    function adapter:getAxis(_)
        return 0
    end

    function adapter:registerLifecycle(_runtime, _options)
        return nil
    end

    return adapter
end

return contract
