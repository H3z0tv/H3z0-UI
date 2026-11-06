local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Event bar: a strip of tiles along the bottom of the world map.
--   Weekly Quest     all weekly storylines of the season (Soiree, Abundance, Prey Hunt, Lady
--                    Liadrin, Weekly Dungeon, Legends, Silvermoon Court, Zul'jarra's Forces,
--                    Slayer's Duellum). Hover: one line per storyline with its state.
--   Professions      the weekly quest of each of your two professions.
--   Stormarion Assault  a timer: when it runs (green bar) and when it starts next.
--   Cursed Surges    a timer from the game's event schedule: where it runs and when.
--   Great Vault      the three rows (Raid, Mythic+, World) with the slots unlocked.
-- Click a tile to open the map at the place (Cursed Surges sets a map pin).
-- Settings: profile.h3zWeeklies (enabled, showVault). Retail only.
---------------------------------------------------------------------------
if ns.Client and (ns.Client.isClassic or ns.Client.isForever) then return end

local W = {}
ns.Weeklies = W
_G.H3z0UI_Weeklies = W

local BAR_H, PAD, GAP = 40, 6, 6

local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.h3zWeeklies = p.h3zWeeklies or {}
    local s = p.h3zWeeklies
    if s.enabled == nil then s.enabled = true end
    if s.showVault == nil then s.showVault = true end
    return s
end
W.Settings = Settings

local GREEN  = { 0.35, 1, 0.45 }
local YELLOW = { 1, 0.82, 0.2 }
local RED    = { 1, 0.45, 0.45 }
local GREY   = { 0.75, 0.75, 0.75 }
local PURPLE = { 0.7, 0.4, 1 }

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function Plain(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function QuestDone(id)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) and true or false
end

local function QuestTitle(id)
    local t = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if type(t) == "string" and t ~= "" then return t end
end

local function MapName(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name
end

local function Clock(secs)
    secs = math.max(0, math.floor(secs or 0))
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

local function OpenMap(mapID)
    return function()
        if C_Map and C_Map.OpenWorldMap and mapID then pcall(C_Map.OpenWorldMap, mapID) end
    end
end

-- storyline state: "done", "ready", "active", "todo" plus the quest id behind it
local function Storyline(ids)
    local active
    for _, id in ipairs(ids) do
        if QuestDone(id) then return "done", id end
        if not active and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) then active = id end
    end
    if active then
        local ready = C_QuestLog.IsComplete and C_QuestLog.IsComplete(active)
        return ready and "ready" or "active", active
    end
    return "todo"
end

---------------------------------------------------------------------------
-- data
---------------------------------------------------------------------------
local STORYLINES = {
    { name = "Soiree",              map = 2395, ids = { 90573, 90574, 90575, 90576 } },
    { name = "Silvermoon Court",    map = 2395, ids = { 89289 } },
    { name = "Slayer's Duellum",    map = 2444, ids = { 89354 } },
    { name = "Dungeon",             map = 2393, ids = { 93751, 93752, 93753, 93754, 93755, 93756, 93757, 93758 } },
    { name = "Legend",              map = 2413, ids = { 89268, 92713 } },
    { name = "Zul'jarra's Forces",  map = 2512, ids = { 96995, 95520 } },
    { name = "Lady Liadrin",        map = 2393, ids = { 93766, 93767, 93769, 93889, 93890, 93891, 93892, 93909, 93911, 93912, 93913, 94457, 95842, 95843, 96727, 98232 } },
    { name = "Prey Hunt",           map = 2393, ids = { 94446, 93910 } },
    { name = "Abundance",           map = nil,  ids = { 89507 } },
}

local PROFESSIONS = {
    [4620669] = { 93690 },                      -- Alchemy
    [4620670] = { 93691 },                      -- Blacksmithing
    [4620672] = { 93697, 93698, 93699 },        -- Enchanting
    [4620673] = { 93692 },                      -- Engineering
    [4620675] = { 93700, 93702, 93703, 93704 }, -- Herbalism
    [4620676] = { 93693 },                      -- Inscription
    [4620677] = { 93694 },                      -- Jewelcrafting
    [4620678] = { 93695 },                      -- Leatherworking
    [4620679] = { 93705, 93706, 93708, 93709 }, -- Mining
    [4620680] = { 93710, 93711, 93714 },        -- Skinning
    [4620681] = { 93696 },                      -- Tailoring
}

local STORM = { start = 1772728200, interval = 30 * 60, duration = 15 * 60, quest = 90962, map = 2405 }

local SURGE_MAP = 2512
local SURGE = {
    interval = 30 * 60, duration = 5 * 60,
    pois = {
        [8936] = { 0.264, 0.649 }, [8937] = { 0.671, 0.775 }, [8938] = { 0.457, 0.296 },
        [8939] = { 0.705, 0.327 }, [8940] = { 0.467, 0.628 },
    },
}

---------------------------------------------------------------------------
-- tile: Weekly Quest
---------------------------------------------------------------------------
local function WeeklyTile()
    local done, total = 0, #STORYLINES
    for _, s in ipairs(STORYLINES) do
        if Storyline(s.ids) == "done" then done = done + 1 end
    end
    local t = { title = "Weekly Quest", icon = 236681, click = OpenMap(2537), help = "Click to show location" }
    if done >= total then
        t.sub, t.subColor = "Completed", GREEN
    else
        t.sub, t.subColor = done > 0 and (done .. " of " .. total .. " done") or "Not completed", done > 0 and YELLOW or RED
    end
    t.tooltip = function()
        GameTooltip:AddDoubleLine("Location:", MapName(2537) or "", 1, 1, 1, 1, 0.82, 0.2)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Quest Progress:", 1, 1, 1)
        for _, s in ipairs(STORYLINES) do
            local state, id = Storyline(s.ids)
            local left = s.name
            local zone = MapName(s.map)
            if zone then left = left .. " (" .. zone .. ")" end
            local right, c
            if state == "done" then
                local q = QuestTitle(id)
                right, c = (q and (q .. " - ") or "") .. "Completed", GREEN
            elseif state == "ready" then
                local q = QuestTitle(id)
                right, c = (q and (q .. " - ") or "") .. "Ready to turn in", YELLOW
            elseif state == "active" then
                local q = QuestTitle(id)
                right, c = (q and (q .. " - ") or "") .. "In Progress", YELLOW
            else
                right, c = "Not Accepted", RED
            end
            GameTooltip:AddDoubleLine(left, right, 0.9, 0.9, 0.9, c[1], c[2], c[3])
        end
    end
    return t
end

---------------------------------------------------------------------------
-- tile: Professions
---------------------------------------------------------------------------
local function MyProfessions()
    local list = {}
    if not GetProfessions then return list end
    local prof = { GetProfessions() }
    for i = 1, 2 do
        local idx = prof[i]
        if idx then
            local name, icon = GetProfessionInfo(idx)
            local ids = icon and PROFESSIONS[icon]
            if ids then list[#list + 1] = { name = name or "Profession", icon = icon, ids = ids } end
        end
    end
    return list
end

local function ProfessionTile()
    local list = MyProfessions()
    local done = 0
    for _, p in ipairs(list) do
        if Storyline(p.ids) == "done" then done = done + 1 end
    end
    local t = { title = "Professions Weekly", icon = 1392955, click = OpenMap(2393), help = "Click to show location" }
    if #list == 0 then
        t.sub, t.subColor = "No profession", GREY
    elseif done >= #list then
        t.sub, t.subColor = "Completed", GREEN
    else
        t.sub, t.subColor = done > 0 and (done .. " of " .. #list .. " done") or "Not completed", done > 0 and YELLOW or RED
    end
    t.tooltip = function()
        GameTooltip:AddDoubleLine("Location:", MapName(2393) or "", 1, 1, 1, 1, 0.82, 0.2)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Quest Progress:", 1, 1, 1)
        if #list == 0 then GameTooltip:AddLine("You have no profession with a weekly quest.", 0.7, 0.7, 0.7) end
        for _, p in ipairs(list) do
            local state, id = Storyline(p.ids)
            local q = id and QuestTitle(id)
            local right, c
            if state == "done" then right, c = (q and (q .. " - ") or "") .. "Completed", GREEN
            elseif state == "ready" then right, c = (q and (q .. " - ") or "") .. "Ready to turn in", YELLOW
            elseif state == "active" then right, c = (q and (q .. " - ") or "") .. "In Progress", YELLOW
            else right, c = "Not Accepted", RED end
            GameTooltip:AddDoubleLine(p.name, right, 0.9, 0.9, 0.9, c[1], c[2], c[3])
        end
    end
    return t
end

---------------------------------------------------------------------------
-- tile: Stormarion Assault (fixed schedule)
---------------------------------------------------------------------------
local function StormTile()
    local now = GetServerTime()
    local since = now - STORM.start
    local over = since % STORM.interval
    local running = over < STORM.duration
    local left = running and (STORM.duration - over) or (STORM.interval - over)
    local nextAt = now + (STORM.interval - over)
    local doneWeek = QuestDone(STORM.quest)
    local t = { title = "Stormarion Assault", icon = 7431083, click = OpenMap(STORM.map), help = "Click to show location" }
    t.timer = Clock(left)
    if running then
        t.sub, t.subColor = "In Progress", GREEN
        t.progress, t.barColor = over / STORM.duration, GREEN
    else
        t.sub, t.subColor = MapName(STORM.map) or "Soon", GREY
        t.progress, t.barColor = 1 - left / STORM.interval, GREY
    end
    t.tooltip = function()
        GameTooltip:AddDoubleLine("Location:", MapName(STORM.map) or "", 1, 1, 1, 1, 0.82, 0.2)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Every:", Clock(STORM.interval), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Lasts:", Clock(STORM.duration), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Next start:", date("%H:%M", nextAt), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Status:", running and "In Progress" or "Waiting", 1, 1, 1, running and 0.35 or 0.75, running and 1 or 0.75, running and 0.45 or 0.75)
        GameTooltip:AddDoubleLine("Weekly reward:", doneWeek and "Collected" or "Not collected", 1, 1, 1, doneWeek and 0.35 or 1, doneWeek and 1 or 0.45, doneWeek and 0.45 or 0.45)
    end
    return t
end

---------------------------------------------------------------------------
-- tile: Cursed Surges (the game's event schedule)
---------------------------------------------------------------------------
local surge = { scanned = 0 }

local function SurgeName(poiID)
    if poiID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
        local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, nil, poiID)
        if not (ok and type(info) == "table") then ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, SURGE_MAP, poiID) end
        if ok and type(info) == "table" then
            local name = Plain(info.name)
            if type(name) == "string" and name ~= "" then return name end
        end
    end
    if poiID and C_EventScheduler and C_EventScheduler.GetEventZoneName then
        local ok, name = pcall(C_EventScheduler.GetEventZoneName, poiID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return "Cursed Surges"
end

local function SurgeScan(now)
    surge.scanned = now
    surge.active, surge.nextEv = nil, nil
    local ES = C_EventScheduler
    if not ES then return end
    if ES.HasData then
        local ok, has = pcall(ES.HasData)
        if ok and not has then
            if ES.RequestEvents and (not surge.requested or now - surge.requested >= 5) then
                surge.requested = now
                pcall(ES.RequestEvents)
            end
            surge.scanned = now - 25 -- look again in 5 seconds
            return
        end
    end
    if ES.GetScheduledEvents then
        local ok, list = pcall(ES.GetScheduledEvents)
        if ok and type(list) == "table" then
            for _, e in ipairs(list) do
                local id = e and e.areaPoiID
                if id and SURGE.pois[id] then
                    local st, et = Plain(e.startTime), Plain(e.endTime)
                    if type(st) == "number" then
                        if st <= now and type(et) == "number" then
                            local stop = math.min(et, st + SURGE.duration)
                            if now < stop and (not surge.active or st > surge.active.start) then
                                surge.active = { poi = id, start = st, stop = stop }
                            end
                        elseif st > now and (not surge.nextEv or st < surge.nextEv.start) then
                            surge.nextEv = { poi = id, start = st }
                        end
                    end
                end
            end
        end
    end
    if not surge.active and ES.GetOngoingEvents then
        local ok, list = pcall(ES.GetOngoingEvents)
        if ok and type(list) == "table" then
            for _, e in ipairs(list) do
                local id = e and e.areaPoiID
                if id and SURGE.pois[id] then
                    surge.active = { poi = id, start = now, stop = now + SURGE.duration }
                    break
                end
            end
        end
    end
end

local function SurgeTile()
    local now = GetServerTime()
    local boundary = surge.active and surge.active.stop or (surge.nextEv and surge.nextEv.start)
    if now - surge.scanned >= 30 or (boundary and now >= boundary) then SurgeScan(now) end
    local t = { title = "Cursed Surges", icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", help = "Click to set a map pin" }
    local ev = surge.active or surge.nextEv
    t.click = function()
        local e = surge.active or surge.nextEv
        local pos = e and SURGE.pois[e.poi]
        if not pos then OpenMap(SURGE_MAP)() return end
        if C_Map.OpenWorldMap then pcall(C_Map.OpenWorldMap, SURGE_MAP) end
        if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(SURGE_MAP) and UiMapPoint then
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(SURGE_MAP, pos[1], pos[2]))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_Timer.After(0.1, function() C_SuperTrack.SetSuperTrackedUserWaypoint(true) end) end
        end
    end
    if surge.active then
        local left = surge.active.stop - now
        t.timer = Clock(left)
        t.sub, t.subColor = SurgeName(surge.active.poi), PURPLE
        t.progress, t.barColor = 1 - left / SURGE.duration, PURPLE
    elseif surge.nextEv then
        local left = surge.nextEv.start - now
        t.timer = Clock(left)
        t.sub, t.subColor = SurgeName(surge.nextEv.poi), GREY
        t.progress, t.barColor = 1 - left / SURGE.interval, GREY
    else
        t.sub, t.subColor = "No data yet", GREY
    end
    t.tooltip = function()
        GameTooltip:AddDoubleLine("Location:", MapName(SURGE_MAP) or "", 1, 1, 1, 1, 0.82, 0.2)
        GameTooltip:AddLine(" ")
        if surge.active then
            GameTooltip:AddDoubleLine("Now:", SurgeName(surge.active.poi), 1, 1, 1, PURPLE[1], PURPLE[2], PURPLE[3])
            GameTooltip:AddDoubleLine("Time left:", Clock(surge.active.stop - now), 1, 1, 1, 1, 1, 1)
        end
        if surge.nextEv then
            GameTooltip:AddDoubleLine("Next:", SurgeName(surge.nextEv.poi), 1, 1, 1, 0.9, 0.9, 0.9)
            GameTooltip:AddDoubleLine("Starts:", date("%H:%M", surge.nextEv.start), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Every:", Clock(SURGE.interval), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Lasts:", Clock(SURGE.duration), 1, 1, 1, 1, 1, 1)
    end
    return t
end

---------------------------------------------------------------------------
-- tile: Great Vault
---------------------------------------------------------------------------
local VAULT = {
    { name = "Raid",    type = "Raid",       fallback = 3 },
    { name = "Mythic+", type = "Activities", fallback = 1 },
    { name = "World",   type = "World",      fallback = 6 },
}

local function VaultRow(v)
    if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then return nil end
    local enumType = _G.Enum and _G.Enum.WeeklyRewardChestThresholdType
    local ok, list = pcall(C_WeeklyRewards.GetActivities, enumType and enumType[v.type] or v.fallback)
    if not ok or type(list) ~= "table" or #list == 0 then return nil end
    local done = 0
    for _, a in ipairs(list) do
        if a.threshold and a.progress and a.progress >= a.threshold then done = done + 1 end
    end
    return done, #list, list
end

local function VaultTile()
    local t = { title = "Great Vault", icon = "Interface\\Icons\\INV_Misc_Treasurechest03a" }
    local parts, unlocked, slots = {}, 0, 0
    for _, v in ipairs(VAULT) do
        local d, n = VaultRow(v)
        if d then unlocked, slots = unlocked + d, slots + n; parts[#parts + 1] = d .. "/" .. n end
    end
    if slots == 0 then
        t.sub, t.subColor = "No data yet", GREY
    else
        t.sub = table.concat(parts, "  ")
        t.subColor = unlocked >= slots and GREEN or (unlocked > 0 and YELLOW or RED)
    end
    t.tooltip = function()
        for _, v in ipairs(VAULT) do
            local d, n, list = VaultRow(v)
            if d then
                GameTooltip:AddDoubleLine(v.name, d .. " / " .. n .. " slots", 1, 1, 1, d >= n and 0.35 or 1, d >= n and 1 or 0.82, d >= n and 0.45 or 0.2)
                for i, a in ipairs(list) do
                    local ok = a.progress and a.threshold and a.progress >= a.threshold
                    GameTooltip:AddDoubleLine("   Slot " .. i, math.min(a.progress or 0, a.threshold or 0) .. " / " .. (a.threshold or 0), 0.7, 0.7, 0.7, ok and 0.35 or 0.8, ok and 1 or 0.8, ok and 0.45 or 0.8)
                end
            end
        end
    end
    return t
end

function W.Tiles()
    local s = Settings()
    local tiles = {}
    local function Add(fn) local ok, t = pcall(fn); if ok and t then tiles[#tiles + 1] = t end end
    Add(WeeklyTile)
    Add(ProfessionTile)
    Add(StormTile)
    Add(SurgeTile)
    if s and s.showVault then Add(VaultTile) end
    return tiles
end

---------------------------------------------------------------------------
-- the bar
---------------------------------------------------------------------------
local bar
local tileFrames = {}

local function TileEnter(self)
    local d = self.data
    if not d then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(d.title, 1, 1, 1)
    GameTooltip:AddLine(" ")
    if d.tooltip then pcall(d.tooltip) end
    if d.help then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(d.help, 0.55, 0.8, 1)
    end
    GameTooltip:Show()
end

local function GetTile(i)
    local f = tileFrames[i]
    if f then return f end
    f = CreateFrame("Button", nil, bar)
    f:SetFrameLevel((bar:GetFrameLevel() or 400) + 2)
    f:SetHeight(BAR_H - 8)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(1, 1, 1, 0.05)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(26, 26)
    f.icon:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 6, 1)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    f.sub = f:CreateFontString(nil, "OVERLAY")
    f.sub:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    f.sub:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 6, 0)
    f.sub:SetJustifyH("LEFT")
    f.sub:SetWordWrap(false)
    f.timer = f:CreateFontString(nil, "OVERLAY")
    f.timer:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    f.timer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -3)
    f.timer:SetJustifyH("RIGHT")
    f.track = f:CreateTexture(nil, "ARTWORK")
    f.track:SetColorTexture(1, 1, 1, 0.12)
    f.track:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.track:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.track:SetHeight(2)
    f.fill = f:CreateTexture(nil, "OVERLAY")
    f.fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.fill:SetHeight(2)
    f:SetScript("OnEnter", TileEnter)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnClick", function(self) if self.data and self.data.click then pcall(self.data.click) end end)
    tileFrames[i] = f
    return f
end

local function BuildBar()
    if bar then return bar end
    local map = _G.WorldMapFrame
    if not map then return nil end
    local f = CreateFrame("Frame", "H3z0UI_EventBar", map)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(400)
    f:SetHeight(BAR_H)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.03, 0.03, 0.05, 0.85)
    f.line = f:CreateTexture(nil, "BORDER")
    f.line:SetColorTexture(1, 0.82, 0.2, 0.5)
    f.line:SetPoint("TOPLEFT", f, "TOPLEFT")
    f.line:SetPoint("TOPRIGHT", f, "TOPRIGHT")
    f.line:SetHeight(1)
    f:Hide()
    bar = f
    return f
