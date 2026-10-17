--[[
    H3z0UI Options - H3z0 Features (first sidebar tab)

    Everything H3z0 UI added on top of the base addon, in one place:
      Combat Mode, Bottom Bar, Steam Deck + PC Controller (moved from General & QoL)
      Portraits     - frame style (round / docked), classic unit frame portraits, party portraits
      Layout & Bars - Layout Mode, Compact Action Bars
      Map           - minimap coordinates
      Extras        - party (ready check, raid manager tab), WoW: Forever, setup wizard
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local TAB_INDEX = 1
local TAB_NAME = "H3z0 Features"
local FORM_ROW = 32

local function RefreshUF()
    if _G.H3z0UI_RefreshUnitFrames then _G.H3z0UI_RefreshUnitFrames() end
    if ns.FrameStyle and ns.FrameStyle.ApplyAll then ns.FrameStyle.ApplyAll() end
end

local function RefreshParty()
    if _G.H3z0UI_RefreshPartyFrames then _G.H3z0UI_RefreshPartyFrames() end
end

local function RefreshMinimap()
    if _G.H3z0UI_RefreshMinimap then _G.H3z0UI_RefreshMinimap() end
end

-- Small layout helper shared by every sub-tab
local function Builder(tabContent)
    local b = { y = -10, PAD = Shared.PADDING or 10 }

    function b.Place(widget, h)
        widget:SetPoint("TOPLEFT", b.PAD, b.y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -b.PAD, 0)
        b.y = b.y - (h or FORM_ROW)
        return widget
    end

    function b.Section(title)
        b.y = b.y - 6
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", b.PAD, b.y)
        b.y = b.y - header.gap
    end

    function b.Sub(title)
        local label = GUI:CreateLabel(tabContent, title, 12, C.accent)
        label:SetPoint("TOPLEFT", b.PAD, b.y)
        b.y = b.y - 22
    end

    function b.Info(text, h, color)
        local label = GUI:CreateLabel(tabContent, text, 11, color or C.textMuted)
        label:SetPoint("TOPLEFT", b.PAD, b.y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -b.PAD, 0)
        label:SetJustifyH("LEFT")
        b.y = b.y - (h or 22)
    end

    function b.Check(label, key, tbl, onChange)
        return b.Place(GUI:CreateFormCheckbox(tabContent, label, key, tbl, onChange))
    end

    function b.Slider(label, min, max, step, key, tbl, onChange)
        return b.Place(GUI:CreateFormSlider(tabContent, label, min, max, step, key, tbl, onChange))
    end

    function b.Drop(label, options, key, tbl, onChange)
        return b.Place(GUI:CreateFormDropdown(tabContent, label, options, key, tbl, onChange))
    end

    function b.Button(label, text, width, onClick)
        local row = CreateFrame("Frame", nil, tabContent)
        row:SetHeight(FORM_ROW)
        local l = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        l:SetPoint("LEFT", 0, 0)
        if GUI.FitFormLabel then GUI.FitFormLabel(l) end
        l:SetText(label)
        l:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        local btn = GUI:CreateButton(row, text, width or 140, 24, onClick)
        btn:SetPoint("LEFT", row, "LEFT", 180, 0)
        b.Place(row)
        return btn
    end

    function b.Finish()
        tabContent:SetHeight(math.abs(b.y) + 40)
    end

    return b
end

---------------------------------------------------------------------------
-- PORTRAITS
---------------------------------------------------------------------------
local function BuildPortraits(tabContent)
    GUI:SetSearchContext({tabIndex = 6, tabName = "Unit Frames", subTabIndex = 8, subTabName = "Portraits"})
    local b = Builder(tabContent)
    local db = Shared.GetDB()

    -- Modern Look (shadow / sheen / glow on frames, minimap and info bar)
    local ML = ns.ModernLook
    local mldb = ML and ML.GetSettings and ML.GetSettings()
    if mldb then
        local function RefreshML()
            if _G.H3z0UI_RefreshModernLook then _G.H3z0UI_RefreshModernLook() end
            if _G.H3z0UI_RefreshWindowSkins then _G.H3z0UI_RefreshWindowSkins() end
        end
        if ns.Round and ns.Round.Settings then ns.Round.Settings() end
        b.Section("Modern Look")
        b.Info("Soft shadows, a subtle sheen on the bars and a glow behind the portraits - on the unit frames, power and cast bars, minimap and info bar. Your settings stay as they are. /h3z0ui modern", 34)
        b.Check("Use Modern Look", "enabled", mldb, RefreshML)
        b.Check("Soft Shadows", "shadow", mldb, RefreshML)
        b.Check("Bar Sheen + Top Highlight", "sheen", mldb, RefreshML)
        b.Check("Portrait Glow (round portraits)", "glow", mldb, RefreshML)
        b.Check("Rounded Corners (unit frames, bars, square minimap, windows)", "rounded", mldb, RefreshML)
        b.Slider("Corner Radius", 2, 14, 1, "radius", mldb, RefreshML)
    end

    -- Window Skins (chat + damage meter)
    local WS = ns.WindowSkins
    local wsdb = WS and WS.GetSettings and WS.GetSettings()
    if wsdb then
        local function RefreshWS() if _G.H3z0UI_RefreshWindowSkins then _G.H3z0UI_RefreshWindowSkins() end end
        b.Section("Window Skins")
        b.Info("A dark, see-through window with soft rounded corners for the chat and Blizzard's damage meter: header strip, accent line and flat bars on the meter, an accent underline on the selected chat tab.", 34)
        b.Check("Use Window Skins", "enabled", wsdb, RefreshWS)
        b.Check("Chat", "chat", wsdb, RefreshWS)
        b.Check("Damage Meter", "damageMeter", wsdb, RefreshWS)
        b.Check("Damage Meter Header + Accent Line", "header", wsdb, RefreshWS)
        b.Slider("Background Opacity", 0, 1, 0.05, "alpha", wsdb, RefreshWS)
    end

    -- Frame style (round / docked)
    local FS = ns.FrameStyle
    local fsdb = FS and FS.GetSettings and FS.GetSettings()
    if fsdb then
        b.Section("Frame Style")
        b.Info("A different look for Player / Target / Focus without losing your setup. Turning it off puts your frames back exactly as they were. /h3z0ui style", 34)
        b.Check("Use Frame Style", "enabled", fsdb, function() FS.SetEnabled(fsdb.enabled) end)
        b.Drop("Style", {
            { value = "round", text = "Round Portrait (ring beside the bar)" },
            { value = "roundv2", text = "Round Portrait v2 (bar starts at the portrait, round end)" },
            { value = "square", text = "Docked Portrait (portrait inside the bar)" },
        }, "style", fsdb, RefreshUF)
        b.Check("Use on Player", "player", fsdb, RefreshUF)
        b.Check("Use on Target", "target", fsdb, RefreshUF)
        b.Check("Use on Focus", "focus", fsdb, RefreshUF)
        b.Slider("Frame Height (0 = your own)", 0, 60, 1, "height", fsdb, RefreshUF)
        b.Slider("Portrait Size (0 = fit the frame)", 0, 90, 1, "pSize", fsdb, RefreshUF)
        b.Slider("Portrait Border Thickness", 0, 6, 1, "ringThickness", fsdb, RefreshUF)
        b.Check("Class / Reaction Colored Border", "classRing", fsdb, RefreshUF)
        b.Check("Name on Top", "nameAbove", fsdb, RefreshUF)
        b.Check("Pet Bar Under the Player", "dockPet", fsdb, RefreshUF)
    end

    -- Classic square portraits of the unit frames (used when Frame Style is off)
    local ufdb = db and db.h3z0uiUnitFrames
    if ufdb then
        b.Section("Unit Frame Portraits (Classic)")
        b.Info("The square portrait beside the unit frame. Used when Frame Style is off (Frame Style draws its own portrait).", 22)
        for _, info in ipairs({ { "player", "Player" }, { "target", "Target" }, { "focus", "Focus" } }) do
            local unitKey, title = info[1], info[2]
            local u = ufdb[unitKey]
            if u then
                if u.showPortrait == nil then u.showPortrait = false end
                if u.portraitSide == nil then u.portraitSide = (unitKey == "player") and "LEFT" or "RIGHT" end
                if u.portraitSize == nil then
                    u.portraitSize = u.portraitScale and math.floor((u.height or 40) * u.portraitScale) or 40
                end
                if u.portraitBorderSize == nil then u.portraitBorderSize = 1 end
                if u.portraitGap == nil then u.portraitGap = 0 end
                if u.portraitOffsetX == nil then u.portraitOffsetX = 0 end
                if u.portraitOffsetY == nil then u.portraitOffsetY = 0 end
                if u.portraitBorderUseClassColor == nil then u.portraitBorderUseClassColor = false end
                if u.portraitBorderColor == nil then u.portraitBorderColor = { 0, 0, 0, 1 } end

                b.Sub(title)
                b.Check("Show Portrait", "showPortrait", u, RefreshUF)
                b.Drop("Portrait Side", { { value = "LEFT", text = "Left" }, { value = "RIGHT", text = "Right" } }, "portraitSide", u, RefreshUF)
                b.Slider("Portrait Size (Pixels)", 20, 150, 1, "portraitSize", u, RefreshUF)
                b.Slider("Portrait Border", 0, 5, 1, "portraitBorderSize", u, RefreshUF)
                b.Slider("Portrait Gap", 0, 10, 1, "portraitGap", u, RefreshUF)
                b.Slider("Portrait Offset X", -500, 500, 1, "portraitOffsetX", u, RefreshUF)
                b.Slider("Portrait Offset Y", -500, 500, 1, "portraitOffsetY", u, RefreshUF)
                local picker
                b.Check("Use Class Color for Border", "portraitBorderUseClassColor", u, function(val)
                    RefreshUF()
                    if picker and picker.SetEnabled then picker:SetEnabled(not val) end
                end)
                picker = b.Place(GUI:CreateFormColorPicker(tabContent, "Border Color", "portraitBorderColor", u, RefreshUF))
                if picker.SetEnabled then picker:SetEnabled(not u.portraitBorderUseClassColor) end
            end
        end
    end

    -- Party frames portrait
    local pf = db and db.partyFrames
    if pf then
        b.Section("Party Frame Portraits")
        b.Slider("Portrait Size", 24, 90, 1, "portraitSize", pf, RefreshParty)
    end

    b.Finish()
end

---------------------------------------------------------------------------
-- LAYOUT & BARS
---------------------------------------------------------------------------
local function BuildLayout(tabContent)
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 4, subTabName = "Layout & Bars"})
    local b = Builder(tabContent)

    b.Section("Layout Mode")
    b.Info("Move every frame in one place: H3z0 UI frames (unit frames, cast bars, party, power bars, totems, timers, minimap, coordinates, panels) and Blizzard frames (action bars, Cooldown Manager, buffs, objective tracker, micro menu, bags, ...). Drag a handle, arrow keys nudge (Shift = 10px), right-click a handle to open its settings, Esc or Done to leave.", 46)
    b.Info("PC and Deck keep separate positions: what you move while Handheld Mode is off is your PC layout, while it is on your Deck layout. Blizzard frames are saved in the Edit Mode layouts \"H3z0 PC\" and \"H3z0 Deck\", managed by H3z0 UI.", 46)
    b.Button("Layout Mode", "Open", 140, function()
        if _G.H3z0UI_ToggleLayoutMode then _G.H3z0UI_ToggleLayoutMode() end
    end)
    b.Info("It is the only edit mode: the Esc menu's Edit Mode button opens it too, as do /h3z0ui layout and the keybind (Key Bindings > AddOns > H3z0UI). Blizzard's own editor is only needed for its size settings (action bar rows / icon size, Cooldown Manager size): /h3z0ui blizzedit", 46)

    b.Section("Share Layout")
    b.Info("Export gives you one code with the positions of every frame for PC and Deck (Blizzard frames included) to share. Import applies a code someone shared with you.", 34)
    b.Button("Export Layout", "Export", 140, function()
        if _G.H3z0UI_ExportLayout then _G.H3z0UI_ExportLayout() end
    end)
    b.Button("Import Layout", "Import", 140, function()
        if _G.H3z0UI_ImportLayout then _G.H3z0UI_ImportLayout() end
    end)

    b.Section("Cooldown Manager")
    b.Info("Essential / Utility / Buff Icons / Tracked Bars not showing? This checks Blizzard's Cooldown Manager option, the viewer visibility in your Edit Mode layout and off-screen positions, fixes what it finds and tells you in chat.", 46)
    b.Button("Cooldown Manager", "Check & Repair", 140, function()
        if _G.H3z0UI_CDMDoctor then _G.H3z0UI_CDMDoctor() end
    end)

    b.Section("Compact Action Bars")
    b.Info("Switches Blizzard Edit Mode to its own layout \"H3z0 Compact\": Action Bars 1-3 as an 8-button grid at the bottom center, Action Bar 4 underneath. Your own layout is not touched; press again to go back. Bars 2-4 must be on in Options > Gameplay > Action Bars. /h3z0ui bars", 46)
    b.Button("Compact Action Bars", "Try / Revert", 140, function()
        if _G.H3z0UI_ToggleCompactBars then _G.H3z0UI_ToggleCompactBars() end
    end)

    b.Finish()
