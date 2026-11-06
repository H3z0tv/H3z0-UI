--[[
    H3z0 UI Options - Oracle (Gameplay)
    Spoken boss warnings: which callouts are on, and the tests that show
    whether it works.
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local FORM_ROW = 32

local function Build(tabContent)
    local y = -10
    local PAD = Shared.PADDING or 10
    local Oracle = _G.H3z0UI_Oracle
    local d = Oracle and Oracle.Settings and Oracle.Settings()
    GUI:SetSearchContext({ tabName = "Oracle", subTabName = "Oracle", tileId = "h3z_oracle", subPageIndex = 1 })

    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PAD, y)
        y = y - header.gap
    end
    local function Place(widget, hgt)
        widget:SetPoint("TOPLEFT", PAD, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - (hgt or FORM_ROW)
    end
    local function Info(text, hgt, color)
        local label = GUI:CreateLabel(tabContent, text, 11, color or C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        if label.SetWordWrap then label:SetWordWrap(true) end
        y = y - (hgt or 22)
    end
    local function ButtonRow(label, text, width, onClick)
        local row = CreateFrame("Frame", nil, tabContent)
        row:SetHeight(FORM_ROW)
        local l = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        l:SetPoint("LEFT", 0, 0)
        if GUI.FitFormLabel then GUI.FitFormLabel(l) end
        l:SetText(label)
        l:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        local btn = GUI:CreateButton(row, text, width or 170, 24, onClick)
        btn:SetPoint("LEFT", row, "LEFT", (GUI.FORM_CONTROL_X or 232), 0)
        Place(row)
        return btn
    end

    if not (Oracle and d) then
        Info("Oracle is not available on this game version.", 22)
        tabContent:SetHeight(80)
        return
    end

    local function Refresh() if _G.H3z0UI_RefreshOracle then _G.H3z0UI_RefreshOracle() end end

    Section("Oracle")
    Info("Oracle says what you have to do before a boss ability lands: Soak, Spread, Stack up, Interrupt, Tank buster and more. The game plays the voice about 5 seconds before the ability. It covers every boss of the raids and Mythic+ dungeons the game knows, this season included, and needs no boss mod.", 60)
    Place(GUI:CreateFormCheckbox(tabContent, "Enable Oracle", "enabled", d, function()
        Refresh()
        if _G.H3z0UI_NotifySwitch then _G.H3z0UI_NotifySwitch("moduleFlag_h3zOracle") end
    end))
    Place(GUI:CreateFormCheckbox(tabContent, "Tank and Healer Callouts Only for My Role", "roleOnly", d, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Say It Again When the Warning Appears", "alsoOnWarning", d, Refresh))
    Place(GUI:CreateFormCheckbox(tabContent, "Boss-Specific Lines (Dungeons and Raid)", "custom", d, Refresh))
    Info("With this on, the bosses of this season's Mythic+ dungeons and raid say exactly what to do (\"Soak the beams\", \"Tank, defensive\", \"Take the gateway\"). Abilities without a line keep the general callout.", 34)
    Place(GUI:CreateFormSlider(tabContent, "Volume", 0.1, 1, 0.1, "volume", d, Refresh))

    Section("On-Screen Warning")
    Info("A big word and the ability icon appear on screen at the same moment the voice speaks (about 5 seconds before the ability). Drag it with the test button to place it.", 34)
    Place(GUI:CreateFormCheckbox(tabContent, "Show the Warning on Screen", "banner", d))
    Place(GUI:CreateFormCheckbox(tabContent, "Also Show Abilities Oracle Cannot Name (INCOMING)", "bannerUnknown", d))
    Place(GUI:CreateFormSlider(tabContent, "Seconds Shown", 1, 8, 1, "bannerSeconds", d))
    Place(GUI:CreateFormSlider(tabContent, "Size", 0.6, 2, 0.1, "bannerScale", d))

    Section("Callouts")
    Info("Switch single callouts off. The number is how many boss abilities the game has that Oracle matched to it (it grows for a few seconds after login while the game loads the ability texts).", 34)
    local counts = Oracle.Counts and Oracle.Counts() or {}
    for _, c in ipairs(Oracle.CATEGORIES) do
        local n = counts[c.key]
        local label = c.label .. (n and ("   (" .. n .. ")") or "")
        Place(GUI:CreateFormCheckbox(tabContent, label, c.key, d.cats, Refresh))
    end

    Section("Test: does it work?")
    Info("Every test prints PASS or FAIL in the chat window.", 22)
    ButtonRow("1. Check Setup", "Check Setup", 170, function() Oracle.Check() end)
    Info("Checks the game support, the voice files and how many boss abilities got a callout. You should hear \"Soak\".", 34)
    ButtonRow("2. Play All Voices", "Play All Voices", 170, function() Oracle.PlayAll() end)
    Info("Plays every callout, one after the other, so you hear what each one says.", 22)

    local options = {}
    for _, c in ipairs(Oracle.CATEGORIES) do options[#options + 1] = { value = c.key, text = c.label } end
    local pick = { cat = "soak" }
    Place(GUI:CreateFormDropdown(tabContent, "Callout to Test", options, "cat", pick))
    ButtonRow("3. Test This Callout", "Test the Voice", 170, function() Oracle.PlayCategory(pick.cat) end)
    ButtonRow("4. Test With a Real Boss Ability", "Test With the Game", 170, function() Oracle.PlayReal(pick.cat) end)
    ButtonRow("5. Test the On-Screen Warning", "Show the Warning", 170, function() Oracle.TestBanner(pick.cat) end)
    Info("Shows the warning for 8 seconds so you can drag it where you want it.", 22)
    ButtonRow("6. Test With the Boss Timeline", "Test the Timeline", 170, function() Oracle.TestLive() end)
    Info("Button 6 puts a real 7 second test event on the game's boss timeline. When the game highlights it, the warning BIG HIT must appear on screen (the test event has no voice). PASS or FAIL shows in chat about 10 seconds later.", 46)
    local dungeons, seen = {}, {}
    local DATA = ns.OracleData
    for _, r in ipairs(DATA and DATA.rows or {}) do
        if not seen[r.dungeon] then seen[r.dungeon] = true; dungeons[#dungeons + 1] = { value = r.dungeon, text = r.dungeon } end
    end
    local dpick = { name = dungeons[1] and dungeons[1].value }
    Place(GUI:CreateFormDropdown(tabContent, "Dungeon or Raid to Test", dungeons, "name", dpick))
    ButtonRow("7. Test a Boss Line", "Play a Boss Line", 170, function() Oracle.TestLine(dpick.name) end)
    Info("Plays one random boss line of that dungeon or raid with its on-screen warning, and tells you if the game has that ability.", 34)
    ButtonRow("7b. Test Every Boss Line", "Test All of It", 170, function() Oracle.TestInstance(dpick.name) end)
    Info("Plays every line of the chosen dungeon or raid one after the other with the warning on screen, boss by boss. The chat tells you which abilities the game does not have and ends with PASS or FAIL.", 46)
    ButtonRow("8. Are the Boss Lines Found?", "Check the Boss Lines", 170, function() Oracle.CustomReport() end)
    Info("The real check: lists, per dungeon, how many boss lines found their ability in this game (matched by spell ID or name) and names the ones that did not.", 34)
    ButtonRow("9. Play All Boss Voices", "Play All Boss Voices", 170, function() Oracle.PlayLines() end)
    Info("Button 4 is the real test: the game itself plays the sound it holds for a real boss ability of that callout and the chat names the ability. If this says PASS, it will speak in the fight.", 46)
    Info("New sound files only load after the game is closed completely and started again (a /reload is not enough). Chat commands: /h3z0ui oracle  (check),  /h3z0ui oracletest  (play all).", 46)

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_OracleOptions = { BuildOracleTab = function(tabContent) Build(tabContent) end }
