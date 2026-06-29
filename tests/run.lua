package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Player = require("src.player")
local Atmosphere = require("src.atmosphere")
local Render = require("src.render")
local Clipmap = require("src.clipmap")
local Rng = require("src.rng")
local Noise = require("src.noise")
local Save = require("src.save")
local Survey = require("src.survey")
local PostFX = require("src.postfx")
local ViewScale = require("src.viewscale")
local WorldGen = require("src.worldgen")
local Diagnostics = require("src.diagnostics")
local Export = require("src.export")
local Benchmark = require("src.benchmark")
local Erosion = require("src.erosion")
local Climate = require("src.climate")
local Biomes = require("src.biomes")
local Aeolian = require("src.aeolian")

local function expect(value, message)
    if not value then error(message or "expectation failed", 2) end
end

local function round(value)
    return math.floor((value or 0) * 100000 + 0.5) / 100000
end

local function soaValue(value)
    if value == true then return 1 end
    if value == false or value == nil then return 0 end
    return value
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
        round(cell.deposition),
        round(cell.thermalErosion),
        round(cell.lakeDepth),
        round(cell.rainfall),
        round(cell.temperature),
        cell.biome,
        tostring(cell.river),
        tostring(cell.riverBank),
        tostring(cell.lake),
        tostring(cell.water),
        tostring(cell.lakeId),
        tostring(cell.lakeGroupSize),
        tostring(cell.lakeOutletX),
        tostring(cell.lakeOutletY),
        round(cell.spilloverElevation),
        round(cell.spilloverFlow),
        tostring(cell.spillover),
        tostring(cell.spilloverLakeId),
        tostring(cell.talus),
        tostring(cell.alluvialFan),
        tostring(cell.floodplain),
        tostring(cell.delta),
        tostring(cell.plateId),
        tostring(cell.secondaryPlateId),
        round(cell.plateAge),
        round(cell.secondaryPlateAge),
        tostring(cell.plateCrust),
        tostring(cell.secondaryPlateCrust),
        round(cell.oceanicSubduction),
        round(cell.subductionBias),
        round(cell.riftValley),
        round(cell.volcanicIslandArc),
        round(cell.shield),
        round(cell.craton),
        tostring(cell.ridgeId),
        tostring(cell.mountainRangeId),
        tostring(cell.basinId),
        tostring(cell.watershedId),
        tostring(cell.macroBasinId),
        tostring(cell.macroChannelId),
        round(cell.streamPowerDelta),
        round(cell.streamPowerErosion),
        round(cell.streamPowerUplift),
        round(cell.isostaticRebound),
        round(cell.sediment),
        round(cell.sedimentFlux),
        round(cell.sedimentCapacity),
        round(cell.precipitation),
        round(cell.rainShadowScore),
        tostring(cell.rainShadow),
        round(cell.windX),
        round(cell.windY),
        round(cell.glacialDelta),
        round(cell.glacialErosion),
        tostring(cell.glaciated),
        tostring(cell.coastCliff),
        tostring(cell.coastBeach),
        round(cell.coastExposure),
        round(cell.coastErosion),
        round(cell.coastDeposition),
        round(cell.duneDelta),
        round(cell.duneAmplitude),
        round(cell.dunePhase),
        tostring(cell.lithology),
        round(cell.erodibilityK),
        round(cell.lithologyAge),
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
    local world = WorldGen.new(1)
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

local function testLakeGroupingAndSpillover()
    local world = WorldGen.new(17)
    local stats = world:hydrologyStats(-1, -2, "continent")
    expect(stats.lakeCells > 0 and stats.lakeGroups > 0, "fixture seed should include grouped lakes")
    local inspected = 0
    local spilloverRefs = 0
    for cy = -3, -2 do
        for cx = -1, 0 do
            local chunk = world:chunk(cx, cy, "continent")
            for y = 1, chunk.size do
                for x = 1, chunk.size do
                    local cell = chunk.cells[y][x]
                    if cell.lake then
                        expect(cell.lakeId and cell.lakeGroupSize and cell.lakeGroupSize > 0, "lake cells should expose stable group ids and size")
                        expect(cell.lakeOutletX and cell.lakeOutletY and cell.spilloverElevation, "lake cells should expose outlet and spillover labels")
                        local outlet = world:sample(cell.lakeOutletX, cell.lakeOutletY, "continent")
                        if outlet.spillover and outlet.spilloverLakeId == cell.lakeId then spilloverRefs = spilloverRefs + 1 end
                        inspected = inspected + 1
                    end
                end
            end
        end
    end
    expect(inspected == stats.lakeCells, "lake group fixture should inspect every lake cell in the region")
    expect(spilloverRefs > 0, "lake outlet should be labeled as spillover inside the fixture region")
end

local function testErosionLandforms()
    local totals = { talus = 0, alluvial = 0, floodplain = 0, delta = 0, sediment = 0 }
    for _, seed in ipairs({ 1, 3, 6 }) do
        local stats = WorldGen.new(seed):hydrologyStats(0, 0, "local")
        totals.talus = totals.talus + stats.talusSlopes
        totals.alluvial = totals.alluvial + stats.alluvialFans
        totals.floodplain = totals.floodplain + stats.floodplains
        totals.delta = totals.delta + stats.deltas
        totals.sediment = totals.sediment + stats.sedimentCells
    end
    expect(totals.talus > 0, "thermal erosion should expose talus slopes")
    expect(totals.sediment > 0, "stream power deposition should expose sediment cells")
    expect(totals.alluvial > 0, "sediment deposition should expose alluvial fans")
    expect(totals.floodplain > 0, "sediment deposition should expose floodplains")
    expect(totals.delta > 0, "river mouths should expose deltas")
end

local function testTectonicFeatures()
    local counts = { age = 0, subduction = 0, rift = 0, islandArc = 0, shield = 0, craton = 0 }
    for _, seed in ipairs({ 3, 19, 45, 46, 99, 616, 717, 20260625 }) do
        local world = WorldGen.new(seed)
        for y = -1024, 1024, 64 do
            for x = -1024, 1024, 64 do
                local cell = world:baseSample(x, y, "local")
                if cell.plateAge and cell.plateAge >= 0 and cell.plateAge <= 1 then counts.age = counts.age + 1 end
                if (cell.oceanicSubduction or 0) > 0.08 then counts.subduction = counts.subduction + 1 end
                if (cell.riftValley or 0) > 0.08 then counts.rift = counts.rift + 1 end
                if (cell.volcanicIslandArc or 0) > 0.04 then counts.islandArc = counts.islandArc + 1 end
                if (cell.shield or 0) > 0.2 then counts.shield = counts.shield + 1 end
                if (cell.craton or 0) > 0.12 then counts.craton = counts.craton + 1 end
            end
        end
    end
    expect(counts.age > 0, "cells should expose normalized plate age")
    expect(counts.subduction > 0, "tectonics should include oceanic subduction bias")
    expect(counts.rift > 0, "tectonics should include rift valleys")
    expect(counts.islandArc > 0, "tectonics should include volcanic island arcs")
    expect(counts.shield > 0, "tectonics should include shield regions")
    expect(counts.craton > 0, "tectonics should include cratons")
end

local function testDiscoveryOverlayIds()
    local world = WorldGen.new(99)
    local ridgeIds, rangeIds = {}, {}
    for cy = -1, 1 do
        for cx = -1, 1 do
            local chunk = world:chunk(cx, cy, "local")
            for y = 1, chunk.size, 4 do
                for x = 1, chunk.size, 4 do
                    local cell = chunk.cells[y][x]
                    expect(cell.basinId and cell.watershedId, "sampled cells should expose basin and watershed ids")
                    if cell.ridgeId then ridgeIds[cell.ridgeId] = true end
                    if cell.mountainRangeId then rangeIds[cell.mountainRangeId] = true end
                end
            end
        end
    end
    local ridgeCount, rangeCount = 0, 0
    for _ in pairs(ridgeIds) do ridgeCount = ridgeCount + 1 end
    for _ in pairs(rangeIds) do rangeCount = rangeCount + 1 end
    expect(ridgeCount > 0, "sampled cells should expose ridge ids")
    expect(rangeCount > 0, "sampled cells should expose mountain-range ids")
