local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI option pages: widget helpers they use on top of the framework
---------------------------------------------------------------------------

local H3z0UI = _G.H3z0UI
local GUI = H3z0UI and H3z0UI.GUI
if not GUI then return end
local C = GUI.Colors or {}

-- font of the options window (H3z0 UI font)
local function GetFontPath()
    if GUI.GetFontPath then
        local ok, path = pcall(GUI.GetFontPath, GUI)
        if ok and path then return path end
    end
    if GUI.FONT_PATH then return GUI.FONT_PATH end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    return (LSM and LSM:Fetch("font", "H3z0UI", true)) or STANDARD_TEXT_FONT
end

-- UI version picked in H3z0 Features > UI Look (classic / modern / v2)
if not GUI.CurrentLook then
    function GUI:CurrentLook()
        local Setup = _G.H3z0UI_Setup
        local ok, look = pcall(function() return Setup and Setup.CurrentLook and Setup.CurrentLook() end)
        return (ok and look) or "classic"
    end
end

if not GUI.LookIs then
    function GUI:LookIs(...)
        local look = self:CurrentLook()
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            if type(v) == "table" then
                for _, x in ipairs(v) do if x == look then return true end end
            elseif v == look then
                return true
            end
        end
        return false
    end
end

-- Rebuild the open page after the UI version changed
if not GUI.RebuildOptions then
    function GUI:RebuildOptions()
        if self.RefreshAccentColor then pcall(self.RefreshAccentColor, self) end
        local frame = self.MainFrame
        if frame and frame:IsShown() and self.SelectFeatureTile and frame._lastTileIndex then
            local tile = frame._tiles and frame._tiles[frame._lastTileIndex]
            if tile then
                tile._built = nil
            end
        end
    end
end

-- Label column of the form rows (label left, control from FORM_CONTROL_X)
local FORM_LABEL_W = 222
if GUI.FORM_CONTROL_X == nil then GUI.FORM_CONTROL_X = 232 end
if GUI.FORM_LABEL_W == nil then GUI.FORM_LABEL_W = FORM_LABEL_W end
if not GUI.FitFormLabel then
    GUI.FitFormLabel = function(text)
        if not (text and text.SetWidth) then return end
        text:SetWidth(FORM_LABEL_W)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("MIDDLE")
        if text.SetWordWrap then text:SetWordWrap(true) end
        if text.SetMaxLines then text:SetMaxLines(2) end
    end
end

-- Simple sub-tab row inside a page (used when a H3z0 page is opened as one page)
if not GUI.CreateSubTabs then
    function GUI:CreateSubTabs(parent, tabs)
        local bar = CreateFrame("Frame", nil, parent)
        bar:SetPoint("TOPLEFT", 0, 0)
        bar:SetPoint("TOPRIGHT", 0, 0)
        bar:SetHeight(30)
        local buttons, contents, built = {}, {}, {}
        local function Select(index)
            for i, content in ipairs(contents) do
                content:SetShown(i == index)
                local b = buttons[i]
                if b and b.text then
                    local col = (i == index) and (C.accent or { 1, 1, 1 }) or (C.text or { 1, 1, 1 })
                    b.text:SetTextColor(col[1], col[2], col[3], 1)
                end
            end
            if not built[index] and tabs[index] and tabs[index].builder then
                built[index] = true
                local ok, err = pcall(tabs[index].builder, contents[index])
                if not ok then geterrorhandler()(err) end
            end
            local h = contents[index] and contents[index]:GetHeight() or 400
            parent:SetHeight(math.max(h, 100) + 34)
        end
        local x = 8
        for i, info in ipairs(tabs) do
            local b = CreateFrame("Button", nil, bar)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            b.text:SetPoint("CENTER")
            b.text:SetText(info.name or ("Tab " .. i))
            local w = math.max(60, (b.text:GetStringWidth() or 40) + 20)
            b:SetSize(w, 24)
            b:SetPoint("TOPLEFT", x, -3)
            x = x + w + 4
            b:SetScript("OnClick", function() Select(i) end)
            buttons[i] = b
            local content = CreateFrame("Frame", nil, parent)
            content:SetPoint("TOPLEFT", 0, -34)
            content:SetPoint("TOPRIGHT", 0, -34)
            content:SetHeight(400)
            content:Hide()
            contents[i] = content
        end
        Select(1)
        return bar
    end
end

