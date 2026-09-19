local addonName, ns = ...

local Adapter = {}
ns.Adapter = Adapter

local listener = {}
local candyRegistered = false

local function OnBarCreated(_, _, bar)
    ns.TrackBar(bar)
end

local function OnBarEmphasized(_, _, bar)
    ns.MarkBarImportant(bar)
end

local function OnBarLifecycleChanged()
    -- The Bars plugin can receive the same message before or after this addon.
    -- Defer one frame so bar.running/bar.paused always reflects the new state.
    ns.RequestRefresh()
end

local function OnModuleDisabled(_, module)
    ns.ForgetModule(module)
end

local function OnCandyBarStopped(_, bar)
    ns.ForgetBar(bar)
end

local function RegisterCandyCallback()
    if candyRegistered or not LibStub then
        return
    end
    local candy = LibStub("LibCandyBar-3.0", true)
    if candy then
        candy.RegisterCallback(listener, "LibCandyBar_Stop", OnCandyBarStopped)
        candyRegistered = true
    end
end

function Adapter:Initialize()
    if not BigWigsLoader or not BigWigsLoader.RegisterMessage then
        print("|cffff0000" .. ns.L.ADDON_NAME .. ":|r " .. ns.L.NO_BIGWIGS)
        return
    end

    BigWigsLoader.RegisterMessage(listener, "BigWigs_BarCreated", OnBarCreated)
    BigWigsLoader.RegisterMessage(listener, "BigWigs_BarEmphasized", OnBarEmphasized)
    BigWigsLoader.RegisterMessage(listener, "BigWigs_PauseBar", OnBarLifecycleChanged)
    BigWigsLoader.RegisterMessage(listener, "BigWigs_ResumeBar", OnBarLifecycleChanged)
    BigWigsLoader.RegisterMessage(listener, "BigWigs_StopBar", OnBarLifecycleChanged)
    BigWigsLoader.RegisterMessage(listener, "BigWigs_StopBars", OnBarLifecycleChanged)
    BigWigsLoader.RegisterMessage(listener, "BigWigs_OnBossDisable", OnModuleDisabled)
    BigWigsLoader.RegisterMessage(listener, "BigWigs_OnBossWipe", OnModuleDisabled)

    RegisterCandyCallback()
    if not candyRegistered then
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(self, _, loadedAddon)
            if loadedAddon == "BigWigs_Plugins" then
                RegisterCandyCallback()
                if candyRegistered then
                    self:UnregisterEvent("ADDON_LOADED")
                end
            end
        end)
    end
end
