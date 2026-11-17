---------------------------------------------------------------------------
-- H3z0 UI - Quest Arrow
-- An arrow on screen that points to where you have to go and says how far it
-- is (like TomTom). It follows
--   * the quest you have focused (clicked in the quest tracker / on the map), and
--   * the pin on your map (also what /way sets).
-- It hides when you arrive and when there is nothing to point at. Turn it on
-- or off on the H3z0 Features page or with /h3z0ui arrow.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetPlayerMapPosition and C_Map.GetBestMapForUnit
    and CreateVector2D) then return end

local DEFAULTS = {
    enabled = true, followQuest = true, followPin = true,
    showDistance = true, showTitle = true, autoClear = true,
    scale = 1, locked = true, x = 0, y = -170,
    nearest = true,            -- nothing focused: point at the closest tracked quest
    units = "yd",              -- "yd" or "m"
    arriveDistance = 8,        -- hide / clear when you are this close (yards)
    alpha = 1, textSize = 14,
    hideInCombat = false, showETA = true,
    color = { 1, 0.82, 0.2, 1 },          -- the arrow
    colorOnTarget = { 0.3, 1, 0.3, 1 },   -- when you walk straight at it
}
local ART = "Interface\\AddOns\\H3z0UI\\assets\\questarrow"

local function S()
    local s = Helpers and Helpers.GetModuleSettings and Helpers.GetModuleSettings("questArrow", DEFAULTS)
    return s or DEFAULTS
end

local function IsSecret(v)
    return issecretvalue ~= nil and v ~= nil and issecretvalue(v) or false
end

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

---------------------------------------------------------------------------
-- Where to go
---------------------------------------------------------------------------
-- returns uiMapID, x, y, label, kind ("pin" / "quest")
local function ResolveTarget(s)
    local ST = C_SuperTrack
    if s.followPin and ST and ST.IsSuperTrackingUserWaypoint and ST.IsSuperTrackingUserWaypoint()
        and C_Map.GetUserWaypoint then
        local wp = C_Map.GetUserWaypoint()
        if wp and wp.position and wp.uiMapID then
            return wp.uiMapID, wp.position.x, wp.position.y, "Map pin", "pin"
        end
    end
    if s.followQuest and ST and ST.GetSuperTrackedQuestID and C_QuestLog then
        local qid = ST.GetSuperTrackedQuestID()
        if qid and qid ~= 0 and not IsSecret(qid) then
            local mapID, x, y
            if C_QuestLog.GetNextWaypoint then
                local ok, m, qx, qy = pcall(C_QuestLog.GetNextWaypoint, qid)
                if ok then mapID, x, y = m, qx, qy end
            end
            if not (mapID and x and y) and C_QuestLog.GetQuestsOnMap then
                local cur = C_Map.GetBestMapForUnit("player")
                if cur and not IsSecret(cur) then
                    local ok, list = pcall(C_QuestLog.GetQuestsOnMap, cur)
                    if ok and type(list) == "table" then
                        for _, q in ipairs(list) do
                            if q.questID == qid then mapID, x, y = cur, q.x, q.y break end
                        end
                    end
                end
            end
            if mapID and x and y then
                local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)
                return mapID, x, y, title or ("Quest " .. qid), "quest"
            end
        end
    end
    if s.followQuest and s.nearest and C_QuestLog and C_QuestLog.GetNumQuestWatches
        and C_QuestLog.GetQuestIDForQuestWatchIndex and C_QuestLog.GetNextWaypoint then
        local bestD, bm, bx, by, bq
        for i = 1, (C_QuestLog.GetNumQuestWatches() or 0) do
            local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if qid then
                local ok, m, qx, qy = pcall(C_QuestLog.GetNextWaypoint, qid)
                if ok and m and qx and qy then
                    local d = ns.QuestArrowDistance and ns.QuestArrowDistance(m, qx, qy)
                    if d and (not bestD or d < bestD) then bestD, bm, bx, by, bq = d, m, qx, qy, qid end
                end
            end
        end
        if bm then
            local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(bq)
            return bm, bx, by, title or ("Quest " .. bq), "quest"
        end
    end
    return nil
end

local function WorldXY(mapID, x, y)
    local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if ok and continent and pos and pos.x then return continent, pos.x, pos.y end
