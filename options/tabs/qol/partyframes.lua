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

    GUI:SetSearchContext({tabIndex = 4, tabName = "Party Frames", subTabIndex = 1, subTabName = "Party Frames"})

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

    -- the style follows the UI version (H3z0 Features > UI Look): Modern v2 = v2, else classic
    local v2 = GUI:LookIs("v2")
    Section(v2 and "Layout (Modern v2)" or "Layout")
    Info(v2 and "Bars start under a big round portrait and end round, like the Player frame. The portrait size follows the bar height."
        or "Portrait beside the bars. Modern v2 party frames come with the Modern v2 version (H3z0 Features > UI Look).", 34)
    Slider("Scale", 0.5, 2.0, 0.05, "scale")
    Slider("Spacing", 0, 40, 1, "spacing")
    Check("Grow Upwards", "growUp")
    if v2 then
        if pf.v2BarWidth == nil then pf.v2BarWidth = 120 end
        if pf.v2HealthHeight == nil then pf.v2HealthHeight = 22 end
        if pf.v2PowerHeight == nil then pf.v2PowerHeight = 4 end
        Slider("Bar Width", 80, 260, 1, "v2BarWidth")
        Slider("Health Bar Height", 12, 40, 1, "v2HealthHeight")
        Slider("Power Bar Height", 2, 12, 1, "v2PowerHeight")
    else
        Slider("Portrait Size", 24, 90, 1, "portraitSize")
        Slider("Bar Width", 50, 220, 1, "barWidth")
        Slider("Health Bar Height", 6, 30, 1, "healthHeight")
        Slider("Power Bar Height", 2, 14, 1, "powerHeight")
    end
    Slider("Font Size", 8, 18, 1, "fontSize")
    if pf.nameFontSize == nil then pf.nameFontSize = 0 end
    if pf.healthFontSize == nil then pf.healthFontSize = 0 end
    Slider("Name Font Size (0 = Font Size)", 0, 24, 1, "nameFontSize")
    Slider("Health Text Size (0 = Font Size)", 0, 24, 1, "healthFontSize")

    Section("Elements")
    Check("Show Power Bar", "showPower")
    Check("Show Role Icon", "showRole")
    Check("Show Level", "showLevel")
    Check("Show Leader Crown", "showLeader")
    Check("Fade Members Out Of Range", "rangeFade")

    Section("Colors")
    Check("Class Color Names", "classColorName")
    Check("Class Color Health Bars", "classColorHealth")
    if not v2 then Check("Class Color Portrait Ring", "classColorRing") end

    Section("Auras")
    Check("Show Auras", "showAuras")
    Check("Show Buffs", "showBuffs")
    Check("Show Debuffs", "showDebuffs")
    Slider("Aura Icon Size", 12, 36, 1, "auraSize")
    Slider("Max Auras", 1, 12, 1, "auraMax")

    tabContent:SetHeight(math.abs(y) + 50)
end

-- Own sidebar page (between General & QoL and Cooldown Manager)
local function CreatePartyFramesPage(parent)
    local scroll, content = ns.H3z0UI_Options.CreateScrollableContent(parent)
    BuildPartyFramesTab(content)
    return scroll
end

ns.H3z0UI_PartyFramesOptions = {
    BuildPartyFramesTab = BuildPartyFramesTab,
    CreatePartyFramesPage = CreatePartyFramesPage,
}
