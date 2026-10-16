--[[
    H3z0UI Options - Quick Access Tab
    Settings for the Group Finder Quick Access panel
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local function BuildQuickAccessTab(tabContent)
    local y = -10
    local FORM_ROW = 32
    local PADDING = Shared.PADDING
    local db = Shared.GetDB()

    GUI:SetSearchContext({tabIndex = 3, tabName = "General & QoL", subTabIndex = 12, subTabName = "Quick Access"})

    local qa = db and db.quickAccess
    if not qa then return end

    local function Refresh()
        if _G.H3z0UI_RefreshQuickAccess then _G.H3z0UI_RefreshQuickAccess() end
    end

    local function Place(widget)
        widget:SetPoint("TOPLEFT", PADDING, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    GUI:SetSearchSection("Quick Access")
    local header = GUI:CreateSectionHeader(tabContent, "Quick Access (Group Finder)")
    header:SetPoint("TOPLEFT", PADDING, y)
    y = y - header.gap

    Place(GUI:CreateFormCheckbox(tabContent, "Enable Quick Access Panel", "enabled", qa, Refresh))

    local info = GUI:CreateLabel(tabContent, "Adds a panel next to the Group Finder (Premade Groups tab) with one-click Mythic+, Raids, Delves, Quest and Custom searches, plus filters for dungeon, score and roles.", 10, C.textMuted)
    info:SetPoint("TOPLEFT", PADDING, y)
    info:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    info:SetJustifyH("LEFT")
    y = y - 34

    Place(GUI:CreateFormDropdown(tabContent, "Panel Position", {
        {value = "AUTO", text = "Automatic (left if there is room)"},
        {value = "LEFT", text = "Left of Group Finder"},
        {value = "RIGHT", text = "Right of Group Finder"},
        {value = "BELOW", text = "Below Group Finder"},
    }, "side", qa, Refresh))
    Place(GUI:CreateFormSlider(tabContent, "Horizontal Offset", -400, 400, 1, "offsetX", qa, Refresh))
    Place(GUI:CreateFormSlider(tabContent, "Vertical Offset", -400, 400, 1, "offsetY", qa, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Show Listing Info (Raider.IO) In Panel", "infoInPanel", qa, Refresh))
    local infoNote = GUI:CreateLabel(tabContent, "When hovering a group, its info (including Raider.IO score and best runs) is shown in a box attached to this panel instead of the normal tooltip.", 10, C.textMuted)
    infoNote:SetPoint("TOPLEFT", PADDING, y)
    infoNote:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    infoNote:SetJustifyH("LEFT")
    y = y - 34
    Place(GUI:CreateFormCheckbox(tabContent, "Otherwise: Move Tooltip Next to Panel", "moveTooltip", qa, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Lock Panel (disable drag to move)", "locked", qa, Refresh))
    local resetBtn = GUI:CreateButton(tabContent, "Reset Dragged Position", 220, 28, function()
        qa.customPos = nil
        Refresh()
    end)
    resetBtn:SetPoint("TOPLEFT", PADDING, y)
    y = y - 40
    Place(GUI:CreateFormSlider(tabContent, "Panel Scale", 0.6, 1.6, 0.05, "scale", qa, Refresh, {precision = 2}))
    Place(GUI:CreateFormCheckbox(tabContent, "Show Filters While Searching", "showFilters", qa, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Remember Filters Between Sessions", "rememberFilters", qa, Refresh))

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_QuickAccessOptions = {
    BuildQuickAccessTab = BuildQuickAccessTab
}
