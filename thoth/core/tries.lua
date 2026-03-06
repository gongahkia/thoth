-- =============================================
-- Trie Data Structure
-- Prefix tree for efficient string searching and autocomplete
-- =============================================

local tries = {}

-- =============================================
-- Trie Node
-- =============================================

---@class TrieNode
---@field children table
---@field isEndOfWord boolean
---@field value any
local TrieNode = {}
TrieNode.__index = TrieNode

---Create a new trie node
---@return TrieNode
function TrieNode.new()
    local self = setmetatable({}, TrieNode)
    self.children = {}
    self.isEndOfWord = false
    self.value = nil
    return self
end

-- =============================================
-- Trie
-- =============================================

---@class Trie
---@field root TrieNode
local Trie = {}
Trie.__index = Trie

---Create a new trie
---@return Trie
function Trie.new()
    local self = setmetatable({}, Trie)
    self.root = TrieNode.new()
    return self
end

---Insert a word into the trie
---@param word string Word to insert
---@param value any|nil Optional value to associate with the word
function Trie:insert(word, value)
    local node = self.root

    for i = 1, #word do
        local char = word:sub(i, i)

        if not node.children[char] then
            node.children[char] = TrieNode.new()
        end

        node = node.children[char]
    end

    node.isEndOfWord = true
    node.value = value
end

---Search for a word in the trie
---@param word string Word to search for
---@return boolean found Whether the word exists
---@return any|nil value Associated value if found
function Trie:search(word)
    local node = self.root

    for i = 1, #word do
        local char = word:sub(i, i)

        if not node.children[char] then
            return false, nil
        end

        node = node.children[char]
    end

    return node.isEndOfWord, node.value
end

---Check if any word starts with the given prefix
---@param prefix string Prefix to check
---@return boolean hasPrefix
function Trie:startsWith(prefix)
    local node = self.root

    for i = 1, #prefix do
        local char = prefix:sub(i, i)

        if not node.children[char] then
            return false
        end

        node = node.children[char]
    end

    return true
end

---Get all words with a given prefix
---@param prefix string Prefix to search for
---@return table words Array of words starting with prefix
function Trie:getAllWordsWithPrefix(prefix)
    local words = {}
    local node = self.root

    -- Navigate to the prefix node
    for i = 1, #prefix do
        local char = prefix:sub(i, i)

        if not node.children[char] then
            return words
        end

        node = node.children[char]
    end

    -- Collect all words from this node
    local function collectWords(node, currentWord)
        if node.isEndOfWord then
            table.insert(words, currentWord)
        end

        for char, childNode in pairs(node.children) do
            collectWords(childNode, currentWord .. char)
        end
    end

    collectWords(node, prefix)

    return words
end

---Get autocomplete suggestions for a prefix
---@param prefix string Prefix to autocomplete
---@param limit number|nil Maximum number of suggestions (default: 10)
---@return table suggestions Array of suggested words
function Trie:autocomplete(prefix, limit)
    limit = limit or 10
    local suggestions = {}
    local node = self.root

    -- Navigate to the prefix node
    for i = 1, #prefix do
        local char = prefix:sub(i, i)

        if not node.children[char] then
            return suggestions
        end

        node = node.children[char]
    end

    -- Collect words with limit
    local function collectWords(node, currentWord)
        if #suggestions >= limit then
            return
        end

        if node.isEndOfWord then
            table.insert(suggestions, currentWord)
        end

        for char, childNode in pairs(node.children) do
            if #suggestions >= limit then
                break
            end
            collectWords(childNode, currentWord .. char)
        end
    end

    collectWords(node, prefix)

    return suggestions
end

---Delete a word from the trie
---@param word string Word to delete
---@return boolean success Whether the word was found and deleted
function Trie:delete(word)
    local function deleteRecursive(node, word, depth)
        if depth == #word then
            if not node.isEndOfWord then
                return false
            end

            node.isEndOfWord = false
            node.value = nil

            -- Check if node has no children
            return next(node.children) == nil
        end

        local char = word:sub(depth + 1, depth + 1)
        local childNode = node.children[char]

        if not childNode then
            return false
        end

        local shouldDeleteChild = deleteRecursive(childNode, word, depth + 1)

        if shouldDeleteChild then
            node.children[char] = nil
            -- Return true if node has no children and is not end of another word
            return next(node.children) == nil and not node.isEndOfWord
        end

        return false
    end

    return deleteRecursive(self.root, word, 0)
end

---Get all words in the trie
---@return table words Array of all words
function Trie:getAllWords()
    local words = {}

    local function collectWords(node, currentWord)
        if node.isEndOfWord then
            table.insert(words, currentWord)
        end

        for char, childNode in pairs(node.children) do
            collectWords(childNode, currentWord .. char)
        end
    end

    collectWords(self.root, "")

    return words
end

---Count total words in the trie
---@return number count
function Trie:count()
    local count = 0

    local function countWords(node)
        if node.isEndOfWord then
            count = count + 1
        end

        for _, childNode in pairs(node.children) do
            countWords(childNode)
        end
    end

    countWords(self.root)

    return count
end

---Check if trie is empty
---@return boolean empty
function Trie:isEmpty()
    return next(self.root.children) == nil
end

---Clear the trie
function Trie:clear()
    self.root = TrieNode.new()
end

-- =============================================
-- Longest Common Prefix
-- =============================================

---Find the longest common prefix of all words in the trie
---@return string prefix Longest common prefix
function Trie:longestCommonPrefix()
    local prefix = ""
    local node = self.root

    while true do
        -- Count children
        local childCount = 0
        local nextChar = nil

        for char, childNode in pairs(node.children) do
            childCount = childCount + 1
            nextChar = char
        end

        -- If more than one child or this is end of a word, stop
        if childCount ~= 1 or node.isEndOfWord then
            break
        end

        -- Continue with the single child
        prefix = prefix .. nextChar
        node = node.children[nextChar]
    end

    return prefix
end

-- =============================================
-- Pattern Matching
-- =============================================

---Search for words matching a pattern (use '.' as wildcard)
---@param pattern string Pattern to match (e.g., "c.t" matches "cat", "cot", "cut")
---@return table matches Array of matching words
function Trie:searchPattern(pattern)
    local matches = {}

    local function searchRecursive(node, pattern, depth, currentWord)
        if depth == #pattern then
            if node.isEndOfWord then
                table.insert(matches, currentWord)
            end
            return
        end

        local char = pattern:sub(depth + 1, depth + 1)

        if char == '.' then
            -- Wildcard - try all children
            for childChar, childNode in pairs(node.children) do
                searchRecursive(childNode, pattern, depth + 1, currentWord .. childChar)
            end
        else
            -- Specific character
            local childNode = node.children[char]
            if childNode then
                searchRecursive(childNode, pattern, depth + 1, currentWord .. char)
            end
        end
    end

    searchRecursive(self.root, pattern, 0, "")

    return matches
end

-- =============================================
-- Factory Function
-- =============================================

---Create a new trie
---@return Trie
function tries.new()
    return Trie.new()
end

-- =============================================
-- Utility Functions
-- =============================================

---Build a trie from an array of words
---@param words table Array of words
---@return Trie trie
function tries.fromArray(words)
    local trie = Trie.new()

    for _, word in ipairs(words) do
        trie:insert(word)
    end

    return trie
end

---Build a trie from a table with word-value pairs
---@param wordTable table Table of {word = value} pairs
---@return Trie trie
function tries.fromTable(wordTable)
    local trie = Trie.new()

    for word, value in pairs(wordTable) do
        trie:insert(word, value)
    end

    return trie
end

return tries
