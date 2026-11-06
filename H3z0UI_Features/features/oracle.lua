local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Oracle: spoken boss warnings ("Soak", "Spread", "Interrupt", ...).
--
-- How it works
--   Midnight hides what a boss is casting from addons while you fight, so an
--   addon can no longer watch the combat log and shout "soak now". What the
--   game does allow is giving a SOUND FILE to every boss ability ("encounter
--   event") ahead of the fight: C_EncounterEvents.SetEventSound. The game
--   then plays it itself about 5 seconds before the ability is cast.
--
--   Oracle goes through the game's list of boss abilities (every raid boss
--   and every Mythic+ dungeon boss, current season included), reads the
--   ability text and the game's own role icons, decides what you have to do
--   (soak, spread, stack, interrupt, ...) and attaches the matching voice
--   clip. Nothing here depends on a boss mod.
--
-- Settings: profile.h3zOracle
-- Tests: Oracle.PlayCategory, Oracle.PlayAll, Oracle.PlayReal, Oracle.Check
---------------------------------------------------------------------------
if ns.Client and (ns.Client.isClassic or ns.Client.isForever) then return end

local PREFIX = "|cFF30D1FFOracle:|r "
local SOUND_DIR = "Interface\\AddOns\\H3z0UI_Features\\sounds\\oracle\\"

local DATA = ns.OracleData or { phrases = {}, rows = {}, Find = function() end }
local Oracle = {}
ns.Oracle = Oracle
_G.H3z0UI_Oracle = Oracle

local function Say(msg) print(PREFIX .. msg) end

---------------------------------------------------------------------------
-- callouts. role: only said for that role (when "only for my role" is on)
---------------------------------------------------------------------------
local CATEGORIES = {
    { key = "soak",      label = "Soak",              say = "Soak" },
    { key = "spread",    label = "Spread",            say = "Spread" },
    { key = "stack",     label = "Stack up",          say = "Stack up" },
    { key = "fixate",    label = "Fixate / chased",   say = "Fixate" },
    { key = "interrupt", label = "Interrupt",         say = "Interrupt" },
    { key = "knockback", label = "Knockback",         say = "Knockback" },
    { key = "hide",      label = "Line of sight",     say = "Line of sight" },
    { key = "move",      label = "Move out",          say = "Move" },
    { key = "adds",      label = "Adds",              say = "Adds" },
    { key = "raid",      label = "Raid damage",       say = "Raid damage" },
    { key = "dispel",    label = "Dispel",            say = "Dispel" },
    { key = "tank",      label = "Tank buster",       say = "Tank buster", role = "TANK" },
    { key = "healer",    label = "Healers",           say = "Heal up",     role = "HEALER" },
    { key = "deadly",    label = "Big hit (defensive)", say = "Big hit, defensive" },
    { key = "enrage",    label = "Enrage",            say = "Enrage" },
    { key = "alert",     label = "Other abilities (heads up)", say = "Heads up", default = false },
}
Oracle.CATEGORIES = CATEGORIES
local CAT = {}
for _, c in ipairs(CATEGORIES) do CAT[c.key] = c end

local function FileFor(key) return SOUND_DIR .. key .. ".ogg" end
Oracle.FileFor = FileFor

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.h3zOracle = p.h3zOracle or {}
    local s = p.h3zOracle
    if s.enabled == nil then s.enabled = true end
    if s.volume == nil then s.volume = 1 end
    if s.roleOnly == nil then s.roleOnly = true end
    if s.alsoOnWarning == nil then s.alsoOnWarning = false end
    if s.custom == nil then s.custom = true end
    if s.banner == nil then s.banner = true end
    if s.bannerUnknown == nil then s.bannerUnknown = true end
    if s.bannerSeconds == nil then s.bannerSeconds = 3 end
    if s.bannerScale == nil then s.bannerScale = 1 end
    s.cats = s.cats or {}
    for _, c in ipairs(CATEGORIES) do
        if s.cats[c.key] == nil then s.cats[c.key] = (c.default ~= false) end
    end
    return s
end
Oracle.Settings = Settings

