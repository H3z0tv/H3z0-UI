local ADDON_NAME, ns = ...

-- WoW: Forever only: Blizzard's character frame stays as it is, with a small
-- item level on every equipped slot (quality colored), a red tint for low
-- durability, and the average item level at the top of the frame.
if not (ns.Client and ns.Client.isForever) then return end

local SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot",
}
local NO_ILVL = { ShirtSlot = true, TabardSlot = true }

local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or _G.GetDetailedItemLevelInfo
local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor

local function IsEnabled()
    local core = ns.Addon
    local s = core and core.db and core.db.profile and core.db.profile.character
    return not (s and s.enabled == false)
end

local labels = {}
local avgText

local function Font(fs, size)
    local path = STANDARD_TEXT_FONT
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then path = LSM:Fetch("font", "H3z0UI", true) or path end
    fs:SetFont(path, size, "OUTLINE")
end

local function GetLabel(slotName)
    if labels[slotName] then return labels[slotName] end
    local button = _G["Character" .. slotName]
    if not button then return nil end
    local fs = button:CreateFontString(nil, "OVERLAY")
    Font(fs, 11)
    fs:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    labels[slotName] = fs
    return fs
end

local function Update()
    if not (CharacterFrame and CharacterFrame:IsShown()) then return end
    local on = IsEnabled()
    for _, slotName in ipairs(SLOTS) do
        local fs = GetLabel(slotName)
        if fs then
            local text
            if on and not NO_ILVL[slotName] then
                local slotID = GetInventorySlotInfo(slotName)
                local link = slotID and GetInventoryItemLink("player", slotID)
                if link then
                    local ilvl = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link)
                    if ilvl and ilvl > 1 then
                        local quality = GetInventoryItemQuality("player", slotID)
                        local r, g, b = 1, 1, 1
                        if quality and GetItemQualityColor then
                            local qr, qg, qb = GetItemQualityColor(quality)
                            if qr then r, g, b = qr, qg, qb end
                        end
                        local cur, max = GetInventoryItemDurability(slotID)
                        if cur and max and max > 0 and cur / max < 0.25 then
                            r, g, b = 1, 0.2, 0.2
                        end
                        text = ("|cff%02x%02x%02x%d|r"):format(r * 255, g * 255, b * 255, ilvl)
                    end
                end
            end
            fs:SetText(text or "")
            fs:SetShown(text ~= nil)
        end
    end

    if not avgText and CharacterFrame then
        avgText = CharacterFrame:CreateFontString(nil, "OVERLAY")
        Font(avgText, 12)
        local anchor = _G.CharacterLevelText or CharacterFrame
        if anchor == CharacterFrame then
            avgText:SetPoint("TOP", CharacterFrame, "TOP", 0, -46)
        else
            avgText:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
        end
    end
    if avgText then
        local overall, equipped = 0, 0
        if GetAverageItemLevel then overall, equipped = GetAverageItemLevel() end
        if on and equipped and equipped > 0 then
            avgText:SetText(("Item Level |cff34D399%.1f|r  |cff888888(%.1f)|r"):format(equipped, overall or equipped))
            avgText:Show()
        else
            avgText:Hide()
        end
    end
end

local pending = false
local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(0.1, function() pending = false; Update() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
ev:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if CharacterFrame then CharacterFrame:HookScript("OnShow", Queue) end
        return
    end
    Queue()
end)

_G.H3z0UI_RefreshForeverItemLevels = Update
