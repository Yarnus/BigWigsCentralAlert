local addonName, ns = ...

local defaults = {
    font = "Friz Quadrata TT",
    fontSize = 34,
    outline = "OUTLINE",
    monochrome = false,
    shadow = true,
    followBarColor = true,
    textColor = { 1, 0.82, 0, 1 },
    timerColor = { 1, 1, 1, 1 },
    sameTimerColor = false,
    layout = "INLINE",
    spacing = 8,
    x = 0,
    y = 140,
    locked = true,
    brackets = true,
    secondsSuffix = true,
    rounding = "CEIL",
}

local bars = setmetatable({}, { __mode = "k" })
local sequence = 0
local currentBar
local expiryTimer
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

function ns.SelectShortest(records)
    local selectedBar, selectedExpiration, selectedOrder
    local fallbackBar, fallbackOrder

    for bar, record in pairs(records) do
        if bar.running and not bar.paused then
            if not fallbackOrder or record.order < fallbackOrder then
                fallbackBar, fallbackOrder = bar, record.order
            end

            local expiration = bar.exp
            if CanRead(expiration) and (not selectedExpiration
                or expiration < selectedExpiration
                or expiration == selectedExpiration and record.order < selectedOrder) then
                selectedBar = bar
                selectedExpiration = expiration
                selectedOrder = record.order
            end
        end
    end

    return selectedBar or fallbackBar
end

local function CancelExpiryTimer()
    if expiryTimer then
        expiryTimer:Cancel()
        expiryTimer = nil
    end
end

local function ScheduleExpiration(bar)
    CancelExpiryTimer()
    if not bar or not CanRead(bar.exp) then
        return
    end

    local delay = math.max(0.05, bar.exp - GetTime() + 0.05)
    expiryTimer = C_Timer.NewTimer(delay, function()
        expiryTimer = nil
        if currentBar == bar then
            bars[bar] = nil
            currentBar = nil
            ns.RefreshSelection(true)
        end
    end)
end

function ns.RefreshSelection(force)
    refreshPending = false
    if ns.testActive then
        return
    end

    local selected = ns.SelectShortest(bars)
    if selected == currentBar and not force then
        return
    end

    currentBar = selected
    ScheduleExpiration(selected)
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

function ns.TrackEmphasizedBar(bar)
    if not bar then
        return
    end
    sequence = sequence + 1
    bars[bar] = { order = sequence }
    ns.RefreshSelection(currentBar == bar)
end

function ns.ForgetBar(bar)
    if not bar then
        return
    end
    bars[bar] = nil
    local wasCurrent = currentBar == bar
    if wasCurrent then
        currentBar = nil
        CancelExpiryTimer()
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
        CancelExpiryTimer()
    end
    ns.RefreshSelection(currentWasRemoved)
end

function ns.ClearBars()
    CancelExpiryTimer()
    bars = setmetatable({}, { __mode = "k" })
    currentBar = nil
    if not ns.testActive and ns.Display then
        ns.Display:Hide()
    end
end

function ns.StartTest()
    ns.testActive = true
    CancelExpiryTimer()
    currentBar = nil
    ns.Display:ShowTest(ns.L.TEST_TEXT, 15)
end

function ns.StopTest()
    ns.testActive = false
    ns.Display:Hide()
    ns.RefreshSelection()
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
