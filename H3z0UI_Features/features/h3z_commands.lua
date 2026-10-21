local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI chat commands
-- Adds the H3z0 Features commands to /h3z0ui. Anything not handled here
-- goes on to the core command handler.
---------------------------------------------------------------------------

local addon = _G.H3z0UI
if type(addon) ~= "table" then return end

local PREFIX = "|cFF30D1FFH3z0 UI:|r "

local function Say(msg) print(PREFIX .. msg) end

local function Call(name, ...)
    local fn = _G[name]
    if type(fn) == "function" then
        return true, fn(...)
    end
    return false
end

local function OnOff(on) return on and "|cff00ff00ON|r" or "|cffff5555OFF|r" end

local COMMANDS = {}

COMMANDS["setup"] = function()
    if _G.H3z0UI_Setup and _G.H3z0UI_Setup.Show then _G.H3z0UI_Setup.Show() else Say("Setup wizard not loaded.") end
end
COMMANDS["wizard"] = COMMANDS["setup"]

COMMANDS["deck"] = function()
    local hh = _G.H3z0UI_Handheld
    if hh and hh.Toggle then hh.Toggle() else Say("Handheld module not loaded.") end
end
COMMANDS["handheld"] = COMMANDS["deck"]

COMMANDS["decksetup"] = function()
    local hh = _G.H3z0UI_Handheld
    if hh and hh.ShowSetupPopup then hh.ShowSetupPopup() end
end

COMMANDS["pchandheld"] = function()
    local hh = _G.H3z0UI_Handheld
    if hh and hh.TogglePCHandheld then hh.TogglePCHandheld() end
end
COMMANDS["pcdeck"] = COMMANDS["pchandheld"]

COMMANDS["controller"] = function()
    local hh = _G.H3z0UI_Handheld
    if hh and hh.TogglePCController then hh.TogglePCController() end
end
COMMANDS["pad"] = COMMANDS["controller"]

COMMANDS["style"] = function()
    local ok, on = Call("H3z0UI_ToggleFrameStyle")
    if ok then Say("Frame Style " .. OnOff(on)) end
end
COMMANDS["portraits"] = COMMANDS["style"]

COMMANDS["modern"] = function()
    local ok, on = Call("H3z0UI_ToggleModernLook")
    if ok then Say("Modern Look " .. OnOff(on)) end
end

COMMANDS["streamer"] = function()
    local core = ns.Addon
    local ab = core and core.db and core.db.profile and core.db.profile.actionBars
    if not ab then return end
    ab.global = ab.global or {}
    ab.global.streamerMode = not ab.global.streamerMode
    Call("H3z0UI_ApplyStreamerMode")
    Say("Streamer Mode " .. (ab.global.streamerMode and "|cff00ff00ON|r - button press highlight hidden." or "|cffff5555OFF|r"))
end

COMMANDS["bars"] = function() Call("H3z0UI_ToggleCompactBars") end
COMMANDS["compact"] = COMMANDS["bars"]

COMMANDS["plates"] = function()
    local ok, on = Call("H3z0UI_TogglePlates")
    if ok then Say("H3z0 Nameplates " .. OnOff(on)) end
end
COMMANDS["nameplates"] = COMMANDS["plates"]

-- Blizzard's Cooldown Manager settings (what the H3z0 CDM shows)
COMMANDS["cdm"] = function()
    local f = _G.CooldownViewerSettings
    if f and f.SetShown then f:SetShown(not f:IsShown()) else Say("Cooldown Manager settings are not available.") end
end

COMMANDS["whatsnew"] = function() Call("H3z0UI_ShowWhatsNew") end
COMMANDS["news"] = COMMANDS["whatsnew"]
COMMANDS["changelog"] = COMMANDS["whatsnew"]

-- H3z0 unit frames keep their own mover (drag the frames, sliders in the options)
COMMANDS["frames"] = function()
    if not Call("H3z0UI_ToggleUnitFrameEditMode") then Say("Unit Frames module not loaded.") end
end

COMMANDS["party"] = function()
    if _G.H3z0UI_PartyFramesSetTest and _G.H3z0UI_PartyFramesIsTest then
        _G.H3z0UI_PartyFramesSetTest(not _G.H3z0UI_PartyFramesIsTest())
    end
end

COMMANDS["raid"] = function()
    if _G.H3z0UI_RaidFramesSetTest and _G.H3z0UI_RaidFramesIsTest then
        _G.H3z0UI_RaidFramesSetTest(not _G.H3z0UI_RaidFramesIsTest())
    end
end

local original = addon.SlashCommandOpen

function addon:SlashCommandOpen(input)
    local key = type(input) == "string" and input:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
    local compactKey = key:gsub("%s+", "")
    local handler = COMMANDS[key] or COMMANDS[compactKey]
    if handler then
        handler()
        return
    end
    if type(original) == "function" then
        return original(self, input)
    end
end
