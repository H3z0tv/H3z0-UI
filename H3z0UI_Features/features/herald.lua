---------------------------------------------------------------------------
-- H3z0 UI - Herald
-- Cinematic banners in the middle of the screen for the moments that matter:
-- zone and subzone changes (with "Discovered" on a first visit), level ups,
-- achievements, boss emotes, quests (accepted, progress, turned in), world
-- quests and scenario / delve stages.
--
-- * one banner at a time, up to 5 more wait in a queue (most important first)
-- * moving between subzones of the zone on screen only changes the subtitle
-- * quiet during a Mythic+ key (zones, quests and scenarios) if you want
-- * Blizzard's zone text and boss emote line step aside while Herald shows them
--
-- Midnight: boss emote texts can be "secret" values. They are only ever passed
-- to SetText, never compared or formatted as a pattern.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local issecretvalue = issecretvalue or function() return false end
local function Secret(v) return v ~= nil and issecretvalue(v) end

local Herald = {}
ns.H3z0Herald = Herald

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = true,
    zone = true, subzone = true, discovery = true,
    levelUp = true, achievement = true, bossEmote = true,
    questAccept = true, questProgress = true, questComplete = true,
    worldQuest = true, scenario = true,
    replaceZoneText = true, replaceBossEmote = true, quietInKeys = true,
    offsetY = -150, scale = 1, titleSize = 30, subtitleSize = 15,
    holdTime = 3, animSpeed = 1,
}

local function DB()
    return Helpers and Helpers.GetModuleDB and Helpers.GetModuleDB("herald")
end

