local camera = require("thoth.game.camera")
local collision = require("thoth.game.collision")
local animation = require("thoth.game.animation")

local cam = camera.new({viewportWidth = 100, viewportHeight = 50})
cam:setBounds(0, 0, 500, 300)
cam:centerOn(200, 100)
local sx, sy = cam:worldToScreen(200, 100)
assert(math.abs(sx - 50) < 1e-9)
assert(math.abs(sy - 25) < 1e-9)
local wx, wy = cam:screenToWorld(sx, sy)
assert(math.abs(wx - 200) < 1e-9)
assert(math.abs(wy - 100) < 1e-9)

local target = {x = 300, y = 150}
cam:setTarget(target, 10)
cam:update(0.1)
assert(cam.x > 0 and cam.y > 0)

assert(collision.pointInRect({x = 5, y = 5}, collision.rect(0, 0, 10, 10)))
assert(collision.pointInCircle({x = 1, y = 1}, collision.circle(0, 0, 2)))
assert(collision.rectsOverlap(collision.rect(0, 0, 4, 4), collision.rect(3, 3, 4, 4)))
assert(collision.circlesOverlap(collision.circle(0, 0, 2), collision.circle(3, 0, 2)))
assert(collision.circleRectOverlap(collision.circle(5, 5, 2), collision.rect(6, 4, 3, 3)))
assert(collision.segmentIntersectsRect(0, 0, 10, 10, collision.rect(4, 4, 2, 2)))
assert(collision.raycastRect({x = 0, y = 0}, {x = 1, y = 0}, 10, collision.rect(5, -1, 2, 2)).hit)

local machine = animation.new("idle")
local entered = {}
local exited = {}
local context = {running = false}

machine:addState("idle", {
    onEnter = function() entered[#entered + 1] = "idle" end,
    onExit = function() exited[#exited + 1] = "idle" end,
})
machine:addState("run", {
    onEnter = function() entered[#entered + 1] = "run" end,
    onExit = function() exited[#exited + 1] = "run" end,
})
machine:addTransition("idle", "run", function(ctx)
    return ctx.running == true
end)
machine:addTransition("run", "idle", function(ctx, timeInState)
    return ctx.running == false and timeInState >= 0.1
end)

assert(machine:update(0.05, context) == "idle")
context.running = true
assert(machine:update(0.05, context) == "run")
context.running = false
assert(machine:update(0.05, context) == "run")
assert(machine:update(0.05, context) == "idle")
assert(entered[1] == "idle" and entered[2] == "run")
assert(exited[1] == "idle")
