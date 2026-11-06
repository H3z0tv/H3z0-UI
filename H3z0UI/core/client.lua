local _, ns = ...
local version, build, _, interfaceVersion = GetBuildInfo()
local isForever = type(version) == "string" and version:match("^1%.60%.") ~= nil
-- Classic games: Classic Era / Anniversary (1.x) and TBC Anniversary (2.x)
local isVanilla = not isForever and type(version) == "string" and version:match("^1%.") ~= nil
local isTBC = type(version) == "string" and version:match("^2%.") ~= nil
local isClassic = isVanilla or isTBC

ns.Client = {
    isForever = isForever,
    isClassic = isClassic,
    isVanilla = isVanilla,
    isTBC = isTBC,
    isRetail = not isForever and not isClassic,
    -- old-style game rules (two spec groups instead of specializations, Spellbook /
    -- Talent micro buttons, Stable / Legacy frames): WoW: Forever and the Classic games
    isLegacy = isForever or isClassic,
    -- retail-only systems the Classic games don't have
    hasAuraContainers = not isClassic,      -- "AuraContainer" frames (H3z0 buff / debuff icons)
    hasSkyriding = not isClassic,
    -- the player's own bags are 0 .. LAST_BAG (retail: + the reagent bag 5;
    -- in the Classic games bag 5 is the first bank bag)
    LAST_BAG = isClassic and (tonumber(NUM_BAG_SLOTS) or 4) or 5,
    restrictedExecutionUnavailable = false,
    flavor = isForever and "forever" or (isVanilla and "vanilla") or (isTBC and "tbc") or "retail",
    version = version,
    build = build,
    interfaceVersion = interfaceVersion,
    -- the addon's name as shown in game ("H3z0 UI Forever" on WoW: Forever)
    displayName = isForever and "H3z0 UI Forever" or (isClassic and "H3z0 UI Classic") or "H3z0 UI",
    -- interface number to use for "is this the 12.x API?" checks
    apiVersion = isForever and 120105 or (tonumber(interfaceVersion) or 0),
}

-- Register an event only when this game has it (the Classic games don't know
-- every retail event, and registering an unknown event is an error there).
local function EventExists(event)
    local EU = C_EventUtils
    if EU and EU.IsEventValid then
        local ok, valid = pcall(EU.IsEventValid, event)
        if ok and valid == false then return false end
    end
    return true
end
ns.Client.EventExists = EventExists
_G.H3z0UI_EventExists = EventExists
-- Does this game know an XML template? (some retail templates are missing in the Classic games)
local templateCache = {}
local function TemplateExists(name)
    if type(name) ~= "string" then return false end
    local known = templateCache[name]
    if known ~= nil then return known end
    local XU = C_XMLUtil
    if XU and XU.GetTemplateInfo then
        local ok, info = pcall(XU.GetTemplateInfo, name)
        known = (ok and info ~= nil) and true or false
    else
        known = not isClassic
    end
    templateCache[name] = known
    return known
end
ns.Client.TemplateExists = TemplateExists
_G.H3z0UI_TemplateExists = TemplateExists
_G.H3z0UI_SafeRegisterEvent = function(frame, event, ...)
    if not (frame and event) or not EventExists(event) then return false end
    if select("#", ...) > 0 and frame.RegisterUnitEvent then
        return pcall(frame.RegisterUnitEvent, frame, event, ...)
    end
    return pcall(frame.RegisterEvent, frame, event)
end

---------------------------------------------------------------------------
-- Specialization API compatibility.
-- WoW: Forever removed some of the old global spec functions; the
-- C_SpecializationInfo versions (or a safe fallback) are used instead.
-- Modules alias these at the top of the file; nothing global is replaced.
---------------------------------------------------------------------------
local CSI = C_SpecializationInfo or {}

local function PlayerClassID()
    local _, _, classID = UnitClass("player")
    return classID
end

local Compat = {}
ns.Compat = Compat

Compat.GetSpecialization = _G.GetSpecialization or CSI.GetSpecialization or function() return 1 end

Compat.GetSpecializationInfo = _G.GetSpecializationInfo or CSI.GetSpecializationInfo or function(index)
    local classID = PlayerClassID()
    local byClass = _G.GetSpecializationInfoForClassID or CSI.GetSpecializationInfoForClassID
    if classID and byClass then return byClass(classID, index or 1) end
    return nil
end

Compat.GetNumSpecializations = _G.GetNumSpecializations or function()
    local classID = PlayerClassID()
    local count = _G.GetNumSpecializationsForClassID or CSI.GetNumSpecializationsForClassID
    if classID and count then
        local ok, n = pcall(count, classID)
        if ok and type(n) == "number" and n > 0 then return n end
    end
    return 1
end

Compat.GetSpecializationInfoByID = _G.GetSpecializationInfoByID or CSI.GetSpecializationInfoByID or function(specID)
    return specID, nil
end

Compat.GetSpecializationRole = _G.GetSpecializationRole or CSI.GetSpecializationRole or function()
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if role and role ~= "NONE" then return role end
    return "DAMAGER"
end
