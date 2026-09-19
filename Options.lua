local addonName, ns = ...

local Options = {}
ns.Options = Options

local panel
local controls = {}
local refreshing = false

local function Apply()
    if refreshing then
        return
    end
    ns.Display:ApplySettings()
end

local function CreateLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function CreateCheckbox(parent, key, label, x, y, onChanged)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox.Text:SetText(label)
    checkbox:SetScript("OnClick", function(self)
        ns.db[key] = self:GetChecked() and true or false
        if onChanged then
            onChanged(ns.db[key])
        else
            Apply()
        end
    end)
    controls[key] = checkbox
    return checkbox
end

local sliderIndex = 0
local function CreateSlider(parent, key, label, x, y, width, minValue, maxValue, step)
    sliderIndex = sliderIndex + 1
    local name = addonName .. "Slider" .. sliderIndex
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(width)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    _G[name .. "Text"]:SetText(label)
    _G[name .. "Low"]:SetText(tostring(minValue))
    _G[name .. "High"]:SetText(tostring(maxValue))
    slider:SetScript("OnValueChanged", function(_, value)
        if step >= 1 then
            value = math.floor(value + 0.5)
        end
        ns.db[key] = value
        Apply()
    end)
    controls[key] = slider
    return slider
end

local function CreateDropdown(parent, key, label, x, y, width, valuesProvider)
    CreateLabel(parent, label, x, y)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 20)
    dropdown:SetWidth(width)
    dropdown:SetupMenu(function(_, rootDescription)
        for _, entry in ipairs(valuesProvider()) do
            rootDescription:CreateRadio(entry.label, function()
                return ns.db[key] == entry.value
            end, function()
                ns.db[key] = entry.value
                dropdown:SetText(entry.label)
                Apply()
            end)
        end
    end)
    dropdown._bwcaDropdown = true
    controls[key] = dropdown
    return dropdown
end

local function CreateColorButton(parent, key, label, x, y)
    CreateLabel(parent, label, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 20)
    button:SetSize(110, 24)
    button:SetText(" ")
    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -6)
    swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -8, 6)
    swatch:SetColorTexture(1, 1, 1, 1)
    button.swatch = swatch
    button:SetScript("OnClick", function()
        local color = ns.db[key]
        local previous = { color[1], color[2], color[3], color[4] }
        local function UpdateColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            color[1], color[2], color[3], color[4] = r, g, b, 1
            swatch:SetColorTexture(r, g, b, 1)
            Apply()
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color[1],
            g = color[2],
            b = color[3],
            hasOpacity = false,
            swatchFunc = UpdateColor,
            cancelFunc = function()
                color[1], color[2], color[3], color[4] = unpack(previous)
                swatch:SetColorTexture(color[1], color[2], color[3], color[4])
                Apply()
            end,
        })
    end)
    controls[key] = button
    return button
end

