local ADDON_NAME, ns = ...
local H3z0UICore = ns.Addon

if ns._inInitSafeWindow and H3z0UICore and H3z0UICore.Minimap and H3z0UICore.Minimap.InitializeOnce then
    H3z0UICore.Minimap:InitializeOnce()
end
