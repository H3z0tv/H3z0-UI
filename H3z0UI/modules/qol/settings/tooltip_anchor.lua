local ADDON_NAME, ns = ...

local Settings = ns.Settings
local ProviderFeatures = Settings and Settings.ProviderFeatures
if not ProviderFeatures or type(ProviderFeatures.Register) ~= "function" then
    return
end

ProviderFeatures:Register({
    id = "tooltipAnchor",
    moverKey = "tooltipAnchor",
    category = "qol",
    nav = {
        tileId = "chat_tooltips",
        subPageIndex = 6,
    },
    apply = function()
        if ns.H3z0UI_RefreshTooltips then
            ns.H3z0UI_RefreshTooltips()
        end
        if ns.H3z0UI_RefreshTooltipFontSize then
            ns.H3z0UI_RefreshTooltipFontSize()
        end
        if ns.H3z0UI_RefreshTooltipSkinColors then
            ns.H3z0UI_RefreshTooltipSkinColors()
        end
    end,
    providerKey = "tooltipAnchor",
})
