local State = require("src.game.tactics.state")

local Board = {}

function Board.new(options)
    return State.new(options)
end

function Board.tileAt(state, x, y)
    return state:tileAt(x, y)
end

function Board.blockerAt(state, x, y)
    return state:blockerAt(x, y)
end

function Board.rotationMarks(state, rotation)
    return state:visibleRotationMarks(rotation)
end

return Board
