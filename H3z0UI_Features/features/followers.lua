--[[
    H3z0 UI - Follower dungeons (solo dungeon with AI followers)

    Blizzard puts the "Dungeon Assistance" toggle (followers lead / you lead)
    on the zone ability or the extra action button. H3z0 UI moves those buttons
    into its own holders, and if the toggle does not show up there it can't be
    used at all. Inside a follower dungeon this makes sure it is there:
      * Blizzard's zone ability / extra action buttons are shown again
      * if neither is visible, H3z0 UI shows its own button for the toggle
        (centered at the bottom of the screen, above the action bars)
]]

local ADDON_NAME, ns = ...

local FOLLOWER_DIFFICULTY = 205

local function InFollowerDungeon()
    local _, instanceType, difficultyID = GetInstanceInfo()
    return instanceType == "party" and difficultyID == FOLLOWER_DIFFICULTY
end

-- what the toggle is right now: { kind = "spell", id } or { kind = "action", id }
local function FindToggle()
    if C_ZoneAbility and C_ZoneAbility.GetActiveAbilities then
        local ok, list = pcall(C_ZoneAbility.GetActiveAbilities)
        if ok and type(list) == "table" then
            for _, info in ipairs(list) do
                if info and info.spellID then return { kind = "spell", id = info.spellID } end
            end
        end
    end
    if HasExtraActionBar and HasExtraActionBar() then
        local btn = _G.ExtraActionBarFrame and _G.ExtraActionBarFrame.button
        local slot = btn and btn.action
        if not slot and GetExtraBarIndex then slot = (GetExtraBarIndex() - 1) * 12 + 1 end
        if slot and HasAction(slot) then return { kind = "action", id = slot } end
    end
    return nil
end

local function Visible(frame)
    return frame and frame:IsVisible() and (frame:GetEffectiveAlpha() or 0) > 0.2 or false
end

-- Blizzard's own buttons: make sure they are not hidden or faded out
local function ShowBlizzard()
    for _, name in ipairs({ "ZoneAbilityFrame", "ExtraActionBarFrame", "ExtraAbilityContainer" }) do
        local f = _G[name]
        if f and f.SetAlpha then f:SetAlpha(1) end
    end
    for _, name in ipairs({ "H3z0UI_zoneAbilityHolder", "H3z0UI_extraActionButtonHolder" }) do
        local h = _G[name]
        if h then
            h:SetAlpha(1)
            if not h:IsShown() then h:Show() end
        end
    end
end

local function BlizzardShowing()
    local z = _G.ZoneAbilityFrame
    local e = _G.ExtraActionBarFrame
    return Visible(z) or Visible(e)
end

---------------------------------------------------------------------------
-- Own button (secure: it casts the toggle)
---------------------------------------------------------------------------
local button
local function Build()
    if button then return button end
    local b = CreateFrame("Button", "H3z0UI_FollowerToggle", UIParent, "SecureActionButtonTemplate")
    b:SetSize(52, 52)
    b:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
    b:SetFrameStrata("MEDIUM")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -3)
    b.label:SetText("Dungeon Assistance")
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.toggle and self.toggle.kind == "spell" then
            GameTooltip:SetSpellByID(self.toggle.id)
        elseif self.toggle then
            GameTooltip:SetAction(self.toggle.id)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    button = b
    return b
end

local pending = false
local function Update()
    if not InFollowerDungeon() then
        if button and button:IsShown() then
            if InCombatLockdown() then pending = true return end
            button:Hide()
        end
        return
    end
    ShowBlizzard()
    local toggle = FindToggle()
    -- give Blizzard's buttons a moment to show themselves first
    C_Timer.After(0.5, function()
        if not InFollowerDungeon() then return end
        if InCombatLockdown() then pending = true return end
        local b = Build()
        if not toggle or BlizzardShowing() then
            b:Hide()
            return
        end
        b.toggle = toggle
        if toggle.kind == "spell" then
            b:SetAttribute("type", "spell")
            b:SetAttribute("spell", toggle.id)
            b:SetAttribute("action", nil)
            local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(toggle.id)
            b.icon:SetTexture(tex or 134400)
        else
            b:SetAttribute("type", "action")
            b:SetAttribute("action", toggle.id)
            b:SetAttribute("spell", nil)
            b.icon:SetTexture(GetActionTexture(toggle.id) or 134400)
        end
        -- under the zone ability holder when there is one (it can be moved in Edit Mode)
        local holder = _G.H3z0UI_zoneAbilityHolder
        b:ClearAllPoints()
        if holder then
            b:SetPoint("CENTER", holder, "CENTER", 0, 0)
        else
            b:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
        end
        b:Show()
    end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UPDATE_EXTRA_ACTIONBAR",
    "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if not pending then return end
        pending = false
    end
    Update()
end)
