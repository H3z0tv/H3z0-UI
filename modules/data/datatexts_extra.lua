--- H3z0UI Extra Datatexts
--- Datatexts that complete the "Bottom Bar" look: icon menu, difficulty, professions,
--- movement speed and location. They register into the normal Datatexts registry, so
--- they can be used in any datapanel slot.

local ADDON_NAME, ns = ...
local H3z0UICore = ns.Addon
local Datatexts = H3z0UICore and H3z0UICore.Datatexts
if not Datatexts then return end

local floor = math.floor
local issecretvalue = issecretvalue or function() return false end

---------------------------------------------------------------------------
-- Helpers (same value-color logic as the built-in datatexts)
---------------------------------------------------------------------------
local function GetValueColor()
    local addon = ns and ns.Addon
    local db = addon and addon.db and addon.db.profile
    local dt = db and db.datatext
    if not dt then return 26, 255, 26 end
    if dt.useClassColor then
        local _, class = UnitClass("player")
        local color = class and RAID_CLASS_COLORS[class]
        if color then return floor(color.r * 255), floor(color.g * 255), floor(color.b * 255) end
    end
    local c = dt.valueColor or {0.1, 1.0, 0.1, 1}
    return floor(c[1] * 255), floor(c[2] * 255), floor(c[3] * 255)
end

local function EnsureText(slotFrame)
    local text = slotFrame.text
    if not text then
        text = slotFrame:CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER")
        slotFrame.text = text
    end
    return text
end

local function HintLine(left, right)
    local r, g, b = GetValueColor()
    GameTooltip:AddLine("|cffFFFFFF" .. left .. ":|r " .. right, r / 255, g / 255, b / 255)
end

