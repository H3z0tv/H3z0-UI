--[[
    H3z0 UI - Character / Inspect background and logo

    On the character pane (Character tab) and the inspect pane:
      - background: the character's homeland (race art from the game's dressing
        room backgrounds, class art as fallback), darkened at the edges so the
        slots and stats stay readable
      - the H3z0 logo with "H3z0 UI" in the bottom-right corner

    Settings: profile.character.h3zBackground, profile.character.h3zLogo (both on by default)
]]

local ADDON_NAME, ns = ...

local CB = {}
ns.H3z0CharacterBackground = CB

local LOGO = "Interface\\AddOns\\H3z0UI\\assets\\icon.tga"

local function Secret(v) return issecretvalue and v ~= nil and issecretvalue(v) or false end

local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.character = p.character or {}
    local s = p.character
    if s.h3zBackground == nil then s.h3zBackground = true end
    if s.h3zLogo == nil then s.h3zLogo = true end
    return s
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

local function Host(frame)
    if frame == CharacterFrame then
        return _G.H3z0UI_CharacterFrameBg_Skin or frame
    end
    return _G.H3z0UI_InspectFrameBg_Skin or frame
end

local function Font()
    local H = ns.Helpers
    if H and H.GetGeneralFont then
        local ok, f = pcall(H.GetGeneralFont)
        if ok and f then return f end
    end
    return STANDARD_TEXT_FONT
end

local function BgColor()
    local core = ns.Addon
    local gen = core and core.db and core.db.profile and core.db.profile.general
    local bc = gen and gen.skinBgColor
    if type(bc) == "table" then return bc[1] or 0, bc[2] or 0, bc[3] or 0 end
    return 0, 0, 0
end

local function Build(frame)
    local v = frame.h3zCharBg
    if v then return v end
    v = {}
    frame.h3zCharBg = v

    v.bg = CreateFrame("Frame", nil, frame)
    v.bg:EnableMouse(false)
    v.art = v.bg:CreateTexture(nil, "BACKGROUND", nil, 1)
    v.shades = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        local t = v.bg:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetColorTexture(1, 1, 1, 1)
        v.shades[side] = t
    end

    v.logoFrame = CreateFrame("Frame", nil, frame)
    v.logoFrame:SetSize(130, 30)
    v.logoFrame:EnableMouse(false)
    v.logo = v.logoFrame:CreateTexture(nil, "OVERLAY")
    v.logo:SetTexture(LOGO)
    v.logo:SetSize(26, 26)
    v.logoText = v.logoFrame:CreateFontString(nil, "OVERLAY")
    return v
end

local function Layout(frame, v)
    local host = Host(frame)
    v.bg:ClearAllPoints()
    v.bg:SetPoint("TOPLEFT", host, "TOPLEFT", 3, -3)
    v.bg:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3, 3)
    v.bg:SetFrameStrata(host:GetFrameStrata())
    v.bg:SetFrameLevel((host:GetFrameLevel() or 0) + 1)
    v.art:SetAllPoints(v.bg)

    local r, g, b = BgColor()
    local function C(a) return CreateColor(r, g, b, a) end
    local s = v.shades
    s.top:ClearAllPoints(); s.top:SetPoint("TOPLEFT"); s.top:SetPoint("TOPRIGHT"); s.top:SetHeight(90)
    s.top:SetGradient("VERTICAL", C(0), C(0.85))
    s.bottom:ClearAllPoints(); s.bottom:SetPoint("BOTTOMLEFT"); s.bottom:SetPoint("BOTTOMRIGHT"); s.bottom:SetHeight(90)
    s.bottom:SetGradient("VERTICAL", C(0.85), C(0))
    s.left:ClearAllPoints(); s.left:SetPoint("TOPLEFT"); s.left:SetPoint("BOTTOMLEFT"); s.left:SetWidth(170)
    s.left:SetGradient("HORIZONTAL", C(0.8), C(0))
    s.right:ClearAllPoints(); s.right:SetPoint("TOPRIGHT"); s.right:SetPoint("BOTTOMRIGHT"); s.right:SetWidth(300)
    s.right:SetGradient("HORIZONTAL", C(0), C(0.9))

    -- logo: bottom-right corner, above the tab row
    v.logoFrame:ClearAllPoints()
    v.logoFrame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -14, frame == CharacterFrame and 44 or 12)
    v.logoFrame:SetFrameStrata(frame:GetFrameStrata())
    v.logoFrame:SetFrameLevel((frame:GetFrameLevel() or 0) + 20)
    v.logoText:SetFont(Font(), 18, "OUTLINE")
    v.logoText:ClearAllPoints()
    v.logoText:SetPoint("RIGHT", v.logoFrame, "RIGHT", 0, 0)
    v.logoText:SetText("H3z0 UI")
    v.logoText:SetTextColor(0.85, 0.88, 0.92, 0.6)
    v.logo:ClearAllPoints()
    v.logo:SetPoint("RIGHT", v.logoText, "LEFT", -4, 0)
    v.logo:SetAlpha(0.65)
