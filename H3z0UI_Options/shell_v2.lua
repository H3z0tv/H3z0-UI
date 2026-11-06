local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI and H3z0UI.GUI
if not GUI or type(GUI.CreateMainFrame) ~= "function" then return end
local C = GUI.Colors

---------------------------------------------------------------------------
-- Shell v2: the new look of the options window.
-- It re-dresses the window the framework builds (header, sidebar, content
-- card, footer) in H3z0 style and adds a profile chip to the header.
-- Every page, tile and search keeps working because the frame fields they
-- use are not touched. "/h3z0ui menu classic" turns it off (after /reload).
---------------------------------------------------------------------------

local WHITE = "Interface\\Buttons\\WHITE8x8"

local function Profile()
    local core = H3z0UI.H3z0UICore or ns.Addon
    return core and core.db and core.db.profile, core
end

local function IsClassic()
    local p = Profile()
    return p and p.optionsShell == "classic"
end

local function Accent()
    local a = C.accent or { 0.204, 0.827, 0.6, 1 }
    return a[1], a[2], a[3]
end

local function Panel(frame, anchorTo, inset, fill, border, radius)
    local card = CreateFrame("Frame", nil, frame)
    card:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", -inset.l, inset.t)
    card:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", inset.r, -inset.b)
    card:SetFrameLevel(math.max(0, frame:GetFrameLevel()))
    local R = ns.UIKit and ns.UIKit.CreateRoundedSurface
    if R then
        R(card, { radius = radius or 10, bgColor = fill, borderColor = border })
    else
        local t = card:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
    end
    return card
end

local function GoToProfiles(frame)
    local _, idx = GUI:FindV2TileByID(frame, "global")
    if not idx then return end
    if frame._searchBox and frame._searchBox.editBox then frame._searchBox.editBox:SetText("") end
    if frame._searchResultsArea then frame._searchResultsArea:Hide() end
    if frame._tileContent then frame._tileContent:Show() end
    GUI:SelectFeatureTile(frame, idx, { subPageIndex = 1 })
end

local function ProfileName()
    local _, core = Profile()
    local db = core and core.db
    return db and db.GetCurrentProfile and db:GetCurrentProfile() or "Default"
end

local function Apply(frame)
    if frame._shellV2 then return end
    frame._shellV2 = true
    local r, g, b = Accent()
    local accentTex, accentLine = {}, nil

    -- 1. accent line along the top edge of the window
    accentLine = frame:CreateTexture(nil, "OVERLAY")
    accentLine:SetTexture(WHITE)
    accentLine:SetHeight(2)
    accentLine:SetPoint("TOPLEFT", 14, -1)
    accentLine:SetPoint("TOPRIGHT", -14, -1)
    accentLine:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.9), CreateColor(r, g, b, 0))

    -- 2. sidebar panel
    if frame.sidebar then
        frame._shellSidebarPanel = Panel(frame, frame.sidebar,
            { l = 0, t = 0, r = 0, b = 0 }, { 1, 1, 1, 0.025 }, { 1, 1, 1, 0.06 }, 12)
        frame._shellSidebarPanel:SetFrameLevel(math.max(0, frame.sidebar:GetFrameLevel() - 1))
    end

    -- 3. content card behind the pages
    if frame.contentArea then
        frame._shellContentCard = Panel(frame, frame.contentArea,
            { l = 6, t = 6, r = 6, b = 6 }, { 1, 1, 1, 0.022 }, { 1, 1, 1, 0.06 }, 12)
        frame._shellContentCard:SetFrameLevel(math.max(0, frame.contentArea:GetFrameLevel() - 1))
    end

    -- 4. profile chip in the header (click opens the Profiles page)
    local chip = CreateFrame("Button", nil, frame)
    chip:SetSize(150, 20)
    chip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -96, -8)
    local R = ns.UIKit and ns.UIKit.CreateRoundedSurface
    if R then
        R(chip, { radius = 10, bgColor = { r, g, b, 0.14 }, borderColor = { r, g, b, 0.5 } })
    end
    local text = chip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 10, 0)
    text:SetPoint("RIGHT", -10, 0)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
    text:SetFont(STANDARD_TEXT_FONT, 10, "")
    text:SetTextColor(1, 1, 1, 1)
    chip.text = text
    chip:SetScript("OnClick", function() GoToProfiles(frame) end)
    chip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Active profile")
        GameTooltip:AddLine("Click to open Profiles.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local function RefreshChip() text:SetText("Profile: " .. ProfileName()) end
    frame:HookScript("OnShow", RefreshChip)
    RefreshChip()
    frame._shellProfileChip = chip

    -- keep the accent line in step with the theme colour
    if type(GUI.RefreshAccentColor) == "function" then
        hooksecurefunc(GUI, "RefreshAccentColor", function()
            local ar, ag, ab = Accent()
            accentLine:SetGradient("HORIZONTAL", CreateColor(ar, ag, ab, 0.9), CreateColor(ar, ag, ab, 0))
        end)
    end
end

local original = GUI.CreateMainFrame
function GUI:CreateMainFrame(...)
    local existed = self.MainFrame ~= nil
    local frame = original(self, ...)
    if frame and not existed and not IsClassic() then
        local ok, err = pcall(Apply, frame)
        if not ok then
            frame._shellV2 = nil
            if geterrorhandler then geterrorhandler()(err) end
        end
    end
    return frame
end

ns.H3z0UI_ShellV2 = { Apply = Apply, IsClassic = IsClassic }