local function Try(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- Size options live on the panel config (Bottom Bar tab > Icons & Sizes); 0 / nil = automatic
local function Opt(settings, key, default)
    local v = settings and tonumber(settings[key])
    if v and v > 0 then return v end
    return default
end

---------------------------------------------------------------------------
-- Great Vault data (used by the Menu Icons button and the Great Vault datatext)
---------------------------------------------------------------------------
local VAULT_ROWS = {
    { key = "raid",  label = "Raid",      type = (Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Raid) or 3 },
    { key = "mplus", label = "Dungeons",  type = (Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Activities) or 1 },
    { key = "world", label = "World",     type = (Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.World) or 6 },
}

local function PlainNum(v)
    if type(v) ~= "number" or issecretvalue(v) then return 0 end
    return v
end

-- { rows = { {label=, slots = { {unlocked=, progress=, threshold=, level=} ... }} ... }, unlocked = n, total = n, claimable = bool }
local function ReadVault()
    local result = { rows = {}, unlocked = 0, total = 0, claimable = false }
    if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then return result end
    for _, row in ipairs(VAULT_ROWS) do
        local ok, acts = pcall(C_WeeklyRewards.GetActivities, row.type)
        local slots = {}
        if ok and type(acts) == "table" then
            table.sort(acts, function(a, b) return PlainNum(a.index) < PlainNum(b.index) end)
            for _, a in ipairs(acts) do
                local progress, threshold = PlainNum(a.progress), PlainNum(a.threshold)
                local unlocked = threshold > 0 and progress >= threshold
                slots[#slots + 1] = { unlocked = unlocked, progress = math.min(progress, threshold),
                                      threshold = threshold, level = PlainNum(a.level) }
                result.total = result.total + 1
                if unlocked then result.unlocked = result.unlocked + 1 end
            end
        end
        result.rows[#result.rows + 1] = { label = row.label, key = row.key, slots = slots }
    end
    if C_WeeklyRewards.HasAvailableRewards then
        local ok, has = pcall(C_WeeklyRewards.HasAvailableRewards)
        result.claimable = ok and has == true
    end
    return result
end

local function SlotDetail(rowKey, level)
    if level <= 0 then return "" end
    if rowKey == "raid" then
        local name = GetDifficultyInfo and GetDifficultyInfo(level)
        return type(name) == "string" and name or ("Difficulty " .. level)
    elseif rowKey == "mplus" then
        return "+" .. level
    end
    return "Tier " .. level
end

local function OpenHousing()
    if InCombatLockdown() then return end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_HousingDashboard") end
    if HousingFramesUtil and HousingFramesUtil.ToggleHousingDashboard then
        pcall(HousingFramesUtil.ToggleHousingDashboard)
    elseif ToggleHousingDashboard then
        pcall(ToggleHousingDashboard)
    elseif HousingMicroButton and HousingMicroButton.Click then
        pcall(HousingMicroButton.Click, HousingMicroButton)
    end
end

local function OpenVault()
    if InCombatLockdown() then return end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards") end
    if WeeklyRewards_ShowUI then
        pcall(WeeklyRewards_ShowUI)
    elseif WeeklyRewardsFrame then
        if WeeklyRewardsFrame:IsShown() then HideUIPanel(WeeklyRewardsFrame) else ShowUIPanel(WeeklyRewardsFrame) end
    end
end


-- Fills a tooltip with the Great Vault overview (shared by the menu button and the datatext)
local function FillVaultTooltip(v)
    GameTooltip:AddLine("Great Vault", 1, 1, 1)
    GameTooltip:AddLine(" ")
    for _, row in ipairs(v.rows) do
        if #row.slots > 0 then
            GameTooltip:AddLine(row.label, 1, 0.82, 0)
            for i, slot in ipairs(row.slots) do
                if slot.unlocked then
                    local detail = SlotDetail(row.key, slot.level)
                    GameTooltip:AddDoubleLine("  Slot " .. i, "|cff33ff33Unlocked|r" .. (detail ~= "" and (" - " .. detail) or ""), 0.7, 0.7, 0.7, 1, 1, 1)
                else
                    GameTooltip:AddDoubleLine("  Slot " .. i, string.format("%d/%d", slot.progress, slot.threshold), 0.7, 0.7, 0.7, 0.62, 0.62, 0.62)
                end
            end
        end
    end
    if v.claimable then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Rewards are ready to claim!", 0.2, 1, 0.2)
    end
end

-- Small numbers shown above some menu icons (online guild members, online friends, vault slots)
local COUNT_COLOR = { 0.36, 0.84, 1 }

local function OnlineGuild()
    if not (IsInGuild and IsInGuild()) then return 0 end
    local _, online = GetNumGuildMembers()
    return PlainNum(online)
end

local function OnlineFriends()
    local n = 0
    if C_FriendList and C_FriendList.GetNumOnlineFriends then n = n + PlainNum(C_FriendList.GetNumOnlineFriends()) end
    if BNGetNumFriends then
        local _, online = BNGetNumFriends()
        n = n + PlainNum(online)
    end
    return n
end

-- returns the text to show above the icon (nil = nothing) and an optional {r,g,b}
local COUNTERS = {
    guild = function()
        local n = OnlineGuild()
        return n > 0 and tostring(n) or nil
    end,
    social = function()
        local n = OnlineFriends()
        return n > 0 and tostring(n) or nil
    end,
    vault = function()
        local v = ReadVault()
        if v.claimable then return "!", { 0.2, 1, 0.2 } end
        return v.unlocked > 0 and tostring(v.unlocked) or nil
    end,
}

---------------------------------------------------------------------------
-- 1) MICRO MENU: a row of icon buttons
---------------------------------------------------------------------------
local MICRO = {
    { name = "Game Menu", custom = "menu", file = "Interface\\Icons\\INV_Misc_Gear_01", atlas = "UI-HUD-MicroMenu-GameMenu-Up", letter = "M",
      click = function()
          if ToggleGameMenu then ToggleGameMenu()
          elseif GameMenuFrame then
              if GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) else ShowUIPanel(GameMenuFrame) end
          end
      end },
    { name = "Character", custom = "character", atlas = "UI-HUD-MicroMenu-Character-Up", letter = "C",
      click = function() ToggleCharacter("PaperDollFrame") end },
    { name = "Spellbook & Talents", custom = "spellbook", file = "Interface\\Icons\\INV_Misc_Book_09", atlas = "UI-HUD-MicroMenu-SpecTalents-Up", letter = "T",
      click = function()
          if PlayerSpellsUtil and PlayerSpellsUtil.TogglePlayerSpellsFrame then
              PlayerSpellsUtil.TogglePlayerSpellsFrame()
          elseif ToggleTalentFrame then ToggleTalentFrame() end
      end },
    { name = "Achievements", custom = "achievements", file = "Interface\\Icons\\Achievement_General", atlas = "UI-HUD-MicroMenu-Achievements-Up", letter = "A",
      click = function() ToggleAchievementFrame() end },
    { name = "Quest Log", custom = "quest", file = "Interface\\GossipFrame\\AvailableQuestIcon", atlas = "UI-HUD-MicroMenu-Questlog-Up", letter = "Q",
      click = function()
          if ToggleQuestLog then ToggleQuestLog() elseif ToggleWorldMap then ToggleWorldMap() end
      end },
    { name = "Guild & Communities", custom = "guild", counter = "guild", file = "Interface\\Icons\\INV_Shirt_GuildTabard_01", atlas = "UI-HUD-MicroMenu-GuildCommunities-Up", letter = "G",
      click = function()
          if ToggleGuildFrame then ToggleGuildFrame()
          elseif ToggleCommunitiesFrame then ToggleCommunitiesFrame() end
      end },
    { name = "Social", custom = "social", counter = "social", file = "Interface\\Icons\\INV_Misc_GroupNeedMore", atlas = "UI-HUD-MicroMenu-Socials-Up", letter = "S",
      click = function() ToggleFriendsFrame(1) end },
    { name = "Group Finder", custom = "groupfinder", file = "Interface\\LFGFrame\\UI-LFG-PORTRAIT", noCrop = true, atlas = "UI-HUD-MicroMenu-GroupFinder-Up", letter = "F",
      click = function() PVEFrame_ToggleFrame() end },
    { name = "Adventure Guide", custom = "adventure", file = "Interface\\Icons\\INV_Misc_Map_01", atlas = "UI-HUD-MicroMenu-AdventureGuide-Up", letter = "J",
      click = function() ToggleEncounterJournal() end },
    { name = "Collections", custom = "collections", file = "Interface\\Icons\\Ability_Mount_RidingHorse", atlas = "UI-HUD-MicroMenu-Collections-Up", letter = "P",
      click = function() ToggleCollectionsJournal() end },
    { name = "Housing", custom = "housing", letter = "H", click = function() OpenHousing() end },
    { name = "Great Vault", custom = "vault", counter = "vault", letter = "V", click = function() OpenVault() end },
}

