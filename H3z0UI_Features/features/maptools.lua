local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI Map Tools
--  * /way: map pins from chat (every game). "/way 45.2 62.1 Mailbox",
--    "/way Elwynn Forest 42 65 Inn", "/way #1453 60 70". Prints a link per
--    place; clicking it puts the game's own map pin there. You get a message
--    when you arrive. "/way clear" forgets the list.
--  * WoW: Forever: unexplored parts of the world map are drawn (tinted),
--    and hovering a zone on a continent map shows its level range and the
--    fishing skill it needs.
-- Settings: profile.h3zMapTools.
---------------------------------------------------------------------------

local MT = {}
ns.H3z0MapTools = MT

local PREFIX = "|cFF30D1FFH3z0 UI:|r "
local function Say(msg) print(PREFIX .. msg) end

local DEFAULTS = {
    waypoints = true,
    reveal = true,
    revealColor = { 0.6, 0.6, 0.6, 1 },
    zoneLevels = true,
    fishing = true,
}

function MT.Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.h3zMapTools = p.h3zMapTools or {}
    local s = p.h3zMapTools
    for k, v in pairs(DEFAULTS) do
        if s[k] == nil then s[k] = type(v) == "table" and { v[1], v[2], v[3], v[4] } or v end
    end
    return s
end

local function WhenWorldMapLoaded(fn)
    if C_AddOns.IsAddOnLoaded("Blizzard_WorldMap") and _G.WorldMapFrame then fn() return end
    local w = CreateFrame("Frame")
    w:RegisterEvent("ADDON_LOADED")
    w:SetScript("OnEvent", function(self, _, name)
        if name == "Blizzard_WorldMap" then
            self:UnregisterAllEvents()
            fn()
        end
    end)
end

---------------------------------------------------------------------------
-- /way
---------------------------------------------------------------------------
local places = {}          -- { mapID, x, y (0-1), label }
local ticker
local zoneIndex            -- lower-case map name -> uiMapID

local function RootMap()
    local id = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while id and guard < 10 do
        local info = C_Map.GetMapInfo(id)
        if not info or not info.parentMapID or info.parentMapID == 0 then return id end
        id = info.parentMapID
        guard = guard + 1
    end
    return id
end

local PREFER = {}
local function TypeRank(t)
    local U = Enum and Enum.UIMapType or {}
    if t == U.Zone then return 1 elseif t == U.City then return 2
    elseif t == U.Continent then return 3 elseif t == U.Dungeon then return 5 end
    return 4
end

local function BuildZoneIndex()
    zoneIndex = {}
    local root = RootMap()
    if not (root and C_Map.GetMapChildrenInfo) then return end
    local list = C_Map.GetMapChildrenInfo(root, nil, true) or {}
    for _, info in ipairs(list) do
        if info.name and info.name ~= "" then
            local key = info.name:lower()
            local old = zoneIndex[key]
            if not old or TypeRank(info.mapType) < TypeRank(PREFER[key] or 99) then
                zoneIndex[key] = info.mapID
                PREFER[key] = info.mapType
            end
        end
    end
end

local function MapName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("#" .. mapID)
end

local function Link(place)
    local text = place.label ~= "" and place.label or string.format("%s %.1f, %.1f", MapName(place.mapID), place.x * 100, place.y * 100)
    return string.format("|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r",
        place.mapID, math.floor(place.x * 10000 + 0.5), math.floor(place.y * 10000 + 0.5), text)
end

local function Distance(a, mapID, px, py)
    if a.mapID ~= mapID then return nil end
    local dx, dy = a.x - px, a.y - py
    return math.sqrt(dx * dx + dy * dy)
end

local function CheckArrival()
    if #places == 0 then
        if ticker then ticker:Cancel(); ticker = nil end
        return
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local px, py = pos:GetXY()
    if not px or (issecretvalue and issecretvalue(px)) then return end
    for i = #places, 1, -1 do
        local d = Distance(places[i], mapID, px, py)
        if d and d < 0.006 then
            Say("you arrived at " .. Link(places[i]) .. ".")
            PlaySound(SOUNDKIT and SOUNDKIT.MAP_PING or 3175)
            table.remove(places, i)
        end
    end
end

local function StartTicker()
    if ticker or #places == 0 then return end
    ticker = C_Timer.NewTicker(1, CheckArrival)
end

