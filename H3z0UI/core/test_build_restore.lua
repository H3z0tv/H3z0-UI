local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- 0.27.0 profile fixes. The 0.27.0 test builds had a second action bar set and a second Bottom Bar
-- look. Both are gone again. A profile that ran them gets its own action bars
-- (settings and positions) and its own Bottom Bar back, once.
---------------------------------------------------------------------------

local BAR_ANCHORS = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "petBar", "stanceBar" }
local LOOK_KEYS = { "height", "fontSize", "bgOpacity", "borderSize", "widgetSpacing", "zonePadding", "menuIconSize", "menuIconSpacing" }

local function FillDefaults(dst, def)
    if type(dst) ~= "table" or type(def) ~= "table" then return end
    for k, v in pairs(def) do
        if k ~= "*" and k ~= "**" then
            if type(v) == "table" then
                if dst[k] == nil then dst[k] = {} end
                if type(dst[k]) == "table" then FillDefaults(dst[k], v) end
            elseif dst[k] == nil then
                dst[k] = v
            end
        end
    end
end

-- 0.27.0: the H3z0UI font is the default font. Every font setting still on the
-- old default (Poppins) moves to H3z0UI once; other fonts you picked stay.
local function FontToH3z0UI(t, depth)
    if type(t) ~= "table" or depth > 8 then return end
    for k, v in pairs(t) do
        if type(v) == "table" then
            FontToH3z0UI(v, depth + 1)
        elseif type(v) == "string" and type(k) == "string" and k:lower():find("font")
            and not k:lower():find("size") and not k:lower():find("outline") and not k:lower():find("color")
            and (v == "Poppins" or v:find("^Poppins ")) then
            t[k] = "H3z0UI"
        end
    end
end

-- 0.27.0: action buttons show again what you can't use right now (dimmed when
-- unusable, blue without enough power, red out of range). The default profile
-- had both switched off; turned on once.
local function UsabilityOn(p)
    if type(p) ~= "table" or p._h3zUsabilityOn then return end
    p._h3zUsabilityOn = true
    local g = type(p.actionBars) == "table" and p.actionBars.global
    if type(g) == "table" then
        g.usabilityIndicator = true
        g.rangeIndicator = true
    end
end

-- 0.27.0: the Cooldown Manager marks the ability to press next with a green border
local function RotationHelperOn(p)
    if type(p) ~= "table" or p._h3zRotationHelperOn then return end
    p._h3zRotationHelperOn = true
    local v = type(p.viewers) == "table" and p.viewers
    if not v then return end
    for _, key in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
        if type(v[key]) == "table" then v[key].showRotationHelper = true end
    end
end

-- 0.27.0: procs on the Cooldown Manager icons use the H3z0 UI glow (the game's own
-- proc glow did not show on the skinned icons); turned on once
local function ProcGlowOn(p)
    if type(p) ~= "table" or p._h3zProcGlowOn then return end
    p._h3zProcGlowOn = true
    p.cooldownEffects = type(p.cooldownEffects) == "table" and p.cooldownEffects or {}
    p.cooldownEffects.hideEssential = true
    p.cooldownEffects.hideUtility = true
    if type(p.customGlow) == "table" then
        p.customGlow.essentialEnabled = true
        p.customGlow.utilityEnabled = true
    end
end

local function FontDefault(p)
    if type(p) ~= "table" or p._h3zFontH3z0UI then return end
    p._h3zFontH3z0UI = true
    FontToH3z0UI(p, 0)
end

local function RestoreProfile(p, defaults)
    if type(p) ~= "table" then return false end
    local changed = false
    -- action bars
    local stash = p.actionBarsSet_legacy
    if p.actionBarsActive == "modern" and type(stash) == "table" then
        local bars = type(stash.bars) == "table" and stash.bars or {}
        if defaults and defaults.actionBars then FillDefaults(bars, defaults.actionBars) end
        p.actionBars = bars
        local fa = p.frameAnchoring
        if type(fa) == "table" then
            local anchors = type(stash.anchors) == "table" and stash.anchors or {}
            for _, k in ipairs(BAR_ANCHORS) do fa[k] = anchors[k] end
        end
        changed = true
    end
    p.actionBarsActive, p.actionBarsSet_legacy, p.actionBarsSet_modern = nil, nil, nil
    -- Bottom Bar
    local ib = p.infobar
    if type(ib) == "table" then
        local saved = ib.h3zLook_legacy
        if ib.h3zLookStyle == "modern" and type(saved) == "table" then
            for _, k in ipairs(LOOK_KEYS) do ib[k] = saved[k] end
            if type(saved.zones) == "table" then ib.zones = saved.zones end
            if type(saved.widgetSettings) == "table" then ib.widgetSettings = saved.widgetSettings end
            changed = true
        end
        ib.h3zLookStyle, ib.h3zLook_legacy, ib.h3zLook_modern = nil, nil, nil
    end
    return changed
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON_NAME then return end
        local db = _G.H3z0UI and _G.H3z0UI.db
        if not db then return end
        local defaults = db.defaults and db.defaults.profile
        RestoreProfile(db.profile, defaults)
        FontDefault(db.profile)
        UsabilityOn(db.profile)
        RotationHelperOn(db.profile)
        ProcGlowOn(db.profile)
        -- the other saved profiles (plain saved tables, defaults come when they are used)
        local sv = db.sv and db.sv.profiles
        if type(sv) == "table" then
            for _, prof in pairs(sv) do
                if prof ~= db.profile then RestoreProfile(prof, nil); FontDefault(prof); UsabilityOn(prof); RotationHelperOn(prof); ProcGlowOn(prof) end
            end
        end
        return
    end
    -- PLAYER_LOGIN: a test build may have switched the action bars addon off
    self:UnregisterAllEvents()
    local p = _G.H3z0UI and _G.H3z0UI.db and _G.H3z0UI.db.profile
    if p then RestoreProfile(p, _G.H3z0UI.db.defaults and _G.H3z0UI.db.defaults.profile) end
    if p then FontDefault(p); UsabilityOn(p); RotationHelperOn(p); ProcGlowOn(p) end
    local wasSwitched = p and p.actionBarsVariant ~= nil
    if p then p.actionBarsVariant = nil end
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.EnableAddOn) then return end
    if wasSwitched and not C_AddOns.IsAddOnLoaded("H3z0UI_ActionBars")
        and (not C_AddOns.DoesAddOnExist or C_AddOns.DoesAddOnExist("H3z0UI_ActionBars")) then
        C_AddOns.EnableAddOn("H3z0UI_ActionBars")
        if C_AddOns.SaveAddOns then C_AddOns.SaveAddOns() end
        print("|cFF30D1FFH3z0 UI:|r your action bars are switched back on. Type /reload to bring them back.")
    end
end)
