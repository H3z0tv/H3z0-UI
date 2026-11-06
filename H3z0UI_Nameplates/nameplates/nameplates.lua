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
    interruptCD = { 0.55, 0.55, 0.55, 1 },
    interrupted = { 1.00, 0.00, 0.02, 1 },
    aggro     = { 1.00, 0.22, 0.22, 1 },
    lostAggro = { 1.00, 0.55, 0.00, 1 },
}
NP.DEFAULT_COLORS = DEFAULT_COLORS

local SETTING_DEFAULTS = {
    enabled = false, width = 150, height = 16, font = "global", nameSize = 11, textSize = 10,
    showLevel = true, showHealth = true, showPercent = true, questMark = true, limitDistance = true, maxDistance = 40, castbar = true, castHeight = 16, castWidth = 0,
    mythicColors = "instance", threat = true, arrows = true, friendly = true, rounded = true,
    targetScale = 1.1, matchPlayer = false, unitFrameColors = true,
    instClassColors = true, instNamesOnly = true, mythicNamesOnly = true, interruptReady = true,
    friendlyNamesOnly = true, showAbsorbs = true,
    -- 0.27.5 extras (all off or neutral by default)
    castOffsetX = 0, castTimeShow = true, castNameShow = true, castGap = 3, castIconSide = "left", castIconSize = 0, castTextSize = 0, nameGap = 3,
    auras = "off", auraMax = 6, auraSize = 18, auraPandemic = true, auraDispel = false,
    focusScale = 1, nonTargetAlpha = 1, castScale = 1, classScale = false,
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
NP.plates, NP.pool = plates, pool   -- extras (rules, auras, focus) read these

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
    if plate.absorb then
        plate.absorb:SetStatusBarTexture(tex)
        plate.absorb:SetStatusBarColor(0.85, 0.95, 1, 0.55)
        plate.healAbsorb:SetStatusBarTexture(tex)
        plate.healAbsorb:SetStatusBarColor(0.45, 0.05, 0.05, 0.75)
        -- the heal absorb bar is as wide as the health bar so its values line up
        plate.healAbsorb:ClearAllPoints()
        plate.healAbsorb:SetPoint("TOPRIGHT", plate.hp:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
        plate.healAbsorb:SetPoint("BOTTOMRIGHT", plate.hp:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
        plate.healAbsorb:SetWidth(W)
    end
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
    plate.name:SetPoint("BOTTOM", plate.border, "TOP", 0, tonumber(s.nameGap) or 3)
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
    local gap = tonumber(s.castGap) or 3
    local side = s.castIconSide or "left"
    local IS = (tonumber(s.castIconSize) or 0) > 0 and s.castIconSize or CH
    local reserve = (side == "off") and 0 or (IS + 2)
    plate.castBorder:ClearAllPoints()
    local CW = tonumber(s.castWidth) or 0
    local OX = tonumber(s.castOffsetX) or 0
    if CW > 0 then
        -- own width, centred under the plate (icon included)
        local shift = (side == "left" and reserve / 2) or (side == "right" and -reserve / 2) or 0
        plate.castBorder:SetPoint("TOP", plate.border, "BOTTOM", shift + OX, -gap)
        plate.castBorder:SetWidth(CW)
    else
        local l = (side == "left") and reserve or 0
        local r = (side == "right") and reserve or 0
        plate.castBorder:SetPoint("TOPLEFT", plate.border, "BOTTOMLEFT", l + OX, -gap)
        plate.castBorder:SetPoint("TOPRIGHT", plate.border, "BOTTOMRIGHT", -r + OX, -gap)
    end
    plate.castBorder:SetHeight(CH)
    plate.cast:ClearAllPoints()
    plate.cast:SetPoint("TOPLEFT", plate.castBorder, "TOPLEFT", 1, -1)
    plate.cast:SetPoint("BOTTOMRIGHT", plate.castBorder, "BOTTOMRIGHT", -1, 1)
    plate.castIcon:SetSize(IS, IS)
    plate.castIcon:ClearAllPoints()
    if side == "right" then
        plate.castIcon:SetPoint("LEFT", plate.castBorder, "RIGHT", 2, 0)
    else
        plate.castIcon:SetPoint("RIGHT", plate.castBorder, "LEFT", -2, 0)
    end
    plate.h3zIconSide = side
    local cfs = (tonumber(s.castTextSize) or 0) > 0 and s.castTextSize or math.max(7, math.min(CH - 3, s.textSize + 2))
    plate.castText:SetFont(font, cfs, "OUTLINE")
    plate.castTime:SetFont(font, cfs, "OUTLINE")
    -- the spell name ends where the time starts: a long name can never run into it
    plate.castTime:SetWidth(math.ceil(cfs * 2.7))
    plate.castText:SetAlpha(s.castNameShow == false and 0 or 1)
    plate.castTime:SetAlpha(s.castTimeShow == false and 0 or 1)
    plate.castText:ClearAllPoints()
    plate.castText:SetPoint("LEFT", plate.castBorder, "LEFT", 4, 0)
    plate.castText:SetPoint("RIGHT", plate.castTime, "LEFT", -3, 0)
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

    -- shields (damage absorbs): a light bar over the health, filled in from the right end
    p.absorb = CreateFrame("StatusBar", nil, p.hp)
    p.absorb.h3zNPOwn = true
    p.absorb:SetAllPoints(p.hp)
    p.absorb:SetFrameLevel(p.hp:GetFrameLevel() + 1)
    p.absorb:SetStatusBarTexture(BAR_TEX)
    p.absorb:SetStatusBarColor(0.85, 0.95, 1, 0.55)
    p.absorb:SetReverseFill(true)
    p.absorb:SetMinMaxValues(0, 1)
    p.absorb:SetValue(0)
    -- heal absorbs (healing that gets eaten first): dark red from the end of the health fill back
    p.healAbsorb = CreateFrame("StatusBar", nil, p.hp)
    p.healAbsorb.h3zNPOwn = true
    p.healAbsorb:SetPoint("TOPRIGHT", p.hp:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    p.healAbsorb:SetPoint("BOTTOMRIGHT", p.hp:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    p.healAbsorb:SetWidth(150)
    p.healAbsorb:SetFrameLevel(p.hp:GetFrameLevel() + 1)
    p.healAbsorb:SetStatusBarTexture(BAR_TEX)
    p.healAbsorb:SetStatusBarColor(0.45, 0.05, 0.05, 0.75)
    p.healAbsorb:SetReverseFill(true)
    p.healAbsorb:SetMinMaxValues(0, 1)
    p.healAbsorb:SetValue(0)

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
    p.castText:SetPoint("RIGHT", p.castBorder, "RIGHT", -30, 0) -- re-anchored to the time in Apply
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
-- shields and heal absorbs; the amounts can be hidden values, the bars take them as they are
local function UpdateAbsorbs(p, max)
    local s = DB()
    local u = p.unit
    if not (p.absorb and u) then return end
    local on = s.showAbsorbs ~= false
    local shield = on and UnitGetTotalAbsorbs and Safe(UnitGetTotalAbsorbs, u) or nil
    if shield ~= nil then
        pcall(p.absorb.SetMinMaxValues, p.absorb, 0, max)
        if not pcall(p.absorb.SetValue, p.absorb, shield) then p.absorb:SetValue(0) end
        p.absorb:Show()
    else
        p.absorb:Hide()
    end
    local eaten = on and UnitGetTotalHealAbsorbs and Safe(UnitGetTotalHealAbsorbs, u) or nil
    if eaten ~= nil then
        pcall(p.healAbsorb.SetMinMaxValues, p.healAbsorb, 0, max)
        if not pcall(p.healAbsorb.SetValue, p.healAbsorb, eaten) then p.healAbsorb:SetValue(0) end
        p.healAbsorb:Show()
    else
        p.healAbsorb:Hide()
    end
end

local function UpdateHealth(p)
    local u = p.unit
    local s = DB()
    local max, cur = UnitHealthMax(u), UnitHealth(u)
    pcall(p.hp.SetMinMaxValues, p.hp, 0, max)
    pcall(p.hp.SetValue, p.hp, cur)
    pcall(UpdateAbsorbs, p, max)
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
    local rr, rg, rb
    if NP.RuleColor then rr, rg, rb = NP.RuleColor(p) end
    if rr then p.hp:SetStatusBarColor(rr, rg, rb) return end
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
    if NP.ExtraScale then sc = sc * NP.ExtraScale(p) end
    p.border:SetScale(sc)
    if NP.ExtraAlpha then NP.ExtraAlpha(p) end
    p.castBorder:SetScale(1)
    UpdateBorder(p)
end

---------------------------------------------------------------------------
-- Your interrupt: casts you can interrupt are grey while your interrupt is on
-- cooldown and turn back to the cast colour the moment it is ready (also in
-- the middle of a cast). Casts that can't be interrupted keep their own grey.
---------------------------------------------------------------------------
local INTERRUPTS = {
    WARRIOR = { 6552 }, ROGUE = { 1766 }, DEATHKNIGHT = { 47528 }, DEMONHUNTER = { 183752 },
    PALADIN = { 96231 }, SHAMAN = { 57994 }, HUNTER = { 147362, 187707 }, MAGE = { 2139 },
    PRIEST = { 15487 }, WARLOCK = { 19647, 119910, 132409 }, MONK = { 116705 },
    DRUID = { 106839, 78675 }, EVOKER = { 351338 },
}
local myInterrupt          -- spellID of the interrupt you have right now (nil: none)
local interruptReady = true

local function Known(id)
    if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id) then return true end
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and (IsSpellKnown(id) or IsSpellKnown(id, true)) then return true end
    return false
end

local function FindInterrupt()
    local _, class = UnitClass("player")
    myInterrupt = nil
    for _, id in ipairs(INTERRUPTS[class or ""] or {}) do
        if Known(id) then myInterrupt = id break end
    end
end

-- true when the interrupt can be used now (the global cooldown doesn't count);
-- when the game hides the cooldown (secret), it counts as ready
local function ReadInterrupt()
    if not myInterrupt or not (C_Spell and C_Spell.GetSpellCooldown) then return true end
    local ok, info = pcall(C_Spell.GetSpellCooldown, myInterrupt)
    if not ok or type(info) ~= "table" then return true end
    local onGCD = info.isOnGCD
    if S(onGCD) then onGCD = nil end
    local active = info.isActive
    if active ~= nil and not S(active) then
        if not active then return true end
        return onGCD == true
    end
    local start, dur = info.startTime, info.duration
    if start == nil or dur == nil or S(start) or S(dur) then return true end
    if dur <= 1.5 or start == 0 then return true end
    return (start + dur) <= GetTime()
end

local function InterruptColor(channel)
    local s = DB()
    if s.interruptReady ~= false and not interruptReady then return Color("interruptCD") end
    return Color(channel and "channel" or "cast")
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
    p.cast:SetStatusBarColor(InterruptColor(channel))
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
    p.castIcon:SetShown(p.h3zIconSide ~= "off")
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

-- Quest marker: a gold "!" at the left of the bar for units you need for a quest.
-- true / false when the game can tell; nil when it cannot (then nothing is shown).
local function IsQuestUnit(unit)
    -- a yes from any source is final; a no is not (a client can know the call but not fill it
    -- in), so every source is asked before the answer is no
    local answered
    if _G.C_QuestLog and _G.C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok, v = pcall(_G.C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok and v ~= nil and not S(v) then
            if v == true then return true end
            answered = true
        end
    end
    if _G.C_TooltipInfo and _G.C_TooltipInfo.GetUnit then
        local ok, data = pcall(_G.C_TooltipInfo.GetUnit, unit)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            answered = true
            local qo = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective
            local qt = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestTitle
            for _, line in ipairs(data.lines) do
                local t = line and line.type
                if t ~= nil and not S(t) and qo and (t == qo or t == qt) then return true end
                local txt = line and line.leftText
                if type(txt) == "string" and not S(txt) and (txt:find("%d+/%d+") or txt:find("%d+%%")) then
                    return true
                end
            end
        end
    end
    -- older client: read the unit's tooltip for quest progress lines (3/8, 40%)
    if _G.CreateFrame then
        local tip = _G.H3z0UIQuestScan
        if not tip then
            local ok, t = pcall(CreateFrame, "GameTooltip", "H3z0UIQuestScan", UIParent, "GameTooltipTemplate")
            if ok then tip = t end
        end
        if tip and tip.SetUnit then
            tip:SetOwner(UIParent, "ANCHOR_NONE")
            local ok = pcall(tip.SetUnit, tip, unit)
            if ok then
                for i = 2, tip:NumLines() do
                    local fs = _G["H3z0UIQuestScanTextLeft" .. i]
                    local txt = fs and fs:GetText()
                    if type(txt) == "string" and not S(txt) and (txt:find("%d+/%d+") or txt:find("%d+%%")) then
                        tip:Hide()
                        return true
                    end
                end
                tip:Hide()
                return false
            end
        end
    end
    if answered then return false end
    return nil
end
NP.IsQuestUnit = IsQuestUnit

-- true when every objective line on the unit's tooltip is full (6/6, 100%): the quest part
-- this unit stands for is done. nil when no progress line can be read.
local function QuestDone(unit)
    local seen, open = false, false
    local function Take(txt)
        if type(txt) ~= "string" or S(txt) then return end
        for a, b in txt:gmatch("(%d+)/(%d+)") do
            seen = true
            if (tonumber(a) or 0) < (tonumber(b) or 1) then open = true end
        end
        for pct in txt:gmatch("(%d+)%%") do
            seen = true
            if (tonumber(pct) or 0) < 100 then open = true end
        end
    end
    if _G.C_TooltipInfo and _G.C_TooltipInfo.GetUnit then
        local ok, data = pcall(_G.C_TooltipInfo.GetUnit, unit)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            for i, line in ipairs(data.lines) do
                if i > 1 and line then Take(line.leftText) end
            end
        end
    end
    if not seen then
        local tip = _G.H3z0UIQuestScan
        if tip and tip.NumLines and tip.SetUnit then
            tip:SetOwner(UIParent, "ANCHOR_NONE")
            if pcall(tip.SetUnit, tip, unit) then
                for i = 2, tip:NumLines() do
                    local fs = _G["H3z0UIQuestScanTextLeft" .. i]
                    Take(fs and fs:GetText())
                end
            end
            tip:Hide()
        end
    end
    if not seen then return nil end
    return not open
end

_G.H3z0UI_QuestCheck = function()
    local say = function(m) print("|cFF30D1FFH3z0 UI:|r " .. m) end
    local u = "target"
    if not UnitExists(u) then say("Target the unit first.") return end
    say("Quest check for " .. tostring(UnitName(u)))
    say("  C_QuestLog.UnitIsRelatedToActiveQuest: " .. tostring(_G.C_QuestLog and _G.C_QuestLog.UnitIsRelatedToActiveQuest and "yes" or "NO"))
    if _G.C_QuestLog and _G.C_QuestLog.UnitIsRelatedToActiveQuest then
        say("    answer: " .. tostring(select(2, pcall(_G.C_QuestLog.UnitIsRelatedToActiveQuest, u))))
    end
    say("  C_TooltipInfo.GetUnit: " .. tostring(_G.C_TooltipInfo and _G.C_TooltipInfo.GetUnit and "yes" or "NO")
        .. ", quest line types: " .. tostring(Enum and Enum.TooltipDataLineType and "yes" or "NO"))
    if _G.C_TooltipInfo and _G.C_TooltipInfo.GetUnit then
        local ok, d = pcall(_G.C_TooltipInfo.GetUnit, u)
        local n = ok and type(d) == "table" and type(d.lines) == "table" and #d.lines or "none"
        say("    tooltip lines: " .. tostring(n))
    end
    say("  final answer used by the nameplate: " .. tostring(IsQuestUnit(u)))
    local tp = C_NamePlate and C_NamePlate.GetNamePlateForUnit(u)
    local mine
    for _, pl in pairs(plates) do if pl.namePlate == tp then mine = pl end end
    say("  H3z0 plate for the target: " .. tostring(mine and "yes" or "NO")
        .. ", marker: " .. tostring(mine and mine.questMark and (mine.questMark:IsShown() and "shown" or "hidden") or "not made")
        .. ", last error: " .. tostring(NP.lastQuestError))
    local tip = _G.H3z0UIQuestScan
    if tip and tip.NumLines then
        for i = 1, tip:NumLines() do
            local fs = _G["H3z0UIQuestScanTextLeft" .. i]
            local t = fs and fs:GetText()
            say("    scan line " .. i .. ": " .. tostring(type(t) == "string" and not S(t) and t or "?"))
        end
    end
end

local function UpdateQuestMark(p)
    local unit = p.unit
    local want = unit and DB().questMark ~= false and not Bool(UnitIsDead(unit)) and IsQuestUnit(unit) == true
    local done = want and QuestDone(unit) == true
    -- above the name: a gold ! while the quest still needs this unit, a green tick when its
    -- objective is full
    if want then
        local size = (DB().nameSize or 11) + 7
        if not p.questMark then
            local m = p:CreateFontString(nil, "OVERLAY", nil, 7)
            m:SetFont(FontPath(DB().font), size, "THICKOUTLINE")
            m:SetPoint("BOTTOM", p.name, "TOP", 0, 2)
            m:SetText("!")
            m:SetTextColor(1, 0.82, 0.1, 1)
            p.questMark = m
        end
        p.questMark:SetFont(FontPath(DB().font), size, "THICKOUTLINE")
        if not p.questTick then
            local t = p:CreateTexture(nil, "OVERLAY", nil, 7)
            t:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            t:SetVertexColor(0.2, 1, 0.3, 1)
            t:SetPoint("BOTTOM", p.name, "TOP", 0, 0)
            p.questTick = t
        end
        p.questTick:SetSize(size + 6, size + 6)
        p.questMark:SetShown(not done)
        p.questTick:SetShown(done)
    else
        if p.questMark then p.questMark:Hide() end
        if p.questTick then p.questTick:Hide() end
    end
end
NP.UpdateQuestMark = UpdateQuestMark

local questPending
local function RefreshQuestMarks()
    if questPending then return end
    questPending = true
    C_Timer.After(0.5, function()
        questPending = nil
        for _, p in pairs(plates) do pcall(UpdateQuestMark, p) end
    end)
end

local skipWhy = {}
local retries = {}
local OnAdded
OnAdded = function(unit)
    if not Active() then return end
    skipWhy[unit] = nil
    if Bool(UnitIsUnit(unit, "player")) then skipWhy[unit] = "it is you" return end
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    if not np or (np.IsForbidden and np:IsForbidden()) then skipWhy[unit] = "the game locks this plate" return end
    local s = DB()
    if not s.friendly and not Bool(UnitCanAttack("player", unit)) then skipWhy[unit] = "friendly plates are off" return end
    -- friendly units show only their name in their class colour: the game's own names-only
    -- plate (set up in ApplyInstanceFriendly) is left alone. Forever and Classic have no
    -- names-only plate, so there the H3z0 name tag is drawn instead of the game's plate.
    if s.friendlyNamesOnly and not Bool(UnitCanAttack("player", unit)) then
        skipWhy[unit] = "friendly, names only"
        if ns.Client and ns.Client.isLegacy then NP.ShowNameTag(np, unit) end
        return
    end
    -- objects you can use (rostrums, mailboxes, ...) get a nameplate from the game too: they
    -- have no health, so they keep the game's own name tag instead of an empty health bar
    if UnitIsGameObject and Bool(UnitIsGameObject(unit)) then skipWhy[unit] = "it is an object" return end
    local hpMax = UnitHealthMax and UnitHealthMax(unit)
    if hpMax ~= nil and not S(hpMax) and hpMax == 0 and not Bool(UnitIsPlayer(unit)) then
        -- a mob far away often has no health data yet when its plate is added (the game fills it
        -- in a moment later): try again a few times instead of leaving it with the game's plate
        skipWhy[unit] = "no health data yet"
        local n = (retries[unit] or 0) + 1
        retries[unit] = n
        if n <= 12 then
            C_Timer.After(0.25, function()
                if plates[unit] then return end
                local cur = C_NamePlate.GetNamePlateForUnit(unit)
                if cur and UnitExists(unit) then OnAdded(unit) end
            end)
        end
        return
    end
    retries[unit] = nil
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
    if NP.OnPlateAdded then pcall(NP.OnPlateAdded, p) end
    FullUpdate(p)
    local okQ, errQ = pcall(UpdateQuestMark, p)
    if not okQ then NP.lastQuestError = errQ end
end

-- /h3z0ui npcheck: one line per nameplate on screen and why it is or is not drawn by H3z0 UI
function NP.CheckPlates(say)
    local list = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    local drawn = 0
    for _ in pairs(plates) do drawn = drawn + 1 end
    say("Nameplates on screen: " .. #list .. "  drawn by H3z0 UI: " .. drawn .. "  (Active=" .. tostring(Active() and true or false) .. ")")
    for i, np in ipairs(list) do
        local unit = np.namePlateUnitToken
        if not unit or S(unit) then unit = np.UnitFrame and np.UnitFrame.unit end
        if S(unit) then unit = nil end
        if not unit and np.UnitFrame and np.UnitFrame.GetUnit then
            local ok, u = pcall(np.UnitFrame.GetUnit, np.UnitFrame)
            if ok and not S(u) then unit = u end
        end
        local name = unit and UnitName(unit)
        local hp = unit and UnitHealthMax and UnitHealthMax(unit)
        local atk = unit and UnitCanAttack("player", unit)
        local uf = np.UnitFrame
        say(string.format("   plate %d: token=%s UnitFrame.unit=%s unitFrameShown=%s ours=%s", i, tostring(np.namePlateUnitToken),
            tostring(uf and uf.unit), tostring(uf and uf:IsShown() and true or false), tostring(pool[np] and pool[np]:IsShown() and true or false)))
        say(string.format("%d. %s [%s]  drawn=%s  attackable=%s  maxHealth=%s  why not: %s",
            i, S(name) and "(secret)" or tostring(name), tostring(unit),
            tostring(unit and plates[unit] and true or false), S(atk) and "secret" or tostring(atk),
            S(hp) and "secret" or tostring(hp), tostring(unit and skipWhy[unit] or "-")))
    end
end

_G.H3z0UI_NameplateCheck = function(say) NP.CheckPlates(say) end

-- How far away nameplates show (the game's own nameplate distance). Mobs further away than this get
-- no plate at all, so only the ones in front of you are drawn. Your own value comes back when the
-- option is switched off.
local distPending = false
function NP.ApplyDistance()
    if InCombatLockdown() then distPending = true return end
    distPending = false
    local s = DB()
    if not s then return end
    local function get(n) if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(n) end return GetCVar and GetCVar(n) end
    local function set(n, v) if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, n, v) else pcall(SetCVar, n, v) end end
    local cur = get("nameplateMaxDistance")
    if cur == nil then return end
    if s.limitDistance ~= false then
        if s.savedDistance == nil then s.savedDistance = cur end
        local want = tostring(math.max(10, math.min(100, tonumber(s.maxDistance) or 40)))
        if cur ~= want then set("nameplateMaxDistance", want) end
    elseif s.savedDistance ~= nil then
        set("nameplateMaxDistance", s.savedDistance)
        s.savedDistance = nil
    end
end
function NP.DistancePending() return distPending end

-- Forever / Classic friendly name tag: only the name (players in their class colour, NPCs in the
-- friendly green), in the H3z0 nameplate font, in place of the game's own friendly plate
local nameTags = {}
function NP.ShowNameTag(np, unit)
    local s = DB()
    local tag = np.h3zNameTag
    if not tag then
        tag = CreateFrame("Frame", nil, np)
        tag:SetAllPoints(np)
        tag:EnableMouse(false)
        -- the game fades and brightens its plates while it changes target / mouseover: the name
        -- tag keeps full strength, so it doesn't flicker with them
        if tag.SetIgnoreParentAlpha then pcall(tag.SetIgnoreParentAlpha, tag, true) end
        tag.text = tag:CreateFontString(nil, "OVERLAY")
        tag.text:SetPoint("CENTER", tag, "CENTER", 0, 0)
        tag.text:SetJustifyH("CENTER")
        tag.text:SetWordWrap(false)
        np.h3zNameTag = tag
    end
    tag.text:SetFont(FontPath(s.font), (s.nameSize or 11) + 1, "OUTLINE")
    local r, g, b = 0.2, 0.8, 0.3
    if Bool(UnitIsPlayer(unit)) then
        local _, class = UnitClass(unit)
        local c = class and not S(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then r, g, b = c.r, c.g, c.b end
    end
    tag.text:SetTextColor(r, g, b, 1)
    pcall(tag.text.SetText, tag.text, UnitName(unit))
    HideBlizzard(np.UnitFrame, true, false)
    tag.unit = unit
    tag:Show()
    nameTags[unit] = np
end

local function HideNameTag(unit)
    local np = nameTags[unit]
    if not np then return end
    -- the same plate is often handed straight back to the same unit (targeting): keep it shown,
    -- ShowNameTag on the next add sets it again
    if np.h3zNameTag then np.h3zNameTag.h3zLeft = GetTime() end
    nameTags[unit] = nil
    if np.h3zNameTag then np.h3zNameTag:Hide(); np.h3zNameTag.unit = nil end
    if np.UnitFrame then HideBlizzard(np.UnitFrame, false, false) end
end

local function OnRemoved(unit)
    HideNameTag(unit)
    local p = plates[unit]
    if not p then return end
    plates[unit] = nil
    if NP.OnPlateRemoved then pcall(NP.OnPlateRemoved, p) end
    p.unit = nil
    p.cast:SetScript("OnUpdate", nil)
    HideCast(p)
    p:Hide()
end

local function RestoreAll()
    for unit in pairs(nameTags) do HideNameTag(unit) end
    for unit in pairs(plates) do OnRemoved(unit) end
    for np in pairs(pool) do
        if np.UnitFrame then HideBlizzard(np.UnitFrame, false, false) end
    end
end

NP.layoutGen = 1
function NP.Refresh()
    NP.layoutGen = (NP.layoutGen or 1) + 1   -- settings may have changed: lay every plate out again
    RestoreAll()
    if NP.ApplyInstanceFriendly then C_Timer.After(0, NP.ApplyInstanceFriendly) end
    if NP.ApplyDistance then C_Timer.After(0, NP.ApplyDistance) end
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
-- Live preview (settings page): two sample plates built with the same code
-- as the real ones, so every setting (size, font, texts, colours, rounded
-- corners, arrows, threat border, cast bar) shows the moment it changes.
--   left:  your target, casting (interruptible)
--   right: another enemy, channelling, with the threat border
---------------------------------------------------------------------------
local PREVIEW_UNITS = {
    { name = "Bladeguard Brute", level = "91+", mythic = "melee", health = 0.72, hp = "1.8M",
      target = true, spell = "Crushing Slam", icon = 132355, channel = false },
    { name = "Shadowbound Adept", level = "90", mythic = "caster", health = 0.41, hp = "684K",
      threat = "aggro", spell = "Void Torrent", icon = 1386551, channel = true },
}
local PREVIEW_CAST_TIME = 2.5

local function PreviewPlate(holder, info)
    local fake = CreateFrame("Frame", nil, holder)
    fake:SetSize(1, 1)
    local p = Create(fake)
    pool[fake] = nil          -- not a real nameplate: the live code never touches it
    p.info = info
    p.fake = fake
    return p
end

local function PreviewApply(p)
    local s = DB()
    local info = p.info
    Layout(p)
    p.hp:SetMinMaxValues(0, 1)
    p.hp:SetValue(info.health)
    if p.absorb then p.absorb:SetValue(0); p.healAbsorb:SetValue(0) end
    local key = (s.mythicColors == "off") and "hostile" or info.mythic
    p.hp:SetStatusBarColor(Color(key))
    if s.showHealth then
        p.hpText:SetText((s.matchPlayer and s.showPercent) and (info.hp .. " |") or info.hp)
    end
    if s.showPercent then p.pctText:SetFormattedText("%d%%", math.floor(info.health * 100 + 0.5)) end
    if s.showLevel then
        local elite = info.level:find("+", 1, true)
        p.name:SetFormattedText("|cff%s%s|r | %s", elite and "ff8040" or "ffd100", info.level, info.name)
    else
        p.name:SetText(info.name)
    end
    p.isTarget = info.target or false
    p.threat = info.threat
    p.h3zBorderKey = nil
    UpdateBorder(p)
    p.border:SetScale(p.isTarget and (s.targetScale or 1) or 1)
    p.castBorder:SetScale(1)
    if s.castbar then
        p.cast:SetMinMaxValues(0, 1)
        p.cast:SetStatusBarColor(InterruptColor(info.channel))
        p.castLock:SetVertexColor(Color("noInterrupt"))
        p.castLock:SetAlpha(0)
        p.castText:SetText(info.spell)
        p.castIcon:SetTexture(info.icon)
        p.castBorder:Show()
        p.castIcon:Show()
    else
        p.castBorder:Hide()
        p.castIcon:Hide()
    end
end

function NP.CreatePreview(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(150)
    local Round = ns.Round
    if Round and Round.Panel then
        f.bg = Round.Panel(f, 8)
        f.bg:SetAllPoints(f)
        f.bg:SetFrameLevel(f:GetFrameLevel())
        local fill = Round.SLATE_FILL or { 0.075, 0.095, 0.12 }
        local edge = Round.SLATE_BORDER or { 0.25, 0.29, 0.33 }
        f.bg:SetFillColor(fill[1], fill[2], fill[3], 0.98)
        f.bg:SetBorderColor(edge[1], edge[2], edge[3], 1)
    else
        local t = f:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(0.075, 0.095, 0.12, 0.98)
    end
    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(FontPath("global"), 11, "OUTLINE")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
    f.title:SetTextColor(0.75, 0.78, 0.82, 1)
    f.title:SetText("Live Preview")

    -- the plates sit in a holder that is scaled down when they don't fit
    f.holder = CreateFrame("Frame", nil, f)
    f.holder:SetFrameLevel(f:GetFrameLevel() + 5)
    f.plates = {}
    for i, info in ipairs(PREVIEW_UNITS) do f.plates[i] = PreviewPlate(f.holder, info) end

    function f:Refresh()
        local s = DB()
        if not s then return end
        if s.enabled and not OtherPlateAddon() then
            self.title:SetText("Live Preview")
        else
            self.title:SetText("Live Preview  |cff888888(H3z0 Nameplates are switched off)|r")
        end
        local w = self:GetWidth()
        if not w or w < 50 then w = 600 end
        local colW = w / 2
        -- room one plate needs: plate (target size) + arrows + cast icon + a little air
        local sc = s.targetScale or 1
        local need = s.width * sc + (s.height + 4) * 4 + 20
        local castW = tonumber(s.castWidth) or 0
        if castW > 0 then need = math.max(need, castW + s.castHeight + 30) end
        local scale = math.min(1, colW / need)
        local tall = s.nameSize + 6 + s.height * sc + (s.castbar and (s.castHeight + 6) or 0)
        scale = math.min(scale, 118 / tall)
        self.holder:SetScale(scale)
        self.holder:ClearAllPoints()
        self.holder:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -18)
        self.holder:SetSize(w / scale, (self:GetHeight() - 18) / scale)
        local hw, hh = w / scale, (self:GetHeight() - 18) / scale
        local midY = -(s.nameSize + 4 + (s.height * sc) / 2) - (hh - tall) / 2
        for i, p in ipairs(self.plates) do
            p.fake:ClearAllPoints()
            p.fake:SetPoint("CENTER", self.holder, "TOPLEFT", hw * (i == 1 and 0.25 or 0.75), midY)
            PreviewApply(p)
        end
    end

    -- the cast bars run on a loop while the preview is visible
    f.elapsed = 0
    f:SetScript("OnUpdate", function(self, el)
        self.elapsed = self.elapsed + el
        local t = self.elapsed % PREVIEW_CAST_TIME
        local done = t / PREVIEW_CAST_TIME
        for _, p in ipairs(self.plates) do
            if p.castBorder:IsShown() then
                p.cast:SetValue(p.info.channel and (1 - done) or done)
                p.castTime:SetFormattedText("%.1f", PREVIEW_CAST_TIME - t)
            end
        end
        if self.onTick then self:onTick() end
    end)
    f:SetScript("OnShow", function(self) self:Refresh() end)
    f:SetScript("OnSizeChanged", function(self) self:Refresh() end)
    return f
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local UNIT_EVENTS = {
    UNIT_HEALTH = function(p) UpdateHealth(p) end,
    UNIT_MAXHEALTH = function(p) UpdateHealth(p) end,
    UNIT_ABSORB_AMOUNT_CHANGED = function(p) pcall(UpdateAbsorbs, p, UnitHealthMax(p.unit)) end,
    UNIT_HEAL_ABSORB_AMOUNT_CHANGED = function(p) pcall(UpdateAbsorbs, p, UnitHealthMax(p.unit)) end,
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
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_FOCUS_CHANGED",
    "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_POI_UPDATE" }) do
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
    elseif event == "PLAYER_FOCUS_CHANGED" then
        for _, p in pairs(plates) do pcall(UpdateTarget, p) end
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" or event == "QUEST_POI_UPDATE" then
        RefreshQuestMarks()
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
-- Interrupt watcher: recolours the cast bars when your interrupt comes off
-- cooldown (checks 5 times a second, only while it is on cooldown)
---------------------------------------------------------------------------
local function RecolorCasts()
    for _, p in pairs(plates) do
        if p.castBorder:IsShown() and not (p.interruptedUntil and GetTime() < p.interruptedUntil) then
            pcall(p.cast.SetStatusBarColor, p.cast, InterruptColor(p.castChannel))
        end
    end
end

local intWatch = CreateFrame("Frame")
intWatch:Hide()
local function CheckInterrupt()
    local ready = ReadInterrupt()
    if ready ~= interruptReady then
        interruptReady = ready
        RecolorCasts()
    end
    -- keep looking only while it is on cooldown
    intWatch:SetShown(not ready and Active())
end
local intElapsed = 0
intWatch:SetScript("OnUpdate", function(_, elapsed)
    intElapsed = intElapsed + elapsed
    if intElapsed < 0.2 then return end
    intElapsed = 0
    CheckInterrupt()
end)

local intEv = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "SPELL_UPDATE_COOLDOWN" }) do
    pcall(intEv.RegisterEvent, intEv, e)
end
pcall(intEv.RegisterUnitEvent, intEv, "UNIT_PET", "player")
pcall(intEv.RegisterUnitEvent, intEv, "UNIT_SPELLCAST_SUCCEEDED", "player")
intEv:SetScript("OnEvent", function(_, event)
    if event ~= "SPELL_UPDATE_COOLDOWN" and event ~= "UNIT_SPELLCAST_SUCCEEDED" then FindInterrupt() end
    CheckInterrupt()
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
    -- names only, but just in Mythic dungeons (Mythic 0 and Mythic+ keys)
    mythicNamesOnly = { name = "nameplateShowOnlyNames", on = "1", mythic = true },
}
local MYTHIC_DIFFICULTY = { [23] = true, [8] = true }   -- Mythic dungeon, Mythic Keystone
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

local function InMythicDungeon()
    local _, instanceType, difficultyID = GetInstanceInfo()
    if S(instanceType) or S(difficultyID) then return false end
    return instanceType == "party" and MYTHIC_DIFFICULTY[difficultyID] or false
end

local function ApplyInstanceFriendly()
    if InCombatLockdown() then instPending = true return end
    instPending = false
    local s = DB()
    if not s then return end
    groupContentCache = nil
    local inside = InGroupContent()
    local mythic = inside and InMythicDungeon()
    -- what each CVar should be right now (several options can share one CVar)
    local wanted, used = {}, {}
    for key, cv in pairs(INST_CVARS) do
        used[cv.name] = true
        if s[key] and inside and (not cv.mythic or mythic) then wanted[cv.name] = cv.on end
    end
    -- Friendly Names Only: everywhere, not only inside instances
    if s.friendlyNamesOnly and not OtherPlateAddon() then
        wanted["ShowClassColorInFriendlyNameplate"] = "1"
        wanted["nameplateShowOnlyNames"] = "1"
    end
    for name in pairs(used) do
        local want = wanted[name]
        if want and GetCV(name) ~= nil then
            instSaved = instSaved or {}
            if instSaved[name] == nil then instSaved[name] = GetCV(name) end
            if GetCV(name) ~= want then SetCV(name, want) end
        elseif instSaved and instSaved[name] ~= nil then
            SetCV(name, instSaved[name]); instSaved[name] = nil
        end
    end
    if instSaved and next(instSaved) == nil then instSaved = nil end
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
    pcall(f.RegisterEvent, f, "PLAYER_DIFFICULTY_CHANGED")
    pcall(f.RegisterEvent, f, "CHALLENGE_MODE_START")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if instPending then ApplyInstanceFriendly() end
            if NP.DistancePending and NP.DistancePending() then NP.ApplyDistance() end
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