-- one destination: "[#mapID | zone name] x y [label]"
local function ParseOne(text)
    text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub(",", " ")
    if text == "" then return nil end
    local mapID
    local id, rest = text:match("^#(%d+)%s+(.+)$")
    if id then
        mapID, text = tonumber(id), rest
    else
        -- a zone name in front of the numbers
        local name, after = text:match("^(.-)%s+(%-?%d+%.?%d*%s+%-?%d+%.?%d*.*)$")
        if name and name ~= "" and not name:match("^%-?%d+%.?%d*$") then
            if not zoneIndex then BuildZoneIndex() end
            mapID = zoneIndex and zoneIndex[name:lower()]
            if not mapID then return nil, "no zone called \"" .. name .. "\"" end
            text = after
        end
    end
    local x, y, label = text:match("^(%-?%d+%.?%d*)%s+(%-?%d+%.?%d*)%s*(.*)$")
    x, y = tonumber(x), tonumber(y)
    if not (x and y) then return nil, "use: /way [zone] x y [text]" end
    if x > 1 or y > 1 then x, y = x / 100, y / 100 end
    if x < 0 or x > 1 or y < 0 or y > 1 then return nil, "the numbers go from 0 to 100" end
    mapID = mapID or C_Map.GetBestMapForUnit("player")
    if type(mapID) ~= "number" then return nil, "your position is not known here" end
    return { mapID = mapID, x = x, y = y, label = label or "" }
end