---------------------------------------------------------------------------
-- reading the ability text
---------------------------------------------------------------------------
local function Plain(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local MASK = {
    Deadly = 1, Enrage = 2, Bleed = 4, Magic = 8, Disease = 16, Curse = 32, Poison = 64,
    Tank = 128, Healer = 256, Dps = 512,
}
do
    local e = _G.Enum and _G.Enum.EncounterEventIconmask
    if type(e) == "table" then
        MASK.Deadly = e.DeadlyEffect or MASK.Deadly
        MASK.Enrage = e.EnrageEffect or MASK.Enrage
        MASK.Bleed = e.BleedEffect or MASK.Bleed
        MASK.Magic = e.MagicEffect or MASK.Magic
        MASK.Disease = e.DiseaseEffect or MASK.Disease
        MASK.Curse = e.CurseEffect or MASK.Curse
        MASK.Poison = e.PoisonEffect or MASK.Poison
        MASK.Tank = e.TankRole or MASK.Tank
        MASK.Healer = e.HealerRole or MASK.Healer
        MASK.Dps = e.DpsRole or MASK.Dps
    end
end
local function Has(mask, bit)
    if type(mask) ~= "number" or not bit then return false end
    return math.floor(mask / bit) % 2 == 1
end
Oracle.Has = Has

-- ordered rules: the first category whose words appear wins
local RULES = {
    { "soak",      { "soak", "shared equally", "split between", "split among", "shared among", "shared by" } },
    { "spread",    { "spread out", "spread apart", "spread", "away from other", "from other players", "away from allies", "away from your allies" } },
    { "stack",     { "stack", "gather", "group up", "run together", "stand together" } },
    { "fixate",    { "fixate", "chases", "pursues", "pursuing", "hunts" } },
    { "interrupt", { "interrupt" } },
    { "knockback", { "knock", "hurls", "flings", "thrown" } },
    { "hide",      { "line of sight", "break line" } },
    { "dispel",    { "dispel" } },
    { "adds",      { "summons", "spawns", "adds", "reinforcements", "calls forth" } },
    { "move",      { "move out", "move away", "run away", "avoid", "dodge", "stay out", "get out", "leave the area", "on the ground", "frontal", "cone", "beam", "swirl", "pool of", "puddle", "eruption" } },
    { "raid",      { "all players", "all allies", "every player", "raid-wide", "raid wide", "entire raid", "the entire group", "all party members" } },
}

-- a word counts when it starts at the beginning of a word ("soak" matches "soaks")
local function ContainsAny(text, words)
    for _, w in ipairs(words) do
        local pattern = "%f[%a]" .. w:gsub("[%-%.%(%)%%%+%*%?%[%]%^%$]", "%%%0")
        if text:find(pattern) then return true end
    end
    return false
end

-- returns the category key (or nil) for an ability: name, description, icon mask
function Oracle.Classify(name, desc, mask)
    local text = ((name or "") .. " " .. (desc or "")):lower()
    if Has(mask, MASK.Tank) then return "tank" end
    for _, rule in ipairs(RULES) do
        if ContainsAny(text, rule[2]) then return rule[1] end
    end
    if Has(mask, MASK.Magic) or Has(mask, MASK.Curse) or Has(mask, MASK.Poison) or Has(mask, MASK.Disease) then
        return "dispel"
    end
    if Has(mask, MASK.Enrage) then return "enrage" end
    if Has(mask, MASK.Deadly) then return "deadly" end
    if Has(mask, MASK.Healer) then return "healer" end
    return nil
end

---------------------------------------------------------------------------
-- the game's list of boss abilities
---------------------------------------------------------------------------
local API = _G.C_EncounterEvents
local TRIG_WARNING, TRIG_FINISHED, TRIG_HIGHLIGHT = 0, 1, 2
do
    local t = _G.Enum and _G.Enum.EncounterEventSoundTrigger
    if type(t) == "table" then
        TRIG_WARNING = t.OnTextWarningShown or TRIG_WARNING
        TRIG_FINISHED = t.OnTimelineEventFinished or TRIG_FINISHED
        TRIG_HIGHLIGHT = t.OnTimelineEventHighlight or TRIG_HIGHLIGHT
    end
end

function Oracle.IsSupported()
    return type(API) == "table" and type(API.GetEventList) == "function"
        and type(API.GetEventInfo) == "function" and type(API.SetEventSound) == "function"
end

local state = {
    byEvent = {},      -- eventID -> { cat, name, spellID }
    applied = {},      -- eventID -> true while we hold a sound for it
    stats = { total = 0, classified = 0, pending = 0, applied = 0, failed = 0, byCat = {} },
    byCat = {},        -- cat -> list of eventIDs
    bySpell = {},      -- spellID -> entry (for the on-screen warning)
    rowMatched = {},   -- boss line row -> true when the game has that ability
    highlights = 0,    -- timeline highlight events seen this session
    passes = 0,
    running = false,
}
Oracle.state = state

local function PlayerRole()
    local spec = GetSpecialization and GetSpecialization()
    local role = spec and GetSpecializationRole and GetSpecializationRole(spec)
    return role or "DAMAGER"
end

local function WantedFor(cat, s)
    if not (s and s.enabled) then return false end
    if not s.cats[cat] then return false end
    local c = CAT[cat]
    if c and c.role and s.roleOnly and PlayerRole() ~= c.role then return false end
    return true
end

-- what Oracle says for one ability: voice clip key, colour, on-screen text (or nil = nothing)
local function Resolve(entry, s)
    if not (s and s.enabled) then return nil end
    local row = entry.row
    if row and s.custom ~= false then
        if row.role and s.roleOnly and PlayerRole() ~= row.role then return nil end
        local ph = DATA.phrases[row.say]
        if ph then return row.say, ph.cat, row.text end
        if CAT[row.say] then
            if not s.cats[row.say] then return nil end
            return row.say, row.say, row.text
        end
    end
    local cat = entry.cat
    if cat and WantedFor(cat, s) then return cat, cat, nil end
    return nil
end

local function SoundInfo(cat, s)
    return { file = FileFor(cat), channel = "Master", volume = s.volume or 1 }
end

local function Describe(spellID)
    local desc = ""
    if C_Spell and C_Spell.GetSpellDescription then
        desc = C_Spell.GetSpellDescription(spellID) or ""
    end
    if desc == "" and C_Spell and C_Spell.RequestLoadSpellData then
        C_Spell.RequestLoadSpellData(spellID)
        return nil
    end
    return desc
end

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
end

local function ReadEvent(id)
    local ok, info = pcall(API.GetEventInfo, id)
    if not ok or type(info) ~= "table" then return nil end
    local spellID = Plain(info.spellID)
    if type(spellID) ~= "number" or spellID == 0 then return nil end
    if info.enabled == false then return nil end
    return spellID, Plain(info.icons), Plain(info.severity)
end

local function ApplyOne(id, s)
    local entry = state.byEvent[id]
    if entry == false then return end
    if not entry then
        local spellID, mask = ReadEvent(id)
        if not spellID then
            state.byEvent[id] = false
            return
        end
        local desc = Describe(spellID)
        local name = SpellName(spellID)
        if desc == nil and not name then
            state.stats.pending = state.stats.pending + 1
            return -- description not loaded yet: next pass
        end
        local cat = Oracle.Classify(name, desc, mask)
        entry = { cat = cat, name = name or ("Spell " .. spellID), spellID = spellID, pendingDesc = (desc == nil) }
        entry.row = DATA.Find(spellID, name)
        if entry.pendingDesc then state.stats.pending = state.stats.pending + 1 end
        state.byEvent[id] = entry
    elseif entry.pendingDesc then
        -- try again for a description that was not loaded earlier
        local desc = Describe(entry.spellID)
        if desc ~= nil then
            entry.pendingDesc = false
            local _, mask = ReadEvent(id)
            entry.cat = Oracle.Classify(entry.name, desc, mask)
        else
            state.stats.pending = state.stats.pending + 1
        end
    end
    local voice, color, text = Resolve(entry, s)
    entry.voice, entry.color, entry.text = voice, color, text
    if voice then
        local ok = pcall(API.SetEventSound, id, TRIG_HIGHLIGHT, SoundInfo(voice, s))
        if ok then
            if s.alsoOnWarning then pcall(API.SetEventSound, id, TRIG_WARNING, SoundInfo(voice, s))
            elseif state.applied[id] == "both" then pcall(API.SetEventSound, id, TRIG_WARNING, nil) end
            state.applied[id] = s.alsoOnWarning and "both" or true
            state.stats.applied = state.stats.applied + 1
        else
            state.stats.failed = state.stats.failed + 1
        end
    elseif state.applied[id] then
        pcall(API.SetEventSound, id, TRIG_HIGHLIGHT, nil)
        pcall(API.SetEventSound, id, TRIG_WARNING, nil)
        state.applied[id] = nil
    end
end

local function Tally()
    local st = state.stats
    st.classified = 0
    st.byCat = {}
    state.byCat = {}
    state.bySpell = {}
    state.rowMatched = {}
    for id, entry in pairs(state.byEvent) do
        if entry and entry.row then state.rowMatched[entry.row] = true end
        if entry and (entry.cat or entry.row) and entry.spellID and not state.bySpell[entry.spellID] then
            state.bySpell[entry.spellID] = entry
        end
        if entry and entry.cat then
            st.classified = st.classified + 1
            st.byCat[entry.cat] = (st.byCat[entry.cat] or 0) + 1
            local list = state.byCat[entry.cat]
            if not list then list = {}; state.byCat[entry.cat] = list end
            list[#list + 1] = id
        end
    end
end

local retryTimer
function Oracle.Apply(reason)
    local s = Settings()
    if not s then return end
    if not Oracle.IsSupported() then return end
    if InCombatLockdown() then
        state.wantApply = true
        return
    end
    if state.running then state.again = true return end
    state.running = true
    state.wantApply = false
    if reason == "retry" then state.retries = (state.retries or 0) + 1 else state.retries = 0 end
    state.stats.pending, state.stats.applied, state.stats.failed = 0, 0, 0

    local ok, list = pcall(API.GetEventList)
    if not ok or type(list) ~= "table" then
        state.running = false
        return
    end
    state.stats.total = #list
    local i, n, CHUNK = 1, #list, 120
    local function Step()
        if InCombatLockdown() then
            state.running = false
            state.wantApply = true
            return
        end
        local last = math.min(n, i + CHUNK - 1)
        for k = i, last do ApplyOne(list[k], s) end
        i = last + 1
        if i <= n then
            C_Timer.After(0, Step)
        else
            state.running = false
            Tally()
            -- descriptions the client had to fetch: look once more shortly
            if state.stats.pending > 0 and (state.retries or 0) < 6 then
                if retryTimer then retryTimer:Cancel() end
                retryTimer = C_Timer.NewTimer(3, function() Oracle.Apply("retry") end)
            end
            if state.again then state.again = false; Oracle.Apply("again") end
        end
    end
    Step()
end


---------------------------------------------------------------------------
-- on-screen warning: a big word and the ability icon when the game's boss
-- timeline highlights an ability (the same moment the voice speaks)
---------------------------------------------------------------------------
local BANNER_COLOR = {
    soak = { 0.30, 1.00, 0.40 }, spread = { 1.00, 0.85, 0.20 }, stack = { 0.40, 0.80, 1.00 },
    fixate = { 1.00, 0.40, 0.40 }, interrupt = { 1.00, 0.60, 0.15 }, knockback = { 0.80, 0.55, 1.00 },
    hide = { 0.60, 0.60, 1.00 }, move = { 1.00, 0.85, 0.20 }, adds = { 1.00, 0.55, 0.30 },
    raid = { 1.00, 0.45, 0.45 }, dispel = { 0.45, 0.85, 1.00 }, tank = { 1.00, 0.30, 0.30 },
    healer = { 0.30, 1.00, 0.60 }, deadly = { 1.00, 0.20, 0.20 }, enrage = { 1.00, 0.20, 0.20 },
    alert = { 1.00, 1.00, 1.00 },
}
local BANNER_WORD = { deadly = "BIG HIT", healer = "HEAL UP", alert = "HEADS UP" }

local banner
local FADE_IN, FADE_OUT = 0.3, 0.7
local function BannerOnUpdate(f)
    local now = GetTime()
    local left = (f.expire or 0) - now
    if left <= 0 then
        f:Hide()
        return
    end
    local age = now - (f.started or now)
    local a = 1
    if age < FADE_IN then a = age / FADE_IN end
    if left < FADE_OUT then a = math.min(a, left / FADE_OUT) end
    f:SetAlpha(a)
end

local function BuildBanner()
    if banner then return banner end
    local f = CreateFrame("Frame", "H3z0UI_OracleBanner", UIParent)
    f:SetSize(460, 84)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:Hide()
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(64, 64)
    f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetColorTexture(0, 0, 0, 0.85)
    f.border:SetPoint("TOPLEFT", f.icon, "TOPLEFT", -2, 2)
    f.border:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 2, -2)
    local font = STANDARD_TEXT_FONT
    f.word = f:CreateFontString(nil, "OVERLAY")
    f.word:SetFont(font, 38, "OUTLINE")
    f.word:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 14, 2)
    f.word:SetJustifyH("LEFT")
    f.name = f:CreateFontString(nil, "OVERLAY")
    f.name:SetFont(font, 18, "OUTLINE")
    f.name:SetPoint("TOPLEFT", f.word, "BOTTOMLEFT", 0, -2)
    f.name:SetJustifyH("LEFT")
    f.name:SetTextColor(0.95, 0.95, 0.95, 1)
    f:SetScript("OnDragStart", function(self) if self.movable then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local s = Settings()
        if s then
            local point, _, rel, x, y = self:GetPoint()
            s.bannerPos = { point = point, rel = rel, x = x, y = y }
        end
    end)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnUpdate", BannerOnUpdate)
    banner = f
    return f
