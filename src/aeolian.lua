local Noise = require("src.noise")

local Aeolian = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0 then return 1, 0 end
    return x / length, y / length
end

function Aeolian.applyCell(cell, seed)
    cell.duneDelta = 0
    cell.duneAmplitude = 0
    cell.dunePhase = 0
    if cell.water or cell.river or cell.lake or cell.biome ~= "desert" then return cell end
    local windX, windY = normalize(cell.windX or 1, cell.windY or 0)
    local along = (cell.x or 0) * windX + (cell.y or 0) * windY
    local across = -(cell.x or 0) * windY + (cell.y or 0) * windX
    local envelope = Noise.value((seed or 1) + 901, (cell.x or 0) * 0.003, (cell.y or 0) * 0.003, 13)
    local phaseNoise = Noise.value((seed or 1) + 907, (cell.x or 0) * 0.012, (cell.y or 0) * 0.012, 17)
    local phase = along * 0.11 + across * 0.012 + phaseNoise * 2.2
    local crest = math.sin(phase) * 0.78 + math.sin(phase * 2.0 + 0.7) * 0.22
    local amplitude = clamp(0.007 + envelope * 0.026, 0, 0.035)
    local delta = clamp(crest * amplitude, -0.038, 0.038)
    cell.duneDelta = delta
    cell.duneAmplitude = math.abs(delta)
    cell.dunePhase = phase
    cell.elevation = (cell.elevation or cell.elevationBase or 0) + delta
    cell.slope = clamp((cell.slope or 0) + math.abs(delta) * 0.8, 0, 1)
    return cell
end

return Aeolian
