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

COMMANDS["gamepad"] = function()
    local H = _G.H3z0UI_Handheld
    if not H then Say("Handheld module not loaded.") return end
    local function CV(n) local ok, v = pcall(C_CVar.GetCVar, n) return ok and tostring(v) or "?" end
    local p = ns.Addon and ns.Addon.db and ns.Addon.db.profile
    local c = p and p.handheld or {}
    Say("Controller check: Forever " .. tostring(H.IsForever and H.IsForever()) .. ", mode Controller (game UI) " .. tostring(c.gamepadUI == true))
    Say("GamePadEnable = " .. CV("GamePadEnable") .. ", game controller UI active " .. tostring(H.GamepadUIActive and H.GamepadUIActive()) .. ", controller plugged in " .. tostring(H.ControllerConnected and H.ControllerConnected()))
    if H.GamepadUISettingInfo then
        local nm, var, val = H.GamepadUISettingInfo()
        if nm then Say("game option found: " .. tostring(nm) .. " (variable " .. tostring(var) .. ") = " .. tostring(val))
        else Say("game option Enable Gamepad UI: NOT FOUND in the game's options") end
    end
    if C_Console and C_Console.GetAllCommands then
        local ok, all = pcall(C_Console.GetAllCommands)
        if ok and type(all) == "table" then
            local names = {}
            for _, cmd in ipairs(all) do
                local n = type(cmd) == "table" and cmd.command
                if type(n) == "string" and n:lower():find("gamepad", 1, true) then
                    local l = n:lower()
                    if l:find("ui", 1, true) or l:find("hud", 1, true) or l:find("legend", 1, true) or l:find("mode", 1, true) then
                        names[#names + 1] = n .. "=" .. CV(n)
                    end
                end
            end
            Say("gamepad UI variables: " .. (#names > 0 and table.concat(names, ", ") or "none"))
        end
    end
    local hide = _G.H3z0UI_ShouldHideBarsForConsole and _G.H3z0UI_ShouldHideBarsForConsole()
    Say("action bars 1-3 hidden: " .. tostring(hide == true))
    local n = 0
    for k, v in pairs(_G) do
        if n < 12 and type(k) == "string" and k:find("GamePad") and type(v) == "table" and v.IsShown then
            local ok, shown = pcall(v.IsShown, v)
            Say("  frame " .. k .. (ok and shown and " (shown)" or ""))
            n = n + 1
        end
    end
end
COMMANDS["controller"] = COMMANDS["gamepad"]

COMMANDS["friendicons"] = function()
    local list = _G.FriendsListFrame
    local box = list and list.ScrollBox
    if not (box and box.ForEachFrame) then Say("Open the Contacts (Friends) window first.") return end
    local n = 0
    box:ForEachFrame(function(row)
        if n >= 6 then return end
        local icon = row.gameIcon
        if icon and icon:IsShown() then
            n = n + 1
            local okt, tex = pcall(icon.GetTexture, icon)
            local oka, atlas = pcall(icon.GetAtlas, icon)
            local r, g, b = icon:GetVertexColor()
            Say(tostring(row.name and row.name:GetText() or "?") .. ": client " .. tostring(row.h3zGameIconClient)
                .. ", texture " .. tostring(okt and tex) .. ", atlas " .. tostring(oka and atlas)
                .. string.format(", colour %.2f %.2f %.2f", r or 0, g or 0, b or 0))
        end
    end)
    if n == 0 then Say("no game icons shown") end
end


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

COMMANDS["girly"] = function()
    local G = ns.H3z0Girly
    local s = G and G.GetSettings and G.GetSettings()
    if not s then Say("Girly Look not loaded.") return end
    s.enabled = not s.enabled
    G.Apply()
    Say("Girly Look " .. OnOff(s.enabled))
end

-- Hidden check (not listed anywhere): which values of Blizzard's damage meter did an
-- addon taint? issecurevariable tells the name of the addon that wrote a value.
COMMANDS["rcscan"] = function()
    -- run during or right after a ready check: lists every visible tick / cross / waiting icon and who owns it
    local found, owners = 0, {}
    local function Owner(fr)
        local parts = {}
        local cur, n = fr, 0
        while cur and n < 4 do
            local ok, name = pcall(cur.GetName, cur)
            if ok and name and name ~= "" then parts[#parts + 1] = name
            elseif cur.unit then parts[#parts + 1] = "unit:" .. tostring(cur.unit)
            else parts[#parts + 1] = (cur.GetObjectType and cur:GetObjectType() or "?") end
            cur = cur.GetParent and cur:GetParent() or nil
            n = n + 1
        end
        return table.concat(parts, " < ")
    end
    local fr = EnumerateFrames()
    while fr do
        if not (fr.IsForbidden and fr:IsForbidden()) then
            local ok, regions = pcall(function() return { fr:GetRegions() } end)
            if ok then
                for _, r in ipairs(regions) do
                    if r.GetObjectType and r:GetObjectType() == "Texture" then
                        local okv, vis = pcall(r.IsVisible, r)
                        if okv and vis then
                            local tex = r.GetTexture and r:GetTexture()
                            local atlas = r.GetAtlas and r:GetAtlas()
                            local t = tostring(atlas or tex or ""):lower()
                            if t:find("readycheck") or t:find("readymark") or t:find("pendingmark") or t:find("declinemark") then
                                found = found + 1
                                local o = Owner(fr)
                                owners[o] = (owners[o] or 0) + 1
                            end
                        end
                    end
                end
            end
        end
        fr = EnumerateFrames(fr)
    end
    Say("ready check icons visible: " .. found)
    for o, n in pairs(owners) do Say(n .. "x  " .. o) end
end

COMMANDS["menuscan"] = function()
    -- open the Esc menu once, close it, then type this: lists what stayed visible
    local fn = _G.H3z0UI_GameMenuLeftovers
    local list = fn and fn() or {}
    Say("still visible the last time the Esc menu was open: " .. #list)
    for i, s in ipairs(list) do Say(i .. ". " .. s) end
end

COMMANDS["moverscan"] = function()
    local BM = ns.H3z0UI_BlizzardMover
    if not (BM and BM.functions and BM.functions.Scan) then Say("Blizzard Mover is not loaded.") return end
    local r = BM.functions.Scan()
    Say("Blizzard Mover: master " .. (r.masterOn and "ON" or "OFF") .. ", modifier " .. tostring(r.modifier) .. (r.requireModifier and "" or " (not required)"))
    local ok, bad = 0, {}
    for _, row in ipairs(r.rows) do
        if row.state == "exists" and row.active and row.hooked and row.canMove then ok = ok + 1
        else bad[#bad + 1] = row.id .. " [" .. row.state .. (row.active and "" or ", off") .. (row.hooked and "" or ", not hooked") .. "]" end
    end
    Say(ok .. " windows ready. Not ready (" .. #bad .. "): " .. table.concat(bad, ", "))
end

COMMANDS["taintcheck"] = function()
    local found = 0
    local function Check(label, tbl, depth)
        if type(tbl) ~= "table" then return end
        for k, v in pairs(tbl) do
            if type(k) == "string" or type(k) == "number" then
                local ok, secure, who = pcall(issecurevariable, tbl, k)
                if ok and secure == false then
                    found = found + 1
                    Say("tainted: " .. label .. "." .. tostring(k) .. " by " .. tostring(who))
                end
                if depth > 0 and type(v) == "table" and not (v.IsForbidden or v.GetObjectType) then
                    Check(label .. "." .. tostring(k), v, depth - 1)
                end
            end
        end
    end
    Check("DamageMeter", _G.DamageMeter, 2)
    for i = 1, 5 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then Check("Window" .. i, w, 1) end
    end
    Check("SessionWindowMixin", _G.DamageMeterSessionWindowMixin, 0)
    Check("MeterMixin", _G.DamageMeterMixin, 0)
    Check("C_DamageMeter", _G.C_DamageMeter, 0)
    for _, g in ipairs({ "UnitAffectingCombat", "SecondsToClock", "Enum", "C_DamageMeter", "InCombatLockdown", "DamageMeterSessionWindowMixin", "DamageMeterMixin" }) do
        local ok, secure, who = pcall(issecurevariable, g)
        if ok and secure == false then found = found + 1; Say("tainted global: " .. g .. " by " .. tostring(who)) end
    end
    Say(found == 0 and "taintcheck: nothing tainted found." or ("taintcheck: " .. found .. " tainted values."))
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
COMMANDS["oracle"] = function()
    local o = _G.H3z0UI_Oracle
    if o and o.Check then o.Check() else Say("Oracle is not available on this game version.") end
end
COMMANDS["oracletest"] = function()
    local o = _G.H3z0UI_Oracle
    if o and o.PlayAll then o.PlayAll() else Say("Oracle is not available on this game version.") end
end

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

-- /h3z0ui menu classic | new : choose the look of the options window (after /reload)
local function SetShell(mode)
    local core = addon.H3z0UICore
    local p = core and core.db and core.db.profile
    if not p then Say("Settings are not ready yet.") return end
    p.optionsShell = mode
    Say("Options window look: " .. mode .. ". Type /reload to apply.")
end
COMMANDS["menuclassic"] = function() SetShell("classic") end
COMMANDS["menunew"] = function() SetShell("new") end
COMMANDS["menu"] = function()
    local core = addon.H3z0UICore
    local p = core and core.db and core.db.profile
    Say("Options window look: " .. ((p and p.optionsShell) or "new") .. ". Use /h3z0ui menu classic or /h3z0ui menu new.")
end

COMMANDS["npsetup"] = function()
    if addon.EnsureOptionsLoaded then addon:EnsureOptionsLoaded() end
    if _G.H3z0UI_NPQuickSetup_Open then _G.H3z0UI_NPQuickSetup_Open() else Say("Nameplates are not available.") end
end
COMMANDS["intlog"] = function()
    local I = _G.H3z0UI_Interrupts
    if not (I and I.ShowHistory) then Say("The Interrupt Tracker is not available.") return end
    I.ShowHistory()
end
COMMANDS["inttest"] = function()
    local I = _G.H3z0UI_Interrupts
    if not (I and I.SelfTest) then Say("The Interrupt Tracker is not available.") return end
    I.SelfTest()
end
-- also the Reset Layout button on the options Home page (asks first)
_G.H3z0UI_ResetLayout = function()
    if not StaticPopupDialogs then return COMMANDS["layoutreset"]() end
    StaticPopupDialogs["H3Z0UI_RESET_LAYOUT"] = StaticPopupDialogs["H3Z0UI_RESET_LAYOUT"] or {
        text = "Put every H3z0 UI frame back in its H3z0 UI place and reload?",
        button1 = YES or "Yes", button2 = NO or "No",
        OnAccept = function() COMMANDS["layoutreset"]() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("H3Z0UI_RESET_LAYOUT")
end

COMMANDS["layoutreset"] = function()
    local LSets = ns.LayoutSets
    if InCombatLockdown() then Say("Not in combat.") return end
    if LSets and LSets.ApplyDefaults and LSets.ApplyDefaults() then
        if LSets.Save then LSets.Save(LSets.CurrentMode and LSets.CurrentMode() or "pc") end
        Say("Frames put back in the H3z0 UI places. Reloading ...")
        -- the reload has to happen right away, inside the key press / click (from a timer the game
        -- ignores it); C_UI.Reload is the newer name of the same call
        if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
    else
        Say("The H3z0 UI places could not be read; nothing was moved.")
    end
end

COMMANDS["chardump"] = function()
    if _G.H3z0UI_CharacterDump then _G.H3z0UI_CharacterDump() else Say("Nothing to show.") end
end

COMMANDS["bardump"] = function()
    local function F(name, ...) local f = _G[name] if type(f) == "function" then local ok, v = pcall(f, ...) return ok and tostring(v) or "err" end return "n/a" end
    Say("Bar 1 check - form " .. F("GetShapeshiftForm") .. ", bonus bar offset " .. F("GetBonusBarOffset")
        .. ", Blizzard page " .. F("GetActionBarPage") .. ", has bonus bar " .. F("HasBonusActionBar")
        .. ", combat " .. tostring(InCombatLockdown() and true or false))
    local hide = SecureCmdOptionParse and SecureCmdOptionParse("[overridebar][vehicleui] hide; show")
    local k1 = GetBindingKey and GetBindingKey("ACTIONBUTTON1")
    Say("Keys - override/vehicle bar check: " .. tostring(hide) .. ", key for button 1: " .. tostring(k1)
        .. ", what that key does now: " .. tostring(k1 and GetBindingAction(k1, true)))
    for i = 1, 12 do
        local b = _G["H3z0UI_Bar1Button" .. i]
        if b then
            local action = b:GetAttribute("action")
            local kind, id = GetActionInfo(action or 0)
            local name = ""
            if kind == "spell" and id then
                local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
                name = info and info.name or (GetSpellInfo and GetSpellInfo(id)) or ""
                local sub = GetSpellSubtext and GetSpellSubtext(id)
                if sub and sub ~= "" then name = name .. " (" .. sub .. ")" end
            end
            Say(string.format("  %d: slot %s  %s %s %s  usable %s", i, tostring(action), tostring(kind), tostring(id), name,
                tostring(action and IsUsableAction(action) and true or false)))
        end
    end
end

-- Old spell ranks on the bars (Forever / Classic) ---------------------------
-- The game normally swaps a slot to the new rank when you learn it, but the pages
-- that are not showing (druid forms and so on) can be left with the old rank, and
-- pressing it says "Old spell rank". This looks at every slot and puts the highest
-- known rank in, out of combat only.
local function SpellNameID(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(id)
        if i then return i.name end
    end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function HighestRankID(name)
    if not name then return end
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(name)
        if i and i.spellID then return i.spellID end
    end
    if GetSpellInfo then return select(7, GetSpellInfo(name)) end
end

local function UpgradeRanks(report)
    if InCombatLockdown() then return 0, "combat" end
    if GetCursorInfo and GetCursorInfo() then return 0, "cursor" end
    local changed = 0
    for slot = 1, 180 do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and type(id) == "number" then
            local name = SpellNameID(id)
            local best = HighestRankID(name)
            local known = best and ((IsPlayerSpell and IsPlayerSpell(best)) or (IsSpellKnown and IsSpellKnown(best)))
            if known and best ~= id then
                local ok = pcall(function()
                    if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(best) else PickupSpell(best) end
                    PlaceAction(slot)
                end)
                if ClearCursor then ClearCursor() end
                if ok then
                    changed = changed + 1
                    if report then Say("  slot " .. slot .. ": " .. tostring(name) .. " " .. id .. " -> " .. best) end
                end
            end
        end
    end
    return changed
end

if ns.Client and ns.Client.isLegacy then
    local rf = CreateFrame("Frame")
    -- an event name this client does not know raises an error, so each one is guarded
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "LEARNED_SPELL_IN_TAB",
                          "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }) do
        pcall(rf.RegisterEvent, rf, ev)
    end
    local pending
    rf:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function() pending = nil pcall(UpgradeRanks) end)
        else
            pending = nil
        end
    end)
end

COMMANDS["fixranks"] = function()
    local n, why = UpgradeRanks(true)
    if why == "combat" then Say("Not in combat, please.") return end
    if why == "cursor" then Say("Put down what you are holding first.") return end
    Say(n == 0 and "All spells on your bars are already the highest rank." or ("Updated " .. n .. " slot(s) to the highest rank."))
end

COMMANDS["questcheck"] = function()
    if _G.H3z0UI_QuestCheck then _G.H3z0UI_QuestCheck() else Say("Nameplates are not available.") end
end

COMMANDS["npcheck"] = function()
    if _G.H3z0UI_NameplateCheck then _G.H3z0UI_NameplateCheck(Say) else Say("Nameplates are not loaded.") end
end

COMMANDS["arrowmove"] = function()
    if _G.H3z0UI_QuestArrowMove then
        Say(_G.H3z0UI_QuestArrowMove() and "Drag the arrow where you want it, then type /h3z0ui arrow move again to lock it." or "Quest Arrow locked.")
    else
        Say("The Quest Arrow is not available on this client.")
    end
end

COMMANDS["arrow"] = function()
    if _G.H3z0UI_QuestArrowToggle then
        Say("Quest Arrow " .. (_G.H3z0UI_QuestArrowToggle() and "on" or "off"))
    else
        Say("The Quest Arrow is not available on this client.")
    end
end

COMMANDS["dungeonmap"] = function()
    if _G.H3z0UI_DungeonMapCheck then _G.H3z0UI_DungeonMapCheck() else Say("The Dungeon Map is not available on this client.") end
end

-- /h3z0 whatis : after 5 seconds, lists the small frames under the mouse (even ones that ignore the
-- mouse) with their parents and picture, to find out what a stray icon belongs to.
COMMANDS["whatis"] = function()
    Say("Put the mouse over the icon now. Result in 5 seconds.")
    C_Timer.After(5, function()
        local x, y = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        x, y = x / sc, y / sc
        local found = 0
        local f = EnumerateFrames()
        while f do
            local ok, shown = pcall(f.IsVisible, f)
            if ok and shown then
                local okr, l, b, w, h = pcall(f.GetRect, f)
                if not okr then l = nil end
                if l and w and w > 0 and w < 140 and h < 140 and x >= l and x <= l + w and y >= b and y <= b + h then
                    local chain, p = "", f
                    for _ = 1, 5 do
                        if not p then break end
                        chain = chain .. (p:GetName() or "?") .. " < "
                        p = p:GetParent()
                    end
                    local tex = ""
                    for _, r in ipairs({ f:GetRegions() }) do
                        if r.GetTexture and r:IsShown() then
                            local t = r:GetTexture()
                            if t ~= nil then tex = tex .. " [" .. tostring(t) .. "]" end
                        end
                    end
                    Say(chain .. tex)
                    found = found + 1
                    if found >= 8 then break end
                end
            end
            f = EnumerateFrames(f)
        end
        if found == 0 then Say("Nothing found under the mouse.") end
    end)
end

COMMANDS["layoutintro"] = function()
    if _G.H3z0UI_LayoutIntroToggle then _G.H3z0UI_LayoutIntroToggle(Say) else Say("The Layout Mode opening animation is not available.") end
end

COMMANDS["layoutroutes"] = function()
    local U = ns.H3z0UI_LayoutMode_Utils
    if U and U.AuditRoutes then U.AuditRoutes(Say) else Say("Layout Mode is not loaded yet.") end
end


COMMANDS["tipcheck"] = function()
    if _G.H3z0UI_TooltipCheck then _G.H3z0UI_TooltipCheck(Say) else Say("Tooltips are not loaded.") end
end

COMMANDS["lkcheck"] = function()
    if _G.H3z0UI_LorekeeperCheck then _G.H3z0UI_LorekeeperCheck(Say) else Say("Lorekeeper is not loaded.") end
end

COMMANDS["badtex"] = function()
    -- finds shown pictures that name an atlas this client does not have (they draw as a red ?)
    local found, shown = 0, 0
    local function Path(f)
        local parts, n = {}, 0
        while f and n < 6 do
            local nm = f.GetName and f:GetName()
            parts[#parts + 1] = nm or (f.GetObjectType and f:GetObjectType()) or "?"
            f = f.GetParent and f:GetParent()
            n = n + 1
        end
        return table.concat(parts, " < ")
    end
    local function Check(owner, region)
        if not (region and region.GetObjectType and region:GetObjectType() == "Texture") then return end
        local ok, vis = pcall(region.IsVisible, region)
        if not (ok and vis) then return end
        shown = shown + 1
        local okA, atlas = pcall(region.GetAtlas, region)
        if okA and type(atlas) == "string" and atlas ~= "" and C_Texture and C_Texture.GetAtlasInfo
            and not C_Texture.GetAtlasInfo(atlas) then
            found = found + 1
            if found <= 15 then
                local w, h = region:GetSize()
                Say(string.format("  missing atlas '%s' (%dx%d) on %s", atlas, w or 0, h or 0, Path(owner)))
            end
        end
    end
    local f = EnumerateFrames()
    while f do
        local forb = f.IsForbidden and f:IsForbidden()
        if not forb then
            local okR, regions = pcall(function() return { f:GetRegions() } end)
            if okR then for _, r in ipairs(regions) do Check(f, r) end end
        end
        f = EnumerateFrames(f)
    end
    Say(found == 0 and ("No missing atlas found (" .. shown .. " pictures checked).") or (found .. " missing atlas picture(s) found, first ones listed above."))
end

COMMANDS["whatishere"] = function()
    -- tells which picture sits under the mouse (for the red ? square): type this command, move the
    -- mouse over the ?, wait. It reads the position after 5 seconds.
    Say("Move the mouse over the red ? now and keep it still. Reading in 5 seconds...")
    C_Timer.After(5, function()
        local cx, cy = GetCursorPosition()
        local list = {}
        local function Path(f)
            local parts, n = {}, 0
            while f and n < 7 do
                local nm = f.GetName and f:GetName()
                parts[#parts + 1] = nm or (f.GetObjectType and f:GetObjectType()) or "?"
                f = f.GetParent and f:GetParent()
                n = n + 1
            end
            return table.concat(parts, " < ")
        end
        local function Check(owner, r)
            if not (r and r.GetObjectType and r:GetObjectType() == "Texture") then return end
            local okV, vis = pcall(r.IsVisible, r)
            if not (okV and vis) then return end
            local okR, l, b, w, h = pcall(r.GetRect, r)
            if not (okR and l and w) then return end
            local sc = r:GetEffectiveScale()
            if not sc or sc == 0 then return end
            local x, y = cx / sc, cy / sc
            if x < l or x > l + w or y < b or y > b + h then return end
            if w > 600 or h > 600 then return end            -- big backgrounds are not it
            local okT, tex = pcall(r.GetTexture, r)
            local okA, atlas = pcall(r.GetAtlas, r)
            list[#list + 1] = string.format("  %dx%d  texture=%s  atlas=%s  on %s", w, h,
                tostring(okT and tex or "-"), tostring(okA and atlas or "-"), Path(owner))
        end
        local f = EnumerateFrames()
        while f do
            if not (f.IsForbidden and f:IsForbidden()) then
                local ok, regions = pcall(function() return { f:GetRegions() } end)
                if ok then for _, r in ipairs(regions) do pcall(Check, f, r) end end
            end
            f = EnumerateFrames(f)
        end
        if #list == 0 then Say("No small picture found under the mouse. Try again with the mouse exactly on the ?.") return end
        Say(#list .. " picture(s) under the mouse:")
        for i = 1, math.min(#list, 12) do Say(list[i]) end
    end)
end

COMMANDS["ejcheck"] = function()
    local function Has(n) return type(_G[n]) == "function" and "yes" or "NO" end
    Say("Adventure Guide check: ToggleEncounterJournal " .. Has("ToggleEncounterJournal")
        .. ", CanShowEncounterJournal " .. Has("CanShowEncounterJournal")
        .. ", EncounterJournal frame " .. (_G.EncounterJournal and "yes" or "NO")
        .. ", EJMicroButton " .. (_G.EJMicroButton and "yes" or "NO"))
end

COMMANDS["intdebug"] = function()
    local I = _G.H3z0UI_Interrupts
    if not (I and I.SetDebug) then Say("The Interrupt Tracker is not available.") return end
    I.SetDebug(not I.IsDebug())
    Say(I.IsDebug() and "Interrupt debug is ON. Fight something with a group member or companion, then send me the lines. Type /h3z0ui intdebug again to stop."
        or "Interrupt debug is off.")
end
-- /h3z0 cpu: which addons use the most time. Shapeshift a few times, then type it: the Peak column is the
-- slowest single frame since login (or since /h3z0 cpureset), which is what a spike is.
COMMANDS["cpu"] = function()
    local P = C_AddOnProfiler
    if not (P and P.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric) then
        Say("This game does not have the addon profiler.")
        return
    end
    if P.IsEnabled and not P.IsEnabled() then Say("The addon profiler is off in this game (Options > Advanced).") return end
    local list = {}
    local tracking = _G.H3z0UI_CpuTrack
    if tracking and tracking.peaks then
        for name, peak in pairs(tracking.peaks) do list[#list + 1] = { name = name, peak = peak } end
        Say(string.format("Slowest single frame per addon (ms) in the last %d seconds (since /h3z0 cpureset):", math.floor(GetTime() - tracking.since)))
    else
        local num = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
        for i = 1, num do
            local name = C_AddOns.GetAddOnInfo(i)
            if name and C_AddOns.IsAddOnLoaded(name) then
                local okPk, peak = pcall(P.GetAddOnMetric, name, Enum.AddOnProfilerMetric.PeakTime)
                if okPk and type(peak) == "number" then list[#list + 1] = { name = name, peak = peak } end
            end
        end
        Say("Slowest single frame per addon (ms) since login, which includes loading screens. For a real test type /h3z0 cpureset first:")
    end
    table.sort(list, function(x, y) return x.peak > y.peak end)
    for i = 1, math.min(10, #list) do
        Say(string.format("%2d. %s  peak %.1f", i, list[i].name, list[i].peak))
    end
end
-- /h3z0 cpureset: start counting now (the game cannot reset its own peaks). It reads each addon's time
-- every frame until /h3z0 cpustop, so shapeshift, then type /h3z0 cpu.
COMMANDS["cpureset"] = function()
    local P = C_AddOnProfiler
    if not (P and P.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric and Enum.AddOnProfilerMetric.LastTime) then
        Say("This game does not have the addon profiler.")
        return
    end
    local names = {}
    local num = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(name) then names[#names + 1] = name end
    end
    local t = { peaks = {}, since = GetTime() }
    _G.H3z0UI_CpuTrack = t
    local f = _G.H3z0UI_CpuTrackFrame or CreateFrame("Frame")
    _G.H3z0UI_CpuTrackFrame = f
    f:SetScript("OnUpdate", function()
        local metric = Enum.AddOnProfilerMetric.LastTime
        local cur = _G.H3z0UI_CpuTrack
        if not cur then f:SetScript("OnUpdate", nil) return end
        for i = 1, #names do
            local ok, v = pcall(P.GetAddOnMetric, names[i], metric)
            if ok and type(v) == "number" and v > (cur.peaks[names[i]] or 0) then cur.peaks[names[i]] = v end
        end
    end)
    Say("Counting. Shapeshift a few times, then type /h3z0 cpu. /h3z0 cpustop ends it.")
end
COMMANDS["abtime"] = function()
    local ab = ns.ActionBarsOwned
    local perf = ab and ab.abPerf
    if not perf or next(perf) == nil then Say("Nothing measured yet. Shapeshift, then type /h3z0 abtime.") return end
    local list = {}
    for k, v in pairs(perf) do list[#list + 1] = { k = k, v = v } end
    table.sort(list, function(x, y) return x.v > y.v end)
    Say("Action bars, slowest run of each step (ms):")
    for _, e in ipairs(list) do Say(string.format("  %s: %.1f", e.k, e.v)) end
    wipe(perf)
end
COMMANDS["charwindow"] = function()
    if _G.H3z0UI_ToggleCharacterWindow then _G.H3z0UI_ToggleCharacterWindow()
    else Say("The H3z0 character window is not loaded.") end
end
-- /h3z0 chartabs: what the game's character window tabs are, for the H3z0 character window
COMMANDS["chartabs"] = function()
    local g = CharacterFrame
    if not g then Say("No character window.") return end
    local mt = g.ModeTabs
    local tabs = (mt and type(mt.Tabs) == "table") and mt.Tabs or nil
    if not tabs then
        tabs = {}
        for i = 1, 12 do local t = _G["CharacterFrameTab" .. i] if not t then break end tabs[#tabs + 1] = t end
    end
    Say("Game tabs: " .. #tabs .. (mt and " (side tabs)" or " (bottom tabs)"))
    for i, t in ipairs(tabs) do
        local parts = {}
        for _, k in ipairs({ "tooltipText", "tooltip", "tooltipTitle", "name", "label", "mode", "frameName", "tabID", "id" }) do
            local v = t[k]
            if v ~= nil and type(v) ~= "table" and type(v) ~= "function" then parts[#parts + 1] = k .. "=" .. tostring(v) end
        end
        local okN, n = pcall(t.GetName, t)
        Say(string.format("  %d. %s shown=%s %s", i, tostring(okN and n or "?"), tostring(t:IsShown()), table.concat(parts, " ")))
    end
    local pages = {}
    for _, c in ipairs({ g:GetChildren() }) do
        local okN, n = pcall(c.GetName, c)
        if okN and n then pages[#pages + 1] = n .. (c:IsShown() and "*" or "") end
    end
    Say("Named parts (* = shown): " .. table.concat(pages, ", "))
    -- what the game offers to switch pages
    local fns = {}
    for k, v in pairs(g) do
        if type(v) == "function" and type(k) == "string" and (k:find("Tab") or k:find("Mode") or k:find("Show") or k:find("Page")) then fns[#fns + 1] = k end
    end
    local mtab = mt or {}
    for k, v in pairs(mtab) do
        if type(v) == "function" and type(k) == "string" then fns[#fns + 1] = "ModeTabs." .. k end
    end
    table.sort(fns)
    Say("Window functions: " .. table.concat(fns, ", "))
    local globals = {}
    for _, n in ipairs({ "SkillFrame", "HonorFrame", "PVPFrame", "PVPParentFrame", "TokenFrame", "ReputationFrame",
        "PetPaperDollFrame", "StatisticsFrame", "CharacterStatsPane", "AchievementFrame" }) do
        if _G[n] then
            local p = _G[n]:GetParent()
            local okP, pn = pcall(p and p.GetName or function() end, p)
            globals[#globals + 1] = n .. "(in " .. tostring(okP and pn or "?") .. ")"
        end
    end
    Say("Known pages present: " .. table.concat(globals, ", "))
    for i, t in ipairs(tabs) do
        local hasClick = t:GetScript("OnClick") and "OnClick" or ""
        local hasDown = t:GetScript("OnMouseDown") and "OnMouseDown" or ""
        local hasUp = t:GetScript("OnMouseUp") and "OnMouseUp" or ""
        Say(string.format("  tab %d scripts: %s %s %s", i, hasClick, hasDown, hasUp))
    end
end
COMMANDS["inspectwindow"] = function()
    if _G.H3z0UI_ToggleInspectWindow then _G.H3z0UI_ToggleInspectWindow()
    else Say("The H3z0 inspect window is not loaded.") end
end
COMMANDS["inspecttabs"] = function()
    local g = InspectFrame
    if not g then Say("Inspect someone first.") return end
    local mt = g.ModeTabs
    local tabs = (mt and type(mt.Tabs) == "table") and mt.Tabs or {}
    if #tabs == 0 then for i = 1, 8 do local t = _G["InspectFrameTab" .. i] if not t then break end tabs[#tabs + 1] = t end end
    Say("Inspect tabs: " .. #tabs)
    for i, t in ipairs(tabs) do
        local okN, n = pcall(t.GetName, t)
        local okT, txt = pcall(t.GetText or function() end, t)
        Say(string.format("  %d. %s shown=%s text=%s tooltip=%s frame=%s", i, tostring(okN and n), tostring(t:IsShown()),
            tostring(okT and txt), tostring(t.tooltipText), tostring(t.frameName)))
    end
    local parts = {}
    for _, c in ipairs({ g:GetChildren() }) do
        local okN, n = pcall(c.GetName, c)
        if okN and n then parts[#parts + 1] = n .. (c:IsShown() and "*" or "") end
    end
    Say("Parts: " .. table.concat(parts, ", "))
end
COMMANDS["cpustop"] = function()
    _G.H3z0UI_CpuTrack = nil
    if _G.H3z0UI_CpuTrackFrame then _G.H3z0UI_CpuTrackFrame:SetScript("OnUpdate", nil) end
    Say("Counting stopped.")
end
COMMANDS["npperf"] = function()
    if _G.H3z0UI_NameplatePerf then _G.H3z0UI_NameplatePerf() else Say("Nameplates are not available.") end
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