local function Get(key)
    local db = DB()
    local v = db and db[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

local function On() return Get("enabled") ~= false end

---------------------------------------------------------------------------
-- Banner kinds: setting key, small label above the title, colour, priority
---------------------------------------------------------------------------
local KINDS = {
    zone          = { key = "zone",          label = "ENTERING",          color = { 1.00, 0.82, 0.35 }, prio = 3, quiet = true },
    subzone       = { key = "subzone",       label = "ENTERING",          color = { 0.55, 0.88, 0.92 }, prio = 1, quiet = true },
    levelUp       = { key = "levelUp",       label = "LEVEL UP",          color = { 0.40, 1.00, 0.50 }, prio = 5 },
    bossEmote     = { key = "bossEmote",     label = "WARNING",           color = { 1.00, 0.28, 0.28 }, prio = 5 },
    achievement   = { key = "achievement",   label = "ACHIEVEMENT",       color = { 0.92, 0.70, 0.42 }, prio = 4 },
    questAccept   = { key = "questAccept",   label = "QUEST ACCEPTED",    color = { 1.00, 0.86, 0.45 }, prio = 2, quiet = true },
    questProgress = { key = "questProgress", label = "QUEST PROGRESS",    color = { 0.85, 0.85, 0.85 }, prio = 2, quiet = true },
    questComplete = { key = "questComplete", label = "QUEST COMPLETE",    color = { 0.40, 1.00, 0.50 }, prio = 3, quiet = true },
    worldQuest    = { key = "worldQuest",    label = "WORLD QUEST",       color = { 0.72, 0.52, 1.00 }, prio = 3, quiet = true },
    scenario      = { key = "scenario",      label = "SCENARIO",          color = { 0.45, 0.72, 1.00 }, prio = 3, quiet = true },
}

local DISCOVER_COLOR = { 0.55, 1.00, 0.60 }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function InKey()
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
        local ok, active = pcall(C_ChallengeMode.IsChallengeModeActive)
        if ok and active then return true end
    end
    local _, instanceType, difficulty = GetInstanceInfo()
    return instanceType == "party" and difficulty == 8
end

local function Font()
    return (Helpers and Helpers.GetGeneralFont and Helpers.GetGeneralFont()) or STANDARD_TEXT_FONT
end

local function SetFont(fs, size, flags)
    if not fs:SetFont(Font(), size, flags or "OUTLINE") then
        fs:SetFont(STANDARD_TEXT_FONT, size, flags or "OUTLINE")
    end
end

local function Accent()
    if Helpers and Helpers.GetSkinColors then
        local r, g, b = Helpers.GetSkinColors()
        if r then return r, g, b end
    end
    return 0.2, 0.83, 0.6
end

---------------------------------------------------------------------------
-- The banner
---------------------------------------------------------------------------
local banner
local holder               -- what H3z0 UI Edit Mode moves; the banner sits on it
local LAYOUT_KEY = "h3zHerald"

local function SavedPlace()
    local core = Helpers and Helpers.GetCore and Helpers.GetCore()
    local fa = core and core.db and core.db.profile and core.db.profile.frameAnchoring
    return type(fa) == "table" and fa[LAYOUT_KEY] ~= nil
end

local function Holder()
    if holder then return holder end
    holder = CreateFrame("Frame", "H3z0UI_HeraldHolder", UIParent)
    holder:SetSize(760, 110)
    holder:SetPoint("TOP", UIParent, "TOP", 0, -150)
    return holder
end

-- Herald's own Vertical Position until it is moved in H3z0 UI Edit Mode
local function PlaceHolder()
    local h = Holder()
    if not SavedPlace() then
        h:ClearAllPoints()
        h:SetPoint("TOP", UIParent, "TOP", 0, tonumber(Get("offsetY")) or -150)
    elseif _G.H3z0UI_ApplyFrameAnchor and not InCombatLockdown() then
        pcall(_G.H3z0UI_ApplyFrameAnchor, LAYOUT_KEY)
    end
end

local function Build()
    if banner then return banner end
    local f = CreateFrame("Frame", "H3z0UI_Herald", Holder())
    f:SetSize(760, 120)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(20)
    f:EnableMouse(false)
    f:Hide()

    f.label = f:CreateFontString(nil, "OVERLAY")
    f.label:SetPoint("TOP", f, "TOP", 0, -14)

    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetPoint("TOP", f.label, "BOTTOM", 0, -6)
    f.title:SetWidth(740)
    f.title:SetWordWrap(true)
    if f.title.SetMaxLines then f.title:SetMaxLines(2) end
    f.title:SetShadowOffset(2, -2)
    f.title:SetShadowColor(0, 0, 0, 0.85)

    -- thin white line that opens from the middle
    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
    f.line:SetSize(1, 1)
    f.line:SetColorTexture(1, 1, 1, 0.75)

    f.subtitle = f:CreateFontString(nil, "OVERLAY")
    f.subtitle:SetPoint("TOP", f.line, "BOTTOM", 0, -7)
    f.subtitle:SetWidth(700)
    f.subtitle:SetWordWrap(true)
    f.subtitle:SetMaxLines(2)

    f.extra = f:CreateFontString(nil, "OVERLAY")
    f.extra:SetPoint("TOP", f.subtitle, "BOTTOM", 0, -4)

    banner = f
    return f
end

local function ApplyLook()
    local f = Build()
    f:SetScale(math.max(0.5, math.min(2, tonumber(Get("scale")) or 1)))
    f:ClearAllPoints()
    f:SetPoint("TOP", Holder(), "TOP", 0, 0)
    local ts = tonumber(Get("titleSize")) or 30
    local ss = tonumber(Get("subtitleSize")) or 15
    SetFont(f.label, math.max(9, math.floor(ss * 0.75)), "OUTLINE")
    SetFont(f.title, ts, "OUTLINE")
    SetFont(f.subtitle, ss, "OUTLINE")
    SetFont(f.extra, math.max(9, math.floor(ss * 0.85)), "OUTLINE")
end

---------------------------------------------------------------------------
-- Playback: fade in (line opens, title rises) -> hold -> fade out
---------------------------------------------------------------------------
local current            -- the banner on screen
local queue = {}
local MAX_QUEUE = 5
local LINE_WIDTH = 400

local function Phase(dur) return dur / math.max(0.25, tonumber(Get("animSpeed")) or 1) end

local PlayNext -- below

local function Paint(item)
    local f = Build()
    local kind = KINDS[item.kind]
    local c = item.color or kind.color
    local ar, ag, ab = Accent()
    -- white look: white title and line, the small label carries the colour of the kind
    f.label:SetText(item.label or kind.label)
    f.label:SetTextColor(c[1], c[2], c[3], 1)
    f.title:SetText(item.title or "")
    f.title:SetTextColor(0.96, 0.96, 0.96, 1)
    f.subtitle:SetText(item.subtitle or "")
    f.subtitle:SetTextColor(0.82, 0.82, 0.82, 1)
    f.subtitle:SetShown(item.subtitle ~= nil and (Secret(item.subtitle) or item.subtitle ~= ""))
    if item.extra then
        f.extra:SetText(item.extra)
        f.extra:SetTextColor(DISCOVER_COLOR[1], DISCOVER_COLOR[2], DISCOVER_COLOR[3], 1)
        f.extra:Show()
    else
        f.extra:Hide()
    end
    f.line:SetColorTexture(1, 1, 1, 0.75)
end

local preview = false

local function OnUpdate(f, elapsed)
    if preview then return end
    local item = current
    if not item then f:Hide(); return end
    item.t = item.t + elapsed
    local fadeIn, fadeOut = Phase(0.45), Phase(0.7)
    local hold = (tonumber(Get("holdTime")) or 3) + (item.holdBonus or 0)
    local t = item.t
    local alpha, rise, open
    if t < fadeIn then
        local p = t / fadeIn
        local e = 1 - (1 - p) * (1 - p)          -- ease out
        alpha, rise, open = p, (1 - e) * 10, e
    elseif t < fadeIn + hold then
        alpha, rise, open = 1, 0, 1
    elseif t < fadeIn + hold + fadeOut then
        local p = (t - fadeIn - hold) / fadeOut
        alpha, rise, open = 1 - p, 0, 1
    else
        current = nil
        f:SetAlpha(0)
        PlayNext()
        return
    end
    f:SetAlpha(alpha)
    f.label:ClearAllPoints()
    f.label:SetPoint("TOP", f, "TOP", 0, -14 - rise)
    f.line:SetWidth(math.max(1, LINE_WIDTH * open))
end

-- Blizzard's own banners in the middle of the screen (zone / world quest area
-- toasts, boss banner): Herald waits until they are gone instead of overlapping
local BLIZZ_BANNERS = { "EventToastManagerFrame", "BossBanner", "LevelUpDisplay" }
local function BlizzardBannerUp()
    for _, name in ipairs(BLIZZ_BANNERS) do
        local f = _G[name]
        if f and f.IsVisible and f:IsVisible() and (f:GetAlpha() or 0) > 0.05 then return true end
    end
    return false
