local ringbuffers = {}

local RingBuffer = {}
RingBuffer.__index = RingBuffer

function RingBuffer.new(capacity)
    assert(type(capacity) == "number" and capacity > 0, "RingBuffer capacity must be > 0")
    local self = setmetatable({}, RingBuffer)
    self.capacity = capacity
    self.buffer = {}
    self.head = 1
    self.count = 0
    return self
end

function RingBuffer:push(value)
    if self.count < self.capacity then
        local index = ((self.head + self.count - 1) % self.capacity) + 1
        self.buffer[index] = value
        self.count = self.count + 1
    else
        self.buffer[self.head] = value
        self.head = (self.head % self.capacity) + 1
    end
    return self
end

function RingBuffer:size()
    return self.count
end

function RingBuffer:isFull()
    return self.count == self.capacity
end

function RingBuffer:get(index)
    assert(index >= 1 and index <= self.count, "RingBuffer index out of range")
    local actual = ((self.head + index - 2) % self.capacity) + 1
    return self.buffer[actual]
end

function RingBuffer:values()
    local values = {}
    for i = 1, self.count do
        values[i] = self:get(i)
    end
    return values
end

ringbuffers.RingBuffer = RingBuffer

function ringbuffers.new(capacity)
    return RingBuffer.new(capacity)
end

return ringbuffers
