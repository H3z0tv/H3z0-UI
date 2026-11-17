-- Wiring: saved settings, form tracking, the update ticker, and a check of each prediction
-- against what a shift really gave (out of combat, where power is readable).
-- Formwise 1.0.0 by kragtenb (MIT License, see LICENSE.txt), bundled into H3z0 UI.
-- Kept in a private namespace (ns.Formwise) so it cannot clash with H3z0 UI's own tables.
local addonName, host = ...
host.Formwise = host.Formwise or {}
local ns = host.Formwise
local Model, Player, Bars = ns.Model, ns.Player, ns.Bars

local Core = {}
ns.Core = Core

Core.DEFAULTS = {
    width = 124, -- the stock player frame's power bar
    height = 10,
    spacing = 2,
    scale = 1,
    x = 0, -- offset from the player frame while attached
    y = -2,
    attached = true,
    locked = true,
    showText = true,
    showCost = true, -- the shift icons (named for the cost mark they replaced)
    -- Each form's shift icon, under showCost; keys from Core.ShiftKey.
    shiftBear = true,
    shiftCat = true,
    shiftTravel = true,
    shiftMoonkin = true,
    showSpark = true, -- the five-second rule's spark on the mana bar
    customColors = false, -- your own bar colours instead of the game's power colours
    color_mana = { 0, 0.55, 1, 1 },
    color_rage = { 0.9, 0.15, 0.15, 1 },
    color_energy = { 1, 0.85, 0.1, 1 },
    enabled = true, -- druids on WoW: Forever only
    matchWidth = true, -- attached bars take the width of the player frame's power bar
}
Core.TICK = 0.1
Core.CHECK_TIMEOUT = 0.5 -- seconds to wait for a shift's power update before reading it anyway
Core.TOLERANCE = 2
Core.ENERGY_TICK = 20 -- Cat Form's regen can land in one lump before a check is read
Core.CAT_REGEN = 10 -- Energy per second in Cat Form, if regen turns out to be continuous
-- What "Reset layout" restores; display choices are left alone. freeX/freeY: where the bars
-- were dragged, used while not attached.
Core.LAYOUT_KEYS = { "matchWidth", "width", "height", "spacing", "scale", "x", "y", "attached", "locked", "freeX", "freeY" }
Core.LOG_SIZE = 20
-- Furor's grant comes with the shift; a later first update is regen and can't teach the rank.
Core.GRANT_WINDOW = 0.2
Core.HINT_DELAY = 5 -- seconds after login before saying Furor wasn't found, so talents have loaded
Core.REGEN_DELAY = 5 -- the five-second rule: Spirit regen resumes this long after Mana is spent

local function print(...)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99H3z0 UI Shapeshift Bars|r " .. string.format(...))
end
Core.Print = print

