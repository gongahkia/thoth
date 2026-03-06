local math2D = require("thoth.core.math2D")

assert(math.abs(math2D.AngleBetween({0, 0}, {1, 0}) - 0) < 1e-9)
assert(math.abs(math2D.AngleBetween({0, 0}, {0, 1}) - (math.pi / 2)) < 1e-9)

assert(math2D.EuclideanDistance({0, 0}, {3, 4}) == 5)
assert(math2D.ManhattanDistance({0, 0}, {3, 4}) == 7)

local add = math2D.VectorAdd({1, 2}, {3, 4})
assert(add[1] == 4 and add[2] == 6)

local norm = math2D.VectorNormalize({3, 4})
assert(math.abs(norm[1] - 0.6) < 1e-9 and math.abs(norm[2] - 0.8) < 1e-9)
