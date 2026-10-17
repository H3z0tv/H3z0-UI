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
    -- one set of settings shared by both styles
    if s.style == nil then s.style = "round" end            -- "round" | "roundv2" | "square"
    if s.height == nil then s.height = s.dockHeight or 37 end -- frame height, 0 = your own
    if s.pSize == nil then s.pSize = 0 end                   -- portrait size, 0 = fit the frame
    if s.ringThickness == nil then s.ringThickness = 1 end   -- ring / portrait border
    if s.classRing == nil then s.classRing = true end        -- class / reaction colored ring / border
    if s.nameAbove == nil then s.nameAbove = true end        -- name on top
    if s.dockPet == nil then s.dockPet = true end            -- pet bar under the player
    return s
end
FS.GetSettings = DB

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
    local s = DB()
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

function FS.UpdatePortrait(unitKey)
    local frame = GetFrame(unitKey)
    if not frame then return end
    local unit = UNIT_OF[unitKey]
    local q = frame.h3zSquare
    if q and q:IsShown() and UnitExists(unit) then
        pcall(SetPortraitTexture, q.tex, unit, true)
        q.tex:SetTexCoord(0.12, 0.88, 0.12, 0.88)
        local st = DB()
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
        r:SetPoint("LEFT", frame, "RIGHT", 4, yOff)
    else
        r:SetPoint("RIGHT", frame, "LEFT", -4, yOff)
    end
    r:Show()

    if s.nameAbove and frame.nameText then
        frame.nameText:ClearAllPoints()
        -- v2: the portrait covers the bar's start, so the name starts after it
        local push = v2 and (size * 0.32 + 2) or 1
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
        hb:ClearAllPoints()
        if right then
            hb:SetPoint("TOPLEFT", frame, "TOPLEFT", px, -px)
            hb:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(px + size), px)
        else
            hb:SetPoint("TOPLEFT", frame, "TOPLEFT", px + size, -px)
            hb:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, px)
        end
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
    local s = DB()
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
ev:SetScript("OnEvent", function(_, event, unit)
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
