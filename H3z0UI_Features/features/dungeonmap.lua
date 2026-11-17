---------------------------------------------------------------------------
-- H3z0 UI - Dungeon Map
-- Inside a dungeon the map window can stay on "World". This opens it on the dungeon you are in
-- when you open the map (M). Switch it off on the H3z0 Features page, Extras tab.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

if not (C_Map and C_Map.GetMapInfo and C_Map.GetBestMapForUnit) then return end

local DEFAULTS = { enabled = true }
local function S()
    local s = Helpers and Helpers.GetModuleSettings and Helpers.GetModuleSettings("dungeonMap", DEFAULTS)
    return s or DEFAULTS
end
_G.H3z0UI_DungeonMapSettings = S

local function IsSecret(v)
    return issecretvalue ~= nil and v ~= nil and issecretvalue(v) or false
end

-- dungeon name (lower case) -> map id, built once from the game's own map list
local byName
local function Index()
    if byName then return byName end
    byName = {}
    local dungeonType = (Enum and Enum.UIMapType and Enum.UIMapType.Dungeon) or 4
    for id = 1, 3500 do
        local info = C_Map.GetMapInfo(id)
        if info and info.mapType == dungeonType and type(info.name) == "string" then
            local key = info.name:lower()
            if not byName[key] then byName[key] = id end
        end
    end
    return byName
end

-- This client has no map of its own for dungeon interiors, so the map opens on the zone that
-- holds the dungeon entrance. instance id -> map id of that zone
local ENTRANCE = {
    [389]=1454, [36]=1436, [43]=1413, [33]=1421, [34]=1453, [48]=1440, [90]=1426, [47]=1413,
    [189]=1420, [129]=1413, [70]=1418, [209]=1446, [349]=1443, [109]=1435, [230]=1427, [229]=1428,
    [429]=1444, [289]=1422, [329]=1423, [249]=1445, [409]=1427, [469]=1428, [309]=1434,
    [509]=1451, [531]=1451, [533]=1423, [532]=1430,
}

local function Resolve()
    local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    if IsSecret(name) then name = nil end
    local byInstance
    if type(name) == "string" then byInstance = Index()[name:lower()] end
    local best = C_Map.GetBestMapForUnit("player")
    if IsSecret(best) then best = nil end
    local entrance = (not IsSecret(instanceID)) and ENTRANCE[instanceID] or nil
    return byInstance or best or entrance, name, best, byInstance, entrance
end

local function Apply()
    if not S().enabled then return end
    local frame = _G.WorldMapFrame
    if not (frame and frame.SetMapID and frame.GetMapID and frame:IsShown()) then return end
    if not (IsInInstance and IsInInstance()) then return end
    local target = Resolve()
    if target and target ~= frame:GetMapID() then pcall(frame.SetMapID, frame, target) end
end

local function OpenDungeonMap()
    Apply()
    -- the game moves the map itself right after it opens, so check again a little later
    C_Timer.After(0.2, Apply)
    C_Timer.After(0.6, Apply)
end

-- /h3z0 dungeonmap : prints what the game knows about the dungeon you are in
_G.H3z0UI_DungeonMapCheck = function()
    local frame = _G.WorldMapFrame
    local target, name, best, byInstance, entrance = Resolve()
    local function P(t) print("|cffe6c200H3z0 UI|r Dungeon Map: " .. t) end
    P("in instance: " .. tostring(IsInInstance and IsInInstance()))
    P("instance name: " .. tostring(name))
    P("map for player: " .. tostring(best))
    P("dungeon map found by name: " .. tostring(byInstance))
    P("map window shows: " .. tostring(frame and frame.GetMapID and frame:GetMapID()))
    P("entrance zone: " .. tostring(entrance))
    P("will open: " .. tostring(target))
    local info = target and C_Map.GetMapInfo(target)
    P("that map: " .. tostring(info and info.name) .. " (type " .. tostring(info and info.mapType) .. ")")
end

local hooked = false
local function Hook()
    if hooked then return end
    local frame = _G.WorldMapFrame
    if not (frame and frame.HookScript) then return end
    hooked = true
    frame:HookScript("OnShow", function() OpenDungeonMap() end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function() Hook() end)
Hook()
