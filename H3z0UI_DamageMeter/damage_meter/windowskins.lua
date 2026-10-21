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
local BAR_TEX = "Interface\\Buttons\\WHITE8x8"     -- flat class-coloured bars
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
    -- separate opacity for the chat, the damage meter and the action button slots
    if s.chatAlpha == nil then s.chatAlpha = s.alpha or 0.9 end
    if s.meterAlpha == nil then s.meterAlpha = s.alpha or 0.9 end
    if s.slotAlpha == nil then s.slotAlpha = 1 end
    if not s.fix1 then          -- 0.24.0: back on once
        s.fix1 = true
        s.enabled = true
    end
    if not s.slate1 then        -- 0.24.0: the flat slate look (solid panel, thin grey border)
        s.slate1 = true
        s.alpha = 0.9
        s.header = false
    end
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

-- flat slate windows: almost square corners, a solid dark slate fill and a thin grey border
local function Radius()
    local R = ns.Round
    if R and R.Enabled and R.Enabled() then return 3 end
    return 1
end

local function StylePanel(panel, s, alpha)
    panel:SetRadius(Radius())
    local R = ns.Round
    local f, b = R.SLATE_FILL, R.SLATE_BORDER
    panel:SetFillColor(f[1], f[2], f[3], alpha or s.alpha or 0.9)
    panel:SetBorderColor(b[1], b[2], b[3], 1)
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
    -- no tab boxes: H3z0 UI's (chat.lua) and Blizzard's tab textures are faded out
    if tab.__h3z0uiBackdrop then tab.__h3z0uiBackdrop:SetAlpha(on and 0 or 1) end
    for _, r in ipairs({ tab:GetRegions() }) do
        if r.IsObjectType and r:IsObjectType("Texture") and r ~= tab.glow and r ~= tab.h3zWSLine then
            if on then
                if r.h3zWSA == nil then r.h3zWSA = r:GetAlpha() end
                r:SetAlpha(0)
            elseif r.h3zWSA ~= nil then
                r:SetAlpha(r.h3zWSA); r.h3zWSA = nil
            end
        end
    end
    local line = tab.h3zWSLine
    if not line then
        if not on then return end
        line = tab:CreateTexture(nil, "OVERLAY", nil, 7)
        line:SetTexture(WHITE)
        tab.h3zWSLine = line
    end
    local fs = tab.GetFontString and tab:GetFontString()
    -- slate look: the selected tab's name in the accent colour, the others grey
    if fs then
        if on then
            if selected then
                local ar, ag, ab = Accent()
                fs:SetTextColor(ar, ag, ab, 1)
            else
                fs:SetTextColor(0.62, 0.66, 0.7, 1)
            end
        end
    end
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
    line:SetShown(false)
end

local function SkinChat(cf, s)
    local on = s.enabled and s.chat
    local panel = cf.h3zWSPanel
    if not on then
        if panel then panel:Hide() end
        if cf.__h3z0uiChatBackdrop then cf.__h3z0uiChatBackdrop:SetAlpha(1) end
        if cf.__h3z0uiEditBoxBackdrop then cf.__h3z0uiEditBoxBackdrop:SetAlpha(1) end
        local eb = _G[(cf:GetName() or "") .. "EditBox"]
        if eb then
            for _, r in ipairs({ eb:GetRegions() }) do
                if r.h3zWSA ~= nil then r:SetAlpha(r.h3zWSA); r.h3zWSA = nil end
            end
            if eb.__h3z0uiChatBackdrop then eb.__h3z0uiChatBackdrop:SetAlpha(1) end
        end
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
    -- lowest layer, so the tabs and the text always draw on top of it
    panel:SetFrameStrata("BACKGROUND")
    panel:SetFrameLevel(1)
    panel:ClearAllPoints()
    -- the panel starts right under the tab row (tabs stay on top, readable); the combat log
    -- also covers its filter bar (My actions / What happened to me?)
    local top = 4
    local qb = _G.CombatLogQuickButtonFrame_Custom
    if cf == _G.ChatFrame2 and qb and qb:IsShown() then top = (qb:GetHeight() or 24) + 4 end
    panel:SetPoint("TOPLEFT", cf, "TOPLEFT", -8, top)
    panel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 8, -8)
    StylePanel(panel, s, s.chatAlpha)
    local px = ns.Round.PixelSize(panel)
    panel.sep:ClearAllPoints()
    panel.sep:SetPoint("TOPLEFT", cf, "TOPLEFT", -2, 2)
    panel.sep:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 2, 2)
    panel.sep:SetHeight(px)
    panel.sep:SetVertexColor(0.24, 0.28, 0.32, 0)
    panel:Show()
    -- the glass backdrop from chat.lua would double the background
    if cf.__h3z0uiChatBackdrop then cf.__h3z0uiChatBackdrop:SetAlpha(0) end
    -- typing box: no box at all, just "Say:" and what you type
    local eb = _G[(cf:GetName() or "") .. "EditBox"]
    if eb then
        for _, r in ipairs({ eb:GetRegions() }) do
            if r.IsObjectType and r:IsObjectType("Texture") then
                if r.h3zWSA == nil then r.h3zWSA = r:GetAlpha() end
                r:SetAlpha(0)
            end
        end
        if eb.__h3z0uiChatBackdrop then eb.__h3z0uiChatBackdrop:SetAlpha(0) end
    end
    if cf.__h3z0uiEditBoxBackdrop then cf.__h3z0uiEditBoxBackdrop:SetAlpha(0) end
    local selected = (not IsDocked(cf)) or SelectedChat() == cf
    SkinChatTab(cf, true, selected)
