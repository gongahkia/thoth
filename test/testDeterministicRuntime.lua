local runtimeModule = require("thoth.game.runtime")
local contract = require("thoth.adapters.contract")

local function runSimulation(seed, deltas)
    local runtime = runtimeModule.new(contract.nullAdapter(), {
        fixedDelta = 0.1,
        maxFrameDelta = 1,
        seed = seed,
    })
    local numbers = {}

    runtime:registerSystem({
        name = "rng",
        fixedUpdate = function(rt)
            numbers[#numbers + 1] = rt:randomNumber(1, 100000)
        end,
    })

    for _, dt in ipairs(deltas) do
        runtime:update(dt)
    end

    return numbers, runtime:getFrameInfo(), runtime
end

local deltas = {0.35, 0.22, 0.08}
local numbersA, frameA, runtimeA = runSimulation(42, deltas)
local numbersB, frameB = runSimulation(42, deltas)
local numbersC = runSimulation(99, deltas)

assert(#numbersA == 6, "Expected six deterministic fixed-step samples")
assert(#numbersA == #numbersB, "Equal seeds should produce equal sample counts")
for i = 1, #numbersA do
    assert(numbersA[i] == numbersB[i], "Equal seeds and deltas should reproduce the same sequence")
end

local diverged = false
for i = 1, #numbersA do
    if numbersA[i] ~= numbersC[i] then
        diverged = true
        break
    end
end
assert(diverged, "Different seeds should diverge")

assert(frameA.index == 3, "Frame index should count update calls")
assert(frameA.fixedIndex == 6, "Fixed index should count executed fixed steps")
assert(math.abs(frameA.time - 0.65) < 1e-9, "Frame time should accumulate dt")
assert(math.abs(frameA.fixedTime - 0.6) < 1e-9, "Fixed time should accumulate fixed dt")
assert(frameA.fixedStepsLastFrame == 1, "Last update should execute one fixed step")
assert(math.abs(frameA.alpha - 0.5) < 1e-9, "Accumulator alpha should be preserved")
assert(frameA.fixedDelta == 0.1, "Frame metadata should expose fixed delta")

assert(frameA.index == frameB.index)
assert(frameA.fixedIndex == frameB.fixedIndex)
assert(frameA.fixedStepsLastFrame == frameB.fixedStepsLastFrame)
assert(math.abs(frameA.alpha - frameB.alpha) < 1e-9)

local frameCopy = runtimeA:getFrameInfo()
frameCopy.index = 999
assert(runtimeA:getFrameInfo().index == 3, "Frame info should be returned by value")

local first = runtimeA:randomNumber(1, 100000)
runtimeA:setSeed(123)
local resetFirst = runtimeA:randomNumber(1, 100000)
runtimeA:setSeed(123)
assert(runtimeA:randomNumber(1, 100000) == resetFirst, "Resetting the runtime seed should reset the RNG stream")
assert(first ~= resetFirst, "Changing the seed should change the stream")

assert(runtimeA:getSeed() == 123, "Runtime should expose the configured seed")
assert(type(runtimeA:randomChoice({"a", "b", "c"})) == "string", "Runtime should expose random choice")
