local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI: friendly nameplates
--   Friendly NPC nameplates:    uiHider.friendlyNPCNameplates
--       "off"  = always off (default), "on" = always on, "game" = left to the game
--   Friendly player nameplates: uiHider.hideFriendlyPlayerNameplates
-- "Always" means the setting is put back whenever something else (the game's
-- options, another addon) changes it.
---------------------------------------------------------------------------

local FP = {}
ns.H3z0FriendlyPlates = FP

local CVAR_NPC = "nameplateShowFriendlyNPCs"
local CVAR_PLAYER = "nameplateShowFriendlyPlayers"

local function Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.uiHider = p.uiHider or {}
    return p.uiHider
end

function FP.NPCMode()
    local s = Settings()
    local mode = s and s.friendlyNPCNameplates
    if mode ~= "on" and mode ~= "game" then mode = "off" end
    return mode
end

local function Get(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar and GetCVar(name)
end

local function Set(name, value)
    if Get(name) == value then return end
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, name, value)
    elseif SetCVar then
        pcall(SetCVar, name, value)
    end
end

local pending = false
local applying = false

function FP.Apply()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local s = Settings()
    if not s then return end
    applying = true
    local mode = FP.NPCMode()
    if mode == "off" then
        Set(CVAR_NPC, "0")
    elseif mode == "on" then
        Set(CVAR_NPC, "1")
    end
    if s.hideFriendlyPlayerNameplates ~= nil then
        Set(CVAR_PLAYER, s.hideFriendlyPlayerNameplates and "0" or "1")
    end
    applying = false
end
_G.H3z0UI_ApplyFriendlyPlates = FP.Apply

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("CVAR_UPDATE")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then FP.Apply() end
        return
    end
    if event == "CVAR_UPDATE" then
        if applying or type(name) ~= "string" then return end
        local lower = name:lower()
        if lower ~= CVAR_NPC:lower() and lower ~= CVAR_PLAYER:lower() then return end
    end
    -- after the game and other addons have set theirs
    C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 2 or 0.1, FP.Apply)
end)