end

-- yards and the bearing (clockwise from north, radians) from you to the spot
local function Compute(mapID, x, y)
    local pm = C_Map.GetBestMapForUnit("player")
    if not pm or IsSecret(pm) then return nil end
    local pp = C_Map.GetPlayerMapPosition(pm, "player")
    if not pp or not pp.GetXY then return nil end
    local px, py = pp:GetXY()
    if not px or not py or IsSecret(px) or IsSecret(py) then return nil end
    local c1, ax, ay = WorldXY(pm, px, py)
    local c2, bx, by = WorldXY(mapID, x, y)
    if not (c1 and c2) or c1 ~= c2 then return nil end
    -- world x runs north, world y runs west
    local north, east = bx - ax, ay - by
    return math.sqrt(north * north + east * east), atan2(east, north)
end

ns.QuestArrowDistance = function(mapID, x, y)
    return (Compute(mapID, x, y))
end

---------------------------------------------------------------------------
-- The arrow
---------------------------------------------------------------------------
local arrow
local moving = false   -- move mode: a sample arrow you can drag
local target = {}   -- mapID, x, y, label, kind

local function Font()
    local path = Helpers and Helpers.GetGeneralFont and Helpers.GetGeneralFont()
    return path or STANDARD_TEXT_FONT
end

local function Place()
    if not arrow then return end
    local s = S()
    arrow:SetScale(tonumber(s.scale) or 1)
    arrow:SetAlpha(tonumber(s.alpha) or 1)
    local size = tonumber(s.textSize) or 14
    arrow.dist:SetFont(Font(), size, "OUTLINE")
    arrow.title:SetFont(Font(), math.max(8, size - 3), "OUTLINE")
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", UIParent, "CENTER", s.x or 0, s.y or -170)
end

