---------------------------------------------------------------------------
-- H3z0 UI Party Frames
-- Own party frames: round portrait with class-colored ring, level badge, role icon,
-- name, health bar (with abbreviated value), power bar and an aura row.
-- Built with secure unit buttons (click = target, right click = menu), so they keep
-- working in combat. Written to be safe with Midnight's secret values: every number
-- that can be secret is only handed to StatusBars / FontStrings, never compared.
--
-- Shift+drag a frame to move the list. /h3z0party test shows a preview, /h3z0party reset
-- puts the list back at its default place.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local MAX_MEMBERS = 5   -- 4 party members + optionally yourself
local RING_TEXTURE = "Interface\\AddOns\\H3z0UI\\assets\\partyframes\\ring"
local MASK_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local container
local members = {}        -- ordered list of member buttons
local byUnit = {}         -- unit token -> member button
local testMode = false
local layoutPending = false

local issecretvalue = issecretvalue or function() return false end

local function GetSettings()
    return Helpers.GetModuleDB("partyFrames")
end

local function ClassColor(unit)
    local ok, _, class = pcall(UnitClass, unit)
    local c = ok and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.8, 0.8, 0.8
end

local function Abbrev(value)
    local fn = AbbreviateNumbers or AbbreviateLargeNumbers
    if fn then
        local ok, txt = pcall(fn, value)
        if ok then return txt end
    end
    return ""
end

---------------------------------------------------------------------------
-- Update helpers (one per element)
---------------------------------------------------------------------------
local function UpdateName(f)
    local s = GetSettings(); if not s then return end
    local unit = f.displayUnit
    local name = UnitName(unit)
    f.name:SetText(name or "")
    if s.classColorName then
        f.name:SetTextColor(ClassColor(unit))
    else
        f.name:SetTextColor(1, 1, 1)
    end
end

local function UpdateLevel(f)
    local s = GetSettings(); if not s then return end
    if not s.showLevel then f.levelBox:Hide() return end
    local lvl = UnitLevel(f.displayUnit)
    local txt = (lvl and lvl > 0) and tostring(lvl) or "??"
    f.levelText:SetText(txt)
    f.levelBox:Show()
end

local ROLE_ATLAS = {
    TANK = "roleicon-tiny-tank",
    HEALER = "roleicon-tiny-healer",
    DAMAGER = "roleicon-tiny-dps",
}

local function UpdateRoleAndLeader(f)
    local s = GetSettings(); if not s then return end
    local unit = f.displayUnit
    local role = s.showRole and UnitGroupRolesAssigned(unit) or nil
    local atlas = role and ROLE_ATLAS[role]
    if atlas then
        f.role:SetAtlas(atlas)
        f.role:Show()
    else
        f.role:Hide()
    end
    if s.showLeader and UnitIsGroupLeader(unit) then
        f.leader:Show()
    else
        f.leader:Hide()
    end
end

local function UpdateRing(f)
    local s = GetSettings(); if not s then return end
    if UnitIsUnit(f.displayUnit, "target") then
        f.ring:SetVertexColor(1, 1, 1)
    elseif s.classColorRing then
        f.ring:SetVertexColor(ClassColor(f.displayUnit))
    else
        f.ring:SetVertexColor(0.45, 0.3, 0.2)
    end
end

local function UpdatePortrait(f)
    pcall(SetPortraitTexture, f.portrait, f.displayUnit)
end

local function UpdateHealth(f)
    local s = GetSettings(); if not s then return end
    local unit = f.displayUnit
    local bar = f.health

    if s.classColorHealth then
        local r, g, b = ClassColor(unit)
        bar:SetStatusBarColor(r, g, b)
    else
        bar:SetStatusBarColor(0.2, 0.75, 0.2)
    end

    if not UnitIsConnected(unit) then
        bar:SetMinMaxValues(0, 1); bar:SetValue(0)
        f.healthText:SetText("Offline")
        return
    end
    if UnitIsDeadOrGhost(unit) then
        bar:SetMinMaxValues(0, 1); bar:SetValue(0)
        f.healthText:SetText("Dead")
        return
    end

    local okMax, maxHP = pcall(UnitHealthMax, unit)
    local okCur, curHP = pcall(UnitHealth, unit)
    if okMax and okCur then
        bar:SetMinMaxValues(0, maxHP)
        bar:SetValue(curHP)
        f.healthText:SetText(Abbrev(curHP))
    end
