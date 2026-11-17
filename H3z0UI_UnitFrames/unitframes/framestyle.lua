--[[
    H3z0UI Frame Style (test) - "Round Portrait" look for Player / Target / Focus

    Purely visual layer on top of the normal unit frames:
      - round portrait with a class (or reaction) colored ring beside the bar
      - name above the bar
      - optional slim bar height

    Nothing in your unit frame settings is changed. Turning the style off
    hides the extras and re-runs the normal unit frame refresh, so the frames
    go back to exactly what your settings say.
]]

local ADDON_NAME, ns = ...

local FS = {}
ns.FrameStyle = FS

local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local UNIT_KEYS = { "player", "target", "focus", "pet" }
local UNIT_OF = { player = "player", target = "target", focus = "focus", pet = "pet" }
local RIGHT_SIDE = { target = true }

local pendingApply = false
local HideV3, ApplyV3Extras   -- Modern v3 extras, defined below

---------------------------------------------------------------------------
-- Settings (profile.frameStyle) - defaults filled in at runtime
---------------------------------------------------------------------------
local function DB()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.frameStyle = p.frameStyle or {}
    local s = p.frameStyle
    if s.enabled == nil then s.enabled = false end
    if s.player == nil then s.player = true end
    if s.target == nil then s.target = true end
    if s.focus == nil then s.focus = false end
    -- the version in use (own settings per version: see Opts below)
    if s.style == nil then s.style = "round" end            -- "round" | "roundv2" | "roundv3" | "square"
    if s.height == nil then s.height = s.dockHeight or 37 end -- frame height, 0 = your own
    if s.pSize == nil then s.pSize = 0 end                   -- portrait size, 0 = fit the frame
    if s.ringThickness == nil then s.ringThickness = 1 end   -- ring / portrait border
    if s.classRing == nil then s.classRing = true end        -- class / reaction colored ring / border
    if s.nameAbove == nil then s.nameAbove = true end        -- name on top
    if s.dockPet == nil then s.dockPet = true end            -- pet bar under the player
    return s
end
FS.GetSettings = DB

-- Every version (Modern, Modern v2, Modern v3) keeps its own settings in profile.frameStyle.v[<version>].
-- "square" is the Modern version with the portrait docked inside the bar. A version used for the first time
-- starts from the values the older builds shared (Modern, Modern v2) or from its own defaults (Modern v3).
local COMMON_OPTS = { player = true, target = true, focus = false, height = 37, pSize = 0, ringThickness = 1,
    classRing = true, nameAbove = true, dockPet = true }
local V3_OPTS = { player = true, target = true, focus = false, height = 20, pSize = 0, ringThickness = 2,
    classRing = true, nameAbove = true, dockPet = true, textSize = 11,
    splitText = true, badge = true, dragon = true, drop = true,
    execute = true, executePct = 20, executeClass = true, castIcon = true }
local OPT_DEFAULTS = { round = COMMON_OPTS, roundv2 = COMMON_OPTS, roundv3 = V3_OPTS }

local function VersionKey(style)
    if style == "square" then return "round" end
    return OPT_DEFAULTS[style] and style or "round"
end

local function Opts(s)
    s = s or DB()
    if not s then return nil end
    local key = VersionKey(s.style)
    s.v = s.v or {}
    local o = s.v[key]
    if not o then
        o = {}
        s.v[key] = o
        if key ~= "roundv3" then
            for k in pairs(OPT_DEFAULTS[key]) do o[k] = s[k] end
        end
    end
    for k, d in pairs(OPT_DEFAULTS[key]) do
        if o[k] == nil then o[k] = d end
    end
    -- build 92 made Modern v3 frames 24 high; they are slimmer now (once, a height you set yourself stays)
    if key == "roundv3" and (o.rev or 0) < 3 then
        o.rev = 3
        if o.height == 24 or o.height == 18 then o.height = 20 end
    end
    return o
end
FS.Opts = function() return Opts() end

-- settings of the version in use, flat (what the apply functions read)
local function Cfg(s)
    s = s or DB()
    if not s then return nil end
    local c = { style = s.style, enabled = s.enabled }
    for k, v in pairs(Opts(s)) do c[k] = v end
    return c
end

local function UF() return ns.H3z0UI_UnitFrames end

local function GetFrame(unitKey)
    local uf = UF()
    return uf and uf.frames and uf.frames[unitKey]
end

local function IsSecret(v)
    return issecretvalue and v ~= nil and issecretvalue(v) or false
