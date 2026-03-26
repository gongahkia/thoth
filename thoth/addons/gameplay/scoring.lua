local scoring = {}
local Manager = {}
Manager.__index = Manager

local DEFAULT_RANKS = {"D", "C", "B", "A", "S", "SS"}
local DEFAULT_THRESHOLDS = {0, 15, 35, 60, 85, 100}
local DEFAULT_DECAY_RATE = 8.0
local DEFAULT_VARIETY_BONUS = 1.4
local DEFAULT_REPEAT_PENALTY = 0.6
local DEFAULT_TECH_WINDOW = 5.0
local DEFAULT_MAX_SCORE = 100
local DEFAULT_FLASH_DURATION = 0.3

function Manager.new(config)
    config = config or {}
    local self = setmetatable({}, Manager)
    self.ranks = config.ranks or DEFAULT_RANKS
    self.thresholds = config.thresholds or DEFAULT_THRESHOLDS
    self.decayRate = config.decayRate or DEFAULT_DECAY_RATE
    self.varietyBonus = config.varietyBonus or DEFAULT_VARIETY_BONUS
    self.repeatPenalty = config.repeatPenalty or DEFAULT_REPEAT_PENALTY
    self.techWindow = config.techWindow or DEFAULT_TECH_WINDOW
    self.maxScore = config.maxScore or DEFAULT_MAX_SCORE
    self.basePoints = config.basePoints or {}
    self.defaultPoints = config.defaultPoints or 10
    self.flashDuration = config.flashDuration or DEFAULT_FLASH_DURATION
    self.score = 0
    self.rankIndex = 1
    self.recentTechs = {}
    self.flashTimer = 0
    return self
end

local function updateRank(self)
    self.rankIndex = 1
    for i = #self.thresholds, 1, -1 do
        if self.score >= self.thresholds[i] then
            self.rankIndex = i
            break
        end
    end
end

function Manager:notifyTech(techName, clock)
    local unique = true
    for _, entry in ipairs(self.recentTechs) do
        if entry.tech == techName then
            unique = false
            break
        end
    end
    local multiplier = unique and self.varietyBonus or self.repeatPenalty
    local points = (self.basePoints[techName] or self.defaultPoints) * multiplier
    self.score = math.min(self.maxScore, self.score + points)
    self.recentTechs[#self.recentTechs + 1] = {tech = techName, time = clock}
    self.flashTimer = self.flashDuration
    updateRank(self)
end

function Manager:update(dt, clock)
    self.flashTimer = math.max(0, self.flashTimer - dt)
    for i = #self.recentTechs, 1, -1 do
        if clock - self.recentTechs[i].time > self.techWindow then
            table.remove(self.recentTechs, i)
        end
    end
    if self.flashTimer <= 0 then
        self.score = math.max(0, self.score - self.decayRate * dt)
    end
    updateRank(self)
end

function Manager:getRank()
    return self.ranks[self.rankIndex] or self.ranks[1]
end

function Manager:getScore()
    return self.score
end

function Manager:getFlash()
    return self.flashTimer
end

function Manager:reset()
    self.score = 0
    self.rankIndex = 1
    self.recentTechs = {}
    self.flashTimer = 0
end

function Manager:snapshot()
    local techs = {}
    for i, entry in ipairs(self.recentTechs) do
        techs[i] = {tech = entry.tech, time = entry.time}
    end
    return {
        score = self.score,
        rankIndex = self.rankIndex,
        recentTechs = techs,
        flashTimer = self.flashTimer,
    }
end

function Manager:restore(snapshot)
    assert(type(snapshot) == "table", "Scoring snapshot must be a table")
    self.score = snapshot.score or 0
    self.rankIndex = snapshot.rankIndex or 1
    self.recentTechs = {}
    for i, entry in ipairs(snapshot.recentTechs or {}) do
        self.recentTechs[i] = {tech = entry.tech, time = entry.time}
    end
    self.flashTimer = snapshot.flashTimer or 0
    return self
end

scoring.Manager = Manager

function scoring.new(config)
    return Manager.new(config)
end

return scoring
