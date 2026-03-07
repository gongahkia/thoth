local thoth = require("thoth")

local mathModule = thoth.core.math
assert(mathModule.clamp == mathModule.Clamp)
assert(mathModule.degree_to_radian == mathModule.DegreeToRadian)
assert(mathModule.rand_range == mathModule.RandRange)

local math2d = thoth.core.math2d
assert(math2d == require("thoth.core.math2d"))
assert(math2d.angle_between == math2d.AngleBetween)
assert(math2d.vector_normalize == math2d.VectorNormalize)

local tables = thoth.core.tables
assert(tables.shallow_copy == tables.ShallowCopy)
assert(tables.shift_value == tables.ShiftValue)

local stringify = thoth.core.stringify
assert(stringify.title_case == stringify.TitleCase)
assert(stringify.levenshtein_distance == stringify.LevenshteinDistance)
assert(stringify.is_blank == stringify.IsBlank)

local performance = thoth.core.performance
assert(performance.timer == performance.Timer)
assert(performance.format_time == performance.FormatTime)
assert(performance.fps_counter == performance.FPSCounter)

local cache = thoth.core.cache
assert(cache.memoize == cache.Memoize)
assert(cache.memoize_lru == cache.MemoizeLRU)
assert(cache.lru_cache == cache.LRUCache)
assert(cache.ttl_cache == cache.TTLCache)
