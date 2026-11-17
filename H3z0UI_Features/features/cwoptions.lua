--[[
    H3z0 UI - settings shared by the H3z0 character and inspect windows

    One set of settings (profile.character) for both windows, opened from the
    "Settings" button in each window's footer or from H3z0 Features > Character
    Window. Also the gear-row helpers both windows use: the upgrade track
    ("Hero 4/6"), and laying out the name and detail lines.
]]

local ADDON_NAME, ns = ...

local LEGACY = ns.Client and ns.Client.isLegacy and true or false
local RETAIL = not LEGACY

local S = {}
ns.H3zCWShared = S

local DEFAULTS = {
    cwNames = true, cwItemLevel = true, cwTrack = true, cwNoUpgrade = true, cwMaxGray = true,
    h3zBackground = true, h3zLogo = true,
}

function S.Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.character = p.character or {}
    local s = p.character
    for k, v in pairs(DEFAULTS) do if s[k] == nil then s[k] = v end end
    if type(s.cwScale) ~= "number" then s.cwScale = 100 end
    if type(s.cwTextSize) ~= "number" then s.cwTextSize = 0 end
    return s
end

function S.Scale()
    local s = S.Settings()
    local v = s and tonumber(s.cwScale) or 100
    return math.max(70, math.min(130, v)) / 100
end

-- tell both windows (and the background) that something changed
function S.ApplyAll()
    for _, fn in ipairs({ "H3z0UI_RefreshCharacterWindow", "H3z0UI_RefreshInspectWindow", "H3z0UI_RefreshCharacterBackground" }) do
        local f = _G[fn]
        if type(f) == "function" then pcall(f) end
    end
    if S.popup and S.popup:IsShown() then S.popup:Refresh() end
end

---------------------------------------------------------------------------
-- upgrade track, read from the item's own tooltip line (in your game language)
-- returns a table { name, cur, max }, false when the item has none, nil when unknown yet
---------------------------------------------------------------------------
local TRACK_COLORS = {
    explorer = { 0.62, 0.62, 0.62 }, adventurer = { 1, 1, 1 }, veteran = { 0.12, 1, 0 },
    champion = { 0, 0.44, 0.87 }, hero = { 0.64, 0.21, 0.93 }, myth = { 1, 0.5, 0 },
}
local TRACK_ORDER = { "explorer", "adventurer", "veteran", "champion", "hero", "myth" }

