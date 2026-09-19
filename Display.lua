local addonName, ns = ...

local Display = {}
ns.Display = Display

local frame
local iconTexture
local labelText
local prefixText
local timerText
local suffixText
local dragHint
local durationBinding
local secondsFormatter
local durationObject
local sourceColor = { 1, 1, 1, 1 }
local sourceIcon
local sourceIconShown = false

local function GetFontPath()
    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    if media then
        return media:Fetch("font", ns.db.font, true) or STANDARD_TEXT_FONT
    end
    return STANDARD_TEXT_FONT
end

local function GetFontFlags()
    local flags = ns.db.outline ~= "NONE" and ns.db.outline or ""
    if ns.db.monochrome then
        flags = flags ~= "" and ("MONOCHROME," .. flags) or "MONOCHROME"
    end
    return flags
end

local function SetColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function ApplyShadow(fontString)
    if ns.db.shadow then
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(2, -2)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
end

local function ApplyLayout()
    local spacing = ns.db.spacing
    labelText:ClearAllPoints()
    prefixText:ClearAllPoints()
    timerText:ClearAllPoints()
    suffixText:ClearAllPoints()

    iconTexture:ClearAllPoints()
    iconTexture:SetSize(ns.db.fontSize, ns.db.fontSize)

    if ns.db.layout == "STACKED" then
        labelText:SetPoint("CENTER", frame, "CENTER", 0, 18 + spacing / 2)
        iconTexture:SetPoint("RIGHT", labelText, "LEFT", -spacing, 0)
        timerText:SetPoint("CENTER", frame, "CENTER", 0, -18 - spacing / 2)
        prefixText:SetPoint("RIGHT", timerText, "LEFT", 0, 0)
        suffixText:SetPoint("LEFT", timerText, "RIGHT", 0, 0)
    else
        labelText:SetPoint("RIGHT", frame, "CENTER", -spacing / 2, 0)
        iconTexture:SetPoint("RIGHT", labelText, "LEFT", -spacing, 0)
        prefixText:SetPoint("LEFT", labelText, "RIGHT", spacing, 0)
        timerText:SetPoint("LEFT", prefixText, "RIGHT", 0, 0)
        suffixText:SetPoint("LEFT", timerText, "RIGHT", 0, 0)
    end
end

local function ConfigureFormatter()
    if durationBinding then
        durationBinding:SetEnabled(false)
        durationBinding:SetToDefaults()
    end

    secondsFormatter = C_StringUtil.CreateSecondsFormatter()
    secondsFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
    secondsFormatter:SetDesiredUnitCount(1)
    if secondsFormatter.SetMillisecondsThreshold then
        secondsFormatter:SetMillisecondsThreshold(0)
    end

    local rounding = Enum.SecondsFormatterRounding
    if ns.db.rounding == "CEIL" then
        secondsFormatter:SetRounding(rounding.RoundUp or rounding.RoundNearest or rounding.Truncate)
    else
        secondsFormatter:SetRounding(rounding.Truncate)
    end

    durationBinding = C_DurationUtil.CreateDurationTextBinding()
    durationBinding:SetFontString(timerText)
    durationBinding:SetTextFormat("{}", {
        {
            property = Enum.DurationTextBindingProperty.RemainingDuration,
            formatter = secondsFormatter,
        },
    })
    durationBinding:SetUpdateInterval(0)
end

local function BindExpiration(expiration)
    if durationBinding then
        durationBinding:SetEnabled(false)
    end
    durationObject = nil

    local readable = (not canaccessvalue or canaccessvalue(expiration))
        and type(expiration) == "number"
    if not readable then
        prefixText:Hide()
        timerText:Hide()
        suffixText:Hide()
        return
    end

    local remaining = math.max(0, expiration - GetTime())
    durationObject = C_DurationUtil.CreateDuration()
    durationObject:SetTimeFromEnd(expiration, remaining, 1)
    durationBinding:SetDuration(durationObject)
    durationBinding:SetEnabled(true)
    durationBinding:UpdateFontString()

    local prefix, suffix = ns.BuildCountdownAffixes(ns.db.brackets)
    prefixText:SetText(prefix)
    suffixText:SetText(suffix)
    prefixText:Show()
    timerText:Show()
    suffixText:Show()
