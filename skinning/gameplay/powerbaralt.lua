local addonName, ns = ...

local function GetCore()
    return (_G.H3z0UI and _G.H3z0UI.H3z0UICore) or ns.Addon
end

local function GetPixelSize(frame, default)
    local core = GetCore()
    if core and type(core.GetPixelSize) == "function" then
        local px = core:GetPixelSize(frame)
        if type(px) == "number" and px > 0 then
            return px
        end
    end
    return default or 1
end

---------------------------------------------------------------------------
-- PLAYER POWER BAR ALT SKINNING
---------------------------------------------------------------------------
-- Replaces the encounter/quest-specific power bar (PlayerPowerBarAlt)
-- with a clean H3z0UI-styled bar. Used for: Atramedes sound, Cho'gall
-- corruption, Darkmoon games, etc.
--
-- Approach: Hide Blizzard's bar, create custom replacement

local FONT_FLAGS = "OUTLINE"

-- Bar dimensions
local BAR_WIDTH = 250
local BAR_HEIGHT = 20

-- Locals for performance
local floor = math.floor
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local GetUnitPowerBarInfo = GetUnitPowerBarInfo
local GetUnitPowerBarStrings = GetUnitPowerBarStrings
local ALTERNATE_POWER_INDEX = Enum.PowerType.Alternate or 10

-- Module state
local H3z0UIAltPowerBar = nil
local powerBarMover = nil
local isEnabled = false

---------------------------------------------------------------------------
-- DATABASE ACCESS
---------------------------------------------------------------------------

local function GetDB()
    local core = GetCore()
    return core and core.db and core.db.profile or {}
end

local function GetBarPosition()
    local db = GetDB()
    return db.powerBarAltPosition
end

local function SaveBarPosition(point, relPoint, x, y)
    local db = GetDB()
    db.powerBarAltPosition = { point = point, relPoint = relPoint, x = x, y = y }
end

---------------------------------------------------------------------------
-- TOOLTIP HANDLING
---------------------------------------------------------------------------

local function OnEnter(self)
    if not self:IsVisible() or GameTooltip:IsForbidden() then return end

    GameTooltip:ClearAllPoints()
    GameTooltip_SetDefaultAnchor(GameTooltip, self)

    if self.powerName and self.powerTooltip then
        GameTooltip:SetText(self.powerName, 1, 1, 1)
        GameTooltip:AddLine(self.powerTooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end
end

local function OnLeave()
    GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- BAR UPDATE
---------------------------------------------------------------------------

local function UpdateBar(self)
    local barInfo = GetUnitPowerBarInfo("player")

    if barInfo then
        local powerName, powerTooltip = GetUnitPowerBarStrings("player")
        local power = UnitPower("player", ALTERNATE_POWER_INDEX)
        local maxPower = UnitPowerMax("player", ALTERNATE_POWER_INDEX)

        -- Calculate percentage safely (handles secret values from Midnight API)
        -- BUG-004: UnitPower can return secret values that pass nil checks but fail arithmetic
        local perc = 0
        local calcOk, calcResult = pcall(function()
            if power and maxPower and maxPower > 0 then
                return floor(power / maxPower * 100)
            end
            return 0
        end)
        if calcOk and calcResult then
            perc = calcResult
        end

        self.powerName = powerName
        self.powerTooltip = powerTooltip
        self.powerValue = power
        self.powerMaxValue = maxPower
        self.powerPercent = perc

        -- StatusBar handles secret values natively in SetMinMaxValues/SetValue
        self:SetMinMaxValues(barInfo.minPower or 0, maxPower or 0)
        self:SetValue(power or 0)

        -- Update text (perc is guaranteed safe from pcall)
        if powerName then
            self.text:SetText(string.format("%s: %d%%", powerName, perc))
        else
            self.text:SetText(string.format("%d%%", perc))
        end

        self:Show()
    else
        self.powerName = nil
        self.powerTooltip = nil
        self.powerValue = nil
        self.powerMaxValue = nil
        self.powerPercent = nil

        self:Hide()
    end
end

local function OnEvent(self, event, arg1, arg2)
    if event == "UNIT_POWER_UPDATE" then
        if arg1 == "player" and arg2 == "ALTERNATE" then
            UpdateBar(self)
        end
    elseif event == "UNIT_POWER_BAR_SHOW" or event == "UNIT_POWER_BAR_HIDE" then
        if arg1 == "player" then
            UpdateBar(self)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateBar(self)
    end
end

---------------------------------------------------------------------------
-- BAR CREATION
---------------------------------------------------------------------------

local function CreateH3z0UIAltPowerBar()
    -- Get skin colors
    local H3z0UI = _G.H3z0UI
    local sr, sg, sb, sa = 0.2, 1.0, 0.6, 1
    local bgr, bgg, bgb, bga = 0.05, 0.05, 0.05, 0.95

    if H3z0UI and H3z0UI.GetSkinColor then
        sr, sg, sb, sa = H3z0UI:GetSkinColor()
    end
    if H3z0UI and H3z0UI.GetSkinBgColor then
        bgr, bgg, bgb, bga = H3z0UI:GetSkinBgColor()
    end

    -- Create the status bar
    local bar = CreateFrame("StatusBar", "H3z0UI_AltPowerBar", UIParent)
    bar:SetSize(BAR_WIDTH, BAR_HEIGHT)

    -- Load saved position or use default
    local pos = GetBarPosition()
    if pos and pos.point then
        bar:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        bar:SetPoint("TOP", UIParent, "TOP", 0, -100)
    end

    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(sr, sg, sb)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
    bar:Hide()

    -- Make movable (controlled by mover overlay)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)

    -- Create backdrop
    bar.backdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.backdrop:SetPoint("TOPLEFT", -2, 2)
    bar.backdrop:SetPoint("BOTTOMRIGHT", 2, -2)
    local safeLevel = bar:GetFrameLevel() - 1
    if safeLevel < 0 then
        safeLevel = 0
    end
    bar.backdrop:SetFrameLevel(safeLevel)
    local px = GetPixelSize(bar.backdrop, 1)
    bar.backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = px,
        insets = { left = px, right = px, top = px, bottom = px }
    })
    bar.backdrop:SetBackdropColor(bgr, bgg, bgb, bga)
    bar.backdrop:SetBackdropBorderColor(sr, sg, sb, sa)

    -- Create text
    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetPoint("CENTER", bar, "CENTER")
    bar.text:SetFont(STANDARD_TEXT_FONT, 11, FONT_FLAGS)
    bar.text:SetTextColor(1, 1, 1)
    bar.text:SetJustifyH("CENTER")

    -- Store colors for refresh and mark as skinned
    bar.h3z0uiSkinColor = { sr, sg, sb, sa }
    bar.h3z0uiBgColor = { bgr, bgg, bgb, bga }
    bar.h3z0uiSkinned = true

    -- Tooltip support
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", OnEnter)
    bar:SetScript("OnLeave", OnLeave)

    -- Event handling
    bar:RegisterEvent("UNIT_POWER_UPDATE")
    bar:RegisterEvent("UNIT_POWER_BAR_SHOW")
    bar:RegisterEvent("UNIT_POWER_BAR_HIDE")
    bar:RegisterEvent("PLAYER_ENTERING_WORLD")
    bar:SetScript("OnEvent", OnEvent)

    return bar
