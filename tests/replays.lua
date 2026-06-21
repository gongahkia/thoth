package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Replay = require("src.game.replay")
local Simulation = require("src.game.simulation")
local Serialize = require("src.core.serialize")
local TacticsState = require("src.game.tactics.state")
local ClassCatalog = require("src.game.tactics.class_catalog")

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

local function tacticalIntentReplayState()
    return TacticsState.new({
        defaultAp = 4,
        board = { width = 8, height = 4 },
        units = {
            { id = "warden", side = "player", x = 1, y = 4, hp = 6 },
            { id = "exacter", side = "enemy", x = 2, y = 2 },
            { id = "categorist", side = "enemy", x = 3, y = 2 },
            { id = "redactor", side = "enemy", x = 4, y = 2 },
            { id = "fuser", side = "enemy", x = 5, y = 2 },
            { id = "conditional", side = "enemy", x = 6, y = 2 },
            { id = "decoy", side = "enemy", x = 7, y = 2 },
            { id = "boss", side = "enemy", x = 8, y = 2 },
        },
        objectives = {
            { id = "seal", x = 1, y = 1, integrity = 1, maxIntegrity = 3, evacuateAt = { x = 8, y = 4 } },
        },
    })
end

local tacticalIntentFrames = {
    { tick = 0, command = TacticsState.commands.intent("exacter", { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 4 } }, damage = 1, escalation = { after = 1, damageDelta = 1 } }) },
    { tick = 1, command = TacticsState.commands.intent("categorist", { mode = "category", category = "repair", effect = "patch_seal" }) },
    { tick = 2, command = TacticsState.commands.intent("redactor", { mode = "hiddenFootprint", category = "redacted", targetTiles = { { x = 2, y = 4 } }, revealActions = { "inspect_intent" } }) },
    { tick = 3, command = TacticsState.commands.intent("fuser", { mode = "fuse", category = "attack", countdown = 2, targetTiles = { { x = 1, y = 4 } }, trigger = { kind = "damage", damage = 1 } }) },
    { tick = 4, command = TacticsState.commands.tickIntentFuse("fuser") },
    { tick = 5, command = TacticsState.commands.intent("conditional", {
        mode = "conditional",
        branches = {
            { condition = { kind = "targetMoved", target = "warden" }, intent = { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 4 } }, damage = 2 }, trigger = { kind = "damage", target = "warden", damage = 2 } },
            { condition = "otherwise", intent = { mode = "exact", category = "repair", targetTiles = { { x = 1, y = 1 } }, effect = "repair_seal" }, trigger = { kind = "repairObjective", objective = "seal", amount = 1 } },
        },
    }) },
    { tick = 6, command = TacticsState.commands.resolveConditionalIntent("conditional") },
    { tick = 7, command = TacticsState.commands.intent("decoy", { mode = "decoy", decoy = { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 4 } }, damage = 4 }, actual = { mode = "exact", category = "guard", targetTiles = { { x = 7, y = 2 } }, damage = 0 }, counterplay = { "exposeWeakPoint" } }) },
    { tick = 8, command = TacticsState.commands.interruptIntent("decoy", "exposeWeakPoint") },
    { tick = 9, command = TacticsState.commands.intent("boss", { mode = "bossStage", category = "destroy", stage = 1, stageCount = 2, mask = "front", targetTiles = { { x = 3, y = 4 } }, masks = { { revealRotation = 1, weakPoint = "rear", revealed = true, stage = 2, targetTiles = { { x = 4, y = 4 } } } } }) },
    { tick = 10, command = TacticsState.commands.advanceBossIntentMask("boss", { rotation = 1, weakPoint = "rear" }) },
    { tick = 11, command = TacticsState.commands.advanceIntentPressure("exacter", "ignored") },
}

local function runTacticalIntentReplay()
    local state = tacticalIntentReplayState()
    for _, frame in ipairs(tacticalIntentFrames) do
        state:apply(frame.command)
    end
    return state
end

local intentA = runTacticalIntentReplay()
local intentB = runTacticalIntentReplay()
expect(Serialize.encode(intentA:snapshot()) == Serialize.encode(intentB:snapshot()), "intent replay command stream should be deterministic")
expect(intentA:intentPreview("exacter").damage == 2, "intent replay should escalate exact intent")
expect(intentA:intentPreview("categorist").categoryOnly, "intent replay should keep category intent")
expect(intentA:intentPreview("redactor", { revealAction = "inspect_intent" }).targetTiles[1].x == 2, "intent replay should reveal redacted footprint")
expect(intentA:intentPreview("fuser").countdown == 1, "intent replay should tick fuse")
expect(intentA:intentPreview("conditional") == nil and intentA:objective("seal").integrity == 2, "intent replay should resolve conditional branch")
expect(intentA:intentPreview("decoy").decoyRevealed, "intent replay should reveal decoy")
expect(intentA:intentPreview("boss").revealed and intentA:intentPreview("boss").targetTiles[1].x == 4, "intent replay should reveal boss mask")
io.stdout:write("tactics replay ok intent_classes\n")

