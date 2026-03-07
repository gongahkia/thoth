local contract = require("thoth.adapters.contract")

local normalized = contract.capabilities({
    clock = true,
    touch = {
        supported = true,
        maxPoints = 5,
    },
})

assert(normalized.clock.supported == true)
assert(normalized.touch.supported == true)
assert(normalized.touch.maxPoints == 5)
assert(normalized.audio.supported == false)

local missingClock = {
    capabilities = contract.capabilities({
        keyboard = true,
    }),
    isDown = function()
        return false
    end,
}
local ok, err = contract.validate(missingClock)
assert(ok == false)
assert(err == "Adapter must support capability 'clock'")

local incompleteStorage = {
    capabilities = contract.capabilities({
        clock = true,
        storage = true,
    }),
    now = function()
        return 0
    end,
    saveData = function()
        return true
    end,
}
ok, err = contract.validate(incompleteStorage)
assert(ok == false)
assert(err:find("loadData", 1, true) ~= nil)

local incompleteLifecycle = {
    capabilities = contract.capabilities({
        clock = true,
        lifecycle = true,
    }),
    now = function()
        return 0
    end,
}
ok, err = contract.validate(incompleteLifecycle)
assert(ok == false)
assert(err:find("registerLifecycle", 1, true) ~= nil)

assert(contract.supports(incompleteStorage, "storage"))
assert(not contract.supports(incompleteStorage, "audio"))
assert(not contract.supports(incompleteStorage, "missingCapability"))

local supportOk, supportErr = pcall(function()
    contract.assertSupport(incompleteStorage, "audio")
end)
assert(not supportOk)
assert(supportErr:find("audio", 1, true) ~= nil)
