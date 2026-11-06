local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Tooltip extras (0.27.5): colours by type, health bar styling, fonts per
-- line, anchors per kind of tooltip, and icons on the name line.
-- Everything is off or neutral by default. Settings live in profile.tooltip
-- with keys that start with "tx".
---------------------------------------------------------------------------
local Helpers = ns.Helpers
local Extras = {}
ns.H3z0UI_TooltipExtras = Extras

local DEFAULTS = {
    txBorderBy = "off",        -- off | unit | quality | both
    txTintBg = false,
    txBarHeight = 0,           -- 0 = the game's height
    txBarColor = "default",    -- default | class | reaction
    txBarText = "none",        -- none | value | percent | both
    txBarTextSize = 10,
    txFontName = 0,            -- 0 = leave alone
    txFontGuild = 0,
    txFontDetail = 0,
    txFontOutline = false,
    txAnchorUnits = "inherit", -- inherit | cursor | fixed
    txAnchorFrames = "inherit",
    txIcons = false,
}

local function Settings()
    local p = ns.TooltipProvider
    return p and p.GetSettings and p:GetSettings() or nil
end

local function Opt(key)
    local s = Settings()
    local v = s and s[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

local function Secret(v)
    return Helpers and Helpers.IsSecretValue and Helpers.IsSecretValue(v)
end

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function IsTooltipOK(tooltip)
    if not tooltip then return false end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return false end
    return true
end

local function TooltipUnit(tooltip)
    if not (tooltip and tooltip.GetUnit) then return nil end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or unit == nil or Secret(unit) then return nil end
    return unit
end

---------------------------------------------------------------------------
-- colours by type
---------------------------------------------------------------------------
local function UnitTint(unit)
    if not unit then return nil end
    local isPlayer = Safe(UnitIsPlayer, unit)
    if Secret(isPlayer) then isPlayer = nil end
    if isPlayer then
        local _, class = Safe(UnitClass, unit)
        if class and not Secret(class) then
            local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
                or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
            if c and type(c.r) == "number" then return c.r, c.g, c.b end
        end
    end
    local r, g, b = Safe(UnitSelectionColor, unit)
    if type(r) == "number" and not Secret(r) and not Secret(g) and not Secret(b) then
        return r, g, b
    end
    return nil
end

local function ItemTint(tooltip)
    if not (tooltip and tooltip.GetItem) then return nil end
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if not ok or not link or Secret(link) then return nil end
    local q = C_Item and C_Item.GetItemQualityByID and Safe(C_Item.GetItemQualityByID, link)
    if not q then
        local okInfo, _, _, quality = pcall(GetItemInfo, link)
        if okInfo then q = quality end
    end
    if type(q) ~= "number" or Secret(q) then return nil end
    local r, g, b
    if C_Item and C_Item.GetItemQualityColor then
        r, g, b = C_Item.GetItemQualityColor(q)
    elseif ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
        local c = ITEM_QUALITY_COLORS[q]
        r, g, b = c.r, c.g, c.b
    end
    if r then return r, g, b end
    return nil
end

-- called by the tooltip skin when it draws the border: returns r, g, b of the
-- border (or nil to keep the normal colour) and whether to tint the background
function Extras.Override(tooltip)
    local t = tooltip and tooltip._h3zTint
    if not t then return nil end
    return t[1], t[2], t[3], Opt("txTintBg")
end

local function Restyle(tooltip)
    if ns.H3z0UI_RestyleTooltip then pcall(ns.H3z0UI_RestyleTooltip, tooltip) end
end

local function ApplyTint(tooltip, r, g, b)
    if r then
        -- the game refreshes a unit tooltip several times a second while you hover: the same
        -- colour is not drawn again (the border was rebuilt twice for every refresh)
        local cur = tooltip._h3zTint
        if cur and cur[1] == r and cur[2] == g and cur[3] == b then return end
        local tint = { r, g, b }
        tooltip._h3zTint = tint
        -- once more a moment later, when the tooltip has its final size
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if tooltip._h3zTint == tint and tooltip:IsShown() then Restyle(tooltip) end
            end)
        end
    else
        if not tooltip._h3zTint then return end
        tooltip._h3zTint = nil
    end
    Restyle(tooltip)