end

local forcePlay = false
local waiting = CreateFrame("Frame")
waiting:Hide()
waiting:SetScript("OnShow", function(self) self.waited = 0 end)
waiting:SetScript("OnUpdate", function(self, elapsed)
    self.t = (self.t or 0) + elapsed
    self.waited = (self.waited or 0) + elapsed
    if self.t < 0.25 then return end
    self.t = 0
    -- never wait longer than 8 seconds (a Blizzard frame that stays up)
    if not BlizzardBannerUp() or self.waited > 8 then
        self:Hide()
        if not current then
            forcePlay = self.waited > 8
            PlayNext()
            forcePlay = false
        end
    end
end)

local function Play(item)
    local f = Build()
    ApplyLook()
    current = item
    item.t = 0
    Paint(item)
    f:SetAlpha(0)
    f:SetScript("OnUpdate", OnUpdate)
    f:Show()
end

PlayNext = function()
    if #queue == 0 then
        if banner then banner:Hide(); banner:SetScript("OnUpdate", nil) end
        return
    end
    if BlizzardBannerUp() and not forcePlay then
        if banner then banner:Hide(); banner:SetScript("OnUpdate", nil) end
        waiting:Show()
        return
    end
    -- most important first, oldest first among equals
    local best = 1
    for i = 2, #queue do
        if KINDS[queue[i].kind].prio > KINDS[queue[best].kind].prio then best = i end
    end
    Play(table.remove(queue, best))
end

local function SameText(a, b)
    if Secret(a) or Secret(b) then return false end
    return a == b
end

local function IsDuplicate(item)
    if current and current.kind == item.kind and SameText(current.title, item.title) then return true end
    for _, q in ipairs(queue) do
        if q.kind == item.kind and SameText(q.title, item.title) then return true end
    end
    return false
end