end

local function UpdatePower(f)
    local s = GetSettings(); if not s then return end
    local bar = f.power
    if not s.showPower then bar:Hide() return end
    local unit = f.displayUnit
    local pType, pToken = UnitPowerType(unit)
    local color = PowerBarColor and (PowerBarColor[pToken] or PowerBarColor[pType])
    if color then bar:SetStatusBarColor(color.r, color.g, color.b) else bar:SetStatusBarColor(0.1, 0.4, 0.9) end
    local okMax, maxP = pcall(UnitPowerMax, unit, pType)
    local okCur, curP = pcall(UnitPower, unit, pType)
    if okMax and okCur then
        bar:SetMinMaxValues(0, maxP)
        bar:SetValue(curP)
    end
    bar:Show()
end

local function CreateAuraIcon(f, index)
    local s = GetSettings()
    local size = (s and s.auraSize) or 20
    local ic = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ic:SetSize(size, size)
    ic:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    ic:SetBackdropBorderColor(0, 0, 0, 1)
    ic.tex = ic:CreateTexture(nil, "ARTWORK")
    ic.tex:SetPoint("TOPLEFT", 1, -1)
    ic.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ic.cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
    ic.cd:SetAllPoints(ic.tex)
    ic.cd:SetHideCountdownNumbers(true)
    ic.cd:SetDrawEdge(false)
    ic.count = ic:CreateFontString(nil, "OVERLAY")
    ic.count:SetFont(Helpers.GetGeneralFont(), 9, "OUTLINE")
    ic.count:SetPoint("BOTTOMRIGHT", 1, 0)
    ic:Hide()
    f.auraIcons[index] = ic
    return ic
end

local function UpdateAuras(f)
    local s = GetSettings(); if not s then return end
    local icons = f.auraIcons
    if not s.showAuras then
        for _, ic in ipairs(icons) do ic:Hide() end
        return
    end
    local unit = f.displayUnit
    local maxAuras = math.min(s.auraMax or 6, 12)
    local size = s.auraSize or 20
    local n = 0

    local function AddFilter(filter, isDebuff)
        for i = 1, 40 do
            if n >= maxAuras then return end
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok or not data then return end
            n = n + 1
            local ic = icons[n] or CreateAuraIcon(f, n)
            ic:SetSize(size, size)
            ic:ClearAllPoints()
            if n == 1 then
                ic:SetPoint("LEFT", f.health, "RIGHT", 5, 2)
            else
                ic:SetPoint("LEFT", icons[n - 1], "RIGHT", 2, 0)
            end
            pcall(ic.tex.SetTexture, ic.tex, data.icon)
            if isDebuff then ic:SetBackdropBorderColor(0.85, 0.15, 0.15, 1) else ic:SetBackdropBorderColor(0, 0, 0, 1) end
            -- stack count (Midnight display-count API, guarded)
            ic.count:SetText("")
            if C_UnitAuras.GetAuraApplicationDisplayCount and data.auraInstanceID then
                local okC, cnt = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, data.auraInstanceID, 2, 99)
                if okC and cnt then ic.count:SetText(cnt) end
            end
            -- cooldown swipe (duration object API, guarded)
            if C_UnitAuras.GetAuraDuration and ic.cd.SetCooldownFromDurationObject and data.auraInstanceID then
                local okD, dur = pcall(C_UnitAuras.GetAuraDuration, unit, data.auraInstanceID)
                if okD and dur then
                    pcall(ic.cd.SetCooldownFromDurationObject, ic.cd, dur)
                else
                    ic.cd:Clear()
                end
            else
                ic.cd:Clear()
            end
            ic:Show()
        end
    end

    if s.showDebuffs then AddFilter("HARMFUL", true) end
    if s.showBuffs then AddFilter("HELPFUL", false) end
    for i = n + 1, #icons do icons[i]:Hide() end
