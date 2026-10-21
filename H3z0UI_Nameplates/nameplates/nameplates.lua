--[[
    H3z0 UI - Nameplates

    H3z0 UI's own nameplate look, drawn on top of Blizzard's nameplates:
      - rounded health bar with a thin border, current health on the left and
        the percentage on the right
      - "level | name" above the bar (level in difficulty colour, + for elites,
        ?? for bosses)
      - cast bar under the bar with icon, spell name and time; uninterruptible
        casts turn grey, interrupts flash red
      - target: white border and arrows on both sides
      - Mythic colours in dungeons / raids / delves: boss, mini boss, caster,
        melee, trivial, minus and rare elite each get their own bar colour
      - threat border: red when a non-tank has aggro, orange when a tank lost it

    Midnight / Mythic+ safe: health, names, cast times and interruptible state
    can be secret values in instances. They are only handed straight to widget
    setters (SetValue, SetText, SetTimerDuration, SetAlphaFromBoolean, ...) and
    never compared, so the plates keep working in keys. Blizzard's nameplate
    keeps doing the real work (clicks, auras, raid icons); H3z0 UI only fades
    the parts it replaces (alpha) and never writes into Blizzard's frames.

    Not used while Plater, Platynator, BetterBlizzPlates or Kui are loaded.
    Settings: profile.h3zPlates
]]

local ADDON_NAME, ns = ...

local NP = {}
ns.H3zPlates = NP

local ASSETS = "Interface\\AddOns\\H3z0UI\\assets\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local BAR_TEX = ASSETS .. "H3z0UI_v2"
local ARROW = ASSETS .. "h3z_np_arrow"

NP.FONTS = {
    { value = "global", text = "H3z0 UI font (Default Font)", path = nil },
    { value = "h3z", text = "Poppins SemiBold", path = ASSETS .. "Poppins-SemiBold.ttf" },
    { value = "bold", text = "Poppins Bold", path = ASSETS .. "Poppins-Bold.ttf" },
    { value = "medium", text = "Poppins Medium", path = ASSETS .. "Poppins-Medium.ttf" },
    { value = "expressway", text = "Expressway", path = ASSETS .. "Expressway.TTF" },
    { value = "game", text = "Game font", path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" },
}

local OTHER_PLATE_ADDONS = { "Plater", "Platynator", "BetterBlizzPlates", "Kui_Nameplates", "TidyPlates_ThreatPlates" }

-- default colours (Mythic set follows the popular "Mythic" nameplate colour scheme)
local DEFAULT_COLORS = {
    boss      = { 0.76, 0.60, 0.42, 1 },
    miniboss  = { 1.00, 0.00, 1.00, 1 },
    caster    = { 0.00, 0.75, 1.00, 1 },
    melee     = { 1.00, 0.00, 0.00, 1 },
    trivial   = { 0.37, 0.12, 0.10, 1 },
    minus     = { 0.63, 0.28, 0.17, 1 },
    rareElite = { 0.49, 1.00, 0.74, 1 },
    hostile   = { 0.78, 0.12, 0.12, 1 },
    neutral   = { 1.00, 0.85, 0.10, 1 },
    friendly  = { 0.20, 0.80, 0.30, 1 },
    tapped    = { 0.55, 0.55, 0.55, 1 },
    cast      = { 1.00, 0.84, 0.20, 1 },
    channel   = { 0.49, 1.00, 0.29, 1 },
    noInterrupt = { 0.40, 0.40, 0.40, 1 },
    interrupted = { 1.00, 0.00, 0.02, 1 },
    aggro     = { 1.00, 0.22, 0.22, 1 },
    lostAggro = { 1.00, 0.55, 0.00, 1 },
}
NP.DEFAULT_COLORS = DEFAULT_COLORS

local SETTING_DEFAULTS = {
    enabled = false, width = 150, height = 16, font = "global", nameSize = 11, textSize = 10,
    showLevel = true, showHealth = true, showPercent = true, castbar = true, castHeight = 16,
    mythicColors = "instance", threat = true, arrows = true, friendly = true, rounded = true,
    targetScale = 1.1, matchPlayer = false, unitFrameColors = true,
    instClassColors = true, instNamesOnly = false,
}
local cachedS     -- 0.24.2: the settings table once its defaults are filled in

local function DB()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    if cachedS and p.h3zPlates == cachedS then return cachedS end
    p.h3zPlates = p.h3zPlates or {}
    local s = p.h3zPlates
    for k, v in pairs(SETTING_DEFAULTS) do if s[k] == nil then s[k] = v end end
    -- rollback: the nameplates keep their own look (the unit frames take the nameplate colours instead)
    if not s.matchRollback then
        s.matchRollback = true
        s.matchPlayer = false
        s.unitFrameColors = true
    end
    -- first test build: bigger cast bar and the shared H3z0 UI font
    if not s.migrated1 then
        s.migrated1 = true
        if s.castHeight == 12 then s.castHeight = 16 end
        if s.font == "h3z" then s.font = "global" end
    end
    s.colors = s.colors or {}
    for k, v in pairs(DEFAULT_COLORS) do
        if type(s.colors[k]) ~= "table" then s.colors[k] = { v[1], v[2], v[3], v[4] } end
    end
    cachedS = s
    return s
end
NP.GetSettings = DB

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function S(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) or false end

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i end
    return nil
end

-- true / false, or nil when the answer is secret or unknown
local function Bool(v)
    if v == nil or S(v) then return nil end
    return v and true or false
end

local function FontPath(key)
    for _, f in ipairs(NP.FONTS) do if f.value == key and f.path then return f.path end end
    local ui = _G.H3z0UI
    if ui and ui.GetGlobalFont then
        local ok, path = pcall(ui.GetGlobalFont, ui)
        if ok and path then return path end
    end
    return ASSETS .. "Poppins-SemiBold.ttf"
end

local function Color(key)
    local s = DB()
    local c = s and s.colors[key] or DEFAULT_COLORS[key]
    return c[1], c[2], c[3]
end

-- 0.24.2: cached; cleared when an addon loads, the zone or the spec changes (see the events below)
local otherAddonCache, groupContentCache, tankCache

local function OtherPlateAddon()
    if otherAddonCache ~= nil then return otherAddonCache or nil end
    otherAddonCache = false
    for _, a in ipairs(OTHER_PLATE_ADDONS) do
        if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(a) then otherAddonCache = a break end
    end
    return otherAddonCache or nil
end

local function Active()
    local s = DB()
    return s and s.enabled and not OtherPlateAddon()
end

local function InGroupContent()
    if groupContentCache ~= nil then return groupContentCache end
    local inInst, kind = IsInInstance()
    if S(inInst) then return true end
    groupContentCache = inInst and (kind == "party" or kind == "raid" or kind == "scenario") or false
    return groupContentCache
end

local function MythicColorsOn()
    local s = DB()
    if not s then return false end
    if s.mythicColors == "always" then return true end
    if s.mythicColors == "off" then return false end
    return InGroupContent()
end

local function PlayerIsTank()
    if tankCache ~= nil then return tankCache end
    if not (GetSpecialization and GetSpecializationRole) then return false end
    local spec = GetSpecialization()
    tankCache = spec and GetSpecializationRole(spec) == "TANK" or false
    return tankCache
end

do
    local cf = CreateFrame("Frame")
    for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
        "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ROLES_ASSIGNED" }) do pcall(cf.RegisterEvent, cf, e) end
    cf:SetScript("OnEvent", function(_, e)
        if e == "ADDON_LOADED" then otherAddonCache = nil return end
        groupContentCache, tankCache = nil, nil
        if e == "PLAYER_ENTERING_WORLD" then otherAddonCache = nil end
    end)
