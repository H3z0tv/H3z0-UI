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
    if s.castbars == nil then s.castbars = true end
    if s.buttons == nil then s.buttons = true end
    -- 0.24.0: rounded map / buttons / cast bars back on once (an older look choice could have turned them off)
    if not s.roundFix1 then
        s.roundFix1 = true
        s.rounded, s.buttons, s.castbars = true, true, true
    end
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

-- Frame Style v2: curved "(" and ")" brackets around both ends of a unit frame bar,
-- drawn with short line segments (smooth at any size, no texture files)
local BRACKET_SEGMENTS = 14
local UNIT_OF = { player = "player", target = "target", focus = "focus", pet = "pet",
    targettarget = "targettarget", focustarget = "focustarget",
    boss1 = "boss1", boss2 = "boss2", boss3 = "boss3", boss4 = "boss4", boss5 = "boss5" }

local function IsSecret(v) return issecretvalue and v ~= nil and issecretvalue(v) or false end

local function UnitColor(unit)
    if unit and UnitExists(unit) then
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if okP and not IsSecret(isPlayer) then
            if isPlayer then
                local _, class = UnitClass(unit)
                local c = class and not IsSecret(class) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
                if c then return c.r, c.g, c.b end
            else
                local okR, reaction = pcall(UnitReaction, unit, "player")
                local c = okR and reaction and not IsSecret(reaction) and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
                if c then return c.r, c.g, c.b end
            end
        end
    end
    return Accent()
end

-- Frame Style v2: the bar's outer end is fully round (pill end) and the black
-- border follows the curve. Done with a half-circle mask (assets/h3z_roundend_*)
-- clamped to the left / right, so everything else of the bar stays square (and is
-- hidden under the portrait on the portrait side).
local ROUND_R = "Interface\\AddOns\\" .. ADDON_NAME .. "\\assets\\h3z_roundend_r"
local ROUND_L = "Interface\\AddOns\\" .. ADDON_NAME .. "\\assets\\h3z_roundend_l"
local BACKDROP_PIECES = { "Center", "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }

local function MaskFor(owner, frame, side, inset, field)
    local m = owner[field]
    if not m then
        m = owner:CreateMaskTexture()
        owner[field] = m
    end
    local tex = (side == "RIGHT") and ROUND_R or ROUND_L
    m:SetTexture(tex, "CLAMP", "CLAMP")
    local h = math.max(2, (frame:GetHeight() or 20) - inset * 2)
    m:ClearAllPoints()
    if side == "RIGHT" then
        m:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
        m:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    else
        m:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        m:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
    end
    m:SetWidth(h / 2)
    return m
end

local function CollectBarTextures(bar, list)
    if not bar then return end
    for _, r in ipairs({ bar:GetRegions() }) do
        if r and r.IsObjectType and r:IsObjectType("Texture") then list[#list + 1] = r end
    end
    for _, c in ipairs({ bar:GetChildren() }) do
        if c and c.IsObjectType and c:IsObjectType("StatusBar") then CollectBarTextures(c, list) end
    end
end

local function SetMasked(tex, mask, on)
    tex.h3zV2Masks = tex.h3zV2Masks or {}
    if on then
        if tex.h3zV2Masks[mask] then return end
        if pcall(tex.AddMaskTexture, tex, mask) then tex.h3zV2Masks[mask] = true end
    else
        for m in pairs(tex.h3zV2Masks) do pcall(tex.RemoveMaskTexture, tex, m) end
        wipe(tex.h3zV2Masks)
    end
end

-- the soft shadow follows the round end too (else a faint square shows around it)
local function ShapeShadow(frame, side, on)
    local sh = frame.h3zMLShadow
    if not (sh and sh.layers) then return end
    for i, t in ipairs(sh.layers) do
        if on then
            local m = sh["h3zV2Mask" .. i]
            if not m then
                m = sh:CreateMaskTexture()
                sh["h3zV2Mask" .. i] = m
            end
            m:SetTexture((side == "RIGHT") and ROUND_R or ROUND_L, "CLAMP", "CLAMP")
            m:ClearAllPoints()
            if side == "RIGHT" then
                m:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, 0)
                m:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 0, 0)
            else
                m:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
                m:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
            end
            m:SetWidth(math.max(2, (frame:GetHeight() or 20) + i * 2) / 2)
            SetMasked(t, m, true)
        else
            SetMasked(t, nil, false)
        end
    end
end

