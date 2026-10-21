---------------------------------------------------------------------------
-- H3z0 UI Raid Control (party control tab)
-- While you are in a 5-man party, a small crown tab with an arrow appears at the
-- top-left of your party frames. Click it to open a skinned panel with the leader
-- tools (Ready Check, Role Check, Pull Timer, Convert to Raid), like Blizzard's raid
-- control panel which is not available in a party.
-- Shift+drag the tab to move it. /h3z0rc toggles the panel, /h3z0rc reset resets the tab.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local panel
local pullSeconds = 10

local COLORS = {
    bg = {0.067, 0.094, 0.153, 0.95},
    accent = {0.204, 0.827, 0.6, 1},
    text = {0.953, 0.957, 0.965, 1},
    muted = {0.6, 0.62, 0.66, 1},
}

local function GetSave()
    local profile = Helpers and Helpers.GetProfile and Helpers.GetProfile()
    if not profile then return nil end
    profile.raidControl = profile.raidControl or {}
    return profile.raidControl
end

local function CanLead()
    if not IsInGroup() then return false end
    return UnitIsGroupLeader("player") or (IsInRaid() and UnitIsGroupAssistant("player")) or false
end

local function Safe(fn, ...)
    if type(fn) ~= "function" then return end
    pcall(fn, ...)
end

local function Msg(text)
    print("|cff34D399H3z0 UI Raid Control:|r " .. text)
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function DoReadyCheck()
    if not CanLead() then return Msg("Only the group leader (or a raid assistant) can start a ready check.") end
    Safe(DoReadyCheck_Blizz or _G.DoReadyCheck)
end

local function DoRoleCheck()
    if not CanLead() then return Msg("Only the group leader (or a raid assistant) can start a role check.") end
    Safe(_G.InitiateRolePoll)
end

local function DoPull(seconds)
    if not IsInGroup() then return Msg("You need to be in a group.") end
    if not CanLead() then return Msg("Only the group leader (or a raid assistant) can start a pull timer.") end
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        Safe(C_PartyInfo.DoCountdown, seconds)
    end
end

local function DoConvert()
    if not IsInGroup() then return Msg("You need to be in a group.") end
    if not UnitIsGroupLeader("player") then return Msg("Only the group leader can do this.") end
    if IsInRaid() then
        Safe(C_PartyInfo and C_PartyInfo.ConvertToParty or _G.ConvertToParty)
    else
        Safe(C_PartyInfo and C_PartyInfo.ConvertToRaid or _G.ConvertToRaid)
    end
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function MakeButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 24)
    b:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    b:SetBackdropColor(0.12, 0.15, 0.22, 1)
    b:SetBackdropBorderColor(0.25, 0.28, 0.35, 1)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1)
    b.label = fs
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.25, 0.28, 0.35, 1) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function UpdatePanel()
    if not panel or not panel:IsShown() then return end
    local grouped = IsInGroup()
    local lead = CanLead()
    if not grouped then
        panel.status:SetText("Not in a group")
    elseif lead then
        panel.status:SetText(IsInRaid() and "Raid - you can lead" or "Party - you are leader")
    else
        panel.status:SetText("You are not the leader")
    end
    for _, b in ipairs(panel.leadButtons) do
        b:SetAlpha(lead and 1 or 0.45)
    end
    panel.convert.label:SetText(IsInRaid() and "Convert to Party" or "Convert to Raid")
    panel.convert:SetAlpha(UnitIsGroupLeader("player") and 1 or 0.45)
end

