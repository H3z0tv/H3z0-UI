local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Cooldown Manager page: the H3z0 UI Cooldown Manager (Blizzard's Essential,
-- Utility and Buff viewers, skinned), its buff bars and the custom trackers
---------------------------------------------------------------------------
local V2 = {}
ns.H3z0UI_CooldownManagerTile = V2

local function Pages(prefix, tabs, skip)
    local pages = {}
    for i, t in ipairs(tabs or {}) do
        if not (skip and skip[t.name]) and type(t.builder) == "function" then
            local builder = t.builder
            pages[#pages + 1] = {
                id = prefix .. i,
                name = t.name,
                buildFunc = function(body)
                    local ok, err = pcall(builder, body)
                    if not ok and geterrorhandler then geterrorhandler()(err) end
                end,
            }
        end
    end
    return pages
end

local function Collect(mod)
    if not (mod and mod.GetSubTabs) then return nil end
    local ok, tabs = pcall(mod.GetSubTabs)
    if ok and type(tabs) == "table" then return tabs end
    return nil
end

local function Add(GUI, frame, config)
    if #config.subPages == 0 then return end
    local ok, err = pcall(GUI.AddFeatureTile, GUI, frame, config)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

function V2.Register(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end

    -- the resource bars get their own page (Resource Bars), the rest stays here
    local cdmTabs = Collect(ns.H3z0UI_NCDMOptions)
    if cdmTabs then
        Add(GUI, frame, {
            id = "cooldown_manager",
            name = ns.L["Cooldown Manager"],
            subtitle = "Essential · Utility · Buff Bars · Effects",
            moduleFeatureId = "moduleAddon_H3z0UI_CDM",
            subPages = Pages("cdm", cdmTabs, { ["Class Resource Bar"] = true }),
        })
    end

    local trackerTabs = Collect(ns.H3z0UI_CustomTrackersOptions)
    if trackerTabs then
        Add(GUI, frame, {
            id = "h3z_customtrackers",
            name = "Custom Trackers",
            subtitle = "Spell scanner · Tracker bars",
            moduleFeatureId = "moduleAddon_H3z0UI_CDM",
            subPages = Pages("ct", trackerTabs),
        })
    end
end
