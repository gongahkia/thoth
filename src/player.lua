local Player = {}

function Player.new(x, y)
    return { x = x or 0, y = y or 0, speed = 28 }
end

function Player.update(player, dt, input, world)
    local dx = (input.right and 1 or 0) - (input.left and 1 or 0)
    local dy = (input.down and 1 or 0) - (input.up and 1 or 0)
    if dx == 0 and dy == 0 then return player end
    local length = math.sqrt(dx * dx + dy * dy)
    dx, dy = dx / length, dy / length
    local cell = world and world:sample(math.floor(player.x), math.floor(player.y), "local") or nil
    local terrainSlow = cell and cell.water and 0.45 or (cell and cell.slope > 0.12 and 0.7 or 1)
    local speed = player.speed * terrainSlow * (input.sprint and 1.75 or 1)
    player.x = player.x + dx * speed * dt
    player.y = player.y + dy * speed * dt
    return player
end

return Player
