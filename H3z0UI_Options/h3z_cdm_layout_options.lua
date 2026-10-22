local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Cooldown Manager viewers in H3z0 UI Edit Mode: right-click the Essential,
-- Utility, Buff Icons or Buff Bars handle and its own Cooldown Manager tab
-- opens in the settings panel ("open in settings" goes to that tab).
---------------------------------------------------------------------------

local Settings_ = ns.Settings
local ProviderPanels = Settings_ and Settings_.ProviderPanels
local ProviderFeatures = Settings_ and Settings_.ProviderFeatures

-- viewer index -> tab name in the Cooldown Manager options, page on the tile
-- (the tile leaves out "Class Resource Bar": Essential 1, Utility 2,
-- Custom Entries 3, Buff 4)
local VIEWERS = {
    { index = 0, tab = "Essential", page = 1 },
    { index = 1, tab = "Utility",   page = 2 },
    { index = 2, tab = "Buff",      page = 4 },
    { index = 3, tab = "Buff",      page = 4 },
}

local function ViewerKey(index)
    local S = Enum and Enum.EditModeSystem
    local BP = ns.BlizzPositions
    if not (S and S.CooldownViewer ~= nil and BP and BP.Key) then return nil end
    return "h3zCDM_" .. BP.Key(S.CooldownViewer, index)
end

local function FindBuilder(tabName)
    local mod = ns.H3z0UI_NCDMOptions
    if not (mod and mod.GetSubTabs) then return nil end
    local ok, tabs = pcall(mod.GetSubTabs)
    if not (ok and type(tabs) == "table") then return nil end
    for _, t in ipairs(tabs) do
        if t.name == tabName and type(t.builder) == "function" then return t.builder end
    end
    return nil
end

if ProviderPanels and type(ProviderPanels.RegisterAfterLoad) == "function" then
    ProviderPanels:RegisterAfterLoad(function(ctx)
        for _, v in ipairs(VIEWERS) do
            local key = ViewerKey(v.index)
            if key then
                ctx.RegisterShared(key, {
                    build = function(content)
                        local builder = FindBuilder(v.tab)
                        if not builder then return 80 end
                        local ok, err = pcall(builder, content)
                        if not ok then
                            if geterrorhandler then geterrorhandler()(err) end
                            return 80
                        end
                        local h = content:GetHeight() or 0
                        return h > 0 and h or 400
                    end,
                })
            end
        end
    end)
end

if ProviderFeatures and type(ProviderFeatures.Register) == "function" then
    for _, v in ipairs(VIEWERS) do
        local key = ViewerKey(v.index)
        if key then
            pcall(ProviderFeatures.Register, ProviderFeatures, {
                id = "h3zCDMViewer_" .. v.index,
                moverKey = key,
                category = "cdm",
                nav = { tileId = "cooldown_manager", subPageIndex = v.page },
                layoutPositionOnly = false,
                getDB = function(profile) return profile and profile.ncdm end,
                apply = function()
                    if _G.H3z0UI_RefreshNCDM then pcall(_G.H3z0UI_RefreshNCDM) end
                end,
                providerKey = key,
            })
        end
    end
end