local function CreatePanel()
    local f = CreateFrame("Frame", "H3z0UI_RaidControlFrame", UIParent, "BackdropTemplate")
    f:SetSize(190, 188)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    f:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], COLORS.bg[4])
    f:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)

    f:SetPoint("TOPLEFT", H3z0UI_RaidControlTab, "TOPRIGHT", 4, 0)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Raid Control")
    title:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -4, -5)
    local x = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    x:SetPoint("CENTER")
    x:SetText("x")
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() x:SetTextColor(1, 0.3, 0.3) end)
    close:SetScript("OnLeave", function() x:SetTextColor(1, 0.82, 0) end)

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.status:SetPoint("TOPLEFT", 10, -26)
    f.status:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1)

    f.leadButtons = {}
    local rc = MakeButton(f, "Ready Check", 82, DoReadyCheck)
    rc:SetPoint("TOPLEFT", 10, -44)
    local role = MakeButton(f, "Role Check", 82, DoRoleCheck)
    role:SetPoint("LEFT", rc, "RIGHT", 6, 0)
    f.leadButtons[#f.leadButtons + 1] = rc
    f.leadButtons[#f.leadButtons + 1] = role

    -- Pull timer row: [Pull] [seconds box] [Cancel]
    local pull = MakeButton(f, "Pull Timer", 82, function() DoPull(pullSeconds) end)
    pull:SetPoint("TOPLEFT", rc, "BOTTOMLEFT", 0, -8)
    local cancel = MakeButton(f, "Cancel Pull", 82, function() DoPull(0) end)
    cancel:SetPoint("LEFT", pull, "RIGHT", 6, 0)
    f.leadButtons[#f.leadButtons + 1] = pull
    f.leadButtons[#f.leadButtons + 1] = cancel

    local secLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secLabel:SetPoint("TOPLEFT", pull, "BOTTOMLEFT", 0, -12)
    secLabel:SetText("Pull seconds:")
    secLabel:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1)

    local box = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    box:SetSize(44, 20)
    box:SetPoint("LEFT", secLabel, "RIGHT", 8, 0)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(3)
    box:SetJustifyH("CENTER")
    box:SetFontObject("GameFontHighlightSmall")
    box:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    box:SetBackdropColor(0.05, 0.07, 0.1, 1)
    box:SetBackdropBorderColor(0.25, 0.28, 0.35, 1)
    local savedPull = GetSave() and GetSave().pull
    pullSeconds = tonumber(savedPull) or 10
    box:SetText(tostring(pullSeconds))
    local function Commit(self)
        local v = tonumber(self:GetText())
        if v and v >= 1 and v <= 600 then
            pullSeconds = v
            local s = GetSave()
            if s then s.pull = v end
        else
            self:SetText(tostring(pullSeconds))
        end
        self:ClearFocus()
    end
    box:SetScript("OnEnterPressed", Commit)
    box:SetScript("OnEditFocusLost", Commit)
    box:SetScript("OnEscapePressed", function(self) self:SetText(tostring(pullSeconds)); self:ClearFocus() end)

    local convert = MakeButton(f, "Convert to Raid", 170, DoConvert)
    convert:SetPoint("TOPLEFT", secLabel, "BOTTOMLEFT", 0, -14)
    f.convert = convert

    f:SetScript("OnShow", UpdatePanel)
    f:SetScript("OnHide", function()
        local t = _G.H3z0UI_RaidControlTab
        if t and t.arrow then t.arrow:SetRotation(0) end
    end)
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("PARTY_LEADER_CHANGED")
    f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    f:SetScript("OnEvent", UpdatePanel)

    f:Hide()
    return f
end

---------------------------------------------------------------------------
-- Party tab (crown + arrow)
---------------------------------------------------------------------------
local tab

local function InPartyOnly()
    return IsInGroup() and not IsInRaid()
end

local function AnchorTab()
    if not tab then return end
    local save = GetSave()
    tab:ClearAllPoints()
    if save and save.tabPoint then
        tab:SetPoint(save.tabPoint, UIParent, save.tabRelPoint or save.tabPoint, save.tabX or 0, save.tabY or 0)
        return
    end
    local target
    for _, name in ipairs({"H3z0UI_PartyFrames", "PartyFrame", "CompactPartyFrame"}) do
        local fr = _G[name]
        if fr and fr.IsShown and fr:IsShown() then target = fr break end
    end
    if target then
        tab:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 4)
    else
        tab:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -180)
    end
end

local function SetExpanded(open)
    if not tab then return end
    if open then
        if not panel then panel = CreatePanel() end
        panel:Show()
    elseif panel then
        panel:Hide()
    end
    tab.arrow:SetRotation(open and math.pi or 0)
end

local function UpdateTab()
    if not tab then return end
    if InPartyOnly() then
        AnchorTab()
        tab:Show()
    else
        tab:Hide()
        SetExpanded(false)
    end
end

local function CreateTab()
    local t = CreateFrame("Button", "H3z0UI_RaidControlTab", UIParent, "BackdropTemplate")
    t:SetSize(40, 22)
    t:SetFrameStrata("MEDIUM")
    t:SetClampedToScreen(true)
    t:SetMovable(true)
    t:RegisterForDrag("LeftButton")
    t:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    t:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 0.9)
    t:SetBackdropBorderColor(0.25, 0.28, 0.35, 1)

    local icon = t:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\menuicons\\raidcontrol")
    icon:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3])

    local arrow = t:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(10, 10)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    t.arrow = arrow

    t:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Raid Control", 1, 1, 1)
        GameTooltip:AddLine("Click: ready check, pull timer, role check", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Shift+drag: move", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.28, 0.35, 1)
        GameTooltip:Hide()
    end)
    t:SetScript("OnClick", function()
        SetExpanded(not (panel and panel:IsShown()))
    end)
    t:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then self:StartMoving() end
    end)
    t:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local sv = GetSave()
        if sv then
            local point, _, relPoint, x, y = self:GetPoint()
            sv.tabPoint, sv.tabRelPoint, sv.tabX, sv.tabY = point, relPoint, x, y
        end
    end)
    t:Hide()
    return t
end

local function Toggle()
    if not tab then return end
    if not InPartyOnly() then
        return Msg("The party control tab is only shown while you are in a 5-man party.")
    end
    SetExpanded(not (panel and panel:IsShown()))
end

_G.H3z0UI_ToggleRaidControl = Toggle
_G.H3z0UI_RaidControlRefreshAnchor = function() AnchorTab() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        tab = CreateTab()
    end
    -- party frames can be created/moved a moment after the roster changes
    UpdateTab()
    C_Timer.After(0.5, UpdateTab)
end)

SLASH_H3Z0RAIDCONTROL1 = "/h3z0rc"
SLASH_H3Z0RAIDCONTROL2 = "/raidcontrol"
SlashCmdList["H3Z0RAIDCONTROL"] = function(msg)
    if msg and msg:lower():match("^%s*reset") then
        local sv = GetSave()
        if sv then sv.tabPoint, sv.tabRelPoint, sv.tabX, sv.tabY = nil, nil, nil, nil end
        AnchorTab()
        return Msg("Tab position reset.")
    end
    Toggle()
end
