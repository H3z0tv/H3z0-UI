--[[
    H3z0 UI - Girly Look

    Pastel backgrounds with a soft pattern (hearts, flowers, sparkles, dots or
    bows) behind the action bars, the chat windows, the damage meter and the
    Bottom Bar. H3z0 Features > UI Look > Girly Look.

    Only H3z0 UI's own panels / textures are created, as children of the frames
    they decorate. Nothing of Blizzard's is replaced or written.

    Settings: profile.girly = { enabled, palette, custom, pattern, patternAlpha,
        patternScale, fillAlpha, lightness, border, actionBars, chat, damageMeter,
        bottomBar }
]]

local ADDON_NAME, ns = ...

local Girly = {}
ns.H3z0Girly = Girly

local ART = "Interface\\AddOns\\H3z0UI\\assets\\girly\\"
local TILE = 128

-- colours: a dark tinted base, the pattern colour and the border colour
local PALETTES = {
    pink     = { text = "Pink",      base = { 0.30, 0.10, 0.19 }, pat = { 1.00, 0.68, 0.84 }, edge = { 1.00, 0.72, 0.86 } },
    rose     = { text = "Rose",      base = { 0.28, 0.07, 0.11 }, pat = { 1.00, 0.55, 0.62 }, edge = { 0.95, 0.45, 0.55 } },
    lavender = { text = "Lavender",  base = { 0.18, 0.12, 0.30 }, pat = { 0.78, 0.65, 1.00 }, edge = { 0.75, 0.60, 1.00 } },
    peach    = { text = "Peach",     base = { 0.32, 0.16, 0.12 }, pat = { 1.00, 0.78, 0.65 }, edge = { 1.00, 0.70, 0.55 } },
    mint     = { text = "Mint",      base = { 0.08, 0.24, 0.20 }, pat = { 0.65, 1.00, 0.88 }, edge = { 0.50, 0.95, 0.80 } },
    sky      = { text = "Baby Blue", base = { 0.09, 0.18, 0.30 }, pat = { 0.65, 0.85, 1.00 }, edge = { 0.55, 0.80, 1.00 } },
}
local PALETTE_ORDER = { "pink", "rose", "lavender", "peach", "mint", "sky", "custom" }

local PATTERNS = {
    { value = "hearts",   text = "Hearts" },
    { value = "flowers",  text = "Flowers" },
    { value = "sparkles", text = "Sparkles" },
    { value = "dots",     text = "Polka Dots" },
    { value = "bows",     text = "Bows" },
    { value = "none",     text = "Plain Colour" },
}

