local eventFrame = {}
function eventFrame:RegisterEvent() end
function eventFrame:SetScript() end

_G.CreateFrame = function()
    return eventFrame
end
_G.GetTime = function() return 0 end
_G.C_Timer = {
    NewTimer = function()
        return { Cancel = function() end }
    end,
    After = function(_, callback) callback() end,
}

local namespace = {}
assert(loadfile("Core.lua"))("BigWigsCentralAlert", namespace)

local function Bar(expiration, running, paused, module)
    return {
        exp = expiration,
        running = running ~= false,
        paused = paused,
        Get = function(_, key)
            if key == "bigwigs:module" then
                return module
            end
        end,
    }
end

local first = Bar(20)
local second = Bar(10)
local records = {
    [first] = { order = 1 },
    [second] = { order = 2 },
}
assert(namespace.SelectShortest(records) == second, "selects shortest remaining emphasized bar")

second.paused = 5
assert(namespace.SelectShortest(records) == first, "ignores paused bars")

first.running = nil
assert(namespace.SelectShortest(records) == nil, "ignores stopped bars")

local earlier = Bar(10)
local later = Bar(10)
records = {
    [later] = { order = 8 },
    [earlier] = { order = 3 },
}
assert(namespace.SelectShortest(records) == earlier, "uses emphasis order as deterministic tie breaker")

local inaccessibleFirst = Bar("secret")
local inaccessibleSecond = Bar("secret")
records = {
    [inaccessibleSecond] = { order = 4 },
    [inaccessibleFirst] = { order = 1 },
}
assert(namespace.SelectShortest(records) == inaccessibleFirst, "falls back deterministically when expiration cannot be read")

local shown
namespace.Display = {
    ShowBar = function(_, bar) shown = bar end,
    Hide = function() shown = nil end,
}
local moduleA, moduleB = {}, {}
local moduleABar = Bar(5, true, nil, moduleA)
local moduleBBar = Bar(8, true, nil, moduleB)
namespace.TrackEmphasizedBar(moduleABar)
namespace.TrackEmphasizedBar(moduleBBar)
assert(shown == moduleABar, "tracks the shortest emphasized bar")
namespace.ForgetModule(moduleB)
assert(shown == moduleABar, "disabling another module preserves the current bar")
namespace.ForgetModule(moduleA)
assert(shown == nil, "disabling the owning module removes its bar")

print("selector and lifecycle tests passed")
