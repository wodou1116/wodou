local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.New(factory, reset, maxRetained)
    assert(type(factory) == "function", "pool factory must be a function")
    local self = setmetatable({}, ObjectPool)
    self.factory = factory
    self.reset = reset
    self.maxRetained = maxRetained or math.huge
    self.free = {}
    self.created = 0
    self.inUse = 0
    return self
end

function ObjectPool:Acquire()
    local item = table.remove(self.free)
    if not item then
        item = self.factory()
        self.created = self.created + 1
    end
    self.inUse = self.inUse + 1
    return item
end

function ObjectPool:Release(item)
    if not item then
        return false
    end
    if self.reset then
        self.reset(item)
    end
    self.inUse = math.max(0, self.inUse - 1)
    if #self.free < self.maxRetained then
        self.free[#self.free + 1] = item
    end
    return true
end

function ObjectPool:GetStats()
    return {
        created = self.created,
        inUse = self.inUse,
        available = #self.free,
    }
end

return ObjectPool
