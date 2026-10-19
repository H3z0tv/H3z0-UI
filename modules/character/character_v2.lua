--[[
    H3z0 UI - Character / Inspect "v2" look

    On top of the H3z0 character pane (and inspect pane):
      - header: name in class colour + title, then "Lv 90  [spec icon] Spec Class"
      - background: the character's homeland (race art from the game's dressing room
        backgrounds, class art as fallback), darkened at the edges so text stays readable
      - the H3z0 logo in the bottom-right corner

    Slots, section headers and the Item Level / Attributes / Enhancements blocks are
    done in character.lua (style "v2"). Settings: profile.character.style ("v2" | "classic").
]]

local ADDON_NAME, ns = ...
if ns.Client and ns.Client.isForever then return end

local V2 = {}
ns.CharacterV2 = V2

local LOGO = "Interface\\AddOns\\" .. ADDON_NAME .. "\\assets\\icon.tga"

local function Settings()
    local H = ns.Helpers
    return H and H.GetModuleDB and H.GetModuleDB("character")
end

local function IsV2()
    local s = Settings()
    return s and s.enabled ~= false and s.style ~= "classic"
end

local function Font()
    if _G.H3z0UI_GetFont then return _G.H3z0UI_GetFont() end
    return STANDARD_TEXT_FONT
end

local function Secret(v) return issecretvalue and v ~= nil and issecretvalue(v) or false end

local function ClassRGB(unit)
    local _, class = UnitClass(unit)
    local c = class and not Secret(class) and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.204, 0.827, 0.6
end

local function AtlasExists(name)
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        return ok and info ~= nil
    end
    return false
end