end

---------------------------------------------------------------------------
-- MAP
---------------------------------------------------------------------------
local function BuildMap(tabContent)
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 5, subTabName = "Map"})
    local b = Builder(tabContent)
    local db = Shared.GetDB()
    local mm = db and db.minimap
    if not mm then
        b.Info("Minimap settings are not loaded.")
        b.Finish()
        return
    end

    b.Section("Map Coordinates")
    b.Check("Show Coordinates", "showCoords", mm, RefreshMinimap)
    if mm.showCoordsButton == nil then mm.showCoordsButton = true end
    b.Check("Show XY Toggle Button on Minimap (on mouseover)", "showCoordsButton", mm, RefreshMinimap)
    b.Drop("Precision", {
        { value = "%d,%d", text = "Normal (45,62)" },
        { value = "%.1f,%.1f", text = "High (45.3,62.1)" },
        { value = "%.2f,%.2f", text = "Very High (45.31,62.08)" },
    }, "coordPrecision", mm, RefreshMinimap)
    if mm.coordsConfig then
        local cc = mm.coordsConfig
        b.Slider("Horizontal Offset", -300, 300, 1, "offsetX", cc, RefreshMinimap)
        b.Slider("Vertical Offset", -300, 300, 1, "offsetY", cc, RefreshMinimap)
        b.Slider("Text Size", 8, 24, 1, "fontSize", cc, RefreshMinimap)
        b.Drop("Text Alignment", {
            { value = "LEFT", text = "Left" }, { value = "CENTER", text = "Center" }, { value = "RIGHT", text = "Right" },
        }, "align", cc, RefreshMinimap)
        b.Check("Use Class Color", "useClassColor", cc, RefreshMinimap)
    end
    b.Info("Drag the coordinates in Layout Mode. Toggle them with the XY button on the minimap, /h3z0ui coords, or a keybind (Key Bindings > AddOns > H3z0UI).", 34)

    b.Finish()
