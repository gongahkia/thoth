local logging = {}

local LEVELS = {
    debug = 10,
    info = 20,
    warn = 30,
    error = 40,
}

local Logger = {}
Logger.__index = Logger

local function defaultSink(entry)
    print(string.format("[%s] %s", entry.level:upper(), entry.message))
end

function Logger.new(options)
    options = options or {}
    local self = setmetatable({}, Logger)
    self.level = LEVELS[options.level or "info"] or LEVELS.info
    self.sink = options.sink or defaultSink
    return self
end

function Logger:log(level, message, fields)
    local rank = LEVELS[level] or LEVELS.info
    if rank < self.level then
        return false
    end
    local entry = {
        level = level,
        message = tostring(message),
        fields = fields or {},
        timestamp = os.time(),
    }
    self.sink(entry)
    return true
end

function Logger:debug(message, fields)
    return self:log("debug", message, fields)
end

function Logger:info(message, fields)
    return self:log("info", message, fields)
end

function Logger:warn(message, fields)
    return self:log("warn", message, fields)
end

function Logger:error(message, fields)
    return self:log("error", message, fields)
end

logging.Logger = Logger
logging.LEVELS = LEVELS

function logging.new(options)
    return Logger.new(options)
end

return logging
