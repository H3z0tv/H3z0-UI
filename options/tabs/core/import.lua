local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options
local H3z0UICore = ns.Addon

-- Local references for shared infrastructure
local CreateScrollableContent = Shared.CreateScrollableContent

local function GetCore()
    return (_G.H3z0UI and _G.H3z0UI.H3z0UICore) or ns.Addon
end

--------------------------------------------------------------------------------
-- Helper: Create a scrollable text box container
--------------------------------------------------------------------------------
local function SafeGetPixelSize(frame)
    local core = ns.Addon
    return (core and core.GetPixelSize and core:GetPixelSize(frame)) or 1
end

local function CreateScrollableTextBox(parent, height, text)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetHeight(height)
    local px = SafeGetPixelSize(container)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = px,
    })
    container:SetBackdropColor(0.1, 0.1, 0.1, 1)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- ScrollFrame to contain the EditBox
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)

    -- Style the scroll bar
    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName().."ScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 18)
    end

    -- EditBox inside ScrollFrame
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() or 400)
    editBox:SetText(text or "")
    editBox:SetCursorPosition(0)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Update width when container is sized
    container:SetScript("OnSizeChanged", function(self)
        editBox:SetWidth(self:GetWidth() - 36)
    end)

    scrollFrame:SetScrollChild(editBox)

    container.editBox = editBox
    container.scrollFrame = scrollFrame
    return container
end

--------------------------------------------------------------------------------
-- SUB-TAB BUILDER: Import/Export (user profile import/export)
--------------------------------------------------------------------------------
local function BuildImportExportTab(tabContent)
    local y = -10
    local PAD = 10

    GUI:SetSearchContext({tabIndex = 14, tabName = "Import", subTabIndex = 1, subTabName = "Import/Export"})

    local info = GUI:CreateLabel(tabContent, "Import and export H3z0 UI profiles", 11, C.textMuted)
    info:SetPoint("TOPLEFT", PAD, y)
    info:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
    info:SetJustifyH("LEFT")
    y = y - 28

    -- Export Section Header
    local exportHeader = GUI:CreateSectionHeader(tabContent, "Export Current Profile")
    exportHeader:SetPoint("TOPLEFT", PAD, y)
    y = y - exportHeader.gap

    -- Create a scroll frame for the export box
    local exportScroll = CreateFrame("ScrollFrame", nil, tabContent, "UIPanelScrollFrameTemplate")
    exportScroll:SetPoint("TOPLEFT", PAD, y)
    exportScroll:SetPoint("TOPRIGHT", -PAD - 20, y)
    exportScroll:SetHeight(100)

    local exportEditBox = CreateFrame("EditBox", nil, exportScroll)
    exportEditBox:SetMultiLine(true)
    exportEditBox:SetAutoFocus(false)
    exportEditBox:SetFont(GUI.FONT_PATH, 11, "")
    exportEditBox:SetTextColor(0.8, 0.85, 0.9, 1)
    exportEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    exportEditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    exportScroll:SetScrollChild(exportEditBox)

    -- Set width dynamically when scroll frame is sized
    exportScroll:SetScript("OnSizeChanged", function(self)
        exportEditBox:SetWidth(self:GetWidth() - 10)
    end)

    -- Background for export box
    local exportBg = tabContent:CreateTexture(nil, "BACKGROUND")
    exportBg:SetPoint("TOPLEFT", exportScroll, -5, 5)
    exportBg:SetPoint("BOTTOMRIGHT", exportScroll, 25, -5)
    exportBg:SetColorTexture(0.05, 0.07, 0.1, 0.9)

    -- Border for export box
    local exportBorder = CreateFrame("Frame", nil, tabContent, "BackdropTemplate")
    exportBorder:SetPoint("TOPLEFT", exportScroll, -6, 6)
    exportBorder:SetPoint("BOTTOMRIGHT", exportScroll, 26, -6)
    local pxExport = SafeGetPixelSize(exportBorder)
    exportBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = pxExport,
    })
    exportBorder:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

    -- Populate export string
    local function RefreshExportString()
        local core = GetCore()
        if core and core.ExportProfileToString then
            local str = core:ExportProfileToString()
            exportEditBox:SetText(str or "Error generating export string")
        else
            exportEditBox:SetText("H3z0UICore not available")
        end
    end
    RefreshExportString()

    y = y - 115

    -- SELECT ALL button (themed)
    local selectBtn = GUI:CreateButton(tabContent, "SELECT ALL", 120, 28, function()
        RefreshExportString()
        exportEditBox:SetFocus()
        exportEditBox:HighlightText()
    end)
    selectBtn:SetPoint("TOPLEFT", PAD, y)

    -- Hint text
    local copyHint = GUI:CreateLabel(tabContent, "then press Ctrl+C to copy", 11, C.textMuted)
    copyHint:SetPoint("LEFT", selectBtn, "RIGHT", 12, 0)

    y = y - 50

    -- Import Section Header
    local importHeader = GUI:CreateSectionHeader(tabContent, "Import Profile String")
    importHeader:SetPoint("TOPLEFT", PAD, y)

    -- Paste hint next to header
    local pasteHint = GUI:CreateLabel(tabContent, "press Ctrl+V to paste", 11, C.textMuted)
    pasteHint:SetPoint("LEFT", importHeader, "RIGHT", 12, 0)

    y = y - importHeader.gap

    -- Import EditBox (user pastes string here)
    local importScroll = CreateFrame("ScrollFrame", nil, tabContent, "UIPanelScrollFrameTemplate")
    importScroll:SetPoint("TOPLEFT", PAD, y)
    importScroll:SetPoint("TOPRIGHT", -PAD - 20, y)
    importScroll:SetHeight(100)

    local importEditBox = CreateFrame("EditBox", nil, importScroll)
    importEditBox:SetMultiLine(true)
    importEditBox:SetAutoFocus(false)
    importEditBox:SetFont(GUI.FONT_PATH, 11, "")
    importEditBox:SetTextColor(0.8, 0.85, 0.9, 1)
    importEditBox:SetHeight(100)
    importEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    importScroll:SetScrollChild(importEditBox)

    -- Set width dynamically when scroll frame is sized
    importScroll:SetScript("OnSizeChanged", function(self)
        importEditBox:SetWidth(self:GetWidth() - 10)
    end)

    -- Background for import box - make it clickable to focus the editbox
    local importBg = CreateFrame("Button", nil, tabContent)
    importBg:SetPoint("TOPLEFT", importScroll, -5, 5)
    importBg:SetPoint("BOTTOMRIGHT", importScroll, 25, -5)
    importBg:SetScript("OnClick", function() importEditBox:SetFocus() end)

    local importBgTex = importBg:CreateTexture(nil, "BACKGROUND")
    importBgTex:SetAllPoints()
    importBgTex:SetColorTexture(0.05, 0.07, 0.1, 0.9)

    -- Border for import box
    local importBorder = CreateFrame("Frame", nil, tabContent, "BackdropTemplate")
    importBorder:SetPoint("TOPLEFT", importScroll, -6, 6)
    importBorder:SetPoint("BOTTOMRIGHT", importScroll, 26, -6)
    local pxImport = SafeGetPixelSize(importBorder)
    importBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = pxImport,
    })
    importBorder:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

    y = y - 115

    -- IMPORT AND RELOAD button (themed)
    local importBtn = GUI:CreateButton(tabContent, "IMPORT AND RELOAD", 200, 28, function()
        local str = importEditBox:GetText()
        if not str or str == "" then
            print("|cffff0000H3z0 UI: No import string provided.|r")
            return
        end
        local core = GetCore()
        if core and core.ImportProfileFromString then
            local ok, err = core:ImportProfileFromString(str)
            if ok then
                print("|cff34D399H3z0 UI:|r Profile imported successfully!")
                print("|cff34D399H3z0 UI:|r Please type |cFFFFD700/reload|r to apply changes.")
            else
                print("|cffff0000H3z0 UI: Import failed: " .. (err or "Unknown error") .. "|r")
            end
        else
            print("|cffff0000H3z0 UI: H3z0UICore not available for import.|r")
        end
    end)
    importBtn:SetPoint("TOPLEFT", PAD, y)
    y = y - 40

    tabContent:SetHeight(math.abs(y) + 20)