end

local function PixelRound(v, frame)
    local core = ns.Addon
    if core and core.PixelRound then
        local ok, r = pcall(core.PixelRound, core, v, frame)
        if ok and r then return r end
    end
    return math.floor(v + 0.5)
end

---------------------------------------------------------------------------
-- Ring color: class color for players, reaction color for NPCs
---------------------------------------------------------------------------
local function RingColor(unit, force)
    local s = Opts()
    if s and (s.classRing or force) and UnitExists(unit) then
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if okP and not IsSecret(isPlayer) then
            if isPlayer then
                local _, class = UnitClass(unit)
                if class and not IsSecret(class) then
                    local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
                    if c then return c.r, c.g, c.b end
                end
            else
                local okR, reaction = pcall(UnitReaction, unit, "player")
                if okR and reaction and not IsSecret(reaction) then
                    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
                    if c then return c.r, c.g, c.b end
                end
            end
        end
    end
    return 0.19, 0.82, 1.0 -- H3z0 blue
end

---------------------------------------------------------------------------
-- Round portrait widget (display only, mouse passes through)
---------------------------------------------------------------------------
local function NewMask(parent)
    local m = parent:CreateMaskTexture()
    m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    return m
end

local function GetRound(frame)
    if frame.h3zRound then return frame.h3zRound end
    local r = CreateFrame("Frame", nil, frame)
    r:EnableMouse(false)
    r:SetFrameLevel(frame:GetFrameLevel() + 6)

    local outerMask = NewMask(r)
    outerMask:SetAllPoints(r)
    local ring = r:CreateTexture(nil, "BACKGROUND")
    ring:SetAllPoints(r)
    ring:SetColorTexture(1, 1, 1, 1)
    ring:AddMaskTexture(outerMask)

    local innerMask = NewMask(r)
    local inner = r:CreateTexture(nil, "BORDER")
    inner:SetColorTexture(0.05, 0.05, 0.05, 1)
    inner:AddMaskTexture(innerMask)

    local tex = r:CreateTexture(nil, "ARTWORK")
    tex:AddMaskTexture(innerMask)

    r.ring, r.inner, r.tex, r.innerMask = ring, inner, tex, innerMask
    frame.h3zRound = r
    return r
end

local function GetSquare(frame)
    if frame.h3zSquare then return frame.h3zSquare end
    local q = CreateFrame("Frame", nil, frame)
    q:EnableMouse(false)
    q:SetFrameLevel(frame:GetFrameLevel() + 6)
    local edge = q:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints(q)
    edge:SetColorTexture(0, 0, 0, 1)
    local bg = q:CreateTexture(nil, "BORDER")
    bg:SetColorTexture(0.06, 0.06, 0.06, 1)
    local tex = q:CreateTexture(nil, "ARTWORK")
    q.edge, q.bg, q.tex = edge, bg, tex
    frame.h3zSquare = q
    return q
end

---------------------------------------------------------------------------
-- Modern v3 extras: elite / rare / boss badge on the portrait, execute line on the
-- health bar, the spell icon in the portrait while the unit casts
---------------------------------------------------------------------------
local BADGE_ATLAS = {
    worldboss = "nameplates-icon-elite-gold",
    elite = "nameplates-icon-elite-gold",
    rareelite = "nameplates-icon-elite-silver",
    rare = "nameplates-icon-elite-silver",
}
local WHITE = "Interface\\Buttons\\WHITE8x8"
-- Blizzard's target frame dragons: size and centre offset in portrait widths (a 58 pixel portrait)
local DRAGON_SMALL = { w = 80 / 58, h = 79 / 58, x = 4 / 58, y = 0.5 / 58 }
local DRAGON_WINGED = { w = 99 / 58, h = 81 / 58, x = 13.5 / 58, y = -0.5 / 58 }
local DRAGON = {
    worldboss = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", g = DRAGON_WINGED },
    elite = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold", g = DRAGON_SMALL },
    rareelite = { atlas = "ui-hud-unitframe-target-portraiton-boss-rare-silver", g = DRAGON_SMALL },
    rare = { atlas = "ui-hud-unitframe-target-portraiton-boss-rare-silver", g = DRAGON_SMALL },
}