local function Create()
    if arrow then return arrow end
    arrow = CreateFrame("Button", "H3z0UI_QuestArrow", UIParent)
    arrow:SetSize(56, 56)
    arrow:SetFrameStrata("MEDIUM")
    arrow:SetClampedToScreen(true)
    arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
    arrow.tex:SetAllPoints()
    arrow.tex:SetTexture(ART)
    arrow.dist = arrow:CreateFontString(nil, "OVERLAY")
    arrow.dist:SetFont(Font(), 14, "OUTLINE")
    arrow.dist:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
    arrow.title = arrow:CreateFontString(nil, "OVERLAY")
    arrow.title:SetFont(Font(), 11, "OUTLINE")
    arrow.title:SetPoint("TOP", arrow.dist, "BOTTOM", 0, -1)
    arrow.title:SetTextColor(0.9, 0.9, 0.9)
    arrow:SetMovable(true)
    arrow:RegisterForDrag("LeftButton")
    arrow:SetScript("OnDragStart", function(self)
        if not S().locked then self:StartMoving() end
    end)
    arrow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local s = S()
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        local es, ues = self:GetEffectiveScale(), UIParent:GetEffectiveScale()
        if cx and ux and es and es > 0 then
            s.x = math.floor(cx - ux * ues / es + 0.5)
            s.y = math.floor(cy - uy * ues / es + 0.5)
        end
        Place()
    end)
    arrow:SetScript("OnEnter", function(self)
        if S().locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Quest Arrow")
        GameTooltip:AddLine("Drag to move it. Lock it again on the H3z0 Features page.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
    arrow:Hide()
    return arrow
end

local function Angle(a)   -- into -pi..pi
    local twoPi = 2 * math.pi
    a = a % twoPi
    if a > math.pi then a = a - twoPi end
    return a
end

local function UpdateArrow()
    local s = S()
    if not arrow or not arrow:IsShown() then return end
    if moving then
        arrow.tex:SetRotation(0)
        arrow.tex:SetVertexColor(0.3, 1, 0.3)
        arrow.dist:SetText("123 yd")
        arrow.dist:Show()
        return
    end
    if not target.mapID then arrow:Hide() return end
    local dist, bearing = Compute(target.mapID, target.x, target.y)
    if not dist then arrow:Hide() return end
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not facing or IsSecret(facing) then facing = 0 end
    local rot = -bearing - facing
    arrow.tex:SetRotation(rot)
    -- another colour when you walk straight at it
    local c = (math.abs(Angle(rot)) < 0.2) and (s.colorOnTarget or DEFAULTS.colorOnTarget) or (s.color or DEFAULTS.color)
    arrow.tex:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
    if s.showDistance ~= false then
        local text
        if s.units == "m" then text = string.format("%d m", dist * 0.9144 + 0.5)
        else text = string.format("%d yd", dist + 0.5) end
        if s.showETA ~= false and GetUnitSpeed then
            local speed = GetUnitSpeed("player")
            if speed and not IsSecret(speed) and speed > 1 then
                local eta = dist / speed
                if eta < 3600 then text = text .. string.format("  %d:%02d", eta / 60, eta % 60) end
            end
        end
        arrow.dist:SetText(text)
        arrow.dist:Show()
    else
        arrow.dist:Hide()
    end
end

-- what to point at, checked a couple of times a second
local function Refresh()
    local s = S()
    if moving then
        Create()
        arrow.title:SetText("Drag me to move the arrow")
        if not arrow:IsShown() then arrow:Show() end
        return
    end
    if s.enabled == false then
        if arrow then arrow:Hide() end
        return
    end
    if s.hideInCombat and InCombatLockdown() then
        if arrow then arrow:Hide() end
        return
    end
    local mapID, x, y, label, kind = ResolveTarget(s)
    if not mapID then
        target.mapID = nil
        if arrow then arrow:Hide() end
        return
    end
    Create()
    target.mapID, target.x, target.y, target.label, target.kind = mapID, x, y, label, kind
    local dist = Compute(mapID, x, y)
    if not dist then arrow:Hide() return end   -- another continent: nothing to point at
    if dist < (tonumber(s.arriveDistance) or 8) then
        -- you are there: a map pin is cleared, a quest just hides the arrow
        if kind == "pin" and s.autoClear and C_Map.ClearUserWaypoint then
            C_Map.ClearUserWaypoint()
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
            end
            UIErrorsFrame:AddMessage("You have arrived.", 0.3, 1, 0.3)
        end
        arrow:Hide()
        return
    end
    arrow.title:SetText(s.showTitle ~= false and label or "")
    if not arrow:IsShown() then arrow:Show() end
end

local watch = CreateFrame("Frame")
local acc, accFast = 0, 0
watch:SetScript("OnUpdate", function(_, el)
    accFast = accFast + el
    if accFast >= 0.05 then accFast = 0; UpdateArrow() end
    acc = acc + el
    if acc >= 0.5 then acc = 0; Refresh() end
end)
watch:RegisterEvent("SUPER_TRACKING_CHANGED")
watch:RegisterEvent("USER_WAYPOINT_UPDATED")
watch:RegisterEvent("PLAYER_ENTERING_WORLD")
watch:SetScript("OnEvent", function() acc = 0.5 end)

---------------------------------------------------------------------------
-- Settings page / commands
---------------------------------------------------------------------------
_G.H3z0UI_QuestArrowSettings = S
_G.H3z0UI_RefreshQuestArrow = function()
    Place()
    Refresh()
end
_G.H3z0UI_QuestArrowReset = function()
    local s = S()
    s.x, s.y = DEFAULTS.x, DEFAULTS.y
    Place()
end
_G.H3z0UI_QuestArrowToggle = function()
    local s = S()
    s.enabled = not (s.enabled ~= false)
    Refresh()
    return s.enabled
end

-- move mode: shows a sample arrow, unlocked; call again to lock it where it is
_G.H3z0UI_QuestArrowMove = function()
    local s = S()
    moving = not moving
    s.locked = not moving
    if moving then Create() end
    Refresh()
    return moving
end

SLASH_H3ZARROW1 = "/h3z0arrow"
SlashCmdList["H3ZARROW"] = function(msg)
    msg = (msg or ""):lower():gsub("%s+", "")
    if msg == "move" then
        local on = _G.H3z0UI_QuestArrowMove()
        print("|cff34d399H3z0 UI|r " .. (on and "Drag the arrow where you want it, then type /h3z0arrow move again to lock it." or "Quest Arrow locked."))
        return
    end
    local on = _G.H3z0UI_QuestArrowToggle()
    print("|cff34d399H3z0 UI|r Quest Arrow " .. (on and "on" or "off"))
end
