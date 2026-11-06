local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Item Upgrade: the Character window opens with it (your equipped items are
-- right there to pick from) and closes again with it, if it was opened this way
---------------------------------------------------------------------------
local openedByUs = false
local hooked = false

local function CharacterShown()
    return _G.CharacterFrame and _G.CharacterFrame:IsShown()
end

local function OnUpgradeShow()
    C_Timer.After(0, function()
        if InCombatLockdown() then return end
        local f = _G.ItemUpgradeFrame
        if not (f and f:IsShown()) then return end
        if CharacterShown() then return end
        if type(ToggleCharacter) == "function" then
            pcall(ToggleCharacter, "PaperDollFrame")
            openedByUs = CharacterShown() and true or false
        end
    end)
end

local function OnUpgradeHide()
    if not openedByUs then return end
    openedByUs = false
    C_Timer.After(0, function()
        if InCombatLockdown() then return end
        if CharacterShown() and type(HideUIPanel) == "function" then
            pcall(HideUIPanel, _G.CharacterFrame)
        end
    end)
end

local function Hook()
    local f = _G.ItemUpgradeFrame
    if hooked or not f then return end
    hooked = true
    f:HookScript("OnShow", OnUpgradeShow)
    f:HookScript("OnHide", OnUpgradeHide)
    if f:IsShown() then OnUpgradeShow() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_ItemUpgradeUI" then return end
    C_Timer.After(0, Hook)
end)