local function V3Parts(frame)
    local x = frame.h3zV3
    if x then return x end
    local r, hb = frame.h3zRound, frame.healthBar
    if not (r and hb) then return nil end
    x = {}
    x.badge = r:CreateTexture(nil, "OVERLAY", nil, 7)
    x.badge:SetSize(16, 16)
    x.badge:Hide()
    -- Blizzard's dragon around the portrait of elite / rare / boss units (behind the ring)
    x.dragon = r:CreateTexture(nil, "BACKGROUND", nil, -8)
    x.dragon:Hide()
    -- "Drop" portrait: the corner toward the bar is square (ring, dark background, picture)
    x.dropRing = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    x.dropRing:SetColorTexture(1, 1, 1, 1)
    x.dropInner = r:CreateTexture(nil, "BORDER", nil, 1)
    x.dropInner:SetColorTexture(0.05, 0.05, 0.05, 1)
    x.dropTex = r:CreateTexture(nil, "ARTWORK", nil, 1)
    x.dropRing:Hide(); x.dropInner:Hide(); x.dropTex:Hide()
    x.cast = r:CreateTexture(nil, "OVERLAY", nil, 5)
    x.cast:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    x.cast:AddMaskTexture(r.innerMask)
    x.cast:Hide()
    -- the line is the edge of an invisible bar filled to the execute percent: it follows the
    -- health bar's size and never reads a health value
    -- percent on the portrait side of the bar, the value on the other side
    local font, size, flags
    if frame.healthText and frame.healthText.GetFont then font, size, flags = frame.healthText:GetFont() end
    x.pct = hb:CreateFontString(nil, "OVERLAY")
    x.val = hb:CreateFontString(nil, "OVERLAY")
    for _, fs in ipairs({ x.pct, x.val }) do
        fs:SetFont(font or STANDARD_TEXT_FONT, size or 11, flags or "OUTLINE")
        fs:SetShadowOffset(0, 0)
        fs:SetTextColor(1, 1, 1, 1)
        fs:Hide()
    end
    frame.h3zSplitHealth = function(f, hp, maxHP)
        local xx = f.h3zV3
        if not (xx and xx.split) then return end
        local uf = UF()
        if not (uf and uf.FormatHealthText and uf.GetHealthPct and f.unit) then return end
        local pct = uf.GetHealthPct(f.unit, false)
        xx.pct:SetText(uf.FormatHealthText(hp, pct, "percent"))
        xx.val:SetText(uf.FormatHealthText(hp, pct, "absolute", nil, maxHP))
    end
    local ex = CreateFrame("StatusBar", nil, hb)
    ex:SetAllPoints(hb)
    ex:SetFrameLevel(hb:GetFrameLevel() + 4)
    ex:SetStatusBarTexture(WHITE)
    ex:GetStatusBarTexture():SetAlpha(0)
    ex:SetMinMaxValues(0, 100)
    ex:EnableMouse(false)
    local line = ex:CreateTexture(nil, "OVERLAY", nil, 7)
    line:SetTexture(WHITE)
    line:SetWidth(2)
    line:SetPoint("TOPLEFT", ex:GetStatusBarTexture(), "TOPRIGHT", -1, 0)
    line:SetPoint("BOTTOMLEFT", ex:GetStatusBarTexture(), "BOTTOMRIGHT", -1, 0)
    ex.line = line
    ex:Hide()
    x.exec = ex
    frame.h3zV3 = x
    return x
end

function HideV3(frame)
    local x = frame.h3zV3
    if not x then return end
    x.wantBadge, x.wantExec, x.castOn = false, false, false
    if x.split then
        x.split = false
        if frame.healthText then frame.healthText:SetAlpha(1) end
    end
    x.pct:Hide(); x.val:Hide()
    x.dragon:Hide(); x.dropRing:Hide(); x.dropInner:Hide(); x.dropTex:Hide()
    x.dropOn = false
    x.badge:Hide()
    x.cast:Hide()
    x.exec:Hide()
end

