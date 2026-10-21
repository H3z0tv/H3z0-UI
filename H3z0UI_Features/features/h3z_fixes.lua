local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- One-time settings fixes for existing profiles
---------------------------------------------------------------------------

local function Profile()
    local core = ns.Addon
    return core and core.db and core.db.profile
end

-- Cooldown Manager: no press / click highlight on the icons
local function CDMPressedOff(p)
    local ncdm = p.ncdm
    if type(ncdm) ~= "table" or ncdm._h3zPressedOff then return end
    ncdm._h3zPressedOff = true
    local function Walk(t, depth)
        if type(t) ~= "table" or depth > 4 then return end
        if t.pressedEffect ~= nil then t.pressedEffect = "off" end
        for k, v in pairs(t) do
            if type(v) == "table" and k ~= "ownedSpells" and k ~= "removedSpells" and k ~= "dormantSpells" and k ~= "spellOverrides" then
                Walk(v, depth + 1)
            end
        end
    end
    Walk(ncdm, 0)
end

-- H3z0 resource bars and Cooldown Manager keep their own positions:
-- drop frame anchors an earlier 0.25.0 build may have saved for them
local function DropCDMAnchors(p)
    if p._h3zCDMAnchorsOff then return end
    p._h3zCDMAnchorsOff = true
    local fa = p.frameAnchoring
    if type(fa) ~= "table" then return end
    for _, key in ipairs({ "cdmEssential", "cdmUtility", "buffIcon", "buffBar" }) do
        fa[key] = nil
    end
end

-- H3z0 UI minimap keeps its own position (minimap.position)
local function DropMinimapAnchors(p)
    if p._h3zMinimapAnchorsOff then return end
    p._h3zMinimapAnchorsOff = true
    local fa = p.frameAnchoring
    if type(fa) ~= "table" then return end
    for _, key in ipairs({ "minimap", "datatextPanel" }) do
        fa[key] = nil
    end
end

-- WoW: Forever shows every empty action button: hide them once (the switch
-- stays in Action Bars > Bar Layout > Hide Empty Slots)
local function ForeverHideEmpty(p)
    if not (ns.Client and ns.Client.isForever) then return end
    local ab = p.actionBars
    if type(ab) ~= "table" or ab._h3zForeverEmptyHidden then return end
    ab._h3zForeverEmptyHidden = true
    ab.global = ab.global or {}
    ab.global.hideEmptySlots = true
    C_Timer.After(2, function()
        if _G.H3z0UI_RefreshActionBars then pcall(_G.H3z0UI_RefreshActionBars) end
    end)
end

-- Keybind text: action bars and the Utility cooldowns in the same place (top right, -1 / -7, size 12)
local function KeybindPlace(p)
    if p._h3zKeybindPlace then return end
    p._h3zKeybindPlace = true
    local ab = p.actionBars and p.actionBars.global
    if type(ab) == "table" then
        ab.keybindFontSize, ab.keybindAnchor, ab.keybindOffsetX, ab.keybindOffsetY = 12, "TOPRIGHT", -1, -7
    end
    local u = p.viewers and p.viewers.UtilityCooldownViewer
    if type(u) == "table" then
        u.keybindTextSize, u.keybindAnchor, u.keybindOffsetX, u.keybindOffsetY = 12, "TOPRIGHT", -1, -7
    end
    C_Timer.After(2, function()
        if _G.H3z0UI_RefreshActionBars then pcall(_G.H3z0UI_RefreshActionBars) end
        if _G.H3z0UI_RefreshKeybinds then pcall(_G.H3z0UI_RefreshKeybinds) end
    end)
end

-- Stack count text on the action bars: bottom right, size 12, X -2, Y 1
local function CountPlace(p)
    if p._h3zCountPlace then return end
    p._h3zCountPlace = true
    local ab = p.actionBars and p.actionBars.global
    if type(ab) == "table" then
        ab.showCounts = true
        ab.countFontSize, ab.countAnchor, ab.countOffsetX, ab.countOffsetY = 12, "BOTTOMRIGHT", -2, 1
        C_Timer.After(2, function()
            if _G.H3z0UI_RefreshActionBars then pcall(_G.H3z0UI_RefreshActionBars) end
        end)
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local p = Profile()
    if not p then return end
    pcall(CDMPressedOff, p)
    pcall(DropCDMAnchors, p)
    pcall(DropMinimapAnchors, p)
    pcall(ForeverHideEmpty, p)
    pcall(KeybindPlace, p)
    pcall(CountPlace, p)
end)