---------------------------------------------------------------------------
-- Collapsible section (H3z0 UI option pages: Per-Bar Overrides, ...)
---------------------------------------------------------------------------
if not GUI.CreateCollapsibleSection then
    local H3z0UICore = ns.Addon
    local function SetFont(fontString, size, flags, color)
        fontString:SetFont(GetFontPath(), size or 12, flags or "")
        if color then fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
    end
    function GUI:CreateCollapsibleSection(parent, title, isExpandedByDefault, badgeConfig)
    local container = CreateFrame("Frame", nil, parent)
    local isExpanded = isExpandedByDefault ~= false  -- Default true

    -- Header (clickable, full width)
    local header = CreateFrame("Button", nil, container, "BackdropTemplate")
    header:SetHeight(28)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    local px = H3z0UICore:GetPixelSize(header)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = px,
    })
    header:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.6)
    header:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.5)

    -- Chevron indicator
    local chevron = header:CreateFontString(nil, "OVERLAY")
    chevron:SetFont(GetFontPath(), 12, "")
    chevron:SetPoint("LEFT", 10, 0)
    chevron:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)

    -- Title text
    local titleText = header:CreateFontString(nil, "OVERLAY")
    SetFont(titleText, 12, "", C.accent)
    titleText:SetText(title or "Section")
    titleText:SetPoint("LEFT", chevron, "RIGHT", 6, 0)

    -- Optional badge (e.g., "Override" indicator)
    local badge = nil
    if badgeConfig and badgeConfig.text then
        badge = CreateFrame("Frame", nil, header, "BackdropTemplate")
        badge:SetHeight(18)
        badge:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = px,
        })
        badge:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 0.2)
        badge:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.5)

        local badgeText = badge:CreateFontString(nil, "OVERLAY")
        badgeText:SetFont(GetFontPath(), 10, "")
        badgeText:SetText(badgeConfig.text)
        badgeText:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
        badgeText:SetPoint("CENTER", 0, 0)

        -- Auto-width based on text
        local textWidth = badgeText:GetStringWidth() or 40
        badge:SetWidth(textWidth + 12)
        badge:SetPoint("RIGHT", header, "RIGHT", -10, 0)

        -- Initial visibility based on showFunc
        if badgeConfig.showFunc then
            badge:SetShown(badgeConfig.showFunc())
        end
    end

    -- Content area
    local content = CreateFrame("Frame", nil, container)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    content:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    content._hasContent = false

    -- Update function
    local function UpdateState()
        if isExpanded then
            chevron:SetText("v")  -- Down arrow
            content:Show()
            container:SetHeight(header:GetHeight() + 4 + (content:GetHeight() or 0))
        else
            chevron:SetText(">")  -- Right arrow
            content:Hide()
            container:SetHeight(header:GetHeight())
        end
    end

    -- Click handler
    header:SetScript("OnClick", function()
        isExpanded = not isExpanded
        UpdateState()
        if container.OnExpandChanged then
            container.OnExpandChanged(isExpanded)
        end
    end)

    -- Hover effects
    header:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
    end)
    header:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.5)
    end)

    -- API methods
    container.SetExpanded = function(self, expanded)
        isExpanded = expanded
        UpdateState()
    end

    container.GetExpanded = function()
        return isExpanded
    end

    container.UpdateHeight = function()
        UpdateState()
    end

    container.SetTitle = function(self, newTitle)
        titleText:SetText(newTitle)
    end

    -- Badge update method
    container.UpdateBadge = function()
        if badge and badgeConfig and badgeConfig.showFunc then
            badge:SetShown(badgeConfig.showFunc())
        end
    end

    container.content = content
    container.header = header
    container.badge = badge

    UpdateState()
    return container
end
end

---------------------------------------------------------------------------
-- Import popup (Custom Trackers: import bars / learned spells)
---------------------------------------------------------------------------
if not GUI.ShowImportPopup then
local H3z0UICore = ns.Addon
local unpack = unpack or table.unpack
local function CreateBackdrop(frame, bgColor, borderColor)
    local px = H3z0UICore:GetPixelSize(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = px,
    })
    frame:SetBackdropColor(unpack(bgColor or C.bg))
    frame:SetBackdropBorderColor(unpack(borderColor or C.border))
end

local function SetFont(fontString, size, flags, color)
    fontString:SetFont(GetFontPath(), size or 12, flags or "")
    if color then
        fontString:SetTextColor(unpack(color))
    end
