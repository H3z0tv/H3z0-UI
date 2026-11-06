local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Character + Inspect (and other side-by-side Blizzard windows): the H3z0
-- skins make these windows wider than Blizzard expects, so when two are open
-- together Blizzard puts them on top of each other. After Blizzard places
-- its windows, the right one is moved so the two sit next to each other.
---------------------------------------------------------------------------

local GAP = 8
local PAIRS = {
    { "InspectFrame", "CharacterFrame" },
}

-- left / top / right of a frame in UIParent units, and its scale factor
-- (the skins draw big background panels as child frames: those count too)
local function Box(f)
    local l, t, r = f:GetLeft(), f:GetTop(), f:GetRight()
    if not (l and t and r) then return nil end
    local k = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local box = { f = f, l = l * k, t = t * k, r = r * k, k = k }
    for _, c in ipairs({ f:GetChildren() }) do
        if c and c.IsShown and c:IsShown() and (c:GetWidth() or 0) >= 100 and (c:GetHeight() or 0) >= 100 then
            local cl, cr = c:GetLeft(), c:GetRight()
            if cl and cr then
                local ck = (c:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
                box.l = math.min(box.l, cl * ck)
                box.r = math.max(box.r, cr * ck)
            end
        end
    end
    -- the frame's own left edge, to place it by its TOPLEFT
    box.fl = l * k
    return box
end

-- move so the visual left edge lands at `left`
local function MoveTo(box, left)
    local f = box.f
    local frameLeft = left + (box.fl - box.l)
    pcall(function()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", frameLeft / box.k, box.t / box.k)
    end)
end

local busy = false
local function Spread()
    if busy or InCombatLockdown() then return end
    busy = true
    for _, pair in ipairs(PAIRS) do
        local a, b = _G[pair[1]], _G[pair[2]]
        if a and b and a:IsShown() and b:IsShown() then
            local A, B = Box(a), Box(b)
            if A and B then
                local L, R = A, B
                if B.l < A.l then L, R = B, A end
                if R.l < L.r + GAP then
                    local screenW = UIParent:GetWidth()
                    local rw, lw = R.r - R.l, L.r - L.l
                    local newRL = L.r + GAP
                    if newRL + rw > screenW then
                        -- no room on the right: keep the right one at the edge, move the left one over
                        newRL = math.max(0, screenW - rw)
                        MoveTo(L, math.max(0, newRL - GAP - lw))
                    end
                    MoveTo(R, newRL)
                end
            end
        end
    end
    busy = false
end

local function Queue()
    C_Timer.After(0, Spread)
    C_Timer.After(0.15, Spread)
end

if type(_G.UpdateUIPanelPositions) == "function" then
    hooksecurefunc("UpdateUIPanelPositions", Queue)
end
if type(_G.ShowUIPanel) == "function" then
    hooksecurefunc("ShowUIPanel", Queue)
end

-- InspectFrame is load-on-demand: hook its OnShow once it exists
local hooked = {}
local function HookShows()
    for _, pair in ipairs(PAIRS) do
        for _, name in ipairs(pair) do
            local f = _G[name]
            if f and not hooked[f] then
                hooked[f] = true
                f:HookScript("OnShow", Queue)
            end
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function() HookShows() end)
