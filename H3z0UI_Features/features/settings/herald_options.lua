--[[
    H3z0 UI Options - Herald (Interface)
    Cinematic banners for zones, level ups, achievements, boss emotes, quests
    and scenarios.
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local FORM_ROW = 32

local function Build(tabContent)
    local y = -10
    local PAD = Shared.PADDING or 10
    local db = Shared.GetDB()
    local h = db and db.herald
    GUI:SetSearchContext({ tabName = "Herald", subTabName = "Herald", tileId = "h3z_herald", subPageIndex = 1 })
    if not h then return end

    local function Refresh()
        if _G.H3z0UI_RefreshHerald then _G.H3z0UI_RefreshHerald() end
    end
    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PAD, y)
        y = y - header.gap
    end
    local function Place(widget, hgt)
        widget:SetPoint("TOPLEFT", PAD, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - (hgt or FORM_ROW)
    end
    local function Check(label, key) Place(GUI:CreateFormCheckbox(tabContent, label, key, h, Refresh)) end
    local function Slider(label, min, max, step, key, opts) Place(GUI:CreateFormSlider(tabContent, label, min, max, step, key, h, Refresh, opts)) end
    local function Info(text, hgt)
        local label = GUI:CreateLabel(tabContent, text, 11, C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        y = y - (hgt or 22)
    end

    Section("Herald")
    Info("Cinematic banners in the middle of the screen: new zones, level ups, achievements, boss emotes, quests and scenario stages. One at a time, the rest wait in line (most important first).", 34)
    Place(GUI:CreateFormCheckbox(tabContent, "Enable Herald", "enabled", h, function() Refresh(); if _G.H3z0UI_NotifySwitch then _G.H3z0UI_NotifySwitch("moduleFlag_h3zHerald") end end))
    local test = GUI:CreateButton(tabContent, "Show Test Banners", 180, 26, function()
        if _G.H3z0UI_HeraldTest then _G.H3z0UI_HeraldTest() end
    end)
    test:SetPoint("TOPLEFT", PAD, y)
    y = y - 38

    Section("Banners")
    Check("Zones", "zone")
    Check("Subzones", "subzone")
    Check("\"Discovered\" on a First Visit", "discovery")
    Check("Level Up", "levelUp")
    Check("Achievements", "achievement")
    Check("Boss Emotes", "bossEmote")
    Check("Quest Accepted", "questAccept")
    Check("Quest Progress", "questProgress")
    Check("Quest Complete", "questComplete")
    Check("World Quests", "worldQuest")
    Check("Scenarios & Delves", "scenario")

    Section("Behaviour")
    Check("Hide Blizzard's Zone Text", "replaceZoneText")
    Check("Hide Blizzard's Boss Emote Line", "replaceBossEmote")
    Check("Quiet During Mythic+ Keys", "quietInKeys")
    Info("Quiet: no zone, quest or scenario banners while a key runs. Level ups, achievements and boss emotes still show.", 22)

    Section("Look")
    Info("Move the banner anywhere in H3z0 UI Edit Mode (Herald Banner). Vertical Position is used until you move it there.", 22)
    Slider("Vertical Position", -600, 0, 1, "offsetY")
    Slider("Scale", 0.5, 2, 0.05, "scale", { precision = 2 })
    Slider("Title Size", 16, 60, 1, "titleSize")
    Slider("Subtitle Size", 10, 30, 1, "subtitleSize")
    Slider("Time on Screen (seconds)", 1, 10, 0.5, "holdTime", { precision = 1 })
    Slider("Animation Speed", 0.5, 2, 0.1, "animSpeed", { precision = 1 })

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_HeraldOptions = { BuildHeraldTab = function(tabContent) Build(tabContent) end }
