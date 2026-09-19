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

local normalized = namespace.NormalizeSettings("invalid root")
assert(type(normalized) == "table" and normalized.leadTime == 10, "invalid saved-variable root resets to defaults")
normalized = namespace.NormalizeSettings({
    fontSize = "999",
    spacing = -4,
    leadTime = "5",
    layout = "INVALID",
    showImportant = "yes",
})
assert(normalized.fontSize == 72, "font size is converted and clamped")
assert(normalized.spacing == 0, "spacing is clamped")
assert(normalized.leadTime == 5, "numeric strings are normalized")
assert(normalized.layout == "INLINE", "invalid enums reset to defaults")
assert(normalized.showImportant == true, "invalid booleans reset to defaults")

local rowOffset, frameHeight = namespace.GetStackedLayoutMetrics(72, 8)
assert(rowOffset * 2 >= 80 and frameHeight >= 152, "large stacked text rows cannot overlap")

local prefix, suffix = namespace.BuildCountdownAffixes(true)
assert(prefix == "(" and suffix == ")", "native formatter unit must not receive a duplicate seconds suffix")
prefix, suffix = namespace.BuildCountdownAffixes(false)
assert(prefix == "" and suffix == "", "disabled brackets produce no affixes")

local shown, shownIcon
namespace.db = settings
namespace.Display = {
    ShowBar = function(_, bar, icon)
        shown = bar
        shownIcon = icon
    end,
    ShowTest = function() end,
    Hide = function() shown = nil end,
}
local moduleA, moduleB = {}, {}
local moduleABar = Bar(5, true, nil, moduleA)
local moduleBBar = Bar(8, true, nil, moduleB)
namespace.TrackBar(moduleABar, 12345)
namespace.TrackBar(moduleBBar, 67890)
assert(shown == moduleABar, "tracks the shortest normal bar")
assert(shownIcon == 12345, "preserves the original callback icon independently of bar display settings")
namespace.MarkBarImportant(moduleABar)
assert(shown == moduleABar, "preserves a bar when it becomes important")
namespace.ForgetModule(moduleB)
assert(shown == moduleABar, "disabling another module preserves the current bar")
namespace.ForgetModule(moduleA)
assert(shown == nil, "disabling the owning module removes its bar")

namespace.L = { TEST_TEXT = "Test" }
namespace.StartTest(true)
assert(namespace.testActive and namespace.autoPreviewActive, "automatic preview state is tracked")
namespace.StopAutoPreview()
assert(not namespace.testActive, "automatic preview stops when locking")
namespace.StartTest(false)
namespace.StopAutoPreview()
assert(namespace.testActive and not namespace.autoPreviewActive, "explicit tests survive automatic-preview cleanup")
namespace.StopTest()

print("selector, filtering, threshold, settings, preview, and lifecycle tests passed")
