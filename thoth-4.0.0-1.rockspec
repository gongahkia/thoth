package = "thoth"
version = "4.0.0-1"
source = {
   url = "git+https://github.com/gongahkia/thoth.git",
   tag = "4.0.0"
}
description = {
   summary = "Functional Lua pocket knife with cross-framework game runtime adapters",
   homepage = "https://github.com/gongahkia/thoth",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["thoth"] = "thoth.lua",
      ["init"] = "init.lua",
      ["thoth.core"] = "thoth/core/init.lua",
      ["thoth.core.cache"] = "thoth/core/cache.lua",
      ["thoth.core.events"] = "thoth/core/events.lua",
      ["thoth.core.graphs"] = "thoth/core/graphs.lua",
      ["thoth.core.heaps"] = "thoth/core/heaps.lua",
      ["thoth.core.links"] = "thoth/core/links.lua",
      ["thoth.core.math"] = "thoth/core/math.lua",
      ["thoth.core.math2D"] = "thoth/core/math2D.lua",
      ["thoth.core.performance"] = "thoth/core/performance.lua",
      ["thoth.core.queues"] = "thoth/core/queues.lua",
      ["thoth.core.serialize"] = "thoth/core/serialize.lua",
      ["thoth.core.stacks"] = "thoth/core/stacks.lua",
      ["thoth.core.stringify"] = "thoth/core/stringify.lua",
      ["thoth.core.tables"] = "thoth/core/tables.lua",
      ["thoth.core.trees"] = "thoth/core/trees.lua",
      ["thoth.core.tries"] = "thoth/core/tries.lua",
      ["thoth.core.validate"] = "thoth/core/validate.lua",
      ["thoth.game"] = "thoth/game/init.lua",
      ["thoth.game.frame"] = "thoth/game/frame.lua",
      ["thoth.game.input"] = "thoth/game/input.lua",
      ["thoth.game.pathfinding"] = "thoth/game/pathfinding.lua",
      ["thoth.game.runtime"] = "thoth/game/runtime.lua",
      ["thoth.game.spatial"] = "thoth/game/spatial.lua",
      ["thoth.game.state"] = "thoth/game/state.lua",
      ["thoth.game.tasks"] = "thoth/game/tasks.lua",
      ["thoth.game.tween"] = "thoth/game/tween.lua",
      ["thoth.adapters"] = "thoth/adapters/init.lua",
      ["thoth.adapters.contract"] = "thoth/adapters/contract.lua",
      ["thoth.adapters.love2d"] = "thoth/adapters/love2d.lua",
      ["thoth.adapters.defold"] = "thoth/adapters/defold.lua",
      ["thoth.adapters.solar2d"] = "thoth/adapters/solar2d.lua"
   }
}
