local serialize = require("thoth.core.serialize")
local randomModule = require("thoth.game.random")
local noiseModule = require("thoth.game.terrain.noise")
local grid = require("thoth.game.terrain.grid")

local registry = {}

local descriptors = {}
local descriptorList = {}

local function clamp(value, minValue, maxValue)
    if minValue ~= nil and value < minValue then
        return minValue
    end
    if maxValue ~= nil and value > maxValue then
        return maxValue
    end
    return value
end

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt((dx * dx) + (dy * dy))
end

local function floatParam(name, default, minValue, maxValue, description, options)
    options = options or {}
    return {
        name = name,
        type = options.type or "float",
        default = default,
        min = minValue,
        max = maxValue,
        description = description,
        evolve = options.evolve ~= false,
        enum = options.enum,
    }
end

local function boolParam(name, default, description)
    return {
        name = name,
        type = "boolean",
        default = default,
        description = description,
        evolve = false,
    }
end

local function stringParam(name, default, enum, description)
    return {
        name = name,
        type = "string",
        default = default,
        enum = enum,
        description = description,
        evolve = false,
    }
end

local function normalizeParam(definition, value)
    if definition.type == "boolean" then
        if value == nil then
            return definition.default
        end
        return not not value
    end

    if definition.type == "string" then
        if type(value) ~= "string" or value == "" then
            value = definition.default
        end
        if definition.enum then
            local allowed = false
            for _, item in ipairs(definition.enum) do
                if item == value then
                    allowed = true
                    break
                end
            end
            if not allowed then
                value = definition.default
            end
        end
        return value
    end

    local numeric = tonumber(value)
    if numeric == nil then
        numeric = definition.default
    end
    numeric = clamp(numeric, definition.min, definition.max)
    if definition.type == "int" then
        numeric = round(numeric)
    end
    return numeric
end

local function applyDefaults(descriptor, provided)
    local params = {}
    provided = provided or {}

    for _, definition in ipairs(descriptor.params or {}) do
        params[definition.name] = normalizeParam(definition, provided[definition.name])
    end

    return params
end

local function buildContext(descriptor, width, height, options)
    options = options or {}
    width = assert(tonumber(width), "width must be numeric")
    height = assert(tonumber(height), "height must be numeric")
    width = math.max(1, round(width))
    height = math.max(1, round(height))

    local seed = tonumber(options.seed) or os.time()
    local rng = randomModule.new(seed)
    local noise = noiseModule.new(seed)
    local params = applyDefaults(descriptor, options.params)

    return {
        id = descriptor.id,
        descriptor = descriptor,
        width = width,
        height = height,
        seed = seed,
        params = params,
        random = rng,
        noise = noise,
        grid = grid,
        randomFloat = function(_, minValue, maxValue)
            if minValue == nil then
                return rng:random()
            end
            return rng:random(minValue, maxValue)
        end,
        randomInt = function(_, minValue, maxValue)
            return rng:random(round(minValue), round(maxValue))
        end,
        chance = function(_, probability)
            return rng:random() < probability
        end,
        choice = function(_, values)
            return rng:choice(values)
        end,
        clone = function(_, source)
            return grid.clone(source)
        end,
        empty = function(_, fillValue)
            return grid.new(width, height, fillValue)
        end,
    }
end

local function metadataFor(descriptor, context)
    return {
        id = descriptor.id,
        name = descriptor.name,
        summary = descriptor.summary,
        seed = context.seed,
        width = context.width,
        height = context.height,
        params = serialize.deepCopy(context.params),
    }
end

local function describeDescriptor(descriptor)
    return {
        id = descriptor.id,
        name = descriptor.name,
        summary = descriptor.summary,
        params = serialize.deepCopy(descriptor.params or {}),
        symbols = serialize.deepCopy(descriptor.symbols or {}),
    }
end