end

local function PlaceBanner(f)
    local s = Settings()
    f:SetScale((s and s.bannerScale) or 1)
    f:ClearAllPoints()
    local pos = s and s.bannerPos
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", -110, 200)
    end
end

-- word, category (colour), icon, ability name, seconds, movable (test only)
function Oracle.ShowBanner(word, cat, icon, name, seconds, movable)
    local f = BuildBanner()
    PlaceBanner(f)
    local c = BANNER_COLOR[cat] or { 1, 0.75, 0.3 }
    f.word:SetText(word or "")
    f.word:SetTextColor(c[1], c[2], c[3], 1)
    pcall(f.icon.SetTexture, f.icon, icon or 134400)
    pcall(f.name.SetText, f.name, name or "")
    f.movable = movable and true or false
    f:EnableMouse(f.movable)
    local s = Settings()
    f.started = GetTime()
    f.expire = f.started + (seconds or (s and s.bannerSeconds) or 3)
    f:SetAlpha(0)
    f:Show()
    state.bannerShown = (state.bannerShown or 0) + 1
    return f
end

local function WordFor(cat)
    return BANNER_WORD[cat] or (CAT[cat] and CAT[cat].say:upper()) or "INCOMING"
end

-- the game says a boss ability is about to happen (about 5 seconds ahead)
local function OnHighlight(id)
    state.highlights = (state.highlights or 0) + 1
    state.lastHighlight = GetTime()
    local s = Settings()
    if not (s and s.enabled and s.banner) then return end
    local info
    if _G.C_EncounterTimeline and C_EncounterTimeline.GetEventInfo and id ~= nil then
        local ok, i = pcall(C_EncounterTimeline.GetEventInfo, id)
        if ok and type(i) == "table" then info = i end
    end
    local spellID = info and Plain(info.spellID)
    local mask = info and Plain(info.icons)
    local cat, customText
    local known = type(spellID) == "number" and state.bySpell[spellID]
    if known then
        if not known.voice then return end        -- switched off or for another role
        cat, customText = known.color, known.text
    else
        if mask ~= nil then cat = Oracle.Classify(nil, nil, mask) end
        if cat and not WantedFor(cat, s) then return end
    end
    if not cat and not s.bannerUnknown then return end
    local icon = info and info.iconFileID
    if icon == nil and type(spellID) == "number" and C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(spellID)
    end
    Oracle.ShowBanner(customText or (cat and WordFor(cat)) or "INCOMING", cat, icon, info and info.spellName)