end

---------------------------------------------------------------------------
-- BLIZZARD BAR HIDING
---------------------------------------------------------------------------

local blizzardBarHooked = false

local function HideBlizzardBar()
    local bar = _G.PlayerPowerBarAlt
    if bar then
        bar:UnregisterAllEvents()
        bar:Hide()
        bar:SetAlpha(0)
    end

    -- Hook UnitPowerBarAlt_SetUp to catch bar creation/setup
    -- IMPORTANT: Skip during combat to avoid taint - let Blizzard's bar show if needed
    if not blizzardBarHooked and _G.UnitPowerBarAlt_SetUp then
        hooksecurefunc("UnitPowerBarAlt_SetUp", function(self)
            if InCombatLockdown() then return end  -- Avoid taint during combat
            if self == _G.PlayerPowerBarAlt and isEnabled then
                self:UnregisterAllEvents()
                self:Hide()
                self:SetAlpha(0)
            end
        end)
        blizzardBarHooked = true
    end
end

---------------------------------------------------------------------------
-- REFRESH COLORS
---------------------------------------------------------------------------

local function RefreshPowerBarAltColors()
    if not H3z0UIAltPowerBar then return end

    local H3z0UI = _G.H3z0UI
    local sr, sg, sb, sa = 0.2, 1.0, 0.6, 1
    local bgr, bgg, bgb, bga = 0.05, 0.05, 0.05, 0.95

    if H3z0UI and H3z0UI.GetSkinColor then
        sr, sg, sb, sa = H3z0UI:GetSkinColor()
    end
    if H3z0UI and H3z0UI.GetSkinBgColor then
        bgr, bgg, bgb, bga = H3z0UI:GetSkinBgColor()
    end

    H3z0UIAltPowerBar:SetStatusBarColor(sr, sg, sb)
    H3z0UIAltPowerBar.backdrop:SetBackdropColor(bgr, bgg, bgb, bga)
    H3z0UIAltPowerBar.backdrop:SetBackdropBorderColor(sr, sg, sb, sa)

    H3z0UIAltPowerBar.h3z0uiSkinColor = { sr, sg, sb, sa }
    H3z0UIAltPowerBar.h3z0uiBgColor = { bgr, bgg, bgb, bga }

    -- Update mover colors if it exists
    if powerBarMover then
        powerBarMover:SetBackdropColor(sr, sg, sb, 0.3)
        powerBarMover:SetBackdropBorderColor(sr, sg, sb, 1)
    end
