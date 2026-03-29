local serialize = require("thoth.core.serialize")

local palette = {}

local colors = {
    G = {0.4, 0.8, 0.4, 1},
    W = {0.3, 0.3, 1.0, 1},
    R = {0.5, 0.5, 0.5, 1},
    S = {0.9, 0.8, 0.6, 1},
    D = {0.2, 0.1, 0.0, 1},
    F = {0.1, 0.5, 0.1, 1},
    T = {0.6, 0.4, 0.2, 1},
    M = {0.8, 0.8, 0.8, 1},
    L = {0.2, 0.4, 0.8, 1},
    B = {0.0, 0.0, 0.2, 1},
    P = {0.7, 0.4, 0.7, 1},
    C = {0.7, 0.7, 0.2, 1},
    A = {1.0, 1.0, 1.0, 1},
    H = {0.5, 0.7, 0.3, 1},
    V = {0.1, 0.7, 0.5, 1},
    O = {0.9, 0.6, 0.2, 1},
    E = {0.4, 0.2, 0.6, 1},
    U = {0.3, 0.2, 0.1, 1},
    Y = {0.9, 0.9, 0.4, 1},
    Q = {0.5, 0.0, 0.0, 1},
    N = {0.6, 0.6, 0.9, 1},
    Z = {0.3, 0.7, 0.9, 1},
    X = {0.7, 0.7, 0.7, 1},
    J = {0.2, 0.2, 0.2, 1},
    K = {0.8, 0.5, 0.2, 1},
    I = {0.7, 0.9, 1.0, 1},
    ["-"] = {0.0, 0.0, 0.0, 0},
}

function palette.all()
    return serialize.deepCopy(colors)
end

function palette.get(symbol)
    local color = colors[symbol]
    if not color then
        return nil
    end
    return serialize.deepCopy(color)
end

function palette.symbols()
    local items = {}
    for symbol in pairs(colors) do
        items[#items + 1] = symbol
    end
    table.sort(items)
    return items
end

return palette