end

local function UpdateRange(f)
    local s = GetSettings(); if not s then return end
    if not s.rangeFade or testMode or f.displayUnit == "player" then f:SetAlpha(1) return end
    local ok, inRange = pcall(UnitInRange, f.displayUnit)
    if not ok then f:SetAlpha(1) return end
    if issecretvalue(inRange) then
        if f.SetAlphaFromBoolean then f:SetAlphaFromBoolean(inRange, 1, 0.45) end
    elseif inRange == false then
        f:SetAlpha(0.45)
    else
        f:SetAlpha(1)
    end
end

-- Ready check: tick / cross / waiting icon over the portrait
local READY_TEX = {
    ready    = READY_CHECK_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = READY_CHECK_NOT_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting  = READY_CHECK_WAITING_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
local readyCheckActive = false
local readyCheckFinishedAt = nil
local readyPreview = false
-- answers seen in READY_CHECK / READY_CHECK_CONFIRM, by party unit
-- (the game's GetReadyCheckStatus can be missing or hidden on some clients)
local rcAnswers = {}

local function IsSecret(v) return issecretvalue and issecretvalue(v) or false end

-- "raid3" / "player" / "party2" from the events -> our "partyN" / "player"
local PARTY_TOKENS = { "player", "party1", "party2", "party3", "party4" }
local function ToPartyUnit(unit)
    if not unit or IsSecret(unit) then return nil end
    if unit == "player" or unit:match("^party%d$") then return unit end
    for _, t in ipairs(PARTY_TOKENS) do
        local ok, same = pcall(UnitIsUnit, unit, t)
        if ok and same and not IsSecret(same) then return t end
    end
end

local function ApiReadyStatus(unit)
    local fn = GetReadyCheckStatus or (C_PartyInfo and C_PartyInfo.GetReadyCheckStatus)
    if not fn then return nil end
    local ok, st = pcall(fn, unit)
    if ok and st and not IsSecret(st) then return st end
end

local function UpdateReadyCheck(f)
    if not f.ready then return end
    local unit = f.displayUnit
    local status
    if readyPreview then
        local i = 0
        for n, m in ipairs(members) do if m == f then i = n end end
        status = ({ "ready", "notready", "waiting", "ready" })[i] or "ready"
    elseif (readyCheckActive or readyCheckFinishedAt) and unit and UnitExists(unit) then
        status = rcAnswers[unit] or ApiReadyStatus(unit)
        if not status and readyCheckActive then status = "waiting" end
    end
    -- keep the icon above the portrait, ring and Frame Style overlays
    if f.readyHolder then f.readyHolder:SetFrameLevel(f:GetFrameLevel() + 20) end
    if status and READY_TEX[status] then
        -- after the check ends, players who never answered count as not ready
        if not readyCheckActive and status == "waiting" then status = "notready" end
        f.ready:SetTexture(READY_TEX[status])
        f.ready:SetAlpha(1)
        f.ready:Show()
    else
        f.ready:Hide()
    end
end

local function UpdateAll(f)
    UpdateName(f); UpdateLevel(f); UpdateRoleAndLeader(f); UpdateRing(f)
    UpdatePortrait(f); UpdateHealth(f); UpdatePower(f); UpdateAuras(f); UpdateRange(f)
    UpdateReadyCheck(f)
end

---------------------------------------------------------------------------
-- Frame creation
---------------------------------------------------------------------------
local function SavePosition()
    local s = GetSettings()
    if not s or not container then return end
    local point, _, relPoint, x, y = container:GetPoint()
    s.pos = {point = point, relPoint = relPoint, x = x, y = y}
end

local function CreateMember(index)
    local f = CreateFrame("Button", "H3z0UI_PartyMember" .. index, container, "SecureUnitButtonTemplate")
    f.index = index
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not InCombatLockdown() then container:StartMoving() end
    end)
    f:SetScript("OnDragStop", function()
        container:StopMovingOrSizing()
        SavePosition()
    end)

    f:SetScript("OnShow", function(self) if self.displayUnit then UpdateAll(self) end end)

    -- hover: unit tooltip
    f:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(self.displayUnit)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ring + masked portrait
    f.ring = f:CreateTexture(nil, "BACKGROUND")
    f.ring:SetTexture(RING_TEXTURE)

    f.portrait = f:CreateTexture(nil, "ARTWORK")
    f.mask = f:CreateMaskTexture()
    f.mask:SetTexture(MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    f.portrait:AddMaskTexture(f.mask)

    -- level badge (black box at the portrait's left)
    f.levelBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.levelBox:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    f.levelBox:SetBackdropColor(0, 0, 0, 0.9)
    f.levelText = f.levelBox:CreateFontString(nil, "OVERLAY")
    f.levelText:SetPoint("CENTER", 0, 0)

    -- role icon + leader crown
    f.role = f:CreateTexture(nil, "OVERLAY")
    f.leader = f:CreateTexture(nil, "OVERLAY")
    f.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")

    -- name
    f.name = f:CreateFontString(nil, "OVERLAY")
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)

    -- health bar
    f.health = CreateFrame("StatusBar", nil, f)
    f.healthBG = f.health:CreateTexture(nil, "BACKGROUND")
    f.healthBG:SetAllPoints()
    f.healthBG:SetColorTexture(0, 0, 0, 0.7)
    f.healthText = f.health:CreateFontString(nil, "OVERLAY")
    f.healthText:SetPoint("CENTER", 0, 0)

    -- power bar
    f.power = CreateFrame("StatusBar", nil, f)
    f.powerBG = f.power:CreateTexture(nil, "BACKGROUND")
    f.powerBG:SetAllPoints()
    f.powerBG:SetColorTexture(0, 0, 0, 0.7)

    -- ready check icon (above everything on the portrait)
    f.readyHolder = CreateFrame("Frame", nil, f)
    f.readyHolder:SetFrameLevel(f:GetFrameLevel() + 20)
    f.ready = f.readyHolder:CreateTexture(nil, "OVERLAY", nil, 7)
    f.ready:Hide()

    f.auraIcons = {}
    f.displayUnit = "party" .. index
    return f
end

local function StyleMember(f)
    local s = GetSettings(); if not s then return end
    local P = s.portraitSize or 46
    local BW = s.barWidth or 96
    local HH = s.healthHeight or 12
    local PH = s.powerHeight or 5
    local font, outline = Helpers.GetGeneralFont(), Helpers.GetGeneralFontOutline()
    local fontSize = s.fontSize or 10
    local tex = Helpers.GetGeneralTexture()

    local gap = 6
    local totalH = math.max(P + 10, HH + PH + fontSize + 8)
    f:SetSize(P + gap + BW + 10, totalH)

    f.ring:SetSize(P + 10, P + 10)
    f.ring:ClearAllPoints()
    f.ring:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -(totalH - P - 10) / 2)

    f.portrait:SetSize(P, P)
    f.portrait:ClearAllPoints()
    f.portrait:SetPoint("CENTER", f.ring, "CENTER", 0, 0)
    f.mask:SetAllPoints(f.portrait)
    if f.readyHolder then
        f.readyHolder:SetAllPoints(f.portrait)
        f.ready:ClearAllPoints()
        f.ready:SetPoint("CENTER", f.portrait, "CENTER", 0, 0)
        f.ready:SetSize(math.floor(P * 0.62), math.floor(P * 0.62))
    end

    f.levelBox:SetSize(math.max(16, fontSize * 2), fontSize + 4)
    f.levelBox:ClearAllPoints()
    f.levelBox:SetPoint("BOTTOMLEFT", f.ring, "BOTTOMLEFT", -4, 2)
    f.levelText:SetFont(font, fontSize, outline)

    f.role:SetSize(14, 14)
    f.role:ClearAllPoints()
    f.role:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, 2)
    f.leader:SetSize(12, 12)

    f.name:SetFont(font, fontSize, outline)
    f.name:ClearAllPoints()
    local nameX = (s.showRole and 16) or 0
    f.name:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", nameX, 2)
    f.name:SetWidth(BW - nameX - 14)
    f.leader:ClearAllPoints()
    f.leader:SetPoint("LEFT", f.name, "RIGHT", 0, 0)

    f.health:ClearAllPoints()
    f.health:SetSize(BW, HH)
    f.health:SetPoint("LEFT", f.ring, "RIGHT", gap, 2)
    f.health:SetStatusBarTexture(tex)
    f.healthText:SetFont(font, math.max(8, fontSize - 1), outline)

    f.power:ClearAllPoints()
    f.power:SetSize(BW, PH)
    f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -1)
    f.power:SetStatusBarTexture(tex)

    local size = s.auraSize or 20
    for _, ic in ipairs(f.auraIcons) do ic:SetSize(size, size) end