end

---------------------------------------------------------------------------
-- health bar
---------------------------------------------------------------------------
local barText
local function BarFS()
    local bar = GameTooltipStatusBar
    if not bar then return nil end
    if not barText then
        barText = bar:CreateFontString(nil, "OVERLAY")
        barText:SetPoint("CENTER", bar, "CENTER", 0, 0)
        barText:SetJustifyH("CENTER")
    end
    return barText
end

local function FontPath()
    return (Helpers and Helpers.GetGeneralFont and Helpers.GetGeneralFont()) or STANDARD_TEXT_FONT
end

local function UpdateBarText()
    local fs = barText
    local bar = GameTooltipStatusBar
    if not (fs and bar) then return end
    local mode = Opt("txBarText")
    local unit = bar._h3zUnit
    if mode == "none" or not unit or not bar:IsShown() then fs:SetText("") return end
    local text, pct
    if mode == "value" or mode == "both" then
        local cur = Safe(UnitHealth, unit)
        local txt = cur ~= nil and Safe(AbbreviateNumbers, cur) or nil
        if txt ~= nil then text = txt end
    end
    local pctOK = false
    if mode == "percent" or mode == "both" then
        if UnitHealthPercent then
            local curve = CurveConstants and CurveConstants.ScaleTo100
            pct = Safe(UnitHealthPercent, unit, true, curve)
            pctOK = pct ~= nil and (curve ~= nil or (not Secret(pct)))
        end
    end
    local shown = false
    if text ~= nil and pctOK then
        local fmt = "%s | %.0f%%"
        local v = pct
        if not (CurveConstants and CurveConstants.ScaleTo100) and type(v) == "number" and v <= 1 then v = v * 100 end
        shown = pcall(fs.SetFormattedText, fs, fmt, text, v)
    elseif text ~= nil then
        shown = pcall(fs.SetText, fs, text)
    elseif pctOK then
        local v = pct
        if not (CurveConstants and CurveConstants.ScaleTo100) and type(v) == "number" and v <= 1 then v = v * 100 end
        shown = pcall(fs.SetFormattedText, fs, "%.0f%%", v)
    end
    if not shown then fs:SetText("") end
end

local function StyleBar(tooltip, unit)
    local bar = GameTooltipStatusBar
    if not (bar and IsTooltipOK(bar)) then return end
    local s = Settings()
    if not s or s.hideHealthBar then return end
    if (tonumber(Opt("txBarHeight")) or 0) <= 0 and Opt("txBarColor") == "default" and Opt("txBarText") == "none" then return end
    bar:SetAlpha(1)
    local h = tonumber(Opt("txBarHeight")) or 0
    if h > 0 then pcall(bar.SetHeight, bar, h) end
    local tex = Helpers and Helpers.GetGeneralTexture and Helpers.GetGeneralTexture()
    if tex and h > 0 then pcall(bar.SetStatusBarTexture, bar, tex) end
    local mode = Opt("txBarColor")
    if mode ~= "default" then
        local r, g, b
        if mode == "class" or mode == "reaction" then
            r, g, b = UnitTint(unit)
            if mode == "reaction" and unit then
                local rr, gg, bb = Safe(UnitSelectionColor, unit)
                if type(rr) == "number" and not Secret(rr) then r, g, b = rr, gg, bb end
            end
        end
        if r then pcall(bar.SetStatusBarColor, bar, r, g, b) end
    end
    bar._h3zUnit = unit
    local fs = BarFS()
    if fs then
        local size = tonumber(Opt("txBarTextSize")) or 10
        pcall(fs.SetFont, fs, FontPath(), size, "OUTLINE")
        UpdateBarText()
        if C_Timer and C_Timer.After then C_Timer.After(0, UpdateBarText) end
    end
    if not bar._h3zHooked then
        bar._h3zHooked = true
        bar:HookScript("OnValueChanged", UpdateBarText)
        bar:HookScript("OnShow", function(self)
            local hh = tonumber(Opt("txBarHeight")) or 0
            if hh > 0 and self._h3zUnit then pcall(self.SetHeight, self, hh) end
            UpdateBarText()
        end)
        bar:HookScript("OnHide", function() if barText then barText:SetText("") end end)
    end
