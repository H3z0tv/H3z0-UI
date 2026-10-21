local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Blizzard frames in H3z0 UI Edit Mode (Layout Mode)
-- Action bars, the Cooldown Manager viewers, the chat window and the damage
-- meter windows get a handle in
-- Layout Mode. Their positions (and the chat / meter sizes) are kept by
-- H3z0 UI per PC / Deck layout (core/h3z/blizzpositions.lua) and put back
-- after login and whenever Blizzard's Edit Mode re-applies its layout.
---------------------------------------------------------------------------

local BL = {}
ns.H3z0BlizzLayout = BL

local GROUP_BARS = "Action Bars"
local GROUP_WINDOWS = "Chat & Damage Meter"
local GROUP_CDM = "Cooldown Manager"

local CDM_LABELS = {
    EssentialCooldownViewer = { "Essential Cooldowns", 1 },
    UtilityCooldownViewer = { "Utility Cooldowns", 2 },
    BuffIconCooldownViewer = { "Buff Icons", 3 },
    BuffBarCooldownViewer = { "Buff Bars", 4 },
}

local function BP() return ns.BlizzPositions end

local function Round(v)
    v = tonumber(v) or 0
    if v >= 0 then return math.floor(v + 0.5) end
    return math.ceil(v - 0.5)
end

-- fraction of the frame where an anchor point sits (0 = left / bottom, 1 = right / top)
local FX = { LEFT = 0, TOPLEFT = 0, BOTTOMLEFT = 0, CENTER = 0.5, TOP = 0.5, BOTTOM = 0.5, RIGHT = 1, TOPRIGHT = 1, BOTTOMRIGHT = 1 }
local FY = { BOTTOM = 0, BOTTOMLEFT = 0, BOTTOMRIGHT = 0, CENTER = 0.5, LEFT = 0.5, RIGHT = 0.5, TOP = 1, TOPLEFT = 1, TOPRIGHT = 1 }

-- centre offset from the screen centre (UIParent units) of a frame
local function CenterOffset(f)
    if not (f and f.GetCenter) then return nil end
    local cx, cy = f:GetCenter()
    if not (cx and cy) then return nil end
    local k = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local ux, uy = UIParent:GetCenter()
    return cx * k - ux, cy * k - uy
end

-- Layout Mode hands back point / relPoint / x / y (relative to UIParent):
-- turn it into the frame's centre offset from the screen centre
local function ToCenter(f, point, relPoint, x, y)
    point = point or "CENTER"
    relPoint = relPoint or point
    local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
    local k = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local w, h = (f:GetWidth() or 0) * k, (f:GetHeight() or 0) * k
    local ax = (FX[relPoint] or 0.5) * uw + (x or 0)
    local ay = (FY[relPoint] or 0.5) * uh + (y or 0)
    local cx = ax + (0.5 - (FX[point] or 0.5)) * w
    local cy = ay + (0.5 - (FY[point] or 0.5)) * h
    return cx - uw / 2, cy - uh / 2
end

local function SystemName(f)
    if f.GetSystemName then
        local ok, n = pcall(f.GetSystemName, f)
        if ok and type(n) == "string" and n ~= "" then return n end
    end
    return f:GetName() or "Frame"
end

-- put a frame's centre at x / y (UIParent units from the screen centre).
-- SetPoint offsets are in the frame's own scale, so they are converted.
local function PlaceCenter(f, x, y)
    if not (f and x and y) then return end
    if InCombatLockdown() and f.IsProtected and f:IsProtected() then return end
    local fs, us = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not (fs and us and fs > 0) then return end
    local k = us / fs
    pcall(function()
        local clear = f.ClearAllPointsBase or f.ClearAllPoints
        local set = f.SetPointBase or f.SetPoint
        clear(f)
        set(f, "CENTER", UIParent, "CENTER", x * k, y * k)
    end)
    -- Blizzard may line the bars up again right after: put saved ones back
    local BP = ns.BlizzPositions
    if BP and BP.QueueApply then BP.QueueApply() end
