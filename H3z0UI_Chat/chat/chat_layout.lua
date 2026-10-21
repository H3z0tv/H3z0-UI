local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI Chat: helpers Layout Mode uses for the chat window
-- (ChatFrame1); the position and size are also stored the Blizzard way.
---------------------------------------------------------------------------

ns.H3z0UI = ns.H3z0UI or {}
ns.H3z0UI.Chat = ns.H3z0UI.Chat or {}

local Display = {}
ns.H3z0UI.Chat.DisplayLayer = Display

local function Primary()
    return _G.ChatFrame1
end

function Display.GetContainer(windowID)
    if windowID == nil or windowID == 1 then return Primary() end
    return nil
end

function Display.GetWindowCount()
    return 1
end

function Display.PersistGeometry(windowID)
    local f = Display.GetContainer(windowID)
    if not f or InCombatLockdown() then return end
    if FCF_SavePositionAndDimensions then
        pcall(FCF_SavePositionAndDimensions, f)
    end
    if _G.H3z0UI_RefreshWindowSkins then pcall(_G.H3z0UI_RefreshWindowSkins) end
end

-- The chat handle in Layout Mode is added by core/h3z/blizz_layout.lua
-- (position + size kept per PC / Deck layout, like the damage meter).
local function Publish()
    local f = Primary()
    if not f then return end
    if f.SetResizable then pcall(f.SetResizable, f, true) end
    if f.SetMovable then pcall(f.SetMovable, f, true) end
end

Publish()

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Publish()
    local lm = ns.H3z0UI_LayoutMode
    -- moving the chat in Layout Mode: keep Blizzard's saved position in step
    if lm and lm.RegisterExitCallback then
        lm:RegisterExitCallback(function()
            C_Timer.After(0, function() Display.PersistGeometry(1) end)
        end)
    end
end)
