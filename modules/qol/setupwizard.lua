---------------------------------------------------------------------------
-- H3z0 UI Setup Wizard  (0.22.6)
--
-- A small step-by-step window that sets H3z0 UI up for the way the player plays:
--   1. Device       - PC (mouse + keyboard) or Steam Deck / Handheld (controller, compact HUD)
--   2. Nameplates   - none / Plater / Platynator / BetterBlizzPlates (strings live in importstrings/)
--   3. Features     - Bottom Bar, minimap, chat, unit frames, action bars, tooltips, ...
--   4. Extras       - map coordinates, party frames, combat timer, M+ timer, consumables, ...
--   5. Done         - summary + reload button + Layout Mode
--
-- * Shown automatically ONCE on a brand-new install (db.global.setupShown), from handheld.lua's login check.
--   Existing users are never interrupted (firstRunProfile == "skipped").
-- * Always available again: /h3z0ui setup   or   the "Setup Wizard" page in the options sidebar (below Import).
-- * Closing the window with Esc / X does nothing permanent (it comes back next login on a new install);
--   "Skip (use defaults)" keeps the addon's default behaviour and never asks again.
-- * Choices are remembered in profile.setup = { completed, device, nameplates, version }.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local Setup = {}
_G.H3z0UI_Setup = Setup

local FONT = "Interface\\AddOns\\H3z0UI\\assets\\Expressway.TTF"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local PANEL_ID = "bottombar"
local WIZARD_VERSION = 1

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Core()
    return (_G.H3z0UI and _G.H3z0UI.H3z0UICore) or ns.Addon
end

local function Profile()
    return Helpers.GetProfile()
end

local function Global()
    local c = Core()
    return c and c.db and c.db.global
end

local function IsLoaded(addon)
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon)) and true or false
end

local function HH()
    return _G.H3z0UI_Handheld
end

local function Say(msg)
    print("|cff34D399H3z0 UI:|r " .. msg)
end

local function GetAccent()
    local p = Profile()
    local g = p and p.general
    if g and g.skinUseClassColor then
        local _, class = UnitClass("player")
        local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if cc then return cc.r, cc.g, cc.b end
    end
    local a = g and g.addonAccentColor
    if a and a[1] then return a[1], a[2], a[3] end
    return 0.204, 0.827, 0.6
end

local function SetupTable()
    local p = Profile()
    if not p then return nil end
    p.setup = p.setup or {}
    return p.setup
end

---------------------------------------------------------------------------
-- Option lists
---------------------------------------------------------------------------
local NAMEPLATES = {
    { value = "none",      label = "No nameplate addon", desc = "Keep Blizzard's own nameplates.", addon = nil },
    { value = "plater",    label = "Plater",             desc = "H3z0 UI's Plater profile - one-click import.", addon = "Plater" },
    { value = "platynator", label = "Platynator",        desc = "H3z0 UI's Platynator profile - copy the string and import it.", addon = "Platynator" },
    { value = "bbp",       label = "BetterBlizzPlates",  desc = "H3z0 UI's BetterBlizzPlates profile - copy the string and import it.", addon = "BetterBlizzPlates" },
}

local SCALES = {
    { value = "compact", label = "Compact (0.85)" },
    { value = "perfect", label = "Pixel-perfect" },
    { value = "comfy",   label = "Comfortable (1.15)" },
}

local function ScaleFor(choice)
    local hh = HH()
    if choice == "perfect" then return hh and hh.AutoScale and hh.AutoScale() or 0.96 end
    if choice == "comfy" then return 1.15 end
    return 0.85
end

-- Bottom bar is a datapanel with id "bottombar"
local function BarPanels(create)
    local p = Profile()
    if not p then return nil end
    if not p.h3z0uiDatatexts then
        if not create then return nil end
        p.h3z0uiDatatexts = { panels = {} }
    end
    if not p.h3z0uiDatatexts.panels then
        if not create then return nil end
        p.h3z0uiDatatexts.panels = {}
    end
    return p.h3z0uiDatatexts.panels
end

local function FindBar()
    local panels = BarPanels(false)
    if not panels then return nil end
    for i, panel in ipairs(panels) do
        if panel.id == PANEL_ID then return panel, i end
    end
end

