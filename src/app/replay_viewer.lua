local Replay = require("src.game.replay")
local Render = require("src.app.render")

local ReplayViewer = {}

local function replayCutscenes(sim)
    local scenes = {}
    for _, event in ipairs((sim and sim.events) or {}) do
        local scene = Render.cutsceneForEvent(event, sim)
        if scene then
            scenes[#scenes + 1] = scene
        end
    end
    return scenes
end

function ReplayViewer.fromData(data, setup)
    local sim = Replay.runData(data, setup)
    return {
        data = data,
        sim = sim,
        status = Replay.summary(data),
        cutscenes = replayCutscenes(sim),
    }
end

function ReplayViewer.load(path, setup)
    local data, err = Replay.read(path)
    if not data then
        return nil, err
    end
    return ReplayViewer.fromData(data, setup)
end

return ReplayViewer
