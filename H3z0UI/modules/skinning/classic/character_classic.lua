---------------------------------------------------------------------------
-- H3z0 UI - Character window for the Classic games
-- (Classic Era / Anniversary and TBC Anniversary; loaded by the Classic .toc
-- files only, the retail character pane is not loaded there.)
--
-- Classic keeps its own Character window (paper doll, stats, model, tabs).
-- H3z0 UI gives it the H3z0 look:
--   * one rounded slate window instead of the parchment art
--   * gear slots with a border in the item's quality colour and the item level
--   * the average item level of your gear and your name / level on top
--   * stat, reputation, skill and honor pages without the old art
--   * H3z0 tabs and close button
-- Appearance > Skinning > Character Window turns it on / off (reload).
-- Only Blizzard frames' look is changed (alpha / anchors); nothing is replaced.
---------------------------------------------------------------------------
local _, ns = ...
local Helpers = ns.Helpers
local SkinBase = ns.SkinBase

if not (ns.Client and ns.Client.isClassic) then return end

local Classic = {}
ns.H3z0ClassicCharacter = Classic

local function Enabled()
    local core = Helpers and Helpers.GetCore and Helpers.GetCore()
    local g = core and core.db and core.db.profile and core.db.profile.general
    return not (g and g.skinCharacterFrame == false)
end

local function Font()
    return (Helpers and Helpers.GetGeneralFont and Helpers.GetGeneralFont()) or STANDARD_TEXT_FONT
end

local function SetFont(fs, size, flags)
    if Helpers and Helpers.ApplyFontWithFallback then
        Helpers.ApplyFontWithFallback(fs, Font(), size, flags or "OUTLINE")
    else
        fs:SetFont(Font(), size, flags or "OUTLINE")
    end
end

-- the gear slots (name, inventory slot id)
local SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot",
}
-- slots that don't count for the average item level
local NO_ILVL = { ShirtSlot = true, TabardSlot = true, AmmoSlot = true }

-- Blizzard frames whose own art is hidden (the window, the pages behind the tabs)
local ART_FRAMES = { "CharacterFrame", "PaperDollFrame", "PetPaperDollFrame", "ReputationFrame", "SkillFrame",
    "HonorFrame", "PVPFrame", "TokenFrame", "CharacterAttributesFrame", "PaperDollItemsFrame" }
local STAT_BACKGROUNDS = { "PlayerStatBackgroundTop", "PlayerStatBackgroundMiddle", "PlayerStatBackgroundBottom",
    "MeleeAttackBackgroundTop", "MeleeAttackBackgroundMiddle", "MeleeAttackBackgroundBottom",
    "RangedAttackBackgroundTop", "RangedAttackBackgroundMiddle", "RangedAttackBackgroundBottom" }

local window          -- the H3z0 backdrop behind the character window
local slotParts = {}  -- slot button -> { border, ilvl }

---------------------------------------------------------------------------
-- Item level / quality of one slot
---------------------------------------------------------------------------
local function SlotInfo(slotName)
    local id = GetInventorySlotInfo(slotName)
    if not id then return nil end
    local link = GetInventoryItemLink("player", id)
    if not link then return id, nil end
    local quality = GetInventoryItemQuality("player", id)
    local ilvl
    local GDIL = (C_Item and C_Item.GetDetailedItemLevelInfo) or _G.GetDetailedItemLevelInfo
    if GDIL then
        local ok, v = pcall(GDIL, link)
        if ok then ilvl = v end
    end
    return id, link, quality, ilvl
end

local function QualityColor(q)
    if q and C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(q)
        if r then return r, g, b end
    end
    local colors = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS
    local c = q and colors and colors[q]
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    return 0.25, 0.29, 0.33
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function HideArt()
    for _, name in ipairs(ART_FRAMES) do
        local f = _G[name]
        if f and SkinBase.StripTextures then SkinBase.StripTextures(f) end
    end
    for _, name in ipairs(STAT_BACKGROUNDS) do
        local t = _G[name]
        if t then t:SetAlpha(0) end
    end
    if _G.CharacterFramePortrait then _G.CharacterFramePortrait:SetAlpha(0) end
end

