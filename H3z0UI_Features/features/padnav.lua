---------------------------------------------------------------------------
-- H3z0 UI - Controller navigation for our own windows
-- With a game controller on, the D-pad moves a highlight through the buttons, switches,
-- sliders and lists of:
--   the options window, its drop-down lists and popups (always, while they are open)
--   the bag and bank windows (after the first D-pad press; B steps back out)
-- A = click   B = back / close   X = pick up (bags)   Left / Right on a slider = change it
--
-- Safe by design:
--   * Only the D-pad, A, B and X are taken, and only while one of these windows is open.
--     Everything else (movement, jump, camera) is untouched.
--   * Nothing happens without a controller (C_GamePad.IsEnabled) or with ConsolePort loaded.
--   * In combat only unprotected things are clicked.
--   * Off switch: Handheld page -> Use the Controller in H3z0 UI Windows.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local PadNav = {}
ns.PadNav = PadNav

local DEFAULTS = { enabled = true, bags = true }
local function Get(key)
    local s = Helpers and Helpers.GetModuleSettings and Helpers.GetModuleSettings("padNav", DEFAULTS)
    if s and s[key] ~= nil then return s[key] end
    return DEFAULTS[key]
end

local function PadOn()
    if Get("enabled") == false then return false end
    if type(_G.ConsolePort) == "table" then return false end
    return _G.C_GamePad and _G.C_GamePad.IsEnabled and _G.C_GamePad.IsEnabled() and true or false
end

---------------------------------------------------------------------------
-- Which window is on top right now
---------------------------------------------------------------------------
local function Shown(f) return f and f.IsShown and f:IsShown() end

local function TopScope()
    local GUI = _G.H3z0UI and _G.H3z0UI.GUI
    local menu = GUI and GUI.sharedDropdownMenu
    if Shown(menu) then return menu, "popup" end
    for _, name in ipairs({ "H3z0UI_ConfirmDialog", "H3z0UI_ExportPopup" }) do
        local f = _G[name]
        if Shown(f) then return f, "popup" end
    end
    local opt = _G.H3z0UI_Options
    if Shown(opt) then return opt, "window" end
    if Get("bags") ~= false then
        for _, name in ipairs({ "H3z0UI_BankWindow", "H3z0UI_BagWindow" }) do
            local f = _G[name]
            if Shown(f) then return f, "bags" end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- The highlight
---------------------------------------------------------------------------
local cursor = CreateFrame("Frame", nil, UIParent)
cursor:SetFrameStrata("TOOLTIP")
cursor:SetFrameLevel(9000)
cursor:EnableMouse(false)
cursor:Hide()
local edges = {}
for i = 1, 4 do
    local t = cursor:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0.2, 0.8, 1, 0.95)
    edges[i] = t
end
edges[1]:SetPoint("TOPLEFT", cursor, "TOPLEFT");     edges[1]:SetPoint("TOPRIGHT", cursor, "TOPRIGHT");       edges[1]:SetHeight(2)
edges[2]:SetPoint("BOTTOMLEFT", cursor, "BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT", cursor, "BOTTOMRIGHT"); edges[2]:SetHeight(2)
edges[3]:SetPoint("TOPLEFT", cursor, "TOPLEFT");     edges[3]:SetPoint("BOTTOMLEFT", cursor, "BOTTOMLEFT");   edges[3]:SetWidth(2)
edges[4]:SetPoint("TOPRIGHT", cursor, "TOPRIGHT");   edges[4]:SetPoint("BOTTOMRIGHT", cursor, "BOTTOMRIGHT"); edges[4]:SetWidth(2)

local focus, focusScope
local memory = setmetatable({}, { __mode = "k" })   -- last selection per window
local engaged = false        -- bags only: the D-pad has been used on this window

local function LeaveFocus()
    if focus then
        local onLeave = focus.GetScript and focus:GetScript("OnLeave")
        if onLeave then pcall(onLeave, focus) end
    end
end

local function Clear()
    LeaveFocus()
    focus, focusScope = nil, nil
    cursor:Hide()
    engaged = false
end

---------------------------------------------------------------------------
-- Finding things to select
---------------------------------------------------------------------------
local NAV_TYPES = { Button = true, CheckButton = true, Slider = true, EditBox = true, ItemButton = true }

