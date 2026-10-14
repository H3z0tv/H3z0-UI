---------------------------------------------------------------------------
-- H3z0UI Quick Access
-- A panel docked to the Group Finder (PVEFrame) with:
--   * Quick Access: one-click jump into Mythic+ / Raids / Delves / Quest / Custom
--     premade group searches.
--   * Filters (while a search is shown): dungeon toggles, minimum leader score,
--     minimum dungeon score, "role available", "has tank", "has healer".
--     Filtering is done client-side on the search results.
--
-- Everything that touches Blizzard's Group Finder is wrapped in pcall and every
-- value coming from the LFG API is checked for Midnight "secret values" first.
-- When anything is unavailable the panel silently does less, never errors.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local issecretvalue = issecretvalue or function() return false end
local WHITE = "Interface\\Buttons\\WHITE8X8"

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = true,
    side = "AUTO",          -- AUTO / LEFT / RIGHT / BELOW the Group Finder window
    offsetX = 0,
    offsetY = 0,
    locked = false,         -- true = panel cannot be dragged
    scale = 1.0,
    showFilters = true,
    rememberFilters = true,
    moveTooltip = true,     -- (only when infoInPanel is off) move the listing tooltip next to this panel
    infoInPanel = true,     -- show the group listing info (incl. Raider.IO) in a frame attached to this panel
}

local function GetDB()
    return Helpers and Helpers.GetModuleDB and Helpers.GetModuleDB("quickAccess")
end

