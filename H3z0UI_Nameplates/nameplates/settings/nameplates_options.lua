--[[
    H3z0UI Options - Nameplates Tab  (0.22)
    Everything about nameplates in one place:
      * H3z0 UI's Plater profile  - one-click import when Plater is installed (+ copy box)
      * H3z0 UI's Platynator profile - copy box + button that opens Platynator's settings
      * H3z0 UI's BetterBlizzPlates profile - copy box + button that opens BetterBlizzPlates' settings
      * Friendly nameplate hiding (moved here from Skinning & Autohide)
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local PLATER_PROFILE_NAME = "H3z0 UI"

local function IsLoaded(addon)
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon)) and true or false
end

local function GetImportData(key)
    local imports = _G.H3z0UI and _G.H3z0UI.imports
    local entry = imports and imports[key]
    local data = entry and entry.data or ""
    return (data:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Say(msg)
    print("|cff34D399H3z0 UI:|r " .. msg)
end

---------------------------------------------------------------------------
-- Small scrollable copy box (same look as the Import tab)
---------------------------------------------------------------------------
local function CreateCopyBox(parent, height, text)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetHeight(height)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container:SetBackdropColor(0.1, 0.1, 0.1, 1)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)

    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName() .. "ScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 18)
    end

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() or 400)
    editBox:SetText(text or "")
    editBox:SetCursorPosition(0)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    container:SetScript("OnSizeChanged", function(self)
        editBox:SetWidth(math.max(50, self:GetWidth() - 36))
    end)
    scrollFrame:SetScrollChild(editBox)

    container.editBox = editBox
    return container
end

