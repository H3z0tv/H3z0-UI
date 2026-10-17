--[[
    H3z0 UI - Rounded corners

    Two tools, both drawn with H3z0 UI's own textures (assets/h3z_corner_*,
    h3z_circle, h3z_ring_*):

      ns.Round.CornerMasks(owner, target, radius, inset, key)
      ns.Round.Mask(texture, masks, on)
          Four clamped corner masks: a texture with all four applied keeps its
          shape but loses its corners. Used to round existing frames (unit
          frames, power / cast bars) without rebuilding them.

      ns.Round.Panel(parent)
          A rounded rectangle background with an optional 1px border, made of
          nine pieces (corners from a circle, straight pieces in between) so it
          stays crisp at any size and also works when it is translucent.
          panel:SetRadius(r)  panel:SetFillColor(r, g, b, a)
          panel:SetBorderColor(r, g, b, a)  (a = 0 hides the border)
]]

local ADDON_NAME, ns = ...

local R = {}
ns.Round = R
_G.H3z0UI_RoundLib = R      -- for the /h3z0ui roundtest check

local ASSETS = "Interface\\AddOns\\" .. ADDON_NAME .. "\\assets\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local CIRCLE = ASSETS .. "h3z_circle"
local RINGS = { 4, 6, 8, 10, 12 }
R.ROUND_SQUARE = ASSETS .. "h3z_roundsquare"
R.TILE = ASSETS .. "h3z_tile"
-- one slate colour for every skinned surface (chat, damage meter, action button slots)
R.SLATE_FILL = { 0.075, 0.095, 0.12 }
R.SLATE_BORDER = { 0.25, 0.29, 0.33 }
function R.SlateAlpha()
    local core = ns.Addon
    local ws = core and core.db and core.db.profile and core.db.profile.windowSkins
    return (ws and ws.slotAlpha) or 1
end                 -- rounded square with small corners (buttons, icons)
R.MAP_MASK = ASSETS .. "h3z_mapmask"          -- .blp: the minimap only takes BLP mask files

local CORNER_TEX = {
    TOPLEFT = ASSETS .. "h3z_corner_tl",
    TOPRIGHT = ASSETS .. "h3z_corner_tr",
    BOTTOMLEFT = ASSETS .. "h3z_corner_bl",
    BOTTOMRIGHT = ASSETS .. "h3z_corner_br",
}
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local QUADRANT = {
    TOPLEFT = { 0, 0.5, 0, 0.5 },
    TOPRIGHT = { 0.5, 1, 0, 0.5 },
    BOTTOMLEFT = { 0, 0.5, 0.5, 1 },
    BOTTOMRIGHT = { 0.5, 1, 0.5, 1 },
}

---------------------------------------------------------------------------
-- Settings (shared with Modern Look: profile.modernLook.rounded / radius)
---------------------------------------------------------------------------
function R.Settings()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.modernLook = p.modernLook or {}
    local s = p.modernLook
    if s.rounded == nil then s.rounded = true end
    if s.radius == nil then s.radius = 6 end
    if not s.roundFix1 then          -- same one-time fix as Modern Look (whichever runs first)
        s.roundFix1 = true
        s.rounded, s.buttons, s.castbars = true, true, true
    end
    return s
end

function R.Enabled()
    local s = R.Settings()
    if not s then return false end
    return s.rounded and true or false
end

function R.Radius()
    local s = R.Settings()
    return math.max(2, math.min(14, (s and s.radius) or 6))
end

local function PixelSize(region)
    local core = ns.Addon
    if core and core.GetPixelSize then
        local ok, v = pcall(core.GetPixelSize, core, region)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    return 1
end
R.PixelSize = PixelSize

---------------------------------------------------------------------------
-- Corner masks
---------------------------------------------------------------------------
-- The client applies at most three masks to one texture, so the four corners are
-- done with TWO masks: a left end (top-left + bottom-left) and a right end. Each end
-- texture holds two quarter circles whose radius is 1/k of its height; the k that
-- gives the radius closest to the one asked for is picked (k = 2 is a full pill end).
local END_K = { 2, 4, 8 }
local function EndFor(h, radius)
    local want = h / math.max(1, radius)
    local best, diff = END_K[1], math.huge
    for _, k in ipairs(END_K) do
        local d = math.abs(k - want)
        if d < diff then best, diff = k, d end
    end
    return best
end

function R.CornerMasks(owner, target, radius, inset, key)
    key = key or "h3zRoundMasks"
    local set = owner[key]
    if not set then
        set = { LEFT = owner:CreateMaskTexture(), RIGHT = owner:CreateMaskTexture() }
        owner[key] = set
    end
    inset = inset or 0
    local h = (target.GetHeight and target:GetHeight()) or 0
    if h <= 0 then h = (radius or 6) * 4 end
    h = math.max(2, h - inset * 2)
    local k = EndFor(h, math.max(1, (radius or 6) - inset))
    local w = h / k
    set.LEFT:SetTexture(ASSETS .. "h3z_end_l" .. k, "CLAMP", "CLAMP")
    set.RIGHT:SetTexture(ASSETS .. "h3z_end_r" .. k, "CLAMP", "CLAMP")
    set.LEFT:ClearAllPoints()
    set.LEFT:SetPoint("TOPLEFT", target, "TOPLEFT", inset, -inset)
    set.LEFT:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", inset, inset)
    set.LEFT:SetWidth(w)
    set.RIGHT:ClearAllPoints()
    set.RIGHT:SetPoint("TOPRIGHT", target, "TOPRIGHT", -inset, -inset)
    set.RIGHT:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -inset, inset)
    set.RIGHT:SetWidth(w)
    return set
