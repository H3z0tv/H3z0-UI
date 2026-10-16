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

-- All Blizzard Edit Mode frames by key
local function SystemFrames()
    local list = {}
    local mgr = _G.EditModeManagerFrame
    local frames = mgr and mgr.registeredSystemFrames
    if type(frames) ~= "table" then return list end
    for _, f in ipairs(frames) do
        if f and f.system then list[BP.Key(f.system, f.systemIndex)] = f end
    end
    return list
end

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
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", pos.x * k, pos.y * k)
    end)
    applying = false
end

local hooked = {}
local function HookFrame(f)
    if hooked[f] or not f.ApplySystemAnchor then return end
    hooked[f] = true
    -- Edit Mode re-anchors its frames now and then: put ours back right after
    hooksecurefunc(f, "ApplySystemAnchor", function(self)
        if applying then return end
        local s = Store(Mode())
        local pos = s and s[BP.Key(self.system, self.systemIndex)]
        if pos then Place(self, pos) end
    end)
end

function BP.ApplyAll()
    local s = Store(Mode())
    if not s then return end
    local frames = SystemFrames()
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

-- Forget a frame's saved position (back to Blizzard's own position after a reload)
function BP.Reset(frame)
    local s = Store(Mode())
    if s and frame and frame.system then s[BP.Key(frame.system, frame.systemIndex)] = nil end
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

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:SetScript("OnEvent", function(_, event)
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