-- Own icon set (assets\\menuicons\\*.tga); a def's "custom" field picks the file
local MENU_ICON_PATH = "Interface\\AddOns\\H3z0UI\\assets\\menuicons\\"

local function AtlasExists(atlas)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
end

Datatexts:Register("micromenu", {
    displayName = "Menu Icons",
    category = "System",
    description = "A row of icon buttons for the game menu, character, talents, achievements, quests, guild, social, group finder, adventure guide, collections, housing and the Great Vault",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()

        -- this datatext draws icons instead of text
        local text = EnsureText(slotFrame)
        text:SetText("")

        local n = #MICRO
        local w = slotFrame:GetWidth() or 200
        local h = slotFrame:GetHeight() or 22
        local fit = floor((w - 8 - (n - 1)) / n)               -- largest icon that still fits the slot
        local size = math.max(10, math.min(h - 6, floor((w - 8) / n) - 2, 22))
        local userSize = Opt(settings, "menuIconSize", nil)
        if userSize then size = math.max(8, math.min(userSize, fit, h - 2)) end
        local gap = math.max(2, floor((w - 8 - size * n) / math.max(n - 1, 1)))
        gap = math.min(gap, 10)
        local userGap = tonumber(settings and settings.menuIconSpacing)
        if userGap and userGap > 0 then gap = math.max(1, math.min(userGap, floor((w - 8 - size * n) / math.max(n - 1, 1)))) end
        local totalW = size * n + gap * (n - 1)
        local startX = 4

        local r, g, b = GetValueColor()
        local buttons = {}

        for i, def in ipairs(MICRO) do
            local btn = CreateFrame("Button", nil, frame)
            btn:SetSize(size, size)
            btn:SetPoint("LEFT", frame, "LEFT", startX + (i - 1) * (size + gap), 0)

            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            local shown = false
            if def.file == "CLASS" then
                -- your class icon, in full color
                local _, classFile = UnitClass("player")
                local classAtlas = classFile and ("classicon-" .. classFile:lower())
                if classAtlas and AtlasExists(classAtlas) then
                    tex:SetAtlas(classAtlas)
                    shown = true
                elseif classFile then
                    tex:SetTexture("Interface\\Icons\\ClassIcon_" .. classFile:sub(1, 1):upper() .. classFile:sub(2):lower())
                    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    shown = true
                end
            elseif def.custom then
                tex:SetTexture(MENU_ICON_PATH .. def.custom)
                shown = true
            elseif def.file then
                tex:SetTexture(def.file)
                if not def.noCrop then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                shown = true
            elseif def.atlas and AtlasExists(def.atlas) then
                tex:SetAtlas(def.atlas)
                shown = true
            end

            if shown then
                tex:SetAlpha(0.85)
            else
                tex:Hide()
                local letter = btn:CreateFontString(nil, "OVERLAY")
                local fontPath = text:GetFont() or "Fonts\\FRIZQT__.TTF"
                letter:SetFont(fontPath, math.max(9, size - 4), "OUTLINE")
                letter:SetPoint("CENTER")
                letter:SetText(def.letter)
                letter:SetTextColor(1, 1, 1, 0.9)
                btn.letter = letter
            end
            btn.tex = tex

            -- thin border so non-custom icons read as buttons (the custom glyphs are drawn on transparent)
            if not def.custom then
                local border = btn:CreateTexture(nil, "BORDER")
                border:SetPoint("TOPLEFT", -1, 1)
                border:SetPoint("BOTTOMRIGHT", 1, -1)
                border:SetColorTexture(0, 0, 0, 0.8)
            end

            -- number above the icon
            if def.counter then
                local count = btn:CreateFontString(nil, "OVERLAY")
                local countFont = text:GetFont() or "Fonts\\FRIZQT__.TTF"
                count:SetFont(countFont, Opt(settings, "menuCounterSize", 11), "OUTLINE")
                count:SetPoint("BOTTOM", btn, "TOP", 0, -1)
                count:SetTextColor(COUNT_COLOR[1], COUNT_COLOR[2], COUNT_COLOR[3], 1)
                btn.count = count
                btn.counterFn = COUNTERS[def.counter]
            end

            btn:SetScript("OnEnter", function(self)
                if self.letter then self.letter:SetTextColor(r / 255, g / 255, b / 255, 1)
                else
                    self.tex:SetAlpha(1)
                    if def.custom then self.tex:SetVertexColor(r / 255, g / 255, b / 255) end
                end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:ClearLines()
                if def.counter == "vault" then
                    FillVaultTooltip(ReadVault())
                else
                    GameTooltip:AddLine(def.name, 1, 1, 1)
                    if def.counter == "guild" then
                        GameTooltip:AddDoubleLine("Online:", tostring(OnlineGuild()), 0.7, 0.7, 0.7, 1, 1, 1)
                    elseif def.counter == "social" then
                        GameTooltip:AddDoubleLine("Friends online:", tostring(OnlineFriends()), 0.7, 0.7, 0.7, 1, 1, 1)
                    end
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                if self.letter then self.letter:SetTextColor(1, 1, 1, 0.9)
                else
                    self.tex:SetAlpha(0.85)
                    if def.custom then self.tex:SetVertexColor(1, 1, 1) end
                end
                GameTooltip:Hide()
            end)
            btn:RegisterForClicks("AnyUp")
            btn:SetScript("OnClick", function(_, mouseButton)
                if mouseButton == "LeftButton" then Try(def.click) end
            end)
            buttons[i] = btn
        end

        local function UpdateCounts()
            for _, btn in ipairs(buttons) do
                if btn.count and btn.counterFn then
                    local ok, value, color = pcall(btn.counterFn)
                    if ok and value then
                        color = color or COUNT_COLOR
                        btn.count:SetTextColor(color[1], color[2], color[3], 1)
                        btn.count:SetText(value)
                    else
                        btn.count:SetText("")
                    end
                end
            end
        end
        frame.Update = UpdateCounts

        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "FRIENDLIST_UPDATE",
                             "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
                             "WEEKLY_REWARDS_UPDATE", "CHALLENGE_MODE_COMPLETED", "ENCOUNTER_END", "UPDATE_INSTANCE_INFO" }) do
            frame:RegisterEvent(e)
        end
        frame:SetScript("OnEvent", UpdateCounts)

        -- ask for fresh data once (guild roster / friends), then the events keep the numbers current
        if C_GuildInfo and C_GuildInfo.GuildRoster and IsInGuild and IsInGuild() then pcall(C_GuildInfo.GuildRoster) end
        if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
        if C_WeeklyRewards and C_WeeklyRewards.OnUIInteract then pcall(C_WeeklyRewards.OnUIInteract) end
        UpdateCounts()

        frame.buttons = buttons
        return frame
    end,

    OnDisable = function(frame)
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
    end,
})

