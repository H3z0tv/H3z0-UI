local ADDON_NAME, ns = ...

local Settings = ns.Settings
local ProviderFeatures = Settings and Settings.ProviderFeatures
if not ProviderFeatures or type(ProviderFeatures.Register) ~= "function" then
    return
end

ProviderFeatures:Register({
    id = "consumables",
    moverKey = "consumables",
    category = "qol",
    nav = {
        tileId = "gameplay",
        subPageIndex = 5,
    },
    getDB = function(profile)
        return profile and profile.general
    end,
    apply = function()
        if _G.H3z0UI_RefreshConsumables then
            _G.H3z0UI_RefreshConsumables()
        end
    end,
    providerKey = "consumables",
})