function ApplyV3Extras(frame, unitKey, cfg)
    local x = V3Parts(frame)
    local r = frame.h3zRound
    if not (x and r) then return end
    local other = unitKey ~= "player" and unitKey ~= "pet"
    x.wantBadge = cfg.badge and other and true or false
    x.wantExec = cfg.execute and other and true or false
    x.execClass = cfg.executeClass and true or false
    x.castOn = cfg.castIcon and true or false
    x.split = cfg.splitText and frame.healthBar and true or false
    local hb = frame.healthBar
    x.dragonOn = cfg.dragon and true or false
    x.mirror = RIGHT_SIDE[unitKey] and true or false
    x.dropOn = cfg.drop and true or false
    local textSize = tonumber(cfg.textSize) or 11
    if frame.healthText and frame.healthText.GetFont then
        local font, _, flags = frame.healthText:GetFont()
        if font then
            x.pct:SetFont(font, textSize, flags or "OUTLINE")
            x.val:SetFont(font, textSize, flags or "OUTLINE")
        end
    end
    -- the square corner of the drop sits on the side of the bar
    local corner = x.mirror and "BOTTOMLEFT" or "BOTTOMRIGHT"
    local half = math.floor(r:GetWidth() / 2 + 0.5)
    local t = PixelRound(tonumber(cfg.ringThickness) or 1, frame)
    local sx = x.mirror and 1 or -1
    x.dropRing:ClearAllPoints(); x.dropRing:SetSize(half, half); x.dropRing:SetPoint(corner, r, corner, 0, 0)
    x.dropInner:ClearAllPoints(); x.dropInner:SetSize(half - t, half - t); x.dropInner:SetPoint(corner, r, corner, sx * t, t)
    x.dropTex:ClearAllPoints(); x.dropTex:SetSize(half - t, half - t); x.dropTex:SetPoint(corner, r, corner, sx * t, t)
    if x.mirror then x.dropTex:SetTexCoord(0.08, 0.5, 0.5, 0.92) else x.dropTex:SetTexCoord(0.5, 0.92, 0.5, 0.92) end
    x.pct:ClearAllPoints(); x.val:ClearAllPoints()
    if RIGHT_SIDE[unitKey] then
        x.pct:SetPoint("RIGHT", hb, "RIGHT", -4, 0); x.pct:SetJustifyH("RIGHT")
        x.val:SetPoint("LEFT", hb, "LEFT", 4, 0); x.val:SetJustifyH("LEFT")
    else
        x.pct:SetPoint("LEFT", hb, "LEFT", 4, 0); x.pct:SetJustifyH("LEFT")
        x.val:SetPoint("RIGHT", hb, "RIGHT", -4, 0); x.val:SetJustifyH("RIGHT")
    end
    x.pct:SetShown(x.split); x.val:SetShown(x.split)
    if frame.healthText then frame.healthText:SetAlpha(x.split and 0 or 1) end
    if x.split and UnitExists(UNIT_OF[unitKey]) then
        pcall(frame.h3zSplitHealth, frame, UnitHealth(UNIT_OF[unitKey]), UnitHealthMax(UNIT_OF[unitKey]))
    end
    x.cast:ClearAllPoints()
    x.cast:SetAllPoints(r.inner)
    x.badge:ClearAllPoints()
    if RIGHT_SIDE[unitKey] then
        x.badge:SetPoint("TOPRIGHT", r, "TOPRIGHT", 5, 5)
    else
        x.badge:SetPoint("TOPLEFT", r, "TOPLEFT", -5, 5)
    end
    x.exec:SetValue(tonumber(cfg.executePct) or 20)
    x.exec.line:SetWidth(PixelRound(2, frame))
end

local function CastTexture(unit)
    local name, _, icon = UnitCastingInfo(unit)
    if name == nil and UnitChannelInfo then name, _, icon = UnitChannelInfo(unit) end
    if name == nil then return nil end
    return icon
end

function FS.UpdateCast(unitKey)
    local frame = GetFrame(unitKey)
    local x = frame and frame.h3zV3
    if not x then return end
    local s = DB()
    local tex
    if frame.h3zStyled and x.castOn and s and s.style == "roundv3" then
        local ok, icon = pcall(CastTexture, UNIT_OF[unitKey])
        if ok then tex = icon end
    end
    if tex ~= nil and pcall(x.cast.SetTexture, x.cast, tex) then
        x.cast:Show()
    else
        x.cast:Hide()
    end
end

