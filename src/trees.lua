local binarySearchTreeModule = {}

-- node structure for binary search trees
local Node = {}
Node.__index = Node

-- defining a metamethod for node table
function Node.new(val)
    local self = setmetatable({}, Node)
    self.val = val
    self.left = nil
    self.right = nil
    return self
end

-- helper functions
local function insertNode(root, val)
    if root == nil then
        return Node.new(val)
    end
    local newNode = Node.new(val)
    if val < root.val then
        newNode.left = insertNode(root.left, val)
        newNode.right = root.right
    elseif val > root.val then
        newNode.left = root.left
        newNode.right = insertNode(root.right, val)
    else  
        newNode = root
    end
    return newNode
end

local function inorderTraversal(root, result)
    if root then
        inorderTraversal(root.left, result)
        table.insert(result, root.val)
        inorderTraversal(root.right, result)
    end
end

local function searchNode(root, val)
    if root == nil or root.val == val then
        return root
    end
    if val < root.val then
        return searchNode(root.left, val)
    else
        return searchNode(root.right, val)
    end
end

local function findMin(root)
    while root.left do
        root = root.left
    end
    return root
end

local function deleteNode(root, val)
    if root == nil then
        return nil
    end
    if val < root.val then
        root.left = deleteNode(root.left, val)
    elseif val > root.val then
        root.right = deleteNode(root.right, val)
    else
        -- Node found
        if root.left == nil then
            return root.right
        elseif root.right == nil then
            return root.left
        end
        -- Two children: replace with in-order successor
        local successor = findMin(root.right)
        root.val = successor.val
        root.right = deleteNode(root.right, successor.val)
    end
    return root
end

-- @param nil
-- @return empty binary search tree
function binarySearchTreeModule.new()
    return {root = nil}
end

-- @param binary search tree, value to be inserted
-- @return updated binary search tree
function binarySearchTreeModule.insert(bst, val)
    local newTree = {root = insertNode(bst.root, val)}
    return newTree
end

-- @param binary seach tree, search value
-- @return boolean depending on whether value found
function binarySearchTreeModule.search(bst, val)
    return searchNode(bst.root, val) ~= nil
end

-- @param binary search tree
-- @return table of binary search tree elements in inorder traversal order
function binarySearchTreeModule.inorderTraversal(bst)
    local result = {}
    inorderTraversal(bst.root, result)
    return result
end

-- @param binary search tree, value to delete
-- @return updated binary search tree
function binarySearchTreeModule.delete(bst, val)
    return {root = deleteNode(bst.root, val)}
end

return binarySearchTreeModule