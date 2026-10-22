local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Minimap in H3z0 UI Edit Mode: right-click the Minimap (or the map
-- coordinates) handle and the Minimap and Datatext settings open in the
-- settings panel; "open in settings" goes to the Minimap & Datatext page.
---------------------------------------------------------------------------

local Settings_ = ns.Settings
local ProviderPanels = Settings_ and Settings_.ProviderPanels
local ProviderFeatures = Settings_ and Settings_.ProviderFeatures

local KEYS = { minimap = 1, h3zMapCoords = 1 }

-- one builder after the other, each in its own block
local function BuildStack(content, builders)
    local y = 0
    for _, b in ipairs(builders) do
        local fn = b.fn
        if type(fn) == "function" then
            local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -y - 8)
            title:SetText(b.title)
            y = y + 26
            local block = CreateFrame("Frame", nil, content)
            block:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            block:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            block:SetHeight(1)
            local ok, err = pcall(fn, block)
            if not ok and geterrorhandler then geterrorhandler()(err) end
            local h = block:GetHeight() or 0
            if h < 2 then h = 60 end
            y = y + h + 6
        end
    end
    return math.max(y, 80)
end

if ProviderPanels and type(ProviderPanels.RegisterAfterLoad) == "function" then
    ProviderPanels:RegisterAfterLoad(function(ctx)
        for key in pairs(KEYS) do
            ctx.RegisterShared(key, {
                build = function(content)
                    local M = ns.H3z0UI_MinimapOptions
                    if not M then return 80 end
                    return BuildStack(content, {
                        { title = ns.L["Minimap"], fn = M.BuildMinimapTab },
                        { title = ns.L["Datatext"], fn = M.BuildDatatextTab },
                    })
                end,
            })
        end
    end)
end

if ProviderFeatures and type(ProviderFeatures.Register) == "function" then
    for key, page in pairs(KEYS) do
        pcall(ProviderFeatures.Register, ProviderFeatures, {
            id = "h3zMinimapLayout_" .. key,
            moverKey = key,
            category = "ui",
            nav = { tileId = "minimap", subPageIndex = page },
            layoutPositionOnly = false,
            getDB = function(profile) return profile and profile.minimap end,
            apply = function()
                local core = ns.Addon
                if _G.H3z0UI_RefreshMinimap then pcall(_G.H3z0UI_RefreshMinimap) end
                if core and core.Minimap and core.Minimap.Refresh then pcall(core.Minimap.Refresh, core.Minimap) end
            end,
            providerKey = key,
        })
    end
end
