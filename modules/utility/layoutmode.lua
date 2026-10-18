--[[
    H3z0 UI - Layout Mode
    One place to move every H3z0 UI frame: drag the green handles, arrow keys nudge
    (Shift = 10px), Esc or Done to leave. Only positions change - sizes are never touched.

    Positions are saved through each module's own save code (the same code the
    per-module edit modes and shift+drag already use), so the options menu stays in sync.

    Open with /h3z0ui layout, the "H3z0 UI Layout Mode" button in the Esc menu,
    or the Layout Mode button in the options window.
]]

local ADDON_NAME, ns = ...

local LM = {
    active = false,
    handles = {},
    started = {},      -- things we switched on when entering, so we only undo our own changes
    selected = nil,
    showGrid = true,
    snap = false,
    GRID = 16,
}
ns.H3z0UI_LayoutMode = LM

local function Core() return ns.Addon end
local function Profile()
    local core = Core()
    return core and core.db and core.db.profile
end
local function UF() return ns.H3z0UI_UnitFrames end

local function Accent()
    local C = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    local a = C and C.accent
    if a then return a[1], a[2], a[3] end
    return 0.204, 0.827, 0.6
end

local function Say(msg)
    print("|cff34D399H3z0 UI:|r " .. msg)
end

local function Round(v)
    return v >= 0 and math.floor(v + 0.5) or math.ceil(v - 0.5)
end

local function PixelRound(v, frame)
    local core = Core()
    if core and core.PixelRound then
        local ok, r = pcall(core.PixelRound, core, v, frame)
        if ok and type(r) == "number" then return r end
    end
    return Round(v)
end

-- Offset of a frame's center from the screen center
local function CenterOffset(frame)
    local x, y = frame:GetCenter()
    local px, py = UIParent:GetCenter()
    if not (x and y and px and py) then return nil end
    return x - px, y - py
end

