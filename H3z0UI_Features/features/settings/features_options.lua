--[[
    H3z0UI Options - H3z0 Features (first sidebar tab)

    Everything H3z0 UI added on top of the base addon, in one place:
      Combat Mode, Bottom Bar, Steam Deck + PC Controller (moved from General & QoL)
      UI Look       - pick Legacy / Modern / Modern v2 / Modern v3, then only that version's options
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
local function AddPortraits(b)
    local db = Shared.GetDB()

    -- Legacy square portraits of the unit frames (used when Frame Style is off)
    local ufdb = db and db.h3z0uiUnitFrames
    if ufdb then
        b.Section("Unit Frame Portraits (Legacy)")
        b.Info("The square portrait beside the unit frame. Only the Legacy version uses it (Modern, Modern v2 and Modern v3 draw their own portrait).", 34)
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
end

local function BuildPortraits(tabContent)
    GUI:SetSearchContext({tabIndex = 6, tabName = "Unit Frames", subTabIndex = 8, subTabName = "Version Settings"})
    local b = Builder(tabContent)
    AddPortraits(b)
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
        "H3z0UI_RefreshCharacterV2", "H3z0UI_RefreshPlates", "H3z0UI_RefreshGirly", "H3z0UI_RefreshInfoBar",
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

local LOOK_NAMES = { classic = "Legacy", modern = "Modern", v2 = "Modern v2", v3 = "Modern v3" }

-- Apply a version everywhere; afterApply runs first (a page redraws itself with the new version)
local function ChangeLook(value, afterApply)
    local Setup = ns.SetupWizard or _G.H3z0UI_Setup
    if Setup and Setup.ApplyLookNow then Setup.ApplyLookNow(value) end
    RefreshAllLook()
    if afterApply then afterApply() end
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
        looks = { { value = "classic", text = "Legacy" }, { value = "modern", text = "Modern" }, { value = "v2", text = "Modern v2" }, { value = "v3", text = "Modern v3" } }
    end
    b.Drop("UI Version", looks, "look", uiState, function(value)
        ChangeLook(value or uiState.look)
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
            -- every module that draws text picks up the new font
            for _, fn in ipairs({ "H3z0UI_RefreshUnitFrames", "H3z0UI_RefreshPartyFrames", "H3z0UI_RefreshRaidFrames",
                "H3z0UI_RefreshNameplates", "H3z0UI_RefreshMinimap", "H3z0UI_RefreshInfoBar", "H3z0UI_RefreshActionBars",
                "H3z0UI_RefreshNCDM", "H3z0UI_RefreshCustomTrackers", "H3z0UI_RefreshHoverName", "H3z0UI_RefreshBottomBar",
                "H3z0UI_RefreshObjectiveTracker", "H3z0UI_RefreshDatatexts" }) do
                local f = _G[fn]
                if type(f) == "function" then pcall(f) end
            end
            -- a few parts (Blizzard's own fonts, chat) take a new font only after a reload
            if GUI and GUI.ShowConfirmation then
                GUI:ShowConfirmation({
                    reload = true,
                    title = "Font changed",
                    message = "The new font is used everywhere now. Reload so the last parts take it too?",
                    acceptText = "Reload",
                    cancelText = "Later",
                    onAccept = function() if H3z0UI and H3z0UI.SafeReload then H3z0UI:SafeReload() else ReloadUI() end end,
                })
            end
        end)
    end

    -- Girly Look: pastel backgrounds with a soft pattern (every version) ----
    local G = ns.H3z0Girly
    local gs = G and G.GetSettings and G.GetSettings()
    if gs then
        b.Section("Girly Look")
        b.Info("Soft pastel pink backgrounds with flowers (or hearts, sparkles, polka dots, bows) behind the action bars. The chat, damage meter and Bottom Bar can get it too: pick them under Where.", 34)
        local preview, customPicker
        local function Changed()
            if G.Apply then G.Apply() end
            if preview and preview.Refresh then preview.Refresh() end
        end
        b.Check("Girly Look", "enabled", gs, Changed)
        preview = G.CreatePreview(holder)
        if preview then b.Place(preview, 112) end
        b.Drop("Colours", G.PaletteOptions(), "palette", gs, function()
            Changed()
            if customPicker and customPicker.SetEnabled then customPicker:SetEnabled(gs.palette == "custom") end
        end)
        customPicker = b.Place(GUI:CreateFormColorPicker(holder, "Custom Colour", "custom", gs, Changed, { noAlpha = true }))
        if customPicker.SetEnabled then customPicker:SetEnabled(gs.palette == "custom") end
        b.Drop("Pattern", G.PatternOptions(), "pattern", gs, Changed)
        b.Slider("Pattern Strength", 0, 1, 0.05, "patternAlpha", gs, Changed, { live = true })
        b.Slider("Pattern Size", 0.4, 2, 0.05, "patternScale", gs, Changed, { live = true })
        b.Slider("Background Opacity", 0.2, 1, 0.05, "fillAlpha", gs, Changed, { live = true })
        b.Slider("Background Lightness (dark to pastel)", 0, 1, 0.05, "lightness", gs, Changed, { live = true })
        b.Check("Coloured Border", "border", gs, Changed)
        b.Sub("Where")
        b.Check("Action Bars", "actionBars", gs, Changed)
        b.Check("Chat", "chat", gs, Changed)
        b.Check("Damage Meter", "damageMeter", gs, Changed)
        b.Check("Bottom Bar", "bottomBar", gs, Changed)
        b.Info("Toggle it any time with /h3z0ui girly.", 22)
    end

    local NP = ns.H3zPlates
    local npdb = NP and NP.GetSettings and NP.GetSettings()
    if npdb then
        b.Check("Unit Frames in Nameplate Colours", "unitFrameColors", npdb, RefreshAllLook)
    end

    local char = db and db.character
    if char then
        if char.h3zBackground == nil then char.h3zBackground = true end
        if char.h3zLogo == nil then char.h3zLogo = true end
        local function RefreshChar()
            if _G.H3z0UI_RefreshCharacterBackground then _G.H3z0UI_RefreshCharacterBackground() end
        end
        b.Section("Character + Inspect")
        b.Check("Homeland Background (race art)", "h3zBackground", char, RefreshChar)
        b.Check("H3z0 UI Logo in the Corner", "h3zLogo", char, RefreshChar)

        b.Info("What the H3z0 character window shows, and its size: H3z0 Features > Character Window.", 22)
    end

    b.Section("Unit Frames")
    b.Info("The unit frame settings of this version (portrait, bar height, border" .. (look == "v3" and ", badge, execute line" or "") .. ") are in Unit Frames > Version Settings. That page shows only the version in use.", 34)

    if look == "classic" then
        b.Section("Legacy")
        b.Info("Square portraits beside flat bars, plain chat and damage meter.", 22)
    end

    -- Modern, Modern v2 and Modern v3 --------------------------------------
    if look ~= "classic" then

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
        if not ok and geterrorhandler then geterrorhandler()(h) end
        GUI._suppressSearchRegistration = false
        first = false
        h = (ok and h) or 600
        holder:SetHeight(h)
        tabContent:SetHeight(h)
    end
    Rebuild()
end

---------------------------------------------------------------------------
-- UNIT FRAMES > VERSION SETTINGS: only the settings of the version in use.
-- Legacy, Modern, Modern v2 and Modern v3 each keep their own values.
---------------------------------------------------------------------------
local function AddFrameStyleControls(b, look)
    local FS = ns.FrameStyle
    local fsdb = FS and FS.GetSettings and FS.GetSettings()
    local o = FS and FS.Opts and FS.Opts()
    if not (fsdb and o) then
        b.Info("The frame style is not loaded.", 22)
        return
    end
    if look == "modern" then
        b.Drop("Portrait", {
            { value = "round", text = "Round portrait beside the bar" },
            { value = "square", text = "Portrait docked inside the bar" },
        }, "style", fsdb, RefreshAllLook)
    end
    b.Check("Use on Player", "player", o, RefreshAllLook)
    b.Check("Use on Target", "target", o, RefreshAllLook)
    b.Check("Use on Focus", "focus", o, RefreshAllLook)
    b.Slider("Frame Height (0 = your own)", 0, 60, 1, "height", o, RefreshAllLook)
    b.Slider("Portrait Size (0 = fit the frame)", 0, 90, 1, "pSize", o, RefreshAllLook)
    b.Slider("Portrait Border Thickness", 0, 6, 1, "ringThickness", o, RefreshAllLook)
    b.Check("Class / Reaction Colored Border", "classRing", o, RefreshAllLook)
    b.Check("Name on Top", "nameAbove", o, RefreshAllLook)
    b.Check("Pet Bar Under the Player", "dockPet", o, RefreshAllLook)

    if look == "v3" then
        b.Section("Modern v3 Extras")
        b.Check("Percent and Value Inside the Bar", "splitText", o, RefreshAllLook)
        b.Slider("Text Size (name, percent, value)", 8, 18, 1, "textSize", o, RefreshAllLook)
        b.Check("Drop Portrait (square corner toward the bar)", "drop", o, RefreshAllLook)
        b.Check("Elite / Rare / Boss Marking on the Portrait", "badge", o, RefreshAllLook)
        b.Check("Dragon Around the Portrait (off = small badge)", "dragon", o, RefreshAllLook)
        b.Check("Execute Line on the Health Bar", "execute", o, RefreshAllLook)
        b.Slider("Execute Line At (% health)", 5, 50, 1, "executePct", o, RefreshAllLook)
        b.Check("Execute Line in My Class Colour", "executeClass", o, RefreshAllLook)
        b.Check("Spell Icon in the Portrait While Casting", "castIcon", o, RefreshAllLook)
        b.Info("The marking and the execute line show on Target and Focus. The execute line only on units you can attack.", 34)
    end
end

local function BuildFrameLookInto(holder, firstBuild, rebuild)
    local b = Builder(holder)
    local Setup = ns.SetupWizard or _G.H3z0UI_Setup
    local look = (Setup and Setup.CurrentLook and Setup.CurrentLook()) or "classic"
    local uiState = { look = look }

    -- rebuilding the page must not add the same options to search again
    if not firstBuild then GUI._suppressSearchRegistration = true end

    b.Section("Version")
    local looks = {}
    for _, o in ipairs((Setup and Setup.LOOKS) or {}) do looks[#looks + 1] = { value = o.value, text = o.label } end
    if #looks == 0 then
        looks = { { value = "classic", text = "Legacy" }, { value = "modern", text = "Modern" }, { value = "v2", text = "Modern v2" }, { value = "v3", text = "Modern v3" } }
    end
    b.Drop("UI Version", looks, "look", uiState, function(value)
        ChangeLook(value or uiState.look, rebuild)
    end)
    for _, o in ipairs((Setup and Setup.LOOKS) or {}) do
        if o.value == look then b.Info(o.desc, 34) end
    end
    b.Info("Only the settings of the version in use are shown below. Pick another version and this page switches to that version's own settings.", 34)

    b.Section((LOOK_NAMES[look] or "Version") .. " Settings")
    if look == "classic" then
        AddPortraits(b)
    else
        AddFrameStyleControls(b, look)
        if look == "v2" then
            b.Info("Party frame sizes of this version: Party Frames.", 22)
        end
    end

    GUI._suppressSearchRegistration = false
    b.Finish()
    return math.abs(b.y) + 40
end

local function BuildFrameLook(tabContent)
    GUI:SetSearchContext({tabIndex = 6, tabName = "Unit Frames", subTabIndex = 8, subTabName = "Version Settings"})
    local holder
    local first = true
    local function Rebuild()
        if holder then holder:Hide(); holder:SetParent(nil) end
        holder = CreateFrame("Frame", nil, tabContent)
        holder:SetPoint("TOPLEFT", 0, 0)
        holder:SetPoint("TOPRIGHT", 0, 0)
        local ok, h = pcall(BuildFrameLookInto, holder, first, function() C_Timer.After(0, Rebuild) end)
        if not ok and geterrorhandler then geterrorhandler()(h) end
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
    b.Info("Move every frame in one place: action bars, Cooldown Manager, resource bars, minimap, panels, Blizzard frames and the H3z0 unit frames, party frames and raid frames. Drag a handle, arrow keys nudge, right-click a handle to open its settings.", 46)
    b.Info("PC and Deck keep separate positions: what you move while Handheld Mode is off is your PC layout, while it is on your Deck layout.", 34)
    b.Button("Layout Mode", "Open", 140, function()
        if _G.H3z0UI_ToggleLayoutMode then _G.H3z0UI_ToggleLayoutMode() end
    end)
    b.Info("Also opens from the Esc menu, /h3z0ui layout and the keybind (Key Bindings > AddOns > H3z0UI). The H3z0 unit frames can also be dragged on their own: /h3z0ui frames", 34)

    b.Section("Compact Action Bars")
    b.Info("Switches Blizzard Edit Mode to its own layout \"H3z0 Compact\": Action Bars 1-3 as an 8-button grid at the bottom center, Action Bar 4 underneath. Your own layout is not touched; press again to go back. Bars 2-4 must be on in Options > Gameplay > Action Bars. /h3z0ui bars", 46)
    b.Button("Compact Action Bars", "Try / Revert", 140, function()
        if _G.H3z0UI_ToggleCompactBars then _G.H3z0UI_ToggleCompactBars() end
    end)

    b.Finish()
end

---------------------------------------------------------------------------
-- STREAMER MODE
---------------------------------------------------------------------------
local function BuildStreamer(tabContent)
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 9, subTabName = "Streamer Mode"})
    local b = Builder(tabContent)
    local db = Shared.GetDB()
    local ab = db and db.actionBars
    if ab then ab.global = ab.global or {} end
    local g = ab and ab.global

    b.Section("Streamer Mode")
    b.Info("Hides the button press highlight on every action button (pressed / checked glow, cast and targeting animations), so viewers can't see which keys you press.", 34)
    if g then
        b.Check("Streamer Mode", "streamerMode", g, function()
            if _G.H3z0UI_ApplyStreamerMode then _G.H3z0UI_ApplyStreamerMode() end
        end)
    else
        b.Info("Action bar settings are not loaded.")
    end
    b.Info("Toggle it any time with /h3z0ui streamer.", 22)
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

    if db and not (ns.Client and (ns.Client.isClassic or ns.Client.isForever)) then
        db.h3zGroupTools = db.h3zGroupTools or {}
        local gt = db.h3zGroupTools
        if gt.keystoneButtons == nil then gt.keystoneButtons = true end
        if gt.sortApplicants == nil then gt.sortApplicants = true end
        if gt.applicantFlags == nil then gt.applicantFlags = true end
        if gt.pullSeconds == nil then gt.pullSeconds = 10 end
        b.Section("Mythic+ Groups")
        b.Check("Ready Check and Pull Timer Buttons on the Keystone Window", "keystoneButtons", gt, function()
            if _G.H3z0UI_RefreshKeystoneButtons then _G.H3z0UI_RefreshKeystoneButtons() end
        end)
        b.Slider("Pull Timer (seconds)", 3, 20, 1, "pullSeconds", gt, function() if _G.H3z0UI_RefreshKeystoneButtons then _G.H3z0UI_RefreshKeystoneButtons() end end)
        b.Info("Left button: ready check. Right button: pull timer. Group leader or assistant only.", 22)
        b.Check("Sort Applicants by Mythic+ Rating", "sortApplicants", gt)
        b.Check("Realm Language Flags Next to Applicants", "applicantFlags", gt)
        b.Info("In your Premade Groups listing the applicants with the highest rating come first, and a small flag shows the language of each player's realm (hover it for the name).", 34)
    end

    local MT = ns.H3z0MapTools
    local mt = MT and MT.Settings and MT.Settings()
    if mt then
        local function RefreshMT() if MT.Apply then MT.Apply() end end
        b.Section("Map")
        b.Check("Waypoints (/way)", "waypoints", mt, RefreshMT)
        b.Info("/way 45.2 62.1 Mailbox, /way Elwynn Forest 42 65 Inn or /way #1453 60 70 prints a link; click it to set the map pin. You get a message when you arrive. /way clear forgets them. If another addon already has /way, use /h3z0way.", 46)
        if ns.Client and ns.Client.isForever then
            b.Check("Show Unexplored Areas on the World Map", "reveal", mt, RefreshMT)
            b.Place(GUI:CreateFormColorPicker(tabContent, "Unexplored Area Colour", "revealColor", mt, RefreshMT))
            b.Check("Zone Levels on the World Map", "zoneLevels", mt, RefreshMT)
            b.Check("Fishing Skill on the World Map", "fishing", mt, RefreshMT)
            b.Info("Hover a zone on a continent map to see its level range; the fishing skill it needs shows under it (red: too low, yellow: some fish get away, green: none do).", 34)
        end
    end

    if _G.H3z0UI_ComboPointsSettings then
        local cp = _G.H3z0UI_ComboPointsSettings()
        local function Rf() if _G.H3z0UI_RefreshComboPoints then _G.H3z0UI_RefreshComboPoints() end end
        b.Section("Combo Points")
        b.Check("Show Combo Points Under the Player Frame", "enabled", cp, Rf)
        b.Info("Red circles under your player frame for rogues and druids in cat form, for when Crosshair Z is not on (for example with a controller).", 34)
        b.Check("Hide Them While Crosshair Z Is Loaded", "hideWithCrosshair", cp, Rf)
        b.Check("Show the Empty Circles Too", "showEmpty", cp, Rf)
        b.Slider("Circle Size", 8, 32, 1, "size", cp, Rf)
        b.Slider("Gap Between Circles", 0, 12, 1, "gap", cp, Rf)
        b.Slider("Distance Under the Frame", -60, 20, 1, "offsetY", cp, Rf)
    end

    if _G.H3z0UI_DungeonMapSettings then
        local dm = _G.H3z0UI_DungeonMapSettings()
        b.Section("Dungeon Map")
        b.Check("Open the Map on the Dungeon You Are In", "enabled", dm)
        b.Info("Inside a dungeon the map window opens on that dungeon instead of staying on World.", 22)
    end

    b.Section("WoW: Forever")
    b.Info("On WoW: Forever, H3z0 UI hides the gryphons and bar art, and the character window stays Blizzard's own with item levels on each slot plus your equipped / overall item level.", 34)
    local client = ns.Client
    b.Info("Running on: " .. ((client and client.isForever) and "WoW: Forever" or "Midnight"), 22, C.text)

    if ns.Client and ns.Client.isForever and select(2, UnitClass("player")) == "DRUID" then
        b.Section("Shapeshift Bars")
        b.Info("The Shapeshift Bars (Mana, Rage and Energy after shifting) are set up under Unit Frames > Player > Shapeshift Bars.", 34)
    end

    if ns.Client and not ns.Client.isLegacy and select(2, UnitClass("player")) == "DRUID" and _G.H3z0UI_DruidManaSettings then
        local dm = _G.H3z0UI_DruidManaSettings()
        if dm then
            local function Apply() if _G.H3z0UI_RefreshDruidMana then _G.H3z0UI_RefreshDruidMana() end end
            b.Section("Druid Mana Bar")
            b.Info("Cat, Bear and Moonkin druids lose the Mana bar. This shows it as part of your H3z0 player frame, under the health / power bar, lined up with it and inside the frame's border, while Mana is not your main resource. Druids only.", 34)
            b.Check("Show the Druid Mana Bar", "enabled", dm, Apply)
            b.Check("Show the Mana Number", "showText", dm, Apply)
            b.Slider("Bar Height", 4, 30, 1, "height", dm, Apply)
        end
    end

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
    b.Info("/h3z0ui layout  -  Layout Mode\n/h3z0ui frames  -  drag the H3z0 unit frames\n/h3z0ui party  /  raid  -  party / raid frame preview\n/h3z0ui style  -  Frame Style on/off\n/h3z0ui modern  -  Modern Look on/off\n/h3z0ui bars  -  Compact Action Bars on/off\n/h3z0ui controller  -  PC Controller on/off\n/h3z0ui pchandheld  -  PC Handheld on/off\n/h3z0ui deck  -  Handheld Mode on/off\n/h3z0ui streamer  -  Streamer Mode on/off\n/h3z0ui girly  -  Girly Look on/off\n/h3z0ui plates  -  H3z0 Nameplates on/off\n/h3z0ui arrow  -  Quest Arrow on/off\n/h3z0ui arrow move  -  move the Quest Arrow\n/h3z0ui whatsnew  -  What's New window\n/h3z0ui setup  -  Setup Wizard", 220, C.text)

    b.Finish()
end

---------------------------------------------------------------------------
-- CHARACTER WINDOW (own tab)
---------------------------------------------------------------------------
local function BuildCharWindow(tabContent)
    local b = Builder(tabContent)
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 2, subTabName = "Character Window"})
    local core = ns.Addon
    local db = core and core.db and core.db.profile
    if not db then b.Finish() return end
    db.character = db.character or {}
    local char = db.character
    local retail = ns.Client and not ns.Client.isLegacy
    for k, v in pairs({ h3zWindow = true, h3zInspectWindow = true, cwNames = true, cwItemLevel = true,
        cwTrack = true, cwNoUpgrade = true, cwMaxGray = true, h3zBackground = true, h3zLogo = true }) do
        if char[k] == nil then char[k] = v end
    end
    if type(char.cwScale) ~= "number" then char.cwScale = 100 end
    if type(char.cwTextSize) ~= "number" then char.cwTextSize = 0 end
    local function Apply()
        if _G.H3z0UI_RefreshCharacterWindow then _G.H3z0UI_RefreshCharacterWindow() end
        if _G.H3z0UI_RefreshCharacterBackground then _G.H3z0UI_RefreshCharacterBackground() end
        if _G.H3z0UI_RefreshInspectWindow then _G.H3z0UI_RefreshInspectWindow() end
    end

    b.Section("Character Window")
    b.Info("The H3z0 character window (C) and inspect window, one set of settings for both. The Settings button in each window's footer opens the same settings. Changes show straight away.", 34)
    b.Check("H3z0 Character Window", "h3zWindow", char, Apply)
    b.Check("H3z0 Inspect Window", "h3zInspectWindow", char)
    b.Check("Homeland Background (race art)", "h3zBackground", char, Apply)
    b.Check("H3z0 UI Logo in the Corner", "h3zLogo", char, Apply)

    b.Section("Gear Rows")
    b.Check("Item Names", "cwNames", char, Apply)
    b.Check("Item Level", "cwItemLevel", char, Apply)
    if retail then
        b.Check("Upgrade Track (Hero 4/6, Myth 2/6...)", "cwTrack", char, Apply)
        b.Check("Fully Upgraded Items Greyed Out", "cwMaxGray", char, Apply)
        b.Check("Mark Items That Can't Be Upgraded", "cwNoUpgrade", char, Apply)
    end

    b.Section("Size")
    b.Slider("Window Size (%)", 70, 130, 5, "cwScale", char, Apply)
    b.Slider("Text Size", -2, 4, 1, "cwTextSize", char, Apply)
    b.Finish()
