---------------------------------------------------------------------------
-- H3z0 UI Raid Frames (0.24.5)
-- One column per group (group number on top), every member a slate tile:
-- name in class colour top left, level top right, health bar in class colour with the
-- missing part dark, a small role badge (tank / healer) and a thin power bar for tanks
-- and healers. Pets get their own column on the right.
--
-- Built on the game's secure group headers, so targeting, the right-click menu and roster
-- changes keep working in combat. Every value that can be secret in Midnight is only handed
-- to StatusBars / FontStrings, never compared.
--
-- Layout Mode shows a 20-player preview with pets while you are not in a raid.
-- /h3z0raid test - preview on/off, /h3z0raid reset - default position.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local issecretvalue = issecretvalue or function() return false end
local WHITE = "Interface\\Buttons\\WHITE8x8"
local MAX_GROUPS = 8
local GROUP_SIZE = 5
local MAX_PETS = 10
local LABEL_H = 14

local container, preview
local headers = {}          -- [group] = secure group header
local petHeader
local cells = {}            -- every real cell (members + pets)
local byUnit = {}           -- unit token -> cell
local labels = {}           -- [group] = group number font string
local testMode = false
local layoutPending = false

local function GetSettings() return Helpers.GetModuleDB("raidFrames") end
local function S(v) return issecretvalue(v) end

local SLATE = { 0.075, 0.095, 0.12 }
local EDGE = { 0.25, 0.29, 0.33 }
local MISSING = { 0.13, 0.16, 0.19 }
local PET_GREEN = { 0.22, 0.72, 0.28 }

local function Colors()
    local R = ns.Round
    return (R and R.SLATE_FILL) or SLATE, (R and R.SLATE_BORDER) or EDGE
end

local function ClassRGB(class)
    local c = class and not S(class) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    if c then return c.r, c.g, c.b end
    return 0.7, 0.7, 0.7
end

local function UnitClassRGB(unit)
    local ok, _, class = pcall(UnitClass, unit)
    return ClassRGB(ok and class)
end

local function PowerRGB(token, ptype)
    local c = PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])
    if c then return c.r, c.g, c.b end
    return 0.2, 0.45, 0.95
end

local function Bool(v)
    if v == nil or S(v) then return nil end
    return v and true or false
end

---------------------------------------------------------------------------
-- Cell look (shared by the real frames and the preview)
---------------------------------------------------------------------------
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer" }

local function BuildCell(f, isPet)
    if f.h3zRF then return end
    f.h3zRF = true
    f.isPet = isPet
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.bg:SetAllPoints()
    f.edges = {}
    for i = 1, 4 do
        local e = f:CreateTexture(nil, "BORDER", nil, 2)
        e:SetTexture(WHITE)
        f.edges[i] = e
    end
    f.edges[1]:SetPoint("TOPLEFT"); f.edges[1]:SetPoint("TOPRIGHT"); f.edges[1]:SetHeight(1)
    f.edges[2]:SetPoint("BOTTOMLEFT"); f.edges[2]:SetPoint("BOTTOMRIGHT"); f.edges[2]:SetHeight(1)
    f.edges[3]:SetPoint("TOPLEFT"); f.edges[3]:SetPoint("BOTTOMLEFT"); f.edges[3]:SetWidth(1)
    f.edges[4]:SetPoint("TOPRIGHT"); f.edges[4]:SetPoint("BOTTOMRIGHT"); f.edges[4]:SetWidth(1)

    f.health = CreateFrame("StatusBar", nil, f)
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(1)
    f.healthBG = f.health:CreateTexture(nil, "BACKGROUND")
    f.healthBG:SetAllPoints()
    f.healthBG:SetColorTexture(MISSING[1], MISSING[2], MISSING[3], 1)

    f.power = CreateFrame("StatusBar", nil, f)
    f.power:SetMinMaxValues(0, 1)
    f.power:SetValue(1)
    f.powerBG = f.power:CreateTexture(nil, "BACKGROUND")
    f.powerBG:SetAllPoints()
    f.powerBG:SetColorTexture(0, 0, 0, 0.8)
    f.power:Hide()

    local text = CreateFrame("Frame", nil, f)
    text:SetAllPoints()
    text:SetFrameLevel(f.health:GetFrameLevel() + 3)
    f.textLayer = text
    f.name = text:CreateFontString(nil, "OVERLAY")
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.level = text:CreateFontString(nil, "OVERLAY")
    f.level:SetJustifyH("RIGHT")
    f.status = text:CreateFontString(nil, "OVERLAY")
    f.status:SetPoint("CENTER", f.health, "CENTER", 0, 0)
    f.status:SetTextColor(0.85, 0.85, 0.85)

    f.roleBox = CreateFrame("Frame", nil, text)
    f.roleBox.bg = f.roleBox:CreateTexture(nil, "BACKGROUND")
    f.roleBox.bg:SetAllPoints()
    f.roleBox.bg:SetColorTexture(0.05, 0.07, 0.09, 0.9)
    f.role = f.roleBox:CreateTexture(nil, "OVERLAY")
    f.role:SetPoint("TOPLEFT", 1, -1)
    f.role:SetPoint("BOTTOMRIGHT", -1, 1)
    f.roleBox:Hide()