---------------------------------------------------------------------------
-- Element definitions
---------------------------------------------------------------------------
-- frame()      -> the frame to move (nil = not available right now)
-- save(frame)  -> store the new position (nil = use the frame's own OnDragStop saver)
-- locked()     -> text when the element follows another frame and can't be dragged
-- enter/exit   -> shared group hooks (preview on / off)

local groups = {}
local elements = {}

local function AddElement(def) elements[#elements + 1] = def end

-- Unit frames + cast bars: use the unit frames' own edit mode for previews and savers
groups.unitframes = {
    enter = function()
        local uf = UF()
        if not uf or not uf.EnableEditMode then return end
        if not uf.editModeActive then
            uf._layoutModeQuiet = true
            uf:EnableEditMode()
            uf._layoutModeQuiet = nil
            LM.started.unitframes = true
        end
        -- Keep our look: hide the module's own overlays / exit button
        if uf.exitEditModeBtn then uf.exitEditModeBtn:Hide() end
        for key, frame in pairs(uf.frames or {}) do
            if frame.editOverlay then frame.editOverlay:Hide() end
            if not (frame.unit and frame.unit:match("^boss%d$")) and frame.EnableKeyboard then
                pcall(frame.EnableKeyboard, frame, false)
            end
        end
    end,
    exit = function()
        local uf = UF()
        if LM.started.unitframes and uf and uf.DisableEditMode then
            uf._layoutModeQuiet = true
            uf:DisableEditMode()
            uf._layoutModeQuiet = nil
        end
        LM.started.unitframes = nil
    end,
}

local UNIT_LABELS = {
    player = "Player", target = "Target", focus = "Focus", pet = "Pet",
    targettarget = "Target of Target", boss = "Boss Frames",
}

local function UnitSettings(key)
    local p = Profile()
    return p and p.h3z0uiUnitFrames and p.h3z0uiUnitFrames[key]
end

for _, key in ipairs({ "player", "target", "focus", "pet", "targettarget", "boss" }) do
    AddElement({
        key = "uf_" .. key, label = UNIT_LABELS[key], group = "unitframes",
        frame = function()
            local s = UnitSettings(key)
            if s and s.enabled == false then return nil end
            local uf = UF()
            return uf and uf.frames and uf.frames[key == "boss" and "boss1" or key]
        end,
        locked = function()
            local s = UnitSettings(key)
            if s and s.anchorTo and s.anchorTo ~= "disabled" and (key == "player" or key == "target") then
                return "locked to " .. tostring(s.anchorTo)
            end
        end,
        afterSave = function()
            local uf = UF()
            if key == "boss" and uf and uf.RefreshFrame then pcall(uf.RefreshFrame, uf, "boss") end
        end,
    })
end

for _, key in ipairs({ "player", "target", "focus", "pet", "targettarget" }) do
    AddElement({
        key = "cb_" .. key, label = UNIT_LABELS[key] .. " Cast Bar", group = "unitframes",
        frame = function()
            local s = UnitSettings(key)
            local cs = s and s.castbar
            if not cs or not cs.enabled then return nil end
            local uf = UF()
            return uf and uf.castbars and uf.castbars[key]
        end,
        locked = function()
            local s = UnitSettings(key)
            local cs = s and s.castbar
            local anchor = cs and cs.anchor or "none"
            if anchor ~= "none" then return "locked to " .. anchor end
        end,
    })
end

-- Party frames (H3z0 UI party frames)
groups.party = {
    enter = function()
        if not IsInGroup() and _G.H3z0UI_PartyFramesSetTest and _G.H3z0UI_PartyFramesIsTest
            and not _G.H3z0UI_PartyFramesIsTest() then
            _G.H3z0UI_PartyFramesSetTest(true)
            LM.started.partyTest = true
        end
        local tab = _G.H3z0UI_RaidControlTab
        if tab then
            LM.started.tabWasShown = tab:IsShown()
            tab:Show()
        end
    end,
    exit = function()
        if LM.started.partyTest and _G.H3z0UI_PartyFramesSetTest then
            _G.H3z0UI_PartyFramesSetTest(false)
        end
        LM.started.partyTest = nil
        local tab = _G.H3z0UI_RaidControlTab
        if tab and LM.started.tabWasShown == false then tab:Hide() end
        LM.started.tabWasShown = nil
        if _G.H3z0UI_RaidControlRefreshAnchor then _G.H3z0UI_RaidControlRefreshAnchor() end
    end,
}

AddElement({
    key = "party", label = "Party Frames", group = "party",
    frame = function()
        local p = Profile()
        if p and p.partyFrames and p.partyFrames.enabled == false then return nil end
        return _G.H3z0UI_PartyFrames
    end,
    save = function(frame)
        local p = Profile()
        if not (p and p.partyFrames) then return end
        local point, _, relPoint, x, y = frame:GetPoint()
        p.partyFrames.pos = { point = point, relPoint = relPoint, x = x, y = y }
    end,
    afterSave = function()
        if _G.H3z0UI_RefreshPartyFrames then _G.H3z0UI_RefreshPartyFrames() end
    end,
})

-- Raid frames (0.24.5): a 20-player preview with pets while you are not in a raid
groups.raid = {
    enter = function()
        if not IsInRaid() and _G.H3z0UI_RaidFramesSetTest and _G.H3z0UI_RaidFramesIsTest
            and not _G.H3z0UI_RaidFramesIsTest() then
            _G.H3z0UI_RaidFramesSetTest(true)
            LM.started.raidTest = true
        end
    end,
    exit = function()
        if LM.started.raidTest and _G.H3z0UI_RaidFramesSetTest then
            _G.H3z0UI_RaidFramesSetTest(false)
        end
        LM.started.raidTest = nil
    end,
}

AddElement({
    key = "raid", label = "Raid Frames", group = "raid",
    frame = function()
        local p = Profile()
        if p and p.raidFrames and p.raidFrames.enabled == false then return nil end
        return _G.H3z0UI_RaidFrames
    end,
    save = function(frame)
        local p = Profile()
        if not (p and p.raidFrames) then return end
        local point, _, relPoint, x, y = frame:GetPoint()
        p.raidFrames.pos = { point = point, relPoint = relPoint, x = x, y = y }
    end,
    afterSave = function()
        if _G.H3z0UI_RefreshRaidFrames then _G.H3z0UI_RefreshRaidFrames() end
    end,
})

AddElement({
    key = "raidtab", label = "Raid Control", group = "party",
    frame = function() return _G.H3z0UI_RaidControlTab end,
})

-- Power bars: their own edit mode does the (lock-aware) saving
groups.powerbars = {
    enter = function()
        local core = Core()
        if core and core.EnablePowerBarEditMode then
            pcall(core.EnablePowerBarEditMode, core)
            LM.started.powerbars = true
            for _, bar in ipairs({ core.powerBar, core.secondaryPowerBar }) do
                if bar and bar.editOverlay then bar.editOverlay:Hide() end
            end
        end
    end,
    exit = function()
        local core = Core()
        if LM.started.powerbars and core and core.DisablePowerBarEditMode then
            pcall(core.DisablePowerBarEditMode, core)
        end
        LM.started.powerbars = nil
    end,
}

AddElement({
    key = "powerbar", label = "Power Bar", group = "powerbars",
    frame = function()
        local p, core = Profile(), Core()
        if not (p and p.powerBar and p.powerBar.enabled) then return nil end
        return core and core.powerBar
    end,
    locked = function()
        local cfg = Profile() and Profile().powerBar
        if cfg and (cfg.lockedToEssential or cfg.lockedToUtility) then return "locked to cooldowns" end
    end,
})

AddElement({
    key = "secondarypowerbar", label = "Secondary Power Bar", group = "powerbars",
    frame = function()
        local p, core = Profile(), Core()
        if not (p and p.secondaryPowerBar and p.secondaryPowerBar.enabled) then return nil end
        return core and core.secondaryPowerBar
    end,
})

-- Totem bar (shaman): moved through its preview
local TOTEM_ANCHOR = { RIGHT = "LEFT", LEFT = "RIGHT", DOWN = "TOP", UP = "BOTTOM" }
groups.totems = {
    enter = function()
        local core = Core()
        local tb = core and core.TotemBar
        local db = Profile() and Profile().totemBar
        if tb and db and db.enabled and tb.ShowPreview and not (tb.IsPreviewShown and tb:IsPreviewShown()) then
            tb:ShowPreview()
            LM.started.totems = true
        end
    end,
    exit = function()
        local core = Core()
        local tb = core and core.TotemBar
        if LM.started.totems and tb and tb.HidePreview then tb:HidePreview() end
        LM.started.totems = nil
    end,
}

AddElement({
    key = "totems", label = "Totem Bar", group = "totems",
    frame = function()
        local db = Profile() and Profile().totemBar
        if not (db and db.enabled) then return nil end
        return _G.H3z0UI_TotemBarPreview
    end,
    save = function(frame)
        local db = Profile() and Profile().totemBar
        if not db then return end
        local anchor = TOTEM_ANCHOR[db.growDirection or "RIGHT"] or "LEFT"
        local x, y = frame:GetCenter()
        if anchor == "LEFT" then x = frame:GetLeft()
        elseif anchor == "RIGHT" then x = frame:GetRight()
        elseif anchor == "TOP" then y = frame:GetTop()
        elseif anchor == "BOTTOM" then y = frame:GetBottom() end
        local px, py = UIParent:GetCenter()
        if not (x and y and px and py) then return end
        db.offsetX = PixelRound(x - px, frame)
        db.offsetY = PixelRound(y - py, frame)
    end,
    afterSave = function()
        if _G.H3z0UI_RefreshTotemBar then _G.H3z0UI_RefreshTotemBar() end
    end,
})

-- Combat timer
groups.combattimer = {
    enter = function()
        local s = Profile() and Profile().combatTimer
        if s and s.enabled and _G.H3z0UI_ToggleCombatTimerPreview
            and not (_G.H3z0UI_IsCombatTimerPreviewMode and _G.H3z0UI_IsCombatTimerPreviewMode()) then
            _G.H3z0UI_ToggleCombatTimerPreview(true)
            LM.started.combattimer = true
        end
    end,
    exit = function()
        if LM.started.combattimer and _G.H3z0UI_ToggleCombatTimerPreview then
            _G.H3z0UI_ToggleCombatTimerPreview(false)
        end
        LM.started.combattimer = nil
    end,
}

AddElement({
    key = "combattimer", label = "Combat Timer", group = "combattimer",
    frame = function()
        local s = Profile() and Profile().combatTimer
        if not (s and s.enabled) then return nil end
        return _G.H3z0UI_CombatTimer
    end,
    save = function(frame)
        local s = Profile() and Profile().combatTimer
        local dx, dy = CenterOffset(frame)
        if not (s and dx) then return end
        s.xOffset = PixelRound(dx, frame)
        s.yOffset = PixelRound(dy, frame)
    end,
    afterSave = function()
        if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
    end,
})

-- Mythic+ timer (demo mode while outside a key)
groups.mplus = {
    enter = function()
        local s = Profile() and Profile().mplusTimer
        local T = _G.H3z0UI_MPlusTimer
        local root = _G.H3z0UI_MPlusTimerFrame
        if s and s.enabled and T and T.EnableDemoMode and not (root and root:IsShown()) then
            pcall(T.EnableDemoMode, T)
            LM.started.mplus = true
        end
    end,
    exit = function()
        local T = _G.H3z0UI_MPlusTimer
        if LM.started.mplus and T and T.DisableDemoMode then pcall(T.DisableDemoMode, T) end
        LM.started.mplus = nil
    end,
}

AddElement({
    key = "mplus", label = "M+ Timer", group = "mplus",
    frame = function()
        local s = Profile() and Profile().mplusTimer
        if not (s and s.enabled) then return nil end
        return _G.H3z0UI_MPlusTimerFrame
    end,
})

-- Minimap
groups.minimap = {
    enter = function()
        local core = Core()
        if core and core.EnableMinimapEditMode then
            pcall(core.EnableMinimapEditMode, core)
            LM.started.minimap = true
        end
    end,
    exit = function()
        local core = Core()
        if LM.started.minimap and core and core.DisableMinimapEditMode then
            pcall(core.DisableMinimapEditMode, core)
        end
        LM.started.minimap = nil
    end,
}

AddElement({
    key = "minimap", label = "Minimap", group = "minimap",
    frame = function()
        local s = Profile() and Profile().minimap
        if s and s.enabled == false then return nil end
        if not (Minimap and Minimap:GetScript("OnDragStop")) then return nil end
        return Minimap
    end,
})

-- Minimap coordinates (offset from the minimap's top right corner)
AddElement({
    key = "coords", label = "Coordinates", group = "minimap",
    frame = function()
        local s = Profile() and Profile().minimap
        if not (s and s.enabled ~= false and s.showCoords and s.coordsConfig) then return nil end
        return _G.H3z0UI_MinimapCoordsFrame
    end,
    save = function(frame)
        local s = Profile() and Profile().minimap
        local cfg = s and s.coordsConfig
        if not (cfg and Minimap) then return end
        local right, top = frame:GetRight(), frame:GetTop()
        local mRight, mTop = Minimap:GetRight(), Minimap:GetTop()
        if not (right and top and mRight and mTop) then return end
        cfg.offsetX = Round(right - mRight)
        cfg.offsetY = Round(top - mTop)
    end,
    afterSave = function()
        if _G.H3z0UI_RefreshMinimap then _G.H3z0UI_RefreshMinimap() end
    end,
})

-- Datatext panels (Bottom Bar and any custom panels)
local function PanelElements()
    local list = {}
    local core = Core()
    local DP = core and core.Datapanels
    if DP and DP.activePanels then
        for id, panel in pairs(DP.activePanels) do
            if panel and panel.GetScript and panel:GetScript("OnDragStop") then
                local cfg = panel.config or {}
                local label = (id == "bottombar") and "Bottom Bar" or (cfg.name or cfg.label or ("Panel " .. tostring(id)))
                list[#list + 1] = {
                    key = "panel_" .. tostring(id), label = label, group = "panels",
                    frame = function() return DP.activePanels[id] end,
                    restoreMovable = function(f) f:SetMovable(not (f.config and f.config.locked)) end,
                }
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Action bars (Blizzard's bars): the position is written into the active
-- Blizzard Edit Mode layout, and Blizzard moves the bar itself. The bar frame
-- is never moved by addon code; the handle is dragged as a ghost.
---------------------------------------------------------------------------
local EM = {}
LM.EditMode = EM

local function NumPresetLayouts()
    local n = 0
    if Enum and Enum.EditModePresetLayouts then
        for _ in pairs(Enum.EditModePresetLayouts) do n = n + 1 end
    end
    return n > 0 and n or 2
end

-- Returns layoutInfo (from C_EditMode) and the active custom layout, or nil + reason
function EM.GetActiveCustomLayout()
    if not (C_EditMode and C_EditMode.GetLayouts) then return nil, nil, "Edit Mode is not available." end
    local layoutInfo = C_EditMode.GetLayouts()
    if type(layoutInfo) ~= "table" or type(layoutInfo.layouts) ~= "table" then
        return nil, nil, "Edit Mode layouts are not loaded yet."
    end
    local active = tonumber(layoutInfo.activeLayout) or 0
    local customIndex = active - NumPresetLayouts()
    local layout = layoutInfo.layouts[customIndex]
    if customIndex < 1 or type(layout) ~= "table" then
        return layoutInfo, nil, "preset"
    end
    return layoutInfo, layout
end

-- Copy the active Blizzard preset (Modern/Classic) into a custom "H3z0 UI" layout
function EM.CopyPresetToCustom()
    if InCombatLockdown() then return false end
    local layoutInfo = C_EditMode.GetLayouts()
    if type(layoutInfo) ~= "table" or type(layoutInfo.layouts) ~= "table" then return false end
    local mgr = _G.EditModePresetLayoutManager
    local ok, presets = pcall(function() return mgr and mgr:GetCopyOfPresetLayouts() end)
    if not ok or type(presets) ~= "table" then return false end
    local preset = presets[tonumber(layoutInfo.activeLayout) or 1] or presets[1]
    if type(preset) ~= "table" or type(preset.systems) ~= "table" then return false end
    local LSets = ns.LayoutSets
    local name = LSets and LSets.ModeLayoutName() or "H3z0 PC"
    for _, l in ipairs(layoutInfo.layouts) do
        if l.layoutName == name then name = name .. " " .. date("%H%M%S") break end
    end
    local accountType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    table.insert(layoutInfo.layouts, { layoutName = name, layoutType = accountType, systems = preset.systems })
    local newIndex = NumPresetLayouts() + #layoutInfo.layouts
    layoutInfo.activeLayout = newIndex
    local saved = pcall(C_EditMode.SaveLayouts, layoutInfo)
    if not saved then return false end
    if C_EditMode.SetActiveLayout then pcall(C_EditMode.SetActiveLayout, newIndex) end
    Say("Your Blizzard preset layout was copied to a custom Edit Mode layout named \"" .. name .. "\". Drag the bar again to move it.")
    return true
end

ns.Popups["H3Z0UI_LAYOUT_COPY_PRESET"] = {
    text = "Your Edit Mode layout is a Blizzard preset (Modern/Classic), which can't be changed.\n\nCopy it to a custom layout managed by H3z0 UI so Layout Mode can move Blizzard frames (action bars, Cooldown Manager, ...)?",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    OnAccept = function() EM.CopyPresetToCustom() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local applyWarned = false
function EM.SaveSystemOffset(systemType, systemIndex, frame, dx, dy)
    if InCombatLockdown() then return end
    local layoutInfo, layout, reason = EM.GetActiveCustomLayout()
    if not layout then
        if reason == "preset" then
            ns.ShowPopup("H3Z0UI_LAYOUT_COPY_PRESET")
        else
            Say(reason or "Could not read your Edit Mode layout.")
        end
        return
    end
    local entry
    for _, sys in ipairs(layout.systems or {}) do
        if sys.system == systemType and (systemIndex == nil or sys.systemIndex == systemIndex) then
            entry = sys
            break
        end
    end
    if not entry then
        Say("This frame is not in your Edit Mode layout yet. Type /h3z0ui blizzedit, move it once there, then use Layout Mode again.")
        return
    end
    dx, dy = Round(dx), Round(dy)
    entry.anchorInfo = {
        point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER",
        offsetX = dx, offsetY = dy,
    }
    entry.anchorInfo2 = nil
    entry.isInDefaultPosition = false

    local ok, err = pcall(C_EditMode.SaveLayouts, layoutInfo)
    if not ok then
        Say("Saving the Edit Mode layout failed: " .. tostring(err))
        return
    end
    -- Let Blizzard re-apply the layout (it moves its own bars and refreshes its cache)
    if C_EditMode.SetActiveLayout then pcall(C_EditMode.SetActiveLayout, layoutInfo.activeLayout) end

    -- If the bar didn't follow, the new position shows after a reload
    C_Timer.After(0.4, function()
        if not frame or applyWarned then return end
        local cx, cy = CenterOffset(frame)
        if cx and (math.abs(cx - dx) > 3 or math.abs(cy - dy) > 3) then
            applyWarned = true
            Say("Action bar position saved to your Edit Mode layout. Type |cffFFFF00/reload|r to see it in place.")
        end
    end)
end

local AB_SYSTEM = Enum and Enum.EditModeSystem and Enum.EditModeSystem.ActionBar
local AB_IDX = Enum and Enum.EditModeActionBarSystemIndices or {}
local ACTION_BARS = {
    { key = "ab1", label = "Action Bar 1", index = AB_IDX.MainBar or 1,   frames = { "MainActionBar", "MainMenuBar" } },
    { key = "ab2", label = "Action Bar 2", index = AB_IDX.Bar2 or 2,      frames = { "MultiBarBottomLeft" } },
    { key = "ab3", label = "Action Bar 3", index = AB_IDX.Bar3 or 3,      frames = { "MultiBarBottomRight" } },
    { key = "ab4", label = "Action Bar 4", index = AB_IDX.RightBar1 or 4, frames = { "MultiBarRight" } },
    { key = "ab5", label = "Action Bar 5", index = AB_IDX.RightBar2 or 5, frames = { "MultiBarLeft" } },
    { key = "ab6", label = "Action Bar 6", index = AB_IDX.ExtraBar1 or 6, frames = { "MultiBar5" } },
    { key = "ab7", label = "Action Bar 7", index = AB_IDX.ExtraBar2 or 7, frames = { "MultiBar6" } },
    { key = "ab8", label = "Action Bar 8", index = AB_IDX.ExtraBar3 or 8, frames = { "MultiBar7" } },
    { key = "abStance", label = "Stance Bar", index = AB_IDX.StanceBar or 11, frames = { "StanceBar" } },
    { key = "abPet",    label = "Pet Bar",    index = AB_IDX.PetActionBar or 12, frames = { "PetActionBar" } },
}

-- Hidden from Layout Mode while Handheld Mode (Deck) is on: ConsolePort covers them
local DECK_HIDDEN_BARS = { ab1 = true, ab2 = true, ab3 = true }

for _, info in ipairs(ACTION_BARS) do
    AddElement({
        key = info.key, label = info.label, group = "actionbars", ghost = true,
        frame = function()
            if not AB_SYSTEM then return nil end
            if DECK_HIDDEN_BARS[info.key] and ns.LayoutSets and ns.LayoutSets.CurrentMode() == "deck" then
                return nil
            end
            for _, name in ipairs(info.frames) do
                local f = _G[name]
                if f then return f end
            end
        end,
        saveOffset = function(frame, dx, dy)
            -- saved in H3z0 UI (not in Blizzard's Edit Mode)
            if ns.BlizzPositions then ns.BlizzPositions.Save(frame, dx, dy) end
        end,
    })
end

---------------------------------------------------------------------------
-- Handles
---------------------------------------------------------------------------
local function StyleHandle(h, state)
    local r, g, b = Accent()
    if h.isLocked then
        h:SetBackdropColor(0.5, 0.5, 0.5, 0.18)
        h:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
    elseif state == "selected" then
        h:SetBackdropColor(r, g, b, 0.35)
        h:SetBackdropBorderColor(1, 1, 1, 1)
    elseif state == "hover" then
        h:SetBackdropColor(r, g, b, 0.30)
        h:SetBackdropBorderColor(r, g, b, 1)
    else
        h:SetBackdropColor(r, g, b, 0.16)
        h:SetBackdropBorderColor(r, g, b, 0.9)
    end
end

local function UpdateReadout()
    local bar = LM.toolbar
    if not bar then return end
    local el = LM.selected
    local h = el and LM.handles[el.key]
    local target = h and h.target
    if target then
        local dx, dy = CenterOffset(target)
        if dx then
            bar.readout:SetText(("%s   X: %d   Y: %d"):format(el.label, Round(dx), Round(dy)))
            return
        end
    end
    bar.readout:SetText("Click a frame to select it, then drag it or use the arrow keys.")
end

local function Select(el)
    local prev = LM.selected and LM.handles[LM.selected.key]
    LM.selected = el
    if prev then StyleHandle(prev, "normal") end
    local h = el and LM.handles[el.key]
    if h then StyleHandle(h, "selected") end
    UpdateReadout()
    if LM.UpdateInspector then pcall(LM.UpdateInspector, el) end
end

local function MoveTo(target, dx, dy)
    target:ClearAllPoints()
    target:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
end

local function SaveElement(el, target)
    if el.save then
        pcall(el.save, target)
    else
        local stop = target:GetScript("OnDragStop")
        if stop then pcall(stop, target) end
    end
    if el.restoreMovable then pcall(el.restoreMovable, target) end
    if el.afterSave then pcall(el.afterSave) end
    UpdateReadout()
end

local function SnapToGrid(target)
    if not LM.snap then return end
    local dx, dy = CenterOffset(target)
    if not dx then return end
    local g = LM.GRID
    MoveTo(target, Round(dx / g) * g, Round(dy / g) * g)
end

---------------------------------------------------------------------------
-- Right-click: open the element's settings page
-- { tab, subTab, section } - tab / sub-tab numbers of the options window
---------------------------------------------------------------------------
local UF_SUB = { player = 2, target = 3, targettarget = 4, pet = 5, focus = 6, boss = 7 }
local SETTINGS = {
    party = { 4, 1 }, raidtab = { 4, 1 }, raid = { 4, 2 },
    powerbar = { 5, 5, "Primary Class Resource Bar" },
    secondarypowerbar = { 5, 5, "Secondary Class Resource Bar" },
    totems = { 8, 6 },
    combattimer = { 3, 1, "Combat Timer" },
    mplus = { 10, 2, "H3z0 UI M+ Timer" },
    minimap = { 9, 1 },
    coords = { 1, 6 },
    panel_bottombar = { 1, 3 },
}
for unit, sub in pairs(UF_SUB) do
    SETTINGS["uf_" .. unit] = { 6, sub }
    SETTINGS["cb_" .. unit] = { 6, sub, "Castbar" }
end
-- 0.24.6: action bars open Action Bars > Bar Layout with that bar picked
local AB_PICK = { ab1 = "bar1", ab2 = "bar2", ab3 = "bar3", ab4 = "bar4", ab5 = "bar5", ab6 = "bar6",
    ab7 = "bar7", ab8 = "bar8", abStance = "stance", abPet = "pet" }
for k in pairs(AB_PICK) do
    SETTINGS[k] = { 8, 1 }
end

local function SettingsFor(el)
    if SETTINGS[el.key] then return SETTINGS[el.key] end
    if el.key:match("^panel_") then return { 9, 2 } end
    local S = Enum and Enum.EditModeSystem or {}
    if el.sys and S.ObjectiveTracker and el.sys == S.ObjectiveTracker then
        return { 10, 2, "Objective Tracker" }          -- Skinning & Autohide > Skinning
    end
    if el.sys and S.AuraFrame and el.sys == S.AuraFrame then
        return { 3, 4 }                               -- General & QoL > Buff & Debuff
    end
    if el.sys and S.ChatFrame and el.sys == S.ChatFrame then
        return { 7, 1 }                               -- Chat
    end
    if el.sys and S.ExtraAbilities and el.sys == S.ExtraAbilities then
        return { 8, 5 }                               -- Action Bars > Extra Buttons
    end
    if el.sys and ((S.TalkingHeadFrame and el.sys == S.TalkingHeadFrame)
        or (S.StatusTrackingBar and el.sys == S.StatusTrackingBar)) then
        return { 10, 1 }                               -- Skinning & Autohide > Autohide
    end
    if el.cdmIndex ~= nil then
        local I = Enum and Enum.EditModeCooldownViewerSystemIndices or {}
        if el.cdmIndex == I.Essential then return { 5, 1 } end
        if el.cdmIndex == I.Utility then return { 5, 2 } end
        return { 5, 4 }
    end
end

local function OpenSettings(el)
    local where = SettingsFor(el)
    local GUI = _G.H3z0UI and _G.H3z0UI.GUI
    if not where then
        -- short on-screen note instead of chat lines (no spam on repeated clicks)
        local now = GetTime()
        if el._noSetNote and now - el._noSetNote < 3 then return end
        el._noSetNote = now
        local msg = el.label .. ": no H3z0 UI settings - drag to move it."
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(msg, 1, 0.82, 0)
        end
        return
    end
    if not (GUI and GUI.NavigateTo) then return end
    if AB_PICK[el.key] then _G.H3z0UI_ActionBarLayoutPick = AB_PICK[el.key] end
    -- Layout Mode stays open: the options window opens on top of the handles
    GUI:NavigateTo(where[1], where[2], where[3])
    local mf = GUI.MainFrame
    if mf then mf:Raise() end
end

local function OptionsOpen()
    local GUI = _G.H3z0UI and _G.H3z0UI.GUI
    return GUI and GUI.MainFrame and GUI.MainFrame:IsShown(), GUI
end

local function CreateHandle(el)
    local h = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    -- HIGH: above every frame it moves, below the options window (DIALOG), so the
    -- options can open on top of Layout Mode without changing the window's layer
    h:SetFrameStrata("HIGH")
    h:SetFrameLevel(200)
    h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    h:RegisterForDrag("LeftButton")
    h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    h:SetClampedToScreen(false)

    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.label:SetPoint("CENTER")
    h.label:SetTextColor(1, 1, 1, 1)
    h.label:SetShadowOffset(1, -1)

    h:SetScript("OnEnter", function(self)
        if LM.selected ~= self.el then StyleHandle(self, "hover") end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.el.label, 1, 1, 1)
        if self.isLocked then
            GameTooltip:AddLine("Can't be dragged: " .. (self.lockText or "locked") .. ".", 1, 0.6, 0.3, true)
            GameTooltip:AddLine("Change its anchor in the options to move it freely.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("Drag to move. Arrow keys nudge 1px, Shift+arrow 10px.", 0.8, 0.8, 0.8, true)
            if self.el.resizable then
                GameTooltip:AddLine("Drag the corner (bottom right) to resize.", 0.8, 0.8, 0.8, true)
            end
        end
        GameTooltip:AddLine("Click: its settings and on / off panel. Right-click: all settings in the options.", 0.2, 0.83, 0.6, true)
        GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function(self)
        StyleHandle(self, LM.selected == self.el and "selected" or "normal")
        GameTooltip:Hide()
    end)
    h:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            GameTooltip:Hide()
            OpenSettings(self.el)
            return
        end
        Select(self.el)
    end)
    h:SetScript("OnDragStart", function(self)
        if self.isLocked or InCombatLockdown() then return end
        local target = self.target
        if not target then return end
        Select(self.el)
        if self.el.ghost then
            -- Drag only the handle; the real frame is moved by Blizzard after saving
            local l, b, w, hh = self:GetLeft(), self:GetBottom(), self:GetWidth(), self:GetHeight()
            if not (l and b) then return end
            self:ClearAllPoints()
            self:SetSize(w, hh)
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
            self:SetMovable(true)
            self:StartMoving()
            LM.dragging = self
            return
        end
        target:SetMovable(true)
        target:StartMoving()
        LM.dragging = target
    end)
    h:SetScript("OnDragStop", function(self)
        local target = self.target
        if self.el.ghost then
            if LM.dragging ~= self then return end
            LM.dragging = nil
            self:StopMovingOrSizing()
            local dx, dy = CenterOffset(self)
            if dx and LM.snap then
                local g = LM.GRID
                dx, dy = Round(dx / g) * g, Round(dy / g) * g
            end
            if dx and target and self.el.saveOffset then self.el.saveOffset(target, dx, dy) end
            -- re-attach the handle to the bar once Blizzard has moved it
            C_Timer.After(0.05, function() self.target = nil end)
            return
        end
        if not target or LM.dragging ~= target then return end
        LM.dragging = nil
        target:StopMovingOrSizing()
        SnapToGrid(target)
        SaveElement(self.el, target)
    end)

    -- Resize grip (bottom-right) for frames that can be resized (chat, damage meter)
    local grip = CreateFrame("Button", nil, h)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -1, 1)
    grip:SetFrameLevel(h:GetFrameLevel() + 5)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:Hide()
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Drag to resize", 1, 1, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    grip:SetScript("OnMouseDown", function(self, button)
        local target = h.target
        if button ~= "LeftButton" or not target or InCombatLockdown() then return end
        local us = UIParent:GetEffectiveScale()
        local fs = target:GetEffectiveScale()
        local left, top = target:GetLeft(), target:GetTop()
        if not (left and top and us and fs) then return end
        local k = fs / us                 -- frame units -> UIParent units
        local leftU, topU = left * k, top * k
        local minW, minH = 120, 60
        if target.GetResizeBounds then
            local ok, a, b = pcall(target.GetResizeBounds, target)
            if ok and a and a > 0 then minW = a end
            if ok and b and b > 0 then minH = b end
        end
        Select(h.el)
        self.resizing = true
        self:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / us, cy / us
            local w = math.max(minW, (cx - leftU) / k)
            local hh = math.max(minH, (topU - cy) / k)
            pcall(target.SetSize, target, w, hh)
            -- keep the top-left corner in place while the size changes
            target:ClearAllPoints()
            target:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            self.w, self.h = w, hh
        end)
        self.leftU, self.topU = leftU, topU
    end)
    grip:SetScript("OnMouseUp", function(self)
        if not self.resizing then return end
        self.resizing = false
        self:SetScript("OnUpdate", nil)
        local target = h.target
        if target and self.w and h.el.saveSize then
            h.el.saveSize(target, self.w, self.h, self.leftU, self.topU)
        end
        self.w, self.h = nil, nil
    end)
    h.grip = grip
    return h
end

-- Every other Blizzard Edit Mode frame (Cooldown Manager, buffs/debuffs,
-- objective tracker, micro menu, bags, extra button, ...): moved like the
-- action bars, written into the H3z0 PC / H3z0 Deck Edit Mode layout
local SKIP_SYSTEMS = {}
do
    local S = Enum and Enum.EditModeSystem or {}
    -- action bars have their own entries; unit frames, cast bar and minimap are H3z0 UI's own
    for _, k in ipairs({ "ActionBar", "UnitFrame", "CastBar", "Minimap" }) do
        if S[k] then SKIP_SYSTEMS[S[k]] = true end
    end
end

local blizzElements
local function BlizzardSystemElements()
    if blizzElements then return blizzElements end
    local list = {}
    local mgr = _G.EditModeManagerFrame
    local frames = mgr and mgr.registeredSystemFrames
    if type(frames) ~= "table" or not AB_SYSTEM then return list end
    local seen = {}
    for _, f in ipairs(frames) do
        local sys, idx = f and f.system, f and f.systemIndex
        if sys and not SKIP_SYSTEMS[sys] then
            local key = "bz_" .. tostring(sys) .. "_" .. tostring(idx)
            if not seen[key] then
                seen[key] = true
                local name = f.systemNameString
                if not name and f.GetSystemName then
                    local ok, n = pcall(f.GetSystemName, f)
                    if ok then name = n end
                end
                name = name or (f.GetName and f:GetName()) or "Blizzard Frame"
                local CDM = Enum and Enum.EditModeSystem and Enum.EditModeSystem.CooldownViewer
                local S = Enum and Enum.EditModeSystem or {}
                local lname = tostring(name):lower()
                -- chat window and damage meter can be resized from Layout Mode
                local resizable = (S.ChatFrame ~= nil and sys == S.ChatFrame)
                    or (S.DamageMeter ~= nil and sys == S.DamageMeter)
                    or lname:find("chat", 1, true) ~= nil
                    or lname:find("damage", 1, true) ~= nil
                -- Extra Action / Zone Ability: the container is hidden and empty unless a
                    -- button is active, so it gets a placeholder handle to move it anyway
                local isExtra = (S.ExtraAbilities ~= nil and sys == S.ExtraAbilities)
                    or lname:find("extra", 1, true) ~= nil
                list[#list + 1] = {
                    placeholderSize = isExtra and 64 or nil,
                    resizable = resizable,
                    saveSize = function(frame, w, h, left, top)
                        if ns.BlizzPositions and ns.BlizzPositions.SaveSize then
                            ns.BlizzPositions.SaveSize(frame, w, h, left, top)
                        end
                    end,
                    key = key, label = tostring(name), group = "blizzard", ghost = true,
                    -- Cooldown Manager gets a handle even while it's hidden out of combat
                    showHidden = (CDM ~= nil and sys == CDM) or isExtra,
                    cdmIndex = (CDM ~= nil and sys == CDM) and idx or nil,
                    sys = sys,
                    frame = function() return f end,
                    saveOffset = function(frame, dx, dy)
                        if ns.BlizzPositions then ns.BlizzPositions.Save(frame, dx, dy) end
                    end,
                }
            end
        end
    end
    blizzElements = list
    return list
end

local function RefreshHandles()
    for _, h in pairs(LM.handles) do h.seen = false end
    local all = {}
    for _, el in ipairs(elements) do all[#all + 1] = el end
    for _, el in ipairs(PanelElements()) do all[#all + 1] = el end
    for _, el in ipairs(BlizzardSystemElements()) do all[#all + 1] = el end

    for _, el in ipairs(all) do
        local ok, target = pcall(el.frame)
        target = ok and target or nil
        local h = LM.handles[el.key]
        local tooSmall = target and ((target:GetWidth() or 0) <= 1 or not target:IsShown())
        local usePlaceholder = target and el.placeholderSize and tooSmall
        if target and target.IsShown and (target:IsShown() or el.showHidden) and ((target:GetWidth() or 0) > 1 or usePlaceholder) and target:GetCenter() then
            if not h then
                h = CreateHandle(el)
                LM.handles[el.key] = h
            end
            h.el = el
            if h.target ~= target or h.placeholder ~= (usePlaceholder and true or false) then
                h:SetMovable(false)
                h:ClearAllPoints()
                if usePlaceholder then
                    h:SetSize(el.placeholderSize, el.placeholderSize)
                    h:SetPoint("CENTER", target, "CENTER", 0, 0)
                else
                    h:SetPoint("TOPLEFT", target, "TOPLEFT", -1, 1)
                    h:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 1, -1)
                end
                h.target = target
                h.placeholder = usePlaceholder and true or false
            end
            local lockText = el.locked and el.locked() or nil
            if h.grip then
                if el.resizable and not lockText then h.grip:Show() else h.grip:Hide() end
            end
            h.isLocked = lockText ~= nil
            h.lockText = lockText
            local hiddenSt = Profile() and Profile().layoutHidden
            local off = hiddenSt and hiddenSt[el.key]
            h.label:SetText(el.label .. (h.isLocked and "  (locked)" or "") .. (off and "  (off)" or ""))
            local state = (LM.selected == el) and "selected" or ((h:IsShown() and h:IsMouseOver()) and "hover" or "normal")
            StyleHandle(h, state)
            h:Show()
            h.seen = true
        elseif h then
            h:Hide()
        end
    end
    for key, h in pairs(LM.handles) do
        if not h.seen then
            h:Hide()
            if LM.selected and LM.selected.key == key then LM.selected = nil end
        end
    end
    UpdateReadout()
end

---------------------------------------------------------------------------
-- 0.24.6: on / off for every element, and a settings panel for the selected one.
-- Everything is controlled from here; Blizzard's Edit Mode never has to be opened.
---------------------------------------------------------------------------
-- Blizzard frames (buffs, objective tracker, ...) are switched off by H3z0 UI (fully see-through,
-- no mouse) and stay off after a reload
local function HiddenStore()
    local p = Profile()
    if not p then return nil end
    p.layoutHidden = p.layoutHidden or {}
    return p.layoutHidden
end

local function ApplyBlizzHidden(frame, hidden)
    if not frame then return end
    frame.h3zLMHidden = hidden and true or nil
    if not frame.h3zLMHook then
        frame.h3zLMHook = true
        hooksecurefunc(frame, "SetAlpha", function(self, a)
            if self.h3zLMHidden and not self.h3zLMSetting and (a or 0) > 0 then
                self.h3zLMSetting = true
                self:SetAlpha(0)
                self.h3zLMSetting = nil
            end
        end)
        frame:HookScript("OnShow", function(self) if self.h3zLMHidden then self:SetAlpha(0) end end)
    end
    frame.h3zLMSetting = true
    pcall(frame.SetAlpha, frame, hidden and 0 or 1)
    frame.h3zLMSetting = nil
    if not InCombatLockdown() and frame.EnableMouse and not (frame.IsProtected and frame:IsProtected()) then
        pcall(frame.EnableMouse, frame, not hidden)
    end
end

local function Refresh(name) local fn = _G[name]; if fn then pcall(fn) end end

local function ModuleToggle(path, refresh, reloadNote)
    return {
        get = function()
            local t = Profile()
            for i = 1, #path - 1 do t = t and t[path[i]] end
            return t and t[path[#path]] ~= false and t[path[#path]] ~= nil
        end,
        set = function(on)
            local t = Profile()
            for i = 1, #path - 1 do t = t and t[path[i]] end
            if not t then return end
            t[path[#path]] = on and true or false
            if type(refresh) == "function" then pcall(refresh) elseif refresh then Refresh(refresh) end
            if reloadNote then Say(reloadNote) end
        end,
    }
end

local function ToggleFor(el)
    local key = el.key
    local ABL = ns.ActionBarLayout
    local bk = AB_PICK[key]
    if bk then
        if not (ABL and ABL.CanToggle(bk)) then return nil end
        return {
            get = function() return ABL.IsShown(bk) end,
            set = function(on)
                local ok, why = ABL.SetShown(bk, on)
                if not ok and why then Say(why) end
            end,
        }
    end
    if key == "party" then return ModuleToggle({ "partyFrames", "enabled" }, "H3z0UI_RefreshPartyFrames") end
    if key == "raid" then
        return ModuleToggle({ "raidFrames", "enabled" }, function()
            Refresh("H3z0UI_RefreshRaidFrames"); Refresh("H3z0UI_RefreshPartyFrames")
        end)
    end
    if key == "powerbar" then
        return ModuleToggle({ "powerBar", "enabled" }, function()
            local core = Core(); if core and core.UpdatePowerBar then pcall(core.UpdatePowerBar, core) end
        end)
    end
    if key == "secondarypowerbar" then
        return ModuleToggle({ "secondaryPowerBar", "enabled" }, function()
            local core = Core(); if core and core.UpdateSecondaryPowerBar then pcall(core.UpdateSecondaryPowerBar, core) end
        end)
    end
    if key == "totems" then return ModuleToggle({ "totemBar", "enabled" }, "H3z0UI_RefreshTotemBar") end
    if key == "combattimer" then return ModuleToggle({ "combatTimer", "enabled" }, "H3z0UI_RefreshCombatTimer") end
    if key == "mplus" then return ModuleToggle({ "mplusTimer", "enabled" }, nil, "M+ Timer: /reload to finish.") end
    -- unit frames and cast bars replace Blizzard's frames, which are switched off once at login:
    -- switching them reloads right away so there are never two (or none)
    local function ReloadNow()
        local ui = _G.H3z0UI
        C_Timer.After(0.1, function()
            if ui and ui.SafeReload then ui:SafeReload() else ReloadUI() end
        end)
    end
    local unit = key:match("^uf_(.+)$")
    if unit then
        return ModuleToggle({ "h3z0uiUnitFrames", unit, "enabled" }, ReloadNow)
    end
    unit = key:match("^cb_(.+)$")
    if unit then
        return ModuleToggle({ "h3z0uiUnitFrames", unit, "castbar", "enabled" }, ReloadNow)
    end
    if key:match("^bz_") then
        return {
            get = function() local st = HiddenStore(); return not (st and st[key]) end,
            set = function(on)
                local st = HiddenStore(); if not st then return end
                st[key] = (not on) or nil
                local ok, f = pcall(el.frame)
                if ok and f then ApplyBlizzHidden(f, not on) end
            end,
        }
    end
    return nil
end
LM.ToggleFor = ToggleFor

local function AllElements()
    local all = {}
    for _, el in ipairs(elements) do all[#all + 1] = el end
    for _, el in ipairs(PanelElements()) do all[#all + 1] = el end
    for _, el in ipairs(BlizzardSystemElements()) do all[#all + 1] = el end
    return all
end

-- Blizzard frames switched off earlier stay off after a reload
local function ApplyAllBlizzHidden()
    local st = HiddenStore()
    if not st or not next(st) then return end
    for _, el in ipairs(BlizzardSystemElements()) do
        if st[el.key] then
            local ok, f = pcall(el.frame)
            if ok and f then ApplyBlizzHidden(f, true) end
        end
    end
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function() C_Timer.After(2.5, ApplyAllBlizzHidden) end)
end

---------------------------------------------------------------------------
-- Panels (built with the options window's widgets)
---------------------------------------------------------------------------
local function GUIRef() return _G.H3z0UI and _G.H3z0UI.GUI end

local function PanelFrame(name, w)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, 200)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.04, 0.06, 0.09, 0.96)
    local r, g, b = Accent()
    f:SetBackdropBorderColor(r, g, b, 0.9)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetPoint("RIGHT", f, "RIGHT", -34, 0)
    f.title:SetJustifyH("LEFT")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide(); if f.onClose then f.onClose() end end)
    f:Hide()
    return f
end

-- a fresh content frame each time (old widgets are dropped)
local function NewBody(f)
    if f.body then f.body:Hide(); f.body:SetParent(nil) end
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", 10, -32)
    body:SetPoint("TOPRIGHT", -10, -32)
    body:SetHeight(10)
    f.body = body
    return body
end

local function Builder(body)
    local GUI = GUIRef()
    local b = { y = 0 }
    function b.Place(w, h)
        w:SetPoint("TOPLEFT", body, "TOPLEFT", 0, b.y)
        w:SetPoint("RIGHT", body, "RIGHT", 0, 0)
        b.y = b.y - (h or 30)
        return w
    end
    function b.Text(txt, h, color)
        local l = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", body, "TOPLEFT", 0, b.y)
        l:SetPoint("RIGHT", body, "RIGHT", 0, 0)
        l:SetJustifyH("LEFT")
        l:SetText(txt)
        if color then l:SetTextColor(color[1], color[2], color[3], 1) end
        b.y = b.y - (h or 18)
        return l
    end
    function b.Button(txt, w, onClick)
        local btn = GUI:CreateButton(body, txt, w or 140, 22, onClick)
        btn:SetPoint("TOPLEFT", body, "TOPLEFT", 0, b.y)
        b.y = b.y - 28
        return btn
    end
    return b, GUI
end

---------------------------------------------------------------------------
-- Inspector: the selected element
---------------------------------------------------------------------------
local inspector
local function UpdateInspector(el)
    if not LM.active then return end
    local GUI = GUIRef()
    if not GUI then return end
    if not inspector then
        inspector = PanelFrame("H3z0UI_LayoutModeInspector", 330)
        inspector:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -120)
    end
    if not el then inspector:Hide() return end
    inspector.title:SetText(el.label)
    local body = NewBody(inspector)
    local b = Builder(body)
    local oldSuppress = GUI._suppressSearchRegistration
    GUI._suppressSearchRegistration = true      -- these widgets must not go into the options search

    local tg = ToggleFor(el)
    if tg then
        local state = { on = tg.get() and true or false }
        b.Place(GUI:CreateFormCheckbox(body, "Shown", "on", state, function(v)
            if InCombatLockdown() then return end
            tg.set(v and true or false)
            C_Timer.After(0.3, function() if LM.active then RefreshHandles() end end)
        end))
    end

    -- action bars: the same settings as Blizzard's Edit Mode, kept by H3z0 UI
    local ABL = ns.ActionBarLayout
    local bk = AB_PICK[el.key]
    if ABL and bk then
        local frame = ABL.Frame(bk)
        local SLIDER = Enum.EditModeSettingDisplayType and Enum.EditModeSettingDisplayType.Slider
        local DROP = Enum.EditModeSettingDisplayType and Enum.EditModeSettingDisplayType.Dropdown
        local CHECK = Enum.EditModeSettingDisplayType and Enum.EditModeSettingDisplayType.Checkbox
        local proxy = {}
        for _, st in ipairs(ABL.SETTINGS) do
            if ABL.Has(bk, st.setting) then
                local dinfo = ABL.DisplayInfo(frame, st.setting)
                local val = ABL.Get(bk, st.setting)
                local function Changed(v)
                    local ok, why = ABL.Set(bk, st.setting, v)
                    if not ok and why then Say(why) end
                    C_Timer.After(0.5, function() if LM.active then RefreshHandles() end end)
                end
                local kind = dinfo and dinfo.type
                if kind == CHECK then
                    proxy[st.key] = (val == 1 or val == true)
                    b.Place(GUI:CreateFormCheckbox(body, st.label, st.key, proxy, function(v) Changed(v and 1 or 0) end))
                elseif kind == DROP and type(dinfo.options) == "table" then
                    local opts = {}
                    for _, o in ipairs(dinfo.options) do opts[#opts + 1] = { value = o.value, text = o.text or tostring(o.value) } end
                    proxy[st.key] = val
                    b.Place(GUI:CreateFormDropdown(body, st.label, opts, st.key, proxy, Changed))
                elseif kind == SLIDER and dinfo.minValue and dinfo.maxValue then
                    proxy[st.key] = tonumber(val) or dinfo.minValue
                    b.Place(GUI:CreateFormSlider(body, st.label, dinfo.minValue, dinfo.maxValue, dinfo.stepSize or 1, st.key, proxy, Changed))
                end
            end
        end
    end

    b.y = b.y - 4
    if SettingsFor(el) then
        b.Button("All Settings", 140, function() OpenSettings(el) end)
    end
    b.Text("Drag the frame to move it. Arrow keys nudge 1px, Shift+arrow 10px.", 30, { 0.7, 0.75, 0.8 })

    GUI._suppressSearchRegistration = oldSuppress
    body:SetHeight(-b.y)
    inspector:SetHeight(-b.y + 46)
    inspector:Show()
end
LM.UpdateInspector = UpdateInspector

---------------------------------------------------------------------------
-- Show / Hide list: every element with an on / off switch (also the ones switched off)
---------------------------------------------------------------------------
local listPanel
local function UpdateList()
    local GUI = GUIRef()
    if not GUI then return end
    if not listPanel then
        listPanel = PanelFrame("H3z0UI_LayoutModeList", 300)
        listPanel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -120)
        listPanel.title:SetText("Show / Hide")
        listPanel.scroll = CreateFrame("ScrollFrame", nil, listPanel, "UIPanelScrollFrameTemplate")
        listPanel.scroll:SetPoint("TOPLEFT", 8, -30)
        listPanel.scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    end
    listPanel:SetHeight(math.min(560, (UIParent:GetHeight() or 800) - 200))
    local content = CreateFrame("Frame", nil, listPanel.scroll)
    content:SetWidth(258)
    if listPanel.content then listPanel.content:Hide(); listPanel.content:SetParent(nil) end
    listPanel.content = content
    listPanel.scroll:SetScrollChild(content)
    local b = Builder(content)
    local oldSuppress = GUI._suppressSearchRegistration
    GUI._suppressSearchRegistration = true
    local seen = {}
    local groupsOrder = {
        { "unitframes", "Unit Frames" }, { "party", "Party" }, { "raid", "Raid" }, { "actionbars", "Action Bars" },
        { "powerbars", "Power Bars" }, { "totems", "Totem Bar" }, { "combattimer", "Timers" }, { "mplus", "Timers" },
        { "blizzard", "Blizzard Frames" },
    }
    for _, gi in ipairs(groupsOrder) do
        local header = false
        for _, el in ipairs(AllElements()) do
            if el.group == gi[1] and not seen[el.key] then
                local tg = ToggleFor(el)
                if tg then
                    seen[el.key] = true
                    if not header then
                        header = true
                        b.y = b.y - 4
                        local r, g, bb = Accent()
                        b.Text(gi[2], 18, { r, g, bb })
                    end
                    local state = { on = tg.get() and true or false }
                    b.Place(GUI:CreateFormCheckbox(content, el.label, "on", state, function(v)
                        if InCombatLockdown() then return end
                        tg.set(v and true or false)
                        C_Timer.After(0.3, function() if LM.active then RefreshHandles() end end)
                    end), 28)
                end
            end
        end
    end
    GUI._suppressSearchRegistration = oldSuppress
    content:SetHeight(-b.y + 10)
    listPanel:Show()
end
LM.UpdateList = UpdateList
LM.HidePanels = function()
    if inspector then inspector:Hide() end
    if listPanel then listPanel:Hide() end
end

---------------------------------------------------------------------------
-- Grid, toolbar, keyboard
---------------------------------------------------------------------------
local function BuildGrid()
    if LM.grid then return LM.grid end
    local grid = CreateFrame("Frame", nil, UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("BACKGROUND")
    grid:EnableMouse(false)
    grid.lines = {}
    local dim = grid:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.25)
    grid.dim = dim
    grid:SetScript("OnShow", function(self)
        for _, t in ipairs(self.lines) do t:Hide() end
        local w, hgt = UIParent:GetWidth(), UIParent:GetHeight()
        local r, g, b = Accent()
        local step = LM.GRID * 4
        local i = 0
        local function Line(isV, offset, center)
            i = i + 1
            local t = self.lines[i] or self:CreateTexture(nil, "BORDER")
            self.lines[i] = t
            t:ClearAllPoints()
            if isV then
                t:SetPoint("TOP", self, "TOP", offset, 0)
                t:SetPoint("BOTTOM", self, "BOTTOM", offset, 0)
                t:SetWidth(1)
            else
                t:SetPoint("LEFT", self, "LEFT", 0, offset)
                t:SetPoint("RIGHT", self, "RIGHT", 0, offset)
                t:SetHeight(1)
            end
            if center then t:SetColorTexture(r, g, b, 0.6) else t:SetColorTexture(1, 1, 1, 0.07) end
            t:Show()
        end
        Line(true, 0, true)
        Line(false, 0, true)
        for x = step, w / 2, step do Line(true, x); Line(true, -x) end
        for y = step, hgt / 2, step do Line(false, y); Line(false, -y) end
    end)
    grid:Hide()
    LM.grid = grid
    return grid
end

local function ToolbarButton(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(22)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetWidth(math.max(70, (b.text:GetStringWidth() or 40) + 20))
    local function Idle()
        local r, g, bb = Accent()
        b:SetBackdropColor(r, g, bb, b.on and 0.35 or 0.10)
        b:SetBackdropBorderColor(r, g, bb, 0.8)
    end
    b.Idle = Idle
    Idle()
    b:SetScript("OnEnter", function(self) local r, g, bb = Accent(); self:SetBackdropColor(r, g, bb, 0.45) end)
    b:SetScript("OnLeave", Idle)
    b:SetScript("OnClick", onClick)
    return b
end

local function BuildToolbar()
    if LM.toolbar then return LM.toolbar end
    local bar = CreateFrame("Frame", "H3z0UI_LayoutModeToolbar", UIParent, "BackdropTemplate")
    bar:SetSize(680, 74)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -24)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    bar:SetBackdropColor(0.04, 0.06, 0.09, 0.95)
    local r, g, b = Accent()
    bar:SetBackdropBorderColor(r, g, b, 0.9)
    bar:EnableMouse(true)
    bar:SetMovable(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    bar:SetScript("OnDragStop", bar.StopMovingOrSizing)

    local logo = bar:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\icon")
    logo:SetSize(30, 30)
    logo:SetPoint("TOPLEFT", 10, -8)

    bar.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    bar.title:SetText("|cff34D399H3z0 UI|r  Layout Mode")

    bar.readout = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.readout:SetPoint("BOTTOMLEFT", 12, 10)
    bar.readout:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
    bar.readout:SetJustifyH("LEFT")

    local done = ToolbarButton(bar, "Done", function() LM:Exit() end)
    done:SetPoint("TOPRIGHT", -10, -10)

    local snap = ToolbarButton(bar, "Snap", nil)
    snap:SetScript("OnClick", function(self)
        LM.snap = not LM.snap
        self.on = LM.snap
        self.Idle()
    end)
    snap:SetPoint("RIGHT", done, "LEFT", -6, 0)

    local grid = ToolbarButton(bar, "Grid", nil)
    grid.on = LM.showGrid
    grid.Idle()
    grid:SetScript("OnClick", function(self)
        LM.showGrid = not LM.showGrid
        self.on = LM.showGrid
        self.Idle()
        if LM.showGrid then BuildGrid():Show() else BuildGrid():Hide() end
    end)
    grid:SetPoint("RIGHT", snap, "LEFT", -6, 0)

    -- Share the layout (PC + Deck) as a text code
    local import = ToolbarButton(bar, "Import", function()
        if _G.H3z0UI_ImportLayout then _G.H3z0UI_ImportLayout() end
    end)
    import:SetPoint("RIGHT", grid, "LEFT", -12, 0)
    local showHide = ToolbarButton(bar, "Show / Hide", function()
        if LM.listShown then
            LM.listShown = false
            if LM.HidePanels then LM.HidePanels() end
            if LM.selected and LM.UpdateInspector then LM.UpdateInspector(LM.selected) end
        else
            LM.listShown = true
            if LM.UpdateList then LM.UpdateList() end
        end
    end)
    showHide:SetPoint("TOPLEFT", bar.title, "TOPRIGHT", 14, 3)
    local export = ToolbarButton(bar, "Export", function()
        if _G.H3z0UI_ExportLayout then _G.H3z0UI_ExportLayout() end
    end)
    export:SetPoint("RIGHT", import, "LEFT", -6, 0)

    bar:Hide()
    LM.toolbar = bar
    return bar
end

local function Nudge(dx, dy)
    local el = LM.selected
    local h = el and LM.handles[el.key]
    if not h or h.isLocked or not h.target or InCombatLockdown() then return end
    local cx, cy = CenterOffset(h.target)
    if not cx then return end
    if el.ghost then
        if el.saveOffset then el.saveOffset(h.target, cx + dx, cy + dy) end
        return
    end
    MoveTo(h.target, cx + dx, cy + dy)
    SaveElement(el, h.target)
end

local function BuildKeyCatcher()
    if LM.keys then return LM.keys end
    local k = CreateFrame("Frame", nil, UIParent)
    k:SetPropagateKeyboardInput(true)
    k:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        local step = IsShiftKeyDown() and 10 or 1
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            -- Esc closes the options window first (opened with right-click), then Layout Mode
            local share = _G.H3z0UI_LayoutShareFrame
            if share and share:IsShown() then share:Hide() return end
            local open, GUI = OptionsOpen()
            if open and GUI.Hide then
                pcall(GUI.Hide, GUI)
                return
            end
            LM:Exit()
            return
        elseif key == "LEFT" and LM.selected then self:SetPropagateKeyboardInput(false); Nudge(-step, 0); return
        elseif key == "RIGHT" and LM.selected then self:SetPropagateKeyboardInput(false); Nudge(step, 0); return
        elseif key == "UP" and LM.selected then self:SetPropagateKeyboardInput(false); Nudge(0, step); return
        elseif key == "DOWN" and LM.selected then self:SetPropagateKeyboardInput(false); Nudge(0, -step); return
        end
        self:SetPropagateKeyboardInput(true)
    end)
    k:Hide()
    LM.keys = k
    return k
end

---------------------------------------------------------------------------
-- Enter / exit
---------------------------------------------------------------------------
function LM:Enter()
    if self.active then return end
    if InCombatLockdown() then
        Say("Layout Mode can't be opened in combat.")
        return
    end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        HideUIPanel(EditModeManagerFrame)
    end
    if _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Hide then
        pcall(_G.H3z0UI.GUI.Hide, _G.H3z0UI.GUI)
    end
    local LSets = ns.LayoutSets
    if LSets then
        Say("Editing the |cffFFFF00" .. (LSets.CurrentMode() == "deck" and "Deck" or "PC") .. "|r layout. Click a frame for its settings, Show / Hide switches frames on and off. Everything is kept by H3z0 UI.")
    end

    self.active = true
    wipe(self.started)

    for _, g in pairs(groups) do
        if g.enter then pcall(g.enter) end
    end
    if ns.ActionBarLayout and ns.ActionBarLayout.ApplyStored then pcall(ns.ActionBarLayout.ApplyStored) end

    if self.showGrid then BuildGrid():Show() end
    BuildToolbar():Show()
    local keys = BuildKeyCatcher()
    keys:Show()
    keys:EnableKeyboard(true)

    -- previews appear over a few frames; keep the handles in sync while active
    RefreshHandles()
    self.ticker = C_Timer.NewTicker(0.25, function()
        if self.active and not self.dragging then RefreshHandles() end
    end)
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 850)
end

function LM:Exit()
    -- older builds raised the options window's layer: put it back if needed
    do
        local GUI = _G.H3z0UI and _G.H3z0UI.GUI
        local mf = GUI and GUI.MainFrame
        if mf and mf:GetFrameStrata() ~= "DIALOG" then mf:SetFrameStrata("DIALOG") end
    end
    if not self.active then return end
    self.active = false
    if self.dragging then
        pcall(self.dragging.StopMovingOrSizing, self.dragging)
        self.dragging = nil
    end
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    for _, h in pairs(self.handles) do h:Hide() end
    self.selected = nil
    if self.grid then self.grid:Hide() end
    if self.toolbar then self.toolbar:Hide() end
    self.listShown = false
    if self.HidePanels then self.HidePanels() end
    if self.keys then self.keys:EnableKeyboard(false); self.keys:Hide() end

    for _, g in pairs(groups) do
        if g.exit then pcall(g.exit) end
    end
    wipe(self.started)
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE or 851)
end

function LM:Toggle()
    if self.active then self:Exit() else self:Enter() end
end

_G.H3z0UI_ToggleLayoutMode = function() LM:Toggle() end

-- Blizzard's own editor, only on request (/h3z0ui blizzedit): for Blizzard-only
-- settings like action bar rows / icon size or Cooldown Manager size
_G.H3z0UI_OpenBlizzardEditMode = function()
    if InCombatLockdown() then Say("Not in combat.") return end
    if LM.active then LM:Exit() end
    if EditModeManagerFrame then ShowUIPanel(EditModeManagerFrame) end
end
_G.H3z0UI_IsLayoutModeActive = function() return LM.active end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function()
    if LM.active then
        LM:Exit()
        Say("Layout Mode closed because you entered combat.")
    end
end)