local function Brackets(frame, key, show)
    if frame.h3zMLBrackets then frame.h3zMLBrackets:Hide() end   -- old line drawing
    local side = (key == "target") and "LEFT" or "RIGHT"          -- the end away from the portrait
    local done = frame.h3zV2Done or {}
    frame.h3zV2Done = done
    if not show then
        for tex in pairs(done) do SetMasked(tex, nil, false) end
        wipe(done)
        ShapeShadow(frame, side, false)
        return
    end
    ShapeShadow(frame, side, true)
    -- outer shape: the frame's own background + border pieces
    local outer = MaskFor(frame, frame, side, 0, "h3zV2Outer")
    for _, k in ipairs(BACKDROP_PIECES) do
        local t = frame[k]
        if t and t.AddMaskTexture then SetMasked(t, outer, true); done[t] = true end
    end
    -- inner shape (inside the border): health / power bars and their fills
    local hb = frame.healthBar
    local inset = 1
    if hb and hb:GetTop() and frame:GetTop() then
        inset = math.max(0, frame:GetTop() - hb:GetTop())
    end
    for _, bar in ipairs({ frame.healthBar, frame.powerBar }) do
        if bar then
            local list = {}
            CollectBarTextures(bar, list)
            for _, t in ipairs(list) do
                local owner = t:GetParent()
                if owner and owner.CreateMaskTexture then
                    local m = MaskFor(owner, frame, side, inset, "h3zV2Inner")
                    SetMasked(t, m, true)
                    done[t] = true
                end
            end
        end
    end
end

-- Rounded corners: four corner masks on the frame's background / border pieces
-- (outer shape) and on every bar texture inside it (inner shape, inset by the
-- border so the border curves with it). The shadow gets the same shape.
local function RoundShadow(frame, radius, on)
    local sh = frame.h3zMLShadow
    if not (sh and sh.layers) then return end
    local Round = ns.Round
    for i, t in ipairs(sh.layers) do
        if on then
            local set = Round.CornerMasks(sh, t, radius + i, 0, "h3zRoundMasks" .. i)
            Round.Mask(t, set, true)
        else
            Round.Mask(t, nil, false)
        end
    end
end

local function RoundFrame(frame, bars, show)
    local Round = ns.Round
    if not Round then return end
    local done = frame.h3zRoundDone or {}
    frame.h3zRoundDone = done
    if not show then
        for tex in pairs(done) do Round.Mask(tex, nil, false) end
        wipe(done)
        RoundShadow(frame, 0, false)
        return
    end
    local radius = Round.Radius()
    local fh = frame:GetHeight() or 20
    radius = math.min(radius, math.max(1, fh / 2))
    RoundShadow(frame, radius, true)
    local outer = Round.CornerMasks(frame, frame, radius, 0, "h3zRoundOuter")
    for _, k in ipairs(BACKDROP_PIECES) do
        local t = frame[k]
        if t and t.AddMaskTexture then Round.Mask(t, outer, true); done[t] = true end
    end
    for _, bar in ipairs(bars) do
        if bar then
            local inset = 0
            if bar:GetTop() and frame:GetTop() then
                inset = math.max(0, math.min(4, frame:GetTop() - bar:GetTop()))
            end
            local list = {}
            CollectBarTextures(bar, list)
            for _, t in ipairs(list) do
                local owner = t:GetParent()
                if owner and owner.CreateMaskTexture then
                    local m = Round.CornerMasks(owner, frame, radius, inset, "h3zRoundInner")
                    Round.Mask(t, m, true)
                    done[t] = true
                end
            end
        end
    end
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
    -- Frame Style "Round Portrait v2": curved brackets at both bar ends
    local FS = ns.FrameStyle
    local fs = FS and FS.GetSettings and FS.GetSettings()
    local v2 = fs and fs.enabled and fs.style == "roundv2" and frame.h3zStyled
        and (key == "player" or key == "target" or key == "focus")
    pcall(Brackets, frame, key, v2 and true or false)
    -- rounded corners (not on v2 frames: they have their own round end)
    local round = ns.Round and ns.Round.Enabled() and not v2
    pcall(RoundFrame, frame, { frame.healthBar, frame.powerBar }, round and true or false)
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
    local roundOn = ns.Round and ns.Round.Enabled() and square
    pcall(RoundShadow, holder, ((mm:GetWidth() or 200) + b * 2) * 34 / 256, (on and roundOn) and true or false)

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
        dt.h3zMLLine:SetShown(false)     -- no accent line on the info bar
        pcall(RoundFrame, dt, {}, roundOn and true or false)
        local set = dt.h3zRoundOuter
        if set then
            for _, t in ipairs({ dt.h3zMLSheen, dt.h3zMLLine, dt.bg, dt.borderLeft, dt.borderRight, dt.borderTop, dt.borderBottom }) do
                ns.Round.Mask(t, set, roundOn and true or false)
            end
        end
    end
    -- rounded square minimap (minimap.lua picks the mask)
    if _G.H3z0UI_RefreshMinimapShape then pcall(_G.H3z0UI_RefreshMinimapShape) end
end

