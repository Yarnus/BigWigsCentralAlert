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

local function NormalizeNumber(value, fallback, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    value = math.floor(value + 0.5)
    return math.max(minimum, math.min(maximum, value))
end

local function NormalizeBoolean(value, fallback)
    return type(value) == "boolean" and value or fallback
end

local function NormalizeEnum(value, fallback, allowed)
    return allowed[value] and value or fallback
end

function ns.NormalizeSettings(saved)
    saved = type(saved) == "table" and saved or {}
    local result = CopyDefaults(defaults)

    if type(saved.font) == "string" and saved.font ~= "" then
        result.font = saved.font
    end
    result.fontSize = NormalizeNumber(saved.fontSize, defaults.fontSize, 12, 72)
    result.spacing = NormalizeNumber(saved.spacing, defaults.spacing, 0, 30)
    result.x = NormalizeNumber(saved.x, defaults.x, -900, 900)
    result.y = NormalizeNumber(saved.y, defaults.y, -500, 500)
    result.leadTime = NormalizeNumber(saved.leadTime, defaults.leadTime, 0, 20)

    result.outline = NormalizeEnum(saved.outline, defaults.outline, {
        NONE = true, OUTLINE = true, THICKOUTLINE = true,
    })
    result.layout = NormalizeEnum(saved.layout, defaults.layout, {
        INLINE = true, STACKED = true,
    })
    result.rounding = NormalizeEnum(saved.rounding, defaults.rounding, {
        CEIL = true, FLOOR = true,
    })

    for _, key in ipairs({ "monochrome", "shadow", "locked", "brackets", "showImportant", "showNormal" }) do
        result[key] = NormalizeBoolean(saved[key], defaults[key])
    end
    return result
end

function ns.GetStackedLayoutMetrics(fontSize, spacing)
    local rowOffset = (fontSize + spacing) / 2
    return rowOffset, fontSize * 2 + spacing + 20
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
        local record = bars[selected]
        ns.Display:ShowBar(selected, record and record.icon)
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

function ns.TrackBar(bar, icon)
    if not bar then
        return
    end
    local record = bars[bar]
    if not record then
        sequence = sequence + 1
        record = { order = sequence, important = false }
        bars[bar] = record
    end
    record.icon = icon
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

function ns.StartTest(isAutoPreview)
    ns.testActive = true
    ns.autoPreviewActive = isAutoPreview == true
    CancelTransitionTimer()
    currentBar = nil
    ns.Display:ShowTest(ns.L.TEST_TEXT, math.max(5, ns.db.leadTime))
end

function ns.StopTest()
    ns.testActive = false
    ns.autoPreviewActive = false
    ns.Display:Hide()
    ns.RefreshSelection(true)
end

function ns.StopAutoPreview()
    if ns.testActive and ns.autoPreviewActive then
        ns.StopTest()
    end
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

    BigWigsCentralAlertDB = ns.NormalizeSettings(BigWigsCentralAlertDB)
    ns.db = BigWigsCentralAlertDB
    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    if media and not media:IsValid("font", ns.db.font) then
        ns.db.font = defaults.font
    end
    ns.Display:Initialize()
    ns.Adapter:Initialize()
    ns.Options:Initialize()
end)
