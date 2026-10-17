--[[
    H3z0 UI - Modern Look

    A purely visual layer on top of the unit frames, the minimap and the info
    bar under it:
      - soft drop shadow around each frame (4 stacked layers, no texture files)
      - a subtle vertical sheen + a 1px top highlight on health / power bars
      - a soft class / reaction colored glow behind the round portraits
      - an accent line on top of the info bar

    Nothing in the frames' own settings is changed; turning it off hides the
    extras. Only H3z0 UI's own frames are touched.
]]

local ADDON_NAME, ns = ...

local ML = {}
ns.ModernLook = ML

local UNIT_KEYS = { "player", "target", "focus", "pet", "targettarget", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5" }
local SHADOW_ALPHA = { 0.30, 0.20, 0.11, 0.05 }

local function DB()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.modernLook = p.modernLook or {}
    local s = p.modernLook
    if s.enabled == nil then s.enabled = true end
    if s.shadow == nil then s.shadow = true end
    if s.sheen == nil then s.sheen = true end
    if s.glow == nil then s.glow = true end
    return s
end
ML.GetSettings = DB

local function Accent()
    local C = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    local a = C and C.accent
    if a then return a[1], a[2], a[3] end
    return 0.19, 0.82, 1.0
end

-- vertical gradient that works on new (ColorMixin) and old clients
local function Gradient(tex, bottom, top)
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    if CreateColor and pcall(tex.SetGradient, tex, "VERTICAL",
        CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]),
        CreateColor(top[1], top[2], top[3], top[4])) then
        return
    end
    if tex.SetGradientAlpha then
        pcall(tex.SetGradientAlpha, tex, "VERTICAL",
            bottom[1], bottom[2], bottom[3], bottom[4], top[1], top[2], top[3], top[4])
    else
        tex:SetColorTexture(1, 1, 1, 0.06)
    end
end

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
-- Soft drop shadow behind `target` (a frame), drawn on its own frame below it
local function Shadow(owner, target, show)
    local sh = owner.h3zMLShadow
    if not show then
        if sh then sh:Hide() end
        return
    end
    if not sh then
        sh = CreateFrame("Frame", nil, owner)
        sh:EnableMouse(false)
        sh.layers = {}
        for i = 1, #SHADOW_ALPHA do
            local t = sh:CreateTexture(nil, "BACKGROUND", nil, -8 + i)
            t:SetColorTexture(0, 0, 0, SHADOW_ALPHA[i])
            sh.layers[i] = t
        end
        owner.h3zMLShadow = sh
    end
    sh:SetFrameStrata(target:GetFrameStrata())
    sh:SetFrameLevel(math.max(0, target:GetFrameLevel() - 1))
    sh:ClearAllPoints()
    sh:SetAllPoints(target)
    for i, t in ipairs(sh.layers) do
        t:ClearAllPoints()
        -- a little more below than above, like light from the top
        t:SetPoint("TOPLEFT", sh, "TOPLEFT", -i, i - 1)
        t:SetPoint("BOTTOMRIGHT", sh, "BOTTOMRIGHT", i, -i - 1)
    end
    sh:Show()
end

-- Sheen + top highlight over a status bar
local function Sheen(bar, show)
    if not bar then return end
    if not show then
        if bar.h3zMLSheen then bar.h3zMLSheen:Hide() end
        if bar.h3zMLTop then bar.h3zMLTop:Hide() end
        return
    end
    if not bar.h3zMLSheen then
        bar.h3zMLSheen = bar:CreateTexture(nil, "OVERLAY", nil, -8)
        Gradient(bar.h3zMLSheen, { 0, 0, 0, 0.28 }, { 1, 1, 1, 0.10 })
        bar.h3zMLTop = bar:CreateTexture(nil, "OVERLAY", nil, -7)
        bar.h3zMLTop:SetColorTexture(1, 1, 1, 0.14)
    end
    bar.h3zMLSheen:ClearAllPoints()
    bar.h3zMLSheen:SetAllPoints(bar)
    bar.h3zMLSheen:Show()
    local px = 1
    local core = ns.Addon
    if core and core.GetPixelSize then
        local ok, v = pcall(core.GetPixelSize, core, bar)
        if ok and v then px = v end
    end
    bar.h3zMLTop:ClearAllPoints()
    bar.h3zMLTop:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.h3zMLTop:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    bar.h3zMLTop:SetHeight(px)
    bar.h3zMLTop:Show()
end

-- Soft glow behind Frame Style's round portrait, in the ring's color
local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local function PortraitGlow(frame, show)
    local r = frame.h3zRound
    local g = frame.h3zMLGlow
    if not (show and r and r:IsShown()) then
        if g then g:Hide() end
        return
    end
    if not g then
        g = CreateFrame("Frame", nil, frame)
        g:EnableMouse(false)
        g.layers = {}
        for i, a in ipairs({ 0.22, 0.12, 0.06 }) do
            local t = g:CreateTexture(nil, "BACKGROUND", nil, -8 + i)
            local m = g:CreateMaskTexture()
            m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            t:SetTexture("Interface\\Buttons\\WHITE8x8")
            t:AddMaskTexture(m)
            t.mask, t.alpha, t.grow = m, a, i * 3
            g.layers[i] = t
        end
        frame.h3zMLGlow = g
    end
    g:SetFrameLevel(math.max(0, r:GetFrameLevel() - 1))
    g:ClearAllPoints()
    g:SetAllPoints(r)
    local cr, cg, cb = 1, 1, 1
    if r.ring and r.ring.GetVertexColor then cr, cg, cb = r.ring:GetVertexColor() end
    for _, t in ipairs(g.layers) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", r, "TOPLEFT", -t.grow, t.grow)
        t:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", t.grow, -t.grow)
        t.mask:ClearAllPoints()
        t.mask:SetAllPoints(t)
        t:SetVertexColor(cr, cg, cb, t.alpha)
    end
    g:Show()