-- the homeland picture of the unit's race (class picture if the race has none)
local function BackgroundAtlas(unit)
    local _, raceFile = UnitRace(unit)
    local _, classFile = UnitClass(unit)
    local tries = {}
    if raceFile and not Secret(raceFile) then
        tries[#tries + 1] = "dressingroom-background-" .. strlower(raceFile)
    end
    if classFile and not Secret(classFile) then
        tries[#tries + 1] = "dressingroom-background-" .. strlower(classFile)
    end
    for _, a in ipairs(tries) do
        if AtlasExists(a) then return a end
    end
    return nil
end

local function SpecInfo(unit)
    if unit == "player" then
        local spec = GetSpecialization and GetSpecialization()
        if spec then
            local _, name, _, icon = GetSpecializationInfo(spec)
            return name, icon
        end
        return nil
    end
    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    if specID and specID > 0 and GetSpecializationInfoByID then
        local _, name, _, icon = GetSpecializationInfoByID(specID)
        return name, icon
    end
    return nil
end

local function TitleText(unit, name)
    if unit == "player" and GetCurrentTitle and GetTitleName then
        local id = GetCurrentTitle()
        if id and id > 0 then
            local t = GetTitleName(id)
            if t then return (strtrim(t:gsub("%%s", ""):gsub(",", ""))) end
        end
        return nil
    end
    local pvp = UnitPVPName(unit)
    if pvp and name and not Secret(pvp) and pvp ~= name then
        local t = pvp:gsub(name, ""):gsub(",", "")
        t = strtrim(t)
        if t ~= "" then return t end
    end
    return nil
end

---------------------------------------------------------------------------
-- Build the pieces once per frame
---------------------------------------------------------------------------
local function BgAnchor(frame)
    if frame == CharacterFrame then
        return _G.H3z0UI_CharacterFrameBg_CharPane or _G.H3z0UI_CharacterFrameBg_Skin or frame
    end
    return _G.H3z0UI_InspectFrameBg_Skin or frame
end

local function Build(frame)
    local v = frame.h3zV2
    if v then return v end
    v = {}
    frame.h3zV2 = v

    -- rounded window panel (replaces the square backdrop while v2 is on)
    if ns.Round then
        v.panel = ns.Round.Panel(frame, 10)
        v.panel:EnableMouse(false)
    end
    -- background (lowest level of the frame: below the model and the slots)
    v.bg = CreateFrame("Frame", nil, frame)
    v.bg:EnableMouse(false)
    v.fill = v.bg:CreateTexture(nil, "BACKGROUND", nil, 0)   -- Background Color under the art
    v.fill:SetAllPoints(v.bg)
    v.art = v.bg:CreateTexture(nil, "BACKGROUND", nil, 1)
    v.shadeTop = v.bg:CreateTexture(nil, "BACKGROUND", nil, 2)
    v.shadeTop:SetColorTexture(1, 1, 1, 1)
    v.shadeBottom = v.bg:CreateTexture(nil, "BACKGROUND", nil, 2)
    v.shadeBottom:SetColorTexture(1, 1, 1, 1)
    v.shadeLeft = v.bg:CreateTexture(nil, "BACKGROUND", nil, 2)
    v.shadeLeft:SetColorTexture(1, 1, 1, 1)
    v.shadeRight = v.bg:CreateTexture(nil, "BACKGROUND", nil, 2)
    v.shadeRight:SetColorTexture(1, 1, 1, 1)

    -- header
    v.head = CreateFrame("Frame", nil, frame)
    v.head:SetSize(420, 44)
    v.name = v.head:CreateFontString(nil, "OVERLAY")
    v.title = v.head:CreateFontString(nil, "OVERLAY")
    v.line2 = v.head:CreateFontString(nil, "OVERLAY")
    v.specIcon = v.head:CreateTexture(nil, "OVERLAY")
    v.specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- logo
    v.logoFrame = CreateFrame("Frame", nil, frame)
    v.logoFrame:SetSize(120, 30)
    v.logo = v.logoFrame:CreateTexture(nil, "OVERLAY")
    v.logo:SetTexture(LOGO)
    v.logo:SetSize(26, 26)
    v.logoText = v.logoFrame:CreateFontString(nil, "OVERLAY")
    return v
end

local function Layout(frame, v)
    local host = BgAnchor(frame)
    v.bg:ClearAllPoints()
    -- inset so the square art stays inside the panel's rounded corners
    v.bg:SetPoint("TOPLEFT", host, "TOPLEFT", 3, -3)
    v.bg:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3, 3)
    v.bg:SetFrameStrata(host:GetFrameStrata())
    v.bg:SetFrameLevel(math.max(0, host:GetFrameLevel() + 2))
    v.art:SetAllPoints(v.bg)
    -- soft rounded corners: our own rounded panel + the art and shades rounded to match
    if v.panel then
        local R = ns.Round
        v.panel:ClearAllPoints()
        v.panel:SetAllPoints(host)
        v.panel:SetFrameStrata(host:GetFrameStrata())
        v.panel:SetFrameLevel(math.max(0, host:GetFrameLevel() + 1))
        local f, b = R.SLATE_FILL, R.SLATE_BORDER
        v.panel:SetFillColor(f[1] * 0.7, f[2] * 0.7, f[3] * 0.7, 0.97)
        v.panel:SetBorderColor(b[1], b[2], b[3], 1)
        v.panel:SetRadius(10)
        v.panel:Show()
        if host ~= frame and host.SetAlpha then host:SetAlpha(0) end
    end

    -- 0.24.9: the Background Color option tints the panel (fill + edge shading) in v2 too
    local core = ns.Addon
    local gen = core and core.db and core.db.profile and core.db.profile.general
    local bc = (gen and gen.skinBgColor) or { 0, 0, 0, 0.95 }
    local br, bgc, bb = bc[1] or 0, bc[2] or 0, bc[3] or 0
    v.fill:SetColorTexture(br, bgc, bb, bc[4] or 0.95)
    local function C(a) return CreateColor(br, bgc, bb, a) end

    local h = 90
    v.shadeTop:ClearAllPoints()
    v.shadeTop:SetPoint("TOPLEFT"); v.shadeTop:SetPoint("TOPRIGHT"); v.shadeTop:SetHeight(h)
    v.shadeTop:SetGradient("VERTICAL", C(0), C(0.85))
    v.shadeBottom:ClearAllPoints()
    v.shadeBottom:SetPoint("BOTTOMLEFT"); v.shadeBottom:SetPoint("BOTTOMRIGHT"); v.shadeBottom:SetHeight(h)
    v.shadeBottom:SetGradient("VERTICAL", C(0.85), C(0))
    v.shadeLeft:ClearAllPoints()
    v.shadeLeft:SetPoint("TOPLEFT"); v.shadeLeft:SetPoint("BOTTOMLEFT"); v.shadeLeft:SetWidth(150)
    v.shadeLeft:SetGradient("HORIZONTAL", C(0.75), C(0))
    v.shadeRight:ClearAllPoints()
    v.shadeRight:SetPoint("TOPRIGHT"); v.shadeRight:SetPoint("BOTTOMRIGHT"); v.shadeRight:SetWidth(260)
    v.shadeRight:SetGradient("HORIZONTAL", C(0), C(0.88))

    local font = Font()
    -- header centred over the model area (between the slot columns)
    local model = (frame == CharacterFrame) and _G.CharacterModelScene or _G.InspectModelFrame
    v.head:ClearAllPoints()
    local mTop, fTop = model and model:GetTop(), frame:GetTop()
    if model and mTop and fTop then
        -- horizontally over the model, vertically at the window's top edge
        v.head:SetPoint("TOP", model, "TOP", 0, (fTop - mTop) - 6)
    else
        v.head:SetPoint("TOP", frame, "TOP", 0, -6)
    end
    v.head:SetFrameLevel(frame:GetFrameLevel() + 20)
    v.name:SetFont(font, 17, "OUTLINE")
    v.title:SetFont(font, 11, "OUTLINE")
    v.line2:SetFont(font, 12, "OUTLINE")
    v.name:ClearAllPoints()
    v.title:ClearAllPoints()
    v.line2:ClearAllPoints()
    v.specIcon:ClearAllPoints()
    v.name:SetPoint("TOP", v.head, "TOP", 0, 0)
    v.title:SetPoint("LEFT", v.name, "RIGHT", 6, -1)
    v.line2:SetPoint("TOP", v.name, "BOTTOM", 9, -5)
    v.specIcon:SetSize(16, 16)
    v.specIcon:SetPoint("RIGHT", v.line2, "LEFT", -4, 0)

    v.logoFrame:ClearAllPoints()
    v.logoFrame:SetPoint("BOTTOMLEFT", v.bg, "BOTTOMLEFT", 12, 8)
    v.logoFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
    v.logoText:SetFont(font, 20, "OUTLINE")
    v.logo:ClearAllPoints()
    v.logo:SetPoint("LEFT", v.logoFrame, "LEFT", 0, 0)
    v.logoText:ClearAllPoints()
    v.logoText:SetPoint("LEFT", v.logo, "RIGHT", 4, 0)
    v.logoText:SetText("H3Z0 UI")
    v.logoText:SetTextColor(0.85, 0.88, 0.92, 0.55)
    v.logo:SetAlpha(0.6)
end

function V2.Update(frame, unit)
    if not frame then return end
    local on = IsV2()
    local v = frame.h3zV2
    if not on then
        if v then
            v.bg:Hide(); v.head:Hide(); v.logoFrame:Hide()
            if v.panel then v.panel:Hide() end
            local host = BgAnchor(frame)
            if host ~= frame and host.SetAlpha then host:SetAlpha(1) end
        end
        return
    end
    unit = unit or "player"
    if not UnitExists(unit) then return end
    -- character frame: only on the Character tab (Reputation / Currency keep their own look)
    if frame == CharacterFrame and PaperDollFrame and not PaperDollFrame:IsShown() then
        if v then
            v.bg:Hide(); v.head:Hide(); v.logoFrame:Hide()
            if v.panel then v.panel:Hide() end
            local host = BgAnchor(frame)
            if host ~= frame and host.SetAlpha then host:SetAlpha(1) end
        end
        return
    end
    v = Build(frame)
    Layout(frame, v)

    local atlas = BackgroundAtlas(unit)
    if atlas then
        v.art:SetAtlas(atlas)
        v.art:SetAlpha(0.75)
        v.art:Show()
    else
        v.art:Hide()
    end
    v.bg:Show()

    local name = UnitName(unit)
    local r, g, b = ClassRGB(unit)
    if not pcall(v.name.SetText, v.name, name or "") then v.name:SetText("") end
    v.name:SetTextColor(r, g, b, 1)
    local title = (name and not Secret(name)) and TitleText(unit, name) or nil
    v.title:SetText(title or "")
    v.title:SetTextColor(0.55, 0.9, 0.45, 1)
    v.title:SetShown(title ~= nil)

    local level = UnitLevel(unit)
    local specName, specIcon = SpecInfo(unit)
    local className = UnitClass(unit)
    local lvlText = (level and not Secret(level) and level > 0) and ("Lv " .. level) or ""
    -- item level next to the level (player: equipped, inspect: the inspected player's)
    local ilvl
    if unit == "player" then
        local _, equipped = GetAverageItemLevel()
        ilvl = equipped
    elseif C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local okI, val = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if okI then ilvl = val end
    end
    if ilvl and not Secret(ilvl) and ilvl > 0 then
        lvlText = lvlText .. string.format("   |cffffd100%.1f|r |cff9aa3adilvl|r", ilvl)
    end
    v.line2:SetText(string.format("%s   |cff%02x%02x%02x%s%s|r", lvlText,
        math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
        specName and (specName .. " ") or "", className or ""))
    v.line2:SetTextColor(0.92, 0.94, 0.97, 1)
    if specIcon then v.specIcon:SetTexture(specIcon); v.specIcon:Show() else v.specIcon:Hide() end
    v.head:Show()
    v.logoFrame:Show()
end

---------------------------------------------------------------------------
-- Inspect: keep its old title pieces out of the way and update on inspect data
---------------------------------------------------------------------------
local function UpdateInspect()
    if not (InspectFrame and InspectFrame:IsShown()) then return end
    local on = IsV2()
    if InspectFrame._h3z0uiILvlDisplay then InspectFrame._h3z0uiILvlDisplay:SetShown(not on) end
    if InspectFrame._h3z0uiCenterILvl then InspectFrame._h3z0uiCenterILvl:SetShown(not on) end
    if InspectFrame._h3z0uiILvlDisplay and InspectFrame._h3z0uiILvlDisplay.specText then
        InspectFrame._h3z0uiILvlDisplay.specText:SetShown(not on)
    end
    pcall(V2.Update, InspectFrame, InspectFrame.unit or "target")
end
V2.UpdateInspect = UpdateInspect
_G.H3z0UI_RefreshCharacterV2 = function()
    if CharacterFrame and CharacterFrame:IsShown() then pcall(V2.Update, CharacterFrame, "player") end
    UpdateInspect()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("INSPECT_READY")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_InspectUI" and InspectFrame then
            InspectFrame:HookScript("OnShow", function() C_Timer.After(0.35, UpdateInspect) end)
        end
        return
    end
    if event == "INSPECT_READY" then
        C_Timer.After(0.2, UpdateInspect)
        C_Timer.After(0.8, UpdateInspect)
    elseif CharacterFrame and CharacterFrame:IsShown() then
        C_Timer.After(0.2, function() pcall(V2.Update, CharacterFrame, "player") end)
    end
end)
if CharacterFrame then
    CharacterFrame:HookScript("OnShow", function() C_Timer.After(0.25, function() pcall(V2.Update, CharacterFrame, "player") end) end)
end
if PaperDollFrame then
    PaperDollFrame:HookScript("OnShow", function() C_Timer.After(0.05, function() pcall(V2.Update, CharacterFrame, "player") end) end)
    PaperDollFrame:HookScript("OnHide", function() pcall(V2.Update, CharacterFrame, "player") end)
end
if InspectFrame then
    InspectFrame:HookScript("OnShow", function() C_Timer.After(0.35, UpdateInspect) end)
end
