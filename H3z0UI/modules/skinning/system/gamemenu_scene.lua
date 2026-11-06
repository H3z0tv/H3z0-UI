local _, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI - Game Menu scene
-- While the Esc menu is open, around it:
--   * left:   your character as it looks right now (shapeshift form too),
--             doing a random emote (dance, cheer, wave, flex, ...) every few seconds
--   * right:  a random pet from your collection
--   * top:    the crest of the class you are playing, in a class coloured ring
--   * top left: a random WoW fact; bottom left: this version's patch notes
--   * bottom right: your last 5 Mythic+ keys
--   * bottom: the H3z0 UI logo
-- The menu itself keeps its look. Switch: Appearance > Skinning > Game Menu >
-- Character & Pet Scene.
---------------------------------------------------------------------------

local Helpers = ns.Helpers

local ASSETS = "Interface\\AddOns\\H3z0UI\\assets\\"
local LOGO = ASSETS .. "h3z0ui_logo_bg.png"

-- character animations: dance, cheer, wave, flex, laugh, roar, applaud, salute, bow, talk
local EMOTES = { 69, 68, 67, 82, 70, 74, 80, 113, 66, 60, 69, 69 }
local EMOTE_TIME = 6

-- symmetric layout around the menu: character and pet in boxes of the same
-- size, the same distance left / right of the menu, centred on it
local MODEL_W, MODEL_H = 360, 420
local SIDE_GAP = 150          -- from the menu edge to the model box
local CREST, CREST_LIFT = 128, 36      -- a little above the middle of the top band
local LOGO_W, LOGO_H, LOGO_LIFT = 140, 70, 25
local BAND_ALPHA = 0.62
local BAND_TOP_OVER = 50      -- the top band ends this far above the menu
local BAND_BOTTOM_UNDER = 10  -- the bottom band starts this far below the menu

local FACTS = {
    "World of Warcraft launched on November 23, 2004. Warcraft: Orcs & Humans came out ten years earlier, in 1994.",
    "The first expansion, The Burning Crusade, arrived in January 2007 and added flying mounts, the Blood Elves and the Draenei.",
    "Wrath of the Lich King introduced the Death Knight, the first hero class. It started at level 55 in the Eastern Plague Lands.",
    "The Demon Hunter joined in Legion and started at level 98. The Evoker, with the Dracthyr race, followed in Dragonflight.",
    "The level cap went 60, 70, 80, 85, 90, 100, 110, 120, then the level squish brought it back to 60 in Shadowlands. It is 90 in Midnight.",
    "In September 2005 the Corrupted Blood debuff from Zul'Gurub escaped into the cities through hunter pets and spread like a plague.",
    "Mythic+ was born in Legion. Finish a key in time and it goes up one level, two if you are 20 percent faster, three if you are 40 percent faster.",
    "Every death in a Mythic+ run adds 5 seconds to your timer.",
    "Dalaran has moved twice: from Alterac Mountains to Northrend in Wrath, then to the Broken Isles in Legion.",
    "The Dark Portal in the Blasted Lands leads to Outland, the broken remains of the orc homeworld Draenor.",
    "Night elves turn into a wisp when they die, and wisps are what the old Warcraft games called their gatherers.",
    "Polymorph does not only make sheep. Mages can turn you into a pig, cat, turtle, rabbit, penguin, polar bear cub, monkey, peacock or bumblebee.",
    "Pandaren first showed up in Warcraft III, years before Mists of Pandaria gave them a whole continent.",
    "Cataclysm in 2010 did something no other expansion did: it rebuilt Azeroth itself, the Barrens, Azshara and Thousand Needles included.",
    "Timewalking scales old dungeons and raids to your level, so you can run the classics for current gear.",
    "Gnomeregan fell when the gnomes irradiated their own city to stop the troggs. The survivors still live in Ironforge.",
    "The gold cap is 99,999,999 gold, 99 silver and 99 copper.",
    "Molten Core, the first raid, needed 40 players. Ragnaros waited at the end.",
    "Typing /dance makes you dance, and almost every race has its own dance.",
    "The Warcraft movie came out in June 2016, the same year as Legion.",
    "Shadowlands launched on the 16th anniversary of World of Warcraft, November 23, 2020.",
    "Classic servers opened on August 26, 2019, the same day of the year as The War Within five years later.",
    "Hogger, the gnoll in Elwynn Forest, is the most famous first elite in the game. Everybody remembers the first time they met him.",
    "Heroism, Bloodlust and Time Warp all give about 30 percent haste. Remember to hold them for a boss kill, not a trash pack.",
    "A battle resurrection is shared by the whole group in dungeons and raids. Do not waste it on a trash death.",
}

