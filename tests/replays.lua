package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Replay = require("src.game.replay")
local Simulation = require("src.game.simulation")

local function expect(value, message)
    if not value then
        error(message or "replay expectation failed", 2)
    end
end

local fixtures = {
    {
        name = "light_and_selection",
        seed = 101,
        finalTick = 4,
        frames = {
            { tick = 0, command = Simulation.commands.move("east") },
            { tick = 1, command = Simulation.commands.useItem("torch") },
            { tick = 2, command = Simulation.commands.selectHero(2) },
        },
        validate = function(sim)
            expect(sim.player.x == 1, "replay movement failed")
            expect(sim.expedition.torch == 99, "replay torch use failed")
            expect(sim.player.selectedHero == 2, "replay hero selection failed")
        end,
    },
    {
        name = "entry_retreat",
        seed = 102,
        finalTick = 7,
        frames = {
            { tick = 0, command = Simulation.commands.move("east") },
            { tick = 1, command = Simulation.commands.move("east") },
            { tick = 2, command = Simulation.commands.move("east") },
            { tick = 3, command = Simulation.commands.move("east") },
            { tick = 4, command = Simulation.commands.move("east") },
            { tick = 5, command = Simulation.commands.retreat() },
        },
        validate = function(sim)
            expect(sim.mode == "expedition", "retreat replay should return to exploration")
            expect(sim.combat == nil, "retreat replay should clear combat")
        end,
    },
    {
        name = "estate_to_camp",
        seed = 103,
        finalTick = 9,
        frames = {
            { tick = 0, command = Simulation.commands.endExpedition(true) },
            { tick = 1, command = Simulation.commands.buyProvision("torch", 2) },
            { tick = 2, command = Simulation.commands.recruitHero(1) },
            { tick = 3, command = Simulation.commands.assignParty(5, 4) },
            { tick = 4, command = Simulation.commands.startExpedition("archive_cleansing") },
            { tick = 5, command = Simulation.commands.camp() },
            { tick = 6, command = Simulation.commands.campSkill("watch_order") },
            { tick = 7, command = Simulation.commands.campSkill("bind_wounds", 4) },
        },
        validate = function(sim)
            expect(sim.expedition.mission == "archive_cleansing", "mission replay should start selected mission")
            expect(sim.expedition.supplies:count("torch") == 6, "provision replay should merge cart")
            expect(#sim.estate.roster == 5 and sim.party[4] == 5, "recruit replay should assign new hero")
            expect(sim.expedition.campUsed and sim.expedition.camping == nil, "camp replay should spend all respite")
        end,
    },
}

for _, fixture in ipairs(fixtures) do
    local sim = Replay.run(fixture.seed, fixture.frames, fixture.finalTick)
    fixture.validate(sim)
    io.stdout:write("replay ok ", fixture.name, "\n")
end

io.stdout:write("replay fixtures passed: ", #fixtures, "\n")
