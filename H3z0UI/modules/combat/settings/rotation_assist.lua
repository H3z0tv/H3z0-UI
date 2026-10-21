local ADDON_NAME, ns = ...

local Settings = ns.Settings
local ProviderFeatures = Settings and Settings.ProviderFeatures
if not ProviderFeatures or type(ProviderFeatures.Register) ~= "function" then
    return
end

ProviderFeatures:Register({
    id = "rotationAssistIcon",
    moverKey = "rotationAssistIcon",
    category = "combat",
    nav = {
        tileId = "gameplay",
        subPageIndex = 6,
    },
    getDB = function(profile)
        return profile and profile.rotationAssistIcon
    end,
    apply = function()
        if _G.H3z0UI_RefreshRotationAssistIcon then
            _G.H3z0UI_RefreshRotationAssistIcon()
        end
    end,
    providerKey = "rotationAssistIcon",
})