local function Settings()
    local core = Helpers.GetCore and Helpers.GetCore()
    return core and core.db and core.db.profile and core.db.profile.general
end

local function On()
    local g = Settings()
    return g and g.gameMenuScene ~= false
end

local scene

local function ClassColor()
    local _, class = UnitClass("player")
    local c = class and (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
        or (RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class])
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Build()
    if scene then return scene end
    local f = CreateFrame("Frame", "H3z0UI_GameMenuScene", UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(1)
    f:EnableMouse(false)
    f:Hide()

    -- cinematic bands: dark top and bottom, the middle (menu, character, pet) stays clear
    f.bandTop = f:CreateTexture(nil, "BACKGROUND")
    f.bandTop:SetColorTexture(0, 0, 0, BAND_ALPHA)
    f.bandBottom = f:CreateTexture(nil, "BACKGROUND")
    f.bandBottom:SetColorTexture(0, 0, 0, BAND_ALPHA)
    f.lineTop = f:CreateTexture(nil, "BORDER")
    f.lineTop:SetColorTexture(1, 1, 1, 0.14)
    f.lineTop:SetHeight(1)
    f.lineBottom = f:CreateTexture(nil, "BORDER")
    f.lineBottom:SetColorTexture(1, 1, 1, 0.14)
    f.lineBottom:SetHeight(1)

    -- your character
    local char = CreateFrame("PlayerModel", nil, f)
    char:SetSize(MODEL_W, MODEL_H)
    f.char = char

    -- a random pet
    local pet = CreateFrame("PlayerModel", nil, f)
    pet:SetSize(MODEL_W, MODEL_H)
    f.pet = pet

    -- class crest on top
    local crest = CreateFrame("Frame", nil, f)
    crest:SetSize(CREST, CREST)
    f.crest = crest
    -- class crests (assets\classcrest, Midnight Edition)
    crest.icon = crest:CreateTexture(nil, "ARTWORK")
    crest.icon:SetAllPoints()
    -- class name (class colour) and specialization under the crest
    local font = (Helpers.GetGeneralFont and Helpers.GetGeneralFont()) or STANDARD_TEXT_FONT
    crest.class = crest:CreateFontString(nil, "OVERLAY")
    crest.class:SetFont(font, 22, "OUTLINE")
    crest.class:SetPoint("TOP", crest, "BOTTOM", 0, -8)
    crest.spec = crest:CreateFontString(nil, "OVERLAY")
    crest.spec:SetFont(font, 15, "OUTLINE")
    crest.spec:SetPoint("TOP", crest.class, "BOTTOM", 0, -3)
    crest.spec:SetTextColor(0.9, 0.9, 0.9, 1)
    -- item level under the specialization
    crest.ilvl = crest:CreateFontString(nil, "OVERLAY")
    crest.ilvl:SetFont(font, 14, "OUTLINE")
    crest.ilvl:SetTextColor(1, 0.82, 0.2, 1)

    -- last 5 Mythic+ keys of the season, bottom right
    local keys = CreateFrame("Frame", nil, f)
    keys:SetSize(380, 230)   -- same height as the patch notes box: both titles on one line
    keys.title = keys:CreateFontString(nil, "OVERLAY")
    keys.title:SetFont(font, 22, "OUTLINE")
    keys.title:SetPoint("TOPRIGHT", keys, "TOPRIGHT", 0, 0)
    keys.title:SetJustifyH("RIGHT")
    keys.title:SetTextColor(1, 0.82, 0.2, 1)
    keys.title:SetText("Last Keys")
    keys.lines = {}
    for i = 1, 5 do
        local fs = keys:CreateFontString(nil, "OVERLAY")
        fs:SetFont(font, 17, "OUTLINE")
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("TOPRIGHT", i == 1 and keys.title or keys.lines[i - 1], "BOTTOMRIGHT", 0, i == 1 and -8 or -4)
        keys.lines[i] = fs
    end
    f.keys = keys

    -- random WoW fact, top left
    local fact = CreateFrame("Frame", nil, f)
    fact:SetSize(720, 150)
    fact.title = fact:CreateFontString(nil, "OVERLAY")
    fact.title:SetFont(font, 20, "OUTLINE")
    fact.title:SetPoint("TOPLEFT", fact, "TOPLEFT", 0, 0)
    fact.title:SetTextColor(1, 0.82, 0.2, 1)
    fact.title:SetText("Did you know?")
    fact.text = fact:CreateFontString(nil, "OVERLAY")
    fact.text:SetFont(font, 17, "OUTLINE")
    fact.text:SetPoint("TOPLEFT", fact.title, "BOTTOMLEFT", 0, -10)
    fact.text:SetWidth(700)
    fact.text:SetJustifyH("LEFT")
    fact.text:SetJustifyV("TOP")
    fact.text:SetTextColor(0.92, 0.92, 0.92, 1)
    f.fact = fact

    -- patch notes of this version, bottom left
    local pn = CreateFrame("Frame", nil, f)
    pn:SetSize(700, 230)
    pn.title = pn:CreateFontString(nil, "OVERLAY")
    pn.title:SetFont(font, 20, "OUTLINE")
    pn.title:SetPoint("TOPLEFT", pn, "TOPLEFT", 0, 0)
    pn.title:SetTextColor(1, 0.82, 0.2, 1)
    pn.lines = {}
    for i = 1, 9 do
        local fs = pn:CreateFontString(nil, "OVERLAY")
        fs:SetFont(font, 15, "OUTLINE")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetWidth(690)
        fs:SetPoint("TOPLEFT", i == 1 and pn.title or pn.lines[i - 1], "BOTTOMLEFT", 0, i == 1 and -10 or -5)
        pn.lines[i] = fs
    end
    f.notes = pn

    -- "H3z0 UI <version>" under the logo
    f.version = f:CreateFontString(nil, "OVERLAY")
    f.version:SetFont(font, 20, "OUTLINE")
    f.version:SetTextColor(0.85, 0.85, 0.85, 1)

    -- logo at the bottom
    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(LOGO)
    logo:SetSize(LOGO_W, LOGO_H)
    f.logo = logo

    scene = f
    return f
end

-- everything follows the menu window
local function Place(f)
    local menu = _G.GameMenuFrame
    f.char:ClearAllPoints()
    f.pet:ClearAllPoints()
    f.crest:ClearAllPoints()
    f.logo:ClearAllPoints()
    for _, t in ipairs({ f.bandTop, f.bandBottom, f.lineTop, f.lineBottom }) do t:ClearAllPoints() end
    f.bandTop:SetPoint("TOPLEFT", f, "TOPLEFT")
    f.bandTop:SetPoint("TOPRIGHT", f, "TOPRIGHT")
    f.bandBottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
    f.bandBottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
    if menu then
        f.bandTop:SetPoint("BOTTOM", menu, "TOP", 0, BAND_TOP_OVER)
        f.bandBottom:SetPoint("TOP", menu, "BOTTOM", 0, -BAND_BOTTOM_UNDER)
    else
        f.bandTop:SetHeight(220)
        f.bandBottom:SetHeight(220)
    end
    f.lineTop:SetPoint("TOPLEFT", f.bandTop, "BOTTOMLEFT")
    f.lineTop:SetPoint("TOPRIGHT", f.bandTop, "BOTTOMRIGHT")
    f.lineBottom:SetPoint("BOTTOMLEFT", f.bandBottom, "TOPLEFT")
    f.lineBottom:SetPoint("BOTTOMRIGHT", f.bandBottom, "TOPRIGHT")
    if menu then
        f.char:SetPoint("RIGHT", menu, "LEFT", -SIDE_GAP, 0)
        f.pet:SetPoint("LEFT", menu, "RIGHT", SIDE_GAP, 0)
        -- crest in the middle of the dark top band, logo in the middle of the bottom band
        f.crest:SetPoint("CENTER", f.bandTop, "CENTER", 0, CREST_LIFT)
        f.logo:SetPoint("CENTER", f.bandBottom, "CENTER", 0, LOGO_LIFT)
        f.keys:ClearAllPoints()
        f.keys:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -60, 75)
        f.fact:ClearAllPoints()
        f.fact:SetPoint("TOPLEFT", f, "TOPLEFT", 80, -70)
        f.notes:ClearAllPoints()
        f.notes:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 60, 75)
    else
        f.char:SetPoint("RIGHT", f, "CENTER", -300, 0)
        f.pet:SetPoint("LEFT", f, "CENTER", 300, 0)
        f.crest:SetPoint("TOP", f, "TOP", 0, -60)
        f.logo:SetPoint("BOTTOM", f, "BOTTOM", 0, 60)
        f.keys:ClearAllPoints()
        f.keys:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -60, 75)
        f.fact:ClearAllPoints()
        f.fact:SetPoint("TOPLEFT", f, "TOPLEFT", 80, -70)
        f.notes:ClearAllPoints()
        f.notes:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 60, 75)
    end
