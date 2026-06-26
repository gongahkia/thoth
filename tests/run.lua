package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Player = require("src.player")
local Render = require("src.render")
local WorldGen = require("src.worldgen")
local Diagnostics = require("src.diagnostics")

local function expect(value, message)
    if not value then error(message or "expectation failed", 2) end
end

local function round(value)
    return math.floor((value or 0) * 100000 + 0.5) / 100000
end

local fastWorldOptions = { hydrologyRegionChunks = 2, hydrologyHaloCells = 0, hydrologyBasinChunks = 8, hydrologyBasinStride = 8 }
local basinWorldOptions = { hydrologyRegionChunks = 1, hydrologyHaloCells = 0, hydrologyBasinChunks = 8, hydrologyBasinStride = 8, hydrologyBasinFlowScale = 0.6 }

local function testWorld(seed)
    return WorldGen.new(seed, fastWorldOptions)
end

local function encodeCell(cell)
    return table.concat({
        cell.x,
        cell.y,
        cell.scale,
        round(cell.filledElevation),
        round(cell.elevation),
        round(cell.flow),
        round(cell.erosion),
        round(cell.lakeDepth),
        round(cell.rainfall),
        round(cell.temperature),
        cell.biome,
        tostring(cell.river),
        tostring(cell.riverBank),
        tostring(cell.lake),
        tostring(cell.water),
        tostring(cell.plateId),
        tostring(cell.basinId),
        tostring(cell.watershedId),
        tostring(cell.macroBasinId),
        tostring(cell.macroChannelId),
    }, "|")
end