end

-- test: shows the warning (you can drag it where you want it)
function Oracle.TestBanner(key)
    local c = CAT[key] or CAT.soak
    local icon, name
    local list = state.byCat[c.key]
    if list and #list > 0 then
        local entry = state.byEvent[list[math.random(#list)]]
        if entry then
            name = entry.name
            if C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(entry.spellID) end
        end
    end
    Oracle.ShowBanner(WordFor(c.key), c.key, icon, name or "Example ability", 8, true)
    Say("|cff44ff44PASS|r  the warning is on your screen for 8 seconds. Drag it to where you want it.")
    return true
end

-- test: a real timeline event. The game adds a 7 second event to the boss
-- timeline; when its highlight arrives, Oracle must react.
function Oracle.TestLive()
    local TL = _G.C_EncounterTimeline
    if not (TL and TL.AddScriptEvent) then
        Say("|cffff5555FAIL|r  this game version has no boss timeline.")
        return false
    end
    local spellID = 6603
    local list = state.byCat.deadly or state.byCat.soak
    if list and state.byEvent[list[1]] then spellID = state.byEvent[list[1]].spellID end
    local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)) or 134400
    local before = state.highlights or 0
    local ok, id = pcall(TL.AddScriptEvent, {
        spellID = spellID, iconFileID = icon, duration = 7, overrideName = "Oracle test",
        icons = MASK.Deadly, severity = 2,
    })
    if not ok or not id then
        Say("|cffff5555FAIL|r  the game refused to add a test event to the timeline (" .. tostring(id) .. "). Try again outside combat.")
        return false
    end
    Say("test event added: the highlight comes in a few seconds, watch the screen for the warning (a test event has no voice, only real boss abilities do).")
    C_Timer.After(10, function()
        if (state.highlights or 0) > before then
            Say("|cff44ff44PASS|r  the game's timeline reached Oracle (the warning appeared).")
        else
            Say("|cffff5555FAIL|r  the timeline never sent a highlight for the test event. Oracle's on-screen warning can only be tested in a real fight then. Tell me and I will adjust.")
        end
        if TL.CancelScriptEvent then pcall(TL.CancelScriptEvent, id) end
    end)
    return true
end

---------------------------------------------------------------------------
-- tests
---------------------------------------------------------------------------
-- 1) the voice clip of one callout (proves the sound file is there and plays)
function Oracle.PlayCategory(key, quiet)
    local c = CAT[key]
    if not c then return false end
    local s = Settings()
    local willPlay = PlaySoundFile(FileFor(key), "Master")
    if not quiet then
        if willPlay then
            Say("|cff44ff44PASS|r  '" .. c.say .. "' played.")
        else
            Say("|cffff5555FAIL|r  '" .. c.say .. "' could not play. The sound files are new: close the game completely and start it again once (a /reload is not enough).")
        end
    end
    return willPlay and true or false