-- Modern cast bar (same look as H3z0 Nameplates): rounded black outline around the
-- bar, the bar textures rounded inside it, the icon as its own rounded tile with a
-- small gap, and the shadow only behind the bar.
local function ModernCast(cb, on)
    local Round = ns.Round
    local sb = cb.statusBar
    if not (Round and sb) then return end
    local m = cb.h3zMC
    if not on then
        if m then
            m.panel:Hide()
            if m.iconPanel then m.iconPanel:Hide() end
            for t in pairs(m.done) do Round.Mask(t, nil, false) end
            wipe(m.done)
            if sb.Border then sb.Border:SetAlpha(1) end
            if cb.iconBorder then cb.iconBorder:SetAlpha(1) end
        end
        return
    end
    if not m then
        m = { done = {} }
        m.panel = Round.Panel(cb, 4)
        cb.h3zMC = m
    end
    local h = sb:GetHeight() or 16
    local r = Round.Enabled() and math.max(2, math.min(Round.Radius(), h / 2 + 1)) or 1
    m.panel:SetFrameStrata(cb:GetFrameStrata())
    m.panel:SetFrameLevel(math.max(0, sb:GetFrameLevel() - 1))
    m.panel:ClearAllPoints()
    m.panel:SetPoint("TOPLEFT", sb, "TOPLEFT", -1, 1)
    m.panel:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT", 1, -1)
    m.panel:SetRadius(r)
    m.panel:SetFillColor(0, 0, 0, 1)
    m.panel:SetBorderColor(0, 0, 0, 0)
    m.panel:Show()
    if sb.Border then sb.Border:SetAlpha(0) end
    local inner = Round.CornerMasks(sb, sb, math.max(1, r - 1), 0, "h3zMCInner")
    local list = {}
    CollectBarTextures(sb, list)
    for _, t in ipairs(list) do
        if t:GetParent() == sb then Round.Mask(t, inner, true); m.done[t] = true end
    end
    local icon, tex = cb.icon, cb.iconTexture
    if icon and tex then
        if not m.iconPanel then m.iconPanel = Round.Panel(icon, 4) end
        m.iconPanel:SetFrameLevel(math.max(0, icon:GetFrameLevel() - 1))
        m.iconPanel:ClearAllPoints()
        m.iconPanel:SetAllPoints(icon)
        m.iconPanel:SetRadius(r)
        m.iconPanel:SetFillColor(0, 0, 0, 1)
        m.iconPanel:SetBorderColor(0, 0, 0, 0)
        m.iconPanel:Show()
        if cb.iconBorder then cb.iconBorder:SetAlpha(0) end
        local im = Round.SquareMask(icon, tex, 0, "h3zMCIconSq")
        Round.Mask(tex, im, true)
        m.done[tex] = true
    end
    -- the icon needs a little gap to read as its own tile (once, only when it was 0)
    local H = ns.Helpers
    local us = H and H.GetUnitSettings and cb.unitKey and H.GetUnitSettings(cb.unitKey)
    local cs = us and us.castbar
    if cs and not cs.h3zModernGap then
        cs.h3zModernGap = true
        if (cs.iconSpacing or 0) < 3 then
            cs.iconSpacing = 3
            if cb.UpdateCastbarElements then pcall(cb.UpdateCastbarElements, cb) end
        end
    end
    return m.panel, r
end

local function ApplyBars(s)
    local on = s.enabled
    -- power bars (the standalone primary / secondary resource bars)
    for _, name in ipairs({ ADDON_NAME .. "PowerBar", ADDON_NAME .. "SecondaryPowerBar" }) do
        local bar = _G[name]
        if bar then
            Shadow(bar, bar, on and s.shadow)
            Sheen(bar.StatusBar, on and s.sheen)
            pcall(RoundFrame, bar, { bar.StatusBar }, on and ns.Round and ns.Round.Enabled() or false)
        end
    end
    -- cast bars
    local cbs = _G.H3z0UI_Castbars
    if type(cbs) == "table" then
        for _, cb in pairs(cbs) do
            if type(cb) == "table" and cb.GetObjectType then
                Sheen(cb.statusBar, on and s.sheen)
                local modern = s.castbars
                pcall(RoundFrame, cb, { cb.statusBar }, false)   -- older whole-frame rounding
                local ok, panel, r = pcall(ModernCast, cb, modern and true or false)
                if ok and panel then
                    Shadow(cb, panel, on and s.shadow)
                    pcall(RoundShadow, cb, (r or 4) + 1, ns.Round.Enabled())
                else
                    Shadow(cb, cb, on and s.shadow)
                    pcall(RoundShadow, cb, 0, false)
                end
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
    if _G.H3z0UI_ApplyModernButtons then pcall(_G.H3z0UI_ApplyModernButtons) end
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
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        pcall(ML.ApplyUnit, "target"); pcall(ML.ApplyUnit, "targettarget")
        return
    elseif event == "PLAYER_FOCUS_CHANGED" then
        pcall(ML.ApplyUnit, "focus")
        return
    end
    C_Timer.After(2, function()
        Hook()
        ML.ApplyAll()
    end)
end)
