function love.conf(t)
    t.identity = "thoth"
    t.appendidentity = true
    t.version = "11.5"
    t.window.title = "Thoth"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.modules.joystick = true
    t.modules.physics = false
    t.modules.video = false
end
