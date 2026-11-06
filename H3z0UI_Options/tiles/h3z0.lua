local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI pages in the options window
--   H3z0 Features, Unit Frames, Party Frames, Nameplates, Chat
-- Each page is built by the H3z0 module's own option builders.
---------------------------------------------------------------------------

local Tiles = {}
ns.H3z0UI_H3z0Tiles = Tiles

local function Builder(fn)
    return function(body)
        if type(fn) ~= "function" then return end
        local ok, err = pcall(fn, body)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end
end

local function Call(modName, fnName)
    return function(body)
        local mod = ns[modName]
        local fn = mod and mod[fnName]
        if type(fn) == "function" then fn(body) end
    end
end

local function Pages(list)
    local pages = {}
    for i, entry in ipairs(list) do
        pages[#pages + 1] = {
            id = entry.id or ("page" .. i),
            name = entry.name,
            buildFunc = Builder(entry.build),
        }
    end
    return pages
end

local function Add(frame, GUI, config)
    if #config.subPages == 0 then return end
    local ok, err = pcall(GUI.AddFeatureTile, GUI, frame, config)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
end

function Tiles.RegisterFeatures(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    local F = ns.H3z0UI_FeaturesOptions
    if not F then return end
    Add(frame, GUI, {
        id = "h3z_features",
        name = "H3z0 Features",
        subtitle = "UI Look · Steam Deck · Combat Mode · Hover Name",
        subPages = Pages({
            { id = "look", name = "UI Look", build = F.BuildLook },
            { id = "combatMode", name = "True Reticle", build = Call("H3z0UI_CombatModeOptions", "BuildCombatModeTab") },
            { id = "handheld", name = "Steam Deck + PC Controller", build = Call("H3z0UI_HandheldOptions", "BuildHandheldTab") },
            { id = "layout", name = "Layout & Bars", build = F.BuildLayout },
            { id = "streamer", name = "Streamer Mode", build = F.BuildStreamer },
            { id = "quickAccess", name = "Quick Access (Dungeons)", build = Call("H3z0UI_QuickAccessOptions", "BuildQuickAccessTab") },
            { id = "hoverName", name = "Hover Name", build = Call("H3z0UI_HoverNameOptions", "BuildHoverNameTab") },
            { id = "extras", name = "Extras", build = F.BuildExtras },
            { id = "setup", name = "Setup Wizard", build = Call("H3z0UI_SetupOptions", "BuildSetupTab") },
        }),
    })
end

function Tiles.RegisterUnitFrames(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    local UFO = ns.H3z0UI_UnitFramesOptions
    if not (UFO and UFO.GetSubTabs) then return end
    local ok, tabs = pcall(UFO.GetSubTabs)
    if not ok or type(tabs) ~= "table" then return end
    local list = {}
    for i, t in ipairs(tabs) do
        list[#list + 1] = { id = "uf" .. i, name = t.name, build = t.builder }
    end
    Add(frame, GUI, {
        id = "h3z_unitframes",
        name = "Unit Frames",
        subtitle = "Player · Target · Focus · Pet · Boss · Cast Bars",
        subPages = Pages(list),
    })
end

function Tiles.RegisterPartyFrames(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    local P = ns.H3z0UI_PartyFramesOptions
    if not P then return end
    Add(frame, GUI, {
        id = "h3z_partyframes",
        name = "Party Frames",
        subtitle = "Party · Raid",
        subPages = Pages({
            { id = "party", name = "Party Frames", build = P.BuildPartyFramesTab },
            { id = "raid", name = "Raid Frames", build = P.BuildRaidFramesTab },
        }),
    })
end

function Tiles.RegisterNameplates(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    local N = ns.H3z0UI_NameplatesOptions
    if not N then return end
    Add(frame, GUI, {
        id = "h3z_nameplates",
        name = "Nameplates",
        subtitle = "H3z0 UI nameplates",
        subPages = Pages({
            { id = "nameplates", name = "Nameplates", build = N.BuildNameplatesTab },
        }),
    })
end

function Tiles.RegisterChat(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    local CO = ns.H3z0UI_ChatOptions
    if not CO then return end
    -- one window: the chat settings and Look & Hide on the same page
    local function BuildChatPage(body)
        local top = CreateFrame("Frame", nil, body)
        top:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, 0)
        top:SetHeight(10)
        if type(CO.BuildChatTab) == "function" then CO.BuildChatTab(top) end
        local bottom = CreateFrame("Frame", nil, body)
        bottom:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(10)
        if type(CO.BuildChatLookTab) == "function" then CO.BuildChatLookTab(bottom) end
        -- chat + damage meter window skin and background opacity
        local windows = CreateFrame("Frame", nil, body)
        windows:SetPoint("TOPLEFT", bottom, "BOTTOMLEFT", 0, 0)
        windows:SetPoint("TOPRIGHT", bottom, "BOTTOMRIGHT", 0, 0)
        windows:SetHeight(10)
        local W = ns.H3z0UI_WindowsOptions
        if W and W.Build then
            local ok, h = pcall(W.Build, windows, nil)
            if ok and h then windows:SetHeight(h) end
        end
        body:SetHeight((top:GetHeight() or 0) + (bottom:GetHeight() or 0) + (windows:GetHeight() or 0) + 20)
    end
    Add(frame, GUI, {
        id = "h3z_chat",
        name = "Chat",
        subtitle = "Chat · Look & Hide · Window Opacity",
        moduleFeatureId = "moduleAddon_H3z0UI_Chat",
        subPages = Pages({
            { id = "chat", name = "Chat", build = BuildChatPage },
        }),
    })
end

-- On / off switch in the sidebar (like the Bottom Bar): the feature's own
-- "enabled" setting, so the switch and the Enable checkbox on the page are the same
local function ProfileTable(key)
    local core = ns.Addon or _G.H3z0UI
    local p = core and core.db and core.db.profile
    return p and p[key]
end

local function ReloadPrompt(message)
    local Q = _G.H3z0UI
    if Q and Q.GUI and Q.GUI.ShowConfirmation then
        Q.GUI:ShowConfirmation({
            reload = true,
            title = "Reload UI?",
            message = message,
            acceptText = "Reload", cancelText = "Later",
            onAccept = function() if Q.SafeReload then Q:SafeReload() end end,
        })
    end
end

local function RegisterSwitch(featureId, dbKey, label, refreshName, reloadMessage)
    local Settings = ns.Settings
    local Registry = Settings and Settings.Registry
    local Schema = Settings and Settings.Schema
    if not (Registry and Schema and Registry.RegisterFeature and Schema.Feature) then return nil end
    if Registry.GetFeature and Registry:GetFeature(featureId) then return featureId end
    local entry = {
        group = "Interface",
        label = label,
        caption = "",
        combatLocked = false,
        isEnabled = function()
            local t = ProfileTable(dbKey)
            return t and t.enabled and true or false
        end,
        setEnabled = function(val, options)
            local t = ProfileTable(dbKey)
            if not t then return end
            t.enabled = val and true or false
            local fn = refreshName and _G[refreshName]
            if fn then pcall(fn) end
            if reloadMessage and not (options and options.suppressReloadPrompt) then ReloadPrompt(reloadMessage) end
        end,
    }
    local ok = pcall(Registry.RegisterFeature, Registry, Schema.Feature({
        id = featureId,
        category = "global",
        moduleEntry = entry,
    }))
    return ok and featureId or nil
end
_G.H3z0UI_NotifySwitch = function(featureId)
    if ns.H3z0UI_Modules and ns.H3z0UI_Modules.NotifyChanged then pcall(ns.H3z0UI_Modules.NotifyChanged, ns.H3z0UI_Modules, featureId) end
end

-- Interface: Herald (cinematic banners) and Arcanum (loot toasts and helpers)
function Tiles.RegisterHerald(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    Add(frame, GUI, {
        id = "h3z_herald",
        name = "Herald",
        moduleFeatureId = RegisterSwitch("moduleFlag_h3zHerald", "herald", "Herald", "H3z0UI_RefreshHerald", nil),
        subtitle = "Zone, level up, achievement, quest and boss banners",
        subPages = Pages({
            { id = "herald", name = "Herald", build = Call("H3z0UI_HeraldOptions", "BuildHeraldTab") },
        }),
    })
end

function Tiles.RegisterArcanum(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    Add(frame, GUI, {
        id = "h3z_arcanum",
        name = "Arcanum",
        moduleFeatureId = RegisterSwitch("moduleFlag_h3zArcanum", "arcanum", "Arcanum", "H3z0UI_RefreshArcanum", nil),
        subtitle = "Loot toasts, alerts, auto vendor, self highlight",
        subPages = Pages({
            { id = "arcanum", name = "Arcanum", build = Call("H3z0UI_ArcanumOptions", "BuildArcanumTab") },
        }),
    })
end

function Tiles.RegisterLorekeeper(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    Add(frame, GUI, {
        id = "h3z_lorekeeper",
        name = "Lorekeeper",
        moduleFeatureId = RegisterSwitch("moduleFlag_h3zLorekeeper", "lorekeeper", "Lorekeeper", "H3z0UI_RefreshLorekeeper", nil),
        subtitle = "NPC talk and quests on a parchment scroll",
        subPages = Pages({
            { id = "lorekeeper", name = "Lorekeeper", build = Call("H3z0UI_LorekeeperOptions", "BuildLorekeeperTab") },
        }),
    })
end

function Tiles.RegisterOracle(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    if ns.Client and (ns.Client.isClassic or ns.Client.isForever) then return end
    Add(frame, GUI, {
        id = "h3z_oracle",
        name = "Oracle",
        moduleFeatureId = RegisterSwitch("moduleFlag_h3zOracle", "h3zOracle", "Oracle", "H3z0UI_RefreshOracle", nil),
        subtitle = "Spoken boss warnings: soak, spread, interrupt...",
        subPages = Pages({
            { id = "oracle", name = "Oracle", build = Call("H3z0UI_OracleOptions", "BuildOracleTab") },
        }),
    })
end

function Tiles.RegisterInterrupts(frame)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and GUI.AddFeatureTile) then return end
    if ns.Client and (ns.Client.isClassic or ns.Client.isForever) then return end
    Add(frame, GUI, {
        id = "h3z_interrupts",
        name = "Interrupts",
        moduleFeatureId = RegisterSwitch("moduleFlag_h3zInterrupts", "h3zInterrupts", "Interrupts", "H3z0UI_RefreshInterrupts", nil),
        subtitle = "Interrupt cooldowns of your group and your own",
        subPages = Pages({
            { id = "interrupts", name = "Interrupts", build = Call("H3z0UI_InterruptOptions", "BuildInterruptsTab") },
        }),
    })
end

function Tiles.RegisterAll(frame)
    Tiles.RegisterFeatures(frame)
    Tiles.RegisterUnitFrames(frame)
    Tiles.RegisterPartyFrames(frame)
    Tiles.RegisterNameplates(frame)
    Tiles.RegisterChat(frame)
    Tiles.RegisterHerald(frame)
    Tiles.RegisterArcanum(frame)
    Tiles.RegisterLorekeeper(frame)
    Tiles.RegisterOracle(frame)
    Tiles.RegisterInterrupts(frame)
end
