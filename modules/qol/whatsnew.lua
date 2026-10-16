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

local function Accent()
    local C = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    local a = C and C.accent
    if a then return a[1], a[2], a[3] end
    return 0.204, 0.827, 0.6
end

local win

local function Build()
    if win then return win end
    local r, g, b = Accent()
    local f = CreateFrame("Frame", "H3z0UI_WhatsNewFrame", UIParent, "BackdropTemplate")
    f:SetSize(560, 480)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.07, 0.10, 0.97)
    f:SetBackdropBorderColor(r, g, b, 0.9)
    tinsert(UISpecialFrames, "H3z0UI_WhatsNewFrame")

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\icon")
    logo:SetSize(40, 40)
    logo:SetPoint("TOPLEFT", 14, -12)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -2)
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.sub:SetText("Thanks for updating! Here's what changed.")

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(r, g, b, 0.5)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 14, -62)
    line:SetPoint("TOPRIGHT", -14, -62)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -72)
    scroll:SetPoint("BOTTOMRIGHT", -34, 56)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(500, 10)
    scroll:SetScrollChild(content)
    f.content = content

    local ok = CreateFrame("Button", nil, f, "BackdropTemplate")
    ok:SetSize(140, 28)
    ok:SetPoint("BOTTOMRIGHT", -14, 14)
    ok:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    ok:SetBackdropColor(r, g, b, 0.25)
    ok:SetBackdropBorderColor(r, g, b, 0.9)
    ok.text = ok:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ok.text:SetPoint("CENTER")
    ok.text:SetText("Got it")
    ok:SetScript("OnEnter", function(self) self:SetBackdropColor(r, g, b, 0.45) end)
    ok:SetScript("OnLeave", function(self) self:SetBackdropColor(r, g, b, 0.25) end)
    ok:SetScript("OnClick", function() f:Hide() end)

    local notes = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    notes:SetPoint("BOTTOMLEFT", 16, 22)
    notes:SetText("Open this again: /h3z0ui whatsnew")

    win = f
    return f
end

local function Fill(f, data)
    local content = f.content
    content.lines = content.lines or {}
    for _, l in ipairs(content.lines) do l:Hide() end
    local y, n = 0, 0
    local function Add(text, font, indent, gap)
        n = n + 1
        local fs = content.lines[n]
        if not fs then
            fs = content:CreateFontString(nil, "OVERLAY")
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            content.lines[n] = fs
        end
        fs:SetFontObject(font)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", indent or 0, -y)
        fs:SetWidth(500 - (indent or 0))
        fs:SetText(text)
        fs:Show()
        y = y + (fs:GetStringHeight() or 14) + (gap or 6)
    end
    local r, g, b = Accent()
    local hex = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
    if data.new and #data.new > 0 then
        Add("|cff" .. hex .. "New|r", GameFontNormalLarge, 0, 8)
        for _, t in ipairs(data.new) do Add("|cff" .. hex .. "-|r  " .. t, GameFontHighlight, 6, 6) end
        y = y + 8
    end
    if data.fixed and #data.fixed > 0 then
        Add("|cff" .. hex .. "Fixed|r", GameFontNormalLarge, 0, 8)
        for _, t in ipairs(data.fixed) do Add("|cff" .. hex .. "-|r  " .. t, GameFontHighlight, 6, 6) end
    end
    content:SetHeight(y + 10)
end

function WN.Show()
    local data = ns.WhatsNew
    if not data then return end
    local f = Build()
    f.title:SetText("|cff34D399H3z0 UI|r  What's New in " .. tostring(data.version))
    Fill(f, data)
    f:Show()
    local G = Global()
    if G then G.whatsNewSeen = data.version end
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
        if G.whatsNewSeen == data.version then return end
        -- brand-new install: the Setup Wizard opens instead; this version counts as seen
        local wiz = _G.H3z0UI_Setup
        if wiz and wiz.ShouldAutoShow and wiz.ShouldAutoShow() then
            G.whatsNewSeen = data.version
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
