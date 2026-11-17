local ADDON_NAME, ns = ...

--------------------------------------------------------------------------------
--  modules/layout/layoutmode_intro.lua -- the opening animation of Layout Mode.
--
--  WHAT YOU SEE (about 1.6 seconds)
--    * the H3z0 skull scales in from large, turns a little and settles, with a
--      light shine running across it (a slice of the logo itself, so it never leaves the skull shape),
--      then fades away
--    * the dim layer and the grid fade in; the grid flickers while it does
--    * the movers fade in a moment later
--    * the EDIT MODE tab slides in from the screen edge
--
--  HOW IT WORKS (read this part if you are learning)
--    One timer (`elapsed`) drives every effect. Each effect is a function of
--    that number, so they all stay in step. There are no AnimationGroups.
--    Easing curves turn a straight 0..1 progress into a smooth one:
--      EaseInOutCubic  slow start and slow end   (scale, slide)
--      EaseOutQuint    fast start, very soft stop (the turn settles gently)
--
--  SAFETY (it is only cosmetic, it must never change your layout)
--    * It runs AFTER the normal Open() finished. Layout Mode itself is not
--      touched or changed.
--    * It remembers what it changes (alphas, the tab's position) and puts the
--      exact values back when it ends, is interrupted (Layout Mode closed, combat)
--      or fails. Any error stops the intro and restores everything.
--    * Turn it off with /h3z0ui layoutintro (saved per profile).
--------------------------------------------------------------------------------

local LM = ns.H3z0UI_LayoutMode
local UI = ns.H3z0UI_LayoutMode_UI
if type(LM) ~= "table" or type(UI) ~= "table" then return end

local type, pairs, pcall, tostring = type, pairs, pcall, tostring
local min, max, sin = math.min, math.max, math.sin

local Intro = {}
ns.H3z0UI_LayoutIntro = Intro

local LOGO_PATH = "Interface\\AddOns\\H3z0UI\\assets\\h3z0ui_logo_bg.png"
local LOGO_W, LOGO_H = 340, 170     -- the logo picture is 2:1
local START_SCALE = 1.7
local START_TURN = 0.45             -- radians (about 26 degrees), settles to 0
local MAX_DT = 0.05                 -- one slow frame must not skip the animation

-- timeline, in seconds
local T_TOTAL      = 1.75
local T_LOGO_IN    = 0.55
local T_LOGO_OUT   = 0.45
local T_LOGO_OUTAT = 1.25
local T_SWEEP_AT   = 0.70
local T_SWEEP      = 0.50
local T_GRID       = 0.75
local T_MOVER_AT   = 0.50
local T_MOVER      = 0.65
local T_TAB_AT     = 0.55
local T_TAB        = 0.50

--------------------------------------------------------------------------------
--  Easing
--------------------------------------------------------------------------------
local function Clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function EaseInOutCubic(t)
    if t < 0.5 then return 4 * t * t * t end
    local f = 2 * t - 2
    return 0.5 * f * f * f + 1
end

local function EaseOutQuint(t)
    local inv = 1 - t
    return 1 - inv * inv * inv * inv * inv
end

Intro._EaseInOutCubic, Intro._EaseOutQuint = EaseInOutCubic, EaseOutQuint

--------------------------------------------------------------------------------
--  Setting (per profile: profile.layoutMode.intro, default on)
--------------------------------------------------------------------------------
local function GetDB()
    local Helpers = ns.Helpers
    local core = Helpers and Helpers.GetCore and Helpers.GetCore()
    local profile = core and core.db and core.db.profile
    if type(profile) ~= "table" then return nil end
    if type(profile.layoutMode) ~= "table" then profile.layoutMode = {} end
    return profile.layoutMode
end

function Intro:IsEnabled()
    local db = GetDB()
    return not (db and db.intro == false)
end

function Intro:SetEnabled(on)
    local db = GetDB()
    if db then db.intro = on and true or false end
end

--------------------------------------------------------------------------------
--  Frames (built once, the first time the intro plays)
--------------------------------------------------------------------------------
function Intro:_Build()
    if self._logoFrame then return self._logoFrame end

    local lf = CreateFrame("Frame", "H3z0UI_LayoutIntro", UIParent)
    lf:SetFrameStrata("TOOLTIP")
    lf:SetFrameLevel(150)
    lf:SetSize(LOGO_W, LOGO_H)
    lf:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    lf:EnableMouse(false)     -- never blocks a click
    lf:Hide()

    local logo = lf:CreateTexture(nil, "ARTWORK")
    logo:SetAllPoints()
    logo:SetTexture(LOGO_PATH)
    if logo.SetSnapToPixelGrid then logo:SetSnapToPixelGrid(false) end
    if logo.SetTexelSnappingBias then logo:SetTexelSnappingBias(0) end
    self._logo = logo

    -- The shine is a thin vertical slice of the logo picture itself, drawn again on top with
    -- additive blending. It uses the logo's own pixels, so it can only ever light the skull
    -- shape (nothing shows over the transparent parts) and needs no mask.
    local sweep = lf:CreateTexture(nil, "OVERLAY")
    sweep:SetTexture(LOGO_PATH)
    sweep:SetBlendMode("ADD")
    sweep:Hide()
    self._sweep = sweep

    self._logoFrame = lf
    return lf
end

--------------------------------------------------------------------------------
--  Restore everything the intro touched
--------------------------------------------------------------------------------
function Intro:Cancel()
    local lf = self._logoFrame
    if lf then
        lf:SetScript("OnUpdate", nil)
        lf:Hide()
    end
    if self._sweep then self._sweep:Hide() end

    if self._active then
        self._active = false

        for handle, alpha in pairs(self._saved or {}) do
            pcall(handle.SetAlpha, handle, alpha)
        end

        local overlay = UI._overlay
        if overlay then pcall(overlay.SetAlpha, overlay, 1) end
        local grid = UI._gridFrame
        if grid then pcall(grid.SetAlpha, grid, 1) end

        local tb = self._tab
        if tb then
            pcall(function()
                tb.frame:ClearAllPoints()
                tb.frame:SetPoint(tb.point, tb.rel, tb.relPoint, tb.x, tb.y)
            end)
        end
    end

    self._saved, self._tab, self._elapsed = nil, nil, nil
end

--------------------------------------------------------------------------------
--  One animation step. `dt` is the time since the last frame.
--------------------------------------------------------------------------------
function Intro:Step(dt)
    if not self._active then return end
    -- Layout Mode ended or was suspended (closed, combat): stop and restore.
    if not LM.isActive or LM._combatSuspended then
        self:Cancel()
        return
    end

    local e = self._elapsed + min(dt, MAX_DT)
    self._elapsed = e

    -- dim layer
    local overlay = UI._overlay
    if overlay then overlay:SetAlpha(Clamp01(e / T_GRID)) end

    -- grid: fades in with a flicker made of three sine waves
    local grid = UI._gridFrame
    if grid and grid:IsShown() then
        local p = Clamp01(e / T_GRID)
        local flicker = 0
        if p < 0.9 then
            local k = (1 - p) * 0.6
            flicker = (sin(e * 37.3) * 0.4 + sin(e * 13.7) * 0.35 + sin(e * 71.1) * 0.25) * k
        end
        grid:SetAlpha(Clamp01(p + flicker))
    end

    -- movers: hidden first, then fade up to the alpha each one had
    local f = Clamp01((e - T_MOVER_AT) / T_MOVER)
    local saved = self._saved
    for _, handle in pairs(LM._handles or {}) do
        local original = saved[handle]
        if original == nil then
            original = handle:GetAlpha() or 1
            saved[handle] = original
        end
        handle:SetAlpha(original * f)
    end

    -- the tab slides in from the edge it sits on
    local tb = self._tab
    if tb then
        local s = EaseInOutCubic(Clamp01((e - T_TAB_AT) / T_TAB))
        tb.frame:ClearAllPoints()
        tb.frame:SetPoint(tb.point, tb.rel, tb.relPoint, tb.x + tb.dir * tb.width * (1 - s), tb.y)
    end

    -- the logo
    local logo, lf = self._logo, self._logoFrame
    local scale, alpha, turn
    if e < T_LOGO_OUTAT then
        local s = EaseInOutCubic(Clamp01(e / T_LOGO_IN))
        scale = START_SCALE + (1 - START_SCALE) * s
        alpha = Clamp01(e / (T_LOGO_IN * 0.7))
        turn = START_TURN * (1 - EaseOutQuint(Clamp01(e / (T_LOGO_IN + 0.35))))
    else
        local o = Clamp01((e - T_LOGO_OUTAT) / T_LOGO_OUT)
        scale = 1 + 0.12 * EaseInOutCubic(o)
        alpha = 1 - o
        turn = 0
    end
    lf:SetScale(max(0.01, scale))
    lf:SetAlpha(alpha)
    logo:SetRotation(turn)

    -- the shine: a slice of the logo that moves from left to right (starts after the turn has settled)
    local sweep = self._sweep
    if sweep then
        local st = Clamp01((e - T_SWEEP_AT) / T_SWEEP)
        if st > 0 and st < 1 then
            local c = -0.1 + 1.2 * EaseInOutCubic(st)          -- centre of the slice, 0..1 across the logo
            local half = 0.09
            local left, right = max(0, c - half), min(1, c + half)
            if right > left then
                sweep:ClearAllPoints()
                sweep:SetPoint("TOPLEFT", lf, "TOPLEFT", left * LOGO_W, 0)
                sweep:SetSize((right - left) * LOGO_W, LOGO_H)
                sweep:SetTexCoord(left, right, 0, 1)
                sweep:SetVertexColor(1, 1, 1, 0.55 * sin(st * 3.14159265))
                sweep:Show()
            else
                sweep:Hide()
            end
        else
            sweep:Hide()
        end
    end

    if e >= T_TOTAL then self:Cancel() end
end

--------------------------------------------------------------------------------
--  Start
--------------------------------------------------------------------------------
function Intro:Play()
    self:Cancel()   -- never two at once
    local lf = self:_Build()

    self._active = true
    self._elapsed = 0
    self._saved = {}

    -- Remember where the tab is, so it can slide in and land exactly there.
    self._tab = nil
    local tab = UI._toolbar
    if tab and tab:IsShown() and tab:GetNumPoints() == 1 then
        local point, rel, relPoint, x, y = tab:GetPoint(1)
        if point then
            local onLeft = point == "LEFT" or point == "TOPLEFT" or point == "BOTTOMLEFT"
            self._tab = {
                frame = tab, point = point, rel = rel, relPoint = relPoint,
                x = x or 0, y = y or 0,
                dir = onLeft and -1 or 1,
                width = (tab:GetWidth() or 26) + 4,
            }
        end
    end

    lf:Show()
    lf:SetScript("OnUpdate", function(_, dt)
        local ok, err = pcall(Intro.Step, Intro, dt)
        if not ok then
            Intro.lastError = tostring(err)
            Intro:Cancel()
        end
    end)

    -- First frame right now, so nothing flashes at full strength before the
    -- first OnUpdate.
    local ok, err = pcall(self.Step, self, 0)
    if not ok then
        self.lastError = tostring(err)
        self:Cancel()
    end
end

--------------------------------------------------------------------------------
--  Hook: play after the normal Open() has finished
--------------------------------------------------------------------------------
local origOpen = LM.Open
if type(origOpen) == "function" then
    function LM:Open(...)
        local wasActive = self.isActive
        local result = origOpen(self, ...)
        if not wasActive and self.isActive and Intro:IsEnabled() then
            local ok, err = pcall(Intro.Play, Intro)
            if not ok then
                Intro.lastError = tostring(err)
                Intro:Cancel()
            end
        end
        return result
    end
end

--------------------------------------------------------------------------------
--  /h3z0ui layoutintro
--------------------------------------------------------------------------------
_G.H3z0UI_LayoutIntroToggle = function(say)
    say = say or print
    local on = not Intro:IsEnabled()
    Intro:SetEnabled(on)
    say("Layout Mode opening animation is now " .. (on and "ON" or "OFF") .. ".")
    if Intro.lastError then say("Last intro error: " .. Intro.lastError) end
end