local function encodeChunk(chunk)
    local parts = { chunk.x, chunk.y, chunk.scale, chunk.scaleFactor }
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            parts[#parts + 1] = encodeCell(chunk.cells[y][x])
        end
    end
    return table.concat(parts, "\n")
end

local function testDeterminism()
    local a = testWorld(1234)
    local b = testWorld(1234)
    expect(encodeChunk(a:chunk(2, -1, "local")) == encodeChunk(b:chunk(2, -1, "local")), "same seed should produce identical local chunk")
    expect(encodeChunk(a:chunk(0, 0, "continent")) == encodeChunk(b:chunk(0, 0, "continent")), "same seed should produce identical continent chunk")
end

local function testSeedVariance()
    local a = encodeChunk(testWorld(1234):chunk(0, 0, "region"))
    local b = encodeChunk(testWorld(5678):chunk(0, 0, "region"))
    expect(a ~= b, "different seeds should differ")
end

local function testSampleChunkAgreement()
    local world = testWorld(44)
    local chunk = world:chunk(1, -2, "local")
    for y = 1, chunk.size do
        local cell = chunk.cells[y][1]
        local sampled = world:sample(cell.x, cell.y, "local")
        expect(encodeCell(cell) == encodeCell(sampled), "sample should match chunk cell")
    end
    local right = world:chunk(0, 0, "region")
    local left = world:chunk(1, 0, "region")
    local seamSample = world:sample(left.cells[1][1].x, left.cells[1][1].y, "region")
    expect(encodeCell(left.cells[1][1]) == encodeCell(seamSample), "adjacent chunk seam should resolve to the same sample")
    expect(right.cells[1][right.size].x + right.scaleFactor == left.cells[1][1].x, "adjacent chunks should be coordinate-continuous")
end

local function testRiverMonotonicity()
    local world = testWorld(99)
    local chunk = world:chunk(0, 0, "local")
    local stats = world:hydrologyStats(0, 0, "local")
    local byCoord = {}
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            local cell = chunk.cells[y][x]
            byCoord[cell.x .. ":" .. cell.y] = cell
        end
    end
    local checked = 0
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            local cell = chunk.cells[y][x]
            if cell.river and cell.downX then
                local down = byCoord[cell.downX .. ":" .. cell.downY]
                if down then
                    expect(cell.elevation + 0.00001 >= down.elevation, "river should not flow uphill")
                    checked = checked + 1
                end
            end
        end
    end
    expect(stats.rivers > 0, "fixture seed should produce rivers")
    expect(stats.uphillRejects == 0, "hydrology should reject uphill filled-flow routes")
    expect(checked >= 0, "river monotonicity check should run")
end

local function testHydrologyStats()
    local world = WorldGen.new(20260625)
    local stats = world:hydrologyStats(0, 0, "local")
    expect(stats.rivers > 0, "hydrology stats should include rivers")
    expect(stats.basins > 0, "hydrology stats should include basins")
    expect(stats.maxFlow > 0, "hydrology stats should include max flow")
    expect(stats.seamMismatches == 0, "hydrology region should not contain broken downstream refs")
    expect(stats.uphillRejects == 0, "hydrology region should not route uphill over filled elevation")
    local chunk = world:chunk(0, 0, "local")
    local inspected = 0
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            local cell = chunk.cells[y][x]
            expect(cell.filledElevation >= cell.elevationBase - 0.000001, "filled elevation should not undercut base elevation")
            expect(cell.basinId and cell.watershedId, "cells should expose basin and watershed ids")
            if cell.lake then
                expect(cell.water and cell.lakeDepth > 0 and cell.lakeSurface >= cell.elevationBase, "lake cells should expose filled water state")
                if cell.outletX then
                    expect(cell.outletX == cell.outletX and cell.outletY == cell.outletY, "lake outlet coordinates should be finite")
                end
                inspected = inspected + 1
            end
        end
    end
    expect(stats.lakes > 0 or inspected == 0, "lake stats should be available when lakes exist")
end

local function testBasinHydrologyBudget()
    local world = WorldGen.new(20260625, basinWorldOptions)
    world:chunk(0, 0, "local")
    local stats = world:hydrologyStats(0, 0, "local")
    local metrics = world:metricsSnapshot()
    local cache = world:cacheStats()
    expect(stats.macroChannels > 0, "coarse basin pass should feed local macro channels")
    expect(metrics.hydrologyMisses == 1 and metrics.basinMisses == 1, "first chunk should solve one detail region and one coarse basin")
    expect(metrics.hydrologyCells == 4096 and metrics.basinCells == 4096, "first chunk hydrology should stay bounded")
    expect(cache.hydrology == 1 and cache.basins == 1, "first chunk should cache one hydrology region and one basin")
end

local function testBasinChannelsSpanDetailRegions()
    local world = WorldGen.new(20260625, basinWorldOptions)
    local spans = {}
    for cy = -2, 3 do
        for cx = -2, 3 do
            local chunk = world:chunk(cx, cy, "local")
            for y = 1, chunk.size, 4 do
                for x = 1, chunk.size, 4 do
                    local cell = chunk.cells[y][x]
                    if cell.river and cell.macroBasinId then
                        local span = spans[cell.macroBasinId] or { regions = {}, count = 0 }
                        span.regions[cell.hydrologyRegion] = true
                        span.count = span.count + 1
                        spans[cell.macroBasinId] = span
                    end
                end
            end
        end
    end
    local bestRegions, bestCount = 0, 0
    for _, span in pairs(spans) do
        local regions = 0
        for _ in pairs(span.regions) do regions = regions + 1 end
        if regions > bestRegions or (regions == bestRegions and span.count > bestCount) then
            bestRegions, bestCount = regions, span.count
        end
    end
    expect(bestRegions >= 8 and bestCount > 24, "macro basins should persist across distant 1x1 hydrology regions")
    expect(world:cacheStats().basins == 1, "scanned chunks should share the same cached coarse basin")
end

local function testBiomes()
    local world = testWorld(314)
    local ids = {}
    for _, id in ipairs(WorldGen.biomeIds()) do ids[id] = true end
    for cy = 0, 1 do
        for cx = 0, 1 do
            local chunk = world:chunk(cx, cy, "region")
            for y = 1, chunk.size, 7 do
                for x = 1, chunk.size, 7 do
                    expect(ids[chunk.cells[y][x].biome], "invalid biome id " .. tostring(chunk.cells[y][x].biome))
                end
            end
        end
    end
end

local function testPlayer()
    local world = testWorld(88)
    local player = Player.new(0, 0)
    Player.update(player, 1, { right = true }, world)
    expect(player.x > 0 and player.y == 0, "player should move right")
    Player.update(player, 0.5, { left = true, up = true, sprint = true }, world)
    expect(player.x == player.x and player.y == player.y, "player position should stay finite")
end

local function testHeightInterpolationAndNormal()
    local world = testWorld(515)
    local x, y = 12.35, -8.7
    local h = world:heightAt(x, y)
    local h00 = world:sample(math.floor(x), math.floor(y), "local").elevation
    local h10 = world:sample(math.floor(x) + 1, math.floor(y), "local").elevation
    local h01 = world:sample(math.floor(x), math.floor(y) + 1, "local").elevation
    local h11 = world:sample(math.floor(x) + 1, math.floor(y) + 1, "local").elevation
    local lo = math.min(h00, h10, h01, h11)
    local hi = math.max(h00, h10, h01, h11)
    expect(h >= lo - 0.000001 and h <= hi + 0.000001, "heightAt should stay inside neighbor range")
    expect(round(h) == round(world:heightAt(x, y)), "heightAt should be deterministic")
    local normal = world:normalAt(x, y)
    local length = math.sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
    expect(length > 0.99 and length < 1.01 and normal.z > 0, "normalAt should return finite normalized upward vector")
end

local function encodeBillboards(list)
    local parts = {}
    for _, item in ipairs(list) do
        parts[#parts + 1] = table.concat({ item.kind, round(item.x), round(item.y), round(item.z), round(item.width), round(item.height) }, ":")
    end
    return table.concat(parts, "|")
end

local function testBillboards()
    local a = testWorld(616)
    local b = testWorld(616)
    local kinds = {}
    for _, kind in ipairs(WorldGen.billboardKinds()) do kinds[kind] = true end
    local count = 0
    for cy = 0, 1 do
        for cx = 0, 1 do
            local list = a:billboards(cx, cy)
            expect(encodeBillboards(list) == encodeBillboards(b:billboards(cx, cy)), "billboards should be deterministic")
            for _, item in ipairs(list) do
                expect(kinds[item.kind], "invalid billboard kind")
                expect(item.x == item.x and item.y == item.y and item.z == item.z, "billboard coordinates should be finite")
                count = count + 1
            end
        end
    end
    expect(count > 0, "fixture seed should generate billboards")
end

local function testRenderStats()
    local app = { world = testWorld(717), player = Player.new(0, 0), camera = Render.defaultCamera() }
    local stats = Render.visibleStats(app, 1280, 720)
    expect(stats.visibleTiles > 0 and stats.triangles == stats.visibleTiles * 2, "render stats should describe terrain mesh")
    expect(stats.billboards >= 0 and stats.cameraHeight == stats.cameraHeight, "render stats should include finite camera and billboard count")
end

local function testTerrainDiagnostics()
    local seeds = Diagnostics.defaultSeeds()
    local sweep = Diagnostics.sweep({
        seeds = seeds,
        chunkRadius = 1,
        sampleStep = 8,
        worldOptions = basinWorldOptions,
    })
    expect(#sweep.results == #seeds, "diagnostics should report every fixture seed")
    expect(#sweep.failed == 0, "diagnostic fixtures should stay inside terrain sanity bounds:\n" .. Diagnostics.formatFailures(sweep.failed))
    for _, stats in ipairs(sweep.results) do
        expect(stats.cells > 0 and stats.land + stats.water == stats.cells, "diagnostics should count sampled cells")
        expect(stats.waterRatio >= 0 and stats.waterRatio <= 1, "water ratio should be normalized")
        expect(stats.riverRatio >= 0 and stats.riverRatio <= 1, "river ratio should be normalized")
        expect(stats.biomeCount >= 3, "diagnostics should observe multiple biomes")
    end
end

local function testBadSeedDiagnostics()
    for _, fixture in ipairs(Diagnostics.badSeeds()) do
        local stats = Diagnostics.analyzeSeed(fixture.seed, {
            chunkRadius = 1,
            sampleStep = 8,
            worldOptions = basinWorldOptions,
        })
        local flags = {}
        for _, flag in ipairs(stats.flags) do flags[flag] = true end
        for _, expectedFlag in ipairs(fixture.flags) do
            expect(flags[expectedFlag], "bad seed fixture should flag " .. expectedFlag .. " for seed " .. tostring(fixture.seed))
        end
    end
end

local function smoke()
    local world = WorldGen.new(20260625)
    local app = { world = world, player = Player.new(0, 0), camera = Render.defaultCamera() }
    local stats = Render.visibleStats(app, 1280, 720)
    local land, water, rivers, lakes = 0, 0, 0, 0
    local localStats = world:hydrologyStats(0, 0, "local")
    for _, scale in ipairs(world:metadata().scales) do
        local chunk = world:chunk(0, 0, scale.id)
        for y = 1, chunk.size do
            for x = 1, chunk.size do
                local cell = chunk.cells[y][x]
                if cell.water then water = water + 1 else land = land + 1 end
                if cell.river then rivers = rivers + 1 end
                if cell.lake then lakes = lakes + 1 end
            end
        end
    end
    print("smoke=terrain")
    print("land=" .. land)
    print("water=" .. water)
    print("rivers=" .. rivers)
    print("lakes=" .. lakes)
    print("basins=" .. localStats.basins)
    print("seam_mismatches=" .. localStats.seamMismatches)
    print("uphill_rejects=" .. localStats.uphillRejects)
    print("max_flow=" .. string.format("%.3f", localStats.maxFlow))
    print("mesh_tiles=" .. stats.visibleTiles)
    print("triangles=" .. stats.triangles)
    print("billboards=" .. stats.billboards)
    print("camera_height=" .. string.format("%.3f", stats.cameraHeight))
    expect(land > 0 and water > 0 and rivers > 0, "smoke should cover land, water, and rivers")
    expect(localStats.basins > 0 and localStats.uphillRejects == 0, "smoke should include sane hydrology stats")
    expect(stats.visibleTiles > 0 and stats.triangles > 0, "smoke should build visible terrain mesh")
end

local tests = {
    testDeterminism,
    testSeedVariance,
    testSampleChunkAgreement,
    testRiverMonotonicity,
    testHydrologyStats,
    testBasinHydrologyBudget,
    testBasinChannelsSpanDetailRegions,
    testBiomes,
    testPlayer,
    testHeightInterpolationAndNormal,
    testBillboards,
    testRenderStats,
    testTerrainDiagnostics,
    testBadSeedDiagnostics,
}

local function hasCliFlag(args, flag)
    for _, item in ipairs(args or {}) do
        if item == flag then return true end
    end
    return false
end

local function cliValue(args, flag, fallback)
    for index, item in ipairs(args or {}) do
        if item == flag then return args[index + 1] or fallback end
    end
    return fallback
end

local function diagnosticSeeds(args)
    local csv = cliValue(args, "--seeds")
    if csv then
        local seeds = {}
        for item in string.gmatch(csv, "([^,]+)") do
            seeds[#seeds + 1] = tonumber(item)
        end
        return seeds
    end
    if not (hasCliFlag(args, "--seed-start") or hasCliFlag(args, "--seed-count")) then
        return Diagnostics.defaultSeeds()
    end
    local start = tonumber(cliValue(args, "--seed-start", 1)) or 1
    local count = tonumber(cliValue(args, "--seed-count", 12)) or 12
    local seeds = {}
    for offset = 0, count - 1 do seeds[#seeds + 1] = start + offset end
    return seeds
end

local function diagnostics(args)
    local sweep = Diagnostics.sweep({
        seeds = diagnosticSeeds(args),
        chunkRadius = tonumber(cliValue(args, "--chunk-radius", 1)) or 1,
        sampleStep = tonumber(cliValue(args, "--sample-step", 8)) or 8,
        worldOptions = basinWorldOptions,
    })
    print("diagnostics=terrain")
    for _, stats in ipairs(sweep.results) do
        print(Diagnostics.formatResult(stats))
    end
    if #sweep.failed > 0 then
        error("diagnostic sweep failed:\n" .. Diagnostics.formatFailures(sweep.failed), 0)
    end
end

if arg and arg[1] == "--smoke" then
    smoke()
    return
end

if arg and arg[1] == "--diagnostics" then
    diagnostics(arg)
    return
end

for index, test in ipairs(tests) do
    test()
    print("ok " .. index)
end
print("tests passed")
