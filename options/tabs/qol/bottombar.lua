--[[
    H3z0UI Options - Bottom Bar Tab
    Add / remove the full-width bottom info bar and customize it
    (position, size, look and what every slot shows).
    The bar is a normal datapanel with the id "bottombar", so it also shows up
    in the Minimap & Datatext page.
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options
local H3z0UICore = ns.Addon

local PANEL_ID = "bottombar"

local tabRef
local Build

local function GetPanels(db)
    if not db.h3z0uiDatatexts then db.h3z0uiDatatexts = {panels = {}} end
    if not db.h3z0uiDatatexts.panels then db.h3z0uiDatatexts.panels = {} end
    return db.h3z0uiDatatexts.panels
end

local function FindBar(db)
    for i, p in ipairs(GetPanels(db)) do
        if p.id == PANEL_ID then return p, i end
    end
end

local function Rebuild()
    if not tabRef or not Build then return end
    for _, child in ipairs({tabRef:GetChildren()}) do
        child:Hide()
        child:ClearAllPoints()
    end
    for _, region in ipairs({tabRef:GetRegions()}) do
        region:Hide()
    end
    Build(tabRef)
end

local function RefreshAll()
    if H3z0UICore and H3z0UICore.Datapanels then
        H3z0UICore.Datapanels:RefreshAll()
    end
end

Build = function(tabContent)
    tabRef = tabContent
    local y = -10
    local FORM_ROW = 32
    local PADDING = Shared.PADDING
    local db = Shared.GetDB()
    if not db then return end

    GUI:SetSearchContext({tabIndex = 1, tabName = "H3z0 Features", subTabIndex = 3, subTabName = "Bottom Bar"})

    local cfg = FindBar(db)

    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PADDING, y)
        y = y - header.gap
    end

    local function Place(widget, h)
        widget:SetPoint("TOPLEFT", PADDING, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - (h or FORM_ROW)
    end

    local function Info(text, h)
        local label = GUI:CreateLabel(tabContent, text, 10, C.textMuted)
        label:SetPoint("TOPLEFT", PADDING, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        label:SetJustifyH("LEFT")
        y = y - (h or 20)
    end

    ---------------------------------------------------------------------
    Section("Bottom Bar")
    Info("A full-width info bar with menu icons, difficulty, time, professions, gold, bags, speed and location. Add it with one click, then customize it below.", 34)

    if not cfg then
        Info("The Bottom Bar is not added.", 22)
        local addBtn = GUI:CreateButton(tabContent, "Add Bottom Bar", 200, 28, function()
            table.insert(GetPanels(db), ns.BottomBarPreset())
            RefreshAll()
            Rebuild()
        end)
        addBtn:SetPoint("TOPLEFT", PADDING, y)
        y = y - 44
        tabContent:SetHeight(math.abs(y) + 50)
        return
    end

    local function Apply()
        if H3z0UICore and H3z0UICore.Datapanels then
            H3z0UICore.Datapanels:UpdatePanel(PANEL_ID)
        end
        if _G.H3z0UI_RefreshBottomBar then _G.H3z0UI_RefreshBottomBar() end
    end

    Place(GUI:CreateFormCheckbox(tabContent, "Show Bottom Bar", "enabled", cfg, Apply))
    Place(GUI:CreateFormCheckbox(tabContent, "Lock Position (unlock to drag the bar)", "locked", cfg, function()
        if H3z0UICore and H3z0UICore.Datapanels then
            H3z0UICore.Datapanels:SetLocked(PANEL_ID, cfg.locked and true or false)
        end
    end))

    Place(GUI:CreateFormCheckbox(tabContent, "Hide Blizzard Menu & Bag Buttons While Active", "hideBlizzardMenus", cfg, Apply))
    Info("The Menu Icons slot replaces Blizzard's micro menu and bag bar (bottom right). They come back automatically when the bar is hidden or removed.", 34)

    local btnRow = CreateFrame("Frame", nil, tabContent)
    btnRow:SetSize(420, 28)
    btnRow:SetPoint("TOPLEFT", PADDING, y)

    local resetBtn = GUI:CreateButton(btnRow, "Reset to Default Layout", 200, 28, function()
        local panels = GetPanels(db)
        local _, idx = FindBar(db)
        if idx then panels[idx] = ns.BottomBarPreset() end
        RefreshAll()
        Rebuild()
    end)
    resetBtn:SetPoint("LEFT", 0, 0)

    local removeBtn = GUI:CreateButton(btnRow, "Remove Bottom Bar", 200, 28, function()
        GUI:ShowConfirmation({
            title = "Remove Bottom Bar?",
            message = "Remove the Bottom Bar and its settings?",
            warningText = "You can add it again at any time.",
            acceptText = "Remove",
            cancelText = "Cancel",
            isDestructive = true,
            onAccept = function()
                local _, idx = FindBar(db)
                if idx then table.remove(GetPanels(db), idx) end
                if H3z0UICore and H3z0UICore.Datapanels then
                    H3z0UICore.Datapanels:DeletePanel(PANEL_ID)
                end
                RefreshAll()
                Rebuild()
            end,
        })
    end)
    removeBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    y = y - 44

    ---------------------------------------------------------------------
    Section("Position & Size")

    -- the panel stores its position as {point, relPoint, x, y}
    local pos = {
        edge = (tostring(cfg.position and cfg.position[1] or "BOTTOM"):find("TOP")) and "TOP" or "BOTTOM",
        x = cfg.position and cfg.position[3] or 0,
        y = cfg.position and cfg.position[4] or 0,
    }
    local function ApplyPosition()
        cfg.position = {pos.edge, pos.edge, pos.x, pos.y}
        Apply()
    end

    Place(GUI:CreateFormDropdown(tabContent, "Screen Edge", {
        {value = "BOTTOM", text = "Bottom"},
        {value = "TOP", text = "Top"},
    }, "edge", pos, ApplyPosition))
    Place(GUI:CreateFormSlider(tabContent, "Horizontal Offset", -600, 600, 1, "x", pos, ApplyPosition))
    Place(GUI:CreateFormSlider(tabContent, "Vertical Offset", -300, 300, 1, "y", pos, ApplyPosition))

    local screenW = math.floor(UIParent:GetWidth() or 1920)
    local widthSlider
    local fullWidthCheck = GUI:CreateFormCheckbox(tabContent, "Full Screen Width", "fullWidth", cfg, function()
        if not cfg.fullWidth then cfg.width = math.min(cfg.width or 600, screenW) end
        Apply()
        Rebuild()
    end)
    Place(fullWidthCheck)
    if not cfg.fullWidth then
        widthSlider = GUI:CreateFormSlider(tabContent, "Bar Width", 200, screenW, 1, "width", cfg, Apply)
        Place(widthSlider)
    end
    Place(GUI:CreateFormSlider(tabContent, "Bar Height", 16, 60, 1, "height", cfg, Apply))

    ---------------------------------------------------------------------
    Section("Appearance")
    Place(GUI:CreateFormSlider(tabContent, "Font Size", 8, 24, 1, "fontSize", cfg, Apply))
    Place(GUI:CreateFormSlider(tabContent, "Background Opacity (%)", 0, 100, 1, "bgOpacity", cfg, Apply))

    ---------------------------------------------------------------------
    Section("Icons & Sizes")
    Info("0 = automatic (fits the bar). Icons never grow larger than their slot or the bar height, so raise Bar Height or the slot width if an icon will not get bigger.", 34)
    cfg.menuIconSize = cfg.menuIconSize or 0
    cfg.menuIconSpacing = cfg.menuIconSpacing or 0
    cfg.menuCounterSize = cfg.menuCounterSize or 11
    cfg.dtIconSize = cfg.dtIconSize or 14
    cfg.clockFontSize = cfg.clockFontSize or 0
    Place(GUI:CreateFormSlider(tabContent, "Menu Icon Size (0 = auto)", 0, 40, 1, "menuIconSize", cfg, Apply))
    Place(GUI:CreateFormSlider(tabContent, "Menu Icon Spacing (0 = auto)", 0, 30, 1, "menuIconSpacing", cfg, Apply))
    Place(GUI:CreateFormSlider(tabContent, "Menu Number Size (guild / friends / vault)", 8, 20, 1, "menuCounterSize", cfg, Apply))
    Place(GUI:CreateFormSlider(tabContent, "Datatext Icon Size (professions, speed, vault)", 8, 32, 1, "dtIconSize", cfg, Apply))
    Place(GUI:CreateFormSlider(tabContent, "Clock Text Size (0 = auto)", 0, 40, 1, "clockFontSize", cfg, Apply))
    Place(GUI:CreateFormSlider(tabContent, "Border Size (0 = none)", 0, 6, 1, "borderSize", cfg, Apply))
    Place(GUI:CreateFormColorPicker(tabContent, "Border Color", "borderColor", cfg, Apply, {noAlpha = true}))
    Place(GUI:CreateFormCheckbox(tabContent, "Accent Line", "accentLine", cfg, Apply))
    cfg.accentColor = cfg.accentColor or {0.6, 0.3, 1, 1}
    Place(GUI:CreateFormColorPicker(tabContent, "Accent Line Color", "accentColor", cfg, Apply, {noAlpha = true}))

    ---------------------------------------------------------------------
    Section("Slots")
    Info("Choose what each slot shows and how wide it is (relative width). Use (Blank) to leave a slot empty. Tip: keep the Clock slot between equal widths on both sides to keep it centered.", 46)

    Place(GUI:CreateFormSlider(tabContent, "Number of Slots", 1, 12, 1, "numSlots", cfg, function()
        cfg.slots = cfg.slots or {}
        for i = 1, cfg.numSlots do
            if not cfg.slots[i] or cfg.slots[i] == "" then cfg.slots[i] = "blank" end
        end
        Apply()
        Rebuild()
    end))

    local dtOptions = {}
    if H3z0UICore and H3z0UICore.Datatexts then
        for _, def in ipairs(H3z0UICore.Datatexts:GetAll()) do
            table.insert(dtOptions, {value = def.id, text = def.displayName})
        end
    end

    cfg.slots = cfg.slots or {}
    cfg.slotSettings = cfg.slotSettings or {}
    for i = 1, (cfg.numSlots or 8) do
        cfg.slotSettings[i] = cfg.slotSettings[i] or {shortLabel = false, noLabel = false}

        local dd = GUI:CreateFormDropdown(tabContent, "Slot " .. i, dtOptions, nil, nil, function(val)
            cfg.slots[i] = val
            Apply()
        end)
        Place(dd)
        local current = cfg.slots[i]
        if not current or current == "" then current = "blank" end
        if dd.SetValue then dd.SetValue(current) end

        Place(GUI:CreateFormCheckbox(tabContent, "Slot " .. i .. " Hide Label", "noLabel", cfg.slotSettings[i], Apply))

        cfg.slotWeights = cfg.slotWeights or {}
        local wProxy = {w = cfg.slotWeights[i] or 1}
        Place(GUI:CreateFormSlider(tabContent, "Slot " .. i .. " Width", 0.3, 4, 0.1, "w", wProxy, function()
            cfg.slotWeights[i] = wProxy.w
            Apply()
        end, {precision = 1}))
    end

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_BottomBarOptions = {
    BuildBottomBarTab = function(tabContent) Build(tabContent) end
}