end
local function StyleScrollBar(scrollFrame)
    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName() .. "ScrollBar"]
    if not scrollBar then return end

    -- Hide default track texture
    if scrollBar.Track then
        scrollBar.Track:SetAlpha(0)
    end

    -- Style thumb to mint accent
    local thumb = scrollBar.ThumbTexture or scrollBar:GetThumbTexture()
    if thumb then
        thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7)
        thumb:SetSize(8, 40)
    end

    -- Hide up/down buttons
    local upBtn = scrollBar.ScrollUpButton or _G[scrollFrame:GetName() .. "ScrollBarScrollUpButton"]
    local downBtn = scrollBar.ScrollDownButton or _G[scrollFrame:GetName() .. "ScrollBarScrollDownButton"]
    if upBtn then upBtn:SetAlpha(0) upBtn:SetSize(1, 1) end
    if downBtn then downBtn:SetAlpha(0) downBtn:SetSize(1, 1) end
end
local ImportPopup = nil  -- Reusable popup frame

-- config = {
--     title = "Import Title",
--     hint = "Paste string below",
--     hasMerge = true/false,  -- if true, shows Merge + Replace All buttons; if false, just Import button
--     onImport = function(str) end,  -- called for single import or merge
--     onReplace = function(str) end, -- called for replace all (only if hasMerge)
--     onSuccess = function() end,     -- called after successful import (for reload prompt)
-- }
function GUI:ShowImportPopup(config)
    -- Create popup frame if it doesn't exist
    if not ImportPopup then
        local popup = CreateFrame("Frame", "H3z0UI_ImportPopup", UIParent, "BackdropTemplate")
        popup:SetSize(500, 250)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        if popup.SetFixedFrameStrata then popup:SetFixedFrameStrata(true) end  -- stays on top even if the options window changes layer
        popup:SetFrameLevel(500)
        popup:SetFrameLevel(500)
        popup:SetMovable(true)
        popup:EnableMouse(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving)
        popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
        CreateBackdrop(popup, {0.08, 0.10, 0.14, 0.98}, {C.accent[1], C.accent[2], C.accent[3], 1})

        -- Title
        popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        popup.title:SetPoint("TOP", 0, -12)
        popup.title:SetTextColor(1, 1, 1, 1)

        -- Hint text
        popup.hint = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        popup.hint:SetPoint("TOP", popup.title, "BOTTOM", 0, -4)
        SetFont(popup.hint, 11, "", C.textMuted)

        -- Background for edit area
        local editBg = CreateFrame("Frame", nil, popup, "BackdropTemplate")
        editBg:SetPoint("TOPLEFT", 12, -55)
        editBg:SetPoint("BOTTOMRIGHT", -12, 50)
        CreateBackdrop(editBg, {0.04, 0.05, 0.07, 1}, nil)

        -- Scroll frame for edit box
        local scrollFrame = CreateFrame("ScrollFrame", "H3z0UI_ImportPopupScroll", editBg, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 8, -8)
        scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)
        StyleScrollBar(scrollFrame)

        -- Edit box
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFont(GetFontPath(), 11, "")
        editBox:SetTextColor(0.85, 0.88, 0.92, 1)
        editBox:SetWidth(scrollFrame:GetWidth() - 10)
        editBox:SetScript("OnEscapePressed", function() popup:Hide() end)
        scrollFrame:SetScrollChild(editBox)
        popup.editBox = editBox
        popup.scrollFrame = scrollFrame

        scrollFrame:SetScript("OnSizeChanged", function(self)
            editBox:SetWidth(self:GetWidth() - 10)
        end)

        -- Button container (buttons are created/updated dynamically)
        popup.buttons = {}

        -- X button in corner
        local xBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
        xBtn:SetSize(22, 22)
        xBtn:SetPoint("TOPRIGHT", -6, -6)
        CreateBackdrop(xBtn, {0.12, 0.12, 0.12, 1}, nil)
        local xText = xBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        xText:SetPoint("CENTER", 0, 0)
        xText:SetText("x")
        xText:SetTextColor(0.6, 0.6, 0.6, 1)
        xBtn:SetScript("OnEnter", function(self)
            pcall(self.SetBackdropBorderColor, self, 1, 0.3, 0.3, 1)
            xText:SetTextColor(1, 0.3, 0.3, 1)
        end)
        xBtn:SetScript("OnLeave", function(self)
            pcall(self.SetBackdropBorderColor, self, C.border[1], C.border[2], C.border[3], 1)
            xText:SetTextColor(0.6, 0.6, 0.6, 1)
        end)
        xBtn:SetScript("OnClick", function() popup:Hide() end)

        popup:Hide()
        ImportPopup = popup
    end

    -- Clear existing buttons
    for _, btn in pairs(ImportPopup.buttons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(ImportPopup.buttons)

    -- Create buttons based on config
    local guiRef = self
    local function DoImport(replaceAll)
        local str = ImportPopup.editBox:GetText()
        if not str or str == "" then
            print("|cffff0000H3z0 UI:|r No import string provided")
            return
        end

        local ok, msg
        if replaceAll and config.onReplace then
            ok, msg = config.onReplace(str)
        elseif config.onImport then
            ok, msg = config.onImport(str)
        end

        if ok then
            print("|cff34D399H3z0 UI:|r " .. (msg or "Import successful"))
            ImportPopup:Hide()
            if config.onSuccess then
                config.onSuccess()
            end
        else
            print("|cffff0000H3z0 UI:|r " .. (msg or "Import failed"))
        end
    end

    if config.hasMerge then
        -- Merge + Replace All + Cancel layout
        local mergeBtn = guiRef:CreateButton(ImportPopup, "Merge", 100, 26, function()
            DoImport(false)
        end)
        mergeBtn:SetPoint("BOTTOMLEFT", 12, 12)
        table.insert(ImportPopup.buttons, mergeBtn)

        local replaceBtn = guiRef:CreateButton(ImportPopup, "Replace All", 100, 26, function()
            DoImport(true)
        end)
        replaceBtn:SetPoint("LEFT", mergeBtn, "RIGHT", 10, 0)
        table.insert(ImportPopup.buttons, replaceBtn)

        local cancelBtn = guiRef:CreateButton(ImportPopup, "Cancel", 80, 26, function()
            ImportPopup:Hide()
        end)
        cancelBtn:SetPoint("BOTTOMRIGHT", -12, 12)
        table.insert(ImportPopup.buttons, cancelBtn)
    else
        -- Import + Cancel layout
        local importBtn = guiRef:CreateButton(ImportPopup, "Import", 100, 26, function()
            DoImport(false)
        end)
        importBtn:SetPoint("BOTTOMLEFT", 12, 12)
        table.insert(ImportPopup.buttons, importBtn)

        local cancelBtn = guiRef:CreateButton(ImportPopup, "Cancel", 80, 26, function()
            ImportPopup:Hide()
        end)
        cancelBtn:SetPoint("BOTTOMRIGHT", -12, 12)
        table.insert(ImportPopup.buttons, cancelBtn)
    end

    -- Set content and show
    ImportPopup.title:SetText(config.title or "Import")
    ImportPopup.hint:SetText(config.hint or "Paste the import string below")
    ImportPopup.editBox:SetText("")
    ImportPopup:Show()
    ImportPopup:Raise()
    ImportPopup.editBox:SetFocus()
end
end

---------------------------------------------------------------------------
-- Small inline checkbox with a label (Minimap & Datatext > panel rows)
---------------------------------------------------------------------------
if not GUI.CreateCheckbox then
    function GUI:CreateCheckbox(parent, label, dbKey, dbTable, onChange)
        local holder = CreateFrame("Button", nil, parent)
        holder:SetHeight(20)
        local box = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        box:SetSize(16, 16)
        box:SetPoint("LEFT", 0, 0)
        box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        local bg = C.bgLight or { 0.12, 0.14, 0.18, 1 }
        local border = C.border or { 0.3, 0.3, 0.3, 1 }
        box:SetBackdropColor(bg[1], bg[2], bg[3], 1)
        box:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        local mark = box:CreateTexture(nil, "OVERLAY")
        mark:SetPoint("TOPLEFT", 3, -3)
        mark:SetPoint("BOTTOMRIGHT", -3, 3)
        local accent = C.accent or { 0.204, 0.827, 0.6, 1 }
        mark:SetColorTexture(accent[1], accent[2], accent[3], 1)
        local text = holder:CreateFontString(nil, "OVERLAY")
        text:SetFont(GetFontPath(), 11, "")
        text:SetPoint("LEFT", box, "RIGHT", 6, 0)
        text:SetText(label or "")
        local col = C.text or { 1, 1, 1, 1 }
        text:SetTextColor(col[1], col[2], col[3], 1)
        holder:SetWidth(16 + 6 + math.max(10, text:GetStringWidth() or 40))

        local function Get() return dbTable and dbKey and dbTable[dbKey] and true or false end
        local function Sync() mark:SetShown(Get()) end
        holder:SetScript("OnClick", function()
            if not (dbTable and dbKey) then return end
            dbTable[dbKey] = not Get()
            Sync()
            if onChange then onChange(dbTable[dbKey]) end
        end)
        holder.SetValue = function(_, v)
            if dbTable and dbKey then dbTable[dbKey] = v and true or false end
            Sync()
        end
        holder.GetValue = function() return Get() end
        Sync()
        return holder
    end
end
