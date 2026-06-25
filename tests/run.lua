package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Player = require("src.player")
local WorldGen = require("src.worldgen")

local function expect(value, message)
    if not value then error(message or "expectation failed", 2) end
end

local function round(value)
    return math.floor((value or 0) * 100000 + 0.5) / 100000
end

local function encodeCell(cell)
    return table.concat({
        cell.x,
        cell.y,
        cell.scale,
        round(cell.elevation),
        round(cell.flow),
        round(cell.erosion),
        round(cell.rainfall),
        round(cell.temperature),
        cell.biome,
        tostring(cell.river),
        tostring(cell.water),
        tostring(cell.plateId),
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
    local a = WorldGen.new(1234)
    local b = WorldGen.new(1234)
    expect(encodeChunk(a:chunk(2, -1, "local")) == encodeChunk(b:chunk(2, -1, "local")), "same seed should produce identical local chunk")
    expect(encodeChunk(a:chunk(0, 0, "continent")) == encodeChunk(b:chunk(0, 0, "continent")), "same seed should produce identical continent chunk")
end

local function testSeedVariance()
    local a = encodeChunk(WorldGen.new(1234):chunk(0, 0, "region"))
    local b = encodeChunk(WorldGen.new(5678):chunk(0, 0, "region"))
    expect(a ~= b, "different seeds should differ")
end

local function testSampleChunkAgreement()
    local world = WorldGen.new(44)
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
    local world = WorldGen.new(99)
    local chunk = world:chunk(0, 0, "local")
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
    expect(checked > 0, "fixture seed should produce river checks")
end

local function testBiomes()
    local world = WorldGen.new(314)
    local ids = {}
    for _, id in ipairs(WorldGen.biomeIds()) do ids[id] = true end
    for cy = -1, 1 do
        for cx = -1, 1 do
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
    local world = WorldGen.new(88)
    local player = Player.new(0, 0)
    Player.update(player, 1, { right = true }, world)
    expect(player.x > 0 and player.y == 0, "player should move right")
    Player.update(player, 0.5, { left = true, up = true, sprint = true }, world)
    expect(player.x == player.x and player.y == player.y, "player position should stay finite")
end

local function smoke()
    local world = WorldGen.new(20260625)
    local land, water, rivers = 0, 0, 0
    for _, scale in ipairs(world:metadata().scales) do
        local chunk = world:chunk(0, 0, scale.id)
        for y = 1, chunk.size do
            for x = 1, chunk.size do
                local cell = chunk.cells[y][x]
                if cell.water then water = water + 1 else land = land + 1 end
                if cell.river then rivers = rivers + 1 end
            end
        end
    end
    print("smoke=terrain")
    print("land=" .. land)
    print("water=" .. water)
    print("rivers=" .. rivers)
    expect(land > 0 and water > 0 and rivers > 0, "smoke should cover land, water, and rivers")
end

local tests = {
    testDeterminism,
    testSeedVariance,
    testSampleChunkAgreement,
    testRiverMonotonicity,
    testBiomes,
    testPlayer,
}

if arg and arg[1] == "--smoke" then
    smoke()
    return
end

for index, test in ipairs(tests) do
    test()
    print("ok " .. index)
end
print("tests passed")
