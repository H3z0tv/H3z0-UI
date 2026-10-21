--- H3z0 UI Bottom Bar
--- The Bottom Bar is the Info Bar (core) set up the H3z0 way:
--- * full width at the bottom, menu icons + spec on the left, the clock in the
---   middle, professions / gold / bags / location on the right
--- * while it is on, Blizzard's micro menu and bag bar are hidden (the bar's
---   menu icons replace them) and come back when the bar is turned off
--- * one-time move of the old datapanel Bottom Bar settings to the Info Bar

local ADDON_NAME, ns = ...
local H3z0UICore = ns.Addon
if not H3z0UICore then return end

local BB = {}
ns.H3z0BottomBar = BB

local OLD_PANEL_ID = "bottombar"
local HIDE_BARS = { "microbar", "bags" }

-- datapanel datatext ids -> Info Bar widget ids
local ID_MAP = {
    clock = "time",
    micromenu = "h3zmenu",
}

BB.PRESET = {
    position = "BOTTOM",
    height = 26,
    fontSize = 12,
    bgOpacity = 60,
    borderSize = 0,
    zones = {
        left = { "h3zmenu", "playerspec" },
        center = { "time" },
        right = { "professions", "gold", "bags", "location" },
    },
    widgetSettings = {
        gold = { noLabel = true },
        bags = { noLabel = true },
    },
}

local function Profile()
    local db = H3z0UICore.db
    return db and db.profile
end

local function InfoBarDB()
    local p = Profile()
    return p and p.infobar
end

local function CopyList(t)
    local c = {}
    for i, v in ipairs(t or {}) do c[i] = v end
    return c
end

-- Put the H3z0 layout on the Info Bar (keeps enabled / hide options)
function BB.ApplyPreset(ib)
    ib = ib or InfoBarDB()
    if not ib then return end
    local P = BB.PRESET
    ib.position = P.position
    ib.height = P.height
    ib.fontSize = P.fontSize
    ib.bgOpacity = P.bgOpacity
    ib.borderSize = P.borderSize
    ib.zones = ib.zones or {}
    ib.zones.left = CopyList(P.zones.left)
    ib.zones.center = CopyList(P.zones.center)
    ib.zones.right = CopyList(P.zones.right)
    ib.zonesSeeded = true
    ib.widgetSettings = ib.widgetSettings or {}
    for id, ws in pairs(P.widgetSettings) do
        ib.widgetSettings[id] = ib.widgetSettings[id] or {}
        for k, v in pairs(ws) do ib.widgetSettings[id][k] = v end
    end
end

local function FindOldPanel()
    local p = Profile()
    local panels = p and p.h3z0uiDatatexts and p.h3z0uiDatatexts.panels
    if type(panels) ~= "table" then return nil end
    for _, panel in ipairs(panels) do
        if type(panel) == "table" and panel.id == OLD_PANEL_ID then return panel end
    end
end