---------------------------------------------------------------------------
-- Plater: one-click import (Plater.ImportAndSwitchProfile creates/switches to its own profile,
-- so the player's existing Plater profiles are not overwritten)
---------------------------------------------------------------------------
ns.Popups["H3Z0UI_PLATER_IMPORT"] = {
    text = "Import the H3z0 UI profile into Plater?\n\nPlater switches to a profile named \"" .. PLATER_PROFILE_NAME ..
           "\" (your other Plater profiles stay as they are) and reloads the UI.",
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
        local data = GetImportData("Plater")
        local plater = _G.Plater
        if data == "" then
            Say("No Plater string is bundled with this build.")
            return
        end
        if not (plater and plater.ImportAndSwitchProfile) then
            Say("Plater is not loaded - enable it on the character select screen and try again.")
            return
        end
        local ok, err = pcall(plater.ImportAndSwitchProfile, PLATER_PROFILE_NAME, data, false, false, false)
        if ok then
            Say("Plater profile imported. If the UI did not reload, type |cffFFFF00/reload|r.")
        else
            Say("Plater import failed: " .. tostring(err) .. "  -  use the copy box and Plater's own Import instead.")
        end
    end,
}

---------------------------------------------------------------------------
-- Platynator: find its slash command at runtime and run it (opens its settings)
---------------------------------------------------------------------------
local function OpenAddonSettings(addon, slashPattern)
    if not IsLoaded(addon) then
        Say(addon .. " is not loaded - install/enable it first.")
        return
    end
    local cmd
    for key, value in pairs(_G) do
        if type(key) == "string" and key:match("^SLASH_") and type(value) == "string"
           and value:lower():match(slashPattern) then
            cmd = value
            break
        end
    end
    if not cmd then
        Say("Could not find " .. addon .. "'s slash command - open its settings from Game Menu > Options > AddOns.")
        return
    end
    local box = ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend()
    if box and ChatEdit_SendText then
        box:SetText(cmd)
        ChatEdit_SendText(box)
    else
        Say("Type |cffFFFF00" .. cmd .. "|r to open Platynator.")
    end
end

local function OpenPlatynatorSettings() OpenAddonSettings("Platynator", "^/platy") end
local function OpenBetterBlizzPlatesSettings() OpenAddonSettings("BetterBlizzPlates", "^/bbp") end

local tabRef
local Build

local function Rebuild()
    if not tabRef or not Build then return end
    for _, child in ipairs({tabRef:GetChildren()}) do
        child:Hide()
        child:ClearAllPoints()
    end
    for _, region in ipairs({tabRef:GetRegions()}) do
        region:Hide()
    end
    Build(tabRef)
end

Build = function(tabContent)
    tabRef = tabContent
    local y = -10
    local FORM_ROW = 32
    local PAD = Shared.PADDING
    local db = Shared.GetDB()
    if not db then return end

    GUI:SetSearchContext({tabIndex = 2, tabName = "Nameplates", subTabIndex = 1, subTabName = "Nameplates"})

    local boxes = {}
    local function SelectOnly(target)
        for _, eb in ipairs(boxes) do
            if eb ~= target then
                eb:ClearFocus()
                eb:HighlightText(0, 0)
            end
        end
        target:SetFocus()
        target:HighlightText()
    end

    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PAD, y)
        y = y - header.gap
    end

    local function Info(text, h, color)
        local label = GUI:CreateLabel(tabContent, text, 10, color or C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        y = y - (h or 20)
    end

    local function Status(addon)
        if IsLoaded(addon) then
            Info(addon .. ": installed and loaded", 18, {0.2, 0.9, 0.5, 1})
        else
            Info(addon .. ": not installed / not loaded", 18, {1, 0.4, 0.4, 1})
        end
    end

    local function CopyBox(key)
        local data = GetImportData(key)
        local box = CreateCopyBox(tabContent, 70, data)
        box:SetPoint("TOPLEFT", PAD, y)
        box:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        boxes[#boxes + 1] = box.editBox
        y = y - 78
        local btn = GUI:CreateButton(tabContent, "SELECT ALL", 120, 24, function() SelectOnly(box.editBox) end)
        btn:SetPoint("TOPLEFT", PAD, y)
        local tip = GUI:CreateLabel(tabContent, "then press Ctrl+C to copy", 11, C.textMuted)
        tip:SetPoint("LEFT", btn, "RIGHT", 10, 0)
        y = y - 36
        return data
    end

    ---------------------------------------------------------------------
    local NP = ns.H3zPlates
    local npdb = NP and NP.GetSettings and NP.GetSettings()
    if npdb then
        local function Place(w, h)
            w:SetPoint("TOPLEFT", PAD, y)
            w:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
            y = y - (h or FORM_ROW)
            return w
        end
        local preview
        local function RefreshNP()
            if preview and preview.Refresh then pcall(preview.Refresh, preview) end
            if _G.H3z0UI_RefreshPlates then _G.H3z0UI_RefreshPlates() end
            if npdb.unitFrameColors and _G.H3z0UI_RefreshUnitFrames then pcall(_G.H3z0UI_RefreshUnitFrames) end
        end
        Section("H3z0 Nameplates")
        Info("H3z0 UI's own nameplates: rounded bar, level | name, health and percent, cast bar, target arrows and Mythic colours (boss, mini boss, caster, melee, trivial, minus). Made to keep working in Mythic+ keys. Not used while Plater, Platynator or BetterBlizzPlates is loaded. /h3z0ui plates", 44)
        for _, a in ipairs({ "Plater", "Platynator", "BetterBlizzPlates" }) do
            if IsLoaded(a) then Info(a .. " is loaded - disable it to use H3z0 Nameplates.", 18, {1, 0.6, 0.2, 1}) end
        end
        -- live preview: stays at the top of the page while you scroll through the settings
        if NP.CreatePreview then
            preview = NP.CreatePreview(tabContent)
            preview:SetFrameLevel(tabContent:GetFrameLevel() + 40)
            local homeY = y
            local lastTop
            local function Pin(self)
                local sf = tabContent:GetParent()
                local off = (sf and sf.GetVerticalScroll) and (sf:GetVerticalScroll() or 0) or 0
                local top = math.min(homeY, -off - 2)
                if top ~= lastTop then
                    lastTop = top
                    self:ClearAllPoints()
                    self:SetPoint("TOPLEFT", tabContent, "TOPLEFT", PAD, top)
                    self:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
                end
            end
            preview.onTick = Pin
            Pin(preview)
            y = y - preview:GetHeight() - 12
        end
        Place(GUI:CreateFormCheckbox(tabContent, "Use H3z0 Nameplates", "enabled", npdb, function()
            RefreshNP()
            if not npdb.enabled then if _G.H3z0UI_NeedReload then _G.H3z0UI_NeedReload("H3z0 nameplates switched off.") end end
        end))
        Place(GUI:CreateFormDropdown(tabContent, "Font", NP.FONTS, "font", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Width", 60, 500, 1, "width", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Height", 6, 80, 1, "height", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Name Size", 6, 20, 1, "nameSize", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Health Text Size", 6, 20, 1, "textSize", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Target Size", 1, 1.5, 0.05, "targetScale", npdb, RefreshNP))
        if npdb.limitDistance == nil then npdb.limitDistance = true end
        if npdb.maxDistance == nil then npdb.maxDistance = 40 end
        Place(GUI:CreateFormCheckbox(tabContent, "Only Show Nameplates Close to You", "limitDistance", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Nameplate Distance (yards)", 10, 60, 1, "maxDistance", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Show Level", "showLevel", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Show Quest Marker (gold ! on units you need for a quest)", "questMark", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Show Health Value", "showHealth", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Show Health Percent", "showPercent", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Show Shields and Heal Absorbs", "showAbsorbs", npdb, RefreshNP))
        -- 0.24.4: stacking / overlap (the game's own spacing; also for Blizzard's plates)
        if NP.StackingAvailable and NP.StackingAvailable() then
            if NP.ReadStacking then NP.ReadStacking() end
            local function Stack()
                npdb.stackManaged = true
                if _G.H3z0UI_ApplyPlateStacking then _G.H3z0UI_ApplyPlateStacking() end
            end
            Section("Stacking & Overlap")
            Info("How nameplates sit next to each other. Stacked: they move apart so none cover another. Overlapping: they stay over their unit and can cover each other. The spacing sliders set how close they may get (lower = closer together, more overlap). Applies to every nameplate and is kept on every login; in combat it waits until combat ends.", 50)
            Place(GUI:CreateFormDropdown(tabContent, "Nameplate Placement", {
                { value = "stack", text = "Stacked (no overlap)" },
                { value = "overlap", text = "Overlapping" },
            }, "stackMode", npdb, Stack))
            Place(GUI:CreateFormSlider(tabContent, "Vertical Spacing", 0.3, 2.5, 0.05, "overlapV", npdb, Stack))
            Place(GUI:CreateFormSlider(tabContent, "Horizontal Spacing", 0.3, 2.5, 0.05, "overlapH", npdb, Stack))
            local resetStack = GUI:CreateButton(tabContent, "Game Default Spacing", 180, 24, function()
                npdb.stackMode, npdb.overlapV, npdb.overlapH = "stack", 1.1, 0.8
                Stack()
                Rebuild()
            end)
            resetStack:SetPoint("TOPLEFT", PAD, y)
            y = y - 36
            Section("Teammates")
        end
        Info("Teammates inside dungeons / raids: the game locks friendly nameplates there, so they can't get the H3z0 look. H3z0 UI can switch Blizzard's own settings while you are inside (and back when you leave):", 34)
        local function RefreshInst() if _G.H3z0UI_ApplyInstanceFriendly then _G.H3z0UI_ApplyInstanceFriendly() end end
        Place(GUI:CreateFormCheckbox(tabContent, "Teammates in Class Colours (instances)", "instClassColors", npdb, RefreshInst))
        Place(GUI:CreateFormCheckbox(tabContent, "Friendly Players as Names Only (all dungeons, raids, scenarios)", "instNamesOnly", npdb, RefreshInst))
        Place(GUI:CreateFormCheckbox(tabContent, "Friendly Players as Names Only (Mythic dungeons and Mythic+)", "mythicNamesOnly", npdb, RefreshInst))
        Info("Only Show Names just in Mythic: on in Mythic dungeons and Mythic+ keys, back to your own setting everywhere else (normal and heroic dungeons, raids, the open world).", 32)
        Place(GUI:CreateFormCheckbox(tabContent, "Nameplate Colours on Unit Frames", "unitFrameColors", npdb, function()
            RefreshNP()
            if _G.H3z0UI_RefreshUnitFrames then pcall(_G.H3z0UI_RefreshUnitFrames) end
        end))
        Place(GUI:CreateFormCheckbox(tabContent, "Rounded Corners", "rounded", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Target Arrows", "arrows", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Threat Border", "threat", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Friendly Nameplates", "friendly", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Friendly Nameplates: Text Only (name, class colour) in towns and everywhere", "friendlyNamesOnly", npdb, function()
            RefreshNP()
            if _G.H3z0UI_ApplyInstanceFriendly then _G.H3z0UI_ApplyInstanceFriendly() end
        end))
        Place(GUI:CreateFormCheckbox(tabContent, "Cast Bar", "castbar", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Cast Bar Height", 6, 48, 1, "castHeight", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Cast Bar Width (0 = as wide as the nameplate)", 0, 600, 5, "castWidth", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Cast Bar Sideways Offset", -150, 150, 1, "castOffsetX", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Cast Bar Gap Under Health Bar", -10, 30, 1, "castGap", npdb, RefreshNP))
        Place(GUI:CreateFormDropdown(tabContent, "Cast Icon", {
            { value = "left", text = "Left" }, { value = "right", text = "Right" }, { value = "off", text = "Hidden" },
        }, "castIconSide", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Cast Icon Size (0 = same as bar height)", 0, 64, 1, "castIconSize", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Cast Text Size (0 = automatic)", 0, 24, 1, "castTextSize", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Show Spell Name On Cast Bar", "castNameShow", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Show Cast Time On Cast Bar", "castTimeShow", npdb, RefreshNP))
        Place(GUI:CreateFormSlider(tabContent, "Name Gap Above Health Bar", -10, 30, 1, "nameGap", npdb, RefreshNP))
        Place(GUI:CreateFormCheckbox(tabContent, "Grey Casts While Your Interrupt Is On Cooldown", "interruptReady", npdb, RefreshNP))
        Place(GUI:CreateFormDropdown(tabContent, "Mythic Colours", {
            { value = "instance", text = "In dungeons, raids and delves" },
            { value = "always", text = "Always" },
            { value = "off", text = "Off (hostile / neutral / friendly)" },
        }, "mythicColors", npdb, RefreshNP))
        Info("Colours", 20, C.text)
        for _, c in ipairs({
            { "boss", "Boss" }, { "miniboss", "Mini Boss / Lieutenant" }, { "caster", "Caster" }, { "melee", "Melee" },
            { "trivial", "Trivial" }, { "minus", "Minus (small mobs)" }, { "rareElite", "Rare Elite" },
            { "hostile", "Hostile" }, { "neutral", "Neutral" }, { "friendly", "Friendly" }, { "tapped", "Tapped" },
            { "cast", "Cast" }, { "channel", "Channel" }, { "noInterrupt", "Can't Interrupt" }, { "interruptCD", "Interrupt On Cooldown" }, { "interrupted", "Interrupted" },
            { "aggro", "Threat: You Have Aggro" }, { "lostAggro", "Threat: Tank Lost Aggro" },
        }) do
            Place(GUI:CreateFormColorPicker(tabContent, c[2], c[1], npdb.colors, RefreshNP))
        end
        local resetBtn = GUI:CreateButton(tabContent, "Reset Colours", 140, 24, function()
            for k, v in pairs(NP.DEFAULT_COLORS) do npdb.colors[k] = { v[1], v[2], v[3], v[4] } end
            RefreshNP()
            Rebuild()
        end)
        resetBtn:SetPoint("TOPLEFT", PAD, y)
        y = y - 40

        -------------------------------------------------------------------
        -- 0.27.5 extras: quick setup, auras, scaling, rules
        -------------------------------------------------------------------
        Section("Quick Setup")
        Info("A short guided setup with a live preview and ready-made templates (Minimalist, Mythic+ Tank, Mythic+ Healer, Raid Leader, PvP). Your settings are backed up first.", 32)
        local wizBtn = GUI:CreateButton(tabContent, "Open Quick Setup", 180, 28, function()
            local Q = ns.H3z0UI_NPQuickSetup
            if Q and Q.Open then Q.Open() end
        end)
        wizBtn:SetPoint("TOPLEFT", PAD, y)
        local perfBtn = GUI:CreateButton(tabContent, "Performance Report", 180, 28, function()
            if NP.PerfReport then NP.PerfReport() end
        end)
        perfBtn:SetPoint("LEFT", wizBtn, "RIGHT", 10, 0)
        y = y - 44

        local function RefreshExtras()
            if NP.RefreshExtras then NP.RefreshExtras() end
            RefreshNP()
        end

        Section("Auras on Nameplates")
        Info("Icons above the plate with the time left. Pandemic: the icon border turns gold in the last 30% of the time, when the game shows addons the times. Nothing is shown while the game hides them.", 32)
        Place(GUI:CreateFormDropdown(tabContent, "Auras", {
            { value = "off", text = "Off" },
            { value = "mine", text = "My debuffs" },
        }, "auras", npdb, RefreshExtras))
        Place(GUI:CreateFormCheckbox(tabContent, "Also Show Dispellable Enemy Buffs", "auraDispel", npdb, RefreshExtras))
        Place(GUI:CreateFormCheckbox(tabContent, "Pandemic Cue", "auraPandemic", npdb, RefreshExtras))
        Place(GUI:CreateFormSlider(tabContent, "Icons Per Plate", 1, 10, 1, "auraMax", npdb, RefreshExtras))
        Place(GUI:CreateFormSlider(tabContent, "Icon Size", 10, 36, 1, "auraSize", npdb, RefreshExtras))

        Section("Focus and Scaling")
        Place(GUI:CreateFormSlider(tabContent, "Focus Size", 1, 1.5, 0.05, "focusScale", npdb, RefreshExtras))
        Place(GUI:CreateFormSlider(tabContent, "Size While Casting (1 = off)", 1, 1.5, 0.05, "castScale", npdb, RefreshExtras))
        Place(GUI:CreateFormSlider(tabContent, "Fade Other Plates When You Have a Target (1 = off)", 0.3, 1, 0.05, "nonTargetAlpha", npdb, RefreshExtras))
        Place(GUI:CreateFormCheckbox(tabContent, "Bigger Plates for Bosses and Rares", "classScale", npdb, RefreshExtras))

        Section("Highlight Rules")
        Info("Make a unit stand out: type its exact name or its NPC number and press Add. It gets a gold bar and a bigger plate. Names are matched out of combat only when the game shows them.", 32)
        npdb.rules = npdb.rules or {}
        local ruleBox = CreateFrame("EditBox", nil, tabContent, "InputBoxTemplate")
        ruleBox:SetSize(220, 20)
        ruleBox:SetPoint("TOPLEFT", PAD + 6, y)
        ruleBox:SetAutoFocus(false)
        ruleBox:SetFontObject(ChatFontNormal)
        local addBtn = GUI:CreateButton(tabContent, "Add", 70, 24, function()
            local text = (ruleBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if text == "" then return end
            local rule = { enabled = true, color = { 1, 0.82, 0.1 }, scale = 1.2 }
            if tonumber(text) then rule.npc = tonumber(text) else rule.name = text end
            NP.AddRule(rule)
            Rebuild()
        end)
        addBtn:SetPoint("LEFT", ruleBox, "RIGHT", 12, 0)
        y = y - 34
        for i, rule in ipairs(npdb.rules) do
            local label = GUI:CreateLabel(tabContent, (rule.name or ("NPC " .. tostring(rule.npc))) .. "  -  gold, size x" .. tostring(rule.scale or 1), 11, C.text)
            label:SetPoint("TOPLEFT", PAD + 6, y)
            local rm = GUI:CreateButton(tabContent, "Remove", 70, 22, function()
                NP.RemoveRule(i)
                Rebuild()
            end)
            rm:SetPoint("TOPRIGHT", tabContent, "TOPRIGHT", -PAD, y + 4)
            y = y - 28
        end
    end

    ---------------------------------------------------------------------
    Section("Plater")
    Info("H3z0 UI's Plater nameplate profile. If Plater is installed you can import it with one click; otherwise copy the string and use Plater > Profiles > Import.", 32)
    Status("Plater")
    local importBtn = GUI:CreateButton(tabContent, "Import into Plater", 180, 28, function()
        if not IsLoaded("Plater") then
            Say("Plater is not installed or not loaded - install it first, or copy the string below.")
            return
        end
        ns.ShowPopup("H3Z0UI_PLATER_IMPORT")
    end)
    importBtn:SetPoint("TOPLEFT", PAD, y)
    local openBtn = GUI:CreateButton(tabContent, "Open Plater options", 180, 28, function()
        if not IsLoaded("Plater") then Say("Plater is not installed or not loaded."); return end
        local plater = _G.Plater
        if plater and plater.OpenOptionsPanel then pcall(plater.OpenOptionsPanel) end
    end)
    openBtn:SetPoint("LEFT", importBtn, "RIGHT", 10, 0)
    y = y - 40
    CopyBox("Plater")

    ---------------------------------------------------------------------
    Section("Platynator")
    Info("H3z0 UI's Platynator nameplate profile. Copy the string, then in Platynator open the profile settings and use Import.", 32)
    Status("Platynator")
    local platyBtn = GUI:CreateButton(tabContent, "Open Platynator settings", 200, 28, OpenPlatynatorSettings)
    platyBtn:SetPoint("TOPLEFT", PAD, y)
    y = y - 40
    CopyBox("Platynator")

    ---------------------------------------------------------------------
    Section("BetterBlizzPlates")
    Info("H3z0 UI's BetterBlizzPlates nameplate profile. Copy the string, then in BetterBlizzPlates open Profiles (/bbp) and use Import.", 32)
    Status("BetterBlizzPlates")
    local bbpBtn = GUI:CreateButton(tabContent, "Open BetterBlizzPlates settings", 220, 28, OpenBetterBlizzPlatesSettings)
    bbpBtn:SetPoint("TOPLEFT", PAD, y)
    y = y - 40
    CopyBox("BetterBlizzPlates")

    ---------------------------------------------------------------------
    Section("Friendly Nameplates")
    Info("Moved here from Skinning & Autohide. These switch Blizzard's friendly nameplate CVars, so they work with Plater, Platynator and BetterBlizzPlates too.", 32)
    db.uiHider = db.uiHider or {}
    local function RefreshUIHider()
        if _G.H3z0UI_RefreshUIHider then _G.H3z0UI_RefreshUIHider() end
    end
    local function ApplyFriendly()
        if _G.H3z0UI_ApplyFriendlyPlates then _G.H3z0UI_ApplyFriendlyPlates() end
    end
    if db.uiHider.friendlyNPCNameplates == nil then db.uiHider.friendlyNPCNameplates = "off" end
    local npcDrop = GUI:CreateFormDropdown(tabContent, "Friendly NPC Nameplates", {
        { value = "off", text = "Always Off" },
        { value = "on", text = "Always On" },
        { value = "game", text = "Game Setting" },
    }, "friendlyNPCNameplates", db.uiHider, ApplyFriendly)
    npcDrop:SetPoint("TOPLEFT", PAD, y)
    npcDrop:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
    y = y - FORM_ROW
    Info("Always Off / Always On keep it that way, even if the game's own option is changed. Game Setting leaves it to the game.", 22)
    local playerCheck = GUI:CreateFormCheckbox(tabContent, "Hide Friendly Player Nameplates", "hideFriendlyPlayerNameplates", db.uiHider, function()
        RefreshUIHider()
        ApplyFriendly()
    end)
    playerCheck:SetPoint("TOPLEFT", PAD, y)
    playerCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
    y = y - FORM_ROW

    tabContent:SetHeight(math.abs(y) + 50)
end

-- Own sidebar page (between H3z0 Features and General & QoL)
local function CreateNameplatesPage(parent)
    local scroll, content = ns.H3z0UI_Options.CreateScrollableContent(parent)
    Build(content)
    return scroll
end

ns.H3z0UI_NameplatesOptions = {
    BuildNameplatesTab = Build,
    CreateNameplatesPage = CreateNameplatesPage,
}