local function fill(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
    return target
end

-- Settings ---------------------------------------------------------------------------------

function Core:Init()
    local Helpers = host.Helpers
    local db = Helpers and Helpers.GetModuleSettings and Helpers.GetModuleSettings("formwise", Core.DEFAULTS)
    if type(db) ~= "table" then
        db = fill({}, Core.DEFAULTS)
    end
    fill(db, Core.DEFAULTS)
    -- Per-character data (Furor rank, shift log, learned costs) lives in H3z0UIDB, by character.
    local root = _G.H3z0UIDB
    local char
    if type(root) == "table" then
        root.formwiseChars = type(root.formwiseChars) == "table" and root.formwiseChars or {}
        local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
        root.formwiseChars[key] = type(root.formwiseChars[key]) == "table" and root.formwiseChars[key] or {}
        char = root.formwiseChars[key]
    else
        char = {}
    end
    char.log = char.log or {}
    char.manaSpells = char.manaSpells or {}
    char.wolfshead = nil
    self.db, self.char = db, char
end

function Core:Set(key, value)
    if key == "scale" and self.db.freeX then
        -- A dragged position is in the bars' own scaled units; keep it on the same screen spot.
        local ratio = self.db.scale / value
        self.db.freeX, self.db.freeY = self.db.freeX * ratio, self.db.freeY * ratio
    end
    self.db[key] = value
    if key == "attached" and not value and not self.db.freeX then
        self:SavePosition() -- detaching before any drag keeps the bars where they are
        self.db.attached = self.db.freeX == nil -- still attached if the position couldn't be read
    end
    self:Apply()
end

function Core:ResetLayout()
    for _, key in ipairs(Core.LAYOUT_KEYS) do
        self.db[key] = Core.DEFAULTS[key]
    end
    self:Apply()
end

-- Furor --------------------------------------------------------------------------------------

-- Rank in use: the player's override, else the detected talent, else one learned from shifts.
function Core:FurorRank()
    if self.char.furorOverride then
        return self.char.furorOverride
    end
    if self.detectedFuror then
        return self.detectedFuror
    end
    return self.char.learnedFuror or 0
end

-- nil returns to automatic.
function Core:SetFurorOverride(rank)
    self.char.furorOverride = rank
    self:Apply()
end

-- Client state -----------------------------------------------------------------------------

-- A read the client won't answer (nil, in combat) keeps the last answer, and stays nil
-- (unknown) until there is one; combat's end re-reads. The detected Furor rank is saved, so a
-- reload in combat starts from it.
local function keep(value, previous)
    if value == nil then
        return previous
    end
    return value
end

function Core:ReadSpells()
    local detected = Player.DetectFurorRank()
    if detected ~= nil then
        -- The talent tree is the truth; a rank learned while it couldn't be read no longer applies.
        self.char.learnedFuror, self.furorCandidate = nil, nil
        self.talentsRead = true
    end
    self.detectedFuror = keep(detected, self.detectedFuror or self.char.detectedFuror)
    self.char.detectedFuror = self.detectedFuror
    self.knowsCat = keep(Player.KnowsCat(), self.knowsCat)
    self.bearForm = keep(Player.BearForm(), self.bearForm)
    self.knowsTravel = keep(Player.Knows(Player.TRAVEL_FORM), self.knowsTravel)
    self.knowsMoonkin = keep(Player.Knows(Player.MOONKIN_FORM), self.knowsMoonkin)
    self.knowsShiftingPower = keep(Player.Knows(Player.SHIFTING_POWER), self.knowsShiftingPower)
    self:ReadCosts()
end

-- spellID: the form's spell, false if not known, nil if unreadable (keeps the last cost). "Not
-- known" drops the cost (a respec can unlearn Moonkin Form) only once the talents have been read
-- this session, and out of combat: until a talent's node loads, its form reads as not known, and
-- in combat the cost couldn't be read back.
local function readCost(spellID, last, talentsRead)
    if spellID == false and talentsRead and not InCombatLockdown() then
        return nil
    end
    return Player.ManaCost(spellID) or last
end

-- Spell costs may be unreadable in combat; the last plain value is kept, across reloads too.
function Core:ReadCosts()
    local costs, read = self.costs or type(self.char.costs) == "table" and self.char.costs or {}, self.talentsRead
    costs.cat = readCost(self.knowsCat and Player.CAT_FORM, costs.cat, read)
    costs.bear = readCost(self.bearForm, costs.bear, read)
    costs.travel = readCost(self.knowsTravel and Player.TRAVEL_FORM, costs.travel, read)
    costs.moonkin = readCost(self.knowsMoonkin and Player.MOONKIN_FORM, costs.moonkin, read)
    -- A spell, not a form: Cat's icon counts it in Cat Form (ShiftCostAndIcon).
    costs.shiftingPower = readCost(self.knowsShiftingPower and Player.SHIFTING_POWER, costs.shiftingPower, read)
    self.costs, self.char.costs = costs, costs
    -- A shift costs Mana whether or not it has been cast yet (the five-second rule's spells).
    local spells = { cat = Player.CAT_FORM, bear = self.bearForm, travel = Player.TRAVEL_FORM,
        moonkin = Player.MOONKIN_FORM, shiftingPower = Player.SHIFTING_POWER }
    for form, spellID in pairs(spells) do
        if spellID and (costs[form] or 0) > 0 then
            self.char.manaSpells[spellID] = true
        end
    end
end

-- A form whose spell can't be read yet (nil) still gets its bar; only "not known" hides it.
function Core:Shown()
    return {
        mana = self.kind ~= "caster",
        rage = self.kind ~= "bear" and self.bearForm ~= false,
        energy = self.kind ~= "cat" and self.knowsCat ~= false,
    }
end

-- The setting that shows a form's shift icon: "bear" -> "shiftBear".
function Core.ShiftKey(form)
    return "shift" .. form:gsub("^%l", string.upper)
end

-- Shift icons, by form: in every form, for each form turned on whose cost is known (so not
-- before it is learned). Learning one fires SPELLS_CHANGED, which lays the bars out again.
function Core:ShiftIcons()
    local icons = {}
    for _, form in ipairs(Bars.SHIFT_FORMS) do
        icons[form] = (self.costs[form] or 0) > 0 and self.db[Core.ShiftKey(form)] == true
    end
    return icons
end

-- A shift icon's cost and icon (nil: the form's own). In Cat Form, where shifting into Cat means
-- nothing, Cat's icon counts Shifting Power instead, if known.
function Core:ShiftCostAndIcon(form)
    if form == "cat" and self.kind == "cat" and (self.costs.shiftingPower or 0) > 0 then
        return self.costs.shiftingPower, Bars.SHIFTING_POWER_ICON
    end
    return self.costs[form]
end

-- Display ----------------------------------------------------------------------------------

-- H3z0 UI's own player frame (made by H3z0UI_UnitFrames, which may load after this file).
function Core:H3Frame()
    local f = _G.H3z0UI_Player
    return f and f.GetObjectType and f or nil
end

-- The bar caster-form Mana shows on: H3z0 UI's power bar, else Blizzard's.
function Core:StockManaBar()
    local f = self:H3Frame()
    if f and f.powerBar and f.powerBar:IsShown() then
        return f.powerBar
    end
    local content = PlayerFrame and PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local area = main and main.ManaBarArea
    return area and area.ManaBar
end

function Core:PlayerAnchor()
    local f = self:H3Frame()
    if f then
        if f.powerBar and f.powerBar:IsShown() and (f.powerBar:GetAlpha() or 0) > 0 then
            return f.powerBar
        end
        return f
    end
    return self:StockManaBar() or PlayerFrame or UIParent
end

-- Settings as the bars use them: attached bars match the width of what they hang under.
function Core:Effective()
    local db = self.db
    if not (db.attached or not db.freeX) or not db.matchWidth then
        return db
    end
    local anchor = self:PlayerAnchor()
    local w = anchor and anchor.GetWidth and Player.Plain(anchor:GetWidth())
    if not w or w < 20 then
        return db
    end
    local eff = setmetatable({ width = math.floor(w + 0.5) }, { __index = db })
    return eff
end

-- Attached to H3z0 UI's own player frame: the bars become part of that frame. They hang
-- under its health / power bar with the same left and right edges, inside its border and
-- rounded outline (the unit frames' sub-bars). Returns the frame, or nil.
function Core:EmbedFrame()
    local db = self.db
    if not (db and (db.attached or not db.freeX)) then return nil end
    if not (_G.H3z0UI_SetUnitSubBar and _G.H3z0UI_RemoveUnitSubBar) then return nil end
    local f = self:H3Frame()
    if f and f.healthBar then return f end
    return nil
end

local SUB_ORDER = { mana = 11, rage = 12, energy = 13 }

-- your own bar colours (customColors on), else nil for the game's power colour
Bars.ColorOverride = function(key)
    local db = Core.db
    if not (db and db.customColors) then return nil end
    return db["color_" .. key]
end

-- After the player frame placed a bar: keep its pieces stacked, and note its width (the fills
-- are sized from it).
local function onBarLayout(bar)
    Bars.KeepLevels(bar)
    local w = Player.Plain(bar:GetWidth())
    if w and w > 1 then bar.width = w end
end

-- Puts the shown bars into the player frame (in Bars.ORDER) and takes the others out.
function Core:Embed(f, shown)
    local bars, db = self.frame.bars, self.db
    local path = Bars.CurrentTexture()
    self.embedded = true
    local batched = _G.H3z0UI_BeginUnitSubBarBatch and _G.H3z0UI_EndUnitSubBarBatch and true or false
    if batched then _G.H3z0UI_BeginUnitSubBarBatch() end
    for _, key in ipairs(Bars.ORDER) do
        local bar = bars[key]
        local id = "formwise_" .. key
        if shown[key] then
            bar.fwColor = Bars.ColorOf(key)
            pcall(Bars.SkinEmbedded, bar, path)
            bar.text:SetShown(db.showText)
            _G.H3z0UI_SetUnitSubBar("player", id, bar, db.height, { order = SUB_ORDER[key], onLayout = onBarLayout })
            onBarLayout(bar)
        else
            _G.H3z0UI_RemoveUnitSubBar("player", id)
        end
    end
    if batched then
        _G.H3z0UI_EndUnitSubBarBatch()
        -- the frame placed the bars only now: note their widths again
        for _, key in ipairs(Bars.ORDER) do
            if shown[key] then onBarLayout(bars[key]) end
        end
    end
end

-- Takes the bars back out of the player frame into their own container.
function Core:Unembed()
    if not self.embedded then return end
    self.embedded = false
    for _, key in ipairs(Bars.ORDER) do
        if _G.H3z0UI_RemoveUnitSubBar then _G.H3z0UI_RemoveUnitSubBar("player", "formwise_" .. key) end
        Bars.Unembed(self.frame.bars[key], self.frame)
    end
end

-- The bars in the player frame want the frame's main power bar (Rage / Energy / Mana) over
-- them, so the order reads health, main power, then the other forms' bars. Turned on once.
function Core:EnsureMainPowerBar(f)
    if self.db.powerBarOn1 or InCombatLockdown() then return end
    local core = host.Addon
    local p = core and core.db and core.db.profile
    local uf = p and p.h3z0uiUnitFrames
    local ps = uf and uf.player
    if not ps then return end
    self.db.powerBarOn1 = true
    if not ps.showPowerBar then
        ps.showPowerBar = true
        if _G.H3z0UI_RefreshUnitFrames then pcall(_G.H3z0UI_RefreshUnitFrames) end
    end
end

function Core:Place()
    local frame, db = self.frame, self.db
    frame:ClearAllPoints()
    local f = self:EmbedFrame()
    if f then
        -- shift icons under the frame's outline (the frame plus the bars' tray)
        frame:SetPoint("TOPLEFT", f.h3zShape or f, "BOTTOMLEFT", 0, -(db.spacing or 2))
        return
    end
    if db.attached or not db.freeX then
        frame:SetPoint("TOPLEFT", self:PlayerAnchor(), "BOTTOMLEFT", db.x, db.y)
    else
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.freeX, db.freeY)
    end
