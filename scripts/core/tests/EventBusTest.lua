package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local EventBus = require("core.EventBus")

local bus = EventBus.New()
local calls = {}
local second

bus:Subscribe("damage", function(payload)
    calls[#calls + 1] = "first:" .. payload.id
    bus:Unsubscribe("damage", second)
    bus:Subscribe("damage", function(nextPayload)
        calls[#calls + 1] = "late:" .. nextPayload.id
    end)
end)

second = bus:Subscribe("damage", function(payload)
    calls[#calls + 1] = "second:" .. payload.id
end)

bus:Emit("damage", { id = 1 })
assert(table.concat(calls, ",") == "first:1,second:1", "emit must use a stable listener snapshot")

calls = {}
bus:Emit("damage", { id = 2 })
assert(table.concat(calls, ",") == "first:2,late:2", "listener changes must apply to the next emit")

local onceCount = 0
bus:Once("death", function()
    onceCount = onceCount + 1
end)
bus:Emit("death")
bus:Emit("death")
assert(onceCount == 1, "Once must remove itself before a re-entrant emit")

local nested = 0
bus:Subscribe("nested", function(depth)
    nested = nested + 1
    if depth == 1 then
        bus:Emit("nested", 2)
    end
end)
bus:Emit("nested", 1)
assert(nested == 2, "EventBus must support re-entrant emits")

print("EventBusTest: stable snapshot, once and re-entrant emit passed")
