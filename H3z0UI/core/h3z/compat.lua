local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI compatibility layer
-- Small helpers the H3z0 UI modules (unit frames, party / raid frames,
-- nameplates, chat, window skins, H3z0 Features) expect from the core.
-- Only fills what is missing; nothing that already exists is replaced.
---------------------------------------------------------------------------

local Helpers = ns.Helpers
if type(Helpers) ~= "table" then return end

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local DEFAULT_TEXTURE = "Interface\\Buttons\\WHITE8x8"

if not Helpers.GetGeneralTexture then
    function Helpers.GetGeneralTexture()
        local profile = Helpers.GetProfile and Helpers.GetProfile()
        local name = profile and profile.general and profile.general.texture or "H3z0UI"
        if LSM then
            return LSM:Fetch("statusbar", name) or DEFAULT_TEXTURE
        end
        return DEFAULT_TEXTURE
    end
end

if not Helpers.GetAddonAccentColor then
    function Helpers.GetAddonAccentColor()
        local addon = _G.H3z0UI
        if addon and addon.GetAddonAccentColor then
            return addon:GetAddonAccentColor()
        end
        return 0.204, 0.827, 0.6, 1
    end
end

if not Helpers.AttachLogoBackground then
    -- faded H3z0 logo watermark behind a background frame
    function Helpers.AttachLogoBackground(bgFrame, alpha)
        if not bgFrame then return end
        local logo = bgFrame._h3z0uiLogo
        if not logo then
            logo = bgFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
            logo:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\h3z0ui_logo_bg.png")
            logo:SetPoint("CENTER", bgFrame, "CENTER", 0, 0)
            bgFrame._h3z0uiLogo = logo
            local function SizeLogo()
                local w, h = bgFrame:GetWidth() or 0, bgFrame:GetHeight() or 0
                if w < 1 or h < 1 then return end
                local lw = math.min(w * 0.9, h * 0.9 * 2)
                logo:SetSize(lw, lw / 2)
            end
            bgFrame:HookScript("OnSizeChanged", SizeLogo)
            bgFrame:HookScript("OnShow", SizeLogo)
            C_Timer.After(0, SizeLogo)
        end
        logo:SetAlpha(alpha or 0.12)
        logo:Show()
        return logo
    end
end

---------------------------------------------------------------------------
-- Layout Mode entry point used by the H3z0 modules (Esc menu, wizard, ...)
---------------------------------------------------------------------------
if not _G.H3z0UI_ToggleLayoutMode then
    _G.H3z0UI_ToggleLayoutMode = function()
        local lm = ns.H3z0UI_LayoutMode
        if lm and lm.Toggle then
            lm:Toggle()
        end
    end
end

---------------------------------------------------------------------------
-- Key bindings (Bindings.xml)
---------------------------------------------------------------------------
_G.BINDING_HEADER_H3z0UI = "H3z0 UI"
_G.BINDING_NAME_H3z0UI_TOGGLE_OPTIONS = "Open H3z0 UI Options"
_G.BINDING_NAME_H3z0UI_TOGGLE_LAYOUT = "Toggle H3z0 UI Layout Mode"

-- Shortcut for modules: the H3z0 UI font file
if not _G.H3z0UI_GetFont then
    _G.H3z0UI_GetFont = function()
        local H = _G.H3z0UI
        if H and H.GetGlobalFont then
            local ok, path = pcall(H.GetGlobalFont, H)
            if ok and path then return path end
        end
        local Helpers = ns.Helpers
        if Helpers and Helpers.GetGeneralFont then
            local ok, path = pcall(Helpers.GetGeneralFont)
            if ok and path then return path end
        end
        return STANDARD_TEXT_FONT
    end
end

