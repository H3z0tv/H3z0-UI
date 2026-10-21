local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI action bars: one-time move from Blizzard's bars to H3z0 UI's own
-- bar frames. Each bar keeps:
--   * its place: the one you gave it in H3z0 UI Edit Mode (PC / Deck layout)
--   * its size: icon size, padding, rows and icon count from Blizzard's
--     Edit Mode settings of that bar
-- Runs once per profile; bars you already set up on the new bars are left alone.
---------------------------------------------------------------------------

local BASE_BUTTON = 45   -- Blizzard's action button at 100% icon size

-- Blizzard bar -> H3z0 UI bar key, Edit Mode system index, Layout Mode key
local BARS = {
    { key = "bar1", index = 1, frame = "MainActionBar", fa = "bar1", alt = "MainMenuBar" },
    { key = "bar2", index = 2, frame = "MultiBarBottomLeft", fa = "bar2" },
    { key = "bar3", index = 3, frame = "MultiBarBottomRight", fa = "bar3" },
    { key = "bar4", index = 4, frame = "MultiBarRight", fa = "bar4" },
    { key = "bar5", index = 5, frame = "MultiBarLeft", fa = "bar5" },
    { key = "bar6", index = 6, frame = "MultiBar5", fa = "bar6" },
    { key = "bar7", index = 7, frame = "MultiBar6", fa = "bar7" },
    { key = "bar8", index = 8, frame = "MultiBar7", fa = "bar8" },
    { key = "stance", index = 11, frame = "StanceBar", fa = "stanceBar" },
    { key = "pet", index = 12, frame = "PetActionBar", fa = "petBar" },
}

local function Profile()
    local core = ns.Addon
    return core and core.db and core.db.profile
end

local function Round(v)
    v = tonumber(v) or 0
    if v >= 0 then return math.floor(v + 0.5) end
    return math.ceil(v - 0.5)
end

local function Setting(frame, setting)
    if not (frame and frame.GetSettingValue and setting ~= nil) then return nil end
    local ok, v = pcall(frame.GetSettingValue, frame, setting)
    if ok and type(v) == "number" then return v end
    return nil
end

local function SavedPlace(p, index)
    local BP = ns.BlizzPositions
    local S = Enum and Enum.EditModeSystem
    if not (BP and BP.Key and S and S.ActionBar) then return nil end
    local LS = ns.LayoutSets
    local mode = (LS and LS.CurrentMode and LS.CurrentMode()) or "pc"
    local store = p.blizzPositions and p.blizzPositions[mode]
    local pos = store and store[BP.Key(S.ActionBar, index)]
    if type(pos) == "table" and pos.x and pos.y then return pos end
    return nil
end

local function ImportBar(p, info)
    local bars = p.actionBars and p.actionBars.bars
    local cfg = bars and bars[info.key]
    if type(cfg) ~= "table" then return end
    local frame = _G[info.frame] or (info.alt and _G[info.alt])

    -- size and shape from Blizzard's Edit Mode settings of that bar
    local AS = Enum and Enum.EditModeActionBarSetting
    if frame and AS and info.index <= 8 then
        local iconSize = Setting(frame, AS.IconSize)
        local padding = Setting(frame, AS.IconPadding)
        local rows = Setting(frame, AS.NumRows)
        local icons = Setting(frame, AS.NumIcons)
        local orientation = Setting(frame, AS.Orientation)
        if iconSize and iconSize > 0 then
            cfg.ownedLayout = type(cfg.ownedLayout) == "table" and cfg.ownedLayout or {}
            local ol = cfg.ownedLayout
            local scale = iconSize / 100
            ol.buttonSize = Round(BASE_BUTTON * scale)
            if padding then ol.buttonSpacing = Round(padding * scale) end
            if icons and icons > 0 then ol.iconCount = icons end
            if rows and rows > 0 then
                ol.columns = math.ceil((ol.iconCount or 12) / rows)
            end
            if orientation ~= nil then
                ol.orientation = (orientation == 1) and "vertical" or "horizontal"
            end
        end
    end

    -- place: where you put it in H3z0 UI Edit Mode
    local pos = SavedPlace(p, info.index)
    p.frameAnchoring = p.frameAnchoring or {}
    if pos then
        p.frameAnchoring[info.fa] = {
            parent = "screen", point = "CENTER", relative = "CENTER",
            offsetX = Round(pos.x), offsetY = Round(pos.y),
        }
    elseif info.index <= 3 then
        -- not placed by you: bars 1-3 start from the H3z0 layout (stacked above the Bottom Bar)
        local d = ns.defaults and ns.defaults.profile and ns.defaults.profile.frameAnchoring
        d = d and d[info.fa]
        if type(d) == "table" then
            local copy = {}
            for k, v in pairs(d) do copy[k] = v end
            p.frameAnchoring[info.fa] = copy
        end
    end
end

local function Run()
    local p = Profile()
    if not p or p._h3zOwnedBarsImported then return end
    if InCombatLockdown() then return false end
    -- Blizzard's Edit Mode settings must be there
    local mgr = _G.EditModeManagerFrame
    if not (mgr and mgr.GetActiveLayoutInfo) then return false end
    local ok, layout = pcall(mgr.GetActiveLayoutInfo, mgr)
    if not ok or type(layout) ~= "table" then return false end

    for _, info in ipairs(BARS) do
        local okBar, err = pcall(ImportBar, p, info)
        if not okBar and geterrorhandler then geterrorhandler()(err) end
    end
    p._h3zOwnedBarsImported = true

    if _G.H3z0UI_RefreshActionBars then pcall(_G.H3z0UI_RefreshActionBars) end
    if _G.H3z0UI_ApplyFrameAnchor then
        for _, info in ipairs(BARS) do pcall(_G.H3z0UI_ApplyFrameAnchor, info.fa) end
    end
    return true
end

local tries = 0
local function TryRun()
    tries = tries + 1
    local done = Run()
    if done == false and tries < 10 then C_Timer.After(1, TryRun) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(1.5, TryRun)
end)
