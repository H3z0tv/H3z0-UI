local ADDON_NAME, ns = ...

local mainNS = type(H3z0UI) == "table" and H3z0UI._ns
if type(mainNS) ~= "table" then
    error(("%s requires the H3z0UI core addon to load first"):format(ADDON_NAME), 0)
end

setmetatable(ns, {
    __index = mainNS,
    __newindex = function(_, key, value)
        local track = mainNS._TrackSuiteNsExport
        if track then track(ADDON_NAME, key, value) end
        mainNS[key] = value
    end,
})