function Girly.PaletteOptions()
    local list = {}
    for _, key in ipairs(PALETTE_ORDER) do
        list[#list + 1] = { value = key, text = (key == "custom") and "Custom Colour" or PALETTES[key].text }
    end
    return list
end
function Girly.PatternOptions() return PATTERNS end

local function DB()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.girly = p.girly or {}
    local s = p.girly
    if s.enabled == nil then s.enabled = false end
    if s.palette == nil then s.palette = "pink" end
    if type(s.custom) ~= "table" then s.custom = { 1, 0.68, 0.84, 1 } end
    if s.pattern == nil then s.pattern = "flowers" end
    if s.patternAlpha == nil then s.patternAlpha = 0.45 end
    if s.patternScale == nil then s.patternScale = 0.9 end
    if s.fillAlpha == nil then s.fillAlpha = 0.92 end
    if s.lightness == nil then s.lightness = 0.7 end
    if s.border == nil then s.border = true end
    if s.actionBars == nil then s.actionBars = true end
    if s.chat == nil then s.chat = false end
    if s.damageMeter == nil then s.damageMeter = false end
    if s.bottomBar == nil then s.bottomBar = false end
    -- 0.26.23 (build 4): only the action bars, flowers, a lighter pastel pink
    if not s.pastel1 then
        s.pastel1 = true
        s.palette, s.pattern = "pink", "flowers"
        s.patternAlpha, s.patternScale, s.fillAlpha, s.lightness = 0.45, 0.9, 0.92, 0.7
        s.actionBars, s.chat, s.damageMeter, s.bottomBar = true, false, false, false
    end
    return s
end
Girly.GetSettings = DB

local function Clamp(v, lo, hi, def)
    v = tonumber(v) or def
    return math.max(lo, math.min(hi, v))
end

-- the three colours the current settings give
local function Colours(s)
    local pal = PALETTES[s.palette]
    local pat, edge, base
    if pal then
        pat, edge, base = pal.pat, pal.edge, pal.base
    else
        local c = s.custom or { 1, 0.62, 0.8 }
        local r, g, b = Clamp(c[1], 0, 1, 1), Clamp(c[2], 0, 1, 0.62), Clamp(c[3], 0, 1, 0.8)
        pat, edge, base = { r, g, b }, { r, g, b }, { r * 0.24, g * 0.24, b * 0.24 }
    end
    -- lightness: from the dark base towards a soft pastel
    local k = Clamp(s.lightness, 0, 1, 0.2)
    local fill = {
        base[1] * (1 - k) + pat[1] * 0.84 * k,
        base[2] * (1 - k) + pat[2] * 0.84 * k,
        base[3] * (1 - k) + pat[3] * 0.84 * k,
    }
    -- the pattern is a lighter tint of the colour, so it shows on the pastel fill
    local w = 0.3 + 0.45 * k
    local lit = { pat[1] + (1 - pat[1]) * w, pat[2] + (1 - pat[2]) * w, pat[3] + (1 - pat[3]) * w }
    return fill, lit, edge
end

---------------------------------------------------------------------------
-- One decoration: a rounded panel (fill + border), the pattern and a soft
-- highlight at the top, as a child of the frame it decorates
---------------------------------------------------------------------------
local function Radius(r)
    local R = ns.Round
    if r then return r end
    if R and R.Enabled and R.Enabled() and R.Radius then
        local ok, v = pcall(R.Radius)
        if ok and type(v) == "number" then return math.min(v, 8) end
    end
    return 3
end

local function UpdatePattern(ov)
    local tex = ov.pattern
    if not (tex and tex:IsShown()) then return end
    local w, h = ov:GetWidth() or 0, ov:GetHeight() or 0
    if w <= 0 or h <= 0 then return end
    local size = TILE * Clamp(ov.patternScale, 0.4, 3, 0.8)
    tex:SetTexCoord(0, w / size, 0, h / size)
end

local function Make(parent)
    local R = ns.Round
    if not (R and R.Panel) then return nil end
    local ov = CreateFrame("Frame", nil, parent)
    ov:EnableMouse(false)
    local base = R.Panel(ov, 4)
    base:SetAllPoints(ov)
    ov.base = base

    local pattern = base:CreateTexture(nil, "ARTWORK", nil, 1)
    pattern:SetPoint("TOPLEFT", base, "TOPLEFT", 2, -2)
    pattern:SetPoint("BOTTOMRIGHT", base, "BOTTOMRIGHT", -2, 2)
    ov.pattern = pattern

    local gloss = base:CreateTexture(nil, "ARTWORK", nil, 2)
    gloss:SetTexture("Interface\\Buttons\\WHITE8x8")
    gloss:SetPoint("TOPLEFT", base, "TOPLEFT", 3, -2)
    gloss:SetPoint("TOPRIGHT", base, "TOPRIGHT", -3, -2)
    gloss:SetHeight(10)
    ov.gloss = gloss

    ov:SetScript("OnSizeChanged", UpdatePattern)
    return ov
end

local function Style(ov, s, radius)
    local fill, pat, edge = Colours(s)
    ov.base:SetRadius(Radius(radius))
    ov.base:SetFillColor(fill[1], fill[2], fill[3], Clamp(s.fillAlpha, 0.1, 1, 0.88))
    if s.border then
        ov.base:SetBorderColor(edge[1], edge[2], edge[3], 0.85)
    else
        ov.base:SetBorderColor(edge[1], edge[2], edge[3], 0)
    end
    if s.pattern ~= "none" and Clamp(s.patternAlpha, 0, 1, 0.3) > 0 then
        ov.pattern:SetTexture(ART .. "g_" .. s.pattern, "REPEAT", "REPEAT")
        ov.pattern:SetVertexColor(pat[1], pat[2], pat[3], Clamp(s.patternAlpha, 0, 1, 0.3))
        ov.pattern:Show()
        ov.patternScale = s.patternScale
        UpdatePattern(ov)
    else
        ov.pattern:Hide()
    end
    -- a soft white highlight fading out downwards
    local g = ov.gloss
    local ok = pcall(function()
        g:SetColorTexture(1, 1, 1, 1)
        if g.SetGradient and CreateColor then
            g:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.16))
        else
            error("no gradient")
        end
    end)
    if not ok then g:SetColorTexture(1, 1, 1, 0.05) end