local function tacticalWardenReplayState()
    return TacticsState.new({
        defaultAp = 4,
        board = { width = 4, height = 3 },
        units = {
            { id = "warden", side = "player", x = 1, y = 2, hp = 10, class = "warden" },
            { id = "scribe", side = "enemy", x = 2, y = 2, hp = 4 },
        },
        objectives = {
            { id = "shelf", kind = "protect_archive_shelf", x = 3, y = 2, integrity = 1, maxIntegrity = 3, evacuateAt = { x = 4, y = 2 } },
        },
    })
end

local tacticalWardenFrames = {
    { tick = 0, command = TacticsState.commands.spend("warden", 1, "brace_pavise") },
    { tick = 1, command = TacticsState.commands.shove("warden", "scribe", "north", 1, 1, 1) },
    { tick = 2, command = TacticsState.commands.repairObjective("warden", "shelf", 2, 1) },
}

local function runTacticalWardenReplay()
    local state = tacticalWardenReplayState()
    for _, frame in ipairs(tacticalWardenFrames) do
        state:apply(frame.command)
    end
    return state
end

local wardenFixture = ClassCatalog.class("warden").replayFixture
local wardenA = runTacticalWardenReplay()
local wardenB = runTacticalWardenReplay()
expect(wardenFixture == "warden_brace_line", "Warden replay fixture should be registered")
expect(Serialize.encode(wardenA:snapshot()) == Serialize.encode(wardenB:snapshot()), "Warden replay fixture should be deterministic")
expect(wardenA.units.scribe.y == 1 and wardenA:objective("shelf").integrity == 3, "Warden replay should shove and repair")
io.stdout:write("tactics replay ok ", wardenFixture, "\n")

local function tacticalDuelistReplayState()
    return TacticsState.new({
        defaultAp = 5,
        board = { width = 5, height = 3 },
        units = {
            { id = "duelist", side = "player", x = 1, y = 2, hp = 8, class = "duelist" },
            { id = "bailiff", side = "enemy", x = 4, y = 2, hp = 5 },
        },
    })
end

local tacticalDuelistFrames = {
    { tick = 0, command = TacticsState.commands.dash("duelist", "east", 2, 1) },
    { tick = 1, command = TacticsState.commands.attack("duelist", "bailiff", 3, 1) },
    { tick = 2, command = TacticsState.commands.swap("duelist", "bailiff", 1) },
}

local function runTacticalDuelistReplay()
    local state = tacticalDuelistReplayState()
    for _, frame in ipairs(tacticalDuelistFrames) do
        state:apply(frame.command)
    end
    return state
end

local duelistFixture = ClassCatalog.class("duelist").replayFixture
local duelistA = runTacticalDuelistReplay()
local duelistB = runTacticalDuelistReplay()
expect(duelistFixture == "duelist_flank_dash", "Duelist replay fixture should be registered")
expect(Serialize.encode(duelistA:snapshot()) == Serialize.encode(duelistB:snapshot()), "Duelist replay fixture should be deterministic")
expect(duelistA.units.duelist.x == 4 and duelistA.units.bailiff.hp == 2, "Duelist replay should dash, strike, and swap")
io.stdout:write("tactics replay ok ", duelistFixture, "\n")

local function tacticalApothecaryReplayState()
    return TacticsState.new({
        defaultAp = 4,
        board = { width = 4, height = 3 },
        units = {
            { id = "mender", side = "player", x = 1, y = 2, hp = 8, class = "mender" },
        },
        objectives = {
            { id = "patient", kind = "repair_cover", x = 2, y = 2, integrity = 1, maxIntegrity = 3, evacuateAt = { x = 4, y = 2 } },
        },
    })
end

local tacticalApothecaryFrames = {
    { tick = 0, command = TacticsState.commands.obscurant("mender", 2, 2, "smoke", 2, 1) },
    { tick = 1, command = TacticsState.commands.repairObjective("mender", "patient", 2, 1) },
    { tick = 2, command = TacticsState.commands.tickObscurants() },
}

