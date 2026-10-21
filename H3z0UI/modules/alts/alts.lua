local ADDON_NAME, ns = ...
local Alts = ns.Alts or {}; ns.Alts = Alts

local Helpers = ns.Helpers
local GetSettings = Helpers.CreateDBGetter("alts")
Alts.GetSettings = GetSettings

local started = false

local function IsEnabled()
    local s = GetSettings()
    return (s and s.enabled) and true or false
end
Alts.IsEnabled = IsEnabled

local function Refresh()
    if not started then return end
    if not IsEnabled() then
        if Alts.Window and Alts.Window.IsShown() then
            Alts.Window.Hide()
        end
        return
    end
    if Alts.Window and Alts.Window.OnProfileChanged then
        Alts.Window.OnProfileChanged()
    end
end

-- luacheck: globals SLASH_H3z0UIALTS1 SLASH_H3z0UIALTS2
SLASH_H3z0UIALTS1 = "/h3z0uialts"
SLASH_H3z0UIALTS2 = "/alts"
SlashCmdList["H3z0UIALTS"] = function()
    if not IsEnabled() then
        print("|cff00ff00H3z0UI:|r " .. ns.L["the Alts module is disabled (Options → Modules)."])
        return
    end
    if _G.H3z0UI_OpenAltsRoster then _G.H3z0UI_OpenAltsRoster() end
end

_G.H3z0UI_RefreshAlts = Refresh

if ns.Registry then
    ns.Registry:Register("alts", {
        refresh = _G.H3z0UI_RefreshAlts,
        priority = 50,
        group = "alts",
        importCategories = { "alts" },
    })
end

ns.WhenLoggedIn(function()
    started = true
end)