local FEATURES = {
    {
        id = "bottombar", label = "Bottom Bar",
        desc = "Full-width info bar: menu icons, clock, gold, bags, location.",
        get = function() local b = FindBar(); return b ~= nil and b.enabled ~= false end,
        set = function(on)
            local bar = FindBar()
            if on then
                if not bar then
                    local panels = BarPanels(true)
                    if panels and ns.BottomBarPreset then table.insert(panels, ns.BottomBarPreset()) end
                else
                    bar.enabled = true
                end
            elseif bar then
                bar.enabled = false
            end
            local core = Core()
            local dp = core and core.Datapanels
            if dp and dp.RefreshAll then pcall(dp.RefreshAll, dp) end
            if _G.H3z0UI_RefreshBottomBar then pcall(_G.H3z0UI_RefreshBottomBar) end
        end,
    },
    { id = "minimap",     label = "Minimap",          desc = "Skinned minimap with clock and zone text.",       tbl = "minimap",         refresh = "H3z0UI_RefreshMinimap" },
    { id = "chat",        label = "Chat",             desc = "Skinned chat window with a copy button.",         tbl = "chat",            refresh = "H3z0UI_RefreshChat" },
    { id = "unitframes",  label = "Unit frames",      desc = "H3z0 player, target, focus and pet frames.",      tbl = "h3z0uiUnitFrames", refresh = "H3z0UI_RefreshUnitFrames" },
    { id = "actionbars",  label = "Action bars",      desc = "Skinned action bars (fade, sizes, keybinds).",    tbl = "actionBars",      refresh = "H3z0UI_RefreshActionBars" },
    { id = "tooltip",     label = "Tooltips",         desc = "H3z0 tooltip look and extras.",                   tbl = "tooltip",         refresh = "H3z0UI_RefreshTooltips" },
    { id = "character",   label = "Character pane",   desc = "Skinned character and inspect windows.",          tbl = "character" },
    { id = "quickaccess", label = "Quick Access",     desc = "Group Finder quick access panel.",                tbl = "quickAccess",     refresh = "H3z0UI_RefreshQuickAccess" },
    { id = "raidbuffs",   label = "Missing raid buffs", desc = "Shows the raid buffs your group is missing.",   tbl = "raidBuffs",       refresh = "H3z0UI_RefreshRaidBuffs" },
    { id = "hovername",   label = "Hover name",       desc = "Name text that follows the mouse cursor.",        tbl = "hoverName",       refresh = "H3z0UI_RefreshHoverName" },
}

for _, f in ipairs(FEATURES) do
    if f.tbl then
        f.get = function()
            local p = Profile()
            local t = p and p[f.tbl]
            return type(t) == "table" and t.enabled ~= false
        end
        f.set = function(on)
            local p = Profile()
            local t = p and p[f.tbl]
            if type(t) ~= "table" then return end
            t.enabled = on and true or false
            local fn = f.refresh and _G[f.refresh]
            if fn then pcall(fn) end
        end
    end
end