---------------------------------------------------------------------------
-- 2) DIFFICULTY
---------------------------------------------------------------------------
Datatexts:Register("difficulty", {
    displayName = "Difficulty",
    category = "Character",
    description = "Current instance difficulty (with keystone level) or your dungeon difficulty setting",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        local text = EnsureText(slotFrame)

        local function CurrentLabel()
            local _, instanceType, _, difficultyName = GetInstanceInfo()
            local inInstance = instanceType == "party" or instanceType == "raid" or instanceType == "scenario"
            local label
            if inInstance and difficultyName and difficultyName ~= "" and not issecretvalue(difficultyName) then
                label = difficultyName
                if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
                    local ok, level = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
                    if ok and type(level) == "number" and not issecretvalue(level) and level > 0 then
                        label = "Mythic +" .. level
                    end
                end
            else
                local id = GetDungeonDifficultyID and GetDungeonDifficultyID()
                if id and GetDifficultyInfo then label = GetDifficultyInfo(id) end
            end
            return label, inInstance
        end

        local function Update()
            local label, inInstance = CurrentLabel()
            if not label or label == "" then text:SetText("") return end
            local r, g, b = GetValueColor()
            if inInstance then
                text:SetFormattedText("|cff%02x%02x%02x%s|r", r, g, b, label:upper())
            else
                text:SetText(label:upper())
            end
        end
        frame.Update = Update

        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
        frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        frame:RegisterEvent("CHALLENGE_MODE_START")
        frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        frame:RegisterEvent("CHALLENGE_MODE_RESET")
        frame:RegisterEvent("UPDATE_INSTANCE_INFO")
        frame:SetScript("OnEvent", Update)

        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Difficulty", 1, 1, 1)
            GameTooltip:AddLine(" ")
            local dungeon = GetDungeonDifficultyID and GetDifficultyInfo and GetDifficultyInfo(GetDungeonDifficultyID())
            local raid = GetRaidDifficultyID and GetDifficultyInfo and GetDifficultyInfo(GetRaidDifficultyID())
            if dungeon then GameTooltip:AddDoubleLine("Dungeon:", dungeon, 0.7, 0.7, 0.7, 1, 1, 1) end
            if raid then GameTooltip:AddDoubleLine("Raid:", raid, 0.7, 0.7, 0.7, 1, 1, 1) end
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        Update()
        return frame
    end,

    OnDisable = function(frame) frame:UnregisterAllEvents() end,
})

