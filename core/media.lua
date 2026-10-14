-- H3z0UI Media Registration
-- This file handles the registration of fonts and textures with LibSharedMedia

local LSM = LibStub("LibSharedMedia-3.0")

-- Media types from LibSharedMedia
local MediaType = LSM.MediaType
local FONT = MediaType.FONT
local STATUSBAR = MediaType.STATUSBAR
local BACKGROUND = MediaType.BACKGROUND
local BORDER = MediaType.BORDER

-- Register media synchronously (LSM:Register is lightweight - just table entries)
-- Register the H3z0UI font (used as the main UI font)
local h3z0uiFontPath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI.ttf"
LSM:Register(FONT, "H3z0UI", h3z0uiFontPath)

-- Register Poppins fonts
LSM:Register(FONT, "Poppins Black", "Interface\\AddOns\\H3z0UI\\assets\\Poppins-Black.ttf")
LSM:Register(FONT, "Poppins Bold", "Interface\\AddOns\\H3z0UI\\assets\\Poppins-Bold.ttf")
LSM:Register(FONT, "Poppins Medium", "Interface\\AddOns\\H3z0UI\\assets\\Poppins-Medium.ttf")
LSM:Register(FONT, "Poppins SemiBold", "Interface\\AddOns\\H3z0UI\\assets\\Poppins-SemiBold.ttf")

-- Register Expressway font
LSM:Register(FONT, "Expressway", "Interface\\AddOns\\H3z0UI\\assets\\Expressway.TTF")

-- Register the H3z0UI Logo texture
local logoTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\icon.tga"
LSM:Register(BACKGROUND, "H3z0UI_logo", logoTexturePath)

-- Register the H3z0UI texture
local h3z0uiTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI.tga"
LSM:Register(BACKGROUND, "H3z0UI", h3z0uiTexturePath)
LSM:Register(STATUSBAR, "H3z0UI", h3z0uiTexturePath)
LSM:Register(BORDER, "H3z0UI", h3z0uiTexturePath)