end

-- Settings changes: everything, including where the bars sit.
function Core:Apply()
    if not self.frame then
        return
    end
    self:Place()
    self:Relayout()
    if self.onApply then
        self.onApply()
    end
end

-- Form changes: which bars show and their stacking, without re-anchoring.
function Core:Relayout()
    local shown = self:Shown()
    local f = self:EmbedFrame()
    if f then
        self:EnsureMainPowerBar(f)
        self:Embed(f, shown)
        local _, hasIcons = Bars.Layout(self.frame, self.db, shown, self:ShiftIcons(), true)
        -- the icons hang under the outline, which just changed height
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", f.h3zShape or f, "BOTTOMLEFT", 0, -(self.db.spacing or 2))
        self.frame:SetShown(hasIcons or not self.db.locked)
        self.frame.mover:SetShown(not self.db.locked)
        self.frame:EnableMouse(not self.db.locked)
        self:Update()
        return
    end
    self:Unembed()
    local count = Bars.Layout(self.frame, self:Effective(), shown, self:ShiftIcons())
    self.frame:SetShown(count > 0 or not self.db.locked)
    self.frame.mover:SetShown(not self.db.locked)
    self.frame:EnableMouse(not self.db.locked)
    self:Update()
end

function Core:Update()
    if not self.frame then
        return
    end
    local bars, rank = self.frame.bars, self:FurorRank()
    -- Read every max each time: they are remembered for combat, where they may be secret.
    local manaMax, rageMax = Player.KnownMaxPower(Player.MANA), Player.MaxPower(Player.RAGE)
    local energyMax = Player.MaxPower(Player.ENERGY)
    local mana = Player.Power(Player.MANA)
    if bars.mana:IsShown() then
        Bars.ShowMana(bars.mana, mana, Player.RawMaxPower(Player.MANA))
    end
    if bars.rage:IsShown() then
        Bars.ShowRage(bars.rage, Model.PredictRage(rank, rageMax), rageMax)
    end
    if bars.energy:IsShown() then
        Bars.ShowEnergy(bars.energy, Model.PredictEnergy(self.energy, rank, GetTime(), energyMax), energyMax)
    end
    for form, holder in pairs(self.frame.shifts) do
        if holder:IsShown() then
            local cost, icon = self:ShiftCostAndIcon(form)
            Bars.ShowShifts(holder, mana, manaMax, cost, icon)
        end
    end
