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
-- KEYSTONE FRAME SKINNING
---------------------------------------------------------------------------

-- Static colors (text only - bg comes from H3z0UI:GetSkinBgColor())
local COLORS = {
    text = { 0.9, 0.9, 0.9, 1 },
    textMuted = { 0.6, 0.6, 0.6, 1 },
}

local FONT_FLAGS = "OUTLINE"

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
    if button.Middle then button.Middle:SetAlpha(0) end
    if button.LeftSeparator then button.LeftSeparator:SetAlpha(0) end
    if button.RightSeparator then button.RightSeparator:SetAlpha(0) end

    -- Hide highlight/pushed textures (removes red hover tint)
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end
    local pushed = button:GetPushedTexture()
    if pushed then pushed:SetAlpha(0) end

    -- Style button text
    local text = button:GetFontString()
    if text then
        text:SetFont(STANDARD_TEXT_FONT, 12, FONT_FLAGS)
        text:SetTextColor(unpack(COLORS.text))
    end

    -- Store skin color for hover effects
    button.h3z0uiSkinColor = { sr, sg, sb, sa }

    -- Hover effect (brighten border)
    button:HookScript("OnEnter", function(self)
        if self.h3z0uiBackdrop and self.h3z0uiSkinColor then
            local r, g, b, a = unpack(self.h3z0uiSkinColor)
            self.h3z0uiBackdrop:SetBackdropBorderColor(math.min(r * 1.3, 1), math.min(g * 1.3, 1), math.min(b * 1.3, 1), a)
        end
    end)
    button:HookScript("OnLeave", function(self)
        if self.h3z0uiBackdrop and self.h3z0uiSkinColor then
            self.h3z0uiBackdrop:SetBackdropBorderColor(unpack(self.h3z0uiSkinColor))
        end
    end)
end

-- Style the close button
local function StyleCloseButton(button)
    if not button then return end
    if button.Border then button.Border:SetAlpha(0) end
end

-- Style the keystone slot
local function StyleKeystoneSlot(slot, sr, sg, sb, sa)
    if not slot then return end

    if not slot.h3z0uiBorder then
        slot.h3z0uiBorder = CreateFrame("Frame", nil, slot, "BackdropTemplate")
        slot.h3z0uiBorder:SetPoint("TOPLEFT", -4, 4)
        slot.h3z0uiBorder:SetPoint("BOTTOMRIGHT", 4, -4)
        slot.h3z0uiBorder:SetFrameLevel(slot:GetFrameLevel() - 1)
        slot.h3z0uiBorder:EnableMouse(false)
        local slotPx = GetPixelSize(slot.h3z0uiBorder, 1)
        local slotEdge2 = 2 * slotPx
        slot.h3z0uiBorder:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = slotEdge2,
            insets = { left = slotEdge2, right = slotEdge2, top = slotEdge2, bottom = slotEdge2 }
        })
        slot.h3z0uiBorder:SetBackdropColor(0, 0, 0, 0.5)
        slot.h3z0uiBorder:SetBackdropBorderColor(sr, sg, sb, sa)
    end
end

-- Hide Blizzard decorative elements
local function HideBlizzardDecorations(f)
    local region = f:GetRegions()
    if region then region:SetAlpha(0) end
    if f.InstructionBackground then f.InstructionBackground:SetAlpha(0) end
    if f.KeystoneSlotGlow then f.KeystoneSlotGlow:Hide() end
    if f.SlotBG then f.SlotBG:Hide() end
    if f.KeystoneFrame then f.KeystoneFrame:Hide() end
    if f.Divider then f.Divider:Hide() end
end