function MT.Way(msg)
    local s = MT.Settings()
    if s and not s.waypoints then Say("waypoints are switched off (H3z0 Features > Extras).") return end
    msg = msg or ""
    if msg:lower():match("^%s*clear%s*$") or msg:lower():match("^%s*reset%s*$") then
        wipe(places)
        Say("waypoints cleared.")
        return
    end
    if msg:match("^%s*$") then
        if #places == 0 then
            Say("no waypoints. /way [zone] x y [text], several with ; between them.")
        else
            for _, p in ipairs(places) do Say(Link(p)) end
        end
        return
    end
    for part in msg:gmatch("[^;]+") do
        local place, err = ParseOne(part)
        if place then
            places[#places + 1] = place
            Say("click to set the map pin: " .. Link(place))
        elseif err then
            Say(err)
        end
    end
    StartTicker()
end

local function RegisterSlash()
    SLASH_H3Z0UIWAY1 = "/h3way"
    local wayTaken = _G.hash_SlashCmdList and _G.hash_SlashCmdList["/WAY"]
    if not wayTaken then
        for k, v in pairs(_G) do
            if type(k) == "string" and k:match("^SLASH_") and type(v) == "string" and v:lower() == "/way" then
                wayTaken = true
                break
            end
        end
    end
    if not wayTaken then SLASH_H3Z0UIWAY2 = "/way" end
    SlashCmdList.H3Z0UIWAY = MT.Way
end

---------------------------------------------------------------------------
-- WoW: Forever: reveal unexplored areas
---------------------------------------------------------------------------
local reveal = { pool = {}, used = 0 }

local function PowerOfTwo(n)
    local p = 16
    while p < n do p = p * 2 end
    return p
end

local function RevealClear()
    for i = 1, reveal.used do reveal.pool[i]:Hide() end
    reveal.used = 0
end

local function RevealTexture()
    reveal.used = reveal.used + 1
    local t = reveal.pool[reveal.used]
    if not t then
        t = reveal.layer:CreateTexture(nil, "ARTWORK")
        reveal.pool[reveal.used] = t
    end
    return t
end

local function RevealDraw()
    RevealClear()
    local s = MT.Settings()
    if not (s and s.reveal) then return end
    local map = _G.WorldMapFrame
    local data = ns.H3z0MapRevealData
    local mapID = map and map:GetMapID()
    if not (data and mapID) then return end
    local overlays = data[C_Map.GetMapArtID(mapID)]
    if not overlays then return end
    local layers = C_Map.GetMapArtLayers(mapID)
    local art = layers and layers[1]
    if not art then return end
    local tileW, tileH = art.tileWidth, art.tileHeight

    -- what the player has explored already (the game draws those itself)
    local seen = {}
    for _, info in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
        if info.fileDataIDs and info.fileDataIDs[1] then seen[info.fileDataIDs[1]] = true end
    end

    local c = s.revealColor or DEFAULTS.revealColor
    for _, o in ipairs(overlays) do
        local w, h, ox, oy = o[1], o[2], o[3], o[4]
        if not seen[o[5]] then
            local cols, rows = math.ceil(w / tileW), math.ceil(h / tileH)
            local n = 5
            for row = 0, rows - 1 do
                local partH = (row < rows - 1) and tileH or (h - tileH * (rows - 1))
                local fileH = (row < rows - 1) and tileH or PowerOfTwo(partH)
                for col = 0, cols - 1 do
                    local partW = (col < cols - 1) and tileW or (w - tileW * (cols - 1))
                    local fileW = (col < cols - 1) and tileW or PowerOfTwo(partW)
                    local file = o[n]
                    n = n + 1
                    if file then
                        local t = RevealTexture()
                        t:SetTexture(file, nil, nil, "TRILINEAR")
                        t:SetTexCoord(0, partW / fileW, 0, partH / fileH)
                        t:SetSize(partW, partH)
                        t:ClearAllPoints()
                        t:SetPoint("TOPLEFT", reveal.layer, "TOPLEFT", ox + tileW * col, -(oy + tileH * row))
                        t:SetVertexColor(c[1] or 0.6, c[2] or 0.6, c[3] or 0.6, c[4] or 1)
                        t:Show()
                    end
                end
            end
        end
    end
end

local function RevealSetup()
    local map = _G.WorldMapFrame
    if reveal.provider or not (map and map.AddDataProvider and _G.MapCanvasDataProviderMixin) then return end
    reveal.layer = CreateFrame("Frame", nil, map.ScrollContainer.Child)
    reveal.layer:SetAllPoints()
    local levels = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
    if levels and levels.GetValidFrameLevel then
        reveal.layer:SetFrameLevel(levels:GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_EXPLORATION"))
    end
    reveal.layer:SetScript("OnEvent", RevealDraw)
    local p = CreateFromMixins(MapCanvasDataProviderMixin)
    p.OnMapChanged = RevealDraw
    p.RefreshAllData = RevealDraw
    p.RemoveAllData = RevealClear
    p.OnShow = function() reveal.layer:RegisterEvent("MAP_EXPLORATION_UPDATED") end
    p.OnHide = function() reveal.layer:UnregisterEvent("MAP_EXPLORATION_UPDATED") end
    p.OnGlobalAlphaChanged = function(self) reveal.layer:SetAlpha(self:GetMap():GetGlobalAlpha()) end
    map:AddDataProvider(p)
    reveal.provider = p
end

---------------------------------------------------------------------------
-- WoW: Forever: zone levels and fishing skill on the world map
---------------------------------------------------------------------------
-- uiMapID = { lowest level, highest level }
local ZONE_LEVELS = {
    -- Eastern Kingdoms
    [1426] = { 1, 10 }, [1429] = { 1, 10 }, [1420] = { 1, 10 },
    [1432] = { 10, 20 }, [1436] = { 10, 20 }, [1421] = { 10, 20 },
    [1433] = { 15, 25 }, [1431] = { 18, 30 }, [1437] = { 20, 30 }, [1424] = { 20, 30 },
    [1416] = { 30, 40 }, [1417] = { 30, 40 }, [1434] = { 30, 45 },
    [1418] = { 35, 45 }, [1435] = { 35, 45 }, [1425] = { 40, 50 }, [1427] = { 43, 50 },
    [1419] = { 45, 55 }, [1428] = { 50, 58 }, [1422] = { 51, 58 }, [1423] = { 53, 60 },
    [1430] = { 55, 60 }, [2548] = { 35, 45 },
    -- Kalimdor
    [1411] = { 1, 10 }, [1412] = { 1, 10 }, [1438] = { 1, 10 },
    [1439] = { 10, 20 }, [1413] = { 10, 25 }, [1442] = { 15, 27 }, [1440] = { 18, 30 },
    [1441] = { 25, 35 }, [1443] = { 30, 40 }, [1445] = { 35, 45 },
    [1444] = { 40, 50 }, [1446] = { 40, 50 }, [1447] = { 45, 55 },
    [1448] = { 48, 55 }, [1449] = { 48, 55 }, [1451] = { 55, 60 }, [1452] = { 55, 60 },
    [2482] = { 55, 60 }, [2652] = { 35, 45 },
    -- elsewhere
    [2521] = { 1, 12 },
}
-- uiMapID = the zone's fishing skill base (fish bite from it, none get away 95 above)
local ZONE_FISHING = {
    [1426] = -70, [1429] = -70, [1420] = -70, [1411] = -70, [1412] = -70, [1438] = -70,
    [1432] = -20, [1436] = -20, [1421] = -20, [1439] = -20, [1413] = -20,
    [1453] = -20, [1455] = -20, [1458] = -20, [1454] = -20, [1456] = -20, [1457] = -20,
    [1433] = 55, [1431] = 55, [1437] = 55, [1424] = 55, [1442] = 55, [1440] = 55,
    [1416] = 130, [1417] = 130, [1434] = 130, [1435] = 130, [1441] = 130, [1443] = 130, [1445] = 130,
    [1425] = 205, [1422] = 205, [1444] = 205, [1446] = 205, [1447] = 205, [1448] = 205, [1449] = 205, [1450] = 205,
    [1423] = 330, [1428] = 330, [1430] = 330, [1451] = 330, [1452] = 330,
}
local GETAWAY = 95

local zl = {}

local function Hex(r, g, b) return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) end

local function LevelLine(range)
    local lo, hi = range[1], range[2]
    local me = UnitLevel("player") or 1
    local c
    if me < lo then c = GetQuestDifficultyColor(lo)
    elseif me > hi then c = GetQuestDifficultyColor(hi - 2)
    else c = QuestDifficultyColors and QuestDifficultyColors.difficult or { r = 1, g = 0.82, b = 0 } end
    return Hex(c.r, c.g, c.b) .. string.format("(%d-%d)", lo, hi) .. "|r"
end

local function FishingLine(base)
    local from = math.max(base, 1)
    local r, g, b = 1, 1, 1
    local _, _, _, fishing = GetProfessions()
    if fishing then
        local _, _, rank, _, _, _, _, bonus = GetProfessionInfo(fishing)
        local skill = (rank or 0) + (bonus or 0)
        if skill < from then r, g, b = 1, 0.3, 0.3
        elseif skill < base + GETAWAY then r, g, b = 1, 0.82, 0
        else r, g, b = 0.3, 1, 0.3 end
    end
    local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(7620)) or "Fishing"
    return Hex(r, g, b) .. name .. " " .. from .. "|r"