function FS.UpdateExtras(unitKey)
    local frame = GetFrame(unitKey)
    local x = frame and frame.h3zV3
    if not x then return end
    local s = DB()
    local unit = UNIT_OF[unitKey]
    local on = frame.h3zStyled and s and s.style == "roundv3" and frame.h3zRound and frame.h3zRound:IsShown()
        and UnitExists(unit)

    local kind
    if on and x.wantBadge then
        local ok, c = pcall(UnitClassification, unit)
        if ok and c ~= nil and not IsSecret(c) then kind = c end
    end
    local d = kind and DRAGON[kind]
    local r = frame.h3zRound
    if d and x.dragonOn and x.dragon.SetAtlas and pcall(x.dragon.SetAtlas, x.dragon, d.atlas) then
        local scale = r:GetWidth()
        x.dragon:SetSize(d.g.w * scale, d.g.h * scale)
        x.dragon:ClearAllPoints()
        x.dragon:SetPoint("CENTER", r, "CENTER", d.g.x * scale * (x.mirror and 1 or -1), d.g.y * scale)
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(d.atlas)
        if info then
            if x.mirror then
                x.dragon:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
            else
                x.dragon:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
            end
        end
        x.dragon:Show()
        x.badge:Hide()
    else
        x.dragon:Hide()
        local atlas = kind and BADGE_ATLAS[kind]
        if atlas and x.badge.SetAtlas and pcall(x.badge.SetAtlas, x.badge, atlas) then
            x.badge:Show()
        else
            x.badge:Hide()
        end
    end

    -- the drop portrait: square corner in the ring colour with its own bit of the picture
    if on and x.dropOn then
        x.dropRing:SetVertexColor(RingColor(unit))
        pcall(SetPortraitTexture, x.dropTex, unit, true)
        x.dropRing:Show(); x.dropInner:Show(); x.dropTex:Show()
    else
        x.dropRing:Hide(); x.dropInner:Hide(); x.dropTex:Hide()
    end

    local line = false
    if on and x.wantExec then
        local ok, can = pcall(UnitCanAttack, "player", unit)
        -- a value that cannot be read keeps the line, it is only a hint
        line = ok and (IsSecret(can) or can) and true or false
    end
    if line then
        local r, g, b = 1, 1, 1
        if x.execClass then
            local _, class = UnitClass("player")
            local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
            if c then r, g, b = c.r, c.g, c.b end
        end
        x.exec.line:SetVertexColor(r, g, b, 0.95)
        x.exec:Show()
    else
        x.exec:Hide()
    end

    FS.UpdateCast(unitKey)
end

function FS.UpdatePortrait(unitKey)
    local frame = GetFrame(unitKey)
    if not frame then return end
    local unit = UNIT_OF[unitKey]
    if FS.UpdateExtras then FS.UpdateExtras(unitKey) end
    local q = frame.h3zSquare
    if q and q:IsShown() and UnitExists(unit) then
        pcall(SetPortraitTexture, q.tex, unit, true)
        q.tex:SetTexCoord(0.12, 0.88, 0.12, 0.88)
        local st = Opts()
        if st and st.classRing then
            local r, g, b = RingColor(unit)
            q.edge:SetColorTexture(r, g, b, 1)
        else
            q.edge:SetColorTexture(0, 0, 0, 1)
        end
    end
    -- missing health shows as a light tint of the class / reaction color
    if frame.h3zTint and frame.h3zTint:IsShown() and UnitExists(unit) then
        local r, g, b = RingColor(unit, true)
        frame.h3zTint:SetColorTexture(r + (1 - r) * 0.55, g + (1 - g) * 0.55, b + (1 - b) * 0.55, 1)
    end
    local uf = UF()
    if uf and uf.UpdateLevel then pcall(uf.UpdateLevel, frame) end
    local r = frame.h3zRound
    if not (r and r:IsShown()) then return end
    if UnitExists(unit) then
        -- square portrait from the game, our mask cuts the circle (clean edge)
        pcall(SetPortraitTexture, r.tex, unit, true)
        r.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    r.ring:SetVertexColor(RingColor(unit))
end

---------------------------------------------------------------------------
-- Apply / revert
---------------------------------------------------------------------------
local function Revert(frame, unitKey)
    if not frame.h3zStyled then return end
    frame.h3zStyled = nil
    if frame.h3zRound then frame.h3zRound:Hide() end
    if frame.h3zSquare then frame.h3zSquare:Hide() end
    if frame.h3zTint then frame.h3zTint:Hide() end
    HideV3(frame)
    if frame.portrait then frame.portrait:SetAlpha(1) end
    if frame.healthText then frame.healthText:SetAlpha(1) end
    if frame.powerBar then frame.powerBar:SetAlpha(1) end
    -- Normal refresh puts size, name and portrait back to your settings
    local uf = UF()
    if uf and uf.RefreshFrame then
        FS._reverting = true
        pcall(uf.RefreshFrame, uf, unitKey)
        FS._reverting = nil
    end
end

local function WantsStyle(s, unitKey)
    if not s.enabled then return false end
    if unitKey == "pet" then
        return s.dockPet and s.player and true or false
    end
    return s[unitKey] and true or false
