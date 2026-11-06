---------------------------------------------------------------------------
-- H3z0 UI Action Bars - Classic games only (loaded by the Classic .toc files)
-- The Classic games keep the old main menu bar art (gryphons, the bar
-- background, the max level bar) under their action bars. With the H3z0 UI
-- action bars on, that art is hidden (alpha only; nothing is moved).
---------------------------------------------------------------------------
local _, ns = ...
if not (ns.Client and ns.Client.isClassic) then return end

local ART = {
    "MainMenuBarArtFrame", "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "MainMenuBarTextureExtender",
    "MainMenuBarMaxLevelBar", "MainMenuBarPerformanceBarFrame",
    "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
}

local function HideArt()
    for _, name in ipairs(ART) do
        local f = _G[name]
        if f and f.SetAlpha then f:SetAlpha(0) end
    end
    local art = _G.MainMenuBarArtFrame
    if art and art.GetRegions then
        for _, r in ipairs({ art:GetRegions() }) do
            if r.SetAlpha then r:SetAlpha(0) end
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    HideArt()
    -- the art can come back when the bar layout changes
    C_Timer.After(1, HideArt)
end)
