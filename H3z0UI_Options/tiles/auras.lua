local ADDON_NAME, ns = ...

ns.H3z0UI_AurasTile = ns.H3z0UI_AurasTile or {}

function ns.H3z0UI_AurasTile.Register(frame)
    local Opts = ns.H3z0UI_Options
    if not Opts or type(Opts.RegisterFeatureTile) ~= "function" then
        return
    end

    Opts.RegisterFeatureTile(frame, {
        id = "auras",
        icon = "*",
        name = ns.L["Auras"],
        subtitle = ns.L["Buffs · debuffs · indicators, all in one place"],
        subPages = {
            {
                id = "aurasActionBar",
                name = ns.L["Buff/Debuff Frames"],
                featureId = "aurasActionBarPage",
                navRoutes = { { tabIndex = 21, subTabIndex = 4 } },
                searchContext = {
                    tabIndex = 21,
                    tabName = ns.L["Auras"],
                    subTabIndex = 4,
                    subTabName = ns.L["Buff/Debuff Frames"],
                },
            },
            {
                id = "aurasDisplays",
                name = ns.L["Aura Displays"],
                featureId = "aurasDisplaysPage",
                navRoutes = { { tabIndex = 21, subTabIndex = 6 } },
                searchAliases = {
                    ns.L["Aura Displays"], ns.L["Custom aura frame"],
                    ns.L["Track a buff on screen"], ns.L["Watch another player's auras"],
                    ns.L["Load Conditions"], ns.L["Classes"], ns.L["Specs"],
                    ns.L["Roles"], ns.L["Encounters"], ns.L["New Display"],
                },
                searchContext = {
                    tabIndex = 21,
                    tabName = ns.L["Auras"],
                    subTabIndex = 6,
                    subTabName = ns.L["Aura Displays"],
                },
            },
            {
                id = "aurasIncoming",
                name = ns.L["Incoming Casts"],
                featureId = "incomingCastsPage",
                navRoutes = { { tabIndex = 21, subTabIndex = 7 } },
                searchAliases = {
                    ns.L["Incoming Casts"], ns.L["Casts targeting me"],
                    ns.L["Targeted spells"], ns.L["Enemy casts on me"],
                },
                searchContext = {
                    tabIndex = 21,
                    tabName = ns.L["Auras"],
                    subTabIndex = 7,
                    subTabName = ns.L["Incoming Casts"],
                },
            },
        },
    })
end
