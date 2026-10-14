--- H3z0UI Bottom Bar support
--- * hides Blizzard's micro menu and bag bar while the Bottom Bar is active
---   (the bar's Menu Icons replace them) and brings them back when the bar is
---   disabled or removed
--- * one-time upgrade of an untouched first-generation Bottom Bar layout

local ADDON_NAME, ns = ...
local H3z0UICore = ns.Addon
if not H3z0UICore then return end

local PANEL_ID = "bottombar"
local FRAME_NAMES = { "MicroMenuContainer", "BagsBar" }

local hider = CreateFrame("Frame", nil, UIParent)
hider:Hide()

local hidden = {}      -- frame -> original parent
local pendingApply = false

local function GetBarConfig()
    local db = H3z0UICore.db and H3z0UICore.db.profile
    local panels = db and db.h3z0uiDatatexts and db.h3z0uiDatatexts.panels
    if not panels then return nil end
    for i, p in ipairs(panels) do
        if p.id == PANEL_ID then return p, i, panels end
    end
end

local function WantsHidden()
    local cfg = GetBarConfig()
    return cfg ~= nil and cfg.enabled == true and cfg.hideBlizzardMenus == true
end

local function Apply()
    if InCombatLockdown() then
        pendingApply = true
        return
    end
    pendingApply = false
    local want = WantsHidden()
    for _, name in ipairs(FRAME_NAMES) do
        local frame = _G[name]
        if frame then
            if want and not hidden[frame] then
                local original = frame:GetParent() or UIParent
                local ok = pcall(frame.SetParent, frame, hider)
                if ok then hidden[frame] = original end
            elseif not want and hidden[frame] then
                pcall(frame.SetParent, frame, hidden[frame] or UIParent)
                hidden[frame] = nil
            end
        end
    end
end

-- Old first-generation layout (before the clock/spec update) -> new layout, only if untouched
local OLD_SLOTS = { "micromenu", "difficulty", "time", "professions", "gold", "bags", "speed", "location" }

local function MigrateOldLayout()
    local cfg, index, panels = GetBarConfig()
    if not cfg or cfg.layoutVersion then return end
    if cfg.numSlots ~= #OLD_SLOTS or type(cfg.slots) ~= "table" then return end
    for i, id in ipairs(OLD_SLOTS) do
        if cfg.slots[i] ~= id then return end
    end
    local new = ns.BottomBarPreset and ns.BottomBarPreset()
    if not new then return end
    new.enabled = cfg.enabled ~= false
    new.locked = cfg.locked and true or false
    if type(cfg.position) == "table" then new.position = cfg.position end
    panels[index] = new
end

-- Older presets (v2: 7 slots, v3: with a separate Great Vault slot) -> current preset, only if untouched.
-- The Great Vault now lives inside the Menu Icons.
local PRESET_HISTORY = {
    [2] = { "micromenu", "playerspec", "clock", "professions", "gold", "bags", "location" },
    [3] = { "micromenu", "playerspec", "clock", "vault", "professions", "gold", "bags", "location" },
}

local function MigratePresetLayout()
    local cfg, index, panels = GetBarConfig()
    if not cfg then return end
    local old = PRESET_HISTORY[cfg.layoutVersion or 0]
    if not old or cfg.numSlots ~= #old or type(cfg.slots) ~= "table" then return end
    for i, id in ipairs(old) do
        if cfg.slots[i] ~= id then return end
    end
    local new = ns.BottomBarPreset and ns.BottomBarPreset()
    if not new then return end
    new.enabled = cfg.enabled ~= false
    new.locked = cfg.locked and true or false
    if type(cfg.position) == "table" then new.position = cfg.position end
    panels[index] = new
end

-- Re-evaluate whenever the panels change
local Datapanels = H3z0UICore.Datapanels
if Datapanels then
    for _, method in ipairs({ "UpdatePanel", "DeletePanel", "RefreshAll" }) do
        if type(Datapanels[method]) == "function" then
            hooksecurefunc(Datapanels, method, function() Apply() end)
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        pcall(MigrateOldLayout)
        pcall(MigratePresetLayout)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then Apply() end
        return
    end
    C_Timer.After(1, Apply)
end)

_G.H3z0UI_RefreshBottomBar = Apply
