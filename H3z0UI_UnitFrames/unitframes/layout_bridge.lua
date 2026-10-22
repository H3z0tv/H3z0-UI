local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI frames in Layout Mode
-- Puts the H3z0 unit frames, party frames and raid frames into Layout Mode.
-- The positions stay where these frames always kept them (their own
-- settings), so the frames are never moved by two systems at once:
--   unit frames  -> h3z0uiUnitFrames.<unit>.offsetX / offsetY (CENTER of the screen)
--   party / raid -> partyFrames.pos / raidFrames.pos
---------------------------------------------------------------------------

local function Profile()
    local core = ns.Addon
    return core and core.db and core.db.profile
end

local function UFSettings(unit)
    local p = Profile()
    local uf = p and p.h3z0uiUnitFrames
    return uf and uf[unit]
end

local function UF()
    return ns.H3z0UI_UnitFrames
end

local function Round(v)
    v = tonumber(v) or 0
    if v >= 0 then return math.floor(v + 0.5) end
    return math.ceil(v - 0.5)
end

-- CENTER offsets of a frame relative to the screen center
local function CenterOffsets(frame)
    if not (frame and frame.GetCenter) then return nil end
    local cx, cy = frame:GetCenter()
    if not (cx and cy) then return nil end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local ux, uy = UIParent:GetCenter()
    return Round(cx * scale - ux), Round(cy * scale - uy)
end

local function Refresh(fnName)
    local fn = _G[fnName]
    if type(fn) == "function" then pcall(fn) end
end

local function ReloadPrompt()
    local H = _G.H3z0UI
    local GUI = H and H.GUI
    if GUI and GUI.ShowConfirmation then
        GUI:ShowConfirmation({
            reload = true,
            title = "Reload UI?",
            message = "Turning H3z0 UI frames on or off needs a reload.",
            acceptText = "Reload",
            cancelText = "Later",
            onAccept = function() H:SafeReload() end,
        })
    end
end

local UNIT_ELEMENTS = {
    { key = "h3zPlayerFrame", label = "Player Frame",      unit = "player",       order = 1 },
    { key = "h3zTargetFrame", label = "Target Frame",      unit = "target",       order = 2 },
    { key = "h3zToTFrame",    label = "Target of Target",  unit = "targettarget", order = 3 },
    { key = "h3zFocusFrame",  label = "Focus Frame",       unit = "focus",        order = 4 },
    { key = "h3zPetFrame",    label = "Pet Frame",         unit = "pet",          order = 5 },
    { key = "h3zBossFrames",  label = "Boss Frames",       unit = "boss",         order = 6, frame = "boss1" },
}

local function RegisterUnitFrames(lm)
    for _, info in ipairs(UNIT_ELEMENTS) do
        local frameKey = info.frame or info.unit
        local function GetFrame()
            local uf = UF()
            return uf and uf.frames and uf.frames[frameKey]
        end
        lm:RegisterElement({
            key = info.key,
            label = info.label,
            group = "H3z0 Unit Frames",
            order = info.order,
            isOwned = false,
            usesCustomPositionPersistence = true,
            getFrame = GetFrame,
            isEnabled = function()
                local s = UFSettings(info.unit)
                return s and s.enabled ~= false or false
            end,
            setEnabled = function(val)
                local s = UFSettings(info.unit)
                if not s then return end
                local old = s.enabled ~= false
                s.enabled = val
                if (val ~= false) ~= old then ReloadPrompt() end
            end,
            loadPosition = function()
                local s = UFSettings(info.unit)
                if not s then return nil end
                return "CENTER", "CENTER", s.offsetX or 0, s.offsetY or 0
            end,
            savePosition = function(_, point, relPoint, x, y)
                local s = UFSettings(info.unit)
                if not s then return end
                if point == "CENTER" and (relPoint == nil or relPoint == "CENTER") then
                    s.offsetX, s.offsetY = Round(x), Round(y)
                else
                    local ox, oy = CenterOffsets(GetFrame())
                    if ox then s.offsetX, s.offsetY = ox, oy end
                end
                Refresh("H3z0UI_RefreshUnitFrames")
            end,
            onOpen = function()
                if _G.H3z0UI_ShowUnitFramePreview then pcall(_G.H3z0UI_ShowUnitFramePreview, info.unit) end
            end,
            onClose = function()
                if _G.H3z0UI_HideUnitFramePreview then pcall(_G.H3z0UI_HideUnitFramePreview, info.unit) end
            end,
        })
    end
