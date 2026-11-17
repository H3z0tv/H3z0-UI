---------------------------------------------------------------------------
-- H3z0 UI - Character Window (WoW: Forever, Classic and Midnight)
--
-- Our own window for the Character tab:
--   header      name, "Level N Race Class", tabs along the top right, close
--   slots       eight per side round the model, weapons in a row under it;
--               each slot: icon with a quality outline, name in quality colour,
--               one grey line under it (Item Level N), or slot name + Empty
--   model       your character (drag to turn it)
--   stats       darker inset on the right, groups that fold, scrolls
--   footer      average item level and durability
--
-- How it fits the game:
--   * The game's CharacterFrame keeps doing all the work. While the Character
--     tab is open it is kept under a hidden parent ("parked"), so the C key,
--     the micro button, Escape and other addons still open and close it, and
--     this window simply follows it.
--   * The game's slot buttons are moved on top of our icons and made
--     invisible: hover, tooltips, dragging, swapping and clicking are the
--     game's own and keep working.
--   * Other tabs (Reputation, Skills, ...) show the game's window as before;
--     this window steps aside for them.
--   * Frames are only moved out of combat.
--
-- Midnight is different in three ways, so the window fits in differently there:
--   * Blizzard code started by addon code runs "tainted" and can then fail on
--     secret values. So addon code never opens, closes or switches the game's
--     window there: the tabs and the X of this window are secure buttons that
--     press the game's own tabs and close button, exactly like a mouse click.
--   * The game's window is not moved away (that would hide it without its own
--     OnShow / OnHide). It stays where the game puts it, made see-through and
--     covered by this window, so it opens, closes and updates as usual.
--   * Many stats are secret in combat: their last known value is shown.
--
-- Settings: profile.character.h3zWindow (on by default). /h3z0 charwindow switches it.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local LEGACY = ns.Client and ns.Client.isLegacy and true or false
-- item functions moved into C_Item on newer clients (Midnight); the old names on Forever / Classic
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or _G.GetDetailedItemLevelInfo
local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon
local MIDNIGHT = not LEGACY

local CW = {}
ns.H3z0CharWindow = CW

---------------------------------------------------------------------------
-- look
---------------------------------------------------------------------------
local WIN_W, WIN_H = 840, 520
local EDGE = 16
local HEADER = 52
local FOOTER = 34
local ROW = 46
local ICON = 38
local COL = 170            -- slot column: icon + names
local STATS_W = 220
local STAT_ROW = 18
local GROUP_HEAD = 24

