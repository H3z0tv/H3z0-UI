local ADDON_NAME, ns = ...
local NP = ns.H3zPlates
if not NP then return end

---------------------------------------------------------------------------
-- Nameplate extras (0.27.5)
--   1. Rules: colour / scale a plate by unit name or NPC id, and a scale for
--      bosses and rares.
--   2. Auras: your own debuffs (and, if you ask, dispellable enemy buffs) as a
--      row of icons, with a pandemic cue where the game lets addons read the
--      times.
--   3. Focus scale, non-target fade, and a scale-up while a unit casts.
--   4. A small performance counter (/h3z0ui npperf).
-- Everything is off or neutral until you switch it on. Values the game hides
-- in combat (secret values) are shown, never compared.
---------------------------------------------------------------------------

local function S(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) or false end
local function Settings() return NP.GetSettings and NP.GetSettings() end

local plates = NP.plates

---------------------------------------------------------------------------
-- performance counter
---------------------------------------------------------------------------
local Perf = { auraRuns = 0, auraMs = 0, adds = 0, skipped = 0, since = GetTime() }
NP.Perf = Perf

---------------------------------------------------------------------------
-- 1. rules
---------------------------------------------------------------------------
-- rule = { name = "Unit name" | npc = 12345, color = {r,g,b}, scale = 1.2 }
local function NpcId(unit)
    local guid = UnitGUID and UnitGUID(unit)
    if not guid or S(guid) then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
    return nil
end

local function FindRule(p)
    local s = Settings()
    local rules = s and s.rules
    if type(rules) ~= "table" or #rules == 0 then return nil end
    local unit = p.unit
    local id = NpcId(unit)
    local name = UnitName and UnitName(unit)
    if S(name) then name = nil end
    for _, rule in ipairs(rules) do
        if rule.enabled ~= false then
            if (rule.npc and id and rule.npc == id) or (rule.name and name and rule.name == name) then
                return rule
            end
        end
    end
end

local function ClassScale(p)
    local s = Settings()
    if not s or not s.classScale then return 1 end
    local c = UnitClassification and UnitClassification(p.unit)
    if not c or S(c) then return 1 end
    if c == "worldboss" or c == "boss" then return 1.15 end
    if c == "rare" or c == "rareelite" then return 1.1 end
    return 1
end

function NP.RuleColor(p)
    local rule = p.h3zRule
    if rule and rule.color then return rule.color[1], rule.color[2], rule.color[3] end
end

---------------------------------------------------------------------------
-- 3. scale and alpha
---------------------------------------------------------------------------
function NP.ExtraScale(p)
    local s = Settings()
    if not s then return 1 end
    local sc = 1
    if p.h3zRule and p.h3zRule.scale then sc = sc * p.h3zRule.scale end
    sc = sc * ClassScale(p)
    if p.isFocus and (s.focusScale or 1) ~= 1 then sc = sc * s.focusScale end
    if p.h3zCasting and (s.castScale or 1) ~= 1 then sc = sc * s.castScale end
    return math.max(0.6, math.min(1.8, sc))
end

function NP.ExtraAlpha(p)
    local s = Settings()
    local a = s and s.nonTargetAlpha or 1
    if a >= 1 then p:SetAlpha(1) return end
    -- fade only when something is targeted, and never the target / focus itself
    local hasTarget = UnitExists and UnitExists("target")
    if hasTarget and not p.isTarget and not p.isFocus then p:SetAlpha(a) else p:SetAlpha(1) end
end

local function Rescale(p)
    if not p.unit then return end
    local s = Settings()
    local sc = (p.isTarget and (s.targetScale or 1) or 1) * NP.ExtraScale(p)
    p.border:SetScale(sc)
    NP.ExtraAlpha(p)
end

local focusFrame = CreateFrame("Frame")
focusFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
focusFrame:SetScript("OnEvent", function()
    for _, p in pairs(plates) do
        p.isFocus = UnitIsUnit and p.unit and UnitIsUnit(p.unit, "focus") == true or false
        Rescale(p)
    end
end)

---------------------------------------------------------------------------
-- 2. auras
---------------------------------------------------------------------------
local PANDEMIC = 0.30
local ICON_TEX = "Interface\\Icons\\INV_Misc_QuestionMark"

local function MakeIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.h3zNPOwn = true
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetColorTexture(0, 0, 0, 1)
    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints()
    f.cd:SetDrawEdge(false)
    f.cd:SetHideCountdownNumbers(false)
    f.count = f:CreateFontString(nil, "OVERLAY")
    f.count:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    f.count:SetPoint("BOTTOMRIGHT", 1, 0)
    return f