end

---------------------------------------------------------------------------
-- Layout (out of combat only: secure frames cannot be resized/moved in combat)
---------------------------------------------------------------------------
local function UnitForSlot(i, s)
    if s.showPlayer then
        if i == 1 then return "player" end
        return "party" .. (i - 1)
    end
    return "party" .. i
end

local function ApplyLayout()
    local s = GetSettings()
    if not container then return end
    if InCombatLockdown() then layoutPending = true return end
    layoutPending = false

    if not s or not s.enabled then
        for _, f in ipairs(members) do
            UnregisterUnitWatch(f)
            f:Hide()
        end
        container:Hide()
        return
    end

    container:SetScale(s.scale or 1)
    container:Show()

    wipe(byUnit)
    local slots = s.showPlayer and 5 or 4
    local rowH
    for i = 1, MAX_MEMBERS do
        local f = members[i]
        if i <= slots then
            local unit = UnitForSlot(i, s)
            f:SetAttribute("unit", unit)
            f.unit = unit
            f.displayUnit = testMode and "player" or unit
            byUnit[unit] = f
            StyleMember(f)
            rowH = f:GetHeight()
            f:ClearAllPoints()
            local step = rowH + (s.spacing or 10)
            if s.growUp then
                f:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, (i - 1) * step)
            else
                f:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * step)
            end
            if testMode then
                UnregisterUnitWatch(f)
                f:Show()
            else
                RegisterUnitWatch(f)
            end
        else
            UnregisterUnitWatch(f)
            f:Hide()
        end
    end

    if rowH then
        container:SetSize(members[1]:GetWidth(), slots * rowH + (slots - 1) * (s.spacing or 10))
    end
    for i = 1, slots do
        if members[i]:IsShown() then UpdateAll(members[i]) end
    end
