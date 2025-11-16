-- Test file for heaps module

local heaps = require("src.heaps")

print("=== Testing Heaps Module ===\n")

-- Test Min Heap
print("Testing MinHeap...")
local minHeap = heaps.newMinHeap()

assert(minHeap:isEmpty(), "New heap should be empty")

minHeap:push(5)
minHeap:push(3)
minHeap:push(7)
minHeap:push(1)

assert(minHeap:size() == 4, "Should have 4 elements")
assert(minHeap:peek() == 1, "Min should be 1")

assert(minHeap:pop() == 1, "Should pop 1")
assert(minHeap:pop() == 3, "Should pop 3")
assert(minHeap:pop() == 5, "Should pop 5")
assert(minHeap:pop() == 7, "Should pop 7")

assert(minHeap:isEmpty(), "Should be empty after popping all")

print("✓ MinHeap works\n")

-- Test Max Heap
print("Testing MaxHeap...")
local maxHeap = heaps.newMaxHeap()

maxHeap:push(5)
maxHeap:push(3)
maxHeap:push(7)
maxHeap:push(1)

assert(maxHeap:peek() == 7, "Max should be 7")

assert(maxHeap:pop() == 7, "Should pop 7")
assert(maxHeap:pop() == 5, "Should pop 5")
assert(maxHeap:pop() == 3, "Should pop 3")
assert(maxHeap:pop() == 1, "Should pop 1")

print("✓ MaxHeap works\n")

-- Test Priority Queue
print("Testing PriorityQueue...")
local pq = heaps.newPriorityQueue()

assert(pq:isEmpty(), "New queue should be empty")

pq:push("low priority task", 10)
pq:push("high priority task", 1)
pq:push("medium priority task", 5)

assert(pq:size() == 3, "Should have 3 items")

assert(pq:peek() == "high priority task", "Should peek highest priority")
assert(pq:pop() == "high priority task", "Should pop highest priority")
assert(pq:pop() == "medium priority task", "Should pop medium priority")
assert(pq:pop() == "low priority task", "Should pop low priority")

assert(pq:isEmpty(), "Should be empty")

print("✓ PriorityQueue works\n")

-- Test Heap with Custom Comparator
print("Testing custom comparator...")
local customHeap = heaps.newMinHeap(function(a, b)
    return a.priority < b.priority
end)

customHeap:push({name = "Task A", priority = 5})
customHeap:push({name = "Task B", priority = 2})
customHeap:push({name = "Task C", priority = 8})

local first = customHeap:pop()
assert(first.priority == 2, "Should pop lowest priority")
assert(first.name == "Task B", "Should be Task B")

print("✓ Custom comparator works\n")

-- Test Heap Sort
print("Testing heapSort...")
local unsorted = {5, 2, 8, 1, 9, 3}
local sorted = heaps.sort(unsorted)

assert(#sorted == #unsorted, "Should have same length")
assert(sorted[1] == 1, "First should be 1")
assert(sorted[6] == 9, "Last should be 9")

for i = 1, #sorted - 1 do
    assert(sorted[i] <= sorted[i + 1], "Should be in ascending order")
end

print("Sorted: " .. table.concat(sorted, ", "))
print("✓ heapSort works\n")

-- Test Large Heap
print("Testing large heap performance...")
local largeHeap = heaps.newMinHeap()

for i = 1000, 1, -1 do
    largeHeap:push(i)
end

assert(largeHeap:size() == 1000, "Should have 1000 elements")

local prev = largeHeap:pop()
for i = 1, 999 do
    local current = largeHeap:pop()
    assert(prev <= current, "Should maintain min heap property")
    prev = current
end

print("✓ Large heap works\n")

-- Test Clear
print("Testing clear...")
local heap = heaps.newMinHeap()
heap:push(1)
heap:push(2)
heap:push(3)

heap:clear()
assert(heap:isEmpty(), "Should be empty after clear")
assert(heap:size() == 0, "Size should be 0")

print("✓ Clear works\n")

print("=== All Heap Tests Passed ===")