end

---------------------------------------------------------------------------
-- Hide the parts of Blizzard's nameplate that H3z0 UI replaces (alpha only;
-- auras, raid icon and the clickable area stay Blizzard's)
---------------------------------------------------------------------------
local HIDE_KEYS = { "HealthBarsContainer", "healthBar", "castBar", "CastBar", "name", "selectionHighlight",
    "aggroHighlight", "ClassificationFrame", "LevelFrame", "LoseAggroFlash", "ExtraIndicators" }

local function AlphaHook(self, a)
    if self.h3zNPHidden and (S(a) or a ~= 0) then self:SetAlpha(0) end
end

local function SetHidden(region, hidden)
    if not (region and region.SetAlpha) then return end
    if hidden then
        region.h3zNPHidden = true
        if not region.h3zNPHook then
            region.h3zNPHook = true
            hooksecurefunc(region, "SetAlpha", AlphaHook)
        end
        region:SetAlpha(0)
    elseif region.h3zNPHidden then
        region.h3zNPHidden = nil
        region:SetAlpha(1)
    end
end

-- Blizzard's cast bar fades in with an animation (that doesn't go through SetAlpha),
-- so cast bars are also kept at 0 while they show
local function CastAlphaGuard(self)
    if self.h3zNPHidden and self:GetAlpha() > 0 then self:SetAlpha(0) end
end

local function IsCastBar(f)
    if not (f and f.IsObjectType and f:IsObjectType("StatusBar")) then return false end
    if f.h3zNPOwn then return false end
    return (f.Icon ~= nil or f.Spark ~= nil or f.Text ~= nil or f.BorderShield ~= nil or f.castID ~= nil)
end

-- every piece of Blizzard's cast bar (fill, spark, icon, text, shield, interrupt flash ...) is
-- faded too: the interrupt flash animates the bar itself, so hiding only the bar isn't enough
local function FadeCastPieces(frame, hidden, depth)
    depth = depth or 0
    if depth > 3 then return end
    -- the flashes are alpha animations that would show a piece again: stop them while hidden
    if hidden and frame.GetAnimationGroups then
        for _, ag in ipairs({ frame:GetAnimationGroups() }) do
            if ag.IsPlaying and ag:IsPlaying() then pcall(ag.Stop, ag) end
        end
    end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.SetAlpha then
            if hidden then
                if r.h3zNPA == nil then r.h3zNPA = r:GetAlpha() end
                r:SetAlpha(0)
            elseif r.h3zNPA ~= nil then
                r:SetAlpha(r.h3zNPA); r.h3zNPA = nil
            end
        end
    end
    for _, c in ipairs({ frame:GetChildren() }) do
        if c.SetAlpha and not c.h3zNPOwn then
            if hidden then
                if c.h3zNPA == nil then c.h3zNPA = c:GetAlpha() end
                c:SetAlpha(0)
            elseif c.h3zNPA ~= nil then
                c:SetAlpha(c.h3zNPA); c.h3zNPA = nil
            end
            FadeCastPieces(c, hidden, depth + 1)
        end
    end
    if frame.GetStatusBarTexture then
        local t = frame:GetStatusBarTexture()
        if t and t.SetAlpha then
            if hidden then t:SetAlpha(0) elseif t.h3zNPA ~= nil then t:SetAlpha(t.h3zNPA); t.h3zNPA = nil end
        end
    end
end

