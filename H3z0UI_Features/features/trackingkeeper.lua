---------------------------------------------------------------------------
-- H3z0 UI - Tracking Keeper
-- The tracking menu on the minimap (Auctioneer, Banker, Flight Master, Find
-- Herbs, ...) can come back reset after a login or a loading screen. This
-- remembers what you tick and untick there, per character, and puts it back
-- whenever the game resets it. Nothing is changed until you have used the
-- menu once.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local applying = false
local pending = false
local applyTimes = {}

local function Store()
    local core = Helpers and Helpers.GetCore and Helpers.GetCore()
    local char = core and core.db and core.db.char
    if not char then return nil end
    char.trackingKeeper = char.trackingKeeper or {}
    return char.trackingKeeper
end

local function NumTypes()
    if C_Minimap and C_Minimap.GetNumTrackingTypes then return C_Minimap.GetNumTrackingTypes() or 0 end
    if GetNumTrackingTypes then return GetNumTrackingTypes() or 0 end
    return 0
end

local function Info(i)
    if C_Minimap and C_Minimap.GetTrackingInfo then
        local t = C_Minimap.GetTrackingInfo(i)
        if type(t) == "table" then return t.name, t.active and true or false end
    end
    if GetTrackingInfo then
        local name, _, active = GetTrackingInfo(i)
        return name, active and true or false
    end
end

local function Set(i, on)
    if C_Minimap and C_Minimap.SetTracking then
        C_Minimap.SetTracking(i, on)
    elseif SetTracking then
        SetTracking(i, on)
    end
end

local function Differs(saved)
    for i = 1, NumTypes() do
        local name, active = Info(i)
        if name and type(saved[name]) == "boolean" and saved[name] ~= active then return true end
    end
    return false
end

local function Apply()
    pending = false
    local saved = Store()
    if not saved or next(saved) == nil then return end
    -- never fight the game: at most 6 corrections a minute
    local now = GetTime()
    for i = #applyTimes, 1, -1 do
        if now - applyTimes[i] > 60 then table.remove(applyTimes, i) end
    end
    if #applyTimes >= 6 then return end
    if not Differs(saved) then return end
    applyTimes[#applyTimes + 1] = now
    applying = true
    for i = 1, NumTypes() do
        local name, active = Info(i)
        if name and type(saved[name]) == "boolean" and saved[name] ~= active then
            pcall(Set, i, saved[name])
        end
    end
    applying = false
end

local function Schedule(delay)
    if pending then return end
    pending = true
    C_Timer.After(delay or 0.5, Apply)
end

-- what you tick / untick in the menu
local function Record(index, on)
    if applying then return end
    local saved = Store()
    if not saved then return end
    local name = Info(index)
    if not name then return end
    saved[name] = on and true or false
end

if C_Minimap and C_Minimap.SetTracking then hooksecurefunc(C_Minimap, "SetTracking", Record) end
if type(_G.SetTracking) == "function" then hooksecurefunc("SetTracking", Record) end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("MINIMAP_UPDATE_TRACKING")
f:SetScript("OnEvent", function(_, event)
    if applying then return end
    if event == "PLAYER_ENTERING_WORLD" then
        Schedule(2)
        C_Timer.After(6, function() Schedule(0) end)
    else
        local saved = Store()
        if saved and next(saved) ~= nil and Differs(saved) then Schedule(0.6) end
    end
end)
