local cache = require("thoth.core.cache")

local calls = 0
local memo = cache.Memoize(function(x)
    calls = calls + 1
    return x * x
end)

assert(memo(3) == 9)
assert(memo(3) == 9)
assert(calls == 1)

local lru = cache.LRUCache(2)
lru:put("a", 1)
lru:put("b", 2)
assert(lru:get("a") == 1)
lru:put("c", 3)
assert(lru:get("b") == nil)

local ttl = cache.TTLCache(5)
ttl:set("k", "v")
assert(ttl:get("k") == "v")
ttl.data["k"].expiry = os.time() - 1
assert(ttl:get("k") == nil)
