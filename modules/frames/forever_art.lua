local ADDON_NAME, ns = ...

-- WoW: Forever shows the classic gryphons / bar art around the main action bar and
-- the micro menu. Hide them (alpha only, the frames are left alone).
if not (ns.Client and ns.Client.isForever) then return end

local function HideArt()
    local bar = _G.MainActionBar or _G.MainMenuBar
    if bar then
        for _, key in ipairs({ "EndCaps", "BorderArt", "Background" }) do
            local art = bar[key]
            if art and art.SetAlpha then art:SetAlpha(0) end
        end
        local caps = bar.EndCaps
        if caps then
            for _, key in ipairs({ "LeftEndCap", "RightEndCap" }) do
                local cap = caps[key]
                if cap and cap.SetAlpha then cap:SetAlpha(0) end
            end
        end
    end
    local micro = _G.MicroMenu
    if micro then
        for _, key in ipairs({ "BorderArt", "BackgroundArt" }) do
            local art = micro[key]
            if art and art.SetAlpha then art:SetAlpha(0) end
        end
    end
end

local hooked = false
local function Hook()
    if hooked then return end
    local bar = _G.MainActionBar or _G.MainMenuBar
    if not bar then return end
    hooked = true
    for _, method in ipairs({ "UpdateEndCaps", "UpdateDividers", "ApplySystemAnchor", "UpdateGridLayout" }) do
        if type(bar[method]) == "function" then hooksecurefunc(bar, method, HideArt) end
    end
    bar:HookScript("OnShow", HideArt)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
ev:SetScript("OnEvent", function()
    Hook()
    HideArt()
    C_Timer.After(0.5, HideArt)
end)
