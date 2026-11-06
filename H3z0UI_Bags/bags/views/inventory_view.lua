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
-- Categories: the shared bag category engine (Bags.Categories), so the
-- Categories settings page (order, hidden, your own categories, items placed
-- by hand, grouping) applies here too
---------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"
local Cat = Bags.Categories

local SPECIAL = {
    { key = "all",    name = "All Items",    icon = ICON .. "INV_Misc_Bag_08" },
    { key = "onebag", name = "OneBag",       icon = ICON .. "INV_Misc_Bag_07" },
    { key = "pinned", name = "Pinned Items", icon = ICON .. "INV_Misc_Note_01" },
    { key = "recent", name = "Recent Items", icon = ICON .. "Spell_Holy_BorrowedTime" },
}
local IS_SPECIAL = { all = true, onebag = true, pinned = true, recent = true }

-- the older Inventory-only categories, moved to the shared engine once
local OLD_TO_NEW = {
    weapons = "weapon", armor = "armor", itemset = "sets", consumables = "consumable",
    professions = "tradegoods", reagentbag = "reagentbag", quest = "quest",
    junk = "junk", misc = "misc", armory = "weapon", prep = "consumable",
}

-- The view is used by the bag window ("inventory") and by the bank window ("bankInventory").
-- CTX says which one is being worked on: where its settings live, what to refresh, and (for the
-- bank) how far down the view starts. It is set at the start of every entry point.
local BAG_CTX = { key = "inventory" }
local CTX = BAG_CTX

local function DB()
    local s = GetSettings()
    if not s then return nil end
    local ckey = CTX.key or "inventory"
    s[ckey] = s[ckey] or {}
    local d = s[ckey]
    d.pinned = d.pinned or {}
    d.hidden = d.hidden or {}
    if d.sidebar == nil then d.sidebar = true end
    d.selected = d.selected or "all"
    if ckey == "inventory" and not d.movedToCategories and Cat then
        d.movedToCategories = true
        local map = {}
        for _, cc in ipairs(d.custom or {}) do
            if cc.key and cc.name then map[cc.key] = Cat.AddCustom(cc.name, "") end
        end
        local cdb = Cat.DB()
        for itemID, key in pairs(d.assign or {}) do
            local nk = map[key] or OLD_TO_NEW[key]
            if nk and cdb and cdb.assign[itemID] == nil then cdb.assign[itemID] = nk end
        end
        d.selected = map[d.selected] or OLD_TO_NEW[d.selected] or d.selected
    end
    return d
end

local version = 0
local function Changed()
    version = version + 1
    if CTX.refresh then CTX.refresh() return end
    if Bags.BagWindow and Bags.BagWindow.Refresh then Bags.BagWindow.Refresh() end
end

function InventoryView.Signature(ctx)
    CTX = ctx or BAG_CTX
    local d = DB()
    return table.concat({ "inv", version, d and d.selected or "", d and tostring(d.sidebar) or "" }, ":")
end

local function CategoryExists(key)
    return Cat and Cat.Exists(key) or false
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
    local ctx = CTX
    H3z0UI_ShowPopup({
        text = "New category name:",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 32,
        OnAccept = function(_, _, name)
            if not name or name == "" or not Cat then return end
            CTX = ctx
            Cat.AddCustom(name, "")
            Changed()
        end,
    })
end

local function RenamePopup(key)
    local ctx = CTX
    H3z0UI_ShowPopup({
        text = "Rename category:",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 32,
        editText = Cat and Cat.Name(key) or "",
        OnAccept = function(_, _, name)
            CTX = ctx
            if Cat then Cat.Rename(key, name) end
            Changed()
        end,
    })
end

local function SearchPopup(key)
    local ctx = CTX
    local cdb = Cat and Cat.DB()
    local def = cdb and cdb.custom[key]
    if not def then return end
    H3z0UI_ShowPopup({
        text = "Search text for " .. (def.name or "") .. " (for example #potion|#flask):",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 200,
        editText = def.search or "",
        OnAccept = function(_, _, value)
            CTX = ctx
            Cat.SetSearch(key, value)
            Changed()
        end,
    })
