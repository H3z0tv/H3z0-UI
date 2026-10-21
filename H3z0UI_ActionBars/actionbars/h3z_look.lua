local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI look on the action bars: Streamer Mode and Modern Action Buttons
-- (Modern Look). Works on H3z0 UI's own bar buttons.
---------------------------------------------------------------------------

local ActionBars = {}

local function GetDB()
    local core = ns.Addon
    return core and core.db and core.db.profile and core.db.profile.actionBars
end

local function GetGlobalSettings()
    local db = GetDB()
    return db and db.global
end

-- run fn after H3z0 UI rebuilt / re-skinned its bars
local function HookOwnedRefresh(fn)
    local owned = ns.ActionBarsOwned
    if owned and type(owned.Refresh) == "function" then
        hooksecurefunc(owned, "Refresh", fn)
    end
    if owned and type(owned.Initialize) == "function" then
        hooksecurefunc(owned, "Initialize", fn)
    end
end

---------------------------------------------------------------------------
-- STREAMER MODE: hide the yellow press / active highlight on action buttons
-- (pushed glow, checked border, cast fill and targeting animation), so
-- viewers don't see which keys are pressed. Only alpha is changed (allowed
-- in and out of combat, no Blizzard state is written).
---------------------------------------------------------------------------
-- H3z0 UI's own bar buttons first, Blizzard's too (in case a bar runs on Blizzard's buttons)
local STREAMER_BARS = {
    "H3z0UI_Bar1Button", "H3z0UI_Bar2Button", "H3z0UI_Bar3Button", "H3z0UI_Bar4Button",
    "H3z0UI_Bar5Button", "H3z0UI_Bar6Button", "H3z0UI_Bar7Button", "H3z0UI_Bar8Button",
    "H3z0UI_StanceButton", "H3z0UI_PetButton",
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button", "StanceButton", "PetActionButton",
}

local function ForEachActionButton(fn)
    for _, prefix in ipairs(STREAMER_BARS) do
        for i = 1, 12 do
            local b = _G[prefix .. i]
            if b then fn(b) end
        end
    end
    if _G.ExtraActionButton1 then fn(_G.ExtraActionButton1) end
end

local function StreamerRegions(b)
    local list = {}
    local function Add(r) if r and r.SetAlpha then list[#list + 1] = r end end
    if b.GetPushedTexture then Add(b:GetPushedTexture()) end
    if b.GetCheckedTexture then Add(b:GetCheckedTexture()) end
    Add(b.PushedTexture)
    Add(b.CheckedTexture)
    Add(b.SpellCastAnimFrame)
    Add(b.TargetReticleAnimFrame)
    Add(b.InterruptDisplay)
    return list
end

local streamerHooked = {}
local function StreamerOn()
    local s = GetGlobalSettings()
    return s and s.streamerMode and true or false
end

local function ApplyStreamerMode()
    local on = StreamerOn()
    ForEachActionButton(function(b)
        for _, r in ipairs(StreamerRegions(b)) do
            pcall(r.SetAlpha, r, on and 0 or 1)
            -- animations can show themselves again: keep them hidden while it's on
            if not streamerHooked[r] and r.Show and r.GetObjectType and r:GetObjectType() == "Frame" then
                streamerHooked[r] = true
                hooksecurefunc(r, "Show", function(self)
                    if StreamerOn() then self:SetAlpha(0) end
                end)
            end
        end
    end)
end
_G.H3z0UI_ApplyStreamerMode = ApplyStreamerMode

-- 0.24.2: run fn once after the last of many calls (shapeshifting fires UPDATE_SHAPESHIFT_FORMS
-- a lot; every one of them started its own full pass over all action buttons)
local function Debounced(fn, delay)
    local pending = false
    return function()
        if pending then return end
        pending = true
        C_Timer.After(delay, function() pending = false; fn() end)
    end
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    f:RegisterEvent("PET_BAR_UPDATE")
    local later = Debounced(ApplyStreamerMode, 1)
    f:SetScript("OnEvent", later)
    -- re-apply after H3z0 UI re-skins the bars
    HookOwnedRefresh(Debounced(ApplyStreamerMode, 0.1))
end

---------------------------------------------------------------------------
-- Modern buttons (Modern Look > Modern Action Buttons)
-- Rounded tiles: a 1px black rounded outline, a dark slot inside it, the icon
-- rounded on top, a soft rounded shadow, rounded hover / pressed / checked
-- highlights and a rounded cooldown swipe. Only textures and masks of H3z0 UI
-- are added; nothing is changed while in combat.
---------------------------------------------------------------------------
local SHADOW_LAYERS = { 0.18, 0.08, 0.03 }

local function ModernSettings()
    local ML = ns.ModernLook
    return ML and ML.GetSettings and ML.GetSettings()
end

local function ModernButtonsOn()
    local s = ModernSettings()
    local gs = GetGlobalSettings()
    return s and s.buttons ~= false and (not gs or gs.skinEnabled ~= false) and ns.Round ~= nil
end

local function HighlightTextures(b)
    local list = {}
    local function Add(t) if t and t.AddMaskTexture then list[#list + 1] = t end end
    if b.GetHighlightTexture then Add(b:GetHighlightTexture()) end
    if b.GetPushedTexture then Add(b:GetPushedTexture()) end
    if b.GetCheckedTexture then Add(b:GetCheckedTexture()) end
    Add(b.Flash)
    Add(b.NewActionTexture)
    return list
end

local function ModernButton(b, on)
    local Round = ns.Round
    if not Round then return end
    local icon = b.icon or b.Icon
    local m = b.h3zModern
    if not on then
        if not m then return end
        for t in pairs(m.masked) do Round.Mask(t, nil, false) end
        wipe(m.masked)
        for _, e in ipairs(m.edges) do e:Hide() end
        m.slot:Hide()
        for _, t in ipairs(m.shadow) do t:Hide() end
        if icon then icon:ClearAllPoints(); icon:SetAllPoints(b) end
        if b._h3z0uiNormal and m.normal then b._h3z0uiNormal:Show() end
        if b._h3z0uiGloss and m.gloss then b._h3z0uiGloss:Show() end
        if b._h3z0uiBackdrop and m.backdrop then b._h3z0uiBackdrop:Show() end
        local cd = b.cooldown or b.Cooldown
        if cd and m.swipe then pcall(cd.SetSwipeTexture, cd, "Interface\\Buttons\\WHITE8x8") end
        b.h3zModernOn = nil
        return
    end
    if not m then
        m = { masked = {}, shadow = {} }
        -- border = four thin edges (a real frame, so a see-through slot never shows a grey square)
        m.edges = {}
        for i = 1, 4 do
            m.edges[i] = b:CreateTexture(nil, "OVERLAY", nil, 3)
        end
        m.slot = b:CreateTexture(nil, "BACKGROUND", nil, -6)
        for i, a in ipairs(SHADOW_LAYERS) do
            local t = b:CreateTexture(nil, "BACKGROUND", nil, -8)
            t:SetColorTexture(0, 0, 0, a)
            t.grow = i
            m.shadow[i] = t
        end
        b.h3zModern = m
    end

    local barKey = GetBarKeyFromButton(b)
    local settings = barKey and GetEffectiveSettings(barKey)
    local px = Round.PixelSize(b)
    local w = b:GetWidth() or 36
    local r = Round.Enabled() and math.max(2, math.min(Round.Radius(), w / 5)) or 1

    -- remember what the classic skin showed, then hide it
    if not b.h3zModernOn then
        m.normal = b._h3z0uiNormal and b._h3z0uiNormal:IsShown()
        m.gloss = b._h3z0uiGloss and b._h3z0uiGloss:IsShown()
        m.backdrop = b._h3z0uiBackdrop and b._h3z0uiBackdrop:IsShown()
    end
    if b._h3z0uiNormal then b._h3z0uiNormal:Hide() end
    if b._h3z0uiBackdrop then b._h3z0uiBackdrop:Hide() end
    b.h3zModernOn = true

    m.slot:ClearAllPoints()
    m.slot:SetPoint("TOPLEFT", b, "TOPLEFT", px, -px)
    m.slot:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -px, px)
    -- Action Bars > Button Appearance drives the tile:
    --   Show Backdrop / Backdrop Opacity -> the dark slate slot (same colour as chat + damage meter)
    --   Show Button Borders              -> the thin slate border
    --   Show Gloss / Gloss Opacity       -> the gloss, rounded like the tile
    local sf, sb = Round.SLATE_FILL, Round.SLATE_BORDER
    m.slot:SetColorTexture(sf[1], sf[2], sf[3], 1)
    local showSlot = not (settings and settings.showBackdrop == false)
    m.slot:SetAlpha(settings and settings.backdropAlpha or 0.9)
    m.slot:SetShown(showSlot)
    local showBorder = not (settings and settings.showBorders == false)
    local e = m.edges
    for _, t in ipairs(e) do t:SetColorTexture(sb[1], sb[2], sb[3], 1); t:ClearAllPoints() end
    e[1]:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0);       e[1]:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0);       e[1]:SetHeight(px)
    e[2]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0); e[2]:SetHeight(px)
    e[3]:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0);       e[3]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0);   e[3]:SetWidth(px)
    e[4]:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0);     e[4]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(px)
    for _, t in ipairs(e) do t:SetShown(showBorder) end
    local gloss = b._h3z0uiGloss
    if gloss then
        if settings and settings.showGloss then
            gloss:SetVertexColor(1, 1, 1, settings.glossAlpha or 0.6)
            gloss:ClearAllPoints()
            gloss:SetAllPoints(b)
            gloss:Show()
        else
            gloss:Hide()
        end
    end
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", b, "TOPLEFT", px, -px)
        icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -px, px)
    end

    local outer = Round.Enabled() and Round.SquareMask(b, b, 0, "h3zMBOuterSq") or {}
    local inner = Round.Enabled() and Round.SquareMask(b, b, px, "h3zMBInnerSq") or {}
    local function Mask(t, set)
        if next(set) == nil then Round.Mask(t, nil, false) return end
        Round.Mask(t, set, true); m.masked[t] = true
    end
    for _, t in ipairs(m.edges) do Mask(t, outer) end
    Mask(m.slot, inner)
    if b._h3z0uiGloss then Mask(b._h3z0uiGloss, inner) end
    if icon then Mask(icon, inner) end
    for _, t in ipairs(HighlightTextures(b)) do Mask(t, inner) end

    for i, t in ipairs(m.shadow) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", b, "TOPLEFT", -t.grow, t.grow - 1)
        t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", t.grow, -t.grow - 1)
        if Round.Enabled() then Mask(t, Round.SquareMask(b, t, 0, "h3zMBShadowSq" .. i)) end
        t:Show()
    end

    local cd = b.cooldown or b.Cooldown
    if cd and cd.SetSwipeTexture and Round.Enabled() then
        m.swipe = pcall(cd.SetSwipeTexture, cd, Round.TILE)
    end
