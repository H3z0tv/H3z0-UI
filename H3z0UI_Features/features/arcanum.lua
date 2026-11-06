---------------------------------------------------------------------------
-- H3z0 UI - Arcanum
-- Loot and quality of life:
-- * loot toasts: items (quality coloured, item level / slot), gold, currency
--   and reputation slide in at the side of the screen; repeats stack into
--   one toast (x3, +450 gold, ...); epic and better stay longer with a sound
-- * alerts: low durability, nearly full bags, new mail, friends online /
--   offline, Great Vault rewards waiting
-- * self highlight: Blizzard's own "find yourself" outline / circle / icon
--   in combat, and when you target an enemy if you want
-- * achievement tracker: earned achievements leave your tracked list
--
-- Midnight: chat texts can be "secret" values inside restricted content.
-- Those are skipped (never matched or compared).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local issecretvalue = issecretvalue or function() return false end
local function Secret(v) return v ~= nil and issecretvalue(v) end

local Arcanum = {}
ns.H3z0Arcanum = Arcanum

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = true,
    loot = true, lootMinQuality = 0, lootMoney = true, lootCurrency = true,
    lootReputation = true, lootSound = true,
    toastSide = "RIGHT", toastGrow = "UP", offsetX = -40, offsetY = -40,
    toastWidth = 340, toastHeight = 32, toastScale = 1, toastHold = 4, maxToasts = 6,
    alertDurability = true, durabilityThreshold = 30,
    alertBags = true, bagsThreshold = 5,
    alertMail = false, alertFriends = false, alertVault = true,
    selfHighlight = false, selfHighlightMode = "outlinecircle", selfHighlightHostile = true,
    untrackAchievements = false,
}

local function DB()
    return Helpers and Helpers.GetModuleDB and Helpers.GetModuleDB("arcanum")
end