end

-- 2) every callout, one after the other
function Oracle.PlayAll()
    local s = Settings()
    local delay, shown = 0, 0
    for _, c in ipairs(CATEGORIES) do
        if s and s.cats[c.key] and (c.default ~= false) then
            shown = shown + 1
            C_Timer.After(delay, function()
                Say("test: " .. c.label)
                Oracle.PlayCategory(c.key, true)
            end)
            delay = delay + 1.6
        end
    end
    C_Timer.After(delay, function() Say("test finished: " .. shown .. " callouts.") end)
end

-- 3) the real thing: ask the game to play the sound it holds for one real boss ability
function Oracle.PlayReal(key)
    if not Oracle.IsSupported() then
        Say("|cffff5555FAIL|r  this game version has no boss ability sounds (C_EncounterEvents).")
        return false
    end
    local list = state.byCat[key]
    if not list or #list == 0 then
        Say("|cffffd100No ability found for '" .. (CAT[key] and CAT[key].label or tostring(key)) .. "' yet.|r Wait a few seconds after logging in, or use Check Setup.")
        return false
    end
    local s = Settings()
    if not WantedFor(key, s) then
        Say("'" .. CAT[key].label .. "' is switched off (or is for another role), so no sound is attached to its abilities.")
        return false
    end
    local id = list[math.random(#list)]
    local entry = state.byEvent[id]
    local ok, handle = pcall(API.PlayEventSound, id, TRIG_HIGHLIGHT)
    if ok and handle then
        Say("|cff44ff44PASS|r  played the game's own sound for the boss ability |cffffffff" .. tostring(entry.name) .. "|r (" .. CAT[key].label .. ").")
        return true
    end
    Say("|cffff5555FAIL|r  the game has no sound stored for |cffffffff" .. tostring(entry and entry.name) .. "|r. Use Check Setup.")
    return false
end

-- boss lines: how many of the dungeon lines this game version knows
function Oracle.CustomReport()
    local total, found = #DATA.rows, 0
    local per, order = {}, {}
    for _, r in ipairs(DATA.rows) do
        local d = per[r.dungeon]
        if not d then d = { total = 0, found = 0, miss = {} }; per[r.dungeon] = d; order[#order + 1] = r.dungeon end
        d.total = d.total + 1
        if state.rowMatched[r] then d.found = d.found + 1; found = found + 1 else d.miss[#d.miss + 1] = r.name end
    end
    Say((found > 0 and "|cff44ff44PASS|r  " or "|cffff5555FAIL|r  ") .. found .. " of " .. total .. " boss lines found their ability in this game.")
    for _, name in ipairs(order) do
        local d = per[name]
        local line = name .. ": " .. d.found .. " of " .. d.total
        if #d.miss > 0 then line = line .. "  (not found: " .. table.concat(d.miss, ", ") .. ")" end
        Say(line)
    end
    if found == 0 then Say("Nothing matched yet. Wait a few seconds after login, or the boss abilities are not in the game's list.") end
    return found, total
end

-- boss lines: all the voice lines, one after the other
function Oracle.PlayLines()
    local keys = {}
    for k in pairs(DATA.phrases) do keys[#keys + 1] = k end
    table.sort(keys)
    local delay, bad = 0, 0
    for _, k in ipairs(keys) do
        C_Timer.After(delay, function()
            local ok = PlaySoundFile(FileFor(k), "Master")
            Say((ok and "" or "|cffff5555FAIL|r  ") .. DATA.phrases[k].say)
            if not ok then bad = bad + 1 end
        end)
        delay = delay + 1.8
    end
    C_Timer.After(delay, function()
        Say((bad == 0 and "|cff44ff44PASS|r  " or "|cffff5555FAIL|r  ") .. #keys .. " boss voice lines played, " .. bad .. " could not play." .. (bad > 0 and " Close the game completely and start it again once (new sound files)." or ""))
    end)
end

-- boss lines: one random line of a dungeon, with voice and on-screen warning
function Oracle.TestLine(dungeon)
    local list = {}
    for _, r in ipairs(DATA.rows) do if r.dungeon == dungeon then list[#list + 1] = r end end
    if #list == 0 then Say("|cffff5555FAIL|r  no lines for " .. tostring(dungeon)) return false end
    local r = list[math.random(#list)]
    local ph = DATA.phrases[r.say]
    local key = r.say
    local ok = PlaySoundFile(FileFor(key), "Master")
    local icon
    local spellID = r.id
    for _, entry in pairs(state.byEvent) do
        if entry and entry.row == r then spellID = entry.spellID break end
    end
    if spellID and C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(spellID) end
    Oracle.ShowBanner(r.text, ph and ph.cat or r.say, icon, r.name .. "  (" .. r.boss .. ")", 6, true)
    local found = state.rowMatched[r] and "yes" or "no"
    Say((ok and "|cff44ff44PASS|r  " or "|cffff5555FAIL|r  ") .. r.dungeon .. ", " .. r.boss .. ": " .. r.name .. " -> " .. (ph and ph.say or r.say) .. ".  The game has this ability: " .. found .. ".")
    return ok and true or false
end

-- boss lines: every line of one dungeon or raid, one after the other (voice + on-screen warning)
function Oracle.TestInstance(name)
    local list = {}
    for _, r in ipairs(DATA.rows) do if r.dungeon == name then list[#list + 1] = r end end
    if #list == 0 then Say("|cffff5555FAIL|r  no lines for " .. tostring(name)) return false end
    if state.instanceTest then Say("a test is already running.") return false end
    state.instanceTest = true
    Say("testing " .. #list .. " lines of " .. name .. " (about " .. math.ceil(#list * 2.6) .. " seconds). Listen and watch the screen.")
    local played, found, lastBoss = 0, 0, nil
    for i, r in ipairs(list) do
        C_Timer.After((i - 1) * 2.6, function()
            if r.boss ~= lastBoss then
                lastBoss = r.boss
                Say("|cffffd100" .. r.boss .. "|r")
            end
            local ph = DATA.phrases[r.say]
            local ok = PlaySoundFile(FileFor(r.say), "Master")
            if ok then played = played + 1 end
            local spellID = r.id
            for _, entry in pairs(state.byEvent) do
                if entry and entry.row == r then spellID = entry.spellID break end
            end
            if state.rowMatched[r] then found = found + 1 end
            local icon = spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
            Oracle.ShowBanner(r.text, ph and ph.cat or r.say, icon, r.name, 2.4, false)
            Say("  " .. (ok and "" or "|cffff5555FAIL|r ") .. r.name .. " -> " .. (ph and ph.say or r.say) .. (r.role and ("  (" .. r.role:lower() .. " only)") or "") .. (state.rowMatched[r] and "" or "  |cffffd100[ability not found in this game]|r"))
        end)
    end
    C_Timer.After(#list * 2.6, function()
        state.instanceTest = false
        local allVoices = played == #list
        Say((allVoices and "|cff44ff44PASS|r  " or "|cffff5555FAIL|r  ") .. played .. " of " .. #list .. " voice lines played. " .. found .. " of " .. #list .. " abilities found in this game." .. (allVoices and "" or " Close the game completely and start it again once (new sound files)."))
    end)
    return true
end

-- 4) a full report
function Oracle.Check()
    local lines = {}
    local function Add(ok, text) lines[#lines + 1] = (ok and "|cff44ff44PASS|r  " or "|cffff5555FAIL|r  ") .. text end
    local s = Settings()
    Add(Oracle.IsSupported(), "boss ability sounds are available in this game version")
    Add(s and s.enabled, "Oracle is switched on")
    -- the voice clips (one is played, you should hear "Soak")
    local heard = PlaySoundFile(FileFor("soak"), "Master")
    Add(heard and true or false, "voice clips found and playing (you should hear \"Soak\"" .. (heard and ")" or "): close the game completely and start it again once, the sound files are new"))
    if Oracle.IsSupported() then
        local st = state.stats
        Add(st.total > 0, st.total .. " boss abilities known to the game")
        Add(st.classified > 0, st.classified .. " of them got a callout (" .. st.applied .. " have a sound attached)")
        if st.pending > 0 then lines[#lines + 1] = "|cffffd100…|r  " .. st.pending .. " ability descriptions are still loading, check again in a few seconds" end
        if st.failed > 0 then Add(false, st.failed .. " abilities refused the sound") end
        -- really ask the game: does it hold our file?
        local checked, good = 0, 0
        for _, list in pairs(state.byCat) do
            for k = 1, math.min(3, #list) do
                local id = list[k]
                if state.applied[id] then
                    checked = checked + 1
                    local ok, info = pcall(API.GetEventSound, id, TRIG_HIGHLIGHT)
                    if ok and type(info) == "table" and info.file then good = good + 1 end
                end
            end
        end
        if checked > 0 then Add(good == checked, "the game confirms the sound is stored for " .. good .. " of " .. checked .. " sampled abilities") end
        local parts = {}
        for _, c in ipairs(CATEGORIES) do
            local n = st.byCat[c.key]
            if n then parts[#parts + 1] = c.label .. " " .. n end
        end
        if #parts > 0 then lines[#lines + 1] = "abilities per callout: " .. table.concat(parts, ", ") end
    end
    do
        local found = 0
        for _ in pairs(state.rowMatched or {}) do found = found + 1 end
        Add(found > 0, "boss lines: " .. found .. " of " .. #DATA.rows .. " dungeon abilities found in this game")
    end
    do
        local frameOk = pcall(BuildBanner)
        Add(frameOk and banner ~= nil, "on-screen warning is ready")
        Add(state.listening and true or false, "listening to the boss timeline (highlight events)")
        lines[#lines + 1] = "highlights seen this session: " .. (state.highlights or 0) .. ", warnings shown: " .. (state.bannerShown or 0)
    end
    lines[#lines + 1] = "your role: " .. PlayerRole()
    for _, l in ipairs(lines) do Say(l) end
    Oracle.lastReport = lines
    return lines
end

function Oracle.Counts()
    return state.stats.byCat or {}
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
_G.H3z0UI_RefreshOracle = function() Oracle.Apply("settings") end

local debounce
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("SPELL_DATA_LOAD_RESULT")
state.listening = pcall(ev.RegisterEvent, ev, "ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT" then
        pcall(OnHighlight, arg1)
    elseif event == "SPELL_DATA_LOAD_RESULT" then
        if not (state.stats.pending > 0) then return end
        if debounce then debounce:Cancel() end
        debounce = C_Timer.NewTimer(1.5, function() Oracle.Apply("data") end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if state.wantApply then Oracle.Apply("combat") end
    elseif event == "PLAYER_LOGIN" then
        Settings()
        C_Timer.After(4, function() Oracle.Apply("login") end)
    else
        C_Timer.After(2, function() Oracle.Apply("event") end)
    end
end)
