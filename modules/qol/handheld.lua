---------------------------------------------------------------------------
-- H3z0 UI Handheld / Steam Deck Mode  (added in 0.18)
--
-- Optimizes the UI for small handheld screens such as the Steam Deck
-- (1280x800, 16:10) and for controller play (ConsolePort or WoW's native gamepad):
--   * applies a handheld UI scale (default = pixel-perfect for the current resolution,
--     768 / screen height = 0.96 on a Deck) and restores your old scale when disabled
--   * swaps the unit frames (and moves the primary power bar under the character) to a Steam Deck layout
--     (handheld_layout.lua) and restores yours when disabled
--   * keeps the action bars always visible (no mouseover fade - there is no mouse hover)
--   * fits the H3z0 UI settings window onto the small screen
--   * can switch itself on automatically the first time it sees a small screen
--   * detects ConsolePort / native gamepad so the options page can show their status
--
-- Slash commands: /h3z0ui deck   (toggle)      /h3z0ui deck setup   (open the Steam Deck setup window)
-- 0.20: on an exact 1280x800 screen a setup popup offers the one-click Steam Deck setup.
-- 0.22: new HUD layout (target bar top centre, player health + power bar bottom centre) - see handheld_layout.lua.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local DEFAULTS = {
    enabled = false,          -- Handheld Mode on/off
    autoDetect = true,        -- Switch on once automatically on a small screen (<= 800p)
    autoApplied = false,      -- Internal: auto-detect already ran
    uiScale = 0,              -- Handheld UI scale (0 = auto pixel-perfect)
    keepBarsVisible = true,   -- Disable mouseover fade on action bars while enabled
    fitOptionsWindow = true,  -- Shrink the settings window so it fits the screen
    setupPrompted = false,    -- Steam Deck setup popup: answered (Apply / Don't ask again)
    deckUnitFrames = true,    -- Use the Steam Deck unit frame layout (handheld_layout.lua) while enabled
    pcController = false,     -- PC Controller: PC layout, but ConsolePort on / Action Combat Mode off
    pcHandheld = false,       -- PC Handheld: Steam Deck HUD + Deck layout + ConsolePort, but your PC UI scale
    deckChoice = false,       -- menu mirror: Steam Deck (Handheld Mode with the handheld scale) is on
}

local Handheld = {}
_G.H3z0UI_Handheld = Handheld

local function Cfg()
    local p = Helpers.GetProfile()
    if not p then return nil end
    p.handheld = p.handheld or {}
    local c = p.handheld
    for k, v in pairs(DEFAULTS) do
        if c[k] == nil then c[k] = v end
    end
    return c
end

local function Core()
    return (_G.H3z0UI and _G.H3z0UI.H3z0UICore) or ns.Addon
end

---------------------------------------------------------------------------
-- Detection helpers (used by the options page too)
---------------------------------------------------------------------------
function Handheld.GetResolution()
    local w, h = GetPhysicalScreenSize()
    return w or 0, h or 0
end

function Handheld.IsSteamDeckResolution()
    local w, h = Handheld.GetResolution()
    return w == 1280 and h == 800
end

function Handheld.IsSmallScreen()
    local w, h = Handheld.GetResolution()
    return h > 0 and h <= 800 and w <= 1366
end

function Handheld.ConsolePortLoaded()
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort")) and true or false
end

function Handheld.GamepadEnabled()
    return (C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()) and true or false
end

--- Pixel-perfect scale for the current screen (768 / height), rounded to 2 decimals.
function Handheld.AutoScale()
    local _, h = Handheld.GetResolution()
    if h <= 0 then return 1 end
    local s = math.floor((768 / h) * 100 + 0.5) / 100
    return math.max(0.5, math.min(1.4, s))
end

function Handheld.TargetScale()
    local c = Cfg()
    if c and c.uiScale and c.uiScale > 0 then return c.uiScale end
    return Handheld.AutoScale()
end

---------------------------------------------------------------------------
-- Combat-safe execution
---------------------------------------------------------------------------
local pendingAfterCombat = false
local function RunSafe(fn)
    if InCombatLockdown() then
        if not pendingAfterCombat then
            pendingAfterCombat = true
            local f = CreateFrame("Frame")
            f:RegisterEvent("PLAYER_REGEN_ENABLED")
            f:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                pendingAfterCombat = false
                fn()
            end)
        end
        return
    end
    fn()
end

---------------------------------------------------------------------------
-- Scale
---------------------------------------------------------------------------
function Handheld.ApplyScale()
    local c, p, core = Cfg(), Helpers.GetProfile(), Core()
    if not (c and p and p.general and core) then return end
    RunSafe(function()
        if c.enabled and not c.pcHandheld then
            if c.prevScale == nil then c.prevScale = p.general.uiScale end
            p.general.uiScale = Handheld.TargetScale()
            if not Handheld._dataOnly then
                if core.ApplyUIScale then core:ApplyUIScale() else pcall(UIParent.SetScale, UIParent, p.general.uiScale) end
            end
        elseif c.prevScale ~= nil then
            p.general.uiScale = c.prevScale
            c.prevScale = nil
            if not Handheld._dataOnly then
                if core.ApplyUIScale then core:ApplyUIScale() else pcall(UIParent.SetScale, UIParent, p.general.uiScale) end
            end
        end
        if not Handheld._dataOnly then Handheld.FitOptionsWindow() end
        -- the layout is proportional to the UI size, so it has to follow every scale change (slider / preset buttons)
        Handheld.ApplyUnitFrames()
        Handheld.ApplyProfileLayout()
    end)
end

---------------------------------------------------------------------------
-- Action bars: no mouseover fade while handheld (there is no mouse hover on a controller)
---------------------------------------------------------------------------
function Handheld.ApplyBars()
    local c, p = Cfg(), Helpers.GetProfile()
    local fade = p and p.actionBars and p.actionBars.fade
    if not (c and fade) then return end
    local changed = false
    if c.enabled and c.keepBarsVisible then
        if c.prevFade == nil then c.prevFade = fade.enabled and "on" or "off" end
        if fade.enabled ~= false then fade.enabled = false; changed = true end
    elseif c.prevFade ~= nil then
        fade.enabled = (c.prevFade == "on")
        c.prevFade = nil
        changed = true
    end
    if changed and not Handheld._dataOnly and _G.H3z0UI_RefreshActionBars then _G.H3z0UI_RefreshActionBars() end
end

---------------------------------------------------------------------------
-- Unit frames: Steam Deck layout (sizes, positions, text) while handheld; old values restored when off
-- Preset values live in handheld_layout.lua (ns.HandheldUnitFrameLayout). Only the keys listed there are touched.
---------------------------------------------------------------------------
local NIL = "__h3z0nil"

-- "castbar.enabled" -> (db.castbar, "enabled"); nil when the parent table does not exist
local function ResolvePath(unitTable, path)
    local parent = unitTable
    for part in string.gmatch(path, "([^%.]+)%.") do
        parent = type(parent) == "table" and parent[part] or nil
        if type(parent) ~= "table" then return nil end
    end
    return parent, string.match(path, "([^%.]+)$")
end

-- 0.22.5: the preset was measured on a 2560x1440 screen at UI scale 0.85 (ns.HandheldLayoutRef). To look the same at
-- ANY handheld UI scale / resolution / aspect ratio, every size and position is converted so it takes up the same
-- share of the screen: k = (UI height now) / (UI height of the reference). Horizontal positions listed in
-- ns.HandheldEdgeAnchors keep their scaled distance from that screen edge (16:9 reference vs a 16:10 Deck);
-- everything else is scaled from the screen centre. Borders stay as they are (pixel-perfect 1-2 px lines).
local SCALED_KEYS = {
    ["width"] = true, ["height"] = true, ["portraitSize"] = true, ["portraitGap"] = true,
    ["nameFontSize"] = "font", ["healthFontSize"] = "font",
    ["nameOffsetX"] = true, ["nameOffsetY"] = true, ["healthOffsetX"] = true, ["healthOffsetY"] = true,
    ["auras.iconSize"] = true, ["auras.buffIconSize"] = true,
    ["castbar.height"] = true, ["castbar.width"] = true, ["castbar.offsetX"] = true, ["castbar.offsetY"] = true,
    ["powerBarHeight"] = true, ["spacing"] = true,
}

local function RoundHalf(v)
    return math.floor(v * 2 + 0.5) / 2
end

local function LayoutMetrics()
    local ref = ns.HandheldLayoutRef
    if not (ref and UIParent) then return nil end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if not (w and h and w > 0 and h > 0) then return nil end
    return ref, w, h, math.max(0.4, math.min(2.5, h / ref.height))
end

local function AdaptValue(value, path, anchors)
    if type(value) ~= "number" or value == 0 then return value end
    local ref, w, h, k = LayoutMetrics()
    if not ref then return value end
    if path == "offsetX" then
        local wr, wc = ref.width / 2, w / 2
        if anchors and anchors.x == "LEFT" then return RoundHalf(-wc + k * (value + wr))
        elseif anchors and anchors.x == "RIGHT" then return RoundHalf(wc - k * (wr - value)) end
        return RoundHalf(k * value)
    elseif path == "offsetY" then
        return RoundHalf(k * value)
    end
    local kind = SCALED_KEYS[path]
    if kind == "font" then return math.max(8, math.floor(value * k + 0.5)) end
    if kind then
        local v = math.floor(value * k + 0.5)
        if v == 0 then v = (value > 0) and 1 or -1 end
        return v
    end
    return value
end

function Handheld.ApplyUnitFrames()
    local c, preset = Cfg(), ns.HandheldUnitFrameLayout
    local db = Helpers.GetModuleDB("h3z0uiUnitFrames")
    if not (c and preset and db) then return end
    RunSafe(function()
        local reloadNeeded = false
        if c.enabled and c.deckUnitFrames then
            c.prevUF = c.prevUF or {}
            for unit, keys in pairs(preset) do
                local ut = db[unit]
                if type(ut) == "table" then
                    c.prevUF[unit] = c.prevUF[unit] or {}
                    for path, value in pairs(keys) do
                        local parent, key = ResolvePath(ut, path)
                        if parent then
                            if c.prevUF[unit][path] == nil then
                                local old = parent[key]
                                c.prevUF[unit][path] = (old == nil) and NIL or old
                            end
                            if key == "enabled" and parent[key] ~= value then reloadNeeded = true end
                            value = AdaptValue(value, path, ns.HandheldEdgeAnchors and ns.HandheldEdgeAnchors.units and ns.HandheldEdgeAnchors.units[unit])
                            parent[key] = value
                        end
                    end
                end
            end
        elseif c.prevUF then
            for unit, saved in pairs(c.prevUF) do
                local ut = db[unit]
                if type(ut) == "table" then
                    for path, old in pairs(saved) do
                        local parent, key = ResolvePath(ut, path)
                        if parent then
                            local v = nil
                            if old ~= NIL then v = old end
                            if key == "enabled" and parent[key] ~= v then reloadNeeded = true end
                            parent[key] = v
                        end
                    end
                end
            end
            c.prevUF = nil
        else
            return
        end
        if not Handheld._dataOnly and _G.H3z0UI_RefreshUnitFrames then pcall(_G.H3z0UI_RefreshUnitFrames) end
        if reloadNeeded and not Handheld._dataOnly then
            print("|cff34D399H3z0 UI:|r Some unit frames or castbars were switched on/off by the Steam Deck layout - type |cffFFFF00/reload|r to finish.")
        end
    end)
end

---------------------------------------------------------------------------
-- Profile tables (0.22): top-level profile tables from ns.HandheldProfileLayout (e.g. powerBar)
-- Same save / restore logic as the unit frames; saved values live in c.prevProfile.
---------------------------------------------------------------------------
function Handheld.ApplyProfileLayout()
    local c, preset, p = Cfg(), ns.HandheldProfileLayout, Helpers.GetProfile()
    if not (c and preset and p) then return end
    RunSafe(function()
        local changed = false
        if c.enabled and c.deckUnitFrames then
            c.prevProfile = c.prevProfile or {}
            for tname, keys in pairs(preset) do
                local t = p[tname]
                if type(t) == "table" then
                    c.prevProfile[tname] = c.prevProfile[tname] or {}
                    for path, value in pairs(keys) do
                        local parent, key = ResolvePath(t, path)
                        if parent then
                            if c.prevProfile[tname][path] == nil then
                                local old = parent[key]
                                c.prevProfile[tname][path] = (old == nil) and NIL or old
                            end
                            value = AdaptValue(value, path, ns.HandheldEdgeAnchors and ns.HandheldEdgeAnchors.profile and ns.HandheldEdgeAnchors.profile[tname])
                            if parent[key] ~= value then changed = true end
                            parent[key] = value
                        end
                    end
                end
            end
        elseif c.prevProfile then
            for tname, saved in pairs(c.prevProfile) do
                local t = p[tname]
                if type(t) == "table" then
                    for path, old in pairs(saved) do
                        local parent, key = ResolvePath(t, path)
                        if parent then
                            local v = nil
                            if old ~= NIL then v = old end
                            if parent[key] ~= v then changed = true end
                            parent[key] = v
                        end
                    end
                end
            end
            c.prevProfile = nil
        else
            return
        end
        if changed and not Handheld._dataOnly then
            local core = Core()
            if core and core.UpdatePowerBar then pcall(core.UpdatePowerBar, core) end
        end
    end)
end

---------------------------------------------------------------------------
-- Settings window: fit it onto the screen
---------------------------------------------------------------------------
function Handheld.FitOptionsWindow()
    local GUI = _G.H3z0UI and _G.H3z0UI.GUI
    local f = GUI and GUI.MainFrame
    local c, p = Cfg(), Helpers.GetProfile()
    if not (f and c and p) then return end
    local saved = p.configPanelScale or 1.0
    if c.enabled and c.fitOptionsWindow and not c.pcHandheld then
        local w, h = f:GetWidth(), f:GetHeight()
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        if w > 0 and h > 0 and sw > 0 and sh > 0 then
            local fit = math.min(saved, 0.95 * sw / w, 0.95 * sh / h)
            f:SetScale(math.max(0.5, fit))
        end
    else
        f:SetScale(saved)
    end
end

---------------------------------------------------------------------------
-- One-click Steam Deck preset (used by the options page and the setup popup)
---------------------------------------------------------------------------
function Handheld.ApplyPreset()
    local c = Cfg()
    if not c then return end
    c.uiScale = Handheld.AutoScale()
    c.keepBarsVisible = true
    c.fitOptionsWindow = true
    c.setupPrompted = true
    Handheld.SetEnabled(true)
end

---------------------------------------------------------------------------
-- Steam Deck setup popup (shown on a 1280x800 screen)
---------------------------------------------------------------------------
local function GetAccent()
    local p = Helpers.GetProfile()
    local g = p and p.general
    if g and g.skinUseClassColor then
        local _, class = UnitClass("player")
        local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if cc then return cc.r, cc.g, cc.b end
    end
    local a = g and g.addonAccentColor
    if a and a[1] then return a[1], a[2], a[3] end
    return 0.204, 0.827, 0.6
end

local FONT = "Interface\\AddOns\\H3z0UI\\assets\\Expressway.TTF"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local setupPopup

local function MakePopupButton(parent, text, w, primary, ar, ag, ab, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 34)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    local label = b:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 12, "")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)
    local function Idle()
        if primary then
            b:SetBackdropColor(ar, ag, ab, 0.9)
            b:SetBackdropBorderColor(ar, ag, ab, 1)
            label:SetTextColor(0.04, 0.06, 0.1, 1)
        else
            b:SetBackdropColor(0.08, 0.11, 0.17, 1)
            b:SetBackdropBorderColor(0.25, 0.3, 0.35, 1)
            label:SetTextColor(0.8, 0.84, 0.88, 1)
        end
    end
    Idle()
    b:SetScript("OnEnter", function()
        if primary then
            b:SetBackdropColor(math.min(1, ar + 0.15), math.min(1, ag + 0.15), math.min(1, ab + 0.15), 1)
        else
            b:SetBackdropBorderColor(ar, ag, ab, 1)
            label:SetTextColor(1, 1, 1, 1)
        end
    end)
    b:SetScript("OnLeave", Idle)
    b:SetScript("OnClick", onClick)
    return b
