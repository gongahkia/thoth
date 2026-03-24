local resources = require("thoth.addons.gameplay.resources")

local manager = resources.new({
    health = {current = 8, max = 10},
    mana = {current = 3, max = 5},
})

assert(manager:current("health") == 8)
assert(manager:max("health") == 10)

assert(manager:add("health", 10) == 10, "Resource add should clamp to max")
assert(manager:add("mana", -10) == 0, "Resource add should clamp at zero")

local spent, remaining = manager:spend("health", 4)
assert(spent == true and remaining == 6, "Spend should succeed when enough resource exists")

local failed, unchanged = manager:spend("mana", 2)
assert(failed == false and unchanged == 0, "Spend should fail without changing the pool when resource is insufficient")

local current, maximum = manager:set("stamina", 15, 12)
assert(current == 12 and maximum == 12, "Set should create pools and clamp current to max")

local snapshot = manager:snapshot()
manager:add("stamina", -6)
manager:restore(snapshot)

assert(manager:current("stamina") == 12, "Restore should replace the current pool state")
