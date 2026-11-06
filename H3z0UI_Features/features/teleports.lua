local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Waygate: an extra side tab on the world map (under the quest
-- log tabs). It opens a panel with every teleport you can use:
--   Favorites (right-click any icon to star it), Home (hearthstones and
--   hearthstone toys), Class (mage, druid, death knight, monk, shaman) and
--   the dungeon teleports of every expansion.
-- Left-click casts. Built out of combat only (secure buttons).
-- Settings: profile.h3zTeleports (enabled, showUnknown, favorites).
---------------------------------------------------------------------------
if ns.Client and (ns.Client.isClassic or ns.Client.isForever) then return end

local PREFIX = "|cFF30D1FFH3z0 UI:|r "
local ICON = 40
local GAP = 6
local PAD = 10
local QMARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.h3zTeleports = p.h3zTeleports or {}
    local s = p.h3zTeleports
    if s.enabled == nil then s.enabled = true end
    if s.showUnknown == nil then s.showUnknown = true end
    s.favorites = s.favorites or {}
    return s
end

---------------------------------------------------------------------------
-- data
---------------------------------------------------------------------------
local HEARTH_ITEMS = { 6948, 110560, 140192, 141605 }
local HEARTH_TOYS = {
    54452, 64488, 93672, 142542, 162973, 163045, 165669, 165670, 165802, 166746,
    166747, 168907, 172179, 180290, 182773, 183716, 184353, 188952, 190196, 190237,
    193588, 200630, 206195, 208704, 209035, 212337, 228940, 235016, 236687, 245970,
}
local CLASS_SPELLS = {
    -- mage
    3561, 3562, 3565, 32271, 49359, 33690, 53140, 88342, 132621, 176248, 224869, 281403, 395277, 446540,
    3567, 3563, 3566, 32272, 49358, 35715, 88344, 132627, 176242, 281404,
    193759, 344587, 120145,
    -- druid / death knight / monk / shaman
    18960, 193753, 50977, 126892, 556,
}

local EXPANSIONS = {
    { key = "cata",  name = "Cataclysm" },
    { key = "mop",   name = "Mists of Pandaria" },
    { key = "wod",   name = "Warlords of Draenor" },
    { key = "legion", name = "Legion" },
    { key = "bfa",   name = "Battle for Azeroth" },
    { key = "sl",    name = "Shadowlands" },
    { key = "df",    name = "Dragonflight" },
    { key = "tww",   name = "The War Within" },
    { key = "wotlk", name = "Wrath of the Lich King" },
    { key = "mid",   name = "Midnight" },
}
local EXP_FIXED = { [438] = "cata", [456] = "cata", [507] = "cata", [556] = "wotlk" }
local function ExpansionOf(mapID)
    if EXP_FIXED[mapID] then return EXP_FIXED[mapID] end
    if mapID < 100 then return "mop" end
    if mapID < 190 then return "wod" end
    if mapID < 240 then return "legion" end
    if mapID < 375 then return "bfa" end
    if mapID < 399 then return "sl" end
    if mapID < 499 then return "df" end
    if mapID < 550 then return "tww" end
    return "mid"
end

local function Known(spellID)
    if not spellID then return false end
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    return IsSpellKnown and IsSpellKnown(spellID) or false
end

local function SpellInfo(spellID)
    local name, icon
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(spellID)
        if i then name, icon = i.name, i.iconID end
    end
    return name, icon
end

