local stringModule = {}

-- =============================================
-- V1 Functions (Backward Compatible)
-- =============================================

-- @param string, substring to be trimmed on both sides
-- @return sanitised string
function stringModule.Strip(str, substr)
    if substr then
        local pattern = "^" .. substr .. "*(.-)" .. substr .. "*$"
        return str:match(pattern)
    else
        return str:match("^%s*(.-)%s*$")
    end
end

-- @param string, substring to be trimmed on the left
-- @return sanitised string
function stringModule.Lstrip(str, substr)
    if substr then
        local pattern = "^" .. substr .. "*(.-)" .. substr .. "*$"
        return str:match(pattern)
    else
        return str:match("^%s*(.-)%s*$")
    end
end

-- @param string, substring to be trimmed on the right
-- @return sanitised string
function stringModule.Rstrip(str, substr)
    if substr then
        local pattern = "^(.-)" .. substr .. "*$"
        return str:match(pattern)
    else
        return str:match("^(.-)%s*$")
    end
end

-- @param string, delimiter
-- @return table of substrings split by specified delimiter
function stringModule.Split(str, delim)
    local fin = {}
    local pattern = string.format("([^%s]+)", delim)
    for word in string.gmatch(str, pattern) do
        table.insert(fin, word)
    end
    return fin
end

-- =============================================
-- V2 String Extensions
-- =============================================

---Check if string starts with prefix
---@param str string String to check
---@param prefix string Prefix to look for
---@return boolean startsWith
function stringModule.StartsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