-- Register the H3z0UI Reverse texture
local h3z0uiReverseTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_reverse.tga"
LSM:Register(BACKGROUND, "H3z0UI Reverse", h3z0uiReverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI Reverse", h3z0uiReverseTexturePath)
LSM:Register(BORDER, "H3z0UI Reverse", h3z0uiReverseTexturePath)

-- Register Square texture
local squareTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\Square.tga"
LSM:Register(BACKGROUND, "Square", squareTexturePath)
LSM:Register(STATUSBAR, "Square", squareTexturePath)
LSM:Register(BORDER, "Square", squareTexturePath)

-- Register H3z0UI v2 texture
local h3z0uiV2TexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v2.tga"
LSM:Register(BACKGROUND, "H3z0UI v2", h3z0uiV2TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v2", h3z0uiV2TexturePath)
LSM:Register(BORDER, "H3z0UI v2", h3z0uiV2TexturePath)

-- Register H3z0UI v2 Reverse texture
local h3z0uiV2ReverseTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v2reverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v2 Reverse", h3z0uiV2ReverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v2 Reverse", h3z0uiV2ReverseTexturePath)
LSM:Register(BORDER, "H3z0UI v2 Reverse", h3z0uiV2ReverseTexturePath)

-- Register H3z0UI v3 texture
local h3z0uiV3TexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v3.tga"
LSM:Register(BACKGROUND, "H3z0UI v3", h3z0uiV3TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v3", h3z0uiV3TexturePath)
LSM:Register(BORDER, "H3z0UI v3", h3z0uiV3TexturePath)

-- Register H3z0UI v3 Inverse texture
local h3z0uiV3InverseTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v3inverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v3 Inverse", h3z0uiV3InverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v3 Inverse", h3z0uiV3InverseTexturePath)
LSM:Register(BORDER, "H3z0UI v3 Inverse", h3z0uiV3InverseTexturePath)

-- Register H3z0UI v4 texture
local h3z0uiV4TexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v4.tga"
LSM:Register(BACKGROUND, "H3z0UI v4", h3z0uiV4TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v4", h3z0uiV4TexturePath)
LSM:Register(BORDER, "H3z0UI v4", h3z0uiV4TexturePath)

-- Register H3z0UI v4 Inverse texture
local h3z0uiV4InverseTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v4inverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v4 Inverse", h3z0uiV4InverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v4 Inverse", h3z0uiV4InverseTexturePath)
LSM:Register(BORDER, "H3z0UI v4 Inverse", h3z0uiV4InverseTexturePath)

-- Register H3z0UI v5 texture
local h3z0uiV5TexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v5.tga"
LSM:Register(BACKGROUND, "H3z0UI v5", h3z0uiV5TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v5", h3z0uiV5TexturePath)
LSM:Register(BORDER, "H3z0UI v5", h3z0uiV5TexturePath)

-- Register H3z0UI v5 Inverse texture
local h3z0uiV5InverseTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v5_inverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v5 Inverse", h3z0uiV5InverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v5 Inverse", h3z0uiV5InverseTexturePath)
LSM:Register(BORDER, "H3z0UI v5 Inverse", h3z0uiV5InverseTexturePath)

-- Register H3z0UI v6 texture
local h3z0uiV6TexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v6.tga"
LSM:Register(BACKGROUND, "H3z0UI v6", h3z0uiV6TexturePath)
LSM:Register(STATUSBAR, "H3z0UI v6", h3z0uiV6TexturePath)
LSM:Register(BORDER, "H3z0UI v6", h3z0uiV6TexturePath)

-- Register H3z0UI v6 Inverse texture
local h3z0uiV6InverseTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\H3z0UI_v6inverse.tga"
LSM:Register(BACKGROUND, "H3z0UI v6 Inverse", h3z0uiV6InverseTexturePath)
LSM:Register(STATUSBAR, "H3z0UI v6 Inverse", h3z0uiV6InverseTexturePath)
LSM:Register(BORDER, "H3z0UI v6 Inverse", h3z0uiV6InverseTexturePath)

-- Register H3z0UI Stripes texture (for absorb shield overlays)
local absorbStripeTexturePath = "Interface\\AddOns\\H3z0UI\\assets\\absorb_stripe"
LSM:Register(STATUSBAR, "H3z0UI Stripes", absorbStripeTexturePath)

-- Function to check if our media is registered
function H3z0UI:CheckMediaRegistration()
    local h3z0uiFontRegistered = LSM:IsValid(FONT, "H3z0UI")
    local logoTextureRegistered = LSM:IsValid(BACKGROUND, "H3z0UI_logo")
    local h3z0uiTextureRegistered = LSM:IsValid(BACKGROUND, "H3z0UI")
    local h3z0uiReverseTextureRegistered = LSM:IsValid(BACKGROUND, "H3z0UI Reverse")
    
    -- Silent check - only print if there's a failure
    if not (h3z0uiFontRegistered and logoTextureRegistered and h3z0uiTextureRegistered and h3z0uiReverseTextureRegistered) then
        H3z0UI:Print("Media registration failed:")
        if not h3z0uiFontRegistered then H3z0UI:Print("- H3z0 UI font not registered") end
        if not logoTextureRegistered then H3z0UI:Print("- H3z0UI_logo texture not registered") end
        if not h3z0uiTextureRegistered then H3z0UI:Print("- H3z0 UI texture not registered") end
        if not h3z0uiReverseTextureRegistered then H3z0UI:Print("- H3z0UI Reverse texture not registered") end
    end
end

-- Register any additional fonts or textures here
-- Example:
-- LSM:Register(FONT, "MyCustomFont", "Interface\\AddOns\\H3z0UI\\assets\\mycustomfont.ttf")
-- LSM:Register(STATUSBAR, "MyCustomTexture", "Interface\\AddOns\\H3z0UI\\assets\\mycustomtexture.tga") 
