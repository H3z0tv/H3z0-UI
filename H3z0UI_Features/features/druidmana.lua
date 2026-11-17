---------------------------------------------------------------------------
-- H3z0 UI - Druid Mana Bar (Midnight)
-- A druid in Cat, Bear or Moonkin form (or Feral / Guardian / Balance) has no
-- Mana on the player frame. This puts a Mana bar inside the H3z0 player frame,
-- under its health / power bar, while the main resource is something else, and hides it when Mana
-- is the main resource. Values may be secret in combat, so they only go to
-- StatusBar:SetValue / SetMinMaxValues and string.format.
-- (WoW: Forever druids get the Formwise form bars instead - see formwise/.)
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

if ns.Client and ns.Client.isLegacy then return end
local _, class = UnitClass("player")
if class ~= "DRUID" then return end

local DEFAULTS = { enabled = true, showText = true, height = 10 }
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local SUB_KEY = "druidMana"

local function S()
    local s = Helpers and Helpers.GetModuleSettings and Helpers.GetModuleSettings("druidMana", DEFAULTS)
    return s or DEFAULTS
end

local bar

-- The bar lives inside the H3z0 player frame: the unit frames stack it under
-- the health / power bar (same left and right edges, 1px separator, inside the
-- frame's one border), so it can't stick out or come loose at the ends.
local function PlayerFrame()
    local f = _G.H3z0UI_Player
    if f and f.GetObjectType and f.healthBar and _G.H3z0UI_SetUnitSubBar then return f end
    return nil
end

local function Create(parent)
    if bar then return bar end
    bar = CreateFrame("StatusBar", "H3z0UI_DruidManaBar", parent)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:EnableMouse(false)
    local c = PowerBarColor and PowerBarColor["MANA"]
    if c and c.r then bar:SetStatusBarColor(c.r, c.g, c.b) else bar:SetStatusBarColor(0, 0, 1) end
    bar.text = bar:CreateFontString(nil, "OVERLAY", TextStatusBarText and "TextStatusBarText" or "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")
    bar:Hide()
    return bar
end

local function Remove()
    if bar then bar:Hide() end
    if _G.H3z0UI_RemoveUnitSubBar then _G.H3z0UI_RemoveUnitSubBar("player", SUB_KEY) end
end

local function Update()
    local s = S()
    if s.enabled == false then Remove() return end
    -- Mana is already the main resource (Restoration, caster forms): nothing to add
    if UnitPowerType("player") == MANA then Remove() return end
    local f = PlayerFrame()
    if not f then if bar then bar:Hide() end return end
    local b = Create(f)
    pcall(b.SetMinMaxValues, b, 0, UnitPowerMax("player", MANA))
    pcall(b.SetValue, b, UnitPower("player", MANA))
    b.text:SetShown(s.showText ~= false)
    if s.showText ~= false then
        pcall(function() b.text:SetText(string.format("%d", UnitPower("player", MANA))) end)
    end
    _G.H3z0UI_SetUnitSubBar("player", SUB_KEY, b, s.height or 10)
end

_G.H3z0UI_RefreshDruidMana = Update
_G.H3z0UI_DruidManaSettings = S

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
end
for _, e in ipairs({ "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
    pcall(ev.RegisterUnitEvent, ev, e, "player")
end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, Update)
    end
    Update()
end)
