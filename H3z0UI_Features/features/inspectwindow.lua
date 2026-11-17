---------------------------------------------------------------------------
-- H3z0 UI - Inspect Window (WoW: Forever, Classic and Midnight)
--
-- Same idea as the H3z0 character window, for another player's gear:
--   header   name, "Level N Race Class", guild, close
--   slots    eight per side round their model, weapons (and ammo) underneath;
--            quality outline, name in quality colour, Item Level under it
--   model    their character (drag to turn it)
--   summary  average item level, items by quality, talent points per tree
--   footer   average item level, H3z0 UI logo
--
-- The game's InspectFrame keeps working underneath, kept out of sight
-- ("parked"), so right-click > Inspect and the keybind work as usual and
-- this window follows it. Every slot here is our own frame: hover for the
-- tooltip, Shift-click links the item, Ctrl-click tries it on.
--
-- Midnight (see the character window for the reasons): the game's window is
-- not moved away but stays in place, see-through, under this one; the tabs
-- and the X are secure buttons pressing the game's own; names, guids and
-- other values that can be secret there are never compared.
--
-- Settings: profile.character.h3zInspectWindow (on by default).
-- /h3z0 inspectwindow switches it.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local LEGACY = ns.Client and ns.Client.isLegacy and true or false
-- item functions moved into C_Item on newer clients (Midnight); the old names on Forever / Classic
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or _G.GetDetailedItemLevelInfo
local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon
local MIDNIGHT = not LEGACY
local function IsSecret(v) return issecretvalue and v ~= nil and issecretvalue(v) or false end
-- a guid we can compare (secret ones are never compared)
local function PlainGUID(u)
    local ok, g = pcall(UnitGUID, u or "")
    if ok and type(g) == "string" and not IsSecret(g) then return g end
    return nil
end

local IW = {}
ns.H3z0InspectWindow = IW

local WIN_W, WIN_H = 760, 520
local EDGE, HEADER, FOOTER = 16, 56, 34
local ROW, ICON, COL = 46, 38, 170
local SUMMARY_W = 190

local function Scale()
    local SH = ns.H3zCWShared
    return SH and SH.Scale() or 1
end

local function Colors()
    local G = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    return {
        accent = G and G.accent or { 0.204, 0.827, 0.6, 1 },
        text = { 0.95, 0.96, 0.97 },
        label = { 0.70, 0.73, 0.77 },
        dim = { 0.50, 0.53, 0.57 },
        up = { 0.45, 0.9, 0.45 },
        head = { 1, 0.62, 0.25 },
    }
end

local function Font()
    local H = ns.Helpers
    if H and H.GetGeneralFont then
        local ok, f = pcall(H.GetGeneralFont)
        if ok and f then return f end
    end
    return STANDARD_TEXT_FONT
end

local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Font(), size or 12, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Panel(parent, radius, fill, alpha)
    local R = ns.Round
    if R and R.Panel then
        local p = R.Panel(parent, radius or 8)
        local f = fill or R.SLATE_FILL or { 0.075, 0.095, 0.12 }
        p:SetFillColor(f[1], f[2], f[3], alpha or 0.97)
        local e = R.SLATE_BORDER or { 0.25, 0.29, 0.33 }
        p:SetBorderColor(e[1], e[2], e[3], 1)
        return p
    end
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    p:SetBackdropColor(0.075, 0.095, 0.12, alpha or 0.97)
    p:SetBackdropBorderColor(0.25, 0.29, 0.33, 1)
    return p
end

local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.character = p.character or {}
    if p.character.h3zInspectWindow == nil then p.character.h3zInspectWindow = true end
    return p.character
end

local function Enabled()
    local s = Settings()
    return s and s.h3zInspectWindow ~= false
end

local function Secret(v) return issecretvalue and v ~= nil and issecretvalue(v) or false end

---------------------------------------------------------------------------
-- slots
---------------------------------------------------------------------------
local LEFT = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local WEAPONS = { "MainHand", "SecondaryHand", "Ranged" }
local LABEL_GLOBAL = {
    Head = "HEADSLOT", Neck = "NECKSLOT", Shoulder = "SHOULDERSLOT", Back = "BACKSLOT", Chest = "CHESTSLOT",
    Shirt = "SHIRTSLOT", Tabard = "TABARDSLOT", Wrist = "WRISTSLOT", Hands = "HANDSSLOT", Waist = "WAISTSLOT",
    Legs = "LEGSSLOT", Feet = "FEETSLOT", Finger0 = "FINGER0SLOT", Finger1 = "FINGER1SLOT",
    Trinket0 = "TRINKET0SLOT", Trinket1 = "TRINKET1SLOT", MainHand = "MAINHANDSLOT",
    SecondaryHand = "SECONDARYHANDSLOT", Ranged = "RANGEDSLOT", Ammo = "AMMOSLOT",
}
local NO_ILVL = { Shirt = true, Tabard = true, Ammo = true }

local function SlotInfo(key)
    local ok, id, empty = pcall(GetInventorySlotInfo, key .. "Slot")
    if ok and id then return id, empty end
    return nil
end

local function SlotLabel(key)
    local t = LABEL_GLOBAL[key] and _G[LABEL_GLOBAL[key]]
    if type(t) == "string" and t ~= "" then return t end
    return key
end

local function QualityColor(q)
    if q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
        local c = ITEM_QUALITY_COLORS[q]
        return c.r, c.g, c.b
    end
    return 0.85, 0.85, 0.85
end