end

local function RestorePosition()
    local s = GetSettings()
    container:ClearAllPoints()
    local pos = s and s.pos
    if pos and pos.point then
        container:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -230)
    end
end

---------------------------------------------------------------------------
-- Blizzard party frames: hide while ours are active
---------------------------------------------------------------------------
-- Blizzard's raid frame manager (the tab at the left screen edge): not needed in a party,
-- the H3z0 UI Raid Control tab replaces it. Shown again in raids.
local managerHooked = false
local function HideRaidManager()
    local s = GetSettings()
    local mgr = _G.CompactRaidFrameManager
    if not mgr then return end
    local hide = s and s.enabled and s.hideBlizzard and not IsInRaid()
    pcall(mgr.SetAlpha, mgr, hide and 0 or 1)
    if not InCombatLockdown() then
        pcall(mgr.EnableMouse, mgr, not hide)
        local toggle = mgr.toggleButton or _G.CompactRaidFrameManagerToggleButton
        if toggle and toggle.EnableMouse then pcall(toggle.EnableMouse, toggle, not hide) end
    end
    if not managerHooked then
        managerHooked = true
        mgr:HookScript("OnShow", function() C_Timer.After(0, HideRaidManager) end)
    end
end

local function HideBlizzardParty()
    HideRaidManager()
    local s = GetSettings()
    local hide = s and s.enabled and s.hideBlizzard
    for _, name in ipairs({"PartyFrame", "CompactPartyFrame"}) do
        local fr = _G[name]
        if fr and fr.SetAlpha then
            pcall(fr.SetAlpha, fr, hide and 0 or 1)
            if not InCombatLockdown() and fr.EnableMouse then
                pcall(fr.EnableMouse, fr, not hide)
                for i = 1, 5 do
                    local m = fr["MemberFrame" .. i]
                    if m and m.EnableMouse then pcall(m.EnableMouse, m, not hide) end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function ForUnit(unit, fn)
    local f = byUnit[unit]
    if f and f:IsShown() then fn(f) end
    if testMode and unit == "player" then
        for _, m in ipairs(members) do
            if m:IsShown() then fn(m) end
        end
    end