end

local function ReadBarColor(bar)
    if not bar.candyBarLabel then
        return nil
    end
    local r, g, b, a = bar.candyBarLabel:GetTextColor()
    if type(r) == "number" and (not canaccessvalue or canaccessvalue(r)) then
        return { r, g, b, a }
    end
end

function Display:Initialize()
    if not (C_DurationUtil and C_DurationUtil.CreateDuration and C_DurationUtil.CreateDurationTextBinding) then
        error(addonName .. " requires the Retail Duration API.", 2)
    end

    frame = CreateFrame("Frame", "BigWigsCentralAlertDisplay", UIParent, "BackdropTemplate")
    frame:SetSize(900, 130)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not ns.db.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local centerX, centerY = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        ns.db.x = math.floor(centerX - parentX + 0.5)
        ns.db.y = math.floor(centerY - parentY + 0.5)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", ns.db.x, ns.db.y)
        if ns.Options then
            ns.Options:Refresh()
        end
    end)

    iconTexture = frame:CreateTexture(nil, "ARTWORK")
    iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    labelText = frame:CreateFontString(nil, "OVERLAY")
    labelText:SetWordWrap(false)
    labelText:SetMaxLines(1)

    prefixText = frame:CreateFontString(nil, "OVERLAY")
    timerText = frame:CreateFontString(nil, "OVERLAY")
    suffixText = frame:CreateFontString(nil, "OVERLAY")

    dragHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dragHint:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    dragHint:SetText(ns.L.DRAG_HINT)
    dragHint:SetTextColor(0.7, 0.7, 0.7)

    ConfigureFormatter()
    self:ApplySettings()
    frame:Hide()
end

function Display:ApplySettings()
    if not frame then
        return
    end

    local fontPath = GetFontPath()
    local flags = GetFontFlags()
    local size = ns.db.fontSize
    for _, fontString in ipairs({ labelText, prefixText, timerText, suffixText }) do
        fontString:SetFont(fontPath, size, flags)
        ApplyShadow(fontString)
    end

    SetColor(labelText, sourceColor)
    SetColor(prefixText, sourceColor)
    SetColor(timerText, sourceColor)
    SetColor(suffixText, sourceColor)
    iconTexture:SetTexture(sourceIcon)
    iconTexture:SetShown(sourceIconShown)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", ns.db.x, ns.db.y)
    frame:SetMovable(not ns.db.locked)
    frame:EnableMouse(not ns.db.locked)
    dragHint:SetShown(not ns.db.locked)
    ApplyLayout()
    ConfigureFormatter()

    if durationObject then
        durationBinding:SetDuration(durationObject)
        durationBinding:SetEnabled(true)
        durationBinding:UpdateFontString()
    end
end

function Display:ShowBar(bar)
    sourceColor = ReadBarColor(bar) or { 1, 1, 1, 1 }
    sourceIcon = bar:GetIcon()
    sourceIconShown = bar.candyBarIconFrame and bar.candyBarIconFrame:IsShown() or false
    labelText:SetText(bar:GetLabel())
    self:ApplySettings()
    BindExpiration(bar.exp)
    frame:Show()
end

function Display:ShowTest(text, seconds)
    sourceColor = { 1, 0.82, 0, 1 }
    sourceIcon = 134400
    sourceIconShown = true
    labelText:SetText(text)
    self:ApplySettings()
    BindExpiration(GetTime() + seconds)
    frame:Show()
end

function Display:Hide()
    if durationBinding then
        durationBinding:SetEnabled(false)
    end
    durationObject = nil
    sourceColor = { 1, 1, 1, 1 }
    sourceIcon = nil
    sourceIconShown = false
    if frame then
        frame:Hide()
    end
end

function Display:SetLocked(locked)
    ns.db.locked = locked
    self:ApplySettings()
    if not locked and not frame:IsShown() then
        ns.StartTest()
    end
end
