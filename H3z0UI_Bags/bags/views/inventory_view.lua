-- luacheck: read globals GetCursorInfo ClearCursor MenuUtil StaticPopup_Show StaticPopupDialogs
---------------------------------------------------------------------------
-- H3z0 UI Inventory view (bags layout "inventory")
--
--   +---------------------------------------------------------------+
--   | Inventory  139 / 194 Items          [sort] [$] [G] [search] X |
--   |---------------+-----------------------------------------------|
--   | Categories  < | Pinned Items (Middle Click to Add or Remove)   |
--   | All Items 139 | [] [] [] +                                Hide |
--   | OneBag    139 | Recent Items (Extra quickview display ...)Hide |
--   | Pinned      3 | The Armory (78)                                |
--   | Recent      0 | [] [] [] [] [] [] [] [] [] [] [] []            |
--   | The Armory 78 | ...                                            |
--   |   Weapons ... |                                                |
--   | Add Category  |                                     1,387,300g |
--   +---------------------------------------------------------------+
--
-- * The sidebar filters the view; parent categories show their children.
-- * Middle-click an item to pin / unpin it. Pinned and Recent are quick views:
--   the item also stays in its own category.
-- * Every category ends with a "+" slot: drop an item there (or click it with an
--   item on the cursor) and that item belongs to the category from now on.
-- * "Add Category" makes your own categories; right-click one to rename / delete.
--
-- Settings: profile.bags.inventory
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Bags = ns.Bags or {}; ns.Bags = Bags
local UIKit = ns.UIKit
local Helpers = ns.Helpers
local GetSettings = Helpers.CreateDBGetter("bags")

local InventoryView = {}
Bags.InventoryView = InventoryView

local SIDEBAR_W = 168
local SIDEBAR_GAP = 8
local ROW_H = 20
local HEADER_H = 22
local SECTION_GAP = 10
local MAX_VIEW_H = 560
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function CJKFont(fs, p, s, f)
    if Bags.CJKFont then return Bags.CJKFont(fs, p, s, f) end
    fs:SetFont(p, s, f)
end

local function Font() return Helpers.GetGeneralFont() or STANDARD_TEXT_FONT end

---------------------------------------------------------------------------
-- Categories
---------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"
local BUILTIN = {
    { key = "armory",      name = "The Armory",          icon = ICON .. "INV_Sword_04" },
    { key = "weapons",     name = "Weapons / Trinkets",  icon = ICON .. "INV_Sword_04",         parent = "armory" },
    { key = "armor",       name = "Armor",               icon = ICON .. "INV_Chest_Chain",      parent = "armory" },
    { key = "itemset",     name = "Item Set Gear",       icon = ICON .. "INV_Shield_06",        parent = "armory" },
    { key = "prep",        name = "Adventure Prep",      icon = ICON .. "INV_Potion_54" },
    { key = "consumables", name = "Consumables",         icon = ICON .. "INV_Potion_54",        parent = "prep" },
    { key = "professions", name = "Professions",         icon = ICON .. "Trade_BlackSmithing" },
    { key = "reagentbag",  name = "Reagent Bag",         icon = ICON .. "INV_Misc_Bag_10" },
    { key = "quest",       name = "Quest Items",         icon = ICON .. "INV_Misc_Note_01",     hideEmpty = true },
    -- custom categories go here
    { key = "junk",        name = "Junk",                icon = ICON .. "INV_Misc_Coin_01",     hideEmpty = true },
    { key = "misc",        name = "Miscellaneous",       icon = ICON .. "INV_Misc_QuestionMark" },
}

local SPECIAL = {
    { key = "all",    name = "All Items",    icon = ICON .. "INV_Misc_Bag_08" },
    { key = "onebag", name = "OneBag",       icon = ICON .. "INV_Misc_Bag_07" },
    { key = "pinned", name = "Pinned Items", icon = ICON .. "INV_Misc_Note_01" },
    { key = "recent", name = "Recent Items", icon = ICON .. "Spell_Holy_BorrowedTime" },
}

local TRINKET_SLOTS = { INVTYPE_TRINKET = true }
local PROFESSION_CLASSES = { [3] = true, [5] = true, [7] = true, [8] = true, [9] = true, [19] = true }

