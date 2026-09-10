package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local AnimationState = require("animation.AnimationState")

local state = AnimationState.New({ hitDuration = 0.2 })
assert(state:Update(0, true) == AnimationState.States.Move)
assert(state:Hit() == AnimationState.States.Hit)
assert(state:Update(0.19, false) == AnimationState.States.Hit)
assert(state:Hit() == AnimationState.States.Hit)
assert(state:Update(0.11, true) == AnimationState.States.Hit)
assert(state:Update(0.09, false) == AnimationState.States.Idle)

assert(state:Die() == AnimationState.States.Death)
assert(state:Set(AnimationState.States.Move) == AnimationState.States.Death)
assert(state:Hit() == AnimationState.States.Death)
assert(state:Update(10, true) == AnimationState.States.Death)

print("AnimationStatePriorityTest: priority and hit refresh passed")
