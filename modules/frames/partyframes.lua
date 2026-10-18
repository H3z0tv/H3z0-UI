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
    local s = Helpers.GetModuleDB("partyFrames")
    if s and not s.levelOff0241 then
        s.levelOff0241 = true
        s.showLevel = false
    end
    return s
end

local function ClassColor(unit)
    local ok, _, class = pcall(UnitClass, unit)
    local c = ok and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.8, 0.8, 0.8
end

-- Round Portrait v2 party frames match the H3z0 Player frame: same font, white name,
-- "614K | 100%" in the bar, nameplate colours, the player frame's bar texture and background
local function IsV2(s) return s and s.style == "v2" end

local function NPColor(unit)
    local NP = ns.H3zPlates
    if NP and NP.ColorFor then
        local ok, r, g, b = pcall(NP.ColorFor, unit)
        if ok and r then return r, g, b end
    end
    return nil
end

local function PlayerFrameTexture()
    local core = ns.Addon
    local prof = core and core.db and core.db.profile
    local uf = prof and prof.h3z0uiUnitFrames
    local name = uf and uf.player and uf.player.texture
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if name and name ~= "" and LSM then
        local path = LSM:Fetch("statusbar", name, true)
        if path then return path end
    end
    return Helpers.GetGeneralTexture()
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
    if IsV2(s) then
        f.name:SetTextColor(1, 1, 1)          -- white like the Player frame name
    elseif s.classColorName then
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
    elseif s.classColorRing or IsV2(s) then
        f.ring:SetVertexColor(ClassColor(f.displayUnit))
    else
        f.ring:SetVertexColor(0.45, 0.3, 0.2)
    end
    if f.v2Glow then
        local r, g, b = f.ring:GetVertexColor()
        for _, t in ipairs(f.v2Glow) do t:SetVertexColor(r, g, b, t.alpha) end
    end
end

local function UpdatePortrait(f)
    pcall(SetPortraitTexture, f.portrait, f.displayUnit)
end

local function UpdateHealth(f)
    local s = GetSettings(); if not s then return end
    local unit = f.displayUnit
    local bar = f.health

    local npr, npg, npb
    if IsV2(s) then npr, npg, npb = NPColor(unit) end
    if npr then
        bar:SetStatusBarColor(npr, npg, npb)
    elseif s.classColorHealth then
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
        local hpTxt = Abbrev(curHP)
        local done = false
        if IsV2(s) and UnitHealthPercent then
            -- "614K | 100%" like the Player frame (secret-safe: values only go to the formatter)
            local curve = CurveConstants and CurveConstants.ScaleTo100
            local okP, pct = pcall(UnitHealthPercent, unit, true, curve)
            if okP and pct ~= nil and curve then
                done = pcall(f.healthText.SetFormattedText, f.healthText, "%s | %.0f%%", hpTxt, pct)
            end
        end
        if not done then f.healthText:SetText(hpTxt) end
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

