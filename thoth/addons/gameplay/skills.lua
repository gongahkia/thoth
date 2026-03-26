local skills = {}
local Manager = {}
Manager.__index = Manager

local DEFAULT_LEVEL_CAP = 5
local DEFAULT_XP_PER_LEVEL = 25

function Manager.new(config)
    config = config or {}
    local self = setmetatable({}, Manager)
    self.levelCap = config.levelCap or DEFAULT_LEVEL_CAP
    self.xpPerLevel = config.xpPerLevel or DEFAULT_XP_PER_LEVEL
    self.skills = {}
    for _, name in ipairs(config.names or {}) do
        self.skills[name] = {level = 1, xp = 0}
    end
    return self
end

function Manager:define(name)
    assert(type(name) == "string" and #name > 0, "Skill name must be a non-empty string")
    if not self.skills[name] then
        self.skills[name] = {level = 1, xp = 0}
    end
end

function Manager:addXP(name, amount)
    local skill = self.skills[name]
    if not skill or amount <= 0 then
        return skill and skill.level or 1
    end
    if skill.level >= self.levelCap then
        return skill.level
    end
    skill.xp = skill.xp + amount
    while skill.level < self.levelCap and skill.xp >= self.xpPerLevel do
        skill.xp = skill.xp - self.xpPerLevel
        skill.level = skill.level + 1
    end
    return skill.level
end

function Manager:getLevel(name)
    local skill = self.skills[name]
    return skill and skill.level or nil
end

function Manager:getXP(name)
    local skill = self.skills[name]
    return skill and skill.xp or nil
end

function Manager:setLevel(name, level)
    local skill = self.skills[name]
    if not skill then return end
    skill.level = math.max(1, math.min(level, self.levelCap))
    skill.xp = 0
end

function Manager:allSkills()
    local result = {}
    for name, skill in pairs(self.skills) do
        result[name] = {level = skill.level, xp = skill.xp}
    end
    return result
end

function Manager:snapshot()
    local snap = {}
    for name, skill in pairs(self.skills) do
        snap[name] = {level = skill.level, xp = skill.xp}
    end
    return {skills = snap, levelCap = self.levelCap, xpPerLevel = self.xpPerLevel}
end

function Manager:restore(snapshot)
    assert(type(snapshot) == "table", "Skills snapshot must be a table")
    self.levelCap = snapshot.levelCap or self.levelCap
    self.xpPerLevel = snapshot.xpPerLevel or self.xpPerLevel
    self.skills = {}
    for name, skill in pairs(snapshot.skills or {}) do
        self.skills[name] = {level = skill.level, xp = skill.xp}
    end
    return self
end

skills.Manager = Manager

function skills.new(config)
    return Manager.new(config)
end

return skills
