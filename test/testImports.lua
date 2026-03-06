local thoth = require("thoth")
assert(type(thoth) == "table", "require('thoth') should return a table")

local graphs = require("thoth.core.graphs")
assert(type(graphs.new) == "function", "thoth.core.graphs should expose .new")

local runtime = require("thoth.game.runtime")
assert(type(runtime.new) == "function", "thoth.game.runtime should expose .new")

local love2d = require("thoth.adapters.love2d")
assert(type(love2d.new) == "function", "thoth.adapters.love2d should expose .new")