end

--------------------------------------------------------------------------------
-- SUB-TAB BUILDER: H3z0UI's Strings (preset import strings)
--------------------------------------------------------------------------------
local function BuildH3z0UIStringsTab(tabContent)
    local y = -10
    local PAD = 10
    local BOX_HEIGHT = 70

    GUI:SetSearchContext({tabIndex = 14, tabName = "Import", subTabIndex = 2, subTabName = "H3z0 UI's Strings"})

    local info = GUI:CreateLabel(tabContent, "H3z0 UI's personal import strings - select all and copy", 11, C.textMuted)
    info:SetPoint("TOPLEFT", PAD, y)
    info:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
    info:SetJustifyH("LEFT")
    y = y - 28

    -- Store all text boxes for clearing selections
    local allTextBoxes = {}

    -- Helper to clear all selections except the target
    local function selectOnly(targetEditBox)
        for _, editBox in ipairs(allTextBoxes) do
            if editBox ~= targetEditBox then
                editBox:ClearFocus()
                editBox:HighlightText(0, 0)
            end
        end
        targetEditBox:SetFocus()
        targetEditBox:HighlightText()
    end

    -- =====================================================
    -- EDIT MODE STRING
    -- =====================================================
    local editModeHeader = GUI:CreateSectionHeader(tabContent, "H3z0 UI Edit Mode String")
    editModeHeader:SetPoint("TOPLEFT", PAD, y)
    y = y - editModeHeader.gap

    local editModeString = ""
    if _G.H3z0UI and _G.H3z0UI.imports and _G.H3z0UI.imports.EditMode then
        editModeString = _G.H3z0UI.imports.EditMode.data or ""
    end

    local editModeContainer = CreateScrollableTextBox(tabContent, BOX_HEIGHT, editModeString)
    editModeContainer:SetPoint("TOPLEFT", PAD, y)
    editModeContainer:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
    table.insert(allTextBoxes, editModeContainer.editBox)

    y = y - BOX_HEIGHT - 8

    local editModeBtn = GUI:CreateButton(tabContent, "SELECT ALL", 120, 24, function()
        selectOnly(editModeContainer.editBox)
    end)
    editModeBtn:SetPoint("TOPLEFT", PAD, y)

    local editModeTip = GUI:CreateLabel(tabContent, "then press Ctrl+C to copy", 11, C.textMuted)
    editModeTip:SetPoint("LEFT", editModeBtn, "RIGHT", 10, 0)
    y = y - 40

    -- =====================================================
    -- H3z0UI IMPORT/EXPORT STRING - DEFAULT PROFILE
    -- =====================================================
    local h3z0uiHeader = GUI:CreateSectionHeader(tabContent, "H3z0 UI Import/Export String - Default Profile")
    h3z0uiHeader:SetPoint("TOPLEFT", PAD, y)
    y = y - h3z0uiHeader.gap

    local h3z0uiString = ""
    if _G.H3z0UI and _G.H3z0UI.imports and _G.H3z0UI.imports.H3z0UIProfile then
        h3z0uiString = _G.H3z0UI.imports.H3z0UIProfile.data or ""
    end

    local h3z0uiContainer = CreateScrollableTextBox(tabContent, BOX_HEIGHT, h3z0uiString)
    h3z0uiContainer:SetPoint("TOPLEFT", PAD, y)
    h3z0uiContainer:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
    table.insert(allTextBoxes, h3z0uiContainer.editBox)

    y = y - BOX_HEIGHT - 8

    local h3z0uiBtn = GUI:CreateButton(tabContent, "SELECT ALL", 120, 24, function()
        selectOnly(h3z0uiContainer.editBox)
    end)
    h3z0uiBtn:SetPoint("TOPLEFT", PAD, y)

    local h3z0uiTip = GUI:CreateLabel(tabContent, "then press Ctrl+C to copy", 11, C.textMuted)
    h3z0uiTip:SetPoint("LEFT", h3z0uiBtn, "RIGHT", 10, 0)
    y = y - 40

    -- =====================================================
    -- H3z0UI IMPORT/EXPORT STRING - DARK MODE
    -- =====================================================
    local h3z0uiDarkHeader = GUI:CreateSectionHeader(tabContent, "H3z0 UI Import/Export String - Dark Mode")
    h3z0uiDarkHeader:SetPoint("TOPLEFT", PAD, y)
    y = y - h3z0uiDarkHeader.gap

    local h3z0uiDarkString = ""
    if _G.H3z0UI and _G.H3z0UI.imports and _G.H3z0UI.imports.H3z0UIProfileDarkMode then
        h3z0uiDarkString = _G.H3z0UI.imports.H3z0UIProfileDarkMode.data or ""
    end

    local h3z0uiDarkContainer = CreateScrollableTextBox(tabContent, BOX_HEIGHT, h3z0uiDarkString)
    h3z0uiDarkContainer:SetPoint("TOPLEFT", PAD, y)
    h3z0uiDarkContainer:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
    table.insert(allTextBoxes, h3z0uiDarkContainer.editBox)

    y = y - BOX_HEIGHT - 8

    local h3z0uiDarkBtn = GUI:CreateButton(tabContent, "SELECT ALL", 120, 24, function()
        selectOnly(h3z0uiDarkContainer.editBox)
    end)
    h3z0uiDarkBtn:SetPoint("TOPLEFT", PAD, y)

    local h3z0uiDarkTip = GUI:CreateLabel(tabContent, "then press Ctrl+C to copy", 11, C.textMuted)
    h3z0uiDarkTip:SetPoint("LEFT", h3z0uiDarkBtn, "RIGHT", 10, 0)
    y = y - 40

    tabContent:SetHeight(math.abs(y) + 30)
end

--------------------------------------------------------------------------------
-- PAGE: H3z0UI Import/Export (with sub-tabs)
--------------------------------------------------------------------------------
local function CreateImportExportPage(parent)
    local scroll, content = CreateScrollableContent(parent)

    GUI:CreateSubTabs(content, {
        {name = "Import/Export", builder = BuildImportExportTab},
        {name = "H3z0 UI's Strings", builder = BuildH3z0UIStringsTab},
    })

    content:SetHeight(550)
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------
ns.H3z0UI_ImportOptions = {
    CreateImportExportPage = CreateImportExportPage,
    BuildImportExportTab = BuildImportExportTab,
    BuildH3z0UIStringsTab = BuildH3z0UIStringsTab,
}
