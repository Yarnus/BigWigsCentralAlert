local callbacks = {}
_G.BigWigsLoader = {
    RegisterMessage = function(_, event, callback)
        callbacks[event] = callback
    end,
}
_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
        UnregisterEvent = function() end,
    }
end

local trackedBar, trackedIcon, importantBar
local namespace = {
    L = { ADDON_NAME = "Test", NO_BIGWIGS = "missing" },
    TrackBar = function(bar, icon)
        trackedBar, trackedIcon = bar, icon
    end,
    MarkBarImportant = function(bar)
        importantBar = bar
    end,
    RequestRefresh = function() end,
    ForgetModule = function() end,
    ForgetBar = function() end,
}

assert(loadfile("BigWigsAdapter.lua"))("BigWigsCentralAlert", namespace)
namespace.Adapter:Initialize()

local bar = {}
callbacks.BigWigs_BarCreated("BigWigs_BarCreated", "BarsPlugin", bar, "BossModule", 123, "Renamed label", 8, 987654, false)
assert(trackedBar == bar, "forwards the created bar")
assert(trackedIcon == 987654, "forwards the original callback icon")

callbacks.BigWigs_BarEmphasized("BigWigs_BarEmphasized", "BarsPlugin", bar)
assert(importantBar == bar, "upgrades emphasized bars")

print("adapter callback tests passed")