end

local GROUP_ELEMENTS = {
    {
        key = "h3zPartyFrames", label = "Party Frames", db = "partyFrames", order = 10,
        frame = "H3z0UI_PartyFrames", refresh = "H3z0UI_RefreshPartyFrames",
        isTest = "H3z0UI_PartyFramesIsTest", setTest = "H3z0UI_PartyFramesSetTest",
    },
    {
        key = "h3zRaidFrames", label = "Raid Frames", db = "raidFrames", order = 11,
        frame = "H3z0UI_RaidFrames", refresh = "H3z0UI_RefreshRaidFrames",
        isTest = "H3z0UI_RaidFramesIsTest", setTest = "H3z0UI_RaidFramesSetTest",
    },
}

local function RegisterGroupFrames(lm)
    for _, info in ipairs(GROUP_ELEMENTS) do
        local startedTest = false
        local function Settings()
            local p = Profile()
            return p and p[info.db]
        end
        lm:RegisterElement({
            key = info.key,
            label = info.label,
            group = "H3z0 Unit Frames",
            order = info.order,
            isOwned = false,
            usesCustomPositionPersistence = true,
            getFrame = function() return _G[info.frame] end,
            isEnabled = function()
                local s = Settings()
                return s and s.enabled ~= false or false
            end,
            setEnabled = function(val)
                local s = Settings()
                if not s then return end
                local old = s.enabled ~= false
                s.enabled = val
                if (val ~= false) ~= old then ReloadPrompt() end
            end,
            loadPosition = function()
                local s = Settings()
                local pos = s and s.pos
                if pos and pos.point then
                    return pos.point, pos.relPoint or pos.point, pos.x or 0, pos.y or 0
                end
                local f = _G[info.frame]
                local ox, oy = CenterOffsets(f)
                if ox then return "CENTER", "CENTER", ox, oy end
                return nil
            end,
            savePosition = function(_, point, relPoint, x, y)
                local s = Settings()
                if not s then return end
                s.pos = { point = point or "CENTER", relPoint = relPoint or point or "CENTER", x = Round(x), y = Round(y) }
                local f = _G[info.frame]
                if f and not InCombatLockdown() then
                    f:ClearAllPoints()
                    f:SetPoint(s.pos.point, UIParent, s.pos.relPoint, s.pos.x, s.pos.y)
                end
                Refresh(info.refresh)
            end,
            onOpen = function()
                local isTest, setTest = _G[info.isTest], _G[info.setTest]
                if type(isTest) == "function" and type(setTest) == "function" and not isTest() then
                    startedTest = true
                    pcall(setTest, true)
                end
            end,
            onClose = function()
                local setTest = _G[info.setTest]
                if startedTest and type(setTest) == "function" then pcall(setTest, false) end
                startedTest = false
            end,
        })
    end
end

---------------------------------------------------------------------------
-- Cast bars (player / target / focus): the place stays in
-- h3z0uiUnitFrames.<unit>.castbar.offsetX / offsetY, whatever the bar is
-- anchored to (free on the screen, under the unit frame, under the Essential
-- or Utility cooldowns). Layout Mode moves it by the distance you drag it.
---------------------------------------------------------------------------
local CASTBAR_ELEMENTS = {
    { key = "h3zPlayerCastbar", label = "Player Cast Bar", unit = "player", order = 20 },
    { key = "h3zTargetCastbar", label = "Target Cast Bar", unit = "target", order = 21 },
    { key = "h3zFocusCastbar",  label = "Focus Cast Bar",  unit = "focus",  order = 22 },
}

local function CastbarSettings(unit)
    local s = UFSettings(unit)
    return s and s.castbar
end

local function CastbarFrame(unit)
    local cb = _G.H3z0UI_Castbars
    if type(cb) ~= "table" then
        local uf = UF()
        cb = uf and uf.castbars
    end
    return type(cb) == "table" and cb[unit] or nil
end