-- 0.24.2: the pieces are collected once per cast start; the fast tick only walks that list
-- (no new tables 20 times a second for every casting nameplate)
local function CollectPieces(frame, pieces, anims, depth)
    if depth > 3 then return end
    if frame.GetAnimationGroups then
        for _, ag in ipairs({ frame:GetAnimationGroups() }) do anims[#anims + 1] = ag end
    end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.SetAlpha then pieces[#pieces + 1] = r end
    end
    for _, c in ipairs({ frame:GetChildren() }) do
        if c.SetAlpha and not c.h3zNPOwn then
            pieces[#pieces + 1] = c
            CollectPieces(c, pieces, anims, depth + 1)
        end
    end
end

local function CacheCastPieces(bar)
    local pieces, anims = bar.h3zNPPieces or {}, bar.h3zNPAnims or {}
    wipe(pieces); wipe(anims)
    pcall(CollectPieces, bar, pieces, anims, 0)
    bar.h3zNPPieces, bar.h3zNPAnims = pieces, anims
end

local function QuickFadeCastPieces(bar)
    local pieces = bar.h3zNPPieces
    if not pieces then
        FadeCastPieces(bar, true)
        CacheCastPieces(bar)
        return
    end
    for i = 1, #bar.h3zNPAnims do
        local ag = bar.h3zNPAnims[i]
        if ag:IsPlaying() then ag:Stop() end
    end
    for i = 1, #pieces do
        local r = pieces[i]
        local a = r:GetAlpha()
        if a > 0 then
            if r.h3zNPA == nil then r.h3zNPA = a end
            r:SetAlpha(0)
        end
    end
    local t = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if t and t.SetAlpha and t:GetAlpha() > 0 then
        if t.h3zNPA == nil then t.h3zNPA = t:GetAlpha() end
        t:SetAlpha(0)
    end
end

local function CastPiecesGuard(self)
    if self.h3zNPHidden then
        pcall(FadeCastPieces, self, true)
        CacheCastPieces(self)
    end
end

local function CastPiecesTick(self, elapsed)
    if not self.h3zNPHidden then return end
    self.h3zNPTick = (self.h3zNPTick or 0) + (elapsed or 0)
    if self.h3zNPTick < 0.05 then return end
    self.h3zNPTick = 0
    pcall(QuickFadeCastPieces, self)
end

local function SetCastHidden(bar, hidden)
    pcall(SetHidden, bar, hidden)
    pcall(FadeCastPieces, bar, hidden)
    if hidden and not bar.h3zNPGuard then
        bar.h3zNPGuard = true
        bar:HookScript("OnShow", CastAlphaGuard)
        bar:HookScript("OnShow", CastPiecesGuard)
        bar:HookScript("OnUpdate", CastAlphaGuard)
        bar:HookScript("OnUpdate", CastPiecesTick)
        -- the interrupt / finish flashes re-show pieces: fade them again when a cast event arrives
        if bar.HookScript and bar:HasScript("OnEvent") then bar:HookScript("OnEvent", CastPiecesGuard) end
    end
end

local function FindCastBars(frame, list, depth)
    if not frame or frame.h3zNPOwn or depth > 3 then return end
    for _, c in ipairs({ frame:GetChildren() }) do
        if IsCastBar(c) then
            list[#list + 1] = c
        elseif not c.h3zNPOwn then
            FindCastBars(c, list, depth + 1)
        end
    end
end

-- 0.24.4: the level box of Blizzard's nameplate has other names on WoW: Forever / Classic
-- (levelText, LevelFrame on the health bar, ...): every part named "level" on the plate, its
-- health bar or its health container is hidden too (our name line shows the level)
local function LevelParts(uf)
    local list = uf.h3zNPLevelParts
    if list then return list end
    list = {}
    local seen = {}
    local function Scan(t)
        if type(t) ~= "table" then return end
        for k, v in pairs(t) do
            if type(k) == "string" and type(v) == "table" and not seen[v] and k:lower():find("level", 1, true)
                and v.SetAlpha and not v.h3zNPOwn then
                seen[v] = true
                list[#list + 1] = v
            end
        end
    end
    Scan(uf)
    Scan(uf.healthBar)
    Scan(uf.HealthBarsContainer)
    if uf.HealthBarsContainer then Scan(uf.HealthBarsContainer.healthBar) end
    if #list > 0 then uf.h3zNPLevelParts = list end   -- nothing found yet: look again next time
    return list
end

local function HideBlizzard(uf, hidden, castToo)
    if not uf then return end
    for _, k in ipairs(HIDE_KEYS) do
        local r = uf[k]
        if type(r) == "table" and r.SetAlpha and k ~= "castBar" and k ~= "CastBar" then pcall(SetHidden, r, hidden) end
    end
    local lv = LevelParts(uf)
    for i = 1, #lv do pcall(SetHidden, lv[i], hidden) end
    local bars = uf.h3zNPCastBars
    if not bars then
        bars = {}
        for _, k in ipairs({ "castBar", "CastBar" }) do
            if type(uf[k]) == "table" and uf[k].SetAlpha then bars[#bars + 1] = uf[k] end
        end
        local np = uf:GetParent()
        FindCastBars(uf, bars, 0)
        if np then FindCastBars(np, bars, 1) end
        uf.h3zNPCastBars = bars
    end
    for i = 1, #bars do SetCastHidden(bars[i], hidden and castToo) end
end

-- where Blizzard's own health bar sits, so ours lands in the same spot
local function BlizzBar(uf)
    if not uf then return nil end
    local c = uf.HealthBarsContainer
    if c and c.healthBar then return c.healthBar end
    return uf.healthBar or c
end

---------------------------------------------------------------------------
-- Plate objects
---------------------------------------------------------------------------
local plates = {}          -- unit -> plate
local pool = {}            -- namePlate -> plate

local function Masks(owner, target, r, inset, key)
    local Round = ns.Round
    if not Round then return nil end
    return Round.CornerMasks(owner, target, r, inset, key)
end

local function Shape(plate)
    local s = DB()
    local Round = ns.Round
    if not (s and Round) then return end
    local r = s.rounded and math.max(2, math.min(s.height / 2, 5)) or 1
    plate.border:SetRadius(r)
    local inner = Masks(plate.hp, plate.border, r, 1, "h3zNPInner")
    for _, t in ipairs({ plate.hp:GetStatusBarTexture(), plate.hpBg }) do Round.Mask(t, inner, s.rounded) end

    local cr = s.rounded and math.max(2, math.min(s.castHeight / 2, 4)) or 1
    plate.castBorder:SetRadius(cr)
    local cinner = Masks(plate.cast, plate.castBorder, cr, 1, "h3zNPCastInner")
    for _, t in ipairs({ plate.cast:GetStatusBarTexture(), plate.castBg, plate.castLock }) do
        Round.Mask(t, cinner, s.rounded)
    end
end

-- "Match Player Frame": the same bar texture and background as H3z0 UI's player frame
local function PlayerLook()
    local s = DB()
    local tex, bg = BAR_TEX, { 0.17, 0.19, 0.22, 1 }
    if not (s and s.matchPlayer) then return tex, bg end
    local core = ns.Addon
    local prof = core and core.db and core.db.profile
    local uf = prof and prof.h3z0uiUnitFrames
    local player = uf and uf.player
    local general = uf and uf.general
    local name = (player and player.texture ~= "" and player.texture) or (prof and prof.general and prof.general.texture)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if name and LSM then tex = LSM:Fetch("statusbar", name, true) or tex end
    if general and general.darkMode then
        bg = general.darkModeBgColor or { 0.25, 0.25, 0.25, 1 }
    else
        bg = { 0.1, 0.1, 0.1, 0.9 }
    end
    return tex, bg
end

local function Layout(plate)
    local s = DB()
    if not s then return end
    local font = FontPath(s.font)
    local W, H = s.width, s.height
    local anchor = BlizzBar(plate.namePlate.UnitFrame) or plate.namePlate
    local tex, bg = PlayerLook()
    plate.hp:SetStatusBarTexture(tex)
    plate.hpBg:SetColorTexture(bg[1], bg[2], bg[3], 1)
    plate.cast:SetStatusBarTexture(tex)
    plate.castLock:SetTexture(tex)
    plate.castBg:SetColorTexture(bg[1], bg[2], bg[3], 1)

    plate.border:ClearAllPoints()
    plate.border:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    plate.border:SetSize(W, H)
    plate.hp:ClearAllPoints()
    plate.hp:SetPoint("TOPLEFT", plate.border, "TOPLEFT", 1, -1)
    plate.hp:SetPoint("BOTTOMRIGHT", plate.border, "BOTTOMRIGHT", -1, 1)

    plate.name:SetFont(font, s.nameSize, "OUTLINE")
    plate.name:ClearAllPoints()
    plate.name:SetPoint("BOTTOM", plate.border, "TOP", 0, 3)
    plate.name:SetWidth(W + 40)
    plate.hpText:SetFont(font, s.textSize, "OUTLINE")
    plate.pctText:SetFont(font, s.textSize, "OUTLINE")
    plate.hpText:SetShown(s.showHealth)
    plate.pctText:SetShown(s.showPercent)
    plate.hpText:ClearAllPoints()
    if s.matchPlayer and s.showPercent then
        plate.hpText:SetPoint("RIGHT", plate.pctText, "LEFT", -3, 0)
        plate.hpText:SetJustifyH("RIGHT")
    else
        plate.hpText:SetPoint("LEFT", plate.border, "LEFT", 5, 0)
        plate.hpText:SetJustifyH("LEFT")
    end

    local ah = H + 4
    plate.arrowL:SetSize(ah * 2, ah)
    plate.arrowR:SetSize(ah * 2, ah)
    plate.arrowL:ClearAllPoints()
    plate.arrowL:SetPoint("RIGHT", plate.border, "LEFT", -2, 0)
    plate.arrowR:ClearAllPoints()
    plate.arrowR:SetPoint("LEFT", plate.border, "RIGHT", 2, 0)

    local CH = s.castHeight
    plate.castBorder:ClearAllPoints()
    plate.castBorder:SetPoint("TOPLEFT", plate.border, "BOTTOMLEFT", CH + 2, -3)
    plate.castBorder:SetPoint("TOPRIGHT", plate.border, "BOTTOMRIGHT", 0, -3)
    plate.castBorder:SetHeight(CH)
    plate.cast:ClearAllPoints()
    plate.cast:SetPoint("TOPLEFT", plate.castBorder, "TOPLEFT", 1, -1)
    plate.cast:SetPoint("BOTTOMRIGHT", plate.castBorder, "BOTTOMRIGHT", -1, 1)
    plate.castIcon:SetSize(CH, CH)
    plate.castIcon:ClearAllPoints()
    plate.castIcon:SetPoint("TOPRIGHT", plate.castBorder, "TOPLEFT", -2, 0)
    local cfs = math.max(7, math.min(CH - 3, s.textSize + 2))
    plate.castText:SetFont(font, cfs, "OUTLINE")
    plate.castTime:SetFont(font, cfs, "OUTLINE")
    Shape(plate)
end

local function Create(namePlate)
    local p = CreateFrame("Frame", nil, namePlate)
    p:SetAllPoints(namePlate)
    p:EnableMouse(false)
    p.h3zNPOwn = true
    p.namePlate = namePlate

    local Round = ns.Round
    p.border = Round.Panel(p, 4)
    p.border:SetFillColor(0, 0, 0, 1)
    p.border:SetBorderColor(0, 0, 0, 0)

    p.hp = CreateFrame("StatusBar", nil, p.border)
    p.hp.h3zNPOwn = true
    p.hp:SetStatusBarTexture(BAR_TEX)
    p.hp:SetMinMaxValues(0, 1)
    p.hp:SetValue(1)
    p.hpBg = p.hp:CreateTexture(nil, "BACKGROUND")
    p.hpBg:SetAllPoints()
    p.hpBg:SetColorTexture(0.17, 0.19, 0.22, 1)

    local textLayer = CreateFrame("Frame", nil, p.border)
    textLayer:SetAllPoints(p.border)
    textLayer:SetFrameLevel(p.hp:GetFrameLevel() + 2)
    p.hpText = textLayer:CreateFontString(nil, "OVERLAY")
    p.hpText:SetPoint("LEFT", p.border, "LEFT", 5, 0)
    p.hpText:SetJustifyH("LEFT")
    p.pctText = textLayer:CreateFontString(nil, "OVERLAY")
    p.pctText:SetPoint("RIGHT", p.border, "RIGHT", -5, 0)
    p.pctText:SetJustifyH("RIGHT")
    p.name = textLayer:CreateFontString(nil, "OVERLAY")
    p.name:SetJustifyH("CENTER")
    p.name:SetWordWrap(false)

    p.arrowL = p:CreateTexture(nil, "OVERLAY")
    p.arrowL:SetTexture(ARROW)
    p.arrowR = p:CreateTexture(nil, "OVERLAY")
    p.arrowR:SetTexture(ARROW)
    p.arrowR:SetTexCoord(1, 0, 0, 1)

    -- cast bar
    p.castBorder = Round.Panel(p, 3)
    p.castBorder:SetFillColor(0, 0, 0, 1)
    p.castBorder:SetBorderColor(0, 0, 0, 0)
    p.cast = CreateFrame("StatusBar", nil, p.castBorder)
    p.cast.h3zNPOwn = true
    p.cast:SetStatusBarTexture(BAR_TEX)
    p.cast:SetMinMaxValues(0, 1)
    p.castBg = p.cast:CreateTexture(nil, "BACKGROUND")
    p.castBg:SetAllPoints()
    p.castBg:SetColorTexture(0.12, 0.12, 0.14, 1)
    -- grey overlay for "can't be interrupted" (alpha from the secret-safe boolean)
    p.castLock = p.cast:CreateTexture(nil, "ARTWORK", nil, 3)
    p.castLock:SetTexture(BAR_TEX)
    p.castLock:SetPoint("TOPLEFT", p.cast:GetStatusBarTexture(), "TOPLEFT")
    p.castLock:SetPoint("BOTTOMRIGHT", p.cast:GetStatusBarTexture(), "BOTTOMRIGHT")
    p.castLock:SetAlpha(0)
    local ctl = CreateFrame("Frame", nil, p.castBorder)
    ctl:SetAllPoints(p.castBorder)
    ctl:SetFrameLevel(p.cast:GetFrameLevel() + 2)
    p.castText = ctl:CreateFontString(nil, "OVERLAY")
    p.castText:SetPoint("LEFT", p.castBorder, "LEFT", 4, 0)
    p.castText:SetPoint("RIGHT", p.castBorder, "RIGHT", -30, 0)
    p.castText:SetJustifyH("LEFT")
    p.castText:SetWordWrap(false)
    p.castTime = ctl:CreateFontString(nil, "OVERLAY")
    p.castTime:SetPoint("RIGHT", p.castBorder, "RIGHT", -4, 0)
    p.castTime:SetJustifyH("RIGHT")
    p.castIcon = p:CreateTexture(nil, "OVERLAY")
    p.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.castBorder:Hide()
    p.castIcon:Hide()

    pool[namePlate] = p
    Layout(p)
    p.h3zLayoutGen = NP.layoutGen
    return p
end

---------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------
local function UpdateHealth(p)
    local u = p.unit
    local s = DB()
    local max, cur = UnitHealthMax(u), UnitHealth(u)
    pcall(p.hp.SetMinMaxValues, p.hp, 0, max)
    pcall(p.hp.SetValue, p.hp, cur)
    if s.showHealth then
        local txt = Safe(AbbreviateNumbers, cur)
        local joined = s.matchPlayer and s.showPercent
        if joined and txt ~= nil and pcall(p.hpText.SetFormattedText, p.hpText, "%s |", txt) then
            -- "728K | 100%" on the right, like the player frame
        elseif txt == nil or not pcall(p.hpText.SetText, p.hpText, txt) then
            if not pcall(p.hpText.SetFormattedText, p.hpText, "%d", cur) then p.hpText:SetText("") end
        end
    end
    if s.showPercent then
        local done = false
        if UnitHealthPercent then
            local curve = CurveConstants and CurveConstants.ScaleTo100
            local pct = Safe(UnitHealthPercent, u, true, curve)
            if pct ~= nil then
                if curve then
                    done = pcall(p.pctText.SetFormattedText, p.pctText, "%.0f%%", pct)
                elseif not S(pct) then
                    done = pcall(p.pctText.SetFormattedText, p.pctText, "%.0f%%", pct <= 1 and pct * 100 or pct)
                end
            end
        end
        if not done then
            if not S(cur) and not S(max) and max and max > 0 then
                p.pctText:SetFormattedText("%.0f%%", cur / max * 100)
            else
                p.pctText:SetText("")
            end
        end
    end
end

local function LevelText(u)
    local lvl = UnitEffectiveLevel and UnitEffectiveLevel(u) or UnitLevel(u)
    if lvl == nil or S(lvl) then return nil end
    local cls = UnitClassification(u)
    if S(cls) then cls = nil end
    if lvl <= 0 then return "??", 1, 0.2, 0.2 end
    local txt = tostring(lvl)
    if cls == "elite" or cls == "rareelite" or cls == "worldboss" then txt = txt .. "+" end
    if cls == "rare" then txt = txt .. "R" end
    local c = GetCreatureDifficultyColor and GetCreatureDifficultyColor(lvl)
    if c then return txt, c.r, c.g, c.b end
    return txt, 1, 0.82, 0
end

local function UpdateName(p)
    local u = p.unit
    local s = DB()
    local name = UnitName(u)
    local lvl, r, g, b
    if s.showLevel then lvl, r, g, b = LevelText(u) end
    local ok = false
    if lvl then
        ok = pcall(p.name.SetFormattedText, p.name, "|cff%02x%02x%02x%s|r | %s",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), lvl, name)
    end
    if not ok then pcall(p.name.SetText, p.name, name) end
end

-- Mythic unit type from level / classification / mana (no NPC lists needed)
local function MythicType(u)
    local cls = UnitClassification(u)
    if S(cls) then return nil end
    local lvl = UnitEffectiveLevel and UnitEffectiveLevel(u) or UnitLevel(u)
    if S(lvl) then lvl = nil end
    local base = UnitEffectiveLevel and UnitEffectiveLevel("player") or UnitLevel("player")
    local caster
    if UnitHasPowerType and Enum and Enum.PowerType then
        caster = Bool(Safe(UnitHasPowerType, u, Enum.PowerType.Mana))
    end
    if caster == nil then
        local pt = UnitPowerType(u)
        local pm = UnitPowerMax(u, 0)
        caster = (not S(pt) and not S(pm) and pt == 0 and (pm or 0) > 0) or false
    end
    if cls == "rareelite" then return "rareElite" end
    if cls == "worldboss" or (lvl and lvl <= 0) or Bool(Safe(UnitIsBossMob, u)) or Bool(Safe(UnitIsQuestBoss, u)) then
        return "boss"
    end
    if cls == "elite" then
        if lvl and base and lvl >= base + 2 then return "boss" end
        if Bool(Safe(UnitIsLieutenant, u)) or (lvl and base and lvl == base + 1) then return "miniboss" end
        return caster and "caster" or "melee"
    end
    if cls == "trivial" then return caster and "caster" or "trivial" end
    if cls == "minus" then return caster and "caster" or "minus" end
    return caster and "caster" or "melee"
end

-- The nameplate colour of a unit (also used by the H3z0 unit frames: Player, Target, ...)
function NP.ColorFor(u)
    local key
    if Bool(UnitIsTapDenied(u)) then
        key = "tapped"
    elseif Bool(UnitIsPlayer(u)) then
        local _, class = UnitClass(u)
        local c = class and not S(class) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        local enemy = Bool(UnitCanAttack("player", u))
        if c and (enemy or Bool(UnitIsFriend("player", u)) or Bool(UnitIsUnit(u, "player"))) then
            return c.r, c.g, c.b
        end
        key = enemy and "hostile" or "friendly"
    else
        local reaction = UnitReaction(u, "player")
        if reaction == nil or S(reaction) then
            key = Bool(UnitCanAttack("player", u)) and "hostile" or "neutral"
        elseif reaction >= 5 then
            key = "friendly"
        elseif reaction == 4 then
            key = "neutral"
        else
            key = "hostile"
        end
        if key == "hostile" or (key == "neutral" and Bool(UnitAffectingCombat(u))) then
            if MythicColorsOn() then key = MythicType(u) or "hostile" end
        end
    end
    return Color(key)
end

local function UpdateColor(p)
    p.hp:SetStatusBarColor(NP.ColorFor(p.unit))
end

local function UpdateBorder(p)
    local s = DB()
    local isTarget = p.isTarget
    local key = (isTarget and "T" or "-") .. (s.arrows and "A" or "-") .. ((s.threat and p.threat) or "")
    if p.h3zBorderKey == key and p.h3zBorderGen == NP.layoutGen then return end
    p.h3zBorderKey, p.h3zBorderGen = key, NP.layoutGen
    p.arrowL:SetShown(isTarget and s.arrows)
    p.arrowR:SetShown(isTarget and s.arrows)
    if isTarget then
        p.border:SetFillColor(0.95, 0.95, 0.95, 1)
        return
    end
    local threat = s.threat and p.threat
    if threat then
        p.border:SetFillColor(Color(threat))
    else
        p.border:SetFillColor(0, 0, 0, 1)
    end
end

local function UpdateThreat(p)
    local s = DB()
    p.threat = nil
    if s.threat and not Bool(UnitIsPlayer(p.unit)) and Bool(UnitAffectingCombat(p.unit)) then
        local status = UnitThreatSituation("player", p.unit)
        if status ~= nil and not S(status) then
            if PlayerIsTank() then
                if status < 2 and (IsInGroup() or IsInRaid()) then p.threat = "lostAggro" end
            elseif status >= 2 then
                p.threat = "aggro"
            end
        end
    end
    UpdateBorder(p)
end

local function UpdateTarget(p, tp)
    if tp == nil then tp = C_NamePlate.GetNamePlateForUnit("target") end
    p.isTarget = (tp ~= nil and tp == p.namePlate)
    local s = DB()
    local sc = p.isTarget and (s.targetScale or 1) or 1
    p.border:SetScale(sc)
    p.castBorder:SetScale(1)
    UpdateBorder(p)
end

---------------------------------------------------------------------------
-- Cast bar
---------------------------------------------------------------------------
local function CastOnUpdate(self, elapsed)
    local p = self.plate
    self.tick = (self.tick or 0) + elapsed
    if self.tick < 0.05 then return end
    self.tick = 0
    if p.castDuration and p.castDuration.GetRemainingDuration then
        local rem = Safe(p.castDuration.GetRemainingDuration, p.castDuration)
        if rem ~= nil then pcall(p.castTime.SetFormattedText, p.castTime, "%.1f", rem) end
        return
    end
    if p.castStart and p.castEnd then
        local now = GetTime() * 1000
        local total = p.castEnd - p.castStart
        if total <= 0 then return end
        local done = (now - p.castStart) / total
        if done > 1 then done = 1 end
        p.cast:SetValue(p.castChannel and (1 - done) or done)
        p.castTime:SetFormattedText("%.1f", math.max(0, (p.castEnd - now) / 1000))
    end
end

local function HideCast(p)
    p.castBorder:Hide()
    p.castIcon:Hide()
    p.castDuration, p.castStart, p.castEnd = nil, nil, nil
end

local function Present(v)
    if S(v) then return true end
    return v ~= nil
end

local function UpdateCast(p)
    local s = DB()
    local u = p.unit
    if not s.castbar then HideCast(p) return end
    if p.interruptedUntil and GetTime() < p.interruptedUntil then return end

    local channel = false
    local name, text, tex, st, et, _, _, notInt = UnitCastingInfo(u)
    if not Present(name) then
        name, text, tex, st, et, _, notInt = UnitChannelInfo(u)
        channel = Present(name)
    end
    if not Present(name) then HideCast(p) return end

    p.castChannel = channel
    p.cast:SetStatusBarColor(Color(channel and "channel" or "cast"))
    p.castLock:SetVertexColor(Color("noInterrupt"))
    if S(notInt) then
        if p.castLock.SetAlphaFromBoolean then pcall(p.castLock.SetAlphaFromBoolean, p.castLock, notInt, 1, 0) end
    else
        p.castLock:SetAlpha(notInt and 1 or 0)
    end
    if not pcall(p.castText.SetText, p.castText, text or name) then pcall(p.castText.SetText, p.castText, name) end
    pcall(p.castIcon.SetTexture, p.castIcon, tex)

    -- progress: Midnight duration objects first, plain times otherwise
    p.castDuration, p.castStart, p.castEnd = nil, nil, nil
    local durFn = channel and _G.UnitChannelDuration or _G.UnitCastingDuration
    local dur = durFn and Safe(durFn, u)
    local timed = false
    if dur and p.cast.SetTimerDuration then
        local dir = Enum and Enum.StatusBarTimerDirection
        local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
        timed = pcall(p.cast.SetTimerDuration, p.cast, dur, interp,
            dir and (channel and dir.RemainingTime or dir.ElapsedTime) or nil)
        if timed then p.castDuration = dur end
    end
    if not timed then
        p.cast:SetMinMaxValues(0, 1)
        if st and et and not S(st) and not S(et) then
            p.castStart, p.castEnd = st, et
        else
            p.cast:SetValue(1)
            p.castTime:SetText("")
        end
    end
    p.castBorder:Show()
    p.castIcon:Show()
end

-- interrupt in the same bar and style as the cast: full red bar, "Interrupted: <name>"
-- (the interrupter in class colour when the game tells who it was)
local function InterrupterName(guid)
    if not guid or S(guid) or guid == "" or not GetPlayerInfoByGUID then return nil end
    local ok, _, class, _, _, _, name = pcall(GetPlayerInfoByGUID, guid)
    if not ok or not name or S(name) then return nil end
    local c = class and not S(class) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    if c then return string.format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), name) end
    return name
end

local function CastInterrupted(p, _, _, interruptedBy)
    local s = DB()
    if not s.castbar then return end
    p.castDuration, p.castStart, p.castEnd = nil, nil, nil
    p.cast:SetMinMaxValues(0, 1)
    p.cast:SetValue(1)
    p.cast:SetStatusBarColor(Color("interrupted"))
    p.castLock:SetAlpha(0)
    local who = InterrupterName(interruptedBy)
    local label = INTERRUPTED or "Interrupted"
    p.castText:SetText(who and (label .. ": " .. who) or label)
    p.castTime:SetText("")
    p.castBorder:Show()
    p.castIcon:Show()
    p.interruptedUntil = GetTime() + 0.9
    C_Timer.After(0.95, function()
        if p.unit then
            p.interruptedUntil = nil
            UpdateCast(p)
        end
    end)
end

---------------------------------------------------------------------------
-- Add / remove
---------------------------------------------------------------------------
local function FullUpdate(p)
    pcall(UpdateName, p)
    pcall(UpdateHealth, p)
    pcall(UpdateColor, p)
    pcall(UpdateTarget, p)
    pcall(UpdateThreat, p)
    pcall(UpdateCast, p)
end

local function OnAdded(unit)
    if not Active() then return end
    if Bool(UnitIsUnit(unit, "player")) then return end
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    if not np or (np.IsForbidden and np:IsForbidden()) then return end
    local s = DB()
    if not s.friendly and not Bool(UnitCanAttack("player", unit)) then return end
    local p = pool[np] or Create(np)
    p.unit = unit
    plates[unit] = p
    HideBlizzard(np.UnitFrame, true, s.castbar)
    p.cast.plate = p
    p.cast:SetScript("OnUpdate", CastOnUpdate)
    if p.h3zLayoutGen ~= NP.layoutGen then
        Layout(p)
        p.h3zLayoutGen = NP.layoutGen
    end
    p:Show()
    FullUpdate(p)
end

local function OnRemoved(unit)
    local p = plates[unit]
    if not p then return end
    plates[unit] = nil
    p.unit = nil
    p.cast:SetScript("OnUpdate", nil)
    HideCast(p)
    p:Hide()
end

local function RestoreAll()
    for unit in pairs(plates) do OnRemoved(unit) end
    for np in pairs(pool) do
        if np.UnitFrame then HideBlizzard(np.UnitFrame, false, false) end
    end
end

NP.layoutGen = 1
function NP.Refresh()
    NP.layoutGen = (NP.layoutGen or 1) + 1   -- settings may have changed: lay every plate out again
    RestoreAll()
    if not Active() then return end
    for _, np in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unit = np.namePlateUnitToken or (np.UnitFrame and np.UnitFrame.unit)
        if unit and not S(unit) then pcall(OnAdded, unit) end
    end
end
_G.H3z0UI_RefreshPlates = NP.Refresh

function NP.Toggle()
    local s = DB()
    if not s then return nil end
    s.enabled = not s.enabled
    NP.Refresh()
    return s.enabled
end
_G.H3z0UI_TogglePlates = NP.Toggle

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local UNIT_EVENTS = {
    UNIT_HEALTH = function(p) UpdateHealth(p) end,
    UNIT_MAXHEALTH = function(p) UpdateHealth(p) end,
    UNIT_NAME_UPDATE = function(p) UpdateName(p) end,
    UNIT_LEVEL = function(p) UpdateName(p); UpdateColor(p) end,
    UNIT_CLASSIFICATION_CHANGED = function(p) UpdateName(p); UpdateColor(p) end,
    UNIT_FACTION = function(p) UpdateColor(p) end,
    UNIT_FLAGS = function(p) UpdateColor(p); UpdateThreat(p) end,
    UNIT_THREAT_LIST_UPDATE = function(p) UpdateThreat(p) end,
    UNIT_THREAT_SITUATION_UPDATE = function(p) UpdateThreat(p) end,
    UNIT_SPELLCAST_START = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_DELAYED = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_STOP = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_SUCCEEDED = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_FAILED = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_INTERRUPTED = function(p, ...) CastInterrupted(p, ...) end,
    UNIT_SPELLCAST_CHANNEL_START = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_CHANNEL_UPDATE = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_CHANNEL_STOP = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_EMPOWER_START = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_EMPOWER_STOP = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_INTERRUPTIBLE = function(p) UpdateCast(p) end,
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function(p) UpdateCast(p) end,
}

local ev = CreateFrame("Frame")
for e in pairs(UNIT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_SPECIALIZATION_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        pcall(OnAdded, unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        OnRemoved(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        local tp = C_NamePlate.GetNamePlateForUnit("target") or false
        for _, p in pairs(plates) do pcall(UpdateTarget, p, tp) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, NP.Refresh)
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        for _, p in pairs(plates) do pcall(UpdateThreat, p); pcall(UpdateColor, p) end
    else
        if not unit or S(unit) then return end
        local p = plates[unit]
        local fn = p and UNIT_EVENTS[event]
        if fn then pcall(fn, p, ...) end
    end
end)


---------------------------------------------------------------------------
-- Friendly nameplates inside dungeons / raids / delves
-- The game locks friendly nameplates in instances (no addon can restyle them), so
-- H3z0 UI only flips Blizzard's own settings there: class colours and, if wanted,
-- names only. Your own values come back when you leave the instance.
---------------------------------------------------------------------------
local INST_CVARS = {
    instClassColors = { name = "ShowClassColorInFriendlyNameplate", on = "1" },
    instNamesOnly   = { name = "nameplateShowOnlyNames", on = "1" },
}
local instSaved = nil      -- cvar -> value before entering the instance
local instPending = false

local function GetCV(n)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(n) end
    return GetCVar and GetCVar(n)
end
local function SetCV(n, v)
    if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, n, v) end
    return pcall(SetCVar, n, v)
end

local function ApplyInstanceFriendly()
    if InCombatLockdown() then instPending = true return end
    instPending = false
    local s = DB()
    if not s then return end
    local inside = InGroupContent()
    if inside then
        for key, cv in pairs(INST_CVARS) do
            if s[key] and GetCV(cv.name) ~= nil then
                instSaved = instSaved or {}
                if instSaved[cv.name] == nil then instSaved[cv.name] = GetCV(cv.name) end
                if GetCV(cv.name) ~= cv.on then SetCV(cv.name, cv.on) end
            elseif instSaved and instSaved[cv.name] ~= nil then
                SetCV(cv.name, instSaved[cv.name]); instSaved[cv.name] = nil
            end
        end
    elseif instSaved then
        for n, v in pairs(instSaved) do SetCV(n, v) end
        instSaved = nil
    end
    -- remember across a reload / crash inside the instance
    s.instSaved = instSaved
end
NP.ApplyInstanceFriendly = ApplyInstanceFriendly
_G.H3z0UI_ApplyInstanceFriendly = ApplyInstanceFriendly

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if instPending then ApplyInstanceFriendly() end
            return
        end
        if event == "PLAYER_ENTERING_WORLD" and instSaved == nil then
            local s = DB()
            if s and type(s.instSaved) == "table" then instSaved = s.instSaved end
        end
        C_Timer.After(1, ApplyInstanceFriendly)
    end)
end

---------------------------------------------------------------------------
-- Stacking / overlap (0.24.4): the game's own nameplate spacing - stacked or overlapping, and
-- how close plates may sit (vertical / horizontal). Works for every nameplate, H3z0 or not.
-- Only touched once you change it in the options (stackManaged), then kept on every login.
---------------------------------------------------------------------------
local STACK_CVARS = { motion = "nameplateMotion", v = "nameplateOverlapV", h = "nameplateOverlapH" }
local stackPending = false

function NP.StackingAvailable()
    return GetCV(STACK_CVARS.v) ~= nil or GetCV(STACK_CVARS.motion) ~= nil
end

-- read the current game values into the settings (before the player has changed anything)
function NP.ReadStacking()
    local s = DB()
    if not s or s.stackManaged then return end
    local m = tonumber(GetCV(STACK_CVARS.motion) or "")
    if m then s.stackMode = (m == 1) and "stack" or "overlap" end
    s.overlapV = tonumber(GetCV(STACK_CVARS.v) or "") or s.overlapV or 1.1
    s.overlapH = tonumber(GetCV(STACK_CVARS.h) or "") or s.overlapH or 0.8
end

function NP.ApplyStacking()
    local s = DB()
    if not (s and s.stackManaged) then return end
    if InCombatLockdown() then stackPending = true return end
    stackPending = false
    if GetCV(STACK_CVARS.motion) ~= nil then SetCV(STACK_CVARS.motion, (s.stackMode == "overlap") and "0" or "1") end
    if GetCV(STACK_CVARS.v) ~= nil and s.overlapV then SetCV(STACK_CVARS.v, string.format("%.2f", s.overlapV)) end
    if GetCV(STACK_CVARS.h) ~= nil and s.overlapH then SetCV(STACK_CVARS.h, string.format("%.2f", s.overlapH)) end
end
_G.H3z0UI_ApplyPlateStacking = NP.ApplyStacking

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if stackPending then NP.ApplyStacking() end
            return
        end
        C_Timer.After(1.5, NP.ApplyStacking)
    end)
end
