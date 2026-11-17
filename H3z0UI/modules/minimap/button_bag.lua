---------------------------------------------------------------------------
-- H3z0 UI - Button Bag
-- Collects the minimap buttons of other addons into one movable H3z0 button.
-- Click the button (or hover it, if chosen) to open a small panel with all of them.
-- Drag the button to move it (unless locked); right-click locks / unlocks it.
-- Works on Midnight, WoW: Forever and Classic: buttons are found on the minimap itself,
-- so addons without LibDBIcon are collected too.
-- Settings: profile.minimap.buttonBag
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers


local DEFAULTS = {
    enabled = true,
    locked = false,
    openOnHover = false,
    autoHideDelay = 1.5,
    toggleSize = 30,
    buttonSize = 28,
    spacing = 3,
    columns = 6,
    grow = "DOWN",          -- side of the H3z0 button the panel opens on: DOWN, UP, LEFT, RIGHT
    hidden = {},            -- [button name] = true: stays where its addon put it
    point = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -230, y = -30 },
}

local Bag = {}
ns.ButtonBag = Bag
Bag.lost = {}   -- buttons given up this session because something else kept taking them (not saved)

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
local function S()
    local mm = Helpers and Helpers.GetModuleDB and Helpers.GetModuleDB("minimap")
    if not mm then return nil end
    local s = mm.buttonBag
    if type(s) ~= "table" then s = {}; mm.buttonBag = s end
    if not s.hiddenReset0285 then
        s.hiddenReset0285 = true
        s.hidden = {}
    end
    for k, v in pairs(DEFAULTS) do
        if s[k] == nil then
            if type(v) == "table" then
                local c = {}
                for k2, v2 in pairs(v) do c[k2] = v2 end
                s[k] = c
            else
                s[k] = v
            end
        end
    end
    return s
end
Bag.GetSettings = S

---------------------------------------------------------------------------
-- which minimap children are addon buttons
---------------------------------------------------------------------------
-- the game's own minimap pieces and other frames that must stay where they are
local SKIP = {
    MinimapZoomIn = true, MinimapZoomOut = true, MiniMapTracking = true, MiniMapTrackingButton = true,
    MiniMapTrackingFrame = true, MiniMapMailFrame = true, MinimapBackdrop = true, MiniMapWorldMapButton = true,
    GameTimeFrame = true, TimeManagerClockButton = true, QueueStatusMinimapButton = true, QueueStatusButton = true,
    ExpansionLandingPageMinimapButton = true, GarrisonLandingPageMinimapButton = true, MiniMapLFGFrame = true,
    MiniMapBattlefieldFrame = true, MiniMapInstanceDifficulty = true, GuildInstanceDifficulty = true,
    MiniMapChallengeMode = true, AddonCompartmentFrame = true, MinimapCompassTexture = true,
    MiniMapVoiceChatFrame = true, MiniMapMeetingStoneFrame = true, MinimapToggleButton = true,
    FeedbackUIButton = true, MiniMapRecordingButton = true, HelpOpenTicketButton = true,
    MinimapZoneTextButton = true, MiniMapNorthTag = true, MinimapNorthTag = true,
}
-- parts of names that mark map pins and markers, not buttons
local SKIP_PARTS = { "pin", "node", "note", "marker", "arrow", "poi", "waypoint", "gathermate", "handynotes",
    "tomtom", "questie", "routes", "h3z0", "blip", "dot" }

local function NameOf(f)
    local ok, n = pcall(f.GetName, f)
    if ok and type(n) == "string" then return n end
    return nil
end

local function IsAddonButton(f)
    if not f or not f.IsObjectType then return false end
    local okB, isBtn = pcall(f.IsObjectType, f, "Button")
    if not (okB and isBtn) then return false end
    local name = NameOf(f)
    if not name then return false end
    if name:sub(1, 12) == "LibDBIcon10_" then return true end
    if SKIP[name] then return false end
    local low = name:lower()
    for _, part in ipairs(SKIP_PARTS) do
        if low:find(part, 1, true) then return false end
    end
    if low:sub(1, 7) == "minimap" and not low:find("button", 1, true) then return false end
    local okP, prot = pcall(f.IsProtected, f)
    if okP and prot then return false end
    local w, h = f:GetSize()
    if type(w) ~= "number" or type(h) ~= "number" then return false end
    if w < 14 or h < 14 or w > 48 or h > 48 then return false end
    return true
end

