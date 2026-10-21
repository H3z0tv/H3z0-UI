--[[
    H3z0 UI - Blizzard frame positions (stored in H3z0 UI, not in Edit Mode)

    Layout Mode saves where you put Blizzard's frames (action bars, Cooldown
    Manager, buffs, objective tracker, ...) in the H3z0 UI profile, one set for
    PC and one for Deck:  profile.blizzPositions.pc / .deck  [key] = { x, y }

    Blizzard's own Edit Mode layouts are never created, changed or switched.
    H3z0 UI puts the frames in place itself (out of combat) after login, after
    Edit Mode re-applies its layout, and after combat if something was pending.

    key = "<EditModeSystem>_<systemIndex>", x / y = centre offset from the
    screen centre in UI units.
]]

local ADDON_NAME, ns = ...

local BP = {}
ns.BlizzPositions = BP

local function Profile()
    local core = ns.Addon
    return core and core.db and core.db.profile
end

local function Mode()
    local LS = ns.LayoutSets
    return LS and LS.CurrentMode() or "pc"
end

function BP.Key(system, index)
    return tostring(system) .. "_" .. tostring(index or 0)
end

local function Store(mode)
    local p = Profile()
    if not p then return nil end
    p.blizzPositions = p.blizzPositions or {}
    p.blizzPositions[mode] = p.blizzPositions[mode] or {}
    return p.blizzPositions[mode]
end

-- Sizes (chat window, damage meter, ...): profile.blizzSizes[mode][key] = { w, h }
local function SizeStore(mode)
    local p = Profile()
    if not p then return nil end
    p.blizzSizes = p.blizzSizes or {}
    p.blizzSizes[mode] = p.blizzSizes[mode] or {}
    return p.blizzSizes[mode]
end

-- Which Edit Mode systems H3z0 UI places itself (the others are moved by
-- the frame anchoring of Layout Mode): action bars, chat, damage meter.
local function ManagedSystems()
    local S = Enum and Enum.EditModeSystem
    local set = {}
    if S then
        for _, name in ipairs({ "ChatFrame", "DamageMeter", "CooldownViewer" }) do
            if S[name] ~= nil then set[S[name]] = true end
        end
    end
    return set
end
BP.ManagedSystems = ManagedSystems

function BP.IsManaged(f)
    return f and f.system ~= nil and ManagedSystems()[f.system] == true
end

-- All managed Blizzard Edit Mode frames by key
local function SystemFrames()
    local list = {}
    local mgr = _G.EditModeManagerFrame
    local frames = mgr and mgr.registeredSystemFrames
    if type(frames) ~= "table" then return list end
    local managed = ManagedSystems()
    for _, f in ipairs(frames) do
        if f and f.system and managed[f.system] then list[BP.Key(f.system, f.systemIndex)] = f end
    end
    return list
end
BP.SystemFrames = SystemFrames

