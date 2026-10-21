local ADDON_NAME, ns = ...

local Settings = ns.Settings
local ProviderFeatures = Settings and Settings.ProviderFeatures
if not ProviderFeatures or type(ProviderFeatures.Register) ~= "function" then
    return
end

ProviderFeatures:Register({
    id = "atonementCounter",
    moverKey = "atonementCounter",
    category = "trackers",
    nav = {
        tileId = "gameplay",
        subPageIndex = 6,
    },
    getDB = function(profile)
        return profile and profile.atonementCounter
    end,
    apply = function()
        if _G.H3z0UI_RefreshAtonementCounter then
            _G.H3z0UI_RefreshAtonementCounter()
        end
    end,
    providerKey = "atonementCounter",
})
