-- Everything Formwise reads from the client about the player, in one place, so a moved or
-- changed API is a one-file fix.
-- Formwise 1.0.0 by kragtenb (MIT License, see LICENSE.txt), bundled into H3z0 UI.
-- Kept in a private namespace (ns.Formwise) so it cannot clash with H3z0 UI's own tables.
local _, host = ...
host.Formwise = host.Formwise or {}
local ns = host.Formwise

local Player = {}
ns.Player = Player

local POWER = Enum and Enum.PowerType or {}
Player.MANA = POWER.Mana or 0
Player.RAGE = POWER.Rage or 1
Player.ENERGY = POWER.Energy or 3

Player.CAT_FORM = 768
Player.BEAR_FORMS = { 9634, 5487 } -- Dire Bear Form first: its cost is the one that applies
Player.TRAVEL_FORM = 783
Player.MOONKIN_FORM = 24858
Player.SHIFTING_POWER = 1322605
-- Forever's Furor is one talent spell whose values scale with the talent's rank (client data,
-- build 1.60.1); Classic's per-rank spells don't exist.
Player.FUROR = 17056

local KIND_BY_POWER = { [Player.ENERGY] = "cat", [Player.RAGE] = "bear" }

local function isSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end
Player.IsSecret = isSecret

-- A plain number, or nil for a secret or missing value.
function Player.Plain(value)
    if isSecret(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

function Player.IsDruid()
    local _, class = UnitClass("player")
    return class == "DRUID"
end

-- "cat", "bear" or "caster", from the power the player's bar shows (readable in combat).
function Player.FormKind()
    local powerType = UnitPowerType("player")
    if isSecret(powerType) then
        return nil
    end
    return KIND_BY_POWER[powerType] or "caster"
end

-- The reads below return nil when the client won't say (a secret), so callers can keep what they
-- knew rather than take it as "no".
local function knows(spellID)
    if IsPlayerSpell == nil then
        return false
    end
    local known = IsPlayerSpell(spellID)
    if isSecret(known) then
        return nil
    end
    return known == true
end
Player.Knows = knows -- true, false, or nil while unreadable

function Player.KnowsCat()
    return knows(Player.CAT_FORM)
end

-- The ID of the Bear Form the player would shift into, false if none, nil if unreadable.
function Player.BearForm()
    for _, spellID in ipairs(Player.BEAR_FORMS) do
        local known = knows(spellID)
        if known == nil then
            return nil
        elseif known then
            return spellID
        end
    end
    return false
end

-- A trait API result as a plain table, or nil if the call fails or returns a secret.
local function readTrait(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok or isSecret(result) or type(result) ~= "table" then
        return nil
    end
    return result
end

-- Furor's rank from its talent node, read the way Forever's talent frame does (C_Traits): the
-- applied rank, including granted ranks (activeRank). 0 if no node holds Furor, nil if the
-- talents aren't loaded yet or any part of the tree can't be read.
function Player.DetectFurorRank()
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then
        return nil
    end
    local ok, activeConfig = pcall(C_ClassTalents.GetActiveConfigID)
    local configID = ok and Player.Plain(activeConfig)
    if configID and C_ClassTalents.IsConfigPopulated then
        local populated
        ok, populated = pcall(C_ClassTalents.IsConfigPopulated, configID)
        if not ok or populated ~= true then
            return nil
        end
    end
    local config = configID and readTrait(C_Traits.GetConfigInfo, configID)
    if not (config and type(config.treeIDs) == "table") then
        return nil
    end
    local unreadable = #config.treeIDs == 0
    for _, treeID in ipairs(config.treeIDs) do
        local nodeIDs = readTrait(C_Traits.GetTreeNodes, treeID)
        unreadable = unreadable or nodeIDs == nil
        for _, nodeID in ipairs(nodeIDs or {}) do
            local node = readTrait(C_Traits.GetNodeInfo, configID, nodeID)
            -- A node not loaded yet comes back as a placeholder with no entries.
            local entryIDs = node and type(node.entryIDs) == "table" and node.entryIDs or {}
            unreadable = unreadable or node == nil or #entryIDs == 0
            for _, entryID in ipairs(entryIDs) do
                local entry = readTrait(C_Traits.GetEntryInfo, configID, entryID)
                local definition = entry and readTrait(C_Traits.GetDefinitionInfo, entry.definitionID)
                local spellID = definition and Player.Plain(definition.spellID)
                unreadable = unreadable or spellID == nil
                if spellID == Player.FUROR then
                    return Player.Plain(node.activeRank) or Player.Plain(node.ranksPurchased)
                end
            end
        end
    end
    -- Not finding Furor only means "no Furor" if the whole tree could be read.
    if unreadable then
        return nil
    end
    return 0
end

-- Current power; a secret in combat. Only ever displayed, or stored, never computed with.
function Player.Power(powerType)
    return UnitPower("player", powerType)
end

-- Max power as the client reports it; may be a secret in combat. Only for display.
function Player.RawMaxPower(powerType)
    return UnitPowerMax("player", powerType)
end

-- Max power as a plain number for maths: the last readable value, since it can be secret in
-- combat; nil until one is seen.
local knownMax = {}
function Player.KnownMaxPower(powerType)
    local max = Player.Plain(UnitPowerMax("player", powerType))
    if max and max > 0 then
        knownMax[powerType] = max
    end
    return knownMax[powerType]
end

-- As KnownMaxPower, with 100 standing in until a max is seen (Energy and Rage max out there).
function Player.MaxPower(powerType)
    return Player.KnownMaxPower(powerType) or 100
end

-- Mana a spell costs, including talents such as Natural Shapeshifter; nil if unreadable.
function Player.ManaCost(spellID)
    if not (spellID and C_Spell and C_Spell.GetSpellPowerCost) then
        return nil
    end
    local costs = C_Spell.GetSpellPowerCost(spellID)
    if isSecret(costs) or type(costs) ~= "table" then
        return nil
    end
    for _, cost in ipairs(costs) do
        if Player.Plain(cost.type) == Player.MANA then
            return Player.Plain(cost.cost)
        end
    end
    return nil
end

-- Whether a spell costs Mana: true, false, or nil while its cost is unreadable.
function Player.CostsMana(spellID)
    if not (C_Spell and C_Spell.GetSpellPowerCost) then
        return nil
    end
    local costs = C_Spell.GetSpellPowerCost(spellID)
    if isSecret(costs) then
        return nil
    end
    for _, cost in ipairs(type(costs) == "table" and costs or {}) do
        local powerType, amount = Player.Plain(cost.type), Player.Plain(cost.cost)
        if powerType == nil or amount == nil then
            return nil
        elseif powerType == Player.MANA and amount > 0 then
            return true
        end
    end
    return false
end

return Player
