local status = require("thoth.addons.gameplay.status")

local manager = status.new()

local poison = manager:apply("poison", 3, {
    tags = {"damage", "debuff"},
    stacks = 2,
    maxStacks = 5,
})
assert(poison.stacks == 2)
assert(manager:has("poison"))
assert(manager:stacks("poison") == 2)

manager:apply("poison", 5, {
    tags = {"damage", "debuff"},
    stacks = 4,
    maxStacks = 5,
})

local current = manager:get("poison")
assert(current.remaining == 5, "Applying an existing status should refresh its duration")
assert(current.stacks == 5, "Status stacks should clamp to maxStacks")

local matches = manager:findByTag("damage")
assert(#matches == 1 and matches[1] == "poison", "Tag lookup should return matching status names")

local snapshot = manager:snapshot()
manager:update(5)
assert(not manager:has("poison"), "Status should expire when its timer reaches zero")

manager:restore(snapshot)
assert(manager:has("poison"), "Restore should restore active statuses")
assert(manager:clear("poison"), "Clear should remove an active status")