---------------------------------------------------------------------------
-- frames
---------------------------------------------------------------------------
local toggle, panel
local bagged = {}       -- [button] = original { parent, scale, points }
local order = {}        -- buttons in the panel, sorted by name
local placing = false
local Bag_Add, Bag_Release
local hideTimer

local function Accent()
    local GUI = (_G.H3z0UI and _G.H3z0UI.GUI) or _G.H3z0UI_GUI
    local c = GUI and GUI.Colors and GUI.Colors.accent
    if type(c) == "table" and c[1] then return c[1], c[2], c[3] end
    return 0.2, 0.8, 0.6
end

-- rounded background with a thin accent border (H3z0 UI's own rounded panel); a plain square
-- backdrop only when that is missing
local function MakeBackdrop(f, radius)
    local R = ns.Round
    local r, g, b = Accent()
    if R and R.Panel then
        local bg = R.Panel(f, radius or 6)
        bg:SetAllPoints(f)
        bg:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1)) -- under the frame itself, so its count and highlight stay on top
        bg:SetFillColor(0.03, 0.035, 0.045, 0.95)
        bg:SetBorderColor(r, g, b, 1)
        f.h3zBg = bg
        return
    end
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.03, 0.03, 0.03, 0.95)
    f:SetBackdropBorderColor(r, g, b, 1)
end

local function SavePosition()
    local s = S()
    if not (s and toggle) then return end
    local point, _, relPoint, x, y = toggle:GetPoint(1)
    s.point = { point = point, relPoint = relPoint, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

local function ApplyPosition()
    local s = S()
    if not (s and toggle) then return end
    local p = s.point or DEFAULTS.point
    toggle:ClearAllPoints()
    toggle:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 0)
end

local Layout

local function VisibleCount()
    local n = 0
    for _, btn in ipairs(order) do if btn.h3zBagHidden ~= true then n = n + 1 end end
    return n
end

local function ShowPanel()
    if not panel or VisibleCount() == 0 then return end
    if hideTimer then hideTimer:Cancel() hideTimer = nil end
    Layout()
    panel:Show()
end

local function HidePanel()
    if hideTimer then hideTimer:Cancel() hideTimer = nil end
    if panel then panel:Hide() end
end

local function MouseInside()
    return (toggle and toggle:IsMouseOver()) or (panel and panel:IsShown() and panel:IsMouseOver())
end

-- hover mode: close a moment after the mouse left both the button and the panel
local function QueueHide()
    local s = S()
    if not (s and s.openOnHover) then return end
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(s.autoHideDelay or 1.5, function()
        hideTimer = nil
        if MouseInside() then QueueHide() return end
        HidePanel()
    end)
end

