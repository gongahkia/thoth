local logging = require("thoth.core.logging")
local path = require("thoth.core.path")
local config = require("thoth.core.config")
local datetime = require("thoth.core.datetime")

local entries = {}
local logger = logging.new({
    level = "debug",
    sink = function(entry)
        entries[#entries + 1] = entry
    end,
})
logger:debug("debug message", {id = 1})
logger:error("error message")
assert(#entries == 2)
assert(entries[1].fields.id == 1)

assert(path.join("foo", "bar", "baz.txt") == "foo/bar/baz.txt")
assert(path.normalize("foo/./bar/../baz") == "foo/baz")
assert(path.basename("foo/bar/baz.txt") == "baz.txt")
assert(path.dirname("foo/bar/baz.txt") == "foo/bar")
assert(path.extname("foo/bar/baz.txt") == ".txt")

local merged = config.merge({host = "localhost", port = 80}, {port = 8080})
assert(merged.host == "localhost" and merged.port == 8080)
assert(config.getenv("THOTH_TEST_ENV", "fallback", {THOTH_TEST_ENV = "present"}) == "present")

local file = "test_tmp_env.env"
local handle = assert(io.open(file, "w"))
handle:write("A=1\n# comment\nB=two\n")
handle:close()
local env = assert(config.loadEnvFile(file))
assert(env.A == "1" and env.B == "two")
os.remove(file)

local timestamp = datetime.fromTable({year = 2024, month = 1, day = 2, hour = 3, min = 4, sec = 5})
assert(type(timestamp) == "number")
assert(datetime.iso8601(timestamp):match("2024%-%d%d%-%d%dT"))
local parts = datetime.toTable(timestamp)
assert(parts.year == 2024 and parts.month == 1)
assert(datetime.addSeconds(timestamp, 60) == timestamp + 60)