end

---------------------------------------------------------------------------
-- fonts per line, icons on the name line
---------------------------------------------------------------------------
local function ApplyLineFont(line, size, outline, fallbackObject)
    if not line then return false end
    if size and size > 0 then
        pcall(line.SetFont, line, FontPath(), size, outline and "OUTLINE" or "")
        line._h3zFont = true
        Extras.fontsTouched = true
        return true
    elseif line._h3zFont then
        line._h3zFont = nil
        if fallbackObject then pcall(line.SetFontObject, line, fallbackObject) end
        return true
    end
    return false
end

local ROLE_ATLAS = {
    TANK = "|A:roleicon-tiny-tank:14:14|a",
    HEALER = "|A:roleicon-tiny-healer:14:14|a",
    DAMAGER = "|A:roleicon-tiny-dps:14:14|a",
}

local function NameIcons(unit)
    local parts = {}
    local idx = Safe(GetRaidTargetIndex, unit)
    if type(idx) == "number" and not Secret(idx) and idx >= 1 and idx <= 8 then
        parts[#parts + 1] = ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:14|t"):format(idx)
    end
    local role = Safe(UnitGroupRolesAssigned, unit)
    if type(role) == "string" and not Secret(role) and ROLE_ATLAS[role] then
        parts[#parts + 1] = ROLE_ATLAS[role]
    end
    return table.concat(parts, "")
end

local function StyleLines(tooltip, unit)
    local lines = tooltip == GameTooltip and "GameTooltipTextLeft" or nil
    if not lines then return false end
    local changed = false
    local outline = Opt("txFontOutline")
    local nameSize = tonumber(Opt("txFontName")) or 0
    local guildSize = tonumber(Opt("txFontGuild")) or 0
    local detailSize = tonumber(Opt("txFontDetail")) or 0

    local guild
    if guildSize > 0 and unit then
        guild = Safe(GetGuildInfo, unit)
        if Secret(guild) then guild = nil end
    end

    local n = tooltip.NumLines and tooltip:NumLines() or 0
    if Secret(n) then return false end
    for i = 1, n do
        local line = _G[lines .. i]
        if line then
            if i == 1 then
                if ApplyLineFont(line, nameSize, outline, GameTooltipHeaderText) then changed = true end
            else
                local isGuild = false
                if guild then
                    local ok, txt = pcall(line.GetText, line)
                    if ok and type(txt) == "string" and not Secret(txt) and i <= 3 and txt:find(guild, 1, true) then
                        isGuild = true
                    end
                end
                if isGuild then
                    if ApplyLineFont(line, guildSize, outline, GameTooltipText) then changed = true end
                else
                    if ApplyLineFont(line, detailSize, outline, GameTooltipText) then changed = true end
                end
            end
        end
    end

    if Opt("txIcons") and unit then
        local icons = NameIcons(unit)
        local line = _G[lines .. 1]
        if icons ~= "" and line then
            local ok, txt = pcall(line.GetText, line)
            if ok and type(txt) == "string" and not Secret(txt) and txt:sub(1, 2) ~= "|T" and txt:sub(1, 2) ~= "|A" then
                if pcall(line.SetText, line, icons .. " " .. txt) then changed = true end
            end
        end
    end
    return changed
end

---------------------------------------------------------------------------
-- anchor: per kind of tooltip. returns true (cursor), false (fixed spot) or
-- nil (the general setting decides)
---------------------------------------------------------------------------
function Extras.AnchorOverride(parent)
    local key = (parent == UIParent or parent == nil) and "txAnchorUnits" or "txAnchorFrames"
    local v = Opt(key)
    if v == "cursor" then return true end
    if v == "fixed" then return false end
    return nil
end

---------------------------------------------------------------------------
-- hooks
---------------------------------------------------------------------------
local function OnUnit(tooltip)
    if not IsTooltipOK(tooltip) then return end
    local s = Settings()
    if not s or not s.enabled then return end
    local unit = TooltipUnit(tooltip)
    local by = Opt("txBorderBy")
    if tooltip == GameTooltip or tooltip == ItemRefTooltip then
        if (by == "unit" or by == "both") and unit then
            ApplyTint(tooltip, UnitTint(unit))
        else
            ApplyTint(tooltip, nil)
        end
    end
    if tooltip == GameTooltip then
        pcall(StyleBar, tooltip, unit)
    end
end

local function FontOptionsUsed()
    return (tonumber(Opt("txFontName")) or 0) > 0 or (tonumber(Opt("txFontGuild")) or 0) > 0
        or (tonumber(Opt("txFontDetail")) or 0) > 0 or Opt("txIcons") and true or false
end

local function OnAny(tooltip)
    if tooltip ~= GameTooltip or not IsTooltipOK(tooltip) then return end
    local s = Settings()
    if not s or not s.enabled then return end
    -- nothing to do (and nothing touched) unless one of these options is on, or a line
    -- still carries a size we set earlier
    if not FontOptionsUsed() and not Extras.fontsTouched then return end
    -- group finder and other addon tooltips are left alone: they lay out their own text
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    local unit = TooltipUnit(tooltip)
    if not unit and owner and owner ~= UIParent then
        local ok, name = pcall(owner.GetName, owner)
        if ok and type(name) == "string" and (name:find("^LFG") or name:find("^PVEFrame") or name:find("^Raider") or name:find("^RIO")) then return end
    end
    local changed = StyleLines(tooltip, unit)
    -- new font sizes change the size of the text: let the game fit the tooltip again
    if changed and tooltip.UpdateTooltipSize and not InCombatLockdown() then pcall(tooltip.UpdateTooltipSize, tooltip) end
end

local function OnItem(tooltip)
    if not IsTooltipOK(tooltip) then return end
    local s = Settings()
    if not s or not s.enabled then return end
    local by = Opt("txBorderBy")
    if by == "quality" or by == "both" then
        ApplyTint(tooltip, ItemTint(tooltip))
    else
        ApplyTint(tooltip, nil)
    end
end

local function Clear(tooltip)
    if tooltip and tooltip._h3zTint then
        tooltip._h3zTint = nil
        tooltip._h3zTintDirty = true   -- draw the normal border again the next time it opens
    end
end

local function OnShowTip(tooltip)
    if tooltip and tooltip._h3zTintDirty then
        tooltip._h3zTintDirty = nil
        Restyle(tooltip)
    end
end

local function Setup()
    if Extras.ready then return end
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then return end
    Extras.ready = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip) pcall(OnUnit, tooltip) end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip) pcall(OnItem, tooltip) end)
    if TooltipDataProcessor.AllTypes then
        TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip) pcall(OnAny, tooltip) end)
    end
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local tip = _G[name]
        if tip and tip.HookScript then
            tip:HookScript("OnHide", Clear)
            tip:HookScript("OnShow", OnShowTip)
        end
    end