-- Step 4: extras and helpers (path = profile table + key, so each is one switch)
local IS_FOREVER = ns.Client and ns.Client.isForever
local EXTRAS = {
    { id = "coords",     label = "Map coordinates",   desc = "Your X,Y position on the minimap (toggle any time with the XY button on the minimap).",
      path = { "minimap", "showCoords" }, refresh = "H3z0UI_RefreshMinimap" },
    { id = "party",      label = "H3z0 party frames", desc = "Round-portrait party frames with ready check, auras and the Raid Control tab.",
      path = { "partyFrames", "enabled" }, refresh = "H3z0UI_RefreshPartyFrames" },
    { id = "combattimer",label = "Combat timer",      desc = "Small timer that counts how long you have been in combat.",
      path = { "combatTimer", "enabled" }, refresh = "H3z0UI_RefreshCombatTimer" },
    { id = "mplus",      label = "M+ timer",          desc = "Mythic+ timer with forces, deaths and boss splits.",
      path = { "mplusTimer", "enabled" }, hide = IS_FOREVER },
    { id = "consumables",label = "Consumable check",  desc = "Reminds you about missing food, flask, rune and weapon buffs.",
      path = { "general", "consumableCheckEnabled" }, refresh = "H3z0UI_RefreshConsumables" },
    { id = "crosshair",  label = "Crosshair",         desc = "Small crosshair in the middle of the screen.",
      path = { "crosshair", "enabled" }, refresh = "H3z0UI_RefreshCrosshair" },
    { id = "totems",     label = "Totem bar",         desc = "Shaman totems as a bar of icons with timers.",
      path = { "totemBar", "enabled" }, refresh = "H3z0UI_RefreshTotemBar" },
    { id = "skyriding",  label = "Skyriding bar",     desc = "Vigor / speed display while skyriding.",
      path = { "skyriding", "enabled" }, refresh = "H3z0UI_RefreshSkyriding", hide = IS_FOREVER },
}
do
    local list = {}
    for _, e in ipairs(EXTRAS) do if not e.hide then list[#list + 1] = e end end
    EXTRAS = list
end
for _, e in ipairs(EXTRAS) do
    e.get = function()
        local p = Profile()
        local t = p and p[e.path[1]]
        return type(t) == "table" and t[e.path[2]] == true
    end
    e.set = function(on)
        local p = Profile()
        if not p then return end
        p[e.path[1]] = type(p[e.path[1]]) == "table" and p[e.path[1]] or {}
        p[e.path[1]][e.path[2]] = on and true or false
        local fn = e.refresh and _G[e.refresh]
        if fn then pcall(fn) end
    end
end

---------------------------------------------------------------------------
-- State (what the wizard currently shows) and Apply
---------------------------------------------------------------------------
local state = {}

local function LoadState()
    local s = SetupTable() or {}
    local hh = HH()
    local p = Profile()
    local hc = p and p.handheld or {}

    local device = s.device
    if not device then
        if hc.enabled then device = "handheld"
        elseif hc.pcController then device = "pccontroller"
        elseif hh and hh.IsSmallScreen and hh.IsSmallScreen() then device = "handheld"
        else device = "pc" end
    end
    state.device = device
    state.scale = s.scale or "compact"
    state.nameplates = s.nameplates or "none"
    state.features = {}
    for _, f in ipairs(FEATURES) do
        state.features[f.id] = f.get() and true or false
    end
    state.extras = {}
    for _, e in ipairs(EXTRAS) do
        state.extras[e.id] = e.get() and true or false
    end
end

--- Apply the chosen options. Returns { lines = {...}, needReload = bool }.
function Setup.Apply()
    local p = Profile()
    local result = { lines = {}, needReload = false }
    if not p then return result end
    local hh = HH()

    -- 1. Device
    p.handheld = p.handheld or {}
    local hc = p.handheld
    hc.autoApplied = true
    hc.setupPrompted = true
    if state.device == "handheld" then
        hc.keepBarsVisible = true
        hc.fitOptionsWindow = true
        hc.uiScale = ScaleFor(state.scale)
        if hh and hh.SetEnabled then hh.SetEnabled(true, true) end
        result.needReload = true
        result.lines[#result.lines + 1] = string.format("Steam Deck / Handheld layout ON (UI scale %.2f)", hc.uiScale)
    else
        hc.autoDetect = false
        -- PC or PC + Controller: set the addon choice first, Handheld Mode off uses it
        hc.pcController = (state.device == "pccontroller")
        if hh and hh.SetEnabled then hh.SetEnabled(false, true) end
        if hh and hh.SetPCController then hh.SetPCController(hc.pcController, true) end
        result.needReload = true
        result.lines[#result.lines + 1] = hc.pcController
            and "PC layout with a controller (ConsolePort on, Action Combat Mode off)"
            or "PC layout (Handheld Mode OFF)"
    end

    -- 3. Features (done before the unit-frame layout re-run so the preset sees the final state)
    local changed = {}
    for _, f in ipairs(FEATURES) do
        local want = state.features[f.id] and true or false
        local have = f.get() and true or false
        if want ~= have then
            f.set(want)
            changed[#changed + 1] = (want and "+ " or "- ") .. f.label
            result.needReload = true
        end
    end
    if #changed > 0 then
        result.lines[#result.lines + 1] = "Features changed: " .. table.concat(changed, ", ")
    else
        result.lines[#result.lines + 1] = "Features: no change"
    end

    -- 4. Extras
    local extrasChanged = {}
    for _, e in ipairs(EXTRAS) do
        local want = state.extras and state.extras[e.id] and true or false
        local have = e.get() and true or false
        if want ~= have then
            e.set(want)
            extrasChanged[#extrasChanged + 1] = (want and "+ " or "- ") .. e.label
            result.needReload = true
        end
    end
    if #extrasChanged > 0 then
        result.lines[#result.lines + 1] = "Extras changed: " .. table.concat(extrasChanged, ", ")
    end

    -- 2. Nameplates (the strings themselves are imported from the Done page / Nameplates tab)
    local np
    for _, o in ipairs(NAMEPLATES) do if o.value == state.nameplates then np = o end end
    if np and np.value ~= "none" then
        result.lines[#result.lines + 1] = "Nameplates: " .. np.label .. (IsLoaded(np.addon) and "" or "  (addon not installed yet)")
    else
        result.lines[#result.lines + 1] = "Nameplates: Blizzard default"
    end

    -- Remember
    local s = SetupTable()
    s.completed = true
    s.device = state.device
    s.scale = state.scale
    s.nameplates = state.nameplates
    s.version = WIZARD_VERSION
    local g = Global()
    if g then g.setupShown = true end

    return result
end

---------------------------------------------------------------------------
-- Skip: keep the addon's pre-wizard behaviour (switch Handheld Mode on once on a small screen)
---------------------------------------------------------------------------
function Setup.Skip()
    local p = Profile()
    local hh = HH()
    if p then
        p.handheld = p.handheld or {}
        local hc = p.handheld
        local wasApplied = hc.autoApplied
        hc.autoApplied = true
        hc.setupPrompted = true
        if not wasApplied and hc.autoDetect ~= false and hh and hh.IsSmallScreen and hh.IsSmallScreen() and not hc.enabled then
            hh.SetEnabled(true)
        end
        local s = SetupTable()
        s.completed = true
        s.skipped = true
        s.version = WIZARD_VERSION
    end
    local g = Global()
    if g then g.setupShown = true end
end

---------------------------------------------------------------------------
-- Auto show (called from handheld.lua's login check)
---------------------------------------------------------------------------
function Setup.ShouldAutoShow()
    local g = Global()
    if not g then return false end
    if g.setupShown == true then return false end
    if g.firstRunProfile == "skipped" then return false end   -- existing install: never interrupt
    return true
end

---------------------------------------------------------------------------
-- UI building blocks
---------------------------------------------------------------------------
local function MakeButton(parent, text, w, h, primary, ar, ag, ab, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h or 30)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    local label = b:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 12, "")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)
    b.label = label
    local function Idle()
        if b.disabled then
            b:SetBackdropColor(0.06, 0.08, 0.12, 1)
            b:SetBackdropBorderColor(0.15, 0.18, 0.22, 1)
            label:SetTextColor(0.35, 0.38, 0.42, 1)
        elseif primary then
            b:SetBackdropColor(ar, ag, ab, 0.9)
            b:SetBackdropBorderColor(ar, ag, ab, 1)
            label:SetTextColor(0.04, 0.06, 0.1, 1)
        else
            b:SetBackdropColor(0.08, 0.11, 0.17, 1)
            b:SetBackdropBorderColor(0.25, 0.3, 0.35, 1)
            label:SetTextColor(0.8, 0.84, 0.88, 1)
        end
    end
    b.Idle = Idle
    Idle()
    b:SetScript("OnEnter", function()
        if b.disabled then return end
        if primary then
            b:SetBackdropColor(math.min(1, ar + 0.15), math.min(1, ag + 0.15), math.min(1, ab + 0.15), 1)
        else
            b:SetBackdropBorderColor(ar, ag, ab, 1)
            label:SetTextColor(1, 1, 1, 1)
        end
    end)
    b:SetScript("OnLeave", Idle)
    b:SetScript("OnClick", function(self)
        if self.disabled then return end
        onClick(self)
    end)
    function b:SetDisabledLook(disabled)
        self.disabled = disabled and true or false
        Idle()
    end
    return b
end

local function MakeText(parent, size, r, g, b, outline)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, outline or "")
    fs:SetTextColor(r, g, b, 1)
    fs:SetJustifyH("LEFT")
    return fs
end

--- A selectable card (radio style). Returns the button; call btn:SetSelected(bool).
local function MakeCard(parent, w, h, title, desc, ar, ag, ab, onClick, descRight)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })

    local dot = CreateFrame("Frame", nil, b, "BackdropTemplate")
    dot:SetSize(14, 14)
    dot:SetPoint("LEFT", 12, 0)
    dot:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    local dotFill = dot:CreateTexture(nil, "OVERLAY")
    dotFill:SetPoint("TOPLEFT", 3, -3)
    dotFill:SetPoint("BOTTOMRIGHT", -3, 3)
    dotFill:SetColorTexture(ar, ag, ab, 1)

    b.title = MakeText(b, 13, 0.92, 0.94, 0.97, "")
    b.title:SetPoint("TOPLEFT", 36, -10)
    b.title:SetText(title)
    b.desc = MakeText(b, 10, 0.6, 0.65, 0.7)
    b.desc:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -4)
    b.desc:SetPoint("RIGHT", b, "RIGHT", -(descRight or 110), 0)
    b.desc:SetText(desc or "")
    b.status = MakeText(b, 10, 0.6, 0.65, 0.7)
    b.status:SetPoint("RIGHT", -12, 0)
    b.status:SetJustifyH("RIGHT")

    function b:SetSelected(sel)
        self.selected = sel and true or false
        if sel then
            self:SetBackdropColor(ar * 0.16 + 0.05, ag * 0.16 + 0.07, ab * 0.16 + 0.1, 1)
            self:SetBackdropBorderColor(ar, ag, ab, 1)
            dot:SetBackdropColor(0.03, 0.045, 0.08, 1)
            dot:SetBackdropBorderColor(ar, ag, ab, 1)
            dotFill:Show()
        else
            self:SetBackdropColor(0.08, 0.11, 0.17, 1)
            self:SetBackdropBorderColor(0.2, 0.25, 0.3, 1)
            dot:SetBackdropColor(0.03, 0.045, 0.08, 1)
            dot:SetBackdropBorderColor(0.35, 0.4, 0.45, 1)
            dotFill:Hide()
        end
    end
    b:SetScript("OnEnter", function(self)
        if not self.selected then self:SetBackdropBorderColor(ar, ag, ab, 0.6) end
    end)
    b:SetScript("OnLeave", function(self) self:SetSelected(self.selected) end)
    b:SetScript("OnClick", onClick)
    b:SetSelected(false)
    return b
end

--- A checkbox row (square toggle + label + description).
local function MakeToggle(parent, w, label, desc, ar, ag, ab, onChange)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(w, 30)

    local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 2, 0)
    box:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    local fill = box:CreateTexture(nil, "OVERLAY")
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    fill:SetColorTexture(ar, ag, ab, 1)

    local title = MakeText(row, 12, 0.92, 0.94, 0.97)
    title:SetPoint("LEFT", box, "RIGHT", 10, 0)
    title:SetWidth(150)
    title:SetText(label)
    local d = MakeText(row, 10, 0.6, 0.65, 0.7)
    d:SetPoint("LEFT", title, "RIGHT", 8, 0)
    d:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    d:SetText(desc or "")

    function row:SetChecked(on)
        self.checked = on and true or false
        box:SetBackdropColor(0.03, 0.045, 0.08, 1)
        if on then
            box:SetBackdropBorderColor(ar, ag, ab, 1)
            fill:Show()
        else
            box:SetBackdropBorderColor(0.35, 0.4, 0.45, 1)
            fill:Hide()
        end
    end
    row:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        onChange(self.checked)
    end)
    row:SetChecked(false)
    return row
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local wizard
local TOTAL_STEPS = 4
local STEP_TITLES = {
    "How do you play?",
    "Which nameplates do you want?",
    "Which features do you want?",
    "Extras and helpers",
    "All set",
}

local function RefreshDevicePage(f)
    f.deviceCards.pc:SetSelected(state.device == "pc")
    if f.deviceCards.pccontroller then f.deviceCards.pccontroller:SetSelected(state.device == "pccontroller") end
    f.deviceCards.handheld:SetSelected(state.device == "handheld")
    f.scaleRow:SetShown(state.device == "handheld")
    for value, btn in pairs(f.scaleButtons) do
        btn.picked = (value == state.scale)
        if btn.picked then
            btn:SetBackdropBorderColor(f.ar, f.ag, f.ab, 1)
            btn:SetBackdropColor(f.ar * 0.2 + 0.05, f.ag * 0.2 + 0.07, f.ab * 0.2 + 0.1, 1)
            btn.label:SetTextColor(1, 1, 1, 1)
        else
            btn:SetBackdropBorderColor(0.25, 0.3, 0.35, 1)
            btn:SetBackdropColor(0.08, 0.11, 0.17, 1)
            btn.label:SetTextColor(0.8, 0.84, 0.88, 1)
        end
    end
    local hh = HH()
    if hh and hh.GetResolution then
        local w, h = hh.GetResolution()
        local extra = ""
        if hh.IsSteamDeckResolution and hh.IsSteamDeckResolution() then
            extra = "  -  this looks like a Steam Deck"
        elseif hh.IsSmallScreen and hh.IsSmallScreen() then
            extra = "  -  small screen, probably a handheld"
        end
        f.screenInfo:SetText(string.format("Detected screen: %dx%d%s", w, h, extra))
    end
end

local function RefreshNameplatePage(f)
    for _, o in ipairs(NAMEPLATES) do
        local card = f.npCards[o.value]
        card:SetSelected(state.nameplates == o.value)
        if o.addon then
            if IsLoaded(o.addon) then
                card.status:SetText("|cff33ee88installed|r")
            else
                card.status:SetText("|cffff6666not installed|r")
            end
        else
            card.status:SetText("")
        end
    end
end

local function RefreshFeaturePage(f)
    for _, feat in ipairs(FEATURES) do
        f.featureRows[feat.id]:SetChecked(state.features[feat.id])
    end
end

local function RefreshExtrasPage(f)
    for _, e in ipairs(EXTRAS) do
        if f.extraRows[e.id] then f.extraRows[e.id]:SetChecked(state.extras[e.id]) end
    end
end

local function BuildDoneText(f, result)
    local lines = {}
    for _, l in ipairs(result.lines) do lines[#lines + 1] = "|cff" .. string.format("%02x%02x%02x", math.floor(f.ar * 255), math.floor(f.ag * 255), math.floor(f.ab * 255)) .. "-|r  " .. l end
    f.doneBody:SetText(table.concat(lines, "\n"))

    local np = state.nameplates
    local hint = ""
    if np == "plater" then
        hint = IsLoaded("Plater") and "Press \"Import into Plater\" to load H3z0 UI's Plater profile (Plater switches to its own \"H3z0 UI\" profile and reloads)."
            or "Install Plater, then run this wizard again (or use Options > Nameplates) to import the profile."
    elseif np == "platynator" or np == "bbp" then
        hint = "Open Options > Nameplates, copy the string and use the addon's own Import."
    end
    f.doneHint:SetText(hint)
    f.importPlater:SetShown(np == "plater" and IsLoaded("Plater"))
    f.openOptions:SetShown(np == "platynator" or np == "bbp")
    f.reloadBtn:SetShown(result.needReload)
end

local function ShowStep(f, step)
    f.step = step
    for i, page in ipairs(f.pages) do page:SetShown(i == step) end
    f.stepTitle:SetText(STEP_TITLES[step])
    if step <= TOTAL_STEPS then
        f.stepCount:SetText(string.format("STEP %d OF %d", step, TOTAL_STEPS))
    else
        f.stepCount:SetText("DONE")
    end
    for i, dotTex in ipairs(f.dots) do
        if i == step then dotTex:SetColorTexture(f.ar, f.ag, f.ab, 1)
        else dotTex:SetColorTexture(0.25, 0.3, 0.35, 1) end
    end

    local onDone = step > TOTAL_STEPS
    f.back:SetShown(not onDone)
    f.next:SetShown(not onDone)
    f.skip:SetShown(not onDone)
    f.close:SetShown(onDone)
    f.back:SetDisabledLook(step == 1)
    f.next.label:SetText(step == TOTAL_STEPS and "Apply & finish" or "Next")

    if step == 1 then RefreshDevicePage(f)
    elseif step == 2 then RefreshNameplatePage(f)
    elseif step == 3 then RefreshFeaturePage(f)
    elseif step == 4 then RefreshExtrasPage(f) end
end

local function CreateWizard()
    local ar, ag, ab = GetAccent()
    local lr, lg, lb = ar + (1 - ar) * 0.3, ag + (1 - ag) * 0.3, ab + (1 - ab) * 0.3

    local f = CreateFrame("Frame", "H3z0UI_SetupWizard", UIParent, "BackdropTemplate")
    f.ar, f.ag, f.ab = ar, ag, ab
    f:SetSize(580, 520)
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(710)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(0.067, 0.094, 0.153, 0.98)
    f:SetBackdropBorderColor(ar, ag, ab, 1)
    tinsert(UISpecialFrames, "H3z0UI_SetupWizard")   -- Esc closes (nothing is saved, it comes back next login on a new install)

    -- Header: accent glow + line, logo badge, title
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("TOPRIGHT", -1, -1)
    glow:SetHeight(78)
    glow:SetColorTexture(1, 1, 1, 1)
    glow:SetGradient("HORIZONTAL", CreateColor(ar, ag, ab, 0.22), CreateColor(ar, ag, ab, 0.02))
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -78)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -78)
    line:SetHeight(2)
    line:SetColorTexture(1, 1, 1, 1)
    line:SetGradient("HORIZONTAL", CreateColor(ar, ag, ab, 1), CreateColor(ar, ag, ab, 0.08))

    local badge = CreateFrame("Frame", nil, f, "BackdropTemplate")
    badge:SetSize(52, 52)
    badge:SetPoint("TOPLEFT", 18, -13)
    badge:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    badge:SetBackdropColor(0.03, 0.045, 0.08, 1)
    badge:SetBackdropBorderColor(ar, ag, ab, 1)
    local icon = badge:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\icon.tga")
    icon:SetSize(48, 48)
    icon:SetPoint("CENTER")
    icon:SetDesaturated(true)
    icon:SetVertexColor(lr, lg, lb, 1)

    f.stepCount = MakeText(f, 18, lr, lg, lb, "OUTLINE")
    f.stepCount:SetPoint("TOPLEFT", badge, "TOPRIGHT", 13, -5)
    f.stepTitle = MakeText(f, 12, 0.7, 0.74, 0.8)
    f.stepTitle:SetPoint("TOPLEFT", f.stepCount, "BOTTOMLEFT", 0, -5)

    -- Step dots (top right)
    f.dots = {}
    for i = 1, TOTAL_STEPS + 1 do
        local d = f:CreateTexture(nil, "OVERLAY")
        d:SetSize(22, 4)
        d:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18 - (TOTAL_STEPS + 1 - i) * 26, -30)
        f.dots[i] = d
    end

    -- Pages
    local PAGE_W = 540
    local function NewPage()
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", 20, -96)
        page:SetPoint("BOTTOMRIGHT", -20, 62)
        page:Hide()
        return page
    end
    f.pages = { NewPage(), NewPage(), NewPage(), NewPage(), NewPage() }

    -- Page 1: device
    do
        local page = f.pages[1]
        local intro = MakeText(page, 11, 0.85, 0.88, 0.92)
        intro:SetPoint("TOPLEFT", 0, 0)
        intro:SetWidth(PAGE_W)
        intro:SetText("H3z0 UI looks different on a handheld. Pick what you play on - you can change it any time.")

        f.deviceCards = {}
        local function Pick(value)
            state.device = value
            RefreshDevicePage(f)
        end
        f.deviceCards.pc = MakeCard(page, PAGE_W, 56, "PC / Desktop",
            "Mouse and keyboard. The standard H3z0 UI layout with Action Combat Mode.", ar, ag, ab,
            function() Pick("pc") end, 14)
        f.deviceCards.pc:SetPoint("TOPLEFT", 0, -36)
        f.deviceCards.pccontroller = MakeCard(page, PAGE_W, 56, "PC + Controller",
            "Same PC layout, played with a controller: ConsolePort on, Action Combat Mode off.", ar, ag, ab,
            function() Pick("pccontroller") end, 14)
        f.deviceCards.pccontroller:SetPoint("TOPLEFT", f.deviceCards.pc, "BOTTOMLEFT", 0, -8)
        f.deviceCards.handheld = MakeCard(page, PAGE_W, 80, "Steam Deck / Handheld",
            "Controller play. Compact HUD (target bar top centre, player top left, power bar bottom centre), action bars always visible, settings window fitted to the screen.", ar, ag, ab,
            function() Pick("handheld") end, 14)
        f.deviceCards.handheld:SetPoint("TOPLEFT", f.deviceCards.pccontroller, "BOTTOMLEFT", 0, -8)

        f.scaleRow = CreateFrame("Frame", nil, page)
        f.scaleRow:SetSize(PAGE_W, 56)
        f.scaleRow:SetPoint("TOPLEFT", f.deviceCards.handheld, "BOTTOMLEFT", 0, -14)
        local sl = MakeText(f.scaleRow, 11, 0.85, 0.88, 0.92)
        sl:SetPoint("TOPLEFT", 0, 0)
        sl:SetText("Handheld UI scale")
        f.scaleButtons = {}
        local prev
        for _, sc in ipairs(SCALES) do
            local btn = MakeButton(f.scaleRow, sc.label, 172, 28, false, ar, ag, ab, function()
                state.scale = sc.value
                RefreshDevicePage(f)
            end)
            if prev then btn:SetPoint("LEFT", prev, "RIGHT", 6, 0) else btn:SetPoint("TOPLEFT", 0, -20) end
            btn.label:SetFont(FONT, 10, "")
            btn.Idle = function() end    -- selection look is driven by RefreshDevicePage
            btn:SetScript("OnLeave", nil)
            btn:SetScript("OnEnter", nil)
            f.scaleButtons[sc.value] = btn
            prev = btn
        end

        f.screenInfo = MakeText(page, 10, 0.6, 0.65, 0.7)
        f.screenInfo:SetPoint("BOTTOMLEFT", 0, 0)
    end

    -- Page 2: nameplates
    do
        local page = f.pages[2]
        local intro = MakeText(page, 11, 0.85, 0.88, 0.92)
        intro:SetPoint("TOPLEFT", 0, 0)
        intro:SetWidth(PAGE_W)
        intro:SetText("H3z0 UI ships a ready-made profile for these nameplate addons. Pick the one you use (or want to use).")
        f.npCards = {}
        local prev
        for _, o in ipairs(NAMEPLATES) do
            local card = MakeCard(page, PAGE_W, 54, o.label, o.desc, ar, ag, ab, function()
                state.nameplates = o.value
                RefreshNameplatePage(f)
            end)
            if prev then card:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6) else card:SetPoint("TOPLEFT", 0, -36) end
            f.npCards[o.value] = card
            prev = card
        end
        local note = MakeText(page, 10, 0.6, 0.65, 0.7)
        note:SetPoint("BOTTOMLEFT", 0, 0)
        note:SetWidth(PAGE_W)
        note:SetText("The profile is applied on the last screen. It never overwrites your other nameplate profiles.")
    end

    -- Page 3: features
    do
        local page = f.pages[3]
        local intro = MakeText(page, 11, 0.85, 0.88, 0.92)
        intro:SetPoint("TOPLEFT", 0, 0)
        intro:SetWidth(PAGE_W)
        intro:SetText("Turn on what you want H3z0 UI to handle. Everything can be changed later in the options.")
        f.featureRows = {}
        local prev
        for _, feat in ipairs(FEATURES) do
            local row = MakeToggle(page, PAGE_W, feat.label, feat.desc, ar, ag, ab, function(on)
                state.features[feat.id] = on
            end)
            if prev then row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2) else row:SetPoint("TOPLEFT", 0, -34) end
            f.featureRows[feat.id] = row
            prev = row
        end
    end

    -- Page 4: extras
    do
        local page = f.pages[4]
        local intro = MakeText(page, 11, 0.85, 0.88, 0.92)
        intro:SetPoint("TOPLEFT", 0, 0)
        intro:SetWidth(PAGE_W)
        intro:SetText("Small helpers. Off by default - turn on what you like. You can move all of them later in Layout Mode.")
        f.extraRows = {}
        local prev
        for _, e in ipairs(EXTRAS) do
            local row = MakeToggle(page, PAGE_W, e.label, e.desc, ar, ag, ab, function(on)
                state.extras[e.id] = on
            end)
            if prev then row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2) else row:SetPoint("TOPLEFT", 0, -34) end
            f.extraRows[e.id] = row
            prev = row
        end
    end

    -- Page 5: done
    do
        local page = f.pages[5]
        f.doneTitle = MakeText(page, 14, lr, lg, lb, "OUTLINE")
        f.doneTitle:SetPoint("TOPLEFT", 0, 0)
        f.doneTitle:SetText("Your setup is applied")
        f.doneBody = MakeText(page, 12, 0.9, 0.92, 0.95)
        f.doneBody:SetPoint("TOPLEFT", f.doneTitle, "BOTTOMLEFT", 0, -12)
        f.doneBody:SetWidth(PAGE_W)
        f.doneBody:SetSpacing(6)
        f.doneHint = MakeText(page, 11, 0.75, 0.8, 0.85)
        f.doneHint:SetPoint("TOPLEFT", f.doneBody, "BOTTOMLEFT", 0, -16)
        f.doneHint:SetWidth(PAGE_W)

        f.importPlater = MakeButton(page, "Import into Plater", 180, 30, true, ar, ag, ab, function()
            f:Hide()
            if StaticPopupDialogs and StaticPopupDialogs["H3Z0UI_PLATER_IMPORT"] then
                StaticPopup_Show("H3Z0UI_PLATER_IMPORT")
            else
                Say("Open Options > Nameplates and use \"Import into Plater\".")
            end
        end)
        f.importPlater:SetPoint("BOTTOMLEFT", 0, 40)
        f.openOptions = MakeButton(page, "Open H3z0 UI options", 180, 30, true, ar, ag, ab, function()
            f:Hide()
            local gui = _G.H3z0UI and _G.H3z0UI.GUI
            if gui and gui.Show then gui:Show() end
            Say("Go to |cffFFFF00Nameplates|r, copy the string and import it in the nameplate addon.")
        end)
        f.openOptions:SetPoint("BOTTOMLEFT", 0, 40)
        f.reloadBtn = MakeButton(page, "Reload UI now", 180, 30, false, ar, ag, ab, function()
            local ui = _G.H3z0UI
            if ui and ui.SafeReload then ui:SafeReload() else ReloadUI() end
        end)
        f.reloadBtn:SetPoint("BOTTOMLEFT", 0, 4)
        f.layoutBtn = MakeButton(page, "Open Layout Mode", 160, 30, false, ar, ag, ab, function()
            f:Hide()
            if _G.H3z0UI_ToggleLayoutMode then _G.H3z0UI_ToggleLayoutMode() end
        end)
        f.layoutBtn:SetPoint("BOTTOMRIGHT", 0, 40)
        local rl = MakeText(page, 10, 0.6, 0.65, 0.7)
        rl:SetPoint("LEFT", f.reloadBtn, "RIGHT", 10, 0)
        rl:SetText("A reload finishes switching frames and modules on or off.")
    end

    -- Footer
    f.back = MakeButton(f, "Back", 90, 32, false, ar, ag, ab, function()
        if f.step > 1 then ShowStep(f, f.step - 1) end
    end)
    f.back:SetPoint("BOTTOMLEFT", 20, 18)

    f.skip = MakeButton(f, "Skip (use defaults)", 150, 32, false, ar, ag, ab, function()
        Setup.Skip()
        f:Hide()
        Say("Setup skipped - default settings kept. Run |cffFFFF00/h3z0ui setup|r any time to open the wizard again.")
    end)
    f.skip:SetPoint("LEFT", f.back, "RIGHT", 8, 0)

    f.next = MakeButton(f, "Next", 150, 32, true, ar, ag, ab, function()
        if f.step < TOTAL_STEPS then
            ShowStep(f, f.step + 1)
        else
            local result = Setup.Apply()
            BuildDoneText(f, result)
            ShowStep(f, TOTAL_STEPS + 1)
        end
    end)
    f.next:SetPoint("BOTTOMRIGHT", -20, 18)

    f.close = MakeButton(f, "Close", 120, 32, true, ar, ag, ab, function() f:Hide() end)
    f.close:SetPoint("BOTTOMRIGHT", -20, 18)

    local hint = MakeText(f, 10, 0.6, 0.65, 0.7)
    hint:SetPoint("BOTTOM", 0, 4)
    hint:SetText("Open this window any time with /h3z0ui setup")

    return f
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
function Setup.Show()
    if InCombatLockdown() then
        Say("Setup wizard opens after combat.")
        local w = CreateFrame("Frame")
        w:RegisterEvent("PLAYER_REGEN_ENABLED")
        w:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            Setup.Show()
        end)
        return
    end
    LoadState()
    if not wizard then wizard = CreateWizard() end
    wizard:Show()
    ShowStep(wizard, 1)
end

--- Short text for the options tab ("what did I pick last time")
function Setup.Describe()
    local s = SetupTable()
    if not s or not s.completed then return "The wizard has not been completed on this profile yet." end
    if s.skipped then return "The wizard was skipped - default settings are in use." end
    local np = s.nameplates or "none"
    for _, o in ipairs(NAMEPLATES) do if o.value == np then np = o.label end end
    return string.format("Last choices: %s  |  Nameplates: %s",
        s.device == "handheld" and "Steam Deck / Handheld" or (s.device == "pccontroller" and "PC + Controller" or "PC"), np)
end