end

-- Layout Mode puts a frame back on close with offsets that ignore the frame's
-- own scale (an action bar at 80% lands somewhere else). Each element keeps
-- where it was when Layout Mode opened and where it was saved, and puts the
-- frame there again right after Layout Mode has let go of it.
local function TrackPlace(f, opts, onSaved)
    local userOpen, userClose = opts.onOpen, opts.onClose
    opts.onOpen = function()
        local x, y = CenterOffset(f)
        f._h3zOpenPos = x and { x, y } or nil
        f._h3zSavedPos = nil
        if userOpen then userOpen() end
    end
    opts.onClose = function()
        if userClose then userClose() end
        local pos = f._h3zSavedPos or f._h3zOpenPos
        local size = f._h3zSize
        f._h3zSavedPos, f._h3zOpenPos, f._h3zSize = nil, nil, nil
        if size and not (InCombatLockdown() and f:IsProtected()) then pcall(f.SetSize, f, size[1], size[2]) end
        if pos then PlaceCenter(f, pos[1], pos[2]) end
        if f == _G.ChatFrame1 and FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, f) end
        if _G.H3z0UI_RefreshWindowSkins then pcall(_G.H3z0UI_RefreshWindowSkins) end
        if onSaved then onSaved() end
    end
    return opts
end

---------------------------------------------------------------------------
-- resize grip (chat / damage meter)
---------------------------------------------------------------------------
-- Layout Mode shows a mover ("handle") over these frames and ties the frame to
-- it while Layout Mode is open. The grip sits on that handle and resizes it;
-- the frame follows, and on release its new size is kept (PC / Deck).
local function Lm() return ns.H3z0UI_LayoutMode end

local function Tie(f, handle)
    local clear = f.ClearAllPointsBase or f.ClearAllPoints
    local set = f.SetPointBase or f.SetPoint
    pcall(clear, f)
    pcall(set, f, "TOPLEFT", handle, "TOPLEFT", 0, 0)
    pcall(set, f, "BOTTOMRIGHT", handle, "BOTTOMRIGHT", 0, 0)
end

local function AttachGrip(key, f)
    local lm = Lm()
    local handle = lm and lm._handles and lm._handles[key]
    if not handle then return end
    local grip = handle._h3zGrip
    if not grip then
        grip = CreateFrame("Button", nil, handle)
        grip:SetSize(20, 20)
        grip:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", -1, 1)
        local t = grip:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        grip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:SetText("Drag to resize")
            GameTooltip:Show()
        end)
        grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        handle._h3zGrip = grip
    end
    grip:SetFrameStrata(handle:GetFrameStrata())
    grip:SetFrameLevel(handle:GetFrameLevel() + 50)
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or InCombatLockdown() then return end
        handle:SetResizable(true)
        if handle.SetResizeBounds then
            pcall(handle.SetResizeBounds, handle, 120, 60, 2000, 1400)
        elseif handle.SetMinResize then
            pcall(handle.SetMinResize, handle, 120, 60)
        end
        handle._h3zSizing = true
        handle:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not handle._h3zSizing then return end
        handle._h3zSizing = nil
        handle:StopMovingOrSizing()
        -- the frame's own size (its units) and its new place (UIParent units)
        local hs = handle:GetEffectiveScale() or 1
        local fs = f:GetEffectiveScale() or 1
        local us = UIParent:GetEffectiveScale() or 1
        local w = (handle:GetWidth() or 0) * hs / fs
        local h = (handle:GetHeight() or 0) * hs / fs
        local left, top = handle:GetLeft(), handle:GetTop()
        if not (left and top and w > 0 and h > 0) then return end
        left, top = left * hs / us, top * hs / us
        local b = BP()
        if b and b.SaveSize then b.SaveSize(f, w, h, left, top) end
        -- keep the frame on the handle while Layout Mode is open
        Tie(f, handle)
        local cx, cy = CenterOffset(handle)
        if cx then f._h3zSavedPos = { cx, cy } end
        f._h3zSize = { w, h }
        if lm.RecordFreeElementPosition then pcall(lm.RecordFreeElementPosition, lm, key, handle) end
        if _G.H3z0UI_RefreshWindowSkins then pcall(_G.H3z0UI_RefreshWindowSkins) end
    end)
    grip:Show()
