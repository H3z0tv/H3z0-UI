--[[
    H3z0 UI - Window Skins

    A dark, translucent, rounded window look for the chat and Blizzard's damage
    meter:
      Chat          - one rounded panel behind each chat window and its tab row,
                      a thin line between the tabs and the text, and an accent
                      underline on the selected tab.
      Damage Meter  - a rounded panel behind each meter window with a header
                      strip and an accent line under it; Blizzard's own window
                      background is faded out and the bars get a flat texture.

    Only H3z0 UI's own panels / textures are created; Blizzard frames only get
    their background textures faded (alpha) and the bar texture swapped. No
    Blizzard function or field is replaced or written.

    Settings: profile.windowSkins = { enabled, chat, damageMeter, alpha, header }
]]

local ADDON_NAME, ns = ...

local WS = {}
ns.WindowSkins = WS

local WHITE = "Interface\\Buttons\\WHITE8x8"
local BAR_TEX = "Interface\\AddOns\\" .. ADDON_NAME .. "\\assets\\H3z0UI_v2"
local MAX_METERS = 5

local function DB()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.windowSkins = p.windowSkins or {}
    local s = p.windowSkins
    if s.enabled == nil then s.enabled = true end
    if s.chat == nil then s.chat = true end
    if s.damageMeter == nil then s.damageMeter = true end
    if s.alpha == nil then s.alpha = 0.78 end
    if s.header == nil then s.header = true end
    return s
end
WS.GetSettings = DB

local function Accent()
    local H = ns.Helpers
    if H and H.GetAddonAccentColor then
        local ok, r, g, b = pcall(H.GetAddonAccentColor)
        if ok and type(r) == "number" then return r, g, b end
    end
    return 0.204, 0.827, 0.6
end

local function Radius()
    local R = ns.Round
    if R and R.Enabled and R.Enabled() then return R.Radius() + 2 end
    return 1
end

local function StylePanel(panel, s)
    panel:SetRadius(Radius())
    panel:SetFillColor(0.035, 0.04, 0.055, s.alpha or 0.78)
    panel:SetBorderColor(1, 1, 1, 0.07)
end

local function NewPanel(parent)
    local R = ns.Round
    if not R then return nil end
    local p = R.Panel(parent, Radius())
    return p
end

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------
local function ChatFrames()
    local list = {}
    local names = _G.CHAT_FRAMES
    if type(names) == "table" then
        for _, n in ipairs(names) do
            local f = _G[n]
            if f then list[#list + 1] = f end
        end
    else
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local f = _G["ChatFrame" .. i]
            if f then list[#list + 1] = f end
        end
    end
    return list
end

local function SelectedChat()
    local dock = _G.GENERAL_CHAT_DOCK
    if dock and _G.FCFDock_GetSelectedWindow then
        local ok, w = pcall(_G.FCFDock_GetSelectedWindow, dock)
        if ok then return w end
    end
    return nil
end

local function IsDocked(cf)
    local dock = _G.GENERAL_CHAT_DOCK
    if not (dock and dock.DOCKED_CHAT_FRAMES) then return false end
    for _, f in ipairs(dock.DOCKED_CHAT_FRAMES) do
        if f == cf then return true end
    end
    return false
end

local function SkinChatTab(cf, on, selected)
    local name = cf:GetName()
    local tab = name and _G[name .. "Tab"]
    if not tab then return end
    -- H3z0 UI's own tab boxes (chat.lua) give way to the underline
    if tab.__h3z0uiBackdrop then tab.__h3z0uiBackdrop:SetAlpha(on and 0 or 1) end
    local line = tab.h3zWSLine
    if not line then
        if not on then return end
        line = tab:CreateTexture(nil, "OVERLAY", nil, 7)
        line:SetTexture(WHITE)
        tab.h3zWSLine = line
    end
    local fs = tab.GetFontString and tab:GetFontString()
    line:ClearAllPoints()
    if fs and fs:GetText() then
        line:SetPoint("BOTTOMLEFT", fs, "BOTTOMLEFT", -2, -5)
        line:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 2, -5)
    else
        line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 6, 2)
        line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 2)
    end
    line:SetHeight(2)
    local r, g, b = Accent()
    line:SetVertexColor(r, g, b, 1)
    line:SetShown(on and selected)
end

