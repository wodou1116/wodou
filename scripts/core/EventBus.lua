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
    local listeners = self.listeners[eventName]
    if not listeners then
        listeners = {}
        self.listeners[eventName] = listeners
    end

    table.insert(listeners, callback)
    return callback
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

    for index = 1, #listeners do
        listeners[index](payload)
    end
end

function EventBus:Clear()
    self.listeners = {}
end

return EventBus
