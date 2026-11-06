---------------------------------------------------------------------------
-- H3z0 UI Bags - categories (bag layout "Categories")
--
-- Every item lands in one category:
--   1. an item you put in a category yourself (drag it onto the category title)
--   2. Recent (new loot)
--   3. Equipment Sets (live bags)
--   4. your own categories, by their search text, in your order
--   5. the built-in categories, most specific first (Junk, Keystone, Potion, ...)
-- Categories are laid out as blocks next to each other, row by row, in the
-- order set on the Categories settings page. Hidden categories are not shown
-- (and neither are their items). Identical items can share one button.
--
-- Settings: profile.bags.categories
--   order    = { key, ... }        display order (missing keys are added)
--   hidden   = { [key] = true }
--   custom   = { [key] = { name = "...", search = "..." } }
--   assign   = { [itemID] = key }
--   groupIdentical = true, groupEmpty = true, spacing = 10
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Bags = ns.Bags or {}; ns.Bags = Bags
local Helpers = ns.Helpers
local GetSettings = Helpers.CreateDBGetter("bags")

local Categories = {}
Bags.Categories = Categories

local HEARTHSTONES = {
    [6948] = true, [110560] = true, [140192] = true, [141605] = true,
    [128353] = true, [212337] = true, [228940] = true, [236687] = true,
}

local function Is(classID, sub)
    return function(d)
        if not d or d.classID ~= classID then return false end
        if sub == nil then return true end
        return d.subClassID == sub
    end
end

-- built-in categories (key, name, matcher). Display order is the list order.
local BUILTIN = {
    { key = "recent",      name = ns.L["Recent"],          special = true },
    { key = "sets",        name = ns.L["Equipment Sets"],  special = true },
    { key = "hearth",      name = ns.L["Hearthstone"],     match = function(d) return d and HEARTHSTONES[d.itemID] or false end },
    { key = "keystone",    name = ns.L["Keystone"],        match = function(d) return d and type(d.link) == "string" and d.link:find("keystone:") ~= nil or false end },
    { key = "potion",      name = ns.L["Potion"],          match = Is(0, 1) },
    { key = "flask",       name = ns.L["Flask"],           match = Is(0, 3) },
    { key = "food",        name = ns.L["Food"],            match = Is(0, 5) },
    { key = "consumable",  name = ns.L["Consumable"],      match = Is(0) },
    { key = "gem",         name = ns.L["Gem"],             match = Is(3) },
    { key = "enhancement", name = ns.L["Item Enhancement"], match = Is(8) },
    { key = "profession",  name = ns.L["Profession"],      match = Is(19) },
    { key = "key",         name = ns.L["Key"],             match = Is(13) },
    { key = "battlepet",   name = ns.L["Battle Pet"],      match = function(d) return d and (d.classID == 17 or (d.classID == 15 and d.subClassID == 2)) or false end },
    { key = "toy",         name = ns.L["Toy"],             match = function(d)
        return d and d.itemID and C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(d.itemID) ~= nil or false
    end },
    { key = "mount",       name = ns.L["Mount"],           match = Is(15, 5) },
    { key = "housing",     name = ns.L["Housing"],         match = Is(20) },
    { key = "reagent",     name = ns.L["Reagent"],         match = function(d) return d and (d.isReagent or d.classID == 5) or false end },
    { key = "reagentbag",  name = ns.L["Reagent Bag"],     special = true },
    { key = "tradegoods",  name = ns.L["Trade Goods"],     match = Is(7) },
    { key = "weapon",      name = ns.L["Weapon"],          match = Is(2), gear = true },
    { key = "armor",       name = ns.L["Armor"],           match = function(d) return d and d.classID == 4 and d.isEquippable or false end, gear = true },
    { key = "container",   name = ns.L["Container"],       match = Is(1) },
    { key = "recipe",      name = ns.L["Recipe"],          match = Is(9) },
    { key = "quest",       name = ns.L["Quest Item"],      match = Is(12) },
    { key = "misc",        name = ns.L["Miscellaneous"],   match = Is(15) },
    { key = "other",       name = ns.L["Other"],           match = function() return true end },
    { key = "junk",        name = ns.L["Junk"],            match = function(d) return d and d.quality == 0 or false end },
    { key = "empty",       name = ns.L["Empty"],           special = true },
}
local BUILTIN_BY_KEY = {}
for _, c in ipairs(BUILTIN) do BUILTIN_BY_KEY[c.key] = c end

-- always first, whatever the saved order says
local PINNED_TOP = { "hearth", "keystone" }
local IS_PINNED_TOP = { hearth = true, keystone = true }
Categories.PINNED_TOP = IS_PINNED_TOP