end

-- The Energy Cat Form would be left with, kept current by the ticker and power updates.
function Core:SampleEnergy()
    if Player.FormKind() == "cat" then
        self.lastEnergy = Player.Power(Player.ENERGY)
    end
end

function Core:Tick()
    self:SampleEnergy()
    self:Update()
end

-- Shifts -------------------------------------------------------------------------------------

function Core:OnFormChanged()
    local kind = Player.FormKind()
    if not kind or kind == self.kind then
        return
    end
    local now = GetTime()
    self:ResolveCheck()
    if self.kind then
        self:StartCheck(kind, now)
    end
    Model.Transition(self.energy, self.kind, kind, now, self.lastEnergy)
    self.kind = kind
    self:SampleEnergy()
    -- The numbers above are taken right away. Moving the bars around waits two or three frames,
    -- so it does not land in the same frame as the action bar change (the shapeshift stutter).
    if C_Timer and C_Timer.After then
        if not self.relayoutQueued then
            self.relayoutQueued = true
            C_Timer.After(0.07, function()
                self.relayoutQueued = nil
                self:Relayout()
                self:UpdateSpark()
            end)
        end
    else
        self:Relayout()
        self:UpdateSpark() -- the bar it was on may have just hidden, which stops its OnUpdate
    end
end

