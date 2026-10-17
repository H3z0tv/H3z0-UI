---------------------------------------------------------------------------
-- H3z0UI Hover Name Module
-- Shows names (and optional extra info) of players / NPCs next to the cursor
-- while hovering them in the 3D world.
--
-- Based on HoverName by MorphieBlossom (MIT License), ported natively to
-- H3z0UI's database and options. See "libs/HoverName LICENSE.txt".
--
-- Midnight "secret values": every value coming from a unit API may be a secret
-- while in combat / M+. Secrets must never be compared, used in arithmetic or
-- used as table keys. They CAN be concatenated, string.format()-ed and passed
-- to FontString:SetText(). All logic below follows those rules.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local H3z0UI = ns.H3z0UI or {}
ns.H3z0UI = H3z0UI
local Helpers = ns.Helpers

local issecretvalue = issecretvalue or function() return false end
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

---------------------------------------------------------------------------
-- Defaults (used when a key is missing from the saved profile)
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = true,
    cursorAnchor = "TOP", offsetVertical = 18, offsetHorizontal = 0,
    aimGap = 28,   -- extra space from the cursor while mouselooking (the cursor is your aim then)
    fontSize = 12, fontType = "Friz Quadrata TT", fontOutline = "OUTLINE",
    bgEnabled = false, bgColor = {0, 0, 0, 1}, bgAlpha = 50, bgPadding = 2,
    playerClassColor = true, playerShowLevel = true, playerLevelColor = true,
    playerShowTarget = true, playerShowStatus = true, playerShowGuildName = false,
    playerShowGuildRank = false, playerShowRace = false, playerShowFaction = false,
    npcColorState = true, npcShowLevel = true, npcLevelColor = true, npcShowTarget = true,
    npcShowClassification = true, npcShowFaction = false, npcShowCreatureType = false,
    npcShowCombat = true,
    questShow = true, questShowCompleted = true, questFontSize = 9,
    mplusShowForces = true, mplusContributionFormat = "PERCENT", mplusShowProgress = false,
    mplusProgressFormat = "PERCENT", mplusFontSize = 12, mplusDisplayRight = false,
}