end

local function EdgeColor(f, r, g, b, a)
    for _, e in ipairs(f.edges) do e:SetVertexColor(r, g, b, a or 1) end
end

-- sizes, fonts and positions of one cell
local function LayoutCell(f, w, h, s)
    local fill, edge = Colors()
    local font, outline = Helpers.GetGeneralFont(), Helpers.GetGeneralFontOutline()
    local tex = Helpers.GetGeneralTexture()
    local fs = s.fontSize or 12
    f.bg:SetColorTexture(fill[1], fill[2], fill[3], 0.92)
    if not f.isTarget then EdgeColor(f, edge[1], edge[2], edge[3], 1) end
    f.health:SetStatusBarTexture(tex)
    f.power:SetStatusBarTexture(tex)
    f.name:SetFont(font, f.isPet and math.max(8, fs - 1) or fs, outline)
    f.level:SetFont(font, fs, outline)
    f.status:SetFont(font, math.max(8, fs - 2), outline)

    f.health:ClearAllPoints()
    f.name:ClearAllPoints()
    if f.isPet then
        f.health:SetPoint("TOPLEFT", 3, -3)
        f.health:SetPoint("BOTTOMRIGHT", -3, 3)
        f.name:SetPoint("LEFT", f.health, "LEFT", 4, 0)
        f.name:SetPoint("RIGHT", f.health, "RIGHT", -4, 0)
        f.name:SetTextColor(1, 1, 1)
        f.level:Hide()
        f.power:Hide()
        f.roleBox:Hide()
        return
    end
    local top = fs + 6
    local ph = (f.powerShown and (s.powerHeight or 4) + 1) or 0
    f.level:ClearAllPoints()
    f.level:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -3)
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -3)
    f.name:SetPoint("RIGHT", f.level, "LEFT", -4, 0)
    f.health:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -top)
    f.health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3 + ph)
    f.power:ClearAllPoints()
    f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 3, 3)
    f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    f.power:SetHeight(s.powerHeight or 4)
    local rb = math.max(10, math.min(16, h - top - ph - 6))
    f.roleBox:SetSize(rb, rb)
    f.roleBox:ClearAllPoints()
    f.roleBox:SetPoint("BOTTOMLEFT", f.health, "BOTTOMLEFT", 2, 2)
end

local function SetPowerShown(f, show, s)
    show = show and true or false
    if f.powerShown == show then return end
    f.powerShown = show
    f.power:SetShown(show)
    LayoutCell(f, f:GetWidth(), f:GetHeight(), s)
end

---------------------------------------------------------------------------
-- Real data
---------------------------------------------------------------------------
local function UpdateName(f)
    local s = GetSettings(); local u = f.unit
    if not (s and u) then return end
    if not pcall(f.name.SetText, f.name, UnitName(u)) then f.name:SetText("") end
    if f.isPet or not s.classColorName then
        f.name:SetTextColor(1, 1, 1)
    else
        f.name:SetTextColor(UnitClassRGB(u))
    end
end

local function UpdateLevel(f)
    local s = GetSettings(); local u = f.unit
    if not (s and u) or f.isPet then return end
    if not s.showLevel then f.level:Hide() return end
    local lvl = UnitLevel(u)
    f.level:Show()
    if lvl ~= nil and not S(lvl) and lvl <= 0 then
        f.level:SetText("??")
    elseif not pcall(f.level.SetFormattedText, f.level, "%d", lvl) then
        f.level:SetText("")
    end
    f.level:SetTextColor(1, 0.82, 0.2)
