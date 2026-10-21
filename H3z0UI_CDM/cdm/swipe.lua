-- cooldownswipe.lua
-- Granular cooldown swipe control: Buff Duration / GCD / Cooldown swipes

local _, ns = ...
local Helpers = ns.Helpers

-- Default settings
local DEFAULTS = {
    showBuffSwipe = true,
    showBuffIconSwipe = false,
    showGCDSwipe = true,
    showCooldownSwipe = true,
}

-- Get settings from AceDB via shared helper
local function GetSettings()
    return Helpers.GetModuleSettings("cooldownSwipe", DEFAULTS)
end

-- Single unified hook for SetCooldown that handles ALL swipe types
-- This runs on EVERY cooldown update, ensuring settings are always applied
local function HookSetCooldown(icon)
    if not icon or not icon.Cooldown then return end
    if icon._H3z0UI_SetCooldownHooked then return end
    icon._H3z0UI_SetCooldownHooked = true

    -- Store parent reference on Cooldown frame for hook access
    icon.Cooldown._H3z0UIParentIcon = icon

    hooksecurefunc(icon.Cooldown, "SetCooldown", function(self)
        local parentIcon = self._H3z0UIParentIcon
        if not parentIcon then return end

        -- Skip during combat to avoid taint propagation (secret value errors)
        if InCombatLockdown() then return end

        -- Skip if we're the ones calling SetCooldown (recursion guard)
        if parentIcon._H3z0UI_BypassCDHook then return end

        local settings = GetSettings()
        local showSwipe
        -- auraInstanceID can be a "secret" number on Midnight; comparing it (> 0) errors out.
        -- A secret value means Blizzard has set an aura on this icon, so treat it as active.
        local auraID = parentIcon.auraInstanceID
        local auraActive
        if auraID == nil then
            auraActive = false
        elseif issecretvalue and issecretvalue(auraID) then
            auraActive = true
        else
            auraActive = type(auraID) == "number" and auraID > 0
        end

        -- Swipe logic
        -- Priority 1: Buff duration (auraInstanceID > 0)
        if auraActive then
            -- Check if this icon is in BuffIconCooldownViewer (separate toggle)
            local parent = parentIcon:GetParent()
            if parent == _G.BuffIconCooldownViewer then
                showSwipe = settings.showBuffIconSwipe
            else
                showSwipe = settings.showBuffSwipe
            end
        -- Priority 2: GCD vs Cooldown (use CooldownFlash visibility)
        elseif parentIcon.CooldownFlash then
            if parentIcon.CooldownFlash:IsShown() then
                showSwipe = settings.showCooldownSwipe
            else
                showSwipe = settings.showGCDSwipe
            end
        -- Fallback: treat as cooldown
        else
            showSwipe = settings.showCooldownSwipe
        end

        self:SetDrawSwipe(showSwipe)

        -- Edge logic: Buff icons use their swipe setting, cooldowns use showRechargeEdge
        local showEdge
        if auraActive then
            showEdge = showSwipe  -- Buff icons: edge follows swipe toggle
        else
            showEdge = settings.showRechargeEdge  -- Cooldowns: separate setting
        end
        self:SetDrawEdge(showEdge)
    end)
end

-- Process all icons in a viewer
local function ProcessViewer(viewer)
    if not viewer then return end

    local children = {viewer:GetChildren()}

    for _, icon in ipairs(children) do
        if icon.Cooldown then
            HookSetCooldown(icon)
        end
    end
end

-- Apply settings to all CDM viewers
local function ApplyAllSettings()
    local viewers = {
        _G.EssentialCooldownViewer,
        _G.UtilityCooldownViewer,
        _G.BuffIconCooldownViewer,
    }

    for _, viewer in ipairs(viewers) do
        ProcessViewer(viewer)

        -- Hook Layout to catch new icons
        if viewer and viewer.Layout and not viewer._H3z0UI_LayoutHooked then
            viewer._H3z0UI_LayoutHooked = true
            hooksecurefunc(viewer, "Layout", function()
                C_Timer.After(0.15, function()  -- 150ms debounce for CPU efficiency
                    ProcessViewer(viewer)
                end)
            end)
        end
    end
end

-- Initialize on addon load
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        C_Timer.After(0.5, ApplyAllSettings)
        C_Timer.After(1.5, ApplyAllSettings)  -- Apply again to catch late icons
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, ApplyAllSettings)
        C_Timer.After(1.5, ApplyAllSettings)  -- Apply again to catch late icons
    end
end)

-- Export to H3z0UI namespace
H3z0UI.CooldownSwipe = {
    Apply = ApplyAllSettings,
    GetSettings = GetSettings,
}

-- Global function for config panel to call
_G.H3z0UI_RefreshCooldownSwipe = function()
    ApplyAllSettings()
end
