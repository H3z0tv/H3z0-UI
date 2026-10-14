--[[
    H3z0UI Options - Setup Wizard Tab  (0.22.6)
    Re-open the Setup Wizard (PC / Steam Deck, nameplate addon, features) at any time.
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local function Build(tabContent)
    local y = -10
    local PAD = Shared.PADDING

    GUI:SetSearchContext({tabIndex = 11, tabName = "Setup Wizard", subTabIndex = 1, subTabName = "Setup Wizard"})

    GUI:SetSearchSection("Setup Wizard")
    local header = GUI:CreateSectionHeader(tabContent, "Setup Wizard")
    header:SetPoint("TOPLEFT", PAD, y)
    y = y - header.gap

    local function Info(text, h, color)
        local label = GUI:CreateLabel(tabContent, text, 10, color or C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        y = y - (h or 20)
    end

    Info("Choose how H3z0 UI is set up: PC or Steam Deck / Handheld, which nameplate addon you use (Plater, Platynator, BetterBlizzPlates) and which features you want (Bottom Bar, minimap, chat, unit frames, action bars, ...). It opens automatically on a new install and you can run it again here whenever you want.", 54)

    local setup = _G.H3z0UI_Setup
    Info(setup and setup.Describe and setup.Describe() or "", 22, C.text)

    local btn = GUI:CreateButton(tabContent, "Open Setup Wizard", 200, 30, function()
        if _G.H3z0UI_Setup then _G.H3z0UI_Setup.Show() end
    end)
    btn:SetPoint("TOPLEFT", PAD, y)
    y = y - 44

    Info("Chat command: /h3z0ui setup", 20)

    tabContent:SetHeight(math.abs(y) + 50)
end

-- Main sidebar page (below Import)
local function CreateSetupPage(parent)
    local scroll, content = Shared.CreateScrollableContent(parent)
    Build(content)
    return scroll
end

ns.H3z0UI_SetupOptions = {
    BuildSetupTab = Build,
    CreateSetupPage = CreateSetupPage,
}
