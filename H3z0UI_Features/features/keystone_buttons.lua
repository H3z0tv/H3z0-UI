local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Keystone window: two round buttons at the top corners while the keystone
-- window is open. Left: ready check. Right: pull timer (10 seconds).
-- Settings: profile.h3zGroupTools.keystoneButtons (on by default).
---------------------------------------------------------------------------
if ns.Client and (ns.Client.isClassic or ns.Client.isForever) then return end

local PREFIX = "|cFF30D1FFH3z0 UI:|r "

local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.h3zGroupTools = p.h3zGroupTools or {}
    local s = p.h3zGroupTools
    if s.keystoneButtons == nil then s.keystoneButtons = true end
    if s.pullSeconds == nil then s.pullSeconds = 10 end
    return s
end

local function CanLead()
    if not IsInGroup() then return false end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local ART = "Interface\\AddOns\\H3z0UI\\assets\\keystone\\"
local RED = { 0.94, 0.33, 0.15 }

-- round picture button: the picture is the button, it brightens on hover
local function PictureButton(parent, file, tip, tip2, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(56, 56)
    b:SetFrameLevel(parent:GetFrameLevel() + 20)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(ART .. file)
    b.icon:SetVertexColor(0.9, 0.9, 0.9)
    b:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(tip, 1, 1, 1)
        GameTooltip:AddLine(type(tip2) == "function" and tip2() or tip2, 0.8, 0.8, 0.8, true)
        if not CanLead() then GameTooltip:AddLine("Only the group leader or an assistant can use it.", 0.9, 0.4, 0.4, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.9, 0.9, 0.9)
        GameTooltip:Hide()
    end)
    b:SetScript("OnMouseDown", function(self) self.icon:ClearAllPoints(); self.icon:SetPoint("TOPLEFT", 1, -1); self.icon:SetPoint("BOTTOMRIGHT", 1, -1) end)
    b:SetScript("OnMouseUp", function(self) self.icon:SetAllPoints() end)
    b:SetScript("OnClick", onClick)
    return b
end

local ready, pull

local function Build()
    local kf = _G.ChallengesKeystoneFrame
    if ready or not kf then return end
    ready = PictureButton(kf, "ready.tga", "Ready Check",
        "Asks everyone in the group if they are ready.",
        function()
            if not CanLead() then print(PREFIX .. "only the group leader (or an assistant) can start a ready check.") return end
            if DoReadyCheck then DoReadyCheck() end
        end)
    ready:SetPoint("TOPLEFT", kf, "TOPLEFT", 30, -34)
    pull = PictureButton(kf, "timer.tga", "Pull Timer",
        function() local s = Settings(); return "Starts a " .. ((s and s.pullSeconds) or 10) .. " second countdown for the group." end,
        function()
            if not CanLead() then print(PREFIX .. "only the group leader (or an assistant) can start a pull timer.") return end
            local s = Settings()
            if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown((s and s.pullSeconds) or 10) end
        end)
    pull:SetPoint("TOPRIGHT", kf, "TOPRIGHT", -30, -34)
    pull.num = pull:CreateFontString(nil, "OVERLAY")
    pull.num:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
    pull.num:SetPoint("CENTER", 0, -1)
    pull.num:SetTextColor(RED[1], RED[2], RED[3])
    kf:HookScript("OnShow", function()
        local s = Settings()
        local on = s and s.keystoneButtons
        if pull.num then pull.num:SetText(tostring((s and s.pullSeconds) or 10)) end
        ready:SetShown(on and true or false)
        pull:SetShown(on and true or false)
    end)
end

local function Refresh()
    local s = Settings()
    if pull and pull.num then pull.num:SetText(tostring((s and s.pullSeconds) or 10)) end
    if ready then
        ready:SetShown(s and s.keystoneButtons and true or false)
        pull:SetShown(s and s.keystoneButtons and true or false)
    end
end
_G.H3z0UI_RefreshKeystoneButtons = Refresh

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_ChallengesUI" then return end
    if _G.ChallengesKeystoneFrame then
        Build()
        Refresh()
        self:UnregisterAllEvents()
    end
end)
