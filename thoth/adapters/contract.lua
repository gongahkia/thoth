local contract = {}

local CAPABILITY_ORDER = {
    "clock",
    "keyboard",
    "mouse",
    "axis",
    "lifecycle",
    "textInput",
    "touch",
    "gamepad",
    "storage",
    "audio",
    "window",
    "debugDraw",
}

local function hasMethod(adapter, methodName)
    return adapter and type(adapter[methodName]) == "function"
end

local CAPABILITY_SPECS = {
    clock = {
        requiredMethods = {"now"},
    },
    keyboard = {
        requiredMethods = {"isDown"},
    },
    mouse = {
        requiredMethods = {"isDown"},
    },
    axis = {
        requiredMethods = {"getAxis"},
    },
    lifecycle = {
        requiredMethods = {"registerLifecycle"},
    },
    textInput = {
        requiredMethods = {},
    },
    touch = {
        requiredMethods = {},
    },
    gamepad = {
        requiredMethods = {},
    },
    storage = {
        requiredMethods = {"saveData", "loadData"},
    },
    audio = {
        requiredMethods = {"playAudio", "stopAudio"},
    },
    window = {
        requiredMethods = {"getWindowSize"},
    },
    debugDraw = {
        requiredMethods = {"debugDraw"},
    },
}

local function normalizeCapabilityValue(value)
    if type(value) == "table" then
        local normalized = {}
        for key, item in pairs(value) do
            normalized[key] = item
        end
        if normalized.supported == nil then
            normalized.supported = true
        end
        normalized.supported = normalized.supported == true
        return normalized
    end

    return {
        supported = value == true,
    }
end

function contract.capabilities(overrides)
    local capabilities = {}
    overrides = overrides or {}

    for _, capabilityName in ipairs(CAPABILITY_ORDER) do
        capabilities[capabilityName] = normalizeCapabilityValue(overrides[capabilityName])
    end

    return capabilities
end

function contract.describe(adapter)
    local rawCapabilities = {}
    if type(adapter) == "table" and type(adapter.capabilities) == "table" then
        rawCapabilities = adapter.capabilities
    end
    return contract.capabilities(rawCapabilities)
end

function contract.supports(adapter, capabilityName)
    local capabilities = contract.describe(adapter)
    return capabilities[capabilityName] and capabilities[capabilityName].supported == true or false
end

function contract.assertSupport(adapter, capabilityName)
    if not contract.supports(adapter, capabilityName) then
        error("Adapter does not support capability '" .. tostring(capabilityName) .. "'")
    end
end

function contract.validate(adapter)
    if type(adapter) ~= "table" then
        return false, "Adapter must be a table"
    end

    local capabilities = contract.describe(adapter)
    for _, capabilityName in ipairs(CAPABILITY_ORDER) do
        local capability = capabilities[capabilityName]
        if type(capability) ~= "table" or type(capability.supported) ~= "boolean" then
            return false, "Adapter capability '" .. capabilityName .. "' must describe a supported boolean"
        end

        if capability.supported then
            for _, methodName in ipairs(CAPABILITY_SPECS[capabilityName].requiredMethods) do
                if not hasMethod(adapter, methodName) then
                    return false, "Adapter capability '" .. capabilityName .. "' requires method '" .. methodName .. "'"
                end
            end
        end
    end

    if not capabilities.clock.supported then
        return false, "Adapter must support capability 'clock'"
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
        capabilities = contract.capabilities({
            clock = true,
            keyboard = true,
            mouse = true,
            axis = true,
            touch = true,
            gamepad = true,
        })
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

    function adapter:getWindowSize()
        return nil, nil
    end

    return adapter
end

return contract
