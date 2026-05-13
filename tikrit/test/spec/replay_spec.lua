local TestRunner = require("test_runner")

local describe = TestRunner.describe
local it = TestRunner.it

local originalLove = _G.love
local files = {}
local directories = {}

_G.love = {
    filesystem = {
        createDirectory = function(path)
            directories[path] = true
        end,
        getDirectoryItems = function(path)
            local items = {}
            for filePath in pairs(files) do
                local item = filePath:match("^" .. path .. "/(.+)$")
                if item then
                    table.insert(items, item)
                end
            end
            table.sort(items)
            return items
        end,
        read = function(path)
            return files[path]
        end,
        write = function(path, contents)
            files[path] = contents
            return true
        end,
        getInfo = function(path)
            if directories[path] or files[path] then
                return {type = directories[path] and "directory" or "file"}
            end
            return nil
        end,
    },
}

package.loaded["replay"] = nil
local Replay = require("replay")

describe("Replay", function()
    it("records and inspects survival replay context", function()
        Replay.init()
        Replay.startRecording(12345, "hard", {
            mode = "survival",
            isDaily = false,
            weather = {current = "snow"},
            timeOfDay = 12,
            player = {carryCapacity = 25},
        })
        Replay.recordKeyState("w", true, 0.1)
        Replay.recordKeyState("w", false, 0.6)
        Replay.stopRecording()
        TestRunner.assertTrue(Replay.save("spec_run"))

        local replay = Replay.inspect("spec_run")
        TestRunner.assertEqual(replay.version, "3.0")
        TestRunner.assertEqual(replay.difficulty, "stalker")
        TestRunner.assertEqual(replay.context.mode, "survival")
        TestRunner.assertEqual(replay.context.weather.current, "snow")
        TestRunner.assertEqual(replay.context.player.carryCapacity, 25)
    end)

    it("round-trips daily replay metadata", function()
        Replay.init()
        Replay.startRecording(20260325, "normal", {
            mode = "daily",
            isDaily = true,
            dailySeed = 20260325,
            weather = {current = "wind"},
        })
        Replay.recordKeyState("r", true, 0.2)
        Replay.recordKeyState("r", false, 0.4)
        Replay.stopRecording()
        TestRunner.assertTrue(Replay.save("daily_run"))

        local replay = Replay.inspect("daily_run")
        TestRunner.assertEqual(replay.difficulty, "voyageur")
        TestRunner.assertEqual(replay.context.mode, "daily")
        TestRunner.assertTrue(replay.context.isDaily)
        TestRunner.assertEqual(replay.context.dailySeed, 20260325)

        TestRunner.assertTrue(Replay.load("daily_run"))
        TestRunner.assertTrue(Replay.startPlayback())
        Replay.update(0.2)
        local first = Replay.getNextInput()
        TestRunner.assertEqual(first.key, "r")
    end)

    it("round-trips layered endgame replay context", function()
        Replay.init()
        Replay.startRecording(99, "stalker", {
            mode = "survival",
            currentDepth = 1,
            endgameActivated = true,
            weatherStation = {
                activated = true,
                depth = 1,
            },
            runtimeObjects = {
                fires = 1,
                traps = 2,
                carcasses = 3,
                openedResourceNodes = 4,
                unopenedResourceNodes = 5,
                fishingSpots = 6,
                climbNodes = 7,
                mapNodes = 8,
                openedGates = 9,
                resolvedNPCs = 10,
            },
            tileSimulation = {
                snowCoverTiles = 11,
                iceStateTiles = 12,
                shelterWearTiles = 13,
                warmthPocketTiles = 14,
                thermalWarmthTiles = 15,
            },
            player = {
                depth = 1,
            },
        })
        Replay.recordKeyState("e", true, 0.1)
        Replay.stopRecording()
        TestRunner.assertTrue(Replay.save("endgame_run"))

        local replay = Replay.inspect("endgame_run")
        TestRunner.assertEqual(replay.context.currentDepth, 1)
        TestRunner.assertTrue(replay.context.endgameActivated)
        TestRunner.assertTrue(replay.context.weatherStation.activated)
        TestRunner.assertEqual(replay.context.weatherStation.depth, 1)
        TestRunner.assertEqual(replay.context.runtimeObjects.fires, 1)
        TestRunner.assertEqual(replay.context.runtimeObjects.traps, 2)
        TestRunner.assertEqual(replay.context.runtimeObjects.carcasses, 3)
        TestRunner.assertEqual(replay.context.runtimeObjects.openedResourceNodes, 4)
        TestRunner.assertEqual(replay.context.runtimeObjects.unopenedResourceNodes, 5)
        TestRunner.assertEqual(replay.context.runtimeObjects.fishingSpots, 6)
        TestRunner.assertEqual(replay.context.runtimeObjects.climbNodes, 7)
        TestRunner.assertEqual(replay.context.runtimeObjects.mapNodes, 8)
        TestRunner.assertEqual(replay.context.runtimeObjects.openedGates, 9)
        TestRunner.assertEqual(replay.context.runtimeObjects.resolvedNPCs, 10)
        TestRunner.assertEqual(replay.context.tileSimulation.snowCoverTiles, 11)
        TestRunner.assertEqual(replay.context.tileSimulation.iceStateTiles, 12)
        TestRunner.assertEqual(replay.context.tileSimulation.shelterWearTiles, 13)
        TestRunner.assertEqual(replay.context.tileSimulation.warmthPocketTiles, 14)
        TestRunner.assertEqual(replay.context.tileSimulation.thermalWarmthTiles, 15)
        TestRunner.assertEqual(replay.context.player.depth, 1)
    end)

    it("round-trips supported depth values and defensive context fields", function()
        for _, depth in ipairs({-1, 0, 1}) do
            Replay.init()
            Replay.startRecording(200 + depth, "stalker", {
                currentDepth = depth,
                player = {depth = depth},
                zeroValue = 0,
                emptyValue = "",
                unknown_field = "kept",
                nested_unknown = {
                    child_value = true,
                },
            })
            Replay.recordKeyState("e", true, 0.1)
            Replay.stopRecording()
            local filename = "depth_" .. tostring(depth):gsub("-", "neg")
            TestRunner.assertTrue(Replay.save(filename))

            local replay = Replay.inspect(filename)
            TestRunner.assertEqual(replay.context.currentDepth, depth)
            TestRunner.assertEqual(replay.context.player.depth, depth)
            TestRunner.assertEqual(replay.context.zeroValue, 0)
            TestRunner.assertEqual(replay.context.emptyValue, "")
            TestRunner.assertEqual(replay.context.unknown_field, "kept")
            TestRunner.assertTrue(replay.context.nested_unknown.child_value)
        end
    end)

    it("plays back key state changes in timestamp order", function()
        Replay.init()
        Replay.startRecording(7, "voyageur")
        Replay.recordKeyState("f", true, 0.1)
        Replay.recordKeyState("f", false, 0.2)
        Replay.stopRecording()
        Replay.save("timing")

        TestRunner.assertTrue(Replay.load("timing"))
        TestRunner.assertTrue(Replay.startPlayback())

        Replay.update(0.1)
        local first = Replay.getNextInput()
        TestRunner.assertEqual(first.type, "keydown")
        TestRunner.assertEqual(first.key, "f")

        Replay.update(0.1)
        local second = Replay.getNextInput()
        TestRunner.assertEqual(second.type, "keyup")
        TestRunner.assertEqual(second.key, "f")
    end)

    it("loads legacy difficulty aliases as canonical names", function()
        Replay.init()
        files["replays/legacy_alias.txt"] = table.concat({
            "VERSION:3.0",
            "SEED:42",
            "DIFFICULTY:normal",
            "DATE:2026-03-25 09:00:00",
            "DURATION:1.0",
            "TOTAL_INPUTS:1",
            "CONTEXT:mode=survival",
            "INPUTS:",
            "keydown|e|0.1000",
        }, "\n")

        local replay = Replay.inspect("legacy_alias.txt")
        TestRunner.assertEqual(replay.difficulty, "voyageur")
    end)
end)

_G.love = originalLove
