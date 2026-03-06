local links = require("thoth.core.links")

local list = links.new()
assert(links.isEmpty(list))

list = links.insert(list, 10)
list = links.insert(list, 20)
list = links.insert(list, 30)
assert(links.size(list) == 3)
assert(links.search(list, 20))

list = links.delete(list, 20)
assert(not links.search(list, 20))
assert(links.size(list) == 2)