local win
local LayoutTabs          -- defined further down, used by UpdateAll
local views = {}
local unit = "target"
-- The window stays on the player you inspected. The game often keeps them as "target", so
-- clicking someone else would switch the window to them. We remember who it is and look them up
-- by that; when nobody near points at them any more, the window keeps what it shows.
local lockedGuid
local function ResolveUnit()
    local own = (InspectFrame and InspectFrame.unit) or "target"
    if not lockedGuid then
        -- Midnight: their guid was secret, so nothing to lock on; use the game's own unit
        if MIDNIGHT and UnitExists(own) then return own end
        return nil
    end
    local tries = { own, "target", "mouseover", "focus" }
    for i = 1, 4 do tries[#tries + 1] = "party" .. i end
    for i = 1, 40 do tries[#tries + 1] = "raid" .. i end
    for _, u in ipairs(tries) do
        if PlainGUID(u) == lockedGuid then return u end
    end
    return nil
end

local function NewSlot(key, side)
    local C = Colors()
    local v = CreateFrame("Frame", nil, win.body)
    v.key, v.side = key, side
    v:SetSize(side == "weapon" and 150 or COL, ICON)
    local ic = CreateFrame("Frame", nil, v)
    ic:SetSize(ICON, ICON)
    v.iconFrame = ic
    v.outline = ic:CreateTexture(nil, "BACKGROUND")
    v.outline:SetAllPoints()
    v.icon = ic:CreateTexture(nil, "ARTWORK")
    v.icon:SetPoint("TOPLEFT", 1, -1)
    v.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    v.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    v.hl = ic:CreateTexture(nil, "OVERLAY")
    v.hl:SetAllPoints(v.icon)
    v.hl:SetColorTexture(1, 1, 1, 0.18)
    v.hl:Hide()
    v.name = Text(v, 12, "LEFT")
    v.detail = Text(v, 11, "LEFT")
    if side == "right" then
        ic:SetPoint("RIGHT", v, "RIGHT", 0, 0)
        v.name:SetPoint("BOTTOMRIGHT", ic, "LEFT", -8, 1)
        v.name:SetPoint("LEFT", v, "LEFT", 0, 0)
        v.name:SetJustifyH("RIGHT")
        v.detail:SetPoint("TOPRIGHT", ic, "LEFT", -8, -2)
        v.detail:SetPoint("LEFT", v, "LEFT", 0, 0)
        v.detail:SetJustifyH("RIGHT")
    else
        ic:SetPoint("LEFT", v, "LEFT", 0, 0)
        v.name:SetPoint("BOTTOMLEFT", ic, "RIGHT", 8, 1)
        v.name:SetPoint("RIGHT", v, "RIGHT", 0, 0)
        v.detail:SetPoint("TOPLEFT", ic, "RIGHT", 8, -2)
        v.detail:SetPoint("RIGHT", v, "RIGHT", 0, 0)
    end
    v.slotId, v.emptyTex = SlotInfo(key)

    ic:EnableMouse(true)
    ic.slotView = v
    ic:SetScript("OnEnter", function(self)
        v.hl:Show()
        IW.hovered = self
        IW.ShowSlotTip(self)
    end)
    ic:SetScript("OnLeave", function() v.hl:Hide() IW.hovered = nil GameTooltip:Hide() end)
    ic:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not v.slotId then return end
        local u = ResolveUnit()
        local link = (u and GetInventoryItemLink(u, v.slotId)) or v.link
        if not link then return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
            ChatEdit_InsertLink(link)
        elseif IsModifiedClick and IsModifiedClick("DRESSUP") and DressUpItemLink then
            DressUpItemLink(link)
        end
    end)
    views[key] = v
    return v
end

---------------------------------------------------------------------------
-- item tooltips: only their item; your own item to compare only while Shift is held
---------------------------------------------------------------------------
local function OurOwner()
    local o = GameTooltip:GetOwner()
    return o and o.slotView and IW.hovered == o
end

local function CompareHeld()
    if IsModifiedClick then
        local ok, on = pcall(IsModifiedClick, "COMPAREITEMS")
        if ok and on then return true end
    end
    return IsShiftKeyDown and IsShiftKeyDown() or false
end

local function HideCompare()
    local list = GameTooltip.shoppingTooltips or { _G.ShoppingTooltip1, _G.ShoppingTooltip2 }
    for _, t in ipairs(list) do if t and t:IsShown() then t:Hide() end end
end

function IW.ShowSlotTip(ic)
    local v = ic.slotView
    if not v then return end
    GameTooltip:SetOwner(ic, v.side == "right" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    if v.slotId then
        local u = ResolveUnit()
        local has = u and GameTooltip:SetInventoryItem(u, v.slotId)
        if not has and v.link then GameTooltip:SetHyperlink(v.link) has = true end
        if not has then GameTooltip:SetText(SlotLabel(v.key)) end
    end
    GameTooltip:Show()
    if CompareHeld() then
        if GameTooltip_ShowCompareItem then pcall(GameTooltip_ShowCompareItem, GameTooltip) end
    else
        HideCompare()
    end
end

-- the game (or the "always compare items" option) can open the compare tooltips by itself:
-- on our icons they only stay while Shift is held
do
    local function Guard(t)
        if t and t.HookScript then
            t:HookScript("OnShow", function(self)
                if OurOwner() and not CompareHeld() then self:Hide() end
            end)
        end
    end
    Guard(_G.ShoppingTooltip1)
    Guard(_G.ShoppingTooltip2)
    local mod = CreateFrame("Frame")
    mod:RegisterEvent("MODIFIER_STATE_CHANGED")
    mod:SetScript("OnEvent", function()
        if IW.hovered and IW.hovered:IsMouseOver() then IW.ShowSlotTip(IW.hovered) end
    end)
end

local function UpdateSlot(v)
    local C = Colors()
    if not v.slotId then v:Hide() return end
    v:Show()
    local link = GetInventoryItemLink(unit, v.slotId)
    if link then
        local name, _, quality, ilvl = GetItemInfo(link)
        if GetDetailedItemLevelInfo then
            local ok, eff = pcall(GetDetailedItemLevelInfo, link)
            if ok and type(eff) == "number" and not IsSecret(eff) and eff > 0 then ilvl = eff end
        end
        quality = quality or GetInventoryItemQuality(unit, v.slotId)
        local r, g, b = QualityColor(quality)
        v.icon:SetTexture(GetInventoryItemTexture(unit, v.slotId) or (GetItemIcon and GetItemIcon(link)))
        v.icon:SetDesaturated(false)
        v.icon:SetAlpha(1)
        v.outline:SetColorTexture(r, g, b, 1)
        if v.isAmmo then
            local count = GetInventoryItemCount(unit, v.slotId)
            v.detail:SetText((type(count) == "number" and count > 1) and count or "")
            v.detail:SetTextColor(1, 1, 1)
        else
            v.name:SetText(name or "")
            v.name:SetTextColor(r, g, b)
            -- item level, then the upgrade track ("Hero 4/6"): the same settings as the character window
            local SH = ns.H3zCWShared
            local detail
            if SH then
                detail = SH.DetailText(unit, v.slotId, link, ilvl, NO_ILVL[v.key], r, g, b)
            elseif ilvl then
                local ok, t = pcall(string.format, _G.ITEM_LEVEL or "Item Level %d", ilvl)
                detail = ok and t or tostring(ilvl)
            end
            v.detail:SetText(detail or "")
            v.detail:SetTextColor(C.label[1], C.label[2], C.label[3])
            if SH then
                local o = SH.Settings() or {}
                SH.Arrange(v, o.cwNames ~= false, (detail or "") ~= "", Font())
            end
        end
        v.ilvl, v.quality, v.link = ilvl, quality, link
    else
        v.icon:SetTexture(v.emptyTex)
        v.icon:SetDesaturated(true)
        v.icon:SetAlpha(0.45)
        v.outline:SetColorTexture(0.22, 0.24, 0.27, 1)
        if not v.isAmmo then
            v.name:SetText(SlotLabel(v.key))
            v.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
            v.detail:SetText(_G.EMPTY or "Empty")
            v.detail:SetTextColor(0.4, 0.42, 0.45)
            local SH = ns.H3zCWShared
            if SH then
                local o = SH.Settings() or {}
                SH.Arrange(v, o.cwNames ~= false, true, Font())
            end
        else
            v.detail:SetText("")
        end
        v.ilvl, v.quality, v.link = nil, nil, nil
    end
end

---------------------------------------------------------------------------
-- summary on the right
---------------------------------------------------------------------------
local function AverageItemLevel()
    if MIDNIGHT and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, v = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if ok and type(v) == "number" and not IsSecret(v) and v > 0 then return v end
    end
    local sum, n, twoHand = 0, 0, false
    for key, v in pairs(views) do
        if v.ilvl and not NO_ILVL[key] then sum, n = sum + v.ilvl, n + 1 end
    end
    local mh = views.MainHand
    if mh and mh.slotId then
        local link = GetInventoryItemLink(unit, mh.slotId)
        local loc = link and select(9, GetItemInfo(link))
        if loc == "INVTYPE_2HWEAPON" and mh.ilvl and not (views.SecondaryHand and views.SecondaryHand.ilvl) then
            sum, n = sum + mh.ilvl, n + 1
        end
    end
    return n > 0 and sum / n or 0
end

local function Talents()
    local out = {}
    if MIDNIGHT then
        local ok, id = pcall(GetInspectSpecialization, unit)
        if ok and type(id) == "number" and not IsSecret(id) and id > 0 and GetSpecializationInfoByID then
            local r = { pcall(GetSpecializationInfoByID, id) }
            if r[1] and type(r[3]) == "string" then out[1] = { _G.SPECIALIZATION or "Specialization", r[3] } end
        end
        return out
    end
    local num = GetNumTalentTabs and select(2, pcall(GetNumTalentTabs, true, false))
    if type(num) ~= "number" then return out end
    for i = 1, num do
        local r = { pcall(GetTalentTabInfo, i, true, false) }
        if r[1] then
            local name, points
            -- classic: name, icon, points, ... ; newer: id, name, description, icon, points, ...
            if type(r[2]) == "string" then name, points = r[2], r[4]
            else name, points = r[3], r[6] end
            if type(name) == "string" and type(points) == "number" and not Secret(points) then
                out[#out + 1] = { name, points }
            end
        end
    end
    return out
end

local function Line(i)
    local l = win.lines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, win.summary)
    l:SetHeight(18)
    l.label = Text(l, 12, "LEFT")
    l.label:SetPoint("LEFT", 4, 0)
    l.value = Text(l, 12, "RIGHT")
    l.value:SetPoint("RIGHT", -4, 0)
    l.label:SetPoint("RIGHT", l.value, "LEFT", -6, 0)
    l.head = Text(l, 13, "LEFT")
    l.head:SetPoint("LEFT", 0, 0)
    l.rule = l:CreateTexture(nil, "ARTWORK")
    l.rule:SetHeight(1)
    l.rule:SetPoint("BOTTOMLEFT", 0, 0)
    l.rule:SetPoint("BOTTOMRIGHT", 0, 0)
    win.lines[i] = l
    return l
end

local function UpdateSummary()
    local C = Colors()
    for _, l in ipairs(win.lines) do l:Hide() end
    local rows = {}
    local function Head(t) rows[#rows + 1] = { head = t } end
    local function Row(a, b, r, g, bl) rows[#rows + 1] = { a, b, r, g, bl } end

    Head(_G.EQUIPMENT or "Equipment")
    Row(_G.STAT_AVERAGE_ITEM_LEVEL or "Item Level", string.format("%.1f", AverageItemLevel()), C.up[1], C.up[2], C.up[3])
    local counts = {}
    for key, v in pairs(views) do
        if v.quality and not NO_ILVL[key] then counts[v.quality] = (counts[v.quality] or 0) + 1 end
    end
    for q = 7, 1, -1 do
        if counts[q] then
            local label = _G["ITEM_QUALITY" .. q .. "_DESC"] or ("Quality " .. q)
            local r, g, b = QualityColor(q)
            Row(label, tostring(counts[q]), r, g, b)
        end
    end
    local t = Talents()
    if #t > 0 then
        Head(_G.TALENTS or "Talents")
        for _, row in ipairs(t) do Row(row[1], tostring(row[2])) end
    end

    local y = 0
    local w = win.summary:GetWidth() - 20
    for i, r in ipairs(rows) do
        local l = Line(i)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", win.summary, "TOPLEFT", 10, -10 - y)
        l:SetWidth(w)
        if r.head then
            if i > 1 then y = y + 6 l:SetPoint("TOPLEFT", win.summary, "TOPLEFT", 10, -10 - y) end
            l:SetHeight(24)
            l.head:SetText(r.head)
            l.head:SetTextColor(C.head[1], C.head[2], C.head[3])
            l.head:Show()
            l.label:Hide() l.value:Hide()
            l.rule:SetColorTexture(C.head[1], C.head[2], C.head[3], 0.55)
            l.rule:Show()
            y = y + 24
        else
            l:SetHeight(18)
            l.head:Hide() l.rule:Hide()
            l.label:SetText(r[1])
            l.label:SetTextColor(C.label[1], C.label[2], C.label[3])
            l.value:SetText(r[2])
            l.value:SetTextColor(r[3] or C.text[1], r[4] or C.text[2], r[5] or C.text[3])
            l.label:Show() l.value:Show()
            y = y + 18
        end
        l:Show()
    end
end

---------------------------------------------------------------------------
-- window
---------------------------------------------------------------------------
local function LayoutWeapons()
    local shown = {}
    for _, key in ipairs(WEAPONS) do
        local v = views[key]
        if v and v.slotId then shown[#shown + 1] = v end
    end
    for i, v in ipairs(shown) do
        v:ClearAllPoints()
        v:SetPoint("TOP", win.modelBox, "BOTTOM", (i - (#shown + 1) / 2) * 150, -8)
    end
    local ammo, ranged = views.Ammo, views.Ranged
    if ammo and ranged then
        ammo:ClearAllPoints()
        ammo:SetPoint("LEFT", ranged, "RIGHT", 6, 0)
    end
end

local function Build()
    if win then return win end
    local C = Colors()
    -- Midnight: part of the game's inspect window, so the game shows and hides it (with its secure
    -- tab buttons) and no addon code has to; placed once, visible while the game's window is see-through
    win = CreateFrame("Frame", "H3z0UI_InspectWindow", MIDNIGHT and InspectFrame or UIParent)
    -- Escape closes it, and however it closes, the game's inspect window closes with it
    if LEGACY and type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "H3z0UI_InspectWindow") end
    win:SetScript("OnHide", function()
        if MIDNIGHT then return end   -- Midnight: Escape and the X close the game's window the game's way
        local g = InspectFrame
        if g and g:IsShown() then
            IW.closedByUs = true
            if InCombatLockdown() then
                IW.wantClosed = true          -- the game's window closes after combat
            else
                pcall(HideUIPanel, g)
                if g:IsShown() then g:Hide() end
            end
        end
    end)
    win:SetSize(WIN_W, WIN_H)
    if MIDNIGHT then
        if win.SetIgnoreParentAlpha then win:SetIgnoreParentAlpha(true) end
        win:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 0, 0)
        win:SetFrameLevel(math.min(9000, (InspectFrame:GetFrameLevel() or 1) + 40))
    else
        win:SetFrameStrata("MEDIUM")
        win:SetToplevel(true)
        win:SetClampedToScreen(true)
        win:Hide()
    end
    win:EnableMouse(true)
    local bg = Panel(win, 10)
    bg:SetAllPoints(win)
    bg:SetFrameLevel(math.max(0, win:GetFrameLevel() - 1))

    -- name, level and guild centered over their character
    local bodyW = WIN_W - 2 * EDGE
    local modelW = bodyW - (SUMMARY_W + 10 + COL + 8) - (COL + 8)
    local centerX = EDGE + COL + 8 + modelW / 2
    win.name = Text(win, 17, "CENTER")
    win.name:SetPoint("TOP", win, "TOPLEFT", centerX, -10)
    win.sub = Text(win, 11, "CENTER")
    win.sub:SetPoint("TOP", win.name, "BOTTOM", 0, -3)
    win.sub:SetTextColor(C.label[1], C.label[2], C.label[3])
    win.guild = Text(win, 11, "CENTER")
    win.guild:SetPoint("TOP", win.sub, "BOTTOM", 0, -2)
    win.guild:SetTextColor(0.45, 0.9, 0.45)

    local close = CreateFrame("Button", nil, win)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -10)
    local x = Text(close, 15, "CENTER")
    x:SetAllPoints()
    x:SetText("x")
    x:SetTextColor(C.label[1], C.label[2], C.label[3])
    close:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() x:SetTextColor(C.label[1], C.label[2], C.label[3]) end)
    close:SetFrameLevel(win:GetFrameLevel() + 250)   -- above the pages, which can reach up here
    close:SetScript("OnClick", function() if LEGACY then win:Hide() end end)
    win.close = close

    win.tabs = {}
    win.pageHost = CreateFrame("Frame", nil, win)
    win.pageHost:SetPoint("TOPLEFT", win, "TOPLEFT", EDGE - 6, -HEADER)
    win.pageHost:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -EDGE + 6, FOOTER)
    win.pageHost:Hide()

    win.body = CreateFrame("Frame", nil, win)
    win.body:SetPoint("TOPLEFT", win, "TOPLEFT", EDGE, -HEADER)
    win.body:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -EDGE, FOOTER + 6)

    win.summary = Panel(win.body, 8, { 0, 0, 0 }, 0.28)
    win.summary:SetPoint("TOPRIGHT", win.body, "TOPRIGHT", 0, 0)
    win.summary:SetPoint("BOTTOMRIGHT", win.body, "BOTTOMRIGHT", 0, 0)
    win.summary:SetWidth(SUMMARY_W)
    win.lines = {}

    win.modelBox = CreateFrame("Frame", nil, win.body)
    win.modelBox:SetPoint("TOPLEFT", win.body, "TOPLEFT", COL + 8, 0)
    win.modelBox:SetPoint("BOTTOMRIGHT", win.body, "BOTTOMRIGHT", -(SUMMARY_W + 10 + COL + 8), ICON + 14)
    local ok, model = pcall(CreateFrame, "PlayerModel", nil, win.modelBox)
    if ok and model then
        model:SetPoint("TOPLEFT", win.modelBox, "TOPLEFT", -20, 0)
        model:SetPoint("BOTTOMRIGHT", win.modelBox, "BOTTOMRIGHT", 20, -10)
        model:EnableMouse(true)
        model:SetScript("OnMouseDown", function(self) self.turning = GetCursorPosition() end)
        model:SetScript("OnMouseUp", function(self) self.turning = nil end)
        model:SetScript("OnHide", function(self) self.turning = nil end)
        model:SetScript("OnUpdate", function(self)
            if not self.turning then return end
            local cx = GetCursorPosition()
            local d = (cx - self.turning) * 0.012
            self.turning = cx
            if d ~= 0 and self.GetFacing then self:SetFacing((self:GetFacing() or 0) + d) end
        end)
        win.model = model
    end

    for i, key in ipairs(LEFT) do NewSlot(key, "left"):SetPoint("TOPLEFT", win.body, "TOPLEFT", 0, -(i - 1) * ROW) end
    for i, key in ipairs(RIGHT) do NewSlot(key, "right"):SetPoint("TOPRIGHT", win.body, "TOPRIGHT", -(SUMMARY_W + 10), -(i - 1) * ROW) end
    for _, key in ipairs(WEAPONS) do NewSlot(key, "weapon") end
    if SlotInfo("Ammo") then
        local v = NewSlot("Ammo", "weapon")
        v.isAmmo = true
        v:SetSize(30, 30)
        v.iconFrame:SetSize(30, 30)
        v.name:Hide()
        v.detail:ClearAllPoints()
        v.detail:SetPoint("BOTTOMRIGHT", v.iconFrame, "BOTTOMRIGHT", -1, 2)
        v.detail:SetJustifyH("RIGHT")
    end

    local rule = win:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", EDGE, FOOTER)
    rule:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -EDGE, FOOTER)
    rule:SetColorTexture(1, 1, 1, 0.07)
    win.foot = Text(win, 12, "LEFT")
    win.foot:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", EDGE + 2, 11)
    win.logoText = Text(win, 13, "RIGHT")
    win.logoText:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -EDGE - 2, 10)
    win.logoText:SetText("H3z0 UI")
    win.logoText:SetTextColor(0.85, 0.88, 0.92, 0.55)
    win.logo = win:CreateTexture(nil, "OVERLAY")
    win.logo:SetSize(18, 18)
    win.logo:SetPoint("RIGHT", win.logoText, "LEFT", -4, 0)
    win.logo:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\icon.tga")
    win.logo:SetAlpha(0.6)
    -- Settings, left of the logo: the same window settings as the character window
    local SH = ns.H3zCWShared
    if SH then win.settingsBtn = SH.FooterButton(win, win.logoText, win.logo) end
    win:SetScale(Scale())
    IW.ShowLogo()
    return win
