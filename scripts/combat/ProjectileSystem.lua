local ObjectPool = require("combat.ObjectPool")

local ProjectileSystem = {}
ProjectileSystem.__index = ProjectileSystem

local function Reset(projectile)
    for key in pairs(projectile) do
        projectile[key] = nil
    end
end

function ProjectileSystem.New(options)
    options = options or {}
    local self = setmetatable({}, ProjectileSystem)
    self.capacity = options.capacity or 64
    self.active = {}
    self.pool = options.pool or ObjectPool.New(function() return {} end, Reset, self.capacity)
    return self
end

function ProjectileSystem:Spawn(spec)
    if #self.active >= self.capacity then
        return nil
    end
    spec = spec or {}
    local projectile = self.pool:Acquire()
    for key, value in pairs(spec) do
        projectile[key] = value
    end
    projectile.x = projectile.x or 0
    projectile.y = projectile.y or 0
    projectile.prevX = projectile.x
    projectile.prevY = projectile.y
    projectile.vx = projectile.vx or 0
    projectile.vy = projectile.vy or 0
    projectile.radius = projectile.radius or 1
    projectile.life = projectile.life or 1
    projectile.maxLife = projectile.maxLife or projectile.life
    projectile.hitsLeft = projectile.hitsLeft or 1
    self.active[#self.active + 1] = projectile
    return projectile
end

function ProjectileSystem:ReleaseAt(index)
    local projectile = table.remove(self.active, index)
    if projectile then
        self.pool:Release(projectile)
    end
    return projectile ~= nil
end

function ProjectileSystem:Update(timeStep, hooks)
    hooks = hooks or {}
    local dt = timeStep or 0
    for index = #self.active, 1, -1 do
        local projectile = self.active[index]
        projectile.prevX = projectile.x
        projectile.prevY = projectile.y
        projectile.x = projectile.x + projectile.vx * dt
        projectile.y = projectile.y + projectile.vy * dt
        projectile.life = projectile.life - dt

        local remove = projectile.life <= 0
        if not remove and hooks.isOutOfBounds then
            remove = hooks.isOutOfBounds(projectile) == true
        end
        if not remove and hooks.queryHit then
            local target, targetIndex = hooks.queryHit(projectile)
            if target then
                local keep = hooks.onHit and hooks.onHit(projectile, target, targetIndex) == true
                remove = not keep
            end
        end
        if remove then
            self:ReleaseAt(index)
        end
    end
end

function ProjectileSystem:Count()
    return #self.active
end

function ProjectileSystem:Clear()
    for index = #self.active, 1, -1 do
        self:ReleaseAt(index)
    end
end

return ProjectileSystem