local function CreateFrames()
    if toggle then return end
    toggle = CreateFrame("Button", "H3z0UI_ButtonBag", UIParent)
    toggle:SetFrameStrata("MEDIUM")
    toggle:SetFrameLevel(20)
    toggle:SetClampedToScreen(true)
    toggle:SetMovable(true)
    toggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    toggle:RegisterForDrag("LeftButton")
    MakeBackdrop(toggle, 7)
    -- icon: four small tiles (a little box of buttons) in the accent colour
    local icon = CreateFrame("Frame", nil, toggle)
    icon:SetPoint("TOPLEFT", 6, -6)
    icon:SetPoint("BOTTOMRIGHT", -6, 6)
    toggle.icon = icon
    toggle.tiles = {}
    local r, g, b = Accent()
    for i = 1, 4 do
        local t = icon:CreateTexture(nil, "ARTWORK")
        local rs = ns.Round and ns.Round.ROUND_SQUARE
        if rs then
            t:SetTexture(rs)
            t:SetVertexColor(r, g, b, i == 1 and 1 or 0.75)
        else
            t:SetColorTexture(r, g, b, i == 1 and 1 or 0.75)
        end
        toggle.tiles[i] = t
    end
    local function PlaceTiles()
        local w = icon:GetWidth()
        if not w or w <= 0 then return end
        local gap = math.max(1, math.floor(w / 9))
        local cell = (w - gap) / 2
        for i, t in ipairs(toggle.tiles) do
            local c, row = (i - 1) % 2, math.floor((i - 1) / 2)
            t:ClearAllPoints()
            t:SetSize(cell, cell)
            t:SetPoint("TOPLEFT", icon, "TOPLEFT", c * (cell + gap), -row * (cell + gap))
        end
    end
    icon:SetScript("OnSizeChanged", PlaceTiles)
    toggle.PlaceTiles = PlaceTiles
    local count = toggle:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetDrawLayer("OVERLAY", 7)
    count:SetPoint("BOTTOMRIGHT", 2, -2)
    toggle.count = count
    local hl = toggle:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    if ns.Round and ns.Round.ROUND_SQUARE then
        hl:SetTexture(ns.Round.ROUND_SQUARE)
        hl:SetVertexColor(1, 1, 1, 0.12)
    else
        hl:SetColorTexture(1, 1, 1, 0.15)
    end

    toggle:SetScript("OnClick", function(_, button)
        local s = S()
        if button == "RightButton" then
            s.locked = not s.locked
            print("|cff60a5faH3z0 UI:|r Button Bag " .. (s.locked and "locked." or "unlocked: drag it to move it."))
            return
        end
        if panel:IsShown() then HidePanel() else ShowPanel() end
    end)
    toggle:SetScript("OnDragStart", function(self)
        local s = S()
        if s and s.locked then return end
        if InCombatLockdown() then return end
        HidePanel()
        self:StartMoving()
    end)
    toggle:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
        ApplyPosition()
    end)
    toggle:SetScript("OnEnter", function(self)
        local s = S()
        if s and s.openOnHover then ShowPanel() end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("H3z0 UI Button Bag")
        GameTooltip:AddLine(string.format("%d addon buttons", #order), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Left-click: open / close", 0.6, 0.6, 0.6)
        GameTooltip:AddLine((s and s.locked) and "Right-click: unlock to move it" or "Drag: move   Right-click: lock", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function()
        GameTooltip:Hide()
        QueueHide()
    end)

    panel = CreateFrame("Frame", "H3z0UI_ButtonBagPanel", toggle)
    panel:SetFrameStrata("MEDIUM")
    panel:SetFrameLevel(25)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    MakeBackdrop(panel, 8)
    panel:Hide()
    panel:SetScript("OnLeave", QueueHide)
    panel:SetScript("OnEnter", function() if hideTimer then hideTimer:Cancel() hideTimer = nil end end)
end

---------------------------------------------------------------------------
-- placing the buttons
---------------------------------------------------------------------------
local function PlaceButton(btn, x, y, size)
    placing = true
    local w, h = btn:GetSize()
    local base = math.max(w or size, h or size, 1)
    pcall(btn.SetParent, btn, panel)
    pcall(btn.SetScale, btn, size / base)
    pcall(btn.ClearAllPoints, btn)
    local scale = btn:GetScale() or 1
    pcall(btn.SetPoint, btn, "TOPLEFT", panel, "TOPLEFT", x / scale, -y / scale)
    -- the usual minimap button library pins strata and level ("fixed"), which left those buttons
    -- under the panel's background: dark and not clickable. Unpin, raise, pin again.
    if btn.SetFixedFrameStrata then pcall(btn.SetFixedFrameStrata, btn, false) end
    if btn.SetFixedFrameLevel then pcall(btn.SetFixedFrameLevel, btn, false) end
    pcall(btn.SetFrameStrata, btn, panel:GetFrameStrata())
    pcall(btn.SetFrameLevel, btn, panel:GetFrameLevel() + 5)
    if btn.SetFixedFrameStrata then pcall(btn.SetFixedFrameStrata, btn, true) end
    if btn.SetFixedFrameLevel then pcall(btn.SetFixedFrameLevel, btn, true) end
    pcall(btn.SetAlpha, btn, 1)
    placing = false
end

Layout = function()
    local s = S()
    if not (s and panel) then return end
    local size, gap = s.buttonSize or 28, s.spacing or 3
    -- a button its own addon hid (its "hide minimap icon" option) gets no slot
    local shown = {}
    for _, btn in ipairs(order) do
        if btn.h3zBagHidden ~= true then shown[#shown + 1] = btn end
    end
    local n = #shown
    local cols = math.max(1, math.min(n, s.columns or 6))
    local rows = math.max(1, math.ceil(n / cols))
    if s.grow == "LEFT" or s.grow == "RIGHT" then
        -- sideways: the columns setting counts rows instead, so it stays a strip along the side
        rows = math.max(1, math.min(n, s.columns or 6))
        cols = math.max(1, math.ceil(n / rows))
    end
    local pad = 5
    panel:SetSize(pad * 2 + cols * size + (cols - 1) * gap, pad * 2 + rows * size + (rows - 1) * gap)
    for i, btn in ipairs(shown) do
        local c, r
        if s.grow == "LEFT" or s.grow == "RIGHT" then
            c, r = math.floor((i - 1) / rows), (i - 1) % rows
        else
            c, r = (i - 1) % cols, math.floor((i - 1) / cols)
        end
        PlaceButton(btn, pad + c * (size + gap), pad + r * (size + gap), size)
    end
    panel:ClearAllPoints()
    if s.grow == "UP" then
        panel:SetPoint("BOTTOMRIGHT", toggle, "TOPRIGHT", 0, 3)
    elseif s.grow == "LEFT" then
        panel:SetPoint("TOPRIGHT", toggle, "TOPLEFT", -3, 0)
    elseif s.grow == "RIGHT" then
        panel:SetPoint("TOPLEFT", toggle, "TOPRIGHT", 3, 0)
    else
        panel:SetPoint("TOPRIGHT", toggle, "BOTTOMRIGHT", 0, -3)
    end
end

local function SortOrder()
    table.sort(order, function(a, b)
        local na, nb = NameOf(a) or "", NameOf(b) or ""
        na, nb = na:gsub("^LibDBIcon10_", ""):lower(), nb:gsub("^LibDBIcon10_", ""):lower()
        return na < nb
    end)
end

-- the addon tries to put its button back on the minimap (drag, its own refresh): keep it in the bag
local function GuardButton(btn)
    if btn.h3zBagGuard then return end
    btn.h3zBagGuard = true
    local fights, since, lastFrame = 0, 0, 0
    local function Back()
        if placing or not bagged[btn] then return end
        -- Something else keeps taking this button every frame (another collector addon): let it have
        -- it for this session instead of fighting. Counted once per frame, so a normal refresh of the
        -- minimap (which moves every button once) never counts as a fight.
        local now = GetTime()
        if now ~= lastFrame then
            lastFrame = now
            if now - since > 2 then since, fights = now, 0 end
            fights = fights + 1
        end
        if fights > 40 then
            local n = NameOf(btn)
            if n then Bag.lost[n] = true end
            Bag_Release(btn)
            if toggle then toggle.count:SetText(VisibleCount() > 0 and VisibleCount() or "") end
            Layout()
            return
        end
        if InCombatLockdown() and btn.IsProtected and btn:IsProtected() then return end
        Layout()
    end
    hooksecurefunc(btn, "SetPoint", Back)
    hooksecurefunc(btn, "SetParent", Back)
    -- its addon hides or shows it (e.g. "hide minimap icon"): free or take its slot
    hooksecurefunc(btn, "Hide", function()
        if placing or not bagged[btn] then return end
        btn.h3zBagHidden = true
        Layout()
    end)
    hooksecurefunc(btn, "Show", function()
        if placing or not bagged[btn] then return end
        btn.h3zBagHidden = nil
        Layout()
    end)
    hooksecurefunc(btn, "SetAlpha", function(self, a)
        if placing or not bagged[btn] or type(a) ~= "number" or a >= 1 then return end
        placing = true
        self:SetAlpha(1)
        placing = false
    end)
    -- LibDBIcon's fade (only on mouseover) would hide it inside the panel
    if btn.fadeOut and btn.fadeOut.Play then
        hooksecurefunc(btn.fadeOut, "Play", function(anim)
            if bagged[btn] then anim:Stop() btn:SetAlpha(1) end
        end)
    end
    -- no dragging around the minimap from inside the bag
    pcall(btn.RegisterForDrag, btn)
end

function Bag_Add(btn)
    if bagged[btn] then return end
    local name = NameOf(btn)
    local s = S()
    if s and name and (s.hidden[name] or Bag.lost[name]) then return end
    local saved = { parent = btn:GetParent(), scale = btn:GetScale(), points = {} }
    for i = 1, btn:GetNumPoints() do saved.points[i] = { btn:GetPoint(i) } end
    bagged[btn] = saved
    btn.h3zBagHidden = (not btn:IsShown()) or nil
    order[#order + 1] = btn
    -- LibDBIcon: no fade on mouseover, it lives in the panel now
    local LDBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDBI and name and name:sub(1, 12) == "LibDBIcon10_" and LDBI.ShowOnEnter then
        pcall(LDBI.ShowOnEnter, LDBI, name:sub(13), false)
    end
    GuardButton(btn)
end

function Bag_Release(btn)
    local saved = bagged[btn]
    if not saved then return end
    bagged[btn] = nil
    btn.h3zBagHidden = nil
    for i = #order, 1, -1 do if order[i] == btn then table.remove(order, i) end end
    placing = true
    pcall(btn.SetParent, btn, saved.parent or Minimap)
    pcall(btn.SetScale, btn, saved.scale or 1)
    pcall(btn.ClearAllPoints, btn)
    for _, p in ipairs(saved.points) do pcall(btn.SetPoint, btn, unpack(p)) end
    pcall(btn.RegisterForDrag, btn, "LeftButton")
    placing = false
end

local function Scan()
    local found = {}
    local function Look(parent)
        if not parent or not parent.GetChildren then return end
        for _, child in ipairs({ parent:GetChildren() }) do
            if IsAddonButton(child) then found[child] = true end
        end
    end
    Look(Minimap)
    Look(_G.MinimapBackdrop)
    Look(_G.MinimapCluster)
    local LDBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDBI and LDBI.GetButtonList then
        for _, n in ipairs(LDBI:GetButtonList() or {}) do
            local b = _G["LibDBIcon10_" .. n]
            if b then found[b] = true end
        end
    end
    return found
end

-- other addons that also collect minimap buttons: two collectors pull the same buttons back and forth
local OTHER_COLLECTORS = { "MinimapButtonButton", "MBB", "MinimapButtonBag", "MinimapButtonFrame", "ButtonBin" }
local function OtherCollector()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not loaded then return nil end
    for _, n in ipairs(OTHER_COLLECTORS) do
        local ok, on = pcall(loaded, n)
        if ok and on then return n end
    end
    return nil
end
Bag.OtherCollector = OtherCollector

function Bag.Refresh()
    local s = S()
    if not s then return end
    if InCombatLockdown() then Bag.pending = true return end
    local other = s.enabled and OtherCollector()
    if other then
        for btn in pairs(bagged) do Bag_Release(btn) end
        if toggle then toggle:Hide() HidePanel() end
        if not Bag.warned then
            Bag.warned = true
            print("|cff60a5faH3z0 UI:|r Another addon that collects minimap buttons is on (" .. other .. "). The Button Bag stays off while it is on: turn that addon off in the AddOns list to use the Button Bag.")
        end
        return
    end
    if not s.enabled then
        for btn in pairs(bagged) do Bag_Release(btn) end
        if toggle then toggle:Hide() HidePanel() end
        return
    end
    CreateFrames()
    -- buttons you took out of the bag go back to the minimap
    for btn in pairs(bagged) do
        local n = NameOf(btn)
        if n and s.hidden[n] then Bag_Release(btn) end
    end
    for btn in pairs(Scan()) do Bag_Add(btn) end
    SortOrder()
    local ts = s.toggleSize or 30
    toggle:SetSize(ts, ts)
    if toggle.PlaceTiles then toggle.PlaceTiles() end
    ApplyPosition()
    local vis = VisibleCount()
    toggle.count:SetText(vis > 0 and vis or "")
    toggle:Show()
    Layout()
end
_G.H3z0UI_RefreshButtonBag = Bag.Refresh

-- buttons the panel holds, by name (for the options list)
function Bag.Known()
    local list = {}
    for btn in pairs(bagged) do list[#list + 1] = NameOf(btn) end
    for btn in pairs(Scan()) do
        local n = NameOf(btn)
        if n and not bagged[btn] then list[#list + 1] = n end
    end
    local s = S()
    if s then for n in pairs(s.hidden) do list[#list + 1] = n end end
    local seen, out = {}, {}
    for _, n in ipairs(list) do if n and not seen[n] then seen[n] = true out[#out + 1] = n end end
    table.sort(out)
    return out
end

function Bag.DisplayName(n)
    return (n:gsub("^LibDBIcon10_", ""))
end

---------------------------------------------------------------------------
-- events: addons make their buttons at different times, so look again a few times
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ADDON_LOADED")
local queued = false
local function Queue(delay)
    if queued then return end
    queued = true
    C_Timer.After(delay or 0.5, function() queued = false pcall(Bag.Refresh) end)
end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if Bag.pending then Bag.pending = nil Queue(0.1) end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        Queue(1)
        C_Timer.After(5, function() pcall(Bag.Refresh) end)
        C_Timer.After(15, function() pcall(Bag.Refresh) end)
        local LDBI = LibStub and LibStub("LibDBIcon-1.0", true)
        if LDBI and LDBI.RegisterCallback and not Bag.ldbiHooked then
            Bag.ldbiHooked = true
            LDBI.RegisterCallback(Bag, "LibDBIcon_IconCreated", function() Queue(0.2) end)
        end
        return
    end
    -- ADDON_LOADED after login: an addon loaded on demand may add a button
    if Bag.ldbiHooked then Queue(1) end
end)