local function Setting(key)
    local db = GetDB()
    local v = db and db[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

-- Filters live in the db when "remember" is on, otherwise only for the session
local sessionFilters
local function NewFilters()
    return { dungeons = {}, leaderScore = 0, dungeonScore = 0,
             roleAvailable = false, hasTank = false, hasHealer = false }
end

local function Filters()
    if Setting("rememberFilters") then
        local db = GetDB()
        if db then
            if type(db.filters) ~= "table" then db.filters = NewFilters() end
            local f = db.filters
            f.dungeons = type(f.dungeons) == "table" and f.dungeons or {}
            return f
        end
    end
    sessionFilters = sessionFilters or NewFilters()
    return sessionFilters
end

local function FiltersActive()
    local f = Filters()
    return next(f.dungeons) ~= nil or (f.leaderScore or 0) > 0 or (f.dungeonScore or 0) > 0
        or f.roleAvailable or f.hasTank or f.hasHealer
end

---------------------------------------------------------------------------
-- Group Finder helpers
---------------------------------------------------------------------------
local CAT = { DUNGEONS = 2, RAIDS = 3, QUEST = 1, CUSTOM = 6, DELVES = 121 }

-- pcall wrapper that returns ALL results of fn (the old version dropped everything after the
-- 3rd one, so e.g. the dungeon icon of C_ChallengeMode.GetMapUIInfo was always nil)
local function Unpack(ok, ...)
    if ok then return ... end
    return nil
end
local function SafeCall(fn, ...)
    return Unpack(pcall(fn, ...))
end

-- Resolve a category id by (localized) name, falling back to the known id
local function ResolveCategory(fallbackId, ...)
    local patterns = { ... }
    if C_LFGList and C_LFGList.GetAvailableCategories then
        local cats = SafeCall(C_LFGList.GetAvailableCategories)
        if type(cats) == "table" then
            for _, id in ipairs(cats) do
                local name
                if C_LFGList.GetLfgCategoryInfo then
                    local info = SafeCall(C_LFGList.GetLfgCategoryInfo, id)
                    name = type(info) == "table" and info.name or nil
                end
                if not name and C_LFGList.GetCategoryInfo then
                    name = SafeCall(C_LFGList.GetCategoryInfo, id)
                end
                if type(name) == "string" and not issecretvalue(name) then
                    local lower = name:lower()
                    for _, pat in ipairs(patterns) do
                        if lower:find(pat, 1, true) then return id end
                    end
                end
            end
        end
    end
    return fallbackId
end

local mplusOnly = false  -- set when the Mythic+ quick button started the search

local function OpenPremadeGroups()
    if not PVEFrame then return false end
    if not PVEFrame:IsShown() then
        if PVEFrame_ToggleFrame then
            pcall(PVEFrame_ToggleFrame)
        else
            pcall(ShowUIPanel, PVEFrame)
        end
    end
    if GroupFinderFrame_ShowGroupFrame and LFGListPVEStub then
        pcall(GroupFinderFrame_ShowGroupFrame, LFGListPVEStub)
    elseif GroupFinderFrameGroupButton3 then
        pcall(GroupFinderFrameGroupButton3.Click, GroupFinderFrameGroupButton3)
    end
    return LFGListFrame ~= nil
end

local function StartSearch(categoryID, isMythicPlus)
    if InCombatLockdown() then
        UIErrorsFrame:AddExternalErrorMessage("H3z0 UI: Quick Access is unavailable in combat.")
        return
    end
    if not OpenPremadeGroups() then return end
    mplusOnly = isMythicPlus and true or false

    local cs = LFGListFrame and LFGListFrame.CategorySelection
    if not cs then return end

    -- Preferred: act like a user click on the category button, then "Find a Group"
    local clicked = false
    if cs.CategoryButtons then
        for _, btn in pairs(cs.CategoryButtons) do
            if btn and btn.categoryID == categoryID and btn:IsShown() then
                pcall(btn.Click, btn)
                clicked = true
                break
            end
        end
    end
    if not clicked then
        cs.selectedCategory = categoryID
        cs.selectedFilters = 0
    end

    if cs.FindGroupButton and cs.FindGroupButton.Click then
        pcall(cs.FindGroupButton.Click, cs.FindGroupButton)
    elseif LFGListCategorySelection_StartFindGroup then
        pcall(LFGListCategorySelection_StartFindGroup, cs)
    end
end

---------------------------------------------------------------------------
-- Dungeon list (current season, mapped to LFG activity groups)
---------------------------------------------------------------------------
local dungeons -- { {name=, abbr=, icon=, groupID=}, ... }

local SKIP_WORDS = { ["of"] = true, ["the"] = true, ["de"] = true, ["and"] = true, ["a"] = true }

local function Abbreviate(name)
    local letters, words = "", 0
    for word in name:gmatch("[%a']+") do
        words = words + 1
        if not SKIP_WORDS[word:lower()] then
            letters = letters .. word:sub(1, 1):upper()
        end
    end
    if words <= 1 or #letters < 2 then return name:sub(1, 3):upper() end
    return letters:sub(1, 4)
end

local function NormalizeName(n)
    return (n:lower():gsub("^the ", ""):gsub("[%p]", ""):gsub("%s+", " "))
end

local function BuildDungeonList()
    if dungeons and #dungeons > 0 then return dungeons end
    local list = {}
    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo
        and C_LFGList and C_LFGList.GetAvailableActivityGroups and C_LFGList.GetActivityGroupInfo) then
        return list
    end

    local groupByName = {}
    local groups = SafeCall(C_LFGList.GetAvailableActivityGroups, CAT.DUNGEONS)
    if type(groups) == "table" then
        for _, gid in ipairs(groups) do
            local gname = SafeCall(C_LFGList.GetActivityGroupInfo, gid)
            if type(gname) == "string" and not issecretvalue(gname) then
                groupByName[NormalizeName(gname)] = gid
            end
        end
    end

    local maps = SafeCall(C_ChallengeMode.GetMapTable)
    if type(maps) == "table" then
        for _, mapID in ipairs(maps) do
            local name, _, _, icon = SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
            if type(name) == "string" and not issecretvalue(name) then
                local norm = NormalizeName(name)
                local gid = groupByName[norm]
                if not gid then
                    for gname, id in pairs(groupByName) do
                        if gname:find(norm, 1, true) or norm:find(gname, 1, true) then gid = id break end
                    end
                end
                if gid then
                    list[#list + 1] = { name = name, abbr = Abbreviate(name), icon = icon, groupID = gid }
                end
            end
        end
    end
    if #list > 0 then dungeons = list end
    return list
end

---------------------------------------------------------------------------
-- Result filtering
---------------------------------------------------------------------------
local function PlainNumber(v)
    if type(v) ~= "number" or issecretvalue(v) then return nil end
    return v
end

local function MyRole()
    local spec = GetSpecialization and GetSpecialization()
    if not spec then return nil end
    return GetSpecializationRole and GetSpecializationRole(spec)
end

local function CategoryOfSearch()
    local sp = LFGListFrame and LFGListFrame.SearchPanel
    return sp and sp.categoryID
end

-- true = keep the result visible
local function PassesFilters(resultID)
    local f = Filters()
    local info = SafeCall(C_LFGList.GetSearchResultInfo, resultID)
    if type(info) ~= "table" or issecretvalue(info) then return true end

    local isDungeonSearch = CategoryOfSearch() == CAT.DUNGEONS

    -- Dungeon toggles / Mythic+ only
    if isDungeonSearch and (next(f.dungeons) ~= nil or mplusOnly) then
        local ids = info.activityIDs
        if type(ids) ~= "table" then ids = { info.activityID } end
        local matched = (next(f.dungeons) == nil)
        local isMplus = not mplusOnly
        for _, aid in ipairs(ids) do
            if type(aid) == "number" and not issecretvalue(aid) then
                local act = SafeCall(C_LFGList.GetActivityInfoTable, aid)
                if type(act) == "table" then
                    if act.isMythicPlusActivity then isMplus = true end
                    local gid = act.groupFinderActivityGroupID
                    if gid and not issecretvalue(gid) and f.dungeons[gid] then matched = true end
                end
            end
        end
        if not matched or not isMplus then return false end
    end

    -- Leader overall score
    if (f.leaderScore or 0) > 0 then
        local score = PlainNumber(info.leaderOverallDungeonScore)
        if score and score < f.leaderScore then return false end
    end

    -- Leader score on the (selected) dungeon
    if (f.dungeonScore or 0) > 0 and C_LFGList.GetSearchResultLeaderInfo then
        local leader = SafeCall(C_LFGList.GetSearchResultLeaderInfo, resultID)
        if type(leader) == "table" and not issecretvalue(leader) then
            local best = leader.bestDungeonScoreForListing
            local score = type(best) == "table" and PlainNumber(best.mapScore) or nil
            if score and score < f.dungeonScore then return false end
        end
    end

    -- Roles
    if f.roleAvailable or f.hasTank or f.hasHealer then
        local counts = C_LFGList.GetSearchResultMemberCounts and SafeCall(C_LFGList.GetSearchResultMemberCounts, resultID)
        if type(counts) == "table" and not issecretvalue(counts) then
            if f.hasTank then
                local n = PlainNumber(counts.TANK)
                if n and n < 1 then return false end
            end
            if f.hasHealer then
                local n = PlainNumber(counts.HEALER)
                if n and n < 1 then return false end
            end
            if f.roleAvailable then
                local role = MyRole()
                if role then
                    local n = PlainNumber(counts[role .. "_REMAINING"])
                    if n and n < 1 then return false end
                end
            end
        end
    end

    return true
end

local filterHooked = false
local function ApplyFilterToPanel(panel)
    if not panel or type(panel.results) ~= "table" then return end
    if not FiltersActive() and not mplusOnly then return end
    local kept = {}
    for _, id in ipairs(panel.results) do
        local ok, pass = pcall(PassesFilters, id)
        if not ok or pass then kept[#kept + 1] = id end
    end
    panel.results = kept
    panel.totalResults = #kept
end

-- Re-apply the filters to the list that is already on screen. This only re-reads the current
-- results and redraws the list; it does not go through Blizzard's search/navigation code.
local function Refilter()
    local sp = LFGListFrame and LFGListFrame.SearchPanel
    if not (sp and sp:IsShown()) then return end

    if C_LFGList and C_LFGList.GetFilteredSearchResults and LFGListSearchPanel_UpdateResults then
        local ok = pcall(function()
            local total, results = C_LFGList.GetFilteredSearchResults()
            if type(results) ~= "table" then error("no results") end
            sp.totalResults, sp.results = total, results
            if LFGListUtil_SortSearchResults then LFGListUtil_SortSearchResults(sp.results) end
            ApplyFilterToPanel(sp)
            LFGListSearchPanel_UpdateResults(sp)
        end)
        if ok then return end
    end
    if LFGListSearchPanel_UpdateResultList then pcall(LFGListSearchPanel_UpdateResultList, sp) end
end

local function HookFiltering()
    if filterHooked or not LFGListSearchPanel_UpdateResultList then return end
    filterHooked = true
    hooksecurefunc("LFGListSearchPanel_UpdateResultList", function(panel)
        if not Setting("enabled") then return end
        pcall(ApplyFilterToPanel, panel)
        if (FiltersActive() or mplusOnly) and LFGListSearchPanel_UpdateResults then
            pcall(LFGListSearchPanel_UpdateResults, panel)
        end
    end)
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local PANEL_W, PAD, BTN_H, GAP = 190, 8, 26, 4

local panel = CreateFrame("Frame", "H3z0UIQuickAccessFrame", UIParent, "BackdropTemplate")
panel:SetFrameStrata("MEDIUM")   -- below tooltips and other addons' popups (e.g. Raider.IO)
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:SetSize(PANEL_W, 200)
panel:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
panel:EnableMouse(true)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -8)

-- Drag the panel by its title area; position is remembered
local dragHandle = CreateFrame("Frame", nil, panel)
dragHandle:SetPoint("TOPLEFT", 0, 0)
dragHandle:SetPoint("TOPRIGHT", 0, 0)
dragHandle:SetHeight(22)
dragHandle:EnableMouse(true)
dragHandle:RegisterForDrag("LeftButton")
dragHandle:SetScript("OnDragStart", function()
    if Setting("locked") or InCombatLockdown() then return end
    panel:StartMoving()
end)
dragHandle:SetScript("OnDragStop", function()
    panel:StopMovingOrSizing()
    local db = GetDB()
    local point, _, relPoint, x, y = panel:GetPoint()
    if db and point then db.customPos = { point, relPoint, x, y } end
end)
dragHandle:SetScript("OnEnter", function(self)
    if Setting("locked") then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Drag to move")
    GameTooltip:AddLine("Reset the position in Settings > General & QoL > Quick Access", 1, 1, 1, true)
    GameTooltip:Show()
end)
dragHandle:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function Skin()
    local sr, sg, sb, sa, bgr, bgg, bgb, bga = 0.2, 1, 0.6, 1, 0.07, 0.07, 0.07, 0.95
    if Helpers and Helpers.GetSkinColors then
        local a, b, c, d, e, f, g, h = Helpers.GetSkinColors()
        if a then sr, sg, sb, sa, bgr, bgg, bgb, bga = a, b, c, d, e, f, g, h end
    end
    panel:SetBackdropColor(bgr, bgg, bgb, bga or 0.95)
    panel:SetBackdropBorderColor(sr, sg, sb, sa or 1)
    title:SetText("|cff" .. string.format("%02x%02x%02x", sr * 255, sg * 255, sb * 255) .. "Quick Access|r")
    return sr, sg, sb
end

local skinButtons = {}   -- every button, to recolor on refresh

local function MakeButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or (PANEL_W - PAD * 2), height or BTN_H)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropColor(0.13, 0.13, 0.15, 1)
    b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text or "")
    b:SetScript("OnEnter", function(self)
        local r, g, bl = Skin()
        self:SetBackdropBorderColor(r, g, bl, 1)
    end)
    b:SetScript("OnLeave", function(self)
        if self.selected then
            local r, g, bl = Skin()
            self:SetBackdropBorderColor(r, g, bl, 1)
        else
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
    end)
    skinButtons[#skinButtons + 1] = b
    return b
end

local function SetSelected(btn, on)
    btn.selected = on and true or false
    if on then
        local r, g, b = Skin()
        btn:SetBackdropColor(r * 0.35, g * 0.35, b * 0.35, 1)
        btn:SetBackdropBorderColor(r, g, b, 1)
    else
        btn:SetBackdropColor(0.13, 0.13, 0.15, 1)
        btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
end

-- ===== Page 1: quick access buttons =====
local quickPage = CreateFrame("Frame", nil, panel)
quickPage:SetPoint("TOPLEFT", 0, 0)
quickPage:SetPoint("BOTTOMRIGHT", 0, 0)

local quickDefs = {
    { "Mythic+", function() StartSearch(CAT.DUNGEONS, true) end },
    { "Raids",   function() StartSearch(ResolveCategory(CAT.RAIDS, "raid"), false) end },
    { "Delves",  function() StartSearch(ResolveCategory(CAT.DELVES, "delve"), false) end },
    { "Quest",   function() StartSearch(ResolveCategory(CAT.QUEST, "quest"), false) end },
    { "Custom",  function() StartSearch(ResolveCategory(CAT.CUSTOM, "custom"), false) end },
}
local quickButtons = {}
for i, def in ipairs(quickDefs) do
    local b = MakeButton(quickPage, def[1], nil, 32)
    b:SetPoint("TOPLEFT", PAD, -30 - (i - 1) * (32 + GAP))
    b:SetScript("OnClick", def[2])
    quickButtons[i] = b
end
local QUICK_HEIGHT = 30 + #quickDefs * (32 + GAP) + PAD

-- ===== Page 2: filters =====
local filterPage = CreateFrame("Frame", nil, panel)
filterPage:SetPoint("TOPLEFT", 0, 0)
filterPage:SetPoint("BOTTOMRIGHT", 0, 0)
filterPage:Hide()

local backBtn = MakeButton(filterPage, "< Quick Access", nil, 20)
backBtn:SetPoint("TOPLEFT", PAD, -26)
backBtn:SetScript("OnClick", function()
    local sp = LFGListFrame and LFGListFrame.SearchPanel
    local back = sp and sp.BackButton
    if back and back.Click then pcall(back.Click, back) end
end)

local dungeonHolder = CreateFrame("Frame", nil, filterPage)
dungeonHolder:SetPoint("TOPLEFT", PAD, -52)
dungeonHolder:SetSize(PANEL_W - PAD * 2, 10)
local dungeonButtons = {}

local leaderBox, dungeonBox, roleBtn, tankBtn, healBtn, defaultBtn
local filterLayoutY = 0

local function RefreshFilterWidgets()
    local f = Filters()
    for _, b in ipairs(dungeonButtons) do
        SetSelected(b, f.dungeons[b.groupID])
    end
    if leaderBox then leaderBox:SetText(tostring(f.leaderScore or 0)) end
    if dungeonBox then dungeonBox:SetText(tostring(f.dungeonScore or 0)) end
    if roleBtn then SetSelected(roleBtn, f.roleAvailable) end
    if tankBtn then SetSelected(tankBtn, f.hasTank) end
    if healBtn then SetSelected(healBtn, f.hasHealer) end
end

local function FilterChanged()
    RefreshFilterWidgets()
    Refilter()
end

local function MakeScoreRow(label, key, y)
    local row = CreateFrame("Frame", nil, filterPage, "BackdropTemplate")
    row:SetSize(PANEL_W - PAD * 2, BTN_H)
    row:SetPoint("TOPLEFT", PAD, y)
    row:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    row:SetBackdropColor(0.13, 0.13, 0.15, 1)
    row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 6, 0)
    fs:SetText(label)
    local eb = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    eb:SetSize(48, 18)
    eb:SetPoint("RIGHT", -4, 0)
    eb:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    eb:SetBackdropColor(0, 0, 0, 0.7)
    eb:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetJustifyH("CENTER")
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(5)
    local function Commit(self)
        local f = Filters()
        f[key] = tonumber(self:GetText()) or 0
        self:ClearFocus()
        FilterChanged()
    end
    eb:SetScript("OnEnterPressed", Commit)
    eb:SetScript("OnEditFocusLost", function(self)
        local f = Filters()
        local v = tonumber(self:GetText()) or 0
        if v ~= (f[key] or 0) then f[key] = v; FilterChanged() end
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshFilterWidgets() end)
    return eb
