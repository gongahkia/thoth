package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Replay = require("src.game.replay")

local function expect(value, message)
    if not value then
        error(message or "expectation failed", 2)
    end
end

local fixtures = {
    require("tests.fixtures.replays.ore_to_plate"),
    require("tests.fixtures.replays.science_research"),
    require("tests.fixtures.replays.full_flow"),
}

for _, fixture in ipairs(fixtures) do
    local sim = Replay.run(fixture.seed, fixture.frames or {}, fixture.finalTick, fixture.setup)
    fixture.validate(sim, expect)
    io.stdout:write("replay ok ", fixture.name, "\n")
end

io.stdout:write("replay fixtures passed: ", #fixtures, "\n")
