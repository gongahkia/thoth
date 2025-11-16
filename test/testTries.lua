-- Test file for tries module

local tries = require("src.tries")

print("=== Testing Tries Module ===\n")

-- Test Trie Creation
print("Testing Trie creation...")
local trie = tries.new()
assert(trie:isEmpty(), "New trie should be empty")
print("✓ Trie creation works\n")

-- Test Insert
print("Testing insert...")
trie:insert("cat")
trie:insert("car")
trie:insert("card")
trie:insert("care")
trie:insert("careful")
trie:insert("dog")

assert(trie:count() == 6, "Should have 6 words")
assert(not trie:isEmpty(), "Should not be empty")
print("✓ Insert works\n")

-- Test Search
print("Testing search...")
local found, value = trie:search("cat")
assert(found == true, "Should find 'cat'")

found = trie:search("ca")
assert(found == false, "Should not find 'ca' (prefix only)")

found = trie:search("cats")
assert(found == false, "Should not find 'cats'")

found = trie:search("dog")
assert(found == true, "Should find 'dog'")
print("✓ Search works\n")

-- Test StartsWith
print("Testing startsWith...")
assert(trie:startsWith("ca"), "Should have words starting with 'ca'")
assert(trie:startsWith("car"), "Should have words starting with 'car'")
assert(trie:startsWith("do"), "Should have words starting with 'do'")
assert(not trie:startsWith("cat"), "Check prefix existence")
print("✓ StartsWith works\n")

-- Test GetAllWordsWithPrefix
print("Testing getAllWordsWithPrefix...")
local carWords = trie:getAllWordsWithPrefix("car")
assert(#carWords == 4, "Should find 4 words starting with 'car'")

local words = {}
for _, word in ipairs(carWords) do
    words[word] = true
end
assert(words["car"], "Should include 'car'")
assert(words["card"], "Should include 'card'")
assert(words["care"], "Should include 'care'")
assert(words["careful"], "Should include 'careful'")

print("Words with 'car': " .. table.concat(carWords, ", "))
print("✓ GetAllWordsWithPrefix works\n")

-- Test Autocomplete
print("Testing autocomplete...")
local suggestions = trie:autocomplete("ca", 3)
assert(#suggestions <= 3, "Should limit to 3 suggestions")
print("Autocomplete for 'ca': " .. table.concat(suggestions, ", "))
print("✓ Autocomplete works\n")

-- Test Delete
print("Testing delete...")
assert(trie:delete("cat") == true, "Should delete 'cat'")

found = trie:search("cat")
assert(found == false, "Should not find 'cat' after deletion")

found = trie:search("car")
assert(found == true, "Should still find 'car'")

assert(trie:delete("notexist") == false, "Should return false for non-existent word")
print("✓ Delete works\n")

-- Test GetAllWords
print("Testing getAllWords...")
local allWords = trie:getAllWords()
assert(#allWords == 5, "Should have 5 words after deleting 'cat'")
print("All words: " .. table.concat(allWords, ", "))
print("✓ GetAllWords works\n")

-- Test Insert with Values
print("Testing insert with values...")
local trie2 = tries.new()
trie2:insert("apple", {price = 1.50, color = "red"})
trie2:insert("banana", {price = 0.80, color = "yellow"})

found, value = trie2:search("apple")
assert(found == true, "Should find 'apple'")
assert(value.price == 1.50, "Should have correct price")
assert(value.color == "red", "Should have correct color")
print("✓ Insert with values works\n")

-- Test Pattern Matching
print("Testing searchPattern...")
local trie3 = tries.new()
trie3:insert("cat")
trie3:insert("car")
trie3:insert("cot")
trie3:insert("cut")

local matches = trie3:searchPattern("c.t")
assert(#matches == 3, "Should match 'cat', 'cot', 'cut'")

local matchSet = {}
for _, word in ipairs(matches) do
    matchSet[word] = true
end
assert(matchSet["cat"], "Should match 'cat'")
assert(matchSet["cot"], "Should match 'cot'")
assert(matchSet["cut"], "Should match 'cut'")
assert(not matchSet["car"], "Should not match 'car'")

print("Pattern 'c.t' matches: " .. table.concat(matches, ", "))
print("✓ SearchPattern works\n")

-- Test Longest Common Prefix
print("Testing longestCommonPrefix...")
local trie4 = tries.new()
trie4:insert("flower")
trie4:insert("flow")
trie4:insert("flight")

local lcp = trie4:longestCommonPrefix()
assert(lcp == "fl", "Longest common prefix should be 'fl'")
print("Longest common prefix: " .. lcp)
print("✓ LongestCommonPrefix works\n")

-- Test Clear
print("Testing clear...")
trie:clear()
assert(trie:isEmpty(), "Should be empty after clear")
assert(trie:count() == 0, "Count should be 0")
print("✓ Clear works\n")

-- Test fromArray
print("Testing fromArray...")
local words = {"test", "testing", "tester", "tea", "team"}
local trie5 = tries.fromArray(words)

assert(trie5:count() == 5, "Should have 5 words")
assert(trie5:search("test"), "Should find 'test'")
assert(trie5:search("tea"), "Should find 'tea'")
print("✓ fromArray works\n")

-- Test fromTable
print("Testing fromTable...")
local wordTable = {
    hello = "greeting",
    world = "earth",
    help = "assist"
}
local trie6 = tries.fromTable(wordTable)

found, value = trie6:search("hello")
assert(found == true, "Should find 'hello'")
assert(value == "greeting", "Should have correct value")
print("✓ fromTable works\n")

print("=== All Trie Tests Passed ===")
