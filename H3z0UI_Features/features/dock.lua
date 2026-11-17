---------------------------------------------------------------------------
-- H3z0 UI - Top Dock
-- A slim bar at the top of the screen: your H3z0 menu icons in two rounded
-- groups with the clock in between, and an optional thin colour line along
-- the top edge of the screen.
--
-- * the same icons and buttons as the Dock Bar's menu icons (Character,
--   Spellbook, Achievements, Quest Log, Guild, Social, Group Finder ...);
--   each one goes left, right or stays off (Interface > Top Dock)
-- * it and the Dock Bar are either-or: turning one on turns the other off,
--   and turning the Top Dock off brings the Dock Bar back
-- * while it is on, the game's micro menu steps aside
-- * the whole dock moves as one in H3z0 UI Edit Mode (Top Dock)
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local H3z0UICore = ns.Addon
local Helpers = ns.Helpers
if not H3z0UICore then return end

local Dock = {}
ns.H3z0Dock = Dock

local LAYOUT_KEY = "h3zDock"

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local DEFAULT_SLOTS = {
    character = "left", spellbook = "left", talents = "left", achievements = "left",
    quest = "left", guild = "left", social = "left",
    groupfinder = "right", adventure = "right", collections = "right",
    housing = "right", vault = "right", menu = "right",
    mode_pc = "off",
}

local DEFAULTS = {
    enabled = false,
    hideBlizzardMenus = true,
    hideInCombat = false,
    iconSize = 20, iconGap = 10, pillGap = 8,
    scale = 1, offsetY = -10,
    bgOpacity = 60, border = true,
    iconColor = "white",             -- white | class
    showClock = true, clock24 = true, clockSource = "local", clockSize = 20,
    strip = true, stripClassColor = true, stripHeight = 2,
}

local function DB()
    return Helpers and Helpers.GetModuleDB and Helpers.GetModuleDB("dock")
end

local function BarDB()
    local p = Helpers and Helpers.GetProfile and Helpers.GetProfile()
    return p and p.infobar
end