-- Split the old slot list into left / center / right: the slot that covers
-- the middle of the bar (by slot width) becomes the center zone.
local function SplitSlots(panel)
    local n = tonumber(panel.numSlots) or (type(panel.slots) == "table" and #panel.slots) or 0
    local ids, weights, total = {}, {}, 0
    for i = 1, n do
        local id = panel.slots and panel.slots[i]
        if type(id) == "string" and id ~= "" then
            local w = tonumber(panel.slotWeights and panel.slotWeights[i]) or 1
            ids[#ids + 1] = { id = ID_MAP[id] or id, w = w, index = i }
            total = total + w
        end
    end
    local left, center, right = {}, {}, {}
    local half, run, centerFound = total / 2, 0, false
    for _, e in ipairs(ids) do
        if not centerFound and run + e.w >= half then
            center[#center + 1] = e.id
            centerFound = true
        elseif centerFound then
            right[#right + 1] = e.id
        else
            left[#left + 1] = e.id
        end
        run = run + e.w
    end
    return left, center, right, ids
end

-- One time: the old datapanel Bottom Bar -> Info Bar
-- 0.25.0 used the core menu icons: switch to the H3z0 icon set once
function BB.UseH3z0MenuIcons()
    local ib = InfoBarDB()
    if not ib or ib.h3zMenuIcons then return end
    ib.h3zMenuIcons = true
    for _, zone in pairs(ib.zones or {}) do
        if type(zone) == "table" then
            for i, id in ipairs(zone) do
                if id == "micromenu" then zone[i] = "h3zmenu" end
            end
        end
    end
end

function BB.MigrateOldPanel()
    local ib = InfoBarDB()
    if not ib or ib.h3zBottomBarMigrated then return end
    ib.h3zBottomBarMigrated = true

    local panel = FindOldPanel()
    if not panel then
        -- no old Bottom Bar: give the Info Bar the H3z0 layout unless it was set up already
        if not ib.zonesSeeded then BB.ApplyPreset(ib) end
        return
    end

    BB.ApplyPreset(ib)
    ib.enabled = panel.enabled ~= false
    local point = type(panel.position) == "table" and tostring(panel.position[1] or "") or "BOTTOM"
    ib.position = point:find("TOP") and "TOP" or "BOTTOM"
    if tonumber(panel.height) then ib.height = tonumber(panel.height) end
    if tonumber(panel.fontSize) then ib.fontSize = tonumber(panel.fontSize) end
    if tonumber(panel.bgOpacity) then ib.bgOpacity = tonumber(panel.bgOpacity) end
    if tonumber(panel.borderSize) then ib.borderSize = tonumber(panel.borderSize) end
    if type(panel.borderColor) == "table" then
        ib.borderColor = { panel.borderColor[1] or 0, panel.borderColor[2] or 0, panel.borderColor[3] or 0, panel.borderColor[4] or 1 }
    end
    ib.h3zHideBlizzardMenus = panel.hideBlizzardMenus ~= false

    local left, center, right, ids = SplitSlots(panel)
    if #left + #center + #right > 0 then
        ib.zones.left, ib.zones.center, ib.zones.right = left, center, right
    end
    if type(panel.slotSettings) == "table" then
        for _, e in ipairs(ids) do
            local ss = panel.slotSettings[e.index]
            if type(ss) == "table" then
                ib.widgetSettings[e.id] = ib.widgetSettings[e.id] or {}
                if ss.noLabel ~= nil then ib.widgetSettings[e.id].noLabel = ss.noLabel end
                if ss.shortLabel ~= nil then ib.widgetSettings[e.id].shortLabel = ss.shortLabel end
            end
        end
    end

    -- the old panel stays in the profile (switched off) so nothing is lost
    panel.enabled = false
    panel.h3zMovedToInfoBar = true
end

---------------------------------------------------------------------------
-- Blizzard micro menu + bag bar: hidden while the Bottom Bar is on
---------------------------------------------------------------------------
local pendingApply = false
local HookMainBar -- below

local function WantsHidden()
    local ib = InfoBarDB()
    return ib ~= nil and ib.enabled ~= false and ib.h3zHideBlizzardMenus ~= false
end

-- Blizzard's micro menu and bag bar are parked on a hidden frame while the
-- Bottom Bar is on (its menu icons replace them) and come back when it is off.
local FRAME_NAMES = { "MicroMenuContainer", "BagsBar" }
local hider = CreateFrame("Frame", nil, UIParent)
hider:Hide()
local hidden = {}      -- frame -> original parent

-- turn the micro menu / bag bar of H3z0 UI's action bars back on
local function UndoOldSwitch(ib)
    if not ib.h3zHidBars then return end
    local p = Profile()
    local bars = p and p.actionBars and p.actionBars.bars
    for key in pairs(ib.h3zHidBars) do
        if bars and type(bars[key]) == "table" then bars[key].enabled = true end
    end
    ib.h3zHidBars = nil
end

-- H3z0 UI's own micro menu / bag bar (Action Bars): off while the Bottom Bar
-- replaces them, back on when it doesn't
local function SwitchOwnedBars(ib, want)
    local p = Profile()
    local bars = p and p.actionBars and p.actionBars.bars
    if type(bars) ~= "table" then return end
    local changed = false
    if want then
        for _, key in ipairs({ "microbar", "bags" }) do
            local cfg = bars[key]
            if type(cfg) == "table" and cfg.enabled ~= false then
                cfg.enabled = false
                ib.h3zHidBars = ib.h3zHidBars or {}
                ib.h3zHidBars[key] = true
                changed = true
            end
        end
    elseif ib.h3zHidBars then
        UndoOldSwitch(ib)
        changed = true
    end
    if changed and _G.H3z0UI_RefreshActionBars then
        C_Timer.After(0, function() pcall(_G.H3z0UI_RefreshActionBars) end)
    end
end

function BB.ApplyMenus()
    if InCombatLockdown() then
        pendingApply = true
        return
    end
    pendingApply = false
    local ib = InfoBarDB()
    if not ib then return end
    local want = WantsHidden()
    SwitchOwnedBars(ib, want)
    for _, name in ipairs(FRAME_NAMES) do
        local frame = _G[name]
        if frame then
            if want and not hidden[frame] then
                local original = frame:GetParent() or UIParent
                if pcall(frame.SetParent, frame, hider) then hidden[frame] = original end
            elseif not want and hidden[frame] then
                pcall(frame.SetParent, frame, hidden[frame] or UIParent)
                hidden[frame] = nil
            end
        end
    end
    HookMainBar()
    BB.LiftMainBar()
end

---------------------------------------------------------------------------
-- Keep the main action bar above the Bottom Bar
-- When the main bar sits in Blizzard's default place at the bottom of the
-- screen (WoW: Forever's layout puts it right on the edge) it would cover
-- the Bottom Bar: lift it by the Bottom Bar's height. A bar you placed
-- yourself (H3z0 UI Edit Mode) is left alone.
---------------------------------------------------------------------------
local lifting = false
local function MainBar() return _G.MainActionBar or _G.MainMenuBar end

local function HasSavedPlace(bar)
    local BP = ns.BlizzPositions
    local p = Profile()
    if not (BP and BP.Key and p and bar and bar.system) then return false end
    local LS = ns.LayoutSets
    local mode = (LS and LS.CurrentMode and LS.CurrentMode()) or "pc"
    local store = p.blizzPositions and p.blizzPositions[mode]
    return store ~= nil and store[BP.Key(bar.system, bar.systemIndex)] ~= nil
end

function BB.LiftMainBar()
    if lifting then return end
    -- H3z0 UI's own bar frames are placed by Layout Mode (above the Bottom Bar by default)
    local owned = ns.ActionBarsOwned
    if owned and type(owned.containers) == "table" and next(owned.containers) then return end
    if InCombatLockdown() then
        pendingApply = true
        return
    end
    local ib = InfoBarDB()
    if not ib or ib.enabled == false or (ib.position or "BOTTOM") ~= "BOTTOM" then return end
    local bar = MainBar()
    if not (bar and bar.GetBottom and bar:IsShown()) then return end
    if bar.isInDefaultPosition == false or HasSavedPlace(bar) then return end
    local mgr = _G.EditModeManagerFrame
    if mgr and mgr.IsEditModeActive and mgr:IsEditModeActive() then return end
    local lm = ns.H3z0UI_LayoutMode
    if lm and lm.isActive then return end
    local info = _G.H3z0UI_InfoBar
    local top = info and info:IsShown() and info:GetTop()
    if not top then return end
    local us = UIParent:GetEffectiveScale() or 1
    top = top * (info:GetEffectiveScale() or 1) / us
    local bottom = (bar:GetBottom() or 0) * (bar:GetEffectiveScale() or 1) / us
    local need = top - bottom
    if need <= 0.5 then return end
    -- Blizzard stacks the bottom bars from the screen edge one by one: move every
    -- bar of that stack (still in its default place, not placed by you) up together
    local bars = { bar }
    if mgr and mgr.GetBottomActionBars then
        local ok, list = pcall(mgr.GetBottomActionBars, mgr)
        if ok and type(list) == "table" then bars = list end
    end
    lifting = true
    for _, b in ipairs(bars) do
        if b and b.IsShown and b:IsShown() and b.isInDefaultPosition ~= false and not HasSavedPlace(b) then
            local point, rel, relPoint, x, y = b:GetPoint(1)
            if point and (rel == nil or rel == UIParent) then
                local bs = (b:GetEffectiveScale() or 1) / us
                pcall(function()
                    local clear = b.ClearAllPointsBase or b.ClearAllPoints
                    local set = b.SetPointBase or b.SetPoint
                    clear(b)
                    set(b, point, UIParent, relPoint or point, x or 0, (y or 0) + need / bs)
                end)
            end
        end
    end
    lifting = false
end

local liftHooked = false
HookMainBar = function()
    if liftHooked then return end
    local bar = MainBar()
    if not bar then return end
    liftHooked = true
    for _, method in ipairs({ "ApplySystemAnchor", "UpdateSystemSettingScale" }) do
        if type(bar[method]) == "function" then
            hooksecurefunc(bar, method, function() C_Timer.After(0, BB.LiftMainBar) end)
        end
    end
    -- Blizzard lines the default bottom bars up again on many occasions
    local mgr = _G.EditModeManagerFrame
    if mgr and type(mgr.UpdateBottomActionBarPositions) == "function" then
        hooksecurefunc(mgr, "UpdateBottomActionBarPositions", function() C_Timer.After(0, BB.LiftMainBar) end)
    end
end

function BB.Refresh()
    if _G.H3z0UI_RefreshInfoBar then pcall(_G.H3z0UI_RefreshInfoBar) end
    BB.ApplyMenus()
end
_G.H3z0UI_RefreshBottomBar = BB.Refresh

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        local ok, err = pcall(BB.MigrateOldPanel)
        if not ok and geterrorhandler then geterrorhandler()(err) end
        pcall(BB.UseH3z0MenuIcons)
        C_Timer.After(0.5, BB.Refresh)
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then BB.ApplyMenus() end
        return
    end
    C_Timer.After(1.5, BB.ApplyMenus)
end)

-- the Info Bar options change things too
local InfoBar = H3z0UICore.InfoBar
if InfoBar and type(InfoBar.ApplyAll) == "function" then
    hooksecurefunc(InfoBar, "ApplyAll", function() C_Timer.After(0, BB.ApplyMenus) end)
end
