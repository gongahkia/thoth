-- =============================================
-- Cache Module
-- Memoization and LRU cache implementations
-- =============================================

local cache = {}

-- =============================================
-- Memoization
-- =============================================

---Memoize a function (cache results based on arguments)
---@param func function Function to memoize
---@param keyGenerator function|nil Optional custom key generator
---@return function memoized Memoized version of the function
function cache.Memoize(func, keyGenerator)
    local cache = {}

    -- Default key generator: serialize arguments
    keyGenerator = keyGenerator or function(...)
        local args = {...}
        local key = ""
        for i, v in ipairs(args) do
            key = key .. tostring(v) .. "|"
        end
        return key
    end

    return function(...)
        local key = keyGenerator(...)

        if cache[key] ~= nil then
            return cache[key]
        end

        local result = func(...)
        cache[key] = result
        return result
    end
end

---Memoize a function with a maximum cache size (LRU eviction)
---@param func function Function to memoize
---@param maxSize number Maximum cache size
---@param keyGenerator function|nil Optional custom key generator
---@return function memoized Memoized function with LRU eviction
function cache.MemoizeLRU(func, maxSize, keyGenerator)
    maxSize = maxSize or 100
    local lruCache = cache.LRUCache(maxSize)

    -- Default key generator
    keyGenerator = keyGenerator or function(...)
        local args = {...}
        local key = ""
        for i, v in ipairs(args) do
            key = key .. tostring(v) .. "|"
        end
        return key
    end

    return function(...)
        local key = keyGenerator(...)

        local cached = lruCache:get(key)
        if cached ~= nil then
            return cached
        end

        local result = func(...)
        lruCache:put(key, result)
        return result
    end
end

-- =============================================
-- LRU Cache Implementation
-- =============================================

---@class LRUNode
---@field key any
---@field value any
---@field prev LRUNode|nil
---@field next LRUNode|nil
local LRUNode = {}
LRUNode.__index = LRUNode

---Create a new LRU node
---@param key any
---@param value any
---@return LRUNode
function LRUNode.new(key, value)
    local self = setmetatable({}, LRUNode)
    self.key = key
    self.value = value
    self.prev = nil
    self.next = nil
    return self
end

---@class LRUCache
---@field capacity number
---@field size number
---@field map table
---@field head LRUNode
---@field tail LRUNode
local LRUCache = {}
LRUCache.__index = LRUCache

---Create a new LRU cache
---@param capacity number Maximum number of items
---@return LRUCache
function LRUCache.new(capacity)
    assert(capacity and capacity > 0, "LRUCache capacity must be greater than 0")
    local self = setmetatable({}, LRUCache)
    self.capacity = capacity or 100
    self.size = 0
    self.map = {}

    -- Dummy head and tail nodes
    self.head = LRUNode.new(nil, nil)
    self.tail = LRUNode.new(nil, nil)
    self.head.next = self.tail
    self.tail.prev = self.head

    return self
end

---Remove a node from the linked list
---@param node LRUNode
function LRUCache:removeNode(node)
    local prev = node.prev
    local next = node.next
    prev.next = next
    next.prev = prev
end

---Add a node right after the head (most recently used position)
---@param node LRUNode
function LRUCache:addToHead(node)
    node.prev = self.head
    node.next = self.head.next
    self.head.next.prev = node
    self.head.next = node
end

---Move a node to the head (mark as recently used)
---@param node LRUNode
function LRUCache:moveToHead(node)
    self:removeNode(node)
    self:addToHead(node)
end

---Remove the least recently used node (tail)
---@return LRUNode removed
function LRUCache:removeTail()
    local node = self.tail.prev
    self:removeNode(node)
    return node
end

---Get a value from the cache
---@param key any
---@return any|nil value Value or nil if not found
function LRUCache:get(key)
    local node = self.map[key]

    if not node then
        return nil
    end

    -- Move to head (mark as recently used)
    self:moveToHead(node)

    return node.value
end

---Put a key-value pair into the cache
---@param key any
---@param value any
function LRUCache:put(key, value)
    local node = self.map[key]

    if node then
        -- Update existing node
        node.value = value
        self:moveToHead(node)
    else
        -- Create new node
        local newNode = LRUNode.new(key, value)
        self.map[key] = newNode
        self:addToHead(newNode)
        self.size = self.size + 1

        -- Evict if over capacity
        if self.size > self.capacity then
            local removed = self:removeTail()
            self.map[removed.key] = nil
            self.size = self.size - 1
        end
    end
end

---Check if key exists in cache
---@param key any
---@return boolean exists
function LRUCache:has(key)
    return self.map[key] ~= nil