end

local function HideAll(frame)
    local v = frame and frame.h3zCharBg
    if v then v.bg:Hide(); v.logoFrame:Hide() end
end

function CB.Update(frame, unit)
    if not frame then return end
    local s = Settings()
    if not s or (not s.h3zBackground and not s.h3zLogo) then HideAll(frame) return end
    unit = unit or "player"
    if not UnitExists(unit) then return end
    -- character frame: only on the Character tab (Reputation / Currency keep their own look)
    if frame == CharacterFrame and PaperDollFrame and not PaperDollFrame:IsShown() then
        HideAll(frame)
        return
    end
    local v = Build(frame)
    Layout(frame, v)

    local atlas = s.h3zBackground and BackgroundAtlas(unit)
    if atlas then
        v.art:SetAtlas(atlas)
        v.art:SetAlpha(0.75)
        v.art:Show()
        for _, t in pairs(v.shades) do t:Show() end
        v.bg:Show()
    else
        v.bg:Hide()
    end
    v.logoFrame:SetShown(s.h3zLogo and true or false)
end

local function UpdateCharacter()
    if CharacterFrame and CharacterFrame:IsShown() then pcall(CB.Update, CharacterFrame, "player") end
end

local function UpdateInspect()
    if InspectFrame and InspectFrame:IsShown() then
        pcall(CB.Update, InspectFrame, InspectFrame.unit or "target")
    end
end

function CB.RefreshAll()
    UpdateCharacter()
    UpdateInspect()
end
_G.H3z0UI_RefreshCharacterBackground = CB.RefreshAll

local inspectHooked = false
local function HookInspect()
    if inspectHooked or not InspectFrame then return end
    inspectHooked = true
    InspectFrame:HookScript("OnShow", function() C_Timer.After(0.35, UpdateInspect) end)
    InspectFrame:HookScript("OnHide", function() HideAll(InspectFrame) end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("INSPECT_READY")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_InspectUI" then HookInspect() end
        return
    end
    if event == "PLAYER_LOGIN" then
        if CharacterFrame then
            CharacterFrame:HookScript("OnShow", function() C_Timer.After(0.25, UpdateCharacter) end)
        end
        if PaperDollFrame then
            PaperDollFrame:HookScript("OnShow", function() C_Timer.After(0.05, UpdateCharacter) end)
            PaperDollFrame:HookScript("OnHide", function() pcall(CB.Update, CharacterFrame, "player") end)
        end
        HookInspect()
        return
    end
    if event == "INSPECT_READY" then
        C_Timer.After(0.2, UpdateInspect)
        C_Timer.After(0.8, UpdateInspect)
    else
        C_Timer.After(0.2, UpdateCharacter)
    end
end)
