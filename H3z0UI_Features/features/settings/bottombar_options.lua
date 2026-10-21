--[[
    H3z0 UI Options - Bottom Bar (H3z0 Features)
    The Bottom Bar is the Info Bar: this page has the H3z0 switches; the
    widgets of every zone are set on the Bottom Bar page of the sidebar.
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local FORM_ROW = 32

local function Refresh()
    if _G.H3z0UI_RefreshBottomBar then
        _G.H3z0UI_RefreshBottomBar()
    elseif _G.H3z0UI_RefreshInfoBar then
        _G.H3z0UI_RefreshInfoBar()
    end
end

local function OpenInfoBarPage()
    local frame = GUI.MainFrame
    if not (frame and frame._tiles) then return end
    for _, tile in ipairs(frame._tiles) do
        if tile.id == "infobar" then
            GUI:SelectFeatureTile(frame, tile.index, { subPageIndex = 2 })
            return
        end
    end
end

local function Build(tabContent)
    local y = -10
    local PAD = Shared.PADDING or 10
    local db = Shared.GetDB()
    local ib = db and db.infobar
    GUI:SetSearchContext({ tabIndex = 18, tabName = "Bottom Bar", subTabIndex = 1, subTabName = "Bottom Bar" })

    local function Place(widget, h)
        widget:SetPoint("TOPLEFT", PAD, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - (h or FORM_ROW)
        return widget
    end
    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PAD, y)
        y = y - header.gap
    end
    local function Info(text, h)
        local label = GUI:CreateLabel(tabContent, text, 11, C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        y = y - (h or 22)
    end
    local function Button(label, text, onClick)
        local row = CreateFrame("Frame", nil, tabContent)
        row:SetHeight(FORM_ROW)
        local l = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        l:SetPoint("LEFT", 0, 0)
        if GUI.FitFormLabel then GUI.FitFormLabel(l) end
        l:SetText(label)
        l:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        local btn = GUI:CreateButton(row, text, 160, 24, onClick)
        btn:SetPoint("LEFT", row, "LEFT", (GUI.FORM_CONTROL_X or 232), 0)
        Place(row)
        return btn
    end

    if not ib then
        Info("Bottom Bar settings are not loaded.")
        tabContent:SetHeight(80)
        return
    end
    if ib.h3zHideBlizzardMenus == nil then ib.h3zHideBlizzardMenus = true end

    Section("Bottom Bar")
    Info("The Bottom Bar is the full-width Info Bar: menu icons and spec on the left, the clock in the middle, professions, gold, bags and location on the right.", 34)
    Place(GUI:CreateFormCheckbox(tabContent, "Show Bottom Bar", "enabled", ib, Refresh))
    Place(GUI:CreateFormDropdown(tabContent, "Position", {
        { value = "BOTTOM", text = "Bottom of the screen" },
        { value = "TOP", text = "Top of the screen" },
    }, "position", ib, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Hide Blizzard Micro Menu and Bags", "h3zHideBlizzardMenus", ib, Refresh))
    Info("The bar's menu icons replace the micro menu and the bag bar. Turning the Bottom Bar off brings them back.", 22)

    Section("Look")
    Place(GUI:CreateFormSlider(tabContent, "Height", 16, 48, 1, "height", ib, Refresh))
    Place(GUI:CreateFormSlider(tabContent, "Font Size", 8, 20, 1, "fontSize", ib, Refresh))
    if ib.menuIconSize == nil then ib.menuIconSize = 0 end
    if ib.menuIconSpacing == nil then ib.menuIconSpacing = 6 end
    Place(GUI:CreateFormSlider(tabContent, "Menu Icon Size (0 = fit the bar)", 0, 32, 1, "menuIconSize", ib, Refresh))
    Place(GUI:CreateFormSlider(tabContent, "Menu Icon Spacing", 1, 16, 1, "menuIconSpacing", ib, Refresh))
    Place(GUI:CreateFormSlider(tabContent, "Background Opacity", 0, 100, 5, "bgOpacity", ib, Refresh))
    Place(GUI:CreateFormSlider(tabContent, "Border Size", 0, 4, 1, "borderSize", ib, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Fade Out Until Mouseover", "mouseoverFade", ib, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Hide in Combat", "hideInCombat", ib, Refresh))

    Section("Widgets")
    Info("Pick what every zone shows (left, center, right) on the Widgets & Zones tab.", 22)
    Button("Widgets & Zones", "Open", OpenInfoBarPage)
    Button("H3z0 Layout", "Reset", function()
        local BB = ns.H3z0BottomBar
        if BB and BB.ApplyPreset then
            BB.ApplyPreset(ib)
            Refresh()
        end
    end)
    Info("Reset puts the H3z0 layout back: menu icons, spec | clock | professions, gold, bags, location.", 22)

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_BottomBarOptions = {
    BuildBottomBarTab = function(tabContent) Build(tabContent) end,
}
