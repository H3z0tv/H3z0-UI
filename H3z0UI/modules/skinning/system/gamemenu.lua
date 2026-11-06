local _, ns = ...

if ns.IsSkinningEnabled and not ns.IsSkinningEnabled() then return end

local Helpers = ns.Helpers
local GetCore = Helpers.GetCore
local SkinBase = ns.SkinBase

local COLORS = { text = { 0.9, 0.9, 0.9, 1 } }

local buttonState = Helpers.CreateStateTable()

local installed = false
local staticDone = false
local menuBg = nil
local TITLE_ROOM = 14      -- room above the buttons for the menu's own "Game Menu" title
local dimFrame = nil
local h3z0uiButton = nil
local editModeButton = nil

local function GetGeneralSettings()
    local core = GetCore()
    return core and core.db and core.db.profile and core.db.profile.general
end

local function GetGameMenuFontSize()
    local s = GetGeneralSettings()
    return s and s.gameMenuFontSize or 12
end

local function GetGameMenuColors()
    return SkinBase.GetWindowColors(GetGeneralSettings(), "gameMenu")
end

local function StripChromeOnce()
    for i = 1, select("#", GameMenuFrame:GetRegions()) do
        local r = select(i, GameMenuFrame:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") then
            r:SetAlpha(0)
        end
    end
end

-- every non-button child of the menu (border, nine-slice, the "Game Menu" header):
-- textures off, text kept and coloured, so the header is just the title
local function StripFrameArt(frame, depth)
    if not frame or depth > 3 then return end
    for i = 1, select("#", frame:GetRegions()) do
        local r = select(i, frame:GetRegions())
        if r and r.IsObjectType then
            if r:IsObjectType("Texture") then
                r:SetAlpha(0)
            elseif r:IsObjectType("FontString") then
                local ar, ag, ab = SkinBase.GetSkinColors()
                if ar then r:SetTextColor(ar, ag, ab, 1) end
            end
        end
    end
    for i = 1, select("#", frame:GetChildren()) do
        StripFrameArt(select(i, frame:GetChildren()), depth + 1)
    end
end

local function ReassertChrome()
    if GameMenuFrame.NineSlice then GameMenuFrame.NineSlice:SetAlpha(0) end
    if GameMenuFrame.Border then GameMenuFrame.Border:SetAlpha(0) end
    for i = 1, select("#", GameMenuFrame:GetChildren()) do
        local child = select(i, GameMenuFrame:GetChildren())
        if child and child ~= menuBg and child ~= dimFrame and not buttonState[child]
           and not (child.IsObjectType and child:IsObjectType("Button")) then
            StripFrameArt(child, 1)
        end
    end
end

local function ReassertLevels(refLevel)
    local base = refLevel or GameMenuFrame:GetFrameLevel() or 1
    if menuBg then menuBg:SetFrameLevel(math.max(0, base - 2)) end
    if dimFrame then dimFrame:SetFrameLevel(math.max(0, base - 3)) end
end

local function EnsureDim()
    if dimFrame then return dimFrame end
    dimFrame = CreateFrame("Frame", "H3z0UIGameMenuDim", GameMenuFrame)
    dimFrame:SetAllPoints(UIParent)
    dimFrame:EnableMouse(false)
    local tex = dimFrame:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(0, 0, 0, 0.5)
    dimFrame.tex = tex
    return dimFrame
end

local function AssertDim(settings)
    local dim = EnsureDim()
    -- the Character & Pet Scene brings its own dark bands instead
    if settings and settings.gameMenuDim and settings.gameMenuScene == false then dim:Show() else dim:Hide() end
end

local function EnsureMenuBg()
    if menuBg then return menuBg end
    menuBg = CreateFrame("Frame", "H3z0UIGameMenuBg", GameMenuFrame)
    menuBg:SetPoint("TOPLEFT", GameMenuFrame, "TOPLEFT", 0, TITLE_ROOM)
    menuBg:SetPoint("BOTTOMRIGHT", GameMenuFrame, "BOTTOMRIGHT", 0, 0)
    menuBg:EnableMouse(false)
    return menuBg
end

local hiddenTex = {}

local function KeepHidden(tex)
    if not tex or not tex.SetAlpha then return end
    tex:SetAlpha(0)
    if not hiddenTex[tex] then
        hiddenTex[tex] = true
        hooksecurefunc(tex, "SetAlpha", function(self, a)
            if a and a > 0 then self:SetAlpha(0) end
        end)
    end
end

local function StripButtonArt(button, isPool, info)
    -- the button's state art (normal / pushed / disabled) and art on child frames
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        if button[getter] then KeepHidden(button[getter](button)) end
    end
    local hl = button.GetHighlightTexture and button:GetHighlightTexture()
    if hl and hl ~= info.highlight then KeepHidden(hl) end
    for i = 1, select("#", button:GetChildren()) do
        local child = select(i, button:GetChildren())
        if child and child ~= info.inset and child ~= button.NewFeature and child ~= button.NewFeatureFrame then
            for k = 1, select("#", child:GetRegions()) do
                local r = select(k, child:GetRegions())
                if r and r.IsObjectType and r:IsObjectType("Texture") then KeepHidden(r) end
            end
        end
    end
    local fs = button.GetFontString and button:GetFontString()
    for i = 1, select("#", button:GetRegions()) do
        local r = select(i, button:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture")
           and r ~= fs and r ~= info.highlight then
            r:SetAlpha(0)
        end
    end
    if isPool and not info.clamped then
        for _, key in ipairs({ "Left", "Center", "Right" }) do
            local tex = button[key]
            if tex and tex.SetAlpha then
                tex:SetAlpha(0)
                hooksecurefunc(tex, "SetAlpha", function(self, a)
                    if a and a > 0 then self:SetAlpha(0) end
                end)
            end
        end
        info.clamped = true
    end
end

local function SkinButton(button, isPool, sr, sg, sb, sa, bgr, bgg, bgb, fontSize)
    if not button then return end
    local info = buttonState[button]
    if not info then
        info = {}
        buttonState[button] = info
    end

    StripButtonArt(button, isPool, info)

    if not info.inset then
        local inset = CreateFrame("Frame", nil, button)
        SkinBase.SetInsetPixelPoints(inset, button, 1)
        inset:EnableMouse(false)
        info.inset = inset

        local hl = button:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(inset)
        hl:SetColorTexture(1, 1, 1, 0.10)
        info.highlight = hl
    end

    info.inset:SetFrameLevel(math.max(0, (button:GetFrameLevel() or 1) - 1))

    bgr, bgg, bgb = SkinBase.GetControlBg()  -- buttons keep the H3z0 slate
    local btnBgR = math.min(bgr + SkinBase.CHROME.BUTTON_BOOST, 1)
    local btnBgG = math.min(bgg + SkinBase.CHROME.BUTTON_BOOST, 1)
    local btnBgB = math.min(bgb + SkinBase.CHROME.BUTTON_BOOST, 1)
    SkinBase.ApplyChromeBackdrop(info.inset, { radius = 5, withBackground = true, borderColor = { sr, sg, sb, sa }, bgColor = { btnBgR, btnBgG, btnBgB, 1 } })

    SkinBase.ApplyButtonFontObjects(button, { size = fontSize, color = COLORS.text })
end

local function GetOrCreateH3z0UIButton()
    if h3z0uiButton then return h3z0uiButton end
    h3z0uiButton = CreateFrame("Button", "H3z0UIGameMenuButton", GameMenuFrame, "UIPanelButtonTemplate")
    h3z0uiButton:SetText(ns.L["H3z0UI"])
    h3z0uiButton:SetSize(160, 30)
    h3z0uiButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        HideUIPanel(GameMenuFrame)
        local H3z0UI = _G.H3z0UI
        if H3z0UI and H3z0UI.ShowOptions then H3z0UI:ShowOptions() end
    end)
    h3z0uiButton:Hide()
    return h3z0uiButton
end

local function GetOrCreateEditModeButton()
    if editModeButton then return editModeButton end
    editModeButton = CreateFrame("Button", "H3z0UIGameMenuEditModeButton", GameMenuFrame, "UIPanelButtonTemplate")
    editModeButton:SetText(ns.L["H3z0UI Edit Mode"])
    editModeButton:SetSize(160, 30)
    editModeButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        HideUIPanel(GameMenuFrame)
        if _G.H3z0UI_ToggleLayoutMode then _G.H3z0UI_ToggleLayoutMode() end
    end)
    editModeButton:Hide()
    return editModeButton
