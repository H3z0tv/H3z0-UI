local addonName, ns = ...

local function GetCore()
    return (_G.H3z0UI and _G.H3z0UI.H3z0UICore) or ns.Addon
end

local function GetPixelSize(frame, default)
    local core = GetCore()
    if core and type(core.GetPixelSize) == "function" then
        local px = core:GetPixelSize(frame)
        if type(px) == "number" and px > 0 then
            return px
        end
    end
    return default or 1
end

---------------------------------------------------------------------------
-- GAME MENU (ESC MENU) SKINNING + H3z0UI BUTTON
---------------------------------------------------------------------------

-- Static colors
local COLORS = {
    text = { 0.9, 0.9, 0.9, 1 },
}

local FONT_FLAGS = "OUTLINE"

-- Get game menu font size from settings
local function GetGameMenuFontSize()
    local core = GetCore()
    local settings = core and core.db and core.db.profile and core.db.profile.general
    return settings and settings.gameMenuFontSize or 12
end

-- Get skinning colors (uses unified color system)
local function GetGameMenuColors()
    local H3z0UI = _G.H3z0UI
    local sr, sg, sb, sa = 0.2, 1.0, 0.6, 1
    local bgr, bgg, bgb, bga = 0.05, 0.05, 0.05, 0.95

    if H3z0UI and H3z0UI.GetSkinColor then
        sr, sg, sb, sa = H3z0UI:GetSkinColor()
    end
    if H3z0UI and H3z0UI.GetSkinBgColor then
        bgr, bgg, bgb, bga = H3z0UI:GetSkinBgColor()
    end

    return sr, sg, sb, sa, bgr, bgg, bgb, bga
end

-- Create a styled backdrop for frames
local function CreateH3z0UIBackdrop(frame, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    if not frame.h3z0uiBackdrop then
        frame.h3z0uiBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.h3z0uiBackdrop:SetAllPoints()
        frame.h3z0uiBackdrop:SetFrameLevel(frame:GetFrameLevel())
        frame.h3z0uiBackdrop:EnableMouse(false)
    end

    local px = GetPixelSize(frame.h3z0uiBackdrop, 1)
    frame.h3z0uiBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = px,
        insets = { left = px, right = px, top = px, bottom = px }
    })
    frame.h3z0uiBackdrop:SetBackdropColor(bgr, bgg, bgb, bga)
    frame.h3z0uiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
end

