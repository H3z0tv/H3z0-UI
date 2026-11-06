--[[
    H3z0 UI - What's New window

    Opens once after an update (when ns.WhatsNew.version hasn't been seen on
    this account), lists what's new and what's fixed. Not shown on a brand-new
    install (the Setup Wizard opens instead). Open again any time with
    /h3z0ui whatsnew or the button in H3z0 Features > Extras.
]]

local ADDON_NAME, ns = ...

local WN = {}
ns.WhatsNewWindow = WN

local function Global()
    local core = ns.Addon
    return core and core.db and core.db.global
end

local function Theme()
    local ui = _G.H3z0UI
    local gui = ui and ui.GUI
    return gui and gui.Colors or {}, ns.SkinBase
end

local function ColorHex(color, fallback)
    color = color or fallback or { 1, 1, 1 }
    return string.format("%02x%02x%02x",
        math.floor((color[1] or 1) * 255 + 0.5),
        math.floor((color[2] or 1) * 255 + 0.5),
        math.floor((color[3] or 1) * 255 + 0.5))
end

local function Accent()
    local C = Theme()
    local a = C.accent
    if a then return a[1], a[2], a[3] end
    return 0.204, 0.827, 0.6
end

local FRAME_W, FRAME_H = 740, 500
local SIDE_W = 150
local TITLE_H = 44
local VIEW_W = FRAME_W - SIDE_W - 12 * 2 - 14 - 20   -- text width of the notes (right side)

local function Surface(frame, radius)
    local UIKit = ns.UIKit
    if UIKit and UIKit.CreateRoundedSurface then
        frame.surface = frame.surface or UIKit.CreateRoundedSurface(frame, { radius = radius or 6 })
        return frame.surface
    end
    if not frame.bgTex then
        frame.bgTex = frame:CreateTexture(nil, "BACKGROUND")
        frame.bgTex:SetAllPoints()
    end
end

local function SetSurface(frame, border, bg)
    if frame.surface then
        frame.surface:SetColors(border, bg)
    elseif frame.bgTex then
        frame.bgTex:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
    end
end

local function Colors()
    local C = Theme()
    return {
        bg = C.optionsWindow or C.bg or { 0.05, 0.07, 0.10, 0.97 },
        border = C.borderStrong or { 0.30, 0.36, 0.39, 0.5 },
        accent = C.accent or { 0.204, 0.827, 0.6, 1 },
        accentLight = C.accentLight or C.accent or { 0.204, 0.827, 0.6, 1 },
        text = C.text or { 0.9, 0.9, 0.9, 1 },
        textDim = C.textDim or { 0.65, 0.68, 0.72, 1 },
        elevated = C.bgElevated or C.bgLight or { 0.12, 0.15, 0.18, 1 },
    }
end

