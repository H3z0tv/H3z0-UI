--[[
    H3z0UI Compact Bars (test)

    Switches Blizzard Edit Mode to a separate layout named "H3z0 Compact":
      - Action Bars 1-3: 8 buttons each, stacked as a 3-row grid, bottom center
      - Action Bar 4: 8 buttons in one row underneath
    Everything else is copied from the layout you are using now.

    Your own layout is never edited. Turning it off switches Edit Mode back to
    the layout you had before, so you can flip between both to compare.
]]

local ADDON_NAME, ns = ...

local CB = {}
ns.CompactBars = CB

local LAYOUT_NAME = "H3z0 Compact"

local function Say(msg)
    print("|cFF30D1FFH3z0 UI:|r " .. msg)
end

local function DB()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.compactBars = p.compactBars or {}
    return p.compactBars
end

local function NumPresets()
    local n = 0
    if Enum and Enum.EditModePresetLayouts then
        for _ in pairs(Enum.EditModePresetLayouts) do n = n + 1 end
    end
    return n > 0 and n or 2
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

local AB_SYSTEM = Enum and Enum.EditModeSystem and Enum.EditModeSystem.ActionBar or 0
local IDX = Enum and Enum.EditModeActionBarSystemIndices or {}
local SET = Enum and Enum.EditModeActionBarSetting or {}
local S_ORIENT   = SET.Orientation or 0
local S_ROWS     = SET.NumRows or 1
local S_ICONS    = SET.NumIcons or 2
local S_PADDING  = SET.IconPadding or 4
local S_HIDEART  = SET.HideBarArt or 6
local S_HIDESCRL = SET.HideBarScrolling or 8

local BAR1 = IDX.MainBar or 1
local BAR2 = IDX.Bar2 or 2
local BAR3 = IDX.Bar3 or 3
local BAR4 = IDX.RightBar1 or 4

local function FindSetting(sys, id)
    for _, e in ipairs(sys.settings or {}) do
        if e.setting == id then return e end
    end
end

local function SetSetting(sys, id, value)
    local e = FindSetting(sys, id)
    if e then
        e.value = value
    else
        sys.settings = sys.settings or {}
        table.insert(sys.settings, { setting = id, value = value })
    end
end

-- Button size on screen, in UIParent units
local function ButtonSize(name)
    local b = _G[name]
    if not b or not b.GetWidth then return nil end
    local w = b:GetWidth()
    local es, ues = b:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not w or w <= 0 or not es or not ues or ues == 0 then return nil end
    return w * es / ues
end

local function ModifySystems(systems)
    local size = math.max(
        ButtonSize("ActionButton1") or 0,
        ButtonSize("MultiBarBottomLeftButton1") or 0,
        ButtonSize("MultiBarBottomRightButton1") or 0,
        ButtonSize("MultiBarRightButton1") or 0)
    if size <= 0 then size = 40 end

    local bySlot = {}
    for _, sys in ipairs(systems) do
        if sys.system == AB_SYSTEM then bySlot[sys.systemIndex] = sys end
    end
    if not (bySlot[BAR1] and bySlot[BAR2] and bySlot[BAR3] and bySlot[BAR4]) then
        return false
    end

    local pad = 2
    local e = FindSetting(bySlot[BAR2], S_PADDING)
    if e and tonumber(e.value) then pad = math.max(0, math.min(10, tonumber(e.value))) end
    local rowH = math.floor(size + pad + 0.5)

    local bottomY = 20
    local gridY = bottomY + rowH + 14
    local place = {
        [BAR4] = bottomY,
        [BAR1] = gridY,
        [BAR2] = gridY + rowH,
        [BAR3] = gridY + rowH * 2,
    }

    for idx, y in pairs(place) do
        local sys = bySlot[idx]
        SetSetting(sys, S_ORIENT, 0)  -- horizontal
        SetSetting(sys, S_ROWS, 1)
        SetSetting(sys, S_ICONS, 8)
        if idx == BAR1 then
            SetSetting(sys, S_HIDEART, 1)
            SetSetting(sys, S_HIDESCRL, 1)
        end
        sys.anchorInfo = {
            point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM",
            offsetX = 0, offsetY = y,
        }
        sys.anchorInfo2 = nil
        sys.isInDefaultPosition = false
    end
    return true