local function runTacticalApothecaryReplay()
    local state = tacticalApothecaryReplayState()
    for _, frame in ipairs(tacticalApothecaryFrames) do
        state:apply(frame.command)
    end
    return state
end

local apothecaryFixture = ClassCatalog.class("mender").replayFixture
local apothecaryA = runTacticalApothecaryReplay()
local apothecaryB = runTacticalApothecaryReplay()
expect(apothecaryFixture == "apothecary_smoke_triage", "Apothecary replay fixture should be registered")
expect(Serialize.encode(apothecaryA:snapshot()) == Serialize.encode(apothecaryB:snapshot()), "Apothecary replay fixture should be deterministic")
expect(apothecaryA:objective("patient").integrity == 3, "Apothecary replay should smoke and repair")
io.stdout:write("tactics replay ok ", apothecaryFixture, "\n")

local function tacticalArcanistReplayState()
    return TacticsState.new({
        defaultAp = 3,
        board = {
            width = 4,
            height = 3,
            tiles = {
                ["1:1"] = { revealed = false, revealClasses = { "arcanist" }, weakPoint = "seal_glyph" },
            },
        },
        units = {
            { id = "arcanist", side = "player", x = 1, y = 3, hp = 6, class = "arcanist" },
            { id = "redactor", side = "enemy", x = 3, y = 2, hp = 4 },
        },
    })
end

local tacticalArcanistFrames = {
    { tick = 0, command = TacticsState.commands.intent("redactor", {
        mode = "hiddenFootprint",
        category = "redacted",
        targetTiles = { { x = 1, y = 3 } },
        revealClasses = { "arcanist" },
    }) },
    { tick = 1, command = TacticsState.commands.classReveal("arcanist", { revealAction = "read_seal" }, 1) },
}

local function runTacticalArcanistReplay()
    local state = tacticalArcanistReplayState()
    for _, frame in ipairs(tacticalArcanistFrames) do
        state:apply(frame.command)
    end
    return state
end

local arcanistFixture = ClassCatalog.class("arcanist").replayFixture
local arcanistA = runTacticalArcanistReplay()
local arcanistB = runTacticalArcanistReplay()
expect(arcanistFixture == "arcanist_seal_read", "Arcanist replay fixture should be registered")
expect(Serialize.encode(arcanistA:snapshot()) == Serialize.encode(arcanistB:snapshot()), "Arcanist replay fixture should be deterministic")
expect(arcanistA:intentPreview("redactor").revealed and arcanistA:tileAt(1, 1).weakPointRevealed, "Arcanist replay should reveal intent and seal")
io.stdout:write("tactics replay ok ", arcanistFixture, "\n")

local function tacticalThiefReplayState()
    return TacticsState.new({
        defaultAp = 5,
        board = { width = 4, height = 3 },
        units = {
            { id = "harrier", side = "player", x = 1, y = 2, hp = 7, class = "harrier" },
        },
        cargo = {
            { id = "ledger", kind = "ledger", x = 2, y = 2, integrity = 1 },
        },
        objectives = {
            { id = "ledger_extract", kind = "extract_ledger", x = 4, y = 2, integrity = 1, evacuateAt = { x = 4, y = 2 } },
        },
    })
end

local tacticalThiefFrames = {
    { tick = 0, command = TacticsState.commands.carryCargo("harrier", "ledger", 1) },
    { tick = 1, command = TacticsState.commands.move("harrier", "east") },
    { tick = 2, command = TacticsState.commands.move("harrier", "east") },
    { tick = 3, command = TacticsState.commands.extractObjective("harrier", "ledger_extract", 1) },
}

local function runTacticalThiefReplay()
    local state = tacticalThiefReplayState()
    for _, frame in ipairs(tacticalThiefFrames) do
        state:apply(frame.command)
    end
    return state
end

local thiefFixture = ClassCatalog.class("harrier").replayFixture
local thiefA = runTacticalThiefReplay()
local thiefB = runTacticalThiefReplay()
expect(thiefFixture == "thief_route_lift", "Thief replay fixture should be registered")
expect(Serialize.encode(thiefA:snapshot()) == Serialize.encode(thiefB:snapshot()), "Thief replay fixture should be deterministic")
expect(thiefA.units.harrier.carryingCargo == "ledger" and thiefA:objectiveStatus("ledger_extract") == "complete", "Thief replay should lift cargo and extract")
io.stdout:write("tactics replay ok ", thiefFixture, "\n")

io.stdout:write("replay fixtures passed: ", #fixtures, "\n")
