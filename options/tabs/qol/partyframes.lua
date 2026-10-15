--[[
    H3z0UI Options - Party Frames Tab
    Settings of the H3z0 UI party frames (portrait ring, name, health/power, auras)
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors

local Shared = ns.H3z0UI_Options

local function BuildPartyFramesTab(tabContent)
    local y = -10
    local FORM_ROW = 32
    local PADDING = Shared.PADDING
    local db = Shared.GetDB()

    GUI:SetSearchContext({tabIndex = 1, tabName = "General & QoL", subTabIndex = 17, subTabName = "Party Frames"})

    local pf = db and db.partyFrames
    if not pf then return end

    local function Refresh()
        if _G.H3z0UI_RefreshPartyFrames then _G.H3z0UI_RefreshPartyFrames() end
    end

    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PADDING, y)
        y = y - header.gap
    end

    local function Place(widget)
        widget:SetPoint("TOPLEFT", PADDING, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    local function Check(label, key) Place(GUI:CreateFormCheckbox(tabContent, label, key, pf, Refresh)) end
    local function Slider(label, min, max, step, key) Place(GUI:CreateFormSlider(tabContent, label, min, max, step, key, pf, Refresh)) end

    local function Info(text, height)
        local label = GUI:CreateLabel(tabContent, text, 10, C.textMuted)
        label:SetPoint("TOPLEFT", PADDING, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        label:SetJustifyH("LEFT")
        y = y - (height or 20)
    end

    Section("Enable/Disable Party Frames")
    Check("H3z0 UI Party Frames", "enabled")
    Info("Own party frames with a round portrait, level, role, name, health/power and auras. Click targets, right click opens the menu. Shift+drag a frame to move the list. If you use another party frame addon, turn this off.", 44)
    Check("Hide Blizzard Party Frames", "hideBlizzard")
    Check("Show Yourself In The List", "showPlayer")

    local previewBtn = GUI:CreateButton(tabContent, "Preview (on/off)", 150, 26, function()
        if SlashCmdList and SlashCmdList["H3Z0PARTY"] then SlashCmdList["H3Z0PARTY"]("test") end
    end)
    previewBtn:SetPoint("TOPLEFT", PADDING, y)
    local resetBtn = GUI:CreateButton(tabContent, "Reset Position", 150, 26, function()
        if SlashCmdList and SlashCmdList["H3Z0PARTY"] then SlashCmdList["H3Z0PARTY"]("reset") end
    end)
    resetBtn:SetPoint("LEFT", previewBtn, "RIGHT", 10, 0)
    y = y - 38

    Section("Layout")
    Slider("Scale", 0.5, 2.0, 0.05, "scale")
    Slider("Spacing", 0, 40, 1, "spacing")
    Check("Grow Upwards", "growUp")
    Slider("Portrait Size", 24, 90, 1, "portraitSize")
    Slider("Bar Width", 50, 220, 1, "barWidth")
    Slider("Health Bar Height", 6, 30, 1, "healthHeight")
    Slider("Power Bar Height", 2, 14, 1, "powerHeight")
    Slider("Font Size", 8, 18, 1, "fontSize")

    Section("Elements")
    Check("Show Power Bar", "showPower")
    Check("Show Role Icon", "showRole")
    Check("Show Level", "showLevel")
    Check("Show Leader Crown", "showLeader")
    Check("Fade Members Out Of Range", "rangeFade")

    Section("Colors")
    Check("Class Color Names", "classColorName")
    Check("Class Color Health Bars", "classColorHealth")
    Check("Class Color Portrait Ring", "classColorRing")

    Section("Auras")
    Check("Show Auras", "showAuras")
    Check("Show Buffs", "showBuffs")
    Check("Show Debuffs", "showDebuffs")
    Slider("Aura Icon Size", 12, 36, 1, "auraSize")
    Slider("Max Auras", 1, 12, 1, "auraMax")

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_PartyFramesOptions = {
    BuildPartyFramesTab = BuildPartyFramesTab
}