end

local function UpdateHealth(f)
    local s = GetSettings(); local u = f.unit
    if not (s and u) then return end
    local bar = f.health
    if f.isPet then
        bar:SetStatusBarColor(PET_GREEN[1], PET_GREEN[2], PET_GREEN[3])
    elseif s.classColorHealth then
        bar:SetStatusBarColor(UnitClassRGB(u))
    else
        bar:SetStatusBarColor(0.2, 0.75, 0.25)
    end
    if Bool(UnitIsConnected(u)) == false then
        bar:SetMinMaxValues(0, 1); bar:SetValue(0)
        f.status:SetText(PLAYER_OFFLINE or "Offline")
        return
    end
    if Bool(UnitIsDeadOrGhost(u)) then
        bar:SetMinMaxValues(0, 1); bar:SetValue(0)
        f.status:SetText(DEAD or "Dead")
        return
    end
    f.status:SetText("")
    pcall(bar.SetMinMaxValues, bar, 0, UnitHealthMax(u))
    pcall(bar.SetValue, bar, UnitHealth(u))
end

local function RoleOf(u)
    local r = UnitGroupRolesAssigned and UnitGroupRolesAssigned(u)
    if S(r) then return nil end
    return r
end

local function UpdateRole(f)
    local s = GetSettings(); local u = f.unit
    if not (s and u) or f.isPet then return end
    local atlas = s.showRole and ROLE_ATLAS[RoleOf(u) or ""]
    if atlas then
        f.role:SetAtlas(atlas)
        f.roleBox:Show()
    else
        f.roleBox:Hide()
    end
end

local function UpdatePower(f)
    local s = GetSettings(); local u = f.unit
    if not (s and u) or f.isPet then return end
    local want = s.powerFor == "all"
    if s.powerFor == "role" then
        local r = RoleOf(u)
        want = (r == "TANK" or r == "HEALER")
    end
    SetPowerShown(f, want, s)
    if not want then return end
    local ptype, token = UnitPowerType(u)
    if not S(ptype) then f.power:SetStatusBarColor(PowerRGB(token, ptype)) end
    pcall(f.power.SetMinMaxValues, f.power, 0, UnitPowerMax(u, ptype))
    pcall(f.power.SetValue, f.power, UnitPower(u, ptype))
end

local function UpdateTarget(f)
    local u = f.unit
    local isT = u and Bool(UnitIsUnit(u, "target")) or false
    f.isTarget = isT
    if isT then
        EdgeColor(f, 1, 1, 1, 1)
    else
        local _, edge = Colors()
        EdgeColor(f, edge[1], edge[2], edge[3], 1)
    end
end

local function UpdateRange(f)
    local s = GetSettings(); local u = f.unit
    if not (s and u) then return end
    if not s.rangeFade or Bool(UnitIsUnit(u, "player")) then f:SetAlpha(1) return end
    local ok, inRange = pcall(UnitInRange, u)
    if not ok then f:SetAlpha(1) return end
    if S(inRange) then
        if f.SetAlphaFromBoolean then pcall(f.SetAlphaFromBoolean, f, inRange, 1, 0.45) end
    else
        f:SetAlpha(inRange == false and 0.45 or 1)
    end
end

local function UpdateAll(f)
    if not f.unit then return end
    UpdateName(f); UpdateLevel(f); UpdateRole(f); UpdatePower(f); UpdateHealth(f)
    UpdateTarget(f); UpdateRange(f)
end