-- kind, title, subtitle, opts { label, extra, color, holdBonus, force }
function Herald.Show(kind, title, subtitle, opts)
    local def = KINDS[kind]
    if not def or preview then return end
    opts = opts or {}
    if not opts.force then
        if not On() or Get(def.key) == false then return end
        if def.quiet and Get("quietInKeys") ~= false and InKey() then return end
    end
    if title == nil then return end
    local item = { kind = kind, title = title, subtitle = subtitle, label = opts.label,
        extra = opts.extra, color = opts.color, holdBonus = opts.holdBonus }
    if IsDuplicate(item) then return end
    if not current then
        if BlizzardBannerUp() then
            queue[#queue + 1] = item
            waiting:Show()
            return
        end
        Play(item)
        return
    end
    if #queue >= MAX_QUEUE then
        -- drop the least important waiting banner if the new one beats it
        local worst = 1
        for i = 2, #queue do
            if KINDS[queue[i].kind].prio < KINDS[queue[worst].kind].prio then worst = i end
        end
        if KINDS[queue[worst].kind].prio >= def.prio then return end
        table.remove(queue, worst)
    end
    queue[#queue + 1] = item
end

---------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------
local lastZone, lastSub

local function ZoneBannerOnScreen(zone)
    return current and (current.kind == "zone" or current.kind == "subzone") and SameText(current.title, zone)
end

local function OnZone(initial)
    local zone = GetZoneText() or ""
    local sub = GetSubZoneText() or ""
    if zone == "" then return end
    if zone ~= lastZone or initial then
        lastZone, lastSub = zone, sub
        Herald.Show("zone", zone, (sub ~= "" and sub ~= zone) and sub or nil)
    end
end

local function OnSubZone()
    local zone = GetZoneText() or ""
    local sub = GetSubZoneText() or ""
    if zone == "" then return end
    if zone ~= lastZone then OnZone(); return end
    if sub == "" or sub == lastSub or sub == zone then lastSub = sub; return end
    lastSub = sub
    -- the zone banner is up: only its subtitle changes
    if ZoneBannerOnScreen(zone) and banner then
        current.subtitle = sub
        banner.subtitle:SetText(sub)
        banner.subtitle:Show()
        return
    end
    Herald.Show("subzone", zone, sub)
end

-- "Discovered: %s" / "Discovered %s: %d experience gained"
local function DiscoveryPatterns()
    local list = {}
    for _, g in ipairs({ _G.ERR_ZONE_EXPLORED, _G.ERR_ZONE_EXPLORED_XP }) do
        if type(g) == "string" then
            local p = g:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
            p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "%%d+")
            list[#list + 1] = "^" .. p .. "$"
        end
    end
    return list
end
local discoveryPatterns

local function OnInfoMessage(msg)
    if not On() or Get("discovery") == false then return end
    if type(msg) ~= "string" or Secret(msg) then return end
    discoveryPatterns = discoveryPatterns or DiscoveryPatterns()
    for _, p in ipairs(discoveryPatterns) do
        local place = msg:match(p)
        if place then
            if current and (current.kind == "zone" or current.kind == "subzone") and banner then
                current.extra = "Discovered"
                current.holdBonus = (current.holdBonus or 0) + 1
                banner.extra:SetText("Discovered")
                banner.extra:SetTextColor(DISCOVER_COLOR[1], DISCOVER_COLOR[2], DISCOVER_COLOR[3], 1)
                banner.extra:Show()
            else
                Herald.Show("subzone", place, nil, { extra = "Discovered", label = "DISCOVERED" })
            end
            return
        end
    end
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
local questTitles = {}       -- questID -> title (titles are gone once a quest is turned in)
local questState = {}        -- questID -> { [objective index] = numFulfilled, complete = bool }
local questScanPending = false
local questScanReady = false

local function IsWorldQuest(questID)
    return C_QuestLog and C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) or false
end

local function QuestTitle(questID)
    local t = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    if t and t ~= "" then questTitles[questID] = t end
    return questTitles[questID]
end

local function ScanQuests()
    questScanPending = false
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives) then return end
    local announce = questScanReady and On() and Get("questProgress") ~= false
    local seen = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
            local id = info.questID
            seen[id] = true
            if info.title and info.title ~= "" then questTitles[id] = info.title end
            local objectives = C_QuestLog.GetQuestObjectives(id) or {}
            local prev = questState[id]
            local now = {}
            for k, obj in ipairs(objectives) do
                now[k] = obj.numFulfilled or 0
                if announce and prev and prev[k] and now[k] > prev[k] and obj.text and obj.text ~= "" then
                    Herald.Show("questProgress", questTitles[id] or "", obj.text)
                end
            end
            local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) or false
            if announce and prev and complete and not prev.complete and #objectives > 0 then
                Herald.Show("questProgress", questTitles[id] or "", "Ready to turn in",
                    { color = KINDS.questComplete.color })
            end
            now.complete = complete
            questState[id] = now
        end
    end
    for id in pairs(questState) do
        if not seen[id] then questState[id] = nil end
    end
    questScanReady = true
end

local function QueueQuestScan()
    if questScanPending then return end
    questScanPending = true
    C_Timer.After(0.3, ScanQuests)
