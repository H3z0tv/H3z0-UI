local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Controller modes (Steam Deck / PC Handheld / PC Controller) with
-- ConsolePort's own bars: H3z0 UI action bars 1-3 are hidden so the two
-- don't sit on top of each other. Leaving the mode (or turning the option
-- off in Handheld settings) brings them back. Out of combat only; anything
-- asked in combat is done right after it.
---------------------------------------------------------------------------

local BARS = { "bar1", "bar2", "bar3" }
local pending = false

local function Owned() return ns.ActionBarsOwned end

local function ShouldHide()
    local fn = _G.H3z0UI_ShouldHideBarsForConsole
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn)
    return ok and v == true
end

local function BarEnabled(barKey)
    local core = ns.Addon
    local ab = core and core.db and core.db.profile and core.db.profile.actionBars
    local b = ab and ab.bars and ab.bars[barKey]
    return not (b and b.enabled == false)
end

local function Apply()
    local owned = Owned()
    if not (owned and owned.containers) then return end
    if InCombatLockdown() then pending = true return end
    if _G.H3z0UI_IsLayoutModeActive and _G.H3z0UI_IsLayoutModeActive() then return end
    local hide = ShouldHide()
    local env = ns.ActionBarsEnv
    for _, key in ipairs(BARS) do
        local c = owned.containers[key]
        if c then
            if hide then
                c._h3zConsoleHidden = true
                if owned.useNativeButtons and env and env.SetNativeBarShown then
                    pcall(env.SetNativeBarShown, c, false)
                else
                    c:SetAttribute("h3z0ui-user-shown", false)
                    c:Hide()
                end
            elseif c._h3zConsoleHidden then
                c._h3zConsoleHidden = nil
                local show = BarEnabled(key)
                if owned.useNativeButtons and env and env.SetNativeBarShown then
                    pcall(env.SetNativeBarShown, c, show)
                else
                    c:SetAttribute("h3z0ui-user-shown", show)
                    if show then c:Show() end
                end
            end
        end
    end
end
_G.H3z0UI_ApplyConsoleBarHide = Apply

local queued = false
local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0.2, function() queued = false; Apply() end)
end

-- after H3z0 UI rebuilds its bars, and when Layout Mode closes
do
    local owned = Owned()
    if owned then
        for _, m in ipairs({ "Refresh", "Initialize", "RefreshNativeBars" }) do
            if type(owned[m]) == "function" then hooksecurefunc(owned, m, Queue) end
        end
    end
    C_Timer.After(2, function()
        local lm = ns.H3z0UI_LayoutMode
        if lm and lm.RegisterExitCallback then lm:RegisterExitCallback(Queue) end
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then pending = false; Apply() end
        return
    end
    if event == "ADDON_LOADED" and not (type(name) == "string" and name:find("^ConsolePort")) then return end
    C_Timer.After(1, Apply)
end)