local function Get(key)
    local db = DB()
    local v = db and db[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

local function On() return Get("enabled") ~= false end
local function Want(key) return On() and Get(key) ~= false end

local function Font()
    return (Helpers and Helpers.GetGeneralFont and Helpers.GetGeneralFont()) or STANDARD_TEXT_FONT
end

local function SetFont(fs, size, flags)
    if not fs:SetFont(Font(), size, flags or "OUTLINE") then
        fs:SetFont(STANDARD_TEXT_FONT, size, flags or "OUTLINE")
    end
end

local function Colors()
    if Helpers and Helpers.GetSkinColors then
        local ar, ag, ab, _, br, bg, bb = Helpers.GetSkinColors()
        if ar then return ar, ag, ab, br or 0.07, bg or 0.08, bb or 0.1 end
    end
    return 0.2, 0.83, 0.6, 0.07, 0.08, 0.1
end

local function QualityColor(q)
    local c = q and type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

---------------------------------------------------------------------------
-- Toasts
---------------------------------------------------------------------------
local TOAST_W, TOAST_H, GAP = 340, 32, 4
local anchor
local active = {}        -- shown toasts, newest first
local pool = {}

local LAYOUT_KEY = "h3zArcanumToasts"

local function ToastWidth()
    return math.max(200, math.min(600, tonumber(Get("toastWidth")) or TOAST_W))
end

local function ToastHeight()
    return math.max(24, math.min(80, tonumber(Get("toastHeight")) or TOAST_H))
end

local function ResizeAnchor(a)
    a:SetSize(ToastWidth(), ToastHeight() * 3 + GAP * 2)
end

local function SavedPlace()
    local core = Helpers and Helpers.GetCore and Helpers.GetCore()
    local fa = core and core.db and core.db.profile and core.db.profile.frameAnchoring
    return type(fa) == "table" and fa[LAYOUT_KEY] ~= nil
end

local function Anchor()
    if anchor then return anchor end
    -- also what H3z0 UI Edit Mode moves ("Arcanum Loot Toasts")
    anchor = CreateFrame("Frame", "H3z0UI_ArcanumToasts", UIParent)
    ResizeAnchor(anchor)
    anchor:SetFrameStrata("HIGH")
    anchor:SetPoint("RIGHT", UIParent, "RIGHT", -40, -40)
    return anchor
end

-- Arcanum's own side / offsets until it is moved in H3z0 UI Edit Mode
local function PlaceAnchor()
    local a = Anchor()
    ResizeAnchor(a)
    a:SetScale(math.max(0.5, math.min(2, tonumber(Get("toastScale")) or 1)))
    if SavedPlace() then
        if _G.H3z0UI_ApplyFrameAnchor and not InCombatLockdown() then
            pcall(_G.H3z0UI_ApplyFrameAnchor, LAYOUT_KEY)
        end
        return
    end
    a:ClearAllPoints()
    local side = Get("toastSide") == "LEFT" and "LEFT" or "RIGHT"
    a:SetPoint(side, UIParent, side, tonumber(Get("offsetX")) or -40, tonumber(Get("offsetY")) or -40)
end

local function Layout()
    local up = Get("toastGrow") ~= "DOWN"
    for i, t in ipairs(active) do
        t:ClearAllPoints()
        local y = (i - 1) * (ToastHeight() + GAP)
        if up then
            t:SetPoint("BOTTOM", anchor, "BOTTOM", 0, y)
        else
            t:SetPoint("TOP", anchor, "TOP", 0, -y)
        end
    end
end

-- one slim row: dark rounded box, icon on the left, name in its quality colour
local function MakeToast()
    local t = CreateFrame("Frame", nil, Anchor())
    local width, height = ToastWidth(), ToastHeight()
    t:SetSize(width, height)
    t:EnableMouse(true)
    -- everything sits on an inner frame so the slide-in moves it all at once
    local inner = CreateFrame("Frame", nil, t)
    inner:SetSize(width, height)
    inner:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
    t.inner = inner

    local Round = ns.Round
    if Round and Round.Panel then
        local ok, panel = pcall(Round.Panel, inner, 5)
        if ok and panel then
            panel:SetAllPoints(inner)
            -- under the icon and text
            panel:SetFrameLevel(math.max(0, inner:GetFrameLevel() - 1))
            t.panel = panel
        end
    end
    if not t.panel then
        t.bg = inner:CreateTexture(nil, "BACKGROUND")
        t.bg:SetAllPoints()
    end

    t.icon = inner:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(height - 6, height - 6)
    t.icon:SetPoint("LEFT", inner, "LEFT", 3, 0)
    t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    t.name = inner:CreateFontString(nil, "OVERLAY")
    t.name:SetWordWrap(false)
    t.name:SetJustifyH("LEFT")
    t.name:SetShadowOffset(1, -1)
    t.name:SetShadowColor(0, 0, 0, 1)
    t.name:SetPoint("LEFT", t.icon, "RIGHT", 10, 0)

    t.count = inner:CreateFontString(nil, "OVERLAY")
    t.count:SetJustifyH("RIGHT")
    t.count:SetShadowOffset(1, -1)
    t.count:SetShadowColor(0, 0, 0, 1)
    t.count:SetPoint("RIGHT", inner, "RIGHT", -10, 0)
    t.name:SetPoint("RIGHT", t.count, "LEFT", -8, 0)

    t:SetScript("OnEnter", function(self)
        self.hover = true
        if self.link and not Secret(self.link) then
            GameTooltip:SetOwner(self, Get("toastSide") == "LEFT" and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
            GameTooltip:Show()
        end
    end)
    t:SetScript("OnLeave", function(self)
        self.hover = false
        GameTooltip:Hide()
    end)
    return t
end

local function Release(t)
    t:Hide()
    t:SetScript("OnUpdate", nil)
    t.key, t.link, t.amount, t.hover = nil, nil, nil, nil
    for i, x in ipairs(active) do
        if x == t then table.remove(active, i) break end
    end
    pool[#pool + 1] = t
    Layout()
end

local function ToastUpdate(t, elapsed)
    if t.hover then return end          -- stays while you read it
    t.t = t.t + elapsed
    local slide, fade = 0.25, 0.5
    local hold = t.hold
    local side = Get("toastSide") == "LEFT" and -1 or 1
    if t.t < slide then
        local p = t.t / slide
        local e = 1 - (1 - p) * (1 - p)
        t:SetAlpha(p)
        t.inner:SetPoint("TOPLEFT", t, "TOPLEFT", side * 30 * (1 - e), 0)
    elseif t.t < slide + hold then
        t:SetAlpha(1)
        t.inner:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
    elseif t.t < slide + hold + fade then
        t:SetAlpha(1 - (t.t - slide - hold) / fade)
    else
        Release(t)
    end
end

local function Paint(t, d)
    local qr, qg, qb = d.r or 1, d.g or 1, d.b or 1
    if t.panel then
        t.panel:SetFillColor(0.04, 0.045, 0.055, 0.82)
        t.panel:SetBorderColor(0.32, 0.32, 0.34, 0.55)
    else
        t.bg:SetColorTexture(0.04, 0.045, 0.055, 0.82)
    end
    t.icon:SetTexture(d.icon or 134400)
    -- name, then the extra info in grey on the same line (gold amount, ilvl, ...)
    local text = d.name or ""
    if d.sub and d.sub ~= "" and not d.hideSub then
        text = text .. "  |cff9a9a9a" .. d.sub .. "|r"
    end
    t.name:SetText(text)
    t.name:SetTextColor(qr, qg, qb, 1)
    t.count:SetText(d.countText or "")
    t.count:SetTextColor(1, 1, 1, 1)
end

local function ResizeToast(t)
    local width, height = ToastWidth(), ToastHeight()
    t:SetSize(width, height)
    t.inner:SetSize(width, height)
    t.icon:SetSize(height - 6, height - 6)
    t.icon:ClearAllPoints()
    t.icon:SetPoint("LEFT", t.inner, "LEFT", 3, 0)
end

-- d = { key, name, sub, icon, r, g, b, link, countText, shine, sound, holdBonus, merge(t, d) }
function Arcanum.Toast(d)
    if not On() then return end
    -- repeats of the same thing stack into the toast already showing
    if d.key then
        for _, t in ipairs(active) do
            if t.key == d.key then
                if d.merge then d.merge(t, d) end
                Paint(t, t.data)
                t.t = math.min(t.t, 0.25)          -- show it again in full
                return t
            end
        end
    end
    if not (ns.H3z0UI_LayoutMode and ns.H3z0UI_LayoutMode.isActive) then PlaceAnchor() end
    local t = table.remove(pool) or MakeToast()
    SetFont(t.name, 13, "")
    SetFont(t.count, 13, "")
    ResizeToast(t)
    t.key, t.link, t.data = d.key, d.link, d
    t.hold = (tonumber(Get("toastHold")) or 4) + (d.holdBonus or 0)
    t.t = 0
    Paint(t, d)
    t:SetAlpha(0)
    t:Show()
    table.insert(active, 1, t)
    local max = math.max(1, tonumber(Get("maxToasts")) or 6)
    while #active > max do Release(active[#active]) end
    Layout()
    t:SetScript("OnUpdate", ToastUpdate)
    if d.sound and Get("lootSound") ~= false and SOUNDKIT then
        PlaySound(SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.UI_LEGENDARY_LOOT_TOAST or 31578, "Master")
    end
    return t
end

---------------------------------------------------------------------------
-- Loot: items
---------------------------------------------------------------------------
local function ToPattern(g)
    if type(g) ~= "string" then return nil end
    local p = g:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    return "^" .. p .. "$"
end

local lootPatterns
local function LootPatterns()
    if lootPatterns then return lootPatterns end
    lootPatterns = {}
    -- multiple first (they are longer)
    for _, name in ipairs({
        "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF_MULTIPLE",
        "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE", "LOOT_ITEM_REFUND_MULTIPLE",
        "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF",
        "LOOT_ITEM_BONUS_ROLL_SELF", "LOOT_ITEM_REFUND",
    }) do
        local p = ToPattern(_G[name])
        if p then lootPatterns[#lootPatterns + 1] = p end
    end
    return lootPatterns
end

local function ItemSub(link, itemType, subType, equipLoc)
    local parts = {}
    if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
        local lvl = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
            or (GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link))
        if lvl and lvl > 1 then parts[#parts + 1] = "ilvl " .. lvl end
        local slot = _G[equipLoc]
        if type(slot) == "string" and slot ~= "" then parts[#parts + 1] = slot end
    end
    if #parts == 0 then
        if subType and subType ~= "" then parts[#parts + 1] = subType
        elseif itemType and itemType ~= "" then parts[#parts + 1] = itemType end
    end
    return table.concat(parts, "  ·  ")
end

local function ItemToast(link, qty, tries)
    local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, _, quality, _, _, itemType, subType, _, equipLoc, icon = GetInfo(link)
    if not name then
        tries = (tries or 0) + 1
        if tries <= 4 then C_Timer.After(0.25 * tries, function() ItemToast(link, qty, tries) end) end
        return
    end
    quality = quality or 1
    if quality < (tonumber(Get("lootMinQuality")) or 0) then return end
    local r, g, b = QualityColor(quality)
    qty = qty or 1
    Arcanum.Toast({
        key = "item:" .. link, link = link, name = name, icon = icon, r = r, g = g, b = b,
        sub = ItemSub(link, itemType, subType, equipLoc), hideSub = true,
        qty = qty, countText = qty > 1 and ("x" .. qty) or nil,
        shine = quality >= 4, sound = quality >= 4, holdBonus = quality >= 4 and 3 or 0,
        merge = function(t, d)
            t.data.qty = (t.data.qty or 1) + (d.qty or 1)
            t.data.countText = "x" .. t.data.qty
        end,
    })
end

local function OnLootMessage(msg)
    if not Want("loot") then return end
    if type(msg) ~= "string" or Secret(msg) then return end
    for _, p in ipairs(LootPatterns()) do
        local link, qty = msg:match(p)
        if link and link:find("|H") then
            ItemToast(link, tonumber(qty) or 1)
            return
        end
    end
end

---------------------------------------------------------------------------
-- Loot: gold, currency, reputation
---------------------------------------------------------------------------
local lastMoney

local function MoneyText(copper)
    local text = type(GetMoneyString) == "function" and GetMoneyString(copper, true)
    if type(text) == "string" then return text end
    return tostring(math.floor(copper / 10000)) .. "g"
end

local function BusyWithGold()
    -- selling, mail, trade and the auction house are not loot
    for _, name in ipairs({ "MerchantFrame", "MailFrame", "TradeFrame", "AuctionHouseFrame", "SendMailFrame" }) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() then return true end
    end
    return false
end

local function OnMoney()
    local now = GetMoney()
    local before = lastMoney
    lastMoney = now
    if not before or not Want("loot") or Get("lootMoney") == false then return end
    local gain = now - before
    if gain <= 0 or BusyWithGold() then return end
    Arcanum.Toast({
        key = "money", name = "Gold", icon = 133784, r = 1, g = 0.82, b = 0.2,
        amount = gain, countText = "+" .. MoneyText(gain),
        merge = function(t, d)
            t.data.amount = (t.data.amount or 0) + (d.amount or 0)
            t.data.countText = "+" .. MoneyText(t.data.amount)
        end,
    })
end

local function OnCurrency(currencyID, quantity, change)
    if not Want("loot") or Get("lootCurrency") == false then return end
    if type(currencyID) ~= "number" or type(change) ~= "number" or Secret(change) or change <= 0 then return end
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info or not info.name or info.name == "" then return end
    local r, g, b = QualityColor(info.quality or 1)
    Arcanum.Toast({
        key = "currency:" .. currencyID, name = info.name, icon = info.iconFileID, r = r, g = g, b = b,
        amount = change, countText = "+" .. change,
        sub = (type(quantity) == "number" and not Secret(quantity)) and ("Total " .. (type(BreakUpLargeNumbers) == "function" and BreakUpLargeNumbers(quantity) or tostring(quantity))) or nil,
        merge = function(t, d)
            t.data.amount = (t.data.amount or 0) + (d.amount or 0)
            t.data.countText = "+" .. t.data.amount
            t.data.sub = d.sub
        end,
    })
end

local repPatterns
local function OnFaction(msg)
    if not Want("loot") or Get("lootReputation") == false then return end
    if type(msg) ~= "string" or Secret(msg) then return end
    if not repPatterns then
        repPatterns = {}
        for _, name in ipairs({ "FACTION_STANDING_INCREASED_ACCOUNT_WIDE", "FACTION_STANDING_INCREASED" }) do
            local p = ToPattern(_G[name])
            if p then repPatterns[#repPatterns + 1] = p end
        end
    end
    for _, p in ipairs(repPatterns) do
        local faction, amount = msg:match(p)
        amount = tonumber(amount)
        if faction and amount then
            Arcanum.Toast({
                key = "rep:" .. faction, name = faction, icon = 236681, r = 0.45, g = 0.72, b = 1,
                amount = amount, countText = "+" .. amount,
                merge = function(t, d)
                    t.data.amount = (t.data.amount or 0) + (d.amount or 0)
                    t.data.countText = "+" .. t.data.amount
                end,
            })
            return
        end
    end
end

---------------------------------------------------------------------------
-- Blizzard's own loot alerts ("You received ...") step aside while Arcanum
-- shows the same thing; with Arcanum's toasts off they come back
---------------------------------------------------------------------------
local hideNext = setmetatable({}, { __mode = "k" })   -- alert frames to hide as soon as they show
local hookedSystems = {}

local function HideBlizzardAlert(frame)
    if frame and frame.Hide and frame:IsShown() then frame:Hide() end
end

local function Mark(frame)
    hideNext[frame] = true
    -- in case the container is not hooked: next frame at the latest
    C_Timer.After(0, function()
        if hideNext[frame] then hideNext[frame] = nil; HideBlizzardAlert(frame) end
    end)
end

local function HookSystem(system, decide)
    if not system or hookedSystems[system] or type(system.setUpFunction) ~= "function" then return end
    hookedSystems[system] = true
    hooksecurefunc(system, "setUpFunction", function(frame, ...)
        if decide(...) then Mark(frame) end
    end)
end

local containerHooked = false
local function HookBlizzardLoot()
    HookSystem(_G.LootAlertSystem, function(_, _, _, _, _, isCurrency)
        if not Want("loot") then return false end
        if isCurrency then return Get("lootCurrency") ~= false end
        return true
    end)
    HookSystem(_G.LootUpgradeAlertSystem, function() return Want("loot") end)
    HookSystem(_G.MoneyWonAlertSystem, function() return Want("loot") and Get("lootMoney") ~= false end)
    -- the alert is set up, then added to the container and shown: hide it right there
    local container = _G.AlertFrame
    if not containerHooked and container and type(container.AddAlertFrame) == "function" then
        containerHooked = true
        hooksecurefunc(container, "AddAlertFrame", function(_, frame)
            if not frame then return end
            local hide = hideNext[frame]
            if not hide and Want("loot") then
                -- also by the system the alert belongs to
                local q = frame.queue
                if q and q == _G.LootAlertSystem then
                    hide = (not frame.isCurrency) or Get("lootCurrency") ~= false
                elseif q and q == _G.LootUpgradeAlertSystem then
                    hide = true
                elseif q and q == _G.MoneyWonAlertSystem then
                    hide = Get("lootMoney") ~= false
                end
            end
            if hide then
                hideNext[frame] = nil
                HideBlizzardAlert(frame)
            end
        end)
    end
end

---------------------------------------------------------------------------
-- Alerts
---------------------------------------------------------------------------
local function Alert(key, name, sub, icon, r, g, b)
    local ar, ag, ab = Colors()
    Arcanum.Toast({ key = "alert:" .. key, name = name, sub = sub, icon = icon,
        r = r or ar, g = g or ag, b = b or ab, holdBonus = 2 })
end

local durabilityWarned = false
local function CheckDurability()
    if not Want("alertDurability") then return end
    local lowest
    for slot = 1, 19 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local pct = cur / max * 100
            if not lowest or pct < lowest then lowest = pct end
        end
    end
    if not lowest then return end
    local limit = tonumber(Get("durabilityThreshold")) or 30
    if lowest <= limit then
        if not durabilityWarned then
            durabilityWarned = true
            Alert("durability", "Low Durability", ("Your gear is at %d%%. Time to repair."):format(math.floor(lowest)),
                136241, 1, 0.45, 0.25)
        end
    elseif lowest > limit + 5 then
        durabilityWarned = false
    end
end

local bagsWarned = false
local function FreeSlots()
    local free = 0
    local GetFree = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
    if not GetFree then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local n, family = GetFree(bag)
        if n and (family == 0 or family == nil) then free = free + n end
    end
    return free
end

local function CheckBags()
    if not Want("alertBags") then return end
    local free = FreeSlots()
    if not free then return end
    local limit = tonumber(Get("bagsThreshold")) or 5
    if free <= limit then
        if not bagsWarned then
            bagsWarned = true
            Alert("bags", free == 0 and "Bags Full" or "Bags Nearly Full",
                free == 0 and "No free bag slots left." or (free .. " free bag slot" .. (free == 1 and "" or "s") .. " left."),
                133633, 1, 0.75, 0.25)
        end
    else
        bagsWarned = false
    end
end

local hadMail
local function CheckMail()
    local has = HasNewMail and HasNewMail() or false
    if has and not hadMail and Want("alertMail") then
        Alert("mail", "New Mail", "You have mail waiting.", 133468)
    end
    hadMail = has
end

local friendsOnline
local function CheckFriends()
    if not (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex) then return end
    local now = {}
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name and not Secret(info.name) and info.connected then now[info.name] = true end
    end
    if friendsOnline and Want("alertFriends") then
        for name in pairs(now) do
            if not friendsOnline[name] then Alert("friend:" .. name, name, "is now online", 134400, 0.4, 1, 0.5) end
        end
        for name in pairs(friendsOnline) do
            if not now[name] then Alert("friend:" .. name, name, "went offline", 134400, 0.6, 0.6, 0.6) end
        end
    end
    friendsOnline = now
end

local function OnBNetFriend(id, online)
    if not Want("alertFriends") or type(id) ~= "number" then return end
    local info = C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(id)
    if not info then return end
    local who = info.accountName
    local game = info.gameAccountInfo
    local char = game and game.characterName
    local sub = online and "is now online" or "went offline"
    if online and char and not Secret(char) and char ~= "" then sub = "is now online (" .. char .. ")" end
    -- account names are protected strings: only ever displayed
    Arcanum.Toast({ key = "bnet:" .. id, name = who, sub = sub, icon = 1395411,
        r = online and 0.35 or 0.6, g = online and 0.75 or 0.6, b = online and 1 or 0.6, holdBonus = 1 })
end

local vaultShown = false
local function CheckVault()
    if vaultShown or not Want("alertVault") then return end
    if not (C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards) then return end
    local ok, has = pcall(C_WeeklyRewards.HasAvailableRewards)
    if ok and has then
        vaultShown = true
        Alert("vault", "Great Vault", "Your weekly rewards are waiting.", 4203069, 0.72, 0.52, 1)
    end
end

---------------------------------------------------------------------------
-- Self highlight (Blizzard's "find yourself" CVars)
---------------------------------------------------------------------------
-- findYourselfMode: 1 outline, 2 circle, 3 icon, 4 outline + circle, 5 outline + icon
local HIGHLIGHT_MODES = {
    outline       = { 1, 1, 0, 0 },
    circle        = { 2, 0, 1, 0 },
    icon          = { 3, 0, 0, 1 },
    outlinecircle = { 4, 1, 1, 0 },
    outlineicon   = { 5, 1, 0, 1 },
}

local function SetVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, name, tostring(value))
    elseif SetCVar then
        pcall(SetCVar, name, value)
    end
end

local function GlobalDB()
    local core = Helpers and Helpers.GetCore and Helpers.GetCore()
    return core and core.db and core.db.global
end

local function HighlightTarget()
    if Get("selfHighlightHostile") == false then return false end
    return UnitExists("target") and UnitCanAttack("player", "target") or false
end

local function ApplyHighlight()
    local g = GlobalDB()
    if Want("selfHighlight") then
        local m = HIGHLIGHT_MODES[Get("selfHighlightMode")] or HIGHLIGHT_MODES.outlinecircle
        SetVar("findYourselfMode", m[1])
        SetVar("findYourselfModeOutline", m[2])
        SetVar("findYourselfModeCircle", m[3])
        SetVar("findYourselfModeIcon", m[4])
        SetVar("findYourselfAnywhere", 1)
        SetVar("findYourselfAnywhereOnlyInCombat", HighlightTarget() and 0 or 1)
        if g then g.h3zArcanumHighlight = true end
    elseif g and g.h3zArcanumHighlight then
        -- only undo what Arcanum switched on
        SetVar("findYourselfAnywhere", 0)
        SetVar("findYourselfAnywhereOnlyInCombat", 0)
        g.h3zArcanumHighlight = nil
    end
end

local function OnTargetChanged()
    if not Want("selfHighlight") then return end
    SetVar("findYourselfAnywhereOnlyInCombat", HighlightTarget() and 0 or 1)
end

---------------------------------------------------------------------------
-- Achievement tracker: earned achievements leave the tracked list
---------------------------------------------------------------------------
local function Untrack(id)
    if not Want("untrackAchievements") or type(id) ~= "number" then return end
    if C_ContentTracking and C_ContentTracking.StopTracking and Enum and Enum.ContentTrackingType then
        local stop = Enum.ContentTrackingStopType and Enum.ContentTrackingStopType.Manual or 0
        pcall(C_ContentTracking.StopTracking, Enum.ContentTrackingType.Achievement, id, stop)
    elseif RemoveTrackedAchievement then
        pcall(RemoveTrackedAchievement, id)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_ENTERING_WORLD", "CHAT_MSG_LOOT", "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE",
    "CHAT_MSG_COMBAT_FACTION_CHANGE", "UPDATE_INVENTORY_DURABILITY", "BAG_UPDATE_DELAYED",
    "UPDATE_PENDING_MAIL", "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
    "WEEKLY_REWARDS_UPDATE", "PLAYER_TARGET_CHANGED", "ACHIEVEMENT_EARNED",
}) do
    pcall(ev.RegisterEvent, ev, e)
end

ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
    if event == "PLAYER_ENTERING_WORLD" then
        pcall(HookBlizzardLoot)
        lastMoney = GetMoney()
        local initial = a1
        C_Timer.After(1, ApplyHighlight)
        C_Timer.After(3, function()
            CheckDurability()
            CheckBags()
            if initial then
                hadMail = nil
                CheckMail()
                CheckVault()
            end
            if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
        end)
        return
    end
    if event == "CHAT_MSG_LOOT" then OnLootMessage(a1)
    elseif event == "PLAYER_MONEY" then OnMoney()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then OnCurrency(a1, a2, a3)
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then OnFaction(a1)
    elseif event == "UPDATE_INVENTORY_DURABILITY" then CheckDurability()
    elseif event == "BAG_UPDATE_DELAYED" then CheckBags()
    elseif event == "UPDATE_PENDING_MAIL" then CheckMail()
    elseif event == "FRIENDLIST_UPDATE" then CheckFriends()
    elseif event == "BN_FRIEND_ACCOUNT_ONLINE" then OnBNetFriend(a1, true)
    elseif event == "BN_FRIEND_ACCOUNT_OFFLINE" then OnBNetFriend(a1, false)
    elseif event == "WEEKLY_REWARDS_UPDATE" then CheckVault()
    elseif event == "PLAYER_TARGET_CHANGED" then OnTargetChanged()
    elseif event == "ACHIEVEMENT_EARNED" then Untrack(a1)
    end
end)

---------------------------------------------------------------------------
-- H3z0 UI Edit Mode: "Arcanum Loot Toasts" can be moved like every other element
---------------------------------------------------------------------------
local previewRows

local function SetPreview(on)
    local a = Anchor()
    if on then
        PlaceAnchor()
        if not previewRows then
            previewRows = {}
            for i = 1, 3 do
                local row = CreateFrame("Frame", nil, a)
                row:SetSize(ToastWidth(), ToastHeight())
                row:SetPoint("BOTTOM", a, "BOTTOM", 0, (i - 1) * (ToastHeight() + GAP))
                local Round = ns.Round
                local ok, panel = false, nil
                if Round and Round.Panel then ok, panel = pcall(Round.Panel, row, 5) end
                if ok and panel then
                    panel:SetAllPoints(row)
                    panel:SetFillColor(0.04, 0.045, 0.055, 0.82)
                    panel:SetBorderColor(0.32, 0.32, 0.34, 0.55)
                else
                    local bg = row:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.04, 0.045, 0.055, 0.82)
                end
                local text = row:CreateFontString(nil, "OVERLAY")
                SetFont(text, 13, "")
                text:SetPoint("LEFT", row, "LEFT", 12, 0)
                text:SetText(i == 1 and "Arcanum Loot Toasts" or "")
                text:SetTextColor(0.8, 0.8, 0.8, 1)
                previewRows[i] = row
            end
        end
        for _, row in ipairs(previewRows) do row:Show() end
    elseif previewRows then
        for _, row in ipairs(previewRows) do row:Hide() end
    end
end

local function RegisterLayout()
    local LM = ns.H3z0UI_LayoutMode
    if not (LM and LM.RegisterElement) then return end
    Anchor()
    PlaceAnchor()
    LM:RegisterElement({
        key = LAYOUT_KEY,
        label = "Arcanum Loot Toasts",
        group = (ns.L and ns.L["Display"]) or "Display",
        order = 91,
        isOwned = true,
        getFrame = function() return anchor end,
        onOpen = function() SetPreview(true) end,
        onClose = function() SetPreview(false) end,
    })
    if _G.H3z0UI_RegisterFrameResolver then
        _G.H3z0UI_RegisterFrameResolver(LAYOUT_KEY, {
            resolver = function() return anchor end,
            displayName = "Arcanum Loot Toasts", category = "Display", order = 91,
        })
    end
    C_Timer.After(0, PlaceAnchor)
end

local lmEv = CreateFrame("Frame")
lmEv:RegisterEvent("PLAYER_LOGIN")
lmEv:SetScript("OnEvent", function() pcall(RegisterLayout) end)

---------------------------------------------------------------------------
-- Options / test
---------------------------------------------------------------------------
function Arcanum.Refresh()
    ApplyHighlight()
    if anchor then
        if not (ns.H3z0UI_LayoutMode and ns.H3z0UI_LayoutMode.isActive) then PlaceAnchor() end
        ResizeAnchor(anchor)
        for _, t in ipairs(active) do ResizeToast(t) end
        Layout()
    end
    if previewRows then
        for i, row in ipairs(previewRows) do
            row:SetSize(ToastWidth(), ToastHeight())
            row:ClearAllPoints()
            row:SetPoint("BOTTOM", anchor, "BOTTOM", 0, (i - 1) * (ToastHeight() + GAP))
        end
    end
    if not On() then
        for i = #active, 1, -1 do Release(active[i]) end
    end
end
_G.H3z0UI_RefreshArcanum = Arcanum.Refresh

function Arcanum.Test()
    if not On() then return end
    local r, g, b = QualityColor(4)
    Arcanum.Toast({ key = "test:epic", name = "Blade of the H3z0 Hero", icon = 135349, r = r, g = g, b = b,
        sound = true, holdBonus = 3 })
    r, g, b = QualityColor(3)
    Arcanum.Toast({ key = "test:rare", name = "Sturdy Bracers", icon = 132602, r = r, g = g, b = b, countText = "x2" })
    r, g, b = QualityColor(0)
    Arcanum.Toast({ key = "test:poor", name = "Perforated Wing", icon = 133708, r = r, g = g, b = b })
    Arcanum.Toast({ key = "test:money", name = "Gold", countText = "+" .. MoneyText(1234567), icon = 133784, r = 1, g = 0.82, b = 0.2 })
    Arcanum.Toast({ key = "test:rep", name = "The Assembly of the Deeps", countText = "+250",
        icon = 236681, r = 0.45, g = 0.72, b = 1 })
    Alert("test:bags", "Bags Nearly Full", "3 free bag slots left.", 133633, 1, 0.75, 0.25)
end
_G.H3z0UI_ArcanumTest = Arcanum.Test
