local s = require("thoth.core.stringify")

assert(s.Strip("   hi   ") == "hi")
assert(s.Lstrip("   hi   ") == "hi   ")
assert(s.Rstrip("   hi   ") == "   hi")

local parts = s.Split("a,b,c", ",")
assert(#parts == 3 and parts[1] == "a" and parts[3] == "c")

local dotted = s.Split("a.b.c", ".")
assert(#dotted == 3 and dotted[2] == "b")

local stars = s.Split("a**b**c", "**")
assert(#stars == 3 and stars[1] == "a" and stars[3] == "c")

local chars = s.Split("abc", "")
assert(#chars == 3 and chars[1] == "a" and chars[3] == "c")

assert(s.StartsWith("hello", "he"))
assert(s.EndsWith("hello", "lo"))
assert(s.Contains("hello", "ell"))
assert(s.Replace("a-b-c", "-", ":") == "a:b:c")
assert(s.Interpolate("${a}+${b}", {a = 1, b = 2}) == "1+2")
