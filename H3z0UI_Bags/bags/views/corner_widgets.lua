local ADDON_NAME, ns = ...
local Bags = ns.Bags or {}; ns.Bags = Bags
local Helpers = ns.Helpers

local function CJKFont(fs, p, s, f)
    if Bags.CJKFont then return Bags.CJKFont(fs, p, s, f) end
    fs:SetFont(p, s, f)
end

local CornerWidgets = {}
Bags.CornerWidgets = CornerWidgets

local EXPANSION_SHORT = {
    [0] = "Cls", "TBC", "WLK", "Cat", "MoP", "WoD", "Leg", "BfA", "SL", "DF",
    "TWW", "Mid",
}

local function TextColor(ctx)
    if ctx.qualityColorText and Bags.ItemButtons then
        return Bags.ItemButtons.GetQualityColor((ctx.entry and ctx.entry.quality) or 1)
    end
    return 1, 1, 1
end

CornerWidgets.Resolvers = {
    crafting_quality = function(ctx)
        if ctx.craftQualityAtlas then return { atlas = ctx.craftQualityAtlas } end
    end,
    upgrade_track = function(ctx)
        local u = ctx.upgradeTrack
        if u then return { text = u.text, r = u.r, g = u.g, b = u.b } end
    end,
    quantity = function(ctx)
        local c = ctx.entry and ctx.entry.count
        if c and c > 1 then
            return { text = tostring(c), r = 1, g = 1, b = 1 }
        end
    end,
    item_level = function(ctx)
        local d = ctx.details
        if d and d.ilvl and d.ilvl > 1 and d.isEquippable then
            local r, g, b = TextColor(ctx)
            return { text = tostring(d.ilvl), r = r, g = g, b = b }
        end
    end,
    junk = function(ctx)
        if ctx.isJunk then return { atlas = "bags-junkcoin" } end
    end,
    equipment_set = function(ctx)
        if ctx.inSet then return { atlas = "questlog-icon-setting" } end
    end,
    binding = function(ctx)
        local d = ctx.details
        if not d or d.isBound then return nil end
        local a = CornerWidgets.GetAppearance and CornerWidgets.GetAppearance()
        if a and a.hideBoeOnCommon and (d.quality or 1) <= 1 then return nil end
        local bt = d.bindType
        if bt == 2 then
            local r, g, b = TextColor(ctx)
            return { text = "BoE", r = r, g = g, b = b }
        elseif bt == 7 or bt == 8 or bt == 9 then
            local r, g, b = TextColor(ctx)
            return { text = "BoA", r = r, g = g, b = b }
        end
    end,
    expansion = function(ctx)
        local d = ctx.details
        local short = d and d.expacID and EXPANSION_SHORT[d.expacID]
        if short then return { text = short, r = 0.8, g = 0.8, b = 0.8 } end
    end,
}

---------------------------------------------------------------------------
-- More corner widgets (binding kinds, keystones, pets, upgrades, transmog)
---------------------------------------------------------------------------
local R = CornerWidgets.Resolvers

local getBags
local function GetAppearance()
    getBags = getBags or (Helpers.CreateDBGetter and Helpers.CreateDBGetter("bags"))
    local s = getBags and getBags()
    return s and s.appearance
end
CornerWidgets.GetAppearance = GetAppearance

-- binding text: hidden on poor / common items when "Hide BoE On Common" is on
local function BindText(ctx, label, wantType)
    local d = ctx.details
    if not d or d.isBound then return nil end
    local bt = d.bindType
    local match = (type(wantType) == "table") and wantType[bt] or bt == wantType
    if not match then return nil end
    local a = GetAppearance()
    if a and a.hideBoeOnCommon and (d.quality or 1) <= 1 then return nil end
    local r, g, b = TextColor(ctx)
    return { text = label, r = r, g = g, b = b }
end

R.boe = function(ctx) return BindText(ctx, "BoE", 2) end
R.bou = function(ctx) return BindText(ctx, "BoU", 3) end
R.boa = function(ctx) return BindText(ctx, "BoA", { [7] = true, [8] = true }) end
R.wue = function(ctx) return BindText(ctx, "WuE", 9) end

-- Warbound: bound to your account (moves freely between your characters)
R.warbound = function(ctx)
    local d = ctx.details
    if not d then return nil end
    if d.bindType == 7 or d.bindType == 8 or (d.bindType == 9 and d.isBound) then
        return { text = "WB", r = 0.0, g = 0.8, b = 1.0 }
    end
end