-- v2: the bars run under the portrait, so the frame itself is never made see-through
-- (the bar would show through the face). Bars / text / auras fade, the portrait
-- stays solid and gets a dark veil instead.
local FADE = 0.45
local function V2Parts(f)
    local parts = { f.health, f.power, f.name, f.role, f.leader, f.levelBox }
    if f.v2Border then parts[#parts + 1] = f.v2Border end
    for _, ic in ipairs(f.auraIcons or {}) do parts[#parts + 1] = ic end
    return parts
end

local function V2Veil(f)
    if f.v2Veil then return f.v2Veil end
    local v = CreateFrame("Frame", nil, f.v2Top or f)
    v:EnableMouse(false)
    v:SetFrameLevel((f.v2Top or f):GetFrameLevel() + 2)
    local t = v:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0, 0, 0, 1)
    t:SetAllPoints(v)
    local m = v:CreateMaskTexture()
    m:SetTexture(MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(v)
    t:AddMaskTexture(m)
    f.v2Veil = v
    return v
end

local function SetPart(part, inRange, secret, onA, offA)
    if not part then return end
    if secret then
        if part.SetAlphaFromBoolean then part:SetAlphaFromBoolean(inRange, onA, offA) end
    else
        part:SetAlpha(inRange == false and offA or onA)
    end
end

local function UpdateRangeV2(f, inRange, secret, active)
    f:SetAlpha(1)
    local veil = V2Veil(f)
    veil:ClearAllPoints()
    veil:SetAllPoints(f.portrait)
    veil:Show()
    if not active then
        for _, p in ipairs(V2Parts(f)) do p:SetAlpha(1) end
        veil:SetAlpha(0)
        return
    end
    for _, p in ipairs(V2Parts(f)) do SetPart(p, inRange, secret, 1, FADE) end
    SetPart(veil, inRange, secret, 0, 0.55)
end

local function UpdateRange(f)
    local s = GetSettings(); if not s then return end
    local v2 = (s.style == "v2")
    if not v2 then
        if f.v2Veil then f.v2Veil:Hide() end
        if f.h3zV2Faded then
            f.h3zV2Faded = nil
            for _, p in ipairs(V2Parts(f)) do p:SetAlpha(1) end
        end
    end
    if not s.rangeFade or testMode or f.displayUnit == "player" then
        f:SetAlpha(1)
        if v2 then UpdateRangeV2(f, true, false, false) end
        return
    end
    local ok, inRange = pcall(UnitInRange, f.displayUnit)
    if not ok then f:SetAlpha(1) return end
    if v2 then
        f.h3zV2Faded = true
        UpdateRangeV2(f, inRange, issecretvalue(inRange), true)
        return
    end
    if issecretvalue(inRange) then
        if f.SetAlphaFromBoolean then f:SetAlphaFromBoolean(inRange, 1, 0.45) end
    elseif inRange == false then
        f:SetAlpha(0.45)
    else
        f:SetAlpha(1)
    end
end

-- Ready check: tick / cross / waiting icon over the portrait
-- atlases first (present in current clients), the old texture files as a fallback
local READY_ATLAS = {
    ready    = "UI-LFG-ReadyMark",
    notready = "UI-LFG-DeclineMark",
    waiting  = "UI-LFG-PendingMark",
}
local READY_TEX = {
    ready    = READY_CHECK_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = READY_CHECK_NOT_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting  = READY_CHECK_WAITING_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
local readyCheckActive = false
local readyCheckFinishedAt = nil
local readyPreview = false
local rcDebug = false
local function RCSay(msg) if rcDebug then print("|cff34D399H3z0 RC:|r " .. msg) end end
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
    if f.readyHolder then
        f.readyHolder:SetFrameStrata("HIGH")
        f.readyHolder:SetFrameLevel(f:GetFrameLevel() + 20)
        f.readyHolder:Show()
    end
    if status and READY_TEX[status] then
        -- after the check ends, players who never answered count as not ready
        if not readyCheckActive and status == "waiting" then status = "notready" end
        local okAtlas = false
        if f.ready.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(READY_ATLAS[status]) then
            okAtlas = pcall(f.ready.SetAtlas, f.ready, READY_ATLAS[status], false)
        end
        if not okAtlas then f.ready:SetTexture(READY_TEX[status]) end
        if (f.ready:GetWidth() or 0) < 2 or f.ready:GetNumPoints() == 0 then
            f.ready:ClearAllPoints()
            f.ready:SetPoint("CENTER", f.portrait or f, "CENTER", 0, 0)
            f.ready:SetSize(28, 28)
        end
        f.ready:SetAlpha(1)
        f.ready:Show()
        if rcDebug then
            local w, h = f.ready:GetSize()
            RCSay(string.format("%s: %s atlas=%s size=%dx%d holder=%s/%s shown=%s",
                tostring(unit), status, tostring(okAtlas), w or 0, h or 0,
                tostring(f.readyHolder and f.readyHolder:GetFrameStrata()), tostring(f.readyHolder and f.readyHolder:GetWidth()),
                tostring(f.ready:IsVisible())))
        end
    else
        f.ready:Hide()
    end
end


local function SafeUpdateReady(f)
    local ok, err = pcall(UpdateReadyCheck, f)
    if not ok then RCSay("update error: " .. tostring(err)) end
end

local function UpdateAllReady()
    for _, f in ipairs(members) do
        if f:IsShown() then SafeUpdateReady(f) end
    end
end

-- own fade (Blizzard's UIFrameFade list is shared UI state; not touched)
local function FadeReadyIcons(stamp)
    local t = 0
    local fader = CreateFrame("Frame")
    fader:SetScript("OnUpdate", function(self, el)
        t = t + el
        local a = math.max(0, 1 - t / 1.5)
        for _, f in ipairs(members) do if f.ready then f.ready:SetAlpha(a) end end
        if t >= 1.5 then
            self:SetScript("OnUpdate", nil)
            if readyCheckFinishedAt == stamp then
                readyCheckFinishedAt = nil
                for _, f in ipairs(members) do if f.ready then f.ready:Hide(); f.ready:SetAlpha(1) end end
            end
        end
    end)
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
    f.readyHolder:SetFrameStrata("HIGH")          -- nothing in the party frames can cover it
    f.readyHolder:SetFrameLevel(f:GetFrameLevel() + 20)
    f.ready = f.readyHolder:CreateTexture(nil, "OVERLAY", nil, 7)
    f.ready:Hide()

    f.auraIcons = {}
    f.displayUnit = "party" .. index
    return f
end


---------------------------------------------------------------------------
-- Style "Round Portrait v2": the bars start under the portrait, the far end is
-- round with a black outline (same look as the Player frame's v2 style)
---------------------------------------------------------------------------
local ROUND_R = "Interface\\AddOns\\" .. ADDON_NAME .. "\\assets\\h3z_roundend_r"

local function V2Mask(owner, field, ref, grow, height)
    local m = owner[field]
    if not m then
        m = owner:CreateMaskTexture()
        owner[field] = m
    end
    m:SetTexture(ROUND_R, "CLAMP", "CLAMP")
    m:ClearAllPoints()
    m:SetPoint("TOPRIGHT", ref, "TOPRIGHT", grow, grow)
    m:SetPoint("BOTTOMRIGHT", ref, "BOTTOMRIGHT", grow, -grow)
    -- the height is passed in: right after a re-layout GetHeight() can still be 0 (= a square end)
    local h = height or ref:GetHeight() or 10
    if h <= 0 then h = 10 end
    m:SetWidth(math.max(2, h + grow * 2) / 2)
    return m
end

local function SetMask(tex, mask, on)
    if not (tex and tex.AddMaskTexture) then return end
    tex.h3zPFMasks = tex.h3zPFMasks or {}
    if on then
        if not tex.h3zPFMasks[mask] and pcall(tex.AddMaskTexture, tex, mask) then tex.h3zPFMasks[mask] = true end
    else
        for m in pairs(tex.h3zPFMasks) do pcall(tex.RemoveMaskTexture, tex, m) end
        wipe(tex.h3zPFMasks)
    end
end

local function ApplyPartyStyle(f, s, P, BW, gap)
    local v2 = (s.style == "v2")
    -- portrait + ring on a layer above the bars (v2) or back on the frame (classic)
    if not f.v2Top then
        f.v2Top = CreateFrame("Frame", nil, f)
        f.v2Top:SetAllPoints(f)
        f.v2Top:EnableMouse(false)
    end
    local parent = v2 and f.v2Top or f
    f.v2Top:SetFrameLevel(f:GetFrameLevel() + 10)
    f.ring:SetParent(parent)
    f.portrait:SetParent(parent)
    f.mask:SetParent(parent)
    -- v2: solid dark disc behind the portrait, so the bar under it never shows through
    -- (out of range the game often gives a faded or empty portrait)
    if not f.v2Disc then
        f.v2Disc = f.v2Top:CreateTexture(nil, "BORDER", nil, 7)
        f.v2Disc:SetColorTexture(0.06, 0.06, 0.07, 1)
        f.v2Disc:AddMaskTexture(f.mask)
    end
    f.v2Disc:ClearAllPoints()
    f.v2Disc:SetAllPoints(f.portrait)
    f.v2Disc:SetShown(v2)

    -- v2 ring: a solid class-coloured disc behind the portrait (thin ring), like the Player frame
    if not f.ringMask then
        f.ringMask = f.v2Top:CreateMaskTexture()
        f.ringMask:SetTexture(MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    f.ringMask:ClearAllPoints()
    f.ringMask:SetAllPoints(f.ring)
    if v2 then
        f.ring:SetTexture("Interface\\Buttons\\WHITE8x8")
        if not f.ringMasked then f.ring:AddMaskTexture(f.ringMask); f.ringMasked = true end
    else
        if f.ringMasked then f.ring:RemoveMaskTexture(f.ringMask); f.ringMasked = nil end
        f.ring:SetTexture(RING_TEXTURE)
    end

    -- v2 glow behind the ring (Modern Look > Portrait Glow), the same soft glow as the Player frame
    local ML = ns.ModernLook
    local mls = ML and ML.GetSettings and ML.GetSettings()
    local glowOn = v2 and mls and mls.enabled and mls.glow
    if not f.v2Glow then
        f.v2Glow = {}
        for i, a in ipairs({ 0.22, 0.12, 0.06 }) do
            local t = f.v2Top:CreateTexture(nil, "BACKGROUND", nil, -8 + i)
            local m = f.v2Top:CreateMaskTexture()
            m:SetTexture(MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            t:SetTexture("Interface\\Buttons\\WHITE8x8")
            t:AddMaskTexture(m)
            t.mask, t.alpha, t.grow = m, a, i * 3
            f.v2Glow[i] = t
        end
    end
    for _, t in ipairs(f.v2Glow) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", f.ring, "TOPLEFT", -t.grow, t.grow)
        t:SetPoint("BOTTOMRIGHT", f.ring, "BOTTOMRIGHT", t.grow, -t.grow)
        t.mask:ClearAllPoints()
        t.mask:SetAllPoints(t)
        t:SetShown(glowOn and true or false)
    end
    f.v2GlowOn = glowOn
    f.levelBox:SetFrameLevel((v2 and f.v2Top:GetFrameLevel() or f:GetFrameLevel()) + 1)

    local texList = {
        f.health:GetStatusBarTexture(), f.healthBG,
        f.power:GetStatusBarTexture(), f.powerBG,
    }
    if not v2 then
        for _, t in ipairs(texList) do SetMask(t, nil, false) end
        if f.v2Border then SetMask(f.v2Border, nil, false); f.v2Border:Hide() end
        return
    end

    -- bars start at the portrait's centre and keep their right end where it was
    local half = (f.ring:GetWidth() or (P + 10)) / 2
    f.health:ClearAllPoints()
    f.health:SetWidth(BW + half + gap)
    f.health:SetPoint("LEFT", f.ring, "CENTER", 0, 2)
    f.power:SetWidth(BW + half + gap)
    -- name / role start after the portrait
    local nameX = (s.showRole and 16) or 0
    f.role:ClearAllPoints()
    f.role:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", half + 2, 2)
    f.name:ClearAllPoints()
    f.name:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", half + 2 + nameX, 2)

    -- block = health (+ power) ; round right end with a 1px black outline
    if not f.v2Ref then
        f.v2Ref = CreateFrame("Frame", nil, f)
        f.v2Ref:EnableMouse(false)
    end
    local bottom = (s.showPower and f.power:IsShown()) and f.power or f.health
    f.v2Ref:ClearAllPoints()
    f.v2Ref:SetPoint("TOPLEFT", f.health, "TOPLEFT", 0, 0)
    f.v2Ref:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", 0, 0)
    if not f.v2Border then
        f.v2Border = f:CreateTexture(nil, "BACKGROUND", nil, -7)
        f.v2Border:SetColorTexture(0, 0, 0, 1)
    end
    f.v2Border:ClearAllPoints()
    f.v2Border:SetPoint("TOPLEFT", f.v2Ref, "TOPLEFT", -1, 1)
    f.v2Border:SetPoint("BOTTOMRIGHT", f.v2Ref, "BOTTOMRIGHT", 1, -1)
    f.v2Border:Show()
    local bh = (bottom == f.power) and ((f.health:GetHeight() or 0) + 1 + (f.power:GetHeight() or 0)) or (f.health:GetHeight() or 0)
    if bh <= 0 then bh = f.v2BlockH or 20 end
    SetMask(f.v2Border, V2Mask(f, "v2OuterMask", f.v2Ref, 1, bh), true)
    local hm = V2Mask(f.health, "v2InnerMask", f.v2Ref, 0, bh)
    SetMask(f.health:GetStatusBarTexture(), hm, true)
    SetMask(f.healthBG, hm, true)
    local pm = V2Mask(f.power, "v2InnerMask", f.v2Ref, 0, bh)
    SetMask(f.power:GetStatusBarTexture(), pm, true)
    SetMask(f.powerBG, pm, true)
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
    local v2 = IsV2(s)
    if v2 then
        HH = s.v2HealthHeight or 22         -- a taller bar like the Player frame
        PH = s.v2PowerHeight or 4
        BW = s.v2BarWidth or math.max(BW, 120)   -- v2 has its own width setting
        fontSize = fontSize + 2
        tex = PlayerFrameTexture()
    end

    local gap = 6
    local R = P + 10                       -- ring size
    local inner = P                        -- portrait size
    if v2 then
        local blockH = HH + ((s.showPower ~= false) and (PH + 1) or 0)
        R = math.floor(blockH * 1.6 + 0.5)
        inner = R - 4                      -- thin ring (2 px) like the Player frame
        P = R - 10
        f.v2BlockH = blockH
    end
    local totalH = math.max(R, HH + PH + fontSize + 8)
    f:SetSize(R + gap + BW, totalH)

    f.ring:SetSize(R, R)
    f.ring:ClearAllPoints()
    f.ring:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -(totalH - R) / 2)

    f.portrait:SetSize(inner, inner)
    f.portrait:ClearAllPoints()
    f.portrait:SetPoint("CENTER", f.ring, "CENTER", 0, 0)
    f.mask:SetAllPoints(f.portrait)
    if f.readyHolder then
        -- the holder covers the whole member frame (a frame anchored to a texture
        -- can end up with no size); the icon itself sits on the portrait's centre
        f.readyHolder:ClearAllPoints()
        f.readyHolder:SetAllPoints(f)
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

    local nameSize = (s.nameFontSize and s.nameFontSize > 0) and s.nameFontSize or fontSize
    f.name:SetFont(font, nameSize, outline)
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
    local hpSize = (s.healthFontSize and s.healthFontSize > 0) and s.healthFontSize or math.max(8, fontSize - 1)
    f.healthText:SetFont(font, hpSize, outline)
    f.healthText:ClearAllPoints()
    if v2 then
        f.healthText:SetPoint("RIGHT", f.health, "RIGHT", -8, 0)
        f.healthText:SetJustifyH("RIGHT")
        f.healthBG:SetColorTexture(0.1, 0.1, 0.1, 0.9)       -- the Player frame's background
        f.powerBG:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    else
        f.healthText:SetPoint("CENTER", f.health, "CENTER", 0, 0)
        f.healthText:SetJustifyH("CENTER")
        f.healthBG:SetColorTexture(0, 0, 0, 0.7)
        f.powerBG:SetColorTexture(0, 0, 0, 0.7)
    end

    f.power:ClearAllPoints()
    f.power:SetSize(BW, PH)
    f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -1)
    f.power:SetStatusBarTexture(tex)

    local size = s.auraSize or 20
    for _, ic in ipairs(f.auraIcons) do ic:SetSize(size, size) end

    ApplyPartyStyle(f, s, P, BW, gap)
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
        UnregisterAttributeDriver(container, "state-visibility")
        container:Hide()
        return
    end

    container:SetScale(s.scale or 1)
    container:Show()
    -- 0.24.5: in a raid the H3z0 UI raid frames take over (party1-4 would be your own raid group)
    local rf = Helpers.GetModuleDB("raidFrames")
    if rf and rf.enabled and not testMode then
        RegisterAttributeDriver(container, "state-visibility", "[group:raid] hide; show")
    else
        UnregisterAttributeDriver(container, "state-visibility")
        container:Show()
    end

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
-- 0.24.2: UNIT_AURA fires many times a second in groups; rebuild a frame's aura icons at most
-- 10 times a second instead of on every single event
local auraQueued = false
local function FlushAuras()
    auraQueued = false
    for _, f in ipairs(members) do
        if f.h3zAuraDirty then
            f.h3zAuraDirty = nil
            if f:IsShown() then pcall(UpdateAuras, f) end
        end
    end
end
local function QueueAuras(f)
    f.h3zAuraDirty = true
    if not auraQueued then
        auraQueued = true
        C_Timer.After(0.1, FlushAuras)
    end
end

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
    UNIT_AURA = function(f) QueueAuras(f) end,
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
        -- the one who started it is ready (READY_CHECK passes the initiator's name first)
        pcall(function()
            local initiator = unit
            if not initiator or IsSecret(initiator) then return end
            for _, t in ipairs(PARTY_TOKENS) do
                local n = GetUnitName(t, true)
                local short = UnitName(t)
                if (n and not IsSecret(n) and n == initiator) or (short and not IsSecret(short) and short == initiator) then
                    rcAnswers[t] = "ready"
                end
            end
        end)
        RCSay("READY_CHECK from " .. tostring(unit) .. ", members shown: " .. tostring(#members))
        UpdateAllReady()
        return
    elseif event == "READY_CHECK_CONFIRM" then
        local isReady = ...
        pcall(function()
            local t = ToPartyUnit(unit)
            if t and not IsSecret(isReady) then
                rcAnswers[t] = isReady and "ready" or "notready"
            end
            RCSay("CONFIRM " .. tostring(unit) .. " -> " .. tostring(t) .. " = " .. tostring(isReady))
        end)
        UpdateAllReady()
        return
    elseif event == "READY_CHECK_FINISHED" then
        UpdateAllReady()
        readyCheckActive = false
        local stamp = GetTime()
        readyCheckFinishedAt = stamp
        UpdateAllReady()
        RCSay("FINISHED")
        -- keep the result on screen for a few seconds, then fade it out
        C_Timer.After(6, function()
            if readyCheckFinishedAt ~= stamp then return end
            FadeReadyIcons(stamp)
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

-- while a ready check runs, refresh the icons twice a second (in case an event is missed)
do
    local poll = CreateFrame("Frame")
    local acc = 0
    poll:SetScript("OnUpdate", function(_, el)
        if not readyCheckActive then return end
        acc = acc + el
        if acc < 0.5 then return end
        acc = 0
        UpdateAllReady()
    end)
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
    elseif msg:match("^%s*rcdebug") then
        rcDebug = not rcDebug
        print("|cff34D399H3z0 UI:|r Ready check debug " .. (rcDebug and "ON - start a ready check and send me the chat lines" or "OFF"))
        if rcDebug then
            for i, f in ipairs(members) do
                print(string.format("  frame %d: unit=%s shown=%s exists=%s icon=%s",
                    i, tostring(f.displayUnit), tostring(f:IsShown()), tostring(UnitExists(f.displayUnit or "")), tostring(f.ready ~= nil)))
            end
        end
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
