package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Audio = require("src.app.audio")
local MusicTracks = require("assets.music.tracks")
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

local png = exists("assets/sprites/oga_700_sprites.png")
assert(png and png:sub(1, 8) == "\137PNG\r\n\26\n", "missing sprite atlas png")
assert(not exists("assets/sprites/thoth_atlas.png"), "prototype sprite atlas should not be present")

local manifest = SpritePipeline.loadManifest(read("assets/sprites/oga_700_sprites.lua"))
assert(manifest and manifest.image == "assets/sprites/oga_700_sprites.png", "missing sprite atlas manifest")
assert(manifest.frames == 304 and manifest.columns == 16 and manifest.rows == 19, "bad sprite atlas manifest")
assert(manifest.frameWidth == 32 and manifest.frameHeight == 32, "bad sprite atlas frame size")
assert(manifest.classes and manifest.classes.warden and manifest.classes.warden.group == "gsd1", "missing hero sprite mapping")
assert(manifest.enemies and manifest.enemies.hollow_guard and manifest.enemies.hollow_guard.group == "skl1", "missing enemy sprite mapping")
assert(manifest.framesByName and manifest.framesByName["group.gsd1.fr1"] == 0, "missing named sprite frame")

for _, name in ipairs({ "mine", "place", "craft", "invalid", "save", "load", "tick", "produce" }) do
    local wav = exists("assets/audio/" .. name .. ".wav")
    assert(wav and wav:sub(1, 4) == "RIFF" and wav:sub(9, 12) == "WAVE", "bad wav: " .. name)
end

assert(Audio.cueForStatus("combat: regent") == "combat", "combat cue missing")
assert(Audio.cueForStatus("mission complete") == "victory", "victory cue missing")
assert(Audio.cueForStatus("hunger gnawed") == "danger", "danger cue missing")
assert(MusicTracks.tracks and MusicTracks.tracks.estate and MusicTracks.tracks.combat_boss, "missing music manifest tracks")
assert(MusicTracks.contexts.expedition_tense == "expedition_tense", "missing tense music context")
assert(MusicTracks.tracks.victory_sting.loop == false and MusicTracks.tracks.death_sting.loop == false, "music stings should not loop")

io.stdout:write("asset checks passed\n")