-- Mythic+ keystone level from the keystone link
R.keystone_level = function(ctx)
    local link = ctx.entry and ctx.entry.link
    if type(link) ~= "string" then return nil end
    local level = link:match("keystone:%d+:%d+:(%d+)")
    if level then return { text = "+" .. level, r = 1, g = 0.82, b = 0.2 } end
end

-- battle pet level from the pet link
R.battle_pet_level = function(ctx)
    local link = ctx.entry and ctx.entry.link
    if type(link) ~= "string" then return nil end
    local level = link:match("battlepet:%d+:(%d+)")
    if level then return { text = level, r = 1, g = 1, b = 1 } end
end

-- the icon of the equipment set the item belongs to
R.equipment_set_icon = function(ctx)
    if ctx.setIcon then return { texture = ctx.setIcon } end
end

-- tradeable loot: an item you may still trade with the others who could loot it
R.tradeable = function(ctx)
    if ctx.isTradeable then return { text = "TL", r = 0.4, g = 1, b = 0.4 } end
end

-- an item level upgrade over what you have equipped (Pawn's verdict when Pawn is loaded)
local SLOT_FOR_LOC = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_RANGED = { 16 },
    INVTYPE_RANGEDRIGHT = { 16 },
}
local function EquippedLevel(slot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if not link then return 0 end
    return (C_Item.GetDetailedItemLevelInfo(link)) or 0
end
local function UpgradeMode()
    getBags = getBags or (Helpers.CreateDBGetter and Helpers.CreateDBGetter("bags"))
    local s = getBags and getBags()
    return s and s.behavior and s.behavior.upgradeDetection or "auto"
end

function CornerWidgets.IsUpgrade(d, bagID, slot)
    if not d or not d.isEquippable or not d.ilvl then return false end
    local mode = UpgradeMode()
    if mode ~= "ilvl" then
        if bagID and slot and _G.PawnIsContainerItemAnUpgrade then
            local ok, up = pcall(_G.PawnIsContainerItemAnUpgrade, bagID, slot)
            if ok then return up and true or false end
        elseif d.link and _G.PawnIsItemAnUpgrade and _G.PawnGetItemData then
            local ok, item = pcall(_G.PawnGetItemData, d.link)
            if ok and item then
                local ok2, up = pcall(_G.PawnIsItemAnUpgrade, item)
                if ok2 then return up and true or false end
            end
        end
        if mode == "pawn" then return false end
    end
    local slots = SLOT_FOR_LOC[d.equipLoc or ""]
    if not slots then return false end
    local lowest
    for _, s in ipairs(slots) do
        local l = EquippedLevel(s)
        if not lowest or l < lowest then lowest = l end
    end
    if not lowest then return false end
    -- usable by this character (armor type / weapon skill): the red tooltip check
    if Bags.ItemButtons and Bags.ItemButtons.IsUnusable
        and Bags.ItemButtons.IsUnusable(bagID, slot, d.link) then
        return false
    end
    return d.ilvl > lowest
end
R.upgrade = function(ctx)
    if ctx.isUpgrade then return { atlas = "bags-greenarrow" } end
end

-- an appearance you have not collected yet
function CornerWidgets.IsUncollectedAppearance(link)
    if type(link) ~= "string" or not C_TransmogCollection then return false end
    local getInfo = C_TransmogCollection.GetItemInfo
    if not getInfo then return false end
    local ok, appearanceID, sourceID = pcall(getInfo, link)
    if not ok or not sourceID then return false end
    local info = C_TransmogCollection.GetAppearanceInfoBySource
        and C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
    if info and info.appearanceIsCollected ~= nil then
        return not info.appearanceIsCollected
    end
    if C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance then
        return not C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID)
    end
    return false
end
R.transmog = function(ctx)
    if ctx.uncollected then return { atlas = "transmog-icon-hidden", tint = { 1, 0.5, 1 } } end
end

-- which widgets need extra work per item: only done when one is in use
function CornerWidgets.Wants(appearance, id)
    local c = appearance and appearance.corners
    if not c then return false end
    return c.tl1 == id or c.tl2 == id or c.tr1 == id or c.tr2 == id
        or c.bl1 == id or c.bl2 == id or c.br1 == id or c.br2 == id
end

