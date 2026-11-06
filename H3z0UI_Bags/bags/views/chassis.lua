-- luacheck: read globals MoneyInputFrame_GetCopper MoneyInputFrame_ResetMoney
local ADDON_NAME, ns = ...
local Bags = ns.Bags or {}; ns.Bags = Bags
local UIKit = ns.UIKit
local Helpers = ns.Helpers

function Bags.CJKFont(fs, p, s, f)
    if ns.Helpers and ns.Helpers.ApplyFontWithFallback then
        ns.Helpers.ApplyFontWithFallback(fs, p, s, f)
    else
        fs:SetFont(p, s, f)
    end
end
local CJKFont = Bags.CJKFont

local Chassis = {}
Bags.Chassis = Chassis

local windows = {}

local settingsGetter
local function BagSettings()
    settingsGetter = settingsGetter or (Helpers.CreateDBGetter and Helpers.CreateDBGetter("bags"))
    return settingsGetter and settingsGetter() or nil
end
local function Appearance() local s = BagSettings(); return s and s.appearance end
local function Behavior() local s = BagSettings(); return s and s.behavior end

-- window padding: smaller with "Reduce Spacing"
local function CurPad()
    local a = Appearance()
    return (a and a.reduceSpacing) and 4 or 8
end

---------------------------------------------------------------------------
-- Header buttons shown only while Alt is held (Show Buttons: While Alt Held)
---------------------------------------------------------------------------
local altButtons = {}
local function ButtonsHidden()
    local a = Appearance()
    return a and a.showButtons == "alt" and not IsAltKeyDown()
end
local function ApplyAltButtons()
    local hide = ButtonsHidden()
    for btn in pairs(altButtons) do
        btn:SetAlpha(hide and 0 or 1)
        btn:EnableMouse(not hide)
    end
end
function Chassis.RegisterAltButton(btn)
    if not btn then return end
    altButtons[btn] = true
    ApplyAltButtons()
end
Chassis.ApplyAltButtons = ApplyAltButtons
local altWatcher = CreateFrame("Frame")
altWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
altWatcher:SetScript("OnEvent", function(_, _, key)
    if key == "LALT" or key == "RALT" then
        local a = Appearance()
        if a and a.showButtons == "alt" then ApplyAltButtons() end
    end
end)

local HEADER_H = 28
local FOOTER_H = 22
local PAD = 8

local function IsControlShown(control)
    if not control then return false end
    if control.IsShown then return control:IsShown() end
    if control.IsVisible then return control:IsVisible() end
    return true
end

local function ControlWidth(control)
    if not control then return 0 end
    local w = nil
    if control.GetWidth then w = control:GetWidth() end
    if (not w or w <= 0) and control.GetStringWidth then
        w = control:GetStringWidth()
    end
    return w or control.width or 0
end

local function ClampNumber(value, fallback, minValue, maxValue)
    local n = tonumber(value)
    if not n then n = fallback end
    if n < minValue then return minValue end
    if n > maxValue then return maxValue end
    return n
end

local function ClampInteger(value, fallback, minValue, maxValue)
    local n = tonumber(value)
    if not n then
        if fallback == nil then return nil end
        n = fallback
    end
    n = math.floor(n)
    if n < minValue then return minValue end
    if n > maxValue then return maxValue end
    return n
end

-- Refreshes are merged into one per frame, and when they keep coming (an
-- event storm while items move) at most one every MIN_REFRESH_GAP seconds, so
-- the game never stalls redrawing the same window.
local MIN_REFRESH_GAP = 0.1
local MAX_REFRESH_GAP = 0.6
local function Now()
    return debugprofilestop and debugprofilestop() or (GetTime() * 1000)
end
-- The gap grows with what a refresh costs (about five times its time, up to 0.6 s), and
-- while a sort, a transfer or selling is running a window refreshes at most every 0.4 s:
-- a big window is not rebuilt for every single item that moves.
function Chassis.MakeScheduleRefresh(getWin, refresh)
    return function()
        local win = getWin()
        if win and win:IsShown() and not win._updateScheduled then
            win._updateScheduled = true
            win:SetScript("OnUpdate", function(self)
                local now = GetTime()
                local gap = self._refreshGap or MIN_REFRESH_GAP
                if Bags.OpsShared and Bags.OpsShared.OpsBusy and Bags.OpsShared.OpsBusy() then
                    gap = math.max(gap, 0.4)
                end
                if self._lastRefresh and now - self._lastRefresh < gap then return end
                self:SetScript("OnUpdate", nil)
                self._updateScheduled = false
                self._lastRefresh = now
                local t0 = Now()
                refresh()
                local cost = (Now() - t0) / 1000
                self._refreshGap = math.min(MAX_REFRESH_GAP, math.max(MIN_REFRESH_GAP, cost * 5))
            end)
        end
    end
