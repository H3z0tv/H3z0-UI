-- /fw commands for the bundled Formwise bars (based on Formwise's own Options.lua, MIT, kragtenb).
local _, host = ...
host.Formwise = host.Formwise or {}
local ns = host.Formwise
local Core = ns.Core

local Commands = {}
ns.Commands = Commands

local function say(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99H3z0 UI Shapeshift Bars|r " .. text)
end

local SIZE = { width = { 40, 400 }, height = { 4, 40 }, spacing = { 0, 20 }, scale = { 0.5, 2 } }

function Commands.Help()
    say("/fw unlock, lock | /fw reset | /fw furor auto or 0-5 | /fw log | /fw width, height, spacing or scale <value>. More in H3z0 UI options > Unit Frames > Player > Shapeshift Bars.")
end

function Commands.Log()
    local log = Core.char and Core.char.log or {}
    if #log == 0 then
        say("No shifts checked yet. Shift into Cat or Bear Form out of combat to record one.")
        return
    end
    for _, e in ipairs(log) do
        local verdict = e.learning and " - Furor rank not known yet" or (not e.ok and " - mismatch" or "")
        say(string.format("%s Form: expected %s, got %d (Furor %d)%s", e.form == "cat" and "Cat" or "Bear",
            Core.Expected(e.expected), e.observed, e.rank, verdict))
    end
end

function Commands.Run(input)
    local command, argument = string.match(string.lower(input or ""), "^%s*(%S*)%s*(.-)%s*$")
    if not Core.frame then
        say("only runs on druids in WoW: Forever (and when turned on in the options).")
    elseif command == "unlock" or command == "lock" then
        Core:Set("locked", command == "lock")
        say(command == "lock" and "Bars locked." or "Bars unlocked: drag them anywhere. /fw lock when done.")
    elseif command == "reset" then
        Core:ResetLayout()
        say("Layout reset under the player frame.")
    elseif command == "furor" then
        local rank = tonumber(argument)
        if argument == "auto" then
            Core:SetFurorOverride(nil)
        elseif rank and rank >= 0 and rank <= 5 and rank % 1 == 0 then
            Core:SetFurorOverride(rank)
        else
            say("Usage: /fw furor auto or 0-5")
            return
        end
        say("Furor: " .. (Core.char.furorOverride and ("set to " .. Core.char.furorOverride) or "automatic"))
    elseif command == "log" then
        Commands.Log()
    elseif SIZE[command] and tonumber(argument) then
        local r = SIZE[command]
        Core:Set(command, math.max(r[1], math.min(r[2], tonumber(argument))))
    else
        Commands.Help()
    end
end

-- Only claim /fw when the standalone Formwise isn't there to own it.
if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Formwise")) then
    SLASH_H3ZFORMWISE1 = "/fw"
    SLASH_H3ZFORMWISE2 = "/shiftbars"
    SlashCmdList.H3ZFORMWISE = Commands.Run
end

return Commands
