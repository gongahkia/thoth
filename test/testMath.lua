local mathModule = require("thoth.core.math")

assert(mathModule.Clamp(10, 0, 20) == 10)
assert(mathModule.Clamp(-5, 0, 20) == 0)
assert(mathModule.Clamp(30, 0, 20) == 20)

assert(mathModule.Fibonacci(0) == 0)
assert(mathModule.Fibonacci(1) == 1)
assert(mathModule.Fibonacci(10) == 55)

assert(math.abs(mathModule.Lerp(0, 10, 0.5) - 5) < 1e-9)
assert(math.abs(mathModule.DegreeToRadian(180) - math.pi) < 1e-9)
assert(math.abs(mathModule.RadianToDegree(math.pi) - 180) < 1e-9)

local r = mathModule.RandRange(1, 2)
assert(r >= 1 and r <= 2)

local scaled = mathModule.ScaleBy(5, 0, 10, 0, 100)
assert(scaled == 50)

local smooth = mathModule.Smooth(0, 10, 5)
assert(math.abs(smooth - 0.5) < 1e-9)

local v, err = mathModule.ScaleBy(1, 2, 2, 0, 1)
assert(v == nil and err)