local function Colors()
    local G = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    local a = G and G.accent or { 0.204, 0.827, 0.6, 1 }
    return {
        accent = a,
        text = { 0.95, 0.96, 0.97 },
        label = { 0.70, 0.73, 0.77 },
        dim = { 0.50, 0.53, 0.57 },
        up = { 0.45, 0.9, 0.45 },
        down = { 1, 0.4, 0.4 },
        head = { 1, 0.62, 0.25 },     -- stat group headers
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

local function Text(parent, size, justify, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
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

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.character = p.character or {}
    local s = p.character
    if s.h3zWindow == nil then s.h3zWindow = true end
    if type(s.h3zWindowFolds) ~= "table" then s.h3zWindowFolds = {} end
    -- what the gear rows show, and how big the window is
    if s.cwNames == nil then s.cwNames = true end
    if s.cwItemLevel == nil then s.cwItemLevel = true end
    if s.cwTrack == nil then s.cwTrack = true end
    if s.cwNoUpgrade == nil then s.cwNoUpgrade = true end
    if s.cwMaxGray == nil then s.cwMaxGray = true end
    if type(s.cwScale) ~= "number" then s.cwScale = 100 end
    if type(s.cwTextSize) ~= "number" then s.cwTextSize = 0 end
    return s
end

local function Enabled()
    local s = Settings()
    return s and s.h3zWindow ~= false
end

-- window size from the settings (0.7 .. 1.3)
local function Scale()
    local s = Settings()
    local v = s and tonumber(s.cwScale) or 100
    return math.max(70, math.min(130, v)) / 100
end

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
    SecondaryHand = "SECONDARYHANDSLOT", Ranged = "RANGEDSLOT",
}
-- slots that do not count for the average item level
local NO_ILVL = { Shirt = true, Tabard = true }

local function SlotInfo(key)
    local ok, id, empty = pcall(GetInventorySlotInfo, key .. "Slot")
    if ok and id then return id, empty end
    return nil
end

local function SlotLabel(key)
    local g = LABEL_GLOBAL[key]
    local t = g and _G[g]
    if type(t) == "string" and t ~= "" then return t end
    return key
end

local function ItemData(slotId)
    local link = GetInventoryItemLink("player", slotId)
    if not link then return nil end
    local name, _, quality, ilvl = GetItemInfo(link)
    if GetDetailedItemLevelInfo then
        local ok, eff = pcall(GetDetailedItemLevelInfo, link)
        if ok and type(eff) == "number" and eff > 0 then ilvl = eff end
    end
    quality = quality or GetInventoryItemQuality("player", slotId)
    return {
        link = link,
        name = name,
        quality = quality,
        ilvl = ilvl,
        icon = GetInventoryItemTexture("player", slotId),
    }
end

---------------------------------------------------------------------------
-- upgrade track (Midnight): "Hero 4/6" and the like, read from the item's
-- own tooltip line, so it is in your game language
---------------------------------------------------------------------------
local TRACK_COLORS = {      -- by track, in the colours the game uses for them
    explorer = { 0.62, 0.62, 0.62 }, adventurer = { 1, 1, 1 }, veteran = { 0.12, 1, 0 },
    champion = { 0, 0.44, 0.87 }, hero = { 0.64, 0.21, 0.93 }, myth = { 1, 0.5, 0 },
}
local TRACK_ORDER = { "explorer", "adventurer", "veteran", "champion", "hero", "myth" }
local trackPattern, trackPatternPlain
local function PatternOf(fmt)
    if type(fmt) ~= "string" then return nil end
    -- "Upgrade Level: %s %d/%d" -> "Upgrade Level: (.-) (%d+)/(%d+)"
    local out, i = {}, 1
    while i <= #fmt do
        local c = fmt:sub(i, i)
        local n = fmt:sub(i + 1, i + 1)
        if c == "%" and n == "s" then out[#out + 1] = "(.-)" i = i + 2
        elseif c == "%" and n == "d" then out[#out + 1] = "(%d+)" i = i + 2
        elseif c == "%" and n == "%" then out[#out + 1] = "%%" i = i + 2
        else
            if c:find("[%(%)%.%+%-%*%?%[%]%^%$%%]") then c = "%" .. c end
            out[#out + 1] = c
            i = i + 1
        end
    end
    return "^%s*" .. table.concat(out) .. "%s*$"
end
local trackCache = {}
local function UpgradeTrack(slotId, link)
    if not MIDNIGHT or not link then return nil end
    local hit = trackCache[link]
    if hit ~= nil then return hit or nil end
    trackPattern = trackPattern or PatternOf(_G.ITEM_UPGRADE_TOOLTIP_FORMAT_STRING) or "^Upgrade Level: (.-) (%d+)/(%d+)$"
    trackPatternPlain = trackPatternPlain or PatternOf(_G.ITEM_UPGRADE_TOOLTIP_FORMAT) or "^Upgrade Level: (%d+)/(%d+)$"
    local data = C_TooltipInfo and C_TooltipInfo.GetInventoryItem and C_TooltipInfo.GetInventoryItem("player", slotId)
    if not (data and data.lines) then return nil end   -- not loaded yet: asked again next time
    local found = false
    for _, line in ipairs(data.lines) do
        local t = line.leftText
        if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then
            t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local name, cur, max = t:match(trackPattern)
            if name then
                found = { name = name, cur = tonumber(cur), max = tonumber(max) }
                break
            end
            cur, max = t:match(trackPatternPlain)
            if cur then
                found = { cur = tonumber(cur), max = tonumber(max) }
                break
            end
        end
    end
    trackCache[link] = found
    return found or nil
end
local function TrackColor(t, quality)
    local n = t.name and t.name:lower() or ""
    for _, key in ipairs(TRACK_ORDER) do
        if n:find(key, 1, true) then return TRACK_COLORS[key] end
    end
    return nil
end

local function QualityColor(q)
    if q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
        local c = ITEM_QUALITY_COLORS[q]
        return c.r, c.g, c.b
    end
    if q and GetItemQualityColor then
        local r, g, b = GetItemQualityColor(q)
        if r then return r, g, b end
    end
    return 0.85, 0.85, 0.85
end

---------------------------------------------------------------------------
-- window
---------------------------------------------------------------------------
local win
local slotViews = {}       -- [key] = view
local currentPage = "character"
local UpdateArt
local borrowed            -- the game page shown inside our window: { frame, parent, points }
local parked = false
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

local lent = { slots = {} }   -- what we borrowed from the game, to give back

local TABS = {
    { id = "character", frame = "PaperDollFrame", label = function() return _G.CHARACTER or "Character" end },
    { id = "pet", frame = "PetPaperDollFrame", label = function() return _G.PET or "Pet" end, need = function() return HasPetUI and HasPetUI() end },
    { id = "reputation", frame = "ReputationFrame", label = function() return _G.REPUTATION or "Reputation" end },
    { id = "skills", frame = "SkillFrame", label = function() return _G.SKILLS or "Skills" end },
    { id = "pvp", frame = "HonorFrame", label = function() return _G.PVP or "PvP" end },
    { id = "currency", frame = "TokenFrame", label = function() return _G.CURRENCY or "Currency" end },
}

local function OpenGamePage(frameName)
    if InCombatLockdown() and frameName ~= "PaperDollFrame" then
        print("|cff60a5faH3z0 UI:|r that page opens after combat.")
        return
    end
    if not ToggleCharacter then return end
    -- the game opens the page; the window follows (also back to Character from another tab)
    local ok = pcall(ToggleCharacter, frameName, true)
    if not ok then pcall(ToggleCharacter, frameName) end
end

local function CloseWindow()
    if MIDNIGHT then return end   -- the secure button on top closes the game's window
    local g = CharacterFrame
    if g and g:IsShown() then
        if HideUIPanel and not InCombatLockdown() then
            pcall(HideUIPanel, g)
        else
            pcall(ToggleCharacter, "PaperDollFrame")
        end
    end
    if win then win:Hide() end
end

local function BuildHeader()
    local C = Colors()
    win.name = Text(win, 17, "LEFT")
    win.name:SetPoint("TOPLEFT", win, "TOPLEFT", EDGE + 2, -12)
    win.name:SetTextColor(C.text[1], C.text[2], C.text[3])
    win.sub = Text(win, 11, "LEFT")
    win.sub:SetPoint("TOPLEFT", win.name, "BOTTOMLEFT", 0, -3)
    win.sub:SetTextColor(C.label[1], C.label[2], C.label[3])

    win.close = CreateFrame("Button", nil, win)
    win.close:SetSize(22, 22)
    win.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -10)
    local x = Text(win.close, 15, "CENTER")
    x:SetAllPoints()
    x:SetText("x")
    x:SetTextColor(C.label[1], C.label[2], C.label[3])
    win.close:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1) end)
    win.close:SetScript("OnLeave", function() x:SetTextColor(C.label[1], C.label[2], C.label[3]) end)
    win.close:SetScript("OnClick", CloseWindow)

    win.tabs = {}
end

---------------------------------------------------------------------------
-- tabs: one for every tab the game's window has (Forever has its own set
-- along the side of its window, Classic the row along the bottom)
---------------------------------------------------------------------------
local tabPage = {}          -- [game tab index] = page it opened ("character" or a frame name)
local pendingLearn          -- game tab index just clicked, page not seen yet
local function GameTabs()
    local g = CharacterFrame
    local mt = g and g.ModeTabs
    if mt and type(mt.Tabs) == "table" and #mt.Tabs > 0 then return mt.Tabs end
    local list = {}
    for i = 1, 12 do
        local t = _G["CharacterFrameTab" .. i]
        if not t then break end
        list[#list + 1] = t
    end
    return list
end

local FRAME_LABEL = {}
for _, t in ipairs(TABS) do FRAME_LABEL[t.frame] = t.label end

local function TabLabel(tab, i)
    local page = tabPage[i]
    if page == "character" then return _G.CHARACTER or "Character" end
    if page and FRAME_LABEL[page] then return FRAME_LABEL[page]() end
    for _, k in ipairs({ "tooltipText", "tooltip", "tooltipTitle", "name", "label" }) do
        local v = tab[k]
        if type(v) == "string" and v ~= "" then return v end
    end
    local fs = tab.Text or tab.text or tab.Label
    if fs and fs.GetText then
        local ok, v = pcall(fs.GetText, fs)
        if ok and type(v) == "string" and v ~= "" then return v end
    end
    if tab.GetText then
        local ok, v = pcall(tab.GetText, tab)
        if ok and type(v) == "string" and v ~= "" then return v end
    end
    if i == 1 then return _G.CHARACTER or "Character" end
    if page then return (page:gsub("Frame$", "")) end
    return nil
end

local function TabIcon(tab)
    local tex = tab.Icon or tab.icon or tab.IconTexture
    if tex and tex.GetTexture then
        local okA, atlas = pcall(tex.GetAtlas, tex)
        if okA and atlas then return nil, atlas end
        local ok, t = pcall(tex.GetTexture, tex)
        if ok and t then return t, nil end
    end
    return nil
end

local function OurTab(i)
    local C = Colors()
    local b = win.tabs[i]
    if b then return b end
    b = CreateFrame("Button", nil, win)
    b:SetHeight(22)
    b.text = Text(b, 11, "CENTER")
    b.text:SetPoint("CENTER", 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("CENTER", 0, 1)
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", 4, 0)
    b.line:SetPoint("BOTTOMRIGHT", -4, 0)
    b.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    b.index = i
    b:SetScript("OnClick", function(self)
        -- Midnight: the secure button on top does the click; this one is only reached when that
        -- button could not be made yet (window first opened in combat)
        if MIDNIGHT then
            print("|cff60a5faH3z0 UI:|r the tabs work after combat.")
            return
        end
        local tab = GameTabs()[self.index]
        if not tab then return end
        if InCombatLockdown() and self.index ~= 1 then
            print("|cff60a5faH3z0 UI:|r that page opens after combat.")
            return
        end
        pendingLearn = self.index
        local g = CharacterFrame
        -- 1. a page we know by name: the game's own way to open it
        local frameName = (type(tab.frameName) == "string" and tab.frameName)
            or ((self.index == 1) and "PaperDollFrame") or tabPage[self.index]
        if not frameName or frameName == "character" then
            local label = self.text:GetText()
            for _, t in ipairs(TABS) do
                if label and t.label() == label then frameName = t.frame end
            end
            if not frameName and label and (label == _G.PLAYER_V_PLAYER or label == _G.PVP) then
                frameName = _G.HonorFrame and "HonorFrame" or (_G.PVPFrame and "PVPFrame") or nil
            end
        end
        if frameName == "character" then frameName = "PaperDollFrame" end
        if frameName and _G[frameName] then
            OpenGamePage(frameName)
            -- Forever: pages ToggleCharacter does not know (Skills, PvP, Statistics) open through
            -- the window's own tab handler, a moment later if the plain way did nothing
            C_Timer.After(0, function()
                local f = _G[frameName]
                if f and f:IsShown() then return end
                if g and g.OnModeTabClicked then
                    if pcall(g.OnModeTabClicked, g, tab) and f:IsShown() then return end
                end
                if g and g.ShowSubFrame then pcall(g.ShowSubFrame, g, frameName) end
                if g and g.SetSelectedModeTabByFrame then pcall(g.SetSelectedModeTabByFrame, g, frameName) end
            end)
            return
        end
        -- 2. the game's tab itself
        local mt = g and g.ModeTabs
        if mt and mt.SetTab and tab.tabID then
            if pcall(mt.SetTab, mt, tab.tabID) then return end
        end
        if g and g.SetTab then
            if pcall(g.SetTab, g, tab.tabID or self.index) then return end
        end
        local fn = tab:GetScript("OnClick")
        if fn then pcall(fn, tab, "LeftButton") else pcall(tab.Click, tab) end
    end)
    b:SetScript("OnEnter", function(self)
        if not self.active then self.text:SetTextColor(1, 1, 1) end
    end)
    b:SetScript("OnLeave", function(self)
        if not self.active then self.text:SetTextColor(C.label[1], C.label[2], C.label[3]) end
    end)
    win.tabs[i] = b
    return b
end

local function ActiveTabIndex()
    for i, tab in ipairs(GameTabs()) do
        local n = type(tab.frameName) == "string" and tab.frameName
        if n and (n == currentPage or (n == "PaperDollFrame" and currentPage == "character")) then return i end
    end
    for i, page in pairs(tabPage) do
        if page == currentPage then return i end
    end
    if currentPage == "character" then return 1 end
    return nil
end

---------------------------------------------------------------------------
-- Midnight: secure buttons over our tabs and X that press the game's own tab
-- and close buttons, like a real mouse click (no addon code runs the game's
-- window code, so nothing in it gets tainted). They belong to the game's
-- window, so they come and go with it; they ignore its see-through alpha.
---------------------------------------------------------------------------
local overlays = {}
local function SecureOverlay(key, target, over, onPre)
    if not MIDNIGHT or InCombatLockdown() or not (target and over and CharacterFrame) then return end
    local ov = overlays[key]
    if not ov then
        ov = CreateFrame("Button", nil, CharacterFrame, "SecureActionButtonTemplate")
        ov:RegisterForClicks("AnyUp")
        if ov.SetIgnoreParentAlpha then ov:SetIgnoreParentAlpha(true) end
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
    ov:SetFrameStrata(win:GetFrameStrata())
    ov:SetFrameLevel(math.min(9500, win:GetFrameLevel() + 70))
    ov:Show()
    ov.used = true
    return ov
end

local function HideOverlays()
    if InCombatLockdown() then return end
    for _, ov in pairs(overlays) do ov:Hide() end
end
CW.HideOverlays = HideOverlays

local function LayoutTabs()
    -- Midnight: the secure buttons sit on these tabs, and they cannot be moved in combat
    if MIDNIGHT and InCombatLockdown() then return end
    local C = Colors()
    local tabs = GameTabs()
    local active = ActiveTabIndex()
    local x = -44
    for _, b in pairs(win.tabs) do b:Hide() end
    for _, ov in pairs(overlays) do ov.used = false end
    for i = #tabs, 1, -1 do
        local tab = tabs[i]
        if tab:IsShown() then
            local b = OurTab(i)
            local label = TabLabel(tab, i)
            local w
            if label then
                b.text:SetText(label)
                b.text:Show()
                b.icon:Hide()
                w = math.ceil(b.text:GetStringWidth()) + 14
            else
                local tex, atlas = TabIcon(tab)
                if atlas then b.icon:SetAtlas(atlas) else b.icon:SetTexture(tex or 134400) end
                b.icon:Show()
                b.text:SetText("")
                w = 30
            end
            b:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", win, "TOPRIGHT", x, -9)
            x = x - w
            b.active = (i == active)
            b.line:SetShown(b.active)
            if b.active then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(C.label[1], C.label[2], C.label[3]) end
            b.icon:SetAlpha(b.active and 1 or 0.7)
            b:Show()
            local index = i
            SecureOverlay("tab" .. i, tab, b, function() pendingLearn = index end)
        end
    end
    SecureOverlay("close", _G.CharacterFrameCloseButton or (CharacterFrame and CharacterFrame.CloseButton), win.close)
    for _, ov in pairs(overlays) do if not ov.used then ov:Hide() end end
end

local function NewSlotView(key, side)
    local C = Colors()
    local v = CreateFrame("Frame", nil, win.body)
    v.key = key
    v.side = side
    v:SetSize(side == "weapon" and (MIDNIGHT and 185 or 150) or COL, ICON)
    v.iconFrame = CreateFrame("Frame", nil, v)
    v.iconFrame:SetSize(ICON, ICON)
    v.outline = v.iconFrame:CreateTexture(nil, "BACKGROUND")
    v.outline:SetAllPoints()
    v.outline:SetColorTexture(0.3, 0.3, 0.3, 1)
    v.icon = v.iconFrame:CreateTexture(nil, "ARTWORK")
    v.icon:SetPoint("TOPLEFT", 1, -1)
    v.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    v.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    v.hl = v.iconFrame:CreateTexture(nil, "OVERLAY")
    v.hl:SetAllPoints(v.icon)
    v.hl:SetColorTexture(1, 1, 1, 0.18)
    v.hl:Hide()
    v.name = Text(v, 12, "LEFT")
    v.detail = Text(v, 11, "LEFT")
    v.detail:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    if side == "right" then
        v.iconFrame:SetPoint("RIGHT", v, "RIGHT", 0, 0)
        v.name:SetPoint("BOTTOMRIGHT", v.iconFrame, "LEFT", -8, 1)
        v.name:SetPoint("LEFT", v, "LEFT", 0, 0)
        v.name:SetJustifyH("RIGHT")
        v.detail:SetPoint("TOPRIGHT", v.iconFrame, "LEFT", -8, -2)
        v.detail:SetPoint("LEFT", v, "LEFT", 0, 0)
        v.detail:SetJustifyH("RIGHT")
    else
        v.iconFrame:SetPoint("LEFT", v, "LEFT", 0, 0)
        v.name:SetPoint("BOTTOMLEFT", v.iconFrame, "RIGHT", 8, 1)
        v.name:SetPoint("RIGHT", v, "RIGHT", 0, 0)
        v.detail:SetPoint("TOPLEFT", v.iconFrame, "RIGHT", 8, -2)
        v.detail:SetPoint("RIGHT", v, "RIGHT", 0, 0)
    end
    local id, empty = SlotInfo(key)
    v.slotId, v.emptyTex = id, empty

    -- Our own icon also answers the mouse. Normally the game's slot button lies on top and does
    -- everything; when it does not reach the mouse, this still gives the tooltip, picking the item
    -- up, dropping an item on the slot and Shift-click links.
    local ic = v.iconFrame
    ic:EnableMouse(true)
    ic:SetScript("OnEnter", function(self)
        v.hl:Show()
        if not v.slotId then return end
        GameTooltip:SetOwner(self, v.side == "right" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
        local has = GameTooltip:SetInventoryItem("player", v.slotId)
        if not has then GameTooltip:SetText(SlotLabel(key)) end
        GameTooltip:Show()
    end)
    ic:SetScript("OnLeave", function() v.hl:Hide() GameTooltip:Hide() end)
    ic:SetScript("OnMouseUp", function(_, button)
        if not v.slotId or button ~= "LeftButton" then return end
        local link = GetInventoryItemLink("player", v.slotId)
        if link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
            ChatEdit_InsertLink(link)
            return
        end
        if link and IsModifiedClick and IsModifiedClick("DRESSUP") and DressUpItemLink then
            DressUpItemLink(link)
            return
        end
        PickupInventoryItem(v.slotId)
    end)
    ic:SetScript("OnReceiveDrag", function() if v.slotId then PickupInventoryItem(v.slotId) end end)
    ic:RegisterForDrag("LeftButton")
    ic:SetScript("OnDragStart", function() if v.slotId then PickupInventoryItem(v.slotId) end end)

    slotViews[key] = v
    return v
end

-- name over detail, or just one of them in the middle when the other is switched off
local function ArrangeSlot(v, hasName, hasDetail)
    local SH = ns.H3zCWShared
    if SH then SH.Arrange(v, hasName, hasDetail, Font()) end
end

-- While the game asks for a certain kind of item (the Item Upgrade window, socketing, and so on)
-- the slots that do not fit are dimmed, the way the game's own character window does it
local function ContextDim(v)
    local IBU = _G.ItemButtonUtil
    if not (MIDNIGHT and IBU and IBU.GetItemContext and IBU.GetItemContext() ~= nil) then return 1 end
    if not (ItemLocation and IBU.GetItemContextMatchResultForItem) then return 1 end
    if not GetInventoryItemLink("player", v.slotId) then return 0.3 end
    local loc = ItemLocation:CreateFromEquipmentSlot(v.slotId)
    local ok, r = pcall(IBU.GetItemContextMatchResultForItem, loc)
    if ok and IBU.ItemContextMatchResult and r == IBU.ItemContextMatchResult.Mismatch then return 0.3 end
    return 1
end
CW.ContextDim = ContextDim

local function UpdateSlot(v)
    local C = Colors()
    if not v.slotId then v:Hide() return end
    v:SetAlpha(ContextDim(v))
    local opts = Settings() or {}
    v:Show()
    if v.isAmmo then
        local link = GetInventoryItemLink("player", v.slotId)
        if link then
            local _, _, quality = GetItemInfo(link)
            local r, g, b = QualityColor(quality or GetInventoryItemQuality("player", v.slotId))
            v.icon:SetTexture(GetInventoryItemTexture("player", v.slotId))
            v.icon:SetDesaturated(false)
            v.icon:SetAlpha(1)
            v.outline:SetColorTexture(r, g, b, 1)
            local count = GetInventoryItemCount("player", v.slotId)
            v.detail:SetText((type(count) == "number" and count > 0) and count or "")
            v.detail:SetTextColor(1, 1, 1)
        else
            v.icon:SetTexture(v.emptyTex)
            v.icon:SetDesaturated(true)
            v.icon:SetAlpha(0.45)
            v.outline:SetColorTexture(0.22, 0.24, 0.27, 1)
            v.detail:SetText("")
        end
        v.ilvl, v.counts = nil, false
        return
    end
    local d = ItemData(v.slotId)
    if d then
        local r, g, b = QualityColor(d.quality)
        v.icon:SetTexture(d.icon)
        v.icon:SetDesaturated(false)
        v.icon:SetAlpha(1)
        v.outline:SetColorTexture(r, g, b, 1)
        v.name:SetText(d.name or "")
        v.name:SetTextColor(r, g, b)
        -- detail line: item level, then the upgrade track ("Hero 4/6"), or that it cannot be upgraded
        local SH = ns.H3zCWShared
        local detail = SH and SH.DetailText("player", v.slotId, d.link, d.ilvl, NO_ILVL[v.key], r, g, b) or ""
        local parts = { detail ~= "" and detail or nil }
        v.detail:SetText(detail)
        v.detail:SetTextColor(C.label[1], C.label[2], C.label[3])
        ArrangeSlot(v, opts.cwNames ~= false, #parts > 0)
        v.ilvl, v.counts = d.ilvl, not NO_ILVL[v.key]
    else
        v.icon:SetTexture(v.emptyTex)
        v.icon:SetDesaturated(true)
        v.icon:SetAlpha(0.45)
        v.outline:SetColorTexture(0.22, 0.24, 0.27, 1)
        v.name:SetText(SlotLabel(v.key))
        v.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        v.detail:SetText(_G.EMPTY or "Empty")
        v.detail:SetTextColor(0.4, 0.42, 0.45)
        ArrangeSlot(v, opts.cwNames ~= false, true)
        v.ilvl, v.counts = nil, false
    end
end

---------------------------------------------------------------------------
-- stats
---------------------------------------------------------------------------
local function Secret(v) return issecretvalue and v ~= nil and issecretvalue(v) or false end
local function Num(v) if type(v) == "number" and not Secret(v) then return v end return nil end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil end
    return select(2, unpack(r))
end
local function Pct(v) v = Num(v) return v and string.format("%.2f%%", v) or nil end
local function Whole(v) v = Num(v) return v and tostring(math.floor(v + 0.5)) or nil end

-- each row: { label, valueText, mood } (mood: 1 = raised by a buff, -1 = lowered)
local function StatRow(index, label)
    local base, eff, pos, neg = Call(UnitStat, "player", index)
    eff, pos, neg = Num(eff), Num(pos) or 0, Num(neg) or 0
    if not eff then return nil end
    local mood = (neg < 0 and -1) or (pos > 0 and 1) or 0
    return { label, tostring(math.floor(eff + 0.5)), mood }
end

-- Midnight: secret values (in combat) show their last known value
local lastKnown = {}
local function Keep(key, v)
    if type(v) == "number" and not Secret(v) then lastKnown[key] = v return v, false end
    if lastKnown[key] ~= nil then return lastKnown[key], true end
    return nil, false
end

local function MidnightGroups()
    local L = function(g, fallback) local t = _G[g] return type(t) == "string" and t or fallback end
    local out = {}
    local function Row(list, label, key, value, fmt)
        local v, stale = Keep(key, value)
        if v == nil then return end
        local text
        if fmt == "pct" then text = string.format("%.2f%%", v)
        elseif fmt == "whole" then text = BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(v + 0.5)) or tostring(math.floor(v + 0.5))
        else text = tostring(v) end
        list[#list + 1] = { label, text, stale and 2 or 0 }
    end

    local attr = { key = "attributes", title = L("STAT_CATEGORY_ATTRIBUTES", "Attributes"), rows = {} }
    -- the main stat of your specialization, then stamina
    local primary
    local spec = GetSpecialization and GetSpecialization()
    if spec and GetSpecializationInfo then
        local r = { pcall(GetSpecializationInfo, spec) }
        if r[1] and type(r[7]) == "number" then primary = r[7] end
    end
    local names = { "SPELL_STAT1_NAME", "SPELL_STAT2_NAME", "SPELL_STAT3_NAME", "SPELL_STAT4_NAME" }
    local fall = { "Strength", "Agility", "Stamina", "Intellect" }
    for _, i in ipairs({ primary or 1, 3 }) do
        local _, eff = Call(UnitStat, "player", i)
        Row(attr.rows, L(names[i], fall[i]), "stat" .. i, eff, "whole")
    end
    Row(attr.rows, L("HEALTH", "Health"), "health", Call(UnitHealthMax, "player"), "whole")
    local _, run = Call(GetUnitSpeed, "player")
    if type(run) == "number" and not Secret(run) then run = run / 7 * 100 end
    Row(attr.rows, L("STAT_MOVEMENT_SPEED", "Movement Speed"), "move", run, "pct")
    out[#out + 1] = attr

    local enh = { key = "enhancements", title = L("STAT_CATEGORY_ENHANCEMENTS", "Enhancements"), rows = {} }
    Row(enh.rows, L("STAT_CRITICAL_STRIKE", "Critical Strike"), "crit", Call(GetCritChance), "pct")
    Row(enh.rows, L("STAT_HASTE", "Haste"), "haste", Call(GetHaste), "pct")
    Row(enh.rows, L("STAT_MASTERY", "Mastery"), "mastery", (Call(GetMasteryEffect)), "pct")
    local vers
    if GetCombatRatingBonus and CR_VERSATILITY_DAMAGE_DONE then
        local a = Call(GetCombatRatingBonus, CR_VERSATILITY_DAMAGE_DONE)
        local b = GetVersatilityBonus and Call(GetVersatilityBonus, CR_VERSATILITY_DAMAGE_DONE) or 0
        if type(a) == "number" and not Secret(a) and type(b) == "number" and not Secret(b) then vers = a + b end
    end
    Row(enh.rows, L("STAT_VERSATILITY", "Versatility"), "vers", vers, "pct")
    Row(enh.rows, L("STAT_LIFESTEAL", "Leech"), "leech", Call(GetLifesteal), "pct")
    Row(enh.rows, L("STAT_AVOIDANCE", "Avoidance"), "avoid", Call(GetAvoidance), "pct")
    Row(enh.rows, L("STAT_SPEED", "Speed"), "speed", Call(GetSpeed), "pct")
    out[#out + 1] = enh

    local def = { key = "defense", title = L("STAT_CATEGORY_DEFENSE", "Defense"), rows = {} }
    local _, armor = Call(UnitArmor, "player")
    Row(def.rows, L("STAT_ARMOR", "Armor"), "armor", armor, "whole")
    Row(def.rows, L("STAT_DODGE", "Dodge"), "dodge", Call(GetDodgeChance), "pct")
    local parry = Call(GetParryChance)
    if type(parry) ~= "number" or Secret(parry) or parry > 0 then Row(def.rows, L("STAT_PARRY", "Parry"), "parry", parry, "pct") end
    local block = Call(GetBlockChance)
    if type(block) ~= "number" or Secret(block) or block > 0 then Row(def.rows, L("STAT_BLOCK", "Block"), "block", block, "pct") end
    out[#out + 1] = def
    return out
end

local function Groups()
    if MIDNIGHT then return MidnightGroups() end
    local L = function(g, fallback) local t = _G[g] return type(t) == "string" and t or fallback end
    local out = {}

    local attr = { key = "attributes", title = L("STAT_CATEGORY_ATTRIBUTES", "Attributes"), rows = {} }
    for i, g in ipairs({ "SPELL_STAT1_NAME", "SPELL_STAT2_NAME", "SPELL_STAT3_NAME", "SPELL_STAT4_NAME", "SPELL_STAT5_NAME" }) do
        local r = StatRow(i, L(g, ({ "Strength", "Agility", "Stamina", "Intellect", "Spirit" })[i]))
        if r then r[4] = "stat" .. i attr.rows[#attr.rows + 1] = r end
    end
    local speed = Num((Call(GetUnitSpeed, "player")))
    local runSpeed = select(2, Call(GetUnitSpeed, "player"))
    runSpeed = Num(runSpeed) or speed
    if runSpeed and runSpeed > 0 then
        attr.rows[#attr.rows + 1] = { L("STAT_MOVEMENT_SPEED", "Movement Speed"), string.format("%d%%", math.floor(runSpeed / 7 * 100 + 0.5)), 0, "speed" }
    end
    out[#out + 1] = attr

    local melee = { key = "melee", title = L("PLAYERSTAT_MELEE_COMBAT", "Melee"), rows = {} }
    local lo, hi = Call(UnitDamage, "player")
    lo, hi = Num(lo), Num(hi)
    if lo and hi then melee.rows[#melee.rows + 1] = { L("DAMAGE", "Damage"), string.format("%d - %d", math.floor(lo), math.floor(hi + 0.5)), 0, "mdmg" } end
    local ms = Num((Call(UnitAttackSpeed, "player")))
    if ms then melee.rows[#melee.rows + 1] = { L("ATTACK_SPEED", "Speed"), string.format("%.2f", ms), 0, "mspeed" } end
    local apBase, apPos, apNeg = Call(UnitAttackPower, "player")
    apBase, apPos, apNeg = Num(apBase), Num(apPos) or 0, Num(apNeg) or 0
    if apBase then
        local mood = (apNeg < 0 and -1) or (apPos > 0 and 1) or 0
        melee.rows[#melee.rows + 1] = { L("ATTACK_POWER", "Attack Power"), tostring(math.max(0, math.floor(apBase + apPos + apNeg))), mood, "map" }
    end
    local hit = Num((Call(GetHitModifier)))
    if hit then melee.rows[#melee.rows + 1] = { L("STAT_HIT_CHANCE", "Hit Chance"), Pct(hit), 0, "mhit" } end
    local crit = Num((Call(GetCritChance)))
    if crit then melee.rows[#melee.rows + 1] = { L("MELEE_CRIT_CHANCE", "Crit Chance"), Pct(crit), 0, "mcrit" } end
    local exp = Num((Call(GetExpertise)))
    if exp and exp > 0 then melee.rows[#melee.rows + 1] = { L("STAT_EXPERTISE", "Expertise"), Whole(exp), 0, "mexp" } end
    out[#out + 1] = melee

    local hasRanged = GetInventoryItemLink("player", (SlotInfo("Ranged")) or 18) ~= nil
    if hasRanged then
        local ranged = { key = "ranged", title = L("PLAYERSTAT_RANGED_COMBAT", "Ranged"), rows = {} }
        local rs, rlo, rhi = Call(UnitRangedDamage, "player")
        rs, rlo, rhi = Num(rs), Num(rlo), Num(rhi)
        if rlo and rhi then ranged.rows[#ranged.rows + 1] = { L("DAMAGE", "Damage"), string.format("%d - %d", math.floor(rlo), math.floor(rhi + 0.5)), 0, "rdmg" } end
        if rs and rs > 0 then ranged.rows[#ranged.rows + 1] = { L("ATTACK_SPEED", "Speed"), string.format("%.2f", rs), 0, "rspeed" } end
        local rb, rp, rn = Call(UnitRangedAttackPower, "player")
        rb, rp, rn = Num(rb), Num(rp) or 0, Num(rn) or 0
        if rb then ranged.rows[#ranged.rows + 1] = { L("ATTACK_POWER", "Attack Power"), tostring(math.max(0, math.floor(rb + rp + rn))), (rn < 0 and -1) or (rp > 0 and 1) or 0, "rap" } end
        local rc = Num((Call(GetRangedCritChance)))
        if rc then ranged.rows[#ranged.rows + 1] = { L("RANGED_CRIT_CHANCE", "Crit Chance"), Pct(rc), 0, "rcrit" } end
        out[#out + 1] = ranged
    end

    local spell = { key = "spell", title = L("PLAYERSTAT_SPELL_COMBAT", "Spell"), rows = {} }
    local sd = Num((Call(GetSpellBonusDamage, 2)))
    if sd then spell.rows[#spell.rows + 1] = { L("STAT_SPELLDAMAGE", "Spell Damage"), Whole(sd), 0, "sdmg" } end
    local sh = Num((Call(GetSpellBonusHealing)))
    if sh then spell.rows[#spell.rows + 1] = { L("STAT_SPELLHEALING", "Spell Healing"), Whole(sh), 0, "sheal" } end
    local shit = Num((Call(GetSpellHitModifier)))
    if shit then spell.rows[#spell.rows + 1] = { L("STAT_HIT_CHANCE", "Hit Chance"), Pct(shit), 0, "shit" } end
    local sc
    for school = 2, 7 do
        local v = Num((Call(GetSpellCritChance, school)))
        if v and (not sc or v > sc) then sc = v end
    end
    if sc then spell.rows[#spell.rows + 1] = { L("SPELL_CRIT_CHANCE", "Crit Chance"), Pct(sc), 0, "scrit" } end
    local base, casting = Call(GetManaRegen)
    casting = Num(casting)
    if casting and UnitPowerType("player") == 0 then
        spell.rows[#spell.rows + 1] = { L("MANA_REGEN", "Mana Regen"), Whole(casting * 5), 0, "regen" }
    end
    if #spell.rows > 0 then out[#out + 1] = spell end

    local def = { key = "defense", title = L("PLAYERSTAT_DEFENSES", "Defense"), rows = {} }
    local abase, aeff, _, apos, aneg = Call(UnitArmor, "player")
    aeff, apos, aneg = Num(aeff), Num(apos) or 0, Num(aneg) or 0
    if aeff then def.rows[#def.rows + 1] = { L("ARMOR", "Armor"), tostring(math.floor(aeff)), (aneg < 0 and -1) or (apos > 0 and 1) or 0, "armor" } end
    local dbase, dmod = Call(UnitDefense, "player")
    dbase, dmod = Num(dbase), Num(dmod) or 0
    if dbase then def.rows[#def.rows + 1] = { L("DEFENSE", "Defense"), tostring(math.floor(dbase + dmod)), dmod > 0 and 1 or (dmod < 0 and -1 or 0), "defense" } end
    local dodge = Num((Call(GetDodgeChance)))
    if dodge then def.rows[#def.rows + 1] = { L("STAT_DODGE", "Dodge"), Pct(dodge), 0, "dodge" } end
    local parry = Num((Call(GetParryChance)))
    if parry and parry > 0 then def.rows[#def.rows + 1] = { L("STAT_PARRY", "Parry"), Pct(parry), 0, "parry" } end
    local block = Num((Call(GetBlockChance)))
    if block and block > 0 then def.rows[#def.rows + 1] = { L("STAT_BLOCK", "Block"), Pct(block), 0, "block" } end
    out[#out + 1] = def
    return out
end

---------------------------------------------------------------------------
-- stat tooltips (WoW: Forever and Classic): what each number is and does,
-- worked out from your own numbers the way the game's character window does
---------------------------------------------------------------------------
local SCHOOLS = { { 2, "Holy" }, { 3, "Fire" }, { 4, "Nature" }, { 5, "Frost" }, { 6, "Shadow" }, { 7, "Arcane" } }
local SCHOOL_GLOBALS = { [2] = "SPELL_SCHOOL1_CAP", [3] = "SPELL_SCHOOL2_CAP", [4] = "SPELL_SCHOOL3_CAP",
    [5] = "SPELL_SCHOOL4_CAP", [6] = "SPELL_SCHOOL5_CAP", [7] = "SPELL_SCHOOL6_CAP" }
local function SchoolName(id, fallback)
    local g = _G[SCHOOL_GLOBALS[id]]
    return type(g) == "string" and g or fallback
end
local function F1(v) return string.format("%.1f", v) end
local function F2(v) return string.format("%.2f", v) end

local function StatTip(id)
    local lines = {}
    local function Add(a, b) lines[#lines + 1] = b and { a, b } or a end
    local _, class = UnitClass("player")
    local level = UnitLevel("player") or 1
    if id and id:match("^stat%d$") then
        local i = tonumber(id:sub(5))
        local base, eff, pos, neg = Call(UnitStat, "player", i)
        base, eff, pos, neg = Num(base) or 0, Num(eff) or 0, Num(pos) or 0, Num(neg) or 0
        local head = tostring(math.floor(eff + 0.5))
        if pos ~= 0 or neg ~= 0 then
            head = head .. string.format("  (%d%s%s)", math.floor(base + 0.5),
                pos > 0 and ("|cff20ff20+" .. math.floor(pos + 0.5) .. "|r") or "",
                neg < 0 and ("|cffff2020" .. math.floor(neg + 0.5) .. "|r") or "")
        end
        Add(head)
        if i == 1 then
            local ap = (class == "DRUID" or class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN") and 2 or 1
            Add(string.format("Increases melee attack power by %d.", math.floor(eff * ap)))
            if class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN" then
                Add("Increases the damage your shield blocks.")
            end
        elseif i == 2 then
            Add("Increases ranged attack power, critical strike chance, armor and dodge chance.")
            local c = GetCritChanceFromAgility and Num((Call(GetCritChanceFromAgility, "player")))
            if c then Add("Crit chance from Agility", F2(c) .. "%") end
            Add("Armor from Agility", tostring(math.floor(eff * 2)))
        elseif i == 3 then
            local hp = math.min(20, eff) + math.max(0, eff - 20) * 10
            Add(string.format("Increases health by %d.", math.floor(hp)))
        elseif i == 4 then
            if UnitPowerType("player") == 0 or class == "DRUID" then
                local mana = math.min(20, eff) + math.max(0, eff - 20) * 15
                Add(string.format("Increases mana by %d.", math.floor(mana)))
                local c = GetSpellCritChanceFromIntellect and Num((Call(GetSpellCritChanceFromIntellect, "player")))
                if c then Add("Spell crit from Intellect", F2(c) .. "%") end
                Add("Also makes your weapon skills rise faster.")
            else
                Add("Makes your weapon skills rise faster.")
            end
        elseif i == 5 then
            local hr = GetUnitHealthRegenRateFromSpirit and Num((Call(GetUnitHealthRegenRateFromSpirit, "player")))
            if hr then Add("Health regen out of combat", F1(hr * 2) .. " per 2 sec") end
            if UnitPowerType("player") == 0 or class == "DRUID" then
                local mr = GetUnitManaRegenRateFromSpirit and Num((Call(GetUnitManaRegenRateFromSpirit, "player")))
                if mr then Add("Mana regen while not casting", F1(mr * 2) .. " per 2 sec") end
                Add("Mana regen from Spirit stops for 5 seconds after you cast.")
            else
                Add("Increases health regeneration while out of combat.")
            end
        end
    elseif id == "speed" then
        Add("How fast you move, compared with normal running speed (100%).")
    elseif id == "mdmg" or id == "mspeed" then
        local ms, os = Call(UnitAttackSpeed, "player")
        ms, os = Num(ms), Num(os)
        local lo, hi, olo, ohi = Call(UnitDamage, "player")
        lo, hi, olo, ohi = Num(lo), Num(hi), Num(olo), Num(ohi)
        if lo and hi and ms and ms > 0 then
            Add("Main hand")
            Add("  Damage", string.format("%d - %d", math.floor(lo), math.floor(hi + 0.5)))
            Add("  Speed", F2(ms) .. " sec")
            Add("  Damage per second", F1((lo + hi) / 2 / ms))
        end
        if olo and ohi and os and os > 0 and ohi > 0 then
            Add("Off hand")
            Add("  Damage", string.format("%d - %d", math.floor(olo), math.floor(ohi + 0.5)))
            Add("  Speed", F2(os) .. " sec")
            Add("  Damage per second", F1((olo + ohi) / 2 / os))
        end
        if id == "mspeed" then Add("Seconds between your melee swings. Lower is faster.") end
    elseif id == "map" or id == "rap" then
        local b, p, n
        if id == "map" then b, p, n = Call(UnitAttackPower, "player") else b, p, n = Call(UnitRangedAttackPower, "player") end
        b, p, n = Num(b) or 0, Num(p) or 0, Num(n) or 0
        local ap = math.max(0, b + p + n)
        Add(string.format("%d  (%d%s%s)", math.floor(ap), math.floor(b),
            p > 0 and ("|cff20ff20+" .. math.floor(p) .. "|r") or "", n < 0 and ("|cffff2020" .. math.floor(n) .. "|r") or ""))
        Add(string.format("Increases %s damage by %s damage per second.", id == "map" and "melee" or "ranged", F1(ap / 14)))
    elseif id == "mhit" or id == "shit" then
        local v = Num((Call(id == "mhit" and GetHitModifier or GetSpellHitModifier))) or 0
        Add(string.format("+%s%% chance to hit from your gear and talents.", F2(v)))
        Add(id == "mhit" and "Lowers the chance your attacks miss." or "Lowers the chance your spells are resisted.")
    elseif id == "mcrit" or id == "rcrit" then
        Add(id == "mcrit" and "Chance for your melee attacks to hit for double damage."
            or "Chance for your ranged attacks to hit for extra damage.")
    elseif id == "mexp" then
        Add("Lowers the chance your attacks are dodged or parried.")
    elseif id == "rdmg" or id == "rspeed" then
        local rs, rlo, rhi = Call(UnitRangedDamage, "player")
        rs, rlo, rhi = Num(rs), Num(rlo), Num(rhi)
        if rlo and rhi and rs and rs > 0 then
            Add("Damage", string.format("%d - %d", math.floor(rlo), math.floor(rhi + 0.5)))
            Add("Speed", F2(rs) .. " sec")
            Add("Damage per second", F1((rlo + rhi) / 2 / rs))
        end
    elseif id == "sdmg" then
        Add("Bonus damage by school:")
        for _, sc in ipairs(SCHOOLS) do
            local v = Num((Call(GetSpellBonusDamage, sc[1])))
            if v then Add("  " .. SchoolName(sc[1], sc[2]), tostring(math.floor(v + 0.5))) end
        end
    elseif id == "sheal" then
        local v = Num((Call(GetSpellBonusHealing))) or 0
        Add(string.format("Increases your healing by up to %d.", math.floor(v + 0.5)))
    elseif id == "scrit" then
        Add("Chance for your spells to hit for extra damage or healing, by school:")
        for _, sc in ipairs(SCHOOLS) do
            local v = Num((Call(GetSpellCritChance, sc[1])))
            if v then Add("  " .. SchoolName(sc[1], sc[2]), F2(v) .. "%") end
        end
    elseif id == "regen" then
        local base, casting = Call(GetManaRegen)
        base, casting = Num(base), Num(casting)
        if base then Add("While not casting", string.format("%d per 5 sec", math.floor(base * 5 + 0.5))) end
        if casting then Add("While casting", string.format("%d per 5 sec", math.floor(casting * 5 + 0.5))) end
        Add("Mana comes back faster when you have not cast for 5 seconds.")
    elseif id == "armor" then
        local _, eff = Call(UnitArmor, "player")
        eff = Num(eff) or 0
        local red = eff / (eff + 400 + 85 * level) * 100
        Add(string.format("Reduces physical damage taken by %s%%", F2(math.min(75, red))))
        Add("(against enemies of your level).")
    elseif id == "defense" then
        local b, m = Call(UnitDefense, "player")
        b, m = Num(b) or 0, Num(m) or 0
        local over = (b + m - level * 5) * 0.04
        Add(string.format("%s%% more chance to dodge, block and parry,", F2(math.max(0, over))))
        Add(string.format("and %s%% less chance to be hit and critically hit.", F2(math.max(0, over))))
    elseif id == "dodge" then
        Add("Chance to dodge enemy melee attacks.")
    elseif id == "parry" then
        Add("Chance to parry enemy melee attacks.")
    elseif id == "block" then
        local bv = GetShieldBlock and Num((Call(GetShieldBlock)))
        Add("Chance to block enemy melee attacks with your shield.")
        if bv then Add("Damage blocked", tostring(math.floor(bv))) end
    else
        return nil
    end
    return lines
end

local function ShowStatTip(row)
    if not row.tipId then return end
    local lines = StatTip(row.tipId)
    if not lines then return end
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    GameTooltip:SetText(row.label:GetText() or "", 1, 1, 1)
    for _, l in ipairs(lines) do
        if type(l) == "table" then
            GameTooltip:AddDoubleLine(l[1], l[2], 0.85, 0.85, 0.85, 1, 1, 1)
        else
            GameTooltip:AddLine(l, 1, 0.82, 0, true)
        end
    end
    GameTooltip:Show()
end

local function BuildStats()
    local C = Colors()
    local inset = Panel(win.body, 8, { 0, 0, 0 }, 0.28)
    inset:SetPoint("TOPRIGHT", win.body, "TOPRIGHT", 0, 0)
    inset:SetPoint("BOTTOMRIGHT", win.body, "BOTTOMRIGHT", 0, 0)
    inset:SetWidth(STATS_W)
    win.statsInset = inset

    local sf = CreateFrame("ScrollFrame", nil, win.body)
    sf:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -8)
    sf:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, 8)
    sf:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(STATS_W - 20, 10)
    sf:SetScrollChild(child)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        local v = math.min(max, math.max(0, self:GetVerticalScroll() - delta * 30))
        self:SetVerticalScroll(v)
    end)
    win.statsScroll, win.statsChild = sf, child
    win.statPool, win.headPool = {}, {}
end

local function GetHead(i)
    local C = Colors()
    local h = win.headPool[i]
    if h then return h end
    h = CreateFrame("Button", nil, win.statsChild)
    h:SetHeight(GROUP_HEAD)
    h.text = Text(h, 13, "LEFT")
    h.text:SetPoint("LEFT", 0, 1)
    h.text:SetTextColor(C.head[1], C.head[2], C.head[3])
    h.state = Text(h, 13, "RIGHT")
    h.state:SetPoint("RIGHT", 0, 1)
    h.state:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    h.line = h:CreateTexture(nil, "ARTWORK")
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT", 0, 2)
    h.line:SetPoint("BOTTOMRIGHT", 0, 2)
    h.line:SetColorTexture(C.head[1], C.head[2], C.head[3], 0.55)
    h:SetScript("OnClick", function(self)
        local s = Settings()
        if not s then return end
        s.h3zWindowFolds[self.key] = not s.h3zWindowFolds[self.key] or nil
        CW.UpdateStats()
    end)
    win.headPool[i] = h
    return h
end

local function GetRow(i)
    local r = win.statPool[i]
    if r then return r end
    r = CreateFrame("Frame", nil, win.statsChild)
    r:SetHeight(STAT_ROW)
    r.stripe = r:CreateTexture(nil, "BACKGROUND")
    r.stripe:SetAllPoints()
    r.stripe:SetColorTexture(1, 1, 1, 0.035)
    r.label = Text(r, 12, "LEFT")
    r.label:SetPoint("LEFT", 4, 0)
    r.value = Text(r, 12, "RIGHT")
    r.value:SetPoint("RIGHT", -4, 0)
    r.label:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
    -- hover: what the number is and what it does
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        self.stripe:SetColorTexture(1, 1, 1, 0.09)
        self.stripe:Show()
        ShowStatTip(self)
    end)
    r:SetScript("OnLeave", function(self)
        self.stripe:SetColorTexture(1, 1, 1, 0.035)
        self.stripe:SetShown(self.striped)
        GameTooltip:Hide()
    end)
    win.statPool[i] = r
    return r
end

function CW.UpdateStats()
    if not (win and win:IsShown() and win.statsChild) then return end
    local C = Colors()
    local s = Settings() or { h3zWindowFolds = {} }
    for _, h in ipairs(win.headPool) do h:Hide() end
    for _, r in ipairs(win.statPool) do r:Hide() end
    local y, hi, ri = 0, 0, 0
    local w = win.statsChild:GetWidth()
    for gi, g in ipairs(Groups()) do
        if gi > 1 then y = y + 6 end
        hi = hi + 1
        local h = GetHead(hi)
        h.key = g.key
        h.text:SetText(g.title)
        local folded = s.h3zWindowFolds[g.key]
        h.state:SetText(folded and "+" or "-")
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", win.statsChild, "TOPLEFT", 0, -y)
        h:SetWidth(w)
        h:Show()
        y = y + GROUP_HEAD
        if not folded then
            for n, row in ipairs(g.rows) do
                if row[2] then
                    ri = ri + 1
                    local r = GetRow(ri)
                    r.label:SetText(row[1])
                    r.label:SetTextColor(C.label[1], C.label[2], C.label[3])
                    r.value:SetText(row[2])
                    if row[3] == 2 then r.value:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
                    elseif row[3] == 1 then r.value:SetTextColor(C.up[1], C.up[2], C.up[3])
                    elseif row[3] == -1 then r.value:SetTextColor(C.down[1], C.down[2], C.down[3])
                    else r.value:SetTextColor(C.text[1], C.text[2], C.text[3]) end
                    r.striped = (n % 2 == 1)
                    r.stripe:SetShown(r.striped)
                    r.tipId = row[4]
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", win.statsChild, "TOPLEFT", 0, -y)
                    r:SetWidth(w)
                    r:Show()
                    y = y + STAT_ROW
                end
            end
        end
    end
    win.statsChild:SetHeight(math.max(10, y))
    local max = math.max(0, y - win.statsScroll:GetHeight())
    if win.statsScroll:GetVerticalScroll() > max then win.statsScroll:SetVerticalScroll(max) end
end

---------------------------------------------------------------------------
-- body layout: two slot columns round the model, weapons underneath
---------------------------------------------------------------------------
local function BuildBody()
    win.body = CreateFrame("Frame", nil, win)
    win.body:SetPoint("TOPLEFT", win, "TOPLEFT", EDGE, -HEADER)
    win.body:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -EDGE, FOOTER + 6)

    -- model area: our own model of you, drag to turn it
    win.modelBox = CreateFrame("Frame", nil, win.body)
    win.modelBox:SetPoint("TOPLEFT", win.body, "TOPLEFT", COL + 8, 0)
    win.modelBox:SetPoint("BOTTOMRIGHT", win.body, "BOTTOMRIGHT", -(STATS_W + 10 + COL + 8), ICON + 14)
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
            local x = GetCursorPosition()
            local d = (x - self.turning) * 0.012
            self.turning = x
            if d ~= 0 and self.GetFacing then self:SetFacing((self:GetFacing() or 0) + d) end
        end)
        win.model = model
    end

    for i, key in ipairs(LEFT) do
        local v = NewSlotView(key, "left")
        v:SetPoint("TOPLEFT", win.body, "TOPLEFT", 0, -(i - 1) * ROW)
    end
    for i, key in ipairs(RIGHT) do
        local v = NewSlotView(key, "right")
        v:SetPoint("TOPRIGHT", win.body, "TOPRIGHT", -(STATS_W + 10), -(i - 1) * ROW)
    end
    -- weapons: centered under the model, the middle one on the model's center
    local n = #WEAPONS
    for i, key in ipairs(WEAPONS) do
        local v = NewSlotView(key, "weapon")
        v:SetWidth(MIDNIGHT and 185 or 150)
        v.weaponIndex = i - (n + 1) / 2
    end
    -- ammo: a small slot right after the ranged slot, for the classes that shoot ammo
    local _, classFile = UnitClass("player")
    if (classFile == "HUNTER" or classFile == "ROGUE" or classFile == "WARRIOR") and SlotInfo("Ammo") then
        local v = NewSlotView("Ammo", "weapon")
        v.isAmmo = true
        v:SetSize(30, 30)
        v.iconFrame:SetSize(30, 30)
        v.name:Hide()
        v.detail:ClearAllPoints()
        v.detail:SetPoint("BOTTOMRIGHT", v.iconFrame, "BOTTOMRIGHT", -1, 2)
        v.detail:SetJustifyH("RIGHT")
    end
    BuildStats()
end

local function LayoutWeapons()
    local shown = {}
    for _, key in ipairs(WEAPONS) do
        local v = slotViews[key]
        if v and v.slotId then shown[#shown + 1] = v end
    end
    local step = MIDNIGHT and 190 or 150   -- Midnight rows also carry the upgrade track
    local total = #shown
    for i, v in ipairs(shown) do
        v:ClearAllPoints()
        local off = (i - (total + 1) / 2) * step
        v:SetPoint("TOP", win.modelBox, "BOTTOM", off, -8)
    end
    local ammo, ranged = slotViews.Ammo, slotViews.Ranged
    if ammo and ranged and ranged.slotId then
        ammo:ClearAllPoints()
        ammo:SetPoint("LEFT", ranged, "RIGHT", 6, 0)
    end
end

local function BuildFooter()
    local C = Colors()
    win.footLine = win:CreateTexture(nil, "ARTWORK")
    win.footLine:SetHeight(1)
    win.footLine:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", EDGE, FOOTER)
    win.footLine:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -EDGE, FOOTER)
    win.footLine:SetColorTexture(1, 1, 1, 0.07)
    win.footIlvl = Text(win, 12, "LEFT")
    win.footIlvl:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", EDGE + 2, 11)
    win.footDura = Text(win, 12, "LEFT")
    win.footDura:SetPoint("LEFT", win.footIlvl, "RIGHT", 24, 0)
end

-- the Settings button in the footer (after the logo is made, so it sits left of it)
local function BuildSettingsButton()
    local SH = ns.H3zCWShared
    if SH and not win.settingsBtn then win.settingsBtn = SH.FooterButton(win, win.logoText, win.logo) end
end

local function Colored(label, value, r, g, b)
    return string.format("|cffa0a8b4%s|r  |cff%02x%02x%02x%s|r", label, r * 255, g * 255, b * 255, value)
end

local function UpdateFooter()
    local sum, n = 0, 0
    local twoHand = false
    for key, v in pairs(slotViews) do
        if v.counts and v.ilvl then sum, n = sum + v.ilvl, n + 1 end
        if key == "MainHand" and v.slotId then
            local link = GetInventoryItemLink("player", v.slotId)
            local equipLoc = link and select(9, GetItemInfo(link))
            if equipLoc == "INVTYPE_2HWEAPON" then twoHand = true end
        end
    end
    -- a two-hander fills the off hand too, as the game counts it
    if twoHand and slotViews.MainHand and slotViews.MainHand.ilvl and not (slotViews.SecondaryHand and slotViews.SecondaryHand.ilvl) then
        sum, n = sum + slotViews.MainHand.ilvl, n + 1
    end
    local avg = n > 0 and sum / n or 0
    local avgFmt = "%.0f"
    if MIDNIGHT and GetAverageItemLevel then
        local ok, _, equipped = pcall(GetAverageItemLevel)
        if ok and type(equipped) == "number" and not Secret(equipped) then avg, avgFmt = equipped, "%.1f" end
    end
    local C = Colors()
    local label = (_G.ITEM_LEVEL_ABBR or "Item Level")
    if type(_G.STAT_AVERAGE_ITEM_LEVEL) == "string" then label = _G.STAT_AVERAGE_ITEM_LEVEL end
    win.footIlvl:SetText(Colored(label, string.format(avgFmt, avg), C.up[1], C.up[2], C.up[3]))

    local cur, max = 0, 0
    for i = 1, 19 do
        local c, m = GetInventoryItemDurability(i)
        if Num(c) and Num(m) and m > 0 then cur, max = cur + c, max + m end
    end
    local pct = max > 0 and math.floor(cur / max * 100 + 0.5) or 100
    local r, g, b = C.up[1], C.up[2], C.up[3]
    if pct < 25 then r, g, b = C.down[1], C.down[2], C.down[3] elseif pct < 60 then r, g, b = 1, 0.82, 0.3 end
    win.footDura:SetText(Colored(_G.DURABILITY or "Durability", pct .. "%", r, g, b))
end

---------------------------------------------------------------------------
-- Midnight tabs. Every tab is a secure button that runs the game's own
-- clicks (a "/click" macro), so the game's window code runs untainted:
--   Character, Titles, Equipment Sets (the sidebar of the character page),
--   then every other tab of the game's window (Reputation, Currency, ...).
-- They can only be made and moved out of combat. When they do not fit,
-- arrows at the ends of the row page through them.
---------------------------------------------------------------------------
local midTabs = {}          -- secure buttons, by id
local midFirst = 1          -- first tab shown when they do not all fit
local sidePane = "stats"    -- what the right panel shows: stats, titles, equipment

local function MidTabDefs()
    local defs = {}
    local function Add(id, label, macro) defs[#defs + 1] = { id = id, label = label, macro = macro } end
    if _G.CharacterFrameTab1 then
        local stats = _G.PaperDollSidebarTab1 and "\n/click PaperDollSidebarTab1" or ""
        Add("character", _G.CHARACTER or "Character", "/click CharacterFrameTab1" .. stats)
        local t2, t3 = _G.PaperDollSidebarTab2, _G.PaperDollSidebarTab3
        if t2 and t2:IsShown() then Add("titles", _G.PAPERDOLL_SIDEBAR_TITLES or _G.TITLES or "Titles", "/click CharacterFrameTab1\n/click PaperDollSidebarTab2") end
        if t3 and t3:IsShown() then Add("equipment", _G.PAPERDOLL_EQUIPMENTMANAGER or _G.EQUIPMENT_MANAGER or "Equipment Sets", "/click CharacterFrameTab1\n/click PaperDollSidebarTab3") end
    end
    for i = 2, 12 do
        local t = _G["CharacterFrameTab" .. i]
        if not t then break end
        if t:IsShown() then
            local ok, label = pcall(t.GetText, t)
            if not (ok and type(label) == "string" and label ~= "") then label = "Tab " .. i end
            Add("tab" .. i, label, "/click CharacterFrameTab" .. i)
        end
    end
    return defs
end

-- which of our tabs is the one open now
local function MidActiveId()
    local n = CharacterFrame and CharacterFrame.selectedTab
    if type(n) ~= "number" or n == 1 then
        if currentPage ~= "character" then return nil end
        if sidePane == "titles" or sidePane == "equipment" then return sidePane end
        return "character"
    end
    return "tab" .. n
end

local function MidTabButton(id)
    local C = Colors()
    local b = midTabs[id]
    if b then return b end
    b = CreateFrame("Button", nil, win, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetHeight(22)
    b:SetFrameLevel(math.min(9500, win:GetFrameLevel() + 300))
    b.text = Text(b, 11, "CENTER")
    b.text:SetPoint("CENTER", 0, 1)
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", 4, 0)
    b.line:SetPoint("BOTTOMRIGHT", -4, 0)
    b.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    b:SetScript("OnEnter", function(self) if not self.active then self.text:SetTextColor(1, 1, 1) end end)
    b:SetScript("OnLeave", function(self) if not self.active then self.text:SetTextColor(C.label[1], C.label[2], C.label[3]) end end)
    midTabs[id] = b
    return b
end

local function MidArrow(dir)
    local key = dir < 0 and "arrowL" or "arrowR"
    if win[key] then return win[key] end
    local C = Colors()
    local a = CreateFrame("Button", nil, win)
    a:SetSize(16, 22)
    a:SetFrameLevel(math.min(9500, win:GetFrameLevel() + 300))
    a.text = Text(a, 13, "CENTER")
    a.text:SetAllPoints()
    a.text:SetText(dir < 0 and "<" or ">")
    a.text:SetTextColor(C.label[1], C.label[2], C.label[3])
    a:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    a:SetScript("OnLeave", function(self) self.text:SetTextColor(C.label[1], C.label[2], C.label[3]) end)
    a:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        midFirst = math.max(1, midFirst + dir)
        CW.LayoutMidTabs()
    end)
    win[key] = a
    return a
end

function CW.LayoutMidTabs()
    if not win then return end
    if InCombatLockdown() then CW.midTabsDirty = true return end
    CW.midTabsDirty = false
    local C = Colors()
    local defs = MidTabDefs()
    local active = MidActiveId()
    local used = {}
    local right = WIN_W - 40            -- tabs end left of the X
    local left = 230                    -- and start right of the name
    local widths, total = {}, 0
    for i, def in ipairs(defs) do
        local b = MidTabButton(def.id)
        b.text:SetText(def.label)
        widths[i] = math.ceil(b.text:GetStringWidth()) + 14
        total = total + widths[i]
    end
    local fits = total <= (right - left)
    if fits then midFirst = 1 end
    local arrowL, arrowR = MidArrow(-1), MidArrow(1)
    arrowL:Hide() arrowR:Hide()
    local avail = right - left
    if not fits then avail = avail - 36 end
    -- the tabs that fit from midFirst on
    midFirst = math.min(midFirst, #defs)
    local last, w = midFirst - 1, 0
    for i = midFirst, #defs do
        if w + widths[i] > avail then break end
        w = w + widths[i]
        last = i
    end
    local x = right - (fits and 0 or 18)
    for i = last, midFirst, -1 do
        local def = defs[i]
        local b = midTabs[def.id]
        b:SetAttribute("macrotext", def.macro)
        b:SetWidth(widths[i])
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", win, "TOPLEFT", x, -9)
        x = x - widths[i]
        b.active = (def.id == active)
        b.line:SetShown(b.active)
        if b.active then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(C.label[1], C.label[2], C.label[3]) end
        b:Show()
        used[def.id] = true
    end
    for id, b in pairs(midTabs) do if not used[id] then b:Hide() end end
    if not fits then
        arrowL:ClearAllPoints()
        arrowL:SetPoint("TOPRIGHT", win, "TOPLEFT", x, -9)
        arrowL:SetShown(midFirst > 1)
        arrowR:ClearAllPoints()
        arrowR:SetPoint("TOPRIGHT", win, "TOPLEFT", right, -9)
        arrowR:SetShown(last < #defs)
    end
    -- the X: presses the game's close button
    if not win.secureClose then
        local cb = _G.CharacterFrameCloseButton or (CharacterFrame and CharacterFrame.CloseButton)
        if cb then
            -- the X itself is the secure button (the plain one is hidden), a bit bigger to hit
            local C2 = Colors()
            local sc = CreateFrame("Button", nil, win, "SecureActionButtonTemplate")
            sc:RegisterForClicks("AnyUp")
            sc:SetAttribute("type", "click")
            sc:SetAttribute("clickbutton", cb)
            sc:SetSize(28, 28)
            sc:SetPoint("TOPRIGHT", win, "TOPRIGHT", -7, -7)
            sc:SetHitRectInsets(0, 0, 0, 0)
            local x = Text(sc, 15, "CENTER")
            x:SetAllPoints()
            x:SetText("x")
            x:SetTextColor(C2.label[1], C2.label[2], C2.label[3])
            sc:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1) end)
            sc:SetScript("OnLeave", function() x:SetTextColor(C2.label[1], C2.label[2], C2.label[3]) end)
            win.close:Hide()
            win.secureClose = sc
            CW.RaiseTabs()
        end
    end
end

-- The tabs and the X stay above everything in the window. The game's Reputation and Currency
-- pages shown inside it have parts (the filter and transfer buttons, dropdowns) up at the top
-- right that sat over the last tab and the X and took their clicks now and then.
-- The game's own window under ours has parts placed very high (its title bar and close button
-- sit at a fixed high level), which were over our X and the last tabs at times. So the tabs and
-- the X go above the highest part of the game's window too, and the game's hidden close button
-- no longer catches clicks while ours is shown (ours presses it).
local function HighestLevel(f, depth, skip)
    local best = f:GetFrameLevel() or 0
    if depth <= 0 then return best end
    for _, c in ipairs({ f:GetChildren() }) do
        if c ~= skip then
            local l = HighestLevel(c, depth - 1, skip)
            if l > best then best = l end
        end
    end
    return best
end
local gameTop, gameTopAt = 0, 0
function CW.RaiseTabs()
    if not win or InCombatLockdown() then return end
    local now = GetTime()
    if now - gameTopAt > 2 and CharacterFrame then
        gameTopAt = now
        gameTop = HighestLevel(CharacterFrame, 2, win)
    end
    local lvl = math.min(9800, math.max(win:GetFrameLevel() + 300, gameTop + 10))
    -- the game's own buttons under our header (its sidebar tabs, close button) stop catching clicks
    if parked and gameTopAt == now and ns.H3zCWShared then
        CW.blocked = ns.H3zCWShared.Unblock(CharacterFrame, win, HEADER, CW.blocked)
    end
    for _, b in pairs(midTabs) do if b:GetFrameLevel() ~= lvl then b:SetFrameLevel(lvl) end end
    for _, k in ipairs({ "arrowL", "arrowR", "secureClose" }) do
        local f = win[k]
        if f and f:GetFrameLevel() ~= lvl then f:SetFrameLevel(lvl) end
    end
end

local function UpdateHeader()
    win.name:SetText(UnitName("player") or "")
    local level = UnitLevel("player") or ""
    local race = UnitRace("player") or ""
    local className, classFile = UnitClass("player")
    local cc = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    local classText = className or ""
    if cc then classText = string.format("|cff%02x%02x%02x%s|r", cc.r * 255, cc.g * 255, cc.b * 255, classText) end
    local lvl = _G.LEVEL or "Level"
    win.sub:SetText(string.format("%s %s %s %s", lvl, level, race, classText))
    if MIDNIGHT then CW.LayoutMidTabs() else LayoutTabs() end
end

function CW.UpdateModel()
    if win and win.model and win:IsShown() then
        pcall(win.model.SetUnit, win.model, "player")
    end
end

function CW.UpdateAll()
    if not (win and win:IsShown()) then return end
    UpdateHeader()
    if UpdateArt then UpdateArt() end
    if currentPage ~= "character" then return end
    for _, v in pairs(slotViews) do UpdateSlot(v) end
    LayoutWeapons()
    UpdateFooter()
    CW.UpdateStats()
end

local function Build()
    if win then return win end
    if MIDNIGHT then
        -- Midnight: part of the game's window. It shows and hides with it (the game does that, so
        -- no addon code shows or hides anything with secure buttons on it in combat), it is
        -- placed once and never moved, and it stays visible while the game's window is see-through.
        win = CreateFrame("Frame", "H3z0UI_CharacterWindow", CharacterFrame)
        if win.SetIgnoreParentAlpha then win:SetIgnoreParentAlpha(true) end
        win:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
        win:SetFrameLevel(math.min(9000, (CharacterFrame:GetFrameLevel() or 1) + 40))
    else
        win = CreateFrame("Frame", "H3z0UI_CharacterWindow", UIParent)
        win:SetFrameStrata("MEDIUM")
        win:SetToplevel(true)
        win:SetClampedToScreen(true)
        win:Hide()
    end
    win:SetSize(WIN_W, WIN_H)
    win:SetScale(Scale())
    win:EnableMouse(true)
    local bg = Panel(win, 10)
    bg:SetAllPoints(win)
    bg:SetFrameLevel(math.max(0, win:GetFrameLevel() - 1))
    win.bg = bg
    -- your homeland behind the Character page, darker towards the edges
    win.art = win:CreateTexture(nil, "BACKGROUND", nil, 1)
    win.art:SetPoint("TOPLEFT", win, "TOPLEFT", 3, -3)
    win.art:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -3, 3)
    win.art:SetAlpha(0.7)
    win.shades = {}
    local R = ns.Round
    local f = (R and R.SLATE_FILL) or { 0.075, 0.095, 0.12 }
    local function Col(a) return CreateColor(f[1], f[2], f[3], a) end
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        local t = win:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetColorTexture(1, 1, 1, 1)
        win.shades[side] = t
    end
    local sh = win.shades
    sh.top:SetPoint("TOPLEFT", win.art, "TOPLEFT"); sh.top:SetPoint("TOPRIGHT", win.art, "TOPRIGHT"); sh.top:SetHeight(110)
    sh.top:SetGradient("VERTICAL", Col(0), Col(0.95))
    sh.bottom:SetPoint("BOTTOMLEFT", win.art, "BOTTOMLEFT"); sh.bottom:SetPoint("BOTTOMRIGHT", win.art, "BOTTOMRIGHT"); sh.bottom:SetHeight(110)
    sh.bottom:SetGradient("VERTICAL", Col(0.95), Col(0))
    sh.left:SetPoint("TOPLEFT", win.art, "TOPLEFT"); sh.left:SetPoint("BOTTOMLEFT", win.art, "BOTTOMLEFT"); sh.left:SetWidth(200)
    sh.left:SetGradient("HORIZONTAL", Col(0.9), Col(0))
    sh.right:SetPoint("TOPRIGHT", win.art, "TOPRIGHT"); sh.right:SetPoint("BOTTOMRIGHT", win.art, "BOTTOMRIGHT"); sh.right:SetWidth(360)
    sh.right:SetGradient("HORIZONTAL", Col(0), Col(0.95))

    BuildHeader()
    BuildBody()
    BuildFooter()

    -- the H3z0 UI logo, small, at the right end of the footer
    win.logoText = Text(win, 13, "RIGHT")
    win.logoText:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -EDGE - 2, 10)
    win.logoText:SetText("H3z0 UI")
    win.logoText:SetTextColor(0.85, 0.88, 0.92, 0.55)
    win.logo = win:CreateTexture(nil, "OVERLAY")
    win.logo:SetSize(18, 18)
    win.logo:SetPoint("RIGHT", win.logoText, "LEFT", -4, 0)
    win.logo:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\icon.tga")
    win.logo:SetAlpha(0.6)
    BuildSettingsButton()
    do
        local st = Settings()
        local on = not st or st.h3zLogo ~= false
        win.logo:SetShown(on) win.logoText:SetShown(on)
    end

    -- other tabs: the game's page is shown here, under our header
    win.pageHost = CreateFrame("Frame", nil, win)
    win.pageHost:SetPoint("TOPLEFT", win, "TOPLEFT", EDGE - 6, -HEADER - 8)
    win.pageHost:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -EDGE + 6, FOOTER)
    -- the right part of a page: where its info panel goes (Reputation, Skills, Currency, ...)
    win.rightArea = CreateFrame("Frame", nil, win.pageHost)
    win.rightArea:SetPoint("TOPLEFT", win.pageHost, "TOPLEFT", 450, 0)
    win.rightArea:SetPoint("BOTTOMRIGHT", win.pageHost, "BOTTOMRIGHT", -6, 0)
    win.pageHost:Hide()
    return win
end

UpdateArt = function()
    local CB = ns.H3z0CharacterBackground
    local atlas = CB and CB.BackgroundAtlas and CB.BackgroundAtlas("player")
    local s = Settings()
    local on = atlas and currentPage == "character" and (not s or s.h3zBackground ~= false)
    if on then
        win.art:SetAtlas(atlas)
        win.art:Show()
    else
        win.art:Hide()
    end
    for _, t in pairs(win.shades) do t:SetShown(on and true or false) end
end

---------------------------------------------------------------------------
-- lending the game's slot buttons and model
---------------------------------------------------------------------------
local function SavePoints(f)
    local pts = {}
    for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
    return pts
end

local function PlaceSlotButton(key)
    local v = slotViews[key]
    local b = _G["Character" .. key .. "Slot"]
    if not (v and b) then return end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", v.iconFrame, "TOPLEFT", 0, 0)
    b:SetPoint("BOTTOMRIGHT", v.iconFrame, "BOTTOMRIGHT", 0, 0)
    b:SetAlpha(0)
    -- skins on the slot buttons can bring their alpha back: make every piece of them see-through
    local rec = lent.slots[key]
    if rec and not rec.parts then
        rec.parts = {}
        for _, r in ipairs({ b:GetRegions() }) do if r.GetAlpha then rec.parts[r] = r:GetAlpha() end end
        for _, c in ipairs({ b:GetChildren() }) do if c.GetAlpha then rec.parts[c] = c:GetAlpha() end end
    end
    for _, r in ipairs({ b:GetRegions() }) do if r.SetAlpha then r:SetAlpha(0) end end
    for _, c in ipairs({ b:GetChildren() }) do if c.SetAlpha then c:SetAlpha(0) end end
    if not b.h3zCWAlphaHook then
        b.h3zCWAlphaHook = true
        hooksecurefunc(b, "SetAlpha", function(self, a)
            if lent.active and lent.slots[key] and type(a) == "number" and a > 0 then
                self:SetAlpha(0)
            end
        end)
    end
    b:SetFrameLevel(v.iconFrame:GetFrameLevel() + 5)
    b:EnableMouse(true)
    if not b:IsShown() then b:Show() end
end

local function Lend()
    if lent.active or InCombatLockdown() then return end
    lent.active = true
    -- Only the slot buttons come over, each on its own. The game's whole item frame used to come
    -- along, but other things live on it too (skins add panels and buttons there), and those lay
    -- invisibly over the whole window and took every click and hover.
    for _, list in ipairs({ LEFT, RIGHT, WEAPONS, { "Ammo" } }) do
        for _, key in ipairs(list) do
            local b = _G["Character" .. key .. "Slot"]
            if b then
                lent.slots[key] = { button = b, parent = b:GetParent(), points = SavePoints(b), alpha = b:GetAlpha(),
                    w = b:GetWidth(), h = b:GetHeight() }
                if not b.h3zCWHooked then
                    b.h3zCWHooked = true
                    b:HookScript("OnEnter", function() local v = slotViews[key] if v and lent.active then v.hl:Show() end end)
                    b:HookScript("OnLeave", function() local v = slotViews[key] if v then v.hl:Hide() end end)
                end
                b:SetParent(win)
                if slotViews[key] then
                    PlaceSlotButton(key)
                else
                    -- the game's ammo slot: not part of this window (it showed as a stray little box)
                    lent.slots[key].shown = b:IsShown()
                    b:Hide()
                end
            end
        end
    end
end

local function GiveBack()
    if not lent.active or InCombatLockdown() then return end
    lent.active = false
    for key, s in pairs(lent.slots) do
        local b = s.button
        b:SetParent(s.parent)
        b:ClearAllPoints()
        for _, p in ipairs(s.points) do b:SetPoint(unpack(p)) end
        lent.slots[key] = nil
        if s.shown ~= nil then
            b:SetShown(s.shown)
        end
        b:SetAlpha(s.alpha or 1)
        for part, al in pairs(s.parts or {}) do pcall(part.SetAlpha, part, al) end
        if s.w then b:SetSize(s.w, s.h) end
        b:EnableMouse(true)
        local v = slotViews[key]
        if v then v.hl:Hide() end
    end
    wipe(lent.slots)
end

-- the skin may put a slot or the model back where it had them: check now and then while open
local function KeepPlaced()
    if not lent.active or InCombatLockdown() then return end
    for key, rec in pairs(lent.slots) do
        local v = slotViews[key]
        local b = _G["Character" .. key .. "Slot"]
        if not v and b and b:IsShown() then b:Hide() end
        if v and b then
            local _, rel = b:GetPoint(1)
            if rel ~= v.iconFrame or b:GetAlpha() > 0 then PlaceSlotButton(key) end
        end
    end
end

---------------------------------------------------------------------------
-- following the game's window
---------------------------------------------------------------------------
local function OnCharacterPage(g)
    local paper = _G.PaperDollFrame
    return paper and paper:IsShown() == true
end

-- the tab the game's window is on, by which of its pages is shown
local function GamePage()
    local paper = _G.PaperDollFrame
    if paper and paper:IsShown() then return "character", paper end
    for i, tab in ipairs(GameTabs()) do
        local n = type(tab.frameName) == "string" and tab.frameName
        local f = n and _G[n]
        if f and n ~= "PaperDollFrame" and f:IsShown() then
            tabPage[i] = n
            return n, f
        end
    end
    for _, t in ipairs(TABS) do
        local f = _G[t.frame]
        if f and t.frame ~= "PaperDollFrame" and f:IsShown() and f:GetParent() == CharacterFrame then return t.frame, f end
    end
    -- a page with another name (Forever has its own): the biggest shown named child of the game's window
    local best, bestArea
    local g = CharacterFrame
    for _, c in ipairs({ g:GetChildren() }) do
        local okN, n = pcall(c.GetName, c)
        if okN and type(n) == "string" and c:IsShown() and not n:find("^CharacterFrame") and not n:find("^H3z0")
            and not n:find("Tab") and c ~= g.ModeTabs then
            local w, h = c:GetSize()
            if type(w) == "number" and type(h) == "number" and w > 200 and h > 200 then
                local area = w * h
                if not bestArea or area > bestArea then best, bestArea = c, area end
            end
        end
    end
    if best then return best:GetName(), best end
    -- the page already moved into our window
    if borrowed and borrowed.frame:IsShown() then return borrowed.frame:GetName() or "page", borrowed.frame end
    return "character", paper
end

-- detail panes the game hangs off the right edge of its window (Reputation, Currency): inside ours
-- they go to the right side of the page instead of over the tabs
local function DetailPanes(f)
    local list = {}
    local function Add(d)
        if d and type(d) == "table" and d.GetObjectType then
            for _, x in ipairs(list) do if x == d then return end end
            list[#list + 1] = d
        end
    end
    Add(_G.ReputationDetailFrame)
    Add(_G.TokenFramePopup)
    Add(f.ReputationDetailFrame)
    Add(f.DetailFrame)
    Add(f.Popup)
    return list
end

local function PlaceDetail(d)
    if not (borrowed and win and win.rightArea) or InCombatLockdown() then return end
    local w, h = d:GetSize()
    d:ClearAllPoints()
    if type(w) == "number" and w > 0 and w <= win.rightArea:GetWidth() + 2 then
        d:SetSize(w, (type(h) == "number" and h > 0) and math.min(h, win.rightArea:GetHeight()) or win.rightArea:GetHeight())
        d:SetPoint("TOP", win.rightArea, "TOP", 0, 0)
    else
        d:SetAllPoints(win.rightArea)
    end
end

-- parts of a page that sit on its right side (an info panel built into the page, like Skills):
-- moved to the middle of the right area. Checked again while the page is open, as they show on a click.
local function TidyRightParts()
    if MIDNIGHT then return end   -- Forever / Classic pages only; Midnight's pages are laid out for any width
    if not (borrowed and win and win.rightArea) or InCombatLockdown() then return end
    local f = borrowed.frame
    local hostLeft = win.pageHost:GetLeft()
    if not hostLeft then return end
    borrowed.moved = borrowed.moved or {}
    for _, c in ipairs({ f:GetChildren() }) do
        if c:IsShown() and not borrowed.moved[c] then
            local left, w = c:GetLeft(), c:GetWidth()
            if left and w and w > 60 and w < 420 and (left - hostLeft) > 380 then
                local pts = {}
                for i = 1, c:GetNumPoints() do pts[i] = { c:GetPoint(i) } end
                local h = c:GetHeight()
                borrowed.moved[c] = pts
                c:ClearAllPoints()
                c:SetSize(w, h)
                c:SetPoint("TOP", win.rightArea, "TOP", 0, 0)
            end
        end
    end
end
CW.TidyRightParts = TidyRightParts

-- Forever keeps a page's info panel in a separate right-hand holder of its window
local function BorrowRightHost()
    local host = _G.CharacterFrameRightPaneHost
    if not host or borrowed.rightHost then return end
    local pts = {}
    for i = 1, host:GetNumPoints() do pts[i] = { host:GetPoint(i) } end
    borrowed.rightHost = { frame = host, parent = host:GetParent(), points = pts, shown = host:IsShown() }
    host:SetParent(win.rightArea)
    host:ClearAllPoints()
    host:SetAllPoints(win.rightArea)
    host:Show()
end

local function ReturnPage()
    if not borrowed or InCombatLockdown() then return end
    for _, d in ipairs(borrowed.details or {}) do
        d.frame:ClearAllPoints()
        for _, p in ipairs(d.points) do d.frame:SetPoint(unpack(p)) end
    end
    for c, pts in pairs(borrowed.moved or {}) do
        c:ClearAllPoints()
        for _, p in ipairs(pts) do c:SetPoint(unpack(p)) end
    end
    local rh = borrowed.rightHost
    if rh then
        rh.frame:SetParent(rh.parent)
        rh.frame:ClearAllPoints()
        for _, p in ipairs(rh.points) do rh.frame:SetPoint(unpack(p)) end
        if not rh.shown then rh.frame:Hide() end
    end
    local f = borrowed.frame
    f:SetParent(borrowed.parent)
    f:ClearAllPoints()
    for _, p in ipairs(borrowed.points) do f:SetPoint(unpack(p)) end
    borrowed = nil
end

local function BorrowPage(f)
    if not f or InCombatLockdown() then return end
    if borrowed and borrowed.frame == f then return end
    ReturnPage()
    local pts = {}
    for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
    -- details exists before the page moves: moving it can show its detail panel at once,
    -- and that panel's OnShow looks through this list
    borrowed = { frame = f, parent = f:GetParent(), points = pts, details = {} }
    f:SetParent(win.pageHost)
    f:ClearAllPoints()
    f:SetAllPoints(win.pageHost)
    BorrowRightHost()
    if CW.RaiseTabs then CW.RaiseTabs() end
    C_Timer.After(0.05, TidyRightParts)
    for _, d in ipairs(DetailPanes(f)) do
        local dp = {}
        for i = 1, d:GetNumPoints() do dp[i] = { d:GetPoint(i) } end
        borrowed.details[#borrowed.details + 1] = { frame = d, points = dp }
        PlaceDetail(d)
        if not d.h3zCWHooked then
            d.h3zCWHooked = true
            d:HookScript("OnShow", function(self)
                if borrowed and borrowed.details then
                    for _, x in ipairs(borrowed.details) do if x.frame == self then PlaceDetail(self) end end
                end
            end)
        end
    end
end

-- Midnight: the game's window stays where it is, see-through, under this window
local function Cover()
    local g = CharacterFrame
    if parked or not g then return end
    parked = true
    lent.oldAlpha = g:GetAlpha()
    lent.oldWidth = g:GetWidth()
    g:SetAlpha(0)
    -- as wide as this window, so the next panel the game opens goes beside it, not under it
    -- (not in combat: sizes of a window holding secure buttons are locked then)
    if not InCombatLockdown() then g:SetWidth(WIN_W * Scale()) end
    if not g.h3zCWAlphaHook then
        g.h3zCWAlphaHook = true
        hooksecurefunc(g, "SetAlpha", function(self, a)
            if parked and MIDNIGHT and type(a) == "number" and a > 0 then self:SetAlpha(0) end
        end)
        hooksecurefunc(g, "SetWidth", function(self, w)
            if parked and MIDNIGHT and type(w) == "number" and math.abs(w - WIN_W * Scale()) > 1 and not InCombatLockdown() then
                lent.oldWidth = w
                self:SetWidth(WIN_W * Scale())
            end
        end)
    end
end

local function Uncover()
    local g = CharacterFrame
    if not parked or not g then return end
    if CW.blocked and ns.H3zCWShared then ns.H3zCWShared.Restore(CW.blocked) end
    if InCombatLockdown() then
        -- the slots stay with us until combat ends; the window itself can be shown again now
        parked = false
        g:SetAlpha(lent.oldAlpha or 1)
        CW.widthPending = true      -- its width goes back after combat
        return
    end
    GiveBack()
    parked = false
    g:SetAlpha(lent.oldAlpha or 1)
    if lent.oldWidth then g:SetWidth(lent.oldWidth) end
end

local function Park()
    if MIDNIGHT then return Cover() end
    local g = CharacterFrame
    if parked or not g or InCombatLockdown() then return end
    lent.oldParent = g:GetParent()
    g:SetParent(hiddenParent)
    parked = true
    if SetUIPanelAttribute then pcall(SetUIPanelAttribute, g, "width", WIN_W * Scale() + 20) end
end

local function Unpark()
    if MIDNIGHT then return Uncover() end
    local g = CharacterFrame
    if not parked or not g or InCombatLockdown() then return end
    GiveBack()
    g:SetParent(lent.oldParent or UIParent)
    parked = false
    if SetUIPanelAttribute then pcall(SetUIPanelAttribute, g, "width", math.floor((g:GetWidth() or 384) + 0.5)) end
end

local function PlaceWindow()
    local g = CharacterFrame
    win:ClearAllPoints()
    if MIDNIGHT and g then
        -- right over the game's window, and above it, so it gets every click
        win:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0)
        win:SetFrameStrata(g:GetFrameStrata())
        win:SetFrameLevel(math.min(9000, (g:GetFrameLevel() or 1) + 40))
        return
    end
    -- on the game window's spot (it stays where the game puts panels, just out of sight)
    if g and g:GetNumPoints() > 0 then
        win:SetPoint("TOPLEFT", g, "TOPLEFT", 12, -12)
    else
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -104)
    end
end

local pendingEvents = false
local function QueueUpdate()
    if pendingEvents then return end
    pendingEvents = true
    C_Timer.After(0, function() pendingEvents = false CW.UpdateAll() end)
end

local EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_ATTACK_SPEED", "UNIT_DAMAGE",
    "UNIT_RANGEDDAMAGE", "UNIT_RESISTANCES", "UNIT_AURA", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED",
    "UPDATE_INVENTORY_DURABILITY", "PLAYER_LEVEL_UP", "COMBAT_RATING_UPDATE", "SKILL_LINES_CHANGED",
    "GET_ITEM_INFO_RECEIVED", "UNIT_PET", "UNIT_MODEL_CHANGED",
    "PLAYER_AVG_ITEM_LEVEL_UPDATE", "MASTERY_UPDATE", "SPEED_UPDATE", "LIFESTEAL_UPDATE", "AVOIDANCE_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED", "UNIT_MAXHEALTH", "PLAYER_REGEN_ENABLED" }
local evFrame = CreateFrame("Frame")
evFrame:SetScript("OnEvent", function(_, event, unit)
    if unit and type(unit) == "string" and event:sub(1, 5) == "UNIT_" and unit ~= "player" and event ~= "UNIT_PET" then return end
    if event == "UNIT_MODEL_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then CW.UpdateModel() end
    QueueUpdate()
end)

-- Midnight: Titles and Equipment Sets are the game's own lists from the side of its character page;
-- they are shown in our right panel instead of the stats while chosen
local sideBorrowed
local function SidePaneFrame(kind)
    local pd = _G.PaperDollFrame
    if kind == "titles" then return _G.PaperDollTitlesPane or (pd and pd.TitleManagerPane) end
    if kind == "equipment" then return _G.PaperDollEquipmentManagerPane or (pd and pd.EquipmentManagerPane) end
end
local function CurrentSidePane()
    local e, t = SidePaneFrame("equipment"), SidePaneFrame("titles")
    if e and e:IsShown() then return "equipment" end
    if t and t:IsShown() then return "titles" end
    return "stats"
end
local function ReturnSidePane()
    if not sideBorrowed or InCombatLockdown() then return end
    local f = sideBorrowed.frame
    f:SetParent(sideBorrowed.parent)
    f:ClearAllPoints()
    for _, p in ipairs(sideBorrowed.points) do f:SetPoint(unpack(p)) end
    sideBorrowed = nil
end
local function ShowSidePane(kind)
    if InCombatLockdown() or not win or not win.statsInset then return end
    sidePane = kind
    if kind == "stats" then
        ReturnSidePane()
        win.statsScroll:Show()
        return
    end
    local f = SidePaneFrame(kind)
    if not f then return end
    if not (sideBorrowed and sideBorrowed.frame == f) then
        ReturnSidePane()
        local pts = {}
        for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
        sideBorrowed = { frame = f, parent = f:GetParent(), points = pts }
        f:SetParent(win.body)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", win.statsInset, "TOPLEFT", 4, -4)
        f:SetPoint("BOTTOMRIGHT", win.statsInset, "BOTTOMRIGHT", -4, 4)
        f:SetFrameLevel(win.statsInset:GetFrameLevel() + 5)
    end
    win.statsScroll:Hide()
end

-- Midnight: follows the game's window. Our window is part of it, so the game shows and hides it;
-- this only reacts to it opening and closing, and to page and side-panel changes.
local midOpen = false
local midTick = 0
local raiseTick = 0
local lastCtx = false
local function MidnightTick(elapsed)
    local g = CharacterFrame
    if midOpen and _G.ItemButtonUtil and ItemButtonUtil.GetItemContext then
        local ctx = ItemButtonUtil.GetItemContext()
        if ctx ~= lastCtx then
            lastCtx = ctx
            for _, sv in pairs(slotViews) do if sv.slotId and not sv.isAmmo then sv:SetAlpha(ContextDim(sv)) end end
        end
    end
    local open = g:IsShown() and Enabled() and true or false
    if open and not midOpen then
        midOpen = true
        Build()
        Cover()
        if not win:IsShown() and not InCombatLockdown() then win:Show() end
        Lend()
        for _, e in ipairs(EVENTS) do pcall(evFrame.RegisterEvent, evFrame, e) end
        CW.UpdateModel()
        CW.UpdateAll()
        gameTopAt = 0
        C_Timer.After(0.1, function() gameTopAt = 0 CW.RaiseTabs() end)
    elseif not open and midOpen then
        midOpen = false
        evFrame:UnregisterAllEvents()
        Uncover()
    end
    if not InCombatLockdown() then
        if CW.widthPending and not parked then
            CW.widthPending = nil
            if lent.oldWidth then g:SetWidth(lent.oldWidth) end
        elseif parked and math.abs((g:GetWidth() or WIN_W) - WIN_W * Scale()) > 1 then
            g:SetWidth(WIN_W * Scale())    -- opened in combat, or resized: widened now
        end
        if open and CW.midTabsDirty then CW.LayoutMidTabs() end
    end
    if not open then
        if CW.blocked and next(CW.blocked) and not InCombatLockdown() and ns.H3zCWShared then
            ns.H3zCWShared.Restore(CW.blocked)
        end
        if win and not InCombatLockdown() then
            if lent.active then GiveBack() end
            ReturnSidePane()
            ReturnPage()
            if currentPage ~= "character" then
                currentPage = "character"
                win.pageHost:Hide()
                win.body:Show()
                win.footIlvl:Show() win.footDura:Show() win.footLine:Show()
            end
            -- switched off while the game's window is open: ours goes away
            if not Enabled() and win:IsShown() and g:IsShown() then win:Hide() end
        end
        return
    end
    if InCombatLockdown() then return end
    local page, f = GamePage()
    if page ~= currentPage then
        currentPage = page
        if page == "character" then
            ReturnPage()
            win.pageHost:Hide()
            win.body:Show()
            win.footIlvl:Show() win.footDura:Show() win.footLine:Show()
            Lend()
        else
            GiveBack()
            win.body:Hide()
            win.footIlvl:Hide() win.footDura:Hide() win.footLine:Hide()
            win.pageHost:Show()
            BorrowPage(f)
        end
        CW.UpdateAll()
    elseif page ~= "character" and borrowed and borrowed.frame ~= f then
        BorrowPage(f)
    end
    if page == "character" then
        local sp = CurrentSidePane()
        if sp ~= sidePane or (sp ~= "stats" and not sideBorrowed) then
            ShowSidePane(sp)
            CW.LayoutMidTabs()
        end
        if not lent.active then Lend() end
        midTick = midTick + elapsed
        if midTick > 0.3 then midTick = 0 KeepPlaced() end
    end
    -- on every page: keep the tabs and X on top
    raiseTick = (raiseTick or 0) + elapsed
    if raiseTick > 0.25 then raiseTick = 0 CW.RaiseTabs() end
end

local function ShowOurs()
    Build()
    PlaceWindow()
    win:Show()
    Lend()
    CW.UpdateModel()
    for _, e in ipairs(EVENTS) do pcall(evFrame.RegisterEvent, evFrame, e) end
    CW.UpdateAll()
end

local function HideOurs()
    if win then win:Hide() end
    evFrame:UnregisterAllEvents()
end

local tickAcc = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function(_, elapsed)
    local g = CharacterFrame
    if not g then return end
    if MIDNIGHT then return MidnightTick(elapsed) end
    if not Enabled() then
        if parked or (win and win:IsShown()) then
            HideOurs()
            ReturnPage()
            Unpark()
            HideOverlays()
        end
        return
    end
    if g:IsShown() then
        if not parked then
            if InCombatLockdown() and not MIDNIGHT then return end   -- the game's window shows as before until combat ends
            Park()
        end
        if not (win and win:IsShown()) then ShowOurs() end
        local page, f = GamePage()
        if pendingLearn and (page ~= currentPage or pendingLearn == 1) then
            tabPage[pendingLearn] = page
            pendingLearn = nil
            if page == currentPage then LayoutTabs() end
        end
        if page ~= currentPage then
            if InCombatLockdown() then return end
            currentPage = page
            if page == "character" then
                ReturnPage()
                win.pageHost:Hide()
                win.body:Show()
                win.footIlvl:Show() win.footDura:Show() win.footLine:Show()
                Lend()
            else
                GiveBack()
                win.body:Hide()
                win.footIlvl:Hide() win.footDura:Hide() win.footLine:Hide()
                win.pageHost:Show()
                BorrowPage(f)
            end
            CW.UpdateAll()
        end
        if page == "character" then
            if not lent.active and not InCombatLockdown() then Lend() end
            tickAcc = tickAcc + elapsed
            if tickAcc > 0.3 then tickAcc = 0 KeepPlaced() end
        elseif borrowed and borrowed.frame ~= f and not InCombatLockdown() then
            BorrowPage(f)
        elseif borrowed then
            tickAcc = tickAcc + elapsed
            if tickAcc > 0.3 then tickAcc = 0 TidyRightParts() end
        end
    else
        if win and win:IsShown() then HideOurs() end
        if not InCombatLockdown() then
            ReturnPage()
            if currentPage ~= "character" then
                currentPage = "character"
                if win then
                    win.pageHost:Hide()
                    win.body:Show()
                    win.footIlvl:Show() win.footDura:Show() win.footLine:Show()
                end
            end
            if MIDNIGHT then
                -- closed: the game's window gets its own look back (see-through only while open)
                if parked then Uncover() end
                if lent.active then GiveBack() end
            elseif not parked then
                -- closed: stays parked so the next C opens straight into ours
                Park()
            end
        end
    end
end)

function CW.Toggle()
    local s = Settings()
    if not s then return end
    s.h3zWindow = not (s.h3zWindow ~= false)
    print("|cff60a5faH3z0 UI:|r H3z0 character window " .. (s.h3zWindow and "on." or "off: the game's window is used."))
end
_G.H3z0UI_ToggleCharacterWindow = CW.Toggle

-- settings changed (what the gear rows show, text size, window size)
function CW.ApplyOptions()
    wipe(trackCache)
    if ns.H3zCWShared then ns.H3zCWShared.ClearTrackCache() end
    if not win then return end
    if InCombatLockdown() then
        C_Timer.After(1, CW.ApplyOptions)
        return
    end
    win:SetScale(Scale())
    local st = Settings()
    local logoOn = not st or st.h3zLogo ~= false
    win.logo:SetShown(logoOn) win.logoText:SetShown(logoOn)
    if UpdateArt then pcall(UpdateArt) end
    for _, v in pairs(slotViews) do v.arranged = nil UpdateSlot(v) end
    if CW.UpdateAll and win:IsVisible() then CW.UpdateAll() end
end
_G.H3z0UI_RefreshCharacterWindow = CW.ApplyOptions
