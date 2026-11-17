---------------------------------------------------------------------------
-- H3z0 UI - Hide banners and pop-ups
-- Two switches on the Autohide page (profile.uiHider):
--   hideBossBanner  - the boss kill banner, event toasts, level-up banner
--   hideAlertPopups - loot, achievement, housing and other pop-up alerts
-- Frames are only made invisible (alpha 0 + no mouse), never hidden or moved,
-- so Blizzard keeps owning them and nothing is tainted.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local function Settings()
    local core = _G.H3z0UICore
    return core and core.db and core.db.profile and core.db.profile.uiHider
end

local BANNERS = { "BossBanner", "EventToastManagerFrame", "LevelUpDisplay" }
local ALERTS  = { "AlertFrame" }

local hooked = {}
local busy = false

local function Wanted(key)
    local s = Settings()
    return s and s[key] == true
end

local function Mute(frame, on)
    if not frame then return end
    pcall(function()
        if on then
            busy = true
            frame:SetAlpha(0)
            busy = false
            if frame.EnableMouse then frame:EnableMouse(false) end
        else
            frame:SetAlpha(1)
        end
    end)
end

local function Watch(frame, key)
    if not frame or hooked[frame] then return end
    hooked[frame] = true
    -- Blizzard fades these in with SetAlpha / Show; put it back to 0 right away
    pcall(hooksecurefunc, frame, "SetAlpha", function(self, a)
        if busy or (a or 0) <= 0 then return end
        if Wanted(key) then
            busy = true
            pcall(self.SetAlpha, self, 0)
            busy = false
        end
    end)
    pcall(hooksecurefunc, frame, "Show", function(self)
        if Wanted(key) then Mute(self, true) end
    end)
end

local function Apply()
    for _, name in ipairs(BANNERS) do
        local f = _G[name]
        if f then Watch(f, "hideBossBanner"); Mute(f, Wanted("hideBossBanner")) end
    end
    for _, name in ipairs(ALERTS) do
        local f = _G[name]
        if f then Watch(f, "hideAlertPopups"); Mute(f, Wanted("hideAlertPopups")) end
    end
end

_G.H3z0UI_ApplyBannerHiding = Apply

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ADDON_LOADED")   -- some of these frames come with a Blizzard load-on-demand addon
ev:SetScript("OnEvent", function(_, event)
    C_Timer.After(event == "ADDON_LOADED" and 0.5 or 0, Apply)
end)