end

ns.Popups["H3Z0UI_COMPACT_RELOAD"] = {
    text = "%s\n\nReload the UI now so the action bars update cleanly?",
    button1 = RELOADUI or "Reload UI",
    button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function Activate(layoutInfo, index, message)
    layoutInfo.activeLayout = index
    local ok, err = pcall(C_EditMode.SaveLayouts, layoutInfo)
    if not ok then
        Say("Saving the Edit Mode layout failed: " .. tostring(err))
        return false
    end
    if C_EditMode.SetActiveLayout then pcall(C_EditMode.SetActiveLayout, index) end
    ns.ShowPopup("H3Z0UI_COMPACT_RELOAD", message)
    return true
end

function CB.IsActive()
    if not (C_EditMode and C_EditMode.GetLayouts) then return false end
    local info = C_EditMode.GetLayouts()
    if type(info) ~= "table" or type(info.layouts) ~= "table" then return false end
    local l = info.layouts[(tonumber(info.activeLayout) or 0) - NumPresets()]
    return type(l) == "table" and l.layoutName == LAYOUT_NAME
end

function CB.Enable()
    if InCombatLockdown() then Say("Leave combat first.") return false end
    if not (C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts) then
        Say("Edit Mode is not available.")
        return false
    end
    local info = C_EditMode.GetLayouts()
    if type(info) ~= "table" or type(info.layouts) ~= "table" then
        Say("Edit Mode layouts are not loaded yet. Try again in a few seconds.")
        return false
    end
    if CB.IsActive() then Say("Compact bars are already on.") return true end

    local np = NumPresets()
    local active = tonumber(info.activeLayout) or 1
    local src
    local current = info.layouts[active - np]
    if active > np and type(current) == "table" then
        src = current.systems
    else
        local mgr = _G.EditModePresetLayoutManager
        local ok, presets = pcall(function() return mgr and mgr:GetCopyOfPresetLayouts() end)
        local preset = ok and type(presets) == "table" and (presets[active] or presets[1])
        src = preset and preset.systems
    end
    if type(src) ~= "table" then
        Say("Could not read your current Edit Mode layout.")
        return false
    end

    local systems = DeepCopy(src)
    if not ModifySystems(systems) then
        Say("Action Bars 1-4 were not found in your Edit Mode layout.")
        return false
    end

    local idx
    for i, l in ipairs(info.layouts) do
        if l.layoutName == LAYOUT_NAME then idx = i break end
    end
    if idx then
        info.layouts[idx].systems = systems
    else
        local accountType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
        table.insert(info.layouts, { layoutName = LAYOUT_NAME, layoutType = accountType, systems = systems })
        idx = #info.layouts
    end

    local db = DB()
    if db then db.previousLayout = active end
    return Activate(info, np + idx,
        "Compact action bars are on (Edit Mode layout \"" .. LAYOUT_NAME .. "\").\nAction Bars 2, 3 and 4 must be enabled in Options > Gameplay > Action Bars.")
end

function CB.Disable()
    if InCombatLockdown() then Say("Leave combat first.") return false end
    if not (C_EditMode and C_EditMode.GetLayouts) then return false end
    local info = C_EditMode.GetLayouts()
    if type(info) ~= "table" or type(info.layouts) ~= "table" then return false end
    if not CB.IsActive() then Say("Compact bars are already off.") return true end

    local np = NumPresets()
    local total = np + #info.layouts
    local db = DB()
    local back = db and tonumber(db.previousLayout)
    local backLayout = back and info.layouts[back - np]
    if not back or back < 1 or back > total or (backLayout and backLayout.layoutName == LAYOUT_NAME) then
        back = nil
        for i, l in ipairs(info.layouts) do
            if l.layoutName ~= LAYOUT_NAME then back = np + i break end
        end
        back = back or 1
    end
    return Activate(info, back, "Your own action bar layout is back.")
end

function CB.Toggle()
    if CB.IsActive() then return CB.Disable() end
    return CB.Enable()
end

_G.H3z0UI_ToggleCompactBars = CB.Toggle