end

local function RestoreButtonArt(button)
    if not button then return end
    local info = buttonState[button]
    if not info then return end
    if info.inset then info.inset:Hide() end
    if info.highlight then info.highlight:SetAlpha(0) end
    local fs = button.GetFontString and button:GetFontString()
    for i = 1, select("#", button:GetRegions()) do
        local r = select(i, button:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture")
           and r ~= fs and r ~= info.highlight then
            r:SetAlpha(1)
        end
    end
    if button.SetNormalFontObject then button:SetNormalFontObject("GameFontNormal") end
    if button.SetHighlightFontObject then button:SetHighlightFontObject("GameFontHighlight") end
    if button.SetDisabledFontObject then button:SetDisabledFontObject("GameFontDisable") end
end

local function PositionCustomButtons(settings, skin, refButton, sr, sg, sb, sa, bgr, bgg, bgb, fontSize)
    if settings.addH3z0UIButton == false then
        if h3z0uiButton then h3z0uiButton:Hide() end
    else
        local b = GetOrCreateH3z0UIButton()
        b:ClearAllPoints()
        b:SetPoint("TOP", GameMenuFrame, "BOTTOM", 0, -2)
        if refButton then b:SetSize(refButton:GetWidth(), refButton:GetHeight()) end
        b:Show()
        if skin then
            SkinButton(b, false, sr, sg, sb, sa, bgr, bgg, bgb, fontSize)
        else
            RestoreButtonArt(b)
        end
    end

    if settings.addEditModeButton == false then
        if editModeButton then editModeButton:Hide() end
    else
        local b = GetOrCreateEditModeButton()
        local anchor = (h3z0uiButton and h3z0uiButton:IsShown()) and h3z0uiButton or GameMenuFrame
        b:ClearAllPoints()
        b:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
        if refButton then b:SetSize(refButton:GetWidth(), refButton:GetHeight()) end
        b:Show()
        if skin then
            SkinButton(b, false, sr, sg, sb, sa, bgr, bgg, bgb, fontSize)
        else
            RestoreButtonArt(b)
        end
    end
end

local function LowestButton()
    local low, lowest
    for _, b in ipairs({ _G.H3z0UIGameMenuButton, _G.H3z0UIGameMenuEditModeButton }) do
        if b and b:IsShown() then
            local v = b:GetBottom()
            if v and (not lowest or v < lowest) then low, lowest = b, v end
        end
    end
    if not low and GameMenuFrame.buttonPool then
        for b in GameMenuFrame.buttonPool:EnumerateActive() do
            local v = b:GetBottom()
            if v and (not lowest or v < lowest) then low, lowest = b, v end
        end
    end
    return low, lowest
end

local function ExtendMenuBg()
    if not menuBg then return end
    C_Timer.After(0, function()
        if not menuBg or not GameMenuFrame then return end
        local _, lowest = LowestButton()
        menuBg:ClearAllPoints()
        menuBg:SetPoint("TOPLEFT", GameMenuFrame, "TOPLEFT", 0, TITLE_ROOM)
        local gmBottom = GameMenuFrame:GetBottom()
        local extend = 0
        if lowest and gmBottom and lowest - 12 < gmBottom then extend = gmBottom - (lowest - 12) end
        menuBg:SetPoint("BOTTOMRIGHT", GameMenuFrame, "BOTTOMRIGHT", 0, -extend)
    end)
end

local function ApplyStaticSkin()
    if staticDone then return end
    local bg = EnsureMenuBg()
    EnsureDim()
    StripChromeOnce()
    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetGameMenuColors()
    SkinBase.ApplyChromeBackdrop(bg, { radius = 8, withBackground = true, borderColor = { sr, sg, sb, sa }, bgColor = { bgr, bgg, bgb, bga } })
    staticDone = true
end

local function OnInitButtons(menu)
    local settings = GetGeneralSettings()
    if not settings then return end
    if not menu or not menu.buttonPool then return end

    -- H3z0 UI: Skin Game Menu (Appearance > Skinning) gives the Esc menu the
    -- H3z0 UI window look. The H3z0 UI / Edit Mode buttons under "Return to Game"
    -- come from core/h3z/gamemenu_buttons.lua and get the same skin here.
    local skin = settings.skinGameMenu ~= false
    if not skin then return end

    if skin then
        ApplyStaticSkin()
        ReassertChrome()
    end

    local sr, sg, sb, sa, bgr, bgg, bgb = GetGameMenuColors()
    local fontSize = GetGameMenuFontSize()

    local refButton, minLevel
    for button in menu.buttonPool:EnumerateActive() do
        if skin then
            SkinButton(button, true, sr, sg, sb, sa, bgr, bgg, bgb, fontSize)
        end
        local lvl = button:GetFrameLevel() or 0
        if not minLevel or lvl < minLevel then minLevel = lvl end
        refButton = refButton or button
    end

    if skin then ReassertLevels(minLevel) end
    -- the H3z0 UI buttons are made right after this (same hook): skin them a frame later
    C_Timer.After(0, function()
        for _, b in ipairs({ _G.H3z0UIGameMenuButton, _G.H3z0UIGameMenuEditModeButton }) do
            if b and b:IsShown() then
                SkinButton(b, false, sr, sg, sb, sa, bgr, bgg, bgb, fontSize)
            end
        end
        ExtendMenuBg()
    end)
    AssertDim(settings)
    ExtendMenuBg()
end

local function RefreshGameMenuColors()
    if not staticDone then return end
    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetGameMenuColors()
    if menuBg then
        SkinBase.ApplyChromeBackdrop(menuBg, { radius = 8, withBackground = true, borderColor = { sr, sg, sb, sa }, bgColor = { bgr, bgg, bgb, bga } })
    end
    local cr, cg, cb = SkinBase.GetControlBg()  -- buttons keep the H3z0 slate
    local btnBgR = math.min(cr + SkinBase.CHROME.BUTTON_BOOST, 1)
    local btnBgG = math.min(cg + SkinBase.CHROME.BUTTON_BOOST, 1)
    local btnBgB = math.min(cb + SkinBase.CHROME.BUTTON_BOOST, 1)
    for _, info in pairs(buttonState) do
        if info.inset then
            SkinBase.ApplyChromeBackdrop(info.inset, { radius = 5, withBackground = true, borderColor = { sr, sg, sb, sa }, bgColor = { btnBgR, btnBgG, btnBgB, 1 } })
        end
    end
end

local function RefreshGameMenuFontSize()
    local settings = GetGeneralSettings()
    if not settings or not settings.skinGameMenu then
        return
    end
    local fontSize = GetGameMenuFontSize()
    for button in pairs(buttonState) do
        SkinBase.ApplyButtonFontObjects(button, { size = fontSize, color = COLORS.text })
    end
end

_G.H3z0UI_RefreshGameMenuColors = RefreshGameMenuColors
_G.H3z0UI_RefreshGameMenuFontSize = RefreshGameMenuFontSize
_G.H3z0UI_RefreshGameMenuDim = function()
    local settings = GetGeneralSettings()
    if not dimFrame then return end
    if settings and settings.gameMenuDim and settings.gameMenuScene == false and GameMenuFrame and GameMenuFrame:IsShown() then
        dimFrame:Show()
    else
        dimFrame:Hide()
    end
end

if ns.Registry then
    ns.Registry:Register("skinGameMenu", {
        refresh = _G.H3z0UI_RefreshGameMenuColors,
        priority = 80,
        group = "skinning",
        importCategories = { "skinning", "theme" },
    })
    ns.Registry:Register("skinGameMenuFonts", {
        refresh = _G.H3z0UI_RefreshGameMenuFontSize,
        priority = 80,
        group = "skinning",
        importCategories = { "skinning", "theme" },
    })
end

local function Install()
    if installed or not GameMenuFrame then return end
    installed = true
    hooksecurefunc(GameMenuFrame, "InitButtons", OnInitButtons)
end

if GameMenuFrame then
    Install()
else
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self)
        if GameMenuFrame then
            Install()
            self:UnregisterAllEvents()
        end
    end)
end
