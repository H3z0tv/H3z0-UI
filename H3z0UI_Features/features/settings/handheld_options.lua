--[[
    H3z0UI Options - Steam Deck / Handheld Tab  (0.18)
    Handheld Mode: UI scale for small screens (Steam Deck 1280x800), always-visible
    action bars for controller play, settings window fit, ConsolePort / gamepad status.
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local tabRef
local Build

local function HH()
    return _G.H3z0UI_Handheld
end

local function Rebuild()
    if not tabRef or not Build then return end
    for _, child in ipairs({tabRef:GetChildren()}) do
        child:Hide()
        child:ClearAllPoints()
    end
    for _, region in ipairs({tabRef:GetRegions()}) do
        region:Hide()
    end
    Build(tabRef)
end

Build = function(tabContent)
    tabRef = tabContent
    local y = -10
    local FORM_ROW = 32
    local PADDING = Shared.PADDING
    local db = Shared.GetDB()
    local handheld = HH()
    if not db or not handheld then return end

    GUI:SetSearchContext({tabIndex = 1, tabName = "H3z0 Features", subTabIndex = 4, subTabName = "Steam Deck + PC Controller"})

    -- Make sure the settings table exists with defaults (module fills it on first use)
    db.handheld = db.handheld or {}
    local cfg = db.handheld
    if cfg.enabled == nil then cfg.enabled = false end
    if cfg.autoDetect == nil then cfg.autoDetect = true end
    if cfg.keepBarsVisible == nil then cfg.keepBarsVisible = true end
    if cfg.fitOptionsWindow == nil then cfg.fitOptionsWindow = true end
    if cfg.deckUnitFrames == nil then cfg.deckUnitFrames = true end
    if cfg.pcController == nil then cfg.pcController = false end
    if cfg.pcHandheld == nil then cfg.pcHandheld = false end
    cfg.deckChoice = (cfg.enabled and not cfg.pcHandheld) and true or false
    if cfg.uiScale == nil or cfg.uiScale <= 0 then cfg.uiScale = handheld.AutoScale() end

    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PADDING, y)
        y = y - header.gap
    end

    local function Place(widget, h)
        widget:SetPoint("TOPLEFT", PADDING, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - (h or FORM_ROW)
    end

    local function Info(text, h, color)
        local label = GUI:CreateLabel(tabContent, text, 10, color or C.textMuted)
        label:SetPoint("TOPLEFT", PADDING, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        label:SetJustifyH("LEFT")
        y = y - (h or 20)
    end

    ---------------------------------------------------------------------
    Section("PC Controller")
    Info("Play on your PC with a controller: keeps your normal PC layout (same positions, sizes and scale) and only swaps the addons - ConsolePort on, Action Combat Mode off - then reloads. Untick to go back to mouse and keyboard (Action Combat Mode on, ConsolePort off). Only one of PC Controller, PC Handheld and Steam Deck can be on: turning one on turns the others off.", 58)
    Place(GUI:CreateFormCheckbox(tabContent, "PC Controller (ConsolePort instead of Action Combat Mode)", "pcController", cfg, function()
        handheld.SetPCController(cfg.pcController)
    end))

    Section("PC Handheld")
    Info("The Steam Deck setup on your PC: Steam Deck HUD and frame positions, and ConsolePort (Action Combat Mode off) - but your normal PC UI scale. Reloads when switched. Only one of PC Controller, PC Handheld and Steam Deck can be on.", 46)
    Place(GUI:CreateFormCheckbox(tabContent, "PC Handheld (Steam Deck layout, PC scale)", "pcHandheld", cfg, function()
        handheld.SetPCHandheld(cfg.pcHandheld)
    end))

    Section("Handheld / Steam Deck Mode")
    Info("Optimizes H3z0 UI for small handheld screens like the Steam Deck (1280x800, 16:10) and for controller play. " ..
         "It applies a handheld UI scale, keeps your action bars visible, and fits this settings window on the screen. " ..
         "Turning it off restores your previous UI scale and bar fading.", 44)

    local w, h = handheld.GetResolution()
    local resText = string.format("Screen: %dx%d", w, h)
    if handheld.IsSteamDeckResolution() then
        resText = resText .. "  -  Steam Deck resolution detected"
    elseif handheld.IsSmallScreen() then
        resText = resText .. "  -  small / handheld screen detected"
    else
        resText = resText .. "  -  desktop-size screen (Handheld Mode is optional here)"
    end
    Info(resText, 18, C.text)

    local padText = handheld.GamepadEnabled() and "Gamepad support (WoW native): ON" or "Gamepad support (WoW native): off"
    local cpText = handheld.ConsolePortLoaded() and "ConsolePort: loaded" or "ConsolePort: not loaded"
    Info(padText .. "   |   " .. cpText, 22, C.text)

    Place(GUI:CreateFormCheckbox(tabContent, "Enable Handheld Mode (Steam Deck)", "deckChoice", cfg, function()
        handheld.SetSteamDeck(cfg.deckChoice)
    end))
    Info("Turning it on disables Action Combat Mode, enables ConsolePort, switches to the Deck positions and reloads. Turning it off enables Action Combat Mode, disables ConsolePort, switches to the PC positions and reloads. PC and Deck each keep their own frame positions: move frames in H3z0 UI Layout Mode while in that mode.", 46)
    Place(GUI:CreateFormCheckbox(tabContent, "Auto-enable on a small screen (<= 800p), first launch only", "autoDetect", cfg))

    ---------------------------------------------------------------------
    Section("Handheld UI Scale")
    Info("Pixel-perfect for the current screen is " .. string.format("%.2f", handheld.AutoScale()) ..
         " (768 / screen height). Higher = bigger and easier to read on a 7\" screen, but fits less on screen.", 32)

    local scaleSlider = GUI:CreateFormSlider(tabContent, "Handheld UI Scale", 0.5, 1.4, 0.01, "uiScale", cfg, function()
        if cfg.enabled then handheld.ApplyScale() end
    end, { deferOnDrag = true, precision = 2 })
    Place(scaleSlider)

    local function SetScale(val)
        cfg.uiScale = val
        if scaleSlider.SetValue then scaleSlider.SetValue(val, true) end
        if cfg.enabled then handheld.ApplyScale() end
    end

    local compact = GUI:CreateButton(tabContent, "Compact (0.85)", 150, 26, function() SetScale(0.85) end)
    compact:SetPoint("TOPLEFT", PADDING, y)
    local perfect = GUI:CreateButton(tabContent, "Pixel-perfect", 150, 26, function() SetScale(handheld.AutoScale()) end)
    perfect:SetPoint("LEFT", compact, "RIGHT", 8, 0)
    local comfy = GUI:CreateButton(tabContent, "Comfortable (1.15)", 150, 26, function() SetScale(1.15) end)
    comfy:SetPoint("LEFT", perfect, "RIGHT", 8, 0)
    y = y - 40

    ---------------------------------------------------------------------
    Section("Controller Friendly")
    Place(GUI:CreateFormCheckbox(tabContent, "Keep action bars always visible (no mouseover fade)", "keepBarsVisible", cfg, function()
        handheld.ApplyBars()
    end))
    Info("A controller has no mouse hover, so faded bars would stay invisible. Your previous fade setting is restored when Handheld Mode is turned off.", 32)
    Place(GUI:CreateFormCheckbox(tabContent, "Fit this settings window to the screen", "fitOptionsWindow", cfg, function()
        handheld.FitOptionsWindow()
    end))

    Place(GUI:CreateFormCheckbox(tabContent, "Keep the ring under your target (controller modes)", "targetRing", cfg, function()
        local hh = _G.H3z0UI_Handheld
        if hh and hh.EnsureTargetRing then hh.EnsureTargetRing() end
    end))
    Place(GUI:CreateFormCheckbox(tabContent, "Use the Steam Deck HUD layout (unit frames)", "deckUnitFrames", cfg, function()
        handheld.ApplyUnitFrames()
    end))
    Info("While Handheld Mode is on, the unit frames use the Steam Deck HUD layout: player portrait + name bar at the top left, wide target bar at the top centre (name, %, portrait), your power bar under the character at the bottom centre, small focus / target-of-target / pet bars. Your own settings are restored when it is turned off. Switching frames or castbars on/off needs a /reload.", 44)

    ---------------------------------------------------------------------
    Section("Quick Setup")
    local preset = GUI:CreateButton(tabContent, "Apply Steam Deck Preset", 220, 28, function()
        handheld.ApplyPreset()
        Rebuild()
    end)
    preset:SetPoint("TOPLEFT", PADDING, y)
    local setupBtn = GUI:CreateButton(tabContent, "Open Setup Window", 180, 28, function()
        handheld.ShowSetupPopup()
    end)
    setupBtn:SetPoint("LEFT", preset, "RIGHT", 10, 0)
    y = y - 40
    Info("Toggle anytime in chat with  /h3z0ui deck.  On a 1280x800 screen a setup window offers this preset on first launch (/h3z0ui deck setup opens it again).", 32)

    ---------------------------------------------------------------------
    Section("ConsolePort")
    Info("ConsolePort is the controller addon most Steam Deck players use. Handheld Mode does not change ConsolePort itself - " ..
         "set up its bar and bindings inside ConsolePort. H3z0 UI just keeps its own bars visible and sized for the Deck's screen.", 44)
    Info("Tip: in Steam Input, the 'Gamepad with Mouse' template + ConsolePort works well. Tell me if anything overlaps and I'll adjust it.", 32)

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_HandheldOptions = {
    BuildHandheldTab = Build,
}