local function PatternOf(fmt)
    if type(fmt) ~= "string" then return nil end
    local out, i = {}, 1
    while i <= #fmt do
        local c, n = fmt:sub(i, i), fmt:sub(i + 1, i + 1)
        if c == "%" and n == "s" then out[#out + 1] = "(.-)" i = i + 2
        elseif c == "%" and n == "d" then out[#out + 1] = "(%d+)" i = i + 2
        elseif c == "%" and n == "%" then out[#out + 1] = "%%" i = i + 2
        else
            if c:find("[%(%)%.%+%-%*%?%[%]%^%$%%]") then c = "%" .. c end
            out[#out + 1] = c
            i = i + 1
        end
    end
    return "^%s*" .. table.concat(out) .. "%s*$"
end

local trackPattern, plainPattern
local cache = {}
function S.ClearTrackCache() wipe(cache) end

function S.Track(unit, slotId, link)
    if not RETAIL or not link or not slotId then return nil end
    if issecretvalue and issecretvalue(link) then return nil end
    local hit = cache[link]
    if hit ~= nil then return hit end
    trackPattern = trackPattern or PatternOf(_G.ITEM_UPGRADE_TOOLTIP_FORMAT_STRING) or "^%s*Upgrade Level: (.-) (%d+)/(%d+)%s*$"
    plainPattern = plainPattern or PatternOf(_G.ITEM_UPGRADE_TOOLTIP_FORMAT) or "^%s*Upgrade Level: (%d+)/(%d+)%s*$"
    local ok, data = pcall(function()
        return C_TooltipInfo and C_TooltipInfo.GetInventoryItem and C_TooltipInfo.GetInventoryItem(unit or "player", slotId)
    end)
    if not (ok and data and type(data.lines) == "table") then return nil end
    local found = false
    for _, line in ipairs(data.lines) do
        local t = line.leftText
        if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then
            t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local name, cur, max = t:match(trackPattern)
            if name then found = { name = name, cur = tonumber(cur), max = tonumber(max) } break end
            cur, max = t:match(plainPattern)
            if cur then found = { cur = tonumber(cur), max = tonumber(max) } break end
        end
    end
    cache[link] = found
    return found
end

-- the detail line for an item: item level, then its track (or "No upgrades")
function S.DetailText(unit, slotId, link, ilvl, cosmetic, qr, qg, qb)
    local opts = S.Settings() or {}
    local parts = {}
    local t
    if RETAIL and not cosmetic and (opts.cwTrack ~= false or opts.cwNoUpgrade ~= false) then
        t = S.Track(unit, slotId, link)
    end
    local showTrack = t and opts.cwTrack ~= false
    local showNone = RETAIL and t == false and opts.cwNoUpgrade ~= false
    if opts.cwItemLevel ~= false and ilvl and not cosmetic then
        if showTrack or showNone then
            parts[#parts + 1] = "|cffe6e8eb" .. ilvl .. "|r"
        else
            local ok, txt = pcall(string.format, _G.ITEM_LEVEL or "Item Level %d", ilvl)
            parts[#parts + 1] = ok and txt or tostring(ilvl)
        end
    end
    if showTrack then
        local n = t.name and t.name:lower() or ""
        local c
        for _, key in ipairs(TRACK_ORDER) do
            if n:find(key, 1, true) then c = TRACK_COLORS[key] break end
        end
        c = c or { qr or 1, qg or 1, qb or 1 }
        local full = t.cur and t.max and t.cur >= t.max
        if full and opts.cwMaxGray ~= false then c = { 0.5, 0.53, 0.57 } end
        local txt = (t.name and (t.name .. " ") or "") .. (t.cur or "?") .. "/" .. (t.max or "?")
        parts[#parts + 1] = string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, txt)
            .. (full and " |cff7f8790max|r" or "")
    elseif showNone then
        parts[#parts + 1] = "|cff6b7280No upgrades|r"
    end
    return table.concat(parts, "  ")
end

-- name over detail, or one of them in the middle when the other is off; text size from the settings
function S.Arrange(v, hasName, hasDetail, fontPath)
    local opts = S.Settings() or {}
    local size = opts.cwTextSize or 0
    local key = (hasName and 1 or 0) + (hasDetail and 2 or 0)
    if v.arranged == key and v.sized == size then return end
    v.arranged, v.sized = key, size
    if fontPath then
        v.name:SetFont(fontPath, 12 + size, "")
        v.detail:SetFont(fontPath, 11 + size, "")
    end
    local right = v.side == "right"
    local pt, rel = right and "RIGHT" or "LEFT", right and "LEFT" or "RIGHT"
    local gap = right and -8 or 8
    local other = right and "LEFT" or "RIGHT"
    v.name:ClearAllPoints()
    v.detail:ClearAllPoints()
    if hasName and hasDetail then
        v.name:SetPoint("BOTTOM" .. pt, v.iconFrame, rel, gap, 1)
        v.detail:SetPoint("TOP" .. pt, v.iconFrame, rel, gap, -2)
    elseif hasName then
        v.name:SetPoint(pt, v.iconFrame, rel, gap, 0)
    else
        v.detail:SetPoint(pt, v.iconFrame, rel, gap, 0)
    end
    v.name:SetPoint(other, v, other, 0, 0)
    v.detail:SetPoint(other, v, other, 0, 0)
    v.name:SetShown(hasName)
    v.detail:SetShown(hasDetail)
end

---------------------------------------------------------------------------
-- the settings popup
---------------------------------------------------------------------------
local function Colors()
    local G = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    return {
        accent = (G and G.accent) or { 0.38, 0.65, 0.98 },
        text = (G and G.text) or { 0.92, 0.93, 0.95 },
        label = (G and G.textMuted) or { 0.63, 0.66, 0.71 },
    }
end

local function Font()
    local H = ns.Helpers
    if H and H.GetGeneralFont then
        local ok, f = pcall(H.GetGeneralFont)
        if ok and f then return f end
    end
    return STANDARD_TEXT_FONT
end

local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Font(), size or 12, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local ROWS = {
    { head = "Gear rows" },
    { check = "cwNames", label = "Item names" },
    { check = "cwItemLevel", label = "Item level" },
    { check = "cwTrack", label = "Upgrade track (Hero 4/6)", retail = true },
    { check = "cwMaxGray", label = "Fully upgraded greyed out", retail = true },
    { check = "cwNoUpgrade", label = "Mark items that can't upgrade", retail = true },
    { head = "Look" },
    { check = "h3zBackground", label = "Homeland background" },
    { check = "h3zLogo", label = "H3z0 UI logo" },
    { head = "Size" },
    { step = "cwScale", label = "Window size", min = 70, max = 130, by = 5, suffix = "%" },
    { step = "cwTextSize", label = "Text size", min = -2, max = 4, by = 1, signed = true },
}

local function Build()
    if S.popup then return S.popup end
    local C = Colors()
    local p = CreateFrame("Frame", "H3z0UI_CharWindowSettings", UIParent)
    p:SetFrameStrata("DIALOG")
    p:SetToplevel(true)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:SetWidth(240)
    local R = ns.Round
    local bg
    if R and R.Panel then
        bg = R.Panel(p, 8)
        bg:SetAllPoints(p)
    else
        bg = p:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.075, 0.095, 0.12, 0.97)
    end
    if bg.SetFrameLevel then bg:SetFrameLevel(math.max(0, p:GetFrameLevel() - 1)) end
    local title = Text(p, 13, "LEFT")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Window Settings")
    title:SetTextColor(C.text[1], C.text[2], C.text[3])
    local close = CreateFrame("Button", nil, p)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -8, -8)
    local cx = Text(close, 14, "CENTER")
    cx:SetAllPoints()
    cx:SetText("x")
    cx:SetTextColor(C.label[1], C.label[2], C.label[3])
    close:SetScript("OnClick", function() p:Hide() end)

    p.items = {}
    local y = -34
    for _, row in ipairs(ROWS) do
        if not row.retail or RETAIL then
            if row.head then
                local h = Text(p, 11, "LEFT")
                h:SetPoint("TOPLEFT", 12, y - 4)
                h:SetText(row.head)
                h:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
                y = y - 22
            elseif row.check then
                local b = CreateFrame("Button", nil, p)
                b:SetPoint("TOPLEFT", 12, y)
                b:SetPoint("RIGHT", p, "RIGHT", -12, 0)
                b:SetHeight(20)
                b.box = b:CreateTexture(nil, "ARTWORK")
                b.box:SetSize(14, 14)
                b.box:SetPoint("LEFT", 0, 0)
                b.box:SetColorTexture(1, 1, 1, 0.12)
                b.tick = b:CreateTexture(nil, "OVERLAY")
                b.tick:SetPoint("TOPLEFT", b.box, "TOPLEFT", 3, -3)
                b.tick:SetPoint("BOTTOMRIGHT", b.box, "BOTTOMRIGHT", -3, 3)
                b.tick:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
                b.text = Text(b, 12, "LEFT")
                b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
                b.text:SetPoint("RIGHT", b, "RIGHT", 0, 0)
                b.text:SetText(row.label)
                b.text:SetTextColor(C.text[1], C.text[2], C.text[3])
                b.key = row.check
                b:SetScript("OnClick", function(self)
                    local s = S.Settings()
                    if not s then return end
                    s[self.key] = not (s[self.key] ~= false)
                    S.ClearTrackCache()
                    S.ApplyAll()
                end)
                b:SetScript("OnEnter", function(self) self.box:SetColorTexture(1, 1, 1, 0.22) end)
                b:SetScript("OnLeave", function(self) self.box:SetColorTexture(1, 1, 1, 0.12) end)
                p.items[#p.items + 1] = b
                y = y - 22
            elseif row.step then
                local f = CreateFrame("Frame", nil, p)
                f:SetPoint("TOPLEFT", 12, y)
                f:SetPoint("RIGHT", p, "RIGHT", -12, 0)
                f:SetHeight(22)
                f.text = Text(f, 12, "LEFT")
                f.text:SetPoint("LEFT", 0, 0)
                f.text:SetText(row.label)
                f.text:SetTextColor(C.text[1], C.text[2], C.text[3])
                local function Btn(label, dir)
                    local b = CreateFrame("Button", nil, f)
                    b:SetSize(20, 20)
                    local t = b:CreateTexture(nil, "BACKGROUND")
                    t:SetAllPoints()
                    t:SetColorTexture(1, 1, 1, 0.1)
                    b.bg = t
                    local fs = Text(b, 14, "CENTER")
                    fs:SetAllPoints()
                    fs:SetText(label)
                    b:SetScript("OnEnter", function() t:SetColorTexture(1, 1, 1, 0.2) end)
                    b:SetScript("OnLeave", function() t:SetColorTexture(1, 1, 1, 0.1) end)
                    b:SetScript("OnClick", function()
                        local s = S.Settings()
                        if not s then return end
                        local v = (tonumber(s[row.step]) or 0) + dir * row.by
                        s[row.step] = math.max(row.min, math.min(row.max, v))
                        S.ApplyAll()
                    end)
                    return b
                end
                f.plus = Btn("+", 1)
                f.plus:SetPoint("RIGHT", 0, 0)
                f.value = Text(f, 12, "CENTER")
                f.value:SetWidth(46)
                f.value:SetPoint("RIGHT", f.plus, "LEFT", -2, 0)
                f.minus = Btn("-", -1)
                f.minus:SetPoint("RIGHT", f.value, "LEFT", -2, 0)
                f.row = row
                p.items[#p.items + 1] = f
                y = y - 26
            end
        end
    end
    local hint = Text(p, 10, "LEFT")
    hint:SetPoint("TOPLEFT", 12, y - 4)
    hint:SetPoint("RIGHT", p, "RIGHT", -12, 0)
    hint:SetText("Same settings for the character and inspect windows.")
    hint:SetTextColor(C.label[1], C.label[2], C.label[3])
    p:SetHeight(-y + 28)

    function p:Refresh()
        local s = S.Settings() or {}
        for _, it in ipairs(self.items) do
            if it.key then
                it.tick:SetShown(s[it.key] ~= false)
            elseif it.row then
                local v = tonumber(s[it.row.step]) or 0
                local txt = (it.row.signed and v > 0 and "+" or "") .. v .. (it.row.suffix or "")
                it.value:SetText(txt)
            end
        end
    end
    p:SetScript("OnShow", p.Refresh)
    -- Escape closes it (only once the frame really is the global of that name)
    if type(UISpecialFrames) == "table" and _G.H3z0UI_CharWindowSettings == p then
        tinsert(UISpecialFrames, "H3z0UI_CharWindowSettings")
    end
    p:Hide()
    S.popup = p
    return p
end

-- open or close the popup beside a window
function S.Toggle(owner)
    local p = Build()
    if p:IsShown() and p.owner == owner then p:Hide() return end
    p.owner = owner
    p:ClearAllPoints()
    if owner then
        p:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", 6, 0)
    else
        p:SetPoint("CENTER")
    end
    p:Show()
    p:Refresh()
end

-- the "Settings" button in a window's footer, left of the logo
function S.FooterButton(win, logoText, logoTex)
    local C = Colors()
    local b = CreateFrame("Button", nil, win)
    b:SetHeight(18)
    b.text = Text(b, 12, "RIGHT")
    b.text:SetPoint("RIGHT", 0, 0)
    b.text:SetText(_G.SETTINGS or "Settings")
    b.text:SetTextColor(C.label[1], C.label[2], C.label[3])
    b:SetWidth(math.ceil(b.text:GetStringWidth()) + 6)
    local anchor = (logoTex and logoTex:IsShown() and logoTex) or logoText
    if anchor then
        b:SetPoint("RIGHT", anchor, "LEFT", -18, 0)
    else
        b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -120, 8)
    end
    b:SetFrameLevel(win:GetFrameLevel() + 25)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(C.label[1], C.label[2], C.label[3]) end)
    b:SetScript("OnClick", function() S.Toggle(win) end)
    win:HookScript("OnHide", function() if S.popup and S.popup.owner == win then S.popup:Hide() end end)
    return b
end

_G.H3z0UI_ToggleCharWindowSettings = function() S.Toggle(nil) end

---------------------------------------------------------------------------
-- Midnight: the game's window lies see-through under ours. Its own buttons
-- that are under our header (the small sidebar tabs of the character page,
-- the close button, the title bar) still caught the mouse and took the clicks
-- meant for our tabs and X. While ours is shown they stop catching clicks
-- (only the mouse area changes; our buttons still press them the game's way).
---------------------------------------------------------------------------
local function ScreenRect(f)
    local l, b, w, h = f:GetRect()
    if not l then return nil end
    local s = f:GetEffectiveScale()
    return l * s, b * s, (l + w) * s, (b + h) * s
end

function S.Unblock(game, win, headerH, list)
    list = list or {}
    if not (game and win) or InCombatLockdown() then return list end
    local wl, wb, wr, wt = ScreenRect(win)
    if not wl then return list end
    local stripB = wt - headerH * win:GetEffectiveScale()
    local function Walk(f, depth)
        if f == win then return end
        if f ~= game and f.IsMouseEnabled and f:IsVisible() then
            local ok, mouse = pcall(f.IsMouseEnabled, f)
            if ok and mouse and not list[f] then
                local l, b, r, t = ScreenRect(f)
                -- only small parts lying in the header strip (whole pages and lists are left alone)
                if l and r > wl and l < wr and t > stripB and b < wt and b >= stripB - 12 * win:GetEffectiveScale() then
                    local okI, a1, a2, a3, a4 = pcall(f.GetHitRectInsets, f)
                    if okI and pcall(f.SetHitRectInsets, f, 5000, 5000, 5000, 5000) then
                        list[f] = { a1 or 0, a2 or 0, a3 or 0, a4 or 0 }
                    end
                end
            end
        end
        if depth > 0 then
            for _, c in ipairs({ f:GetChildren() }) do Walk(c, depth - 1) end
        end
    end
    Walk(game, 5)
    return list
end

function S.Restore(list)
    if not list or InCombatLockdown() then return list end
    for f, ins in pairs(list) do
        pcall(f.SetHitRectInsets, f, ins[1], ins[2], ins[3], ins[4])
        list[f] = nil
    end
    return list
end