---------------------------------------------------------------------------
-- Place one frame (offsets in UI units, converted to the frame's own scale)
---------------------------------------------------------------------------
local applying = false
local pending = false

local function Place(f, pos)
    if not (f and pos and pos.x and pos.y) then return end
    if InCombatLockdown() and f.IsProtected and f:IsProtected() then
        pending = true
        return
    end
    local fs, us = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not (fs and us and fs > 0) then return end
    local k = us / fs
    applying = true
    pcall(function()
        -- Edit Mode frames: the plain SetPoint (Blizzard's own SetPoint also
        -- marks the layout as changed / snapped)
        local clear = f.ClearAllPointsBase or f.ClearAllPoints
        local set = f.SetPointBase or f.SetPoint
        clear(f)
        set(f, "CENTER", UIParent, "CENTER", pos.x * k, pos.y * k)
    end)
    applying = false
end

local function PlaceSize(f, sz)
    if not (f and sz and sz.w and sz.h) then return end
    if InCombatLockdown() and f.IsProtected and f:IsProtected() then
        pending = true
        return
    end
    applying = true
    pcall(f.SetSize, f, sz.w, sz.h)
    applying = false
end

local hooked = {}
local function HookFrame(f)
    if hooked[f] or not f.ApplySystemAnchor or not BP.IsManaged(f) then return end
    hooked[f] = true
    -- Edit Mode re-anchors its frames now and then: put ours back right after
    hooksecurefunc(f, "ApplySystemAnchor", function(self)
        if applying then return end
        local key = BP.Key(self.system, self.systemIndex)
        local sz = SizeStore(Mode())
        if sz and sz[key] then PlaceSize(self, sz[key]) end
        local s = Store(Mode())
        local pos = s and s[key]
        if pos then Place(self, pos) end
    end)
    -- and when it re-applies its own size settings
    if f.UpdateSystem then
        hooksecurefunc(f, "UpdateSystem", function(self)
            if applying then return end
            local sz = SizeStore(Mode())
            local v = sz and sz[BP.Key(self.system, self.systemIndex)]
            if v then PlaceSize(self, v) end
        end)
    end
end

function BP.ApplyAll()
    local s = Store(Mode())
    if not s then return end
    local frames = SystemFrames()
    local sizes = SizeStore(Mode()) or {}
    for key, sz in pairs(sizes) do
        local f = frames[key]
        if f then
            HookFrame(f)
            PlaceSize(f, sz)
        end
    end
    for key, pos in pairs(s) do
        local f = frames[key]
        if f then
            HookFrame(f)
            Place(f, pos)
        end
    end
end

---------------------------------------------------------------------------
-- Save (from Layout Mode): dx / dy = centre offset in UI units
---------------------------------------------------------------------------
function BP.Save(frame, dx, dy)
    if not (frame and frame.system and dx and dy) then return end
    local s = Store(Mode())
    if not s then return end
    s[BP.Key(frame.system, frame.systemIndex)] = {
        x = math.floor(dx + 0.5), y = math.floor(dy + 0.5),
    }
    HookFrame(frame)
    Place(frame, s[BP.Key(frame.system, frame.systemIndex)])
end

-- Save a size (from Layout Mode's resize grip). The frame keeps its top-left
-- corner where it is: the centre offset is saved again for the new size.
function BP.SaveSize(frame, w, h, left, top)
    if not (frame and frame.system and w and h) then return end
    local sz = SizeStore(Mode())
    if not sz then return end
    local key = BP.Key(frame.system, frame.systemIndex)
    sz[key] = { w = math.floor(w + 0.5), h = math.floor(h + 0.5) }
    HookFrame(frame)
    PlaceSize(frame, sz[key])
    if left and top then
        -- left / top in UIParent units -> centre offset in UIParent units
        local k = (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        local cx = left + (w * k) / 2
        local cy = top - (h * k) / 2
        local px, py = UIParent:GetCenter()
        if px and py then BP.Save(frame, cx - px, cy - py) end
    end
end

function BP.GetSizes()
    local p = Profile()
    return p and p.blizzSizes
end

function BP.SetSizes(t)
    local p = Profile()
    if p and type(t) == "table" then p.blizzSizes = t end
end

-- Forget a frame's saved position (back to Blizzard's own position after a reload)
function BP.Reset(frame)
    local s = Store(Mode())
    if s and frame and frame.system then s[BP.Key(frame.system, frame.systemIndex)] = nil end
    local sz = SizeStore(Mode())
    if sz and frame and frame.system then sz[BP.Key(frame.system, frame.systemIndex)] = nil end
end

-- For Export / Import
function BP.GetAll()
    local p = Profile()
    return p and p.blizzPositions
end

function BP.SetAll(t)
    local p = Profile()
    if p and type(t) == "table" then p.blizzPositions = t end
end

-- (Action bars are H3z0 UI's own bar frames now: Layout Mode moves them
-- directly. Positions saved here for Blizzard's bars were moved over once.)
---------------------------------------------------------------------------
-- Blizzard lines up the action bars that are still "in default position"
-- itself (UpdateBottomActionBarPositions / UpdateRightActionBarPositions) on
-- many occasions: combat, vehicles, XP bar, a bar shown or hidden, opening
-- Edit Mode, ... That never goes through ApplySystemAnchor, so the saved
-- places are put back after each of those too.
---------------------------------------------------------------------------
local queued = false
local function QueueApply()
    if applying or queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        if InCombatLockdown() then
            pending = true
            return
        end
        BP.ApplyAll()
    end)
end
BP.QueueApply = QueueApply

local managerHooked = false
local function HookManager()
    if managerHooked then return end
    local mgr = _G.EditModeManagerFrame
    if not mgr then return end
    managerHooked = true
    for _, method in ipairs({ "UpdateBottomActionBarPositions", "UpdateRightActionBarPositions", "UpdateActionBarPositions", "EnterEditMode", "ExitEditMode" }) do
        if type(mgr[method]) == "function" then
            hooksecurefunc(mgr, method, QueueApply)
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:SetScript("OnEvent", function(_, event)
    HookManager()
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then
            pending = false
            BP.ApplyAll()
        end
        return
    end
    -- give Edit Mode a moment to apply its own layout first
    C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 1 or 0.2, BP.ApplyAll)
end)