---------------------------------------------------------------------------
-- 3) PROFESSIONS
---------------------------------------------------------------------------
local function GetPrimaryProfessions()
    local list = {}
    if not GetProfessions or not GetProfessionInfo then return list end
    local p1, p2 = GetProfessions()
    for _, idx in ipairs({ p1 or false, p2 or false }) do
        if idx then
            local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
            if name then
                list[#list + 1] = { name = name, icon = icon, rank = rank, maxRank = maxRank, skillLine = skillLine }
            end
        end
    end
    return list
end

local function OpenProfession(info)
    if not info then return end
    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill and info.skillLine then
        local ok = pcall(C_TradeSkillUI.OpenTradeSkill, info.skillLine)
        if ok then return end
    end
    if ToggleProfessionsBook then pcall(ToggleProfessionsBook) end
end

Datatexts:Register("professions", {
    displayName = "Professions",
    category = "Character",
    description = "Your primary professions. Left-click opens the first, right-click the second",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        local text = EnsureText(slotFrame)
        local cached = {}
        local DTICON = Opt(settings, "dtIconSize", 14)

        local function Update()
            cached = GetPrimaryProfessions()
            if #cached == 0 then
                text:SetText("|cff888888No Professions|r")
                return
            end
            local parts = {}
            for _, p in ipairs(cached) do
                local icon = p.icon and ("|T" .. p.icon .. ":" .. DTICON .. ":" .. DTICON .. ":0:0:64:64:5:59:5:59|t ") or ""
                parts[#parts + 1] = icon .. p.name:upper()
            end
            text:SetText(table.concat(parts, "   "))
        end
        frame.Update = Update

        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("SKILL_LINES_CHANGED")
        frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
        frame:SetScript("OnEvent", Update)

        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Professions", 1, 1, 1)
            GameTooltip:AddLine(" ")
            for _, p in ipairs(cached) do
                GameTooltip:AddDoubleLine(p.name, string.format("%d / %d", p.rank or 0, p.maxRank or 0), 1, 1, 1, 0.7, 1, 0.7)
            end
            if #cached > 0 then
                GameTooltip:AddLine(" ")
                HintLine("Left Click", cached[1].name)
                if cached[2] then HintLine("Right Click", cached[2].name) end
            end
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then OpenProfession(cached[1])
            elseif button == "RightButton" then OpenProfession(cached[2]) end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame) frame:UnregisterAllEvents() end,
})

---------------------------------------------------------------------------
-- 4) MOVEMENT SPEED
---------------------------------------------------------------------------
local BASE_SPEED = 7 -- yards per second at 100%

