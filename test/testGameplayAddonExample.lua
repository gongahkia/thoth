local showcase = require("examples.shared.gameplay_addons")

local result = showcase.run()

assert(result.energy == 4, "Shared gameplay example should apply both queued recharge commands")
assert(result.dashReady, "Shared gameplay example should advance cooldowns")
assert(result.focusActive, "Shared gameplay example should keep active statuses that have not expired yet")
assert(result.queuedCommands == 0, "Shared gameplay example should drain its queued commands")