end

local function OnQuestAccepted(questID)
    if type(questID) ~= "number" then return end
    C_Timer.After(0.2, function()
        local title = QuestTitle(questID)
        if not title then return end
        if IsWorldQuest(questID) then
            Herald.Show("worldQuest", title, nil, { label = "WORLD QUEST ACCEPTED" })
        else
            Herald.Show("questAccept", title)
        end
    end)
end

local function OnQuestTurnedIn(questID)
    if type(questID) ~= "number" then return end
    local title = QuestTitle(questID)
    questState[questID] = nil
    if not title then return end
    if IsWorldQuest(questID) then
        Herald.Show("worldQuest", title, nil, { label = "WORLD QUEST COMPLETE", color = KINDS.questComplete.color })
    else
        Herald.Show("questComplete", title)
    end
end

---------------------------------------------------------------------------
-- Scenarios and delves
---------------------------------------------------------------------------
local lastScenario, lastStage

local function OnScenario()
    if not (C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo) then return end
    local info = C_ScenarioInfo.GetScenarioInfo()
    if not info or not info.name or info.name == "" then
        lastScenario, lastStage = nil, nil
        return
    end
    local step = C_ScenarioInfo.GetScenarioStepInfo and C_ScenarioInfo.GetScenarioStepInfo()
    local stepTitle = step and step.title ~= "" and step.title or nil
    local stage = info.currentStage
    if info.name ~= lastScenario then
        lastScenario, lastStage = info.name, stage
        Herald.Show("scenario", info.name, stepTitle)
    elseif stage and stage ~= lastStage then
        lastStage = stage
        local of = (info.numStages and info.numStages > 1) and ("Stage " .. stage .. " / " .. info.numStages) or nil
        Herald.Show("scenario", stepTitle or info.name, of, { label = "NEXT STAGE" })
    end
end

---------------------------------------------------------------------------
-- Blizzard's own versions step aside while Herald shows them
---------------------------------------------------------------------------
local hooked = false

local function ZoneTextReplaced(frame)
    if not On() or Get("replaceZoneText") == false then return false end
    if frame == _G.SubZoneTextFrame then return Get("subzone") ~= false end
    return Get("zone") ~= false
end

local function StepBack()
    if not current or preview then return end
    local item = current
    current = nil
    item.t = 0
    table.insert(queue, 1, item)
    if banner then banner:Hide(); banner:SetScript("OnUpdate", nil) end
    waiting:Show()
end

local function ApplyBlizzard()
    if not hooked then
        hooked = true
        for _, name in ipairs(BLIZZ_BANNERS) do
            local frame = _G[name]
            if frame and frame.HookScript then
                frame:HookScript("OnShow", function() C_Timer.After(0, function()
                    if BlizzardBannerUp() then StepBack() end
                end) end)
            end
        end
        for _, name in ipairs({ "ZoneTextFrame", "SubZoneTextFrame" }) do
            local frame = _G[name]
            if frame and frame.HookScript then
                frame:HookScript("OnShow", function(self)
                    if ZoneTextReplaced(self) then self:SetAlpha(0); self:Hide() end
                end)
                -- Blizzard fades it in with SetAlpha while it stays shown: keep it at 0
                local busy = false
                hooksecurefunc(frame, "SetAlpha", function(self, a)
                    if busy or not a or a == 0 or not ZoneTextReplaced(self) then return end
                    busy = true
                    self:SetAlpha(0)
                    busy = false
                end)
            end
        end
    end
    local emote = _G.RaidBossEmoteFrame
    if emote and emote.SetAlpha then
        local hide = On() and Get("bossEmote") ~= false and Get("replaceBossEmote") ~= false
        emote:SetAlpha(hide and 0 or 1)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "UI_INFO_MESSAGE", "PLAYER_LEVEL_UP", "ACHIEVEMENT_EARNED", "RAID_BOSS_EMOTE",
    "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
    "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE",
}) do
    pcall(ev.RegisterEvent, ev, e)
