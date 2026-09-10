local AnimationState = require("animation.AnimationState")

local state = AnimationState.New({ hitDuration = 0.2 })
assert(state:Get() == AnimationState.States.Idle)
assert(state:Update(0.01, true) == AnimationState.States.Move)
assert(state:Hit() == AnimationState.States.Hit)
assert(state:Update(0.19, true) == AnimationState.States.Hit)
assert(state:Update(0.01, false) == AnimationState.States.Idle)
assert(state:Die() == AnimationState.States.Death)
assert(state:Hit() == AnimationState.States.Death)
assert(state:Update(10, true) == AnimationState.States.Death)

return true