-- centre offset from the screen centre, in UIParent units
local function CenterUI(frame)
    if not (frame and frame.GetCenter) then return nil end
    local cx, cy = frame:GetCenter()
    if not (cx and cy) then return nil end
    local k = (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local ux, uy = UIParent:GetCenter()
    return cx * k - ux, cy * k - uy
end

local function RegisterCastbars(lm)
    for _, info in ipairs(CASTBAR_ELEMENTS) do
        local openCenter
        lm:RegisterElement({
            key = info.key,
            label = info.label,
            group = "H3z0 Unit Frames",
            order = info.order,
            isOwned = false,
            usesCustomPositionPersistence = true,
            getFrame = function() return CastbarFrame(info.unit) end,
            isEnabled = function()
                local cs = CastbarSettings(info.unit)
                local us = UFSettings(info.unit)
                return cs and cs.enabled ~= false and (not us or us.enabled ~= false) and CastbarFrame(info.unit) ~= nil or false
            end,
            setEnabled = function(val)
                local cs = CastbarSettings(info.unit)
                if not cs then return end
                local old = cs.enabled ~= false
                cs.enabled = val
                if (val ~= false) ~= old then
                    Refresh("H3z0UI_RefreshCastbars")
                    if val and not CastbarFrame(info.unit) then ReloadPrompt() end
                end
            end,
            loadPosition = function()
                local x, y = CenterUI(CastbarFrame(info.unit))
                if not x then return nil end
                return "CENTER", "CENTER", Round(x), Round(y)
            end,
            savePosition = function(_, point, relPoint, x, y)
                local cs = CastbarSettings(info.unit)
                if not (cs and openCenter) then return end
                -- Layout Mode hands back the new centre (CENTER / CENTER offsets)
                local nx, ny = x, y
                if not (point == "CENTER" and (relPoint == nil or relPoint == "CENTER")) then
                    nx, ny = CenterUI(CastbarFrame(info.unit))
                end
                if not nx then return end
                local dx, dy = nx - openCenter[1], ny - openCenter[2]
                cs.offsetX = Round((cs.offsetX or 0) + dx)
                cs.offsetY = Round((cs.offsetY or 0) + dy)
                if (cs.anchor or "none") == "none" then
                    cs.freeOffsetX, cs.freeOffsetY = cs.offsetX, cs.offsetY
                end
                openCenter = { nx, ny }
                Refresh("H3z0UI_RefreshCastbars")
            end,
            onOpen = function()
                local x, y = CenterUI(CastbarFrame(info.unit))
                openCenter = x and { x, y } or nil
                if _G.H3z0UI_ShowCastbarPreview then pcall(_G.H3z0UI_ShowCastbarPreview, info.unit) end
                -- the preview may have just placed the bar: take its centre again
                local x2, y2 = CenterUI(CastbarFrame(info.unit))
                if x2 then openCenter = { x2, y2 } end
            end,
            onClose = function()
                if _G.H3z0UI_HideCastbarPreview then pcall(_G.H3z0UI_HideCastbarPreview, info.unit) end
                openCenter = nil
                C_Timer.After(0, function() Refresh("H3z0UI_RefreshCastbars") end)
            end,
        })
    end
end

local registered = false
local function Register()
    if registered then return end
    local lm = ns.H3z0UI_LayoutMode
    if not (lm and lm.RegisterElement) then return end
    registered = true
    local ok, err = pcall(RegisterUnitFrames, lm)
    if not ok and geterrorhandler then geterrorhandler()(err) end
    ok, err = pcall(RegisterGroupFrames, lm)
    if not ok and geterrorhandler then geterrorhandler()(err) end
    ok, err = pcall(RegisterCastbars, lm)
    if not ok and geterrorhandler then geterrorhandler()(err) end
    -- Layout Mode puts frames back on close without their own scale: put the
    -- H3z0 frames on their saved positions again right after
    if lm.RegisterExitCallback then
        lm:RegisterExitCallback(function()
            C_Timer.After(0, function()
                Refresh("H3z0UI_RefreshUnitFrames")
                Refresh("H3z0UI_RefreshPartyFrames")
                Refresh("H3z0UI_RefreshRaidFrames")
                Refresh("H3z0UI_RefreshCastbars")
            end)
        end)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(1, Register)
end)
if IsLoggedIn and IsLoggedIn() then C_Timer.After(1, Register) end