end

function WS.ApplyChat()
    local s = DB()
    if not s then return end
    for _, cf in ipairs(ChatFrames()) do
        if not (cf.IsForbidden and cf:IsForbidden()) then
            local ok, err = pcall(SkinChat, cf, s)
            if not ok then WS.lastError = err end
        end
    end
end

-- /h3z0ui round: what happens on ChatFrame1
function WS.Debug()
    local s = DB()
    local cf = _G.ChatFrame1
    if not (s and cf) then return "no settings / ChatFrame1" end
    local ok, err = pcall(SkinChat, cf, s)
    local p = cf.h3zWSPanel
    return string.format("chat skin ok=%s err=%s panel=%s shown=%s visible=%s level=%s/%s alpha=%s size=%dx%d",
        tostring(ok), tostring(err or WS.lastError), tostring(p ~= nil), tostring(p and p:IsShown()),
        tostring(p and p:IsVisible()), tostring(p and p:GetFrameLevel()), tostring(cf:GetFrameLevel()),
        tostring(p and p:GetEffectiveAlpha()), p and p:GetWidth() or 0, p and p:GetHeight() or 0)
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
    StylePanel(panel, s, s.meterAlpha)

    -- header strip + accent line (rounded top corners follow the panel)
    local px = ns.Round.PixelSize(panel)
    local hh = 24
    panel.header:ClearAllPoints()
    panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    panel.header:SetHeight(hh)
    panel.header:SetVertexColor(1, 1, 1, 0.045)
    -- inset by the corner so the faint strip stays inside the rounded top corners
    local rr = Radius()
    panel.header:ClearAllPoints()
    panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", rr * 0.35, -1)
    panel.header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -rr * 0.35, -1)
    panel.header:SetHeight(hh - 1)
    local r, g, b = Accent()
    panel.line:ClearAllPoints()
    panel.line:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -hh)
    panel.line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -hh)
    panel.line:SetHeight(px)
    panel.line:SetVertexColor(r, g, b, 0.9)
    panel.header:SetShown(s.header)
    panel.line:SetShown(false)       -- no accent line under the header
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

-- opacity only: what the opacity sliders call while you drag them (no re-skinning)
function WS.UpdateAlpha()
    local s = DB()
    if not s then return end
    local fill = ns.Round and ns.Round.SLATE_FILL
    if not fill then return end
    for _, cf in ipairs(ChatFrames()) do
        local p = cf.h3zWSPanel
        if p and p.SetFillColor then p:SetFillColor(fill[1], fill[2], fill[3], s.chatAlpha or 0.9) end
    end
    for i = 1, MAX_METERS do
        local win = _G["DamageMeterSessionWindow" .. i]
        local p = win and win.h3zWSPanel
        if p and p.SetFillColor then p:SetFillColor(fill[1], fill[2], fill[3], s.meterAlpha or 0.9) end
    end
end
_G.H3z0UI_WindowSkinsAlpha = WS.UpdateAlpha

function WS.ApplyAll()
    WS.ApplyChat()
    WS.ApplyDamageMeter()
    if _G.H3z0UI_ApplyModernButtons then pcall(_G.H3z0UI_ApplyModernButtons) end
