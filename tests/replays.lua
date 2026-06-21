package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Replay = require("src.game.replay")
local Simulation = require("src.game.simulation")
local Serialize = require("src.core.serialize")
local TacticsState = require("src.game.tactics.state")

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
        setup = function(sim)
            local startExpedition = sim.startExpedition
            function sim:startExpedition(locationKey)
                local ok = startExpedition(self, locationKey)
                if ok then
                    self.world:setTile(self.player.x, self.player.y, self.player.z, { id = "camp_marker", data = 0 })
                end
                return ok
            end
        end,
        validate = function(sim)
            expect(sim.expedition.mission == "archive_cleansing", "mission replay should start selected mission")
            expect(sim.expedition.supplies:count("torch") == 6, "provision replay should merge cart")
            expect(#sim.estate.roster == 5 and sim.party[4] == 5, "recruit replay should assign new hero")
            expect(sim.expedition.campUsed and sim.expedition.camping == nil, "camp replay should spend all respite")
        end,
    },
    {
        name = "merchant_unlock_recruit",
        seed = 104,
        finalTick = 5,
        frames = {
            { tick = 0, command = Simulation.commands.endExpedition(true) },
            { tick = 1, command = Simulation.commands.recruitHero(1) },
            { tick = 2, command = Simulation.commands.assignParty(5, 4) },
            { tick = 3, command = Simulation.commands.startExpedition("archive_scout") },
        },
        setup = function(sim)
            sim.estate.campaign.completedMissions.archive_regent = true
            sim.estate.campaign.bossKills.buried_archive = true
        end,
        validate = function(sim)
            expect(sim.estate.campaign.flags.merchant_ledger_accepted, "merchant replay should unlock ledger")
            expect(sim:heroById(5).class == "merchant" and sim.party[4] == 5, "merchant replay should recruit and assign merchant")
            expect(sim.expedition and sim.expedition.mission == "archive_scout", "merchant replay should enter expedition")
        end,
    },
}

for _, fixture in ipairs(fixtures) do
    local sim = Replay.run(fixture.seed, fixture.frames, fixture.finalTick, fixture.setup)
    fixture.validate(sim)
    io.stdout:write("replay ok ", fixture.name, "\n")
end

local function tacticalReplayState()
    return TacticsState.new({
        defaultAp = 8,
        board = {
            width = 5,
            height = 3,
            tiles = {
                ["3:2"] = { kind = "route_machine", destructibleHp = 2, coverEdges = { west = "half" } },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 2, hp = 8 },
            { id = "lamplighter", side = "player", x = 5, y = 2, hp = 5 },
            { id = "custodian", side = "enemy", x = 2, y = 2, hp = 4 },
        },
        objectives = {
            { id = "route_machine", x = 3, y = 2, integrity = 2, evacuateAt = { x = 5, y = 2 } },
        },
    })
end

local tacticalFrames = {
    { tick = 0, command = TacticsState.commands.attack("warden", "custodian", 1) },
    { tick = 1, command = TacticsState.commands.shove("warden", "custodian", "south", 1, 1) },
    { tick = 2, command = TacticsState.commands.intent("custodian", { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 2 } }, damage = 1 }) },
    { tick = 3, command = TacticsState.commands.damageObjective("warden", "route_machine", 1, 0) },
    { tick = 4, command = TacticsState.commands.evacuate("lamplighter", "route_machine", 1) },
}

local function runTacticalReplay()
    local state = tacticalReplayState()
    for _, frame in ipairs(tacticalFrames) do
        state:apply(frame.command)
    end
    return state
end

local tacticalA = runTacticalReplay()
local tacticalB = runTacticalReplay()
expect(Serialize.encode(tacticalA:snapshot()) == Serialize.encode(tacticalB:snapshot()), "tactical replay command stream should be deterministic")
expect(tacticalA:objectiveStatus("route_machine") == "complete", "tactical replay should complete protect/evacuate objective")
io.stdout:write("tactics replay ok prototype_board\n")

io.stdout:write("replay fixtures passed: ", #fixtures, "\n")
