local tries = require("thoth.core.tries")

local trie = tries.new()
trie:insert("cat")
trie:insert("car")
trie:insert("dog")

assert(trie:search("cat"))
assert(not trie:search("ca"))
assert(trie:startsWith("ca"))
assert(trie:startsWith("cat"))

local suggestions = trie:autocomplete("ca", 10)
assert(#suggestions >= 2)

assert(trie:delete("cat") == true)
assert(not trie:search("cat"))
