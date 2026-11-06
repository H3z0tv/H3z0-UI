local ADDON_NAME, ns = ...
local Bags = ns.Bags or {}; ns.Bags = Bags

local Search = {}
Bags.Search = Search

local function Fold(text)
    local helpers = ns.Helpers
    if helpers and helpers.FoldSearchUTF8 then return helpers.FoldSearchUTF8(text) end
    return (text or ""):lower()
end

local function triAnd(a, b)
    if a == false or b == false then return false end
    if a == nil or b == nil then return nil end
    return true
end
local function triOr(a, b)
    if a == true or b == true then return true end
    if a == nil or b == nil then return nil end
    return false
end
local function triNot(a)
    if a == nil then return nil end
    return not a
end

local QUALITY = { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4,
                  legendary = 5, artifact = 6, heirloom = 7 }

local EXPANSION = { classic = 0, bc = 1, wotlk = 2, cata = 3, mop = 4, wod = 5,
                    legion = 6, bfa = 7, shadowlands = 8, dragonflight = 9,
                    tww = 10, midnight = 11 }

local SLOT = {
    head = "INVTYPE_HEAD", neck = "INVTYPE_NECK", shoulder = "INVTYPE_SHOULDER",
    back = "INVTYPE_CLOAK", cloak = "INVTYPE_CLOAK", chest = "INVTYPE_CHEST",
    wrist = "INVTYPE_WRIST", hands = "INVTYPE_HAND", waist = "INVTYPE_WAIST",
    legs = "INVTYPE_LEGS", feet = "INVTYPE_FEET", finger = "INVTYPE_FINGER",
    ring = "INVTYPE_FINGER", trinket = "INVTYPE_TRINKET", bag = "INVTYPE_BAG",
}

local KEYWORDS = {
    junk      = function(d) if d.quality == nil then return nil end return d.quality == 0 end,
    reagent   = function(d) if d.classID == nil then return nil end return d.classID == 7 or d.classID == 5 end,
    gear      = function(d) if d.classID == nil then return nil end return d.classID == 2 or d.classID == 4 end,
    quest     = function(d) if d.classID == nil then return nil end return d.classID == 12 end,
    pet       = function(d) if d.classID == nil then return nil end return d.classID == 17 end,
    soulbound = function(d) return d.isBound == true end,
    bound     = function(d) return d.isBound == true end,
}
KEYWORDS.equipment = KEYWORDS.gear
KEYWORDS.trash = KEYWORDS.junk

-- more search words (item class / subclass, binding, collections)
local function Class(id, sub)
    return function(d)
        if d.classID == nil then return nil end
        if d.classID ~= id then return false end
        if sub == nil then return true end
        if type(sub) == "table" then return sub[d.subClassID] == true end
        return d.subClassID == sub
    end
end
local function Bind(kinds, unboundOnly)
    return function(d)
        if d.bindType == nil then return nil end
        if unboundOnly and d.isBound then return false end
        return kinds[d.bindType] == true
    end
end
local function LinkHas(pattern)
    return function(d)
        if type(d.link) ~= "string" then return nil end
        return d.link:find(pattern) ~= nil
    end
end

KEYWORDS.consumable  = Class(0)
KEYWORDS.potion      = Class(0, 1)
KEYWORDS.elixir      = Class(0, 2)
KEYWORDS.flask       = Class(0, 3)
KEYWORDS.phial       = KEYWORDS.flask
KEYWORDS.food        = Class(0, 5)
KEYWORDS.drink       = KEYWORDS.food
KEYWORDS.bandage     = Class(0, 7)
KEYWORDS.rune        = Class(0, 9)
KEYWORDS.container   = Class(1)
KEYWORDS.weapon      = Class(2)
KEYWORDS.gem         = Class(3)
KEYWORDS.armor       = Class(4)
KEYWORDS.armour      = KEYWORDS.armor
KEYWORDS.cloth       = Class(4, 1)
KEYWORDS.leather     = Class(4, 2)
KEYWORDS.mail        = Class(4, 3)
KEYWORDS.plate       = Class(4, 4)
KEYWORDS.cosmetic    = Class(4, 5)
KEYWORDS.shield      = Class(4, 6)
KEYWORDS.tradegoods  = Class(7)
KEYWORDS.tradegood   = KEYWORDS.tradegoods
KEYWORDS.enhancement = Class(8)
KEYWORDS.recipe      = Class(9)
KEYWORDS.key         = Class(13)
KEYWORDS.miscellaneous = Class(15)
KEYWORDS.misc        = KEYWORDS.miscellaneous
KEYWORDS.mount       = Class(15, 5)
KEYWORDS.glyph       = Class(16)
KEYWORDS.battlepet   = Class(17)
KEYWORDS.profession  = Class(19)
KEYWORDS.housing     = Class(20)
KEYWORDS.decor       = KEYWORDS.housing
KEYWORDS.boe         = Bind({ [2] = true }, true)
KEYWORDS.bou         = Bind({ [3] = true }, true)
KEYWORDS.boa         = Bind({ [7] = true, [8] = true })
KEYWORDS.warbound    = Bind({ [7] = true, [8] = true, [9] = true })
KEYWORDS.wue         = Bind({ [9] = true }, true)
KEYWORDS.keystone    = LinkHas("keystone:")
KEYWORDS.toy = function(d)
    if not (d.itemID and C_ToyBox and C_ToyBox.GetToyInfo) then return nil end
    return C_ToyBox.GetToyInfo(d.itemID) ~= nil