end

local function OnAreaName(_, name)
    local s = MT.Settings()
    if not (s and (s.zoneLevels or s.fishing) and zl.levels) then return end
    local zone, onContinent
    if name and name ~= "" then
        local mapID = _G.WorldMapFrame:GetMapID()
        local info = mapID and C_Map.GetMapInfo(mapID)
        local U = Enum and Enum.UIMapType or {}
        if info and info.mapType == U.Continent then
            zone, onContinent = zl.byName[name], true
        elseif info and info.mapType == U.Zone then
            zone = mapID
        end
    end
    local range = s.zoneLevels and onContinent and zone and ZONE_LEVELS[zone]
    local base = s.fishing and zone and ZONE_FISHING[zone]
    zl.levels:SetShown(range and true or false)
    if range then zl.levels:SetText(LevelLine(range)) end
    zl.fishing:SetShown(base and true or false)
    if base then
        zl.fishing:SetText(FishingLine(base))
        zl.fishing:ClearAllPoints()
        zl.fishing:SetPoint("TOP", range and zl.levels or zl.name, "BOTTOM", 0, range and -2 or -6)
    end
end

local function ZoneLevelsSetup()
    local map = _G.WorldMapFrame
    if zl.levels or not map then return end
    local label
    for provider in pairs(map.dataProviders or {}) do
        if provider.Label and provider.Label.Name and provider.Label.labelInfoByType then label = provider.Label break end
    end
    if not label then return end
    zl.name = label.Name
    zl.byName = {}
    for _, list in ipairs({ ZONE_LEVELS, ZONE_FISHING }) do
        for id in pairs(list) do
            local info = C_Map.GetMapInfo(id)
            if info and info.name then zl.byName[info.name] = id end
        end
    end
    local holder = CreateFrame("Frame", nil, map.ScrollContainer)
    holder:SetAllPoints()
    holder:SetFrameStrata("HIGH")
    zl.levels = holder:CreateFontString(nil, "OVERLAY", "SubZoneTextFont")
    zl.fishing = holder:CreateFontString(nil, "OVERLAY", "SubZoneTextFont")
    local font, size, flags = zl.name:GetFont()
    if font and size then
        zl.levels:SetFont(font, math.floor(size * 0.7 + 0.5), flags)
        zl.fishing:SetFont(font, math.max(9, math.floor(size * 0.45 + 0.5)), flags)
    end
    zl.levels:SetPoint("TOP", zl.name, "BOTTOM", 0, -6)
    zl.levels:Hide()
    zl.fishing:Hide()
    hooksecurefunc(zl.name, "SetText", OnAreaName)
end

---------------------------------------------------------------------------
function MT.Apply()
    local s = MT.Settings()
    if not s then return end
    if ns.Client and ns.Client.isForever then
        WhenWorldMapLoaded(function()
            RevealSetup()
            ZoneLevelsSetup()
            if _G.WorldMapFrame:IsShown() then RevealDraw() end
            if not s.reveal then RevealClear() end
            if zl.levels and not (s.zoneLevels or s.fishing) then zl.levels:Hide(); zl.fishing:Hide() end
        end)
    end
end
_G.H3z0UI_RefreshMapTools = MT.Apply

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    RegisterSlash()
    MT.Apply()
end)
