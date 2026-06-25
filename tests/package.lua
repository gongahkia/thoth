local packagePath = arg[1] or "dist/thoth.love"

local handle = io.popen("unzip -Z1 " .. packagePath)
if not handle then
    io.stderr:write("could not inspect package\n")
    os.exit(1)
end

local entries = {}
for line in handle:lines() do
    entries[line] = true
end
local ok = handle:close()
if not ok then
    io.stderr:write("package listing failed\n")
    os.exit(1)
end

local required = {
    "main.lua",
    "conf.lua",
    "TODO.md",
    "src/game/data/registry.lua",
    "src/app/credits.lua",
    "vendor/g3d/g3d/init.lua",
    "assets/sprites/oga_700_sprites.png",
    "assets/tiles/kenney_tiny_dungeon.png",
    "assets/audio/mine.wav",
    "assets/audio/hit_slash.wav",
    "assets/music/tracks.lua",
    "docs/market-audit.md",
    "docs/asset-licenses.md",
}

for _, path in ipairs(required) do
    if not entries[path] then
        io.stderr:write("missing package entry: ", path, "\n")
        os.exit(1)
    end
end

for path in pairs(entries) do
    if path:find("^assets/previews/") or path:find("^assets/press/") or path:find("^assets/replays/") or path:find("^vendor/g3d/%.git") then
        io.stderr:write("excluded package entry present: ", path, "\n")
        os.exit(1)
    end
end

print("package contents passed")