local function GetFonts()
    local result = {}
    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    local names = media and media:List("font") or { "Friz Quadrata TT" }
    table.sort(names)
    for _, name in ipairs(names) do
        result[#result + 1] = { label = name, value = name }
    end
    return result
end

local function StaticValues(...)
    local values = { ... }
    return function()
        return values
    end
end

function Options:Initialize()
    panel = CreateFrame("Frame", "BigWigsCentralAlertOptions", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(700, 650)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel.TitleText:SetText(ns.L.ADDON_NAME)
    panel:Hide()

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -38)
    description:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -38)
    description:SetJustifyH("LEFT")
    description:SetText(ns.L.DESCRIPTION)

    CreateDropdown(panel, "font", ns.L.FONT, 28, -78, 300, GetFonts)
    CreateSlider(panel, "fontSize", ns.L.FONT_SIZE, 375, -90, 275, 12, 72, 1)

    CreateDropdown(panel, "outline", ns.L.OUTLINE, 28, -150, 190, StaticValues(
        { label = ns.L.OUTLINE_NONE, value = "NONE" },
        { label = ns.L.OUTLINE_THIN, value = "OUTLINE" },
        { label = ns.L.OUTLINE_THICK, value = "THICKOUTLINE" }
    ))
    CreateCheckbox(panel, "monochrome", ns.L.MONOCHROME, 260, -168)
    CreateCheckbox(panel, "shadow", ns.L.SHADOW, 465, -168)

    CreateCheckbox(panel, "followBarColor", ns.L.FOLLOW_BAR_COLOR, 28, -226)
    CreateCheckbox(panel, "sameTimerColor", ns.L.SAME_TIMER_COLOR, 330, -226)
    CreateColorButton(panel, "textColor", ns.L.TEXT_COLOR, 28, -260)
    CreateColorButton(panel, "timerColor", ns.L.TIMER_COLOR, 190, -260)

    CreateDropdown(panel, "layout", ns.L.LAYOUT, 28, -335, 190, StaticValues(
        { label = ns.L.LAYOUT_INLINE, value = "INLINE" },
        { label = ns.L.LAYOUT_STACKED, value = "STACKED" }
    ))
    CreateDropdown(panel, "rounding", ns.L.ROUNDING, 260, -335, 190, StaticValues(
        { label = ns.L.ROUND_CEIL, value = "CEIL" },
        { label = ns.L.ROUND_FLOOR, value = "FLOOR" }
    ))
    CreateSlider(panel, "spacing", ns.L.SPACING, 490, -347, 165, 0, 30, 1)

    CreateCheckbox(panel, "brackets", ns.L.BRACKETS, 28, -420)
    CreateCheckbox(panel, "secondsSuffix", ns.L.SECONDS_SUFFIX, 260, -420)
    CreateCheckbox(panel, "locked", ns.L.LOCKED, 490, -420, function(locked)
        ns.Display:SetLocked(locked)
    end)

    CreateSlider(panel, "x", ns.L.POSITION_X, 28, -485, 290, -900, 900, 1)
    CreateSlider(panel, "y", ns.L.POSITION_Y, 365, -485, 290, -500, 500, 1)

    local testButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testButton:SetSize(150, 28)
    testButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 28, 22)
    testButton:SetScript("OnClick", function()
        ns.ToggleTest()
        testButton:SetText(ns.testActive and ns.L.STOP_TEST or ns.L.TEST)
    end)
    controls.test = testButton

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 28)
    resetButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 22)
    resetButton:SetText(ns.L.RESET)
    resetButton:SetScript("OnClick", ns.ResetSettings)

    panel:SetScript("OnShow", function()
        self:Refresh()
        if not ns.testActive then
            ns.StartTest()
        end
        controls.test:SetText(ns.L.STOP_TEST)
    end)
    panel:SetScript("OnHide", function()
        if ns.testActive then
            ns.StopTest()
        end
    end)

    SLASH_BIGWIGSCENTRALALERT1 = "/bwca"
    SLASH_BIGWIGSCENTRALALERT2 = "/bigwigscentralalert"
    SlashCmdList.BIGWIGSCENTRALALERT = function(message)
        message = strtrim(message or ""):lower()
        if message == "test" then
            ns.ToggleTest()
        elseif message == "lock" then
            ns.Display:SetLocked(not ns.db.locked)
            self:Refresh()
        elseif message == "reset" then
            ns.ResetSettings()
        elseif panel:IsShown() then
            panel:Hide()
        else
            panel:Show()
        end
    end

    self:Refresh()
end

function Options:Refresh()
    if not panel then
        return
    end
    refreshing = true
    for key, control in pairs(controls) do
        if key == "test" then
            control:SetText(ns.testActive and ns.L.STOP_TEST or ns.L.TEST)
        elseif control.SetChecked and type(ns.db[key]) == "boolean" then
            control:SetChecked(ns.db[key])
        elseif control.SetValue and type(ns.db[key]) == "number" then
            control:SetValue(ns.db[key])
        elseif control._bwcaDropdown then
            local display = ns.db[key]
            if key == "outline" then
                display = ns.db[key] == "NONE" and ns.L.OUTLINE_NONE
                    or ns.db[key] == "THICKOUTLINE" and ns.L.OUTLINE_THICK
                    or ns.L.OUTLINE_THIN
            elseif key == "layout" then
                display = ns.db[key] == "STACKED" and ns.L.LAYOUT_STACKED or ns.L.LAYOUT_INLINE
            elseif key == "rounding" then
                display = ns.db[key] == "FLOOR" and ns.L.ROUND_FLOOR or ns.L.ROUND_CEIL
            end
            control:SetText(display)
        elseif control.swatch and type(ns.db[key]) == "table" then
            local color = ns.db[key]
            control.swatch:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        end
    end
    refreshing = false
end