Datatexts:Register("speed", {
    displayName = "Movement Speed",
    category = "Character",
    description = "Your current movement speed in percent",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        local text = EnsureText(slotFrame)
        local DTICON = Opt(settings, "dtIconSize", 14)
        local ICON = "|TInterface\\Icons\\Ability_Rogue_Sprint:" .. DTICON .. ":" .. DTICON .. ":0:0:64:64:5:59:5:59|t "

        local function Speeds()
            local cur, run, flight, swim = GetUnitSpeed("player")
            if issecretvalue(cur) or type(cur) ~= "number" then return nil end
            return cur, run, flight, swim
        end

        local function Update()
            local cur, run, flight, swim = Speeds()
            local prefix = slotFrame.noLabel and "" or ICON
            if not cur then
                text:SetText(prefix .. "-")
                return
            end
            local speed = cur
            if speed <= 0 then
                if IsFlying and IsFlying() then speed = flight or run
                elseif IsSwimming and IsSwimming() then speed = swim or run
                else speed = run end
            end
            local r, g, b = GetValueColor()
            text:SetFormattedText(prefix .. "|cff%02x%02x%02x%d%%|r", r, g, b, floor(((speed or 0) / BASE_SPEED) * 100 + 0.5))
        end
        frame.Update = Update

        local elapsed = 0
        frame:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed >= 0.25 then
                elapsed = 0
                Update()
            end
        end)

        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Movement Speed", 1, 1, 1)
            GameTooltip:AddLine(" ")
            local cur, run, flight, swim = Speeds()
            if cur then
                local function pct(v) return string.format("%d%%", floor(((v or 0) / BASE_SPEED) * 100 + 0.5)) end
                GameTooltip:AddDoubleLine("Current:", pct(cur), 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine("Run:", pct(run), 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine("Flight:", pct(flight), 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine("Swim:", pct(swim), 0.7, 0.7, 0.7, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        Update()
        return frame
    end,

    OnDisable = function(frame) frame:SetScript("OnUpdate", nil) end,
})

---------------------------------------------------------------------------
-- 5) LOCATION
---------------------------------------------------------------------------
local PVP_COLORS = {
    sanctuary = { 0.41, 0.8, 0.94 },
    friendly  = { 0.1, 1, 0.1 },
    hostile   = { 1, 0.1, 0.1 },
    contested = { 1, 0.7, 0 },
    arena     = { 1, 0.1, 0.1 },
    combat    = { 1, 0.1, 0.1 },
}

Datatexts:Register("location", {
    displayName = "Location",
    category = "Character",
    description = "Current sub-zone or zone name, colored by PvP status. Click opens the world map",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        local text = EnsureText(slotFrame)

        local function Update()
            local zone = GetZoneText() or ""
            local sub = GetSubZoneText() or ""
            local name = (sub ~= "" and sub) or zone
            if name == "" then text:SetText("") return end
            local pvpType = C_PvP.GetZonePVPInfo and C_PvP.GetZonePVPInfo()
            local c = (pvpType and PVP_COLORS[pvpType]) or { 1, 0.93, 0.76 }
            text:SetFormattedText("|cff%02x%02x%02x%s|r", floor(c[1] * 255), floor(c[2] * 255), floor(c[3] * 255), name:upper())
        end
        frame.Update = Update

        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("ZONE_CHANGED")
        frame:RegisterEvent("ZONE_CHANGED_INDOORS")
        frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        frame:SetScript("OnEvent", Update)

        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            local zone = GetZoneText() or ""
            local sub = GetSubZoneText() or ""
            GameTooltip:AddLine(zone, 1, 1, 1)
            if sub ~= "" and sub ~= zone then GameTooltip:AddLine(sub, 0.7, 0.7, 0.7) end
            GameTooltip:AddLine(" ")
            HintLine("Left Click", "World Map")
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then Try(ToggleWorldMap) end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame) frame:UnregisterAllEvents() end,
})

---------------------------------------------------------------------------
-- 6) BLANK (empty slot that draws nothing)
---------------------------------------------------------------------------
Datatexts:Register("blank", {
    displayName = "(Blank)",
    category = "System",
    description = "An empty slot that shows nothing",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        EnsureText(slotFrame):SetText("")
        frame.Update = function() end
        return frame
    end,

    OnDisable = function(frame) end,
})