end

-- One mask for square things (buttons, icons): a rounded square stretched over the target
function R.SquareMask(owner, target, inset, key)
    key = key or "h3zSquareMask"
    local set = owner[key]
    if not set then
        local m = owner:CreateMaskTexture()
        m:SetTexture(R.TILE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        set = { ALL = m }
        owner[key] = set
    end
    inset = inset or 0
    set.ALL:ClearAllPoints()
    set.ALL:SetPoint("TOPLEFT", target, "TOPLEFT", inset, -inset)
    set.ALL:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -inset, inset)
    return set
end

function R.Mask(tex, set, on)
    if not (tex and tex.AddMaskTexture) then return end
    tex.h3zRoundMasks = tex.h3zRoundMasks or {}
    local have = tex.h3zRoundMasks
    if on and set then
        -- switching to another mask set: drop the old one first
        for m in pairs(have) do
            local keep = false
            for _, n in pairs(set) do if n == m then keep = true end end
            if not keep then pcall(tex.RemoveMaskTexture, tex, m); have[m] = nil end
        end
        for _, m in pairs(set) do
            if not have[m] and pcall(tex.AddMaskTexture, tex, m) then have[m] = true end
        end
    else
        for m in pairs(have) do pcall(tex.RemoveMaskTexture, tex, m) end
        wipe(have)
    end
end

---------------------------------------------------------------------------
-- Rounded panel
---------------------------------------------------------------------------
local function RingFor(r, px)
    local want = r / px
    local best, diff = RINGS[1], math.huge
    for _, n in ipairs(RINGS) do
        local d = math.abs(n - want)
        if d < diff then best, diff = n, d end
    end
    return ASSETS .. "h3z_ring_" .. best
end

local PanelMixin = {}

function PanelMixin:Layout()
    local r = self.radius or 6
    local px = PixelSize(self)
    local w, h = self:GetSize()
    if w and h and w > 0 and h > 0 then r = math.min(r, w / 2, h / 2) end
    r = math.max(1, r)
    local f, e = self.fill, self.edge
    local ring = RingFor(r, px)
    for _, c in ipairs(CORNERS) do
        for _, t in ipairs({ f[c], e[c] }) do
            t:ClearAllPoints()
            t:SetPoint(c, self, c, 0, 0)
            t:SetSize(r, r)
            t:SetTexCoord(unpack(QUADRANT[c]))
        end
        e[c]:SetTexture(ring)
        e[c]:SetTexCoord(unpack(QUADRANT[c]))
    end
    f.T:ClearAllPoints()
    f.T:SetPoint("TOPLEFT", self, "TOPLEFT", r, 0)
    f.T:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -r, -r)
    f.B:ClearAllPoints()
    f.B:SetPoint("TOPLEFT", self, "BOTTOMLEFT", r, r)
    f.B:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -r, 0)
    f.M:ClearAllPoints()
    f.M:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -r)
    f.M:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, r)

    e.T:ClearAllPoints()
    e.T:SetPoint("TOPLEFT", self, "TOPLEFT", r, 0)
    e.T:SetPoint("TOPRIGHT", self, "TOPRIGHT", -r, 0)
    e.T:SetHeight(px)
    e.B:ClearAllPoints()
    e.B:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", r, 0)
    e.B:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -r, 0)
    e.B:SetHeight(px)
    e.L:ClearAllPoints()
    e.L:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -r)
    e.L:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, r)
    e.L:SetWidth(px)
    e.R:ClearAllPoints()
    e.R:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -r)
    e.R:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, r)
    e.R:SetWidth(px)
end

function PanelMixin:SetRadius(r)
    self.radius = r
    self:Layout()
end

function PanelMixin:SetFillColor(r, g, b, a)
    for _, t in pairs(self.fill) do t:SetVertexColor(r, g, b, a or 1) end
end

function PanelMixin:SetBorderColor(r, g, b, a)
    a = a or 1
    for _, t in pairs(self.edge) do
        t:SetVertexColor(r, g, b, a)
        t:SetShown(a > 0)
    end
end

function R.Panel(parent, radius)
    local p = CreateFrame("Frame", nil, parent)
    p:EnableMouse(false)
    p.fill, p.edge = {}, {}
    for _, c in ipairs(CORNERS) do
        local t = p:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetTexture(CIRCLE)
        p.fill[c] = t
        local e = p:CreateTexture(nil, "BORDER", nil, 1)
        p.edge[c] = e
    end
    for _, k in ipairs({ "T", "B", "M" }) do
        local t = p:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetTexture(WHITE)
        p.fill[k] = t
    end
    for _, k in ipairs({ "T", "B", "L", "R" }) do
        local t = p:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(WHITE)
        p.edge[k] = t
    end
    for k, v in pairs(PanelMixin) do p[k] = v end
    p.radius = radius or 6
    p:SetScript("OnSizeChanged", p.Layout)
    p:Layout()
    p:SetFillColor(0.05, 0.06, 0.08, 0.8)
    p:SetBorderColor(1, 1, 1, 0.08)
    return p
end
