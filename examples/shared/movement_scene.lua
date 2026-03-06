local scene = {}

function scene.attach(runtime, input)
    local player = {
        x = 0,
        y = 0,
        speed = 120
    }

    input:bind("move_x", {axis = {positive = "right", negative = "left"}})
    input:bind("move_y", {axis = {positive = "down", negative = "up"}})

    runtime:registerSystem({
        name = "movement",
        priority = 10,
        update = function(_rt, dt)
            player.x = player.x + input:axis("move_x") * player.speed * dt
            player.y = player.y + input:axis("move_y") * player.speed * dt
        end
    })

    return player
end

return scene