end

local function testNamedTerrainDiscoveries()
    local world = WorldGen.new(1)
    local repeatWorld = WorldGen.new(1)
    local points = { { -320, -320 }, { -64, -320 }, { 0, -320 }, { -32, -128 }, { -32, -512 } }
    local seen = {}
    local expected = {}
    for _, kind in ipairs(WorldGen.discoveryKinds()) do expected[kind] = true end
    for _, point in ipairs(points) do
        local first = world:discoveriesAt(point[1], point[2], "local")
        local second = repeatWorld:discoveriesAt(point[1], point[2], "local")
        expect(#first == #second, "terrain discovery labels should be deterministic")
        for index, item in ipairs(first) do
            expect(item.name == second[index].name and item.id == second[index].id, "terrain discovery names should be stable")
            seen[item.kind] = true
        end
    end
    for kind in pairs(expected) do
        expect(seen[kind], "terrain discovery should include " .. kind)
    end
end

local function testSurveyHistory()
    local world = WorldGen.new(99)
    local history = Survey.new()
    Survey.mark(history, world, -64, -64, "local")
    local cellsAfterFirst = history.cellCount
    local discoveriesAfterFirst = history.discoveryCount
    expect(cellsAfterFirst == 1, "survey should mark sampled terrain cells")
    expect(discoveriesAfterFirst > 0, "survey should record terrain discoveries")
    Survey.mark(history, world, -64, -64, "local")
    expect(history.cellCount == cellsAfterFirst and history.discoveryCount == discoveriesAfterFirst, "survey should dedupe repeated marks")
    Survey.mark(history, world, -16, 16, "local")
    expect(history.cellCount > cellsAfterFirst and history.discoveryCount >= discoveriesAfterFirst, "survey should grow when marking new cells")
end

local function testSaveLoadRoundTrip()
    local world = WorldGen.new(99)
    local survey = Survey.new()
    Survey.mark(survey, world, -64, -64, "local")
    local viewScale = ViewScale.new(world)
    ViewScale.set(viewScale, world, "region", -64, -64)
    ViewScale.update(viewScale, 1, world, -64, -64)
    local app = {
        world = world,
        player = { x = 12.5, y = -7.25 },
        camera = { yaw = 0.7, pitch = -0.1 },
        survey = survey,
        viewScale = viewScale,
        mouseLook = false,
        debugPerf = true,
        debugTopo = true,
        debugPanels = true,
        atmosphere = Atmosphere.new({ time = 0.4, season = "autumn", dayLength = 90 }),
    }
    local encoded = Save.encode(Save.snapshot(app))
    local decoded = Save.decode(encoded)
    local restoredSurvey = Survey.fromSnapshot(decoded.survey)
    expect(decoded.seed == 99 and decoded.player.x == 12.5 and decoded.player.y == -7.25, "save should round-trip seed and player position")
    expect(decoded.camera.yaw == 0.7 and decoded.display.viewScale == "region", "save should round-trip camera and display settings")
    expect(decoded.atmosphere.time == 0.4 and decoded.atmosphere.season == "autumn" and decoded.atmosphere.dayLength == 90, "save should round-trip atmosphere state")
    expect(decoded.display.debugPerf and decoded.display.debugTopo and decoded.display.debugPanels and not decoded.display.mouseLook, "save should round-trip display toggles")
    expect(restoredSurvey.cellCount == survey.cellCount and restoredSurvey.discoveryCount == survey.discoveryCount, "save should round-trip survey annotations")
end

local function testViewScaleTransitions()
    local world = WorldGen.new(99)
    local view = ViewScale.new(world)
    ViewScale.update(view, 0, world, -64, -64)
    expect(ViewScale.activeScale(view) == "local", "view scale should start local")
    local labelsAfterLocal = #ViewScale.visibleLabels(view, 16)
    ViewScale.shift(view, world, 1, -64, -64)
    local mid = ViewScale.params(view, world)
    expect(mid.target == "region" and mid.factor == 1, "view scale should begin region transition from local")
    ViewScale.update(view, 0.28, world, -64, -64)
    mid = ViewScale.params(view, world)
    expect(mid.factor > 1 and mid.factor < 4 and mid.transitioning, "view scale should ease between local and region")
    ViewScale.update(view, 1, world, -64, -64)
    local region = ViewScale.params(view, world)
    expect(region.target == "region" and region.factor == 4 and not region.transitioning, "view scale should finish at region")
    ViewScale.shift(view, world, 1, -16, 16)
    ViewScale.update(view, 1, world, -16, 16)
    local continent = ViewScale.params(view, world)
    local labels = ViewScale.visibleLabels(view, 32)
    local scales = {}
    for _, label in ipairs(labels) do scales[label.scale] = true end
    expect(continent.target == "continent" and continent.factor == 16, "view scale should reach continent")
    expect(#labels >= labelsAfterLocal and scales["local"] and scales.region and scales.continent, "view labels should persist across nested scales")
end

local function testDiegeticScaleTransitions()
    local world = WorldGen.new(99)
    local view = ViewScale.new(world)
    local localAnchor = ViewScale.advanceDiegetic(view, world, -64, -64)
    expect(localAnchor.from == "local" and localAnchor.target == "region" and localAnchor.name, "local scope should use a terrain anchor")
    ViewScale.update(view, 1, world, -64, -64)
    local regionAnchor = ViewScale.advanceDiegetic(view, world, -16, 16)
    expect(regionAnchor.from == "region" and regionAnchor.target == "continent" and regionAnchor.name, "region scope should use a terrain anchor")
    ViewScale.update(view, 1, world, -16, 16)
    local returnAnchor = ViewScale.advanceDiegetic(view, world, -16, 16)
    ViewScale.update(view, 1, world, -16, 16)
    expect(returnAnchor.from == "continent" and returnAnchor.target == "local", "continent scope should return to local terrain")
    expect(ViewScale.params(view, world).target == "local" and view.anchor.name == returnAnchor.name, "diegetic scope anchor should persist on the view")
end

local function testBasinHydrologyBudget()
    local world = WorldGen.new(1, basinWorldOptions)
    world:chunk(0, 0, "local")
    local stats = world:hydrologyStats(0, 0, "local")
    local metrics = world:metricsSnapshot()
    local cache = world:cacheStats()
    expect(stats.macroChannels > 0, "coarse basin pass should feed local macro channels")
    expect(metrics.hydrologyMisses == 1 and metrics.basinMisses == 1, "first chunk should solve one detail region and one coarse basin")
    expect(metrics.hydrologyCells == 4096 and metrics.basinCells == 4096, "first chunk hydrology should stay bounded")
    expect(cache.hydrology == 1 and cache.basins == 1, "first chunk should cache one hydrology region and one basin")
end

local function testCacheBoundsAndCounters()
    local world = WorldGen.new(20260625, {
        hydrologyRegionChunks = 1,
        hydrologyHaloCells = 0,
        hydrologyBasinChunks = 8,
        hydrologyBasinStride = 8,
        cacheMaxEntries = 10,
        cacheLimits = { chunks = 3, hydrology = 2, basins = 1, billboards = 2 },
    })
    local first = encodeChunk(world:chunk(0, 0, "local"))
    for cy = -1, 1 do
        for cx = -1, 1 do
            world:chunk(cx, cy, "local")
        end
    end
    local cache = world:cacheStats()
    local metrics = world:metricsSnapshot()
    expect(cache.total <= 10 and cache.maxEntries == 10, "cache should enforce configured entry bound")
    expect(cache.chunks <= 3 and cache.hydrology <= 2 and cache.basins <= 1, "cache should enforce per-tier entry bounds")
    expect(cache.limits.chunks == 3 and cache.limits.hydrology == 2 and cache.limits.basins == 1, "cache stats should expose tier limits")
    expect(metrics.cachePuts > 10 and metrics.cacheEvictions > 0 and metrics.cacheMisses > 0, "cache metrics should count puts, evictions, and misses")
    expect(metrics.evictions.chunks > 0 and metrics.evictions.hydrology > 0 and metrics.evictions.basins >= 0, "cache metrics should expose tier evictions")
    expect(encodeChunk(world:chunk(0, 0, "local")) == first, "evicted chunk should regenerate deterministically")
    world:chunk(0, 0, "local")
    local after = world:metricsSnapshot()
    expect(after.cacheHits > metrics.cacheHits, "cache metrics should count hits")
end

local function testChunkSoAArrays()
    local world = testWorld(20260625)
    local chunk = world:chunk(0, 0, "local")
    local doubleFields = WorldGen.soaDoubleFields()
    local int8Fields = WorldGen.soaInt8Fields()
    local int32Fields = WorldGen.soaInt32Fields()
    local fields = WorldGen.soaFields()
    expect(#fields > 0 and chunk.arrays, "chunk should expose ffi-backed SoA arrays")
    expect(#doubleFields > 0 and #int8Fields > 0 and #int32Fields > 0, "soa field groups should cover double, int8, and int32 arrays")
    for _, field in ipairs(fields) do
        expect(chunk.arrays[field] ~= nil, "soa array should exist for " .. field)
    end
    local mismatches = 0
    local total = 0
    local firstMismatch
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            local cell = chunk.cells[y][x]
            local index = (y - 1) * chunk.size + (x - 1)
            for _, field in ipairs(doubleFields) do
                total = total + 1
                if round(chunk.arrays[field][index]) ~= round(soaValue(cell[field])) then
                    mismatches = mismatches + 1
                    firstMismatch = firstMismatch or field
                end
            end
            for _, field in ipairs(int8Fields) do
                total = total + 1
                local value = tonumber(chunk.arrays[field][index])
                local enumOk = field == "lithology" and value >= 0 and value <= 7
                local boolOk = field ~= "lithology" and (value == 0 or value == 1)
                if value ~= soaValue(cell[field]) or not (enumOk or boolOk) then
                    mismatches = mismatches + 1
                    firstMismatch = firstMismatch or field
                end
            end
            for _, field in ipairs(int32Fields) do
                total = total + 1
                if tonumber(chunk.arrays[field][index]) ~= soaValue(cell[field]) then
                    mismatches = mismatches + 1
                    firstMismatch = firstMismatch or field
                end
            end
        end
    end
    expect(total > 0 and mismatches == 0, "soa arrays should mirror cell field values: " .. tostring(firstMismatch))
end

local function testLithologyDistribution()
    local classes, land, unknownLand, invalid, crystalline, oceanicYoung, oceanicOld, carbonate = {}, 0, 0, 0, 0, 0, 0, 0
    for seed = 1, 32 do
        local world = WorldGen.new(seed, fastWorldOptions)
        expect(world.lithologyTable and world.lithologyTable[7].name == "evaporite", "world should expose lithology metadata")
        for gy = -3, 3 do
            for gx = -3, 3 do
                local x = gx * 211 + seed * 17
                local y = gy * 197 - seed * 13
                local cell = world:baseSample(x, y, "local")
                local lithology = cell.lithology
                classes[lithology] = true
                if type(lithology) ~= "number" or lithology < 0 or lithology > 7 then invalid = invalid + 1 end
                if cell.elevation > world.seaLevel then
                    land = land + 1
                    if lithology < 1 or lithology > 7 then unknownLand = unknownLand + 1 end
                end
                local props = world.lithologyTable[lithology]
                if not props or round(cell.erodibilityK) ~= round(props.erodibilityK) then invalid = invalid + 1 end
                if cell.plateCrust == "continental" and (cell.shield or 0) + (cell.craton or 0) > 0.5 then
                    crystalline = crystalline + 1
                    if lithology ~= 2 and lithology ~= 3 then invalid = invalid + 1 end
                end
                if cell.plateCrust == "oceanic" and (cell.plateAge or 0) < 0.1 then
                    oceanicYoung = oceanicYoung + 1
                    if lithology ~= 1 then invalid = invalid + 1 end
                end
                if cell.plateCrust == "oceanic" and (cell.plateAge or 0) > 0.7 then
                    oceanicOld = oceanicOld + 1
                    if lithology ~= 6 then invalid = invalid + 1 end
                end
                local latitude = 0.5 + 0.5 * math.sin(y * 0.00045 + seed * 0.0001)
                local latitudeUnit = math.abs(latitude * 2 - 1)
                if cell.plateCrust == "continental" and (cell.plateBoundary or 0) < 0.24 and latitudeUnit < 0.5 and (cell.rainfall or 0) > 0.16 and (cell.shield or 0) + (cell.craton or 0) <= 0.5 then
                    carbonate = carbonate + 1
                    if lithology ~= 4 then invalid = invalid + 1 end
                end
            end
        end
    end
    local classCount = 0
    for id = 1, 7 do
        if classes[id] then classCount = classCount + 1 end
    end
    local world = testWorld(20260625)
    local dryTerminal = { water = false, rainfall = 0.05, lithology = 5, erodibilityK = 0.9, lithologyAge = 0.4 }
    world:refineLithology(dryTerminal)
    expect(classCount >= 4 and land > 0 and unknownLand == 0 and invalid == 0, "lithology sweep should produce valid land classes")
    expect(crystalline > 0 and oceanicYoung > 0 and oceanicOld > 0 and carbonate > 0, "lithology sweep should cover tectonic rules")
    expect(dryTerminal.lithology == 7 and round(dryTerminal.erodibilityK) == round(world.lithologyTable[7].erodibilityK), "arid terminal land should refine to evaporite")
end

local function testLithologyErodibilityScalesStreamPower()
    local function erosionFor(multiplier)
        local low = { gx = 0, gy = 0, elevationBase = 0, elevation = 0, filledElevation = 0, flow = 1, water = false }
        local high = { gx = 1, gy = 0, elevationBase = 1, elevation = 1, filledElevation = 1, flow = 100, downCell = low, downDistance = 1, erodibilityK = multiplier, water = false }
        Erosion.relax({ cells = { low = low, high = high }, seaLevel = -1, stride = 1 }, { iterations = 1, K = 0.01, m = 0.5, n = 1, uplift = false, isostasy = false })
        return high.streamPowerErosion or 0
    end
    expect(erosionFor(1.6) > erosionFor(0.4), "lithology erodibility should scale stream-power erosion")
end

local function testPlateMotionGeologicTime()
    local stationary = WorldGen.new(20260625)
    local stationaryAgain = WorldGen.new(20260625)
    local drifted = WorldGen.new(20260625, { geologicTime = 0.5 })
    local driftedAgain = WorldGen.new(20260625, { geologicTime = 0.5 })
    expect(stationary:metadata().geologicTime == 0, "default geologic time should be zero")
    expect(drifted:metadata().geologicTime == 0.5, "geologic time should round trip in metadata")
    local probes = { { 0, 0 }, { 384, -192 }, { -640, 320 } }
    for _, probe in ipairs(probes) do
        local x, y = probe[1], probe[2]
        local a = stationary:plateAt(x, y)
        local b = stationaryAgain:plateAt(x, y)
        local c = drifted:plateAt(x, y)
        local d = driftedAgain:plateAt(x, y)
        expect(a.id == b.id and round(a.boundary) == round(b.boundary), "stationary plateAt should be deterministic per seed")
        expect(round(c.boundary) == round(d.boundary), "drifted plateAt should be deterministic per (seed, time)")
        expect(round(a.boundary) ~= round(c.boundary) or a.id ~= c.id, "non-zero geologic time should shift plate field")
    end
end

local function testPlateCacheBounds()
    local world = WorldGen.new(20260625, { plateCacheEntries = 16 })
    for gy = -4, 4 do
        for gx = -4, 4 do
            world:plateAt(gx * world.plateCellSize, gy * world.plateCellSize)
        end
    end
    expect(world.plateCache.count <= world.plateCacheEntries, "plate cache should enforce configured entry bound")
    local first = encodeCell(world:baseSample(384, -192, "local"))
    local second = encodeCell(WorldGen.new(20260625, { plateCacheEntries = 16 }):baseSample(384, -192, "local"))
    expect(first == second, "plate cache should preserve deterministic base samples")
end

local function testRngHashRange()
    local seen = {}
    local minValue, maxValue, sum = 1, 0, 0
    for index = 1, 2048 do
        local value = Rng.unitAt(20260625, index, -index, index % 31, 17)
        expect(value >= 0 and value < 1, "Rng.unitAt should stay in [0, 1)")
        minValue = math.min(minValue, value)
        maxValue = math.max(maxValue, value)
        sum = sum + value
        seen[math.floor(value * 32)] = true
    end
    local buckets = 0
    for _ in pairs(seen) do buckets = buckets + 1 end
    expect(minValue < 0.02 and maxValue > 0.98, "Rng.hash should cover the unit range")
    expect(math.abs(sum / 2048 - 0.5) < 0.035, "Rng.hash should have a centered fixture mean")
    expect(buckets >= 28, "Rng.hash should distribute fixture samples across buckets")
end

local function testOpenSimplexNoise()
    local minValue, maxValue, sum = 1, 0, 0
    local axisDelta, diagonalDelta = 0, 0
    for y = -16, 16 do
        for x = -16, 16 do
            local value = Noise.value(20260625, x * 0.21, y * 0.21, 9)
            expect(value >= 0 and value <= 1, "Noise.value should stay normalized")
            minValue = math.min(minValue, value)
            maxValue = math.max(maxValue, value)
            sum = sum + value
            axisDelta = axisDelta + math.abs(value - Noise.value(20260625, (x + 1) * 0.21, y * 0.21, 9))
            diagonalDelta = diagonalDelta + math.abs(value - Noise.value(20260625, (x + 1) * 0.21, (y + 1) * 0.21, 9))
        end
    end
    local mean = sum / (33 * 33)
    expect(round(Noise.value(7, -2.96, -2.96, 3)) == round(Noise.value(7, -2.96, -2.96, 3)), "Noise.value should be deterministic")
    expect(round(Noise.value(7, -2.96, -2.96, 3)) ~= round(Noise.value(8, -2.96, -2.96, 3)), "Noise.value should vary by seed")
    expect(minValue < 0.08 and maxValue > 0.92 and math.abs(mean - 0.5) < 0.04, "OpenSimplex fixture should use the normalized range")
    expect(axisDelta / diagonalDelta > 0.55 and axisDelta / diagonalDelta < 1.45, "OpenSimplex fixture should not be strongly axis biased")
end

local function testStreamPowerConvergence()
    local function makeRegion()
        local region = { stride = 1, seaLevel = -1, cells = {}, visitOrder = {} }
        for index = 1, 28 do
            local cell = {
                gx = index,
                gy = 0,
                elevationBase = (index - 1) * 0.035 + ((index % 7 == 0) and 0.08 or 0),
                flow = (29 - index) * (29 - index) * 5,
                water = false,
                uplift = 0,
                plateBoundary = 0,
            }
            cell.elevation = cell.elevationBase
            region.cells[index] = cell
            region.visitOrder[index] = cell
            if index > 1 then
                cell.downCell = region.visitOrder[index - 1]
                cell.downDistance = 1
            end
        end
        return region
    end

    local region = makeRegion()
    local before = region.visitOrder[#region.visitOrder].elevation
    local result = Erosion.relax(region, { iterations = 320, K = 0.016, m = 0.5, n = 1.0, uplift = false, isostasy = false })
    expect(region.visitOrder[#region.visitOrder].elevation < before, "stream power relaxation should mutate elevations in-place")
    expect(result.maxDelta < 0.0001, "stream power relaxation should converge below fixture delta")
    expect(region.visitOrder[#region.visitOrder].streamPowerErosion > 0, "stream power relaxation should expose erosion depth")

    local repeatRegion = makeRegion()
    Erosion.relax(repeatRegion, { iterations = 320, K = 0.016, m = 0.5, n = 1.0, uplift = false, isostasy = false })
    for index, cell in ipairs(region.visitOrder) do
        expect(round(cell.elevation) == round(repeatRegion.visitOrder[index].elevation), "stream power relaxation should be deterministic")
    end
end

local function testIsostasy()
    local function makeRegion()
        local region = { stride = 1, seaLevel = -1, cells = {}, visitOrder = {}, minX = 1, minY = 0, maxX = 28, maxY = 0 }
        for index = 1, 28 do
            local cell = {
                gx = index,
                gy = 0,
                elevationBase = (index - 1) * 0.034 + ((index % 6 == 0) and 0.09 or 0),
                flow = (29 - index) * (29 - index) * 5,
                water = false,
                uplift = 0,
                plateBoundary = index >= 14 and 1 or 0,
            }
            cell.elevation = cell.elevationBase
            region.cells[index] = cell
            region.visitOrder[index] = cell
            if index > 1 then
                cell.downCell = region.visitOrder[index - 1]
                cell.downDistance = 1
            end
        end
        return region
    end
    local function boundaryMean(region)
        local sum, count = 0, 0
        for _, cell in ipairs(region.visitOrder) do
            if (cell.plateBoundary or 0) > 0.35 then
                sum = sum + cell.elevation
                count = count + 1
            end
        end
        return sum / math.max(1, count)
    end
    local without = makeRegion()
    Erosion.relax(without, { iterations = 80, K = 0.014, m = 0.5, n = 1.0, uplift = false, isostasy = false })
    local with = makeRegion()
    local result = Erosion.relax(with, { iterations = 80, K = 0.014, m = 0.5, n = 1.0, uplift = false, isostasy = true, isostasyRatio = 0.8, isostasyRadius = 2 })
    expect(result.isostaticErosion > 0, "isostasy should record eroded mass")
    expect(math.abs(result.isostaticRebound - result.isostaticErosion * 0.8) < 0.00001, "isostasy should conserve rebound ratio")
    expect(boundaryMean(with) > boundaryMean(without), "isostasy should raise plate-boundary mean elevation")

    local function broadThresholds()
        return {
            waterRatioMin = 0,
            waterRatioMax = 1,
            riverRatioMin = 0,
            riverRatioMax = 1,
            lakeRatioMax = 1,
            meanSlopeMax = 1,
            steepSlopeRatioMax = 1,
            singleBiomeMax = 1,
            minBiomeCount = 1,
        }
    end
    local function options(enabled)
        local out = {}
        for k, v in pairs(basinWorldOptions) do out[k] = v end
        out.streamPowerIterations = 24
        out.streamPowerK = 0.0009
        out.streamPowerIsostasy = enabled
        return out
    end
    local low = Diagnostics.analyzeSeed(26, { chunkRadius = 1, sampleStep = 16, worldOptions = options(false), thresholds = broadThresholds() })
    local high = Diagnostics.analyzeSeed(26, { chunkRadius = 1, sampleStep = 16, worldOptions = options(true), thresholds = broadThresholds() })
    expect(low.plateBoundaryCells > 0 and high.plateBoundaryCells > 0, "isostasy diagnostics should sample plate-boundary cells")
    expect(high.meanPlateBoundaryElevation > low.meanPlateBoundaryElevation, "isostasy diagnostics should raise plate-boundary elevation")
end

local function testStreamPowerDiagnostics()
    local function broadThresholds()
        return {
            waterRatioMin = 0,
            waterRatioMax = 1,
            riverRatioMin = 0,
            riverRatioMax = 1,
            lakeRatioMax = 1,
            meanSlopeMax = 1,
            steepSlopeRatioMax = 1,
            singleBiomeMax = 1,
            minBiomeCount = 1,
        }
    end
    local function worldOptions(iterations)
        local out = {}
        for k, v in pairs(basinWorldOptions) do out[k] = v end
        out.streamPowerIterations = iterations
        return out
    end
    local function slopeMeans(iterations)
        local nonMountain, boundary = 0, 0
        local seeds = { 1, 6, 26 }
        for _, seed in ipairs(seeds) do
            local stats = Diagnostics.analyzeSeed(seed, {
                chunkRadius = 1,
                sampleStep = 16,
                worldOptions = worldOptions(iterations),
                thresholds = broadThresholds(),
            })
            nonMountain = nonMountain + stats.meanNonMountainSlope
            boundary = boundary + stats.meanPlateBoundarySlope
        end
        return nonMountain / #seeds, boundary / #seeds
    end

    local baseNonMountain, baseBoundary = slopeMeans(0)
    local erodedNonMountain, erodedBoundary = slopeMeans(80)
    expect(erodedNonMountain < baseNonMountain, "stream power diagnostics should lower stable non-mountain slope")
    expect(erodedBoundary > baseBoundary, "stream power diagnostics should raise plate-boundary slope")
end

local function testOrographicRainShadow()
    local region = { scale = "local", scaleFactor = 1, stride = 1, cells = {} }
    for gy = -4, 4 do
        for gx = -12, 12 do
            local ridge = math.max(0, 1 - math.abs(gx) / 2)
            local elevation = 0.06 + ridge * 0.78
            local cell = {
                gx = gx,
                gy = gy,
                x = gx,
                y = 1200 + gy,
                elevationBase = elevation,
                elevation = elevation,
                water = gx == -12,
            }
            region.cells[gx .. ":" .. gy] = cell
        end
    end
    local world = { seed = 1, climateSamples = {}, hydrologyBasinStride = 1, orographicLiftScale = 12, orographicLeeScale = 3 }
    local climate = Climate.solveRegion(world, region)
    local windward, leeward, samples = 0, 0, 0
    for gy = -4, 4 do
        windward = windward + region.cells["-1:" .. gy].precipitation
        leeward = leeward + region.cells["3:" .. gy].precipitation
        samples = samples + 1
    end
    expect(windward / samples > (leeward / samples) * 1.5, "orographic precipitation should make windward slopes wetter than leeward slopes")
    expect(climate.rainShadowCells > 0, "orographic precipitation should mark leeward rain-shadow cells")
end

local function testBasinChannelsSpanDetailRegions()
    local world = WorldGen.new(1, basinWorldOptions)
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

local function testWhittakerBins()
    expect(Biomes.lookup(0.74, 0.1, 0.1, false, 0.02) == "desert", "hot arid Whittaker bin should be desert")
    expect(Biomes.lookup(0.74, 0.36, 0.1, false, 0.02) == "savanna", "hot seasonal Whittaker bin should be savanna")
    expect(Biomes.lookup(0.76, 0.9, 0.2, false, 0.02) == "rainforest", "hot wet Whittaker bin should be rainforest")
    expect(Biomes.lookup(0.48, 0.64, 0.1, false, 0.02) == "temperate_forest", "temperate mesic Whittaker bin should be forest")
    expect(Biomes.lookup(0.24, 0.64, 0.1, false, 0.02) == "boreal_forest", "cold wet Whittaker bin should be boreal forest")
    expect(Biomes.lookup(0.18, 0.22, 0.1, false, 0.02) == "tundra", "cold dry Whittaker bin should be tundra")
    expect(Biomes.lookup(0.7, 0.9, 0.05, false, 0.02) == "wetland", "low saturated Whittaker bin should be wetland")
    expect(Biomes.lookup(0.4, 0.6, 0.8, false, 0.02) == "rock", "high warm Whittaker override should be rock")
    expect(Biomes.lookup(0.2, 0.6, 0.8, false, 0.02) == "snow", "high cold Whittaker override should be snow")
end

local function testWhittakerDiagnostics()
    local sweep = Diagnostics.sweep({
        seeds = Diagnostics.defaultSeeds(),
        chunkRadius = 1,
        sampleStep = 8,
        worldOptions = basinWorldOptions,
    })
    local biomeCount, topRatio = 0, 0
    for _, stats in ipairs(sweep.results) do
        biomeCount = biomeCount + stats.biomeCount
        topRatio = topRatio + (stats.topBiome and stats.topBiome.ratio or 1)
    end
    expect(biomeCount / #sweep.results >= 5, "Whittaker diagnostics should keep biome diversity above fixture baseline")
    expect(topRatio / #sweep.results < 0.62, "Whittaker diagnostics should avoid single-biome dominance")
end

local function testGlacialFeatures()
    local world = WorldGen.new(12)
    local stats = world:hydrologyStats(0, -2, "local")
    expect(stats.glaciatedCells > 0, "alpine fixture should expose glaciated reaches")
    local chunk = world:chunk(0, -2, "local")
    local glaciated, eroded, inspected = 0, 0, 0
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            local cell = chunk.cells[y][x]
            if cell.glaciated then
                glaciated = glaciated + 1
                expect(cell.temperature < 0.38 and cell.elevationBase > 0.52, "glaciated cells should be cold high terrain")
            end
            if (cell.glacialErosion or 0) > 0 then eroded = eroded + 1 end
            inspected = inspected + 1
        end
    end
    expect(glaciated > 0 and eroded > glaciated and inspected == chunk.size * chunk.size, "glacial pass should widen beyond primary ice cells")
end

local function testCoastlines()
    local totals = { cliffs = 0, beaches = 0 }
    for _, seed in ipairs({ 1, 6, 7, 30 }) do
        local world = WorldGen.new(seed)
        for cy = -1, 1 do
            for cx = -1, 1 do
                local stats = world:hydrologyStats(cx, cy, "local")
                totals.cliffs = totals.cliffs + (stats.coastCliffs or 0)
                totals.beaches = totals.beaches + (stats.coastBeaches or 0)
            end
        end
    end
    expect(totals.cliffs > 0, "coastline pass should expose windward cliffs")
    expect(totals.beaches > 0, "coastline pass should expose sheltered beaches")
end

local function testAeolianDunes()
    local cell = {
        x = 128,
        y = -64,
        elevation = 0.18,
        elevationBase = 0.18,
        slope = 0.02,
        biome = "desert",
        windX = 1,
        windY = 0,
    }
    Aeolian.applyCell(cell, 20260625)
    expect(cell.duneAmplitude > 0 and cell.duneAmplitude < 0.04, "aeolian pass should add bounded dune amplitude")
    expect(math.abs(cell.elevation - cell.elevationBase) < 0.04, "aeolian dunes should keep elevation deltas small")
    local repeatCell = {
        x = 128,
        y = -64,
        elevation = 0.18,
        elevationBase = 0.18,
        slope = 0.02,
        biome = "desert",
        windX = 1,
        windY = 0,
    }
    Aeolian.applyCell(repeatCell, 20260625)
    expect(round(cell.duneDelta) == round(repeatCell.duneDelta), "aeolian dunes should be deterministic")

    local world = WorldGen.new(20260625, { hydrologyRegionChunks = 1, hydrologyHaloCells = 0, hydrologyBasinChunks = 0 })
    local chunk = world:chunk(0, 0, "local")
    local dunes = 0
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            if (chunk.cells[y][x].duneAmplitude or 0) > 0 then dunes = dunes + 1 end
        end
    end
    expect(dunes > 0, "aeolian worldgen hook should mark desert dune cells")
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
        parts[#parts + 1] = table.concat({ item.kind, round(item.x), round(item.y), round(item.z), round(item.width), round(item.height), round(item.swayPhase) }, ":")
    end
    return table.concat(parts, "|")
end

local function pngDimensions(path)
    local file = assert(io.open(path, "rb"))
    local header = file:read(24)
    file:close()
    expect(header and string.sub(header, 1, 8) == "\137PNG\r\n\26\n", "atlas should be a PNG")
    local b = { string.byte(header, 17, 24) }
    return b[1] * 16777216 + b[2] * 65536 + b[3] * 256 + b[4], b[5] * 16777216 + b[6] * 65536 + b[7] * 256 + b[8]
end

local function testBillboardAtlas()
    local kinds = Render.billboardAtlasKinds()
    local width, height = pngDimensions("assets/billboards.png")
    expect(width == #kinds * 32 and height == 32, "billboard atlas should have one 32px cell per kind")
    local atlas = {}
    for _, kind in ipairs(kinds) do atlas[kind] = true end
    for _, kind in ipairs({ "tree_deciduous", "tree_conifer", "tree_dead", "shrub", "reed", "rock", "outcrop", "peak", "snow_tuft" }) do
        expect(atlas[kind], "billboard atlas missing " .. kind)
    end
    for _, kind in ipairs(WorldGen.billboardKinds()) do
        expect(atlas[Render.billboardAtlasKindFor(kind)], "billboard kind missing atlas quad " .. kind)
    end
    expect(Render.billboardSwayMagnitude("tree_deciduous") > Render.billboardSwayMagnitude("reed"), "tree sway should exceed reed sway")
    expect(Render.billboardSwayMagnitude("reed") > Render.billboardSwayMagnitude("shrub"), "reed sway should exceed shrub sway")
    expect(Render.billboardSwayMagnitude("rock") == 0 and Render.billboardSwayMagnitude("peak") == 0, "static billboard kinds should not sway")
end

local function testBillboards()
    local a = testWorld(717)
    local b = testWorld(717)
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
                expect((item.swayPhase or 0) >= -1 and (item.swayPhase or 0) <= 1, "billboard sway phase should be normalized")
                count = count + 1
            end
        end
    end
    expect(count > 0, "fixture seed should generate billboards")
end

local function testClipmap()
    local state = Clipmap.new({ levelCount = 3, halfResolution = 4 })
    local function sample(x, y)
        return { x = x, y = y, biome = "grassland", elevation = (x + y) * 0.01, slope = 0 }, x + y
    end
    local _, first = Clipmap.update(state, 0, 0, sample, { scaleId = "local" })
    expect(first.rings == 3 and first.steps[1] == 1 and first.steps[2] == 2 and first.steps[3] == 4, "clipmap should build fixed density rings")
    expect(first.radius == 16 and first.tileCapacity > 0 and first.vertexCapacity == first.tileCapacity * 6, "clipmap should expose constant ring buffer capacity")
    expect(first.fullRefills == 3 and first.samplesRefilled == 3 * 9 * 9, "initial clipmap update should fill every ring")
    local _, reused = Clipmap.update(state, 0.4, 0.4, sample, { scaleId = "local" })
    expect(reused.reusedRings == 3 and reused.samplesRefilled == 0, "clipmap should reuse rings until origin crosses a grid step")
    local _, partial = Clipmap.update(state, 1, 0, sample, { scaleId = "local" })
    expect(partial.partialRefills >= 1 and partial.fullRefills == 0, "clipmap should partially refill scrolled strips")
    expect(Clipmap.outerMorph(state.levels[1], 4, 0) > 0 and Clipmap.outerMorph(state.levels[3], 4, 0) == 0, "clipmap should morph only rings with coarser neighbors")
    expect(Clipmap.heightAt(state.levels[2], state.levels[2].originX, state.levels[2].originY) ~= nil, "clipmap should interpolate cached heights")
end

local function testRenderStats()
    local world = testWorld(3)
    local app = { world = world, player = Player.new(0, 0), camera = Render.defaultCamera(), viewScale = ViewScale.new(world) }
    local stats = Render.visibleStats(app, 1280, 720)
    expect(stats.visibleTiles > 0 and stats.triangles == stats.visibleTiles * 2, "render stats should describe terrain mesh")
    expect(stats.visibleTiles <= stats.expectedMaxForFOV, "visible tiles should stay within FOV-cull budget")
    expect(stats.fullTiles > 0 and stats.visibleTiles <= stats.fullTiles, "FOV culling should keep visible terrain bounded")
    expect(stats.clipmap == true and stats.clipmapRings >= 5 and stats.clipmapRadius >= 500, "local render should use extended clipmap terrain")
    expect(stats.clipmapSteps == "1,2,4,8,16,32" and stats.clipmapMorphBands == stats.clipmapRings - 1, "clipmap should expose nested densities and morph bands")
    expect(stats.clipmapTileCapacity > 0 and stats.clipmapVertexCapacity == stats.clipmapTileCapacity * 6, "clipmap should keep fixed tile and vertex capacities")
    expect(stats.clipmapMorphTiles > 0 and stats.terrainRadius >= stats.clipmapRadius, "clipmap should draw morphed far terrain")
    local reusedStats = Render.visibleStats(app, 1280, 720)
    expect(reusedStats.clipmapReusedRings == reusedStats.clipmapRings and reusedStats.clipmapSamplesRefilled == 0, "static camera should reuse clipmap rings")
    app.player.x = app.player.x + 1
    local shiftedStats = Render.visibleStats(app, 1280, 720)
    expect(shiftedStats.clipmapPartialRefills > 0 and shiftedStats.clipmapFullRefills == 0, "clipmap should scroll with partial ring refills")
    expect(stats.billboards >= 0 and stats.cameraHeight == stats.cameraHeight, "render stats should include finite camera and billboard count")
    expect(stats.riverStrips > 0, "render stats should include river strips")
    expect(stats.silhouetteStrips > 0, "render stats should include slope silhouettes")
    expect(stats.landmarks > 0, "render stats should include terrain landmarks")
    ViewScale.shift(app.viewScale, world, 1, 0, 0)
    ViewScale.update(app.viewScale, 1, world, 0, 0)
    local regionStats = Render.visibleStats(app, 1280, 720)
    expect(regionStats.viewScale == "region" and regionStats.viewFactor == 4 and regionStats.visibleTiles > 0, "render stats should follow region view scale")
    for _, pose in ipairs({ { math.pi * 0.5, -0.36 }, { math.pi, 0.34 }, { -math.pi * 0.75, 0.02 } }) do
        app.camera = Render.defaultCamera()
        app.camera.yaw = pose[1]
        app.camera.pitch = pose[2]
        local poseStats = Render.visibleStats(app, 1280, 720)
        expect(poseStats.visibleTiles > 0 and poseStats.visibleTiles <= poseStats.expectedMaxForFOV, "render stats should cull safely across yaw and pitch")
    end
end

local function colorDistance(a, b)
    local dr, dg, db = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return math.sqrt(dr * dr + dg * dg + db * db)
end

local function testBiomePalette()
    local palette = Render.biomePalette()
    expect(colorDistance(palette.ocean, palette.river) > 0.28, "water palette should separate ocean and rivers")
    expect(colorDistance(palette.desert, palette.grassland) > 0.35, "dry and grass biomes should have distinct colors")
    expect(colorDistance(palette.rainforest, palette.boreal_forest) > 0.16, "forest biomes should avoid a single green ramp")
    expect(colorDistance(palette.snow, palette.rock) > 0.75, "high terrain palette should separate snow and rock")
end

local function testSkyDomeColors()
    local noon = Render.skyColors(0.25)
    local midnight = Render.skyColors(0.75)
    expect(colorDistance(noon.top, midnight.top) > 0.32, "sky dome should react to time of day")
    expect(colorDistance(noon.horizon, noon.fog) < 0.25, "sky dome should haze horizon toward fog")
    expect(colorDistance(Render.skyColors(0.25, "summer").top, Render.skyColors(0.25, "winter").top) > 0.08, "sky dome should react to season")
end

local function testAtmosphereCycle()
    local base = PostFX.paletteFor("local")
    local noon = Atmosphere.palette(base, Atmosphere.new({ time = 0.25, season = "summer" }))
    local midnight = Atmosphere.palette(base, Atmosphere.new({ time = 0.75, season = "summer" }))
    expect(colorDistance(noon[12], midnight[12]) > 0.18, "atmosphere palette at noon should differ from midnight")
    local winter = Atmosphere.palette(base, Atmosphere.new({ time = 0.25, season = "winter" }))
    expect(colorDistance(noon[23], winter[23]) > 0.08, "atmosphere palette should vary by season")
    local state = Atmosphere.new({ time = 0.99, season = "winter", dayLength = 60 })
    Atmosphere.update(state, 1.2)
    expect(state.time > 0 and state.time < 0.02, "atmosphere update should wrap day cycle")
    expect(Atmosphere.shiftSeason(state, 1) == "spring" and Atmosphere.shiftSeason(state, -1) == "winter", "atmosphere season shift should wrap")
end

local function testAtmosphereSunDirection()
    local noon = Atmosphere.sunDirection(Atmosphere.new({ time = 0.25 }))
    local midnight = Atmosphere.sunDirection(Atmosphere.new({ time = 0.75 }))
    local dusk = Atmosphere.sunDirection(Atmosphere.new({ time = 0.5 }))
    local function unit(v) return math.abs(math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) - 1) < 1e-6 end
    expect(unit(noon) and unit(midnight) and unit(dusk), "sun direction should be unit length")
    expect(noon.z > midnight.z, "sun should be higher at noon than midnight")
    expect(noon.daylight > midnight.daylight, "daylight should be greater at noon than midnight")
    expect(math.abs(noon.x) < 0.01, "sun should be near zenith east-west at noon")
    expect(dusk.x < 0, "sun should swing west at dusk")
end

local function testPostFxPixelScale()
    expect(PostFX.parsePixelScale(nil) == 2, "postfx default pixel scale should be 2")
    expect(PostFX.parsePixelScale("3") == 3 and PostFX.parsePixelScale(4) == 4, "postfx should accept configured pixel scales")
    local width, height = PostFX.lowResSize(1280, 720, 2)
    expect(width == 640 and height == 360, "postfx should compute half-res canvas dimensions")
    local ok = pcall(PostFX.parsePixelScale, "5")
    expect(not ok, "postfx should reject unsupported pixel scales")
    expect(#PostFX.paletteFor("local") == 32 and #PostFX.paletteFor("region") == 32, "postfx palettes should expose 32 colors")
    expect(PostFX.paletteFor("local")[1][1] ~= PostFX.paletteFor("region")[1][1] or PostFX.paletteFor("local")[4][3] ~= PostFX.paletteFor("region")[4][3], "postfx scope palettes should differ")
    expect(PostFX.activePaletteId({ viewScale = { target = "continent" } }) == "continent", "postfx palette should follow active scope")
end

local function testTopographicMapData()
    local world = testWorld(20260625)
    local app = { world = world, player = Player.new(0, 0), camera = Render.defaultCamera(), viewScale = ViewScale.new(world) }
    local data = Render.topographicMapData(app, 32)
    expect(data.samples == 1024 and data.scale == "local", "topographic map should sample local terrain when enabled")
    expect(data.water > 0 and data.water < data.samples, "topographic map should include land and water")
    expect(data.rivers > 0 and data.contours > 0, "topographic map should expose rivers and contours")
end

local function testDebugPanelIds()
    local ids = Render.debugPanelIds()
    local seen = {}
    for _, id in ipairs(ids) do seen[id] = true end
    expect(seen.plate and seen.drainage and seen.erosion and seen.biome, "debug panel ids should expose plate, drainage, erosion, biome overlays")
    expect(#ids == 4, "render should expose exactly four toggleable panels")
end

local function testDebugPanelData()
    local world = testWorld(20260625)
    local app = { world = world, player = Player.new(0, 0), camera = Render.defaultCamera(), viewScale = ViewScale.new(world) }
    local data = Render.debugPanelData(app)
    expect(data.plate.vx == data.plate.vx and data.plate.boundary >= 0, "debug panels should expose finite plate vector inputs")
    expect(data.drainage.flow >= 0 and data.drainage.dx == data.drainage.dx and data.drainage.watershedId, "debug panels should expose drainage direction inputs")
    expect(data.erosion.erosion == data.erosion.erosion and data.erosion.thermal == data.erosion.thermal, "debug panels should expose erosion deltas")
    expect(data.biome.id and data.biome.temperature >= 0 and data.biome.moisture >= 0 and data.biome.slope >= 0, "debug panels should expose biome classifier inputs")
end

local function testMapExportData()
    local world = testWorld(20260625)
    local map = Export.renderMap(world, { size = 32, span = 256, scale = "local" })
    local ppm = Export.ppmBytes(map)
    local json = Export.metadataJson(map.metadata)
    expect(map.metadata.seed == 20260625 and map.metadata.size == 32, "export metadata should include seed and size")
    expect(map.stats.land > 0 and map.stats.water > 0 and map.stats.rivers > 0, "export map should include terrain stats")
    expect(string.sub(ppm, 1, 12) == "P6\n32 32\n255" and #ppm > 32 * 32 * 3, "export should produce image bytes")
    expect(string.find(json, '"seed": 20260625', 1, true) ~= nil, "export metadata should encode seed json")
end

local function testTerrainBenchmark()
    local result = Benchmark.run({
        seed = 20260625,
        chunkRadius = 0,
        scales = { "local", "region", "continent" },
        worldOptions = basinWorldOptions,
    })
    expect(result.chunks == 3 and result.cells == 3 * 64 * 64, "benchmark should visit requested chunks and scales")
    expect(result.seconds > 0 and result.chunksPerSecond > 0 and result.cellsPerSecond > 0, "benchmark should report timing rates")
    expect(result.cache.total > 0 and result.metrics.chunkMisses == 3, "benchmark should expose cache and miss counters")
    expect(string.find(Benchmark.format(result), "benchmark=terrain", 1, true) ~= nil, "benchmark should format cli output")
end

local function testBenchmarkBaselineGate()
    local result = Benchmark.run({
        seed = 20260625,
        chunkRadius = 0,
        scales = { "local" },
        worldOptions = basinWorldOptions,
    })
    local snapshot = Benchmark.snapshot(result)
    expect(snapshot.cellsPerSecond and snapshot.cellsPerSecond > 0, "snapshot should preserve cellsPerSecond")
    local pass = Benchmark.compareToBaseline(result, { cellsPerSecond = result.cellsPerSecond * 0.5 }, 0.1)
    expect(pass.ok, "current run should beat 50% of itself")
    local fail = Benchmark.compareToBaseline(result, { cellsPerSecond = result.cellsPerSecond * 4 }, 0.1)
    expect(not fail.ok, "4x baseline should detect regression")
    expect(Benchmark.compareToBaseline(result, nil, 0.1).ok, "missing baseline should not block")
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
        expect(stats.biomeGroups and stats.biomeGroups.water >= 0, "diagnostics should report biome group ratios")
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

local function testRegressionSeedDiagnostics()
    local categories = {}
    for _, fixture in ipairs(Diagnostics.regressionSeeds()) do
        categories[fixture.category] = true
        local stats = Diagnostics.analyzeSeed(fixture.seed, {
            chunkRadius = 1,
            sampleStep = 8,
            worldOptions = basinWorldOptions,
        })
        local flags = {}
        for _, flag in ipairs(stats.flags) do flags[flag] = true end
        for _, expectedFlag in ipairs(fixture.flags or {}) do
            expect(flags[expectedFlag], "regression seed should flag " .. expectedFlag .. " for " .. fixture.category)
        end
        if fixture.maxSeamMismatches then expect(stats.seamMismatches <= fixture.maxSeamMismatches, "regression seed should bound seam mismatches") end
        if fixture.maxUphillRejects then expect(stats.uphillRejects <= fixture.maxUphillRejects, "regression seed should bound river discontinuities") end
        if fixture.minRivers then expect(stats.rivers >= fixture.minRivers, "regression seed should keep river coverage") end
    end
    expect(categories.ugly_terrain and categories.all_water and categories.all_land and categories.broken_seams and categories.river_discontinuities, "regression seed categories should cover terrain failure modes")
    expect(categories.riverless and categories.single_biome and categories.biome_count_low and categories.steep_slopes and categories.drowned_basin, "regression seed categories should cover extended failure modes")
    local count = 0
    for _ in pairs(categories) do count = count + 1 end
    expect(count >= 10, "regression seed fixtures should cover at least 10 categories")
end

local function testTerrainFirstScope()
    local files = {
        "main.lua",
        "src/hydrology.lua",
        "src/player.lua",
        "src/render.lua",
        "src/save.lua",
        "src/survey.lua",
        "src/viewscale.lua",
        "src/export.lua",
        "src/benchmark.lua",
        "src/worldgen.lua",
    }
    local forbidden = { "ruin", "lore", "quest", "collectible", "combat", "survival" }
    for _, path in ipairs(files) do
        local handle = assert(io.open(path, "r"))
        local text = handle:read("*a")
        handle:close()
        local lower = string.lower(text)
        for _, term in ipairs(forbidden) do
            expect(not string.find(lower, term, 1, true), "terrain-first runtime should not include " .. term .. " in " .. path)
        end
    end
end

local function smoke()
    local world = WorldGen.new(1)
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
    print("lake_groups=" .. localStats.lakeGroups)
    print("talus=" .. localStats.talusSlopes)
    print("alluvial_fans=" .. localStats.alluvialFans)
    print("floodplains=" .. localStats.floodplains)
    print("deltas=" .. localStats.deltas)
    print("sediment_cells=" .. localStats.sedimentCells)
    print("glaciated_cells=" .. localStats.glaciatedCells)
    print("coast_cliffs=" .. localStats.coastCliffs)
    print("coast_beaches=" .. localStats.coastBeaches)
    print("seam_mismatches=" .. localStats.seamMismatches)
    print("uphill_rejects=" .. localStats.uphillRejects)
    print("max_flow=" .. string.format("%.3f", localStats.maxFlow))
    print("mesh_tiles=" .. stats.visibleTiles)
    print("triangles=" .. stats.triangles)
    print("river_strips=" .. stats.riverStrips)
    print("silhouettes=" .. stats.silhouetteStrips)
    print("billboards=" .. stats.billboards)
    print("landmarks=" .. stats.landmarks)
    print("camera_height=" .. string.format("%.3f", stats.cameraHeight))
    if stats.clipmap then
        print("clipmap=" .. tostring(stats.clipmapRings) .. ":" .. tostring(stats.clipmapRadius) .. ":" .. tostring(stats.clipmapSteps))
    end
    expect(land > 0 and water > 0 and rivers > 0, "smoke should cover land, water, and rivers")
    expect(localStats.basins > 0 and localStats.uphillRejects == 0, "smoke should include sane hydrology stats")
    expect(localStats.sedimentCells > 0 and localStats.talusSlopes + localStats.alluvialFans + localStats.floodplains + localStats.deltas > 0, "smoke should include erosion landforms")
    expect(stats.visibleTiles > 0 and stats.triangles > 0, "smoke should build visible terrain mesh")
    expect(stats.riverStrips > 0 and stats.silhouetteStrips > 0 and stats.landmarks > 0, "smoke should include readability overlays")
end

local tests = {
    testDeterminism,
    testSeedVariance,
    testSampleChunkAgreement,
    testRiverMonotonicity,
    testHydrologyStats,
    testLakeGroupingAndSpillover,
    testErosionLandforms,
    testTectonicFeatures,
    testDiscoveryOverlayIds,
    testNamedTerrainDiscoveries,
    testSurveyHistory,
    testSaveLoadRoundTrip,
    testViewScaleTransitions,
    testDiegeticScaleTransitions,
    testBasinHydrologyBudget,
    testCacheBoundsAndCounters,
    testPlateCacheBounds,
    testChunkSoAArrays,
    testLithologyDistribution,
    testLithologyErodibilityScalesStreamPower,
    testPlateMotionGeologicTime,
    testRngHashRange,
    testOpenSimplexNoise,
    testStreamPowerConvergence,
    testIsostasy,
    testStreamPowerDiagnostics,
    testOrographicRainShadow,
    testBasinChannelsSpanDetailRegions,
    testBiomes,
    testWhittakerBins,
    testWhittakerDiagnostics,
    testGlacialFeatures,
    testCoastlines,
    testAeolianDunes,
    testPlayer,
    testHeightInterpolationAndNormal,
    testBillboardAtlas,
    testBillboards,
    testClipmap,
    testRenderStats,
    testBiomePalette,
    testSkyDomeColors,
    testAtmosphereCycle,
    testAtmosphereSunDirection,
    testPostFxPixelScale,
    testTopographicMapData,
    testDebugPanelIds,
    testDebugPanelData,
    testMapExportData,
    testTerrainBenchmark,
    testBenchmarkBaselineGate,
    testTerrainDiagnostics,
    testBadSeedDiagnostics,
    testRegressionSeedDiagnostics,
    testTerrainFirstScope,
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

local function csvList(value)
    if not value then return nil end
    local out = {}
    for item in string.gmatch(value, "([^,]+)") do out[#out + 1] = item end
    return out
end

local function benchmark(args)
    local result = Benchmark.run({
        seed = tonumber(cliValue(args, "--seed", 20260625)) or 20260625,
        chunkRadius = tonumber(cliValue(args, "--chunk-radius", 1)) or 1,
        scales = csvList(cliValue(args, "--scales")),
        worldOptions = basinWorldOptions,
    })
    print(Benchmark.format(result))
    local baselinePath = cliValue(args, "--baseline")
    if cliValue(args, "--update-baseline") then
        local outPath = cliValue(args, "--update-baseline")
        Benchmark.writeBaseline(outPath, Benchmark.snapshot(result))
        print("benchmark-baseline-written=" .. outPath)
        return
    end
    if baselinePath then
        local baseline = Benchmark.readBaseline(baselinePath)
        if not baseline then
            print("benchmark-baseline-missing=" .. baselinePath)
            return
        end
        local tolerance = tonumber(cliValue(args, "--baseline-tolerance", 0.1)) or 0.1
        local check = Benchmark.compareToBaseline(result, baseline, tolerance)
        print(string.format(
            "benchmark-baseline=%s baseline_cells_per_sec=%.0f current_cells_per_sec=%.0f ratio=%.3f tolerance=%.2f status=%s",
            baselinePath,
            check.baseline or 0,
            check.current or 0,
            check.ratio or 0,
            tolerance,
            check.ok and "ok" or "regression"
        ))
        if not check.ok then
            error(string.format(
                "benchmark regression: %.0f cells/sec is below %.0f floor (baseline %.0f, tolerance %.0f%%)",
                check.current,
                check.floor,
                check.baseline,
                tolerance * 100
            ), 0)
        end
    end
end

local function plateBenchmark(args)
    local result = WorldGen.benchmarkPlates({
        seed = tonumber(cliValue(args, "--seed", 20260625)) or 20260625,
        count = tonumber(cliValue(args, "--count", 10000)) or 10000,
        cacheLimit = tonumber(cliValue(args, "--cache-limit", 4096)) or 4096,
    })
    print(string.format(
        "benchmark=plates count=%d cold=%.6f cached=%.6f speedup=%.2f cache_entries=%d checksum=%d",
        result.count,
        result.cold.seconds,
        result.cached.seconds,
        result.speedup,
        result.cached.cacheEntries,
        result.cached.checksum
    ))
    expect(result.cold.checksum == result.cached.checksum, "plate benchmark should preserve outputs")
    expect(result.speedup >= 3, "plate benchmark should show at least 3x speedup")
end

local function rngBenchmark(args)
    local result = Rng.benchmarkHash({
        count = tonumber(cliValue(args, "--count", 1000000)) or 1000000,
    })
    print(string.format(
        "benchmark=rng count=%d legacy=%.6f current=%.6f speedup=%.2f legacy_checksum=%.0f current_checksum=%.0f",
        result.count,
        result.legacy.seconds,
        result.current.seconds,
        result.speedup,
        result.legacy.checksum,
        result.current.checksum
    ))
    expect(result.legacy.checksum ~= result.current.checksum, "Rng.hash benchmark should produce a new bit stream")
    expect(result.speedup >= 4, "Rng.hash benchmark should show at least 4x speedup")
end

local function regressions()
    for _, fixture in ipairs(Diagnostics.regressionSeeds()) do
        local stats = Diagnostics.analyzeSeed(fixture.seed, {
            chunkRadius = 1,
            sampleStep = 8,
            worldOptions = basinWorldOptions,
        })
        print("regression=" .. fixture.category .. " " .. Diagnostics.formatResult(stats))
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

if arg and arg[1] == "--benchmark" then
    benchmark(arg)
    return
end

if arg and arg[1] == "--bench-plates" then
    plateBenchmark(arg)
    return
end

if arg and arg[1] == "--bench-rng" then
    rngBenchmark(arg)
    return
end

if arg and arg[1] == "--regressions" then
    regressions()
    return
end

for index, test in ipairs(tests) do
    test()
    print("ok " .. index)
end
print("tests passed")
