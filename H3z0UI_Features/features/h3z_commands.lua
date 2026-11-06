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
