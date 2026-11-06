local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Premade Groups, your listing's applicants:
--  * sorted by Mythic+ rating, highest first
--  * a small flag next to each name for the language of the player's realm
--    (EU: German, French, Spanish, Russian, Italian, Portuguese, else English;
--    US: Brazil, Latin America, Oceania, else US)
-- Settings: profile.h3zGroupTools.sortApplicants / applicantFlags (both on).
---------------------------------------------------------------------------
if ns.Client and (ns.Client.isClassic or ns.Client.isForever) then return end

local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.h3zGroupTools = p.h3zGroupTools or {}
    local s = p.h3zGroupTools
    if s.sortApplicants == nil then s.sortApplicants = true end
    if s.applicantFlags == nil then s.applicantFlags = true end
    return s
end

local function Plain(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

---------------------------------------------------------------------------
-- realm -> flag
---------------------------------------------------------------------------
local function Key(realm)
    return (realm:lower():gsub("[%s%-'’%.]", ""))
end

local REALMS = {}
local function Add(flag, list)
    for name in list:gmatch("[^|]+") do REALMS[Key(name)] = flag end
end

-- Europe
Add("de", "Aegwynn|Alexstrasza|Alleria|Aman'Thul|Ambossar|Anetheron|Antonidas|Anub'arak|Area 52|Arthas|Arygos|Azshara|Baelgun|Blackhand|Blackmoore|Blackrock|Blutkessel|Dalvengyr|Das Konsortium|Das Syndikat|Der abyssische Rat|Der Mithrilorden|Der Rat von Dalaran|Destromath|Dethecus|Die Aldor|Die Arguswacht|Die ewige Wacht|Die Nachtwache|Die Silberne Hand|Die Todeskrallen|Dun Morogh|Durotan|Echsenkessel|Eredar|Festung der Stürme|Forscherliga|Frostmourne|Frostwolf|Garrosh|Gilneas|Gorgonnash|Gul'dan|Kargath|Kel'Thuzad|Khaz'goroth|Kil'jaeden|Krag'jin|Kult der Verdammten|Lordaeron|Lothar|Madmortem|Mal'Ganis|Malfurion|Malorne|Malygos|Mannoroth|Mug'thol|Nathrezim|Nazjatar|Nefarian|Nera'thor|Nethersturm|Norgannon|Nozdormu|Onyxia|Perenolde|Proudmoore|Rajaxx|Rexxar|Sen'jin|Shattrath|Taerar|Teldrassil|Terrordar|Theradras|Thrall|Tichondrius|Tirion|Todeswache|Ulduar|Un'Goro|Vek'lor|Wrathbringer|Ysera|Zirkel des Cenarius|Zuluhed")
Add("fr", "Arak-arahm|Arathi|Archimonde|Chants éternels|Cho'gall|Confrérie du Thorium|Conseil des Ombres|Culte de la Rive noire|Dalaran|Drek'Thar|Eitrigg|Eldre'Thalas|Elune|Garona|Hyjal|Illidan|Kael'thas|Khaz Modan|Kirin Tor|Krasus|La Croisade écarlate|Les Clairvoyants|Les Sentinelles|Marécage de Zangar|Medivh|Naxxramas|Ner'zhul|Rashgarroth|Sargeras|Sinstralis|Suramar|Temple noir|Throk'Feroth|Uldaman|Varimathras|Vol'jin|Ysondre")
Add("es", "C'Thun|Colinas Pardas|Dun Modr|Exodar|Los Errantes|Minahonda|Sanguino|Shen'dralar|Tyrande|Uldum|Zul'jin")
Add("ru", "Азурегос|Борейская тундра|Вечная Песня|Галакронд|Гордунни|Гром|Дракономор|Король-лич|Пиратская бухта|Подземье|Разувий|Ревущий фьорд|Свежеватель Душ|Седогрив|Страж Смерти|Термоштепсель|Ткач Смерти|Черный Шрам|Ясеневый лес|Azuregos|Borean Tundra|Eversong|Galakrond|Goldrinn|Gordunni|Grom|Fordragon|Howling Fjord|Lich King|Deathguard|Deathweaver|Razuvious|Soulflayer|Thermaplugg|Blackscar|Ashenvale|Booty Bay|Greymane")
Add("it", "Nemesis|Pozzo dell'Eternità")
Add("pt", "Aggra (Português)|Aggra")

-- Americas / Oceania (US region)
local US = {}
local function AddUS(flag, list)
    for name in list:gmatch("[^|]+") do US[Key(name)] = flag end
end
AddUS("br", "Azralon|Gallywix|Goldrinn|Nemesis|Tol Barad")
AddUS("mx", "Drakkari|Quel'Thalas|Ragnaros")
AddUS("au", "Aman'Thul|Barthilas|Caelestrasz|Dath'Remar|Dreadmaul|Frostmourne|Gundrak|Jubei'Thos|Khaz'goroth|Nagrand|Saurfang|Thaurissan")

local FLAG_NAMES = {
    de = "German", fr = "French", es = "Spanish", ru = "Russian", it = "Italian", pt = "Portuguese",
    gb = "English", us = "English (US)", br = "Brazilian", mx = "Latin American", au = "Oceanic",
}

local myRealm
local function FlagFor(fullName)
    if not fullName then return nil end
    local realm = fullName:match("%-(.+)$")
    if not realm or realm == "" then
        myRealm = myRealm or GetRealmName()
        realm = myRealm
    end
    local k = Key(realm)
    local region = GetCurrentRegion and GetCurrentRegion() or 3
    if region == 1 then return US[k] or "us" end
    if region == 3 then return REALMS[k] or "gb" end
    return nil
end

---------------------------------------------------------------------------
-- tiny flags drawn from coloured stripes (16 x 11)
---------------------------------------------------------------------------
local W, H = 16, 11
local function Stripe(f, layer, x, y, w, h, r, g, b)
    local t = f:CreateTexture(nil, "ARTWORK", nil, layer or 1)
    t:SetColorTexture(r, g, b, 1)
    t:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
    t:SetSize(w, h)
    return t
end

local DRAW = {
    de = function(f) Stripe(f, 1, 0, 0, W, 4, 0, 0, 0); Stripe(f, 1, 0, 4, W, 3, 0.87, 0, 0); Stripe(f, 1, 0, 7, W, 4, 1, 0.81, 0) end,
    fr = function(f) Stripe(f, 1, 0, 0, 5, H, 0, 0.14, 0.58); Stripe(f, 1, 5, 0, 6, H, 1, 1, 1); Stripe(f, 1, 11, 0, 5, H, 0.93, 0.16, 0.22) end,
    it = function(f) Stripe(f, 1, 0, 0, 5, H, 0, 0.57, 0.27); Stripe(f, 1, 5, 0, 6, H, 1, 1, 1); Stripe(f, 1, 11, 0, 5, H, 0.81, 0.17, 0.22) end,
    mx = function(f) Stripe(f, 1, 0, 0, 5, H, 0, 0.41, 0.28); Stripe(f, 1, 5, 0, 6, H, 1, 1, 1); Stripe(f, 1, 11, 0, 5, H, 0.81, 0.07, 0.15) end,
    ru = function(f) Stripe(f, 1, 0, 0, W, 4, 1, 1, 1); Stripe(f, 1, 0, 4, W, 3, 0, 0.22, 0.65); Stripe(f, 1, 0, 7, W, 4, 0.84, 0.17, 0.12) end,
    es = function(f) Stripe(f, 1, 0, 0, W, 3, 0.67, 0.08, 0.11); Stripe(f, 1, 0, 3, W, 5, 0.98, 0.74, 0); Stripe(f, 1, 0, 8, W, 3, 0.67, 0.08, 0.11) end,
    pt = function(f) Stripe(f, 1, 0, 0, 6, H, 0, 0.4, 0); Stripe(f, 1, 6, 0, 10, H, 1, 0, 0); Stripe(f, 2, 4, 3, 5, 5, 1, 0.9, 0) end,
    br = function(f) Stripe(f, 1, 0, 0, W, H, 0, 0.61, 0.23); Stripe(f, 2, 3, 2, 10, 7, 1, 0.87, 0); Stripe(f, 3, 6, 3, 4, 5, 0, 0.15, 0.46) end,
    gb = function(f)
        Stripe(f, 1, 0, 0, W, H, 0, 0.14, 0.49)
        Stripe(f, 2, 0, 3, W, 5, 1, 1, 1); Stripe(f, 2, 5, 0, 6, H, 1, 1, 1)
        Stripe(f, 3, 0, 4, W, 3, 0.81, 0.07, 0.15); Stripe(f, 3, 6, 0, 4, H, 0.81, 0.07, 0.15)
    end,
    au = function(f)
        Stripe(f, 1, 0, 0, W, H, 0, 0.14, 0.49)
        Stripe(f, 2, 0, 0, 8, 6, 1, 1, 1); Stripe(f, 3, 0, 2, 8, 2, 0.81, 0.07, 0.15); Stripe(f, 3, 3, 0, 2, 6, 0.81, 0.07, 0.15)
        Stripe(f, 2, 11, 6, 2, 2, 1, 1, 1)
    end,
    us = function(f)
        for i = 0, 5 do
            local red = (i % 2 == 0)
            Stripe(f, 1, 0, i * 2, W, (i == 5) and 1 or 2, red and 0.7 or 1, red and 0.13 or 1, red and 0.2 or 1)
        end
        Stripe(f, 2, 0, 0, 7, 6, 0.24, 0.23, 0.43)
    end,
}

local function FlagFrame(member)
    local f = member.h3zFlag
    if f and f.code then return f end
    f = f or CreateFrame("Frame", nil, member)
    f:SetSize(W + 2, H + 2)
    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 0.9)
    f.inner = CreateFrame("Frame", nil, f)
    f.inner:SetPoint("TOPLEFT", 1, -1)
    f.inner:SetSize(W, H)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText((FLAG_NAMES[self.code] or "") .. " realm", 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    member.h3zFlag = f
    return f
end

local function SetFlag(member, code)
    local f = member.h3zFlag
    if not code then
        if f then f:Hide() end
        return
    end
    if not f or f.code ~= code then
        if f then
            f:Hide()
            f:SetParent(nil)
            member.h3zFlag = nil
        end
        f = FlagFrame(member)
        local draw = DRAW[code]
        if draw then draw(f.inner) end
        f.code = code
    end
    -- the role icons start 104 px from the left of the row: the name is
    -- shortened so name + flag always end before them
    local rowLeft = member:GetLeft()
    local nameLeft = member.Name:GetLeft()
    local offset = (rowLeft and nameLeft) and (nameLeft - rowLeft) or 7
    local room = 100 - offset - (W + 2) - 3
    if room < 20 then room = 20 end
    member.Name:SetWordWrap(false)
    local fullW = member.Name.GetUnboundedStringWidth and member.Name:GetUnboundedStringWidth() or member.Name:GetStringWidth() or 0
    if fullW > room then
        member.Name:SetWidth(room)
    end
    local used = math.min(member.Name:GetStringWidth() or 60, room)
    f:ClearAllPoints()
    f:SetPoint("LEFT", member.Name, "LEFT", used + 3, 0)
    f:SetFrameLevel(member:GetFrameLevel() + 3)
    f:Show()
end

local function OnMember(member, appID, memberIdx)
    local s = Settings()
    if not (member and member.Name) then return end
    if not (s and s.applicantFlags) then
        if member.h3zFlag then member.h3zFlag:Hide() end
        return
    end
    local ok, name = pcall(C_LFGList.GetApplicantMemberInfo, appID, memberIdx)
    name = ok and Plain(name) or nil
    SetFlag(member, name and FlagFor(name) or nil)
end

---------------------------------------------------------------------------
-- sort: highest Mythic+ rating first
---------------------------------------------------------------------------
local function Score(appID)
    local info = C_LFGList.GetApplicantInfo(appID)
    local best = 0
    local n = info and Plain(info.numMembers) or 1
    for i = 1, (n or 1) do
        local ok, _, _, _, _, _, _, _, _, _, _, _, score = pcall(C_LFGList.GetApplicantMemberInfo, appID, i)
        score = ok and Plain(score) or 0
        if type(score) == "number" and score > best then best = score end
    end
    return best
end

local function SortApplicants(apps)
    local s = Settings()
    if not (s and s.sortApplicants) or type(apps) ~= "table" or #apps < 2 then return end
    local cache = {}
    for _, id in ipairs(apps) do cache[id] = Score(id) end
    table.sort(apps, function(a, b)
        if cache[a] ~= cache[b] then return cache[a] > cache[b] end
        return a < b
    end)
end

local hookedSort, hookedMember = false, false
local function Hook()
    if not hookedSort and type(_G.LFGListUtil_SortApplicants) == "function" then
        hookedSort = true
        hooksecurefunc("LFGListUtil_SortApplicants", SortApplicants)
    end
    if not hookedMember and type(_G.LFGListApplicationViewer_UpdateApplicantMember) == "function" then
        hookedMember = true
        hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", OnMember)
    end
    return hookedSort and hookedMember
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self)
    if Hook() then self:UnregisterAllEvents() end
end)