end

---------------------------------------------------------------------------
-- Targets
---------------------------------------------------------------------------
local overlays = setmetatable({}, { __mode = "k" })

local function ChatFrames()
    local list = {}
    local names = _G.CHAT_FRAMES
    if type(names) == "table" then
        for _, n in ipairs(names) do
            local f = _G[n]
            if f then list[#list + 1] = f end
        end
    else
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local f = _G["ChatFrame" .. i]
            if f then list[#list + 1] = f end
        end
    end
    return list
end

-- each target: the frames to decorate and how (outset, strata, level, corner)
local TARGETS = {
    {
        key = "actionBars",
        get = function()
            local out = {}
            local owned = ns.ActionBarsOwned
            if owned and type(owned.containers) == "table" then
                for _, c in pairs(owned.containers) do
                    if c and c.GetWidth and (c:GetWidth() or 0) > 8 then
                        out[#out + 1] = { frame = c, l = -5, t = 5, r = 5, b = -5, strata = "BACKGROUND", level = 0 }
                    end
                end
            end
            return out
        end,
    },
    {
        key = "chat",
        get = function()
            local out = {}
            for _, cf in ipairs(ChatFrames()) do
                if not (cf.IsForbidden and cf:IsForbidden()) then
                    out[#out + 1] = { frame = cf, l = -8, t = 4, r = 8, b = -8, strata = "BACKGROUND", level = 2 }
                end
            end
            return out
        end,
    },
    {
        key = "damageMeter",
        get = function()
            local out = {}
            for i = 1, 5 do
                local win = _G["DamageMeterSessionWindow" .. i]
                if win and not (win.IsForbidden and win:IsForbidden()) then
                    out[#out + 1] = { frame = win, l = -2, t = 2, r = 2, b = -2,
                        strata = win:GetFrameStrata(), level = win:GetFrameLevel() }
                end
            end
            return out
        end,
    },
    {
        key = "bottomBar",
        get = function()
            local bar = _G.H3z0UI_InfoBar
            if not bar then return {} end
            return { { frame = bar, l = 0, t = 0, r = 0, b = 0, strata = bar:GetFrameStrata(),
                level = bar:GetFrameLevel(), radius = 1 } }
        end,
    },
}

local later   -- debounced Apply, defined below
local hooked = {}

local function Place(entry, s)
    local f = entry.frame
    local ov = overlays[f]
    if not ov then
        ov = Make(f)
        if not ov then return end
        overlays[f] = ov
    end
    ov:SetFrameStrata(entry.strata or "BACKGROUND")
    ov:SetFrameLevel(math.max(0, entry.level or 0))
    ov:ClearAllPoints()
    ov:SetPoint("TOPLEFT", f, "TOPLEFT", entry.l, entry.t)
    ov:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", entry.r, entry.b)
    Style(ov, s, entry.radius)
    ov:Show()
end

function Girly.Apply()
    local s = DB()
    if not s then return end
    local used = {}
    if s.enabled then
        for _, target in ipairs(TARGETS) do
            if s[target.key] then
                local ok, list = pcall(target.get)
                if ok and type(list) == "table" then
                    for _, entry in ipairs(list) do
                        local okP = pcall(Place, entry, s)
                        if okP then used[entry.frame] = true end
                    end
                end
            end
        end
    end
    for f, ov in pairs(overlays) do
        if not used[f] then ov:Hide() end
    end
end
_G.H3z0UI_RefreshGirly = Girly.Apply

---------------------------------------------------------------------------
-- Preview for the options page: a few sample pieces in the chosen look
---------------------------------------------------------------------------
function Girly.CreatePreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(112)

    local function Piece(width, anchor, x)
        local ov = Make(frame)
        if not ov then return nil end
        ov:SetFrameLevel(frame:GetFrameLevel() + 1)
        ov:SetSize(width, 92)
        ov:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -10)
        return ov
    end

    local bar = Piece(170, nil, 0)
    local chat = Piece(230, nil, 186)
    local label = function(ov, text, point, x, y)
        local fs = ov:CreateFontString(nil, "OVERLAY")
        local font = (ns.Helpers and ns.Helpers.GetGeneralFont and ns.Helpers.GetGeneralFont()) or STANDARD_TEXT_FONT
        fs:SetFont(font, 11, "OUTLINE")
        fs:SetPoint(point, ov, point, x, y)
        fs:SetText(text)
        fs:SetTextColor(1, 1, 1, 1)
        return fs
    end
    if bar then
        label(bar, "Action Bars", "TOPLEFT", 8, -8)
        for i = 1, 5 do
            local slot = bar:CreateTexture(nil, "OVERLAY")
            slot:SetColorTexture(0.04, 0.04, 0.06, 0.75)
            slot:SetSize(26, 26)
            slot:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 8 + (i - 1) * 30, 12)
        end
    end
    if chat then
        label(chat, "Chat", "TOPLEFT", 8, -8)
        local l1 = label(chat, "[Party] Tester: lets go!", "TOPLEFT", 8, -30)
        l1:SetTextColor(0.67, 0.67, 1)
        local l2 = label(chat, "[Guild] Friend: hi hi :)", "TOPLEFT", 8, -46)
        l2:SetTextColor(0.25, 1, 0.25)
        local l3 = label(chat, "You receive loot: [Shiny Thing]", "TOPLEFT", 8, -62)
        l3:SetTextColor(0, 0.8, 1)
    end

    function frame.Refresh()
        local s = DB()
        if not s then return end
        for _, ov in ipairs({ bar, chat }) do
            if ov then Style(ov, s) end
        end
    end
    frame.Refresh()
    return frame
end

---------------------------------------------------------------------------
-- Events / hooks
---------------------------------------------------------------------------
do
    local pending = false
    later = function()
        if pending then return end
        pending = true
        C_Timer.After(0.1, function() pending = false; Girly.Apply() end)
    end
end

-- chat / meter windows can appear at any time: look again now and then (only
-- while Girly Look is on and only for the number of windows, no hooks on
-- Blizzard's frames)
local known = ""
C_Timer.NewTicker(3, function()
    local s = DB()
    if not (s and s.enabled) or InCombatLockdown() then return end
    local sig = ""
    for i = 1, 5 do if _G["DamageMeterSessionWindow" .. i] then sig = sig .. i end end
    for _, cf in ipairs(ChatFrames()) do sig = sig .. (cf:IsShown() and "c" or "n") end
    if sig ~= known then known = sig; Girly.Apply() end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- run again after H3z0 UI re-draws its bars / chat / meter
        local owned = ns.ActionBarsOwned
        if owned and type(owned.Refresh) == "function" then hooksecurefunc(owned, "Refresh", later) end
        if owned and type(owned.Initialize) == "function" then hooksecurefunc(owned, "Initialize", later) end
        for _, fn in ipairs({ "H3z0UI_RefreshWindowSkins", "H3z0UI_RefreshChat", "FCF_DockUpdate",
            "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow", "FCF_SelectDockFrame" }) do
            if type(_G[fn]) == "function" then hooksecurefunc(_G, fn, later) end
        end
        later()
    else
        C_Timer.After(2, Girly.Apply)
    end
end)