-- Records what Cat or Bear Form should start with; ResolveCheck compares it with what arrived.
function Core:StartCheck(kind, now)
    if InCombatLockdown() then
        return
    end
    local rank = self:FurorRank()
    if kind == "cat" and self.knowsCat then
        local max = Player.MaxPower(Player.ENERGY)
        local prediction = Model.PredictEnergy(self.energy, rank, now, max)
        -- A secret stored Energy can't teach Furor's rank or be compared, so it isn't checked.
        if prediction.value and not Player.IsSecret(self.energy.base) then
            local before = { base = self.energy.base, accrued = Model.SecondsOutside(self.energy, now) }
            self.check = { kind = kind, power = Player.ENERGY, token = "ENERGY", expected = { prediction.value },
                rank = rank, before = before, max = max, at = now }
        end
    elseif kind == "bear" then
        local rage = Model.PredictRage(rank, Player.MaxPower(Player.RAGE))
        self.check = { kind = kind, power = Player.RAGE, token = "RAGE", expected = { rage.guaranteed, rage.possible },
            rank = rank, at = now }
    end
    if self.check then
        local check = self.check
        C_Timer.After(Core.CHECK_TIMEOUT, function()
            if self.check == check then
                self:ResolveCheck()
            end
        end)
    end
end

-- slack: power the form may have gained on its own since the shift.
local function matches(expected, observed, slack)
    for _, value in ipairs(expected) do
        if observed >= value - Core.TOLERANCE and observed <= value + Core.TOLERANCE + slack then
            return true
        end
    end
    return false