---------------------------------------------------------------------------
-- Secure headers
---------------------------------------------------------------------------
local function SetupButton(b, isPet)
    if b.h3zRFSetup then return end
    b.h3zRFSetup = true
    BuildCell(b, isPet)
    if not InCombatLockdown() then
        b:RegisterForClicks("AnyUp")
        b:SetAttribute("*type1", "target")
        b:SetAttribute("*type2", "togglemenu")
    end
    b:HookScript("OnAttributeChanged", function(self, name, value)
        if name ~= "unit" then return end
        if self.unit and byUnit[self.unit] == self then byUnit[self.unit] = nil end
        self.unit = value
        if value then
            byUnit[value] = self
            if self:IsVisible() then UpdateAll(self) end
        end
    end)
    b:HookScript("OnShow", function(self) UpdateAll(self) end)
    b:HookScript("OnEnter", function(self)
        if not self.unit then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    b.unit = b:GetAttribute("unit")
    if b.unit then byUnit[b.unit] = b end
    cells[#cells + 1] = b
end

local function CollectChildren(h, n, isPet)
    for i = 1, n do
        local b = h:GetAttribute("child" .. i)
        if b then SetupButton(b, isPet) end
    end
end

local function MakeHeader(name, template, isPet, group)
    local h = CreateFrame("Frame", name, container, template)
    local n = isPet and MAX_PETS or GROUP_SIZE
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    h:SetAttribute("showRaid", true)
    h:SetAttribute("showParty", false)
    h:SetAttribute("showPlayer", true)
    h:SetAttribute("showSolo", false)
    h:SetAttribute("point", "TOP")
    h:SetAttribute("unitsPerColumn", n)
    h:SetAttribute("maxColumns", 1)
    if group then h:SetAttribute("groupFilter", tostring(group)) end
    h:SetAttribute("initialConfigFunction", [[
        self:SetAttribute("*type1", "target")
        self:SetAttribute("*type2", "togglemenu")
    ]])
    -- create every button now (out of combat), so nothing has to be built in a fight
    h:SetAttribute("startingIndex", -(n - 1))
    h:Show()
    h:SetAttribute("startingIndex", 1)
    CollectChildren(h, n, isPet)
    return h
end

---------------------------------------------------------------------------
-- Preview (Layout Mode / /h3z0raid test): a fake 20-player raid with pets
---------------------------------------------------------------------------
local FAKE = {
    { "Xeno", "MONK", 0.45, "TANK" }, { "Grimjaw", "WARRIOR", 0.95, "TANK" }, { "Toxik", "MONK", 0.78, "HEALER" },
    { "Jarnan", "SHAMAN", 0.38 }, { "Stickymittens", "EVOKER", 0.6 },
    { "Delasteve", "PALADIN", 0.75, "HEALER" }, { "Burne", "DRUID", 0.98, "HEALER" }, { "Kulia", "PALADIN", 0.7, "HEALER" },
    { "Lily", "MONK", 0.7 }, { "Thiaspriest", "PRIEST", 1.0 },
    { "Pelleas", "SHAMAN", 0.45 }, { "Khardi", "HUNTER", 0.42 }, { "Morgath", "DEATHKNIGHT", 0.8 },
    { "Drakmoor", "DEMONHUNTER", 0.53 }, { "Embertide", "EVOKER", 0.47 },
    { "Elyndra", "MAGE", 0.62 }, { "Fenwick", "ROGUE", 0.85 }, { "Zulkhar", "WARLOCK", 0.68 },
    { "Luneth", "DRUID", 0.72 }, { "Stormhelm", "SHAMAN", 0.44 },
}
local FAKE_PETS = { { "Felhunter", 0.95 }, { "Ghoul", 0.4 }, { "Spirit Beast", 0.92 }, { "Water Elemental", 0.25 }, { "Imp", 0.6 } }
local CLASS_POWER = { WARRIOR = "RAGE", DRUID = "MANA", PALADIN = "MANA", MONK = "ENERGY", PRIEST = "MANA" }

local function FillFake(f, d, s, level)
    f.unit = nil
    f.name:SetText(d[1])
    if f.isPet then
        f.health:SetStatusBarColor(PET_GREEN[1], PET_GREEN[2], PET_GREEN[3])
        f.health:SetMinMaxValues(0, 1); f.health:SetValue(d[2])
        return
    end
    local r, g, b = ClassRGB(d[2])
    if s.classColorName then f.name:SetTextColor(r, g, b) else f.name:SetTextColor(1, 1, 1) end
    if s.classColorHealth then f.health:SetStatusBarColor(r, g, b) else f.health:SetStatusBarColor(0.2, 0.75, 0.25) end
    f.health:SetMinMaxValues(0, 1); f.health:SetValue(d[3])
    f.status:SetText("")
    f.level:SetShown(s.showLevel)
    f.level:SetText(tostring(level))
    f.level:SetTextColor(1, 0.82, 0.2)
    local atlas = s.showRole and d[4] and ROLE_ATLAS[d[4]]
    if atlas then f.role:SetAtlas(atlas); f.roleBox:Show() else f.roleBox:Hide() end
    local want = s.powerFor == "all" or (s.powerFor == "role" and d[4] ~= nil)
    SetPowerShown(f, want, s)
    if want then
        local token = CLASS_POWER[d[2]] or "MANA"
        f.power:SetStatusBarColor(PowerRGB(token))
        f.power:SetMinMaxValues(0, 1); f.power:SetValue(0.85)
    end
    local _, edge = Colors()
    EdgeColor(f, edge[1], edge[2], edge[3], 1)
end

local previewCells, previewPets = {}, {}

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function GroupHasMembers()
    local used = {}
    if IsInRaid() then
        for i = 1, (GetNumGroupMembers() or 0) do
            local _, _, sub = GetRaidRosterInfo(i)
            if sub and not S(sub) then used[sub] = true end
        end
    end
    return used
end

local function ColumnX(s, col)
    return (col - 1) * ((s.width or 150) + (s.groupSpacing or 6))
end

local function UpdateLabels(s, used, previewCols)
    for g = 1, MAX_GROUPS do
        local l = labels[g]
        if l then
            local show = s.showGroupNumbers and g <= (s.maxGroups or 8)
                and ((previewCols and g <= previewCols) or (not previewCols and used[g]))
            l:SetShown(show and true or false)
        end
    end
end

local function LastUsedColumn(s, used)
    local last = 0
    for g = 1, math.min(MAX_GROUPS, s.maxGroups or 8) do if used[g] then last = g end end
    return last
end

local function ApplyPreview(s)
    if not preview then return end
    local show = testMode and not IsInRaid() and s.enabled
    preview:SetShown(show and true or false)
    if not show then return end
    local w, h, sp = s.width or 150, s.height or 52, s.spacing or 4
    for i, d in ipairs(FAKE) do
        local f = previewCells[i]
        if not f then
            f = CreateFrame("Frame", nil, preview)
            BuildCell(f, false)
            previewCells[i] = f
        end
        local col, row = math.floor((i - 1) / GROUP_SIZE) + 1, (i - 1) % GROUP_SIZE
        f:SetSize(w, h)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", preview, "TOPLEFT", ColumnX(s, col), -LABEL_H - row * (h + sp))
        f.powerShown = nil
        LayoutCell(f, w, h, s)
        FillFake(f, d, s, 9)
        f:Show()
    end
    local pw, ph = s.petWidth or 110, s.petHeight or 26
    for i, d in ipairs(FAKE_PETS) do
        local f = previewPets[i]
        if not f then
            f = CreateFrame("Frame", nil, preview)
            BuildCell(f, true)
            previewPets[i] = f
        end
        f:SetSize(pw, ph)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", preview, "TOPLEFT", ColumnX(s, 5), -LABEL_H - (i - 1) * (ph + sp))
        LayoutCell(f, pw, ph, s)
        FillFake(f, d, s)
        f:SetShown(s.showPets and true or false)
    end
end

local function HideBlizzardRaid()
    local s = GetSettings()
    local hide = s and s.enabled and s.hideBlizzard
    local fr = _G.CompactRaidFrameContainer
    if not fr then return end
    pcall(fr.SetAlpha, fr, hide and 0 or 1)
    if not InCombatLockdown() and fr.EnableMouse then pcall(fr.EnableMouse, fr, not hide) end
    if not fr.h3zRFHooked then
        fr.h3zRFHooked = true
        fr:HookScript("OnShow", function() C_Timer.After(0, HideBlizzardRaid) end)
    end
end

local lastError       -- the last error while building / laying out the secure frames (/h3z0raid debug)

local function PreviewOn()
    return testMode and not IsInRaid()
end

-- the secure part: group headers and their buttons, the pet header
local function LayoutHeaders(s, enabled, w, h, sp, maxG, petCol)
    for g = 1, MAX_GROUPS do
        local hd = headers[g]
        if hd then
            for i = 1, GROUP_SIZE do
                local b = hd:GetAttribute("child" .. i)
                if b then
                    SetupButton(b, false)
                    b:SetSize(w, h)
                    b.powerShown = nil
                    LayoutCell(b, w, h, s)
                end
            end
            hd:SetAttribute("initialConfigFunction", string.format([[
                self:SetWidth(%d)
                self:SetHeight(%d)
                self:SetAttribute("*type1", "target")
                self:SetAttribute("*type2", "togglemenu")
            ]], w, h))
            hd:SetAttribute("yOffset", -sp)        -- also makes the header lay its buttons out again
            hd:ClearAllPoints()
            hd:SetPoint("TOPLEFT", container, "TOPLEFT", ColumnX(s, g), -LABEL_H)
            if enabled and g <= maxG then
                RegisterAttributeDriver(hd, "state-visibility", "[group:raid] show; hide")
            else
                UnregisterAttributeDriver(hd, "state-visibility")
                hd:Hide()
            end
        end
    end
    if petHeader then
        local pw, ph = s.petWidth or 110, s.petHeight or 26
        for i = 1, MAX_PETS do
            local b = petHeader:GetAttribute("child" .. i)
            if b then
                SetupButton(b, true)
                b:SetSize(pw, ph)
                LayoutCell(b, pw, ph, s)
            end
        end
        petHeader:SetAttribute("yOffset", -sp)
        petHeader:ClearAllPoints()
        petHeader:SetPoint("TOPLEFT", container, "TOPLEFT", ColumnX(s, math.max(1, petCol)), -LABEL_H)
        if enabled and s.showPets then
            RegisterAttributeDriver(petHeader, "state-visibility", "[group:raid] show; hide")
        else
            UnregisterAttributeDriver(petHeader, "state-visibility")
            petHeader:Hide()
        end
    end
end

local function ApplyLayout()
    local s = GetSettings()
    if not (s and container) then return end
    if InCombatLockdown() then layoutPending = true return end
    layoutPending = false

    pcall(HideBlizzardRaid)
    local enabled = s.enabled and true or false
    container:SetScale(s.scale or 1)
    container:Show()
    local w, h, sp = s.width or 150, s.height or 52, s.spacing or 4
    local maxG = math.max(1, math.min(MAX_GROUPS, s.maxGroups or 8))
    local used = GroupHasMembers()
    local prev = PreviewOn()

    -- size of the whole block (used by Layout Mode) and the group numbers
    local groupsUsed = prev and 4 or math.max(1, LastUsedColumn(s, used))
    local cols = groupsUsed + ((s.showPets and 1) or 0)
    container:SetSize(ColumnX(s, cols) + w, LABEL_H + GROUP_SIZE * h + (GROUP_SIZE - 1) * sp)
    for g = 1, MAX_GROUPS do
        local l = labels[g]
        if l then
            l:SetFont(Helpers.GetGeneralFont(), 11, Helpers.GetGeneralFontOutline())
            l:ClearAllPoints()
            l:SetPoint("BOTTOM", container, "TOPLEFT", ColumnX(s, g) + w / 2, -LABEL_H + 1)
        end
    end
    UpdateLabels(s, used, prev and 4 or nil)

    -- 0.24.5 fix: the preview does not depend on the secure frames any more
    local okP, errP = pcall(ApplyPreview, s)
    if not okP then lastError = errP end

    local petCol = prev and 5 or (LastUsedColumn(s, used) + 1)
    local okH, errH = pcall(LayoutHeaders, s, enabled, w, h, sp, maxG, petCol)
    if not okH then lastError = errH end

    for _, f in ipairs(cells) do if f:IsVisible() then pcall(UpdateAll, f) end end
end

local function SavePosition()
    local s = GetSettings()
    if not (s and container) then return end
    local point, _, relPoint, x, y = container:GetPoint()
    s.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition()
    local s = GetSettings()
    container:ClearAllPoints()
    local pos = s and s.pos
    if pos and pos.point then
        container:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -330)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local UNIT_HANDLERS = {
    UNIT_HEALTH = UpdateHealth,
    UNIT_MAXHEALTH = UpdateHealth,
    UNIT_CONNECTION = UpdateHealth,
    UNIT_FLAGS = UpdateHealth,
    UNIT_POWER_UPDATE = UpdatePower,
    UNIT_MAXPOWER = UpdatePower,
    UNIT_DISPLAYPOWER = UpdatePower,
    UNIT_NAME_UPDATE = UpdateName,
    UNIT_LEVEL = UpdateLevel,
}

local events = CreateFrame("Frame")
local rosterQueued = false
local function RosterChanged()
    rosterQueued = false
    local s = GetSettings()
    if not s then return end
    HideBlizzardRaid()
    if not InCombatLockdown() then
        ApplyLayout()
    else
        layoutPending = true
        for _, f in ipairs(cells) do if f:IsVisible() then UpdateAll(f) end end
    end
end

events:SetScript("OnEvent", function(_, event, unit)
    local fn = UNIT_HANDLERS[event]
    if fn then
        local f = unit and byUnit[unit]
        if f and f:IsVisible() then fn(f) end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        for _, f in ipairs(cells) do if f:IsVisible() then UpdateTarget(f) end end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if layoutPending then ApplyLayout() end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "UNIT_PET"
        or event == "PLAYER_ENTERING_WORLD" then
        if not rosterQueued then
            rosterQueued = true
            C_Timer.After(0.2, RosterChanged)
        end
    end
end)

-- range fade (UnitInRange has no event)
do
    local acc = 0
    events:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.3 then return end
        acc = 0
        if not IsInRaid() then return end
        for _, f in ipairs(cells) do if f:IsVisible() then UpdateRange(f) end end
    end)
