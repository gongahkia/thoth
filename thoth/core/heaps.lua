-- =============================================
-- Heap Data Structure
-- Min-heap and max-heap implementations with O(log n) operations
-- =============================================

local heaps = {}

-- =============================================
-- Min Heap
-- =============================================

---@class MinHeap
---@field data table
---@field comparator function
local MinHeap = {}
MinHeap.__index = MinHeap

---Create a new min heap
---@param comparator function|nil Optional custom comparator (default: a < b)
---@return MinHeap
function MinHeap.new(comparator)
    local self = setmetatable({}, MinHeap)
    self.data = {}
    self.comparator = comparator or function(a, b) return a < b end
    return self
end

---Get parent index
---@param index number
---@return number parentIndex
local function parent(index)
    return math.floor(index / 2)
end

---Get left child index
---@param index number
---@return number leftIndex
local function leftChild(index)
    return index * 2
end

---Get right child index
---@param index number
---@return number rightIndex
local function rightChild(index)
    return index * 2 + 1
end

---Swap two elements in the heap
---@param i number First index
---@param j number Second index
function MinHeap:swap(i, j)
    self.data[i], self.data[j] = self.data[j], self.data[i]
end

---Bubble up (heapify up) from index
---@param index number
function MinHeap:bubbleUp(index)
    while index > 1 do
        local parentIndex = parent(index)

        if self.comparator(self.data[index], self.data[parentIndex]) then
            self:swap(index, parentIndex)
            index = parentIndex
        else
            break
        end
    end
end

---Bubble down (heapify down) from index
---@param index number
function MinHeap:bubbleDown(index)
    local size = #self.data

    while true do
        local smallest = index
        local left = leftChild(index)
        local right = rightChild(index)

        if left <= size and self.comparator(self.data[left], self.data[smallest]) then
            smallest = left
        end

        if right <= size and self.comparator(self.data[right], self.data[smallest]) then
            smallest = right
        end

        if smallest ~= index then
            self:swap(index, smallest)
            index = smallest
        else
            break
        end
    end
end

---Insert a value into the heap
---@param value any
function MinHeap:push(value)
    table.insert(self.data, value)
    self:bubbleUp(#self.data)
end

---Remove and return the minimum value
---@return any|nil value Minimum value or nil if empty
function MinHeap:pop()
    if #self.data == 0 then
        return nil
    end

    if #self.data == 1 then
        return table.remove(self.data)
    end

    local min = self.data[1]
    self.data[1] = table.remove(self.data)
    self:bubbleDown(1)

    return min
end

---Peek at the minimum value without removing
---@return any|nil value Minimum value or nil if empty
function MinHeap:peek()
    return self.data[1]
end

---Check if heap is empty
---@return boolean empty
function MinHeap:isEmpty()
    return #self.data == 0
end

---Get heap size
---@return number size
function MinHeap:size()
    return #self.data
end

---Clear the heap
function MinHeap:clear()
    self.data = {}
end

-- =============================================
-- Max Heap
-- =============================================

---@class MaxHeap
---@field data table
---@field comparator function
local MaxHeap = {}
MaxHeap.__index = MaxHeap

---Create a new max heap
---@param comparator function|nil Optional custom comparator (default: a > b)
---@return MaxHeap
function MaxHeap.new(comparator)
    local self = setmetatable({}, MaxHeap)
    self.data = {}
    self.comparator = comparator or function(a, b) return a > b end
    return self
end

-- MaxHeap uses the same methods as MinHeap
MaxHeap.swap = MinHeap.swap
MaxHeap.bubbleUp = MinHeap.bubbleUp
MaxHeap.bubbleDown = MinHeap.bubbleDown
MaxHeap.push = MinHeap.push
MaxHeap.pop = MinHeap.pop
MaxHeap.peek = MinHeap.peek
MaxHeap.isEmpty = MinHeap.isEmpty
MaxHeap.size = MinHeap.size
MaxHeap.clear = MinHeap.clear

-- =============================================
-- Priority Queue (using min heap with priorities)
-- =============================================

---@class PriorityQueueItem
---@field value any
---@field priority number
local PriorityQueueItem = {}
PriorityQueueItem.__index = PriorityQueueItem

---Create a new priority queue item
---@param value any
---@param priority number
---@return PriorityQueueItem
function PriorityQueueItem.new(value, priority)
    local self = setmetatable({}, PriorityQueueItem)
    self.value = value
    self.priority = priority
    return self
end

---@class PriorityQueue
---@field heap MinHeap
local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

---Create a new priority queue
---@return PriorityQueue
function PriorityQueue.new()
    local self = setmetatable({}, PriorityQueue)

    -- Use min heap with custom comparator for priority
    self.heap = MinHeap.new(function(a, b)
        return a.priority < b.priority
    end)

    return self
end

---Push an item with priority
---@param value any The value to store
---@param priority number The priority (lower = higher priority)
function PriorityQueue:push(value, priority)
    local item = PriorityQueueItem.new(value, priority)
    self.heap:push(item)
end

---Pop the highest priority item
---@return any|nil value The value with highest priority (lowest priority number)
function PriorityQueue:pop()
    local item = self.heap:pop()
    if item then
        return item.value
    end
    return nil
end

---Peek at the highest priority item
---@return any|nil value The value with highest priority
function PriorityQueue:peek()
    local item = self.heap:peek()
    if item then
        return item.value
    end
    return nil
end

---Check if queue is empty
---@return boolean empty
function PriorityQueue:isEmpty()
    return self.heap:isEmpty()
end

---Get queue size
---@return number size
function PriorityQueue:size()
    return self.heap:size()
end

---Clear the queue
function PriorityQueue:clear()
    self.heap:clear()
end

-- =============================================
-- Heap Sort
-- =============================================

---Sort an array using heap sort
---@param arr table Array to sort
---@param comparator function|nil Optional comparator (default: a < b)
---@return table sorted Sorted array
function heaps.sort(arr, comparator)
    local heap = MinHeap.new(comparator)

    -- Push all elements into heap
    for _, value in ipairs(arr) do
        heap:push(value)
    end

    -- Pop all elements back out (they come out sorted)
    local sorted = {}
    while not heap:isEmpty() do
        table.insert(sorted, heap:pop())
    end

    return sorted
end

-- =============================================
-- Factory Functions
-- =============================================

---Create a new min heap
---@param comparator function|nil Optional custom comparator
---@return MinHeap
function heaps.newMinHeap(comparator)
    return MinHeap.new(comparator)
end

---Create a new max heap
---@param comparator function|nil Optional custom comparator
---@return MaxHeap
function heaps.newMaxHeap(comparator)
    return MaxHeap.new(comparator)
end

---Create a new priority queue
---@return PriorityQueue
function heaps.newPriorityQueue()
    return PriorityQueue.new()
end

return heaps