-- Style a button with H3z0UI theme
local function StyleButton(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    if not button then return end

    -- Create backdrop if needed
    if not button.h3z0uiBackdrop then
        button.h3z0uiBackdrop = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.h3z0uiBackdrop:SetAllPoints()
        button.h3z0uiBackdrop:SetFrameLevel(button:GetFrameLevel())
        button.h3z0uiBackdrop:EnableMouse(false)
    end

    local btnPx = GetPixelSize(button.h3z0uiBackdrop, 1)
    button.h3z0uiBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = btnPx,
        insets = { left = btnPx, right = btnPx, top = btnPx, bottom = btnPx }
    })

    -- Button bg slightly lighter than main bg
    local btnBgR = math.min(bgr + 0.07, 1)
    local btnBgG = math.min(bgg + 0.07, 1)
    local btnBgB = math.min(bgb + 0.07, 1)
    button.h3z0uiBackdrop:SetBackdropColor(btnBgR, btnBgG, btnBgB, 1)
    button.h3z0uiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)

    -- Hide default textures
    if button.Left then button.Left:SetAlpha(0) end
    if button.Right then button.Right:SetAlpha(0) end
    if button.Center then button.Center:SetAlpha(0) end
    if button.Middle then button.Middle:SetAlpha(0) end

    -- Hide highlight/pushed/normal/disabled textures
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end
    local pushed = button:GetPushedTexture()
    if pushed then pushed:SetAlpha(0) end
    local normal = button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    local disabled = button:GetDisabledTexture()
    if disabled then disabled:SetAlpha(0) end

    -- Style button text
    local text = button:GetFontString()
    if text then
        local H3z0UI = _G.H3z0UI
        local fontPath = H3z0UI and H3z0UI.GetGlobalFont and H3z0UI:GetGlobalFont() or STANDARD_TEXT_FONT
        local fontSize = GetGameMenuFontSize()
        text:SetFont(fontPath, fontSize, FONT_FLAGS)
        text:SetTextColor(unpack(COLORS.text))
    end

    -- Store colors for hover effects
    button.h3z0uiSkinColor = { sr, sg, sb, sa }
    button.h3z0uiBgColor = { btnBgR, btnBgG, btnBgB, 1 }

    -- Set hover scripts without replacing existing handlers
    button:HookScript("OnEnter", function(self)
        if self.h3z0uiBackdrop then
            if self.h3z0uiBgColor then
                local r, g, b, a = unpack(self.h3z0uiBgColor)
                self.h3z0uiBackdrop:SetBackdropColor(math.min(r + 0.15, 1), math.min(g + 0.15, 1), math.min(b + 0.15, 1), a)
            end
            if self.h3z0uiSkinColor then
                local r, g, b, a = unpack(self.h3z0uiSkinColor)
                self.h3z0uiBackdrop:SetBackdropBorderColor(math.min(r * 1.4, 1), math.min(g * 1.4, 1), math.min(b * 1.4, 1), a)
            end
        end
        local txt = self:GetFontString()
        if txt then txt:SetTextColor(1, 1, 1, 1) end
    end)

    button:HookScript("OnLeave", function(self)
        if self.h3z0uiBackdrop then
            if self.h3z0uiBgColor then
                self.h3z0uiBackdrop:SetBackdropColor(unpack(self.h3z0uiBgColor))
            end
            if self.h3z0uiSkinColor then
                self.h3z0uiBackdrop:SetBackdropBorderColor(unpack(self.h3z0uiSkinColor))
            end
        end
        local txt = self:GetFontString()
        if txt then txt:SetTextColor(unpack(COLORS.text)) end
    end)

    button.h3z0uiStyled = true
end