end

---------------------------------------------------------------------------
-- Apply
---------------------------------------------------------------------------
local function UF() return ns.H3z0UI_UnitFrames end

function ML.ApplyUnit(key)
    local uf = UF()
    local frame = uf and uf.frames and uf.frames[key]
    local s = DB()
    if not (frame and s) then return end
    local on = s.enabled
    Shadow(frame, frame, on and s.shadow)
    Sheen(frame.healthBar, on and s.sheen)
    Sheen(frame.powerBar, on and s.sheen)
    PortraitGlow(frame, on and s.glow)
end

local function ApplyMinimap(s)
    local on = s.enabled and s.shadow
    local mm = _G.Minimap
    if not mm then return end
    -- square minimap only (a square shadow around a round map looks wrong)
    local core = ns.Addon
    local ms = core and core.db and core.db.profile and core.db.profile.minimap
    local square = not ms or ms.shape == nil or ms.shape == "SQUARE"
    local holder = ML.mmHolder
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:EnableMouse(false)
        ML.mmHolder = holder
    end
    local b = (ms and ms.borderSize) or 2
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", mm, "TOPLEFT", -b, b)
    holder:SetPoint("BOTTOMRIGHT", mm, "BOTTOMRIGHT", b, -b)
    holder:SetFrameStrata("BACKGROUND")
    holder:SetFrameLevel(1)
    Shadow(holder, holder, on and square)

    local dt = _G.H3z0UI_DatatextPanel
    if dt then
        Shadow(dt, dt, on)
        if not dt.h3zMLSheen then
            dt.h3zMLSheen = dt:CreateTexture(nil, "BORDER", nil, 7)
            Gradient(dt.h3zMLSheen, { 0, 0, 0, 0.25 }, { 1, 1, 1, 0.05 })
            dt.h3zMLLine = dt:CreateTexture(nil, "OVERLAY", nil, -8)
        end
        dt.h3zMLSheen:SetAllPoints(dt)
        local ar, ag, ab = Accent()
        dt.h3zMLLine:SetColorTexture(ar, ag, ab, 0.85)
        dt.h3zMLLine:ClearAllPoints()
        dt.h3zMLLine:SetPoint("TOPLEFT", dt, "TOPLEFT", 0, 0)
        dt.h3zMLLine:SetPoint("TOPRIGHT", dt, "TOPRIGHT", 0, 0)
        dt.h3zMLLine:SetHeight(1)
        local show = s.enabled and s.sheen
        dt.h3zMLSheen:SetShown(show)
        dt.h3zMLLine:SetShown(show)
    end
end

local function ApplyBars(s)
    local on = s.enabled
    -- power bars (the standalone primary / secondary resource bars)
    for _, name in ipairs({ ADDON_NAME .. "PowerBar", ADDON_NAME .. "SecondaryPowerBar" }) do
        local bar = _G[name]
        if bar then
            Shadow(bar, bar, on and s.shadow)
            Sheen(bar.StatusBar, on and s.sheen)
        end
    end
    -- cast bars
    local cbs = _G.H3z0UI_Castbars
    if type(cbs) == "table" then
        for _, cb in pairs(cbs) do
            if type(cb) == "table" and cb.GetObjectType then
                Shadow(cb, cb, on and s.shadow)
                Sheen(cb.statusBar, on and s.sheen)
            end
        end
    end
end

function ML.ApplyAll()
    local s = DB()
    if not s then return end
    for _, key in ipairs(UNIT_KEYS) do pcall(ML.ApplyUnit, key) end
    pcall(ApplyMinimap, s)
    pcall(ApplyBars, s)
end

function ML.SetEnabled(on)
    local s = DB()
    if not s then return end
    s.enabled = on and true or false
    ML.ApplyAll()
end

_G.H3z0UI_RefreshModernLook = ML.ApplyAll
_G.H3z0UI_ToggleModernLook = function()
    local st = DB()
    if not st then return nil end
    ML.SetEnabled(not st.enabled)
    return st.enabled
end

---------------------------------------------------------------------------
-- Keep it applied when frames refresh / portraits change
---------------------------------------------------------------------------
local hooked = false
local function Hook()
    if hooked then return end
    local uf = UF()
    if not uf then return end
    hooked = true
    if uf.RefreshFrame then
        hooksecurefunc(uf, "RefreshFrame", function(_, key) C_Timer.After(0, function() pcall(ML.ApplyUnit, key) end) end)
    end
    if uf.RefreshAll then
        hooksecurefunc(uf, "RefreshAll", function() C_Timer.After(0, ML.ApplyAll) end)
    end
    local FS = ns.FrameStyle
    if FS then
        if FS.UpdatePortrait then
            hooksecurefunc(FS, "UpdatePortrait", function(key) pcall(ML.ApplyUnit, key) end)
        end
        if FS.ApplyUnit then
            hooksecurefunc(FS, "ApplyUnit", function(key) pcall(ML.ApplyUnit, key) end)
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    C_Timer.After(2, function()
        Hook()
        ML.ApplyAll()
    end)
end)