end

local ALT_CREST = { DEATHKNIGHT = true, SHAMAN = true, MONK = true }

local function Crest(f)
    local _, class = UnitClass("player")
    local r, g, b = ClassColor()
    -- Death Knight, Shaman and Monk have two crests: one of them at random
    local file = class
    if class and ALT_CREST[class] and math.random(2) == 2 then file = class .. "_2" end
    f.crest.icon:SetTexture(file and (ASSETS .. "classcrest\\" .. file) or 134400)
    local className = UnitClass("player")
    f.crest.class:SetText(className or "")
    f.crest.class:SetTextColor(r, g, b, 1)
    local specName
    local GetSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local GetInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if GetSpec and GetInfo then
        local ok, idx = pcall(GetSpec)
        if ok and idx then
            local ok2, _, name = pcall(GetInfo, idx)
            if ok2 then specName = name end
        end
    end
    f.crest.spec:SetText(specName or "")
    f.crest.spec:SetShown(specName ~= nil and specName ~= "")

    -- item level (equipped), under the spec (or the class name without a spec)
    f.crest.ilvl:ClearAllPoints()
    f.crest.ilvl:SetPoint("TOP", f.crest.spec:IsShown() and f.crest.spec or f.crest.class, "BOTTOM", 0, -3)
    local _, equipped = GetAverageItemLevel and GetAverageItemLevel()
    if equipped and equipped > 0 then
        f.crest.ilvl:SetFormattedText("Item Level %.1f", equipped)
        f.crest.ilvl:Show()
    else
        f.crest.ilvl:Hide()
    end