end

---------------------------------------------------------------------------
-- QUEST ARROW (own tab)
---------------------------------------------------------------------------
local function BuildArrow(tabContent)
    local b = Builder(tabContent)
    GUI:SetSearchContext({tabIndex = TAB_INDEX, tabName = TAB_NAME, subTabIndex = 10, subTabName = "Quest Arrow"})
    if not _G.H3z0UI_QuestArrowSettings then
        b.Info("The Quest Arrow is not available on this client.", 22)
        b.Finish()
        return
    end
    local qa = _G.H3z0UI_QuestArrowSettings()
    local function Apply() if _G.H3z0UI_RefreshQuestArrow then _G.H3z0UI_RefreshQuestArrow() end end

    b.Section("Quest Arrow")
    b.Info("An arrow on screen that points to where you have to go and shows how far it is, like TomTom. It follows the quest you have focused (click a quest in the quest tracker or on the map) and the pin on your map, also the one /way sets. It hides when you arrive.", 46)
    b.Check("Show the Quest Arrow", "enabled", qa, Apply)

    b.Section("What It Points To")
    b.Check("Follow the Focused Quest", "followQuest", qa, Apply)
    b.Check("Nothing Focused: Closest Tracked Quest", "nearest", qa, Apply)
    b.Check("Follow the Map Pin (/way)", "followPin", qa, Apply)
    b.Check("Clear the Map Pin When You Arrive", "autoClear", qa, Apply)
    b.Slider("Arrived Distance (Yards)", 3, 60, 1, "arriveDistance", qa, Apply)

    b.Section("Text")
    b.Check("Show the Distance", "showDistance", qa, Apply)
    b.Check("Show the Arrival Time", "showETA", qa, Apply)
    b.Check("Show the Quest Name", "showTitle", qa, Apply)
    b.Drop("Distance In", { { value = "yd", text = "Yards" }, { value = "m", text = "Metres" } }, "units", qa, Apply)
    b.Slider("Text Size", 8, 24, 1, "textSize", qa, Apply)

    b.Section("Look")
    b.Slider("Arrow Size", 0.5, 2.5, 0.05, "scale", qa, Apply)
    b.Slider("Opacity", 0.2, 1, 0.05, "alpha", qa, Apply)
    b.Place(GUI:CreateFormColorPicker(tabContent, "Arrow Colour", "color", qa, Apply, { noAlpha = true }))
    b.Place(GUI:CreateFormColorPicker(tabContent, "Colour When Heading Straight At It", "colorOnTarget", qa, Apply, { noAlpha = true }))
    b.Check("Hide in Combat", "hideInCombat", qa, Apply)

    b.Section("Position")
    b.Button("Move the Arrow", "Move", 140, function()
        if _G.H3z0UI_QuestArrowMove then _G.H3z0UI_QuestArrowMove() end
    end)
    b.Info("Move shows a sample arrow: drag it where you want it, then press Move again to lock it.", 22)
    b.Button("Arrow Position", "Reset", 140, function()
        if _G.H3z0UI_QuestArrowReset then _G.H3z0UI_QuestArrowReset() end
    end)

    b.Section("Commands")
    b.Info("/h3z0arrow  -  Quest Arrow on/off\n/h3z0arrow move  -  move it\n/way 45.2 62.1 Mailbox  -  put a map pin the arrow follows", 46, C.text)

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
        { name = "Character Window", builder = BuildCharWindow },
        { name = "Crosshair Z", builder = function(c) Sub(ns.H3z0UI_CombatModeOptions, "BuildCombatModeTab", c) end },
        { name = "Bottom Bar", builder = function(c) Sub(ns.H3z0UI_BottomBarOptions, "BuildBottomBarTab", c) end },
        { name = "Steam Deck + PC Controller", builder = function(c) Sub(ns.H3z0UI_HandheldOptions, "BuildHandheldTab", c) end },
        { name = "Layout & Bars", builder = BuildLayout },
        { name = "Quest Arrow", builder = BuildArrow },
        { name = "Extras", builder = BuildExtras },
    })
    content:SetHeight(600)
    return scroll
end

ns.H3z0UI_FeaturesOptions = {
    CreateFeaturesPage = CreateFeaturesPage,
    BuildPortraits = BuildPortraits,   -- the Legacy portrait settings on their own
    BuildFrameLook = BuildFrameLook,   -- Unit Frames > Version Settings
    BuildLook = BuildLook,
    BuildLayout = BuildLayout,
    BuildExtras = BuildExtras,
    BuildArrow = BuildArrow,
    BuildCharWindow = BuildCharWindow,
    BuildStreamer = BuildStreamer,
}