end

local function BuildFilterPage()
    if filterPage.built then return end
    filterPage.built = true
    local y = -(52)
    -- dungeons are laid out dynamically (see LayoutDungeons); rows below follow
    filterLayoutY = y
end

-- Lays out dungeon buttons + the static rows below them, returns total height
local function LayoutFilterPage(showDungeons)
    BuildFilterPage()
    local list = showDungeons and BuildDungeonList() or {}

    -- create dungeon buttons once
    if #dungeonButtons == 0 and #list > 0 then
        for _, d in ipairs(list) do
            local b = MakeButton(dungeonHolder, d.abbr, (PANEL_W - PAD * 2 - GAP) / 2, 26)
            b.groupID = d.groupID
            b.dungeonName = d.name
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetPoint("LEFT", 4, 0)
            if d.icon then icon:SetTexture(d.icon) end
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b.text:ClearAllPoints()
            b.text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            b:SetScript("OnClick", function(self)
                local f = Filters()
                if f.dungeons[self.groupID] then f.dungeons[self.groupID] = nil
                else f.dungeons[self.groupID] = true end
                FilterChanged()
            end)
            b:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.dungeonName)
                GameTooltip:Show()
            end)
            b:HookScript("OnLeave", function() GameTooltip:Hide() end)
            dungeonButtons[#dungeonButtons + 1] = b
        end
    end

    local rows = 0
    for i, b in ipairs(dungeonButtons) do
        b:SetShown(showDungeons)
        if showDungeons then
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", dungeonHolder, "TOPLEFT", col * ((PANEL_W - PAD * 2 - GAP) / 2 + GAP), -row * (26 + GAP))
            rows = math.max(rows, row + 1)
        end
    end
    local gridH = showDungeons and rows > 0 and (rows * (26 + GAP)) or 0
    dungeonHolder:SetHeight(math.max(gridH, 1))

    local y = -52 - gridH - (gridH > 0 and 4 or 0)

    if not leaderBox then
        leaderBox = MakeScoreRow("Leader Score Over", "leaderScore", y)
    end
    leaderBox:GetParent():ClearAllPoints()
    leaderBox:GetParent():SetPoint("TOPLEFT", PAD, y)
    y = y - (BTN_H + GAP)

    if not dungeonBox then
        dungeonBox = MakeScoreRow("Dungeon Score Over", "dungeonScore", y)
    end
    dungeonBox:GetParent():SetShown(showDungeons)
    dungeonBox:GetParent():ClearAllPoints()
    dungeonBox:GetParent():SetPoint("TOPLEFT", PAD, y)
    if showDungeons then y = y - (BTN_H + GAP) end

    if not roleBtn then
        roleBtn = MakeButton(filterPage, "Role Available")
        roleBtn:SetScript("OnClick", function()
            local f = Filters(); f.roleAvailable = not f.roleAvailable; FilterChanged()
        end)
        roleBtn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Role Available")
            GameTooltip:AddLine("Only groups with a free slot for your current role.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        roleBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    roleBtn:ClearAllPoints()
    roleBtn:SetPoint("TOPLEFT", PAD, y)
    y = y - (BTN_H + GAP)

    local half = (PANEL_W - PAD * 2 - GAP) / 2
    if not tankBtn then
        tankBtn = MakeButton(filterPage, "Has Tank", half)
        tankBtn:SetScript("OnClick", function()
            local f = Filters(); f.hasTank = not f.hasTank; FilterChanged()
        end)
        healBtn = MakeButton(filterPage, "Has Healer", half)
        healBtn:SetScript("OnClick", function()
            local f = Filters(); f.hasHealer = not f.hasHealer; FilterChanged()
        end)
    end
    tankBtn:ClearAllPoints()
    tankBtn:SetPoint("TOPLEFT", PAD, y)
    healBtn:ClearAllPoints()
    healBtn:SetPoint("TOPLEFT", PAD + half + GAP, y)
    y = y - (BTN_H + GAP + 4)

    if not defaultBtn then
        defaultBtn = MakeButton(filterPage, "Default")
        defaultBtn:SetScript("OnClick", function()
            local f = Filters()
            f.dungeons = {}
            f.leaderScore, f.dungeonScore = 0, 0
            f.roleAvailable, f.hasTank, f.hasHealer = false, false, false
            mplusOnly = false
            FilterChanged()
        end)
    end
    defaultBtn:ClearAllPoints()
    defaultBtn:SetPoint("TOPLEFT", PAD, y)
    y = y - (BTN_H + PAD)

    RefreshFilterWidgets()
    return math.abs(y)
end

---------------------------------------------------------------------------
-- Visibility / docking
---------------------------------------------------------------------------
-- Screen-pixel rectangle of a frame (left, right, top, bottom) or nil while it has no layout yet
local function PxRect(f)
    if not f or not f.GetLeft then return nil end
    local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    if type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" then
        return nil
    end
    local s = f:GetEffectiveScale()
    return l * s, r * s, t * s, b * s
end

-- true while the panel sits on the right-hand side of the Group Finder window
local function PanelNextToWindow()
    if not PVEFrame or not panel:IsShown() then return false end
    local pl = PxRect(panel)
    local _, wr = PxRect(PVEFrame)
    return pl ~= nil and wr ~= nil and pl >= wr - 6
end

local function Dock()
    if InCombatLockdown() or not PVEFrame then return end
    local scale = tonumber(Setting("scale")) or 1
    panel:SetScale(scale)
    panel:ClearAllPoints()

    panel.dockedSide = nil

    -- A position the user dragged the panel to wins over everything
    local db = GetDB()
    local cp = db and db.customPos
    if type(cp) == "table" and cp[1] then
        panel:SetPoint(cp[1], UIParent, cp[2] or cp[1], cp[3] or 0, cp[4] or 0)
        return
    end

    local ox, oy = tonumber(Setting("offsetX")) or 0, tonumber(Setting("offsetY")) or 0
    local side = Setting("side")

    if side == "AUTO" or side == "LEFT" then
        local left = PVEFrame:GetLeft()
        local pe, ue = PVEFrame:GetEffectiveScale(), UIParent:GetEffectiveScale()
        local ratio = (type(pe) == "number" and type(ue) == "number" and ue ~= 0) and (pe / ue) or 1
        local room = type(left) == "number" and (left * ratio) or 0
        -- "Left" with no room on screen would push the panel off-screen: use the right side instead
        if room >= (PANEL_W * scale + 8 + math.max(0, -ox)) then side = "LEFT" else side = "RIGHT" end
    end

    if side == "LEFT" then
        panel:SetPoint("TOPRIGHT", PVEFrame, "TOPLEFT", -4 + ox, oy)
    elseif side == "BELOW" then
        -- under the window and its tabs
        panel:SetPoint("TOPLEFT", PVEFrame, "BOTTOMLEFT", ox, -36 + oy)
    else
        -- Right side: sit directly next to the window. Raider.IO's profile box is moved out of
        -- the way automatically (see the Raider.IO section below), so nothing overlaps.
        panel:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", 4 + ox, oy)
        panel.dockedSide = "RIGHT"
    end
end

---------------------------------------------------------------------------
-- Raider.IO profile box
--
-- Raider.IO parks its profile box (GameTooltip "RaiderIO_ProfileTooltip", positioned through the
-- frame "RaiderIO_ProfileTooltipAnchor") on the right edge of the Group Finder window, which is
-- exactly where this panel docks, so the two used to sit on top of each other.
-- We do not poll or fight it: we hook the anchor's SetPoint and, every time Raider.IO places it,
-- put it right next to the panel instead (or under the panel when the screen is too narrow).
-- Anything user-placed (Raider.IO's "free position" mode) is left alone.
---------------------------------------------------------------------------
local RIO_GAP = 4
local rio = { busy = false, moved = false, beside = false, hooked = false }
local onRioChanged      -- set by SetupHooks: re-places the listing info frame

local function RioFrames()
    local a, t = _G.RaiderIO_ProfileTooltipAnchor, _G.RaiderIO_ProfileTooltip
    if type(a) == "table" and a.SetPoint and type(t) == "table" and t.IsShown then return a, t end
end

-- Would the box, left where Raider.IO wants it (right edge of the window), land on our panel?
local function RioCollides(home, tip)
    if home[2] ~= PVEFrame then return false end     -- free position / another anchor: not ours to touch
    local pl, pr, pt, pb = PxRect(panel)
    local _, wr, wt = PxRect(PVEFrame)
    if not (pl and wr) then return false end
    local ts = tip:GetEffectiveScale()
    local w = math.max((tip:GetWidth() or 0) * ts, 250 * ts)
    local h = math.max((tip:GetHeight() or 0) * ts, 150 * ts)
    return pl < wr + w and pr > wr and pt > wt - h and pb < wt
end

local function ApplyRIO()
    local anchor, tip = RioFrames()
    local home = rio.home
    if not anchor or not home then return end

    local collide = Setting("enabled") and panel:IsShown() and PVEFrame and PVEFrame:IsShown()
        and RioCollides(home, tip)

    rio.busy = true
    local ok = pcall(function()
        if collide then
            local aw = anchor:GetWidth() or 16
            local _, pr = PxRect(panel)
            local room = pr and ((UIParent:GetRight() or 0) * UIParent:GetEffectiveScale() - pr) or 0
            local need = ((tip:GetWidth() or 260) + RIO_GAP) * tip:GetEffectiveScale()
            anchor:ClearAllPoints()
            if room >= need then
                -- the box starts at the anchor's right edge, hence "- aw"
                anchor:SetPoint("TOPLEFT", panel, "TOPRIGHT", RIO_GAP - aw, 0)
                rio.beside = true
            else
                anchor:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", -aw, -RIO_GAP)
                rio.beside = false
            end
            rio.moved = true
        elseif rio.moved then
            anchor:ClearAllPoints()
            anchor:SetPoint(home[1], home[2], home[3], home[4], home[5])
            rio.moved, rio.beside = false, false
        end
    end)
    rio.busy = false
    if not ok then rio.moved, rio.beside = false, false end
    if onRioChanged then pcall(onRioChanged) end
end

-- Hooks Raider.IO once its frames exist; cheap enough to call whenever the panel updates
local function EnsureRIO()
    if rio.hooked then return true end
    local anchor, tip = RioFrames()
    if not anchor then return false end
    rio.hooked = true

    local p, rel, rp, x, y = anchor:GetPoint()
    if type(rel) == "table" and rel ~= panel then rio.home = { p, rel, rp or p, x or 0, y or 0 } end

    hooksecurefunc(anchor, "SetPoint", function(_, point, relTo, relPoint, x2, y2)
        if rio.busy or type(relTo) ~= "table" or relTo == panel then return end
        -- Raider.IO just (re)positioned its box: remember where it wanted to be, then move it if needed
        rio.home = { point, relTo, relPoint or point, tonumber(x2) or 0, tonumber(y2) or 0 }
        rio.moved, rio.beside = false, false
        pcall(ApplyRIO)
    end)

    local lastW = 0
    tip:HookScript("OnShow", function() pcall(ApplyRIO) end)
    tip:HookScript("OnHide", function() if onRioChanged then pcall(onRioChanged) end end)
    tip:HookScript("OnSizeChanged", function(_, w)
        if type(w) == "number" and math.abs(w - lastW) > 1 then
            lastW = w
            pcall(ApplyRIO)
        end
    end)
    pcall(ApplyRIO)
    return true
end

panel:HookScript("OnShow", function() if EnsureRIO() then pcall(ApplyRIO) end end)
panel:HookScript("OnHide", function() if rio.hooked then pcall(ApplyRIO) end end)

local currentPage = nil      -- "filter" or "quick"
local quickCheckPending = false

local function UpdatePanel(confirmed)
    if not Setting("enabled") or not PVEFrame or not PVEFrame:IsShown() then
        panel:Hide()
        currentPage = nil
        return
    end
    -- only on the Premade Groups tab
    if not (LFGListFrame and LFGListFrame:IsVisible()) then
        panel:Hide()
        currentPage = nil
        return
    end

    Dock()
    Skin()
    panel:SetFrameLevel((PVEFrame:GetFrameLevel() or 1) + 1)
    if EnsureRIO() then pcall(ApplyRIO) end

    local sp = LFGListFrame.SearchPanel
    local inSearch = sp and sp:IsShown()
    local wantFilter = inSearch and Setting("showFilters")

    -- Do not flip from the filters back to Quick Access because of a momentary hide/show of the
    -- search panel (it can happen while the list redraws): wait and confirm first.
    if not wantFilter and currentPage == "filter" and confirmed ~= true then
        if not quickCheckPending then
            quickCheckPending = true
            C_Timer.After(0.35, function()
                quickCheckPending = false
                UpdatePanel(true)
            end)
        end
        panel:Show()
        return
    end

    if wantFilter then
        quickPage:Hide()
        filterPage:Show()
        local isDungeons = (sp.categoryID == CAT.DUNGEONS)
        panel:SetHeight(LayoutFilterPage(isDungeons))
        currentPage = "filter"
    else
        filterPage:Hide()
        quickPage:Show()
        panel:SetHeight(QUICK_HEIGHT)
        currentPage = "quick"
    end

    -- highlight the active quick button
    for i, b in ipairs(quickButtons) do SetSelected(b, false) end
    panel:Show()
end

local hooked = false
local function SetupHooks()
    if hooked or not PVEFrame or not LFGListFrame then return end
    hooked = true
    HookFiltering()

    local function IsSearchEntry(owner)
        local sp = LFGListFrame and LFGListFrame.SearchPanel
        if not owner or not sp or not sp:IsShown() then return false end
        if owner.resultID then return true end
        local p = owner
        for _ = 1, 8 do
            p = p.GetParent and p:GetParent()
            if not p then return false end
            if p == sp then return true end
        end
        return false
    end

    ---------------------------------------------------------------------
    -- Listing info frame: mirrors the group listing tooltip (Blizzard lines plus whatever
    -- Raider.IO adds) inside a frame attached to the panel, so it can never overlap it.
    ---------------------------------------------------------------------
    local info = CreateFrame("Frame", "H3z0UIQuickAccessInfo", UIParent, "BackdropTemplate")
    info:SetFrameStrata("DIALOG")
    info:SetClampedToScreen(true)
    info:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    info:Hide()
    panel.infoFrame = info
    local rows, MAX_ROWS, ROW_H = {}, 45, 13

    local function GetRow(i)
        if not rows[i] then
            local left = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local right = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            left:SetJustifyH("LEFT")
            right:SetJustifyH("RIGHT")
            rows[i] = { left = left, right = right }
        end
        return rows[i]
    end

    local function SafeText(fs)
        if not fs or not fs.GetText then return nil end
        local t = fs:GetText()
        if t == nil or issecretvalue(t) then return nil end
        return t
    end

    local function FillInfo(tip)
        local n = math.min(tip:NumLines() or 0, MAX_ROWS)
        if n == 0 then info:Hide() return false end

        for i = 1, #rows do rows[i].left:Hide(); rows[i].right:Hide() end

        local y, maxW = -8, 0
        for i = 1, n do
            local lfs, rfs = _G["GameTooltipTextLeft" .. i], _G["GameTooltipTextRight" .. i]
            local lt, rt = SafeText(lfs), SafeText(rfs)
            local row = GetRow(i)

            row.left:ClearAllPoints()
            row.left:SetPoint("TOPLEFT", info, "TOPLEFT", 8, y)
            row.left:SetText(lt or "")
            local lr, lg, lb = 1, 1, 1
            if lfs and lfs.GetTextColor then lr, lg, lb = lfs:GetTextColor() end
            row.left:SetTextColor(lr, lg, lb)
            row.left:Show()

            local rw = 0
            row.right:ClearAllPoints()
            if rt and rt ~= "" then
                row.right:SetPoint("TOPRIGHT", info, "TOPRIGHT", -8, y)
                row.right:SetText(rt)
                local rr, rg, rb = 1, 1, 1
                if rfs and rfs.GetTextColor then rr, rg, rb = rfs:GetTextColor() end
                row.right:SetTextColor(rr, rg, rb)
                row.right:Show()
                rw = row.right:GetStringWidth() or 0
            end

            local lw = row.left:GetStringWidth() or 0
            maxW = math.max(maxW, lw + (rw > 0 and (rw + 16) or 0))
            y = y - ROW_H
        end

        local width = math.max(220, math.min(maxW + 16, 420))
        info:SetSize(width, -y + 8)
        return true
    end

    -- Where the info frame goes. It must never cover the Group Finder window, the panel or
    -- Raider.IO's profile box, so candidates are tried in order and the first one with room wins:
    --   panel left of the window : left of the panel, then right of Raider.IO's box / the window
    --   panel right of the window: right of Raider.IO's box (which sits next to the panel) or the
    --                              panel, then left of the window
    --   last resort              : below the panel
    local function PlaceInfo()
        info:SetScale(panel:GetScale())
        info:ClearAllPoints()

        local us = UIParent:GetEffectiveScale()
        local uiRight = (UIParent:GetRight() or 0) * us
        local need = ((info:GetWidth() or 220) + 8) * info:GetEffectiveScale()

        local _, riTip = RioFrames()
        local riShown = riTip and riTip:IsShown() and PxRect(riTip) ~= nil
        local pl, pr = PxRect(panel)
        local wl = PxRect(PVEFrame)
        local panelLeftOfWindow = pl and wl and pr <= wl + 6

        local candidates = {}
        if panelLeftOfWindow then
            candidates[1] = { panel, "TOPRIGHT", "TOPLEFT", -4, "L" }
            candidates[2] = { riShown and riTip or PVEFrame, "TOPLEFT", "TOPRIGHT", 4, "R" }
        else
            candidates[1] = { (rio.beside and riShown) and riTip or panel, "TOPLEFT", "TOPRIGHT", 4, "R" }
            if PVEFrame then candidates[2] = { PVEFrame, "TOPRIGHT", "TOPLEFT", -4, "L" } end
        end

        local placed = false
        for _, c in ipairs(candidates) do
            local ref = c[1]
            local l, r = PxRect(ref)
            if l and ((c[5] == "R" and uiRight - r >= need) or (c[5] == "L" and l >= need)) then
                info:SetPoint(c[2], ref, c[3], c[4], 0)
                placed = true
                break
            end
        end
        if not placed then info:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -4) end

        local sr, sg, sb = Skin()
        info:SetBackdropColor(0.07, 0.07, 0.07, 0.96)
        info:SetBackdropBorderColor(sr or 0.2, sg or 1, sb or 0.6, 1)
    end
    -- Raider.IO's box moved / appeared / went away: keep the info frame clear of it
    onRioChanged = function()
        if info:IsShown() then PlaceInfo() end
    end

    local function InfoActive(tip)
        return Setting("enabled") and Setting("infoInPanel") and panel:IsShown()
            and IsSearchEntry(tip:GetOwner())
    end

    local function ShowInfo(tip)
        if not tip.h3z0Hidden or not tip:IsShown() then return end
        local ok, filled = pcall(FillInfo, tip)
        if ok and filled then
            pcall(PlaceInfo)
            info:Show()
        else
            -- never leave the real tooltip invisible if something went wrong
            tip:SetAlpha(1)
            tip.h3z0Hidden = nil
            info:Hide()
        end
    end

    -- Old behaviour (only when "info in panel" is off): put the tooltip right of the panel
    local function MoveTooltip(tip)
        if not Setting("enabled") or Setting("infoInPanel") or not Setting("moveTooltip") then return end
        if not PanelNextToWindow() or not IsSearchEntry(tip:GetOwner()) then return end
        tip:ClearAllPoints()
        tip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 4, 0)
    end

    GameTooltip:HookScript("OnShow", function(tip)
        -- This hook runs for every tooltip in the game: bail out immediately when we are not involved
        if not panel:IsShown() then
            if tip.h3z0Hidden then tip:SetAlpha(1) tip.h3z0Hidden = nil end
            return
        end
        local okActive, active = pcall(InfoActive, tip)
        if okActive and active then
            tip:SetAlpha(0)          -- the info frame replaces it visually
            tip.h3z0Hidden = true
            -- Raider.IO appends its lines after the tooltip is shown, so copy a bit later (twice)
            C_Timer.After(0.03, function() ShowInfo(tip) end)
            C_Timer.After(0.25, function() ShowInfo(tip) end)
        else
            if tip.h3z0Hidden then tip:SetAlpha(1) tip.h3z0Hidden = nil end
            pcall(MoveTooltip, tip)
            C_Timer.After(0, function() if tip:IsShown() then pcall(MoveTooltip, tip) end end)
        end
    end)
    GameTooltip:HookScript("OnHide", function(tip)
        if tip.h3z0Hidden then
            tip:SetAlpha(1)
            tip.h3z0Hidden = nil
        end
        info:Hide()
    end)

    local function Later() C_Timer.After(0.05, UpdatePanel) end
    PVEFrame:HookScript("OnShow", Later)
    PVEFrame:HookScript("OnHide", function() panel:Hide() end)
    LFGListFrame:HookScript("OnShow", Later)
    LFGListFrame:HookScript("OnHide", Later)
    if LFGListFrame.SearchPanel then
        LFGListFrame.SearchPanel:HookScript("OnShow", Later)
        LFGListFrame.SearchPanel:HookScript("OnHide", Later)
    end
    if LFGListFrame.CategorySelection then
        LFGListFrame.CategorySelection:HookScript("OnShow", Later)
    end
    if LFGListFrame_SetActivePanel then
        hooksecurefunc("LFGListFrame_SetActivePanel", Later)
    end
    Later()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_GroupFinder" or arg1 == "Blizzard_LFGList" then
            C_Timer.After(0, function() pcall(SetupHooks) end)
        elseif arg1 == "RaiderIO" then
            C_Timer.After(0, function() pcall(EnsureRIO) end)
        end
    elseif event == "PLAYER_LOGIN" then
        pcall(SetupHooks)
    elseif event == "PLAYER_REGEN_ENABLED" then
        pcall(UpdatePanel)
    end
end)

