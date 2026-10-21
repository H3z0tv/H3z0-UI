local ADDON_NAME, ns = ...

local function RefreshAuraSurfaces()
    if ns.H3z0UI_RefreshGroupFrameAuras then ns.H3z0UI_RefreshGroupFrameAuras() end
    if ns.H3z0UI_RefreshUnitFrameAuras then ns.H3z0UI_RefreshUnitFrameAuras() end
    if ns.H3z0UI_RefreshBuffBorderAuras then ns.H3z0UI_RefreshBuffBorderAuras() end
end

if CreateFrame then
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:SetScript("OnEvent", function(_, _, arg1)
        if arg1 == "player" or arg1 == nil then
            local pins = ns.Settings and ns.Settings.Pins
            if pins and type(pins.HandleProfileFeatureSpecChanged) == "function" then
                pins:HandleProfileFeatureSpecChanged()
            end
            RefreshAuraSurfaces()
        end
    end)
end
