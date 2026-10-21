local ADDON_NAME, ns = ...

local Settings = ns.Settings
local ProviderFeatures = Settings and Settings.ProviderFeatures
if not ProviderFeatures or type(ProviderFeatures.Register) ~= "function" then
    return
end

ProviderFeatures:Register({
    id = "mplusTimer",
    moverKey = "mplusTimer",
    category = "dungeon",
    nav = {
        tileId = "gameplay",
        subPageIndex = 6,
    },
    getDB = function(profile)
        return profile and profile.mplusTimer
    end,
    apply = function()
        local timer = _G.H3z0UI_MPlusTimer
        if timer and timer.UpdateLayout then
            timer:UpdateLayout()
        end
        if _G.H3z0UI_ApplyMPlusTimerSkin then
            _G.H3z0UI_ApplyMPlusTimerSkin()
        end
    end,
    providerKey = "mplusTimer",
})
