local s = require("thoth.core.stringify")
assert(s.Lstrip("###watermelon", "#") == "watermelon")

local thoth = require("thoth")
assert(type(thoth.core) == "table")
assert(type(thoth.game) == "table")
assert(type(thoth.adapters) == "table")

local runtime = thoth.game.runtime.new(thoth.adapters.contract.nullAdapter())
runtime.input:bind("jump", "space")
runtime:update(1 / 60)
assert(runtime.input:down("jump") == false)