local function SkinSlot(button)
    if not button or slotParts[button] then return end
    local parts = {}
    -- Blizzard's slot frame art
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    local icon = button.icon or _G[(button:GetName() or "") .. "IconTexture"]
    if icon then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    -- quality border (four thin lines, our own frame on top of the icon)
    local edge = CreateFrame("Frame", nil, button)
    edge:SetAllPoints()
    edge:SetFrameLevel(button:GetFrameLevel() + 2)
    edge:EnableMouse(false)
    edge.lines = {}
    for i = 1, 4 do edge.lines[i] = edge:CreateTexture(nil, "OVERLAY") end
    local L = edge.lines
    L[1]:SetPoint("TOPLEFT", -1, 1); L[1]:SetPoint("TOPRIGHT", 1, 1); L[1]:SetHeight(1)
    L[2]:SetPoint("BOTTOMLEFT", -1, -1); L[2]:SetPoint("BOTTOMRIGHT", 1, -1); L[2]:SetHeight(1)
    L[3]:SetPoint("TOPLEFT", -1, 1); L[3]:SetPoint("BOTTOMLEFT", -1, -1); L[3]:SetWidth(1)
    L[4]:SetPoint("TOPRIGHT", 1, 1); L[4]:SetPoint("BOTTOMRIGHT", 1, -1); L[4]:SetWidth(1)
    parts.edge = edge
    -- dark square behind an empty slot
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.07, 0.09, 0.9)
    parts.bg = bg
    -- item level
    local ilvl = edge:CreateFontString(nil, "OVERLAY")
    SetFont(ilvl, 11, "OUTLINE")
    ilvl:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 2)
    ilvl:SetJustifyH("RIGHT")
    parts.ilvl = ilvl
    slotParts[button] = parts
end

local function UpdateSlots()
    if not window then return end
    local total, count = 0, 0
    for _, slotName in ipairs(SLOTS) do
        local button = _G["Character" .. slotName]
        local parts = button and slotParts[button]
        if parts then
            local _, link, quality, ilvl = SlotInfo(slotName)
            local r, g, b = QualityColor(link and quality)
            for i = 1, 4 do parts.edge.lines[i]:SetColorTexture(r, g, b, link and 1 or 0.5) end
            if link and ilvl and ilvl > 1 and not NO_ILVL[slotName] then
                parts.ilvl:SetText(ilvl)
                parts.ilvl:SetTextColor(r, g, b, 1)
                total, count = total + ilvl, count + 1
            else
                parts.ilvl:SetText("")
            end
        end
    end
    if window.ilvl then
        if count > 0 then
            window.ilvl:SetFormattedText("Item Level %.1f", total / count)
        else
            window.ilvl:SetText("")
        end
    end
end

local function SkinTabs()
    for i = 1, 6 do
        local tab = _G["CharacterFrameTab" .. i]
        if tab then
            if SkinBase.SkinTab then pcall(SkinBase.SkinTab, tab, _G.CharacterFrame) end
            if SkinBase.StripTextures then SkinBase.StripTextures(tab) end
        end
    end
end

local function Build()
    local frame = _G.CharacterFrame
    if window or not frame then return end
    HideArt()

    -- the H3z0 window inside the old 384 x 512 frame (its art leaves a margin)
    window = CreateFrame("Frame", nil, frame)
    window:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    window:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 74)
    window:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    window:EnableMouse(false)
    local R = ns.Round
    if R and R.Panel then
        local panel = R.Panel(window, 10)
        panel:SetAllPoints(window)
        local fill = R.SLATE_FILL or { 0.075, 0.095, 0.12 }
        local edge = R.SLATE_BORDER or { 0.25, 0.29, 0.33 }
        panel:SetFillColor(fill[1] + 0.03, fill[2] + 0.03, fill[3] + 0.03, 0.97)
        panel:SetBorderColor(edge[1], edge[2], edge[3], 1)
        window.panel = panel
    else
        local t = window:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(0.105, 0.125, 0.16, 0.97)
    end

    -- average item level, top middle
    local text = frame:CreateFontString(nil, "OVERLAY")
    SetFont(text, 13, "OUTLINE")
    text:SetPoint("TOP", window, "TOP", 0, -30)
    text:SetTextColor(1, 0.82, 0.2, 1)
    window.ilvl = text

    -- name / level / guild in white
    for _, name in ipairs({ "CharacterNameText", "CharacterLevelText", "CharacterGuildText" }) do
        local fs = _G[name]
        if fs then
            local _, size = fs:GetFont()
            SetFont(fs, math.max(10, math.floor((size or 12) + 0.5)), "OUTLINE")
            fs:SetTextColor(0.95, 0.95, 0.96, 1)
        end
    end

    -- close button in the corner of the H3z0 window
    local close = _G.CharacterFrameCloseButton
    if close then
        if SkinBase.SkinCloseButton then pcall(SkinBase.SkinCloseButton, close) end
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -4, -4)
    end

    for _, slotName in ipairs(SLOTS) do SkinSlot(_G["Character" .. slotName]) end
    SkinTabs()
    UpdateSlots()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        if not Enabled() then return end
        local frame = _G.CharacterFrame
        if not frame then return end
        frame:HookScript("OnShow", function()
            if not window then Build() end
            HideArt()
            UpdateSlots()
        end)
        H3z0UI_SafeRegisterEvent(self, "PLAYER_EQUIPMENT_CHANGED")
        H3z0UI_SafeRegisterEvent(self, "UNIT_INVENTORY_CHANGED")
        H3z0UI_SafeRegisterEvent(self, "GET_ITEM_INFO_RECEIVED")
        return
    end
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    local frame = _G.CharacterFrame
    if window and frame and frame:IsShown() then UpdateSlots() end
end)

Classic.Build = Build
Classic.Update = UpdateSlots