local function SkinChat(cf, s)
    local on = s.enabled and s.chat
    local panel = cf.h3zWSPanel
    if not on then
        if panel then panel:Hide() end
        if cf.__h3z0uiChatBackdrop then cf.__h3z0uiChatBackdrop:SetAlpha(1) end
        SkinChatTab(cf, false, false)
        return
    end
    if not panel then
        panel = NewPanel(cf)
        if not panel then return end
        panel.sep = panel:CreateTexture(nil, "BORDER", nil, 2)
        panel.sep:SetTexture(WHITE)
        cf.h3zWSPanel = panel
    end
    panel:SetFrameStrata(cf:GetFrameStrata())
    panel:SetFrameLevel(math.max(0, cf:GetFrameLevel() - 1))
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", cf, "TOPLEFT", -8, 30)
    panel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 8, -8)
    StylePanel(panel, s)
    local px = ns.Round.PixelSize(panel)
    panel.sep:ClearAllPoints()
    panel.sep:SetPoint("TOPLEFT", cf, "TOPLEFT", -2, 4)
    panel.sep:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 2, 4)
    panel.sep:SetHeight(px)
    panel.sep:SetVertexColor(1, 1, 1, 0.08)
    panel:Show()
    -- the glass backdrop from chat.lua would double the background
    if cf.__h3z0uiChatBackdrop then cf.__h3z0uiChatBackdrop:SetAlpha(0) end
    local selected = (not IsDocked(cf)) or SelectedChat() == cf
    SkinChatTab(cf, true, selected)
end

function WS.ApplyChat()
    local s = DB()
    if not s then return end
    for _, cf in ipairs(ChatFrames()) do
        if not (cf.IsForbidden and cf:IsForbidden()) then pcall(SkinChat, cf, s) end
    end
end

---------------------------------------------------------------------------
-- Damage meter
---------------------------------------------------------------------------
local function IsButtonLike(obj)
    if not obj.IsObjectType then return true end
    if obj:IsObjectType("Button") or obj:IsObjectType("EditBox") or obj:IsObjectType("StatusBar")
        or obj:IsObjectType("ScrollFrame") or obj:IsObjectType("Slider") then
        return true
    end
    if obj.ForEachFrame or obj.ScrollToElementData then return true end    -- the list itself
    if obj.SetScrollPercentage then return true end                         -- its scroll bar
    return false
end

-- fade Blizzard's window background textures (background / border layers only)
local function FadeBackground(frame, on, depth)
    depth = depth or 0
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.IsObjectType and r:IsObjectType("Texture") then
            local layer = r:GetDrawLayer()
            if layer == "BACKGROUND" or layer == "BORDER" then
                if on then
                    if r.h3zWSAlpha == nil then r.h3zWSAlpha = r:GetAlpha() end
                    r:SetAlpha(0)
                elseif r.h3zWSAlpha ~= nil then
                    r:SetAlpha(r.h3zWSAlpha)
                    r.h3zWSAlpha = nil
                end
            end
        end
    end
    if depth >= 1 then return end
    for _, c in ipairs({ frame:GetChildren() }) do
        if c and not c.h3zWSOwn and not IsButtonLike(c) then
            FadeBackground(c, on, depth + 1)
        end
    end
end

local function FindList(win)
    if win.ScrollBox and win.ScrollBox.ForEachFrame then return win.ScrollBox end
    for _, c in ipairs({ win:GetChildren() }) do
        if c.ForEachFrame then return c end
        for _, cc in ipairs({ c:GetChildren() }) do
            if cc.ForEachFrame then return cc end
        end
    end
    return nil
end

local function FindStatusBar(entry)
    if entry.StatusBar and entry.StatusBar.SetStatusBarTexture then return entry.StatusBar end
    if entry.IsObjectType and entry:IsObjectType("StatusBar") then return entry end
    for _, c in ipairs({ entry:GetChildren() }) do
        if c.IsObjectType and c:IsObjectType("StatusBar") then return c end
    end
    return nil
end

local function SkinEntry(entry)
    local s = DB()
    if not (s and s.enabled and s.damageMeter) then return end
    local bar = FindStatusBar(entry)
    if not bar then return end
    local cur = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if cur and cur.GetTexture and cur:GetTexture() == BAR_TEX then return end
    pcall(bar.SetStatusBarTexture, bar, BAR_TEX)
end