---------------------------------------------------------------------------
-- 7) CLOCK (large, for the middle of the Bottom Bar)
---------------------------------------------------------------------------
Datatexts:Register("clock", {
    displayName = "Clock (Large)",
    category = "System",
    description = "A larger, centered clock with a resting indicator. Uses the local/server and 12/24h time settings",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        local text = EnsureText(slotFrame)

        local path, size, flags = text:GetFont()
        local h = slotFrame:GetHeight() or 22
        local big = Opt(settings, "clockFontSize", math.max(10, math.min((size or 12) + 6, h - 4)))
        -- outlined + larger so the time stays readable on any background
        if path then pcall(text.SetFont, text, path, big, "OUTLINE") end

        local REST = " |TInterface\\CharacterFrame\\UI-StateIcon:" .. Opt(settings, "dtIconSize", 14) .. ":" .. Opt(settings, "dtIconSize", 14) .. ":0:0:64:64:0:31:0:31|t"

        local function Settings()
            local addon = ns and ns.Addon
            local dt = addon and addon.db and addon.db.profile and addon.db.profile.datatext
            local useLocal = (not dt) or (dt.timeFormat == "local")
            local use24 = (not dt) or (dt.use24Hour ~= false)
            return useLocal, use24
        end

        local function Update()
            local useLocal, use24 = Settings()
            local hour, minute
            if useLocal then hour, minute = tonumber(date("%H")), tonumber(date("%M"))
            else hour, minute = GetGameTime() end
            local r, g, b = GetValueColor()
            local rest = (IsResting and IsResting()) and REST or ""
            if use24 then
                text:SetFormattedText("|cffffffff%02d|r|cff%02x%02x%02x:|r|cffffffff%02d|r%s", hour, r, g, b, minute, rest)
            else
                local suffix = hour >= 12 and "PM" or "AM"
                local h12 = hour % 12
                if h12 == 0 then h12 = 12 end
                text:SetFormattedText("|cffffffff%d|r|cff%02x%02x%02x:|r|cffffffff%02d|r |cff%02x%02x%02x%s|r%s", h12, r, g, b, minute, r, g, b, suffix, rest)
            end
        end
        frame.Update = Update

        local elapsed = 0
        frame:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed >= 1 then elapsed = 0 Update() end
        end)
        frame:RegisterEvent("PLAYER_UPDATE_RESTING")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:SetScript("OnEvent", Update)

        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Time", 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Local:", date("%H:%M"), 0.7, 0.7, 0.7, 1, 1, 1)
            local sh, sm = GetGameTime()
            GameTooltip:AddDoubleLine("Realm:", string.format("%02d:%02d", sh, sm), 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddLine(" ")
            HintLine("Left Click", "Calendar")
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then
                Try(ToggleCalendar or Calendar_Toggle)
            end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame)
        frame:UnregisterAllEvents()
        frame:SetScript("OnUpdate", nil)
    end,
})

