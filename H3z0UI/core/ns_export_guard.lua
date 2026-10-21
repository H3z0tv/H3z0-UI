local _, ns = ...

local SHARED_NS_KEYS = {
    CDMRuntimeEventTraceHook = true,
    H3z0UI                      = true,
    H3z0UI_Options              = true,
    H3z0UI_PerfRegistry         = true,
    SkinBase                 = true,
    _inInitSafeWindow        = true,
    _memprobes               = true,
}

local exportOwners = {}
local warnedKeys = {}

local collisionLog = {}
ns._NsExportCollisionLog = collisionLog

function ns._TrackSuiteNsExport(addonName, key, value)
    local existing = ns[key]
    if existing == nil then
        if exportOwners[key] == nil then
            exportOwners[key] = addonName
        end
        return
    end
    if existing == value then return end

    local owner = exportOwners[key] or "H3z0UI"
    if owner == addonName or SHARED_NS_KEYS[key] then return end

    collisionLog[#collisionLog + 1] = {
        key = key,
        owner = owner,
        overwrittenBy = addonName,
    }
    if not warnedKeys[key] then
        warnedKeys[key] = true
        print(("|cFFFF6666H3z0UI:|r namespace export '%s' from %s was overwritten by %s — cross-suite state may be broken. Please report this."):format(
            tostring(key), tostring(owner), tostring(addonName)))
    end
end
