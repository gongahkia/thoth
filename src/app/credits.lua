local Credits = {}

local libraries = {
    { name = "g3d", source = "vendor/g3d/LICENSE", author = "groverburger", license = "MIT" },
    { name = "LOVE", source = "https://love2d.org", author = "LOVE Development Team", license = "zlib/libpng" },
}

local function stripBackticks(value)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value:sub(1, 1) == "`" and value:sub(-1) == "`" then
        return value:sub(2, -2)
    end
    return value
end

local function markdownCells(line)
    if not line:match("^|") then
        return nil
    end
    local cells = {}
    for cell in line:gmatch("|([^|]*)") do
        cells[#cells + 1] = stripBackticks(cell)
    end
    return cells
end

function Credits.parseAssetLicenses(text)
    local rows = {}
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        local cells = markdownCells(line)
        if cells and cells[1] and cells[1] ~= "File" and not cells[1]:find("%-%-%-", 1, false) then
            rows[#rows + 1] = { file = cells[1], source = cells[2], author = cells[3], license = cells[4], notes = cells[5] }
        end
    end
    return rows
end

function Credits.lines(data)
    local lines = {
        { kind = "heading", text = "Asset Attributions", indent = 0 },
    }
    for _, asset in ipairs(data.assets or {}) do
        lines[#lines + 1] = { kind = "entry", text = asset.file .. " / " .. asset.license .. " / " .. asset.author, indent = 14 }
        lines[#lines + 1] = { kind = "source", text = asset.source or "-", indent = 28 }
        lines[#lines + 1] = { kind = "note", text = asset.notes or "", indent = 28 }
    end
    lines[#lines + 1] = { kind = "spacer", text = "", indent = 0 }
    lines[#lines + 1] = { kind = "heading", text = "Libraries", indent = 0 }
    for _, lib in ipairs(data.libraries or {}) do
        lines[#lines + 1] = { kind = "entry", text = lib.name .. " / " .. lib.license .. " / " .. lib.author, indent = 14 }
        lines[#lines + 1] = { kind = "source", text = lib.source, indent = 28 }
    end
    lines[#lines + 1] = { kind = "spacer", text = "", indent = 0 }
    lines[#lines + 1] = { kind = "heading", text = "Music", indent = 0 }
    if #(data.music or {}) == 0 then
        lines[#lines + 1] = { kind = "note", text = "No external music tracks packaged.", indent = 14 }
    else
        for _, track in ipairs(data.music) do
            lines[#lines + 1] = { kind = "entry", text = track.title .. " / " .. track.license .. " / " .. track.creator, indent = 14 }
            lines[#lines + 1] = { kind = "source", text = track.source or "-", indent = 28 }
        end
    end
    return lines
end

function Credits.text(lines)
    local output = {}
    for _, line in ipairs(lines or {}) do
        output[#output + 1] = string.rep(" ", line.indent or 0) .. (line.text or "")
    end
    return table.concat(output, "\n")
end

function Credits.data(assetLicenseText)
    local data = {
        project = "Thoth",
        assets = Credits.parseAssetLicenses(assetLicenseText),
        libraries = libraries,
        music = {},
    }
    data.lines = Credits.lines(data)
    data.text = Credits.text(data.lines)
    return data
end

return Credits
