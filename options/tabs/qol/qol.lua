--[[
    H3z0UI QoL Options - General Tab
    BuildGeneralTab for General & QoL page
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local H3z0UICore = ns.Addon
local C = GUI.Colors

-- Import shared utilities
local Shared = ns.H3z0UI_Options

local function BuildGeneralTab(tabContent)
    local y = -10
    local FORM_ROW = 32
    local PADDING = Shared.PADDING
    local db = Shared.GetDB()

    -- Refresh callback for fonts/textures (refreshes everything that uses these defaults)
    local function RefreshAll()
        -- Refresh core CDM viewers
        if H3z0UICore and H3z0UICore.RefreshAll then
            H3z0UICore:RefreshAll()
        end
        -- Refresh unit frames (use global function)
        if _G.H3z0UI_RefreshUnitFrames then
            _G.H3z0UI_RefreshUnitFrames()
        end
        -- Refresh power bars (recreate to apply new fonts/textures)
        if H3z0UICore then
            if H3z0UICore.UpdatePowerBar then
                H3z0UICore:UpdatePowerBar()
            end
            if H3z0UICore.UpdateSecondaryPowerBar then
                H3z0UICore:UpdateSecondaryPowerBar()
            end
        end
        -- Refresh minimap/datatext
        if H3z0UICore and H3z0UICore.Minimap and H3z0UICore.Minimap.Refresh then
            H3z0UICore.Minimap:Refresh()
        end
        -- Refresh buff borders
        if _G.H3z0UI_RefreshBuffBorders then
            _G.H3z0UI_RefreshBuffBorders()
        end
        -- Refresh NCDM (CDM icons)
        if ns and ns.NCDM and ns.NCDM.RefreshAll then
            ns.NCDM:RefreshAll()
        end
        -- Trigger CDM layout refresh
        C_Timer.After(0.1, function()
            if H3z0UICore and H3z0UICore.ApplyViewerLayout then
                H3z0UICore:ApplyViewerLayout("EssentialCooldownViewer")
                H3z0UICore:ApplyViewerLayout("UtilityCooldownViewer")
            end
        end)
    end

    -- Set search context for auto-registration
    GUI:SetSearchContext({tabIndex = 3, tabName = "General & QoL", subTabIndex = 1, subTabName = "General"})

    -- UI Scale Section
    GUI:SetSearchSection("UI Scale")
    local scaleHeader = GUI:CreateSectionHeader(tabContent, "UI Scale")
    scaleHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - scaleHeader.gap

    if db and db.general then
        local scaleSlider = GUI:CreateFormSlider(tabContent, "Global UI Scale", 0.3, 2.0, 0.01,
            "uiScale", db.general, function(val)
                pcall(function() UIParent:SetScale(val) end)
            end, { deferOnDrag = true, precision = 7 })
        scaleSlider:SetPoint("TOPLEFT", PADDING, y)
        scaleSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Quick preset buttons
        local presetLabel = GUI:CreateLabel(tabContent, "Quick UI Scale Presets:", 12, C.text)
        presetLabel:SetPoint("TOPLEFT", PADDING, y)

        local function ApplyPreset(val, name)
            db.general.uiScale = val
            pcall(function() UIParent:SetScale(val) end)
            local msg = "|cff34D399[H3z0 UI]|r UI scale set to " .. val
            if name then msg = msg .. " (" .. name .. ")" end
            DEFAULT_CHAT_FRAME:AddMessage(msg)
            scaleSlider.SetValue(val, true)
        end

        local function AutoScale()
            local _, height = GetPhysicalScreenSize()
            local scale = 768 / height
            scale = math.max(0.3, math.min(2.0, scale))
            ApplyPreset(scale, "Auto")
        end

        -- Button container aligned with slider track (180px) to editbox right edge
        local buttonContainer = CreateFrame("Frame", nil, tabContent)
        buttonContainer:SetPoint("LEFT", scaleSlider, "LEFT", (GUI.FORM_CONTROL_X or 232), 0)
        buttonContainer:SetPoint("RIGHT", scaleSlider, "RIGHT", 0, 0)
        buttonContainer:SetPoint("TOP", presetLabel, "TOP", 0, 0)
        buttonContainer:SetHeight(26)

        local BUTTON_GAP = 6
        local NUM_BUTTONS = 5
        local buttons = {}

        -- Create buttons with placeholder width (will be set dynamically)
        buttons[1] = GUI:CreateButton(buttonContainer, "1080p", 50, 26, function() ApplyPreset(0.7111111, "1080p") end)
        buttons[2] = GUI:CreateButton(buttonContainer, "1440p", 50, 26, function() ApplyPreset(0.5333333, "1440p") end)
        buttons[3] = GUI:CreateButton(buttonContainer, "1440p+", 50, 26, function() ApplyPreset(0.64, "1440p+") end)
        buttons[4] = GUI:CreateButton(buttonContainer, "4K", 50, 26, function() ApplyPreset(0.3555556, "4K") end)
        buttons[5] = GUI:CreateButton(buttonContainer, "Auto", 50, 26, AutoScale)

        -- Dynamically size and position buttons when container width is known
        buttonContainer:SetScript("OnSizeChanged", function(self, width)
            if width and width > 0 then
                local buttonWidth = (width - (NUM_BUTTONS - 1) * BUTTON_GAP) / NUM_BUTTONS
                for i, btn in ipairs(buttons) do
                    btn:SetWidth(buttonWidth)
                    btn:ClearAllPoints()
                    if i == 1 then
                        btn:SetPoint("LEFT", self, "LEFT", 0, 0)
                    else
                        btn:SetPoint("LEFT", buttons[i-1], "RIGHT", BUTTON_GAP, 0)
                    end
                end
            end
        end)

        -- Tooltip data for preset buttons
        local tooltipData = {
            { title = "1080p", desc = "Scale: 0.7111111\nPixel-perfect for 1920x1080" },
            { title = "1440p", desc = "Scale: 0.5333333\nPixel-perfect for 2560x1440" },
            { title = "1440p+", desc = "Scale: 0.64\nH3z0UI's personal setting - larger and more readable.\nRequires manual adjustment for pixel perfection." },
            { title = "4K", desc = "Scale: 0.3555556\nPixel-perfect for 3840x2160" },
            { title = "Auto", desc = "Computes pixel-perfect scale based on your resolution.\nFormula: 768 / screen height" },
        }

        -- Add tooltips to buttons
        for i, btn in ipairs(buttons) do
            local data = tooltipData[i]
            btn:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(data.title, 1, 1, 1)
                GameTooltip:AddLine(data.desc, 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            btn:HookScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end

        y = y - FORM_ROW - 6

        -- Single summary line
        local presetSummary = GUI:CreateLabel(tabContent,
            "Hover over any preset for details. 1440p+ is H3z0 UI's personal setting.",
            11, C.textMuted)
        presetSummary:SetPoint("TOPLEFT", PADDING, y)
        y = y - 20

        -- Big picture advice
        local bigPicture = GUI:CreateLabel(tabContent,
            "UI scale is highly personal-it depends on your monitor size, resolution, and preference. If you already have a scale you like from years of playing WoW, stick with it. These presets are just common values people tend to use.",
            11, C.textMuted)
        bigPicture:SetPoint("TOPLEFT", PADDING, y)
        bigPicture:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        bigPicture:SetJustifyH("LEFT")
        y = y - 36
    end

    -- Default Font Section
    GUI:SetSearchSection("Default Font Settings")
    local fontTexHeader = GUI:CreateSectionHeader(tabContent, "Default Font Settings")
    fontTexHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - fontTexHeader.gap

    local tipText = GUI:CreateLabel(tabContent, "These settings apply throughout the UI. Individual elements with their own font options will override these defaults.", 11, C.textMuted)
    tipText:SetPoint("TOPLEFT", PADDING, y)
    tipText:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    tipText:SetJustifyH("LEFT")
    y = y - 28

    if db and db.general then
        local fontList = {}
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM then
            for name in pairs(LSM:HashTable("font")) do
                table.insert(fontList, {value = name, text = name})
            end
            table.sort(fontList, function(a, b) return a.text < b.text end)
        else
            fontList = {{value = "Friz Quadrata TT", text = "Friz Quadrata TT"}}
        end

        -- picking the default font puts it on everything (every element's own font too)
        local function UseEverywhere(quiet)
            local core = ns.Addon
            if not (core and core.SetAllFonts) then return end
            local n = core:SetAllFonts(db.general.font)
            if core.ApplyGlobalFont then pcall(core.ApplyGlobalFont, core) end
            RefreshAll()
            if _G.H3z0UI_RefreshPlates then pcall(_G.H3z0UI_RefreshPlates) end
            if ns.ShowPopup then
                ns.ShowPopup("H3Z0UI_FONT_RELOAD", db.general.font)
            elseif not quiet then
                print("|cff34D399H3z0 UI:|r " .. db.general.font .. " is now used everywhere (" .. (n or 0) .. " settings). /reload to update every frame.")
            end
        end
        ns.Popups["H3Z0UI_FONT_RELOAD"] = {
            text = "%s is now the font of all of H3z0 UI.\n\nReload now so every frame, bar and Blizzard window picks it up?",
            button1 = "Reload",
            button2 = "Later",
            OnAccept = function()
                local ui = _G.H3z0UI
                if ui and ui.SafeReload then ui:SafeReload() else ReloadUI() end
            end,
        }
        local fontDropdown = GUI:CreateFormDropdown(tabContent, "Default Font", fontList, "font", db.general, function() UseEverywhere() end)
        fontDropdown:SetPoint("TOPLEFT", PADDING, y)
        fontDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local everywhereBtn = GUI:CreateButton(tabContent, "Use this font everywhere", 200, 26, function() UseEverywhere() end)
        everywhereBtn:SetPoint("TOPLEFT", PADDING, y)
        local ewTip = GUI:CreateLabel(tabContent, "Picking a font above already does this; use the button if you changed single elements later.", 10, C.textMuted)
        ewTip:SetPoint("LEFT", everywhereBtn, "RIGHT", 10, 0)
        y = y - 36

        local outlineOptions = {
            {value = "", text = "None"},
            {value = "OUTLINE", text = "Outline"},
            {value = "THICKOUTLINE", text = "Thick Outline"},
        }
        local outlineDropdown = GUI:CreateFormDropdown(tabContent, "Font Outline", outlineOptions, "fontOutline", db.general, RefreshAll)
        outlineDropdown:SetPoint("TOPLEFT", PADDING, y)
        outlineDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    y = y - 10

    -- H3z0UI Recommended FPS Settings Section
    local fpsHeader = GUI:CreateSectionHeader(tabContent, "H3z0 UI Recommended FPS Settings")
    fpsHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - fpsHeader.gap

    local fpsDesc = GUI:CreateLabel(tabContent,
        "Apply H3z0 UI's optimized graphics settings for competitive play. " ..
        "Your current settings are automatically saved when you click Apply - use 'Restore Previous Settings' to revert anytime. " ..
        "Caution: Clicking Apply again will overwrite your backup with these settings.",
        11, C.textMuted)
    fpsDesc:SetPoint("TOPLEFT", PADDING, y)
    fpsDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    fpsDesc:SetJustifyH("LEFT")
    fpsDesc:SetWordWrap(true)
    fpsDesc:SetHeight(30)
    y = y - 40

    local restoreFpsBtn
    local fpsStatusText

    local function UpdateFPSStatus()
        local allMatch, matched, total = Shared.CheckCVarsMatch()
        -- Some CVars can't be verified (protected/restart required), so threshold at 50+
        if matched >= 50 then
            fpsStatusText:SetText("Settings: All applied")
            fpsStatusText:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
        else
            fpsStatusText:SetText(string.format("Settings: %d/%d match", matched, total))
            fpsStatusText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
        end
    end

    local applyFpsBtn = GUI:CreateButton(tabContent, "Apply FPS Settings", 180, 28, function()
        Shared.ApplyH3z0UIFPSSettings()
        restoreFpsBtn:SetAlpha(1)
        restoreFpsBtn:Enable()
        UpdateFPSStatus()
    end)
    applyFpsBtn:SetPoint("TOPLEFT", PADDING, y)
    applyFpsBtn:SetPoint("RIGHT", tabContent, "CENTER", -5, 0)

    restoreFpsBtn = GUI:CreateButton(tabContent, "Restore Previous Settings", 180, 28, function()
        if Shared.RestorePreviousFPSSettings() then
            restoreFpsBtn:SetAlpha(0.5)
            restoreFpsBtn:Disable()
        end
        UpdateFPSStatus()
    end)
    restoreFpsBtn:SetPoint("LEFT", tabContent, "CENTER", 5, 0)
    restoreFpsBtn:SetPoint("TOP", applyFpsBtn, "TOP", 0, 0)
    restoreFpsBtn:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - 38

    fpsStatusText = GUI:CreateLabel(tabContent, "", 11, C.accent)
    fpsStatusText:SetPoint("TOPLEFT", PADDING, y)

    if not db.fpsBackup then
        restoreFpsBtn:SetAlpha(0.5)
        restoreFpsBtn:Disable()
    end

    UpdateFPSStatus()

    y = y - 22

    -- Combat Status Text Indicator Section
    local combatTextHeader = GUI:CreateSectionHeader(tabContent, "Combat Status Text Indicator")
    combatTextHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - combatTextHeader.gap

    local combatTextDesc = GUI:CreateLabel(tabContent,
        "Displays '+Combat' or '-Combat' text on screen when entering or leaving combat. Useful for Shadowmeld skips.",
        11, C.textMuted)
    combatTextDesc:SetPoint("TOPLEFT", PADDING, y)
    combatTextDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    combatTextDesc:SetJustifyH("LEFT")
    combatTextDesc:SetWordWrap(true)
    combatTextDesc:SetHeight(15)
    y = y - 25

    -- Preview buttons
    local previewEnterBtn = GUI:CreateButton(tabContent, "Preview +Combat", 140, 28, function()
        if _G.H3z0UI_PreviewCombatText then _G.H3z0UI_PreviewCombatText("+Combat") end
    end)
    previewEnterBtn:SetPoint("TOPLEFT", PADDING, y)
    previewEnterBtn:SetPoint("RIGHT", tabContent, "CENTER", -5, 0)

    local previewLeaveBtn = GUI:CreateButton(tabContent, "Preview -Combat", 140, 28, function()
        if _G.H3z0UI_PreviewCombatText then _G.H3z0UI_PreviewCombatText("-Combat") end
    end)
    previewLeaveBtn:SetPoint("LEFT", tabContent, "CENTER", 5, 0)
    previewLeaveBtn:SetPoint("TOP", previewEnterBtn, "TOP", 0, 0)
    previewLeaveBtn:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - 38

    local combatTextDB = db and db.combatText
    if combatTextDB then
        local combatTextCheck = GUI:CreateFormCheckbox(tabContent, "Enable Combat Text", "enabled", combatTextDB, function(val)
            if _G.H3z0UI_RefreshCombatText then _G.H3z0UI_RefreshCombatText() end
        end)
        combatTextCheck:SetPoint("TOPLEFT", PADDING, y)
        combatTextCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local displayTimeSlider = GUI:CreateFormSlider(tabContent, "Display Time (sec)", 0.3, 3.0, 0.1, "displayTime", combatTextDB, function()
            if _G.H3z0UI_RefreshCombatText then _G.H3z0UI_RefreshCombatText() end
        end)
        displayTimeSlider:SetPoint("TOPLEFT", PADDING, y)
        displayTimeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local fadeTimeSlider = GUI:CreateFormSlider(tabContent, "Fade Duration (sec)", 0.1, 1.0, 0.05, "fadeTime", combatTextDB, function()
            if _G.H3z0UI_RefreshCombatText then _G.H3z0UI_RefreshCombatText() end
        end)
        fadeTimeSlider:SetPoint("TOPLEFT", PADDING, y)
        fadeTimeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local fontSizeSlider = GUI:CreateFormSlider(tabContent, "Font Size", 12, 48, 1, "fontSize", combatTextDB, function()
            if _G.H3z0UI_RefreshCombatText then _G.H3z0UI_RefreshCombatText() end
        end)
        fontSizeSlider:SetPoint("TOPLEFT", PADDING, y)
        fontSizeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local xOffsetSlider = GUI:CreateFormSlider(tabContent, "X Position Offset", -2000, 2000, 1, "xOffset", combatTextDB, function()
            if _G.H3z0UI_RefreshCombatText then _G.H3z0UI_RefreshCombatText() end
        end)
        xOffsetSlider:SetPoint("TOPLEFT", PADDING, y)
        xOffsetSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local yOffsetSlider = GUI:CreateFormSlider(tabContent, "Y Position Offset", -2000, 2000, 1, "yOffset", combatTextDB, function()
            if _G.H3z0UI_RefreshCombatText then _G.H3z0UI_RefreshCombatText() end
        end)
        yOffsetSlider:SetPoint("TOPLEFT", PADDING, y)
        yOffsetSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local enterColorPicker = GUI:CreateFormColorPicker(tabContent, "+Combat Text Color", "enterCombatColor", combatTextDB, function()
            if _G.H3z0UI_RefreshCombatText then _G.H3z0UI_RefreshCombatText() end
        end)
        enterColorPicker:SetPoint("TOPLEFT", PADDING, y)
        enterColorPicker:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local leaveColorPicker = GUI:CreateFormColorPicker(tabContent, "-Combat Text Color", "leaveCombatColor", combatTextDB, function()
            if _G.H3z0UI_RefreshCombatText then _G.H3z0UI_RefreshCombatText() end
        end)
        leaveColorPicker:SetPoint("TOPLEFT", PADDING, y)
        leaveColorPicker:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    y = y - 10

    -- Combat Timer Section
    local combatTimerHeader = GUI:CreateSectionHeader(tabContent, "Combat Timer")
    combatTimerHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - combatTimerHeader.gap

    local combatTimerDesc = GUI:CreateLabel(tabContent,
        "Displays elapsed combat time. Timer resets each time you leave combat.",
        11, C.textMuted)
    combatTimerDesc:SetPoint("TOPLEFT", PADDING, y)
    combatTimerDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    combatTimerDesc:SetJustifyH("LEFT")
    combatTimerDesc:SetWordWrap(true)
    combatTimerDesc:SetHeight(15)
    y = y - 25

    local combatTimerDB = db and db.combatTimer
    if combatTimerDB then
        local combatTimerCheck = GUI:CreateFormCheckbox(tabContent, "Enable Combat Timer", "enabled", combatTimerDB, function(val)
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        combatTimerCheck:SetPoint("TOPLEFT", PADDING, y)
        combatTimerCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Encounters-only mode toggle
        local encountersOnlyCheck = GUI:CreateFormCheckbox(tabContent, "Only Show In Encounters", "onlyShowInEncounters", combatTimerDB, function(val)
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        encountersOnlyCheck:SetPoint("TOPLEFT", PADDING, y)
        encountersOnlyCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Preview toggle
        local previewState = { enabled = _G.H3z0UI_IsCombatTimerPreviewMode and _G.H3z0UI_IsCombatTimerPreviewMode() or false }
        local previewCheck = GUI:CreateFormCheckbox(tabContent, "Preview Combat Timer", "enabled", previewState, function(val)
            if _G.H3z0UI_ToggleCombatTimerPreview then
                _G.H3z0UI_ToggleCombatTimerPreview(val)
            end
        end)
        previewCheck:SetPoint("TOPLEFT", PADDING, y)
        previewCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Frame size settings
        local timerWidthSlider = GUI:CreateFormSlider(tabContent, "Frame Width", 40, 200, 1, "width", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        timerWidthSlider:SetPoint("TOPLEFT", PADDING, y)
        timerWidthSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local timerHeightSlider = GUI:CreateFormSlider(tabContent, "Frame Height", 20, 100, 1, "height", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        timerHeightSlider:SetPoint("TOPLEFT", PADDING, y)
        timerHeightSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local timerFontSizeSlider = GUI:CreateFormSlider(tabContent, "Font Size", 12, 32, 1, "fontSize", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        timerFontSizeSlider:SetPoint("TOPLEFT", PADDING, y)
        timerFontSizeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local timerXOffsetSlider = GUI:CreateFormSlider(tabContent, "X Position Offset", -2000, 2000, 1, "xOffset", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        timerXOffsetSlider:SetPoint("TOPLEFT", PADDING, y)
        timerXOffsetSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local timerYOffsetSlider = GUI:CreateFormSlider(tabContent, "Y Position Offset", -2000, 2000, 1, "yOffset", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        timerYOffsetSlider:SetPoint("TOPLEFT", PADDING, y)
        timerYOffsetSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Text color with class color toggle
        local timerColorPicker  -- Forward declare

        local useClassColorTextCheck = GUI:CreateFormCheckbox(tabContent, "Use Class Color for Text", "useClassColorText", combatTimerDB, function(val)
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
            -- Enable/disable text color picker based on toggle
            if timerColorPicker and timerColorPicker.SetEnabled then
                timerColorPicker:SetEnabled(not val)
            end
        end)
        useClassColorTextCheck:SetPoint("TOPLEFT", PADDING, y)
        useClassColorTextCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        timerColorPicker = GUI:CreateFormColorPicker(tabContent, "Timer Text Color", "textColor", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        timerColorPicker:SetPoint("TOPLEFT", PADDING, y)
        timerColorPicker:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        -- Initial state based on setting
        if timerColorPicker.SetEnabled then
            timerColorPicker:SetEnabled(not combatTimerDB.useClassColorText)
        end
        y = y - FORM_ROW

        -- Font selection with custom toggle
        local fontList = Shared.GetFontList()
        local timerFontDropdown  -- Forward declare

        local useCustomFontCheck = GUI:CreateFormCheckbox(tabContent, "Use Custom Font", "useCustomFont", combatTimerDB, function(val)
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
            -- Enable/disable font dropdown based on toggle
            if timerFontDropdown and timerFontDropdown.SetEnabled then
                timerFontDropdown:SetEnabled(val)
            end
        end)
        useCustomFontCheck:SetPoint("TOPLEFT", PADDING, y)
        useCustomFontCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        timerFontDropdown = GUI:CreateFormDropdown(tabContent, "Font", fontList, "font", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        timerFontDropdown:SetPoint("TOPLEFT", PADDING, y)
        timerFontDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        -- Initial state based on setting
        if timerFontDropdown.SetEnabled then
            timerFontDropdown:SetEnabled(combatTimerDB.useCustomFont == true)
        end
        y = y - FORM_ROW

        -- Backdrop settings
        local backdropCheck = GUI:CreateFormCheckbox(tabContent, "Show Backdrop", "showBackdrop", combatTimerDB, function(val)
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        backdropCheck:SetPoint("TOPLEFT", PADDING, y)
        backdropCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local backdropColorPicker = GUI:CreateFormColorPicker(tabContent, "Backdrop Color", "backdropColor", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        backdropColorPicker:SetPoint("TOPLEFT", PADDING, y)
        backdropColorPicker:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Border settings
        -- Normalize mutually exclusive flags on load (prefer class color)
        if combatTimerDB.useClassColorBorder and combatTimerDB.useAccentColorBorder then
            combatTimerDB.useAccentColorBorder = false
        end

        local borderSizeSlider, borderTextureDropdown, useClassColorCheck, useAccentColorCheck, borderColorPicker

        local function UpdateBorderControlsEnabled(enabled)
            if borderSizeSlider and borderSizeSlider.SetEnabled then borderSizeSlider:SetEnabled(enabled) end
            if borderTextureDropdown and borderTextureDropdown.SetEnabled then borderTextureDropdown:SetEnabled(enabled) end
            if useClassColorCheck and useClassColorCheck.SetEnabled then useClassColorCheck:SetEnabled(enabled) end
            if useAccentColorCheck and useAccentColorCheck.SetEnabled then useAccentColorCheck:SetEnabled(enabled) end
            if borderColorPicker and borderColorPicker.SetEnabled then
                borderColorPicker:SetEnabled(enabled and not combatTimerDB.useClassColorBorder and not combatTimerDB.useAccentColorBorder)
            end
        end

        local hideBorderCheck = GUI:CreateFormCheckbox(tabContent, "Hide Border", "hideBorder", combatTimerDB, function(val)
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
            UpdateBorderControlsEnabled(not val)
        end)
        hideBorderCheck:SetPoint("TOPLEFT", PADDING, y)
        hideBorderCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        borderSizeSlider = GUI:CreateFormSlider(tabContent, "Border Size", 1, 5, 0.5, "borderSize", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        borderSizeSlider:SetPoint("TOPLEFT", PADDING, y)
        borderSizeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local borderList = Shared.GetBorderList()
        borderTextureDropdown = GUI:CreateFormDropdown(tabContent, "Border Texture", borderList, "borderTexture", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        borderTextureDropdown:SetPoint("TOPLEFT", PADDING, y)
        borderTextureDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        useClassColorCheck = GUI:CreateFormCheckbox(tabContent, "Use Class Color for Border", "useClassColorBorder", combatTimerDB, function(val)
            if val then
                combatTimerDB.useAccentColorBorder = false
                if useAccentColorCheck and useAccentColorCheck.SetValue then useAccentColorCheck:SetValue(false, true) end
            end
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
            if borderColorPicker and borderColorPicker.SetEnabled then
                borderColorPicker:SetEnabled(not val and not combatTimerDB.useAccentColorBorder and not combatTimerDB.hideBorder)
            end
        end)
        useClassColorCheck:SetPoint("TOPLEFT", PADDING, y)
        useClassColorCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        useAccentColorCheck = GUI:CreateFormCheckbox(tabContent, "Use Accent Color for Border", "useAccentColorBorder", combatTimerDB, function(val)
            if val then
                combatTimerDB.useClassColorBorder = false
                if useClassColorCheck and useClassColorCheck.SetValue then useClassColorCheck:SetValue(false, true) end
            end
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
            if borderColorPicker and borderColorPicker.SetEnabled then
                borderColorPicker:SetEnabled(not val and not combatTimerDB.useClassColorBorder and not combatTimerDB.hideBorder)
            end
        end)
        useAccentColorCheck:SetPoint("TOPLEFT", PADDING, y)
        useAccentColorCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        borderColorPicker = GUI:CreateFormColorPicker(tabContent, "Border Color", "borderColor", combatTimerDB, function()
            if _G.H3z0UI_RefreshCombatTimer then _G.H3z0UI_RefreshCombatTimer() end
        end)
        borderColorPicker:SetPoint("TOPLEFT", PADDING, y)
        borderColorPicker:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Apply initial border control states
        UpdateBorderControlsEnabled(not combatTimerDB.hideBorder)
    end

    y = y - 10

    -- QoL Automation Section
    GUI:SetSearchSection("Automation")
    local autoHeader = GUI:CreateSectionHeader(tabContent, "Automation")
    autoHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - autoHeader.gap

    local autoDesc = GUI:CreateLabel(tabContent,
        "Toggle quality-of-life automation features. These run silently in the background.",
        11, C.textMuted)
    autoDesc:SetPoint("TOPLEFT", PADDING, y)
    autoDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    autoDesc:SetJustifyH("LEFT")
    autoDesc:SetWordWrap(true)
    autoDesc:SetHeight(15)
    y = y - 25

    local generalDB = db and db.general
    if generalDB then
        -- Sell Junk
        local sellJunkCheck = GUI:CreateFormCheckbox(tabContent, "Sell Junk Items at Vendors", "sellJunk", generalDB)
        sellJunkCheck:SetPoint("TOPLEFT", PADDING, y)
        sellJunkCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Auto Repair
        local repairOptions = {
            {value = "off", text = "Off"},
            {value = "personal", text = "Personal Gold"},
            {value = "guild", text = "Guild Bank (fallback to personal)"},
        }
        local autoRepairDropdown = GUI:CreateFormDropdown(tabContent, "Auto Repair at Vendors", repairOptions, "autoRepair", generalDB)
        autoRepairDropdown:SetPoint("TOPLEFT", PADDING, y)
        autoRepairDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Fast Auto Loot
        local fastLootCheck = GUI:CreateFormCheckbox(tabContent, "Fast Auto Loot", "fastAutoLoot", generalDB)
        fastLootCheck:SetPoint("TOPLEFT", PADDING, y)
        fastLootCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Auto Accept Party Invites
        local inviteOptions = {
            {value = "off", text = "Off"},
            {value = "all", text = "Everyone"},
            {value = "friends", text = "Friends & BNet Only"},
            {value = "guild", text = "Guild Members Only"},
            {value = "both", text = "Friends & Guild"},
        }
        local autoInviteDropdown = GUI:CreateFormDropdown(tabContent, "Auto Accept Party Invites", inviteOptions, "autoAcceptInvites", generalDB)
        autoInviteDropdown:SetPoint("TOPLEFT", PADDING, y)
        autoInviteDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Auto Role Accept
        local autoRoleCheck = GUI:CreateFormCheckbox(tabContent, "Auto Accept Role Check", "autoRoleAccept", generalDB)
        autoRoleCheck:SetPoint("TOPLEFT", PADDING, y)
        autoRoleCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Auto Accept Quests
        local autoQuestCheck = GUI:CreateFormCheckbox(tabContent, "Auto Accept Quests", "autoAcceptQuest", generalDB)
        autoQuestCheck:SetPoint("TOPLEFT", PADDING, y)
        autoQuestCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Auto Turn-In Quests
        local autoTurnInCheck = GUI:CreateFormCheckbox(tabContent, "Auto Turn-In Quests", "autoTurnInQuest", generalDB)
        autoTurnInCheck:SetPoint("TOPLEFT", PADDING, y)
        autoTurnInCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Auto Select Gossip
        local autoGossipCheck = GUI:CreateFormCheckbox(tabContent, "Auto Select Single Gossip Option", "autoSelectGossip", generalDB)
        autoGossipCheck:SetPoint("TOPLEFT", PADDING, y)
        autoGossipCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Hold Shift to Pause
        local shiftPauseCheck = GUI:CreateFormCheckbox(tabContent, "Hold Shift to Pause Quest/Gossip Automation", "questHoldShift", generalDB)
        shiftPauseCheck:SetPoint("TOPLEFT", PADDING, y)
        shiftPauseCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Auto Insert M+ Keys
        local autoInsertKeyCheck = GUI:CreateFormCheckbox(tabContent, "Auto Insert M+ Keys", "autoInsertKey", generalDB)
        autoInsertKeyCheck:SetPoint("TOPLEFT", PADDING, y)
        autoInsertKeyCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Auto Combat Log in M+
        local autoCombatLogCheck = GUI:CreateFormCheckbox(tabContent, "Auto Combat Log in M+", "autoCombatLog", generalDB)
        autoCombatLogCheck:SetPoint("TOPLEFT", PADDING, y)
        autoCombatLogCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- M+ Dungeon Teleport
        local mplusTeleportCheck = GUI:CreateFormCheckbox(tabContent, "Click-to-Teleport on M+ Tab", "mplusTeleportEnabled", generalDB)
        mplusTeleportCheck:SetPoint("TOPLEFT", PADDING, y)
        mplusTeleportCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Auto Delete Confirmation
        local autoDeleteCheck = GUI:CreateFormCheckbox(tabContent, "Auto-Fill DELETE Text (can block Item Upgrade popups)", "autoDeleteConfirm", generalDB)
        autoDeleteCheck:SetPoint("TOPLEFT", PADDING, y)
        autoDeleteCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    y = y - 10

    -- Quick Salvage Section
    GUI:SetSearchSection("Quick Salvage")
    local quickSalvageHeader = GUI:CreateSectionHeader(tabContent, "Quick Salvage")
    quickSalvageHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - quickSalvageHeader.gap

    local quickSalvageDesc = GUI:CreateLabel(tabContent,
        "Mill, prospect, or disenchant items with a single click using a modifier key. Requires the corresponding profession.",
        11, C.textMuted)
    quickSalvageDesc:SetPoint("TOPLEFT", PADDING, y)
    quickSalvageDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    quickSalvageDesc:SetJustifyH("LEFT")
    quickSalvageDesc:SetWordWrap(true)
    quickSalvageDesc:SetHeight(20)
    y = y - 30

    local qsDB = db and db.general and db.general.quickSalvage
    if qsDB then
        local qsEnableCheck = GUI:CreateFormCheckbox(tabContent, "Enable Quick Salvage", "enabled", qsDB, function()
            if _G.H3z0UI_RefreshQuickSalvage then _G.H3z0UI_RefreshQuickSalvage() end
        end)
        qsEnableCheck:SetPoint("TOPLEFT", PADDING, y)
        qsEnableCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local modifierOptions = {
            {value = "ALT", text = "Alt"},
            {value = "ALTCTRL", text = "Alt + Ctrl"},
            {value = "ALTSHIFT", text = "Alt + Shift"},
        }
        local qsModifierDropdown = GUI:CreateFormDropdown(tabContent, "Modifier Key", modifierOptions, "modifier", qsDB, function()
            if _G.H3z0UI_RefreshQuickSalvage then _G.H3z0UI_RefreshQuickSalvage() end
        end)
        qsModifierDropdown:SetPoint("TOPLEFT", PADDING, y)
        qsModifierDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local qsActionsDesc = GUI:CreateLabel(tabContent,
            "Milling: Herbs (5+ stack)  |  Prospecting: Ores (5+ stack)  |  Disenchanting: Green+ gear",
            11, C.textMuted)
        qsActionsDesc:SetPoint("TOPLEFT", PADDING, y)
        qsActionsDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        qsActionsDesc:SetJustifyH("LEFT")
        qsActionsDesc:SetWordWrap(true)
        qsActionsDesc:SetHeight(20)
        y = y - 30
    end

    y = y - 10

    -- Pet Warning Section
    GUI:SetSearchSection("Pet Warning")
    local petWarningHeader = GUI:CreateSectionHeader(tabContent, "Pet Warning")
    petWarningHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - petWarningHeader.gap

    local petWarningIntro = GUI:CreateLabel(tabContent, "Warn pet class players (Hunter, Warlock, DK, Frost Mage) when pet is missing or on passive during combat in instances.", 11, C.textMuted)
    petWarningIntro:SetPoint("TOPLEFT", PADDING, y)
    petWarningIntro:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    petWarningIntro:SetJustifyH("LEFT")
    petWarningIntro:SetWordWrap(true)
    petWarningIntro:SetHeight(20)
    y = y - 30

    if generalDB then
        local petCombatCheck = GUI:CreateFormCheckbox(tabContent, "Show Combat Warning in Instances", "petCombatWarning", generalDB)
        petCombatCheck:SetPoint("TOPLEFT", PADDING, y)
        petCombatCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local petOffsetXSlider = GUI:CreateFormSlider(tabContent, "Horizontal Offset", -500, 500, 10, "petWarningOffsetX", generalDB, function()
            if _G.H3z0UI_RepositionPetWarning then _G.H3z0UI_RepositionPetWarning() end
        end)
        petOffsetXSlider:SetPoint("TOPLEFT", PADDING, y)
        petOffsetXSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local petOffsetYSlider = GUI:CreateFormSlider(tabContent, "Vertical Offset", -500, 500, 10, "petWarningOffsetY", generalDB, function()
            if _G.H3z0UI_RepositionPetWarning then _G.H3z0UI_RepositionPetWarning() end
        end)
        petOffsetYSlider:SetPoint("TOPLEFT", PADDING, y)
        petOffsetYSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Preview toggle button
        local petPreviewActive = false
        local petPreviewBtn = GUI:CreateButton(tabContent, "Show Preview", 140, 24)
        petPreviewBtn:SetPoint("TOPLEFT", PADDING, y)
        petPreviewBtn:SetScript("OnClick", function(self)
            petPreviewActive = not petPreviewActive
            if _G.H3z0UI_TogglePetWarningPreview then
                _G.H3z0UI_TogglePetWarningPreview(petPreviewActive)
            end
            self:SetText(petPreviewActive and "Hide Preview" or "Show Preview")
        end)

        -- Hide preview when leaving this tab
        local existingOnHide = tabContent:GetScript("OnHide")
        tabContent:SetScript("OnHide", function(self)
            if petPreviewActive and _G.H3z0UI_TogglePetWarningPreview then
                _G.H3z0UI_TogglePetWarningPreview(false)
                petPreviewActive = false
                petPreviewBtn:SetText("Show Preview")
            end
            if existingOnHide then existingOnHide(self) end
        end)
        y = y - 32
    end

    y = y - 10

    -- Consumable Check Section
    GUI:SetSearchSection("Consumable Check")
    local consumableHeader = GUI:CreateSectionHeader(tabContent, "Consumable Check")
    consumableHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - consumableHeader.gap

    local consumableDesc = GUI:CreateLabel(tabContent,
        "Display consumable status icons when triggered by events below. Click missing consumable icons to use them.",
        11, C.textMuted)
    consumableDesc:SetPoint("TOPLEFT", PADDING, y)
    consumableDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    consumableDesc:SetJustifyH("LEFT")
    consumableDesc:SetWordWrap(true)
    consumableDesc:SetHeight(20)
    y = y - 30

    if generalDB then
        local consumableEnableCheck = GUI:CreateFormCheckbox(tabContent, "Enable Consumable Check", "consumableCheckEnabled", generalDB)
        consumableEnableCheck:SetPoint("TOPLEFT", PADDING, y)
        consumableEnableCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Triggers sub-header
        local triggersLabel = GUI:CreateLabel(tabContent, "Triggers", 12, C.accent)
        triggersLabel:SetPoint("TOPLEFT", PADDING, y)
        y = y - 20

        local triggerReadyCheck = GUI:CreateFormCheckbox(tabContent, "Ready Check", "consumableOnReadyCheck", generalDB)
        triggerReadyCheck:SetPoint("TOPLEFT", PADDING + 20, y)
        triggerReadyCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local triggerDungeon = GUI:CreateFormCheckbox(tabContent, "Dungeon Entrance", "consumableOnDungeon", generalDB)
        triggerDungeon:SetPoint("TOPLEFT", PADDING + 20, y)
        triggerDungeon:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local triggerRaid = GUI:CreateFormCheckbox(tabContent, "Raid Entrance", "consumableOnRaid", generalDB)
        triggerRaid:SetPoint("TOPLEFT", PADDING + 20, y)
        triggerRaid:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local triggerResurrect = GUI:CreateFormCheckbox(tabContent, "Instanced Resurrect", "consumableOnResurrect", generalDB)
        triggerResurrect:SetPoint("TOPLEFT", PADDING + 20, y)
        triggerResurrect:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Buff Checks sub-header
        local buffsLabel = GUI:CreateLabel(tabContent, "Buff Checks", 12, C.accent)
        buffsLabel:SetPoint("TOPLEFT", PADDING, y)
        y = y - 20

        local consumableFoodCheck = GUI:CreateFormCheckbox(tabContent, "Food Buff", "consumableFood", generalDB)
        consumableFoodCheck:SetPoint("TOPLEFT", PADDING + 20, y)
        consumableFoodCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local consumableFlaskCheck = GUI:CreateFormCheckbox(tabContent, "Flask Buff", "consumableFlask", generalDB)
        consumableFlaskCheck:SetPoint("TOPLEFT", PADDING + 20, y)
        consumableFlaskCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local consumableOilMHCheck = GUI:CreateFormCheckbox(tabContent, "Weapon Oil (Main Hand)", "consumableOilMH", generalDB)
        consumableOilMHCheck:SetPoint("TOPLEFT", PADDING + 20, y)
        consumableOilMHCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local consumableOilOHCheck = GUI:CreateFormCheckbox(tabContent, "Weapon Oil (Off Hand)", "consumableOilOH", generalDB)
        consumableOilOHCheck:SetPoint("TOPLEFT", PADDING + 20, y)
        consumableOilOHCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local consumableRuneCheck = GUI:CreateFormCheckbox(tabContent, "Augment Rune", "consumableRune", generalDB)
        consumableRuneCheck:SetPoint("TOPLEFT", PADDING + 20, y)
        consumableRuneCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local consumableHSCheck = GUI:CreateFormCheckbox(tabContent, "Healthstones", "consumableHealthstone", generalDB)
        consumableHSCheck:SetPoint("TOPLEFT", PADDING + 20, y)
        consumableHSCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local consumableHSDesc = GUI:CreateLabel(tabContent, "Only shows when a Warlock is in the group.", 11, C.textMuted)
        consumableHSDesc:SetPoint("TOPLEFT", PADDING, y + 4)
        consumableHSDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        consumableHSDesc:SetJustifyH("LEFT")
        y = y - 20

        -- Expiration Warning sub-header
        local expirationLabel = GUI:CreateLabel(tabContent, "Expiration Warning", 12, C.accent)
        expirationLabel:SetPoint("TOPLEFT", PADDING, y)
        y = y - 20

        local expirationCheck = GUI:CreateFormCheckbox(tabContent, "Warn When Buffs Expiring", "consumableExpirationWarning", generalDB)
        expirationCheck:SetPoint("TOPLEFT", PADDING, y)
        expirationCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local expirationDesc = GUI:CreateLabel(tabContent, "Show consumables window when food/flask/rune is about to expire (instanced content only).", 11, C.textMuted)
        expirationDesc:SetPoint("TOPLEFT", PADDING, y + 4)
        expirationDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        expirationDesc:SetJustifyH("LEFT")
        expirationDesc:SetWordWrap(true)
        expirationDesc:SetHeight(20)
        y = y - 30

        local thresholdSlider = GUI:CreateFormSlider(tabContent, "Warning Threshold (seconds)", 60, 600, 30, "consumableExpirationThreshold", generalDB)
        thresholdSlider:SetPoint("TOPLEFT", PADDING, y)
        thresholdSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Positioning sub-header
        local positionLabel = GUI:CreateLabel(tabContent, "Positioning", 12, C.accent)
        positionLabel:SetPoint("TOPLEFT", PADDING, y)
        y = y - 20

        local function RefreshConsumables()
            if _G.H3z0UI_RefreshConsumables then _G.H3z0UI_RefreshConsumables() end
        end

        local function RepositionConsumables()
            if _G.H3z0UI_RepositionConsumables then _G.H3z0UI_RepositionConsumables() end
        end

        -- Forward declare for callback reference
        local iconOffsetSlider

        local anchorModeCheck = GUI:CreateFormCheckbox(tabContent, "Anchor to Ready Check", "consumableAnchorMode", generalDB, function()
            if iconOffsetSlider then
                iconOffsetSlider:SetEnabled(generalDB.consumableAnchorMode)
            end
            RepositionConsumables()
        end)
        anchorModeCheck:SetPoint("TOPLEFT", PADDING, y)
        anchorModeCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local anchorDesc = GUI:CreateLabel(tabContent, "When off, use 'Toggle Mover' to freely position the frame.", 11, C.textMuted)
        anchorDesc:SetPoint("TOPLEFT", PADDING, y + 4)
        anchorDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        anchorDesc:SetJustifyH("LEFT")
        y = y - 20

        local moverButton = GUI:CreateButton(tabContent, "Toggle Mover", 140, 24)
        moverButton:SetPoint("TOPLEFT", PADDING, y)
        moverButton:SetScript("OnClick", function()
            if _G.H3z0UI_ToggleConsumablesMover then _G.H3z0UI_ToggleConsumablesMover() end
        end)
        y = y - 32

        iconOffsetSlider = GUI:CreateFormSlider(tabContent, "Icon Offset", -10, 30, 1, "consumableIconOffset", generalDB, RepositionConsumables)
        iconOffsetSlider:SetPoint("TOPLEFT", PADDING, y)
        iconOffsetSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        iconOffsetSlider:SetEnabled(generalDB.consumableAnchorMode)
        y = y - FORM_ROW

        local iconSizeSlider = GUI:CreateFormSlider(tabContent, "Icon Size", 24, 64, 2, "consumableIconSize", generalDB, RefreshConsumables)
        iconSizeSlider:SetPoint("TOPLEFT", PADDING, y)
        iconSizeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Show/hide preview buttons
        local consumablePreviewActive = false
        local consumablePreviewBtn = GUI:CreateButton(tabContent, "Show Preview", 140, 24)
        consumablePreviewBtn:SetPoint("TOPLEFT", PADDING, y)
        consumablePreviewBtn:SetScript("OnClick", function(self)
            consumablePreviewActive = not consumablePreviewActive
            if consumablePreviewActive then
                if _G.H3z0UI_ShowConsumables then _G.H3z0UI_ShowConsumables() end
            else
                if _G.H3z0UI_HideConsumables then _G.H3z0UI_HideConsumables() end
            end
            self:SetText(consumablePreviewActive and "Hide Preview" or "Show Preview")
        end)

        -- Clean up preview when leaving tab
        local existingOnHideConsumable = tabContent:GetScript("OnHide")
        tabContent:SetScript("OnHide", function(self)
            if consumablePreviewActive and _G.H3z0UI_HideConsumables then
                _G.H3z0UI_HideConsumables()
                consumablePreviewActive = false
                consumablePreviewBtn:SetText("Show Preview")
            end
            if existingOnHideConsumable then existingOnHideConsumable(self) end
        end)
        y = y - 32
    end

    y = y - 10

    -- H3z0UI Panel Settings
    local panelHeader = GUI:CreateSectionHeader(tabContent, "H3z0 UI Panel Settings")
    panelHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - panelHeader.gap

    local minimapBtnDB = db and db.minimapButton
    if minimapBtnDB then
        local showMinimapIconCheck = GUI:CreateFormCheckbox(tabContent, "Hide H3z0 UI Minimap Icon", "hide", minimapBtnDB, function(dbVal)
            local LibDBIcon = LibStub("LibDBIcon-1.0", true)
            if LibDBIcon then
                if dbVal then
                    LibDBIcon:Hide("H3z0UI")
                else
                    LibDBIcon:Show("H3z0UI")
                end
            end
        end)
        showMinimapIconCheck:SetPoint("TOPLEFT", PADDING, y)
        showMinimapIconCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    local panelAlphaSlider = GUI:CreateFormSlider(tabContent, "H3z0 UI Panel Transparency", 0.3, 1.0, 0.01, "configPanelAlpha", db, function(val)
        local mainFrame = GUI.MainFrame
        if mainFrame then
            local bgColor = GUI.Colors.bg
            mainFrame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], val)
        end
    end)
    panelAlphaSlider:SetPoint("TOPLEFT", PADDING, y)
    panelAlphaSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    tabContent:SetHeight(math.abs(y) + 50)
end

-- Export
ns.H3z0UI_QoLOptions = {
    BuildGeneralTab = BuildGeneralTab
}