-- Main skinning function
local function SkinKeystoneFrame()
    local core = GetCore()
    local settings = core and core.db and core.db.profile and core.db.profile.general
    if not settings or not settings.skinKeystoneFrame then return end

    local keystoneFrame = _G.ChallengesKeystoneFrame
    if not keystoneFrame or keystoneFrame.h3z0uiSkinned then return end

    -- Get skin colors from H3z0UI system
    local H3z0UI = _G.H3z0UI
    local sr, sg, sb, sa
    local bgr, bgg, bgb, bga
    if H3z0UI and H3z0UI.GetSkinColor then
        sr, sg, sb, sa = H3z0UI:GetSkinColor()
    else
        sr, sg, sb, sa = 0.2, 1.0, 0.6, 1  -- Fallback mint
    end
    if H3z0UI and H3z0UI.GetSkinBgColor then
        bgr, bgg, bgb, bga = H3z0UI:GetSkinBgColor()
    else
        bgr, bgg, bgb, bga = 0.05, 0.05, 0.05, 0.95  -- Fallback dark
    end

    -- Create backdrop
    CreateH3z0UIBackdrop(keystoneFrame, sr, sg, sb, sa, bgr, bgg, bgb, bga)

    -- Hide Blizzard decorations via hooks
    hooksecurefunc(keystoneFrame, "Reset", HideBlizzardDecorations)
    keystoneFrame:HookScript("OnShow", HideBlizzardDecorations)

    -- Style fonts
    if keystoneFrame.DungeonName then
        keystoneFrame.DungeonName:SetFont(STANDARD_TEXT_FONT, 22, FONT_FLAGS)
        keystoneFrame.DungeonName:SetTextColor(unpack(COLORS.text))
    end

    if keystoneFrame.TimeLimit then
        keystoneFrame.TimeLimit:SetFont(STANDARD_TEXT_FONT, 16, FONT_FLAGS)
        keystoneFrame.TimeLimit:SetTextColor(unpack(COLORS.textMuted))
    end

    if keystoneFrame.Instructions then
        keystoneFrame.Instructions:SetFont(STANDARD_TEXT_FONT, 11, FONT_FLAGS)
        keystoneFrame.Instructions:SetTextColor(unpack(COLORS.textMuted))
    end

    -- Style buttons
    StyleButton(keystoneFrame.StartButton, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    StyleCloseButton(keystoneFrame.CloseButton)

    -- Style keystone slot
    StyleKeystoneSlot(keystoneFrame.KeystoneSlot, sr, sg, sb, sa)

    -- Store skin color for affix hook
    keystoneFrame.h3z0uiSkinColor = { sr, sg, sb, sa }

    -- Style affix icons when keystone is slotted
    hooksecurefunc(keystoneFrame, "OnKeystoneSlotted", function(f)
        local r, g, b, a = unpack(f.h3z0uiSkinColor or { 0.2, 1.0, 0.6, 1 })
        for i = 1, 4 do
            local affix = f["Affix" .. i]
            if affix and affix.Portrait then
                if not affix.h3z0uiBorder then
                    affix.h3z0uiBorder = affix:CreateTexture(nil, "OVERLAY")
                    affix.h3z0uiBorder:SetPoint("TOPLEFT", affix.Portrait, -1, 1)
                    affix.h3z0uiBorder:SetPoint("BOTTOMRIGHT", affix.Portrait, 1, -1)
                    affix.h3z0uiBorder:SetColorTexture(r, g, b, a)
                    affix.h3z0uiBorder:SetDrawLayer("OVERLAY", -1)
                end
            end
        end
    end)

    keystoneFrame.h3z0uiSkinned = true
end

-- Refresh colors on already-skinned keystone frame (for live preview)
local function RefreshKeystoneColors()
    local keystoneFrame = _G.ChallengesKeystoneFrame
    if not keystoneFrame or not keystoneFrame.h3z0uiSkinned then return end

    -- Get current colors
    local H3z0UI = _G.H3z0UI
    local sr, sg, sb, sa = 0.2, 1.0, 0.6, 1
    local bgr, bgg, bgb, bga = 0.05, 0.05, 0.05, 0.95

    if H3z0UI and H3z0UI.GetSkinColor then
        sr, sg, sb, sa = H3z0UI:GetSkinColor()
    end
    if H3z0UI and H3z0UI.GetSkinBgColor then
        bgr, bgg, bgb, bga = H3z0UI:GetSkinBgColor()
    end

    -- Update main frame backdrop
    if keystoneFrame.h3z0uiBackdrop then
        keystoneFrame.h3z0uiBackdrop:SetBackdropColor(bgr, bgg, bgb, bga)
        keystoneFrame.h3z0uiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
    end

    -- Update button backdrop
    if keystoneFrame.StartButton and keystoneFrame.StartButton.h3z0uiBackdrop then
        local btnBgR = math.min(bgr + 0.07, 1)
        local btnBgG = math.min(bgg + 0.07, 1)
        local btnBgB = math.min(bgb + 0.07, 1)
        keystoneFrame.StartButton.h3z0uiBackdrop:SetBackdropColor(btnBgR, btnBgG, btnBgB, 1)
        keystoneFrame.StartButton.h3z0uiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
        keystoneFrame.StartButton.h3z0uiSkinColor = { sr, sg, sb, sa }
    end

    -- Update keystone slot border
    if keystoneFrame.KeystoneSlot and keystoneFrame.KeystoneSlot.h3z0uiBorder then
        keystoneFrame.KeystoneSlot.h3z0uiBorder:SetBackdropBorderColor(sr, sg, sb, sa)
    end

    -- Update affix borders
    for i = 1, 4 do
        local affix = keystoneFrame["Affix" .. i]
        if affix and affix.h3z0uiBorder then
            affix.h3z0uiBorder:SetColorTexture(sr, sg, sb, sa)
        end
    end

    -- Update stored color for future affix borders
    keystoneFrame.h3z0uiSkinned = true
    keystoneFrame.h3z0uiSkinColor = { sr, sg, sb, sa }
end

-- Expose refresh function globally
_G.H3z0UI_RefreshKeystoneColors = RefreshKeystoneColors

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_ChallengesUI" then
        if ChallengesKeystoneFrame then
            SkinKeystoneFrame()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