end

function IW.ShowLogo()
    if not win then return end
    local SH = ns.H3zCWShared
    local s = SH and SH.Settings()
    local on = not s or s.h3zLogo ~= false
    win.logo:SetShown(on)
    win.logoText:SetShown(on)
end

function IW.UpdateAll()
    if not (win and win:IsShown()) then return end
    local u = ResolveUnit()
    if not u then return end      -- not reachable now: keep showing them as they were
    unit = u
    local C = Colors()
    local name = UnitName(unit)
    win.name:SetText(name or "")
    local className, classFile = UnitClass(unit)
    local cc = classFile and not IsSecret(classFile) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if cc then win.name:SetTextColor(cc.r, cc.g, cc.b) else win.name:SetTextColor(C.text[1], C.text[2], C.text[3]) end
    local level, race = UnitLevel(unit), UnitRace(unit)
    if IsSecret(level) or IsSecret(race) or IsSecret(className) then
        win.sub:SetText("")
    else
        className = className or ""
        if cc then className = string.format("|cff%02x%02x%02x%s|r", cc.r * 255, cc.g * 255, cc.b * 255, className) end
        win.sub:SetText(string.format("%s %s %s %s", _G.LEVEL or "Level", tostring(level or ""), race or "", className))
    end
    local guild = GetGuildInfo and GetGuildInfo(unit)
    if IsSecret(guild) then win.guild:SetText(guild)
    else win.guild:SetText(guild and ("<" .. guild .. ">") or "") end
    for _, v in pairs(views) do pcall(UpdateSlot, v) end
    LayoutWeapons()
    win.foot:SetText(string.format("|cffa0a8b4%s|r  |cff%02x%02x%02x%.1f|r", _G.STAT_AVERAGE_ITEM_LEVEL or "Item Level",
        C.up[1] * 255, C.up[2] * 255, C.up[3] * 255, AverageItemLevel()))
    UpdateSummary()
    LayoutTabs()