end
_G.H3z0UI_RefreshWindowSkins = WS.ApplyAll
_G.H3z0UI_DebugWindowSkins = function() return WS.Debug() end

---------------------------------------------------------------------------
-- Events / hooks
---------------------------------------------------------------------------
local hooked = false
local HookChatActivity      -- defined below (forward declaration: Hook uses it)
local function Hook()
    if hooked then return end
    hooked = true
    local function later() C_Timer.After(0.05, function() WS.ApplyChat(); HookChatActivity() end) end
    for _, fn in ipairs({ "FCF_Tab_OnClick", "FCF_DockUpdate", "FCF_OpenTemporaryWindow", "FCF_OpenNewWindow",
        "FCF_SelectDockFrame", "FCF_UnDockFrame", "FCF_DockFrame" }) do
        if type(_G[fn]) == "function" then hooksecurefunc(fn, later) end
    end
    if type(_G.H3z0UI_RefreshChat) == "function" then
        hooksecurefunc(_G, "H3z0UI_RefreshChat", later)
    end
end

---------------------------------------------------------------------------
-- Hide Chat When Idle: the whole chat window fades out when nothing happens and
-- comes back on a new message, mouseover or when you press Enter
---------------------------------------------------------------------------
local lastActivity = GetTime()
local idleAlpha = 1
local hookedAdd = {}

local function ChatPieces(cf)
    local name = cf:GetName() or ""
    return { cf, cf.h3zWSPanel, _G[name .. "Tab"], _G[name .. "ButtonFrame"], cf.buttonFrame }
end

local busyList = {}
local busyAt = 0
local function AnyChatBusy()
    -- the chat window list is refreshed every 2 seconds instead of built 10 times a second
    local now = GetTime()
    if now - busyAt > 2 then busyAt = now; busyList = ChatFrames() end
    for _, cf in ipairs(busyList) do
        if cf:IsShown() then
            local eb = _G[(cf:GetName() or "") .. "EditBox"]
            if eb and eb.HasFocus and eb:HasFocus() then return true end
            if cf:IsMouseOver(30, -8, -8, 8) then return true end
            local p = cf.h3zWSPanel
            if p and p:IsShown() and p:IsMouseOver() then return true end
        end
    end
    if _G.GeneralDockManager and _G.GeneralDockManager:IsMouseOver() then return true end
    return false
end

local function SetChatAlpha(a)
    for _, cf in ipairs(ChatFrames()) do
        for _, f in ipairs(ChatPieces(cf)) do
            if f and f.SetAlpha then f:SetAlpha(a) end
        end
    end
    if _G.GeneralDockManager then _G.GeneralDockManager:SetAlpha(a) end
    if _G.ChatFrameMenuButton then _G.ChatFrameMenuButton:SetAlpha(a) end
    if _G.ChatFrameChannelButton then _G.ChatFrameChannelButton:SetAlpha(a) end
    if _G.QuickJoinToastButton then _G.QuickJoinToastButton:SetAlpha(a) end
    if _G.H3z0UI_ChatSideBar then _G.H3z0UI_ChatSideBar:SetAlpha(a) end
end

HookChatActivity = function()
    for _, cf in ipairs(ChatFrames()) do
        if not hookedAdd[cf] and cf.AddMessage then
            hookedAdd[cf] = true
            hooksecurefunc(cf, "AddMessage", function() lastActivity = GetTime() end)
        end
    end
end

local idleTicker = CreateFrame("Frame")
idleTicker.t = 0
idleTicker:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    if self.t < 0.1 then return end
    local dt = self.t
    self.t = 0
    local s = DB()
    local on = s and s.chatIdleFade
    if not on then
        if idleAlpha ~= 1 then idleAlpha = 1; SetChatAlpha(1) end
        return
    end
    if AnyChatBusy() then lastActivity = GetTime() end
    local hidden = (GetTime() - lastActivity) > (s.chatIdleDelay or 10)
    local target = hidden and (s.chatIdleAlpha or 0) or 1
    if idleAlpha ~= target then
        -- fade out slowly, come back fast
        local speed = hidden and 1.5 or 6
        if idleAlpha < target then idleAlpha = math.min(target, idleAlpha + dt * speed)
        else idleAlpha = math.max(target, idleAlpha - dt * speed) end
        SetChatAlpha(idleAlpha)
    end
end)

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
        HookChatActivity()
        lastActivity = GetTime()
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
