local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Overrides: rules that switch modules on or off depending on your role and
-- where you are, and put them back when the rule stops matching.
--
-- A rule: { name, enabled, role = "any"|"TANK"|"HEALER"|"DAMAGER",
--           content = "any"|"world"|"dungeon"|"raid"|"pvp"|"scenario",
--           mods = { [moduleFeatureId] = true|false } }
-- Only the modules a rule lists are touched. Before a module is changed its
-- original state is written to a journal (saved in the profile, so it
-- survives /reload) and restored as soon as no rule wants it any more.
-- Rules never run in combat; they wait for it to end.
---------------------------------------------------------------------------

local O = {}
ns.H3z0UI_Overrides = O
_G.H3z0UI_Overrides = O

O.ROLES = { "any", "TANK", "HEALER", "DAMAGER" }
O.CONTENT = { "any", "world", "dungeon", "raid", "pvp", "scenario" }

local function Core()
    return ns.Addon or (ns.Helpers and ns.Helpers.GetCore and ns.Helpers.GetCore())
end

function O.Store(create)
    local core = Core()
    local p = core and core.db and core.db.profile
    if not p then return nil end
    if not p.h3zOverrides then
        if not create then return nil end
        p.h3zOverrides = { enabled = false, rules = {}, journal = {} }
    end
    local s = p.h3zOverrides
    s.rules = s.rules or {}
    s.journal = s.journal or {}
    return s
end

function O.CurrentRole()
    if GetSpecialization and GetSpecializationRole then
        local i = GetSpecialization()
        if i then return GetSpecializationRole(i) end
    end
    return nil
end

function O.CurrentContent()
    if not IsInInstance then return "world" end
    local inInstance, kind = IsInInstance()
    if not inInstance then return "world" end
    if kind == "party" then return "dungeon" end
    if kind == "raid" then return "raid" end
    if kind == "pvp" or kind == "arena" then return "pvp" end
    if kind == "scenario" then return "scenario" end
    return "world"
end

local function RuleMatches(rule, role, content)
    if rule.enabled == false then return false end
    if rule.role and rule.role ~= "any" and rule.role ~= role then return false end
    if rule.content and rule.content ~= "any" and rule.content ~= content then return false end
    return true
end

-- what the rules want right now: { [id] = true|false }, later rules win
function O.Desired(store)
    local role, content = O.CurrentRole(), O.CurrentContent()
    local want = {}
    if store and store.enabled then
        for _, rule in ipairs(store.rules) do
            if RuleMatches(rule, role, content) and type(rule.mods) == "table" then
                for id, v in pairs(rule.mods) do want[id] = v and true or false end
            end
        end
    end
    return want
end

local function Modules() return ns.H3z0UI_Modules end

local function Set(id, value)
    local M = Modules()
    if not M or not M.SetEnabled then return false end
    local ok, res = pcall(M.SetEnabled, M, id, value, { suppressReloadPrompt = true })
    return ok and res
end

function O.Evaluate()
    if InCombatLockdown() then O._pending = true return false end
    O._pending = nil
    local store = O.Store(false)
    if not store then return false end
    local hasJournal = next(store.journal) ~= nil
    if not hasJournal and not (store.enabled and #store.rules > 0) then return false end

    -- module entries come from the options code; load it only when it is needed
    local addon = _G.H3z0UI
    if not (ns.Settings and ns.Settings.Registry and ns.Settings.Registry._featuresById
        and next(ns.Settings.Registry._featuresById)) then
        if addon and addon.EnsureOptionsLoaded then pcall(addon.EnsureOptionsLoaded, addon) end
    end
    local M = Modules()
    if not M then return false end

    local want = O.Desired(store)
    local changed = false

    -- put back what no rule wants any more
    for id, original in pairs(store.journal) do
        if want[id] == nil then
            if M:GetEntry(id) then Set(id, original and true or false) end
            store.journal[id] = nil
            changed = true
        end
    end
    -- apply what the rules want
    for id, value in pairs(want) do
        if M:GetEntry(id) then
            if store.journal[id] == nil then
                store.journal[id] = M:IsEnabled(id) and true or false
            end
            if M:IsEnabled(id) ~= value then
                Set(id, value)
                changed = true
            end
        end
    end
    O._lastWant = want
    return changed
end

-- text for the page: what is overridden right now
function O.ActiveList()
    local store = O.Store(false)
    local list = {}
    if not store then return list end
    for id, original in pairs(store.journal) do
        list[#list + 1] = { id = id, original = original, now = O._lastWant and O._lastWant[id] }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local timer
function O.Request()
    if timer then return end
    timer = C_Timer.After(0.6, function()
        timer = nil
        O.Evaluate()
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(f.RegisterEvent, f, "PLAYER_SPECIALIZATION_CHANGED")
pcall(f.RegisterEvent, f, "ACTIVE_TALENT_GROUP_CHANGED")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not O._pending then return end
    O.Request()
end)