end

local function Thickness(s, frame)
    return PixelRound(tonumber(s.ringThickness) or 1, frame)
end

local function PortraitSize(s, frame, fit)
    local v = tonumber(s.pSize) or 0
    if v > 0 then return PixelRound(v, frame) end
    return PixelRound(fit, frame)
end

-- Round: circle with a ring beside the bar, name above
local function ApplyRound(frame, unitKey, s)
    if frame.h3zSquare then frame.h3zSquare:Hide() end
    if frame.h3zTint then frame.h3zTint:Hide() end
    local r = GetRound(frame)
    local size = PortraitSize(s, frame, (s.style == "roundv2") and (frame:GetHeight() * 1.6)
        or (s.style == "roundv3") and (frame:GetHeight() * 2.6)
        or (frame:GetHeight() * 1.35 + (s.nameAbove and 8 or 0)))
    local t = Thickness(s, frame)
    r:SetSize(size, size)
    r.inner:ClearAllPoints()
    r.inner:SetPoint("TOPLEFT", r, "TOPLEFT", t, -t)
    r.inner:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -t, t)
    r.innerMask:ClearAllPoints()
    r.innerMask:SetAllPoints(r.inner)
    r.tex:ClearAllPoints()
    r.tex:SetAllPoints(r.inner)

    local yOff = s.nameAbove and 6 or 0
    if s.style == "roundv3" then yOff = math.floor(size * 0.29 + 0.5) end
    local v2 = (s.style == "roundv2")
    r:ClearAllPoints()
    if v2 then
        -- v2: the ring sits on the bar's end, the bar starts under the portrait
        r:SetFrameLevel(frame:GetFrameLevel() + 6)
        if RIGHT_SIDE[unitKey] then
            r:SetPoint("CENTER", frame, "RIGHT", size * 0.18, 0)
        else
            r:SetPoint("CENTER", frame, "LEFT", -size * 0.18, 0)
        end
    elseif RIGHT_SIDE[unitKey] then
        r:SetPoint("LEFT", frame, "RIGHT", (s.style == "roundv3") and 2 or 4, yOff)
    else
        r:SetPoint("RIGHT", frame, "LEFT", (s.style == "roundv3") and -2 or -4, yOff)
    end
    r:Show()

    -- v2: the portrait covers the end of the bar; health text on that side moves out from
    -- under it (same anchor and offsets as in the unit frame settings, plus the covered part)
    if v2 and frame.healthText then
        local core = ns.Addon
        local ufdb = core and core.db and core.db.profile and core.db.profile.h3z0uiUnitFrames
        local us = ufdb and ufdb[unitKey]
        local anchor = (us and us.healthAnchor) or "RIGHT"
        local ox, oy = (us and us.healthOffsetX) or -4, (us and us.healthOffsetY) or 0
        local cover = size * 0.32 + 4
        if RIGHT_SIDE[unitKey] and anchor:find("RIGHT") then
            ox = ox - cover
        elseif not RIGHT_SIDE[unitKey] and anchor:find("LEFT") then
            ox = ox + cover
        end
        frame.healthText:ClearAllPoints()
        frame.healthText:SetPoint(anchor, frame, anchor, ox, oy)
    end

    if s.nameAbove and frame.nameText then
        frame.nameText:ClearAllPoints()
        -- v2: the portrait covers the bar's start, so the name starts after it
        local push = v2 and (size * 0.32 + 2) or 1
        if s.style == "roundv3" and frame.nameText.GetFont then
            local nf, _, nfl = frame.nameText:GetFont()
            if nf then frame.nameText:SetFont(nf, tonumber(s.textSize) or 11, nfl) end
        end
        if RIGHT_SIDE[unitKey] then
            frame.nameText:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -push, 3)
            frame.nameText:SetJustifyH("RIGHT")
        else
            frame.nameText:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", push, 3)
            frame.nameText:SetJustifyH("LEFT")
        end
    end
end

-- Pet row under the player: 2px gap, about half the player height
local function PetRow()
    local player = GetFrame("player")
    local h = player and player:GetHeight() or 37
    return 2, math.floor(h * 0.52 + 0.5)
end

