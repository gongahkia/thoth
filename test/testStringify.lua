local s = require("thoth.core.stringify")

assert(s.Strip("   hi   ") == "hi")
assert(s.Lstrip("   hi   ") == "hi   ")
assert(s.Rstrip("   hi   ") == "   hi")

local parts = s.Split("a,b,c", ",")
assert(#parts == 3 and parts[1] == "a" and parts[3] == "c")

assert(s.StartsWith("hello", "he"))
assert(s.EndsWith("hello", "lo"))
assert(s.Contains("hello", "ell"))
assert(s.Replace("a-b-c", "-", ":") == "a:b:c")
assert(s.Interpolate("${a}+${b}", {a = 1, b = 2}) == "1+2")
