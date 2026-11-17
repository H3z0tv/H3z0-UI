---------------------------------------------------------------------------
-- H3z0 UI - Combo Points under the player frame (WoW: Forever only)
-- Red circles under your player frame, for classes that use combo points (rogue, and a druid in cat
-- form). For when Crosshair Z is not on, e.g. with a controller. They hide while Crosshair Z is
-- loaded, because it shows its own. Settings: H3z0 Features page, Extras tab.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

-- WoW: Forever only (Midnight has its own combo point display)
if not (ns.Client and ns.Client.isForever) then return end

local DEFAULTS = {
    enabled = true,
    hideWithCrosshair = true,
    size = 16,
    gap = 3,
    offsetY = -6,
    showEmpty = true,
}
local function S()
    local s = Helpers and Helpers.GetModuleSettings and Helpers.GetModuleSettings("comboPoints", DEFAULTS)
    return s or DEFAULTS
end
_G.H3z0UI_ComboPointsSettings = S

local LIT = "Interface\\COMMON\\Indicator-Red"
local EMPTY = "Interface\\COMMON\\Indicator-Gray"
local MAX_DOTS = 7

local function IsSecret(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) or false end

local container = CreateFrame("Frame", "H3z0UI_ComboPoints", UIParent)
container:SetSize(10, 10)
container:SetFrameStrata("HIGH")
container:Hide()
local dots = {}
for i = 1, MAX_DOTS do
    local t = container:CreateTexture(nil, "ARTWORK")
    t:SetTexture(EMPTY)
    t:Hide()
    dots[i] = t
end

local function CrosshairLoaded()
    if not (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo) then return false end
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if type(name) == "string" then
            local l = name:lower()
            if (l:find("crosshairz", 1, true) or l:find("truereticle", 1, true))
                and C_AddOns.IsAddOnLoaded(name) then
                return true
            end
        end
    end
    return false
end

local function UsesComboPoints()
    local _, class = UnitClass("player")
    if IsSecret(class) then return false end
    if class == "ROGUE" then return true end
    if class == "DRUID" then
        local power = UnitPowerType("player")
        return power == (Enum and Enum.PowerType and Enum.PowerType.Energy or 3)
    end
    return false
end

local function Current()
    if ns.Client and ns.Client.isLegacy and GetComboPoints then
        return GetComboPoints("player", "target") or 0, 5
    end
    local pt = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
    local cur, max = UnitPower("player", pt), UnitPowerMax("player", pt)
    if IsSecret(cur) or IsSecret(max) then return nil end
    return cur or 0, math.min(MAX_DOTS, math.max(5, max or 5))
end

-- The player frame, and the lowest thing that belongs to it: the last bar of its tray (the main power
-- bar, the druid mana / rage / energy bars) when there is one, so the circles sit under all of them.
local function PlayerFrame()
    local uf = ns.H3z0UI_UnitFrames
    local f = uf and uf.frames and uf.frames.player
    if not (f and f.IsShown and f:IsShown()) then return nil end
    local lowest = f
    if uf.ActiveSubBars then
        local ok, list = pcall(uf.ActiveSubBars, f)
        if ok and type(list) == "table" and #list > 0 then
            local last = list[#list].bar
            if last and last.IsShown and last:IsShown() then lowest = last end
        end
    end
    return lowest
end

local function Update()
    local s = S()
    if not s.enabled or (s.hideWithCrosshair and CrosshairLoaded()) or not UsesComboPoints() then
        container:Hide()
        return
    end
    local anchor = PlayerFrame()
    if not anchor then container:Hide() return end
    local cur, max = Current()
    if not cur then container:Hide() return end
    if cur <= 0 and not s.showEmpty then container:Hide() return end

    local size, gap = s.size or 16, s.gap or 3
    local total = max * size + (max - 1) * gap
    container:SetSize(total, size)
    container:ClearAllPoints()
    container:SetPoint("TOP", anchor, "BOTTOM", 0, s.offsetY or -8)
    for i = 1, MAX_DOTS do
        local t = dots[i]
        if i <= max then
            t:ClearAllPoints()
            t:SetSize(size, size)
            t:SetPoint("LEFT", container, "LEFT", (i - 1) * (size + gap), 0)
            t:SetTexture(i <= cur and LIT or EMPTY)
            t:SetAlpha(i <= cur and 1 or 0.45)
            t:Show()
        else
            t:Hide()
        end
    end
    container:Show()
end
_G.H3z0UI_RefreshComboPoints = Update

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM",
    "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_COMBO_POINTS", "PLAYER_REGEN_ENABLED" }) do
    pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event, unit)
    if (event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER"
        or event == "UNIT_COMBO_POINTS") and unit and unit ~= "player" and unit ~= "vehicle" then
        return
    end
    -- a form change sends a burst of these: draw once, just after it
    if event == "UPDATE_SHAPESHIFT_FORM" then
        if not f.formQueued then
            f.formQueued = true
            C_Timer.After(0.1, function() f.formQueued = nil Update() end)
        end
        return
    end
    if f.formQueued then return end
    Update()
end)
-- the frame's bars come and go (druid forms), so the circles follow them
local acc = 0
f:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    Update()
end)
-- the player frame can appear a moment after login
C_Timer.After(2, Update)
C_Timer.After(5, Update)