local function DB()
    local s = GetSettings()
    if not s then return nil end
    s.inventory = s.inventory or {}
    local d = s.inventory
    d.pinned = d.pinned or {}
    d.assign = d.assign or {}
    d.custom = d.custom or {}
    d.hidden = d.hidden or {}
    if d.sidebar == nil then d.sidebar = true end
    d.selected = d.selected or "all"
    return d
end

local version = 0
local function Changed()
    version = version + 1
    if Bags.BagWindow and Bags.BagWindow.Refresh then Bags.BagWindow.Refresh() end
end

function InventoryView.Signature()
    local d = DB()
    return table.concat({ "inv", version, d and d.selected or "", d and tostring(d.sidebar) or "" }, ":")
end

-- ordered list of every category (builtin + custom)
local function AllCategories()
    local d = DB()
    local out = {}
    for _, c in ipairs(BUILTIN) do
        if c.key == "junk" and d then
            for _, cc in ipairs(d.custom) do
                out[#out + 1] = { key = cc.key, name = cc.name, icon = ICON .. "INV_Misc_Bag_EnchantedMageweave", custom = true }
            end
        end
        out[#out + 1] = c
    end
    return out
end

local function CategoryByKey(key)
    for _, c in ipairs(AllCategories()) do
        if c.key == key then return c end
    end
end

local function ChildrenOf(key)
    local list = {}
    for _, c in ipairs(AllCategories()) do
        if c.parent == key then list[#list + 1] = c.key end
    end
    return list
end

local function InSet(cell, live)
    if not live or not C_Container.GetContainerItemEquipmentSetInfo then return false end
    local ok, inSet = pcall(C_Container.GetContainerItemEquipmentSetInfo, cell.bagID, cell.slot)
    return ok and inSet and true or false
end

-- the leaf category of an occupied cell
function InventoryView.Categorize(cell, details, live)
    local d = DB()
    local itemID = cell.entry and cell.entry.itemID
    local assigned = d and itemID and d.assign[itemID]
    if assigned and CategoryByKey(assigned) then return assigned end
    if cell.bagID == 5 then return "reagentbag" end
    if not details then return "misc" end
    if details.quality == 0 then return "junk" end
    if InSet(cell, live) then return "itemset" end
    local classID = details.classID
    if classID == 2 or (classID == 4 and TRINKET_SLOTS[details.equipLoc or ""]) then return "weapons" end
    if classID == 4 then return "armor" end
    if classID == 0 then return "consumables" end
    if classID and PROFESSION_CLASSES[classID] then return "professions" end
    if classID == 12 or classID == 13 then return "quest" end
    return "misc"
end

-- does leaf category "leaf" belong to "key" (itself or a parent)?
local function Belongs(leaf, key)
    if leaf == key then return true end
    local c = CategoryByKey(leaf)
    return c and c.parent == key or false
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local function SkinColors()
    local sr, sg, sb = Helpers.GetSkinColors()
    return sr or 0.2, sg or 0.83, sb or 0.6
end

local function MakeText(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or "ARTWORK")
    CJKFont(fs, Font(), size or 11, "OUTLINE")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function MakeSmallButton(parent, text)
    local b = Bags.Chassis.CreatePanelButton(parent, true)
    b._label:SetText(text)
    b:SetSize(math.max(32, math.ceil(b._label:GetStringWidth()) + 12), 16)
    UIKit.CreateBorderLines(b)
    local sr, sg, sb, sa = Helpers.GetWindowColors()
    UIKit.UpdateBorderLines(b, 1, sr, sg, sb, 0.35 * (sa or 1))
    return b
end

local function AddCategoryPopup()
    local key = "H3Z0UI_BAGS_ADD_CATEGORY"
    StaticPopupDialogs[key] = StaticPopupDialogs[key] or {
        text = "New category name:",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 32,
        OnAccept = function(self)
            local box = self.editBox or self.EditBox
            local name = box and strtrim(box:GetText() or "") or ""
            if name == "" then return end
            local d = DB()
            if not d then return end
            local n = (#d.custom + 1)
            local newKey
            repeat
                newKey = "custom" .. n
                n = n + 1
            until not CategoryByKey(newKey)
            d.custom[#d.custom + 1] = { key = newKey, name = name }
            Changed()
        end,
        EditBoxOnEnterPressed = function(box)
            local dialog = box:GetParent()
            if dialog and dialog.button1 then dialog.button1:Click() end
        end,
        EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show(key)
end

local function RenamePopup(cat)
    local key = "H3Z0UI_BAGS_RENAME_CATEGORY"
    StaticPopupDialogs[key] = {
        text = "Rename category:",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 32,
        OnShow = function(self)
            local box = self.editBox or self.EditBox
            if box then box:SetText(cat.name or "") end
        end,
        OnAccept = function(self)
            local box = self.editBox or self.EditBox
            local name = box and strtrim(box:GetText() or "") or ""
            if name == "" then return end
            local d = DB()
            for _, cc in ipairs(d and d.custom or {}) do
                if cc.key == cat.key then cc.name = name end
            end
            Changed()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show(key)
end

local function DeleteCategory(key)
    local d = DB()
    if not d then return end
    for i, cc in ipairs(d.custom) do
        if cc.key == key then table.remove(d.custom, i) break end
    end
    for itemID, k in pairs(d.assign) do
        if k == key then d.assign[itemID] = nil end
    end
    if d.selected == key then d.selected = "all" end
    Changed()
end

local function EnsureFrames(win)
    local v = win._inventory
    if v then return v end
    v = {}
    win._inventory = v

    -- sidebar
    v.sidebar = CreateFrame("Frame", nil, win._body)
    v.sidebar:SetWidth(SIDEBAR_W)
    v.sidebarBg = v.sidebar:CreateTexture(nil, "BACKGROUND")
    v.sidebarBg:SetAllPoints()
    v.sidebarBg:SetTexture(WHITE)
    v.sidebarBg:SetVertexColor(1, 1, 1, 0.035)
    v.sidebarTitle = MakeText(v.sidebar, 11)
    v.sidebarTitle:SetPoint("TOPLEFT", 8, -6)
    v.sidebarTitle:SetText("Categories")
    v.sidebarTitle:SetTextColor(0.7, 0.7, 0.7)
    v.rows = {}

    v.collapse = MakeSmallButton(win._body, "<")
    v.collapse:SetSize(16, 16)
    v.collapse:SetScript("OnClick", function()
        local d = DB()
        if d then d.sidebar = not d.sidebar end
        Changed()
    end)
    v.collapse:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show / hide the categories")
        GameTooltip:Show()
    end)
    v.collapse:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- scrolling item area
    v.scroll = CreateFrame("ScrollFrame", nil, win._body)
    v.scroll:EnableMouseWheel(true)
    v.child = CreateFrame("Frame", nil, v.scroll)
    v.child:SetSize(10, 10)
    v.scroll:SetScrollChild(v.child)
    v.scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, (v.child:GetHeight() or 0) - (self:GetHeight() or 0))
        local cur = self:GetVerticalScroll() or 0
        local new = math.min(max, math.max(0, cur - delta * 48))
        self:SetVerticalScroll(new)
        InventoryView.UpdateScrollBar(v)
    end)
    v.bar = v.scroll:CreateTexture(nil, "OVERLAY")
    v.bar:SetTexture(WHITE)
    v.bar:SetWidth(3)

    v.headers = {}
    v.mirrors = {}
    v.plus = {}
    return v
end

function InventoryView.UpdateScrollBar(v)
    local viewH = v.scroll:GetHeight() or 0
    local total = v.child:GetHeight() or 0
    if total <= viewH + 1 or viewH <= 0 then v.bar:Hide() return end
    local sr, sg, sb = SkinColors()
    v.bar:SetVertexColor(sr, sg, sb, 0.6)
    local h = math.max(20, viewH * viewH / total)
    local maxScroll = total - viewH
    local pos = (v.scroll:GetVerticalScroll() or 0) / maxScroll
    v.bar:ClearAllPoints()
    v.bar:SetHeight(h)
    v.bar:SetPoint("TOPRIGHT", v.scroll, "TOPRIGHT", 0, -pos * (viewH - h))
    v.bar:Show()
end

---------------------------------------------------------------------------
-- Sidebar
---------------------------------------------------------------------------
local function SidebarRow(v, i)
    local row = v.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, v.sidebar)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetTexture(WHITE)
    row.sel = row:CreateTexture(nil, "ARTWORK")
    row.sel:SetPoint("TOPLEFT"); row.sel:SetPoint("BOTTOMLEFT"); row.sel:SetWidth(2)
    row.sel:SetTexture(WHITE)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.text = MakeText(row, 11)
    row.count = MakeText(row, 11)
    row.count:SetJustifyH("RIGHT")
    row.count:SetPoint("RIGHT", -6, 0)
    row:SetScript("OnEnter", function(self) self.hl:SetVertexColor(1, 1, 1, 0.06) end)
    row:SetScript("OnLeave", function(self) self.hl:SetVertexColor(1, 1, 1, self.isSelected and 0.04 or 0) end)
    v.rows[i] = row
    return row
end

local function RenderSidebar(v, counts, total)
    local d = DB()
    local list = {}
    for _, s in ipairs(SPECIAL) do list[#list + 1] = { key = s.key, name = s.name, icon = s.icon, count = counts[s.key] or 0 } end
    for _, c in ipairs(AllCategories()) do
        local n = counts[c.key] or 0
        if not (c.hideEmpty and n == 0) then
            list[#list + 1] = { key = c.key, name = c.name, icon = c.icon, count = n, indent = c.parent and 14 or 0, custom = c.custom, cat = c }
        end
    end
    list[#list + 1] = { key = "__add", name = "Add Category", icon = ICON .. "INV_Misc_QuestionMark", add = true }

    local sr, sg, sb = SkinColors()
    local y = -24
    for i, e in ipairs(list) do
        local row = SidebarRow(v, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", v.sidebar, "TOPLEFT", 4, y)
        row:SetPoint("RIGHT", v.sidebar, "RIGHT", -4, 0)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", 6 + (e.indent or 0), 0)
        row.icon:SetTexture(e.icon)
        row.icon:SetDesaturated(e.add and true or false)
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
        row.text:SetText(e.name)
        row.count:SetText(e.add and "" or tostring(e.count))
        row.isSelected = (d and d.selected == e.key) or false
        row.sel:SetVertexColor(sr, sg, sb, 1)
        row.sel:SetShown(row.isSelected)
        row.hl:SetVertexColor(1, 1, 1, row.isSelected and 0.04 or 0)
        if e.add then
            row.text:SetTextColor(0.55, 0.55, 0.55)
        elseif row.isSelected then
            row.text:SetTextColor(sr, sg, sb)
        else
            row.text:SetTextColor(0.9, 0.9, 0.9)
        end
        row.count:SetTextColor(0.6, 0.6, 0.6)
        row:SetScript("OnClick", function(_, mouseButton)
            if e.add then AddCategoryPopup() return end
            if mouseButton == "RightButton" and e.custom and MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(row, function(_, root)
                    root:CreateTitle(e.name)
                    root:CreateButton("Rename", function() RenamePopup(e.cat) end)
                    root:CreateButton("Delete", function() DeleteCategory(e.key) end)
                end)
                return
            end
            local db = DB()
            if db then db.selected = e.key end
            if v.scroll then v.scroll:SetVerticalScroll(0) end
            Changed()
        end)
        row:Show()
        y = y - ROW_H
    end
    for i = #list + 1, #v.rows do v.rows[i]:Hide() end
    return math.abs(y) + 6
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
-- returns { placed, mirrors, sections, contentW, contentH, viewW, viewH, anchor }
function InventoryView.Compute(win, slots, gridOpts, live, sortOpts, buildDetails)
    local v = EnsureFrames(win)
    local d = DB() or { pinned = {}, hidden = {}, selected = "all", sidebar = true }
    local selected = d.selected or "all"
    if selected ~= "all" and selected ~= "onebag" and selected ~= "pinned" and selected ~= "recent"
        and not CategoryByKey(selected) then
        selected = "all"
        d.selected = "all"
    end

    -- classify
    local counts = { all = 0, onebag = 0, pinned = 0, recent = 0 }
    local leafCells = {}
    local used, total = 0, 0
    local compare = Bags.SortPlanner.MakeComparator(sortOpts or {})
    for seq, cell in ipairs(slots) do
        total = total + 1
        if cell.entry then
            used = used + 1
            local details = buildDetails(cell.entry)
            cell._invDetails = details
            cell._sortDetails = {
                entry = {
                    quality = (details and details.quality) or cell.entry.quality,
                    sortClass = details and details.classID,
                    sortSubClass = details and details.subClassID,
                    ilvl = details and details.ilvl,
                    name = details and details.name,
                    expacID = details and details.expacID,
                    itemID = cell.entry.itemID,
                },
                count = cell.entry.count or 1,
                seq = seq,
            }
            local leaf = InventoryView.Categorize(cell, details, live)
            cell._invLeaf = leaf
            leafCells[leaf] = leafCells[leaf] or {}
            table.insert(leafCells[leaf], cell)
            counts[leaf] = (counts[leaf] or 0) + 1
            local parent = CategoryByKey(leaf)
            if parent and parent.parent then counts[parent.parent] = (counts[parent.parent] or 0) + 1 end
            counts.all = counts.all + 1
            counts.onebag = counts.onebag + 1
            if d.pinned[cell.entry.itemID] then counts.pinned = counts.pinned + 1 end
            if cell._newGuid ~= nil then counts.recent = counts.recent + 1 end
        end
    end
    local function less(a, b) return compare(a._sortDetails, b._sortDetails) end

    local function CellsFor(key)
        local out = {}
        for leaf, list in pairs(leafCells) do
            if Belongs(leaf, key) then
                for _, c in ipairs(list) do out[#out + 1] = c end
            end
        end
        table.sort(out, less)
        return out
    end

    -- sections to show
    local sections = {}
    local function AddSection(sec) sections[#sections + 1] = sec end
    local function PinnedCells()
        local out = {}
        for _, cell in ipairs(slots) do
            if cell.entry and d.pinned[cell.entry.itemID] then out[#out + 1] = cell end
        end
        table.sort(out, less)
        return out
    end
    local function RecentCells()
        local out = {}
        for _, cell in ipairs(slots) do
            if cell.entry and cell._newGuid ~= nil then out[#out + 1] = cell end
        end
        table.sort(out, less)
        return out
    end

    if selected == "onebag" then
        AddSection({ key = "onebag", title = "OneBag", cells = slots, live = true, includeEmpty = true })
    elseif selected == "pinned" then
        AddSection({ key = "pinned", title = "Pinned Items", sub = "Middle Click to Add or Remove", cells = PinnedCells(), live = true, plus = true })
    elseif selected == "recent" then
        AddSection({ key = "recent", title = "Recent Items", cells = RecentCells(), live = true })
    elseif selected == "all" then
        AddSection({ key = "pinned", title = "Pinned Items", sub = "Middle Click to Add or Remove", cells = PinnedCells(), mirror = true, plus = true, hideable = true })
        AddSection({ key = "recent", title = "Recent Items", sub = "Extra quickview display, your items are also in their category", cells = RecentCells(), mirror = true, hideable = true })
        for _, c in ipairs(AllCategories()) do
            if not c.parent then
                local cells = CellsFor(c.key)
                if #cells > 0 or c.custom then
                    AddSection({ key = c.key, title = c.name, cells = cells, live = true, plus = true, count = true })
                end
            end
        end
        -- free slots at the end
        local free = {}
        for _, cell in ipairs(slots) do if not cell.entry then free[#free + 1] = cell end end
        if #free > 0 then
            AddSection({ key = "free", title = "Free Slots", cells = free, live = true, count = true, collapseFree = true })
        end
    else
        local cat = CategoryByKey(selected)
        AddSection({ key = selected, title = cat and cat.name or selected, cells = CellsFor(selected), live = true, plus = true, count = true })
    end

    -- positions (relative to the scroll child)
    local size, gap = gridOpts.iconSize or 36, gridOpts.spacing or 4
    local cols = math.max(1, math.floor(gridOpts.columns or 12))
    local step = size + gap
    local gridW = cols * size + (cols - 1) * gap
    local placed, mirrors = {}, {}
    local y = 0
    for _, sec in ipairs(sections) do
        sec.y = y
        y = y - HEADER_H
        local hidden = sec.hideable and d.hidden[sec.key]
        sec.hidden = hidden
        if not hidden then
            local cells = sec.cells
            if sec.collapseFree and #cells > 1 then
                -- empty slots: show one with the free count
                local first = cells[1]
                first._freeCount = #cells
                cells = { first }
            end
            local n = #cells + (sec.plus and 1 or 0)
            for i, cell in ipairs(cells) do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local entry = { cell = cell, x = col * step, y = y - row * step }
                if sec.mirror then mirrors[#mirrors + 1] = entry else placed[#placed + 1] = entry end
            end
            if sec.plus then
                local i = n
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                sec.plusX, sec.plusY = col * step, y - row * step
            end
            local rows = math.max(1, math.ceil(math.max(n, 1) / cols))
            if n == 0 then rows = 1 end
            y = y - rows * step + gap
        end
        y = y - SECTION_GAP
    end
    local contentH = math.max(1, -y)

    local sidebarOn = d.sidebar ~= false
    local sidebarH = 0
    if sidebarOn then
        v.sidebar:Show()
        sidebarH = RenderSidebar(v, counts, total)
    else
        v.sidebar:Hide()
    end

    local leftW = sidebarOn and (SIDEBAR_W + SIDEBAR_GAP) or 0
    local viewH = math.min(MAX_VIEW_H, math.max(contentH, sidebarH, 200))
    v.scroll:ClearAllPoints()
    v.scroll:SetPoint("TOPLEFT", win._body, "TOPLEFT", leftW, -20)
    v.scroll:SetSize(gridW + 8, viewH)
    v.child:SetSize(gridW + 8, contentH)
    v.sidebar:ClearAllPoints()
    v.sidebar:SetPoint("TOPLEFT", win._body, "TOPLEFT", 0, 0)
    v.sidebar:SetHeight(viewH + 20)
    v.collapse._label:SetText(sidebarOn and "<" or ">")
    v.collapse:ClearAllPoints()
    if sidebarOn then
        v.collapse:SetPoint("TOPRIGHT", v.sidebar, "TOPRIGHT", -4, -4)
    else
        v.collapse:SetPoint("TOPLEFT", win._body, "TOPLEFT", 0, -2)
    end
    v.collapse:Show()
    v.scroll:Show()
    local maxScroll = math.max(0, contentH - viewH)
    if (v.scroll:GetVerticalScroll() or 0) > maxScroll then v.scroll:SetVerticalScroll(maxScroll) end

    -- window title: "Inventory  used / total Items"
    if win._title then
        win._title:SetText(string.format("Inventory  |cff9aa3ad%d / %d Items|r", used, total))
    end

    v.sections = sections
    v.mirrorList = mirrors
    v.selected = selected
    return {
        placed = placed,
        mirrors = mirrors,
        sections = sections,
        anchor = v.child,
        contentW = leftW + gridW + 8,
        contentH = viewH + 20,
        size = size,
    }
end

---------------------------------------------------------------------------
-- After the item buttons are placed: headers, quickview copies, "+" slots
---------------------------------------------------------------------------
local function HeaderFrame(v, i)
    local h = v.headers[i]
    if h then return h end
    h = CreateFrame("Frame", nil, v.child)
    h:SetHeight(HEADER_H)
    h.title = MakeText(h, 12)
    h.title:SetPoint("LEFT", 0, 0)
    h.sub = MakeText(h, 10)
    h.sub:SetPoint("LEFT", h.title, "RIGHT", 6, 0)
    h.sub:SetTextColor(0.55, 0.55, 0.55)
    h.toggle = MakeSmallButton(h, "Hide")
    h.toggle:SetPoint("RIGHT", 0, 0)
    v.headers[i] = h
    return h
end

local function AssignCursorItem(sectionKey)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID then return false end
    local d = DB()
    if not d then return false end
    if sectionKey == "pinned" then
        d.pinned[itemID] = true
    elseif CategoryByKey(sectionKey) then
        d.assign[itemID] = sectionKey
    end
    -- put the item down in a free bag slot if it is still on the cursor
    for _, bag in ipairs({ 0, 1, 2, 3, 4 }) do
        local free = C_Container.GetContainerNumFreeSlots(bag)
        if free and free > 0 then
            local n = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, n do
                if not C_Container.GetContainerItemInfo(bag, slot) then
                    C_Container.PickupContainerItem(bag, slot)
                    break
                end
            end
            break
        end
    end
    ClearCursor()
    Changed()
    return true
end

local function PlusButton(v, i)
    local b = v.plus[i]
    if b then return b end
    b = CreateFrame("Button", nil, v.child)
    Bags.ItemButtons.AddSlotBackground(b)
    UIKit.CreateBorderLines(b)
    b.text = MakeText(b, 18)
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetJustifyH("CENTER")
    b.text:SetText("+")
    b.text:SetTextColor(0.6, 0.6, 0.6)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnReceiveDrag", function(self) AssignCursorItem(self.sectionKey) end)
    b:SetScript("OnClick", function(self) AssignCursorItem(self.sectionKey) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.sectionKey == "pinned" and "Pin an item" or "Add an item to this category")
        GameTooltip:AddLine("Drop an item here (or click with one on the cursor).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    v.plus[i] = b
    return b
end

local function MirrorButton(v, i)
    local b = v.mirrors[i]
    if b then return b end
    b = Bags.ItemButtons.CreateCached(v.child)
    b:RegisterForClicks("LeftButtonUp", "MiddleButtonUp")
    b:SetScript("OnClick", function(self, mouseButton)
        local cell = self._cell
        if not (cell and cell.entry) then return end
        if mouseButton == "MiddleButton" then
            InventoryView.TogglePin(cell.entry.itemID)
        elseif Bags.BagWindow and Bags.BagWindow.FocusItem then
            -- left click: flash the item in its category
            Bags.BagWindow.FocusItem(cell.entry.itemID)
        end
    end)
    v.mirrors[i] = b
    return b
end

function InventoryView.TogglePin(itemID)
    local d = DB()
    if not (d and itemID) then return end
    d.pinned[itemID] = (not d.pinned[itemID]) or nil
    Changed()
end

-- middle-click on a live item button pins / unpins it
function InventoryView.HookButton(btn)
    if btn._h3zPinHooked then return end
    btn._h3zPinHooked = true
    btn:HookScript("OnMouseUp", function(self, mouseButton)
        if mouseButton ~= "MiddleButton" then return end
        local s = GetSettings()
        if not (s and s.appearance and s.appearance.layoutMode == "inventory") then return end
        local bagID, slot = self:GetBagID(), self:GetID()
        local info = bagID and slot and C_Container.GetContainerItemInfo(bagID, slot)
        if info and info.itemID then InventoryView.TogglePin(info.itemID) end
    end)
end

function InventoryView.Finish(win, result, live, matcherFn)
    local v = win._inventory
    if not v then return end
    local sr, sg, sb = SkinColors()
    local size = result.size
    local gridW = (v.child:GetWidth() or 100) - 8
    local d = DB()

    for i, sec in ipairs(result.sections) do
        local h = HeaderFrame(v, i)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", v.child, "TOPLEFT", 0, sec.y)
        h:SetWidth(gridW)
        local n = #sec.cells
        if sec.collapseFree then n = #sec.cells end
        h.title:SetText(sec.count and string.format("%s (%d)", sec.title, n) or sec.title)
        h.title:SetTextColor(sr, sg, sb)
        h.sub:SetText(sec.sub and ("(" .. sec.sub .. ")") or "")
        if sec.hideable then
            h.toggle._label:SetText(sec.hidden and "Show" or "Hide")
            h.toggle:SetScript("OnClick", function()
                if d then d.hidden[sec.key] = not d.hidden[sec.key] or nil end
                Changed()
            end)
            h.toggle:Show()
        else
            h.toggle:Hide()
        end
        h:Show()
    end
    for i = #result.sections + 1, #v.headers do v.headers[i]:Hide() end

    -- quickview copies
    for i, m in ipairs(result.mirrors) do
        local b = MirrorButton(v, i)
        b._cell = m.cell
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", v.child, "TOPLEFT", m.x, m.y)
        local res = matcherFn and matcherFn(m.cell) or nil
        Bags.ItemButtons.DressCached(b, m.cell.entry, res)
        if m.cell.entry and (m.cell.entry.count or 1) > 1 then b._count:SetText(m.cell.entry.count) end
        b:Show()
    end
    for i = #result.mirrors + 1, #v.mirrors do v.mirrors[i]:Hide() end

    -- "+" slots
    local pi = 0
    for _, sec in ipairs(result.sections) do
        if sec.plus and not sec.hidden and sec.plusX then
            pi = pi + 1
            local b = PlusButton(v, pi)
            b.sectionKey = sec.key
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", v.child, "TOPLEFT", sec.plusX, sec.plusY)
            local wr, wg, wb, wa = Helpers.GetWindowColors()
            UIKit.UpdateBorderLines(b, 1, wr, wg, wb, 0.35 * (wa or 1))
            b:Show()
        end
    end
    for i = pi + 1, #v.plus do v.plus[i]:Hide() end

    InventoryView.UpdateScrollBar(v)
end

function InventoryView.HideAll(win)
    local v = win and win._inventory
    if not v then return end
    v.sidebar:Hide()
    v.scroll:Hide()
    v.collapse:Hide()
end

function InventoryView.IsActive()
    local s = GetSettings()
    return s and s.appearance and s.appearance.layoutMode == "inventory" or false
end

return InventoryView
