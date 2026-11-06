local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Interrupt Tracker
--   List: one bar per group member who has an interrupt, in class colour,
--         full and bright when ready, shrinking and dim while on cooldown,
--         with the seconds left.
--   Icon: your own interrupt with its cooldown and a green / red border.
--
-- How it knows: it watches every cast of the group (and their pets) and
-- starts the cooldown of the interrupt it sees, using the base cooldown of
-- that spell. Cooldown reductions of talents are not known, so a member
-- can come back a little earlier than the bar says. When the game hides the
-- spell of a cast in combat (secret value) that cast cannot be seen; your
-- own cooldown is read from the game when it allows it. A landed interrupt
-- also tells who did it, so group members' cooldowns start from that too.
--
-- Settings: profile.h3zInterrupts
---------------------------------------------------------------------------
if ns.Client and (ns.Client.isClassic or ns.Client.isForever) then return end

local PREFIX = "|cFF30D1FFInterrupts:|r "
local I = {}
ns.Interrupts = I
_G.H3z0UI_Interrupts = I

local function Say(msg) print(PREFIX .. msg) end

---------------------------------------------------------------------------
-- spells: [spellID] = cooldown in seconds
---------------------------------------------------------------------------
local SPELLS = {
    [47528]  = 15, -- Mind Freeze
    [183752] = 15, -- Disrupt
    [106839] = 15, -- Skull Bash
    [78675]  = 60, -- Solar Beam
    [351338] = 40, -- Quell
    [147362] = 24, -- Counter Shot
    [187707] = 15, -- Muzzle
    [2139]   = 24, -- Counterspell
    [116705] = 15, -- Spear Hand Strike
    [96231]  = 15, -- Rebuke
    [15487]  = 45, -- Silence
    [1766]   = 15, -- Kick
    [57994]  = 12, -- Wind Shear
    [119910] = 24, -- Spell Lock (pet)
    [119914] = 30, -- Axe Toss (pet)
    [132409] = 24, -- Spell Lock (Grimoire of Sacrifice)
    [6552]   = 15, -- Pummel
}

-- per class: the interrupt to show first, and who has none
local CLASS = {
    DEATHKNIGHT = { 47528 },
    DEMONHUNTER = { 183752 },
    DRUID       = { 106839, 78675, noHealer = true },
    EVOKER      = { 351338, noHealer = true },
    HUNTER      = { 147362, 187707 },
    MAGE        = { 2139 },
    MONK        = { 116705, noHealer = true },
    PALADIN     = { 96231, noHealer = true },
    PRIEST      = { 15487, noHealer = true },
    ROGUE       = { 1766 },
    SHAMAN      = { 57994 },
    WARLOCK     = { 119910, 119914 },
    WARRIOR     = { 6552 },
}

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.h3zInterrupts = p.h3zInterrupts or {}
    local s = p.h3zInterrupts
    if s.enabled == nil then s.enabled = false end
    if s.showList == nil then s.showList = true end
    if s.showIcon == nil then s.showIcon = true end
    if s.showCounts == nil then s.showCounts = true end
    if s.onlyInstance == nil then s.onlyInstance = false end
    if s.scale == nil then s.scale = 1 end
    return s
