local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Chat + Damage Meter windows: skin and background opacity
--   * on the Chat page (Chat & Damage Meter Windows)
--   * in H3z0 UI Edit Mode: right-click the Chat Window or Damage Meter
--     handle (settings panel), with a link to the Chat page
-- Settings: profile.windowSkins (enabled, chat, damageMeter, chatAlpha, meterAlpha)
---------------------------------------------------------------------------

local H3z0UI = _G.H3z0UI
local GUI = H3z0UI and H3z0UI.GUI
if not GUI then return end
local C = GUI.Colors or {}

local W = {}
ns.H3z0UI_WindowsOptions = W

local FORM_ROW = 32

local function Settings()
    local WS = ns.WindowSkins
    local s = WS and WS.GetSettings and WS.GetSettings()
    if s then return s end
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    if not p then return nil end
    p.windowSkins = p.windowSkins or {}
    return p.windowSkins
end

local function Skins()
    if _G.H3z0UI_RefreshWindowSkins then pcall(_G.H3z0UI_RefreshWindowSkins) end
end
local function Alpha()
    if _G.H3z0UI_WindowSkinsAlpha then pcall(_G.H3z0UI_WindowSkinsAlpha) end
end

-- open the options window on the Chat page
function W.OpenChatPage()
    if H3z0UI and H3z0UI.ShowOptions and not (GUI.MainFrame and GUI.MainFrame:IsShown()) then
        pcall(H3z0UI.ShowOptions, H3z0UI)
    end
    local frame = GUI.MainFrame
    if not (frame and GUI.FindV2TileByID and GUI.SelectFeatureTile) then return end
    local _, index = GUI:FindV2TileByID(frame, "h3z_chat")
    if index then GUI:SelectFeatureTile(frame, index, { subPageIndex = 1 }) end
end

-- which: "chat", "meter" or nil (both). Returns the height used.
function W.Build(content, which, opts)
    opts = opts or {}
    local PAD = opts.pad or 10
    local y = opts.y or -10
    local s = Settings()

    local function Place(widget, h)
        widget:SetPoint("TOPLEFT", PAD, y)
        widget:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
        y = y - (h or FORM_ROW)
        return widget
    end
    local function Section(title)
        local header = GUI:CreateSectionHeader(content, title)
        header:SetPoint("TOPLEFT", PAD, y)
        y = y - (header.gap or 30)
    end
    local function Info(text, h)
        local label = GUI:CreateLabel(content, text, 11, C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        if label.SetWordWrap then label:SetWordWrap(true) end
        y = y - (h or 22)
    end

    if not s then
        Info("Chat and damage meter window settings are not loaded.")
        return math.abs(y) + 20
    end
    if s.chatAlpha == nil then s.chatAlpha = s.alpha or 0.9 end
    if s.meterAlpha == nil then s.meterAlpha = s.alpha or 0.9 end

    if not opts.noHeader then
        Section(which == "chat" and "Chat Window" or which == "meter" and "Damage Meter Window" or "Chat & Damage Meter Windows")
    end
    Place(GUI:CreateFormCheckbox(content, "Dark Rounded Windows", "enabled", s, Skins))
    if which ~= "meter" then
        Place(GUI:CreateFormCheckbox(content, "Skin the Chat", "chat", s, Skins))
        Place(GUI:CreateFormSlider(content, "Chat Background Opacity", 0, 1, 0.05, "chatAlpha", s, Alpha, { live = true }))
    end
    if which ~= "chat" then
        Place(GUI:CreateFormCheckbox(content, "Skin the Damage Meter", "damageMeter", s, Skins))
        Place(GUI:CreateFormSlider(content, "Damage Meter Background Opacity", 0, 1, 0.05, "meterAlpha", s, Alpha, { live = true }))
    end
    Info("The opacity is the window's background; text and bars stay fully visible.", 22)

    if opts.link then
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(FORM_ROW)
        local btn = GUI:CreateButton(row, "Open Chat Settings", 180, 24, function() W.OpenChatPage() end)
        btn:SetPoint("LEFT", row, "LEFT", 0, 0)
        Place(row)
    end

    return math.abs(y) + 20
end

---------------------------------------------------------------------------
-- H3z0 UI Edit Mode settings panel for the Chat Window / Damage Meter handles
---------------------------------------------------------------------------
local Settings_ = ns.Settings
local ProviderPanels = Settings_ and Settings_.ProviderPanels
if not (ProviderPanels and type(ProviderPanels.RegisterAfterLoad) == "function") then return end

local function MeterKeys()
    local keys = {}
    local S = Enum and Enum.EditModeSystem
    local BP = ns.BlizzPositions
    if S and S.DamageMeter ~= nil and BP and BP.Key then
        keys[#keys + 1] = "h3zMeter_" .. BP.Key(S.DamageMeter, nil)
        for i = 0, 4 do keys[#keys + 1] = "h3zMeter_" .. BP.Key(S.DamageMeter, i) end
    end
    for i = 2, 10 do keys[#keys + 1] = "h3zMeterWin" .. i end
    return keys
end

ProviderPanels:RegisterAfterLoad(function(ctx)
    local function Provider(which)
        return {
            build = function(content)
                local ok, h = pcall(W.Build, content, which, { link = true })
                if not ok then
                    if geterrorhandler then geterrorhandler()(h) end
                    return 80
                end
                return h
            end,
        }
    end
    ctx.RegisterShared("h3zChat", Provider("chat"))
    local seen = {}
    for _, key in ipairs(MeterKeys()) do
        if not seen[key] then
            seen[key] = true
            ctx.RegisterShared(key, Provider("meter"))
        end
    end
end)

---------------------------------------------------------------------------
-- Features: link the Edit Mode handles (mover keys) to the panels above,
-- with "open in settings" going to the Chat page
---------------------------------------------------------------------------
local ProviderFeatures = Settings_ and Settings_.ProviderFeatures
if ProviderFeatures and type(ProviderFeatures.Register) == "function" then
    local function Feature(id, moverKey)
        pcall(ProviderFeatures.Register, ProviderFeatures, {
            id = id,
            moverKey = moverKey,
            category = "chat",
            nav = { tileId = "h3z_chat", subPageIndex = 1 },
            layoutPositionOnly = false,
            getDB = function(profile) return profile and profile.windowSkins end,
            apply = function() Skins() end,
            providerKey = moverKey,
        })
    end
    Feature("h3zChatWindow", "h3zChat")
    local seen = {}
    for _, key in ipairs(MeterKeys()) do
        if not seen[key] then
            seen[key] = true
            Feature("h3zMeterWindow_" .. key, key)
        end
    end
end