end

if ns.WhenLoggedIn then ns.WhenLoggedIn(Setup) else
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", Setup)
end

ns.H3z0UI_TooltipAnchorOverride = Extras.AnchorOverride
Extras._OnUnit, Extras._OnItem, Extras._OnAny = OnUnit, OnItem, OnAny

---------------------------------------------------------------------------
-- settings (added to the Tooltip page)
---------------------------------------------------------------------------
function Extras.BuildSettings(L, tooltip, row, Refresh, RefreshSkin)
    local GUI = H3z0UI and H3z0UI.GUI
    if not (GUI and L and L.headerAt and L.sectionAt) then return end
    local function Drop(s, key, list, desc, refresh)
        return GUI:CreateFormDropdown(s.frame, nil, list, key, tooltip, refresh or Refresh, { description = desc })
    end
    local function Slide(s, key, lo, hi, step, desc, refresh)
        return GUI:CreateFormSlider(s.frame, nil, lo, hi, step, key, tooltip, refresh or Refresh, { description = desc })
    end
    local function Check(s, key, desc, refresh)
        return GUI:CreateFormCheckbox(s.frame, nil, key, tooltip, refresh or Refresh, { description = desc })
    end
    for k, v in pairs(DEFAULTS) do if tooltip[k] == nil then tooltip[k] = v end end

    L.headerAt("Colours by Type")
    local s1 = L.sectionAt()
    s1.AddRow(
        row(s1.frame, "Border Colour By", Drop(s1, "txBorderBy", {
            { value = "off", text = "Off (normal border)" },
            { value = "unit", text = "Unit (class or reaction)" },
            { value = "quality", text = "Item quality" },
            { value = "both", text = "Unit and item quality" },
        }, "Colour the tooltip border by the kind of unit you hover (class colour for players, reaction colour for NPCs) and by the quality of an item.", RefreshSkin)),
        row(s1.frame, "Tint the Background Too", Check(s1, "txTintBg", "Give the tooltip background a faint touch of the same colour.", RefreshSkin)))
    L.closeSection(s1)

    L.headerAt("Health Bar")
    local s2 = L.sectionAt()
    s2.AddRow(
        row(s2.frame, "Bar Height (0 = default)", Slide(s2, "txBarHeight", 0, 24, 1, "Height of the tooltip health bar. Needs Hide Health Bar to be off.")),
        row(s2.frame, "Bar Colour", Drop(s2, "txBarColor", {
            { value = "default", text = "Default" },
            { value = "class", text = "Class colour" },
            { value = "reaction", text = "Reaction colour" },
        }, "Colour of the health bar.")))
    s2.AddRow(
        row(s2.frame, "Text On the Bar", Drop(s2, "txBarText", {
            { value = "none", text = "None" },
            { value = "value", text = "Health" },
            { value = "percent", text = "Percent" },
            { value = "both", text = "Health and percent" },
        }, "Show the health on the bar.")),
        row(s2.frame, "Bar Text Size", Slide(s2, "txBarTextSize", 7, 20, 1, "Size of the text on the bar.")))
    L.closeSection(s2)

    L.headerAt("Fonts per Line")
    local s3 = L.sectionAt()
    s3.AddRow(
        row(s3.frame, "Name Line Size (0 = default)", Slide(s3, "txFontName", 0, 28, 1, "Font size of the first line (the name).")),
        row(s3.frame, "Guild Line Size (0 = default)", Slide(s3, "txFontGuild", 0, 24, 1, "Font size of the guild line on player tooltips.")))
    s3.AddRow(
        row(s3.frame, "Other Lines Size (0 = default)", Slide(s3, "txFontDetail", 0, 24, 1, "Font size of every other line.")),
        row(s3.frame, "Outline On Those Lines", Check(s3, "txFontOutline", "Draw the lines with an outline.")))
    L.closeSection(s3)

    L.headerAt("Anchors and Icons")
    local s4 = L.sectionAt()
    local anchorList = {
        { value = "inherit", text = "As set above" },
        { value = "cursor", text = "Follow the cursor" },
        { value = "fixed", text = "Fixed spot" },
    }
    s4.AddRow(
        row(s4.frame, "Units In the World", Drop(s4, "txAnchorUnits", anchorList, "Where the tooltip goes when you hover a unit or object in the world.")),
        row(s4.frame, "Frames and Buttons", Drop(s4, "txAnchorFrames", anchorList, "Where the tooltip goes when you hover an action button, a frame or a bag item.")))
    s4.AddRow(
        row(s4.frame, "Icons On the Name Line", Check(s4, "txIcons", "Show the raid marker and the group role in front of the name.")))
    L.closeSection(s4)
end
