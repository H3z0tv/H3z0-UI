--[[
    H3z0UI Options - H3z0 Features (first sidebar tab)

    Everything H3z0 UI added on top of the base addon, in one place:
      Combat Mode, Bottom Bar, Steam Deck + PC Controller (moved from General & QoL)
      UI Look       - pick Classic / Modern / Modern v2, then only that version's options
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

    function b.Slider(label, min, max, step, key, tbl, onChange, opts)
        return b.Place(GUI:CreateFormSlider(tabContent, label, min, max, step, key, tbl, onChange, opts))
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
        btn:SetPoint("LEFT", row, "LEFT", (GUI.FORM_CONTROL_X or 232), 0)
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

    b.Info("Square portraits of the Classic look. Modern and Modern v2 portraits are set in H3z0 Features > UI Look.", 22, C.accent)

    -- Classic square portraits of the unit frames (used when Frame Style is off)
    local ufdb = db and db.h3z0uiUnitFrames
    if ufdb then
        b.Section("Unit Frame Portraits (Classic)")
        b.Info("The square portrait beside the unit frame. Used by the Classic look (Modern and Modern v2 draw their own portrait).", 22)
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

    b.Finish()
end

---------------------------------------------------------------------------
-- UI LOOK: pick a version, see only the options that version uses
---------------------------------------------------------------------------
local function RefreshAllLook()
    local FS = ns.FrameStyle
    if FS and FS.ApplyAll then pcall(FS.ApplyAll) end
    for _, name in ipairs({
        "H3z0UI_RefreshUnitFrames", "H3z0UI_RefreshModernLook", "H3z0UI_RefreshWindowSkins",
        "H3z0UI_ApplyModernButtons", "H3z0UI_RefreshMinimapShape", "H3z0UI_RefreshPartyFrames",
        "H3z0UI_RefreshCharacterV2", "H3z0UI_RefreshPlates",
    }) do
        local fn = _G[name]
        if fn then pcall(fn) end
    end
end

local function Fonts()
    local list = {}
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for name in pairs(LSM:HashTable("font")) do list[#list + 1] = { value = name, text = name } end
        table.sort(list, function(a, b) return a.text < b.text end)
    end
    if #list == 0 then list[1] = { value = "Friz Quadrata TT", text = "Friz Quadrata TT" } end
    return list
end

local function BuildLookInto(holder, firstBuild)
    local b = Builder(holder)
    local db = Shared.GetDB()
    local Setup = ns.SetupWizard or _G.H3z0UI_Setup
    local look = (Setup and Setup.CurrentLook and Setup.CurrentLook()) or "classic"
    local uiState = { look = look }

    -- rebuilding the page must not add the same options to search again
    if not firstBuild then GUI._suppressSearchRegistration = true end

    b.Section("Version")
    b.Info("Pick a version. Every tab of the menu then shows only the options that version uses, and every change applies right away.", 22)
    local looks = {}
    for _, o in ipairs((Setup and Setup.LOOKS) or {}) do looks[#looks + 1] = { value = o.value, text = o.label } end
    if #looks == 0 then
        looks = { { value = "classic", text = "Classic" }, { value = "modern", text = "Modern" }, { value = "v2", text = "Modern v2" } }
    end
    b.Drop("UI Version", looks, "look", uiState, function(value)
        value = value or uiState.look
        if Setup and Setup.ApplyLookNow then Setup.ApplyLookNow(value) end
        RefreshAllLook()
        -- every tab shows only this version's options: rebuild the whole menu
        C_Timer.After(0, function()
            GUI:RebuildOptions()
            GUI:ShowConfirmation({
                title = "Version Changed",
                message = "The new look is applied and the menu now shows only its options. A reload makes sure every frame picks it up.",
                acceptText = "Reload Now",
                cancelText = "Later",
                isDestructive = false,
                onAccept = function() H3z0UI:SafeReload() end,
            })
        end)
    end)
    for _, o in ipairs((Setup and Setup.LOOKS) or {}) do
        if o.value == look then b.Info(o.desc, 22) end
    end

    -- Common to every version --------------------------------------------
    b.Section("Font")
    if db and db.general then
        b.Drop("Font (used everywhere)", Fonts(), "font", db.general, function()
            local core = ns.Addon
            if core and core.SetAllFonts then pcall(core.SetAllFonts, core, db.general.font) end
            if core and core.ApplyGlobalFont then pcall(core.ApplyGlobalFont, core) end
            RefreshAllLook()
            if ns.ShowPopup and ns.Popups and ns.Popups["H3Z0UI_FONT_RELOAD"] then
                ns.ShowPopup("H3Z0UI_FONT_RELOAD", db.general.font)
            end
        end)
    end

    local NP = ns.H3zPlates
    local npdb = NP and NP.GetSettings and NP.GetSettings()
    if npdb then
        b.Check("Unit Frames in Nameplate Colours", "unitFrameColors", npdb, RefreshAllLook)
    end

    local char = db and db.character
    if char then
        if char.style == nil then char.style = "v2" end
        b.Drop("Character + Inspect Pane", {
            { value = "v2", text = "v2 (race background, item level, enchant hints)" },
            { value = "classic", text = "Classic (item names and enchants listed)" },
        }, "style", char, function()
            RefreshAllLook()
            GUI:ShowConfirmation({
                title = "Reload Recommended",
                message = "The character and inspect panes switch style completely after a reload.",
                acceptText = "Reload Now",
                cancelText = "Later",
                isDestructive = false,
                onAccept = function() H3z0UI:SafeReload() end,
            })
        end)
    end

    if look == "classic" then
        b.Section("Classic")
        b.Info("Square portraits beside flat bars, plain chat and damage meter. The square portraits are set in Unit Frames > Portraits.", 34)
    end

    -- Modern and Modern v2 -----------------------------------------------
    if look ~= "classic" then
        local FS = ns.FrameStyle
        local fsdb = FS and FS.GetSettings and FS.GetSettings()
        if fsdb then
            b.Section("Unit Frames")
            if look == "modern" then
                b.Drop("Portrait", {
                    { value = "round", text = "Round portrait beside the bar" },
                    { value = "square", text = "Portrait docked inside the bar" },
                }, "style", fsdb, RefreshAllLook)
            else
                b.Info("Bars start under a big round portrait and end round.", 22)
            end
            b.Check("Use on Player", "player", fsdb, RefreshAllLook)
            b.Check("Use on Target", "target", fsdb, RefreshAllLook)
            b.Check("Use on Focus", "focus", fsdb, RefreshAllLook)
            b.Slider("Frame Height (0 = your own)", 0, 60, 1, "height", fsdb, RefreshAllLook)
            b.Slider("Portrait Size (0 = fit the frame)", 0, 90, 1, "pSize", fsdb, RefreshAllLook)
            b.Slider("Portrait Border Thickness", 0, 6, 1, "ringThickness", fsdb, RefreshAllLook)
            b.Check("Class / Reaction Colored Border", "classRing", fsdb, RefreshAllLook)
            b.Check("Name on Top", "nameAbove", fsdb, RefreshAllLook)
            b.Check("Pet Bar Under the Player", "dockPet", fsdb, RefreshAllLook)
        end

        local ML = ns.ModernLook
        local mldb = ML and ML.GetSettings and ML.GetSettings()
        if mldb then
            if ns.Round and ns.Round.Settings then ns.Round.Settings() end
            b.Section("Modern Look")
            b.Check("Soft Shadows", "shadow", mldb, RefreshAllLook)
            b.Check("Bar Sheen + Top Highlight", "sheen", mldb, RefreshAllLook)
            b.Check("Portrait Glow", "glow", mldb, RefreshAllLook)
            b.Check("Rounded Corners (frames, bars, buttons, minimap)", "rounded", mldb, RefreshAllLook)
            b.Slider("Corner Radius", 2, 14, 1, "radius", mldb, RefreshAllLook)
            b.Check("Modern Cast Bars", "castbars", mldb, RefreshAllLook)
            b.Check("Modern Action Buttons", "buttons", mldb, RefreshAllLook)
            b.Info("Button slot opacity, borders and gloss: Action Bars > Button Appearance.", 22)
        end

        local WS = ns.WindowSkins
        local wsdb = WS and WS.GetSettings and WS.GetSettings()
        if wsdb then
            if wsdb.chatAlpha == nil then wsdb.chatAlpha = wsdb.alpha or 0.9 end
            if wsdb.meterAlpha == nil then wsdb.meterAlpha = wsdb.alpha or 0.9 end
            b.Section("Chat + Damage Meter")
            local function Skins()
                if _G.H3z0UI_RefreshWindowSkins then _G.H3z0UI_RefreshWindowSkins() end
                -- the Chat tab shows the old background options only while the chat is not skinned
                C_Timer.After(0, function() GUI:RebuildOptions() end)
            end
            b.Check("Dark Rounded Windows", "enabled", wsdb, Skins)
            b.Check("Chat", "chat", wsdb, Skins)
            b.Check("Damage Meter", "damageMeter", wsdb, function()
                if _G.H3z0UI_RefreshWindowSkins then _G.H3z0UI_RefreshWindowSkins() end
            end)
            local function Alpha() if _G.H3z0UI_WindowSkinsAlpha then _G.H3z0UI_WindowSkinsAlpha() end end
            b.Slider("Chat Opacity", 0, 1, 0.05, "chatAlpha", wsdb, Alpha, { live = true })
            b.Slider("Damage Meter Opacity", 0, 1, 0.05, "meterAlpha", wsdb, Alpha, { live = true })
            b.Info("Hide Chat When Idle: Chat > Look & Hide. Party frames v2 sizes: Party Frames.", 22)
        end
    end

    GUI._suppressSearchRegistration = false
    b.Finish()
    return math.abs(b.y) + 40
end

local function BuildLook(tabContent)
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 1, subTabName = "UI Look"})
    local holder
    local first = true
    local function Rebuild()
        if holder then holder:Hide(); holder:SetParent(nil) end
        holder = CreateFrame("Frame", nil, tabContent)
        holder:SetPoint("TOPLEFT", 0, 0)
        holder:SetPoint("TOPRIGHT", 0, 0)
        holder.h3zRebuild = Rebuild
        local ok, h = pcall(BuildLookInto, holder, first)
        GUI._suppressSearchRegistration = false
        first = false
        h = (ok and h) or 600
        holder:SetHeight(h)
        tabContent:SetHeight(h)
    end
    Rebuild()
end

---------------------------------------------------------------------------
-- LAYOUT & BARS
---------------------------------------------------------------------------
local function BuildLayout(tabContent)
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 5, subTabName = "Layout & Bars"})
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
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 6, subTabName = "Map"})
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
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 7, subTabName = "Extras"})
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
    b.Info("/h3z0ui layout  -  Layout Mode (also the Esc menu Edit Mode button)\n/h3z0ui blizzedit  -  Blizzard Edit Mode (size settings only)\n/h3z0ui cdm  -  Cooldown Manager not showing? check and repair\n/h3z0ui export  /  import  -  share a layout code\n/h3z0ui style  -  Frame Style on/off\n/h3z0ui modern  -  Modern Look on/off\n/h3z0ui bars  -  Compact Action Bars on/off\n/h3z0ui coords  -  Map coordinates on/off\n/h3z0ui controller  -  PC Controller on/off\n/h3z0ui pchandheld  -  PC Handheld on/off\n/h3z0ui deck  -  Handheld Mode on/off\n/h3z0ui streamer  -  Streamer Mode on/off\n/h3z0ui plates  -  H3z0 Nameplates on/off\n/h3z0ui whatsnew  -  What's New window\n/h3z0ui setup  -  Setup Wizard", 226, C.text)

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
        { name = "UI Look", builder = BuildLook },
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