end

local pendingModern = false
local function ApplyModernButtons()
    if InCombatLockdown() then
        pendingModern = true
        return
    end
    pendingModern = false
    -- once: slots on and as solid as the chat panel, so the bars match chat + damage meter
    local gs = GetGlobalSettings()
    if gs and not gs.h3zSlateSync then
        gs.h3zSlateSync = true
        local core = ns.Addon
        local ws = core and core.db and core.db.profile and core.db.profile.windowSkins
        gs.showBackdrop = true
        gs.backdropAlpha = (ws and ws.chatAlpha) or 0.9
    end
    local on = ModernButtonsOn()
    ForEachActionButton(function(b)
        if b.IsForbidden and b:IsForbidden() then return end
        local ok, err = pcall(ModernButton, b, on and true or false)
        if not ok then ActionBars.modernError = err end
    end)
end
_G.H3z0UI_ApplyModernButtons = ApplyModernButtons
_G.H3z0UI_DebugModernButtons = function()
    local b = _G.ActionButton1
    local ok, err = true, nil
    if b and not InCombatLockdown() then ok, err = pcall(ModernButton, b, ModernButtonsOn() and true or false) end
    local m = b and b.h3zModern
    return string.format("buttons on=%s ok=%s err=%s rim=%s shown=%s", tostring(ModernButtonsOn()), tostring(ok),
        tostring(err or ActionBars.modernError), tostring(m ~= nil), tostring(m and m.slot:IsShown()))
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    f:RegisterEvent("PET_BAR_UPDATE")
    local later = Debounced(ApplyModernButtons, 1.2)
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingModern then ApplyModernButtons() end
            return
        end
        later()
    end)
    -- the classic skin re-anchors the icon when bar settings change: put the modern look back
    HookOwnedRefresh(Debounced(ApplyModernButtons, 0.15))
end