end

local function UpdateModel()
    local u = ResolveUnit()
    if win and win.model and u then
        unit = u
        pcall(win.model.SetUnit, win.model, u)
    end
end

---------------------------------------------------------------------------
-- tabs: the game's inspect window tabs (gear, PvP, talents, ...) along the top
---------------------------------------------------------------------------
local GEAR_PAGES = { InspectPaperDollFrame = true }
local currentPage = "gear"
local selectedTab = 1      -- which of our tabs is chosen; the page follows this, not the game's shown flags
local borrowed

local function GameTabs()
    local g = InspectFrame
    local holder = (g and g.ModeTabs) or _G.InspectUITabs
    if holder and type(holder.Tabs) == "table" and #holder.Tabs > 0 then return holder.Tabs end
    local list = {}
    -- Forever: InspectFrameModeTab1.. ; Classic: InspectFrameTab1..
    for _, prefix in ipairs({ "InspectFrameModeTab", "InspectFrameTab" }) do
        for i = 1, 8 do
            local t = _G[prefix .. i]
            if not t then break end
            list[#list + 1] = t
        end
        if #list > 0 then return list end
    end
    return list
end

-- the page frame a tab opens
local SUBFRAMES = { "InspectPaperDollFrame", "InspectPVPFrame", "InspectHonorFrame", "InspectTalentFrame", "InspectGuildFrame" }
-- by what the tab says, when it does not name its page
local BY_LABEL = {
    { "guild", "InspectGuildFrame" }, { "player vs", "InspectPVPFrame" }, { "pvp", "InspectPVPFrame" },
    { "honor", "InspectHonorFrame" }, { "talent", "InspectTalentFrame" },
}
local function TabFrameName(tab, i)
    if type(tab.frameName) == "string" then return tab.frameName end
    if i == 1 then return "InspectPaperDollFrame" end
    local tip = type(tab.tooltipText) == "string" and tab.tooltipText:lower() or ""
    if tip == "" and tab.GetText then
        local ok, t = pcall(tab.GetText, tab)
        if ok and type(t) == "string" and not IsSecret(t) then tip = t:lower() end
    end
    for _, m in ipairs(BY_LABEL) do
        if tip:find(m[1], 1, true) and _G[m[2]] then return m[2] end
    end
    if _G.INSPECTFRAME_SUBFRAMES and _G.INSPECTFRAME_SUBFRAMES[i] then return _G.INSPECTFRAME_SUBFRAMES[i] end
    return nil
end

local function TabLabel(tab, i)
    for _, k in ipairs({ "tooltipText", "tooltip", "name" }) do
        if type(tab[k]) == "string" and tab[k] ~= "" then return tab[k] end
    end
    local fs = tab.Text or tab.text
    if fs and fs.GetText then
        local ok, v = pcall(fs.GetText, fs)
        if ok and type(v) == "string" and v ~= "" then return v end
    end
    if tab.GetText then
        local ok, v = pcall(tab.GetText, tab)
        if ok and type(v) == "string" and v ~= "" then return v end
    end
    local n = TabFrameName(tab, i)
    if n then return (n:gsub("^Inspect", ""):gsub("Frame$", "")) end
    return "Tab " .. i
end

-- the page of the chosen tab ("gear" for the first one)
local function GamePage()
    if selectedTab == 1 then return "gear", nil end
    local tab = GameTabs()[selectedTab]
    local n = tab and TabFrameName(tab, selectedTab)
    local f = n and _G[n]
    if not f or GEAR_PAGES[n] then return "gear", nil end
    return n, f
end

-- Choosing a tab: we remember it ourselves, and let the game fill that page (its own tab code
-- loads the PvP or guild data). The other tab pages are hidden so only one shows.
local function OpenTab(tab, i)
    local g = InspectFrame
    selectedTab = i
    local n = TabFrameName(tab, i)
    local target = n and _G[n]
    -- let the game switch too (it fills the page); errors and "did nothing" do not matter here
    if InspectSwitchTabs then pcall(InspectSwitchTabs, i) end
    if g and g.OnModeTabClicked then pcall(g.OnModeTabClicked, g, tab) end
    -- then make sure only the chosen page shows
    for j, t in ipairs(GameTabs()) do
        local on = TabFrameName(t, j)
        local f = on and _G[on]
        if f and f ~= target then f:Hide() end
    end
    if target and not target:IsShown() then target:Show() end
end

-- Midnight: secure buttons over our tabs and X, pressing the game's own tabs and close button
-- like a mouse click. They belong to the game's inspect window (so they come and go with it) and
-- ignore its see-through alpha.
local overlays = {}
local function SecureOverlay(key, target, over, onPre)
    if not MIDNIGHT or InCombatLockdown() or not (target and over and InspectFrame) then return end
    local ov = overlays[key]
    if not ov then
        -- a child of our window (itself part of the game's window), so it is always on top of our tab;
        -- registered for down and up, as the game only acts on the one its key-down setting picks
        ov = CreateFrame("Button", nil, win, "SecureActionButtonTemplate")
        ov:RegisterForClicks("AnyUp", "AnyDown")
        ov:SetAttribute("type", "click")
        ov:HookScript("OnEnter", function(self)
            local f = self.over
            local fn = f and f:GetScript("OnEnter")
            if fn then fn(f) end
        end)
        ov:HookScript("OnLeave", function(self)
            local f = self.over
            local fn = f and f:GetScript("OnLeave")
            if fn then fn(f) end
        end)
        if onPre then ov:HookScript("PreClick", onPre) end
        overlays[key] = ov
    end
    ov.over = over
    ov:SetAttribute("clickbutton", target)
    ov:ClearAllPoints()
    ov:SetAllPoints(over)
    ov:SetFrameLevel(math.min(9500, win:GetFrameLevel() + 300))
    ov:Show()
    ov.used = true
    return ov
end

LayoutTabs = function()
    -- Midnight: secure buttons sit on these tabs, and those cannot be moved in combat
    if MIDNIGHT and InCombatLockdown() then IW.tabsDirty = true return end
    IW.tabsDirty = false
    local C = Colors()
    for _, b in pairs(win.tabs) do b:Hide() end
    for _, ov in pairs(overlays) do ov.used = false end
    local tabs = GameTabs()
    if #tabs < 2 then
        SecureOverlay("close", _G.InspectFrameCloseButton or (InspectFrame and InspectFrame.CloseButton), win.close)
        return
    end
    local x = -44
    for i = #tabs, 1, -1 do
        local tab = tabs[i]
        if tab:IsShown() or tab:GetName() and tab:GetName():find("ModeTab") then
            local b = win.tabs[i]
            if not b then
                b = CreateFrame("Button", nil, win)
                b:SetHeight(22)
                -- Midnight: the secure button on top takes the clicks
                if MIDNIGHT then b:EnableMouse(false) end
                -- above the pages: the game's PvP and guild pages reach up behind the header and
                -- took the clicks meant for these tabs
                b:SetFrameLevel(win:GetFrameLevel() + 250)
                b.text = Text(b, 11, "CENTER")
                b.text:SetPoint("CENTER", 0, 1)
                b.line = b:CreateTexture(nil, "OVERLAY")
                b.line:SetHeight(2)
                b.line:SetPoint("BOTTOMLEFT", 4, 0)
                b.line:SetPoint("BOTTOMRIGHT", -4, 0)
                b.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
                b:SetScript("OnClick", function(self)
                    if MIDNIGHT then
                        -- the secure button on top does this; reached only if it could not be made yet
                        print("|cff60a5faH3z0 UI:|r the tabs work after combat.")
                        return
                    end
                    if InCombatLockdown() then print("|cff60a5faH3z0 UI:|r that page opens after combat.") return end
                    local t = GameTabs()[self.index]
                    if t then OpenTab(t, self.index) end
                end)
                b:SetScript("OnEnter", function(self) if not self.active then self.text:SetTextColor(1, 1, 1) end end)
                b:SetScript("OnLeave", function(self) if not self.active then self.text:SetTextColor(C.label[1], C.label[2], C.label[3]) end end)
                b.index = i
                win.tabs[i] = b
            end
            b.text:SetText(TabLabel(tab, i))
            local w = math.ceil(b.text:GetStringWidth()) + 14
            b:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", win, "TOPRIGHT", x, -9)
            x = x - w
            b.active = (i == selectedTab)
            b.line:SetShown(b.active)
            if b.active then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(C.label[1], C.label[2], C.label[3]) end
            b:Show()
            local index = i
            SecureOverlay("tab" .. i, tab, b, function() selectedTab = index end)
        end
    end
    SecureOverlay("close", _G.InspectFrameCloseButton or (InspectFrame and InspectFrame.CloseButton), win.close)
    for _, ov in pairs(overlays) do if not ov.used then ov:Hide() end end
end

-- How the game's inspect pages are laid out: the things on them (PvP emblem, rank text, guild
-- banner, guild name) are placed against the game's inspect window and its inner panel, not
-- against the page. That window is hidden while ours is open, so moving the page did nothing.
--
-- So we make a stand-in of the game's window (same size) that sits centered in ours, and a
-- stand-in of every part of it the page leans on. Every place on the page that leans on the game's
-- window is pointed at its stand-in instead. Everything then lands exactly where the game would put
-- it, only in the middle of our window. All of it is put back when the page goes back.

local function IsInside(frame, ancestor)
    local x = frame
    for _ = 1, 30 do
        if not x then return false end
        if x == ancestor then return true end
        local ok, p = pcall(x.GetParent, x)
        x = ok and p or nil
    end
    return false
end

local function Stand(real)
    local g = InspectFrame
    borrowed.stands = borrowed.stands or {}
    if borrowed.stands[real] then return borrowed.stands[real] end
    local st = CreateFrame("Frame", nil, win.pageHost)
    borrowed.stands[real] = st
    if real == g then
        st:SetSize(g:GetWidth(), g:GetHeight())
        -- the top of the game's inner panel sits just under our header
        local inset = _G.InspectFrameInset
        local drop = 60
        if inset and inset:GetTop() and g:GetTop() then drop = g:GetTop() - inset:GetTop() end
        st:SetPoint("TOP", win.pageHost, "TOP", 0, drop - 4)
    else
        st:SetSize(real:GetWidth(), real:GetHeight())
        local any = false
        for i = 1, real:GetNumPoints() do
            local pt, rel, rp, x, y = real:GetPoint(i)
            if rel and (rel == g or IsInside(rel, g)) then
                st:SetPoint(pt, Stand(rel), rp, x, y)
                any = true
            end
        end
        if not any then st:SetPoint("CENTER", Stand(g), "CENTER", 0, 0) end
    end
    return st
end

local function Rewire(region, page)
    local g = InspectFrame
    local n = region:GetNumPoints()
    if n == 0 then return end
    local pts, changed = {}, false
    for i = 1, n do
        local pt, rel, rp, x, y = region:GetPoint(i)
        pts[i] = { pt, rel, rp, x, y }
        if rel and rel ~= page and not IsInside(rel, page) and (rel == g or IsInside(rel, g)) then changed = true end
    end
    if not changed then return end
    borrowed.rewired[#borrowed.rewired + 1] = { region = region, points = pts }
    region:ClearAllPoints()
    for _, p in ipairs(pts) do
        local rel = p[2]
        if rel and rel ~= page and not IsInside(rel, page) and (rel == g or IsInside(rel, g)) then rel = Stand(rel) end
        region:SetPoint(p[1], rel, p[3], p[4], p[5])
    end
end

local function RewirePage(f)
    local function Walk(frame, depth)
        for _, r in ipairs({ frame:GetRegions() }) do pcall(Rewire, r, f) end
        if depth <= 0 then return end
        for _, c in ipairs({ frame:GetChildren() }) do
            pcall(Rewire, c, f)
            Walk(c, depth - 1)
        end
    end
    Walk(f, 4)
end

local function ReturnPage()
    if not borrowed or InCombatLockdown() then return end
    for i = #(borrowed.nudged or {}), 1, -1 do
        local n = borrowed.nudged[i]
        n.region:ClearAllPoints()
        for _, p in ipairs(n.points) do n.region:SetPoint(unpack(p)) end
    end
    for i = #borrowed.rewired, 1, -1 do
        local rw = borrowed.rewired[i]
        rw.region:ClearAllPoints()
        for _, p in ipairs(rw.points) do rw.region:SetPoint(unpack(p)) end
    end
    local f = borrowed.frame
    f:SetParent(borrowed.parent)
    f:ClearAllPoints()
    for _, p in ipairs(borrowed.points) do f:SetPoint(unpack(p)) end
    for _, st in pairs(borrowed.stands or {}) do st:Hide() st:ClearAllPoints() end
    borrowed = nil
end

-- Guild page: the banner is placed for the game's window and does not line up with the guild name
-- in ours. Everything above the name (banner, emblem, border) is moved as one so it sits centered
-- over the name, and down far enough to stay clear of the header.
local function CenterGuildBanner()
    if not (borrowed and win) or InCombatLockdown() then return end
    local f = borrowed.frame
    if f ~= _G.InspectGuildFrame then return end
    local host = win.pageHost
    local hl, hr, ht = host:GetLeft(), host:GetRight(), host:GetTop()
    if not (hl and hr and ht) then return end
    -- the guild name line: the target to center on
    local guildName = GetGuildInfo and ResolveUnit() and GetGuildInfo(ResolveUnit())
    local nameFS
    local all = {}
    local function Collect(frame, depth)
        for _, r in ipairs({ frame:GetRegions() }) do all[#all + 1] = r end
        if depth <= 0 then return end
        for _, c in ipairs({ frame:GetChildren() }) do all[#all + 1] = c Collect(c, depth - 1) end
    end
    Collect(f, 4)
    for _, r in ipairs(all) do
        if r.GetText and r:IsShown() then
            local ok, t = pcall(r.GetText, r)
            if ok and type(t) == "string" and not IsSecret(t) and guildName and not IsSecret(guildName) and t == guildName then nameFS = r break end
        end
    end
    local targetX = hl + (hr - hl) / 2
    local nameTop = ht - 140
    if nameFS and nameFS:GetLeft() and nameFS:GetTop() then
        targetX = nameFS:GetLeft() + nameFS:GetWidth() / 2
        nameTop = nameFS:GetTop()
    end
    -- the banner group: shown things fully above the name, not stretched across the page
    local group, inGroup = {}, {}
    local minL, maxR, maxT
    for _, r in ipairs(all) do
        local okS, shown = pcall(r.IsShown, r)
        if okS and shown and r ~= nameFS then
            local l, rr, b, t = r:GetLeft(), r:GetRight(), r:GetBottom(), r:GetTop()
            if l and rr and b and t and b >= nameTop and (rr - l) < (hr - hl) * 0.6 and (rr - l) > 2 then
                group[#group + 1] = r
                inGroup[r] = true
                minL = minL and math.min(minL, l) or l
                maxR = maxR and math.max(maxR, rr) or rr
                maxT = maxT and math.max(maxT, t) or t
            end
        end
    end
    if not minL then return end
    local dx = targetX - (minL + (maxR - minL) / 2)
    local dy = 0
    if maxT > ht - 6 then dy = (ht - 6) - maxT end
    if math.abs(dx) < 1 and math.abs(dy) < 1 then return end
    borrowed.nudged = borrowed.nudged or {}
    for _, r in ipairs(group) do
        -- move only the pieces placed against something outside the group (the rest follow them)
        local pts, outside = {}, false
        for i = 1, r:GetNumPoints() do
            local pt, rel, rp, x, y = r:GetPoint(i)
            pts[i] = { pt, rel, rp, x, y }
            if not (rel and inGroup[rel]) then outside = true end
        end
        if outside and #pts > 0 then
            borrowed.nudged[#borrowed.nudged + 1] = { region = r, points = pts }
            r:ClearAllPoints()
            for _, p in ipairs(pts) do
                if p[2] and inGroup[p[2]] then
                    r:SetPoint(p[1], p[2], p[3], p[4], p[5])
                else
                    r:SetPoint(p[1], p[2], p[3], (p[4] or 0) + dx, (p[5] or 0) + dy)
                end
            end
        end
    end
end

local function BorrowPage(f)
    if not f or InCombatLockdown() or (borrowed and borrowed.frame == f) then return end
    ReturnPage()
    local pts = {}
    for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
    borrowed = { frame = f, parent = f:GetParent(), points = pts, rewired = {} }
    f:SetParent(win.pageHost)
    -- the page itself and everything on it: pointed at the stand-ins
    pcall(Rewire, f, nil)
    RewirePage(f)
    if f == _G.InspectGuildFrame then
        C_Timer.After(0.05, function() pcall(CenterGuildBanner) end)
        C_Timer.After(0.4, function() pcall(CenterGuildBanner) end)   -- a late banner; does nothing if already centered
    end
end

local function ShowPage(page, f)
    currentPage = page
    if page == "gear" then
        ReturnPage()
        win.pageHost:Hide()
        win.body:Show()
    else
        win.body:Hide()
        win.pageHost:Show()
        BorrowPage(f)
    end
    LayoutTabs()
end

---------------------------------------------------------------------------
-- following the game's inspect window
---------------------------------------------------------------------------
local hidden = CreateFrame("Frame", nil, UIParent)
hidden:Hide()
local parked, oldParent = false, nil

-- Midnight: the game's window stays where it is (its own OnShow / OnHide keep running the game's
-- way), see-through and covered by this window
local coverAlpha, coverWidth
local function Cover()
    local g = InspectFrame
    if parked or not g then return end
    parked = true
    coverAlpha, coverWidth = g:GetAlpha(), g:GetWidth()
    g:SetAlpha(0)
    -- not in combat: sizes of a window holding secure buttons are locked then
    if not InCombatLockdown() then g:SetWidth(WIN_W * Scale()) end
    if not g.h3zIWHooks then
        g.h3zIWHooks = true
        hooksecurefunc(g, "SetAlpha", function(self, a)
            if parked and MIDNIGHT and type(a) == "number" and a > 0 then self:SetAlpha(0) end
        end)
    end
end
local function Uncover()
    local g = InspectFrame
    if not parked or not g then return end
    if IW.blocked and ns.H3zCWShared then ns.H3zCWShared.Restore(IW.blocked) end
    parked = false
    g:SetAlpha(coverAlpha or 1)
    if InCombatLockdown() then IW.widthPending = true return end
    if coverWidth then g:SetWidth(coverWidth) end
end

local function Park()
    if MIDNIGHT then return Cover() end
    local g = InspectFrame
    if parked or not g or InCombatLockdown() then return end
    oldParent = g:GetParent()
    -- Moving the open window out of sight counts as "hidden" for the game, and its OnHide clears
    -- the inspected player's gear (that left every slot empty). So OnHide is held back for the move.
    local onHide = g:GetScript("OnHide")
    if onHide then g:SetScript("OnHide", nil) end
    g:SetParent(hidden)
    if onHide then g:SetScript("OnHide", onHide) end
    parked = true
    if SetUIPanelAttribute then pcall(SetUIPanelAttribute, g, "width", WIN_W * Scale() + 20) end
    -- if the gear was cleared anyway, ask the server for it again
    C_Timer.After(0.3, function()
        local u = ResolveUnit()
        if not (win and win:IsShown()) or not u then return end
        for _, v in pairs(views) do
            if v.slotId and GetInventoryItemLink(u, v.slotId) then return end
        end
        if CanInspect and NotifyInspect and CanInspect(u) then pcall(NotifyInspect, u) end
    end)
end

local function Unpark()
    if MIDNIGHT then return Uncover() end
    local g = InspectFrame
    if not parked or not g or InCombatLockdown() then return end
    g:SetParent(oldParent or UIParent)
    parked = false
    if SetUIPanelAttribute then pcall(SetUIPanelAttribute, g, "width", math.floor((g:GetWidth() or 384) + 0.5)) end
end

local queued = false
local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0.05, function() queued = false IW.UpdateAll() end)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_MODEL_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        local g = PlainGUID(arg1)
        if lockedGuid and g ~= lockedGuid then return end
        if not lockedGuid and not (arg1 and InspectFrame and InspectFrame.unit and UnitIsUnit(arg1, InspectFrame.unit)) then return end
        if event == "UNIT_MODEL_CHANGED" then UpdateModel() end
    end
    if event == "INSPECT_READY" then
        if arg1 and lockedGuid and not IsSecret(arg1) and arg1 ~= lockedGuid then return end   -- someone else's data
        UpdateModel()
    end
    Queue()
end)
local EVENTS = { "INSPECT_READY", "UNIT_INVENTORY_CHANGED", "UNIT_MODEL_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_ENABLED" }

-- The game's inspect window listens for target changes and re-inspects your new target (that is
-- what switched the window to whoever you clicked, even after closing). While our window is open
-- those events are taken off the game's window; they are given back when it closes.
local FOLLOW_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE", "UNIT_TARGET",
    "MODIFIER_STATE_CHANGED" }
local heldEvents = {}
local function HoldGameEvents()
    local g = InspectFrame
    if not (g and g.IsEventRegistered) then return end
    for _, e in ipairs(FOLLOW_EVENTS) do
        local ok, on = pcall(g.IsEventRegistered, g, e)
        if ok and on then
            g:UnregisterEvent(e)
            heldEvents[e] = true
        end
    end
end
local function GiveGameEvents()
    local g = InspectFrame
    if not g then return end
    for e in pairs(heldEvents) do pcall(g.RegisterEvent, g, e) end
    wipe(heldEvents)
end

-- The real cause of "it keeps inspecting whoever I click after closing": the game's inspect window
-- only lets go of the inspected player in its OnHide (it clears the inspect and forgets its unit).
-- While it is kept out of sight, closing it never runs that OnHide (an unseen frame does not get
-- one), so the game still thought it was inspecting "target" and followed every click. So when it
-- closes while out of sight, its OnHide is run by hand, once.
local function RunGameClose()
    local g = InspectFrame
    if not g or g:IsShown() then return end
    local onHide = g:GetScript("OnHide")
    if onHide then pcall(onHide, g) end
    if g.unit ~= nil then g.unit = nil end
    if _G.INSPECTED_UNIT ~= nil then _G.INSPECTED_UNIT = nil end
    if ClearInspectPlayer then pcall(ClearInspectPlayer) end
end

local function ShowOurs()
    HoldGameEvents()
    Build()
    win:ClearAllPoints()
    local g = InspectFrame
    if MIDNIGHT and g then
        win:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0)
        win:SetFrameStrata(g:GetFrameStrata())
        win:SetFrameLevel(math.min(9000, (g:GetFrameLevel() or 1) + 40))
    elseif g and g:GetNumPoints() > 0 then
        win:SetPoint("TOPLEFT", g, "TOPLEFT", 12, -12)
    else
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -104)
    end
    win:Show()
    for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    UpdateModel()
    IW.UpdateAll()
    -- item names arrive a moment later the first time
    C_Timer.After(0.4, Queue)
    C_Timer.After(1.2, Queue)
