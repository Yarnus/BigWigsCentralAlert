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

local settings = {
    leadTime = 20,
    showImportant = true,
    showNormal = true,
}

local first = Bar(20)
local second = Bar(10)
local records = {
    [first] = { order = 1, important = false },
    [second] = { order = 2, important = true },
}
assert(namespace.SelectShortest(records, settings, 0) == second, "selects shortest eligible bar")

second.paused = 5
assert(namespace.SelectShortest(records, settings, 0) == first, "ignores paused bars")

first.running = nil
assert(namespace.SelectShortest(records, settings, 0) == nil, "ignores stopped bars")

local earlier = Bar(10)
local later = Bar(10)
records = {
    [later] = { order = 8, important = false },
    [earlier] = { order = 3, important = false },
}
assert(namespace.SelectShortest(records, settings, 0) == earlier, "uses creation order as deterministic tie breaker")

local future = Bar(10)
records = { [future] = { order = 1, important = false } }
local selected, eligibleAt = namespace.SelectShortest(records, {
    leadTime = 5,
    showImportant = true,
    showNormal = true,
}, 0)
assert(selected == nil and eligibleAt == 5, "waits until the configured lead time")
assert(namespace.SelectShortest(records, {
    leadTime = 5,
    showImportant = true,
    showNormal = true,
}, 5) == future, "selects a bar when it enters the lead-time window")

records[future].important = true
assert(namespace.SelectShortest(records, {
    leadTime = 20,
    showImportant = false,
    showNormal = true,
}, 0) == nil, "important toggle excludes emphasized bars")
assert(namespace.SelectShortest(records, {
    leadTime = 20,
    showImportant = true,
    showNormal = false,
}, 0) == future, "important toggle includes emphasized bars")

local inaccessible = Bar("secret")
records = { [inaccessible] = { order = 1, important = false } }
assert(namespace.SelectShortest(records, settings, 0) == nil, "does not bypass the lead-time rule for inaccessible expiration values")

local prefix, suffix = namespace.BuildCountdownAffixes(true)
assert(prefix == "(" and suffix == ")", "native formatter unit must not receive a duplicate seconds suffix")
prefix, suffix = namespace.BuildCountdownAffixes(false)
assert(prefix == "" and suffix == "", "disabled brackets produce no affixes")

local shown
namespace.db = settings
namespace.Display = {
    ShowBar = function(_, bar) shown = bar end,
    Hide = function() shown = nil end,
}
local moduleA, moduleB = {}, {}
local moduleABar = Bar(5, true, nil, moduleA)
local moduleBBar = Bar(8, true, nil, moduleB)
namespace.TrackBar(moduleABar)
namespace.TrackBar(moduleBBar)
assert(shown == moduleABar, "tracks the shortest normal bar")
namespace.MarkBarImportant(moduleABar)
assert(shown == moduleABar, "preserves a bar when it becomes important")
namespace.ForgetModule(moduleB)
assert(shown == moduleABar, "disabling another module preserves the current bar")
namespace.ForgetModule(moduleA)
assert(shown == nil, "disabling the owning module removes its bar")

print("selector, filtering, threshold, and lifecycle tests passed")