-- entry: { kind = "spell"/"toy"/"item", id, name, icon, known }
local function Gather()
    local s = Settings() or { showUnknown = true, favorites = {} }
    local all, sections = {}, {}

    local home = {}
    for _, id in ipairs(HEARTH_ITEMS) do
        local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0
        if count and count > 0 then
            home[#home + 1] = { kind = "item", id = id, name = C_Item.GetItemNameByID(id), icon = C_Item.GetItemIconByID(id), known = true }
        end
    end
    if PlayerHasToy then
        for _, id in ipairs(HEARTH_TOYS) do
            if PlayerHasToy(id) then
                local _, name, icon = C_ToyBox.GetToyInfo(id)
                home[#home + 1] = { kind = "toy", id = id, name = name, icon = icon, known = true }
            end
        end
    end

    local class = {}
    for _, id in ipairs(CLASS_SPELLS) do
        if Known(id) then
            local name, icon = SpellInfo(id)
            class[#class + 1] = { kind = "spell", id = id, name = name, icon = icon, known = true }
        end
    end

    local DD = ns.DungeonData or _G.H3z0UI_DungeonData
    local byExp, seen = {}, {}
    if DD and DD.mapIdToSpell then
        local ids = {}
        for mapID in pairs(DD.mapIdToSpell) do ids[#ids + 1] = mapID end
        table.sort(ids)
        for _, mapID in ipairs(ids) do
            local spellID = (DD.GetTeleportSpellID and DD.GetTeleportSpellID(mapID)) or DD.mapIdToSpell[mapID]
            if spellID and not seen[spellID] then
                seen[spellID] = true
                local known = Known(spellID)
                if known or s.showUnknown then
                    local name, _, _, icon
                    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
                        name, _, _, icon = C_ChallengeMode.GetMapUIInfo(mapID)
                    end
                    local sName, sIcon = SpellInfo(spellID)
                    local exp = ExpansionOf(mapID)
                    byExp[exp] = byExp[exp] or {}
                    table.insert(byExp[exp], { kind = "spell", id = spellID, name = name or sName, icon = icon or sIcon, known = known })
                end
            end
        end
    end

    local function Fav(e) return s.favorites[e.kind .. ":" .. e.id] end
    local favs = {}
    local function Collect(list) for _, e in ipairs(list) do all[#all + 1] = e; if Fav(e) then favs[#favs + 1] = e end end end
    Collect(home); Collect(class)
    for i = #EXPANSIONS, 1, -1 do
        local list = byExp[EXPANSIONS[i].key]
        if list then
            table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
            Collect(list)
        end
    end

    sections[#sections + 1] = { title = "Favorites", list = favs, hint = "Right-click any teleport to add it here." }
    sections[#sections + 1] = { title = "Home", list = home }
    if #class > 0 then sections[#sections + 1] = { title = "Class", list = class } end
    -- newest expansion first
    local order = { "mid", "tww", "df", "sl", "bfa", "legion", "wod", "mop", "cata", "wotlk" }
    local names = {}
    for _, e in ipairs(EXPANSIONS) do names[e.key] = e.name end
    for _, key in ipairs(order) do
        if byExp[key] and #byExp[key] > 0 then
            sections[#sections + 1] = { title = names[key], list = byExp[key] }
        end
    end
    return sections
end

---------------------------------------------------------------------------
-- panel
---------------------------------------------------------------------------
local tab, panel, scroll, child
local pool, headers = {}, {}
local dirty = true

local function ApplyEntry(btn, e)
    btn.entry = e
    if e.kind == "spell" then
        btn:SetAttribute("type1", "spell"); btn:SetAttribute("spell", e.id)
        btn:SetAttribute("toy", nil); btn:SetAttribute("item", nil)
    elseif e.kind == "toy" then
        btn:SetAttribute("type1", "toy"); btn:SetAttribute("toy", e.id)
        btn:SetAttribute("spell", nil); btn:SetAttribute("item", nil)
    else
        btn:SetAttribute("type1", "item"); btn:SetAttribute("item", "item:" .. e.id)
        btn:SetAttribute("spell", nil); btn:SetAttribute("toy", nil)
    end
    btn.icon:SetTexture(e.icon or QMARK)
    btn.icon:SetDesaturated(not e.known)
    btn.icon:SetAlpha(e.known and 1 or 0.45)
    local s = Settings()
    btn.star:SetShown(s and s.favorites[e.kind .. ":" .. e.id] and true or false)
end

local function UpdateCooldowns()
    for _, btn in ipairs(pool) do
        local e = btn:IsShown() and btn.entry
        if e then
            local start, dur
            if e.kind == "spell" and C_Spell and C_Spell.GetSpellCooldown then
                local cd = C_Spell.GetSpellCooldown(e.id)
                if cd then start, dur = cd.startTime, cd.duration end
            elseif C_Item and C_Item.GetItemCooldown then
                start, dur = C_Item.GetItemCooldown(e.id)
            end
            if issecretvalue and (issecretvalue(start) or issecretvalue(dur)) then start, dur = nil, nil end
            if start and dur and dur > 1.5 then
                btn.cd:SetCooldown(start, dur)
            else
                btn.cd:Clear()
            end
        end
    end
end

local function ToggleFavorite(btn)
    local e = btn.entry
    local s = Settings()
    if not (e and s) then return end
    local k = e.kind .. ":" .. e.id
    s.favorites[k] = (not s.favorites[k]) or nil
    dirty = true
    if InCombatLockdown() then
        print(PREFIX .. "favorites update after combat.")
    else
        _G.H3z0UI_RefreshTeleports()
    end
end

local function NewButton()
    local b = CreateFrame("Button", nil, child, "SecureActionButtonTemplate")
    b:SetSize(ICON, ICON)
    b:RegisterForClicks("AnyUp", "AnyDown")
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1); border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints()
    b.cd:SetDrawEdge(false)
    b.star = b:CreateTexture(nil, "OVERLAY")
    b.star:SetSize(16, 16)
    b.star:SetPoint("TOPRIGHT", 4, 4)
    b.star:SetAtlas("PetJournal-FavoritesIcon", false)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.18)
    b:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down then ToggleFavorite(self) end
    end)
    b:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if e.kind == "spell" then GameTooltip:SetSpellByID(e.id)
        elseif e.kind == "toy" and GameTooltip.SetToyByItemID then GameTooltip:SetToyByItemID(e.id)
        else GameTooltip:SetItemByID(e.id) end
        if e.name and e.kind == "spell" then GameTooltip:AddLine(e.name, 0.4, 0.8, 1) end
        if not e.known then GameTooltip:AddLine("Not learned yet (time this dungeon in Mythic+ to earn it).", 0.9, 0.4, 0.4, true) end
        GameTooltip:AddLine("Left-click: teleport.  Right-click: favorite.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pool[#pool + 1] = b
    return b
end

local function Header(i)
    local h = headers[i]
    if not h then
        h = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetJustifyH("LEFT")
        h.line = child:CreateTexture(nil, "ARTWORK")
        h.line:SetHeight(1)
        h.line:SetColorTexture(0.19, 0.82, 1, 0.35)
        h.line:SetPoint("LEFT", h, "RIGHT", 8, 0)
        h.line:SetPoint("RIGHT", child, "RIGHT", -PAD, 0)
        h.hint = child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        h.hint:SetJustifyH("LEFT")
        headers[i] = h
    end
    return h
end

local function Layout()
    if InCombatLockdown() or not child then return end
    dirty = false
    local width = math.max(scroll:GetWidth(), 200)
    child:SetWidth(width)
    local perRow = math.max(1, math.floor((width - PAD * 2 + GAP) / (ICON + GAP)))
    for _, b in ipairs(pool) do b:Hide() end
    for _, h in ipairs(headers) do h:Hide(); h.line:Hide(); h.hint:Hide() end

    local y, used, hi = -PAD, 0, 0
    for _, sec in ipairs(Gather()) do
        hi = hi + 1
        local h = Header(hi)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, y)
        h:SetText(sec.title)
        h:Show(); h.line:Show()
        y = y - 20
        if #sec.list == 0 and sec.hint then
            h.hint:ClearAllPoints()
            h.hint:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, y)
            h.hint:SetText(sec.hint)
            h.hint:Show()
            y = y - 22
        end
        for i, e in ipairs(sec.list) do
            used = used + 1
            local b = pool[used] or NewButton()
            local col = (i - 1) % perRow
            local row = math.floor((i - 1) / perRow)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", child, "TOPLEFT", PAD + col * (ICON + GAP), y - row * (ICON + GAP))
            ApplyEntry(b, e)
            b:Show()
        end
        if #sec.list > 0 then
            y = y - math.ceil(#sec.list / perRow) * (ICON + GAP) - 8
        end
    end
    child:SetHeight(-y + PAD)
    UpdateCooldowns()
end

local function SetTabChecked(on)
    if not tab then return end
    tab.SelectedTexture:SetShown(on)
    tab.Icon:SetDesaturated(not on)
    if _G.H3z0UI_RestyleMapTabs then _G.H3z0UI_RestyleMapTabs() end
end

local function ShowPanel(on)
    if not panel then return end
    if InCombatLockdown() then
        if on then print(PREFIX .. "Waygate opens after combat.") end
        return
    end
    panel:SetShown(on)
    SetTabChecked(on)
    if on and dirty then Layout() elseif on then UpdateCooldowns() end
end

local function Build()
    if panel or InCombatLockdown() then return end
    local qmf = _G.QuestMapFrame
    if not (qmf and qmf.MapLegendTab) then return end

    tab = CreateFrame("Frame", nil, qmf, "LargeSideTabButtonTemplate")
    qmf.H3z0WaygateTab = tab
    tab:SetPoint("TOP", qmf.MapLegendTab, "BOTTOM", 0, -3)
    tab.tooltipText = "Waygate"
    tab.Icon:SetTexture("Interface\\Icons\\Spell_Arcane_TeleportDalaran")
    tab.Icon:SetSize(26, 26)
    tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = tab:CreateMaskTexture()
    mask:SetAllPoints(tab.Icon)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    tab.Icon:AddMaskTexture(mask)
    tab.SelectedTexture:Hide()
    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button == "LeftButton" and upInside then ShowPanel(not panel:IsShown()) end
    end)
    SetTabChecked(false)
    if _G.H3z0UI_RestyleMapTabs then _G.H3z0UI_RestyleMapTabs() end

    panel = CreateFrame("Frame", nil, qmf)
    local anchor = qmf.ContentsAnchor or qmf
    panel:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -2)
    panel:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -2, 0)
    panel:SetFrameLevel(qmf:GetFrameLevel() + 40)
    panel:EnableMouse(true)
    panel:Hide()
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.05, 0.07, 0.97)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", PAD, -10)
    title:SetText("Waygate")
    title:SetTextColor(0.19, 0.82, 1)

    scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 0, -36)
    scroll:SetPoint("BOTTOMRIGHT", 0, 6)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(260, 10)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        if InCombatLockdown() then return end
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 60)))
    end)
    scroll:SetScript("OnSizeChanged", function() dirty = true; if panel:IsShown() then Layout() end end)

    -- a Blizzard tab was clicked: give the space back
    for _, key in ipairs({ "QuestsTab", "EventsTab", "MapLegendTab" }) do
        local b = qmf[key]
        if b and b.HookScript then b:HookScript("OnMouseUp", function() ShowPanel(false) end) end
    end
    if _G.WorldMapFrame then
        _G.WorldMapFrame:HookScript("OnHide", function() ShowPanel(false) end)
    end
end

local function Apply()
    local s = Settings()
    if not (s and s.enabled) then
        if tab then tab:Hide() end
        ShowPanel(false)
        return
    end
    Build()
    if tab then tab:Show() end
end

_G.H3z0UI_RefreshTeleports = function()
    dirty = true
    Apply()
    if panel and panel:IsShown() then Layout() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("TOYS_UPDATED")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then
        if not panel and IsLoggedIn() then Apply() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not panel then Apply() end
        if dirty and panel and panel:IsShown() then Layout() end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if panel and panel:IsVisible() then UpdateCooldowns() end
    else
        dirty = true
        if panel and panel:IsVisible() and not InCombatLockdown() then Layout() end
    end
end)
