local tableModule = {}

-- @param table
-- @return table length
function tableModule.Count(tbl)
    local count = 0
    for _ in pairs(tbl) do 
        count = count + 1 
    end
    return count
end

-- @param table
-- @return last value of table
function tableModule.Pop(tbl)
    local val = table.remove(tbl)
    return val
end

-- @param table, value to be pushed
-- @return new table
function tableModule.Push(tbl, val)
    table.insert(tbl, val)
    return tbl
end

-- @param table to be shallow copied
-- @return shallow copy of specified table 
function tableModule.ShallowCopy(tbl) 
    local fin = {}
    for key, value in ipairs(tbl) do
        fin[key] = value
    end
    return fin
end

-- @param table
-- @return first element of table
function tableModule.Shift(tbl)
    table.remove(tbl, 1)
    return tbl
end

-- @param value to be added to start of table
-- @return new table
function tableModule.Unshift(tbl, val)
    table.insert(tbl, 1, val)
    return tbl
end

-- @param function, iterable structure
-- @return transformed iterable structure
function tableModule.Map(func, arr)
    local fin = {}
    for index, val in ipairs(arr) do
        fin[index] = func(val)
    end
    return fin
end

-- @param predicate function, iterable structure
-- @return filtered iterable structure
function tableModule.Filter(predicateFunc, arr)
    local fin = {}
    for _, val in ipairs(arr) do
        if predicateFunc(val) then
            table.insert(fin, val)
        end
    end
    return fin
end

-- @param aggregate function, iterable structure
-- @return single element
function tableModule.Reduce(aggFunc, arr)
    local fin = arr[1]
    for i = 2, #arr do
        fin = aggFunc(fin, arr[i])
    end
    return fin
end

return tableModule