local addonName, ns = ...

local defaults = {
    font = "Friz Quadrata TT",
    fontSize = 34,
    outline = "OUTLINE",
    monochrome = false,
    shadow = true,
    layout = "INLINE",
    spacing = 8,
    x = 0,
    y = 140,
    locked = true,
    brackets = true,
    rounding = "CEIL",
    showImportant = true,
    showNormal = true,
    leadTime = 10,
}

local bars = setmetatable({}, { __mode = "k" })
local sequence = 0
local currentBar
local transitionTimer
local refreshPending = false

local function CopyDefaults(source)
    local result = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = CopyDefaults(value)
        else
            result[key] = value
        end
    end
    return result
end

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function CanRead(value)
    if canaccessvalue and not canaccessvalue(value) then
        return false
    end
    return type(value) == "number"
end

function ns.BuildCountdownAffixes(brackets)
    return brackets and "(" or "", brackets and ")" or ""
end

function ns.SelectShortest(records, settings, now)
    local selectedBar, selectedExpiration, selectedOrder
    local nextEligibleAt
    local leadTime = settings.leadTime or 0

    for bar, record in pairs(records) do
        local categoryEnabled = record.important and settings.showImportant
            or not record.important and settings.showNormal
        if categoryEnabled and bar.running and not bar.paused and CanRead(bar.exp) then
            local remaining = bar.exp - now
            if remaining > 0 and remaining <= leadTime then
                if not selectedExpiration
                    or bar.exp < selectedExpiration
                    or bar.exp == selectedExpiration and record.order < selectedOrder then
                    selectedBar = bar
                    selectedExpiration = bar.exp
                    selectedOrder = record.order
                end
            elseif remaining > leadTime then
                local eligibleAt = bar.exp - leadTime
                if not nextEligibleAt or eligibleAt < nextEligibleAt then
                    nextEligibleAt = eligibleAt
                end
            end
        end
    end

    return selectedBar, nextEligibleAt
end

local function CancelTransitionTimer()
    if transitionTimer then
        transitionTimer:Cancel()
        transitionTimer = nil
    end
end

local function ScheduleTransition(selected, nextEligibleAt)
    CancelTransitionTimer()
    local wakeAt = selected and selected.exp or nextEligibleAt
    if not CanRead(wakeAt) then
        return
    end

    local delay = math.max(0.05, wakeAt - GetTime() + 0.05)
    transitionTimer = C_Timer.NewTimer(delay, function()
        transitionTimer = nil
        ns.RefreshSelection(true)
    end)
end

function ns.RefreshSelection(force)
    refreshPending = false
    if ns.testActive then
        return
    end

    local selected, nextEligibleAt = ns.SelectShortest(bars, ns.db, GetTime())
    if selected == currentBar and not force then
        return
    end

    currentBar = selected
    ScheduleTransition(selected, nextEligibleAt)
    if selected then
        ns.Display:ShowBar(selected)
    else
        ns.Display:Hide()
    end
end

function ns.RequestRefresh()
    if refreshPending then
        return
    end
    refreshPending = true
    C_Timer.After(0, function()
        ns.RefreshSelection(true)
    end)
end

function ns.TrackBar(bar)
    if not bar then
        return
    end
    local record = bars[bar]
    if not record then
        sequence = sequence + 1
        record = { order = sequence, important = false }
        bars[bar] = record
    end
    ns.RefreshSelection(true)
end

function ns.MarkBarImportant(bar)
    if not bar then
        return
    end
    local record = bars[bar]
    if not record then
        sequence = sequence + 1
        record = { order = sequence }
        bars[bar] = record
    end
    record.important = true
    ns.RefreshSelection(true)
end

function ns.ForgetBar(bar)
    if not bar then
        return
    end
    bars[bar] = nil
    local wasCurrent = currentBar == bar
    if wasCurrent then
        currentBar = nil
        CancelTransitionTimer()
    end
    ns.RefreshSelection(wasCurrent)
end

function ns.ForgetModule(module)
    if not module then
        return
    end

    local currentWasRemoved = false
    for bar in pairs(bars) do
        if bar.Get and bar:Get("bigwigs:module") == module then
            bars[bar] = nil
            if currentBar == bar then
                currentWasRemoved = true
            end
        end
    end

    if currentWasRemoved then
        currentBar = nil
        CancelTransitionTimer()
    end
    ns.RefreshSelection(currentWasRemoved)
end

function ns.SettingsChanged()
    ns.RefreshSelection(true)
end

function ns.ClearBars()
    CancelTransitionTimer()
    bars = setmetatable({}, { __mode = "k" })
    currentBar = nil
    if not ns.testActive and ns.Display then
        ns.Display:Hide()
    end
end

function ns.StartTest()
    ns.testActive = true
    CancelTransitionTimer()
    currentBar = nil
    ns.Display:ShowTest(ns.L.TEST_TEXT, math.max(5, ns.db.leadTime))
end

function ns.StopTest()
    ns.testActive = false
    ns.Display:Hide()
    ns.RefreshSelection(true)
end

function ns.ToggleTest()
    if ns.testActive then
        ns.StopTest()
    else
        ns.StartTest()
    end
end

function ns.ResetSettings()
    BigWigsCentralAlertDB = CopyDefaults(defaults)
    ns.db = BigWigsCentralAlertDB
    ns.Display:ApplySettings()
    ns.SettingsChanged()
    if ns.Options then
        ns.Options:Refresh()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    BigWigsCentralAlertDB = BigWigsCentralAlertDB or {}
    ApplyDefaults(BigWigsCentralAlertDB, defaults)
    ns.db = BigWigsCentralAlertDB
    ns.Display:Initialize()
    ns.Adapter:Initialize()
    ns.Options:Initialize()
end)