-- icons for the Inventory sidebar
local ICON = "Interface\\Icons\\"
local ICONS = {
    recent = "Spell_Holy_BorrowedTime", sets = "INV_Shield_06", hearth = "INV_Misc_Rune_01",
    keystone = "INV_Relics_Hourglass", potion = "INV_Potion_54", flask = "INV_Alchemy_EndlessFlask_06",
    food = "INV_Misc_Food_15", consumable = "INV_Potion_93", gem = "INV_Misc_Gem_01",
    enhancement = "INV_Misc_EnggizmosEssence", profession = "Trade_BlackSmithing", key = "INV_Misc_Key_03",
    battlepet = "INV_Box_PetCarrier_01", toy = "INV_Misc_Toy_10", mount = "Ability_Mount_RidingHorse",
    housing = "INV_Misc_Furniture_Chair_03", reagent = "INV_Misc_Herb_01", reagentbag = "INV_Misc_Bag_10",
    tradegoods = "INV_Fabric_Linen_01", weapon = "INV_Sword_04", armor = "INV_Chest_Chain",
    container = "INV_Misc_Bag_08", recipe = "INV_Scroll_03", quest = "INV_Misc_Note_01",
    misc = "INV_Misc_QuestionMark", other = "INV_Misc_QuestionMark", junk = "INV_Misc_Coin_01",
    empty = "INV_Misc_Bag_07",
}
function Categories.Icon(key)
    return ICON .. (ICONS[key] or "INV_Misc_Bag_EnchantedMageweave")
end

-- which built-in wins when several match: the most specific first
local PRIORITY = {
    "junk", "keystone", "hearth", "potion", "flask", "food", "consumable", "gem",
    "enhancement", "profession", "key", "battlepet", "toy", "mount", "housing",
    "reagent", "tradegoods", "weapon", "armor", "container", "recipe", "quest",
    "misc", "other",
}

local function DB()
    local s = GetSettings()
    if not s then return nil end
    s.categories = s.categories or {}
    local c = s.categories
    c.order = c.order or {}
    c.hidden = c.hidden or {}
    c.custom = c.custom or {}
    c.assign = c.assign or {}
    if c.groupIdentical == nil then c.groupIdentical = true end
    if c.spacing == nil then c.spacing = 10 end
    if c.groupEmpty == nil then c.groupEmpty = true end
    return c
end
Categories.DB = DB

