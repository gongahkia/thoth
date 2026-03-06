local trees = require("thoth.core.trees")

local bst = trees.new()
for _, value in ipairs({10, 5, 15, 7, 12, 3, 17}) do
    bst = trees.insert(bst, value)
end

assert(trees.search(bst, 10))
assert(trees.search(bst, 3))
assert(not trees.search(bst, 99))

local ordered = trees.inorderTraversal(bst)
local expected = {3, 5, 7, 10, 12, 15, 17}
for i = 1, #expected do
    assert(ordered[i] == expected[i])
end

bst = trees.delete(bst, 10)
assert(not trees.search(bst, 10))