end

-- A power update settles the check only on a non-zero match: the shift's first update may be
-- a 0 that comes before Furor's. Otherwise the timeout settles it with whatever arrived.
function Core:OnPowerUpdate(token)
    if token == "ENERGY" then
        self:SampleEnergy()
    end
    local check = self.check
    if not check or token ~= check.token then
        return
    end
    local observed = Player.Plain(Player.Power(check.power))
    if not observed or observed <= 0 then
        return
    end
    if not check.first and GetTime() - check.at <= Core.GRANT_WINDOW then
        check.first = observed
    end
    -- Only the largest outcome settles early: a smaller reading may be a step on the way to it.
    if matches({ check.expected[#check.expected] }, observed, 0) then
        self:ResolveCheck()
    end
end

function Core:ResolveCheck()
    local check = self.check
    self.check = nil
    if not check or Player.FormKind() ~= check.kind then
        return
    end
    local observed = Player.Plain(Player.Power(check.power))
    if not observed then
        return
    end
    local slack = check.kind == "cat" and Core.ENERGY_TICK or 0
    local ok = matches(check.expected, observed, slack)
    -- Whether this check's expectation came from a known rank, before this entry teaches one.
    local learning = self:LearningFuror()
    local entry = { form = check.kind, expected = check.expected, observed = observed, rank = check.rank,
        ok = ok, learning = learning, at = GetServerTime() }
    if check.kind == "cat" then
        self:LearnFuror(check, observed)
    end
    local log = self.char.log
    table.insert(log, entry)
    while #log > Core.LOG_SIZE do
        table.remove(log, 1)
    end
    if not ok and not self.warned and not learning then
        self.warned = true
        print("%s Form started with %d, expected %s. Details: /fw log", check.kind == "cat" and "Cat" or "Bear",
            observed, Core.Expected(check.expected))
    end
end

-- "10", or "0 or 10" when Furor's Rage is a chance.
function Core.Expected(expected)
    if expected[2] and expected[2] ~= expected[1] then
        return string.format("%d or %d", expected[1], expected[2])
    end
    return string.format("%d", expected[1])
end

-- True while no Furor rank is known: none set or learned, and the talent tree can't be read.
function Core:LearningFuror()
    return not self.char.furorOverride and self.detectedFuror == nil and self.char.learnedFuror == nil
end

-- What Furor granted: the first update right after the shift; with none, 0 if no more than half a
-- second of regen arrived by the timeout. Anything else is unclear (nil): later readings carry
-- regen, so they never teach the rank.
local function granted(check, observed)
    if check.first then
        return check.first
    end
    if observed <= Core.CAT_REGEN * Core.CHECK_TIMEOUT + Core.TOLERANCE then
        return 0
    end
    return nil
end

-- While the talent tree can't be read, Cat Form entries that only one rank explains teach it. A lone
-- 20 could be a regen tick on no Furor as much as rank 1, so it is skipped. Two usable entries in
-- a row must agree, so one odd reading can't set a wrong rank.
function Core:LearnFuror(check, observed)
    if self.char.furorOverride or self.detectedFuror ~= nil then
        return
    end
    local grant = granted(check, observed)
    local state = { base = check.before.base, accrued = check.before.accrued }
    local candidate = self.furorCandidate
    self.furorCandidate = nil
    if not grant or math.abs(grant - Core.ENERGY_TICK) <= Core.TOLERANCE then
        return
    end
    local ranks = Model.RanksMatchingEnergy(state, 0, check.max, grant, Core.TOLERANCE)
    local rank = #ranks == 1 and ranks[1] or nil
    self.furorCandidate = rank
    if rank and rank == candidate and rank ~= self.char.learnedFuror then
        self.char.learnedFuror = rank
        print("Furor rank %d worked out from your shifts into Cat Form.", rank)
        if self.onApply then
            self.onApply()
        end
    end
end

-- Five-second rule ---------------------------------------------------------------------------

-- Records a cost read as plain. Once a spell has cost Mana it stays known as costing Mana, so
-- one free cast (Clearcasting) doesn't unlearn it.
function Core:LearnManaCost(spellID, spent)
    local known = self.char.manaSpells
    known[spellID] = known[spellID] or spent
end

-- Costs can be secret in combat, so each spell's last readable answer is kept. A spell never
-- read counts as free, and its cost is read when combat ends (ReadUnreadCosts).
function Core:OnSpellCast(spellID)
    spellID = Player.Plain(spellID)
    if not spellID then
        return
    end
    local spent = Player.CostsMana(spellID)
    if spent ~= nil then
        self:LearnManaCost(spellID, spent)
    else
        spent = self.char.manaSpells[spellID]
        if spent == nil then
            self.unread = self.unread or {}
            self.unread[spellID] = true
        end
    end
    if spent then
        self.manaSpentAt = GetTime()
        self:UpdateSpark()
    end
end

function Core:ReadUnreadCosts()
    for spellID in pairs(self.unread or {}) do
        local spent = Player.CostsMana(spellID)
        if spent ~= nil then
            self:LearnManaCost(spellID, spent)
            self.unread[spellID] = nil
        end
    end
end

-- Runs every frame while the spark shows; a hidden spark gets no OnUpdate, so a Mana spend calls
-- it to start. Caster forms show Blizzard's mana bar (none if it's missing), Cat and Bear
-- Formwise's.
function Core:UpdateSpark()
    local elapsed = self.manaSpentAt and GetTime() - self.manaSpentAt
    local bar
    if self.db.showSpark and elapsed and elapsed < Core.REGEN_DELAY then
        if self.kind == "caster" then
            bar = self:StockManaBar()
        else
            bar = self.frame.bars.mana
        end
    end
    Bars.ShowSpark(self.spark, bar, elapsed, Core.REGEN_DELAY)
end

-- Events -------------------------------------------------------------------------------------

function Core:Start()
    self.frame = Bars.Create("FormwiseFrame")
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        self:SaveDraggedPosition()
    end)
    self.spark = Bars.CreateSpark()
    self.spark:SetScript("OnUpdate", function() self:UpdateSpark() end)
    self:ReadSpells()
    C_Timer.After(Core.HINT_DELAY, function() self:HintFuror() end)
    local away = self.char.savedAt and (GetServerTime() - self.char.savedAt) or 0
    self.energy = Model.Restore(self.char.energy, GetTime(), away)
    self.kind, self.lastEnergy, self.startedAt = nil, 0, GetTime()
    self:OnFormChanged()
    self:Apply()
    C_Timer.NewTicker(Core.TICK, function() self:Tick() end)
end

-- Says once per character that Furor's rank couldn't be read, once the talents have had time to
-- load.
function Core:HintFuror()
    if self:LearningFuror() and not InCombatLockdown() and not self.char.furorHinted
        and GetTime() - self.startedAt >= Core.HINT_DELAY then
        self.char.furorHinted = true
        print("Couldn't read Furor's rank from your talents. It will be worked out from your next shifts "
            .. "into Cat Form; or set it with /fw furor 0-5.")
    end
end

-- Dragging detaches the bars from the player frame and keeps them where they were dropped.
function Core:SaveDraggedPosition()
    self:SavePosition()
    self:Apply()
end

-- Detaches the bars where they are now. A position the client won't reveal (anchored to a
-- secret frame) is not saved.
function Core:SavePosition()
    local frame = self.frame
    local left, top = Player.Plain(frame:GetLeft()), Player.Plain(frame:GetTop())
    local parentTop = Player.Plain(UIParent:GetTop())
    if left and top and parentTop then
        local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        self.db.attached = false
        self.db.freeX, self.db.freeY = left, top - parentTop * ratio
    else
        print("Couldn't read where the bars are; try again out of combat.")
    end
