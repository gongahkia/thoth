local ok, err = pcall(require, "src.math")
assert(ok == false, "Legacy src.math import should fail in v4")
assert(tostring(err):find("thoth%.core%.math"), "Migration error should point to thoth.core.math")
