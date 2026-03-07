local deques = {}

local Deque = {}
Deque.__index = Deque

function Deque.new()
    local self = setmetatable({}, Deque)
    self.first = 0
    self.last = -1
    self.data = {}
    return self
end

function Deque:isEmpty()
    return self.first > self.last
end

function Deque:size()
    return self.last - self.first + 1
end

function Deque:pushFront(value)
    self.first = self.first - 1
    self.data[self.first] = value
    return self
end

function Deque:pushBack(value)
    self.last = self.last + 1
    self.data[self.last] = value
    return self
end

function Deque:popFront()
    assert(not self:isEmpty(), "Deque is empty")
    local value = self.data[self.first]
    self.data[self.first] = nil
    self.first = self.first + 1
    return value
end

function Deque:popBack()
    assert(not self:isEmpty(), "Deque is empty")
    local value = self.data[self.last]
    self.data[self.last] = nil
    self.last = self.last - 1
    return value
end

function Deque:peekFront()
    assert(not self:isEmpty(), "Deque is empty")
    return self.data[self.first]
end

function Deque:peekBack()
    assert(not self:isEmpty(), "Deque is empty")
    return self.data[self.last]
end

deques.Deque = Deque

function deques.new()
    return Deque.new()
end

return deques