end

---------------------------------------------------------------------------
-- element for one Edit Mode system frame
---------------------------------------------------------------------------
local registered = {}

local function WithGrip(key, f, opts)
    local userOpen = opts.onOpen
    opts.onOpen = function()
        if userOpen then userOpen() end
        -- the handle is made right after this: put the grip on it then
        C_Timer.After(0, function() pcall(AttachGrip, key, f) end)
        C_Timer.After(0.3, function() pcall(AttachGrip, key, f) end)
    end
    return opts
end

local function Register(lm, key, f, label, group, order, resizable, opts)
    opts = opts or {}
    if resizable then opts = WithGrip(key, f, opts) end
    opts = TrackPlace(f, opts)
    if registered[key] then return end
    registered[key] = true
    lm:RegisterElement({
        key = key,
        label = label,
        group = group,
        order = order,
        isOwned = false,
        usesCustomPositionPersistence = true,
        getFrame = function() return f end,
        isEnabled = opts.isEnabled or function() return f:IsShown() or f == _G.ChatFrame1 or (f.system ~= nil and Enum and Enum.EditModeSystem and f.system == Enum.EditModeSystem.CooldownViewer) end,
        onOpen = opts.onOpen,
        onClose = opts.onClose,
        loadPosition = function()
            local x, y = CenterOffset(f)
            if not x then return nil end
            return "CENTER", "CENTER", Round(x), Round(y)
        end,
        savePosition = function(_, point, relPoint, x, y)
            if InCombatLockdown() then return end
            local b = BP()
            if not (b and b.Save) then return end
            local cx, cy = ToCenter(f, point, relPoint, x, y)
            f._h3zSavedPos = { cx, cy }
            b.Save(f, cx, cy)
            if f == _G.ChatFrame1 and FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, f) end
            if _G.H3z0UI_RefreshWindowSkins then pcall(_G.H3z0UI_RefreshWindowSkins) end
            if group == GROUP_CDM then
                -- bars locked to the Essential / Utility viewer follow it
                if _G.H3z0UI_ApplyUtilityAnchor then pcall(_G.H3z0UI_ApplyUtilityAnchor) end
                local core = ns.Addon
                if core and core.UpdatePowerBar then pcall(core.UpdatePowerBar, core) end
                if core and core.UpdateSecondaryPowerBar then pcall(core.UpdateSecondaryPowerBar, core) end
            end
        end,

    })
end

local BAR_LABELS = {
    MainActionBar = "Action Bar 1", MainMenuBar = "Action Bar 1",
    MultiBarBottomLeft = "Action Bar 2", MultiBarBottomRight = "Action Bar 3",
    MultiBarRight = "Action Bar 4", MultiBarLeft = "Action Bar 5",
    MultiBar5 = "Action Bar 6", MultiBar6 = "Action Bar 7", MultiBar7 = "Action Bar 8",
    StanceBar = "Stance Bar", PetActionBar = "Pet Bar", PossessActionBar = "Possess Bar",
}

local RegisterMeterWindows