end

_G.H3z0UI_RefreshPowerBarAltColors = RefreshPowerBarAltColors

---------------------------------------------------------------------------
-- MOVER OVERLAY
---------------------------------------------------------------------------

local function CreateMover()
    if powerBarMover then return end
    if not H3z0UIAltPowerBar then return end

    -- Get skin colors for mover
    local H3z0UI = _G.H3z0UI
    local sr, sg, sb, sa = 0.2, 1.0, 0.6, 1
    if H3z0UI and H3z0UI.GetSkinColor then
        sr, sg, sb, sa = H3z0UI:GetSkinColor()
    end

    -- Create mover overlay
    powerBarMover = CreateFrame("Frame", "H3z0UI_AltPowerBarMover", UIParent, "BackdropTemplate")
    powerBarMover:SetSize(BAR_WIDTH + 4, BAR_HEIGHT + 4)
    powerBarMover:SetPoint("CENTER", H3z0UIAltPowerBar, "CENTER")
    local mvPx = GetPixelSize(powerBarMover, 1)
    powerBarMover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = mvPx,
    })
    powerBarMover:SetBackdropColor(sr, sg, sb, 0.3)
    powerBarMover:SetBackdropBorderColor(sr, sg, sb, 1)
    powerBarMover:EnableMouse(true)
    powerBarMover:SetMovable(true)
    powerBarMover:RegisterForDrag("LeftButton")
    powerBarMover:SetFrameStrata("FULLSCREEN_DIALOG")
    powerBarMover:Hide()

    -- Mover label
    powerBarMover.text = powerBarMover:CreateFontString(nil, "OVERLAY")
    powerBarMover.text:SetPoint("CENTER")
    powerBarMover.text:SetFont(STANDARD_TEXT_FONT, 10, FONT_FLAGS)
    powerBarMover.text:SetText("Encounter Power Bar")
    powerBarMover.text:SetTextColor(1, 1, 1)

    -- Drag handlers
    powerBarMover:SetScript("OnDragStart", function(self)
        H3z0UIAltPowerBar:StartMoving()
    end)

    powerBarMover:SetScript("OnDragStop", function(self)
        H3z0UIAltPowerBar:StopMovingOrSizing()
        -- Save position (snapped to pixel grid)
        local core = GetCore()
        local point, _, relPoint, x, y = core:SnapFramePosition(H3z0UIAltPowerBar)
        if point then
            SaveBarPosition(point, relPoint, x, y)
        end
        -- Re-anchor mover to bar
        self:ClearAllPoints()
        self:SetPoint("CENTER", H3z0UIAltPowerBar, "CENTER")
    end)
end

---------------------------------------------------------------------------
-- MOVER TOGGLE (called from options)
---------------------------------------------------------------------------

local function ShowMover()
    CreateMover()
    if powerBarMover then
        powerBarMover:Show()
        -- Show the bar too so user can see what they're positioning
        if H3z0UIAltPowerBar then
            H3z0UIAltPowerBar:Show()
            -- Show placeholder if no active power bar
            if not H3z0UIAltPowerBar.powerName then
                H3z0UIAltPowerBar.text:SetText("Encounter Power Bar")
                H3z0UIAltPowerBar:SetMinMaxValues(0, 100)
                H3z0UIAltPowerBar:SetValue(50)
            end
        end
    end
end

local function HideMover()
    if powerBarMover then
        powerBarMover:Hide()
    end
    -- Re-update bar visibility based on actual power state
    if H3z0UIAltPowerBar then
        UpdateBar(H3z0UIAltPowerBar)
    end
end

local function ToggleMover()
    if powerBarMover and powerBarMover:IsShown() then
        HideMover()
    else
        ShowMover()
    end
end

-- Expose toggle function globally
_G.H3z0UI_TogglePowerBarAltMover = ToggleMover

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

local function Initialize()
    local core = GetCore()
    local settings = core and core.db and core.db.profile and core.db.profile.general

    if not settings or not settings.skinPowerBarAlt then return end
    if isEnabled then return end

    -- Hide Blizzard's bar
    HideBlizzardBar()

    -- Create our bar
    H3z0UIAltPowerBar = CreateH3z0UIAltPowerBar()

    -- Initial update
    UpdateBar(H3z0UIAltPowerBar)

    isEnabled = true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    -- Delay slightly to ensure H3z0UI is loaded
    C_Timer.After(0.1, Initialize)
end)
