--[[
    H3z0 UI Options - Top Dock (Interface)
    A slim bar at the top of the screen: the H3z0 menu icons in two groups
    with the clock in between, and a thin colour line along the top edge.
    The Top Dock and the Dock Bar are either-or.
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
    local d = db and db.dock
    GUI:SetSearchContext({ tabName = "Dock Bar", subTabName = "Top Dock", tileId = "infobar", subPageIndex = 3 })
    if not d then return end
    d.slots = d.slots or {}

    local function Refresh()
        if _G.H3z0UI_RefreshDock then _G.H3z0UI_RefreshDock() end
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
    local function Check(label, key) Place(GUI:CreateFormCheckbox(tabContent, label, key, d, Refresh)) end
    local function Slider(label, min, max, step, key, opts) Place(GUI:CreateFormSlider(tabContent, label, min, max, step, key, d, Refresh, opts)) end
    local function Info(text, hgt)
        local label = GUI:CreateLabel(tabContent, text, 11, C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        y = y - (hgt or 22)
    end

    Section("Top Dock")
    Info("A slim bar at the top of the screen: your H3z0 menu icons in two rounded groups with the clock in between, and a thin colour line along the top edge of the screen.", 34)
    Place(GUI:CreateFormCheckbox(tabContent, "Show the Top Dock", "enabled", d, Refresh))
    Info("The Top Dock and the Dock Bar are either-or: turning one on turns the other off. Turning the Top Dock off brings the Dock Bar back.", 34)
    Check("Hide Blizzard Micro Menu", "hideBlizzardMenus")
    Info("The dock's icons replace the game's micro menu. Turning the dock off brings it back.", 22)
    Check("Hide in Combat", "hideInCombat")

    Section("Buttons")
    Info("Pick a side for every button, or Off to leave it out. Buttons keep the order shown here. The numbers (guild, friends, Great Vault) show on the icons.", 34)
    local sides = {
        { value = "left", text = "Left" },
        { value = "right", text = "Right" },
        { value = "off", text = "Off" },
    }
    local list = ns.H3z0Dock and ns.H3z0Dock.ButtonList and ns.H3z0Dock.ButtonList() or {}
    for _, e in ipairs(list) do
        if d.slots[e.key] == nil then d.slots[e.key] = ns.H3z0Dock.DefaultSlot(e.key) end
        Place(GUI:CreateFormDropdown(tabContent, e.label, sides, e.key, d.slots, Refresh))
    end

    Section("Look")
    Slider("Icon Size", 14, 40, 1, "iconSize")
    Slider("Icon Spacing", 2, 20, 1, "iconGap")
    Slider("Gap Between the Groups", 0, 30, 1, "pillGap")
    Slider("Background Opacity", 0, 100, 5, "bgOpacity")
    Slider("Scale", 0.5, 2, 0.05, "scale", { precision = 2 })
    Check("Border Around the Groups", "border")
    Place(GUI:CreateFormDropdown(tabContent, "Icon Colour", {
        { value = "white", text = "White" },
        { value = "class", text = "Class colour" },
    }, "iconColor", d, Refresh))

    Section("Clock")
    Check("Show the Clock", "showClock")
    Check("24 Hour Clock", "clock24")
    Place(GUI:CreateFormDropdown(tabContent, "Time", {
        { value = "local", text = "Local time" },
        { value = "server", text = "Realm time" },
    }, "clockSource", d, Refresh))
    Slider("Clock Size", 10, 32, 1, "clockSize")
    Info("Hover the clock for the daily and weekly reset. Click it to open the calendar.", 22)

    Section("Colour Line")
    Check("Show the Line at the Top of the Screen", "strip")
    Check("Use My Class Colour", "stripClassColor")
    Place(GUI:CreateFormColorPicker(tabContent, "Line Colour", "stripColor", d, Refresh, { noAlpha = true }))
    Slider("Line Thickness", 1, 6, 1, "stripHeight")

    Section("Position")
    Info("Move the dock anywhere in H3z0 UI Edit Mode (Top Dock). Vertical Position is used until you move it there.", 46)
    Slider("Vertical Position", -400, 0, 1, "offsetY")
    Info("/h3z0dock  -  Top Dock on / off", 22)

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_DockOptions = { BuildDockTab = function(tabContent) Build(tabContent) end }