end

-- In Cat Form the stored Energy is stale; save what Cat Form would be left with instead.
function Core:OnLogout()
    local snapshot = Model.Snapshot(self.energy, GetTime())
    if self.kind == "cat" then
        snapshot.base, snapshot.seconds = Player.Plain(self.lastEnergy) or 0, 0
    end
    self.char.energy = snapshot
    self.char.savedAt = GetServerTime()
end

local events = CreateFrame("Frame")
Core.events = events

local started = false
local handlers = {}

local function onSpellsChanged()
    Core:ReadSpells()
    Core:Apply()
end

-- Called by H3z0 UI once the player is in the world. Does nothing unless this is a Forever druid
-- with the setting on and the standalone Formwise addon absent.
function Core.Boot()
    if started then return end
    if not (host.Client and host.Client.isForever) then return end
    if not Player.IsDruid() then return end
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Formwise") then return end
    Core:Init()
    if Core.db.enabled == false then return end
    started = true
    Core:Start()
    for _, event in ipairs({ "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE",
        "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED",
        "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_LOGOUT" }) do
        pcall(events.RegisterEvent, events, event)
    end
    pcall(events.RegisterUnitEvent, events, "UNIT_DISPLAYPOWER", "player")
    pcall(events.RegisterUnitEvent, events, "UNIT_POWER_UPDATE", "player")
    pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    -- The unit frames can finish after us: re-attach a moment later, and again when the world loads.
    C_Timer.After(1, function() Core:Apply() end)
    C_Timer.After(4, function() Core:Apply() end)