-- Update button colors (for live refresh)
local function UpdateButtonColors(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    if not button or not button.h3z0uiBackdrop then return end

    local btnBgR = math.min(bgr + 0.07, 1)
    local btnBgG = math.min(bgg + 0.07, 1)
    local btnBgB = math.min(bgb + 0.07, 1)
    button.h3z0uiBackdrop:SetBackdropColor(btnBgR, btnBgG, btnBgB, 1)
    button.h3z0uiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
    button.h3z0uiSkinColor = { sr, sg, sb, sa }
    button.h3z0uiBgColor = { btnBgR, btnBgG, btnBgB, 1 }
end

-- Hide Blizzard decorative elements
local function HideBlizzardDecorations()
    if GameMenuFrame.Border then GameMenuFrame.Border:Hide() end
    if GameMenuFrame.Header then GameMenuFrame.Header:Hide() end
end

-- Dim background frame
local dimFrame = nil

local function CreateDimFrame()
    if dimFrame then return dimFrame end

    dimFrame = CreateFrame("Frame", "H3z0UIGameMenuDim", UIParent)
    dimFrame:SetAllPoints(UIParent)
    dimFrame:SetFrameStrata("DIALOG")
    dimFrame:SetFrameLevel(0)
    dimFrame:EnableMouse(false)  -- Don't capture mouse events
    dimFrame:Hide()

    -- Dark overlay texture
    dimFrame.overlay = dimFrame:CreateTexture(nil, "BACKGROUND")
    dimFrame.overlay:SetAllPoints()
    dimFrame.overlay:SetColorTexture(0, 0, 0, 0.5)

    return dimFrame
end

local function ShowDimBehindGameMenu()
    local core = GetCore()
    local settings = core and core.db and core.db.profile and core.db.profile.general
    if not settings or not settings.skinGameMenu or not settings.gameMenuDim then return end

    local dim = CreateDimFrame()
    dim:SetFrameStrata("DIALOG")
    dim:SetFrameLevel(GameMenuFrame:GetFrameLevel() - 1)
    dim:Show()
end

local function HideDimBehindGameMenu()
    if dimFrame then
        dimFrame:Hide()
    end
end

-- Expose for settings toggle
_G.H3z0UI_RefreshGameMenuDim = function()
    local core = GetCore()
    local settings = core and core.db and core.db.profile and core.db.profile.general

    if settings and settings.gameMenuDim and GameMenuFrame:IsShown() then
        ShowDimBehindGameMenu()
    else
        HideDimBehindGameMenu()
    end
end

-- Main skinning function
local function SkinGameMenu()
    local core = GetCore()
    local settings = core and core.db and core.db.profile and core.db.profile.general
    if not settings or not settings.skinGameMenu then return end

    if not GameMenuFrame then return end
    if GameMenuFrame.h3z0uiSkinned then return end
    -- first skin re-lays out the (protected) menu: do it out of combat, next time it opens
    if InCombatLockdown() then return end

    -- Get colors based on setting
    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetGameMenuColors()

    -- Hide Blizzard decorations
    HideBlizzardDecorations()

    -- Create backdrop
    CreateH3z0UIBackdrop(GameMenuFrame, sr, sg, sb, sa, bgr, bgg, bgb, bga)

    -- Adjust frame padding for cleaner look
    GameMenuFrame.topPadding = 15
    GameMenuFrame.bottomPadding = 15
    GameMenuFrame.leftPadding = 15
    GameMenuFrame.rightPadding = 15
    GameMenuFrame.spacing = 2

    -- Style all buttons in the pool
    if GameMenuFrame.buttonPool then
        for button in GameMenuFrame.buttonPool:EnumerateActive() do
            StyleButton(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
        end
    end

    -- re-layout only out of combat (protected frame)
    if not InCombatLockdown() then GameMenuFrame:MarkDirty() end
    GameMenuFrame.h3z0uiSkinned = true
end

-- Refresh colors on already-skinned game menu (for live preview)
local function RefreshGameMenuColors()
    if not GameMenuFrame or not GameMenuFrame.h3z0uiSkinned then return end

    -- Get colors based on setting
    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetGameMenuColors()

    -- Update main frame backdrop
    if GameMenuFrame.h3z0uiBackdrop then
        GameMenuFrame.h3z0uiBackdrop:SetBackdropColor(bgr, bgg, bgb, bga)
        GameMenuFrame.h3z0uiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
    end

    -- Update all buttons
    if GameMenuFrame.buttonPool then
        for button in GameMenuFrame.buttonPool:EnumerateActive() do
            UpdateButtonColors(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
        end
    end
end

-- Refresh font size on game menu buttons
local function RefreshGameMenuFontSize()
    if not GameMenuFrame then return end

    local fontSize = GetGameMenuFontSize()
    local H3z0UI = _G.H3z0UI
    local fontPath = H3z0UI and H3z0UI.GetGlobalFont and H3z0UI:GetGlobalFont() or STANDARD_TEXT_FONT

    if GameMenuFrame.buttonPool then
        for button in GameMenuFrame.buttonPool:EnumerateActive() do
            local text = button:GetFontString()
            if text then
                text:SetFont(fontPath, fontSize, FONT_FLAGS)
            end
        end
    end

    -- Mark dirty to recalculate layout if needed
    if GameMenuFrame.MarkDirty and not InCombatLockdown() then
        GameMenuFrame:MarkDirty()
    end
end

-- Expose refresh functions globally
_G.H3z0UI_RefreshGameMenuColors = RefreshGameMenuColors
_G.H3z0UI_RefreshGameMenuFontSize = RefreshGameMenuFontSize

---------------------------------------------------------------------------
-- H3z0UI BUTTON INJECTION
---------------------------------------------------------------------------

-- Inject button on every InitButtons call (buttonPool gets reset each time)
local function InjectH3z0UIButton()
    -- The Esc menu is protected in combat: adding / changing buttons there makes
    -- Blizzard re-layout it from addon code (ADDON_ACTION_BLOCKED GameMenuFrame:SetSize)
    if InCombatLockdown() then return end
    local core = GetCore()
    local settings = core and core.db and core.db.profile and core.db.profile.general
    if not settings then return end

    -- v0.17: the ESC-menu button used to be opt-in (default OFF), so most profiles never saw it.
    -- Turn it on once; after that the checkbox in Skinning stays the user's choice.
    if not settings._gameMenuButtonOn017 then
        settings._gameMenuButtonOn017 = true
        settings.addH3z0UIButton = true
    end
    if not GameMenuFrame or not GameMenuFrame.buttonPool then return end

    -- Blizzard's "Edit Mode" button opens H3z0 UI Layout Mode (the only edit mode)
    local editText = HUD_EDIT_MODE_MENU or "Edit Mode"
    for button in GameMenuFrame.buttonPool:EnumerateActive() do
        if button:GetText() == editText then
            button:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                HideUIPanel(GameMenuFrame)
                if _G.H3z0UI_ToggleLayoutMode then _G.H3z0UI_ToggleLayoutMode() end
            end)
        end
    end

    if settings.addH3z0UIButton == false then return end

    -- v0.17: Place the H3z0 UI button at the very BOTTOM of the menu (below "Return to Game")
    local lastIndex = 0
    for button in GameMenuFrame.buttonPool:EnumerateActive() do
        if button:GetText() == "H3z0 UI" then
            -- Already injected for this layout pass
            return
        end
        if button.layoutIndex and button.layoutIndex > lastIndex then
            lastIndex = button.layoutIndex
        end
    end

    local h3z0uiButton = GameMenuFrame:AddButton("H3z0 UI", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        HideUIPanel(GameMenuFrame)
        local H3z0UI = _G.H3z0UI
        if H3z0UI and H3z0UI.GUI then
            H3z0UI.GUI:Show()
        end
    end)
    h3z0uiButton.layoutIndex = lastIndex + 1

    GameMenuFrame:MarkDirty()
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

-- Hook into GameMenuFrame button initialization (with defensive check)
if GameMenuFrame and GameMenuFrame.InitButtons then
    hooksecurefunc(GameMenuFrame, "InitButtons", function()
        -- Inject H3z0UI button (always, regardless of skinning setting)
        InjectH3z0UIButton()

        -- Skin menu if enabled (defer to ensure buttons are ready)
        C_Timer.After(0, function()
            SkinGameMenu()

            -- Style any new buttons that were added
            if GameMenuFrame.h3z0uiSkinned and GameMenuFrame.buttonPool then
                local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetGameMenuColors()

                for button in GameMenuFrame.buttonPool:EnumerateActive() do
                    if not button.h3z0uiStyled then
                        StyleButton(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
                    end
                end
            end
        end)
    end)

    -- Hook Show/Hide for dim effect and button re-styling
    GameMenuFrame:HookScript("OnShow", function()
        ShowDimBehindGameMenu()

        -- Defer button styling to ensure InitButtons has completed
        C_Timer.After(0, function()
            if not GameMenuFrame:IsShown() then return end
            if not GameMenuFrame.h3z0uiSkinned or not GameMenuFrame.buttonPool then return end

            local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetGameMenuColors()
            for button in GameMenuFrame.buttonPool:EnumerateActive() do
                -- Force full re-styling every time (hooks may be lost on pool recycle)
                button.h3z0uiStyled = nil
                StyleButton(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
            end
        end)
    end)
    GameMenuFrame:HookScript("OnHide", function()
        HideDimBehindGameMenu()
    end)
end