end

local events = CreateFrame("Frame")
local EVENT_HANDLERS = {
    UNIT_HEALTH = UpdateHealth,
    UNIT_MAXHEALTH = UpdateHealth,
    UNIT_CONNECTION = function(f) UpdateHealth(f); UpdateRange(f) end,
    UNIT_POWER_UPDATE = UpdatePower,
    UNIT_MAXPOWER = UpdatePower,
    UNIT_DISPLAYPOWER = UpdatePower,
    UNIT_AURA = UpdateAuras,
    UNIT_PORTRAIT_UPDATE = UpdatePortrait,
    UNIT_MODEL_CHANGED = UpdatePortrait,
    UNIT_NAME_UPDATE = UpdateName,
    UNIT_LEVEL = UpdateLevel,
}

local function RefreshShown()
    for _, f in ipairs(members) do
        if f:IsShown() then UpdateAll(f) end
    end
end

events:SetScript("OnEvent", function(_, event, unit, ...)
    local s = GetSettings()
    if not s or not s.enabled or not container then return end

    local handler = EVENT_HANDLERS[event]
    if handler then
        ForUnit(unit, handler)
        return
    end

    if event == "READY_CHECK" then
        readyCheckActive = true
        readyCheckFinishedAt = nil
        wipe(rcAnswers)
        for _, t in ipairs(PARTY_TOKENS) do
            if UnitExists(t) then rcAnswers[t] = "waiting" end
        end
        -- the one who started it is ready (arg1 = initiator name)
        local initiator = unit   -- READY_CHECK passes the initiator's name first
        if initiator and not IsSecret(initiator) then
            for _, t in ipairs(PARTY_TOKENS) do
                local ok, n = pcall(GetUnitName, t, true)
                local ok2, short = pcall(UnitName, t)
                if (ok and n == initiator) or (ok2 and short == initiator) then rcAnswers[t] = "ready" end
            end
        end
        for _, f in ipairs(members) do if f:IsShown() then UpdateReadyCheck(f) end end
        return
    elseif event == "READY_CHECK_CONFIRM" then
        local who, isReady = unit, select(1, ...)
        local t = ToPartyUnit(who)
        if t and not IsSecret(isReady) then
            rcAnswers[t] = isReady and "ready" or "notready"
        end
        for _, f in ipairs(members) do if f:IsShown() then UpdateReadyCheck(f) end end
        return
    elseif event == "READY_CHECK_FINISHED" then
        for _, f in ipairs(members) do if f:IsShown() then UpdateReadyCheck(f) end end
        readyCheckActive = false
        local stamp = GetTime()
        readyCheckFinishedAt = stamp
        for _, f in ipairs(members) do if f:IsShown() then UpdateReadyCheck(f) end end
        -- keep the result on screen for a few seconds, then fade it out
        C_Timer.After(6, function()
            if readyCheckFinishedAt ~= stamp then return end
            for _, f in ipairs(members) do
                if f.ready and f.ready:IsShown() then
                    UIFrameFadeOut(f.ready, 1.5, 1, 0)
                end
            end
            C_Timer.After(1.6, function()
                if readyCheckFinishedAt ~= stamp then return end
                readyCheckFinishedAt = nil
                for _, f in ipairs(members) do if f.ready then f.ready:Hide(); f.ready:SetAlpha(1) end end
            end)
        end)
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        for _, f in ipairs(members) do if f:IsShown() then UpdateRing(f) end end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "PARTY_LEADER_CHANGED" then
        HideBlizzardParty()
        C_Timer.After(0.1, RefreshShown)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if layoutPending then ApplyLayout() end
        HideBlizzardParty()
    elseif event == "PLAYER_ENTERING_WORLD" then
        HideBlizzardParty()
        C_Timer.After(0.5, RefreshShown)
    end
end)