local function Get(key)
    local db = DB()
    local v = db and db[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

local function On() return Get("enabled") == true end

local function SlotOf(key)
    local db = DB()
    local s = db and type(db.slots) == "table" and db.slots[key]
    if s == "left" or s == "right" or s == "off" then return s end
    return DEFAULT_SLOTS[key] or "off"
end

function Dock.DefaultSlot(key) return DEFAULT_SLOTS[key] or "off" end

function Dock.WantsMenusHidden()
    return On() and Get("hideBlizzardMenus") ~= false
end

local function ClassColor()
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Font()
    local f = Helpers and Helpers.GetGeneralFont and Helpers.GetGeneralFont()
    return f or STANDARD_TEXT_FONT
end

---------------------------------------------------------------------------
-- The button list: the menu icons of the Dock Bar (datatexts_extra.lua)
---------------------------------------------------------------------------
local function Defs()
    local M = ns.H3zMenu
    return M and M.MICRO
end

local function KeyOf(def) return def.custom end

-- key + label of every button, for the options page
function Dock.ButtonList()
    local list = {}
    for _, def in ipairs(Defs() or {}) do
        if KeyOf(def) then list[#list + 1] = { key = KeyOf(def), label = def.name } end
    end
    return list
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local holder, leftPill, rightPill, centerPill, strip
local buttons = {}                 -- key -> button
local buttonList = {}              -- in menu order, for the numbers above the icons
local layoutPending = false
local ready = false

local function SavedPlace()
    local core = Helpers and Helpers.GetCore and Helpers.GetCore()
    local fa = core and core.db and core.db.profile and core.db.profile.frameAnchoring
    return type(fa) == "table" and fa[LAYOUT_KEY] ~= nil
end

local function PlaceHolder()
    if not holder then return end
    if not SavedPlace() then
        holder:ClearAllPoints()
        holder:SetPoint("TOP", UIParent, "TOP", 0, tonumber(Get("offsetY")) or -10)
    elseif _G.H3z0UI_ApplyFrameAnchor and not InCombatLockdown() then
        pcall(_G.H3z0UI_ApplyFrameAnchor, LAYOUT_KEY)
    end
end

local function NewPill(name)
    local pill = CreateFrame("Frame", name, holder)
    pill:SetFrameStrata("LOW")
    local Round = ns.Round
    if Round and Round.Panel then
        pill.bg = Round.Panel(pill, 8)
        pill.bg:SetAllPoints(pill)
        pill.bg:SetFrameLevel(pill:GetFrameLevel())
    else
        pill.bg = pill:CreateTexture(nil, "BACKGROUND")
        pill.bg:SetAllPoints(pill)
        pill.bg.SetFillColor = function(self, r, g, b, a) self:SetColorTexture(r, g, b, a) end
        pill.bg.SetBorderColor = function() end
    end
    -- buttons and the clock live on a frame above the background
    pill.content = CreateFrame("Frame", nil, pill)
    pill.content:SetAllPoints(pill)
    pill.content:SetFrameLevel(pill:GetFrameLevel() + 3)
    return pill
end

local function BuildFrames()
    if holder then return end
    holder = CreateFrame("Frame", "H3z0UI_Dock", UIParent)
    holder:SetFrameStrata("LOW")
    holder:SetSize(400, 34)
    holder:SetPoint("TOP", UIParent, "TOP", 0, -10)
    holder:Hide()           -- shown by Layout once the dock is on

    centerPill = NewPill("H3z0UI_DockClock")
    centerPill:SetPoint("CENTER", holder, "CENTER", 0, 0)
    centerPill:EnableMouse(true)

    leftPill = NewPill("H3z0UI_DockLeft")
    rightPill = NewPill("H3z0UI_DockRight")

    local clock = centerPill.content:CreateFontString(nil, "OVERLAY")
    clock:SetPoint("CENTER", centerPill, "CENTER", 0, 0)
    clock:SetTextColor(1, 1, 1, 1)
    clock:SetShadowOffset(1, -1)
    clock:SetShadowColor(0, 0, 0, 0.8)
    centerPill.text = clock

    centerPill:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(ns.L["Time"], 1, 1, 1)
        GameTooltip:AddDoubleLine(ns.L["Local time"], date("%H:%M"), 0.8, 0.8, 0.8, 1, 1, 1)
        if GameTime_GetGameTime then
            GameTooltip:AddDoubleLine(ns.L["Realm time:"], GameTime_GetGameTime(true), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        local daily = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset()
        if daily and daily > 0 then
            GameTooltip:AddDoubleLine(ns.L["Daily Reset"], SecondsToTime(daily), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        local weekly = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
        if weekly and weekly > 0 then
            GameTooltip:AddDoubleLine(ns.L["Weekly Reset"], SecondsToTime(weekly), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffFFFFFF" .. ns.L["Left Click:"] .. "|r " .. ns.L["Open Calendar"], 0.6, 0.85, 1)
        GameTooltip:Show()
    end)
    centerPill:SetScript("OnLeave", function() GameTooltip:Hide() end)
    centerPill:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and not InCombatLockdown() and _G.ToggleCalendar then pcall(_G.ToggleCalendar) end
    end)

    -- thin colour line along the top edge of the screen
    strip = CreateFrame("Frame", "H3z0UI_DockStrip", UIParent)
    strip:SetFrameStrata("BACKGROUND")
    strip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    strip:SetHeight(2)
    strip.tex = strip:CreateTexture(nil, "ARTWORK")
    strip.tex:SetAllPoints()
    strip:Hide()
end

---------------------------------------------------------------------------
-- Clock
---------------------------------------------------------------------------
local lastClock
local function ClockText()
    local hour, minute
    if Get("clockSource") == "server" then
        hour, minute = GetGameTime()
    else
        hour, minute = tonumber(date("%H")), tonumber(date("%M"))
    end
    if Get("clock24") ~= false then
        return ("%02d:%02d"):format(hour, minute)
    end
    local suffix = hour >= 12 and "PM" or "AM"
    if hour == 0 then hour = 12 elseif hour > 12 then hour = hour - 12 end
    return ("%d:%02d %s"):format(hour, minute, suffix)
end

local function UpdateClock(force)
    if not (centerPill and centerPill.text) or not centerPill:IsShown() then return end
    local text = ClockText()
    if text == lastClock and not force then return end
    lastClock = text
    centerPill.text:SetText(text)
    local w = centerPill.text:GetStringWidth() or 0
    centerPill:SetWidth(math.max(60, w + 28))
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local function RestColor()
    if Get("iconColor") == "class" then
        local r, g, b = ClassColor()
        return { r, g, b }
    end
    return nil
end

local function EnsureButton(def, size)
    local key = KeyOf(def)
    local b = buttons[key]
    if b then return b end
    local cr, cg, cb = ClassColor()
    b = ns.H3zMenu.CreateButton(holder, def, size, {
        r = cr * 255, g = cg * 255, b = cb * 255,
        rest = RestColor(),
        font = Font(),
        counterSize = 10,
        counterCorner = true,
        tooltipAnchor = "ANCHOR_BOTTOM",
    })
    buttons[key] = b
    buttonList[#buttonList + 1] = b
    return b
end

local function UpdateCounts()
    local M = ns.H3zMenu
    if M and M.UpdateCounts then M.UpdateCounts(buttonList) end
end

---------------------------------------------------------------------------
-- Layout (out of combat only: the buttons are secure)
---------------------------------------------------------------------------
local function ApplyLook()
    if not holder then return end
    local scale = math.max(0.5, math.min(2, tonumber(Get("scale")) or 1))
    holder:SetScale(scale)
    local opacity = (tonumber(Get("bgOpacity")) or 60) / 100
    local border = Get("border") ~= false
    for _, pill in ipairs({ leftPill, rightPill, centerPill }) do
        pill.bg:SetFillColor(0.04, 0.05, 0.07, opacity)
        pill.bg:SetBorderColor(1, 1, 1, border and 0.10 or 0)
    end
    local fs = tonumber(Get("clockSize")) or 20
    if not centerPill.text:SetFont(Font(), fs, "OUTLINE") then
        centerPill.text:SetFont(STANDARD_TEXT_FONT, fs, "OUTLINE")
    end

    -- the icons at rest: white (the glyphs are white) or your class colour
    local rest = RestColor()
    for _, b in pairs(buttons) do
        b._rest = rest
        if b.tex and not b:IsMouseOver() then
            if rest then b.tex:SetVertexColor(rest[1], rest[2], rest[3]) else b.tex:SetVertexColor(1, 1, 1) end
        end
    end

    -- the colour line
    local sh = tonumber(Get("stripHeight")) or 2
    strip:SetHeight(math.max(1, sh))
    local r, g, b = 1, 1, 1
    if Get("stripClassColor") ~= false then
        r, g, b = ClassColor()
    else
        local db = DB()
        local c = db and db.stripColor
        if type(c) == "table" then r, g, b = c[1] or 1, c[2] or 1, c[3] or 1 end
    end
    strip.tex:SetColorTexture(r, g, b, 0.9)
    strip:SetShown(On() and Get("strip") ~= false)
end

local function Layout()
    if not On() then
        if holder then holder:Hide() end
        if strip then strip:Hide() end
        return
    end
    if not Defs() then return end
    if InCombatLockdown() then
        layoutPending = true
        return
    end
    layoutPending = false
    BuildFrames()
    holder:Show()           -- shown first: the Game Menu icon needs a visible parent to take its button
    ApplyLook()

    local size = tonumber(Get("iconSize")) or 20
    local gap = tonumber(Get("iconGap")) or 10
    local padX, padY = 12, 7
    local pillH = size + padY * 2
    local pillGap = tonumber(Get("pillGap")) or 8

    local cursor = { left = padX, right = padX }
    local count = { left = 0, right = 0 }
    local pills = { left = leftPill, right = rightPill }

    for _, def in ipairs(Defs()) do
        local key = KeyOf(def)
        if key then
            local side = SlotOf(key)
            local b = EnsureButton(def, size)
            if side == "left" or side == "right" then
                local pill = pills[side]
                b:SetParent(pill.content)
                b:ClearAllPoints()
                b:SetPoint("LEFT", pill, "LEFT", cursor[side], 0)
                b:SetSize(size, size)
                b:Show()
                cursor[side] = cursor[side] + size + gap
                count[side] = count[side] + 1
            else
                b:Hide()
            end
        end
    end

    local showClock = Get("showClock") ~= false
    centerPill:SetShown(showClock)
    centerPill:SetHeight(pillH)
    if showClock then
        lastClock = nil
        UpdateClock(true)
    end

    local widthOf = {}
    for _, side in ipairs({ "left", "right" }) do
        local pill = pills[side]
        local shown = count[side] > 0
        pill:SetShown(shown)
        pill:SetHeight(pillH)
        widthOf[side] = shown and (cursor[side] - gap + padX) or 0
        if shown then pill:SetWidth(widthOf[side]) end
    end

    -- the clock sits in the middle; the groups hang off its sides
    local centerW = showClock and centerPill:GetWidth() or 0
    local halfGap = showClock and pillGap or 0
    leftPill:ClearAllPoints()
    rightPill:ClearAllPoints()
    if showClock then
        leftPill:SetPoint("RIGHT", centerPill, "LEFT", -halfGap, 0)
        rightPill:SetPoint("LEFT", centerPill, "RIGHT", halfGap, 0)
    else
        leftPill:SetPoint("RIGHT", holder, "CENTER", -pillGap / 2, 0)
        rightPill:SetPoint("LEFT", holder, "CENTER", pillGap / 2, 0)
    end
    local side = math.max(widthOf.left, widthOf.right)
    holder:SetSize(math.max(60, side * 2 + centerW + halfGap * 2), pillH)
    PlaceHolder()
    UpdateCounts()
end

---------------------------------------------------------------------------
-- Visibility
---------------------------------------------------------------------------
local function ApplyVisibility()
    if not holder then return end
    local want = On()
    if want and Get("hideInCombat") and InCombatLockdown() then want = false end
    if want and not holder:IsShown() then pcall(holder.Show, holder)
    elseif not want and holder:IsShown() then pcall(holder.Hide, holder) end
end

local acc = 0
local function OnUpdate(_, elapsed)
    acc = acc + elapsed
    if acc < 1 then return end
    acc = 0
    UpdateClock()
end

---------------------------------------------------------------------------
-- Either-or with the Dock Bar
-- Turning the Top Dock on turns the Dock Bar off (it is remembered, so it
-- comes back when the Top Dock goes off). Turning the Dock Bar on turns
-- the Top Dock off.
---------------------------------------------------------------------------
local function RefreshBar()
    if _G.H3z0UI_RefreshBottomBar then pcall(_G.H3z0UI_RefreshBottomBar)
    elseif _G.H3z0UI_RefreshInfoBar then pcall(_G.H3z0UI_RefreshInfoBar) end
end

local function SyncExclusive()
    local d, ib = DB(), BarDB()
    if not (d and ib) then return false end
    if d.enabled == true then
        if ib.enabled ~= false then
            d.barWasOn = true
            ib.enabled = false
            return true
        end
    elseif d.barWasOn then
        d.barWasOn = nil
        ib.enabled = true
        return true
    end
    return false
end

local function ApplyMenus()
    local BB = ns.H3z0BottomBar
    if BB and BB.ApplyMenus then pcall(BB.ApplyMenus) end
end

---------------------------------------------------------------------------
-- H3z0 UI Edit Mode: the dock moves as one
---------------------------------------------------------------------------
local function RegisterLayout()
    local LM = ns.H3z0UI_LayoutMode
    if not (LM and LM.RegisterElement) then return end
    BuildFrames()
    LM:RegisterElement({
        key = LAYOUT_KEY,
        label = "Top Dock",
        group = (ns.L and ns.L["Display"]) or "Display",
        order = 85,
        isOwned = true,
        isEnabled = function() return On() end,
        getFrame = function() return holder end,
    })
    if _G.H3z0UI_RegisterFrameResolver then
        _G.H3z0UI_RegisterFrameResolver(LAYOUT_KEY, {
            resolver = function() return holder end,
            displayName = "Top Dock", category = "Display", order = 85,
        })
    end
    C_Timer.After(0, PlaceHolder)
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function Dock.Refresh()
    local barChanged = SyncExclusive()
    Layout()
    ApplyVisibility()
    ApplyMenus()
    if barChanged then RefreshBar() end
end
_G.H3z0UI_RefreshDock = Dock.Refresh

-- the Dock Bar was turned on (by its switch, its options or a profile): the Top Dock steps aside
local InfoBar = H3z0UICore.InfoBar
if InfoBar and type(InfoBar.ApplyAll) == "function" then
    hooksecurefunc(InfoBar, "ApplyAll", function()
        if not ready then return end
        local d, ib = DB(), BarDB()
        if d and ib and d.enabled == true and ib.enabled ~= false then
            d.enabled = false
            d.barWasOn = nil
            C_Timer.After(0, Dock.Refresh)
        end
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        local ok, err = pcall(function()
            local barChanged = SyncExclusive()
            Layout()
            RegisterLayout()
            if holder then holder:SetScript("OnUpdate", OnUpdate) end
            ApplyVisibility()
            if barChanged then RefreshBar() end
            local M = ns.H3zMenu
            if M and M.COUNT_EVENTS and holder then
                local f = CreateFrame("Frame")
                for _, e in ipairs(M.COUNT_EVENTS) do
                    if _G.H3z0UI_SafeRegisterEvent then _G.H3z0UI_SafeRegisterEvent(f, e) else pcall(f.RegisterEvent, f, e) end
                end
                f:SetScript("OnEvent", UpdateCounts)
                if M.RequestData and On() then M.RequestData() end
            end
        end)
        if not ok and geterrorhandler then geterrorhandler()(err) end
        ready = true
        C_Timer.After(0.6, ApplyMenus)
    elseif event == "PLAYER_REGEN_DISABLED" then
        ApplyVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if layoutPending then Layout() end
        ApplyVisibility()
    else
        C_Timer.After(1, function()
            if not InCombatLockdown() then Layout() ApplyVisibility() end
        end)
    end
end)

-- a new default font reaches the clock
for _, method in ipairs({ "ApplyGlobalFont", "RefreshAllFonts" }) do
    if type(H3z0UICore[method]) == "function" then
        hooksecurefunc(H3z0UICore, method, function()
            C_Timer.After(0, function() if holder and not InCombatLockdown() then ApplyLook() end end)
        end)
    end
end

-- a profile change reaches the dock like the other bars
if ns.Registry and ns.Registry.Register then
    pcall(ns.Registry.Register, ns.Registry, "dock", {
        refresh = Dock.Refresh,
        priority = 42,
        group = "data",
    })
end

-- /h3z0dock: on / off
SLASH_H3Z0DOCK1 = "/h3z0dock"
SlashCmdList["H3Z0DOCK"] = function()
    local db = DB()
    if not db then return end
    db.enabled = not On()
    Dock.Refresh()
    print("|cff30D1FFH3z0 UI|r Top Dock " .. (On() and "on" or "off"))
end
