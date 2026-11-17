--[[
    H3z0 UI - Unit Frame Visibility

    Lets a unit frame (player, target, target of target, pet, focus) fade out
    while you are out of combat. It comes back when you enter combat, when you
    hover it, when you have a target, or when the unit is hurt (each one is an
    option). Only the frame's alpha is changed, so it also works in combat.

    Settings live in the frame's own table: h3z0uiUnitFrames[unitKey].visibility
]]

local ADDON_NAME, ns = ...

local V = {}
ns.UnitFrameVisibility = V

local KEYS = { "player", "target", "targettarget", "pet", "focus" }
local FADE_SPEED = 4          -- alpha per second
local state = {}              -- [unitKey] = { alpha, lastActive }

local function UFDB()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    return p and p.h3z0uiUnitFrames
end

function V.GetSettings(unitKey)
    local db = UFDB()
    local u = db and db[unitKey]
    if not u then return nil end
    local s = u.visibility
    if type(s) ~= "table" then s = {}; u.visibility = s end
    if s.fadeOutOfCombat == nil then s.fadeOutOfCombat = false end
    if s.outOfCombatAlpha == nil then s.outOfCombatAlpha = 0 end
    if s.showOnMouseover == nil then s.showOnMouseover = true end
    if s.showWithTarget == nil then s.showWithTarget = false end
    if s.showWhenHurt == nil then s.showWhenHurt = false end
    if s.holdTime == nil then s.holdTime = 2 end
    return s
end

local function IsHurt(unit)
    local ok, hurt = pcall(function()
        local hp, mx = UnitHealth(unit), UnitHealthMax(unit)
        return hp < mx
    end)
    return ok and hurt or false
end

local function WantVisible(frame, unitKey, s, now)
    local st = state[unitKey]
    if UnitAffectingCombat("player") or InCombatLockdown() then
        st.lastActive = now
        return true
    end
    local H = ns.H3z0UI_UnitFrames
    if H and H.previewMode and H.previewMode[unitKey] then return true end
    if s.showOnMouseover and frame:IsMouseOver() then st.lastActive = now return true end
    if s.showWithTarget and UnitExists("target") then st.lastActive = now return true end
    if s.showWhenHurt and frame.unit and UnitExists(frame.unit) and IsHurt(frame.unit) then
        st.lastActive = now
        return true
    end
    return (now - (st.lastActive or 0)) < (s.holdTime or 0)
end

local function Step(elapsed)
    local frames = _G.H3z0UI_UnitFrames
    if not frames then return end
    local now = GetTime()
    for _, key in ipairs(KEYS) do
        local frame = frames[key]
        if frame and frame.SetAlpha then
            local st = state[key]
            if not st then st = { alpha = 1, lastActive = 0, touched = false }; state[key] = st end
            local s = V.GetSettings(key)
            if s and s.fadeOutOfCombat then
                local want = WantVisible(frame, key, s, now) and 1 or (s.outOfCombatAlpha or 0)
                local a = st.alpha
                if a < want then a = math.min(want, a + FADE_SPEED * elapsed)
                elseif a > want then a = math.max(want, a - FADE_SPEED * elapsed) end
                st.alpha = a
                st.touched = true
                frame:SetAlpha(a)
            elseif st.touched then
                -- option turned off: give the frame back
                st.touched = false
                st.alpha = 1
                frame:SetAlpha(1)
            end
        end
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed) pcall(Step, elapsed) end)

-- called by the options when a value changes
function V.Refresh() end
_G.H3z0UI_RefreshUnitFrameVisibility = V.Refresh