local function register(descriptor)
    descriptors[descriptor.id] = descriptor
    descriptorList[#descriptorList + 1] = descriptor.id
end

local function coastGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local profile = {}
    profile[1] = 0.5
    profile[width] = 0.5

    local function displace(startIndex, endIndex, range, depth)
        if depth <= 0 or (endIndex - startIndex) <= 1 then
            return
        end
        local mid = math.floor((startIndex + endIndex) / 2)
        profile[mid] = ((profile[startIndex] + profile[endIndex]) / 2) + context:randomFloat(-range, range)
        local nextRange = range * (2 ^ (-params.roughness))
        displace(startIndex, mid, nextRange, depth - 1)
        displace(mid, endIndex, nextRange, depth - 1)
    end

    displace(1, width, 1.0, params.iterations)

    for x = 1, width do
        if profile[x] == nil then
            local previous = profile[x - 1] or 0.5
            local nextValue = profile[x + 1] or previous
            profile[x] = (previous + nextValue) / 2
        end
    end

    local minHeight = math.huge
    local maxHeight = -math.huge
    for x = 1, width do
        minHeight = math.min(minHeight, profile[x])
        maxHeight = math.max(maxHeight, profile[x])
    end

    local scale = maxHeight == minHeight and 1 or (maxHeight - minHeight)
    for x = 1, width do
        profile[x] = (profile[x] - minHeight) / scale
    end

    local terrain = context:empty("G")
    for y = 1, height do
        for x = 1, width do
            local dx = (x - ((width + 1) / 2)) / math.max(width / 2, 1)
            local dy = (y - ((height + 1) / 2)) / math.max(height / 2, 1)
            local radial = distance(0, 0, dx, dy) * 0.75
            local elevation = profile[x] - radial

            if elevation < params.sea_level - 0.1 then
                terrain[y][x] = "B"
            elseif elevation < params.sea_level then
                terrain[y][x] = "W"
            elseif elevation < params.sea_level + 0.15 then
                terrain[y][x] = "O"
            else
                terrain[y][x] = "G"
            end
        end
    end

    return terrain
end

local function mountainGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("G")
    local peaks = {}

    for i = 1, params.peak_count do
        peaks[i] = {
            x = context:randomFloat(width * 0.2, width * 0.8),
            y = context:randomFloat(height * 0.2, height * 0.8),
            height = context:randomFloat(0.6, params.peak_height),
            radius = context:randomFloat(6, math.max(8, math.min(width, height) * 0.5)),
        }
    end

    for y = 1, height do
        for x = 1, width do
            local elevation = 0
            local baseNoise = context.noise:octave(x / 30, y / 30, 4, 0.5) * 0.3

            for _, peak in ipairs(peaks) do
                local influence = math.max(0, 1 - (distance(x, y, peak.x, peak.y) / peak.radius))
                elevation = elevation + (peak.height * influence * influence)
            end

            elevation = elevation + baseNoise
            elevation = elevation + (math.abs(context.noise:octave(x / 20, y / 20, 3, 0.6)) * params.ridge_intensity)

            if elevation > 0.8 then
                terrain[y][x] = "A"
            elseif elevation > 0.65 then
                terrain[y][x] = "M"
            elseif elevation > 0.5 then
                terrain[y][x] = "R"
            elseif elevation > 0.35 then
                terrain[y][x] = "X"
            elseif elevation > 0.25 then
                terrain[y][x] = "T"
            elseif elevation > 0.15 then
                terrain[y][x] = "F"
            else
                terrain[y][x] = "G"
            end
        end
    end

    return terrain
end

local function forestGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("G")
    local densityMap = {}
    local clearings = {}

    for y = 1, height do
        densityMap[y] = {}
        for x = 1, width do
            densityMap[y][x] = (context.noise:octave(x / 25, y / 25, 3, params.tree_density)
                + (context.noise:octave(x / 8, y / 8, 2, 0.4) * 0.3))
        end
    end

    for i = 1, params.num_clearings do
        clearings[i] = {
            x = context:randomInt(1, width),
            y = context:randomInt(1, height),
            radius = context:randomInt(3, math.max(4, math.floor(math.min(width, height) * 0.2))),
        }
    end

    local riverY = context:randomFloat(height * 0.3, height * 0.7)

    for y = 1, height do
        for x = 1, width do
            local riverOffset = math.sin(x / 10) * 2
            local isRiver = params.river_enabled and math.abs(y - riverY) <= params.river_width
                and math.abs(y - riverY - riverOffset) <= params.river_width

            if isRiver then
                terrain[y][x] = math.abs(y - riverY) <= 1 and "W" or "S"
            else
                local inClearing = false
                for _, clearing in ipairs(clearings) do
                    if distance(x, y, clearing.x, clearing.y) <= clearing.radius then
                        inClearing = true
                        break
                    end
                end

                if inClearing then
                    terrain[y][x] = "G"
                else
                    local density = densityMap[y][x]
                    if density > 0.6 then
                        terrain[y][x] = "E"
                    elseif density > 0.4 then
                        terrain[y][x] = "F"
                    elseif density > 0.2 then
                        terrain[y][x] = "T"
                    else
                        terrain[y][x] = "G"
                    end
                end
            end
        end
    end

    return terrain
end

local function canyonGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("D")
    local elevationMap = {}
    local tributaries = {}
    local mainChannelY = height / 2

    for i = 1, params.num_tributaries do
        tributaries[i] = {
            start_x = context:randomInt(1, width),
            start_y = context:randomInt(1, height),
            direction = context:randomFloat(0, math.pi * 2),
        }
    end

    for y = 1, height do
        elevationMap[y] = {}
        for x = 1, width do
            local baseElevation = (context.noise:octave(x / 40, y / 40, 3, 0.5) * 0.5) + 0.5
            local channelCurve = math.sin(x / 15) * params.meander_intensity
            local curvedDistance = math.abs(y - (mainChannelY + channelCurve))
            local elevation = baseElevation - (math.max(0, 1 - (curvedDistance / 20)) * params.erosion_depth)

            for _, tributary in ipairs(tributaries) do
                local tributaryX = tributary.start_x + (math.cos(tributary.direction) * (x - tributary.start_x) * 0.3)
                local tributaryY = tributary.start_y + (math.sin(tributary.direction) * (x - tributary.start_x) * 0.3)
                local tributaryDistance = distance(x, y, tributaryX, tributaryY)
                elevation = elevation - (math.max(0, 1 - (tributaryDistance / 8)) * 0.4)
            end

            elevationMap[y][x] = elevation
        end
    end

    for y = 1, height do
        for x = 1, width do
            local elevation = elevationMap[y][x]
            local slope = 0
            if x > 1 and x < width and y > 1 and y < height then
                local dx = elevationMap[y][x + 1] - elevationMap[y][x - 1]
                local dy = elevationMap[y + 1][x] - elevationMap[y - 1][x]
                slope = math.sqrt((dx * dx) + (dy * dy))
            end

            if elevation < 0.1 then
                terrain[y][x] = "W"
            elseif elevation < 0.2 then
                terrain[y][x] = "S"
            elseif slope > 0.3 then
                terrain[y][x] = "R"
            elseif elevation > 0.7 then
                terrain[y][x] = "M"
            elseif elevation > 0.5 then
                terrain[y][x] = "X"
            elseif elevation > 0.3 then
                terrain[y][x] = "O"
            else
                terrain[y][x] = "D"
            end
        end
    end

    return terrain
end

local function archipelagoGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("B")
    local islands = {}

    for i = 1, params.num_islands do
        islands[i] = {
            x = context:randomFloat(width * 0.1, width * 0.9),
            y = context:randomFloat(height * 0.1, height * 0.9),
            size = context:randomFloat(params.min_island_size, params.max_island_size),
            height_scale = context:randomFloat(0.4, 0.8),
        }
    end

    for y = 1, height do
        for x = 1, width do
            local maxElevation = 0
            local closestDistance = math.huge

            for _, island in ipairs(islands) do
                local cellDistance = distance(x, y, island.x, island.y)
                closestDistance = math.min(closestDistance, cellDistance)
                if cellDistance <= island.size then
                    local normalized = cellDistance / island.size
                    local elevation = ((1 - normalized) * island.height_scale)
                        + (context.noise:octave(x / 8, y / 8, 3, 0.5) * 0.2)
                    maxElevation = math.max(maxElevation, elevation)
                end
            end

            local shallowWater = closestDistance <= 5 and maxElevation <= 0
            if maxElevation > 0.6 then
                terrain[y][x] = "M"
            elseif maxElevation > 0.4 then
                terrain[y][x] = "R"
            elseif maxElevation > 0.2 then
                terrain[y][x] = "F"
            elseif maxElevation > 0.1 then
                terrain[y][x] = "O"
            elseif maxElevation > 0.05 then
                terrain[y][x] = "S"
            elseif shallowWater then
                terrain[y][x] = "W"
            else
                terrain[y][x] = "B"
            end
        end
    end

    local maxRadius = math.max(4, math.floor(math.min(width, height) * 0.25))
    local atolls = math.max(1, context:randomInt(1, 3))
    for _ = 1, atolls do
        local centerX = context:randomFloat(width * 0.2, width * 0.8)
        local centerY = context:randomFloat(height * 0.2, height * 0.8)
        local outerRadius = context:randomFloat(4, maxRadius)
        local innerRadius = outerRadius * 0.6

        for y = 1, height do
            for x = 1, width do
                local cellDistance = distance(x, y, centerX, centerY)
                if cellDistance <= outerRadius and cellDistance >= innerRadius then
                    if context:chance(0.7) then
                        terrain[y][x] = "O"
                    end
                elseif cellDistance < innerRadius then
                    terrain[y][x] = "W"
                end
            end
        end
    end

    return terrain
end

local function badlandsGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("D")
    local mesas = {}

    for i = 1, params.mesa_count do
        mesas[i] = {
            x = context:randomFloat(width * 0.1, width * 0.9),
            y = context:randomFloat(height * 0.1, height * 0.9),
            width = context:randomFloat(4, math.max(5, width * 0.35)),
            height = context:randomFloat(4, math.max(5, height * 0.35)),
            elevation = context:randomFloat(0.6, 0.9),
        }
    end

    for y = 1, height do
        for x = 1, width do
            local elevation = (context.noise:octave(x / 50, y / 50, 2, 0.4) * 0.3) + 0.2
            elevation = elevation + (math.sin(elevation * 20) * params.stratification)
            elevation = elevation + (context.noise:octave(x / 15, y / 15, 4, 0.6) * params.erosion_intensity)

            for _, mesa in ipairs(mesas) do
                local dx = math.abs(x - mesa.x)
                local dy = math.abs(y - mesa.y)
                if dx <= (mesa.width / 2) and dy <= (mesa.height / 2) then
                    local edgeDistance = math.min(
                        math.min(dx, (mesa.width / 2) - dx),
                        math.min(dy, (mesa.height / 2) - dy)
                    )
                    local mesaElevation = mesa.elevation + (context.noise:octave(x / 10, y / 10, 2, 0.5) * 0.1)
                    if edgeDistance > 2 then
                        elevation = math.max(elevation, mesaElevation)
                    else
                        local cliffFactor = clamp(edgeDistance / 2, 0, 1)
                        elevation = math.max(elevation, elevation + ((mesaElevation - elevation) * cliffFactor))
                    end
                end
            end

            if math.abs(context.noise:octave(x / 8, y / 25, 1, 1)) < 0.1 then
                elevation = elevation * 0.3
            end

            if elevation > 0.7 then
                terrain[y][x] = "R"
            elseif elevation > 0.5 then
                terrain[y][x] = "K"
            elseif elevation > 0.35 then
                terrain[y][x] = "O"
            elseif elevation > 0.25 then
                terrain[y][x] = "X"
            elseif elevation > 0.15 then
                terrain[y][x] = "D"
            elseif elevation > 0.05 then
                terrain[y][x] = "S"
            else
                terrain[y][x] = "W"
            end
        end
    end

    return terrain
end

local function desertGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("S")
    local heightmap = {}
    local windDirection = math.rad(params.wind_direction)
    local windVector = {
        x = math.cos(windDirection),
        y = math.sin(windDirection),
    }

    for y = 1, height do
        heightmap[y] = {}
        for x = 1, width do
            local nx = (x / params.dune_spacing) + (windVector.x * y / params.dune_spacing)
            local ny = (y / params.dune_spacing) + (windVector.y * x / params.dune_spacing)
            heightmap[y][x] = (context.noise:sample(nx, ny) * 0.7) + (context.noise:sample(nx * 2, ny * 2) * 0.3)
        end
    end

    for y = 1, height do
        for x = 1, width do
            local alongWind = (x * windVector.x) + (y * windVector.y)
            local acrossWind = (x * windVector.y) - (y * windVector.x)
            local duneShape = math.abs(acrossWind / params.dune_spacing) ^ 2
            local duneWave = math.sin(alongWind / params.dune_spacing * math.pi * 2)
            local duneHeight = math.max(0, (1 - duneShape) * ((duneWave + 1) / 2))
            heightmap[y][x] = heightmap[y][x] + (duneHeight * params.sand_mobility)
        end
    end

    for y = 1, height do
        for x = 1, width do
            local left = heightmap[y][clamp(x - 1, 1, width)]
            local right = heightmap[y][clamp(x + 1, 1, width)]
            local up = heightmap[clamp(y - 1, 1, height)][x]
            local down = heightmap[clamp(y + 1, 1, height)][x]
            local slope = math.sqrt(((right - left) ^ 2) + ((down - up) ^ 2))
            local value = heightmap[y][x]

            if slope > 0.3 then
                terrain[y][x] = "O"
            elseif value > 0.6 then
                terrain[y][x] = "Y"
            elseif value > 0.4 then
                terrain[y][x] = "S"
            elseif value > 0.3 then
                terrain[y][x] = "X"
            else
                terrain[y][x] = "-"
            end
        end
    end

    return terrain
end

local function caveGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("-")

    for y = 1, height do
        for x = 1, width do
            terrain[y][x] = context:chance(params.initial_density) and "U" or "-"
        end
    end

    for _ = 1, params.erosion_passes do
        local nextGrid = context:empty("-")
        for y = 1, height do
            for x = 1, width do
                local neighbors = grid.countNeighbors(terrain, x, y, "U", {clamp = true})
                nextGrid[y][x] = neighbors >= 4 and "U" or "-"
            end
        end
        terrain = nextGrid
    end

    local visited = {}
    local caverns = {}
    for y = 1, height do
        visited[y] = {}
    end

    for y = 1, height do
        for x = 1, width do
            if terrain[y][x] == "-" and not visited[y][x] then
                local cavern = {}
                local queue = {{x = x, y = y}}
                visited[y][x] = true
                while #queue > 0 do
                    local node = table.remove(queue, 1)
                    cavern[#cavern + 1] = node
                    for dy = -1, 1 do
                        for dx = -1, 1 do
                            local nx = node.x + dx
                            local ny = node.y + dy
                            if nx >= 1 and nx <= width and ny >= 1 and ny <= height and not visited[ny][nx]
                                and terrain[ny][nx] == "-" then
                                visited[ny][nx] = true
                                queue[#queue + 1] = {x = nx, y = ny}
                            end
                        end
                    end
                end
                caverns[#caverns + 1] = cavern
            end
        end
    end

    table.sort(caverns, function(a, b)
        return #a > #b
    end)

    for i = 1, math.max(0, #caverns - 1) do
        if #caverns[i] > 0 and #caverns[i + 1] > 0 then
            local start = caverns[i][context:randomInt(1, #caverns[i])]
            local target = caverns[i + 1][context:randomInt(1, #caverns[i + 1])]
            local x = start.x
            local y = start.y
            while x ~= target.x or y ~= target.y do
                if x < target.x then
                    x = x + 1
                elseif x > target.x then
                    x = x - 1
                end
                if y < target.y then
                    y = y + 1
                elseif y > target.y then
                    y = y - 1
                end
                terrain[y][x] = "-"
            end
        end
    end

    local margin = math.max(1, math.floor(math.min(width, height) * 0.15))
    for _ = 1, params.mineral_veins do
        local veinX = context:randomInt(1 + margin, math.max(1 + margin, width - margin))
        local veinY = context:randomInt(1 + margin, math.max(1 + margin, height - margin))
        for dy = -3, 3 do
            for dx = -3, 3 do
                local x = veinX + dx
                local y = veinY + dy
                if x >= 1 and x <= width and y >= 1 and y <= height and context:chance(0.4) then
                    terrain[y][x] = "T"
                end
            end
        end
    end

    return terrain
end

local function riverGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local heightmap = {}
    local accumulation = {}
    local riverMask = {}

    for y = 1, height do
        heightmap[y] = {}
        accumulation[y] = {}
        riverMask[y] = {}
        for x = 1, width do
            heightmap[y][x] = (context.noise:sample(x / 100, y / 100) * 0.6)
                + (context.noise:sample(x / 30, y / 30) * 0.3)
                + (context.noise:sample(x / 10, y / 10) * 0.1)
            accumulation[y][x] = 1
        end
    end

    for y = 1, height do
        for x = 1, width do
            local currentX = x
            local currentY = y
            for _ = 1, 100 do
                local lowest = {elevation = heightmap[currentY][currentX]}
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if not (dx == 0 and dy == 0) then
                            local nx = clamp(currentX + dx, 1, width)
                            local ny = clamp(currentY + dy, 1, height)
                            if heightmap[ny][nx] < lowest.elevation then
                                lowest = {
                                    x = nx,
                                    y = ny,
                                    elevation = heightmap[ny][nx],
                                }
                            end
                        end
                    end
                end

                if lowest.x == nil then
                    break
                end
                accumulation[lowest.y][lowest.x] = accumulation[lowest.y][lowest.x] + 1
                currentX = lowest.x
                currentY = lowest.y
            end
        end
    end

    for _ = 1, params.river_count do
        local source = {x = 1, y = 1}
        for y = 1, height do
            for x = 1, width do
                if accumulation[y][x] > accumulation[source.y][source.x] then
                    source = {x = x, y = y}
                end
            end
        end

        local current = {x = source.x, y = source.y}
        local meanderPhase = context:randomFloat(0, math.pi * 2)
        local steps = 0

        while steps < (width + height) * 2 do
            riverMask[current.y][current.x] = true
            local meanderOffset = math.sin(meanderPhase) * 2
            meanderPhase = meanderPhase + (params.delta_size + 0.1)
            local best = {x = current.x, y = current.y, elevation = math.huge}

            for dx = -1, 1 do
                for dy = 1, -1, -1 do
                    local nx = clamp(round(current.x + dx + meanderOffset), 1, width)
                    local ny = clamp(round(current.y + dy), 1, height)
                    if heightmap[ny][nx] < best.elevation then
                        best = {x = nx, y = ny, elevation = heightmap[ny][nx]}
                    end
                end
            end

            if best.x == current.x and best.y == current.y then
                break
            end
            current = {x = best.x, y = best.y}
            if current.x == 1 or current.x == width or current.y == 1 or current.y == height then
                riverMask[current.y][current.x] = true
                break
            end
            steps = steps + 1
        end
    end

    local terrain = context:empty("D")
    for y = 1, height do
        for x = 1, width do
            if riverMask[y][x] then
                terrain[y][x] = "W"
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local nx = clamp(x + dx, 1, width)
                        local ny = clamp(y + dy, 1, height)
                        heightmap[ny][nx] = heightmap[ny][nx] - (params.sediment_load * 0.1)
                    end
                end
            else
                local elevation = heightmap[y][x]
                if elevation < 0.3 then
                    terrain[y][x] = "B"
                elseif elevation < 0.4 then
                    terrain[y][x] = "W"
                elseif elevation < 0.5 then
                    terrain[y][x] = "S"
                elseif elevation < 0.7 then
                    terrain[y][x] = "D"
                else
                    terrain[y][x] = "R"
                end
            end
        end
    end

    return terrain
end

local function swampGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local sites = {}
    local waterMap = {}
    local terrain = context:empty("V")

    for _ = 1, math.max(1, math.floor(width * height / 400)) do
        sites[#sites + 1] = {
            x = context:randomInt(1, width),
            y = context:randomInt(1, height),
            kind = context:chance(0.3) and "mound" or "pool",
        }
    end

    for y = 1, height do
        waterMap[y] = {}
        for x = 1, width do
            waterMap[y][x] = (context.noise:sample(x / 20, y / 20) * 0.5)
                + (context.noise:sample(x / 5, y / 5) * 0.3)
        end
    end

    local function growMangrove(out, startX, startY, depth)
        if depth > (3 + params.biodiversity) then
            return
        end
        local angle = math.rad(25 + context:randomFloat(-15, 15))
        local length = 3 + context:randomInt(0, 2)

        for i = 1, length do
            local y = startY - i
            if y >= 1 and y <= height then
                out[#out + 1] = {x = round(startX), y = y}
            end
        end

        if depth > 1 then
            growMangrove(out, startX + math.cos(angle), startY - length, depth + 1)
            growMangrove(out, startX - math.cos(angle), startY - length, depth + 1)
        end
    end

    for y = 1, height do
        for x = 1, width do
            local nearest = grid.nearestVoronoiSeed(x, y, sites)
            local waterLevel = waterMap[y][x] * params.humidity
            local flooded = context.noise:sample((x / 10) + 1000, y / 10) < params.flood_cycle
            local char

            if waterLevel > 0.7 then
                char = "B"
            elseif waterLevel > 0.6 then
                char = "W"
            elseif flooded then
                char = "V"
            elseif nearest and nearest.kind == "mound" then
                char = "H"
            else
                char = "V"
            end

            terrain[y][x] = char

            if char == "V" and context:chance(0.02 * params.biodiversity) then
                local branches = {}
                growMangrove(branches, x, y, 1)
                for _, node in ipairs(branches) do
                    if node.x >= 1 and node.x <= width and node.y >= 1 and node.y <= height then
                        terrain[node.y][node.x] = context:chance(0.7) and "F" or "T"
                    end
                end
            end
        end
    end

    return terrain
end

local function urbanGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("-")
    local density = params.era == "1920s" and 2.0 or 3.5
    local citySize = math.ceil(math.sqrt(params.population / density))
    citySize = math.min(citySize, math.max(3, math.min(width, height) - 2))
    local mainInterval = params.era == "1920s" and 8 or 5

    for x = 1, width, mainInterval do
        for y = 1, height do
            terrain[y][x] = "J"
        end
    end

    for y = 1, height, mainInterval do
        for x = 1, width do
            terrain[y][x] = "J"
        end
    end

    local function createZone(startX, startY, zoneWidth, zoneHeight, zoneType)
        local buildingChars = {
            residential = {"U", "D", "H"},
            commercial = {"C", "P", "R"},
            industrial = {"P", "X", "J"},
            park = {"H", "F", "Y"},
        }

        for dy = 1, zoneHeight do
            for dx = 1, zoneWidth do
                local x = startX + dx
                local y = startY + dy
                if x <= width and y <= height and terrain[y][x] == "-" then
                    if zoneType == "park" then
                        terrain[y][x] = context:chance(0.7) and "H" or "F"
                    else
                        local options = buildingChars[zoneType]
                        terrain[y][x] = options[context:randomInt(1, #options)]
                    end
                end
            end
        end
    end

    local blockSize = params.era == "1920s" and 6 or 4
    for y = 1, height, blockSize + 2 do
        for x = 1, width, blockSize + 2 do
            if context:chance(0.3) then
                local rotation = context:randomInt(0, 3) * math.pi / 2
                for dy = 0, blockSize do
                    for dx = 0, blockSize do
                        local rx = round(x + (math.cos(rotation) * dx) - (math.sin(rotation) * dy))
                        local ry = round(y + (math.sin(rotation) * dx) + (math.cos(rotation) * dy))
                        if rx >= 1 and rx <= width and ry >= 1 and ry <= height then
                            terrain[ry][rx] = "J"
                        end
                    end
                end
            end

            local zoneType = "residential"
            local sample = context:randomFloat()
            if sample < 0.4 then
                zoneType = "commercial"
            elseif sample < 0.5 then
                zoneType = "industrial"
            elseif sample < 0.7 then
                zoneType = "park"
            end

            createZone(x + 1, y + 1, math.min(blockSize, citySize), math.min(blockSize, citySize), zoneType)
        end
    end

    if params.water_access then
        for x = 1, width do
            terrain[height][x] = context:chance(0.7) and "W" or "B"
            if params.era == "1920s" and x % 10 == 0 and height > 1 then
                terrain[height - 1][x] = "J"
            end
        end
    end

    return terrain
end

local function volcanoGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local elevation = {}
    local heat = {}
    local moisture = {}

    for octave = 0, params.magma_channels - 1 do
        local frequency = 2 ^ octave
        local amplitude = 0.5 ^ octave
        for y = 1, height do
            elevation[y] = elevation[y] or {}
            heat[y] = heat[y] or {}
            moisture[y] = moisture[y] or {}
            for x = 1, width do
                local nx = x / params.base_scale * frequency
                local ny = y / params.base_scale * frequency
                elevation[y][x] = (elevation[y][x] or 0) + (amplitude * context.noise:sample(nx, ny, octave))
                heat[y][x] = (heat[y][x] or 0) + (amplitude * context.noise:sample(nx + 1000, ny, octave + 10))
                moisture[y][x] = (moisture[y][x] or 0) + (amplitude * context.noise:sample(nx, ny + 1000, octave + 20))
            end
        end
    end

    local centerX = width / 2
    local centerY = height / 2
    local maxRadius = math.min(centerX, centerY) * 0.9

    for y = 1, height do
        for x = 1, width do
            local falloff = math.max(0, 1 - (distance(x, y, centerX, centerY) / maxRadius))
            elevation[y][x] = elevation[y][x] * falloff
            heat[y][x] = heat[y][x] * falloff
        end
    end

    local calderaRadius = maxRadius * 0.3
    for y = 1, height do
        for x = 1, width do
            local normalized = distance(x, y, centerX, centerY) / calderaRadius
            if normalized < 1 then
                local sigmoid = 1 / (1 + math.exp(10 * (normalized - 0.5)))
                elevation[y][x] = elevation[y][x] * sigmoid
                heat[y][x] = heat[y][x] + ((1 - sigmoid) * params.lava_flow)
            end
        end
    end

    local terrain = context:empty("B")
    for y = 1, height do
        for x = 1, width do
            local e = elevation[y][x]
            local h = heat[y][x]
            local m = moisture[y][x]
            if e < 0.1 then
                terrain[y][x] = "B"
            elseif e < 0.2 then
                terrain[y][x] = "L"
            elseif e < 0.3 then
                terrain[y][x] = "S"
            elseif e < 0.5 then
                terrain[y][x] = m > 0.6 and "V" or "G"
            elseif e < 0.7 then
                terrain[y][x] = "R"
            else
                terrain[y][x] = h > 0.6 and "Q" or "M"
            end
        end
    end

    return terrain
end

local function tundraGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local du = 0.16
    local dv = 0.08
    local feed = 0.04
    local kill = 0.06
    local u = {}
    local v = {}

    for y = 1, height do
        u[y] = {}
        v[y] = {}
        for x = 1, width do
            u[y][x] = 1.0
            v[y][x] = context:chance(0.2) and 0.5 or 0.0
        end
    end

    for _ = 1, 200 do
        local nextU = {}
        local nextV = {}
        for y = 1, height do
            nextU[y] = {}
            nextV[y] = {}
            for x = 1, width do
                local laplaceU = 0
                local laplaceV = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local nx = clamp(x + dx, 1, width)
                        local ny = clamp(y + dy, 1, height)
                        local weight = (dx == 0 and dy == 0) and -1 or 0.2
                        laplaceU = laplaceU + (u[ny][nx] * weight)
                        laplaceV = laplaceV + (v[ny][nx] * weight)
                    end
                end
                local reaction = u[y][x] * v[y][x] * v[y][x]
                nextU[y][x] = u[y][x] + (du * laplaceU) - reaction + (feed * (1 - u[y][x]))
                nextV[y][x] = v[y][x] + (dv * laplaceV) + reaction - ((feed + kill) * v[y][x])
            end
        end
        u = nextU
        v = nextV
    end

    local terrain = context:empty("N")
    for y = 1, height do
        for x = 1, width do
            terrain[y][x] = (v[y][x] * params.permafrost_depth) > 0.3 and "X" or "N"
        end
    end

    for y = 2, height - 1 do
        for x = 2, width - 1 do
            if terrain[y][x] == "X" then
                local neighbors = grid.countNeighbors(terrain, x, y, "X")
                if neighbors <= 4 then
                    terrain[y][x] = "Z"
                end
            end
        end
    end

    local windX = math.cos(math.rad(params.wind_direction))
    local windY = math.sin(math.rad(params.wind_direction))
    for y = 1, height do
        for x = 1, width do
            if terrain[y][x] == "N" then
                local snow = context.noise:sample((x + (windX * 5)) / 20, (y + (windY * 5)) / 20)
                if snow > params.snow_cover then
                    terrain[y][x] = "A"
                end
            end
        end
    end

    return terrain
end

local function coralGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("S")
    local coralRules = {
        staghorn = {
            axiom = "F",
            rules = {
                F = "FF+[+F-F-F]-[-F+F+F]",
                ["+"] = "+",
                ["-"] = "-",
                ["["] = "[",
                ["]"] = "]",
            },
            angle = 25,
        },
        brain = {
            axiom = "F",
            rules = {
                F = "F+F-F-F+F",
                ["+"] = "+",
                ["-"] = "-",
            },
            angle = 90,
        },
    }

    for y = 1, height do
        for x = 1, width do
            if y < height * 0.2 then
                terrain[y][x] = "B"
            elseif y < height * 0.7 then
                terrain[y][x] = "W"
            else
                terrain[y][x] = "S"
            end
        end
    end

    local function growCoral(startX, startY, coralType)
        local path = coralRules[coralType].axiom
        for _ = 1, math.max(1, math.floor(params.water_temp - 25)) do
            local nextPath = {}
            for symbol in path:gmatch(".") do
                nextPath[#nextPath + 1] = coralRules[coralType].rules[symbol] or symbol
            end
            path = table.concat(nextPath)
        end

        local stack = {}
        local current = {x = startX, y = startY, angle = 90}
        for symbol in path:gmatch(".") do
            if symbol == "F" then
                local nx = round(current.x + math.cos(math.rad(current.angle)))
                local ny = current.y - 1
                if nx >= 1 and nx <= width and ny >= 1 and terrain[ny][nx] == "W" then
                    terrain[ny][nx] = "C"
                    current.x = nx
                    current.y = ny
                end
            elseif symbol == "+" then
                current.angle = current.angle + coralRules[coralType].angle
            elseif symbol == "-" then
                current.angle = current.angle - coralRules[coralType].angle
            elseif symbol == "[" then
                stack[#stack + 1] = {
                    x = current.x,
                    y = current.y,
                    angle = current.angle,
                }
            elseif symbol == "]" and #stack > 0 then
                current = table.remove(stack)
            end
        end
    end

    for x = 1, width, 10 do
        if params.acidity > 8.0 then
            growCoral(x, math.max(1, math.floor(height * 0.7) - 1), context:chance(0.5) and "staghorn" or "brain")
        end
    end

    local fishSchools = {}
    for _ = 1, math.max(1, math.floor(width / 20)) do
        fishSchools[#fishSchools + 1] = {
            x = context:randomFloat(1, width),
            y = context:randomFloat(1, math.max(1, height * 0.5)),
            dx = math.cos(params.current_strength * math.pi),
            dy = math.sin(params.current_strength * math.pi),
        }
    end

    for _ = 1, 50 do
        for _, fish in ipairs(fishSchools) do
            local separation = {x = 0, y = 0}
            local alignment = {x = 0, y = 0}
            local cohesion = {x = 0, y = 0}
            local neighbors = 0

            for _, other in ipairs(fishSchools) do
                if fish ~= other then
                    local cellDistance = distance(fish.x, fish.y, other.x, other.y)
                    if cellDistance < 5 then
                        separation.x = separation.x + (fish.x - other.x)
                        separation.y = separation.y + (fish.y - other.y)
                        alignment.x = alignment.x + other.dx
                        alignment.y = alignment.y + other.dy
                        cohesion.x = cohesion.x + other.x
                        cohesion.y = cohesion.y + other.y
                        neighbors = neighbors + 1
                    end
                end
            end

            if neighbors > 0 then
                separation.x = separation.x / neighbors
                separation.y = separation.y / neighbors
                alignment.x = alignment.x / neighbors
                alignment.y = alignment.y / neighbors
                cohesion.x = ((cohesion.x / neighbors) - fish.x) / 100
                cohesion.y = ((cohesion.y / neighbors) - fish.y) / 100
                fish.dx = fish.dx + (separation.x * 0.1) + (alignment.x * 0.01) + (cohesion.x * 0.01)
                fish.dy = fish.dy + (separation.y * 0.1) + (alignment.y * 0.01) + (cohesion.y * 0.01)
            end

            fish.dx = fish.dx + (params.current_strength * 0.1)
            fish.dy = fish.dy + context:randomFloat(-0.1, 0.1)
            fish.x = clamp(fish.x + fish.dx, 1, width)
            fish.y = clamp(fish.y + fish.dy, 1, math.max(1, height * 0.6))
            local x = clamp(round(fish.x), 1, width)
            local y = clamp(round(fish.y), 1, height)
            if terrain[y][x] == "W" then
                terrain[y][x] = "F"
            end
        end
    end

    return terrain
end

local function apocalypseGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("U")
    local mainRoadInterval = 10
    local bombPoints = {}
    local radiationMap = {}

    for y = 1, height do
        for x = 1, width do
            if x % mainRoadInterval == 0 or y % mainRoadInterval == 0 then
                terrain[y][x] = "J"
            else
                terrain[y][x] = context:chance(0.7) and "C" or "U"
            end
        end
    end

    for y = 1, height, 15 do
        for x = 1, width, 15 do
            if context:chance(0.7) then
                bombPoints[#bombPoints + 1] = {
                    x = clamp(x + context:randomInt(-5, 5), 1, width),
                    y = clamp(y + context:randomInt(-5, 5), 1, height),
                }
            end
        end
    end

    for _, bomb in ipairs(bombPoints) do
        for dy = -6, 6 do
            for dx = -6, 6 do
                local cellDistance = math.sqrt((dx * dx) + (dy * dy))
                local x = clamp(round(bomb.x + dx), 1, width)
                local y = clamp(round(bomb.y + dy), 1, height)
                if cellDistance < 3 then
                    terrain[y][x] = "Q"
                elseif cellDistance < 6 then
                    terrain[y][x] = "X"
                end
            end
        end
    end

    for _ = 1, params.radiation_level do
        local x = context:randomInt(1, width)
        local y = context:randomInt(1, height)
        for _ = 1, 100 do
            x = clamp(x + context:randomInt(-1, 1), 1, width)
            y = clamp(y + context:randomInt(-1, 1), 1, height)
            radiationMap[y] = radiationMap[y] or {}
            for dy = -2, 2 do
                for dx = -2, 2 do
                    local nx = clamp(x + dx, 1, width)
                    local ny = clamp(y + dy, 1, height)
                    radiationMap[ny] = radiationMap[ny] or {}
                    radiationMap[ny][nx] = true
                end
            end
        end
    end

    for y = 1, height do
        for x = 1, width do
            if radiationMap[y] and radiationMap[y][x] then
                terrain[y][x] = "P"
            elseif terrain[y][x] == "X" and context:chance(params.loot_density) then
                terrain[y][x] = "K"
            elseif terrain[y][x] == "-" and context:chance(0.1) then
                terrain[y][x] = context:chance(0.3) and "Y" or "F"
            end
        end
    end

    return terrain
end

local function glacierGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local heightmap = {}
    local glacierMap = {}
    local sediment = {}
    local origin = {x = 1, y = 1}
    local path = {}
    local terminus = {
        x = width,
        y = math.max(1, math.floor(height / 2)),
    }

    for y = 1, height do
        heightmap[y] = {}
        glacierMap[y] = {}
        sediment[y] = {}
        for x = 1, width do
            local elevation = 0
            local frequency = 1
            local amplitude = 1
            for _ = 1, 4 do
                elevation = elevation + (context.noise:sample(x * frequency / 50, y * frequency / 50) * amplitude)
                frequency = frequency * 2
                amplitude = amplitude * 0.5
            end
            heightmap[y][x] = elevation * 2
            glacierMap[y][x] = 0
            sediment[y][x] = 0
            if x <= math.max(1, math.floor(width * 0.2)) and heightmap[y][x] > heightmap[origin.y][origin.x] then
                origin = {x = x, y = y}
            end
        end
    end

    local iceRemaining = params.ice_thickness
    local current = {x = origin.x, y = origin.y}
    local steps = 0
    while iceRemaining > 0 and steps < 1000 do
        path[#path + 1] = {x = current.x, y = current.y}
        glacierMap[current.y][current.x] = glacierMap[current.y][current.x] + 0.1

        local candidates = {}
        local bestScore = -math.huge
        for dy = -1, 1 do
            for dx = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    local x = current.x + dx
                    local y = current.y + dy
                    if x >= 1 and x <= width and y >= 1 and y <= height then
                        local slope = (heightmap[current.y][current.x] - heightmap[y][x]) / math.sqrt((dx * dx) + (dy * dy))
                        local score = slope + (glacierMap[y][x] * 0.3)
                        if score > bestScore then
                            bestScore = score
                            candidates = {{x = x, y = y}}
                        elseif math.abs(score - bestScore) < 1e-9 then
                            candidates[#candidates + 1] = {x = x, y = y}
                        end
                    end
                end
            end
        end

        if #candidates == 0 then
            break
        end
        current = candidates[context:randomInt(1, #candidates)]
        iceRemaining = iceRemaining - 0.1
        steps = steps + 1
        if math.abs(current.x - terminus.x) < 3 and math.abs(current.y - terminus.y) < 3 then
            break
        end
    end

    for _, node in ipairs(path) do
        local valleyWidth = params.ice_thickness / 2
        for dy = -valleyWidth, valleyWidth do
            for dx = -valleyWidth, valleyWidth do
                local x = node.x + dx
                local y = node.y + dy
                if x >= 1 and x <= width and y >= 1 and y <= height then
                    local erosion = params.abrasion_rate * math.max(0, 1 - ((distance(0, 0, dx, dy) / math.max(valleyWidth * 0.8, 1)) ^ 2))
                    heightmap[y][x] = heightmap[y][x] - erosion
                    sediment[y][x] = sediment[y][x] + (erosion * 0.5)
                end
            end
        end
    end

    local moraineRadius = params.ice_thickness * 0.7
    for dy = -moraineRadius, moraineRadius do
        for dx = -moraineRadius, moraineRadius do
            local x = terminus.x + dx
            local y = terminus.y + dy
            if x >= 1 and x <= width and y >= 1 and y <= height then
                local falloff = 1 - math.min(1, distance(0, 0, dx, dy) / math.max(moraineRadius, 1))
                heightmap[y][x] = heightmap[y][x] + (sediment[y][x] * falloff)
            end
        end
    end

    local terrain = context:empty("N")
    for y = 1, height do
        for x = 1, width do
            local elevation = heightmap[y][x]
            if glacierMap[y][x] > 0.2 then
                terrain[y][x] = "Z"
            elseif elevation > 1.5 then
                terrain[y][x] = "A"
            elseif elevation > 1.2 then
                terrain[y][x] = "M"
            elseif elevation > 0.8 then
                terrain[y][x] = "R"
            elseif elevation > 0.6 then
                terrain[y][x] = sediment[y][x] > 0.3 and "K" or "X"
            elseif elevation > 0.4 then
                terrain[y][x] = "D"
            elseif elevation > 0.3 then
                terrain[y][x] = "H"
            else
                terrain[y][x] = "N"
            end
        end
    end

    return terrain
end

local function islandGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local spectralMap = {}
    local islands = {}
    local debrisMap = {}
    local terrain = context:empty("-")

    for y = 1, height do
        spectralMap[y] = {}
        debrisMap[y] = {}
        for x = 1, width do
            local nx = x / 50
            local ny = y / 50
            spectralMap[y][x] = (context.noise:sample(nx, ny) * 0.5)
                + (context.noise:sample(nx * 3, ny * 3) * 0.3)
                + (context.noise:sample(nx * 9, ny * 9) * 0.2)
        end
    end

    local islandCount = math.max(1, math.floor(width * height / 1000))
    for _ = 1, islandCount do
        islands[#islands + 1] = {
            x = context:randomFloat(1, width),
            y = context:randomFloat(1, height),
            radius = context:randomFloat(4, math.max(5, 25 * params.anti_gravity)),
            height = context:randomFloat(0.2, 1),
        }
    end

    for y = 1, height do
        for x = 1, width do
            local influence = 0
            for _, island in ipairs(islands) do
                local normalized = distance(x, y, island.x, island.y) / island.radius
                influence = math.max(influence, math.max(0, 1 - (normalized * normalized)) * island.height)
            end
            local combined = (spectralMap[y][x] * 0.7) + (influence * 0.3)
            if combined > 0.5 then
                terrain[y][x] = "R"
                for drop = 1, math.floor((1 - params.anti_gravity) * 10) do
                    if y + drop <= height then
                        debrisMap[y + drop][x] = context:chance(0.3) and "X" or "R"
                    end
                end
            elseif combined > 0.4 then
                terrain[y][x] = "G"
            end
        end
    end

    for y = 1, height do
        for x = 1, width do
            if terrain[y][x] == "R" and context:chance(params.crystal_density) then
                terrain[y][x] = "Q"
            end
            if debrisMap[y][x] then
                terrain[y][x] = debrisMap[y][x]
            end
            if terrain[y][x] == "-" and context.noise:sample(x / 30, y / 30) > params.cloud_layer then
                terrain[y][x] = "M"
            end
        end
    end

    return terrain
end

local function megaGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local terrain = context:empty("-")

    local function quantumPosition(x, y)
        local qx = (math.floor(x) + math.floor(y / 20)) % width
        local qy = (math.floor(y) + math.floor(x / 20)) % height
        if qx == 0 then
            qx = width
        end
        if qy == 0 then
            qy = height
        end
        return qx, qy
    end

    local function generateStructure(x, y, size, depth)
        if depth > params.tech_level then
            return
        end
        if depth == 0 then
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local qx, qy = quantumPosition(x + dx, y + dy)
                    terrain[qy][qx] = "Q"
                end
            end
        end

        local angle = math.pi * params.quantum_flux
        for i = 1, 4 do
            local newSize = size * 0.6
            local dirX = math.cos(angle * i)
            local dirY = math.sin(angle * i)
            local nextX, nextY = quantumPosition(x + (dirX * size * 2), y + (dirY * size * 2))
            for step = 0, math.floor(size * 1.5) do
                local qx, qy = quantumPosition(x + (dirX * step * 2), y + (dirY * step * 2))
                if context.noise:sample(qx / 10, qy / 10) > 0.3 then
                    terrain[qy][qx] = "P"
                end
            end
            generateStructure(nextX, nextY, newSize, depth + 1)
        end
    end

    generateStructure(width / 4, height / 4, 20, 0)
    generateStructure(width / 2, height / 2, 20, 0)
    generateStructure(width * 0.75, height * 0.75, 20, 0)

    for y = 1, height do
        for x = 1, width do
            if context.noise:sample((x / 5) + 1000, y / 5) > (1 - params.bio_luminescence) then
                terrain[y][x] = "C"
            end
        end
    end

    return terrain
end

local function farmGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local seeds = {}
    local fieldCount = math.max(1, math.floor(width * height / 100))

    for _ = 1, fieldCount do
        seeds[#seeds + 1] = {
            x = context:randomInt(1, width),
            y = context:randomInt(1, height),
            crop = context:randomInt(1, params.crop_types),
        }
    end

    local function calculateFitness(candidate)
        local total = 0
        for _, seed in ipairs(candidate) do
            local waterDistance = math.min(seed.x / width, 1 - (seed.x / width), seed.y / height)
            local soil = context.noise:sample(seed.x / 50, seed.y / 50) * params.soil_quality
            total = total + ((waterDistance * params.water_access) + soil)
                * (1.2 - (0.4 * seed.crop / params.crop_types))
        end
        return total
    end

    local mutationRate = 0.1
    for _ = 1, 50 do
        local population = {}
        for _ = 1, 10 do
            local candidate = {}
            for _, seed in ipairs(seeds) do
                local crop = context:chance(mutationRate) and context:randomInt(1, params.crop_types) or seed.crop
                candidate[#candidate + 1] = {
                    x = seed.x,
                    y = seed.y,
                    crop = crop,
                }
            end
            candidate.fitness = calculateFitness(candidate)
            population[#population + 1] = candidate
        end
        table.sort(population, function(a, b)
            return a.fitness > b.fitness
        end)
        seeds = population[1]
    end

    local terrain = context:empty("C")
    for y = 1, height do
        for x = 1, width do
            local bestCrop = 1
            local bestDistance = math.huge
            for _, seed in ipairs(seeds) do
                local dx = x - seed.x
                local dy = y - seed.y
                local cellDistance = (dx * dx) + (dy * dy)
                if cellDistance < bestDistance then
                    bestDistance = cellDistance
                    bestCrop = seed.crop
                end
            end

            local crop = bestCrop
            local seedRotation = context.seed % params.crop_types
            local soilBias = context.noise:sample((x / 15) + params.soil_quality, (y / 15) + params.water_access)
            if soilBias > 0.82 then
                crop = (crop % params.crop_types) + 1
            end
            crop = ((crop + seedRotation - 1) % params.crop_types) + 1

            if crop == 1 then
                terrain[y][x] = "C"
            elseif crop == 2 then
                terrain[y][x] = "H"
            else
                terrain[y][x] = "Y"
            end
        end
    end

    for y = 2, height - 1 do
        for x = 2, width - 1 do
            if (context.noise:sample(x / 30, y / 30) * params.water_access) > 0.6 then
                terrain[y][x] = "W"
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if terrain[y + dy][x + dx] ~= "W" and context:chance(0.3) then
                            terrain[y + dy][x + dx] = "L"
                        end
                    end
                end
            end
        end
    end

    return terrain
end

local function templeGenerator(context)
    local width = context.width
    local height = context.height
    local params = context.params
    local tiles = {
        J = {rules = {north = {"J", "A"}, south = {"J", "S"}, east = {"J", "S"}, west = {"J", "S"}}},
        S = {rules = {north = {"J", "S", "C"}, south = {"J", "S", "C"}, east = {"J", "S", "C"}, west = {"J", "S", "C"}}},
        C = {rules = {north = {"S"}, south = {"S"}, east = {"S"}, west = {"S"}}},
        A = {rules = {north = {"S"}, south = {"J"}, east = {"J"}, west = {"J"}}},
        F = {rules = {north = {"F", "S"}, south = {"F", "S"}, east = {"F", "S"}, west = {"F", "S"}}},
    }
    local state = {}

    for y = 1, height do
        state[y] = {}
        for x = 1, width do
            state[y][x] = {
                possible = {"J", "S", "C", "A", "F"},
                entropy = 5,
                collapsed = false,
            }
        end
    end

    local center = math.floor(params.complex_size / 2)
    for y = center, math.max(center, height - center) do
        for x = center, math.max(center, width - center) do
            if x >= 1 and x <= width and y >= 1 and y <= height then
                state[y][x] = {
                    possible = {"S"},
                    entropy = 1,
                    collapsed = false,
                }
            end
        end
    end

    local function collapse()
        local minEntropy = math.huge
        local candidates = {}
        for y = 1, height do
            for x = 1, width do
                local cell = state[y][x]
                if not cell.collapsed and cell.entropy < minEntropy then
                    minEntropy = cell.entropy
                    candidates = {{x = x, y = y}}
                elseif not cell.collapsed and cell.entropy == minEntropy then
                    candidates[#candidates + 1] = {x = x, y = y}
                end
            end
        end
        if #candidates == 0 then
            return nil
        end
        local cell = candidates[context:randomInt(1, #candidates)]
        local chosen = state[cell.y][cell.x].possible[context:randomInt(1, #state[cell.y][cell.x].possible)]
        state[cell.y][cell.x].possible = {chosen}
        state[cell.y][cell.x].entropy = 1
        state[cell.y][cell.x].collapsed = true
        return cell
    end

    local function propagate(start)
        local queue = {start}
        while #queue > 0 do
            local current = table.remove(queue, 1)
            local tile = state[current.y][current.x].possible[1]
            if tile then
                local neighbors = {
                    north = {x = current.x, y = current.y - 1},
                    south = {x = current.x, y = current.y + 1},
                    east = {x = current.x + 1, y = current.y},
                    west = {x = current.x - 1, y = current.y},
                }
                for direction, node in pairs(neighbors) do
                    if node.x >= 1 and node.x <= width and node.y >= 1 and node.y <= height then
                        local cell = state[node.y][node.x]
                        if not cell.collapsed then
                            local valid = {}
                            for _, possible in ipairs(cell.possible) do
                                for _, allowed in ipairs(tiles[tile].rules[direction]) do
                                    if possible == allowed then
                                        valid[#valid + 1] = possible
                                        break
                                    end
                                end
                            end
                            if #valid == 0 then
                                valid = {"S"}
                            end
                            if #valid ~= #cell.possible then
                                cell.possible = valid
                                cell.entropy = #valid
                                queue[#queue + 1] = {x = node.x, y = node.y}
                            end
                        end
                    end
                end
            end
        end
    end

    while true do
        local cell = collapse()
        if not cell then
            break
        end
        propagate(cell)
    end

    local terrain = context:empty("S")
    for y = 1, height do
        for x = 1, width do
            local tile = state[y][x].possible[1]
            if tile == "J" and context.noise:sample(x / 10, y / 10) > (params.age / 2000) then
                tile = "X"
            elseif tile == "S" and context.noise:sample(x / 8, y / 8) > (params.age / 1500) then
                tile = "F"
            end
            terrain[y][x] = tile
        end
    end

    return terrain
end

register({
    id = "apocalypse",
    name = "Apocalyptic Wasteland",
    summary = "Urban-grid ruin generation with craters, fallout, and scavenging pockets.",
    params = {
        floatParam("destruction_year", 2145, 2050, 2300, "Narrative year for ruin bias.", {type = "int", evolve = false}),
        floatParam("radiation_level", 4, 1, 10, "Number of radiation walks.", {type = "int"}),
        floatParam("loot_density", 0.2, 0.05, 0.5, "Chance to convert rubble into salvage."),
    },
    symbols = {"J", "C", "U", "Q", "X", "P", "K", "Y", "F"},
    generate = apocalypseGenerator,
})

register({
    id = "archipelago",
    name = "Archipelago",
    summary = "Island-cluster generator with beaches, reef rings, and deep-water separation.",
    params = {
        floatParam("num_islands", 8, 3, 20, "Number of primary island masses.", {type = "int"}),
        floatParam("min_island_size", 8, 4, 18, "Minimum island radius.", {type = "int"}),
        floatParam("max_island_size", 25, 8, 40, "Maximum island radius.", {type = "int"}),
    },
    symbols = {"M", "R", "F", "O", "S", "W", "B"},
    generate = archipelagoGenerator,
})

register({
    id = "badlands",
    name = "Badlands",
    summary = "Mesa-heavy arid terrain with stratified layers, arroyos, and flash-flood basins.",
    params = {
        floatParam("mesa_count", 6, 2, 12, "Count of mesa formations.", {type = "int"}),
        floatParam("erosion_intensity", 0.3, 0.1, 0.6, "Strength of erosion noise."),
        floatParam("stratification", 0.05, 0.01, 0.15, "Amplitude of layered strata."),
    },
    symbols = {"R", "K", "O", "X", "D", "S", "W"},
    generate = badlandsGenerator,
})

register({
    id = "canyon",
    name = "Canyon System",
    summary = "Meandering canyon terrain carved by a central river and tributary erosion.",
    params = {
        floatParam("num_tributaries", 3, 1, 6, "Number of tributary channels.", {type = "int"}),
        floatParam("erosion_depth", 0.8, 0.3, 1.0, "Depth of the canyon cut."),
        floatParam("meander_intensity", 5, 1, 10, "Side-to-side curvature of the main channel."),
    },
    symbols = {"W", "S", "R", "M", "X", "O", "D"},
    generate = canyonGenerator,
})

register({
    id = "cave",
    name = "Cave Network",
    summary = "Cellular cave carving with chamber linking and mineral-vein decoration.",
    params = {
        floatParam("initial_density", 0.4, 0.2, 0.6, "Initial rock fill ratio."),
        floatParam("erosion_passes", 5, 2, 10, "Cellular smoothing passes.", {type = "int"}),
        floatParam("mineral_veins", 5, 1, 15, "Number of mineral clusters.", {type = "int"}),
    },
    symbols = {"U", "-", "T"},
    generate = caveGenerator,
})

register({
    id = "coast",
    name = "Coastline",
    summary = "Fractal coastline profile with open water, shore bands, and inland terrain.",
    params = {
        floatParam("roughness", 0.7, 0.3, 1.0, "Fractal roughness of the coastline."),
        floatParam("iterations", 7, 3, 12, "Subdivision depth for the shoreline profile.", {type = "int"}),
        floatParam("sea_level", 0.35, 0.1, 0.6, "Sea-height threshold."),
    },
    symbols = {"B", "W", "O", "G"},
    generate = coastGenerator,
})

register({
    id = "coral",
    name = "Coral Reef",
    summary = "Layered reef biome with L-system coral growth and schooling fish trails.",
    params = {
        floatParam("water_temp", 28, 20, 35, "Water temperature influencing coral growth."),
        floatParam("acidity", 8.1, 7.5, 8.5, "Water acidity threshold for coral health."),
        floatParam("current_strength", 0.4, 0.1, 0.8, "Ocean-current influence on fish schooling."),
    },
    symbols = {"B", "W", "S", "C", "F"},
    generate = coralGenerator,
})

register({
    id = "desert",
    name = "Desert Dunes",
    summary = "Wind-driven dune field with variable slopes, ridges, and exposed flats.",
    params = {
        floatParam("wind_direction", 30, 0, 360, "Dominant dune-forming wind direction."),
        floatParam("sand_mobility", 0.7, 0.2, 1.0, "How easily dunes accumulate."),
        floatParam("dune_spacing", 10, 5, 25, "Spacing between dune bands.", {type = "int"}),
    },
    symbols = {"O", "Y", "S", "X", "-"},
    generate = desertGenerator,
})

register({
    id = "farm",
    name = "Farmland",
    summary = "Field-partitioned farmland optimized for crop mix and water distribution.",
    params = {
        floatParam("soil_quality", 0.7, 0.2, 1.0, "Base fertility of field centers."),
        floatParam("water_access", 0.4, 0.1, 0.8, "Availability of irrigation."),
        floatParam("crop_types", 3, 1, 6, "Number of crop classes.", {type = "int"}),
    },
    symbols = {"C", "H", "Y", "W", "L"},
    generate = farmGenerator,
})

register({
    id = "forest",
    name = "Dense Forest",
    summary = "Noise-driven forest cover with clearings and an optional winding river.",
    params = {
        floatParam("num_clearings", 4, 1, 10, "How many grass clearings to carve.", {type = "int"}),
        floatParam("tree_density", 0.6, 0.1, 0.95, "Density of the canopy noise."),
        boolParam("river_enabled", true, "Whether to cut a river through the forest."),
        floatParam("river_width", 3, 1, 8, "Half-width of the river corridor.", {type = "int"}),
    },
    symbols = {"E", "F", "T", "G", "W", "S"},
    generate = forestGenerator,
})

register({
    id = "glacier",
    name = "Glacial Valley",
    summary = "Ice-carved valley generation with moraine deposits and high-elevation snow.",
    params = {
        floatParam("ice_thickness", 30, 10, 60, "Thickness of the glacier body.", {type = "int"}),
        floatParam("abrasion_rate", 0.05, 0.01, 0.15, "Amount of erosion per pass."),
    },
    symbols = {"Z", "A", "M", "R", "K", "X", "D", "H", "N"},
    generate = glacierGenerator,
})

register({
    id = "island",
    name = "Floating Islands",
    summary = "Sky-island terrain with debris tails, cloud fields, and crystalline outcrops.",
    params = {
        floatParam("anti_gravity", 0.9, 0.5, 1.0, "Controls island suspension and debris falloff."),
        floatParam("crystal_density", 0.15, 0.05, 0.4, "Chance to convert rock to crystals."),
        floatParam("cloud_layer", 0.6, 0.3, 0.9, "Noise threshold for cloud coverage."),
    },
    symbols = {"R", "G", "-", "X", "Q", "M"},
    generate = islandGenerator,
})

register({
    id = "mega",
    name = "Megastructure",
    summary = "Recursive synthetic architecture with quantum offsets and luminous overlays.",
    params = {
        floatParam("tech_level", 7, 1, 10, "Recursion depth of the structure.", {type = "int"}),
        floatParam("bio_luminescence", 0.8, 0.2, 1.0, "Coverage of glowing overlays."),
        floatParam("quantum_flux", 0.3, 0.05, 0.8, "Angular variation in the recursive layout."),
    },
    symbols = {"Q", "P", "C", "-"},
    generate = megaGenerator,
})

register({
    id = "mountain",
    name = "Mountain Range",
    summary = "Peak-driven mountain terrain with ridges and multi-band elevation zones.",
    params = {
        floatParam("peak_count", 5, 1, 12, "Number of major peaks.", {type = "int"}),
        floatParam("peak_height", 1.0, 0.5, 1.5, "Relative height of peaks."),
        floatParam("ridge_intensity", 0.4, 0.1, 0.8, "Contribution of ridge noise."),
    },
    symbols = {"A", "M", "R", "X", "T", "F", "G"},
    generate = mountainGenerator,
})

register({
    id = "river",
    name = "River Basin",
    summary = "Hydrology-inspired basin formation with flow accumulation and floodplain bands.",
    params = {
        floatParam("river_count", 5, 1, 10, "How many primary rivers to carve.", {type = "int"}),
        floatParam("sediment_load", 0.4, 0.1, 0.8, "How much nearby terrain erodes into rivers."),
        floatParam("delta_size", 0.3, 0.1, 0.6, "Controls meander phase progression."),
    },
    symbols = {"W", "B", "S", "D", "R"},
    generate = riverGenerator,
})

register({
    id = "swamp",
    name = "Swamp Ecosystem",
    summary = "Voronoi-shaped wetland with flood cycles, mounds, and mangrove growth.",
    params = {
        floatParam("humidity", 0.8, 0.3, 1.0, "Overall wetness of the biome."),
        floatParam("biodiversity", 3, 1, 6, "Controls mangrove branching complexity.", {type = "int"}),
        floatParam("flood_cycle", 0.2, 0.05, 0.5, "Frequency of flooded cells."),
    },
    symbols = {"B", "W", "V", "H", "F", "T"},
    generate = swampGenerator,
})

register({
    id = "temple",
    name = "Forest Temple",
    summary = "Wave-function-style temple layouts aged by erosion and overgrowth.",
    params = {
        floatParam("complex_size", 6, 3, 12, "Approximate size of the temple footprint.", {type = "int"}),
        floatParam("age", 1000, 100, 3000, "Age used to bias decay and vegetation."),
    },
    symbols = {"J", "S", "C", "A", "F", "X"},
    generate = templeGenerator,
})

register({
    id = "tundra",
    name = "Tundra Biome",
    summary = "Reaction-diffusion permafrost patterns with wind-driven snow coverage.",
    params = {
        floatParam("permafrost_depth", 0.9, 0.3, 1.0, "Strength of frozen patterning."),
        floatParam("wind_direction", 270, 0, 360, "Wind direction for snow deposition."),
        floatParam("snow_cover", 0.6, 0.1, 0.9, "Threshold for snow coverage."),
    },
    symbols = {"X", "N", "Z", "A"},
    generate = tundraGenerator,
})

register({
    id = "urban",
    name = "Urban Grid",
    summary = "Era-biased procedural city blocks with parks, industry, and waterfront edges.",
    params = {
        floatParam("population", 2000, 500, 5000, "Population scale used to size blocks.", {type = "int"}),
        boolParam("water_access", true, "Whether to reserve a waterfront edge."),
        stringParam("era", "1920s", {"1920s", "modern"}, "Street-grid era bias."),
    },
    symbols = {"-", "J", "U", "D", "H", "C", "P", "R", "X", "F", "Y", "W", "B"},
    generate = urbanGenerator,
})

register({
    id = "volcano",
    name = "Volcanic Archipelago",
    summary = "Caldera-centered volcanic terrain with lava channels, moisture, and shoreline bands.",
    params = {
        floatParam("base_scale", 50, 20, 100, "Base scale of the elevation noise."),
        floatParam("magma_channels", 4, 2, 8, "Number of volcanic octaves.", {type = "int"}),
        floatParam("lava_flow", 0.1, 0.01, 0.5, "Heat added by the caldera."),
    },
    symbols = {"B", "L", "S", "V", "G", "R", "Q", "M"},
    generate = volcanoGenerator,
})

table.sort(descriptorList)

function registry.list()
    return serialize.deepCopy(descriptorList)
end

function registry.get(id)
    return descriptors[id]
end

function registry.describe(id)
    local descriptor = assert(descriptors[id], "Unknown terrain generator '" .. tostring(id) .. "'")
    return describeDescriptor(descriptor)
end

function registry.defaultParams(id)
    local descriptor = assert(descriptors[id], "Unknown terrain generator '" .. tostring(id) .. "'")
    return applyDefaults(descriptor, {})
end

function registry.buildContext(id, width, height, options)
    local descriptor = assert(descriptors[id], "Unknown terrain generator '" .. tostring(id) .. "'")
    return buildContext(descriptor, width, height, options)
end

function registry.generate(id, width, height, options)
    local descriptor = assert(descriptors[id], "Unknown terrain generator '" .. tostring(id) .. "'")
    local context = buildContext(descriptor, width, height, options)
    local terrain = descriptor.generate(context)
    return terrain, metadataFor(descriptor, context)
end

return registry
