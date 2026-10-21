local ADDON_NAME, ns = ...

local V2 = {}
ns.H3z0UI_ChatTooltipsTile = V2

function V2.Register(frame)
    local Opts = ns.H3z0UI_Options
    if not Opts or type(Opts.RegisterFeatureTile) ~= "function" then
        return
    end

    Opts.RegisterFeatureTile(frame, {
        id = "chat_tooltips",
        icon = "T",
        name = ns.L["Tooltips"],
        
        subPages = {
            {
                id = "tooltips",
                name = ns.L["Tooltips"],
                sectionNav = true,
                featureId = "tooltipAnchor",
                navRoutes = { { tabIndex = 2, subTabIndex = 6 } },
            },
        },
    })
end