function BL.RegisterAll()
    local lm = ns.H3z0UI_LayoutMode
    local b = BP()
    if not (lm and lm.RegisterElement and b and b.SystemFrames) then return end
    pcall(RegisterMeterWindows, lm)
    local S = Enum and Enum.EditModeSystem or {}
    local frames = b.SystemFrames()
    local order = 0
    for key, f in pairs(frames) do
        order = order + 1
        local name = f:GetName() or ""
        if f.system == S.ActionBar then
            Register(lm, "h3zBar_" .. key, f, BAR_LABELS[name] or SystemName(f), GROUP_BARS, 1 + (f.systemIndex or order), false)
        elseif f.system == S.ChatFrame then
            if f == _G.ChatFrame1 then
                -- the chat handle of the core Layout Mode would move the frame a second way
                if lm.UnregisterElement and lm._elements and lm._elements.chatFrame1 then
                    pcall(lm.UnregisterElement, lm, "chatFrame1")
                end
                Register(lm, "h3zChat", f, "Chat Window", GROUP_WINDOWS, 1, true)
            end
        elseif S.CooldownViewer and f.system == S.CooldownViewer then
            local info = CDM_LABELS[name]
            if info then
                Register(lm, "h3zCDM_" .. key, f, info[1], GROUP_CDM, info[2], false)
            end
        elseif f.system == S.DamageMeter then
            -- the meter is hidden out of combat (Blizzard's visibility setting): always list it
            -- and show it while Layout Mode is open
            Register(lm, "h3zMeter_" .. key, f, "Damage Meter" .. ((f.systemIndex or 1) > 1 and (" " .. f.systemIndex) or ""), GROUP_WINDOWS, 10 + (f.systemIndex or 1), true, {
                isEnabled = function() return true end,
                onOpen = function()
                    if InCombatLockdown() then return end
                    f._h3zLayoutShown = true
                    pcall(f.Show, f)
                end,
                onClose = function()
                    if not f._h3zLayoutShown then return end
                    f._h3zLayoutShown = nil
                    if f.UpdateShownState then pcall(f.UpdateShownState, f) end
                end,
            })
        end
    end
end

-- extra damage meter windows (2, 3, ...): not Edit Mode frames, Blizzard keeps their
-- place itself (user placed), so they are moved straight away
RegisterMeterWindows = function(lm)
    for i = 2, 10 do
        local win = _G["DamageMeterSessionWindow" .. i]
        local key = "h3zMeterWin" .. i
        if win and not registered[key] then
            registered[key] = true
            local wopts = TrackPlace(win, WithGrip(key, win, {}), function()
                if win.SetUserPlaced and win:IsMovable() then pcall(win.SetUserPlaced, win, true) end
            end)
            lm:RegisterElement({
                onOpen = wopts.onOpen,
                onClose = wopts.onClose,
                key = key,
                label = "Damage Meter " .. i,
                group = GROUP_WINDOWS,
                order = 20 + i,
                isOwned = false,
                usesCustomPositionPersistence = true,
                getFrame = function() return win end,
                isEnabled = function() return win:IsShown() end,
                loadPosition = function()
                    local x, y = CenterOffset(win)
                    if not x then return nil end
                    return "CENTER", "CENTER", Round(x), Round(y)
                end,
                savePosition = function(_, point, relPoint, x, y)
                    if InCombatLockdown() then return end
                    local cx, cy = ToCenter(win, point, relPoint, x, y)
                    win._h3zSavedPos = { cx, cy }
                    local k = (UIParent:GetEffectiveScale() or 1) / (win:GetEffectiveScale() or 1)
                    pcall(function()
                        win:ClearAllPoints()
                        win:SetPoint("CENTER", UIParent, "CENTER", cx * k, cy * k)
                        if win.SetUserPlaced and win:IsMovable() then win:SetUserPlaced(true) end
                    end)
                    if _G.H3z0UI_RefreshWindowSkins then pcall(_G.H3z0UI_RefreshWindowSkins) end
                end,
            })
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= "Blizzard_DamageMeter" then return end
    C_Timer.After(event == "PLAYER_LOGIN" and 2 or 0.5, function()
        local ok, err = pcall(BL.RegisterAll)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end)
end)

-- Layout Mode open: catch frames that appeared since login (a new meter window, ...)
C_Timer.After(3, function()
    local lm = ns.H3z0UI_LayoutMode
    if lm and lm.RegisterEnterCallback then
        lm:RegisterEnterCallback(function() pcall(BL.RegisterAll) end)
    end
end)