end

local function DeleteCategory(key)
    if Cat then Cat.DeleteCustom(key) end
    local d = DB()
    if d and d.selected == key then d.selected = "all" end
    Changed()
end

local function EnsureFrames(win, ctx)
    local v = win._inventory
    if v then return v end
    v = {}
    v.ctx = ctx or BAG_CTX
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
        CTX = v.ctx
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

-- the scrolling area's content frame (built on first use); the bag window parents
-- its item holders here before combat so a bag opened in combat still scrolls
function InventoryView.GetAnchor(win, ctx)
    local v = EnsureFrames(win, ctx)
    return v and v.child
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

local function RenderSidebar(v, counts, catList)
    CTX = v.ctx
    local d = DB()
    local list = {}
    for _, sp in ipairs(SPECIAL) do list[#list + 1] = { key = sp.key, name = (sp.key == "onebag" and CTX.oneName) or sp.name, icon = sp.icon, count = counts[sp.key] or 0 } end
    for _, c in ipairs(catList) do list[#list + 1] = c end
    list[#list + 1] = { key = "__add", name = "Add Category", icon = ICON .. "INV_Misc_QuestionMark", add = true }

    local sr, sg, sb = SkinColors()
    local y = -24
    for i, e in ipairs(list) do
        local row = SidebarRow(v, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", v.sidebar, "TOPLEFT", 4, y)
        row:SetPoint("RIGHT", v.sidebar, "RIGHT", -4, 0)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:SetTexture(e.icon)
        row.icon:SetDesaturated(e.add and true or false)
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
        row.text:SetText(e.name)
        row.count:SetText(e.add and "" or tostring(e.count or 0))
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
            CTX = v.ctx
            if e.add then AddCategoryPopup() return end
            if mouseButton == "RightButton" and not IS_SPECIAL[e.key] and Cat
                and MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(row, function(_, root)
                    root:CreateTitle(e.name)
                    if not (Cat.PINNED_TOP and Cat.PINNED_TOP[e.key]) then
                        root:CreateButton("Move Up", function() Cat.Move(e.key, -1); Changed() end)
                        root:CreateButton("Move Down", function() Cat.Move(e.key, 1); Changed() end)
                    end
                    root:CreateButton("Hide Category", function() Cat.SetHidden(e.key, true); Changed() end)
                    if e.custom then
                        root:CreateButton("Rename", function() RenamePopup(e.key) end)
                        root:CreateButton("Search Text", function() SearchPopup(e.key) end)
                        root:CreateButton("Delete", function() DeleteCategory(e.key) end)
                    end
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
function InventoryView.Compute(win, slots, gridOpts, live, sortOpts, buildDetails, ctx)
    CTX = ctx or BAG_CTX
    local v = EnsureFrames(win, CTX)
    v.ctx = CTX
    local top = CTX.top or 0
    local d = DB() or { pinned = {}, hidden = {}, selected = "all", sidebar = true }
    local selected = d.selected or "all"
    if not IS_SPECIAL[selected] and not CategoryExists(selected) then
        selected = "all"
        d.selected = "all"
    end

    -- All Items: new items are real (usable) buttons in Recent and join their
    -- own category once they are no longer new
    local recentLive = (selected == "all") and not (d.hidden and d.hidden.recent)
    local used, total = 0, 0
    for _, cell in ipairs(slots) do
        total = total + 1
        if cell.entry then used = used + 1 end
        cell.recent = recentLive and cell._newGuid ~= nil or false
    end

    local groups = Cat and Cat.Group(slots, buildDetails, sortOpts or {}, live) or {}
    local byKey = {}
    for _, g in ipairs(groups) do byKey[g.key] = g end

    local compare = Bags.SortPlanner.MakeComparator(sortOpts or {})
    local function sortDetails(cell)
        local details = buildDetails(cell.entry)
        return {
            entry = {
                quality = (details and details.quality) or cell.entry.quality,
                sortClass = details and details.classID, sortSubClass = details and details.subClassID,
                ilvl = details and details.ilvl, name = details and details.name,
                expacID = details and details.expacID, itemID = cell.entry.itemID,
            },
            count = cell.entry.count or 1, seq = 0,
        }
    end
    local function SortedCopy(list)
        local out, keyOf = {}, {}
        for _, c in ipairs(list) do out[#out + 1] = c; keyOf[c] = sortDetails(c) end
        table.sort(out, function(x, y) return compare(keyOf[x], keyOf[y]) end)
        return out
    end

    -- counts for the sidebar
    local counts = { all = used, onebag = used, pinned = 0, recent = 0 }
    for _, cell in ipairs(slots) do
        if cell.entry then
            if d.pinned[cell.entry.itemID] then counts.pinned = counts.pinned + 1 end
            if cell._newGuid ~= nil then counts.recent = counts.recent + 1 end
        end
    end
    local catList = {}
    for _, key in ipairs(Cat and Cat.Order() or {}) do
        if key ~= "recent" and key ~= "empty" and not Cat.IsHidden(key) then
            local g = byKey[key]
            local n = 0
            for _, c in ipairs(g and g.cells or {}) do n = n + 1 end
            if n > 0 or Cat.IsCustom(key) then
                catList[#catList + 1] = { key = key, name = Cat.Name(key), icon = Cat.Icon(key),
                    count = n, custom = Cat.IsCustom(key) }
            end
        end
    end

    -- sections to show
    local sections = {}
    local function AddSection(sec) sections[#sections + 1] = sec end
    local function PinnedCells()
        local out = {}
        for _, cell in ipairs(slots) do
            if cell.entry and d.pinned[cell.entry.itemID] then out[#out + 1] = cell end
        end
        return SortedCopy(out)
    end
    local function RecentCells()
        local out = {}
        for _, cell in ipairs(slots) do
            if cell.entry and cell._newGuid ~= nil then out[#out + 1] = cell end
        end
        return SortedCopy(out)
    end
    local function CategorySection(key)
        local g = byKey[key]
        AddSection({ key = key, title = Cat.Name(key), cells = g and g.cells or {}, live = true, plus = true, count = true })
    end

    if selected == "onebag" then
        AddSection({ key = "onebag", title = CTX.oneName or "OneBag", cells = slots, live = true, includeEmpty = true })
    elseif selected == "pinned" then
        AddSection({ key = "pinned", title = "Pinned Items", sub = "Middle Click to Add or Remove", cells = PinnedCells(), live = true, plus = true })
    elseif selected == "recent" then
        AddSection({ key = "recent", title = "Recent Items", cells = RecentCells(), live = true })
    elseif selected == "all" then
        -- Hearthstone and Keystone always on top
        for _, key in ipairs({ "hearth", "keystone" }) do
            if byKey[key] and #byKey[key].cells > 0 then CategorySection(key) end
        end
        AddSection({ key = "pinned", title = "Pinned Items", sub = "Middle Click to Add or Remove", cells = PinnedCells(), mirror = true, plus = true, hideable = true })
        AddSection({ key = "recent", title = "Recent Items", sub = "New items - use them right here; they move to their category after a while", cells = (byKey.recent and byKey.recent.cells) or {}, live = true, hideable = true })
        for _, c in ipairs(catList) do
            if c.key ~= "hearth" and c.key ~= "keystone" then CategorySection(c.key) end
        end
        -- free slots at the end
        local free = byKey.empty and byKey.empty.cells or {}
        if #free > 0 then
            AddSection({ key = "free", title = "Free Slots", cells = free, live = true, count = true })
        end
    else
        CategorySection(selected)
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
        sidebarH = RenderSidebar(v, counts, catList)
    else
        v.sidebar:Hide()
    end

    local leftW = sidebarOn and (SIDEBAR_W + SIDEBAR_GAP) or 0
    local viewH = math.min(MAX_VIEW_H, math.max(contentH, sidebarH, 200))
    v.scroll:ClearAllPoints()
    v.scroll:SetPoint("TOPLEFT", win._body, "TOPLEFT", leftW, -20 - top)
    v.scroll:SetSize(gridW + 8, viewH)
    v.child:SetSize(gridW + 8, contentH)
    v.sidebar:ClearAllPoints()
    v.sidebar:SetPoint("TOPLEFT", win._body, "TOPLEFT", 0, -top)
    v.sidebar:SetHeight(viewH + 20)
    v.collapse._label:SetText(sidebarOn and "<" or ">")
    v.collapse:ClearAllPoints()
    if sidebarOn then
        v.collapse:SetPoint("TOPRIGHT", v.sidebar, "TOPRIGHT", -4, -4)
    else
        v.collapse:SetPoint("TOPLEFT", win._body, "TOPLEFT", 0, -2 - top)
    end
    v.collapse:Show()
    v.scroll:Show()
    local maxScroll = math.max(0, contentH - viewH)
    if (v.scroll:GetVerticalScroll() or 0) > maxScroll then v.scroll:SetVerticalScroll(maxScroll) end

    -- window title: "Inventory  used / total Items"
    if win._title and not CTX.keepTitle then
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
    elseif CategoryExists(sectionKey) and Cat then
        Cat.Assign(itemID, sectionKey)
    end
    -- put the item down in a free bag slot if it is still on the cursor (the bag window only:
    -- from the bank, clearing the cursor leaves the item where it was)
    for _, bag in ipairs(CTX.key == "inventory" and { 0, 1, 2, 3, 4 } or {}) do
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
    b:SetScript("OnReceiveDrag", function(self) CTX = v.ctx; AssignCursorItem(self.sectionKey) end)
    b:SetScript("OnClick", function(self) CTX = v.ctx; AssignCursorItem(self.sectionKey) end)
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
        CTX = v.ctx
        local cell = self._cell
        if not (cell and cell.entry) then return end
        if mouseButton == "MiddleButton" then
            InventoryView.TogglePin(cell.entry.itemID)
        elseif CTX.focus then
            CTX.focus(cell.entry.itemID)
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
function InventoryView.HookButton(btn, ctx)
    if btn._h3zPinHooked then return end
    btn._h3zPinHooked = true
    ctx = ctx or BAG_CTX
    btn:HookScript("OnMouseUp", function(self, mouseButton)
        if mouseButton ~= "MiddleButton" then return end
        local s = GetSettings()
        if not (s and s.appearance and s.appearance.layoutMode == "inventory") then return end
        -- the bank pins only while it shows this layout (not in its plain grid)
        if ctx.active and not ctx.active() then return end
        CTX = ctx
        local bagID, slot = self:GetBagID(), self:GetID()
        local info = bagID and slot and C_Container.GetContainerItemInfo(bagID, slot)
        if info and info.itemID then InventoryView.TogglePin(info.itemID) end
    end)
end

function InventoryView.Finish(win, result, live, matcherFn)
    local v = win._inventory
    if not v then return end
    CTX = v.ctx
    local sr, sg, sb = SkinColors()
    local size = result.size
    local gridW = (v.child:GetWidth() or 100) - 8
    local d = DB()

    for i, sec in ipairs(result.sections) do
        local h = HeaderFrame(v, i)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", v.child, "TOPLEFT", 0, sec.y)
        h:SetWidth(gridW)
        local n = 0
        for _, c in ipairs(sec.cells) do n = n + (c._freeCount or 1) end
        h.title:SetText(sec.count and string.format("%s (%d)", sec.title, n) or sec.title)
        h.title:SetTextColor(sr, sg, sb)
        h.sub:SetText(sec.sub and ("(" .. sec.sub .. ")") or "")
        if sec.hideable then
            h.toggle._label:SetText(sec.hidden and "Show" or "Hide")
            h.toggle:SetScript("OnClick", function()
                CTX = v.ctx
                d = DB()
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