-- Debug: /h3qa scan   (then hover a group listing within 5 seconds)
SLASH_H3QA1 = "/h3qa"
SlashCmdList["H3QA"] = function(msg)
    if msg == "scan" then
        print("|cff00ff99H3z0 UI|r: hover a group in the list now... (5 s)")
        C_Timer.After(5, function()
            print("|cff00ff99H3z0 UI scan|r panel shown:", tostring(panel:IsShown()),
                "docked:", tostring(panel.dockedSide),
                "customPos:", tostring(GetDB() and GetDB().customPos ~= nil))
            print("GameTooltip shown:", tostring(GameTooltip:IsShown()), "alpha:", tostring(GameTooltip:GetAlpha()),
                "lines:", tostring(GameTooltip:NumLines()))
            local sp = LFGListFrame and LFGListFrame.SearchPanel
            print("SearchPanel shown:", tostring(sp and sp:IsShown()), "category:", tostring(sp and sp.categoryID),
                "results:", tostring(sp and sp.results and #sp.results), "page:", tostring(currentPage))
            local owner = GameTooltip:GetOwner()
            print("GameTooltip owner:", owner and tostring(owner:GetName() or "unnamed") or "none",
                "resultID:", tostring(owner and owner.resultID))
            local ra, rt = RioFrames()
            print("RaiderIO anchor:", tostring(ra ~= nil), "tooltip shown:", tostring(rt and rt:IsShown()),
                "moved by us:", tostring(rio.moved), "beside panel:", tostring(rio.beside))
        end)
    else
        print("|cff00ff99H3z0 UI|r: /h3qa scan")
    end
end

_G.H3z0UI_RefreshQuickAccess = function()
    pcall(Skin)
    pcall(UpdatePanel)
    pcall(Refilter)
end
