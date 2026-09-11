local EventBus = {}
EventBus.__index = EventBus

function EventBus.New()
    local self = setmetatable({}, EventBus)
    self:Init()
    return self
end

function EventBus:Init()
    self.listeners = {}
end

function EventBus:Subscribe(eventName, callback)
    assert(type(eventName) == "string" and eventName ~= "", "event name is required")
    assert(type(callback) == "function", "event callback must be a function")
    local listeners = self.listeners[eventName]
    if not listeners then
        listeners = {}
        self.listeners[eventName] = listeners
    end

    table.insert(listeners, callback)
    return callback
end

function EventBus:Once(eventName, callback)
    local wrapper
    wrapper = function(payload)
        self:Unsubscribe(eventName, wrapper)
        callback(payload)
    end
    self:Subscribe(eventName, wrapper)
    return wrapper
end

function EventBus:Unsubscribe(eventName, callback)
    local listeners = self.listeners[eventName]
    if not listeners then
        return
    end

    for index = #listeners, 1, -1 do
        if listeners[index] == callback then
            table.remove(listeners, index)
            break
        end
    end
end

function EventBus:Emit(eventName, payload)
    local listeners = self.listeners[eventName]
    if not listeners then
        return
    end

    -- Dispatch a snapshot so listeners can subscribe, unsubscribe or emit again safely.
    local snapshot = {}
    for index = 1, #listeners do
        snapshot[index] = listeners[index]
    end
    for index = 1, #snapshot do
        snapshot[index](payload)
    end
end

function EventBus:Clear(eventName)
    if eventName then
        self.listeners[eventName] = nil
    else
        self.listeners = {}
    end
end

return EventBus