for _, e in ipairs({
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
    "UNIT_DISPLAYPOWER", "UNIT_AURA", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED", "PARTY_LEADER_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
}) do
    events:RegisterEvent(e)
end

-- range fade (UnitInRange has no event)
local rangeElapsed = 0
events:SetScript("OnUpdate", function(_, elapsed)
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed < 0.3 then return end
    rangeElapsed = 0
    if not container or not container:IsShown() then return end
    for _, f in ipairs(members) do
        if f:IsShown() then UpdateRange(f) end
    end
end)

---------------------------------------------------------------------------
-- Init / refresh
---------------------------------------------------------------------------
local function Refresh()
    if not container then return end
    HideBlizzardParty()
    ApplyLayout()
    -- let the raid control tab follow the list
    if _G.H3z0UI_RaidControlRefreshAnchor then _G.H3z0UI_RaidControlRefreshAnchor() end
end

local function Init()
    local s = GetSettings()
    if not s then return end
    container = CreateFrame("Frame", "H3z0UI_PartyFrames", UIParent)
    container:SetFrameStrata("LOW")
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:SetSize(150, 300)
    RestorePosition()
    for i = 1, MAX_MEMBERS do
        members[i] = CreateMember(i)
    end
    Refresh()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(0.6, Init)
end)

_G.H3z0UI_RefreshPartyFrames = Refresh
-- Layout Mode hooks (preview the list while solo)
_G.H3z0UI_PartyFramesSetTest = function(on)
    if not container or InCombatLockdown() then return end
    testMode = on and true or false
    ApplyLayout()
end
_G.H3z0UI_PartyFramesIsTest = function() return testMode end

SLASH_H3Z0PARTY1 = "/h3z0party"
SlashCmdList["H3Z0PARTY"] = function(msg)
    msg = (msg or ""):lower()
    if not container then return end
    if InCombatLockdown() then
        print("|cff34D399H3z0 UI:|r Party frames can't be changed in combat.")
        return
    end
    if msg:match("^%s*reset") then
        local s = GetSettings()
        if s then s.pos = nil end
        RestorePosition()
        print("|cff34D399H3z0 UI:|r Party frames position reset.")
    elseif msg:match("^%s*ready") then
        readyPreview = not readyPreview
        for _, f in ipairs(members) do if f:IsShown() then UpdateReadyCheck(f) end end
        print("|cff34D399H3z0 UI:|r Ready check icons preview " .. (readyPreview and "ON (use /h3z0party test while solo)" or "OFF"))
    elseif msg:match("^%s*test") then
        testMode = not testMode
        ApplyLayout()
        print("|cff34D399H3z0 UI:|r Party frames preview " .. (testMode and "ON (shows your own character in every slot)" or "OFF"))
    else
        print("|cff34D399H3z0 UI:|r /h3z0party test - preview, /h3z0party ready - preview ready check icons, /h3z0party reset - reset position. Shift+drag a frame to move the list.")
    end
end
