local datetime = {}

function datetime.unix()
    return os.time()
end

function datetime.iso8601(timestamp)
    return os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp or os.time())
end

function datetime.fromTable(parts)
    return os.time(parts)
end

function datetime.toTable(timestamp, utc)
    return os.date(utc and "!*t" or "*t", timestamp or os.time())
end

function datetime.addSeconds(timestamp, seconds)
    return (timestamp or os.time()) + (seconds or 0)
end

return datetime
