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

local safeLoaded, safeErr = serialize.loadLuaSafe(file)
assert(safeLoaded and safeLoaded.v == 42, safeErr)

local unsafeFile = "test_tmp_serialize_unsafe.lua"
local f = io.open(unsafeFile, "w")
assert(f)
f:write("return { has_os = os ~= nil, has_io = io ~= nil, token = token }")
f:close()

local sandboxed = assert(serialize.loadLuaSafe(unsafeFile, {token = "ok"}))
assert(sandboxed.has_os == false)
assert(sandboxed.has_io == false)
assert(sandboxed.token == "ok")

os.remove(unsafeFile)
os.remove(file)
