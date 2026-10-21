local ADDON_NAME, ns = ...
local H3z0UICore = ns.Addon

local H3z0UI_AbilityTimeline = {}
ns.H3z0UI_AbilityTimeline = H3z0UI_AbilityTimeline

local pendingUpdate = false

local TARGET_KEYS = {
    timeline = "abilityTimelineTimeline",
    bigIcon = "abilityTimelineBigIcon",
}

local function GetDB()
    if H3z0UICore and H3z0UICore.db and H3z0UICore.db.profile and H3z0UICore.db.profile.abilityTimeline then
        return H3z0UICore.db.profile.abilityTimeline
    end
    return nil
end

local function IsAddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    if type(IsAddOnLoaded) == "function" then
        return IsAddOnLoaded(name)
    end
    return false
end

function H3z0UI_AbilityTimeline:IsAvailable()
    if _G.AbilityTimelineFrame or _G.AbilityTimelineBigIconFrame then
        return true
    end
    return IsAddonLoaded("AbilityTimeline")
end

function H3z0UI_AbilityTimeline:GetAddonFrame(frameKey)
    if frameKey == "timeline" then
        return _G.AbilityTimelineFrame
    elseif frameKey == "bigIcon" then
        return _G.AbilityTimelineBigIconFrame
    end
    return nil
end

function H3z0UI_AbilityTimeline:GetAnchorFrame(anchorName)
    return ns.H3z0UI_IntegrationShared.GetAnchorFrame(anchorName)
end

local QueueRetry = ns.H3z0UI_IntegrationShared.MakeQueueRetry("H3z0UI_AbilityTimeline")

local anchoredFramesHookInstalled = false
local function TryInstallAnchoredFramesHook()
    if anchoredFramesHookInstalled then
        return true
    end
    if not (ns.H3z0UI_Anchoring and ns.H3z0UI_Anchoring.RegisterAnchoredFramesPostHook) then
        return false
    end
    ns.H3z0UI_Anchoring.RegisterAnchoredFramesPostHook("abilitytimeline", function()
        H3z0UI_AbilityTimeline:ApplyAllPositions()
    end)
    anchoredFramesHookInstalled = true
    return true
end

local function RegisterAnchorTargets()
    if not (ns.H3z0UI_Anchoring and ns.H3z0UI_Anchoring.RegisterAnchorTarget) then
        return
    end

    local timelineFrame = _G.AbilityTimelineFrame
    if timelineFrame then
        ns.H3z0UI_Anchoring:RegisterAnchorTarget(TARGET_KEYS.timeline, timelineFrame, {
            displayName = "AbilityTimeline Timeline",
            category = "External",
            categoryOrder = 1,
            order = 3,
        })
    end

    local bigIconFrame = _G.AbilityTimelineBigIconFrame
    if bigIconFrame then
        ns.H3z0UI_Anchoring:RegisterAnchorTarget(TARGET_KEYS.bigIcon, bigIconFrame, {
            displayName = "AbilityTimeline Big Icon",
            category = "External",
            categoryOrder = 1,
            order = 4,
        })
    end
end

function H3z0UI_AbilityTimeline:ApplyPosition(frameKey)
    local db = GetDB()
    if not db or not db[frameKey] then
        return
    end

    local cfg = db[frameKey]
    if not cfg.enabled or cfg.anchorTo == "disabled" then
        return
    end

    local addonFrame = self:GetAddonFrame(frameKey)
    if not addonFrame then
        pendingUpdate = true
        QueueRetry()
        return
    end

    local anchorFrame = self:GetAnchorFrame(cfg.anchorTo)
    if not anchorFrame then
        pendingUpdate = true
        QueueRetry()
        return
    end

    local ok = pcall(function()
        addonFrame:ClearAllPoints()
        addonFrame:SetPoint(
            cfg.sourcePoint or "TOP",
            anchorFrame,
            cfg.targetPoint or "BOTTOM",
            cfg.offsetX or 0,
            cfg.offsetY or -5
        )
    end)

    if not ok then
        pendingUpdate = true
        QueueRetry()
    end
end

function H3z0UI_AbilityTimeline:ApplyAllPositions()
    TryInstallAnchoredFramesHook()
    RegisterAnchorTargets()
    self:ApplyPosition("timeline")
    self:ApplyPosition("bigIcon")
end

function H3z0UI_AbilityTimeline:Initialize()
    if not self:IsAvailable() then
        return
    end

    self:ApplyAllPositions()
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, function()
            H3z0UI_AbilityTimeline:Initialize()
        end)
    elseif event == "ADDON_LOADED" and arg1 == "AbilityTimeline" then
        C_Timer.After(1.0, function()
            H3z0UI_AbilityTimeline:Initialize()
        end)
    elseif event == "PLAYER_REGEN_ENABLED" and pendingUpdate then
        pendingUpdate = false
        C_Timer.After(0.1, function()
            H3z0UI_AbilityTimeline:ApplyAllPositions()
        end)
    end
end)

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
