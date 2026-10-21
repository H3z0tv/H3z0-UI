--[[
    H3z0 UI - Cooldown Manager repair (/h3z0ui cdm)

    Finds out why Essential / Utility / Buff Icons / Tracked Bars don't show
    and fixes what it can:
      - Blizzard's "Enable Cooldown Manager" option off   -> turned on
      - viewer set to "Hidden" in the active Edit Mode layout -> "Always"
      - viewer placed off-screen                            -> moved back
      - viewer faded to 0 by something else                  -> reported
    Prints one line per viewer so it's clear what was wrong.
]]

local ADDON_NAME, ns = ...

local function Say(msg) print("|cff34D399H3z0 UI:|r " .. msg) end

local IDX = Enum and Enum.EditModeCooldownViewerSystemIndices or {}
local VIEWERS = {
    { frame = "EssentialCooldownViewer", label = "Essential Cooldowns", index = IDX.Essential, y = -170 },
    { frame = "UtilityCooldownViewer",   label = "Utility Cooldowns",   index = IDX.Utility,   y = -220 },
    { frame = "BuffIconCooldownViewer",  label = "Buff Icons",          index = IDX.BuffIcon,  y = -110 },
    { frame = "BuffBarCooldownViewer",   label = "Tracked Bars",        index = IDX.BuffBar,   y = -290 },
}

local function CDMSystem()
    return Enum and Enum.EditModeSystem and Enum.EditModeSystem.CooldownViewer
end

local function OnScreen(f)
    local x, y = f:GetCenter()
    if not (x and y) then return false end
    local s = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    x, y = x * s, y * s
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    return x > 0 and x < w and y > 0 and y < h
end

local function Run()
    if InCombatLockdown() then Say("Leave combat first.") return end
    local lines, reload = {}, false

    -- 1. Blizzard option
    if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("cooldownViewerEnabled") == "0" then
        C_CVar.SetCVar("cooldownViewerEnabled", "1")
        lines[#lines + 1] = "Blizzard's Cooldown Manager was turned OFF (Options > Gameplay Enhancements) - turned it on."
        reload = true
    end

    -- 2. Visibility in the active Edit Mode layout
    local LS = ns.LayoutSets
    local info = LS and LS.GetLayouts()
    local sys = CDMSystem()
    local SET = Enum and Enum.EditModeCooldownViewerSetting
    local VIS = Enum and Enum.CooldownViewerVisibleSetting
    local layout = info and info.layouts[(tonumber(info.activeLayout) or 0) - LS.NumPresetLayouts()]
    local layoutChanged = false
    if layout and sys and SET and SET.VisibleSetting and VIS and VIS.Hidden then
        for _, s in ipairs(layout.systems or {}) do
            if s.system == sys then
                for _, e in ipairs(s.settings or {}) do
                    if e.setting == SET.VisibleSetting and e.value == VIS.Hidden then
                        for _, v in ipairs(VIEWERS) do
                            if v.index == s.systemIndex then
                                lines[#lines + 1] = v.label .. " is set to Hidden in your Edit Mode layout \"" .. tostring(layout.layoutName) .. "\" - set its Visibility to Always with /h3z0ui blizzedit."
                            end
                        end
                    end
                end
            end
        end
    end

    -- 3. Each viewer: exists / on screen / visible
    local EM = ns.H3z0UI_LayoutMode and ns.H3z0UI_LayoutMode.EditMode
    for _, v in ipairs(VIEWERS) do
        local f = _G[v.frame]
        if not f then
            lines[#lines + 1] = v.label .. ": not loaded (Cooldown Manager off - reload after this)."
            reload = true
        else
            if not OnScreen(f) then
                if ns.BlizzPositions then
                    ns.BlizzPositions.Save(f, 0, v.y)
                    lines[#lines + 1] = v.label .. " was off-screen - moved back below the screen centre."
                else
                    lines[#lines + 1] = v.label .. " is off-screen - move it in Layout Mode."
                end
            elseif (f:GetAlpha() or 1) < 0.05 then
                lines[#lines + 1] = v.label .. " is faded out (alpha 0) - check Skinning & Autohide / HUD Visibility."
            elseif not f:IsShown() then
                if v.frame == "BuffBarCooldownViewer" or v.frame == "BuffIconCooldownViewer" then
                    lines[#lines + 1] = v.label .. ": hidden right now - it only shows while a tracked buff is active (or set in combat only)."
                else
                    lines[#lines + 1] = v.label .. ": hidden right now (may be set to show in combat only)."
                end
            else
                lines[#lines + 1] = v.label .. ": OK."
            end
        end
    end

    if layoutChanged then
        local ok = pcall(C_EditMode.SaveLayouts, info)
        if ok then LS.Activate(info.activeLayout) end
        reload = true
    end

    Say("Cooldown Manager check:")
    for _, l in ipairs(lines) do print("   " .. l) end
    if reload then
        if _G.H3z0UI_NeedReload then _G.H3z0UI_NeedReload("Cooldown Manager check made changes.") end
    end
end

_G.H3z0UI_CDMDoctor = Run
