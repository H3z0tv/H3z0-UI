--[[
    H3z0 UI Options - Lorekeeper (Interface)
    Style "Scroll" (parchment on the right) or "Quest Window" (normal windows
    with extras), camera, typewriter text, font sizes and size.
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
    local db = Shared.GetDB()
    local d = db and db.lorekeeper
    GUI:SetSearchContext({ tabName = "Lorekeeper", subTabName = "Lorekeeper", tileId = "h3z_lorekeeper", subPageIndex = 1 })
    if not d then return end

    local function Refresh()
        if _G.H3z0UI_RefreshLorekeeper then _G.H3z0UI_RefreshLorekeeper() end
    end
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
    local function Check(label, key, fn) Place(GUI:CreateFormCheckbox(tabContent, label, key, d, fn or Refresh)) end
    local function Slider(label, min, max, step, key) Place(GUI:CreateFormSlider(tabContent, label, min, max, step, key, d, Refresh)) end
    local function Info(text, hgt)
        local label = GUI:CreateLabel(tabContent, text, 11, C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        if label.SetWordWrap then label:SetWordWrap(true) end
        y = y - (hgt or 22)
    end
    local function Buttons(list)
        local x = PAD
        for _, b in ipairs(list) do
            local btn = GUI:CreateButton(tabContent, b[1], b[3] or 170, 26, b[2])
            btn:SetPoint("TOPLEFT", x, y)
            x = x + (b[3] or 170) + 10
        end
        y = y - 38
    end
    local function Reload()
        local Q = _G.H3z0UI
        if Q and Q.GUI and Q.GUI.ShowConfirmation then
            Q.GUI:ShowConfirmation({
                reload = true,
                title = "Reload UI?",
                message = "Turning Lorekeeper on or off takes effect after a reload.",
                acceptText = "Reload", cancelText = "Later",
                onAccept = function() if Q.SafeReload then Q:SafeReload() end end,
            })
        end
    end

    local function Reload2(msg)
        local Q = _G.H3z0UI
        if Q and Q.GUI and Q.GUI.ShowConfirmation then
            Q.GUI:ShowConfirmation({
                reload = true, title = "Reload UI?", message = msg,
                acceptText = "Reload", cancelText = "Later",
                onAccept = function() if Q.SafeReload then Q:SafeReload() end end,
            })
        end
    end
    local scroll = (d.style or "scroll") ~= "window"

    Section("Lorekeeper")
    Info("Talk to NPCs and handle quests your way. Scroll: a parchment scroll on the right of the screen with numbered choices (keys 1-9, Space continues, Esc says goodbye). Quest Window: the normal quest and NPC windows with the H3z0 UI look, plus the extras. Both move the camera in on the NPC and write the text out like a typewriter. Works everywhere: open world, dungeons, raids, delves and quests from items.", 60)
    Check("Enable Lorekeeper", "enabled", function()
        Refresh()
        if _G.H3z0UI_NotifySwitch then _G.H3z0UI_NotifySwitch("moduleFlag_h3zLorekeeper") end
        Reload2("Turning Lorekeeper on or off takes effect after a reload.")
    end)
    if d.style == nil then d.style = "scroll" end
    Place(GUI:CreateFormDropdown(tabContent, "Style", {
        { value = "scroll", text = "Scroll (parchment on the right)" },
        { value = "window", text = "Quest Window (normal windows + extras)" },
    }, "style", d, function() Reload2("The Lorekeeper style changes after a reload.") end))
    local blocker = _G.H3z0UI_LorekeeperBlockedBy and _G.H3z0UI_LorekeeperBlockedBy()
    if blocker then
        Info("|cffff9933" .. blocker .. " is loaded, so Lorekeeper is switched off and leaves quests to it. Disable " .. blocker .. " to use Lorekeeper.|r", 34)
    end
    Info("While Lorekeeper is on, H3z0 UI's quest automation (Auto Accept Quests, Auto Turn-In Quests, Auto Select Single Gossip Option) is off, so no quest text is skipped.", 34)
    if scroll then
        Buttons({
            { "Show a Preview", function() if _G.H3z0UI_LorekeeperTest then _G.H3z0UI_LorekeeperTest() end end },
            { "Run the Setup Again", function() if _G.H3z0UI_LorekeeperSetup then _G.H3z0UI_LorekeeperSetup() end end },
        })
    else
        Buttons({
            { "Type the Text Again", function() if _G.H3z0UI_LorekeeperTest then _G.H3z0UI_LorekeeperTest() end end, 190 },
        })
    end

    if db and not (ns.Client and (ns.Client.isClassic or ns.Client.isForever)) then
        db.h3zTeleports = db.h3zTeleports or {}
        local tp = db.h3zTeleports
        if tp.enabled == nil then tp.enabled = true end
        if tp.showUnknown == nil then tp.showUnknown = true end
        local function RefreshTP() if _G.H3z0UI_RefreshTeleports then _G.H3z0UI_RefreshTeleports() end end
        Section("Waygate")
        Info("An extra tab on the world map, under the quest log tabs: every teleport in one place. Favorites (right-click an icon to star it), Home (hearthstones and hearthstone toys), Class teleports and the dungeon teleports of every expansion. Left-click teleports.", 46)
        Place(GUI:CreateFormCheckbox(tabContent, "Waygate on the World Map", "enabled", tp, RefreshTP))
        Place(GUI:CreateFormCheckbox(tabContent, "Show Dungeon Teleports You Haven't Learned", "showUnknown", tp, RefreshTP))
        db.h3zWeeklies = db.h3zWeeklies or {}
        local wk = db.h3zWeeklies
        if wk.enabled == nil then wk.enabled = true end
        local function RefreshWK() if _G.H3z0UI_RefreshWeeklies then _G.H3z0UI_RefreshWeeklies() end end
        Section("Event Bar on the World Map")
        Info("A small panel at the bottom of the world map: the three Great Vault rows, this season's weekly quests (Soiree, Abundance, Prey Hunt, Lady Liadrin, Dungeon, Legend, Silvermoon Court, Zul'jarra's Forces, Slayer's Duellum, Stormarion Assault), the weekly quest of your professions, and the time to the daily and weekly reset. Hover a row for the quests. The plus / minus in the header folds the panel.", 60)
        Place(GUI:CreateFormCheckbox(tabContent, "Event Bar on the World Map", "enabled", wk, RefreshWK))
        Place(GUI:CreateFormCheckbox(tabContent, "Show the Great Vault Tile", "showVault", wk, RefreshWK))
    end

    Section("Camera")
    Check("Move the Camera In on the NPC", "camera")
    Slider("Camera Distance", 1, 20, 1, "cameraDistance")
    Check("Turn the Camera Toward the NPC", "cameraFocus")
    if scroll then Check("Hide the Rest of the UI While Talking", "hideUI") end
    Info("The camera turns toward the NPC (the game's own interact camera focus) and goes back to where it was when you stop talking. If another camera addon (DynamicCam, True Reticle) controls this, turn the option off. The UI is never hidden in combat.", 52)

    if scroll then
        Section("Transitions")
        Check("Smooth Transitions", "animate")
        Info("The scroll slides in and fades in when you start talking, fades out when you stop, and grows or shrinks smoothly with the text.", 22)
    end

    Section("Typewriter")
    Check("Typewriter Text", "typewriter")
    Slider("Typewriter Speed (letters per second)", 15, 200, 5, "typeSpeed")
    Info(scroll and "Click the text to show it all at once (or press Space)." or "Click the quest or NPC window to show the whole text at once.", 22)

    if scroll then
        Section("Font Sizes")
        Slider("NPC Name", 10, 30, 1, "npcSize")
        Slider("Quest Title", 12, 40, 1, "titleSize")
        Slider("Text", 10, 30, 1, "fontSize")
        Slider("Choices", 10, 30, 1, "optionSize")
        Slider("Rewards", 9, 24, 1, "rewardSize")
        Slider("Buttons", 9, 24, 1, "buttonSize")

        Section("Text Options")
        Check("Show the NPC Name", "showNpcName")
        Check("Show Quest Objectives", "showObjectives")
        Check("Page Turn Sound", "pageSound")

        Section("Keys & Choices")
        Check("Number Keys 1-9 Pick a Choice", "numberKeys")
        Check("Space Continues / Accepts / Completes", "spaceKey")
        Check("Space Picks the First Choice When Talking", "spaceSelectsFirst")
        Check("Show the Keys on the Buttons", "keyHints")
        Check("Pick the Only Choice Automatically (no text)", "autoSelectSingle")
        Check("Game Controller Support (Forever)", "controller")
        Info("Controller: D-pad or shoulder buttons move the highlight, A / Cross picks or continues, B / Circle says goodbye or declines. With ConsolePort (Midnight and Forever) the scroll is added to ConsolePort's cursor instead and ConsolePort does the moving. Steam Deck: use a gamepad layout (not Desktop mouse/keyboard) or the trackpad to click.", 48)
        Info("Esc says goodbye, or declines the quest that is offered. In combat the keys are off (the game doesn't allow them) - click instead.", 34)

        if d.inputDevice == nil then d.inputDevice = "auto" end
        Place(GUI:CreateFormDropdown(tabContent, "Button Hints Written For", {
            { value = "auto", text = "Automatic" },
            { value = "kbm", text = "Keyboard and mouse (Space, Esc)" },
            { value = "xbox", text = "Xbox (A, B)" },
            { value = "playstation", text = "PlayStation (Cross, Circle)" },
            { value = "switch", text = "Switch (B, A)" },
        }, "inputDevice", d, Refresh))
        Info("The confirm and cancel hints on the two big buttons. Automatic shows Xbox letters when a game controller is on (and ConsolePort is not), keys otherwise.", 34)

        Section("Rewards")
        Check("Mark the Choice That Sells for the Most (gold coin)", "markSellPrice")
        Check("Mark Gear That Is Better Than What You Wear (green arrow)", "markUpgrade")
        Check("Smaller Currency Rewards (icon and amount only)", "simpleCurrency")

        Section("Focus While Talking")
        Check("Hide the Names of Other Players and NPCs", "hideNames")
        Info("Their name tags come back when you leave the NPC (and after a reload if the game closed while you talked). The camera zoom and hiding the rest of the UI are under Camera and Transitions.", 34)

        Section("Scroll")
        Info("The scroll sits on the right of the screen. Move it with Move by Dragging (drag the blue handle, arrow keys nudge, right-click or Esc to finish) or with the two position sliders. Both change the same values. It is not part of Edit Mode.", 34)
        Buttons({ { "Move by Dragging", function()
            if _G.H3z0UI_LorekeeperMove then _G.H3z0UI_LorekeeperMove() end
        end, 170 } })
        Slider("Scale", 0.6, 1.6, 0.05, "scale")
        Slider("Width", 320, 1000, 10, "width")
        Slider("Minimum Height", 200, 1000, 10, "minHeight")
        Slider("Distance From the Right Edge", 0, 1600, 5, "offsetX")
        Slider("Vertical Position (from the middle)", -600, 600, 5, "offsetY")
        Slider("Parchment Opacity", 0.3, 1, 0.05, "bgAlpha")
    else
        Section("Font Sizes")
        Check("Use These Font Sizes", "fonts")
        Slider("Text", 10, 30, 1, "fontSize")
        Slider("Titles", 10, 36, 1, "titleSize")
        Slider("Choices (NPC options)", 10, 30, 1, "optionSize")
        Slider("Objectives & Rewards", 9, 24, 1, "rewardSize")

        Section("Window")
        Slider("Window Size", 0.6, 1.6, 0.05, "scale")
        Info("Width and height of the windows (0 = the normal size). The list and text grow with the window. NPC Window Height at 0: the window grows by itself until every choice fits.", 34)
        Slider("NPC Window Width", 0, 1000, 10, "npcWidth")
        Slider("NPC Window Height", 0, 1200, 10, "npcHeight")
        Slider("Quest Window Width", 0, 1000, 10, "questWidth")
        Slider("Quest Window Height", 0, 1200, 10, "questHeight")
        Info("Move the quest and NPC windows by dragging them (General & QoL > Blizzard Frame Mover > Quest).", 22)
    end

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_LorekeeperOptions = { BuildLorekeeperTab = function(tabContent) Build(tabContent) end }