end

function Chassis.CreatePanelButton(parent, withLabel, template)
    local btn = CreateFrame("Button", nil, parent, template)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0, 0, 0, 0.35)
    UIKit.DisablePixelSnap(bg)
    if withLabel then
        btn._label = btn:CreateFontString(nil, "ARTWORK")
        btn._label:SetPoint("CENTER", 0, 0)
        CJKFont(btn._label, Helpers.GetGeneralFont() or STANDARD_TEXT_FONT, 11, "OUTLINE")
    end
    return btn
end

function Chassis.ShowMoneyPopup(key, kind, onAccept)
    local depositing = (kind == "deposit")
    H3z0UI_ShowPopup({
        text = depositing and ns.L["Deposit gold:"] or ns.L["Withdraw gold:"],
        button1 = ACCEPT,
        button2 = CANCEL,
        hasMoneyInput = true,
        OnAccept = function(_, _, amount)
            if amount and amount > 0 then onAccept(depositing, amount) end
        end,
    })
end

function Chassis.MeasureHeaderWidth(controls, opts)
    opts = opts or {}
    local leftPad = opts.leftPad or PAD
    local rightPad = opts.rightPad or PAD
    local gap = opts.gap or 0
    local width = leftPad + rightPad
    local visible = 0
    for _, control in ipairs(controls or {}) do
        if IsControlShown(control) then
            if visible > 0 then width = width + gap end
            width = width + ControlWidth(control)
            visible = visible + 1
        end
    end
    return width
end

function Chassis.ClampAppearance(appearance)
    local src = appearance or {}
    local out = {}
    for k, v in pairs(src) do out[k] = v end
    out.iconSize = ClampNumber(src.iconSize, 36, 24, 48)
    out.spacing = ClampNumber(src.spacing, 4, 0, 8)
    out.columns = ClampInteger(src.columns, 12, 1, 20)
    out.bankColumns = ClampInteger(src.bankColumns, nil, 1, 24)
    out.guildColumns = ClampInteger(src.guildColumns, nil, 1, 24)
    return out
end

-- H3z0 UI: rounded slate window (like the character / inspect panes)
-- a little lighter than the shared slate (follows the UI colour)
local SLATE_FILL = { 0.105, 0.125, 0.16, 0.97 }
local SLATE_TOP = { 0.17, 0.2, 0.25, 0.55 }
local function SyncSlate()
    local base = ns.Round and ns.Round.SLATE_FILL
    if not base then return end
    for i = 1, 3 do
        SLATE_FILL[i] = math.min(1, base[i] + 0.03)
        SLATE_TOP[i] = math.min(1, base[i] + 0.095)
    end
end

local function EnsureRoundedPanel(win)
    local R = ns.Round
    if win._h3zPanel or not (R and R.Panel) then return win._h3zPanel end
    local panel = R.Panel(win, 10)
    panel:SetAllPoints(win)
    panel:SetFrameLevel(win:GetFrameLevel())
    -- soft light from the top so the window isn't a flat black box
    local glow = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    glow:SetPoint("TOPLEFT", 4, -4)
    glow:SetPoint("TOPRIGHT", -4, -4)
    glow:SetHeight(140)
    glow:SetGradient("VERTICAL", CreateColor(SLATE_TOP[1], SLATE_TOP[2], SLATE_TOP[3], 0), CreateColor(SLATE_TOP[1], SLATE_TOP[2], SLATE_TOP[3], SLATE_TOP[4]))
    panel._glow = glow
    win._h3zPanel = panel
    return panel
end