end

-- the last 5 Mythic+ runs of the season, newest first
local function KeyColor(level)
    if level >= 12 then return 1, 0.5, 0 end
    if level >= 10 then return 0.64, 0.21, 0.93 end
    if level >= 7 then return 0, 0.44, 0.87 end
    return 0.12, 1, 0
end

local function LastKeys(f)
    local keys = f.keys
    local runs
    if C_MythicPlus and C_MythicPlus.GetRunHistory then
        local ok, list = pcall(C_MythicPlus.GetRunHistory, true, true)
        if ok and type(list) == "table" then runs = list end
    end
    if not runs or #runs == 0 then
        keys:Hide()
        return
    end
    keys:Show()
    local n = 0
    for i = #runs, 1, -1 do
        n = n + 1
        if n > 5 then break end
        local run = runs[i]
        local name = run.mapChallengeModeID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
            and C_ChallengeMode.GetMapUIInfo(run.mapChallengeModeID) or "?"
        local level = run.level or 0
        local r, g, b = KeyColor(level)
        local timed = run.completed and "|cff40ff40in time|r" or "|cffff5050over time|r"
        keys.lines[n]:SetFormattedText("|cff%02x%02x%02x+%d|r  %s  %s",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), level, name, timed)
        keys.lines[n]:Show()
    end
    for i = n + 1, 5 do keys.lines[i]:Hide() end
end

local lastFact
local function RandomFact(f)
    local n = #FACTS
    if n == 0 then f.fact:Hide() return end
    local i = math.random(n)
    if n > 1 and i == lastFact then i = i % n + 1 end
    lastFact = i
    f.fact.text:SetText(FACTS[i])
    f.fact:Show()
end

-- first sentence of a patch note line, cut to fit one row
local function Headline(text)
    local first = text:match("^(.-[%.%!%?])%s") or text
    if #first > 95 then first = first:sub(1, 92):gsub("%s+%S*$", "") .. "..." end
    return first
end

