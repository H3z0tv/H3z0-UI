local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Other bag addons (Baganator, Bagnon, AdiBags, ...)
-- While H3z0 UI Bags is on, other bag addons are turned off (after a reload)
-- so only one set of bags opens. Turning H3z0 UI Bags off turns the ones it
-- switched off back on. Which ones were switched off is kept in
-- H3z0UIDB.global.h3zBagsTurnedOff.
---------------------------------------------------------------------------

local OTHER_BAGS = {
    "Baganator", "Bagnon", "AdiBags", "ArkInventory", "BetterBags", "Combuctor",
    "Inventorian", "Sorted", "OneBag3", "OneBank3", "LiteBag", "BaudBag", "Bagshui",
    "cargBags_Nivaya", "DJBags",
}

local function Api(name)
    return (C_AddOns and C_AddOns[name]) or _G[name]
end

local function Exists(name)
    local fn = Api("DoesAddOnExist")
    if fn then return fn(name) == true end
    local info = Api("GetAddOnInfo")
    return info and info(name) ~= nil or false
end

local function IsOn(name)
    local fn = Api("GetAddOnEnableState")
    if not fn then return false end
    local ok, state = pcall(fn, name, UnitName and UnitName("player"))
    if not ok then ok, state = pcall(fn, name) end
    return ok and (tonumber(state) or 0) > 0
end

local function IsLoaded(name)
    local fn = Api("IsAddOnLoaded")
    return fn and fn(name) == true or false
end

local function H3zBagsOn()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if p and p.bags and p.bags.enabled == false then return false end
    return IsOn("H3z0UI_Bags")
end

local function Record()
    local core = ns.Addon
    local g = core and core.db and core.db.global
    if not g then return nil end
    if type(g.h3zBagsTurnedOff) ~= "table" then g.h3zBagsTurnedOff = {} end
    return g.h3zBagsTurnedOff
end

-- H3z0 UI's own popup (never Blizzard's StaticPopup: writing to it from an
-- addon makes Blizzard's own popups blocked, e.g. "RemoveListing()")
local POPUP = {
    text = "%s",
    button1 = "Reload now",
    button2 = "Later",
    OnAccept = function() ReloadUI() end,
}

local function Ask(text)
    if ns.ShowPopup then ns.ShowPopup(POPUP, text) end
end

local function Check()
    local rec = Record()
    if not rec then return end
    local disable, enable = Api("DisableAddOn"), Api("EnableAddOn")

    if H3zBagsOn() then
        local loadedNow = {}
        for _, name in ipairs(OTHER_BAGS) do
            if Exists(name) and IsOn(name) and disable then
                pcall(disable, name)
                rec[name] = true
                if IsLoaded(name) then loadedNow[#loadedNow + 1] = name end
            end
        end
        if #loadedNow > 0 then
            Ask("H3z0 UI Bags is on, so " .. table.concat(loadedNow, ", ")
                .. (#loadedNow > 1 and " are" or " is") .. " turned off and only H3z0 UI Bags will open.\n\nIt comes back when you turn H3z0 UI Bags off.\n\nReload now?")
        end
    else
        local back = {}
        for name in pairs(rec) do
            if Exists(name) and enable then
                pcall(enable, name)
                back[#back + 1] = name
            end
            rec[name] = nil
        end
        if #back > 0 then
            table.sort(back)
            Ask("H3z0 UI Bags is off, so " .. table.concat(back, ", ")
                .. (#back > 1 and " are" or " is") .. " turned back on.\n\nReload now to use it?")
        end
    end
end
ns.H3z0BagConflicts = { Check = Check, List = OTHER_BAGS }

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(4, function() pcall(Check) end)
end)