-- display order: saved order, plus anything new (custom categories go in
-- front of the built-in ones, new built-ins next to their default neighbour)
function Categories.Order()
    local c = DB()
    if not c then
        local out = {}
        for _, b in ipairs(BUILTIN) do out[#out + 1] = b.key end
        return out
    end
    local seen, out = {}, {}
    for _, key in ipairs(c.order) do
        if (BUILTIN_BY_KEY[key] or c.custom[key]) and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    for i, b in ipairs(BUILTIN) do
        if not seen[b.key] then
            seen[b.key] = true
            local prev = BUILTIN[i - 1]
            local at = #out + 1
            if prev then
                for j, k in ipairs(out) do if k == prev.key then at = j + 1 end end
            else
                at = 1
            end
            table.insert(out, at, b.key)
        end
    end
    local customKeys = {}
    for key in pairs(c.custom) do
        if not seen[key] then customKeys[#customKeys + 1] = key end
    end
    table.sort(customKeys)
    for i, key in ipairs(customKeys) do
        seen[key] = true
        -- after Recent / Equipment Sets
        local at = 1
        for j, k in ipairs(out) do if k == "recent" or k == "sets" then at = j + 1 end end
        table.insert(out, at + i - 1, key)
    end
    -- Hearthstone and Keystone stay on top
    for i = #PINNED_TOP, 1, -1 do
        local key = PINNED_TOP[i]
        for j, k in ipairs(out) do
            if k == key then table.remove(out, j) break end
        end
        table.insert(out, 1, key)
    end
    c.order = out
    return out
end

function Categories.Name(key)
    local c = DB()
    local custom = c and c.custom[key]
    if custom then return custom.name or key end
    local b = BUILTIN_BY_KEY[key]
    return b and b.name or key
end

function Categories.Rename(key, name)
    local c = DB()
    if c and c.custom[key] and name and name ~= "" then c.custom[key].name = name end
end

function Categories.SetSearch(key, search)
    local c = DB()
    if c and c.custom[key] then c.custom[key].search = search or "" end
end

function Categories.IsCustom(key)
    local c = DB()
    return c and c.custom[key] ~= nil or false
end

function Categories.IsHidden(key)
    local c = DB()
    return c and c.hidden[key] and true or false
end

function Categories.Exists(key)
    local c = DB()
    return BUILTIN_BY_KEY[key] ~= nil or (c and c.custom[key] ~= nil) or false
end

-- own categories
function Categories.AddCustom(name, search)
    local c = DB()
    if not c or not name or name == "" then return nil end
    local n, key = 1, nil
    repeat key = "c" .. n; n = n + 1 until not c.custom[key]
    c.custom[key] = { name = name, search = search or "" }
    Categories.Order()
    return key
end

function Categories.DeleteCustom(key)
    local c = DB()
    if not c or not c.custom[key] then return end
    c.custom[key] = nil
    c.hidden[key] = nil
    for itemID, k in pairs(c.assign) do
        if k == key then c.assign[itemID] = nil end
    end
    for i, k in ipairs(c.order) do
        if k == key then table.remove(c.order, i) break end
    end
end

function Categories.Move(key, delta)
    local order = Categories.Order()
    for i, k in ipairs(order) do
        if k == key then
            local j = i + delta
            if j >= 1 and j <= #order then
                order[i], order[j] = order[j], order[i]
            end
            return
        end
    end
end

function Categories.SetHidden(key, hidden)
    local c = DB()
    if c then c.hidden[key] = hidden and true or nil end
end

function Categories.Assign(itemID, key)
    local c = DB()
    if not c or not itemID then return end
    c.assign[itemID] = key
end

-- changes whenever the order, the hidden categories, your own categories or the items put
-- in a category by hand change (a window uses it to know its layout is still the same)
function Categories.Signature()
    local c = DB()
    if not c then return "" end
    local parts = { table.concat(c.order, ",") }
    local hidden = {}
    for k, v in pairs(c.hidden) do if v then hidden[#hidden + 1] = k end end
    table.sort(hidden)
    parts[#parts + 1] = table.concat(hidden, ",")
    local custom = {}
    for k, def in pairs(c.custom) do custom[#custom + 1] = k .. "=" .. tostring(def.name) .. "/" .. tostring(def.search) end
    table.sort(custom)
    parts[#parts + 1] = table.concat(custom, ",")
    local n, sum = 0, 0
    for itemID, key in pairs(c.assign) do
        n = n + 1
        sum = sum + itemID * (#tostring(key) + 1)
    end
    parts[#parts + 1] = n .. ":" .. sum
    parts[#parts + 1] = tostring(c.groupIdentical) .. tostring(c.spacing)
    return table.concat(parts, "|")
end

function Categories.Reset()
    local c = DB()
    if not c then return end
    wipe(c.order)
    wipe(c.hidden)
end

---------------------------------------------------------------------------
-- Matching
---------------------------------------------------------------------------
local function CustomMatchers(c, order)
    local list = {}
    for _, key in ipairs(order) do
        local def = c and c.custom[key]
        if def and def.search and def.search ~= "" and Bags.Search then
            list[#list + 1] = { key = key, match = Bags.Search.Compile(def.search) }
        end
    end
    return list
end

local function InSet(cell, live)
    if not live or not C_Container.GetContainerItemEquipmentSetInfo then return false end
    local ok, inSet = pcall(C_Container.GetContainerItemEquipmentSetInfo, cell.bagID, cell.slot)
    return ok and inSet and true or false
end

local function Classify(cell, d, live, c, customs)
    local itemID = cell.entry and cell.entry.itemID
    local assigned = c and itemID and c.assign[itemID]
    if assigned and Categories.Exists(assigned) then return assigned end
    if cell.recent then return "recent" end
    if InSet(cell, live) then return "sets" end
    if cell.bagID == 5 and not (c and c.hidden.reagentbag) then return "reagentbag" end
    for _, m in ipairs(customs) do
        if d and m.match(d) == true then return m.key end
    end
    for _, key in ipairs(PRIORITY) do
        local b = BUILTIN_BY_KEY[key]
        if b.match(d) then return key end
    end
    return "other"
end

---------------------------------------------------------------------------
-- Grouping: cells -> ordered groups { key, title, cells }
---------------------------------------------------------------------------
function Categories.Group(cells, buildDetails, sortOpts, live, opts)
    local c = DB()
    local order = Categories.Order()
    local customs = CustomMatchers(c, order)
    local grouping = c and c.groupIdentical
    local buckets, empties, reagentEmpties = {}, {}, {}
    local merged = {}

    for seq, cell in ipairs(cells) do
        cell._freeCount = nil
        cell._groupCount = nil
        if cell.entry then
            local d = buildDetails(cell.entry)
            local key = Classify(cell, d, live, c, customs)
            -- identical items share one button (gear by its link, the rest by item ID)
            local mergeKey
            if grouping then
                local id = cell.entry.itemID
                mergeKey = key .. ":" .. ((d and d.isEquippable and cell.entry.link) or tostring(id))
            end
            local host = mergeKey and merged[mergeKey]
            if host then
                host._groupCount = (host._groupCount or (host.entry.count or 1)) + (cell.entry.count or 1)
            else
                if mergeKey then merged[mergeKey] = cell end
                local b = buckets[key]
                if not b then b = {}; buckets[key] = b end
                b[#b + 1] = cell
                cell._sortDetails = {
                    entry = {
                        quality = (d and d.quality) or cell.entry.quality,
                        sortClass = d and d.classID,
                        sortSubClass = d and d.subClassID,
                        ilvl = d and d.ilvl,
                        name = d and d.name,
                        expacID = d and d.expacID,
                        itemID = cell.entry.itemID,
                    },
                    count = cell.entry.count or 1,
                    seq = seq,
                }
            end
        elseif cell.bagID == 5 then
            reagentEmpties[#reagentEmpties + 1] = cell
        else
            empties[#empties + 1] = cell
        end
    end

    local compare = Bags.SortPlanner.MakeComparator(sortOpts)
    local gearOpts = {}
    for k, v in pairs(sortOpts or {}) do gearOpts[k] = v end
    gearOpts.gear = true
    local compareGear = Bags.SortPlanner.MakeComparator(gearOpts)
    local function less(a, b) return compare(a._sortDetails, b._sortDetails) end
    local function lessGear(a, b) return compareGear(a._sortDetails, b._sortDetails) end

    local groups = {}
    for _, key in ipairs(order) do
        if not (c and c.hidden[key]) then
            if key == "empty" then
                local list = {}
                local groupEmpty = not (c and c.groupEmpty == false)
                for _, set in ipairs({ empties, reagentEmpties }) do
                    if #set > 0 then
                        if groupEmpty then
                            set[1]._freeCount = #set
                            list[#list + 1] = set[1]
                        else
                            for _, e in ipairs(set) do list[#list + 1] = e end
                        end
                    end
                end
                if #list > 0 then
                    groups[#groups + 1] = { key = key, title = Categories.Name(key), cells = list }
                end
            else
                local b = buckets[key]
                if b and #b > 0 then
                    local def = BUILTIN_BY_KEY[key]
                    table.sort(b, (def and def.gear or key == "sets") and lessGear or less)
                    groups[#groups + 1] = { key = key, title = Categories.Name(key), cells = b }
                end
            end
        end
    end
    for _, b in pairs(buckets) do
        for _, cell in ipairs(b) do cell._sortDetails = nil end
    end
    return groups
end

---------------------------------------------------------------------------
-- Packing: each category is a block (title + its own little grid); blocks
-- sit next to each other while they fit in the window's columns
---------------------------------------------------------------------------
function Categories.Compute(groups, config)
    local size = config.iconSize or 36
    local gap = config.spacing or 4
    local cols = math.max(1, config.columns or 12)
    local headerH = config.headerHeight or 18
    local catGap = config.categorySpacing or 10
    local totalW = cols * size + (cols - 1) * gap
    local out = { buttons = {}, headers = {} }
    local x, y, rowH, width = 0, 0, 0, 0
    for _, group in ipairs(groups) do
        local n = #group.cells
        local blockCols = math.min(n, cols)
        local blockW = blockCols * size + (blockCols - 1) * gap
        local blockRows = math.ceil(n / blockCols)
        local blockH = headerH + blockRows * size + (blockRows - 1) * gap
        if x > 0 and x + blockW > totalW + 0.5 then
            x = 0
            y = y - rowH - catGap
            rowH = 0
        end
        out.headers[#out.headers + 1] = { title = group.title, key = group.key, x = x, y = y, w = math.max(blockW, size) }
        for i, cell in ipairs(group.cells) do
            local col = (i - 1) % blockCols
            local row = math.floor((i - 1) / blockCols)
            out.buttons[#out.buttons + 1] = {
                cell = cell,
                x = x + col * (size + gap),
                y = y - headerH - row * (size + gap),
            }
        end
        width = math.max(width, x + blockW)
        rowH = math.max(rowH, blockH)
        x = x + blockW + catGap
    end
    out.width = width
    out.height = (#groups > 0) and (-y + rowH) or 0
    return out
end

-- for the settings page: every category in display order
function Categories.List()
    local out = {}
    for _, key in ipairs(Categories.Order()) do
        out[#out + 1] = {
            key = key,
            name = Categories.Name(key),
            custom = Categories.IsCustom(key),
            hidden = Categories.IsHidden(key),
            special = BUILTIN_BY_KEY[key] and BUILTIN_BY_KEY[key].special or false,
        }
    end
    return out
end