end
I.Settings = Settings

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------
local base = {}      -- [slot] = what the game's meter already counted when the counting last started
local rawTotals = {}
local rawAmount = {}   -- [slot] = the meter's total for that member as the game gave it (maybe hidden)
local counts = {}    -- [slot] = interrupts done this run (the game's damage meter, or seen by the tracker)
I._counts = counts
local used = {}     -- [guid] = { spell = id, start = time, cd = seconds }
I._used = used
local testUntil = 0
local testData
local list, icon

local function Plain(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- self test (/h3z0ui inttest): made-up group members stand in for the real group
local virtual = nil
local selfTesting = false
local function UExists(u)
    if virtual and type(u) == "string" and u:find("^party%d$") then return virtual[u] ~= nil end
    return UnitExists(u)
end
local function UClass(u)
    if virtual and virtual[u] then return virtual[u].name, virtual[u].class end
    return UnitClass(u)
end
local function UName(u)
    if virtual and virtual[u] then return virtual[u].name end
    return UnitName(u)
end
local function URole(u)
    if virtual and virtual[u] then return virtual[u].role end
    return UnitGroupRolesAssigned and UnitGroupRolesAssigned(u)
end
local function UInGroup()
    if virtual then return true end
    return IsInGroup()
end

local function ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.7, 0.7, 0.7
end

local function SpellIcon(id)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    return (info and info.iconID) or 134400
end

---------------------------------------------------------------------------
-- own interrupt
---------------------------------------------------------------------------
local function OwnSpell()
    local _, class = UnitClass("player")
    local t = class and CLASS[class]
    if not t then return nil end
    for _, id in ipairs(t) do
        if type(id) == "number" and IsPlayerSpell and IsPlayerSpell(id) then return id end
    end
    if class == "WARLOCK" then return t[1] end
    return nil
end

-- start, duration for your own interrupt; nil when ready
local function OwnCooldown(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(cd) == "table" then
            local st, du = Plain(cd.startTime), Plain(cd.duration)
            if type(st) == "number" and type(du) == "number" then
                if du > 1.6 and st > 0 then return st, du end
                if du <= 1.6 then
                    -- only the global cooldown: fall through to the tracked cast
                    local u = used["player"]
                    if u and GetTime() < u.start + u.cd then return u.start, u.cd end
                    return nil
                end
                return nil
            end
        end
    end
    local u = used["player"]
    if u and GetTime() < u.start + u.cd then return u.start, u.cd end
    return nil
end

---------------------------------------------------------------------------
-- group
---------------------------------------------------------------------------
local function UnitUnits()
    local units = { "player" }
    for i = 1, 4 do units[#units + 1] = "party" .. i end
    return units
end

local function UnitList()
    local units = { "player" }
    if UInGroup() and not IsInRaid() then
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    return units
end

local function MemberRows()
    local rows = {}
    if testUntil > GetTime() and testData then
        for _, r in ipairs(testData) do rows[#rows + 1] = r end
        return rows
    end
    for _, unit in ipairs(UnitList()) do
        if UExists(unit) then
            local _, class = UClass(unit)
            local def = class and CLASS[class]
            local u = used[unit]
            if u and u.name then
                local cur = Plain(UName(unit))
                if cur and cur ~= u.name then u = nil end   -- somebody else took this slot
            end
            local role = URole(unit)
            local has = def and not (def.noHealer and role == "HEALER")
            if u or has then
                local id = (u and u.spell) or (def and def[1])
                local now = GetTime()
                local left, cd = 0, (u and u.cd) or SPELLS[id] or 15
                if u and now < u.start + u.cd then left = u.start + u.cd - now end
                rows[#rows + 1] = { name = UName(unit) or "?", class = class, left = left, cd = cd, spell = id, count = counts[unit], countRaw = rawAmount[unit], countBase = base[unit] or 0 }
            end
        end
    end
    table.sort(rows, function(a, b)
        if (a.left > 0) ~= (b.left > 0) then return a.left == 0 end
        if a.left ~= b.left then return a.left < b.left end
        return a.name < b.name
    end)
    return rows
end

---------------------------------------------------------------------------
-- frames
---------------------------------------------------------------------------
local ROW_H, ROW_GAP, LIST_W = 20, 2, 190

local function SavePos(f, key)
    local s = Settings()
    if not s then return end
    local point, _, rel, x, y = f:GetPoint()
    s[key] = { point = point, rel = rel, x = x, y = y }
end

local function PlaceFrame(f, key, dx, dy)
    local s = Settings()
    if f.dragging then return end
    f:ClearAllPoints()
    local pos = s and s[key]
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
    end
    f:SetScale((s and s.scale) or 1)
end

local function MakeMovable(f, key)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if self.movable then self.dragging = true; self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dragging = false
        SavePos(self, key)
    end)
end

local histFrame
local function BuildList()
    if list then return list end
    local f = CreateFrame("Frame", "H3z0UI_InterruptList", UIParent)
    f:SetSize(LIST_W, ROW_H)
    f:SetFrameStrata("MEDIUM")
    MakeMovable(f, "listPos")
    f.rows = {}
    -- a small button above the list opens the history of the runs
    local b = CreateFrame("Button", nil, f)
    b:SetSize(38, 14)
    b:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 2)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0, 0, 0, 0.55)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    b.text:SetPoint("CENTER")
    b.text:SetText("Log")
    b:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.25, 0.25, 0.3, 0.85)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Interrupts by run")
            GameTooltip:AddLine("Click to open the history of your Mythic+ runs.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0, 0, 0, 0.55)
        if GameTooltip then GameTooltip:Hide() end
    end)
    b:SetScript("OnClick", function()
        if histFrame and histFrame:IsShown() then histFrame:Hide() else I.ShowHistory() end
    end)
    f.logButton = b
    list = f
    return f
end

local function GetRow(i)
    local f = BuildList()
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, f)
    r:SetSize(LIST_W, ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(0, 0, 0, 0.45)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.ico = r:CreateTexture(nil, "OVERLAY")
    r.ico:SetSize(ROW_H, ROW_H)
    r.ico:SetPoint("RIGHT", r, "LEFT", -2, 0)
    r.ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.x = r:CreateTexture(nil, "OVERLAY", nil, 2)
    r.x:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    r.x:SetAllPoints(r.ico)
    r.x:Hide()
    r.name = r:CreateFontString(nil, "OVERLAY")
    r.name:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    r.name:SetPoint("LEFT", r, "LEFT", 6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWidth(LIST_W - 46)
    r.name:SetWordWrap(false)
    r.time = r:CreateFontString(nil, "OVERLAY")
    r.time:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    r.time:SetPoint("RIGHT", r, "RIGHT", -5, 0)
    r.time:SetJustifyH("RIGHT")
    r.count = r:CreateFontString(nil, "OVERLAY")
    r.count:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    r.count:SetPoint("RIGHT", r, "RIGHT", -30, 0)
    r.count:SetJustifyH("RIGHT")
    r.count:SetTextColor(1, 0.85, 0.3, 1)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -((i - 1) * (ROW_H + ROW_GAP)))
    f.rows[i] = r
    return r
end

local function BuildIcon()
    if icon then return icon end
    local f = CreateFrame("Frame", "H3z0UI_InterruptIcon", UIParent)
    f:SetSize(46, 46)
    f:SetFrameStrata("MEDIUM")
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints()
    f.border:SetColorTexture(0.2, 0.9, 0.3, 1)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", 2, -2)
    f.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.shade = f:CreateTexture(nil, "OVERLAY")
    f.shade:SetPoint("TOPLEFT", 2, -2)
    f.shade:SetPoint("BOTTOMRIGHT", -2, 2)
    f.shade:SetColorTexture(0, 0, 0, 0.55)
    f.num = f:CreateFontString(nil, "OVERLAY")
    f.num:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
    f.num:SetPoint("CENTER")
    MakeMovable(f, "iconPos")
    icon = f
    return f
end

local function Visible(s)
    if selfTesting then return true end
    if not (s and s.enabled) then return false end
    if testUntil > GetTime() then return true end
    if s.onlyInstance then
        local inInst = IsInInstance and IsInInstance()
        if not inInst then return false end
    end
    return true
end

function I.Update()
    local s = Settings()
    if not s then return end
    local show = Visible(s)
    local testing = testUntil > GetTime()

    if show and s.showList and (testing or selfTesting or UInGroup()) then
        local f = BuildList()
        PlaceFrame(f, "listPos", -430, -60)
        f.movable = testing
        f:EnableMouse(testing)
        local rows = MemberRows()
        for i, d in ipairs(rows) do
            local r = GetRow(i)
            local cr, cg, cb = ClassColor(d.class)
            local ready = d.left <= 0
            local frac = ready and 1 or math.max(0.04, 1 - d.left / math.max(d.cd, 1))
            r.bar:SetWidth(math.max(1, LIST_W * frac))
            r.bar:SetColorTexture(cr, cg, cb, ready and 0.95 or 0.55)
            r.name:SetText(d.name)
            r.name:SetTextColor(1, 1, 1, ready and 1 or 0.75)
            r.time:SetText(ready and "" or string.format("%d", math.ceil(d.left)))
            local n = s.showCounts and d.count
            if n and n > 0 then
                r.count:SetText(tostring(n))
            elseif s.showCounts and d.countRaw ~= nil and (d.countBase or 0) == 0 then
                -- the game hides the number from addons but lets it be shown as it is
                if not pcall(r.count.SetFormattedText, r.count, "%d", d.countRaw) then r.count:SetText("") end
            else
                r.count:SetText("")
            end
            pcall(r.ico.SetTexture, r.ico, SpellIcon(d.spell))
            -- on cooldown: a grey icon with a red X over it, like a missing check mark
            r.ico:SetDesaturated(not ready)
            r.ico:SetVertexColor(ready and 1 or 0.6, ready and 1 or 0.6, ready and 1 or 0.6)
            r.x:SetShown(not ready)
            r.time:SetTextColor(1, 0.35, 0.35, 1)
            r:Show()
        end
        for i = #rows + 1, #f.rows do f.rows[i]:Hide() end
        f:SetHeight(math.max(ROW_H, #rows * (ROW_H + ROW_GAP)))
        f:SetShown(#rows > 0)
    elseif list then
        list:Hide()
    end

    if show and s.showIcon then
        local id = testing and 1766 or OwnSpell()
        if id then
            local f = BuildIcon()
            PlaceFrame(f, "iconPos", -250, -60)
            f.movable = testing
            f:EnableMouse(testing)
            pcall(f.tex.SetTexture, f.tex, SpellIcon(id))
            local st, du
            if testing then
                local left = 10 - (GetTime() % 12)
                if left > 0 then st, du = GetTime() - (15 - left), 15 end
            else
                st, du = OwnCooldown(id)
            end
            if st and du then
                local left = st + du - GetTime()
                if left > 0 then
                    f.border:SetColorTexture(0.85, 0.15, 0.15, 1)
                    f.shade:Show()
                    f.num:SetText(string.format("%d", math.ceil(left)))
                    f:Show()
                    return
                end
            end
            f.border:SetColorTexture(0.2, 0.9, 0.3, 1)
            f.shade:Hide()
            f.num:SetText("")
            f:Show()
        elseif icon then
            icon:Hide()
        end
    elseif icon then
        icon:Hide()
    end
end

---------------------------------------------------------------------------
-- test
---------------------------------------------------------------------------
function I.IsUnlocked() return testUntil == math.huge end

-- seconds nil / 0: stays on and movable until Lock
function I.Test(seconds)
    local s = Settings()
    if not s then return end
    testData = {
        { name = "Player 1",    class = "SHAMAN",  left = 0,  cd = 12, spell = 57994, count = 6 },
        { name = "Player 2",  class = "DRUID",   left = 9,  cd = 15, spell = 106839, count = 3 },
        { name = "Player 3",   class = "PRIEST",  left = 31, cd = 45, spell = 15487, count = 1 },
        { name = "Player 4",     class = "WARLOCK", left = 0,  cd = 24, spell = 119910, count = 9 },
    }
    if seconds and seconds > 0 then
        testUntil = GetTime() + seconds
        Say("Test for " .. seconds .. " seconds. Drag the list and the icon where you want them.")
    else
        testUntil = math.huge
        Say("Unlocked. Drag the list and the icon where you want them, then press Lock.")
    end
    I.Update()
end

function I.Lock()
    testUntil = 0
    if list then list.dragging = false end
    if icon then icon.dragging = false end
    Say("Locked.")
    I.Update()
end

function I.ToggleUnlock()
    if I.IsUnlocked() then I.Lock() else I.Test(0) end
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
-- the cooldown is stored under the group slot (player, party1 ... party4), not the GUID:
-- the game can hide a member's GUID, and a hidden value cannot be a table key
local function OwnerGuid(unit)
    if unit == "pet" then return "player" end
    local n = unit:match("^partypet(%d)$")
    if n then return "party" .. n end
    return unit
end
local function Mark(unit, spell, cd)
    local key = OwnerGuid(unit)
    local owner = key
    local nm = Plain(UName(owner))
    used[key] = { spell = spell, start = GetTime(), cd = cd, name = nm }
end

local castTimes = {}   -- [party slot] = time of the last cast of that member (what they cast may be hidden)
-- debug: /h3z0ui intdebug prints what the game tells us about casts and interrupts
local debugOn = false
function I.SetDebug(on) debugOn = on and true or false end
function I.IsDebug() return debugOn end
local function Dbg(...)
    if not debugOn then return end
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if issecretvalue and issecretvalue(v) then parts[#parts + 1] = "<secret>" else parts[#parts + 1] = tostring(v) end
    end
    print(PREFIX .. table.concat(parts, " "))
end

-- some casters (a Delve companion, other versions of a spell) use another spell ID
-- for the same interrupt: match them by name
local NAMES
local function NameToId(spellID)
    if not (C_Spell and C_Spell.GetSpellName) then return nil end
    if not NAMES then
        NAMES = {}
        for id in pairs(SPELLS) do
            local ok, nm = pcall(C_Spell.GetSpellName, id)
            if ok and type(nm) == "string" and nm ~= "" then NAMES[nm] = id end
        end
    end
    local ok, nm = pcall(C_Spell.GetSpellName, spellID)
    if ok and type(nm) == "string" then return NAMES[nm] end
    return nil
end

local function OnCast(unit, spellID)
    local raw = spellID
    spellID = Plain(spellID)
    if unit ~= "player" and unit ~= "pet" then
        local slot = unit:match("^partypet(%d)$") or unit:match("^party(%d)$")
        if slot then castTimes["party" .. slot] = GetTime() end
    end
    if debugOn and unit ~= "player" and unit ~= "pet" then
        Dbg("cast", unit, spellID == nil and "spell hidden" or spellID)
    end
    if type(spellID) ~= "number" then return end
    local cd = SPELLS[spellID]
    if not cd then
        local alias = NameToId(spellID)
        if not alias then return end
        spellID, cd = alias, SPELLS[alias]
    end
    if not cd then return end
    Mark(unit, spellID, cd)
    if unit == "player" and I.Broadcast then I.Broadcast(spellID) end
end

-- The game hides the spell of other players' casts in combat, but when an
-- interrupt lands it says who did it (the GUID of the interrupter, a plain value
-- unless the game hides it too). That GUID is matched to a group member or their
-- pet and the usual interrupt of their class starts its cooldown.
-- When the game hides both the interrupter and the spell, the timing still tells a
-- story: an enemy cast was interrupted (the game says "by somebody" without saying who)
-- and exactly one member whose interrupt is ready cast something at that moment.
-- That is a good guess, not a certainty; it is skipped when it is not clear.
local function ResolveByTiming(ti)
    local now = GetTime()
    local mine = used["player"]
    if mine and math.abs(mine.start - ti) <= 0.35 then return end   -- your own interrupt
    local cands = {}
    for i = 1, 4 do
        local unit = "party" .. i
        local tc = castTimes[unit]
        if tc and math.abs(tc - ti) <= 0.35 and UExists(unit) then
            local _, class = UClass(unit)
            local def = class and CLASS[class]
            local role = URole(unit)
            local has = def and not (def.noHealer and role == "HEALER")
            local u = used[unit]
            local ready = not (u and now < u.start + u.cd)
            if has and ready then cands[#cands + 1] = { unit = unit, class = class, def = def } end
        end
    end
    if #cands ~= 1 then
        if debugOn then Dbg("timing: candidates", #cands, "- not guessed") end
        return
    end
    local c = cands[1]
    local spell = c.def[1]
    if spell and SPELLS[spell] then
        if debugOn then Dbg("timing: guessed", c.unit, c.class) end
        Mark(c.unit, spell, SPELLS[spell])
        counts[c.unit] = (counts[c.unit] or 0) + 1
    end
end

local function OnInterrupted(...)
    do
        -- unit, castGUID, spellID, interruptedBy, castBarID: interruptedBy is empty when the
        -- cast just stopped, and set (maybe hidden) when somebody interrupted it
        local unit = Plain((...))
        local by = select(4, ...)
        local friendly = type(unit) == "string" and (unit:find("^party") or unit:find("^player") or unit:find("^pet") or unit:find("^raid"))
        if by ~= nil and not friendly then
            local ti = GetTime()
            C_Timer.After(0.4, function() pcall(ResolveByTiming, ti) end)
        end
    end
    if debugOn then
        local parts = {}
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            parts[#parts + 1] = (issecretvalue and issecretvalue(v)) and "<secret>" or tostring(v)
        end
        Dbg("interrupted:", table.concat(parts, ", "))
    end
    local by
    for i = 1, select("#", ...) do
        local v = Plain((select(i, ...)))
        if type(v) == "string" and (v:find("^Player%-") or v:find("^Pet%-") or v:find("^Creature%-")) then
            -- the interrupted unit's cast GUID starts with "Cast-"; the interrupter is a unit GUID
            by = v
        end
    end
    if not by then return end
    local units = { "player", "pet" }
    for i = 1, 4 do units[#units + 1] = "party" .. i; units[#units + 1] = "partypet" .. i end
    for _, unit in ipairs(units) do
        if UExists(unit) then
            local g = Plain(UnitGUID(unit))
            if g and g == by then
                local ownerUnit = unit
                if unit == "pet" then ownerUnit = "player" end
                local pn = unit:match("^partypet(%d)$")
                if pn then ownerUnit = "party" .. pn end
                local _, class = UClass(ownerUnit)
                local def = class and CLASS[class]
                local spell = def and def[1]
                if unit:find("pet") and class == "WARLOCK" then spell = 119910 end
                if spell and SPELLS[spell] then Mark(unit, spell, SPELLS[spell]) end
                counts[ownerUnit] = (counts[ownerUnit] or 0) + 1
                return
            end
        end
    end
end

-- Second source: the game's own damage meter counts interrupts per player. When
-- a member's count goes up, they just interrupted something. That works even
-- when the spell of the cast is hidden, as long as the game lets us read the
-- numbers (it does not always in combat; /h3z0ui intdebug shows what it says).
local meterLast = {}
local meterSecretNoted = false
local function MemberByMeterSource(src, units)
    local guid = Plain(src.sourceGUID)
    local name = Plain(src.name)
    local class = Plain(src.classFilename)
    local classMatches, classUnit = 0, nil
    for _, unit in ipairs(units) do
        if UExists(unit) then
            local g = Plain(UnitGUID(unit))
            if guid and g == guid then return unit end
            local n = Plain(UName(unit))
            if name and n and (n == name or n:gsub("%-.*$", "") == name:gsub("%-.*$", "")) then return unit end
            local _, c = UClass(unit)
            if class and Plain(c) == class then classMatches = classMatches + 1; classUnit = unit end
        end
    end
    if not guid and not name and classMatches == 1 then return classUnit end
    return nil
end

-- how many interrupts each member did: the game's own damage meter counts them for the
-- whole run (when it lets addons read the numbers; they are hidden in some fights, then the
-- last known number stays)
function I._ReadCounts(units)
    if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and Enum and Enum.DamageMeterType
        and Enum.DamageMeterSessionType) then return end
    for _, st in ipairs({ "Overall", "Current" }) do
        local kind = Enum.DamageMeterSessionType[st]
        if kind ~= nil then
            local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, kind, Enum.DamageMeterType.Interrupts)
            if ok and type(session) == "table" and type(session.combatSources) == "table" then
                for _, src in ipairs(session.combatSources) do
                    local amount = Plain(src.totalAmount)
                    if type(amount) == "number" and amount > 0 then
                        local unit = MemberByMeterSource(src, units)
                        if not unit and Plain(src.isLocalPlayer) == true then unit = "player" end
                        if unit then
                            if amount > (rawTotals[unit] or 0) then rawTotals[unit] = amount end
                            local v = amount - (base[unit] or 0)
                            if v > (counts[unit] or 0) then counts[unit] = v end
                        end
                    end
                end
            end
        end
    end
end

-- Who kicked, from the shape of the meter's interrupt list rather than its numbers.
-- In combat the game hides the amounts, but what it does not hide is the list itself: which
-- rows exist, their class, spec icon and whether one is you, the order of the rows (the
-- game orders them by count) and how long each member's spell list is. The moment an
-- interrupt lands the game tells us the interrupt list changed (an event). Then:
--   - a row that was not there before: that member kicked for the first time
--   - a row that moved up past another row: that member's count passed the other's
--   - a member whose own spell list got longer: that member kicked a new spell
-- Only those cases name a kicker, and only when the row belongs to exactly one group
-- member; two members of one class that cannot be told apart are left alone.
local snap          -- { sid, rows = { { key, unit } ... }, lens = { [unit] = n } }

local function RowKey(src)
    return tostring(Plain(src.classFilename)) .. ":" .. tostring(Plain(src.specIconID))
end

local function UnitForRow(src, units)
    if Plain(src.isLocalPlayer) == true then return "player" end
    return MemberByMeterSource(src, units)
end

local function KickedBy(unit, why)
    if not unit or unit == "player" then return end
    local _, class = UClass(unit)
    local def = class and CLASS[class]
    local spell = def and def[1]
    if not (spell and SPELLS[spell]) then return end
    local u = used[unit]
    if u and GetTime() - u.start < 1.5 then return end   -- seen a moment ago by another way
    if debugOn then Dbg("meter shape: kick by", unit, class, why) end
    Mark(unit, spell, SPELLS[spell])
    counts[unit] = math.max(counts[unit] or 0, 0) + 1
end

function I._Structural(session, sid)
    if type(session) ~= "table" or type(session.combatSources) ~= "table" then return end
    local units = UnitUnits()
    local rows = {}
    for i, src in ipairs(session.combatSources) do
        local unit = UnitForRow(src, units)
        rows[i] = { key = RowKey(src), unit = unit }
        if unit then rawAmount[unit] = src.totalAmount end
    end
    -- spell list length of every other member (their group GUID is readable)
    local lens = {}
    if C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType and Enum and Enum.DamageMeterType then
        for i = 1, 4 do
            local unit = "party" .. i
            if UExists(unit) then
                local g = Plain(UnitGUID(unit))
                if g then
                    local ok, info = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
                        Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.Interrupts, g)
                    local list = ok and type(info) == "table" and info.combatSpells
                    if type(list) == "table" then lens[unit] = #list end
                end
            end
        end
    end
    local before = snap
    snap = { sid = sid, rows = rows, lens = lens }
    if not before or before.sid ~= sid then return end    -- the first look is only a starting point

    -- new rows
    local prevCount, seen = {}, {}
    for _, r in ipairs(before.rows) do prevCount[r.key] = (prevCount[r.key] or 0) + 1 end
    local inList = {}
    for _, r in ipairs(rows) do inList[r.key] = (inList[r.key] or 0) + 1 end
    for _, r in ipairs(rows) do
        seen[r.key] = (seen[r.key] or 0) + 1
        -- a class and spec that shows up twice cannot be told apart: no guess
        if seen[r.key] > (prevCount[r.key] or 0) and inList[r.key] == 1 then KickedBy(r.unit, "new row") end
    end
    -- rows that moved up past another one (rows whose key is in the list once only)
    local prevIdx, curCount = {}, {}
    for i, r in ipairs(before.rows) do
        if prevCount[r.key] == 1 then prevIdx[r.key] = i end
    end
    for _, r in ipairs(rows) do curCount[r.key] = (curCount[r.key] or 0) + 1 end
    local common = {}
    for _, r in ipairs(rows) do
        if prevIdx[r.key] and curCount[r.key] == 1 then common[#common + 1] = r end
    end
    for a = 1, #common do
        for b = a + 1, #common do
            if prevIdx[common[a].key] > prevIdx[common[b].key] then   -- a was behind b, is now ahead
                KickedBy(common[a].unit, "moved up")
                break
            end
        end
    end
    -- longer spell lists
    for unit, n in pairs(lens) do
        local was = before.lens and before.lens[unit]
        if was and n > was then KickedBy(unit, "new spell") end
    end
end

-- the game says the interrupt list changed
local function OnMeterUpdated(sid)
    local s = Settings()
    if not (s and s.enabled) or not UInGroup() then return end
    if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and Enum and Enum.DamageMeterSessionType) then return end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType,
        Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.Interrupts)
    if ok then I._Structural(session, Plain(sid) or 0) end
end

local countsReadAt
local function PollMeter()
    if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and Enum and Enum.DamageMeterType
        and Enum.DamageMeterSessionType) then return end
    if not UInGroup() then return end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType,
        Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.Interrupts)
    if not ok or type(session) ~= "table" then return end
    local sources = session.combatSources
    if type(sources) ~= "table" then return end
    local units = { "player" }
    for i = 1, 4 do units[#units + 1] = "party" .. i end
    -- the run totals change slowly: read them every 2 seconds, not with every poll
    local now = GetTime()
    if not countsReadAt or now - countsReadAt >= 2 then
        countsReadAt = now
        I._ReadCounts(units)
    end
    for idx, src in ipairs(sources) do
        local amount = Plain(src.totalAmount)
        if debugOn and not meterSecretNoted then
            meterSecretNoted = true
            Dbg("meter source", idx, "amount", amount == nil and "<secret>" or amount,
                "guid", Plain(src.sourceGUID) and "plain" or "<secret>", "name", Plain(src.name) and "plain" or "<secret>")
        end
        if type(amount) == "number" then
            local key = Plain(src.sourceGUID) or Plain(src.name) or ("c" .. tostring(Plain(src.classFilename)) .. idx)
            local last = meterLast[key]
            meterLast[key] = amount
            if last == nil then last = 0 end
            if amount > last or (amount < last and amount > 0) then
                local unit = MemberByMeterSource(src, units)
                if unit and unit ~= "player" then
                    local _, class = UClass(unit)
                    local def = class and CLASS[class]
                    local spell = def and def[1]
                    if debugOn then Dbg("meter: interrupt by", unit, class) end
                    if spell and SPELLS[spell] then Mark(unit, spell, SPELLS[spell]) end
                end
            end
        end
    end
end
I._PollMeter = PollMeter

local castFrames = {}
local function MakeCastFrames()
    if next(castFrames) then return end
    local units = { "player", "pet" }
    for i = 1, 4 do units[#units + 1] = "party" .. i; units[#units + 1] = "partypet" .. i end
    for _, unit in ipairs(units) do
        local f = CreateFrame("Frame")
        local ok = pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", unit)
        if ok then
            f:SetScript("OnEvent", function(_, _, u, _, spellID) OnCast(unit, spellID) end)
            castFrames[unit] = f
        end
    end
end

I._castFrames = castFrames
-- Group members who also run H3z0 UI tell each other when they interrupt, so their
-- cooldown shows even when the game hides the cast. (The game does not allow addon
-- messages during a keystone run, a boss fight or PvP; then the other sources are used.)
local MSG_PREFIX = "H3zINT"
function I.Broadcast(spellID)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local channel
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        channel = "INSTANCE_CHAT"
    elseif IsInGroup and IsInGroup() then
        channel = "PARTY"
    end
    if not channel then return end
    pcall(C_ChatInfo.SendAddonMessage, MSG_PREFIX, tostring(spellID), channel)
end

local function OnAddonMessage(prefix, msg, _, sender)
    if Plain(prefix) ~= MSG_PREFIX then return end
    msg, sender = Plain(msg), Plain(sender)
    if type(msg) ~= "string" or type(sender) ~= "string" then return end
    local spell = tonumber(msg)
    local cd = spell and SPELLS[spell]
    if not cd then return end
    local short = sender:gsub("%-.*$", "")
    for i = 1, 4 do
        local unit = "party" .. i
        if UExists(unit) then
            local n = Plain(UName(unit))
            if n and (n == sender or n == short) then
                if debugOn then Dbg("message from", sender, "spell", spell) end
                Mark(unit, spell, cd)
                return
            end
        end
    end
end

local function MakeMessageFrame()
    if castFrames._message then return end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, MSG_PREFIX) end
    local f = CreateFrame("Frame")
    if pcall(f.RegisterEvent, f, "CHAT_MSG_ADDON") then
        f:SetScript("OnEvent", function(_, _, ...) pcall(OnAddonMessage, ...) end)
        castFrames._message = f
    end
end

local function MakeInterruptFrame()
    if castFrames._interrupted then return end
    local f = CreateFrame("Frame")
    if pcall(f.RegisterEvent, f, "UNIT_SPELLCAST_INTERRUPTED") then
        f:SetScript("OnEvent", function(_, _, ...) pcall(OnInterrupted, ...) end)
        castFrames._interrupted = f
    end
end

---------------------------------------------------------------------------
-- counting per Mythic+ run: the counts start from zero on every keystone start and the
-- finished (or left) run is saved in a history, newest first, to look at by dungeon
---------------------------------------------------------------------------
local run          -- { name, level, startedAt } while a keystone run is on
local MAX_HISTORY = 30

local function Snapshot()
    local members = {}
    for _, unit in ipairs(UnitList()) do
        if UExists(unit) then
            local _, class = UClass(unit)
            members[#members + 1] = { name = Plain(UName(unit)) or "?", class = class, count = counts[unit] or 0 }
        end
    end
    return members
end


local function SaveRun(finished)
    if not run then return end
    local s = Settings()
    local r = run
    run = nil
    if not s then return end
    pcall(I._ReadCounts, UnitUnits())
    local members = Snapshot()
    local total = 0
    for _, m in ipairs(members) do total = total + m.count end
    if total == 0 and not finished then return end
    s.history = s.history or {}
    table.insert(s.history, 1, { dungeon = r.name or "Mythic+", level = r.level or 0, date = date and date("%d.%m %H:%M") or "",
        finished = finished and true or false, members = members })
    while #s.history > MAX_HISTORY do table.remove(s.history) end
end

-- counting starts from zero: what the meter already counted is remembered and taken off
function I.ResetCounts()
    pcall(I._ReadCounts, UnitUnits())
    wipe(counts)
    wipe(base)
    for unit, v in pairs(rawTotals) do base[unit] = v end
    pcall(I.Update)
end

local function StartRun()
    SaveRun(false)    -- a run that was left before it ended
    local name, level
    if C_ChallengeMode then
        local id = C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
        if id and C_ChallengeMode.GetMapUIInfo then name = C_ChallengeMode.GetMapUIInfo(id) end
        if C_ChallengeMode.GetActiveKeystoneInfo then level = C_ChallengeMode.GetActiveKeystoneInfo() end
    end
    run = { name = Plain(name), level = Plain(level) }
    I.ResetCounts()
end

function I.GetHistory()
    local s = Settings()
    return s and s.history or {}
end

function I.ClearHistory()
    local s = Settings()
    if s then s.history = {} end
end

-- the history window: runs newest first, each with the interrupts of every member
local HIST_LINES = 22

local function HistLines()
    local lines = {}
    local h = I.GetHistory()
    if #h == 0 then
        lines[1] = { text = "Nothing yet. Every Mythic+ run is saved here when it ends." }
        return lines
    end
    for _, e in ipairs(h) do
        local lvl = (e.level and e.level > 0) and (" +" .. e.level) or ""
        lines[#lines + 1] = { text = ("|cFFFFD100%s%s|r  |cFF9A9A9A%s%s|r"):format(e.dungeon or "?", lvl, e.date or "", e.finished and "" or "  (left early)") }
        local ms = {}
        for _, m in ipairs(e.members or {}) do ms[#ms + 1] = m end
        table.sort(ms, function(a, b) return (a.count or 0) > (b.count or 0) end)
        for _, m in ipairs(ms) do
            local r, g, b = ClassColor(m.class)
            lines[#lines + 1] = { text = ("   |cFF%02X%02X%02X%s|r   %d"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), m.name or "?", m.count or 0) }
        end
        lines[#lines + 1] = { text = " " }
    end
    return lines
end

local function RefreshHistory()
    local f = histFrame
    if not (f and f:IsShown()) then return end
    local lines = HistLines()
    local maxOff = math.max(0, #lines - HIST_LINES)
    f.offset = math.min(f.offset or 0, maxOff)
    for i = 1, HIST_LINES do
        local l = lines[f.offset + i]
        f.lines[i]:SetText(l and l.text or "")
    end
end

function I.ShowHistory()
    if not histFrame then
        local f = CreateFrame("Frame", "H3z0UI_InterruptHistory", UIParent, "BackdropTemplate")
        f:SetSize(360, 40 + HIST_LINES * 15 + 40)
        f:SetPoint("CENTER", 0, 0)
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        if f.SetBackdrop then
            f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            f:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
            f:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
        end
        local title = f:CreateFontString(nil, "OVERLAY")
        title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        title:SetPoint("TOPLEFT", 12, -12)
        title:SetText("Interrupts by Mythic+ Run")
        f.lines = {}
        for i = 1, HIST_LINES do
            local fs = f:CreateFontString(nil, "OVERLAY")
            fs:SetFont(STANDARD_TEXT_FONT, 12, "")
            fs:SetPoint("TOPLEFT", 12, -34 - (i - 1) * 15)
            fs:SetJustifyH("LEFT")
            f.lines[i] = fs
        end
        f.offset = 0
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel", function(self, d)
            self.offset = math.max(0, (self.offset or 0) - d * 3)
            RefreshHistory()
        end)
        local function Btn(label, x, fn)
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(110, 22)
            b:SetPoint("BOTTOMLEFT", x, 10)
            b:SetText(label)
            b:SetScript("OnClick", fn)
            return b
        end
        Btn("Reset Counts", 10, function() I.ResetCounts(); Say("The counts start from zero.") end)
        Btn("Clear History", 125, function() I.ClearHistory(); f.offset = 0; RefreshHistory() end)
        Btn("Close", 240, function() f:Hide() end)
        if UISpecialFrames then table.insert(UISpecialFrames, "H3z0UI_InterruptHistory") end
        histFrame = f
    end
    histFrame:Show()
    histFrame.offset = 0
    RefreshHistory()
end

---------------------------------------------------------------------------
-- self test: no dungeon needed. Four made-up members run the real code paths with
-- made-up events (hidden casts, an interrupted enemy cast, an addon message, a plain
-- cast) and the result of each is printed. The list shows them while it runs.
---------------------------------------------------------------------------
function I.SelfTest()
    if selfTesting then Say("The test is already running.") return end
    if InCombatLockdown() then Say("Not in combat.") return end
    selfTesting = true
    virtual = {
        party1 = { name = "Test Rogue",  class = "ROGUE",  role = "DAMAGER" },
        party2 = { name = "Test Mage",   class = "MAGE",   role = "DAMAGER" },
        party3 = { name = "Test Priest", class = "PRIEST", role = "HEALER" },
        party4 = { name = "Test Monk",   class = "MONK",   role = "DAMAGER" },
    }
    for i = 1, 4 do used["party" .. i] = nil; castTimes["party" .. i] = nil; counts["party" .. i] = nil end
    local passed, total = 0, 0
    local function Check(label, ok)
        total = total + 1
        if ok then passed = passed + 1 end
        Say((ok and "|cFF40FF40PASS|r " or "|cFFFF4040FAIL|r ") .. label)
    end
    local function On(u) return used[u] and GetTime() < used[u].start + used[u].cd end
    Say("Self test: made-up members Test Rogue, Test Mage, Test Priest (healer), Test Monk are in the list for about 16 seconds.")
    I.Update()
    local function After(sec, fn) C_Timer.After(sec, function() pcall(fn); pcall(I.Update) end) end

    -- A: one member casts something hidden at the moment an enemy cast is interrupted
    After(1, function()
        OnCast("party1", nil)
        OnInterrupted("nameplate1", "cast", "spell", "Hidden-guid", "CastBar-test")
    end)
    After(2, function() Check("hidden cast + interrupt: Test Rogue's cooldown started", On("party1")) end)

    -- B: two members cast at once: unclear, nothing may be guessed
    After(3, function()
        OnCast("party2", nil); OnCast("party4", nil)
        OnInterrupted("nameplate2", "cast", "spell", "Hidden-guid", "CastBar-test")
    end)
    After(4, function() Check("two members cast at once: no guess", not On("party2") and not On("party4")) end)

    -- C: the healer casts at the moment of an interrupt: a Priest healer has no interrupt
    After(5, function()
        OnCast("party3", nil)
        OnInterrupted("nameplate3", "cast", "spell", "Hidden-guid", "CastBar-test")
    end)
    After(6, function() Check("healer with no interrupt: no guess", not On("party3")) end)

    -- D: a message from another H3z0 UI user
    After(7, function() OnAddonMessage(MSG_PREFIX, "2139", "PARTY", "Test Mage") end)
    After(7.2, function() Check("addon message: Test Mage's cooldown started", On("party2")) end)

    -- E: a cast whose spell is readable
    After(8, function() OnCast("party4", 116705) end)
    After(8.2, function() Check("readable cast: Test Monk's cooldown started", On("party4")) end)

    -- F: an enemy cast that just stopped (nobody interrupted): nothing happens
    After(9, function()
        used["party1"] = nil
        OnCast("party1", nil)
        OnInterrupted("nameplate4", "cast", "spell", nil, "CastBar-test")
    end)
    After(10, function() Check("cast stopped by nobody: no guess", not On("party1")) end)

    -- G: the shape of the meter's interrupt list: a new row means that member kicked
    local function Src(class, icon) return { classFilename = class, specIconID = icon, isLocalPlayer = false, totalAmount = 1 } end
    local snapSave = snap
    After(11, function()
        snap = nil
        used["party4"] = nil
        I._Structural({ combatSources = { Src("MAGE", 1) } }, 991)               -- starting point
        I._Structural({ combatSources = { Src("MAGE", 1), Src("MONK", 2) } }, 991) -- a new row: Test Monk
    end)
    After(11.3, function() Check("meter list got a new row: Test Monk's cooldown started", On("party4")) end)

    -- H: a row that moved up past another one
    After(12.5, function()
        used["party4"] = nil
        I._Structural({ combatSources = { Src("MONK", 2), Src("MAGE", 1) } }, 991)
    end)
    After(12.8, function() Check("meter list row moved up: Test Monk's cooldown started", On("party4")) end)

    -- I: two members of one class cannot be told apart: nothing is guessed
    After(13.5, function()
        used["party2"] = nil
        used["party4"] = nil
        snap = nil
        I._Structural({ combatSources = { Src("MAGE", 1) } }, 992)
        I._Structural({ combatSources = { Src("MAGE", 1), Src("MAGE", 1) } }, 992)
    end)
    After(13.8, function() Check("same class twice in the list: no guess", not On("party2") and not On("party4")) end)

    After(16, function()
        snap = snapSave
        virtual = nil
        selfTesting = false
        for i = 1, 4 do used["party" .. i] = nil; castTimes["party" .. i] = nil; counts["party" .. i] = nil end
        Say(("Self test finished: %d of %d passed."):format(passed, total))
    end)
end

_G.H3z0UI_RefreshInterrupts = function() I.Update() end

local ev = CreateFrame("Frame")
I._ev = ev
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("CHALLENGE_MODE_START")
pcall(ev.RegisterEvent, ev, "DAMAGE_METER_COMBAT_SESSION_UPDATED")
pcall(ev.RegisterEvent, ev, "DAMAGE_METER_RESET")
ev:RegisterEvent("CHALLENGE_MODE_COMPLETED")
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        if Enum and Enum.DamageMeterType and a1 == Enum.DamageMeterType.Interrupts then pcall(OnMeterUpdated, a2) end
        return
    elseif event == "DAMAGE_METER_RESET" then
        snap = nil
        wipe(rawAmount)
        return
    elseif event == "PLAYER_LOGIN" then
        Settings()
        MakeCastFrames()
        MakeInterruptFrame()
        MakeMessageFrame()
        local acc, meterAcc = 0, 0
        ev:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + elapsed
            meterAcc = meterAcc + elapsed
            if meterAcc >= 0.5 then
                meterAcc = 0
                local s0 = Settings()
                if s0 and s0.enabled then pcall(PollMeter) end
            end
            if acc >= 0.2 then
                acc = 0
                local s = Settings()
                if s and (s.enabled or icon or list) then pcall(I.Update) end
            end
        end)
    elseif event == "CHALLENGE_MODE_START" then
        pcall(StartRun)
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        pcall(SaveRun, true)
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(used)
        wipe(meterLast)
        snap = nil
    end
    pcall(I.Update)
end)