end

local function Init()
    local s = GetSettings()
    if not s or container then return end
    if InCombatLockdown() then
        local w = CreateFrame("Frame")
        w:RegisterEvent("PLAYER_REGEN_ENABLED")
        w:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); Init() end)
        return
    end
    container = CreateFrame("Frame", "H3z0UI_RaidFrames", UIParent)
    container:SetFrameStrata("LOW")
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:SetSize(640, 300)
    RestorePosition()

    -- preview and group numbers first: they work even if a secure header can't be built
    preview = CreateFrame("Frame", nil, container)
    preview:SetAllPoints()
    preview:Hide()
    for g = 1, MAX_GROUPS do
        labels[g] = container:CreateFontString(nil, "OVERLAY")
        labels[g]:SetFont(Helpers.GetGeneralFont(), 11, Helpers.GetGeneralFontOutline())
        labels[g]:SetText(tostring(g))
        labels[g]:SetTextColor(0.85, 0.88, 0.9)
    end
    for g = 1, MAX_GROUPS do
        local ok, h = pcall(MakeHeader, "H3z0UI_RaidGroup" .. g, "SecureGroupHeaderTemplate", false, g)
        if ok then headers[g] = h else lastError = h end
    end
    local okP, ph = pcall(MakeHeader, "H3z0UI_RaidPets", "SecureGroupPetHeaderTemplate", true)
    if okP then petHeader = ph else lastError = ph end

    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_POWER_UPDATE",
        "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PET",
        "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
        "PLAYER_ENTERING_WORLD" }) do
        pcall(events.RegisterEvent, events, e)
    end
    ApplyLayout()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() C_Timer.After(0.8, Init) end)

