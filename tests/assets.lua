package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Audio = require("src.app.audio")
local SpritePipeline = require("src.app.sprite_pipeline")

local function exists(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local data = file:read(16)
    file:close()
    return data
end

local function read(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local data = file:read("*a")
    file:close()
    return data
end

local png = exists("assets/sprites/thoth_atlas.png")
assert(png and png:sub(1, 8) == "\137PNG\r\n\26\n", "missing sprite atlas png")

local manifest = SpritePipeline.loadManifest(read("assets/sprites/thoth_atlas.lua"))
assert(manifest and manifest.image == "assets/sprites/thoth_atlas.png", "missing sprite atlas manifest")
assert(manifest.frames == 40 and manifest.columns == 8 and manifest.rows == 5, "bad sprite atlas manifest")

for _, name in ipairs({ "mine", "place", "craft", "invalid", "save", "load", "tick", "produce" }) do
    local wav = exists("assets/audio/" .. name .. ".wav")
    assert(wav and wav:sub(1, 4) == "RIFF" and wav:sub(9, 12) == "WAVE", "bad wav: " .. name)
end

assert(Audio.cueForStatus("combat: regent") == "combat", "combat cue missing")
assert(Audio.cueForStatus("mission complete") == "victory", "victory cue missing")
assert(Audio.cueForStatus("hunger gnawed") == "danger", "danger cue missing")

io.stdout:write("asset checks passed\n")
