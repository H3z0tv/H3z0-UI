local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Minimap & Datatext page: the H3z0 UI minimap (square map, clock, zone
-- text, coordinates, datatext panel under the map) and the datatext panels
---------------------------------------------------------------------------
local V2Minimap = {}
ns.H3z0UI_MinimapTile = V2Minimap

local function Build(fn)
    return function(body)
        if type(fn) ~= "function" then return end
        local ok, err = pcall(fn, body)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end

function V2Minimap.Register(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    local M = ns.H3z0UI_MinimapOptions
    if not (GUI and GUI.AddFeatureTile and M) then return end
    local ok, err = pcall(GUI.AddFeatureTile, GUI, frame, {
        id = "minimap",
        name = ns.L["Minimap & Datatext"],
        subtitle = "Minimap · Datatext",
        subPages = {
            { id = "minimap", name = ns.L["Minimap"], buildFunc = Build(M.BuildMinimapTab) },
            { id = "datatext", name = ns.L["Datatext"], buildFunc = Build(M.BuildDatatextTab) },
        },
    })
    if not ok and geterrorhandler then geterrorhandler()(err) end
end
