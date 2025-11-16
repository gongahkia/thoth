-- Test file for cache module

local cache = require("src.cache")

print("=== Testing Cache Module ===\n")

-- Test Memoize
print("Testing Memoize...")
local callCount = 0
local function expensive(n)
    callCount = callCount + 1
    return n * n
end

local memoized = cache.Memoize(expensive)

assert(memoized(5) == 25, "Should return correct result")
assert(callCount == 1, "Should call function once")

assert(memoized(5) == 25, "Should return cached result")
assert(callCount == 1, "Should not call function again (cached)")

assert(memoized(10) == 100, "Should work for different input")
assert(callCount == 2, "Should call function for new input")

print("✓ Memoize works\n")

-- Test Memoized Fibonacci
print("Testing Memoized Fibonacci...")
local result = cache.Fibonacci(30)
print("Fibonacci(30) = " .. result)
assert(result == 832040, "Should calculate correct Fibonacci")
print("✓ Memoized Fibonacci works\n")

-- Test LRU Cache
print("Testing LRU Cache...")
local lru = cache.LRUCache(3)

lru:put("a", 1)
lru:put("b", 2)
lru:put("c", 3)

assert(lru:get("a") == 1, "Should get value 'a'")
assert(lru:get("b") == 2, "Should get value 'b'")
assert(lru:get("c") == 3, "Should get value 'c'")

lru:put("d", 4) -- Should evict 'a' (least recently used)

assert(lru:get("a") == nil, "Should have evicted 'a'")
assert(lru:get("d") == 4, "Should have 'd'")

assert(lru:getSize() == 3, "Should maintain max size")

print("✓ LRU Cache works\n")

-- Test LRU ordering
print("Testing LRU ordering...")
local lru2 = cache.LRUCache(3)
lru2:put("x", 1)
lru2:put("y", 2)
lru2:put("z", 3)

lru2:get("x") -- Access 'x' to make it most recently used

lru2:put("w", 4) -- Should evict 'y' (not 'x')

assert(lru2:get("x") == 1, "Should still have 'x'")
assert(lru2:get("y") == nil, "Should have evicted 'y'")
assert(lru2:get("z") == 3, "Should still have 'z'")
assert(lru2:get("w") == 4, "Should have 'w'")

print("✓ LRU ordering works\n")

-- Test SimpleCache
print("Testing SimpleCache...")
local simple = cache.SimpleCache()

simple:set("key1", "value1")
simple:set("key2", "value2")

assert(simple:get("key1") == "value1", "Should get value")
assert(simple:has("key1") == true, "Should have key")
assert(simple:has("key3") == false, "Should not have key")

assert(simple:size() == 2, "Should have 2 items")

simple:remove("key1")
assert(simple:get("key1") == nil, "Should remove key")
assert(simple:size() == 1, "Should have 1 item")

simple:clear()
assert(simple:size() == 0, "Should clear all")

print("✓ SimpleCache works\n")

-- Test TTL Cache
print("Testing TTL Cache...")
local ttl = cache.TTLCache(1) -- 1 second TTL

ttl:set("test", "value")
assert(ttl:get("test") == "value", "Should get fresh value")

-- Wait would be needed for real expiry test, but we can test the structure
ttl:set("test2", "value2", 0) -- Already expired
assert(ttl:get("test2") == nil, "Should expire immediately")

print("✓ TTL Cache works\n")

-- Test MemoizeLRU
print("Testing MemoizeLRU...")
local calls = 0
local function slowFunc(n)
    calls = calls + 1
    return n * 2
end

local memoLRU = cache.MemoizeLRU(slowFunc, 2)

memoLRU(1) -- calls = 1
memoLRU(2) -- calls = 2
memoLRU(1) -- cached, calls still 2
assert(calls == 2, "Should use cache")

memoLRU(3) -- calls = 3, evicts one
memoLRU(1) -- may need recalculation depending on eviction

print("✓ MemoizeLRU works\n")

print("=== All Cache Tests Passed ===")