end

local function HideOurs()
    if win then win:Hide() end
    ev:UnregisterAllEvents()
end

local lastUnitGuid
-- No following a new InspectUnit while open: on Forever the game calls it by itself when your
-- target changes, which switched the window to whoever you clicked. The window stays on the player
-- it opened for until it is closed (as the old H3z0 inspect did).

-- Midnight: our window is part of the game's, so the game shows and hides it. This only reacts
-- to the game's window opening and closing and to the chosen tab.
local midOpen = false
local function MidnightTick()
    local g = InspectFrame
    local open = g:IsShown() and Enabled() and true or false
    if open and not midOpen then
        midOpen = true
        HoldGameEvents()
        unit = g.unit or "target"
        lockedGuid = PlainGUID(unit)
        selectedTab = 1
        Build()
        Cover()
        if not win:IsShown() and not InCombatLockdown() then win:Show() end
        for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
        UpdateModel()
        IW.UpdateAll()
        C_Timer.After(0.4, Queue)
        C_Timer.After(1.2, Queue)
        IW.topAt = 0
    elseif not open and midOpen then
        midOpen = false
        ev:UnregisterAllEvents()
        GiveGameEvents()
        Uncover()
    end
    if InCombatLockdown() or not win then return end
    if IW.widthPending and not parked then
        IW.widthPending = nil
        if coverWidth then g:SetWidth(coverWidth) end
    elseif parked and math.abs((g:GetWidth() or WIN_W) - WIN_W * Scale()) > 1 then
        g:SetWidth(WIN_W * Scale())
    end
    if not open then
        if IW.blocked and next(IW.blocked) and ns.H3zCWShared then ns.H3zCWShared.Restore(IW.blocked) end
        if currentPage ~= "gear" then ShowPage("gear") end
        if not Enabled() and win:IsShown() and g:IsShown() then win:Hide() end
        return
    end
    if IW.tabsDirty then LayoutTabs() end
    local page, f = GamePage()
    if page ~= currentPage then ShowPage(page, f) end
    -- keep the tabs and X above the PvP and Guild pages shown inside the window, and above the
    -- game's own window parts that sit at a fixed high level (its title bar and close button)
    local now = GetTime()
    if now - (IW.topAt or 0) > 2 then
        IW.topAt = now
        local function Highest(fr, depth)
            local best = fr:GetFrameLevel() or 0
            if depth <= 0 then return best end
            for _, c in ipairs({ fr:GetChildren() }) do
                if c ~= win then
                    local l = Highest(c, depth - 1)
                    if l > best then best = l end
                end
            end
            return best
        end
        IW.gameTop = Highest(g, 2)
        if parked and ns.H3zCWShared then
            IW.blocked = ns.H3zCWShared.Unblock(g, win, HEADER, IW.blocked)
        end
    end
    local lvl = math.min(9800, math.max(win:GetFrameLevel() + 300, (IW.gameTop or 0) + 10))
    for _, ov in pairs(overlays) do
        if ov:IsShown() and ov:GetFrameLevel() ~= lvl then ov:SetFrameLevel(lvl) end
    end
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
    local g = InspectFrame
    if not g then return end
    if MIDNIGHT then return MidnightTick() end
    if not Enabled() then
        if parked or (win and win:IsShown()) then HideOurs() Unpark() end
        if next(heldEvents) then GiveGameEvents() end
        return
    end
    if g:IsShown() and IW.wantClosed then
        -- closed by you in combat: stay closed, close the game's window once combat is over
        if not InCombatLockdown() then
            IW.wantClosed = nil
            pcall(HideUIPanel, g)
            if g:IsShown() then g:Hide() end
        end
        return
    end
    IW.wantClosed = nil
    if g:IsShown() then
        IW.gameWasShown = true
        if not parked then
            if InCombatLockdown() and LEGACY then return end
            Park()
        end
        if not (win and win:IsShown()) then
            unit = g.unit or "target"
            -- the game closing and reopening its window on its own right after (it does that when your
            -- target changes) is not a new inspect: stay on the same player
            local reopened = IW.closedAt and (GetTime() - IW.closedAt) < 0.5 and not IW.closedByUs
            if not (reopened and lockedGuid) then
                lockedGuid = PlainGUID(unit)
                selectedTab = 1
            end
            IW.closedAt, IW.closedByUs = nil, nil
            ShowOurs()
        end
        local page, f = GamePage()
        if page ~= currentPage and not InCombatLockdown() then ShowPage(page, f) end
    else
        if win and win:IsShown() then
            HideOurs()
            IW.closedAt = GetTime()
        end
        -- the game's window just closed (by our X, Escape or the game): let the game drop the
        -- inspected player. This used to sit inside the check above, which X and Escape skip
        -- (they hide our window first), so it never ran for them.
        if IW.gameWasShown then
            IW.gameWasShown = nil
            if parked and LEGACY then RunGameClose() end
        end
        if next(heldEvents) then GiveGameEvents() end
        if currentPage ~= "gear" and win and not InCombatLockdown() then ShowPage("gear") end
        -- closed: the game's window goes back to its usual place, so the next Inspect opens it the
        -- normal way (a parked, closed window did not open again for the next player)
        if parked and (MIDNIGHT or not InCombatLockdown()) then Unpark() end
    end
end)

-- window settings changed (shared with the character window)
function IW.ApplyOptions()
    if not win then return end
    if InCombatLockdown() then C_Timer.After(1, IW.ApplyOptions) return end
    win:SetScale(Scale())
    IW.ShowLogo()
    for _, v in pairs(views) do v.arranged = nil end
    if win:IsVisible() then IW.UpdateAll() end
end
_G.H3z0UI_RefreshInspectWindow = IW.ApplyOptions

function IW.Toggle()
    local s = Settings()
    if not s then return end
    s.h3zInspectWindow = not (s.h3zInspectWindow ~= false)
    print("|cff60a5faH3z0 UI:|r H3z0 inspect window " .. (s.h3zInspectWindow and "on." or "off: the game's window is used."))
end
_G.H3z0UI_ToggleInspectWindow = IW.Toggle