-- Square style: the bar fills the box beside the portrait; sub-bars (druid
-- bars, ...) hang under it in the tray, with the same left / right edges
local function SquareBars(frame, unitKey, size, px)
    local hb = frame.healthBar
    local uf = UF()
    hb:ClearAllPoints()
    if RIGHT_SIDE[unitKey] then
        hb:SetPoint("TOPLEFT", frame, "TOPLEFT", px, -px)
        hb:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(px + size), px)
    else
        hb:SetPoint("TOPLEFT", frame, "TOPLEFT", px + size, -px)
        hb:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, px)
    end
    -- sub-bars go in the tray under the box, lined up with the bar
    if uf and uf.StackSubBars then uf.StackSubBars(frame, hb, px) end
end

-- Called by the unit frames when a sub-bar comes or goes. Returns true when
-- this style placed the bars (square), false to let the normal stack do it.
function FS.RelayoutBars(frame, unitKey)
    local s = Cfg()
    local v3 = s and s.style == "roundv3"
    if not (s and frame.h3zStyled and (s.style == "square" or v3) and UNIT_OF[unitKey] and unitKey ~= "pet") then
        return false
    end
    if not frame.healthBar then return false end
    local px = PixelRound(1, frame)
    -- Modern v3: the portrait sits beside the bar, the bar fills the whole frame
    local size = v3 and 0 or PortraitSize(s, frame, frame:GetHeight() - px * 2)
    SquareBars(frame, unitKey, size, px)
    return true
end

-- Docked: one bordered box, portrait inside on the outer side, bar fills the
-- rest (missing health = light tint of the class color), no power bar,
-- name on the top edge, health text in the row underneath
local function ApplySquare(frame, unitKey, s)
    if frame.h3zRound then frame.h3zRound:Hide() end
    local px = PixelRound(1, frame)
    local right = RIGHT_SIDE[unitKey]
    local inner = frame:GetHeight() - px * 2
    local size = PortraitSize(s, frame, inner)
    local t = Thickness(s, frame)

    local q = GetSquare(frame)
    q:SetSize(size, size)
    q.bg:ClearAllPoints()
    q.bg:SetPoint("TOPLEFT", q, "TOPLEFT", t, -t)
    q.bg:SetPoint("BOTTOMRIGHT", q, "BOTTOMRIGHT", -t, t)
    q.tex:ClearAllPoints()
    q.tex:SetAllPoints(q.bg)
    q:ClearAllPoints()
    if right then
        q:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, px)
    else
        q:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", px, px)
    end
    q:Show()

    local hb = frame.healthBar
    if hb then
        SquareBars(frame, unitKey, size, px)
        if not frame.h3zTint then
            frame.h3zTint = hb:CreateTexture(nil, "BACKGROUND", nil, -7)
            frame.h3zTint:SetAllPoints(hb)
        end
        frame.h3zTint:Show()
    end
    if frame.powerBar then frame.powerBar:SetAlpha(0) end

    if s.nameAbove and frame.nameText and hb then
        frame.nameText:ClearAllPoints()
        if right then
            frame.nameText:SetPoint("RIGHT", hb, "TOPRIGHT", -5, 0)
            frame.nameText:SetJustifyH("RIGHT")
        else
            frame.nameText:SetPoint("LEFT", hb, "TOPLEFT", 5, 0)
            frame.nameText:SetJustifyH("LEFT")
        end
    end

    local gap, petH = PetRow()
    if frame.healthText then
        frame.healthText:ClearAllPoints()
        local y = -(gap + petH / 2)
        if right then
            frame.healthText:SetPoint("LEFT", frame, "BOTTOMLEFT", 1, y)
            frame.healthText:SetJustifyH("LEFT")
        else
            frame.healthText:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -1, y)
            frame.healthText:SetJustifyH("RIGHT")
        end
        frame.healthText:SetAlpha(1)
    end

    if frame.restedIndicator and hb then
        frame.restedIndicator:ClearAllPoints()
        frame.restedIndicator:SetPoint("CENTER", hb, "CENTER", 0, 0)
    end
end

-- Modern v3: a slim bar that fills the frame, no power bar on it (the Resource Bars show it)
local function ApplyV3Bars(frame, unitKey)
    local px = PixelRound(1, frame)
    if frame.powerBar then frame.powerBar:SetAlpha(0) end
    if frame.healthBar then SquareBars(frame, unitKey, 0, px) end
end