-- the extra context for the live bag / bank buttons
local tradeCache = {}
function CornerWidgets.ExtraContext(ctx, appearance, bagID, slot, link)
    if not ctx then return ctx end
    local d = ctx.details
    if CornerWidgets.Wants(appearance, "upgrade") then
        ctx.isUpgrade = CornerWidgets.IsUpgrade(d, bagID, slot)
    end
    if CornerWidgets.Wants(appearance, "transmog") then
        ctx.uncollected = CornerWidgets.IsUncollectedAppearance(link)
    end
    if bagID and slot and CornerWidgets.Wants(appearance, "equipment_set_icon")
        and C_Container.GetContainerItemEquipmentSetInfo then
        local inSet, names = C_Container.GetContainerItemEquipmentSetInfo(bagID, slot)
        if inSet and type(names) == "string" and C_EquipmentSet then
            local first = names:match("^([^,]+)")
            local id = first and C_EquipmentSet.GetEquipmentSetID(first)
            if id then
                local _, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
                ctx.setIcon = icon
            end
        end
    end
    if bagID and slot and CornerWidgets.Wants(appearance, "tradeable")
        and link and C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local key = bagID .. ":" .. slot .. ":" .. link
        local hit = tradeCache[key]
        local now = GetTime()
        if hit and now - hit.t < 60 then
            ctx.isTradeable = hit.v
        else
            local data = C_TooltipInfo.GetBagItem(bagID, slot)
            local pattern = _G.BIND_TRADE_TIME_REMAINING
                and _G.BIND_TRADE_TIME_REMAINING:gsub("%%s", ".+"):gsub("[%(%)]", "%%%0")
            local v = false
            if data and data.lines and pattern then
                for _, line in ipairs(data.lines) do
                    if line.leftText and line.leftText:find(pattern) then v = true break end
                end
            end
            tradeCache[key] = { v = v, t = now }
            ctx.isTradeable = v
        end
    end
    return ctx
end

function CornerWidgets.Select(id1, id2, ctx)
    if not ctx then return nil end
    local resolver = id1 and CornerWidgets.Resolvers[id1]
    local payload = resolver and resolver(ctx)
    if payload then return payload end
    resolver = id2 and CornerWidgets.Resolvers[id2]
    return resolver and resolver(ctx) or nil
end

local CORNERS = {
    { key = "tl", point = "TOPLEFT",     x = 2,  y = -1, justify = "LEFT" },
    { key = "tr", point = "TOPRIGHT",    x = -2, y = -1, justify = "RIGHT" },
    { key = "bl", point = "BOTTOMLEFT",  x = 2,  y = 1,  justify = "LEFT" },
    { key = "br", point = "BOTTOMRIGHT", x = -2, y = 1,  justify = "RIGHT" },
}

local function EnsureCorner(button, c)
    local store = button._h3z0uiCorners
    if not store then
        store = {}
        button._h3z0uiCorners = store
    end
    local slot = store[c.key]
    if not slot then
        local fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetPoint(c.point, button, c.point, c.x, c.y)
        fs:SetJustifyH(c.justify)
        local tex = button:CreateTexture(nil, "OVERLAY", nil, 6)
        tex:SetPoint(c.point, button, c.point, c.x, c.y)
        tex:SetSize(12, 12)
        slot = { fs = fs, tex = tex }
        store[c.key] = slot
    end
    return slot
end

function CornerWidgets.Apply(button, ctx, appearance)
    local corners = appearance and appearance.corners
    local fontSize = (appearance and appearance.cornerFontSize) or 11
    local iconSize = (appearance and appearance.cornerIconSize) or 12
    for _, c in ipairs(CORNERS) do
        local payload
        if ctx and corners then
            payload = CornerWidgets.Select(corners[c.key .. "1"], corners[c.key .. "2"], ctx)
        end
        local slot = button._h3z0uiCorners and button._h3z0uiCorners[c.key]
        if payload then
            slot = slot or EnsureCorner(button, c)
            if payload.text then
                CJKFont(slot.fs, Helpers.GetGeneralFont() or STANDARD_TEXT_FONT,
                    fontSize, "OUTLINE")
                slot.fs:SetText(payload.text)
                slot.fs:SetTextColor(payload.r or 1, payload.g or 1, payload.b or 1)
                slot.fs:Show()
                slot.tex:Hide()
            else
                if payload.texture then
                    slot.tex:SetTexture(payload.texture)
                    slot.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                else
                    slot.tex:SetAtlas(payload.atlas)
                end
                if payload.tint then
                    slot.tex:SetVertexColor(payload.tint[1], payload.tint[2], payload.tint[3])
                else
                    slot.tex:SetVertexColor(1, 1, 1)
                end
                slot.tex:SetSize(iconSize, iconSize)
                slot.tex:Show()
                slot.fs:Hide()
            end
        elseif slot then
            slot.fs:Hide()
            slot.tex:Hide()
        end
    end
end