local function Reskin(win)
    SyncSlate()
    local sr, sg, sb, sa, bgr, bgg, bgb, bga = Helpers.GetWindowColors()
    local panel = EnsureRoundedPanel(win)
    if panel and panel._glow then
        panel._glow:SetGradient("VERTICAL", CreateColor(SLATE_TOP[1], SLATE_TOP[2], SLATE_TOP[3], 0), CreateColor(SLATE_TOP[1], SLATE_TOP[2], SLATE_TOP[3], SLATE_TOP[4]))
    end
    if panel then
        win._bg:SetAlpha(0)
        -- the old 1px white frame border: switch it off for good (it showed itself
        -- again on every UI scale refresh when it was only hidden)
        if win._border then
            if win._border.SetBackdropBorderColor then win._border:SetBackdropBorderColor(0, 0, 0, 0) end
            if win._border.SetBackdrop then win._border:SetBackdrop(nil) end
            win._border:Hide()
        end
        panel:SetFillColor(SLATE_FILL[1], SLATE_FILL[2], SLATE_FILL[3], SLATE_FILL[4])
        -- no outline around the window (it read as a white line)
        local b = (ns.Round and ns.Round.SLATE_BORDER) or { 0.25, 0.29, 0.33 }
        panel:SetBorderColor(b[1], b[2], b[3], 0)
        panel:SetRadius(10)
        panel:Show()
    else
        win._bg:SetVertexColor(bgr, bgg, bgb, bga)
        if win._border and win._border.SetBackdropBorderColor then
            win._border:SetBackdropBorderColor(sr, sg, sb, sa)
        end
    end
    local fontPath = Helpers.GetGeneralFont() or STANDARD_TEXT_FONT
    local outline = Helpers.GetGeneralFontOutline() or "OUTLINE"
    CJKFont(win._title, fontPath, 13, outline)
    CJKFont(win._closeText, fontPath, 12, outline)
    CJKFont(win._searchBox, fontPath, 12, outline)
    if win._searchBox._placeholder then
        CJKFont(win._searchBox._placeholder, fontPath, 12, outline)
    end
    if win._searchBox._refreshChrome then
        win._searchBox._refreshChrome(win._searchBox)
    end
end

function Chassis.ReskinAll()
    for _, win in pairs(windows) do Reskin(win) end
end