---------------------------------------------------------------------------
-- 8) GREAT VAULT
---------------------------------------------------------------------------
Datatexts:Register("vault", {
    displayName = "Great Vault",
    category = "Character",
    description = "Great Vault progress: unlocked slots out of 9 (Raid, Dungeons, World). Shows when rewards can be claimed. Click to open the Vault",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        local text = EnsureText(slotFrame)
        local DTICON = Opt(settings, "dtIconSize", 14)
        local ICON = "|T" .. MENU_ICON_PATH .. "vault:" .. DTICON .. ":" .. DTICON .. ":0:0|t "

        local function Update()
            local v = ReadVault()
            local prefix = slotFrame.noLabel and "" or ICON
            if v.claimable then
                text:SetText(prefix .. "|cff33ff33Claim!|r")
            elseif v.total == 0 then
                text:SetText(prefix .. "|cff9d9d9d-|r")
            else
                local r, g, b = GetValueColor()
                local color = v.unlocked == 0 and "ff9d9d9d" or string.format("ff%02x%02x%02x", r, g, b)
                text:SetFormattedText("%s|c%s%d/%d|r", prefix, color, v.unlocked, v.total)
            end
        end
        frame.Update = Update

        for _, e in ipairs({ "WEEKLY_REWARDS_UPDATE", "PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_COMPLETED",
                             "ENCOUNTER_END", "UPDATE_INSTANCE_INFO", "PLAYER_REGEN_ENABLED" }) do
            frame:RegisterEvent(e)
        end
        frame:SetScript("OnEvent", Update)

        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            FillVaultTooltip(ReadVault())
            GameTooltip:AddLine(" ")
            HintLine("Left Click", "Open Great Vault")
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then OpenVault() end
        end)

        -- ask the server for fresh vault data now and then (needed after login)
        if C_WeeklyRewards and C_WeeklyRewards.OnUIInteract then pcall(C_WeeklyRewards.OnUIInteract) end
        Update()
        return frame
    end,

    OnDisable = function(frame) frame:UnregisterAllEvents() end,
})

---------------------------------------------------------------------------
-- Bottom Bar preset (shared by the datatext tab and the Bottom Bar tab)
---------------------------------------------------------------------------
ns.BottomBarPreset = function()
    -- Slot widths are weighted so the clock (slot 3) sits exactly in the middle:
    -- left side 2.3 + 1.5 = 3.8 (wider menu: it has 11 icons), clock 1.0, right side 1.5 + 1.0 + 0.6 + 0.7 = 3.8
    return {
        id = "bottombar",
        name = "Bottom Bar",
        layoutVersion = 4,
        enabled = true,
        locked = false,
        numSlots = 7,
        fullWidth = true,
        width = math.floor(UIParent:GetWidth() or 1920),
        height = 26,
        bgOpacity = 60,
        borderSize = 0,
        borderColor = {0, 0, 0, 1},
        accentLine = true,
        hideBlizzardMenus = true,
        fontSize = 12,
        position = {"BOTTOM", "BOTTOM", 0, 0},
        slots = {"micromenu", "playerspec", "clock", "professions", "gold", "bags", "location"},
        slotWeights = {2.3, 1.5, 1.0, 1.5, 1.0, 0.6, 0.7},
        slotSettings = {
            [5] = {noLabel = true},
            [6] = {noLabel = true},
        },
    }
end
