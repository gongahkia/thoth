local cooldowns = require("thoth.addons.gameplay.cooldowns")

local manager = cooldowns.new()

assert(manager:ready("dash"), "Unknown cooldowns should be ready")
assert(manager:start("dash", 1.5) == 1.5)
assert(not manager:ready("dash"))
assert(manager:remaining("dash") == 1.5)

manager:update(0.5)
assert(math.abs(manager:remaining("dash") - 1.0) < 1e-9, "Cooldowns should tick down during update")

local snapshot = manager:snapshot()
manager:start("blink", 0.25)
assert(manager:clear("blink"), "Clear should remove an active cooldown")
assert(manager:ready("blink"))

manager:update(1.0)
assert(manager:ready("dash"), "Cooldown should expire once its timer reaches zero")

manager:restore(snapshot)
assert(math.abs(manager:remaining("dash") - 1.0) < 1e-9, "Restore should replace active cooldown state")
