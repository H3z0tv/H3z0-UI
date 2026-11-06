--[[
    H3z0 UI Options - Arcanum (Interface)
    Loot toasts, alerts, auto vendor, self highlight and achievement tracker.
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local FORM_ROW = 32

-- open the options window on the Arcanum page
local function OpenArcanumPage()
    if H3z0UI and H3z0UI.ShowOptions and not (GUI.MainFrame and GUI.MainFrame:IsShown()) then
        pcall(H3z0UI.ShowOptions, H3z0UI)
    end
    local frame = GUI.MainFrame
    if not (frame and GUI.FindV2TileByID and GUI.SelectFeatureTile) then return end
    local _, index = GUI:FindV2TileByID(frame, "h3z_arcanum")
    if index then GUI:SelectFeatureTile(frame, index, { subPageIndex = 1 }) end
end

-- opts.panel: built inside the H3z0 UI Edit Mode settings panel (right-click
-- the Arcanum Loot Toasts handle): no options search entries, a link to the page
local function Build(tabContent, opts)
    opts = opts or {}
    local panel = opts.panel
    local y = -10
    local PAD = Shared.PADDING or 10
    local db = Shared.GetDB()
    local a = db and db.arcanum
    if not panel then
        GUI:SetSearchContext({ tabName = "Arcanum", subTabName = "Arcanum", tileId = "h3z_arcanum", subPageIndex = 1 })
    end
    if not a then return 80 end

    local function Refresh()
        if _G.H3z0UI_RefreshArcanum then _G.H3z0UI_RefreshArcanum() end
    end
    local function Section(title)
        if not panel then GUI:SetSearchSection(title) end
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PAD, y)
        y = y - header.gap
    end
    local function Place(widget, hgt)
        widget:SetPoint("TOPLEFT", PAD, y)
        widget:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - (hgt or FORM_ROW)
    end
    local function Check(label, key, tbl) Place(GUI:CreateFormCheckbox(tabContent, label, key, tbl or a, Refresh)) end
    local function Slider(label, min, max, step, key, opts) Place(GUI:CreateFormSlider(tabContent, label, min, max, step, key, a, Refresh, opts)) end
    local function Dropdown(label, options, key, tbl) Place(GUI:CreateFormDropdown(tabContent, label, options, key, tbl or a, Refresh)) end
    local function Info(text, hgt)
        local label = GUI:CreateLabel(tabContent, text, 11, C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        y = y - (hgt or 22)
    end

    Section("Arcanum")
    Info("Loot that deserves to be seen, plus small helpers: alerts, auto vendor, self highlight and a tidy achievement list.", 22)
    if panel then
        local link = GUI:CreateButton(tabContent, "Open Arcanum Settings", 180, 24, OpenArcanumPage)
        link:SetPoint("TOPLEFT", PAD, y)
        y = y - 34
    end
    Place(GUI:CreateFormCheckbox(tabContent, "Enable Arcanum", "enabled", a, function() Refresh(); if _G.H3z0UI_NotifySwitch then _G.H3z0UI_NotifySwitch("moduleFlag_h3zArcanum") end end))
    local test = GUI:CreateButton(tabContent, "Show Test Toasts", 180, 26, function()
        if _G.H3z0UI_ArcanumTest then _G.H3z0UI_ArcanumTest() end
    end)
    test:SetPoint("TOPLEFT", PAD, y)
    y = y - 38

    Section("Loot Toasts")
    Check("Item Toasts", "loot")
    Dropdown("Lowest Item Quality", {
        { value = 0, text = "Poor (grey)" }, { value = 1, text = "Common (white)" },
        { value = 2, text = "Uncommon (green)" }, { value = 3, text = "Rare (blue)" },
        { value = 4, text = "Epic (purple)" }, { value = 5, text = "Legendary (orange)" },
    }, "lootMinQuality")
    Check("Gold", "lootMoney")
    Check("Currency", "lootCurrency")
    Check("Reputation", "lootReputation")
    Check("Sound for Epic and Better", "lootSound")
    Info("Repeats stack into the toast already showing (x3, +450 gold). Hover a toast to keep it on screen and see the item tooltip.", 22)
    Info("While these toasts are on, Blizzard's own \"You received ...\" loot alerts are hidden (items, currency, gold). Switch them off and Blizzard's come back.", 22)

    Section("Toast Position")
    Info("Move the toasts anywhere in H3z0 UI Edit Mode (Arcanum Loot Toasts). Screen Side and the offsets are used until you move them there.", 22)
    Dropdown("Screen Side", { { value = "RIGHT", text = "Right" }, { value = "LEFT", text = "Left" } }, "toastSide")
    Dropdown("New Toasts Go", { { value = "UP", text = "Up (stack grows upwards)" }, { value = "DOWN", text = "Down (stack grows downwards)" } }, "toastGrow")
    Slider("Toast Width", 200, 600, 1, "toastWidth")
    Slider("Toast Height", 24, 80, 1, "toastHeight")
    Slider("Horizontal Offset", -800, 800, 1, "offsetX")
    Slider("Vertical Offset", -500, 500, 1, "offsetY")
    Slider("Scale", 0.5, 2, 0.05, "toastScale", { precision = 2 })
    Slider("Time on Screen (seconds)", 2, 12, 0.5, "toastHold", { precision = 1 })
    Slider("Most Toasts at Once", 1, 12, 1, "maxToasts")

    Section("Alerts")
    Check("Low Durability", "alertDurability")
    Slider("Warn at Durability (%)", 5, 80, 1, "durabilityThreshold")
    Check("Bags Nearly Full", "alertBags")
    Slider("Warn at Free Bag Slots", 0, 30, 1, "bagsThreshold")
    Check("New Mail", "alertMail")
    Check("Friends Online / Offline", "alertFriends")
    Check("Great Vault Rewards Waiting", "alertVault")

    local general = db.general
    if general then
        Section("Auto Vendor")
        Info("The same switches as Quality of Life > Automation.", 22)
        Check("Sell Junk Items at Vendors", "sellJunk", general)
        Dropdown("Auto Repair at Vendors", {
            { value = "off", text = "Off" },
            { value = "personal", text = "Personal Gold" },
            { value = "guild", text = "Guild Bank (fallback to personal)" },
        }, "autoRepair", general)
    end

    Section("Self Highlight")
    Info("Blizzard's own \"find yourself\" marker on your character while you are in combat.", 22)
    Check("Self Highlight", "selfHighlight")
    Dropdown("Highlight Style", {
        { value = "outline", text = "Outline" },
        { value = "circle", text = "Circle" },
        { value = "icon", text = "Icon" },
        { value = "outlinecircle", text = "Outline + Circle" },
        { value = "outlineicon", text = "Outline + Icon" },
    }, "selfHighlightMode")
    Check("Also When You Target an Enemy", "selfHighlightHostile")

    Section("Achievements")
    Check("Untrack Achievements When Earned", "untrackAchievements")

    tabContent:SetHeight(math.abs(y) + 50)
    return math.abs(y) + 50
end

ns.H3z0UI_ArcanumOptions = {
    BuildArcanumTab = function(tabContent) Build(tabContent) end,
    Build = Build,
    OpenPage = OpenArcanumPage,
}

---------------------------------------------------------------------------
-- H3z0 UI Edit Mode: right-click the Arcanum Loot Toasts handle for these
-- settings, with "Open Arcanum Settings" going to the Arcanum page
---------------------------------------------------------------------------
local ARCANUM_KEY = "h3zArcanumToasts"
local Settings_ = ns.Settings
local ProviderPanels = Settings_ and Settings_.ProviderPanels
if ProviderPanels and type(ProviderPanels.RegisterAfterLoad) == "function" then
    ProviderPanels:RegisterAfterLoad(function(ctx)
        ctx.RegisterShared(ARCANUM_KEY, {
            build = function(content)
                local ok, h = pcall(Build, content, { panel = true })
                if not ok then
                    if geterrorhandler then geterrorhandler()(h) end
                    return 80
                end
                return h or 80
            end,
        })
    end)
end

local ProviderFeatures = Settings_ and Settings_.ProviderFeatures
if ProviderFeatures and type(ProviderFeatures.Register) == "function" then
    pcall(ProviderFeatures.Register, ProviderFeatures, {
        id = "h3zArcanum",
        moverKey = ARCANUM_KEY,
        category = "ui",
        nav = { tileId = "h3z_arcanum", subPageIndex = 1 },
        layoutPositionOnly = false,
        getDB = function(profile) return profile and profile.arcanum end,
        apply = function() if _G.H3z0UI_RefreshArcanum then _G.H3z0UI_RefreshArcanum() end end,
        providerKey = ARCANUM_KEY,
    })
end