end

function Handheld.ShowSetupPopup()
    if setupPopup then
        setupPopup.Refresh()
        setupPopup:Show()
        return
    end
    local ar, ag, ab = GetAccent()
    local lr, lg, lb = ar + (1 - ar) * 0.3, ag + (1 - ag) * 0.3, ab + (1 - ab) * 0.3

    local f = CreateFrame("Frame", "H3z0UI_DeckSetupPopup", UIParent, "BackdropTemplate")
    f:SetSize(468, 322)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(700)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(0.067, 0.094, 0.153, 0.98)
    f:SetBackdropBorderColor(ar, ag, ab, 1)
    tinsert(UISpecialFrames, "H3z0UI_DeckSetupPopup")  -- Esc = "Not now"

    -- Accent glow + line (same look as the options window header)
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("TOPRIGHT", -1, -1)
    glow:SetHeight(78)
    glow:SetColorTexture(1, 1, 1, 1)
    glow:SetGradient("HORIZONTAL", CreateColor(ar, ag, ab, 0.22), CreateColor(ar, ag, ab, 0.02))
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -78)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -78)
    line:SetHeight(2)
    line:SetColorTexture(1, 1, 1, 1)
    line:SetGradient("HORIZONTAL", CreateColor(ar, ag, ab, 1), CreateColor(ar, ag, ab, 0.08))

    -- Logo badge
    local badge = CreateFrame("Frame", nil, f, "BackdropTemplate")
    badge:SetSize(52, 52)
    badge:SetPoint("TOPLEFT", 18, -13)
    badge:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    badge:SetBackdropColor(0.03, 0.045, 0.08, 1)
    badge:SetBackdropBorderColor(ar, ag, ab, 1)
    local icon = badge:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\icon.tga")
    icon:SetSize(48, 48)
    icon:SetPoint("CENTER")
    icon:SetDesaturated(true)
    icon:SetVertexColor(lr, lg, lb, 1)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 18, "OUTLINE")
    title:SetTextColor(lr, lg, lb, 1)
    title:SetPoint("TOPLEFT", badge, "TOPRIGHT", 13, -5)
    title:SetText("STEAM DECK DETECTED")

    local sub = f:CreateFontString(nil, "OVERLAY")
    sub:SetFont(FONT, 11, "")
    sub:SetTextColor(0.6, 0.65, 0.7, 1)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)

    -- What the setup does
    local body = f:CreateFontString(nil, "OVERLAY")
    body:SetFont(FONT, 12, "")
    body:SetTextColor(0.9, 0.92, 0.95, 1)
    body:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -96)
    body:SetWidth(428)
    body:SetJustifyH("LEFT")
    body:SetSpacing(5)

    local note = f:CreateFontString(nil, "OVERLAY")
    note:SetFont(FONT, 10, "")
    note:SetTextColor(0.6, 0.65, 0.7, 1)
    note:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -10)
    note:SetWidth(428)
    note:SetJustifyH("LEFT")

    local c0 = Cfg()
    local function Done()
        f:Hide()
    end

    local apply = MakePopupButton(f, "Apply Steam Deck Setup", 196, true, ar, ag, ab, function()
        Handheld.ApplyPreset()
        Done()
    end)
    apply:SetPoint("BOTTOMLEFT", 20, 40)

    local later = MakePopupButton(f, "Not now", 90, false, ar, ag, ab, Done)
    later:SetPoint("LEFT", apply, "RIGHT", 8, 0)

    local never = MakePopupButton(f, "Don't ask again", 122, false, ar, ag, ab, function()
        local c = Cfg()
        if c then c.setupPrompted = true end
        print("|cff34D399H3z0 UI:|r Steam Deck setup window disabled. Run |cffFFFF00/h3z0ui deck setup|r to open it again.")
        Done()
    end)
    never:SetPoint("LEFT", later, "RIGHT", 8, 0)

    local hint = f:CreateFontString(nil, "OVERLAY")
    hint:SetFont(FONT, 10, "")
    hint:SetTextColor(0.6, 0.65, 0.7, 1)
    hint:SetPoint("BOTTOM", 0, 14)
    hint:SetText("Open this window any time with /h3z0ui deck setup")

    function f.Refresh()
        local w, h = Handheld.GetResolution()
        sub:SetText(string.format("%dx%d screen - set up H3z0 UI for handheld play?", w, h))
        body:SetText(table.concat({
            string.format("|cff%02x%02x%02x-|r  UI scale set to pixel-perfect (%.2f)", ar * 255, ag * 255, ab * 255, Handheld.AutoScale()),
            string.format("|cff%02x%02x%02x-|r  Action bars always visible (no mouseover fade)", ar * 255, ag * 255, ab * 255),
            string.format("|cff%02x%02x%02x-|r  Player portrait top left, target bar top centre, power bar bottom centre", ar * 255, ag * 255, ab * 255),
            string.format("|cff%02x%02x%02x-|r  Settings window shrunk to fit the screen", ar * 255, ag * 255, ab * 255),
            string.format("|cff%02x%02x%02x-|r  Your old scale, fade and frame settings are restored if you turn it off", ar * 255, ag * 255, ab * 255),
        }, "\n"))
        if Handheld.ConsolePortLoaded() then
            note:SetText("ConsolePort detected - its own bars and bindings are left untouched.")
        elseif Handheld.GamepadEnabled() then
            note:SetText("WoW's native gamepad support is on. ConsolePort not loaded.")
        else
            note:SetText("ConsolePort not loaded. Set up controller bindings in ConsolePort or WoW's gamepad options.")
        end
    end
    f.Refresh()

    setupPopup = f
