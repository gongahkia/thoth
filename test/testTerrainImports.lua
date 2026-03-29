local thoth = require("thoth")
local terrain = require("thoth.game.terrain")
local terrainAddon = require("thoth.addons.terrain")

assert(type(thoth.game.terrain) == "table", "Thoth should expose the terrain namespace")
assert(type(thoth.addons.terrain) == "table", "Thoth should expose the terrain addon")
assert(type(terrain.generate) == "function", "Terrain facade should expose generate")
assert(type(terrain.describe) == "function", "Terrain facade should expose describe")
assert(type(terrainAddon.install) == "function", "Terrain addon should expose install")

local list = terrain.list()
assert(#list == 20, "Terrain registry should expose all transplanted generators")
assert(list[1] == "apocalypse", "Terrain generator list should be stable and sorted")
assert(list[#list] == "volcano", "Terrain generator list should include volcano")

local forest = terrain.describe("forest")
assert(forest.name == "Dense Forest", "Descriptions should include human-readable metadata")
assert(type(forest.params) == "table" and #forest.params >= 3, "Descriptions should expose parameter definitions")

local manifest = assert(io.open("thoth-4.0.0-1.rockspec", "r"))
local manifestText = manifest:read("*a")
manifest:close()

assert(manifestText:find("%[\"thoth%.game%.terrain\"%]"), "Rockspec should export thoth.game.terrain")
assert(manifestText:find("%[\"thoth%.game%.terrain%.simulation\"%]"), "Rockspec should export terrain simulation")
assert(manifestText:find("%[\"thoth%.addons%.terrain\"%]"), "Rockspec should export thoth.addons.terrain")