local function Collect(root, out, depth)
    if depth > 30 then return end
    local kids = { root:GetChildren() }
    for i = 1, #kids do
        local c = kids[i]
        if c ~= cursor and not (c.IsForbidden and c:IsForbidden()) and c:IsShown() then
            local okType, t = pcall(c.GetObjectType, c)
            if okType and NAV_TYPES[t] and c:IsMouseEnabled() and c:IsVisible()
                and (c:GetWidth() or 0) > 6 and (c:GetHeight() or 0) > 6
                and (c:GetEffectiveAlpha() or 1) > 0.05
                and not (c.IsEnabled and t ~= "Slider" and t ~= "EditBox" and c:IsEnabled() == false) then
                out[#out + 1] = c
            end
            Collect(c, out, depth + 1)
        end
    end
end

local function Center(f)
    local x, y = f:GetCenter()
    if not x then return nil end
    local s = f:GetEffectiveScale() or 1
    return x * s, y * s
end

local function Candidates(scope)
    local out = {}
    Collect(scope, out, 0)
    return out
end

local function Nearest(list, from, dir)
    local fx, fy = Center(from)
    if not fx then return nil end
    local best, bestScore
    for i = 1, #list do
        local c = list[i]
        if c ~= from then
            local cx, cy = Center(c)
            if cx then
                local dx, dy = cx - fx, cy - fy
                local primary, perp
                if dir == "UP" and dy > 4 then primary, perp = dy, math.abs(dx)
                elseif dir == "DOWN" and dy < -4 then primary, perp = -dy, math.abs(dx)
                elseif dir == "LEFT" and dx < -4 then primary, perp = -dx, math.abs(dy)
                elseif dir == "RIGHT" and dx > 4 then primary, perp = dx, math.abs(dy) end
                if primary then
                    local score = primary + perp * 2.5
                    if not bestScore or score < bestScore then best, bestScore = c, score end
                end
            end
        end
    end
    return best
end

local function FirstOf(list)
    -- top-left-most
    local best, bx, by
    for i = 1, #list do
        local x, y = Center(list[i])
        if x and (not best or y > by + 6 or (math.abs(y - by) <= 6 and x < bx)) then best, bx, by = list[i], x, y end
    end
    return best
end

---------------------------------------------------------------------------
-- Showing the focus (and scrolling it into view)
---------------------------------------------------------------------------
local function ScrollIntoView(w)
    local p = w:GetParent()
    local guard = 0
    while p and guard < 20 do
        guard = guard + 1
        if p.GetObjectType and p:GetObjectType() == "ScrollFrame" and p.GetVerticalScroll then
            local top, bottom = w:GetTop(), w:GetBottom()
            local sTop, sBottom = p:GetTop(), p:GetBottom()
            if top and bottom and sTop and sBottom then
                local cur = p:GetVerticalScroll() or 0
                local range = p:GetVerticalScrollRange() or 0
                local s = (w:GetEffectiveScale() or 1) / (p:GetEffectiveScale() or 1)
                local new
                if top * s > sTop then new = cur - (top * s - sTop) - 12
                elseif bottom * s < sBottom then new = cur + (sBottom - bottom * s) + 12 end
                if new then p:SetVerticalScroll(math.max(0, math.min(range, new))) end
            end
            return
        end
        p = p:GetParent()
    end
end

local function SetFocus(w, scope)
    if w == focus then return end
    LeaveFocus()
    focus, focusScope = w, scope
    if not w then cursor:Hide(); return end
    memory[scope] = w
    ScrollIntoView(w)
    cursor:ClearAllPoints()
    cursor:SetPoint("TOPLEFT", w, "TOPLEFT", -3, 3)
    cursor:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", 3, -3)
    cursor:Show()
    -- the same tooltip / hover look the mouse would give
    local onEnter = w.GetScript and w:GetScript("OnEnter")
    if onEnter then pcall(onEnter, w) end
end

local function FocusValid(scope)
    return focus and focusScope == scope and focus:IsVisible() and focus:GetCenter() ~= nil
end

---------------------------------------------------------------------------
-- Doing things
---------------------------------------------------------------------------
local function SafeClick(w, mouseButton)
    if InCombatLockdown() and w.IsProtected and w:IsProtected() then return end
    local t = w:GetObjectType()
    if t == "EditBox" then
        if w.SetFocus then w:SetFocus() end
    elseif t == "Slider" then
        return
    elseif w.Click then
        pcall(w.Click, w, mouseButton or "LeftButton")
    end
end

local function AdjustSlider(s, sign)
    local lo, hi = s:GetMinMaxValues()
    local step = s:GetValueStep()
    if not step or step <= 0 then step = ((hi or 1) - (lo or 0)) / 50 end
    local v = (s:GetValue() or 0) + sign * step
    if lo and v < lo then v = lo end
    if hi and v > hi then v = hi end
    s:SetValue(v)
end

local function IsItemButton(w)
    return w.GetBagID ~= nil or (w.GetObjectType and w:GetObjectType() == "ItemButton")
end

local function CloseScope(scope, kind)
    if kind == "popup" then
        -- a drop-down list just closes; a popup goes through its own Cancel if it has one
        local cancel = scope.cancelButton or scope.CancelButton or scope.noButton
        if cancel and cancel.Click and cancel:IsShown() then pcall(cancel.Click, cancel) else scope:Hide() end
    else
        scope:Hide()
    end
end

---------------------------------------------------------------------------
-- Button handling; returns true when the press was used
---------------------------------------------------------------------------
local DIRS = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT" }

local last = { b = nil, t = 0 }
function PadNav.OnPad(button)
    if not PadOn() then return false end
    local scope, kind = TopScope()
    if not scope then return false end

    -- a drop-down or popup opened on top of the window: the focus belongs to it now
    if focusScope and focusScope ~= scope then Clear() end

    local dir = DIRS[button]
    if kind == "bags" and not engaged then
        if not dir then return false end        -- A / B / X keep their normal game meaning
        engaged = true
    end

    local now = GetTime()
    if last.b == button and now - last.t < 0.04 then return true end
    last.b, last.t = button, now

    if not FocusValid(scope) then
        local first = kind ~= "popup" and memory[scope] or nil
        if not (first and first:IsVisible() and first:GetCenter()) then
            first = FirstOf(Candidates(scope))
        end
        if not first then return false end
        SetFocus(first, scope)
        if dir then return true end
    end

    if dir then
        -- left / right on a slider changes it
        if focus:GetObjectType() == "Slider" and (dir == "LEFT" or dir == "RIGHT") then
            AdjustSlider(focus, dir == "RIGHT" and 1 or -1)
            return true
        end
        local target = Nearest(Candidates(scope), focus, dir)
        if target then SetFocus(target, scope) end
        return true
    elseif button == "PAD1" then
        if kind == "bags" and IsItemButton(focus) then SafeClick(focus, "RightButton") else SafeClick(focus) end
        return true
    elseif button == "PAD3" then
        if kind == "bags" and IsItemButton(focus) then SafeClick(focus, "LeftButton") return true end
        return false
    elseif button == "PAD2" then
        if focus:GetObjectType() == "EditBox" and focus:HasFocus() then focus:ClearFocus(); return true end
        if kind == "bags" then Clear(); return true end   -- first B steps out, the next B is normal
        CloseScope(scope, kind)
        Clear()
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- The listener: only listens while one of our windows is up
---------------------------------------------------------------------------
local driver = CreateFrame("Frame", "H3z0UI_PadNav", UIParent)
driver:SetSize(1, 1)
driver:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
driver:Show()
local listening = false
local function Listen(on)
    if on == listening then return end
    if not driver.EnableGamePadButton then return end
    listening = on
    driver:EnableGamePadButton(on)
end

driver:SetScript("OnGamePadButtonDown", function(self, button)
    local handled = PadNav.OnPad(button)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
end)

local elapsedSince = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.2 then return end
    elapsedSince = 0
    local scope = PadOn() and TopScope()
    Listen(scope and true or false)
    if not scope then
        if focus or cursor:IsShown() then Clear() end
    elseif focusScope and focusScope ~= scope then
        Clear()
    elseif focus and not focus:IsVisible() then
        Clear()
    end
end)

function PadNav.IsActive() return listening end
