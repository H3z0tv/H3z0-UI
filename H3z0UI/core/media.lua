local ADDON_NAME, ns = ...
local LSM = ns.LSM
local AssetPath = ns.Helpers.AssetPath

local MediaType = LSM.MediaType
local FONT = MediaType.FONT
local STATUSBAR = MediaType.STATUSBAR
local BACKGROUND = MediaType.BACKGROUND
local BORDER = MediaType.BORDER

local h3z0uiFontPath = AssetPath .. "H3z0UI.ttf"
LSM:Register(FONT, "H3z0UI", h3z0uiFontPath)

LSM:Register(FONT, "Poppins Black", AssetPath .. "Poppins-Black.ttf")
LSM:Register(FONT, "Poppins Bold", AssetPath .. "Poppins-Bold.ttf")
LSM:Register(FONT, "Poppins Medium", AssetPath .. "Poppins-Medium.ttf")
LSM:Register(FONT, "Poppins SemiBold", AssetPath .. "Poppins-SemiBold.ttf")

LSM:Register(FONT, "Expressway", AssetPath .. "Expressway.TTF")

local logoTexturePath = AssetPath .. "icon.tga"
LSM:Register(BACKGROUND, "H3z0UI_logo", logoTexturePath)

local h3z0uiTexturePath = AssetPath .. "H3z0UI.tga"
LSM:Register(BACKGROUND, "H3z0UI", h3z0uiTexturePath)
LSM:Register(STATUSBAR, "H3z0UI", h3z0uiTexturePath)
LSM:Register(BORDER, "H3z0UI", h3z0uiTexturePath)

local h3z0uiReverseTexturePath = AssetPath .. "H3z0UI_reverse.tga"
LSM:Register(BACKGROUND, "H3z0UI Reverse", h3z0uiReverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI Reverse", h3z0uiReverseTexturePath)
LSM:Register(BORDER, "H3z0UI Reverse", h3z0uiReverseTexturePath)

local squareTexturePath = AssetPath .. "Square.tga"
LSM:Register(BACKGROUND, "Square", squareTexturePath)
LSM:Register(STATUSBAR, "Square", squareTexturePath)
LSM:Register(BORDER, "Square", squareTexturePath)

LSM:Register(STATUSBAR, "Flat", "Interface\\Buttons\\WHITE8X8")
LSM:Register(STATUSBAR, "Satin", AssetPath .. "appearance\\Satin.tga")

local h3z0uiV2TexturePath = AssetPath .. "H3z0UI_v2.tga"
LSM:Register(BACKGROUND, "H3z0UI v2", h3z0uiV2TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v2", h3z0uiV2TexturePath)
LSM:Register(BORDER, "H3z0UI v2", h3z0uiV2TexturePath)

local h3z0uiV2ReverseTexturePath = AssetPath .. "H3z0UI_v2reverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v2 Reverse", h3z0uiV2ReverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v2 Reverse", h3z0uiV2ReverseTexturePath)
LSM:Register(BORDER, "H3z0UI v2 Reverse", h3z0uiV2ReverseTexturePath)

local h3z0uiV3TexturePath = AssetPath .. "H3z0UI_v3.tga"
LSM:Register(BACKGROUND, "H3z0UI v3", h3z0uiV3TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v3", h3z0uiV3TexturePath)
LSM:Register(BORDER, "H3z0UI v3", h3z0uiV3TexturePath)

local h3z0uiV3InverseTexturePath = AssetPath .. "H3z0UI_v3inverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v3 Inverse", h3z0uiV3InverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v3 Inverse", h3z0uiV3InverseTexturePath)
LSM:Register(BORDER, "H3z0UI v3 Inverse", h3z0uiV3InverseTexturePath)

local h3z0uiV4TexturePath = AssetPath .. "H3z0UI_v4.tga"
LSM:Register(BACKGROUND, "H3z0UI v4", h3z0uiV4TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v4", h3z0uiV4TexturePath)
LSM:Register(BORDER, "H3z0UI v4", h3z0uiV4TexturePath)

local h3z0uiV4InverseTexturePath = AssetPath .. "H3z0UI_v4inverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v4 Inverse", h3z0uiV4InverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v4 Inverse", h3z0uiV4InverseTexturePath)
LSM:Register(BORDER, "H3z0UI v4 Inverse", h3z0uiV4InverseTexturePath)

local h3z0uiV5TexturePath = AssetPath .. "H3z0UI_v5.tga"
LSM:Register(BACKGROUND, "H3z0UI v5", h3z0uiV5TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v5", h3z0uiV5TexturePath)
LSM:Register(BORDER, "H3z0UI v5", h3z0uiV5TexturePath)

local h3z0uiV5InverseTexturePath = AssetPath .. "H3z0UI_v5_inverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v5 Inverse", h3z0uiV5InverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v5 Inverse", h3z0uiV5InverseTexturePath)
LSM:Register(BORDER, "H3z0UI v5 Inverse", h3z0uiV5InverseTexturePath)

local h3z0uiV6TexturePath = AssetPath .. "H3z0UI_v6.tga"
LSM:Register(BACKGROUND, "H3z0UI v6", h3z0uiV6TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v6", h3z0uiV6TexturePath)
LSM:Register(BORDER, "H3z0UI v6", h3z0uiV6TexturePath)

local h3z0uiV6InverseTexturePath = AssetPath .. "H3z0UI_v6inverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v6 Inverse", h3z0uiV6InverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v6 Inverse", h3z0uiV6InverseTexturePath)
LSM:Register(BORDER, "H3z0UI v6 Inverse", h3z0uiV6InverseTexturePath)

local absorbStripeTexturePath = AssetPath .. "absorb_stripe"
LSM:Register(STATUSBAR, "H3z0UI Stripes", absorbStripeTexturePath)

if ns.IconSkin then
    local ICONSKIN = "h3z0ui-iconskin"
    for _, name in ipairs(ns.IconSkin.GetSkinList()) do
        LSM:Register(ICONSKIN, name, name)
    end
end

function H3z0UI:CheckMediaRegistration()
    local h3z0uiFontRegistered = LSM:IsValid(FONT, "H3z0UI")
    local logoTextureRegistered = LSM:IsValid(BACKGROUND, "H3z0UI_logo")
    local h3z0uiTextureRegistered = LSM:IsValid(BACKGROUND, "H3z0UI")
    local h3z0uiReverseTextureRegistered = LSM:IsValid(BACKGROUND, "H3z0UI Reverse")

    if not (h3z0uiFontRegistered and logoTextureRegistered and h3z0uiTextureRegistered and h3z0uiReverseTextureRegistered) then
        H3z0UI:Print("Media registration failed:")
        if not h3z0uiFontRegistered then H3z0UI:Print("- H3z0UI font not registered") end
        if not logoTextureRegistered then H3z0UI:Print("- H3z0UI_logo texture not registered") end
        if not h3z0uiTextureRegistered then H3z0UI:Print("- H3z0UI texture not registered") end
        if not h3z0uiReverseTextureRegistered then H3z0UI:Print("- H3z0UI Reverse texture not registered") end
    end
end