end

function W.Refresh()
    local s = Settings()
    if not s then return end
    local map = _G.WorldMapFrame
    if not (s.enabled and map and map:IsShown()) then
        if bar then bar:Hide() end
        return
    end
    local f = BuildBar()
    if not f then return end
    f:ClearAllPoints()
    -- below the map window, as wide as the map picture
    local sc = map.ScrollContainer
    local sl, ml, sw = sc and sc.GetLeft and sc:GetLeft(), map.GetLeft and map:GetLeft(), sc and sc.GetWidth and sc:GetWidth()
    if sl and ml and sw and sw > 100 then
        f:SetPoint("TOPLEFT", map, "BOTTOMLEFT", sl - ml, -4)
        f:SetWidth(sw)
    else
        f:SetPoint("TOPLEFT", map, "BOTTOMLEFT", 6, -4)
        f:SetPoint("TOPRIGHT", map, "BOTTOMRIGHT", -6, -4)
    end

    local tiles = W.Tiles()
    local n = #tiles
    local width = (f:GetWidth() or 0)
    if width < 100 then width = 700 end
    local each = (width - PAD * 2 - GAP * (n - 1)) / math.max(n, 1)
    for i, d in ipairs(tiles) do
        local t = GetTile(i)
        t.data = d
        t:ClearAllPoints()
        t:SetPoint("LEFT", f, "LEFT", PAD + (i - 1) * (each + GAP), -1)
        t:SetWidth(each)
        pcall(t.icon.SetTexture, t.icon, d.icon or 134400)
        t.title:SetText(d.title)
        t.title:SetTextColor(1, 1, 1, 1)
        t.title:SetWidth(each - 26 - 14 - (d.timer and 48 or 0))
        t.sub:SetText(d.sub or "")
        local c = d.subColor or GREY
        t.sub:SetTextColor(c[1], c[2], c[3], 1)
        t.sub:SetWidth(each - 26 - 14)
        t.timer:SetText(d.timer or "")
        t.timer:SetTextColor(1, 1, 1, 1)
        if d.progress then
            local bc = d.barColor or GREY
            t.fill:SetColorTexture(bc[1], bc[2], bc[3], 0.95)
            t.fill:SetWidth(math.max(1, each * math.min(1, math.max(0, d.progress))))
            t.fill:Show()
            t.track:Show()
        else
            t.fill:Hide()
            t.track:Hide()
        end
        t:Show()
    end
    for i = n + 1, #tileFrames do tileFrames[i]:Hide() end
    f:Show()
end

_G.H3z0UI_RefreshWeeklies = function() W.Refresh() end

---------------------------------------------------------------------------
-- events: the timers tick every half second while the map is open
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local pending
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        pcall(W.Refresh)
    end)
end
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("QUEST_REMOVED")
ev:RegisterEvent("SKILL_LINES_CHANGED")
pcall(ev.RegisterEvent, ev, "WEEKLY_REWARDS_UPDATE")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Settings()
        local map = _G.WorldMapFrame
        if map then
            map:HookScript("OnShow", Soon)
            map:HookScript("OnHide", function() if bar then bar:Hide() end end)
            local acc = 0
            map:HookScript("OnUpdate", function(_, elapsed)
                acc = acc + elapsed
                if acc >= 0.5 then
                    acc = 0
                    if bar and bar:IsShown() then pcall(W.Refresh) end
                end
            end)
        end
        if C_WeeklyRewards and C_WeeklyRewards.OnUIInteract then pcall(C_WeeklyRewards.OnUIInteract) end
        if C_EventScheduler and C_EventScheduler.RequestEvents then pcall(C_EventScheduler.RequestEvents) end
    elseif _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then
        Soon()
    end
end)