end

---------------------------------------------------------------------------
-- EXTRAS
---------------------------------------------------------------------------
local function BuildExtras(tabContent)
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 6, subTabName = "Extras"})
    local b = Builder(tabContent)
    local db = Shared.GetDB()

    local pf = db and db.partyFrames
    if pf then
        b.Section("Party")
        b.Info("Ready check ticks show on the party frame portraits (green = ready, red = not ready) and fade out after the check. Blizzard's raid manager tab on the left edge is hidden in a party when \"Hide Blizzard Party Frames\" is on (Party Frames page).", 46)
    end

    b.Section("WoW: Forever")
    b.Info("On WoW: Forever, H3z0 UI hides the gryphons and bar art, and the character window stays Blizzard's own with item levels on each slot plus your equipped / overall item level.", 34)
    local client = ns.Client
    b.Info("Running on: " .. ((client and client.isForever) and "WoW: Forever" or "Midnight"), 22, C.text)

    b.Section("What's New")
    b.Info("The list of what's new and what's fixed opens once after every update. Open it again here.", 22)
    b.Button("What's New", "Open", 140, function()
        if _G.H3z0UI_ShowWhatsNew then _G.H3z0UI_ShowWhatsNew() end
    end)

    b.Section("Setup Wizard")
    b.Info("Run the setup again: PC or Steam Deck, nameplate addon, features and the extras (coordinates, party frames, combat timer, M+ timer, consumables, crosshair, totems, skyriding).", 34)
    b.Button("Setup Wizard", "Open", 140, function()
        if _G.H3z0UI_Setup then _G.H3z0UI_Setup.Show() end
    end)

    b.Section("Chat Commands")
    b.Info("/h3z0ui layout  -  Layout Mode (also the Esc menu Edit Mode button)\n/h3z0ui blizzedit  -  Blizzard Edit Mode (size settings only)\n/h3z0ui cdm  -  Cooldown Manager not showing? check and repair\n/h3z0ui export  /  import  -  share a layout code\n/h3z0ui style  -  Frame Style on/off\n/h3z0ui modern  -  Modern Look on/off\n/h3z0ui bars  -  Compact Action Bars on/off\n/h3z0ui coords  -  Map coordinates on/off\n/h3z0ui controller  -  PC Controller on/off\n/h3z0ui pchandheld  -  PC Handheld on/off\n/h3z0ui deck  -  Handheld Mode on/off\n/h3z0ui streamer  -  Streamer Mode on/off\n/h3z0ui whatsnew  -  What's New window\n/h3z0ui setup  -  Setup Wizard", 226, C.text)

    b.Finish()
end

---------------------------------------------------------------------------
-- PAGE
---------------------------------------------------------------------------
-- Pages that moved here from General & QoL keep their own builders
local function Sub(mod, fn, c)
    if mod and mod[fn] then mod[fn](c) end
end

local function CreateFeaturesPage(parent)
    local scroll, content = Shared.CreateScrollableContent(parent)
    GUI:CreateSubTabs(content, {
        { name = "Combat Mode", builder = function(c) Sub(ns.H3z0UI_CombatModeOptions, "BuildCombatModeTab", c) end },
        { name = "Bottom Bar", builder = function(c) Sub(ns.H3z0UI_BottomBarOptions, "BuildBottomBarTab", c) end },
        { name = "Steam Deck + PC Controller", builder = function(c) Sub(ns.H3z0UI_HandheldOptions, "BuildHandheldTab", c) end },
        { name = "Layout & Bars", builder = BuildLayout },
        { name = "Map", builder = BuildMap },
        { name = "Extras", builder = BuildExtras },
    })
    content:SetHeight(600)
    return scroll
end

ns.H3z0UI_FeaturesOptions = {
    CreateFeaturesPage = CreateFeaturesPage,
    BuildPortraits = BuildPortraits,   -- shown as Unit Frames > Portraits
}
