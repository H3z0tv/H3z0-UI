local _, ns = ...

-- Which client are we on? Midnight (retail 12.x) or WoW: Forever (1.60.x).
-- Forever runs on the Midnight client code, so it uses the 12.x APIs.
local version, build, _, interfaceVersion = GetBuildInfo()
local isForever = type(version) == "string" and version:match("^1%.60%.") ~= nil

ns.Client = {
    isForever = isForever,
    flavor = isForever and "forever" or "midnight",
    version = version,
    build = build,
    interfaceVersion = interfaceVersion,
    -- interface number to use for "is this the 12.x API?" checks
    apiVersion = isForever and 120105 or (tonumber(interfaceVersion) or 0),
}

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
