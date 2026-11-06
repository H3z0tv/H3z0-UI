local ADDON_NAME, ns = ...
local Storage = ns.Storage or {}; ns.Storage = Storage

local ItemInfo = {}
Storage.ItemInfo = ItemInfo

local derived = {}
local pendingLoads = {}

function ItemInfo.GetDerived(itemID)
    if not itemID then return nil end
    local hit = derived[itemID]
    if hit then return hit end
    local _, _, _, equipLoc, icon, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if not classID then return nil end
    local isEquippable = C_Item.IsEquippableItem(itemID) and true or false
    local rec = { classID = classID, subClassID = subClassID, equipLoc = equipLoc,
        icon = icon, isEquippable = isEquippable }
    derived[itemID] = rec
    return rec
end

-- how often one item was asked for lately (an item whose slot never gets a
-- quality, e.g. while it sits on the cursor, must not be loaded over and over:
-- every load result re-scanned the bank, which re-asked, every frame)
local recentLoads = {}
local LOAD_WINDOW, LOAD_MAX = 10, 2

function ItemInfo.RequestLoad(itemID, callback)
    if not itemID then return end
    -- the data is already here: loading it again changes nothing
    if C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(itemID) then return end
    local now = GetTime and GetTime() or 0
    local r = recentLoads[itemID]
    if r and now - r.t < LOAD_WINDOW then
        if r.n >= LOAD_MAX and not pendingLoads[itemID] then return end
        r.n = r.n + 1
    else
        recentLoads[itemID] = { t = now, n = 1 }
    end
    local list = pendingLoads[itemID]
    if list then
        list[#list + 1] = callback
        return
    end
    pendingLoads[itemID] = { callback }
    C_Item.RequestLoadItemDataByID(itemID)
end

function ItemInfo.OnItemDataLoadResult(itemID, success)
    local list = pendingLoads[itemID]
    if not list then return end
    pendingLoads[itemID] = nil
    for i = 1, #list do
        xpcall(function() list[i](itemID, success) end, geterrorhandler())
    end
end

local extended = {}

function ItemInfo.GetExtended(itemID, link)
    if not itemID then return nil end
    local key = link or itemID
    local hit = extended[key]
    if hit then return hit end
    local name, infoLink, _, baseIlvl, _, _, _, maxStack, _, _, _, _, _, bindType, expacID, _, isCraftingReagent = C_Item.GetItemInfo(itemID)
    if not name then return nil end
    local ilvl = C_Item.GetDetailedItemLevelInfo(link or infoLink) or baseIlvl
    local rec = { name = name, ilvl = ilvl, expacID = expacID, maxStack = maxStack,
        bindType = bindType, isReagent = isCraftingReagent and true or false }
    extended[key] = rec
    return rec
end
