--[[
    H3z0 UI - Layout Sets (PC / Deck)

    Every frame keeps one position for PC and one for Deck (Handheld Mode).

    H3z0 UI frames: their saved position values (the same values Layout Mode
    writes) are stored per mode in profile.layoutSets.pc / .deck and swapped
    when Handheld Mode turns on or off.

    Blizzard frames (action bars, Cooldown Manager, buffs, ...): Layout Mode
    writes their position into an Edit Mode layout that H3z0 UI manages:
    "H3z0 PC" and "H3z0 Deck". Handheld Mode switches between the two, so
    Blizzard's own Edit Mode never has to be opened.
]]

local ADDON_NAME, ns = ...

local LS = {}
ns.LayoutSets = LS

LS.PC_LAYOUT = "H3z0 PC"
LS.DECK_LAYOUT = "H3z0 Deck"

local NIL = "__h3z0nil"

local function Profile()
    local core = ns.Addon
    return core and core.db and core.db.profile
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

---------------------------------------------------------------------------
-- Which saved values are "positions" (everything Layout Mode can change)
---------------------------------------------------------------------------
local STATIC = {
    { "partyFrames", "pos" },
    { "raidControl", "tabPoint" }, { "raidControl", "tabRelPoint" }, { "raidControl", "tabX" }, { "raidControl", "tabY" },
    { "powerBar", "offsetX" }, { "powerBar", "offsetY" },
    { "secondaryPowerBar", "offsetX" }, { "secondaryPowerBar", "offsetY" },
    { "totemBar", "offsetX" }, { "totemBar", "offsetY" },
    { "combatTimer", "xOffset" }, { "combatTimer", "yOffset" },
    { "mplusTimer", "position" },
    { "minimap", "position" },
    { "minimap", "coordsConfig", "offsetX" }, { "minimap", "coordsConfig", "offsetY" },
    { "raidBuffs", "position" },
    { "skyriding", "offsetX" }, { "skyriding", "offsetY" },
    { "general", "consumableFreePosition" },
    { "actionBars", "bars", "extraActionButton", "position" },
    { "actionBars", "bars", "zoneAbility", "position" },
}

local function Paths()
    local list = {}
    for _, p in ipairs(STATIC) do list[#list + 1] = p end
    for _, unit in ipairs({ "player", "target", "focus", "pet", "targettarget", "boss" }) do
        list[#list + 1] = { "h3z0uiUnitFrames", unit, "offsetX" }
        list[#list + 1] = { "h3z0uiUnitFrames", unit, "offsetY" }
        list[#list + 1] = { "h3z0uiUnitFrames", unit, "castbar", "offsetX" }
        list[#list + 1] = { "h3z0uiUnitFrames", unit, "castbar", "offsetY" }
    end
    local p = Profile()
    local panels = p and p.h3z0uiDatatexts and p.h3z0uiDatatexts.panels
    if type(panels) == "table" then
        for i in pairs(panels) do
            list[#list + 1] = { "h3z0uiDatatexts", "panels", i, "position" }
        end
    end
    return list
end

local function Key(path)
    local parts = {}
    for i, v in ipairs(path) do parts[i] = tostring(v) end
    return table.concat(parts, ".")
end

-- parent table + last key, nil when a parent table doesn't exist
local function Resolve(root, path)
    local t = root
    for i = 1, #path - 1 do
        if type(t) ~= "table" then return nil end
        t = t[path[i]]
    end
    if type(t) ~= "table" then return nil end
    return t, path[#path]
end

function LS.Capture()
    local p = Profile()
    if not p then return nil end
    local snap = {}
    for _, path in ipairs(Paths()) do
        local parent, k = Resolve(p, path)
        if parent then
            local v = parent[k]
            snap[Key(path)] = { path = path, value = (v == nil) and NIL or DeepCopy(v) }
        end
    end
    return snap
end

function LS.Restore(snap)
    local p = Profile()
    if not (p and type(snap) == "table") then return end
    for _, entry in pairs(snap) do
        local parent, k = Resolve(p, entry.path)
        if parent then
            if entry.value == NIL then parent[k] = nil else parent[k] = DeepCopy(entry.value) end
        end
    end
end

function LS.Save(mode)
    local p = Profile()
    if not p then return end
    p.layoutSets = p.layoutSets or {}
    p.layoutSets[mode] = LS.Capture()
end

-- Load the saved positions of a mode (returns false when that mode has none yet)
function LS.Load(mode)
    local p = Profile()
    local snap = p and p.layoutSets and p.layoutSets[mode]
    if not snap then return false end
    LS.Restore(snap)
    return true
end

function LS.CurrentMode()
    local p = Profile()
    return (p and p.handheld and p.handheld.enabled) and "deck" or "pc"
end

---------------------------------------------------------------------------
-- Managed Edit Mode layouts ("H3z0 PC" / "H3z0 Deck")
---------------------------------------------------------------------------
local function Clean(s)
    s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:lower():gsub("[%s_%-%.]", "")
    return s
end
LS.Clean = Clean

function LS.NumPresetLayouts()
    local n = 0
    if Enum and Enum.EditModePresetLayouts then
        for _ in pairs(Enum.EditModePresetLayouts) do n = n + 1 end
    end
    return n > 0 and n or 2
end

function LS.GetLayouts()
    if not (C_EditMode and C_EditMode.GetLayouts) then return nil end
    local info = C_EditMode.GetLayouts()
    if type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
    return info
end

function LS.FindLayout(name, info)
    info = info or LS.GetLayouts()
    if not info then return nil end
    local want = Clean(name)
    for i, l in ipairs(info.layouts) do
        if Clean(l.layoutName) == want then return LS.NumPresetLayouts() + i end
    end
end

-- Index of the named layout; created as a copy of sourceIndex (default: the
-- active layout) when it doesn't exist yet. The new layout becomes active.
function LS.EnsureLayout(name, sourceIndex)
    if InCombatLockdown() then return nil end
    local info = LS.GetLayouts()
    if not info then return nil end
    local found = LS.FindLayout(name, info)
    if found then return found, false end

    local np = LS.NumPresetLayouts()
    local src = tonumber(sourceIndex) or tonumber(info.activeLayout) or 1
    local systems
    local custom = info.layouts[src - np]
    if src > np and type(custom) == "table" then
        systems = DeepCopy(custom.systems)
    else
        local mgr = _G.EditModePresetLayoutManager
        local ok, presets = pcall(function() return mgr and mgr:GetCopyOfPresetLayouts() end)
        local preset = ok and type(presets) == "table" and (presets[src] or presets[1])
        systems = preset and DeepCopy(preset.systems)
    end
    if type(systems) ~= "table" then return nil end

    local accountType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    table.insert(info.layouts, { layoutName = name, layoutType = accountType, systems = systems })
    local index = np + #info.layouts
    info.activeLayout = index
    local ok = pcall(C_EditMode.SaveLayouts, info)
    if not ok then return nil end
    return index, true
end

function LS.Activate(index)
    if index and C_EditMode and C_EditMode.SetActiveLayout and not InCombatLockdown() then
        pcall(C_EditMode.SetActiveLayout, index)
        return true
    end
end

-- Name of the managed layout for the current mode
function LS.ModeLayoutName(mode)
    return (mode or LS.CurrentMode()) == "deck" and LS.DECK_LAYOUT or LS.PC_LAYOUT
end