end

ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_ENTERING_WORLD" then
        ApplyBlizzard()
        local initial, reload = a1, a2
        if reload then
            lastZone, lastSub = GetZoneText(), GetSubZoneText()
        else
            C_Timer.After(initial and 2 or 0.5, function() OnZone(true) end)
        end
        C_Timer.After(1, ScanQuests)
        C_Timer.After(1.5, OnScenario)
        return
    end
    if not On() then return end
    if event == "ZONE_CHANGED_NEW_AREA" then
        OnZone()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        OnSubZone()
    elseif event == "UI_INFO_MESSAGE" then
        OnInfoMessage(a2)
    elseif event == "PLAYER_LEVEL_UP" then
        local level = a1
        Herald.Show("levelUp", "Level " .. tostring(level or (UnitLevel("player") or 0) + 1), "Well done, adventurer")
    elseif event == "ACHIEVEMENT_EARNED" then
        local id, already = a1, a2
        if already or type(id) ~= "number" then return end
        local _, name, points = GetAchievementInfo(id)
        if name then
            Herald.Show("achievement", name, (points and points > 0) and (points .. " points") or nil)
        end
    elseif event == "RAID_BOSS_EMOTE" then
        local text, who = a1, a2
        if text == nil then return end
        if not Secret(text) and not Secret(who) and type(text) == "string" and text:find("%%s") then
            local ok, out = pcall(string.format, text, who or "")
            if ok then text = out end
        end
        Herald.Show("bossEmote", text, nil)
    elseif event == "QUEST_ACCEPTED" then
        OnQuestAccepted(a1)
        QueueQuestScan()
    elseif event == "QUEST_TURNED_IN" then
        OnQuestTurnedIn(a1)
    elseif event == "QUEST_LOG_UPDATE" then
        QueueQuestScan()
    elseif event == "SCENARIO_UPDATE" or event == "SCENARIO_CRITERIA_UPDATE" then
        OnScenario()
    end
end)

---------------------------------------------------------------------------
-- H3z0 UI Edit Mode: "Herald Banner" can be moved like every other element
---------------------------------------------------------------------------
local function SetPreview(on)
    local f = Build()
    if on then
        preview = true
        ApplyLook()
        Paint({ kind = "zone", title = "Herald", subtitle = "Zone, level up, achievement and quest banners", label = "H3Z0 UI" })
        f:SetAlpha(1)
        f.label:ClearAllPoints()
        f.label:SetPoint("TOP", f, "TOP", 0, -14)
        f.line:SetWidth(LINE_WIDTH)
        f:Show()
    else
        preview = false
        if current then
            f:SetScript("OnUpdate", OnUpdate)
            Paint(current)
        else
            f:Hide()
        end
    end
end

local function RegisterLayout()
    local LM = ns.H3z0UI_LayoutMode
    if not (LM and LM.RegisterElement) then return end
    Holder()
    PlaceHolder()
    LM:RegisterElement({
        key = LAYOUT_KEY,
        label = "Herald Banner",
        group = (ns.L and ns.L["Display"]) or "Display",
        order = 90,
        isOwned = true,
        getFrame = function() return holder end,
        onOpen = function() SetPreview(true) end,
        onClose = function() SetPreview(false) end,
    })
    if _G.H3z0UI_RegisterFrameResolver then
        _G.H3z0UI_RegisterFrameResolver(LAYOUT_KEY, {
            resolver = function() return holder end,
            displayName = "Herald Banner", category = "Display", order = 90,
        })
    end
    C_Timer.After(0, PlaceHolder)
end

local lmEv = CreateFrame("Frame")
lmEv:RegisterEvent("PLAYER_LOGIN")
lmEv:SetScript("OnEvent", function() pcall(RegisterLayout) end)

---------------------------------------------------------------------------
-- Options / test
---------------------------------------------------------------------------
function Herald.Refresh()
    ApplyBlizzard()
    if not (ns.H3z0UI_LayoutMode and ns.H3z0UI_LayoutMode.isActive) then PlaceHolder() end
    if banner then ApplyLook() end
    if not On() then
        wipe(queue)
        current = nil
        if banner then banner:Hide(); banner:SetScript("OnUpdate", nil) end
    end
end
_G.H3z0UI_RefreshHerald = Herald.Refresh

function Herald.Test()
    local zone = GetZoneText() or "Dornogal"
    Herald.Show("zone", zone ~= "" and zone or "Dornogal", GetSubZoneText(), { force = true, extra = "Discovered" })
    Herald.Show("levelUp", "Level " .. (UnitLevel("player") or 80), "Well done, adventurer", { force = true })
    Herald.Show("achievement", "Glory of the H3z0 Hero", "10 points", { force = true })
    Herald.Show("questComplete", "A Fine Day for Testing", nil, { force = true })
end
_G.H3z0UI_HeraldTest = Herald.Test