local SECTION_COLOR = { New = "ff40ff40", Fixed = "ff4db8ff", Changed = "ffffd100", Removed = "ffff6060" }
local function PatchNotes(f)
    local pn = f.notes
    local data = _G.H3z0UI_WhatsNew
    if type(data) ~= "table" or type(data.sections) ~= "table" then pn:Hide() return end
    pn.title:SetText("Patch Notes  " .. tostring(data.version or ""))
    local n = 0
    local show = _G.H3z0UI_WhatsNewShowSection
    for _, sec in ipairs(data.sections) do
        local items = sec.items or {}
        if #items > 0 and n < 9 and (not show or show(sec)) then
            n = n + 1
            local col = SECTION_COLOR[sec.title] or SECTION_COLOR.New or "ffffffff"
            pn.lines[n]:SetText("|c" .. col .. tostring(sec.title) .. "|r")
            for _, it in ipairs(items) do
                if n >= 9 then break end
                n = n + 1
                pn.lines[n]:SetText("|cffbbbbbb-|r " .. Headline(it))
            end
        end
    end
    for i = 1, 9 do pn.lines[i]:SetShown(i <= n) end
    pn:Show()
end

local function VersionText(f)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local v = get and get("H3z0UI", "Version") or ""
    f.version:ClearAllPoints()
    f.version:SetPoint("TOP", f.logo, "BOTTOM", 0, -45)
    f.version:SetText("H3z0 UI " .. (v or ""))
end

local function RandomPetDisplay()
    local PJ = C_PetJournal
    if not (PJ and PJ.GetOwnedPetIDs and PJ.GetPetInfoByPetID) then return nil end
    local ok, ids = pcall(PJ.GetOwnedPetIDs)
    if not ok or type(ids) ~= "table" or #ids == 0 then return nil end
    for _ = 1, 8 do
        local id = ids[math.random(#ids)]
        local info = { pcall(PJ.GetPetInfoByPetID, id) }
        local displayID = info[1] and info[7]      -- speciesID, name, level, xp, maxXp, displayID, ...
        if type(displayID) == "number" and displayID > 0 then return displayID end
    end
    return nil
end

local emoteTimer = 0
local function NextEmote(f)
    if not f.char:IsShown() then return end
    pcall(f.char.SetAnimation, f.char, EMOTES[math.random(#EMOTES)])
end

local function OnUpdate(f, elapsed)
    emoteTimer = emoteTimer + elapsed
    if emoteTimer >= EMOTE_TIME then
        emoteTimer = 0
        NextEmote(f)
    end
    -- soft fade in
    local a = f:GetAlpha()
    if a < 1 then f:SetAlpha(math.min(1, a + elapsed * 3)) end
end

local function Show()
    if not On() then return end
    local f = Build()
    local menu = _G.GameMenuFrame
    if menu then f:SetFrameLevel(math.max(1, (menu:GetFrameLevel() or 2) - 1)) end
    Place(f)
    Crest(f)
    pcall(LastKeys, f)
    RandomFact(f)
    pcall(PatchNotes, f)
    VersionText(f)

    f.char:ClearModel()
    f.char:SetUnit("player")
    f.char:SetFacing(0.5)
    f.char:SetCamDistanceScale(1.1)
    f.char:Show()

    local displayID = RandomPetDisplay()
    if displayID then
        f.pet:ClearModel()
        f.pet:SetDisplayInfo(displayID)
        f.pet:SetFacing(-0.5)
        f.pet:SetCamDistanceScale(1.1)
        f.pet:Show()
    else
        f.pet:Hide()
    end

    emoteTimer = 0
    f:SetAlpha(0)
    f:SetScript("OnUpdate", OnUpdate)
    f:Show()
    -- the model is ready a moment later: first emote then
    C_Timer.After(0.15, function() if f:IsShown() then NextEmote(f) end end)
end

local function Hide()
    if not scene then return end
    scene:SetScript("OnUpdate", nil)
    scene:Hide()
    scene.char:ClearModel()
    scene.pet:ClearModel()
end

_G.H3z0UI_RefreshGameMenuScene = function()
    local menu = _G.GameMenuFrame
    if menu and menu:IsShown() and On() then Show() else Hide() end
end

local installed = false
local function Install()
    local menu = _G.GameMenuFrame
    if not menu then return false end
    if installed then return true end
    installed = true
    menu:HookScript("OnShow", function() Show() end)
    menu:HookScript("OnHide", function() Hide() end)
    return true
end

if not Install() then
    local w = CreateFrame("Frame")
    w:RegisterEvent("PLAYER_LOGIN")
    w:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Install()
    end)
end
