--[[
    H3z0 UI Options - Interrupt Tracker (Gameplay)
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local FORM_ROW = 32

local function Build(tabContent)
    local y = -10
    local PAD = Shared.PADDING or 10
    local I = _G.H3z0UI_Interrupts
    local d = I and I.Settings and I.Settings()
    GUI:SetSearchContext({ tabName = "Interrupts", subTabName = "Interrupts", tileId = "h3z_interrupts", subPageIndex = 1 })

    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PAD, y)
        y = y - header.gap
    end
    local function Place(widget, hgt)
        widget:SetPoint("TOPLEFT", PAD, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - (hgt or FORM_ROW)
    end
    local function Info(text, hgt)
        local label = GUI:CreateLabel(tabContent, text, 11, C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        if label.SetWordWrap then label:SetWordWrap(true) end
        y = y - (hgt or 22)
    end

    if not (I and d) then
        Info("The Interrupt Tracker is not available on this game version.", 22)
        tabContent:SetHeight(80)
        return
    end

    local function Refresh() if _G.H3z0UI_RefreshInterrupts then _G.H3z0UI_RefreshInterrupts() end end

    Section("Interrupt Tracker")
    Info("Shows when the interrupt of every group member is ready, in the colour of their class, and a big icon with the cooldown of your own interrupt (green is ready, red is on cooldown). It sees the cast of an interrupt and counts the base cooldown of that spell, so a talent that shortens a cooldown is not known.", 60)
    Place(GUI:CreateFormCheckbox(tabContent, "Enable Interrupt Tracker", "enabled", d, function()
        Refresh()
        if _G.H3z0UI_NotifySwitch then _G.H3z0UI_NotifySwitch("moduleFlag_h3zInterrupts") end
    end))
    Place(GUI:CreateFormCheckbox(tabContent, "Show the Group List", "showList", d, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Show How Many Interrupts Everyone Did", "showCounts", d, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Show My Interrupt Icon", "showIcon", d, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Only in Dungeons and Raids", "onlyInstance", d, Refresh))
    Place(GUI:CreateFormSlider(tabContent, "Size", 0.6, 2, 0.1, "scale", d, Refresh))

    Section("Interrupts by Run")
    Info("The counts start from zero on every Mythic+ start. Every run is saved when it ends, with the interrupts of every member, to look at by dungeon (the last 30 runs). Command: /h3z0ui intlog", 46)
    local hrow = CreateFrame("Frame", nil, tabContent)
    hrow:SetHeight(FORM_ROW)
    local hl = hrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hl:SetPoint("LEFT", 0, 0)
    if GUI.FitFormLabel then GUI.FitFormLabel(hl) end
    hl:SetText("History")
    hl:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    local hb = GUI:CreateButton(hrow, "Open History", 170, 24, function() I.ShowHistory() end)
    hb:SetPoint("LEFT", hrow, "LEFT", (GUI.FORM_CONTROL_X or 232), 0)
    Place(hrow)

    Section("Place It")
    local row = CreateFrame("Frame", nil, tabContent)
    row:SetHeight(FORM_ROW)
    local l = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l:SetPoint("LEFT", 0, 0)
    if GUI.FitFormLabel then GUI.FitFormLabel(l) end
    l:SetText("Move and Test")
    l:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    local btn
    btn = GUI:CreateButton(row, "Unlock and Move", 170, 24, function()
        I.ToggleUnlock()
        local label = I.IsUnlocked() and "Lock" or "Unlock and Move"
        if btn.text and btn.text.SetText then btn.text:SetText(label) elseif btn.SetText then btn:SetText(label) end
    end)
    btn:SetPoint("LEFT", row, "LEFT", (GUI.FORM_CONTROL_X or 232), 0)
    Place(row)
    Info("Unlock shows four example players and a counting icon. Drag the list and the icon with the left mouse button where you want them, then press Lock. The place is saved.", 34)

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_InterruptOptions = { BuildInterruptsTab = function(tabContent) Build(tabContent) end }