---Check if string ends with suffix
---@param str string String to check
---@param suffix string Suffix to look for
---@return boolean endsWith
function stringModule.EndsWith(str, suffix)
    return str:sub(-#suffix) == suffix
end

---Check if string contains substring
---@param str string String to search in
---@param substr string Substring to search for
---@return boolean contains
function stringModule.Contains(str, substr)
    return str:find(substr, 1, true) ~= nil
end

---Pad string on the left to reach target length
---@param str string String to pad
---@param length number Target length
---@param char string|nil Padding character (default: space)
---@return string padded
function stringModule.PadLeft(str, length, char)
    char = char or " "
    local padding = string.rep(char, length - #str)
    return padding .. str
end

---Pad string on the right to reach target length
---@param str string String to pad
---@param length number Target length
---@param char string|nil Padding character (default: space)
---@return string padded
function stringModule.PadRight(str, length, char)
    char = char or " "
    local padding = string.rep(char, length - #str)
    return str .. padding
end

---Pad string on both sides to center it
---@param str string String to pad
---@param length number Target length
---@param char string|nil Padding character (default: space)
---@return string centered
function stringModule.Center(str, length, char)
    char = char or " "
    local totalPadding = length - #str
    local leftPadding = math.floor(totalPadding / 2)
    local rightPadding = totalPadding - leftPadding
    return string.rep(char, leftPadding) .. str .. string.rep(char, rightPadding)
end

---Truncate string to maximum length
---@param str string String to truncate
---@param maxLength number Maximum length
---@param ellipsis string|nil Ellipsis to append if truncated (default: "...")
---@return string truncated
function stringModule.Truncate(str, maxLength, ellipsis)
    ellipsis = ellipsis or "..."

    if #str <= maxLength then
        return str
    end

    return str:sub(1, maxLength - #ellipsis) .. ellipsis
end

---Repeat string n times
---@param str string String to repeat
---@param count number Number of repetitions
---@param separator string|nil Separator between repetitions
---@return string repeated
function stringModule.Repeat(str, count, separator)
    separator = separator or ""
    local parts = {}

    for i = 1, count do
        table.insert(parts, str)
    end

    return table.concat(parts, separator)
end

---Reverse a string
---@param str string String to reverse
---@return string reversed
function stringModule.Reverse(str)
    return str:reverse()
end

---Word wrap text to fit within specified width
---@param str string Text to wrap
---@param width number Maximum line width
---@return string wrapped Wrapped text with newlines
function stringModule.WordWrap(str, width)
    local lines = {}
    local currentLine = ""

    for word in str:gmatch("%S+") do
        if #currentLine + #word + 1 > width then
            if #currentLine > 0 then
                table.insert(lines, currentLine)
                currentLine = word
            else
                -- Word is longer than width, force break
                table.insert(lines, word)
                currentLine = ""
            end
        else
            if #currentLine > 0 then
                currentLine = currentLine .. " " .. word
            else
                currentLine = word
            end
        end
    end

    if #currentLine > 0 then
        table.insert(lines, currentLine)
    end

    return table.concat(lines, "\n")
end

---Join array of strings with separator
---@param parts table Array of strings
---@param separator string Separator
---@return string joined
function stringModule.Join(parts, separator)
    return table.concat(parts, separator)
end

---Title case (capitalize first letter of each word)
---@param str string String to title case
---@return string titleCased
function stringModule.TitleCase(str)
    return str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

---Convert to uppercase
---@param str string String to convert
---@return string uppercase
function stringModule.Upper(str)
    return str:upper()
end

---Convert to lowercase
---@param str string String to convert
---@return string lowercase
function stringModule.Lower(str)
    return str:lower()
end

---Count occurrences of substring
---@param str string String to search in
---@param substr string Substring to count
---@return number count
function stringModule.Count(str, substr)
    local count = 0
    local pos = 1

    while true do
        local found = str:find(substr, pos, true)
        if not found then
            break
        end
        count = count + 1
        pos = found + 1
    end

    return count
end

---Replace all occurrences of pattern with replacement
---@param str string String to search in
---@param pattern string Pattern to replace
---@param replacement string Replacement string
---@param plain boolean|nil Whether to treat pattern as plain text (default: true)
---@return string replaced
function stringModule.Replace(str, pattern, replacement, plain)
    plain = plain == nil and true or plain
    return str:gsub(plain and pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1") or pattern, replacement)
end

---Remove all occurrences of substring
---@param str string String to modify
---@param substr string Substring to remove
---@return string cleaned
function stringModule.Remove(str, substr)
    return stringModule.Replace(str, substr, "")
end

---Calculate Levenshtein distance (edit distance) between two strings
---@param str1 string First string
---@param str2 string Second string
---@return number distance Edit distance
function stringModule.LevenshteinDistance(str1, str2)
    local len1 = #str1
    local len2 = #str2

    local matrix = {}

    -- Initialize matrix
    for i = 0, len1 do
        matrix[i] = {[0] = i}
    end

    for j = 0, len2 do
        matrix[0][j] = j
    end

    -- Fill matrix
    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (str1:sub(i, i) == str2:sub(j, j)) and 0 or 1

            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,      -- Deletion
                matrix[i][j-1] + 1,      -- Insertion
                matrix[i-1][j-1] + cost  -- Substitution
            )
        end
    end

    return matrix[len1][len2]
end

---Check if two strings are similar (using Levenshtein distance)
---@param str1 string First string
---@param str2 string Second string
---@param threshold number|nil Maximum allowed distance (default: 3)
---@return boolean similar
function stringModule.IsSimilar(str1, str2, threshold)
    threshold = threshold or 3
    return stringModule.LevenshteinDistance(str1, str2) <= threshold
end

---Template string interpolation (replace ${key} with values from table)
---@param template string Template string
---@param values table Table of key-value pairs
---@return string interpolated
function stringModule.Interpolate(template, values)
    return template:gsub("%$%{([%w_]+)%}", function(key)
        return tostring(values[key] or "${" .. key .. "}")
    end)
end

---Check if string is empty or only whitespace
---@param str string String to check
---@return boolean isEmpty
function stringModule.IsBlank(str)
    return str:match("^%s*$") ~= nil
end

---Get all lines in a string
---@param str string String to split
---@return table lines Array of lines
function stringModule.Lines(str)
    local lines = {}
    for line in str:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

return stringModule