local function Get(key)
    local db = Helpers and Helpers.GetModuleDB and Helpers.GetModuleDB("hoverName")
    local v = db and db[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

---------------------------------------------------------------------------
-- Colors / icons
---------------------------------------------------------------------------
local COLOR = {
    ALLIANCE = { r = 0 / 255, g = 112 / 255, b = 221 / 255 },
    COMPLETE = { r = 136 / 255, g = 136 / 255, b = 136 / 255 },
    DEAD = { r = 136 / 255, g = 136 / 255, b = 136 / 255 },
    DEFAULT = { r = 1, g = 1, b = 1 },
    ELITE = { r = 213 / 255, g = 154 / 255, b = 18 / 255 },
    GUILD = { r = 24 / 255, g = 222 / 255, b = 0 },
    HORDE = { r = 1, g = 0, b = 0 },
    HOSTILE = { r = 1, g = 68 / 255, b = 68 / 255 },
    HOSTILE_UNATTACKABLE = { r = 210 / 255, g = 76 / 255, b = 56 / 255 },
    NEUTRAL = { r = 1, g = 1, b = 68 / 255 },
    RARE = { r = 226 / 255, g = 228 / 255, b = 226 / 255 },
    CONTEXT = { r = 0.7, g = 0.7, b = 0.7 },
}
local ICON_CHECKMARK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:11|t"
local ICON_LIST = "- "
local COMBAT_ICON_TEXTURE = "Interface\\CharacterFrame\\UI-StateIcon"

---------------------------------------------------------------------------
-- Utils
---------------------------------------------------------------------------
local function IsNotEmpty(val)
    return val ~= nil and (issecretvalue(val) or val ~= "")
end

local function Clamp255(x)
    if type(x) ~= "number" then return 255 end
    if x < 0 then return 0 end
    if x > 1 then x = 1 end
    return math.floor(x * 255 + 0.5)
end

local function Colorize(text, color)
    return string.format("|cFF%02x%02x%02x%s|r",
        Clamp255(color and color.r or 1), Clamp255(color and color.g or 1), Clamp255(color and color.b or 1), text)
end

local function CombineText(...)
    local combined
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if IsNotEmpty(v) then
            if combined then combined = combined .. " " .. v else combined = v end
        end
    end
    return combined
end

local function GetNpcID(unit)
    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then return nil end
    local npcID = select(6, strsplit("-", guid))
    if not npcID or npcID == "" then return nil end
    return tonumber(npcID)
end

local function GetTopMouseFocusName()
    if type(GetMouseFoci) == "function" then
        local foci = GetMouseFoci()
        if foci and foci[1] and foci[1].GetName then return foci[1]:GetName() end
    elseif type(GetMouseFocus) == "function" then
        local f = GetMouseFocus()
        if f and f.GetName then return f:GetName() end
    end
    return nil
end

local function GetTooltipLines()
    local lines = {}
    if not GameTooltip or UnitIsPlayer("mouseover") then return lines end
    for i = 1, GameTooltip:NumLines() do
        local fs = _G["GameTooltipTextLeft" .. i]
        if fs and fs.GetText then
            local line = fs:GetText()
            if line then lines[#lines + 1] = line end
        end
    end
    return lines
end

local function IsInTooltip(lines, query)
    if type(query) ~= "string" or query == "" or issecretvalue(query) then return false end
    local q = string.lower(query)
    for _, line in ipairs(lines) do
        if line and not issecretvalue(line) then
            if string.find(string.lower(line), q, 1, true) then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Unit info
---------------------------------------------------------------------------
local function IsPlayer(unit) return UnitIsPlayer(unit or "mouseover") end

local function UnitNameColor(unit)
    local reaction = UnitReaction(unit, "player")
    if reaction == nil or issecretvalue(reaction) then reaction = 5 end

    if IsPlayer(unit) then
        if Get("playerClassColor") then
            local _, class = UnitClass(unit)
            if class == nil or issecretvalue(class) then return COLOR.DEFAULT end
            return RAID_CLASS_COLORS[class] or COLOR.DEFAULT
        end
        return COLOR.DEFAULT
    elseif not Get("npcColorState") then
        return COLOR.DEFAULT
    end

    local canAttack = UnitCanAttack("player", unit)
    if issecretvalue(canAttack) then return COLOR.DEFAULT end
    if canAttack then
        local dead = UnitIsDead(unit)
        if not issecretvalue(dead) and dead then return COLOR.DEAD end
        if reaction < 4 then return COLOR.HOSTILE
        elseif reaction == 4 then return COLOR.NEUTRAL end
        return COLOR.DEFAULT
    end
    if reaction < 4 then return COLOR.HOSTILE_UNATTACKABLE end
    return COLOR.DEFAULT
end

local function LevelText()
    local isPlayer = IsPlayer()
    if isPlayer and not Get("playerShowLevel") then return "" end
    if not isPlayer and not Get("npcShowLevel") then return "" end

    local level = UnitLevel("mouseover")
    if level == nil or issecretvalue(level) then return "" end
    if level > 1 then
        local s = tostring(level)
        if (isPlayer and not Get("playerLevelColor")) or (not isPlayer and not Get("npcLevelColor")) then
            return s
        end
        return Colorize(s, GetQuestDifficultyColor(level))
    end
    return ""
end

local function TargetText()
    local isPlayer = IsPlayer()
    if isPlayer and not Get("playerShowTarget") then return "" end
    if not isPlayer and not Get("npcShowTarget") then return "" end
    local target = UnitName("mouseovertarget")
    if target then
        return Colorize("> ", COLOR.DEFAULT) .. Colorize(target, UnitNameColor("mouseovertarget"))
    end
    return ""
end

local function StatusText()
    if not IsPlayer() or not Get("playerShowStatus") then return nil end
    local isAfk, isDnd, isPvp = UnitIsAFK("mouseover"), UnitIsDND("mouseover"), UnitIsPVP("mouseover")
    local afk, dnd, pvp
    if not issecretvalue(isAfk) and isAfk then afk = Colorize("<AFK>", COLOR.DEAD) end
    if not issecretvalue(isDnd) and isDnd then dnd = Colorize("<DND>", COLOR.HOSTILE) end
    if not issecretvalue(isPvp) and isPvp then pvp = Colorize("<PVP>", COLOR.HOSTILE) end
    return CombineText(afk, dnd, pvp)
end

local function ClassificationText()
    if IsPlayer() or not Get("npcShowClassification") then return nil end
    local c = UnitClassification("mouseover")
    if c == nil or issecretvalue(c) then return nil end
    if c == "worldboss" then return Colorize("World Boss", COLOR.ELITE)
    elseif c == "elite" then return Colorize("Elite", COLOR.ELITE)
    elseif c == "rareelite" then return Colorize("Rare Elite", COLOR.RARE)
    elseif c == "rare" then return Colorize("Rare", COLOR.RARE) end
    return nil
end

local function GuildText()
    if not IsPlayer() then return nil end
    local showName, showRank = Get("playerShowGuildName"), Get("playerShowGuildRank")
    if not showName and not showRank then return nil end
    local guildName, guildRank = GetGuildInfo("mouseover")
    if not guildName or issecretvalue(guildName) then return nil end
    local text = ""
    if showName then text = text .. "<" .. Colorize(guildName, COLOR.GUILD) .. ">" end
    if showRank and guildRank and not issecretvalue(guildRank) and guildRank ~= "" then
        if text ~= "" then text = text .. " " end
        text = text .. "[" .. Colorize(guildRank, COLOR.GUILD) .. "]"
    end
    if text == "" then return nil end
    return text
end

local function FactionText()
    local isPlayer = IsPlayer()
    if isPlayer and not Get("playerShowFaction") then return nil end
    if not isPlayer and not Get("npcShowFaction") then return nil end
    local label, faction = UnitFactionGroup("mouseover")
    if not label or issecretvalue(label) then return nil end
    if faction == "Horde" then return Colorize(label, COLOR.HORDE)
    elseif faction == "Alliance" then return Colorize(label, COLOR.ALLIANCE) end
    return Colorize(label, COLOR.NEUTRAL)
end

local function RaceText()
    if not IsPlayer() or not Get("playerShowRace") then return nil end
    local race = UnitRace("mouseover")
    if race then return Colorize(race, COLOR.DEFAULT) end
    return nil
end

local function CombatIcon()
    if IsPlayer() or not Get("npcShowCombat") then return nil end
    local inCombat = UnitAffectingCombat("mouseover")
    if inCombat == nil or issecretvalue(inCombat) or not inCombat then return nil end
    local size = tonumber(Get("fontSize")) or 12
    return string.format("|T%s:%d:%d:0:0:64:64:32:64:0:31|t", COMBAT_ICON_TEXTURE, size, size)
end

local function CreatureTypeText()
    if IsPlayer() or not Get("npcShowCreatureType") then return nil end
    local t = UnitCreatureType("mouseover")
    if t and not issecretvalue(t) and t ~= "Not specified" then return Colorize(t, COLOR.DEFAULT) end
    return nil
end

---------------------------------------------------------------------------
-- Quest info
---------------------------------------------------------------------------
local function GetActiveQuests()
    local results = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then
                local objectives = {}
                for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                    objectives[#objectives + 1] = { text = o.text, type = o.type, finished = (o.finished == true) }
                end
                results[#results + 1] = { questID = info.questID, objectives = objectives }
            end
        end
    end
    return results
end

local function StripQuestCount(text)
    if not text then return "" end
    local s = string.lower(text)
    s = s:gsub("%s*:?%s*%d+/%d+", "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function QuestText(unit, tooltipLines)
    if UnitIsPlayer(unit) or not Get("questShow") then return nil end
    if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest and not C_QuestLog.UnitIsRelatedToActiveQuest(unit) then
        return nil
    end

    local unitName = UnitName(unit)
    if not unitName or (not issecretvalue(unitName) and unitName == "") then return nil end

    local targetName = (not issecretvalue(unitName)) and string.lower(unitName) or nil
    local LOP = LibStub and LibStub:GetLibrary("LibObjectiveProgress-1.0", true)
    local weights
    local npcID = GetNpcID(unit)
    if npcID and LOP and LOP.GetNPCWeightByCurrentQuests then
        weights = LOP:GetNPCWeightByCurrentQuests(npcID)
    end

    local questTexts = {}
    for _, info in ipairs(GetActiveQuests()) do
        for _, obj in ipairs(info.objectives or {}) do
            local text = obj.text
            if text and not issecretvalue(text) then
                if obj.type == "progressbar" and weights and weights[info.questID] then
                    questTexts[#questTexts + 1] = { text = text .. string.format(" + %.1f%%", weights[info.questID]), finished = obj.finished }
                    break
                end
                if obj.type == "monster" and targetName and string.find(string.lower(text), targetName, 1, true) then
                    questTexts[#questTexts + 1] = { text = text, finished = obj.finished }
                    break
                end
                if IsInTooltip(tooltipLines, text) or IsInTooltip(tooltipLines, StripQuestCount(text)) then
                    questTexts[#questTexts + 1] = { text = text, finished = obj.finished }
                    break
                end
            end
        end
    end

    if not Get("questShowCompleted") then
        local filtered = {}
        for _, e in ipairs(questTexts) do if not e.finished then filtered[#filtered + 1] = e end end
        questTexts = filtered
    end

    table.sort(questTexts, function(a, b) return not a.finished and b.finished end)

    local out = {}
    for _, e in ipairs(questTexts) do
        local color = e.finished and COLOR.COMPLETE or COLOR.DEFAULT
        local icon = e.finished and ICON_CHECKMARK or ICON_LIST
        out[#out + 1] = Colorize(icon .. e.text, color)
    end
    return #out > 0 and out or nil
end

---------------------------------------------------------------------------
-- Mythic+ enemy forces (display-only: never do math on secret values)
---------------------------------------------------------------------------
local function InMythicPlus()
    if not (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive) then return false end
    local ok, active = pcall(C_ChallengeMode.IsChallengeModeActive)
    return ok and active == true
end

local function Present(v)
    if issecretvalue(v) then return true end
    return v ~= nil and v ~= ""
end

local function NumberStr(v)
    if not Present(v) then return nil end
    return "" .. v
end

local function Compose(mode, numberStr, percentStr)
    if mode == "NUMBER" then return numberStr or percentStr
    elseif mode == "BOTH" then
        if numberStr and percentStr then return numberStr .. " (" .. percentStr .. ")" end
        return numberStr or percentStr
    end
    return percentStr or numberStr
end

local function GetForcesCriteria()
    if not (C_Scenario and C_Scenario.GetStepInfo and C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo) then return nil end
    local _, _, numCriteria = C_Scenario.GetStepInfo()
    if not numCriteria or issecretvalue(numCriteria) or numCriteria <= 0 then return nil end
    for i = 1, numCriteria do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and info.isWeightedProgress then return info.quantity, info.totalQuantity end
    end
    return nil
end

local function BuildForces(unit)
    if not Get("mplusShowForces") then return nil end
    if UnitIsPlayer(unit) or not InMythicPlus() then return nil end
    if not (C_ScenarioInfo and C_ScenarioInfo.GetUnitCriteriaProgressValues) then return nil end

    local actualValue, _, percentValueString = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
    if not issecretvalue(actualValue) then
        local n = tonumber(actualValue)
        if not n or n <= 0 then return nil end
    end

    local mode = Get("mplusContributionFormat") or "PERCENT"
    local pctPart = Present(percentValueString) and (percentValueString .. "%") or nil
    local contrib = Compose(mode, NumberStr(actualValue), pctPart)
    if not contrib then return nil end

    local line = Colorize("+" .. contrib, COLOR.DEFAULT)

    if Get("mplusShowProgress") then
        local currentQ, totalQ = GetForcesCriteria()
        if Present(currentQ) then
            local pMode = Get("mplusProgressFormat") or "PERCENT"
            local curNum
            if not issecretvalue(currentQ) and not issecretvalue(totalQ) then
                local cp, tr = tonumber(currentQ), tonumber(totalQ)
                if cp and tr then curNum = tostring(math.floor((cp / 100) * tr + 0.5)) end
            end
            local currentStr = Compose(pMode, curNum, NumberStr(currentQ))
            local totalStr = Compose(pMode, NumberStr(totalQ), "100%")
            if currentStr and totalStr then
                line = line .. " " .. Colorize("(" .. currentStr .. " / " .. totalStr .. ")", COLOR.CONTEXT)
            end
        end
    end
    return { line }
end

local function ForcesText(unit)
    local ok, result = pcall(BuildForces, unit)
    if ok then return result end
    return nil
end

local function ForcesReserveText()
    local mode = Get("mplusContributionFormat") or "PERCENT"
    local reserve = (mode == "NUMBER" and "+999") or (mode == "BOTH" and "+999 (100%)") or "+100%"
    if Get("mplusShowProgress") then
        local pMode = Get("mplusProgressFormat") or "PERCENT"
        local ctx = (pMode == "NUMBER" and "(999 / 999)") or (pMode == "BOTH" and "(999 (100%) / 999 (100%))") or "(999 / 100%)"
        reserve = reserve .. " " .. ctx
    end
    return reserve
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local Layout = {
    LINE_STEP = 13, LINE_OFFSET = 2, SUB_BOTTOM_OFFSET = 1, SUB_LINE_STEP = 12, SUB_LEFT_INSET = 12,
    FRAME_MIN_WIDTH = 1, FRAME_MIN_HEIGHT = 1, FORCES_GAP_RIGHT = 6, FORCES_GAP_UNDER = 2, COMBAT_ICON_GAP = -2,
}

local ANCHOR_TO_POINT = {
    TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT",
    TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT",
}

local frame = CreateFrame("Frame", "H3z0UIHoverNameFrame", UIParent, "BackdropTemplate")
frame:SetFrameStrata("TOOLTIP")
frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
frame:SetBackdropColor(0, 0, 0, 0)
frame:Hide()

frame.mainText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.combatIcon = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.headerText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.guildText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.subText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.forcesText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")

local function ResolveFontPath()
    local name = Get("fontType")
    local path
    if LSM and name then path = LSM:Fetch("font", name, true) end
    return path or "Fonts\\FRIZQT__.TTF"
end

local function UpdateFonts()
    local path = ResolveFontPath()
    local size = tonumber(Get("fontSize")) or 12
    local outline = Get("fontOutline") or "OUTLINE"
    if outline == "NONE" then outline = "" end
    local mpSize = tonumber(Get("mplusFontSize")) or size
    local questSize = tonumber(Get("questFontSize")) or (size - 3)

    local function Set(fs, s)
        if not (fs and fs:SetFont(path, math.max(s, 6), outline)) then
            fs:SetFont("Fonts\\FRIZQT__.TTF", math.max(s, 6), outline)
        end
    end
    Set(frame.mainText, size)
    Set(frame.combatIcon, size)
    Set(frame.headerText, size - 3)
    Set(frame.statusText, size - 4)
    Set(frame.guildText, size - 4)
    Set(frame.subText, questSize)
    Set(frame.forcesText, mpSize)
end

local function UpdateBackground()
    if not Get("bgEnabled") then
        frame:SetBackdropColor(0, 0, 0, 0)
        return
    end
    local c = Get("bgColor") or DEFAULTS.bgColor
    local alpha = tonumber(Get("bgAlpha")) or 50
    if alpha > 1 then alpha = alpha / 100 end
    frame:SetBackdropColor(c[1] or c.r or 0, c[2] or c.g or 0, c[3] or c.b or 0, alpha)
end

local function Measure(fs)
    local w, h = 0, 0
    local okW, rw = pcall(fs.GetStringWidth, fs)
    local okH, rh = pcall(fs.GetStringHeight, fs)
    if okW and type(rw) == "number" and not issecretvalue(rw) then w = rw end
    if okH and type(rh) == "number" and not issecretvalue(rh) then h = rh end
    return w, h
end

local function SetStackAnchor(element, anchor, top)
    local margin = (top or 0) + Layout.LINE_STEP
    element:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, margin)
    return margin + Layout.LINE_OFFSET
end

local fontsReady = false

local function UpdateContents()
    if not fontsReady then
        fontsReady = true
        pcall(UpdateFonts)
    end

    local focusName = GetTopMouseFocusName()
    if IsNotEmpty(focusName) and focusName ~= "WorldFrame" then return end

    local unitName = UnitName("mouseover")
    if unitName == nil then return end

    local unitText = Colorize(unitName, UnitNameColor("mouseover"))

    local combatIcon
    pcall(function() combatIcon = CombatIcon() end)

    local level = LevelText()
    local targetName = TargetText()
    local status = StatusText()
    local classification = ClassificationText()
    local guild = GuildText()
    local faction = FactionText()
    local race = RaceText()
    local creatureType = CreatureTypeText()

    local mainText = CombineText(level, unitText, targetName)
    local headerText = CombineText(faction, classification, creatureType, race)

    frame.mainText:SetText(mainText or "")
    frame.combatIcon:SetText(combatIcon or "")
    frame.statusText:SetText(status or "")
    frame.headerText:SetText(headerText or "")
    frame.guildText:SetText(guild or "")

    -- Quest / objective lines
    local okQ, subTexts = pcall(QuestText, "mouseover", GetTooltipLines())
    if not okQ then subTexts = nil end
    local subCount = subTexts and #subTexts or 0
    if subCount > 0 then
        frame.subText:SetText(table.concat(subTexts, "\n"))
    else
        frame.subText:SetText("")
    end

    -- Mythic+ enemy forces
    local forcesArr = ForcesText("mouseover")
    local hasForces = forcesArr ~= nil
    local forcesRight = hasForces and (Get("mplusDisplayRight") and true or false)

    local mainW, mainH = Measure(frame.mainText)
    local guildW = Measure(frame.guildText)
    local headerW = Measure(frame.headerText)
    local statusW = Measure(frame.statusText)
    local subW, subH = Measure(frame.subText)
    local fontSize = tonumber(Get("fontSize")) or 14
    local mpFontSize = tonumber(Get("mplusFontSize")) or fontSize

    local forcesW, forcesH = 0, 0
    if hasForces then
        frame.forcesText:SetText(ForcesReserveText())
        forcesW = Measure(frame.forcesText)
        frame.forcesText:SetText(forcesArr[1])
        forcesH = mpFontSize
    else
        frame.forcesText:SetText("")
    end

    mainW = math.max(mainW, 1)
    mainH = math.max(mainH, fontSize)

    local topLines = 0
    if IsNotEmpty(guild) then topLines = topLines + 1 end
    if IsNotEmpty(headerText) then topLines = topLines + 1 end
    if IsNotEmpty(status) then topLines = topLines + 1 end

    local padding = math.max(0, tonumber(Get("bgPadding")) or 0)
    local topExtra = (topLines * Layout.LINE_STEP) + padding

    local dropY, forcesUnderY, questY = 0, nil, nil
    local forcesUnder = hasForces and not forcesRight
    if forcesUnder then
        dropY = dropY + Layout.FORCES_GAP_UNDER
        forcesUnderY = -dropY
        dropY = dropY + forcesH
    end
    if subCount > 0 then
        dropY = dropY + Layout.SUB_BOTTOM_OFFSET
        questY = -dropY
        dropY = dropY + ((subH > 0) and subH or (Layout.SUB_LINE_STEP * subCount))
    end

    local belowMain = dropY
    if belowMain > 0 then belowMain = belowMain + Layout.SUB_BOTTOM_OFFSET end

    local rightExtra = 0
    if hasForces and forcesRight then
        rightExtra = Layout.FORCES_GAP_RIGHT + forcesW
        mainH = math.max(mainH, forcesH)
    end
    local forcesUnderWidth = forcesUnder and (forcesW + Layout.SUB_LEFT_INSET) or 0

    local width = math.max(mainW + rightExtra, guildW, headerW, statusW, subW + Layout.SUB_LEFT_INSET, forcesUnderWidth)
    width = math.max(Layout.FRAME_MIN_WIDTH, width + (padding * 2))
    local height = math.max(Layout.FRAME_MIN_HEIGHT, topExtra + mainH + belowMain + padding)

    frame:SetSize(width, height)
    frame.mainText:ClearAllPoints()
    frame.mainText:SetPoint("TOP", frame, "TOP", -(rightExtra / 2), -topExtra)

    frame.combatIcon:ClearAllPoints()
    if combatIcon then
        frame.combatIcon:SetPoint("RIGHT", frame.mainText, "LEFT", -Layout.COMBAT_ICON_GAP, 0)
    end

    frame.guildText:ClearAllPoints()
    frame.headerText:ClearAllPoints()
    frame.statusText:ClearAllPoints()
    local top = 0
    if IsNotEmpty(guild) then top = SetStackAnchor(frame.guildText, frame.mainText, top) end
    if IsNotEmpty(headerText) then top = SetStackAnchor(frame.headerText, frame.mainText, top) end
    if IsNotEmpty(status) then top = SetStackAnchor(frame.statusText, frame.mainText, top) end

    frame.subText:ClearAllPoints()
    if subCount > 0 then
        frame.subText:SetPoint("TOPLEFT", frame.mainText, "BOTTOMLEFT", Layout.SUB_LEFT_INSET, questY)
    end

    frame.forcesText:ClearAllPoints()
    if hasForces then
        if forcesRight then
            frame.forcesText:SetPoint("LEFT", frame.mainText, "RIGHT", Layout.FORCES_GAP_RIGHT, 0)
        else
            frame.forcesText:SetPoint("TOPLEFT", frame.mainText, "BOTTOMLEFT", Layout.SUB_LEFT_INSET, forcesUnderY)
        end
    end

    UpdateBackground()
    frame:Show()
end

local function UpdatePosition()
    if not UnitExists("mouseover") then
        frame:Hide()
        return
    end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local anchor = Get("cursorAnchor") or "TOP"
    local point = ANCHOR_TO_POINT[anchor] or ANCHOR_TO_POINT.TOP
    local xOff = tonumber(Get("offsetHorizontal")) or 0
    local yOff = tonumber(Get("offsetVertical")) or 18

    -- While mouselooking / Action Combat the cursor is the aim point in the middle
    -- of the screen: move the name further away so it never covers the crosshair.
    if IsMouselooking and IsMouselooking() then
        local gap = tonumber(Get("aimGap")) or 28
        if anchor:find("TOP") then yOff = yOff + gap end
        if anchor:find("BOTTOM") then yOff = yOff - gap end
        if anchor:find("LEFT") then xOff = xOff - gap end
        if anchor:find("RIGHT") then xOff = xOff + gap end
    end

    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, "BOTTOMLEFT", (x / scale) + xOff, (y / scale) + yOff)
end

---------------------------------------------------------------------------
-- Enable / disable and refresh
---------------------------------------------------------------------------
local function Apply()
    if Get("enabled") then
        frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    else
        frame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
        frame:Hide()
    end
    pcall(UpdateFonts)
    pcall(UpdateBackground)
end

frame:SetScript("OnUpdate", function() pcall(UpdatePosition) end)
frame:SetScript("OnEvent", function(self, event)
    if event == "UPDATE_MOUSEOVER_UNIT" then
        -- Never let an error here break the UI
        local ok = pcall(UpdateContents)
        if not ok then self:Hide() end
    elseif event == "PLAYER_LOGIN" then
        Apply()
    end
end)
frame:RegisterEvent("PLAYER_LOGIN")

_G.H3z0UI_RefreshHoverName = function()
    Apply()
end
