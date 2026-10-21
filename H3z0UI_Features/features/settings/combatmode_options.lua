--[[
    H3z0UI Options - Combat Mode Tab
    Control panel for the bundled Combat Mode addon (djsmithdev/combatmode).
    Combat Mode ships as its own addon folder (CombatMode) next to H3z0UI;
    this tab shows its status and lets you open its settings, enable/disable it
    and avoid a double crosshair.
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

-- Folder of the Combat Mode addon (now titled "Action Combat Mode"); found by name or title
local CM_NAME = "CombatMode"
local function FindCM()
    local hh = _G.H3z0UI_Handheld
    local list = hh and hh.FindCombatModeAddOns and hh.FindCombatModeAddOns()
    if list and list[1] then CM_NAME = list[1] end
    return CM_NAME
end

local function CMInstalled()
    FindCM()
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local name = C_AddOns.GetAddOnInfo(CM_NAME)
        return name ~= nil
    end
    return false
end

local function CMLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(CM_NAME) or false
end

local function CMEnabled()
    local hh = _G.H3z0UI_Handheld
    if hh and hh.IsAddOnEnabled then return hh.IsAddOnEnabled(CM_NAME) end
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local state = C_AddOns.GetAddOnEnableState(CM_NAME, UnitName("player"))
        return state and state > 0
    end
    return false
end

local function BuildCombatModeTab(tabContent)
    local y = -10
    local PADDING = Shared.PADDING
    local db = Shared.GetDB()

    GUI:SetSearchContext({tabIndex = 1, tabName = "H3z0 Features", subTabIndex = 2, subTabName = "Combat Mode"})

    GUI:SetSearchSection("Combat Mode")
    local header = GUI:CreateSectionHeader(tabContent, "Combat Mode")
    header:SetPoint("TOPLEFT", PADDING, y)
    y = y - header.gap

    local function Text(str, height, color)
        local label = GUI:CreateLabel(tabContent, str, 11, color or C.textMuted)
        label:SetPoint("TOPLEFT", PADDING, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        label:SetJustifyH("LEFT")
        y = y - (height or 20)
        return label
    end

    Text("Action Combat Mode (folder CombatMode, by djsmithdev) adds action-combat controls: Mouse Look targeting instead of tab-targeting, a crosshair, soft-target reticle, click casting and ally cycling. It is a separate addon that is not included in H3z0 UI; install it from CurseForge or GitHub if you want it.", 56)

    local status = Text("", 20, C.text)
    local hint = Text("", 36)

    local function Refresh()
        if not CMInstalled() then
            status:SetText("Status: |cffff5555Not installed|r")
            hint:SetText("Install the Action Combat Mode / CombatMode addon (CurseForge / GitHub) into Interface\\AddOns, then restart the game.")
        elseif CMLoaded() then
            status:SetText("Status: |cff55ff55Active|r")
            hint:SetText("Open the Combat Mode settings below, or type /cm in chat.")
        elseif CMEnabled() then
            status:SetText("Status: |cffffff55Enabled - reload to activate|r")
            hint:SetText("Press Reload UI to load Combat Mode.")
        else
            status:SetText("Status: |cffaaaaaaDisabled|r")
            hint:SetText("Use the button below to enable it, then reload the UI.")
        end
    end
    Refresh()

    y = y - 4

    local openBtn = GUI:CreateButton(tabContent, "Open Combat Mode Settings", 220, 28, function()
        if CMLoaded() and _G.CM and _G.CM.OpenOptions then
            _G.CM.OpenOptions()
        else
            print("|cff00ff99H3z0 UI|r: Combat Mode is not active. Enable it and reload the UI first.")
        end
    end)
    openBtn:SetPoint("TOPLEFT", PADDING, y)
    y = y - 36

    local toggleBtn
    toggleBtn = GUI:CreateButton(tabContent, "Enable / Disable Combat Mode", 220, 28, function()
        if not CMInstalled() then Refresh() return end
        local hh = _G.H3z0UI_Handheld
        if hh and hh.SetAddOnEnabled then
            hh.SetAddOnEnabled(CM_NAME, not CMEnabled())
        elseif CMEnabled() then
            C_AddOns.DisableAddOn(CM_NAME)
        else
            C_AddOns.EnableAddOn(CM_NAME)
        end
        Refresh()
        print("|cff00ff99H3z0 UI|r: Combat Mode setting changed - press Reload UI to apply.")
    end)
    toggleBtn:SetPoint("TOPLEFT", PADDING, y)
    y = y - 36

    local reloadBtn = GUI:CreateButton(tabContent, "Reload UI", 220, 28, function() ReloadUI() end)
    reloadBtn:SetPoint("TOPLEFT", PADDING, y)
    y = y - 44

    -- Crosshair overlap
    GUI:SetSearchSection("Crosshair overlap")
    local header2 = GUI:CreateSectionHeader(tabContent, "Crosshair overlap")
    header2:SetPoint("TOPLEFT", PADDING, y)
    y = y - header2.gap

    Text("Combat Mode draws its own crosshair. If you use it, turn off the H3z0 UI crosshair (Cursor & Crosshair tab) to avoid seeing two.", 40)

    local ch = db and db.crosshair
    if ch then
        local offBtn = GUI:CreateButton(tabContent, "Turn Off H3z0 UI Crosshair", 220, 28, function()
            ch.enabled = false
            if Shared.RefreshCrosshair then Shared.RefreshCrosshair() end
            print("|cff00ff99H3z0 UI|r: H3z0 UI crosshair turned off.")
        end)
        offBtn:SetPoint("TOPLEFT", PADDING, y)
        y = y - 36
    end

    tabContent:HookScript("OnShow", Refresh)
    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_CombatModeOptions = {
    BuildCombatModeTab = BuildCombatModeTab
}