end

-- Turned on or off from the options page. Turning off hides the bars; turning on after a
-- reload-free start needs Boot to have run, so it is started here if it was off at login.
function Core.SetEnabled(on)
    if not Core.db then Core.db = (host.Helpers and host.Helpers.GetModuleSettings("formwise", Core.DEFAULTS)) or Core.db end
    if Core.db then Core.db.enabled = on and true or false end
    if on and not started then
        Core.Boot()
    elseif Core.frame then
        Core.frame:SetShown(on and true or false)
        if on then
            Core:Relayout()
        else
            Core:Unembed()
            for _, bar in pairs(Core.frame.bars) do bar:Hide() end
        end
    end
end

handlers.UPDATE_SHAPESHIFT_FORM = function() Core:OnFormChanged() end
handlers.UNIT_DISPLAYPOWER = function() Core:OnFormChanged() end
handlers.UNIT_POWER_UPDATE = function(_, token) Core:OnPowerUpdate(token) end
handlers.UNIT_SPELLCAST_SUCCEEDED = function(_, _, spellID) Core:OnSpellCast(spellID) end
handlers.PLAYER_LOGOUT = function() Core:OnLogout() end
handlers.SPELLS_CHANGED = onSpellsChanged
handlers.PLAYER_TALENT_UPDATE = onSpellsChanged
handlers.CHARACTER_POINTS_CHANGED = onSpellsChanged
handlers.TRAIT_CONFIG_UPDATED = onSpellsChanged
handlers.TRAIT_CONFIG_LIST_UPDATED = onSpellsChanged
handlers.ACTIVE_COMBAT_CONFIG_CHANGED = onSpellsChanged
handlers.PLAYER_REGEN_ENABLED = function()
    onSpellsChanged()
    Core:ReadUnreadCosts()
    Core:HintFuror()
end

events:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
handlers.PLAYER_LOGIN = function() C_Timer.After(0.5, Core.Boot) end
handlers.PLAYER_ENTERING_WORLD = function() if started then Core:Apply() end end

-- For the options page (another addon, so reached through a global).
_G.H3z0UI_Formwise = Core
function Core.OptionsDB()
    if Core.db then return Core.db end
    local H = host.Helpers
    return H and H.GetModuleSettings and H.GetModuleSettings("formwise", Core.DEFAULTS) or nil
end

return Core