end

local function EnsureAuraRow(p)
    if p.h3zAuras then return p.h3zAuras end
    local row = CreateFrame("Frame", nil, p)
    row:SetHeight(20)
    row.icons = {}
    p.h3zAuras = row
    return row
end

local function Present(v) return v ~= nil end

-- icon times that the game allows us to read; nil when they are secret
local function ReadTimes(aura)
    local d, e = aura.duration, aura.expirationTime
    if d == nil or e == nil or S(d) or S(e) then return nil end
    return d, e
end

local function SetCooldown(icon, unit, aura)
    local cd = icon.cd
    local id = aura.auraInstanceID
    if id and not S(id) and C_UnitAuras and C_UnitAuras.GetAuraDuration and cd.SetCooldownFromDurationObject then
        local dur = C_UnitAuras.GetAuraDuration(unit, id)
        if dur then
            local ok = pcall(cd.SetCooldownFromDurationObject, cd, dur)
            if ok then return end
        end
    end
    local d, e = ReadTimes(aura)
    if d and d > 0 then cd:SetCooldown(e - d, d) else cd:Clear() end
end

local function GetAuras(unit, filter, max)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return {} end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter, max)
    if ok and type(list) == "table" then return list end
    return {}
end

local function RefreshAuras(p)
    local s = Settings()
    local row = p.h3zAuras
    if not s or s.auras == "off" or not p.unit then
        if row then row:Hide() end
        return
    end
    local t0 = debugprofilestop and debugprofilestop() or 0
    row = EnsureAuraRow(p)
    local size, max = s.auraSize or 18, s.auraMax or 6

    local list = GetAuras(p.unit, "HARMFUL|PLAYER", max)
    if s.auraDispel then
        for _, a in ipairs(GetAuras(p.unit, "HELPFUL", max)) do
            local dn = a.dispelName
            if dn ~= nil and (S(dn) or dn ~= "") then
                list[#list + 1] = a
                if #list >= max then break end
            end
        end
    end

    row:ClearAllPoints()
    row:SetPoint("BOTTOM", p.border, "TOP", 0, 4)
    row:SetSize(math.max(1, #list * (size + 2)), size)
    row:Show()

    local pandemic = false
    for i = 1, max do
        local icon = row.icons[i]
        local aura = list[i]
        if aura then
            if not icon then icon = MakeIcon(row); row.icons[i] = icon end
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", row, "LEFT", (i - 1) * (size + 2), 0)
            pcall(icon.tex.SetTexture, icon.tex, aura.icon or ICON_TEX)
            SetCooldown(icon, p.unit, aura)
            local n = aura.applications
            if n ~= nil and not S(n) and n > 1 then icon.count:SetText(n) else icon.count:SetText("") end
            icon.times = nil
            local d, e = ReadTimes(aura)
            if d and d > 0 then icon.times = { d, e } end
            icon.border:SetColorTexture(0, 0, 0, 1)
            icon:Show()
            if icon.times then pandemic = true end
        elseif icon then
            icon:Hide()
        end
    end
    p.h3zAuraTimed = pandemic

    Perf.auraRuns = Perf.auraRuns + 1
    if debugprofilestop then Perf.auraMs = Perf.auraMs + (debugprofilestop() - t0) end
end

NP.RefreshAuras = RefreshAuras

-- pandemic cue: border turns bright when 30% or less of the time is left.
-- It needs times the game shows addons; when they are hidden there is no cue.
local function PandemicTick(p)
    local s = Settings()
    local row = p.h3zAuras
    if not row or not s or not s.auraPandemic then return end
    local now = GetTime()
    for _, icon in ipairs(row.icons) do
        if icon:IsShown() and icon.times then
            local d, e = icon.times[1], icon.times[2]
            local left = e - now
            if left > 0 and left <= d * PANDEMIC then
                icon.border:SetColorTexture(1, 0.82, 0.1, 1)
            else
                icon.border:SetColorTexture(0, 0, 0, 1)
            end
        end
    end
end

---------------------------------------------------------------------------
-- dirty queue: aura refreshes run in a shared frame with a time budget
---------------------------------------------------------------------------
local dirty, dirtyCount = {}, 0
local queue = CreateFrame("Frame")
queue:Hide()
local acc = 0
local BUDGET_MS = 1.5

local function PlateCount()
    local n = 0
    for _ in pairs(plates) do n = n + 1 end
    return n
end

queue:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    -- dense pulls: 5 refreshes a second; otherwise every frame
    local interval = (PlateCount() > 25) and 0.2 or 0
    if acc < interval then return end
    acc = 0
    local start = debugprofilestop and debugprofilestop() or 0
    for p in pairs(dirty) do
        dirty[p] = nil
        dirtyCount = dirtyCount - 1
        if p.unit then pcall(RefreshAuras, p) end
        if debugprofilestop and debugprofilestop() - start > BUDGET_MS then
            Perf.skipped = Perf.skipped + 1
            break
        end
    end
    if dirtyCount <= 0 then dirtyCount = 0; self:Hide() end
end)

local function MarkDirty(p)
    if not dirty[p] then dirty[p] = true; dirtyCount = dirtyCount + 1 end
    queue:Show()
end

-- pandemic ticker, only while any plate shows timed auras
NP.PandemicTick = PandemicTick
local pandemicAcc = 0
local pandemicFrame = CreateFrame("Frame")
pandemicFrame:SetScript("OnUpdate", function(_, elapsed)
    pandemicAcc = pandemicAcc + elapsed
    if pandemicAcc < 0.25 then return end
    pandemicAcc = 0
    for _, p in pairs(plates) do
        if p.h3zAuraTimed then PandemicTick(p) end
    end
end)

---------------------------------------------------------------------------
-- plate hooks
---------------------------------------------------------------------------
function NP.OnPlateAdded(p)
    Perf.adds = Perf.adds + 1
    p.h3zRule = FindRule(p)
    p.isFocus = UnitIsUnit and UnitIsUnit(p.unit, "focus") == true or false
    -- cast scale: follows the cast bar showing and hiding (once per plate)
    if not p.h3zCastHooked then
        p.h3zCastHooked = true
        p.castBorder:HookScript("OnShow", function()
            local s = Settings()
            if s and (s.castScale or 1) ~= 1 then p.h3zCasting = true; Rescale(p) end
        end)
        p.castBorder:HookScript("OnHide", function()
            if p.h3zCasting then p.h3zCasting = false; Rescale(p) end
        end)
        -- aura updates for this plate's unit only
        p.h3zAuraEv = CreateFrame("Frame")
        p.h3zAuraEv:SetScript("OnEvent", function() MarkDirty(p) end)
    end
    if p.h3zAuraEv and p.h3zAuraEv.RegisterUnitEvent then
        p.h3zAuraEv:UnregisterAllEvents()
        p.h3zAuraEv:RegisterUnitEvent("UNIT_AURA", p.unit)
    end
    Rescale(p)
    MarkDirty(p)
end

function NP.OnPlateRemoved(p)
    if p.h3zAuraEv then p.h3zAuraEv:UnregisterAllEvents() end
    dirty[p] = nil
    p.h3zCasting = false
    p.h3zRule = nil
    p.h3zAuraTimed = false
    if p.h3zAuras then p.h3zAuras:Hide() end
end

-- called after the options change
function NP.RefreshExtras()
    for _, p in pairs(plates) do
        p.h3zRule = FindRule(p)
        Rescale(p)
        MarkDirty(p)
    end
end

---------------------------------------------------------------------------
-- rule helpers for the options
---------------------------------------------------------------------------
function NP.AddRule(rule)
    local s = Settings()
    if not s then return false end
    s.rules = s.rules or {}
    s.rules[#s.rules + 1] = rule
    NP.RefreshExtras()
    return true
end

function NP.RemoveRule(index)
    local s = Settings()
    if s and s.rules and s.rules[index] then table.remove(s.rules, index); NP.RefreshExtras() end
end

---------------------------------------------------------------------------
-- /h3z0ui npperf : what the extras cost
---------------------------------------------------------------------------
function NP.PerfReport()
    local secs = math.max(1, GetTime() - Perf.since)
    local n = PlateCount()
    local avg = Perf.auraRuns > 0 and (Perf.auraMs / Perf.auraRuns) or 0
    print(string.format("|cff34D399H3z0 UI nameplates:|r %d plates, %d aura refreshes (%.3f ms each, %.2f per second), %d frames hit the time budget, %d plates added.",
        n, Perf.auraRuns, avg, Perf.auraRuns / secs, Perf.skipped, Perf.adds))
    Perf.auraRuns, Perf.auraMs, Perf.adds, Perf.skipped, Perf.since = 0, 0, 0, 0, GetTime()
end
_G.H3z0UI_NameplatePerf = NP.PerfReport
