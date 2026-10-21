local _, ns = ...

local Settings = ns.Settings
local ProviderFeatures = Settings and Settings.ProviderFeatures
if not ProviderFeatures or type(ProviderFeatures.Register) ~= "function" then
    return
end

ProviderFeatures:Register({
    id = "infobar",
    category = "ui",
    nav = {
        tileId = "infobar",
        subPageIndex = 1,
    },
    getDB = function(profile)
        return profile and profile.infobar
    end,
    apply = function()
        if _G.H3z0UI_RefreshInfoBar then _G.H3z0UI_RefreshInfoBar() end
    end,
    providerKey = "infobar",
})
