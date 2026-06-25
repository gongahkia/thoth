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

local function trackedAssetPaths()
    local pipe = io.popen("git ls-files assets")
    assert(pipe, "cannot list tracked assets")
    local paths = {}
    for path in pipe:lines() do
        paths[#paths + 1] = path
    end
    local ok = pipe:close()
    assert(ok, "git ls-files assets failed")
    return paths
end

local function assertAssetLicenseCoverage()
    local licenseText = assert(read("docs/asset-licenses.md"), "missing asset license doc")
    local rules = {
        { "^assets/audio/.*%.wav$", "`assets/audio/*.wav`" },
        { "^assets/audio/README%.md$", "`assets/audio/README.md`" },
        { "^assets/models/README%.md$", "`assets/models/README.md`" },
        { "^assets/models/tile_model_map%.lua$", "`assets/models/tile_model_map.lua`" },
        { "^assets/music/README%.md$", "`assets/music/README.md`" },
        { "^assets/music/tracks%.lua$", "`assets/music/tracks.lua`" },
        { "^assets/previews/.*%.gif$", "`assets/previews/*.gif`" },
        { "^assets/previews/.*%.png$", "`assets/previews/*.png`" },
        { "^assets/press/.*$", "`assets/press/*`" },
        { "^assets/sprites/README%.md$", "`assets/sprites/README.md`" },
        { "^assets/sprites/oga_700_sprites%.lua$", "`assets/sprites/oga_700_sprites.lua`" },
        { "^assets/sprites/oga_700_sprites%.png$", "`assets/sprites/oga_700_sprites.png`" },
        { "^assets/tiles/kenney_tiny_dungeon%.png$", "`assets/tiles/kenney_tiny_dungeon.png`" },
    }
    for _, path in ipairs(trackedAssetPaths()) do
        local covered = false
        for _, rule in ipairs(rules) do
            if path:match(rule[1]) and licenseText:find(rule[2], 1, true) then
                covered = true
                break
            end
        end
        assert(covered, "asset missing license trace: " .. path)
    end
end

local png = exists("assets/sprites/oga_700_sprites.png")
assert(png and png:sub(1, 8) == "\137PNG\r\n\26\n", "missing sprite atlas png")
local tilePng = exists("assets/tiles/kenney_tiny_dungeon.png")
assert(tilePng and tilePng:sub(1, 8) == "\137PNG\r\n\26\n", "missing tile atlas png")
assert(not exists("assets/sprites/thoth_atlas.png"), "prototype sprite atlas should not be present")

local manifest = SpritePipeline.loadManifest(read("assets/sprites/oga_700_sprites.lua"))
assert(manifest and manifest.image == "assets/sprites/oga_700_sprites.png", "missing sprite atlas manifest")
assert(manifest.frames == 304 and manifest.columns == 16 and manifest.rows == 19, "bad sprite atlas manifest")
assert(manifest.frameWidth == 32 and manifest.frameHeight == 32, "bad sprite atlas frame size")
assert(manifest.classes and manifest.classes.warden and manifest.classes.warden.group == "gsd1", "missing hero sprite mapping")
assert(manifest.classes.merchant and manifest.classes.merchant.group == "man3", "missing merchant sprite mapping")
assert(manifest.enemies and manifest.enemies.hollow_guard and manifest.enemies.hollow_guard.group == "skl1", "missing enemy sprite mapping")
assert(manifest.framesByName and manifest.framesByName["group.gsd1.fr1"] == 0, "missing named sprite frame")

for _, name in ipairs({
    "mine", "place", "craft", "invalid", "save", "load", "tick", "produce",
    "hit_slash", "hit_blunt", "hit_burn", "hit_affliction", "hit_stress",
    "footstep_stone", "footstep_wet", "footstep_ash",
    "ui_click", "ui_confirm", "ui_back", "ui_error",
    "dialogue_chirp_low", "dialogue_chirp_high",
}) do
    local wav = exists("assets/audio/" .. name .. ".wav")
    assert(wav and wav:sub(1, 4) == "RIFF" and wav:sub(9, 12) == "WAVE", "bad wav: " .. name)
end

assert(Audio.cueForStatus("combat: regent") == "combat", "combat cue missing")
assert(Audio.cueForStatus("mission complete") == "victory", "victory cue missing")
assert(Audio.cueForStatus("hunger gnawed") == "danger", "danger cue missing")
assert(Audio.cueForSkill("razor_lunge") == "hit_slash", "slash skill cue missing")
assert(Audio.cueForSkill("white_flare") == "hit_burn", "burn skill cue missing")
assert(Audio.cueForSkill("brine_spit", true) == "hit_affliction", "affliction skill cue missing")
assert(Audio.cueForSkill("censer_wail", true) == "hit_stress", "stress skill cue missing")
assert(Audio.footstepCueForTile("archive_floor") == "footstep_stone", "stone footstep cue missing")
assert(Audio.footstepCueForTile("salt_floor") == "footstep_wet", "wet footstep cue missing")
assert(Audio.footstepCueForTile("ember_floor") == "footstep_ash", "ash footstep cue missing")
assert(Audio.cueForEvent({ event = "move", tile = "black_water" }) == "footstep_wet", "move event cue missing")
assert(MusicTracks.tracks and MusicTracks.tracks.estate and MusicTracks.tracks.combat_boss, "missing music manifest tracks")
assert(MusicTracks.contexts.expedition_tense == "expedition_tense", "missing tense music context")
assert(MusicTracks.ambient and MusicTracks.ambient.combat.track == "expedition_tense", "missing combat ambient layer")
assert(MusicTracks.tracks.victory_sting.loop == false and MusicTracks.tracks.death_sting.loop == false, "music stings should not loop")
assertAssetLicenseCoverage()

io.stdout:write("asset checks passed\n")
