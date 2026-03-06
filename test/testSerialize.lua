local serialize = require("thoth.core.serialize")

local original = {a = 1, nested = {b = 2}}
local copy = serialize.deepCopy(original)
copy.nested.b = 99
assert(original.nested.b == 2)

local json = serialize.toJSON({x = 1, arr = {1, 2, 3}})
local decoded = serialize.fromJSON(json)
assert(decoded.x == 1)
assert(decoded.arr[3] == 3)

local luaCode = serialize.toLua({x = 1}, nil)
assert(luaCode:find("x"))

local file = "test_tmp_serialize.lua"
local ok, err = serialize.saveLua(file, {v = 42}, "data")
assert(ok, err)
local loaded, loadErr = serialize.loadLua(file)
assert(loaded and loaded.v == 42, loadErr)
os.remove(file)