local function SkinEntries(win)
    local list = FindList(win)
    if not list then return end
    pcall(list.ForEachFrame, list, SkinEntry)
    if list.h3zWSHooked then return end
    list.h3zWSHooked = true
    -- the callback gets (owner, frame, data); pick the frame either way
    local function cb(a, b)
        local f = (type(b) == "table" and b.GetObjectType) and b or a
        if type(f) == "table" and f.GetObjectType then pcall(SkinEntry, f) end
    end
    local SU = _G.ScrollUtil
    if SU and SU.AddInitializedFrameCallback then
        pcall(SU.AddInitializedFrameCallback, list, cb, WS, false)
    elseif SU and SU.AddAcquiredFrameCallback then
        pcall(SU.AddAcquiredFrameCallback, list, cb, WS, false)
    end
end

local function SkinMeter(win, s)
    local on = s.enabled and s.damageMeter
    local panel = win.h3zWSPanel
    if not on then
        if panel then panel:Hide() end
        if win.h3zWSFaded then FadeBackground(win, false); win.h3zWSFaded = nil end
        return
    end
    if not panel then
        panel = NewPanel(win)
        if not panel then return end
        panel.h3zWSOwn = true
        panel.header = panel:CreateTexture(nil, "BACKGROUND", nil, 3)
        panel.header:SetTexture(WHITE)
        panel.line = panel:CreateTexture(nil, "BORDER", nil, 3)
        panel.line:SetTexture(WHITE)
        win.h3zWSPanel = panel
    end
    panel:SetFrameStrata(win:GetFrameStrata())
    panel:SetFrameLevel(math.max(0, win:GetFrameLevel() - 1))
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", win, "TOPLEFT", -2, 2)
    panel:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 2, -2)
    StylePanel(panel, s)

    -- header strip + accent line (rounded top corners follow the panel)
    local px = ns.Round.PixelSize(panel)
    local hh = 24
    panel.header:ClearAllPoints()
    panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    panel.header:SetHeight(hh)
    panel.header:SetVertexColor(1, 1, 1, 0.045)
    local masks = ns.Round.CornerMasks(panel, panel, Radius(), 0, "h3zWSMasks")
    ns.Round.Mask(panel.header, masks, true)
    local r, g, b = Accent()
    panel.line:ClearAllPoints()
    panel.line:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -hh)
    panel.line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -hh)
    panel.line:SetHeight(px)
    panel.line:SetVertexColor(r, g, b, 0.9)
    panel.header:SetShown(s.header)
    panel.line:SetShown(s.header)
    panel:Show()

    FadeBackground(win, true)
    win.h3zWSFaded = true
    SkinEntries(win)

    if not win.h3zWSShowHook then
        win.h3zWSShowHook = true
        win:HookScript("OnShow", function(self)
            C_Timer.After(0, function()
                local st = DB()
                if st then pcall(SkinMeter, self, st) end
            end)
        end)
    end
end

function WS.ApplyDamageMeter()
    local s = DB()
    if not s then return end
    for i = 1, MAX_METERS do
        local win = _G["DamageMeterSessionWindow" .. i]
        if win and not (win.IsForbidden and win:IsForbidden()) then pcall(SkinMeter, win, s) end
    end
end

function WS.ApplyAll()
    WS.ApplyChat()
    WS.ApplyDamageMeter()
end
_G.H3z0UI_RefreshWindowSkins = WS.ApplyAll

---------------------------------------------------------------------------
-- Events / hooks
---------------------------------------------------------------------------
local hooked = false
local function Hook()
    if hooked then return end
    hooked = true
    local function later() C_Timer.After(0.05, WS.ApplyChat) end
    for _, fn in ipairs({ "FCF_Tab_OnClick", "FCF_DockUpdate", "FCF_OpenTemporaryWindow", "FCF_OpenNewWindow",
        "FCF_SelectDockFrame", "FCF_UnDockFrame", "FCF_DockFrame" }) do
        if type(_G[fn]) == "function" then hooksecurefunc(fn, later) end
    end
    if type(_G.H3z0UI_RefreshChat) == "function" then
        hooksecurefunc(_G, "H3z0UI_RefreshChat", later)
    end
end

local known = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_DamageMeter" then C_Timer.After(0.5, WS.ApplyDamageMeter) end
        return
    end
    C_Timer.After(1.5, function()
        Hook()
        WS.ApplyAll()
    end)
end)

-- new meter windows can be opened at any time; check for them now and then
C_Timer.NewTicker(3, function()
    if InCombatLockdown() then return end
    local n = 0
    for i = 1, MAX_METERS do
        if _G["DamageMeterSessionWindow" .. i] then n = i end
    end
    if n ~= known then
        known = n
        WS.ApplyDamageMeter()
    end
end)