end
KEYWORDS.upgrade = function(d)
    local CW = Bags.CornerWidgets
    if not (CW and CW.IsUpgrade) then return nil end
    return CW.IsUpgrade(d)
end
KEYWORDS.transmog = function(d)
    local CW = Bags.CornerWidgets
    if not (CW and CW.IsUncollectedAppearance) then return nil end
    return CW.IsUncollectedAppearance(d.link)
end
KEYWORDS.uncollected = KEYWORDS.transmog
KEYWORDS.set = function(d)
    if not d.itemID or not C_EquipmentSet or not C_EquipmentSet.GetItemIDs then return nil end
    for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetEquipmentSetIDs() or {}) do
        for _, itemID in pairs(C_EquipmentSet.GetItemIDs(id) or {}) do
            if itemID == d.itemID then return true end
        end
    end
    return false
end
KEYWORDS.equipmentset = KEYWORDS.set

local function MakeTermMatcher(term)
    -- "#weapon" (keyword marker) and "ilvl>600" / "ilvl:600-650" forms
    local keywordOnly = term:sub(1, 1) == "#"
    term = term:gsub("^#", "")
    term = term:gsub("^ilvl:?", "")
    if term == "" then return function() return true end end
    local op, num = term:match("^([<>=])(%d+)$")
    if op then
        num = tonumber(num)
        return function(d)
            if d.ilvl == nil then return nil end
            if op == "<" then return d.ilvl < num
            elseif op == ">" then return d.ilvl > num
            else return d.ilvl == num end
        end
    end
    local lo, hi = term:match("^(%d+)%-(%d+)$")
    if lo then
        lo, hi = tonumber(lo), tonumber(hi)
        return function(d)
            if d.ilvl == nil then return nil end
            return d.ilvl >= lo and d.ilvl <= hi
        end
    end
    if QUALITY[term] ~= nil then
        local q = QUALITY[term]
        return function(d)
            if d.quality == nil then return nil end
            return d.quality == q
        end
    end
    if EXPANSION[term] ~= nil then
        local e = EXPANSION[term]
        return function(d)
            if d.expacID == nil then return nil end
            return d.expacID == e
        end
    end
    if SLOT[term] then
        local slot = SLOT[term]
        return function(d)
            if d.equipLoc == nil then return nil end
            return d.equipLoc == slot
        end
    end
    if KEYWORDS[term] then
        local kw = KEYWORDS[term]
        if keywordOnly then return kw end
        -- a plain word is the keyword or a name match ("mail" still finds Chainmail)
        local needleExact = term
        return function(d)
            local r = kw(d)
            if r == true then return true end
            local n = (d.name ~= nil) and (Fold(d.name):find(needleExact, 1, true) ~= nil) or nil
            return triOr(r, n)
        end
    end
    local prefixChecks
    for kw, fn in pairs(KEYWORDS) do
        if #term < #kw and kw:sub(1, #term) == term then
            prefixChecks = prefixChecks or {}
            local seen = false
            for i = 1, #prefixChecks do
                if prefixChecks[i] == fn then seen = true break end
            end
            if not seen then prefixChecks[#prefixChecks + 1] = fn end
        end
    end
    local needle = term
    local nameCheck = function(d)
        if d.name == nil then return nil end
        return Fold(d.name):find(needle, 1, true) ~= nil
    end
    if not prefixChecks then
        return nameCheck
    end
    return function(d)
        local r = nameCheck(d)
        for i = 1, #prefixChecks do
            r = triOr(r, prefixChecks[i](d))
            if r == true then return true end
        end
        return r
    end
end

local function CompileUncached(query)
    local orMatchers = {}
    for orPart in (query .. "|"):gmatch("(.-)|") do
        local andMatchers = {}
        for token in orPart:gmatch("[^&%s]+") do
            local negate = false
            while token:sub(1, 1) == "~" or token:sub(1, 1) == "!" do
                negate = not negate
                token = token:sub(2)
            end
            if token ~= "" then
                local m = MakeTermMatcher(token)
                if negate then
                    local inner = m
                    m = function(d) return triNot(inner(d)) end
                end
                andMatchers[#andMatchers + 1] = m
            end
        end
        if #andMatchers > 0 then
            orMatchers[#orMatchers + 1] = andMatchers
        end
    end
    if #orMatchers == 0 then
        return function() return true end
    end
    return function(d)
        local result = false
        for i = 1, #orMatchers do
            local group = orMatchers[i]
            local g = true
            for j = 1, #group do
                g = triAnd(g, group[j](d))
                if g == false then break end
            end
            result = triOr(result, g)
            if result == true then return true end
        end
        return result
    end
end

local CACHE_CAP = 64
local cache, cacheCount = {}, 0

function Search.Compile(query)
    query = Fold(query):match("^%s*(.-)%s*$")
    local hit = cache[query]
    if hit then return hit end
    if cacheCount >= CACHE_CAP then
        cache, cacheCount = {}, 0
    end
    local m = CompileUncached(query)
    cache[query] = m
    cacheCount = cacheCount + 1
    return m
end
