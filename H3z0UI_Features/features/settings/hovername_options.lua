--[[
    H3z0UI Options - Hover Name Tab
    All settings of the Hover Name module
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors

local Shared = ns.H3z0UI_Options

local function BuildHoverNameTab(tabContent)
    local y = -10
    local FORM_ROW = 32
    local PADDING = Shared.PADDING
    local db = Shared.GetDB()

    GUI:SetSearchContext({tabIndex = 3, tabName = "H3z0 Features", subTabIndex = 6, subTabName = "Hover Name"})

    local hn = db and db.hoverName
    if not hn then return end

    local function Refresh()
        if _G.H3z0UI_RefreshHoverName then _G.H3z0UI_RefreshHoverName() end
    end

    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PADDING, y)
        y = y - header.gap
    end

    local function Place(widget)
        widget:SetPoint("TOPLEFT", PADDING, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    local function Check(label, key, onChange)
        Place(GUI:CreateFormCheckbox(tabContent, label, key, hn, onChange or Refresh))
    end

    local function Slider(label, min, max, step, key)
        Place(GUI:CreateFormSlider(tabContent, label, min, max, step, key, hn, Refresh))
    end

    local function Dropdown(label, options, key)
        Place(GUI:CreateFormDropdown(tabContent, label, options, key, hn, Refresh))
    end

    local function Info(text, height)
        local label = GUI:CreateLabel(tabContent, text, 10, C.textMuted)
        label:SetPoint("TOPLEFT", PADDING, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        label:SetJustifyH("LEFT")
        y = y - (height or 20)
    end

    local formatOptions = {
        {value = "PERCENT", text = "Percentage"},
        {value = "NUMBER", text = "Number"},
        {value = "BOTH", text = "Both"},
    }

    -- ENABLE
    Section("Enable/Disable Hover Name")
    Check("Hover Name Module", "enabled")
    Info("Shows the name of players and NPCs next to your cursor while hovering them in the world.", 28)
    Info("Tip: set Tooltip > Tooltip Visibility > \"NPCs & Players\" to \"Always Hide\" if you only want this display.", 28)

    -- DISPLAY
    Section("Display")
    Dropdown("Cursor Anchor", {
        {value = "TOP", text = "Top"}, {value = "BOTTOM", text = "Bottom"},
        {value = "LEFT", text = "Left"}, {value = "RIGHT", text = "Right"},
        {value = "TOPLEFT", text = "Top Left"}, {value = "TOPRIGHT", text = "Top Right"},
        {value = "BOTTOMLEFT", text = "Bottom Left"}, {value = "BOTTOMRIGHT", text = "Bottom Right"},
    }, "cursorAnchor")
    Slider("Vertical Offset", -200, 200, 1, "offsetVertical")
    Slider("Horizontal Offset", -200, 200, 1, "offsetHorizontal")
    Slider("Gap While Aiming (mouselook)", 0, 150, 1, "aimGap")
    Slider("Font Size", 8, 30, 1, "fontSize")
    Dropdown("Font Type", Shared.GetFontList(), "fontType")
    Dropdown("Font Outline", {
        {value = "NONE", text = "None"}, {value = "OUTLINE", text = "Outline"},
        {value = "THICKOUTLINE", text = "Thick Outline"}, {value = "MONOCHROMEOUTLINE", text = "Monochrome Outline"},
    }, "fontOutline")
    Check("Show Background", "bgEnabled")
    Place(GUI:CreateFormColorPicker(tabContent, "Background Color", "bgColor", hn, Refresh, {noAlpha = true}))
    Slider("Background Transparency (0 = clear, 100 = solid)", 0, 100, 1, "bgAlpha")
    Slider("Background Padding", 0, 20, 1, "bgPadding")

    -- PLAYER
    Section("Player")
    Check("Class Colors", "playerClassColor")
    Check("Show Level", "playerShowLevel")
    Check("Level Color", "playerLevelColor")
    Check("Show Target", "playerShowTarget")
    Check("Show Status (AFK / DND / PvP)", "playerShowStatus")
    Check("Show Guild Name", "playerShowGuildName")
    Check("Show Guild Rank", "playerShowGuildRank")
    Check("Show Race", "playerShowRace")
    Check("Show Faction", "playerShowFaction")

    -- NPC
    Section("NPC")
    Check("Standing Colors", "npcColorState")
    Check("Show Level", "npcShowLevel")
    Check("Level Color", "npcLevelColor")
    Check("Show Target", "npcShowTarget")
    Check("Show Classification (rare / elite / boss)", "npcShowClassification")
    Check("Show Faction", "npcShowFaction")
    Check("Show Creature Type", "npcShowCreatureType")
    Check("Show Combat Status Icon", "npcShowCombat")

    -- QUESTS
    Section("Quests / Objectives")
    Check("Show Information", "questShow")
    Info("Show quest / objective info below the name if the target is needed for a quest.")
    Check("Show Completed", "questShowCompleted")
    Slider("Font Size", 8, 30, 1, "questFontSize")

    -- MYTHIC+
    Section("Mythic+")
    Check("Show Enemy Forces", "mplusShowForces")
    Info("During a keystone run, show how much a hovered enemy contributes to Enemy Forces.")
    Dropdown("Contribution Format", formatOptions, "mplusContributionFormat")
    Check("Show Pull Progress", "mplusShowProgress")
    Dropdown("Progress Format", formatOptions, "mplusProgressFormat")
    Slider("Font Size", 8, 30, 1, "mplusFontSize")
    Check("Show Next to Name", "mplusDisplayRight")

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_HoverNameOptions = {
    BuildHoverNameTab = BuildHoverNameTab
}