end

---Remove a key from the cache
---@param key any
function LRUCache:remove(key)
    local node = self.map[key]

    if node then
        self:removeNode(node)
        self.map[key] = nil
        self.size = self.size - 1
    end
end

---Clear the entire cache
function LRUCache:clear()
    self.map = {}
    self.size = 0
    self.head.next = self.tail
    self.tail.prev = self.head
end

---Get current cache size
---@return number size
function LRUCache:getSize()
    return self.size
end

---Get cache capacity
---@return number capacity
function LRUCache:getCapacity()
    return self.capacity
end

---Get all keys in the cache (most to least recently used)
---@return table keys Array of keys
function LRUCache:keys()
    local keys = {}
    local node = self.head.next

    while node ~= self.tail do
        table.insert(keys, node.key)
        node = node.next
    end

    return keys
end

---Factory function for LRU cache
---@param capacity number Maximum items
---@return LRUCache
function cache.LRUCache(capacity)
    return LRUCache.new(capacity)
end

-- =============================================
-- Simple Cache (unlimited size)
-- =============================================

---@class SimpleCache
---@field data table
local SimpleCache = {}
SimpleCache.__index = SimpleCache

---Create a new simple cache
---@return SimpleCache
function SimpleCache.new()
    local self = setmetatable({}, SimpleCache)
    self.data = {}
    return self
end

---Get a value
---@param key any
---@return any|nil value
function SimpleCache:get(key)
    return self.data[key]
end

---Set a value
---@param key any
---@param value any
function SimpleCache:set(key, value)
    self.data[key] = value
end

---Check if key exists
---@param key any
---@return boolean exists
function SimpleCache:has(key)
    return self.data[key] ~= nil
end

---Remove a key
---@param key any
function SimpleCache:remove(key)
    self.data[key] = nil
end

---Clear all data
function SimpleCache:clear()
    self.data = {}
end

---Get all keys
---@return table keys
function SimpleCache:keys()
    local keys = {}
    for k in pairs(self.data) do
        table.insert(keys, k)
    end
    return keys
end

---Get cache size
---@return number size
function SimpleCache:size()
    local count = 0
    for _ in pairs(self.data) do
        count = count + 1
    end
    return count
end

---Factory function for simple cache
---@return SimpleCache
function cache.SimpleCache()
    return SimpleCache.new()
end

-- =============================================
-- TTL Cache (Time-To-Live)
-- =============================================

---@class TTLCache
---@field data table
---@field ttl number
local TTLCache = {}
TTLCache.__index = TTLCache

---Create a new TTL cache
---@param ttl number Time to live in seconds
---@return TTLCache
function TTLCache.new(ttl)
    assert(ttl and ttl > 0, "TTLCache ttl must be greater than 0")
    local self = setmetatable({}, TTLCache)
    self.data = {}
    self.ttl = ttl or 60
    return self
end

---Get a value (returns nil if expired)
---@param key any
---@return any|nil value
function TTLCache:get(key)
    local entry = self.data[key]

    if not entry then
        return nil
    end

    -- Check if expired
    if os.time() > entry.expiry then
        self.data[key] = nil
        return nil
    end

    return entry.value
end

---Set a value with TTL
---@param key any
---@param value any
---@param ttl number|nil Optional custom TTL for this entry
function TTLCache:set(key, value, ttl)
    ttl = ttl or self.ttl
    self.data[key] = {
        value = value,
        expiry = os.time() + ttl
    }
end

---Check if key exists and is not expired
---@param key any
---@return boolean exists
function TTLCache:has(key)
    return self:get(key) ~= nil
end

---Remove a key
---@param key any
function TTLCache:remove(key)
    self.data[key] = nil
end

---Clear all expired entries
---@return number removed Number of removed entries
function TTLCache:cleanup()
    local now = os.time()
    local removed = 0

    for key, entry in pairs(self.data) do
        if now > entry.expiry then
            self.data[key] = nil
            removed = removed + 1
        end
    end

    return removed
end

---Clear all data
function TTLCache:clear()
    self.data = {}
end

---Factory function for TTL cache
---@param ttl number Time to live in seconds
---@return TTLCache
function cache.TTLCache(ttl)
    return TTLCache.new(ttl)
end

-- =============================================
-- Example Memoized Functions
-- =============================================

---Example: Memoized Fibonacci (fixes the O(2^n) performance issue)
---@param n number
---@return number result
cache.Fibonacci = cache.Memoize(function(n)
    if n <= 1 then
        return n
    end
    return cache.Fibonacci(n - 1) + cache.Fibonacci(n - 2)
end)

return cache