-- Pet bar under the left half of the player, name on its bottom edge
local function ApplyPetDock(petFrame, s)
    local player = GetFrame("player")
    if not player then return end
    local gap, petH = PetRow()
    petFrame:ClearAllPoints()
    petFrame:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -PixelRound(gap, petFrame))
    petFrame:SetWidth(PixelRound(player:GetWidth() * 0.52, petFrame))
    petFrame:SetHeight(PixelRound(petH, petFrame))
    if petFrame.powerBar then petFrame.powerBar:SetAlpha(0) end
    if petFrame.healthBar then
        local px = PixelRound(1, petFrame)
        petFrame.healthBar:ClearAllPoints()
        petFrame.healthBar:SetPoint("TOPLEFT", petFrame, "TOPLEFT", px, -px)
        petFrame.healthBar:SetPoint("BOTTOMRIGHT", petFrame, "BOTTOMRIGHT", -px, px)
    end
    if petFrame.nameText then
        petFrame.nameText:ClearAllPoints()
        petFrame.nameText:SetPoint("CENTER", petFrame, "BOTTOM", 0, 0)
        petFrame.nameText:SetJustifyH("CENTER")
    end
    if petFrame.healthText then petFrame.healthText:SetAlpha(0) end
    if petFrame.portrait then petFrame.portrait:SetAlpha(0) end
end

function FS.ApplyUnit(unitKey)
    if FS._reverting or not UNIT_OF[unitKey] then return end
    local frame = GetFrame(unitKey)
    local s = Cfg()
    if not (frame and s) then return end
    if InCombatLockdown() then
        pendingApply = true
        return
    end

    if not WantsStyle(s, unitKey) then
        Revert(frame, unitKey)
        return
    end
    frame.h3zStyled = true

    if unitKey == "pet" then
        ApplyPetDock(frame, s)
        return
    end

    if frame.portrait then frame.portrait:SetAlpha(0) end

    -- Frame height for both styles (0 = keep your own height)
    local h = tonumber(s.height) or 0
    if h > 0 then
        frame:SetHeight(PixelRound(h, frame))
    end

    if s.style == "square" then
        ApplySquare(frame, unitKey, s)
    else
        ApplyRound(frame, unitKey, s)
    end

    if s.style == "roundv3" then
        ApplyV3Bars(frame, unitKey)
        ApplyV3Extras(frame, unitKey, s)
    else
        HideV3(frame)
    end

    FS.UpdatePortrait(unitKey)
end

function FS.ApplyAll()
    for _, key in ipairs(UNIT_KEYS) do FS.ApplyUnit(key) end
end

-- Called by the options and the slash command
function FS.SetEnabled(on)
    local s = DB()
    if not s then return end
    s.enabled = on and true or false
    if InCombatLockdown() then
        print("|cFF30D1FFH3z0 UI:|r The frame style changes when you leave combat.")
    end
    FS.ApplyAll()
end

function FS.Toggle()
    local s = DB()
    if s then FS.SetEnabled(not s.enabled) end
    return s and s.enabled
end

_G.H3z0UI_RefreshFrameStyle = function() FS.ApplyAll() end
_G.H3z0UI_ToggleFrameStyle = FS.Toggle

---------------------------------------------------------------------------
-- Hooks and events
---------------------------------------------------------------------------
local hooked = false
local function HookUF()
    if hooked then return end
    local uf = UF()
    if not uf then return end
    hooked = true
    if uf.RefreshFrame then
        hooksecurefunc(uf, "RefreshFrame", function(_, unitKey)
            if UNIT_OF[unitKey] then FS.ApplyUnit(unitKey) end
        end)
    end
    if uf.RefreshAll then
        hooksecurefunc(uf, "RefreshAll", function() FS.ApplyAll() end)
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:RegisterEvent("UNIT_PORTRAIT_UPDATE")
ev:RegisterEvent("UNIT_MODEL_CHANGED")
ev:RegisterEvent("UNIT_FACTION")
-- the cast icon in the Modern v3 portrait (some events do not exist on every client)
local CAST_EVENTS = {
    UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_EMPOWER_START = true, UNIT_SPELLCAST_EMPOWER_STOP = true,
}
for name in pairs(CAST_EVENTS) do pcall(ev.RegisterEvent, ev, name) end
ev:SetScript("OnEvent", function(_, event, unit)
    if CAST_EVENTS[event] then
        if unit and UNIT_OF[unit] then FS.UpdateCast(unit) end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.5, function()
            HookUF()
            FS.ApplyAll()
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then
            pendingApply = false
            FS.ApplyAll()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        FS.UpdatePortrait("target")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        FS.UpdatePortrait("focus")
    elseif unit and UNIT_OF[unit] then
        FS.UpdatePortrait(unit)
    end
end)