function Chassis.CreateWindow(opts)
    if opts.name and windows[opts.name] then
        return windows[opts.name]
    end
    local win = CreateFrame("Frame", opts.name, UIParent)
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:SetClampedToScreen(true)
    if win.SetDontSavePosition then win:SetDontSavePosition(true) end
    win:Hide()

    win._bg = win:CreateTexture(nil, "BACKGROUND")
    win._bg:SetAllPoints()
    win._bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    UIKit.DisablePixelSnap(win._bg)
    win._border = UIKit.CreateBackdropBorder(win, 1, 0, 0, 0, 0)

    local header = CreateFrame("Frame", nil, win)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        local b = Behavior()
        if b and b.lockWindows then return end
        win:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        local point, _, _, x, y = win:GetPoint()
        if not point then return end
        local core = Helpers.GetCore()
        if core and core.PixelRound then
            x, y = core:PixelRound(x), core:PixelRound(y)
        end
        if opts.setPosition then opts.setPosition(point, x, y) end
    end)
    win._header = header

    win._title = header:CreateFontString(nil, "ARTWORK")
    CJKFont(win._title, Helpers.GetGeneralFont() or STANDARD_TEXT_FONT, 13, Helpers.GetGeneralFontOutline() or "OUTLINE")
    win._title:SetPoint("LEFT", PAD, 0)
    win._title:SetText(opts.title or "")

    local close = UIKit.CreateCloseButton(header, {
        size = HEADER_H - 8,
        point = "RIGHT",
        x = -6,
        onClick = function()
            if opts.onUserClose then opts.onUserClose() else win:Hide() end
        end,
    })
    win._closeText = close.text
    win._close = close

    local search = CreateFrame("EditBox", nil, header)
    search:SetSize(140, HEADER_H - 10)
    search:SetPoint("RIGHT", close, "LEFT", -8, 0)
    search:SetAutoFocus(false)
    search:SetTextInsets(4, 4, 0, 0)
    local searchBg = search:CreateTexture(nil, "BACKGROUND")
    searchBg:SetAllPoints()
    searchBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    searchBg:SetVertexColor(0, 0, 0, 0.35)
    UIKit.DisablePixelSnap(searchBg)
    UIKit.CreateBorderLines(search)
    local placeholder = search:CreateFontString(nil, "OVERLAY")
    placeholder:SetPoint("LEFT", search, "LEFT", 5, 0)
    CJKFont(placeholder, Helpers.GetGeneralFont() or STANDARD_TEXT_FONT, 12,
        Helpers.GetGeneralFontOutline() or "OUTLINE")
    placeholder:SetTextColor(0.55, 0.55, 0.55, 0.9)
    placeholder:SetText(_G.SEARCH or ns.L["Search"])
    search._placeholder = placeholder
    local SEARCH_FULL_W, SEARCH_COMPACT_W = 140, 70
    local function UpdateSearchWidth(self)
        if not opts.compactSearch then return end
        local expanded = self:HasFocus() or (self:GetText() or "") ~= ""
        local want = expanded and SEARCH_FULL_W or SEARCH_COMPACT_W
        if math.abs(self:GetWidth() - want) > 0.5 then
            self:SetWidth(want)
            if opts.onChromeChanged then opts.onChromeChanged() end
        end
    end
    if opts.compactSearch then search:SetWidth(SEARCH_COMPACT_W) end
    local function RefreshSearchChrome(self)
        placeholder:SetShown(self:GetText() == "" and not self:HasFocus())
        UpdateSearchWidth(self)
        if self:HasFocus() then
            local QGUI = _G.H3z0UI and _G.H3z0UI.GUI
            local acc = QGUI and QGUI.Colors and QGUI.Colors.accent
            local ar, ag, ab
            if acc then ar, ag, ab = acc[1], acc[2], acc[3]
            else ar, ag, ab = Helpers.GetSkinColors() end
            UIKit.UpdateBorderLines(self, 1, ar, ag, ab, 0.9)
        else
            local sr, sg, sb = Helpers.GetWindowColors()
            UIKit.UpdateBorderLines(self, 1, sr, sg, sb, 0.5)
        end
    end
    search._refreshChrome = RefreshSearchChrome
    search:SetScript("OnEditFocusGained", RefreshSearchChrome)
    search:SetScript("OnEditFocusLost", RefreshSearchChrome)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    local lastDispatched = nil
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text ~= lastDispatched then
            lastDispatched = text
            if opts.onSearchChanged then opts.onSearchChanged(text) end
        end
        RefreshSearchChrome(self)
    end)
    win._searchBox = search
    RefreshSearchChrome(search)

    -- saved searches: right-click the search box
    search:HookScript("OnEnter", function(self)
        if self:HasFocus() then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(_G.SEARCH or ns.L["Search"])
        GameTooltip:AddLine(ns.L["Right-click: saved searches."], 1, 1, 1, true)
        GameTooltip:AddLine(ns.L["Words like #potion, #boe, epic, ilvl>600; & = and, | = or, ! = not."], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    search:HookScript("OnLeave", function() GameTooltip:Hide() end)
    search:HookScript("OnMouseUp", function(self, mouseButton)
        if mouseButton ~= "RightButton" or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        local st = BagSettings()
        if not st then return end
        st.savedSearches = st.savedSearches or {}
        local saved = st.savedSearches
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle(ns.L["Saved Searches"])
            if #saved == 0 then
                root:CreateButton("|cff888888" .. ns.L["None yet"] .. "|r", function() end)
            end
            for i, text in ipairs(saved) do
                local entry = root:CreateButton(text, function()
                    self:SetText(text)
                    self:ClearFocus()
                end)
                entry:CreateButton(ns.L["Delete"], function() table.remove(saved, i) end)
            end
            local cur = self:GetText() or ""
            if cur ~= "" then
                local exists = false
                for _, t in ipairs(saved) do if t == cur then exists = true end end
                if not exists then
                    root:CreateDivider()
                    root:CreateButton(ns.L["Save"] .. ": " .. cur, function()
                        saved[#saved + 1] = cur
                    end)
                end
            end
        end)
    end)

    local body = CreateFrame("Frame", nil, win)
    body:SetPoint("TOPLEFT", PAD, -HEADER_H)
    body:SetPoint("BOTTOMRIGHT", -PAD, FOOTER_H)
    win._body = body

    local footerH = FOOTER_H
    local footer = CreateFrame("Frame", nil, win)
    footer:SetPoint("BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", 0, 0)
    footer:SetHeight(footerH)
    win._footer = footer

    win:SetScript("OnHide", function()
        win:StopMovingOrSizing()
        if opts.onClose then opts.onClose(win) end
    end)

    if opts.name and not tContains(UISpecialFrames, opts.name) then
        tinsert(UISpecialFrames, opts.name)
    end

    function win:ApplyChromeOptions()
        local pad = CurPad()
        if self._pad ~= pad then
            self._pad = pad
            body:ClearAllPoints()
            body:SetPoint("TOPLEFT", pad, -HEADER_H)
            body:SetPoint("BOTTOMRIGHT", -pad, footerH)
        end
        local a = Appearance()
        local wantSearch = not (a and a.showSearchBox == false)
        if wantSearch ~= self._searchShown then
            self._searchShown = wantSearch
            if wantSearch then
                search:Show()
                search:SetWidth(opts.compactSearch and SEARCH_COMPACT_W or SEARCH_FULL_W)
                RefreshSearchChrome(search)
            else
                search:SetText("")
                search:ClearFocus()
                search:SetWidth(0.1)
                search:Hide()
            end
        end
        ApplyAltButtons()
    end

    function win:SetContentSize(contentW, contentH)
        self:ApplyChromeOptions()
        self._contentW, self._contentH = contentW, contentH
        local pad = self._pad or PAD
        self:SetSize(contentW + pad * 2, contentH + HEADER_H + footerH)
    end

    function win:SetFooterHeight(h)
        if h == footerH then return end
        footerH = h
        footer:SetHeight(h)
        body:SetPoint("BOTTOMRIGHT", -(self._pad or PAD), h)
        if self._contentW then
            self:SetContentSize(self._contentW, self._contentH)
        end
    end

    function win:ApplyPosition()
        local pos = opts.getPosition and opts.getPosition()
        self:ClearAllPoints()
        if pos and pos.point then
            self:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
        else
            self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 120)
        end
    end

    Reskin(win)
    windows[opts.name or tostring(win)] = win
    return win
end

local getBagsSettings
local function GetBagsSettings()
    if not getBagsSettings then
        if not (Helpers and Helpers.CreateDBGetter) then return nil end
        getBagsSettings = Helpers.CreateDBGetter("bags")
    end
    return getBagsSettings()
end

local SORT_MODES = {
    { key = "quality", label = ns.L["Quality"] },
    { key = "type", label = ns.L["Type"] },
    { key = "name", label = ns.L["Name"] },
    { key = "ilvl", label = ns.L["Item Level"] },
    { key = "expansion", label = ns.L["Expansion"] },
}

function Chassis.SortModeText()
    local s = GetBagsSettings()
    local key = s and s.behavior and s.behavior.sortKey or "quality"
    local label = "Quality"
    for _, m in ipairs(SORT_MODES) do
        if m.key == key then label = m.label end
    end
    if s and s.behavior and s.behavior.sortReverse then
        label = label .. " " .. ns.L["(reversed)"]
    end
    return label
end

function Chassis.ShowSortMenu(anchor, extra)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(ns.L["Sort by"])
        for _, m in ipairs(SORT_MODES) do
            root:CreateRadio(m.label,
                function()
                    local s = GetBagsSettings()
                    return (s and s.behavior and s.behavior.sortKey or "quality") == m.key
                end,
                function()
                    local s = GetBagsSettings()
                    if s and s.behavior then
                        s.behavior.sortKey = m.key
                        Bags.BagWindow.Refresh()
                    end
                end)
        end
        root:CreateCheckbox(ns.L["Reverse order"],
            function()
                local s = GetBagsSettings()
                return s and s.behavior and s.behavior.sortReverse or false
            end,
            function()
                local s = GetBagsSettings()
                if s and s.behavior then
                    s.behavior.sortReverse = not s.behavior.sortReverse
                    Bags.BagWindow.Refresh()
                end
            end)
        root:CreateCheckbox(ns.L["Pack to bottom"],
            function()
                local s = GetBagsSettings()
                return s and s.behavior and s.behavior.fillFromBottom or false
            end,
            function()
                local s = GetBagsSettings()
                if s and s.behavior then s.behavior.fillFromBottom = not s.behavior.fillFromBottom end
            end)
        if extra then extra(root) end
    end)
end

if ns.Registry then
    ns.Registry:Register("bagsSkin", {
        refresh = Chassis.ReskinAll,
        priority = 50,
        group = "skinning",
        importCategories = { "skinning", "theme" },
    })
end