_G.H3z0UI_RefreshRaidFrames = function() if container then ApplyLayout() end end
_G.H3z0UI_RaidFramesSetTest = function(on)
    if not container or InCombatLockdown() then return end
    testMode = on and true or false
    ApplyLayout()
end
_G.H3z0UI_RaidFramesIsTest = function() return testMode end
_G.H3z0UI_RaidFramesSavePosition = SavePosition

SLASH_H3Z0RAID1 = "/h3z0raid"
SlashCmdList["H3Z0RAID"] = function(msg)
    msg = (msg or ""):lower()
    if InCombatLockdown() then
        print("|cff34D399H3z0 UI:|r Raid frames can't be changed in combat.")
        return
    end
    if not container then pcall(Init) end
    if not container then
        print("|cff34D399H3z0 UI:|r Raid frames are not ready yet - try again in a moment.")
        return
    end
    if msg:match("^%s*debug") then
        local n = 0
        for g = 1, MAX_GROUPS do if headers[g] then n = n + 1 end end
        print(string.format("|cff34D399H3z0 UI|r raid frames: preview=%s shown=%s headers=%d/8 pets=%s cells=%d size=%dx%d",
            tostring(testMode), tostring(preview and preview:IsShown()), n, tostring(petHeader ~= nil), #cells,
            container:GetWidth() or 0, container:GetHeight() or 0))
        if lastError then print("  last error: " .. tostring(lastError)) end
        return
    end
    if msg:match("^%s*reset") then
        local s = GetSettings()
        if s then s.pos = nil end
        RestorePosition()
        print("|cff34D399H3z0 UI:|r Raid frames position reset.")
    elseif msg:match("^%s*test") then
        testMode = not testMode
        ApplyLayout()
        print("|cff34D399H3z0 UI:|r Raid frames preview " .. (testMode and "ON" or "OFF"))
    else
        print("|cff34D399H3z0 UI:|r /h3z0raid test - preview, /h3z0raid reset - reset position. Move them in H3z0 UI Layout Mode.")
    end
end