-- a scroll area with a thin bar (works on every client)
local function MakeScroll(parent, width)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 10)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)

    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(6)
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetAllPoints()
    bar.track:SetColorTexture(1, 1, 1, 0.07)
    local thumb = CreateFrame("Button", nil, bar)
    thumb:SetWidth(6)
    thumb.tex = thumb:CreateTexture(nil, "ARTWORK")
    thumb.tex:SetAllPoints()
    bar.thumb = thumb
    scroll.bar, scroll.content = bar, content

    local function Range()
        return math.max(0, content:GetHeight() - scroll:GetHeight())
    end
    local function Update()
        local range = Range()
        local trackH = bar:GetHeight()
        if range <= 0 or trackH <= 0 then
            bar:SetAlpha(0)
            thumb:Hide()
            return
        end
        bar:SetAlpha(1)
        thumb:Show()
        local viewH = scroll:GetHeight()
        local thumbH = math.max(26, trackH * viewH / (viewH + range))
        thumb:SetHeight(thumbH)
        local pos = (scroll:GetVerticalScroll() / range) * (trackH - thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", bar, "TOP", 0, -pos)
    end
    scroll.UpdateBar = Update
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = Range()
        self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 48)))
    end)
    scroll:SetScript("OnVerticalScroll", Update)
    scroll:SetScript("OnSizeChanged", Update)
    thumb:SetScript("OnMouseDown", function(self)
        local _, cy = GetCursorPosition()
        self.startY = cy / self:GetEffectiveScale()
        self.startScroll = scroll:GetVerticalScroll()
        self:SetScript("OnUpdate", function(btn)
            local _, y = GetCursorPosition()
            y = y / btn:GetEffectiveScale()
            local trackH, thumbH = bar:GetHeight(), btn:GetHeight()
            local travel = trackH - thumbH
            if travel <= 0 then return end
            local delta = (btn.startY - y) / travel * Range()
            scroll:SetVerticalScroll(math.min(Range(), math.max(0, btn.startScroll + delta)))
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    return scroll
end

local win

local function ApplyTheme(f)
    local c = Colors()
    local profile = ns.Addon and ns.Addon.db and ns.Addon.db.profile
    local alpha = profile and profile.configPanelAlpha or c.bg[4] or 0.97
    SetSurface(f, { c.border[1], c.border[2], c.border[3], c.border[4] or 0.5 }, { c.bg[1], c.bg[2], c.bg[3], alpha })
    SetSurface(f.titleBar, { 0, 0, 0, 0 }, { c.elevated[1], c.elevated[2], c.elevated[3], 0.55 })
    SetSurface(f.side, { c.border[1], c.border[2], c.border[3], 0.35 }, { 0, 0, 0, 0.28 })
    SetSurface(f.view, { c.border[1], c.border[2], c.border[3], 0.35 }, { 0, 0, 0, 0.18 })
    f.line:SetColorTexture(c.accent[1], c.accent[2], c.accent[3], 0.65)
    f.title:SetTextColor(c.text[1], c.text[2], c.text[3], 1)
    f.logo:SetVertexColor(c.accentLight[1], c.accentLight[2], c.accentLight[3], 1)
    for _, sc in ipairs({ f.sideScroll, f.viewScroll }) do
        sc.bar.thumb.tex:SetColorTexture(c.accent[1], c.accent[2], c.accent[3], 0.85)
    end
    f.close.text:SetTextColor(c.textDim[1], c.textDim[2], c.textDim[3], 1)
    for _, btn in ipairs(f.versionButtons or {}) do btn.Refresh() end
end

local Select

local function Build()
    if win then return win end
    local f = CreateFrame("Frame", "H3z0UI_WhatsNewFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "H3z0UI_WhatsNewFrame")
    Surface(f, 8)

    -- title bar (drag here)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", 6, -6)
    bar:SetPoint("TOPRIGHT", -6, -6)
    bar:SetHeight(TITLE_H - 8)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    Surface(bar, 5)
    f.titleBar = bar

    f.logo = bar:CreateTexture(nil, "ARTWORK")
    f.logo:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\icon")
    f.logo:SetSize(24, 24)
    f.logo:SetPoint("LEFT", 10, 0)
    f.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("LEFT", f.logo, "RIGHT", 8, 0)
    f.title:SetText("WHAT'S NEW")

    local close = CreateFrame("Button", nil, bar)
    close:SetSize(28, 28)
    close:SetPoint("RIGHT", -6, 0)
    close.text = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    close.text:SetPoint("CENTER")
    close.text:SetText("x")
    close:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1, 1) end)
    close:SetScript("OnLeave", function() ApplyTheme(f) end)
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 6, -TITLE_H)
    line:SetPoint("TOPRIGHT", -6, -TITLE_H)
    f.line = line

    -- left: every version
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", 12, -(TITLE_H + 8))
    side:SetPoint("BOTTOMLEFT", 12, 12)
    side:SetWidth(SIDE_W)
    Surface(side, 6)
    f.side = side
    f.sideScroll = MakeScroll(side, SIDE_W - 20)
    f.sideScroll:SetPoint("TOPLEFT", 6, -6)
    f.sideScroll:SetPoint("BOTTOMRIGHT", -12, 6)
    f.sideScroll.bar:SetPoint("TOPRIGHT", -4, -8)
    f.sideScroll.bar:SetPoint("BOTTOMRIGHT", -4, 8)

    -- right: the notes of the chosen version
    local view = CreateFrame("Frame", nil, f)
    view:SetPoint("TOPLEFT", side, "TOPRIGHT", 8, 0)
    view:SetPoint("BOTTOMRIGHT", -12, 12)
    Surface(view, 6)
    f.view = view
    f.viewScroll = MakeScroll(view, VIEW_W)
    f.viewScroll:SetPoint("TOPLEFT", 10, -8)
    f.viewScroll:SetPoint("BOTTOMRIGHT", -18, 8)
    f.viewScroll.bar:SetPoint("TOPRIGHT", -6, -10)
    f.viewScroll.bar:SetPoint("BOTTOMRIGHT", -6, 10)
    f.content = f.viewScroll.content

    -- version buttons
    f.versionButtons = {}
    local history = ns.WhatsNewHistory or {}
    local sc = f.sideScroll.content
    local y = 0
    for i, entry in ipairs(history) do
        local btn = CreateFrame("Button", nil, sc)
        btn:SetSize(SIDE_W - 22, 28)
        btn:SetPoint("TOPLEFT", 0, -y)
        Surface(btn, 5)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        btn.label:SetPoint("CENTER")
        btn.label:SetText(entry.version)
        btn.index = i
        btn.Refresh = function()
            local c = Colors()
            local selected = (f.selected == i)
            if selected then
                SetSurface(btn, { c.accent[1], c.accent[2], c.accent[3], 0.9 }, { c.elevated[1], c.elevated[2], c.elevated[3], 1 })
                btn.label:SetTextColor(c.accentLight[1], c.accentLight[2], c.accentLight[3], 1)
            elseif btn.hover then
                SetSurface(btn, { c.border[1], c.border[2], c.border[3], 0.5 }, { c.elevated[1], c.elevated[2], c.elevated[3], 0.6 })
                btn.label:SetTextColor(c.text[1], c.text[2], c.text[3], 1)
            else
                SetSurface(btn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
                btn.label:SetTextColor(c.textDim[1], c.textDim[2], c.textDim[3], 1)
            end
        end
        btn:SetScript("OnEnter", function(self) self.hover = true; self.Refresh() end)
        btn:SetScript("OnLeave", function(self) self.hover = false; self.Refresh() end)
        btn:SetScript("OnClick", function() Select(f, i) end)
        f.versionButtons[i] = btn
        y = y + 32
    end
    sc:SetHeight(y + 4)

    win = f
    ApplyTheme(f)
    return f
end

local function Fill(f, entry)
    local content = f.content
    content.lines = content.lines or {}
    for _, l in ipairs(content.lines) do l:Hide() end
    local c = Colors()
    local accentHex = ColorHex(c.accentLight, c.accent)
    local y, n = 0, 0
    local function Add(text, font, indent, gap)
        n = n + 1
        local fs = content.lines[n]
        if not fs then
            fs = content:CreateFontString(nil, "OVERLAY")
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            fs:SetWordWrap(true)
            content.lines[n] = fs
        end
        fs:SetFontObject(font)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", indent or 0, -y)
        fs:SetWidth(VIEW_W - (indent or 0))
        fs:SetText(text)
        fs:Show()
        y = y + (fs:GetStringHeight() or 14) + (gap or 6)
    end
    Add("|cff" .. accentHex .. (((ns.Client and ns.Client.displayName) or "H3z0 UI") .. " " .. tostring(entry.version)) .. "|r", GameFontNormalLarge, 0, 10)
    for _, sec in ipairs(entry.sections or {}) do
        if sec.items and #sec.items > 0 and ns.WhatsNewShowSection(sec) then
            Add("|cff" .. accentHex .. tostring(sec.title) .. "|r", GameFontNormal, 0, 6)
            for _, t in ipairs(sec.items) do
                Add("|cff" .. accentHex .. "\226\128\162|r  " .. t, GameFontHighlightSmall, 4, 7)
            end
            y = y + 8
        end
    end
    content:SetHeight(y + 10)
    f.viewScroll:SetVerticalScroll(0)
    f.viewScroll.UpdateBar()
end

Select = function(f, index)
    local history = ns.WhatsNewHistory
    if not (history and history[index]) then return end
    f.selected = index
    for _, btn in ipairs(f.versionButtons) do btn.Refresh() end
    Fill(f, history[index])
end

-- 0.24.2: version + build, so an update of the same version (same number, new fixes) shows
-- the window again after it is installed
local function SeenKey(data)
    return tostring(data.version) .. (data.build and ("." .. tostring(data.build)) or "")
end

function WN.Show()
    local data = ns.WhatsNew
    if not data then return end
    local f = Build()
    ApplyTheme(f)
    if ns.WhatsNewHistory then
        Select(f, 1)
        f.sideScroll:SetVerticalScroll(0)
        f.sideScroll.UpdateBar()
    else
        Fill(f, { version = data.version, sections = data.sections })
    end
    f:Show()
    -- above the settings window when it is opened from there (Patch Notes row)
    local opts = _G.H3z0UI_Options
    if opts and opts:IsShown() then
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(60)
    else
        f:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    f:Raise()
    local G = Global()
    if G then G.whatsNewSeen = SeenKey(data) end
    C_Timer.After(0, function()
        f.sideScroll.UpdateBar()
        f.viewScroll.UpdateBar()
    end)
end

_G.H3z0UI_ShowWhatsNew = WN.Show

-- Once per new version, a few seconds after login (after other startup popups)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, _, isLogin, isReload)
    if not (isLogin or isReload) then return end
    self:UnregisterAllEvents()
    C_Timer.After(4, function()
        local data, G = ns.WhatsNew, Global()
        if not (data and G) then return end
        if G.whatsNewSeen == SeenKey(data) then return end
        -- brand-new install: the Setup Wizard opens instead; this version counts as seen
        local wiz = _G.H3z0UI_Setup
        if wiz and wiz.ShouldAutoShow and wiz.ShouldAutoShow() then
            G.whatsNewSeen = SeenKey(data)
            return
        end
        if InCombatLockdown() then
            local wait = CreateFrame("Frame")
            wait:RegisterEvent("PLAYER_REGEN_ENABLED")
            wait:SetScript("OnEvent", function(w) w:UnregisterAllEvents(); WN.Show() end)
            return
        end
        WN.Show()
    end)
end)