end

---------------------------------------------------------------------------
-- Deck switch: Action Combat Mode off, ConsolePort on, Edit Mode layout "H3z0 Deck"
-- What was active before is saved in c.deckSwap and put back when Handheld
-- Mode is turned off again.
---------------------------------------------------------------------------
local DECK_LAYOUT = "h3z0 deck"

local function Clean(str)
    str = tostring(str or "")
    str = str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return str:lower():gsub("[%s_%-%.]", "")
end

-- Every name the Combat Mode addon has had (folder "CombatMode", now titled "Action Combat Mode")
local COMBAT_MODE_KEYS = { combatmode = true, actioncombat = true, actioncombatmode = true }

-- Folder names of installed addons matching a key ("actioncombat", "consoleport")
local function FindAddOns(key, exactOnly)
    if key == "actioncombat" then
        local found = {}
        local num = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or (GetNumAddOns and GetNumAddOns()) or 0
        for i = 1, num do
            local name, title
            if C_AddOns and C_AddOns.GetAddOnInfo then name, title = C_AddOns.GetAddOnInfo(i) else name, title = GetAddOnInfo(i) end
            if name then
                local n, t = Clean(name), Clean(title)
                if COMBAT_MODE_KEYS[n] or COMBAT_MODE_KEYS[t] then found[#found + 1] = name end
            end
        end
        return found
    end
    return Handheld._FindAddOnsByKey(key, exactOnly)
end

function Handheld._FindAddOnsByKey(key, exactOnly)
    if key == "consoleport" then
        local found = {}
        local num = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or (GetNumAddOns and GetNumAddOns()) or 0
        for i = 1, num do
            local name
            if C_AddOns and C_AddOns.GetAddOnInfo then name = C_AddOns.GetAddOnInfo(i) else name = GetAddOnInfo(i) end
            if name and Clean(name):sub(1, #key) == key then found[#found + 1] = name end
        end
        return found
    end
    local found = {}
    local num = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or (GetNumAddOns and GetNumAddOns()) or 0
    for i = 1, num do
        local name, title
        if C_AddOns and C_AddOns.GetAddOnInfo then name, title = C_AddOns.GetAddOnInfo(i) else name, title = GetAddOnInfo(i) end
        if name then
            local n = Clean(name)
            if n == key or (not exactOnly and Clean(title) == key) then
                found[#found + 1] = name
            end
        end
    end
    return found
end

function Handheld.FindCombatModeAddOns() return FindAddOns("actioncombat") end

-- Is the addon loaded right now? (reliable on Midnight and WoW: Forever)
local function IsLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok then return loaded and true or false end
    end
    if IsAddOnLoaded then return IsAddOnLoaded(name) and true or false end
    return false
end

-- Enabled for the next load? Both argument orders exist (Midnight: name, character;
-- older-style clients: character, name), so ask both ways and take the one that answers.
local function IsAddOnOn(name)
    local me = UnitName("player")
    local function Try(fn, a, b)
        local ok, v = pcall(fn, a, b)
        v = ok and tonumber(v) or nil
        return v
    end
    local state
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        state = Try(C_AddOns.GetAddOnEnableState, name, me) or Try(C_AddOns.GetAddOnEnableState, me, name)
    end
    if state == nil and GetAddOnEnableState then
        state = Try(GetAddOnEnableState, me, name) or Try(GetAddOnEnableState, name, me)
    end
    if state == nil then return IsLoaded(name) end
    return state > 0
end

-- Enable / disable for all characters AND this character (per-character settings
-- would otherwise win on some clients)
local function SetAddOn(name, on)
    local me = UnitName("player")
    local fn
    if on then
        fn = (C_AddOns and C_AddOns.EnableAddOn) or EnableAddOn
    else
        fn = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
    end
    if not fn then return end
    pcall(fn, name)
    if me then pcall(fn, name, me) end
end

function Handheld.IsAddOnEnabled(name) return IsAddOnOn(name) end
function Handheld.SetAddOnEnabled(name, on) SetAddOn(name, on) end

local function NumPresetLayouts()
    local n = 0
    if Enum and Enum.EditModePresetLayouts then
        for _ in pairs(Enum.EditModePresetLayouts) do n = n + 1 end
    end
    return n > 0 and n or 2
end

local function EditModeInfo()
    if not (C_EditMode and C_EditMode.GetLayouts) then return nil end
    local info = C_EditMode.GetLayouts()
    if type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
    return info
end

local function FindDeckLayout(info)
    for i, l in ipairs(info.layouts) do
        if Clean(l.layoutName) == Clean(DECK_LAYOUT) then return NumPresetLayouts() + i end
    end
end

local function SetLayout(index)
    if index and C_EditMode and C_EditMode.SetActiveLayout then
        pcall(C_EditMode.SetActiveLayout, index)
        return true
    end
end

local function Say(msg) print("|cff34D399H3z0 UI:|r " .. msg) end

-- Controller addons: ConsolePort on + Action Combat Mode off (controller = true),
-- or the mouse / keyboard set (Action Combat Mode on + ConsolePort off).
-- Returns true when an addon was switched (needs a reload).
local function ApplyAddonSet(controller)
    local changed, switched = false, {}
    -- Always set the wanted state (cheap, and fixes a wrong saved state);
    -- a reload is needed when what's loaded right now differs from what we want.
    local function Want(name, on)
        if IsAddOnOn(name) ~= on then switched[#switched + 1] = (on and "+" or "-") .. name end
        SetAddOn(name, on)
        if IsLoaded(name) ~= on then changed = true end
    end
    for _, name in ipairs(FindAddOns("actioncombat")) do Want(name, not controller) end
    -- ConsolePort and all its modules (ConsolePort_Bar, ConsolePort_Menu, ...)
    local cp = FindAddOns("consoleport")
    if controller and #cp == 0 then Say("ConsolePort is not installed.") end
    for _, name in ipairs(cp) do Want(name, controller) end
    -- the game's own gamepad support must be on for ConsolePort
    if controller and C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("GamePadEnable") == "0" then
        pcall(C_CVar.SetCVar, "GamePadEnable", "1")
        changed = true
    end
    if #switched > 0 then Say("Addons: " .. table.concat(switched, ", ")) end
    return changed
end

-- Returns true when something changed (a reload is needed)
function Handheld.ApplyDeckSwitch(on)
    local c = Cfg()
    if not c then return false end
    if InCombatLockdown() then
        Say("Leave combat to switch addons and the Edit Mode layout.")
        return false
    end
    local changed = false

    if on then
        local swap = {}
        if ApplyAddonSet(true) then changed = true end
        -- (Blizzard frame positions for Deck come from H3z0 UI, Edit Mode is not touched)
        -- keep the first saved state if Handheld Mode is switched on twice
        if not c.deckSwap then c.deckSwap = swap end
    else
        -- Off: back to the PC layout; addons follow PC / PC Controller
        if ApplyAddonSet(c.pcController and true or false) then changed = true end
        c.deckSwap = nil
    end
    return changed
end

ns.Popups["H3Z0UI_DECK_RELOAD"] = {
    text = "Handheld Mode switched addons and the Edit Mode layout.\n\nReload the UI now?",
    button1 = RELOADUI or "Reload UI",
    button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

---------------------------------------------------------------------------
-- Public entry points
---------------------------------------------------------------------------
function Handheld.Apply()
    Handheld.ApplyScale()   -- also runs ApplyUnitFrames + ApplyProfileLayout
    Handheld.ApplyBars()
end

-- Save every handheld setting without refreshing anything on screen
-- (used right before a reload, which applies it all anyway)
function Handheld.ApplyDataOnly()
    Handheld._dataOnly = true
    local ok, err = pcall(Handheld.Apply)
    Handheld._dataOnly = nil
    if not ok then geterrorhandler()(err) end
end

function Handheld.SetEnabled(on, silent, auto)
    local c = Cfg()
    if not c then return end
    -- Steam Deck / PC Handheld on turns PC Controller off (only one at a time)
    if on and c.pcController then
        c.pcController = false
        if not silent then Say((c.pcHandheld and "PC Handheld" or "Steam Deck") .. " on - PC Controller turned off.") end
    end
    if not on then c.pcHandheld = false end
    c.deckChoice = (on and not c.pcHandheld) and true or false
    local was = c.enabled and true or false
    c.enabled = on and true or false

    -- Action Combat / ConsolePort / Edit Mode layout first: if that needs a
    -- reload, only save the settings (no live rescale or frame refreshes,
    -- the reload applies everything) - this is what made the toggle freeze.
    -- PC / Deck positions of the H3z0 UI frames: remember the ones of the mode we leave
    local LSets = ns.LayoutSets
    local modeChanged = (was ~= c.enabled)
    if modeChanged and LSets then
        LSets.Save(was and "deck" or "pc")
    end

    local needReload = false
    if modeChanged or (c.enabled and not c.deckSwap) or not c.enabled then
        needReload = Handheld.ApplyDeckSwitch(c.enabled)
    end

    -- after the Steam Deck preset ran, put back the positions saved for the new mode
    local function LoadPositions()
        if modeChanged and LSets and LSets.Load(c.enabled and "deck" or "pc") then
            return true
        end
    end

    if modeChanged then needReload = true end

    if needReload and not auto and not silent and not InCombatLockdown() then
        Handheld.ApplyDataOnly()
        LoadPositions()
        ReloadUI()
        return
    end

    Handheld.Apply()
    if LoadPositions() and _G.H3z0UI_RefreshUnitFrames then pcall(_G.H3z0UI_RefreshUnitFrames) end
    if needReload and auto then
        ns.ShowPopup("H3Z0UI_DECK_RELOAD")
    end
    -- silent (Setup Wizard): the wizard shows its own Reload button

    if not silent then
        local w, h = Handheld.GetResolution()
        if c.enabled then
            print(string.format("|cff34D399H3z0 UI:|r Handheld Mode |cff00ff00ON|r (%dx%d, UI scale %.2f). Use |cffFFFF00/h3z0ui deck|r to toggle.", w, h, Handheld.TargetScale()))
        else
            print("|cff34D399H3z0 UI:|r Handheld Mode |cffff5555OFF|r - previous UI scale restored.")
        end
    end
end

-- PC Controller: keeps the PC layout, only swaps the addons (ConsolePort on,
-- Action Combat Mode off) and reloads. While Handheld Mode is on the controller
-- addons are used anyway; the choice applies when Handheld Mode goes off.
function Handheld.SetPCController(on, silent)
    local c = Cfg()
    if not c then return end
    c.pcController = on and true or false
    -- PC Controller, PC Handheld and Steam Deck can't be on together: PC Controller
    -- on turns Handheld Mode off (back to the PC layout, ConsolePort stays on) and reloads
    if c.enabled then
        if c.pcController then
            if not silent then Say("PC Controller on - " .. (c.pcHandheld and "PC Handheld" or "Steam Deck") .. " turned off.") end
            Handheld.SetEnabled(false, silent)
        end
        return
    end
    if InCombatLockdown() then
        Say("Leave combat to switch addons.")
        return
    end
    local changed = ApplyAddonSet(c.pcController)
    if not silent then
        Say("PC Controller " .. (c.pcController and "|cff00ff00ON|r - ConsolePort on, Action Combat Mode off." or "|cffff5555OFF|r - Action Combat Mode on, ConsolePort off."))
        if changed then ReloadUI() end
    end
    return changed
end

-- PC Handheld: Steam Deck HUD + Deck layout + ConsolePort, but the PC UI scale.
-- Same switch logic as Steam Deck (addons, Edit Mode layout, reload).
function Handheld.SetPCHandheld(on, silent)
    local c = Cfg()
    if not c then return end
    -- The menu checkbox writes c.pcHandheld before calling this, so the current
    -- state is read from c.enabled / c.deckChoice (Steam Deck), not from c.pcHandheld.
    local deckOn = c.enabled and c.deckChoice and true or false
    local pcHandheldOn = c.enabled and not c.deckChoice and true or false
    if on then
        c.pcHandheld = true
        if deckOn then
            -- coming from Steam Deck: same layout, only the scale goes back to PC
            if not silent then Say("PC Handheld on - Steam Deck turned off (PC UI scale).") end
            c.deckChoice = false
            Handheld.ApplyDataOnly()
            if not silent and not InCombatLockdown() then ReloadUI() end
            return
        end
        if pcHandheldOn then return end
        Handheld.SetEnabled(true, silent)
    else
        if pcHandheldOn then
            c.pcHandheld = true            -- so SetEnabled knows which mode it leaves
            Handheld.SetEnabled(false, silent)
        else
            c.pcHandheld = false
        end
    end
end

-- Steam Deck switch in the menu (Handheld Mode with the handheld scale)
function Handheld.SetSteamDeck(on, silent)
    local c = Cfg()
    if not c then return end
    if on then
        if c.enabled and c.pcHandheld then
            -- coming from PC Handheld: same layout, only the scale changes
            c.pcHandheld = false
            c.deckChoice = true
            if not silent then Say("Steam Deck on - PC Handheld turned off (handheld UI scale).") end
            Handheld.ApplyDataOnly()
            if not silent and not InCombatLockdown() then ReloadUI() end
            return
        end
        c.pcHandheld = false
        Handheld.SetEnabled(true, silent)
    else
        Handheld.SetEnabled(false, silent)
    end
end

function Handheld.TogglePCHandheld()
    local c = Cfg()
    if c then Handheld.SetPCHandheld(not (c.enabled and c.pcHandheld and not c.deckChoice)) end
end

function Handheld.TogglePCController()
    local c = Cfg()
    if c then Handheld.SetPCController(not c.pcController) end
end

function Handheld.Toggle()
    local c = Cfg()
    if not c then return end
    Handheld.SetEnabled(not c.enabled)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    -- Re-fit the settings window every time it opens
    local GUI = _G.H3z0UI and _G.H3z0UI.GUI
    if GUI and GUI.Show then
        hooksecurefunc(GUI, "Show", function() Handheld.FitOptionsWindow() end)
    end

    -- 0.22.5: docking / undocking the Deck (or any resolution or scale change) changes the screen width, so
    -- re-run the edge-anchored layout once things have settled.
    local pending = false
    local function Relayout()
        if pending then return end
        pending = true
        C_Timer.After(1, function()
            pending = false
            local c = Cfg()
            if c and c.enabled then
                Handheld.ApplyUnitFrames()
                Handheld.ApplyProfileLayout()
            end
        end)
    end
    self:RegisterEvent("DISPLAY_SIZE_CHANGED")
    self:RegisterEvent("UI_SCALE_CHANGED")
    self:SetScript("OnEvent", function(_, ev)
        if ev == "DISPLAY_SIZE_CHANGED" or ev == "UI_SCALE_CHANGED" then Relayout() end
    end)

    -- Give the core a moment to apply its own saved scale first
    C_Timer.After(2, function()
        local c = Cfg()
        if not c then return end
        -- 0.22.6: brand-new install -> the Setup Wizard (device / nameplates / features) decides everything
        local wiz = _G.H3z0UI_Setup
        if wiz and wiz.ShouldAutoShow and wiz.ShouldAutoShow() then
            wiz.Show()
            return
        end
        -- Exact Steam Deck screen (1280x800): offer the one-click setup window instead of switching silently
        if Handheld.IsSteamDeckResolution() and not c.setupPrompted and not c.enabled then
            c.autoApplied = true
            Handheld.ShowSetupPopup()
        -- First time on another small screen: switch on automatically, once
        elseif c.autoDetect and not c.autoApplied and Handheld.IsSmallScreen() then
            c.autoApplied = true
            if not c.enabled then Handheld.SetEnabled(true, nil, true) end
        elseif c.enabled then
            -- Already on: make sure bars + window fit are in the right state (scale is already saved)
            Handheld.ApplyBars()
            Handheld.ApplyUnitFrames()
            Handheld.ApplyProfileLayout()
        end
        if c.enabled and Handheld.ConsolePortLoaded() then
            print("|cff34D399H3z0 UI:|r Handheld Mode active, ConsolePort detected.")
        end
    end)
end)
