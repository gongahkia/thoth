local Love2DInputModule = {}

-- Internal state tracking tables
local previousKeys = {}
local currentKeys = {}
local previousMouseButtons = {}
local currentMouseButtons = {}
local typedTextBuffer = ""

-- Must be called once per frame (e.g. at the start of love.update)
function Love2DInputModule.Update()
    previousKeys = {}
    for k, v in pairs(currentKeys) do previousKeys[k] = v end
    previousMouseButtons = {}
    for k, v in pairs(currentMouseButtons) do previousMouseButtons[k] = v end
    typedTextBuffer = ""
end

-- Love2D callbacks — hook these in main.lua
function Love2DInputModule.keypressed(key)
    currentKeys[key] = true
end

function Love2DInputModule.keyreleased(key)
    currentKeys[key] = nil
end

function Love2DInputModule.mousepressed(x, y, button)
    currentMouseButtons[button] = true
end

function Love2DInputModule.mousereleased(x, y, button)
    currentMouseButtons[button] = nil
end

function Love2DInputModule.textinput(text)
    typedTextBuffer = typedTextBuffer .. text
end

-- @return coordinates of mouse as a table {x,y}
function Love2DInputModule.GetMouseXY()
    return {love.mouse.getX(), love.mouse.getY()}
end

-- @return text typed by the user since the last frame
function Love2DInputModule.GetTypedText()
    return typedTextBuffer
end

-- @param specified key to check
-- @return boolean value depending on whether the key is pressed down
function Love2DInputModule.IsKeyDown(key)
    return love.keyboard.isDown(key)
end

-- @param specified key to check
-- @return boolean value depending on whether the key is released up
function Love2DInputModule.IsKeyUp(key)
    return not love.keyboard.isDown(key)
end

-- @param x, y, width, height of the area
-- @return boolean value depending on whether the mouse cursor is within the specified area
function Love2DInputModule.IsMouseOver(x, y, width, height)
    local mouseX, mouseY = love.mouse.getPosition()
    return mouseX >= x and mouseX <= x + width and mouseY >= y and mouseY <= y + height
end

-- @param nil
-- @return boolean value depending on whether the text input is currently active
function Love2DInputModule.IsTextInputActive()
    return love.keyboard.hasTextInput()
end

-- @param specified key to check
-- @return true if the key was pressed this frame but not the previous frame
function Love2DInputModule.WasKeyPressed(key)
    return currentKeys[key] == true and not previousKeys[key]
end

-- @param specified key to check
-- @return true if the key was released this frame (held previous, not held now)
function Love2DInputModule.WasKeyReleased(key)
    return previousKeys[key] == true and not currentKeys[key]
end

-- @param mouse button (1=left, 2=right, 3=middle)
-- @return true if the button was pressed this frame but not the previous frame
function Love2DInputModule.WasMousePressed(button)
    return currentMouseButtons[button] == true and not previousMouseButtons[button]
end

-- @param mouse button (1=left, 2=right, 3=middle)
-- @return true if the button was released this frame
function Love2DInputModule.WasMouseReleased(button)
    return previousMouseButtons[button] == true and not currentMouseButtons[button]
end

return Love2DInputModule