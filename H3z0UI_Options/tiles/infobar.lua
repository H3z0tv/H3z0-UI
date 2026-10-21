local ADDON_NAME, ns = ...

local V2InfoBar = {}
ns.H3z0UI_InfoBarTile = V2InfoBar

function V2InfoBar.Register(frame)
    local Opts = ns.H3z0UI_Options
    if not Opts or type(Opts.RegisterFeatureTile) ~= "function" then
        return
    end

    Opts.RegisterFeatureTile(frame, {
        id = "infobar",
        icon = "i",
        name = "Bottom Bar",
        moduleFeatureId = "moduleFlag_infobar",
        subPages = {
            {
                id = "infobar",
                name = "Widgets & Zones",
                sectionNav = true,
                featureId = "infobar",
                navRoutes = {
                    { tabIndex = 18, subTabIndex = 0 },
                    { tabIndex = 18, subTabIndex = 1 },
                },
                searchContext = {
                    tabIndex = 18,
                    tabName = ns.L["Info Bar"],
                    subTabIndex = 1,
                    subTabName = ns.L["Info Bar"],
                },
                searchAliases = {
                    ns.L["info bar"],
                    ns.L["infobar"],
                    ns.L["data bar"],
                    ns.L["top bar"],
                    ns.L["bottom bar"],
                },
            },
        },
    })

    -- H3z0 UI: the Bottom Bar switches (show, position, Blizzard menus, look) as the first page
    local BBO = ns.H3z0UI_BottomBarOptions
    if BBO and BBO.BuildBottomBarTab and frame._tiles then
        for _, tile in ipairs(frame._tiles) do
            if tile.id == "infobar" and tile.config and type(tile.config.subPages) == "table" then
                table.insert(tile.config.subPages, 1, {
                    id = "h3zBottomBar",
                    name = "Bottom Bar",
                    buildFunc = function(body)
                        local ok, err = pcall(BBO.BuildBottomBarTab, body)
                        if not ok and geterrorhandler then geterrorhandler()(err) end
                    end,
                })
                break
            end
        end
    end
end
