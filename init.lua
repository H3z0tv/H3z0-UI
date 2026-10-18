-- Keybinding display name (must be global before Bindings.xml loads)
BINDING_NAME_H3z0UI_TOGGLE_OPTIONS = "Open H3z0 UI Options"
BINDING_NAME_H3z0UI_TOGGLE_LAYOUT = "Toggle H3z0 UI Layout Mode"
BINDING_NAME_H3z0UI_TOGGLE_COORDS = "Show / hide map coordinates"

---@type table|AceAddon
H3z0UI = LibStub("AceAddon-3.0"):NewAddon("H3z0UI", "AceConsole-3.0", "AceEvent-3.0")

---@type table
H3z0UI.DF = _G["DetailsFramework"]
H3z0UI.DEBUG_MODE = false

-- Version info
H3z0UI.versionString = C_AddOns.GetAddOnMetadata("H3z0UI", "Version") or "2.00"

---@type table
H3z0UI.defaults = {
    global = {},
    char = {
        ---@type table
        debug = {
            ---@type boolean
            reload = false
        },
        ---@type table
        ncdm = {
            essential = {
                customEntries = { enabled = true, placement = "after", entries = {} },
            },
            utility = {
                customEntries = { enabled = true, placement = "after", entries = {} },
            },
        },
    }
}

function H3z0UI:OnInitialize()
    ---@type AceDBObject-3.0
    self.db = LibStub("AceDB-3.0"):New("H3z0UI_DB", self.defaults, "Default")

    self:RegisterChatCommand("h3z0ui", "SlashCommandOpen")
    self:RegisterChatCommand("rl", "SlashCommandReload")
    
    -- Register our media files with LibSharedMedia
    self:CheckMediaRegistration()
end

-- Quick Keybind Mode shortcut (/kb)
SLASH_H3z0UIKB1 = "/kb"
SlashCmdList["H3z0UIKB"] = function()
    local LibKeyBound = LibStub("LibKeyBound-1.0", true)
    if LibKeyBound then
        LibKeyBound:Toggle()
    elseif QuickKeybindFrame then
        -- Fallback to Blizzard's Quick Keybind Mode (no mousewheel support)
        ShowUIPanel(QuickKeybindFrame)
    else
        print("|cff34D399H3z0 UI:|r Quick Keybind Mode not available.")
    end
end

-- Cooldown Settings shortcut (/cdm)
SLASH_H3z0UI_CDM1 = "/cdm"
SlashCmdList["H3z0UI_CDM"] = function()
    if CooldownViewerSettings then
        CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown())
    else
        print("|cff34D399H3z0 UI:|r Cooldown Settings not available. Enable CDM first.")
    end
end

function H3z0UI:SlashCommandOpen(input)
    if input and input == "debug" then
        self.db.char.debug.reload = true
        H3z0UI:SafeReload()
    elseif input and (input == "setup" or input == "wizard" or input == "setup wizard") then
        -- Open the Setup Wizard (device / nameplates / features)
        if _G.H3z0UI_Setup then
            _G.H3z0UI_Setup.Show()
        else
            print("|cFF56D1FFH3z0 UI:|r Setup wizard not loaded.")
        end
        return
    elseif input and (input == "deck setup" or input == "decksetup" or input == "handheld setup") then
        -- Open the Steam Deck setup window
        if _G.H3z0UI_Handheld then
            _G.H3z0UI_Handheld.ShowSetupPopup()
        else
            print("|cFF56D1FFH3z0 UI:|r Handheld module not loaded.")
        end
        return
    elseif input and (input == "pchandheld" or input == "pcdeck") then
        -- PC Handheld: Steam Deck layout + ConsolePort with the PC UI scale
        if _G.H3z0UI_Handheld and _G.H3z0UI_Handheld.TogglePCHandheld then
            _G.H3z0UI_Handheld.TogglePCHandheld()
        end
        return
    elseif input and (input == "controller" or input == "pad") then
        -- PC Controller: PC layout + ConsolePort (Action Combat Mode off)
        if _G.H3z0UI_Handheld and _G.H3z0UI_Handheld.TogglePCController then
            _G.H3z0UI_Handheld.TogglePCController()
        end
        return
    elseif input and (input == "deck" or input == "handheld") then
        -- Toggle Handheld / Steam Deck Mode
        if _G.H3z0UI_Handheld then
            _G.H3z0UI_Handheld.Toggle()
        else
            print("|cFF56D1FFH3z0 UI:|r Handheld module not loaded.")
        end
        return
    elseif input and (input == "style" or input == "portraits") then
        -- Round Portrait frame style (test) on/off
        if _G.H3z0UI_ToggleFrameStyle then
            local on = _G.H3z0UI_ToggleFrameStyle()
            print("|cFF30D1FFH3z0 UI:|r Frame style " .. (on and "|cff00ff00on|r" or "|cffff4040off|r"))
        end
        return
    elseif input and (input == "bars" or input == "compact") then
        -- Compact action bar layout (test) on/off
        if _G.H3z0UI_ToggleCompactBars then _G.H3z0UI_ToggleCompactBars() end
        return
    elseif input and (input == "coords" or input == "coordinates") then
        if _G.H3z0UI_ToggleMapCoords then _G.H3z0UI_ToggleMapCoords() end
        return
    elseif input and (input == "layout" or input == "move" or input == "unlock") then
        -- H3z0 UI Layout Mode (drag every H3z0 UI frame)
        if _G.H3z0UI_ToggleLayoutMode then
            _G.H3z0UI_ToggleLayoutMode()
        else
            print("|cFF56D1FFH3z0 UI:|r Layout Mode not loaded.")
        end
        return
    elseif input and input == "ring" then
        local hh = _G.H3z0UI_Handheld
        if hh and hh.DebugTargetRing then hh.DebugTargetRing() end
        if hh and hh.EnsureTargetRing then hh.EnsureTargetRing() end
        return
    elseif input and input == "modern" then
        if _G.H3z0UI_ToggleModernLook then
            local on = _G.H3z0UI_ToggleModernLook()
            print("|cff34D399H3z0 UI:|r Modern Look " .. (on and "|cff00ff00ON|r" or "|cffff5555OFF|r"))
        end
        return
    elseif input and input == "streamer" then
        local core = _G.H3z0UI and (_G.H3z0UI.H3z0UICore or _G.H3z0UI)
        local g = core and core.db and core.db.profile and core.db.profile.actionBars and core.db.profile.actionBars.global
        if g then
            g.streamerMode = not g.streamerMode
            if _G.H3z0UI_ApplyStreamerMode then _G.H3z0UI_ApplyStreamerMode() end
            print("|cff34D399H3z0 UI:|r Streamer Mode " .. (g.streamerMode and "|cff00ff00ON|r - button press highlight hidden." or "|cffff5555OFF|r"))
        end
        return
    elseif input and (input == "round" or input == "rounddebug") then
        local function P(k, v) print("|cff34D399H3z0 UI:|r " .. k .. ": " .. tostring(v)) end
        local core = _G.H3z0UI and (_G.H3z0UI.H3z0UICore or _G.H3z0UI)
        local prof = core and core.db and core.db.profile
        local ml = prof and prof.modernLook or {}
        local ws = prof and prof.windowSkins or {}
        local mm = prof and prof.minimap or {}
        P("Rounded Corners", ml.rounded)
        P("Modern Look", ml.enabled)
        P("Modern Action Buttons", ml.buttons)
        P("Modern Cast Bars", ml.castbars)
        P("Window Skins", ws.enabled)
        P("Minimap shape", mm.shape)
        P("Rounded helper loaded", _G.H3z0UI_RefreshWindowSkins ~= nil)
        -- do the new texture files load? (new files need a full game restart, not just /reload)
        local test = UIParent:CreateTexture()
        for _, f in ipairs({ "h3z_circle", "h3z_corner_tl", "h3z_roundsquare", "h3z_roundend_r" }) do
            test:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\" .. f)
            local id = test.GetTextureFileID and test:GetTextureFileID()
            P("Texture " .. f, (id and id ~= 0) and ("loaded (" .. tostring(id) .. ")") or "NOT FOUND")
        end
        test:Hide()
        local mmMask = Minimap and Minimap.h3zLastMask
        P("Minimap mask", mmMask or "not set by H3z0 UI")
        P("Minimap mask replaced by something else", Minimap and Minimap.h3zForeignMask or "no")
        if Minimap and Minimap.h3zForeignBy then P("  replaced from", Minimap.h3zForeignBy) end
        if _G.H3z0UI_DebugWindowSkins then P("Chat", _G.H3z0UI_DebugWindowSkins()) end
        if _G.H3z0UI_DebugModernButtons then P("Buttons", _G.H3z0UI_DebugModernButtons()) end
        if _G.H3z0UI_RefreshModernLook then _G.H3z0UI_RefreshModernLook() end
        if _G.H3z0UI_RefreshWindowSkins then _G.H3z0UI_RefreshWindowSkins() end
        if _G.H3z0UI_ApplyModernButtons then _G.H3z0UI_ApplyModernButtons() end
        return
    elseif input and input == "roundtest" then
        -- three 160x160 squares, each rounded a different way: shows which way the client draws
        local A = "Interface\\AddOns\\H3z0UI\\assets\\"
        local f = _G.H3z0UI_RoundTest or CreateFrame("Frame", "H3z0UI_RoundTest", UIParent)
        f:SetSize(560, 200)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:Show()
        local function Box(i, r, g, b, label)
            local t = f["t" .. i] or f:CreateTexture(nil, "ARTWORK")
            f["t" .. i] = t
            t:SetColorTexture(r, g, b, 1)
            t:SetSize(160, 160)
            t:ClearAllPoints()
            t:SetPoint("LEFT", f, "LEFT", (i - 1) * 190 + 10, 0)
            local fs = f["l" .. i] or f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            f["l" .. i] = fs
            fs:SetPoint("BOTTOM", t, "TOP", 0, 4)
            fs:SetText(label)
            return t
        end
        local t1 = Box(1, 0.9, 0.2, 0.2, "1: corner masks")
        local t2 = Box(2, 0.2, 0.8, 0.3, "2: round square")
        local t3 = Box(3, 0.2, 0.5, 1.0, "3: round end")
        local R = _G.H3z0UI_RoundLib
        if R and not f.done1 then
            f.done1 = true
            R.Mask(t1, R.CornerMasks(f, t1, 40, 0, "testMasks"), true)
        end
        if not f.m2 then
            f.m2 = f:CreateMaskTexture()
            f.m2:SetTexture(A .. "h3z_roundsquare", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            f.m2:SetAllPoints(t2)
            t2:AddMaskTexture(f.m2)
            f.m3 = f:CreateMaskTexture()
            f.m3:SetTexture(A .. "h3z_roundend_r", "CLAMP", "CLAMP")
            f.m3:SetPoint("TOPRIGHT", t3, "TOPRIGHT")
            f.m3:SetPoint("BOTTOMRIGHT", t3, "BOTTOMRIGHT")
            f.m3:SetWidth(80)
            t3:AddMaskTexture(f.m3)
        end
        print("|cff34D399H3z0 UI:|r round test shown for 20 seconds - please take a screenshot.")
        C_Timer.After(20, function() f:Hide() end)
        return
    elseif input and (input == "plates" or input == "nameplates") then
        if _G.H3z0UI_TogglePlates then
            local on = _G.H3z0UI_TogglePlates()
            print("|cff34D399H3z0 UI:|r H3z0 Nameplates " .. (on and "|cff00ff00ON|r" or "|cffff5555OFF|r"))
        end
        return
    elseif input and (input == "whatsnew" or input == "news" or input == "changelog") then
        if _G.H3z0UI_ShowWhatsNew then _G.H3z0UI_ShowWhatsNew() end
        return
    elseif input and input == "export" then
        if _G.H3z0UI_ExportLayout then _G.H3z0UI_ExportLayout() end
        return
    elseif input and input == "import" then
        if _G.H3z0UI_ImportLayout then _G.H3z0UI_ImportLayout() end
        return
    elseif input and (input == "cdm" or input == "cdmfix") then
        -- Cooldown Manager repair: why Essential / Tracked Bars don't show
        if _G.H3z0UI_CDMDoctor then _G.H3z0UI_CDMDoctor() end
        return
    elseif input and (input == "blizzedit" or input == "blizzardedit") then
        -- Blizzard's own Edit Mode (only for its size / row settings)
        if _G.H3z0UI_OpenBlizzardEditMode then _G.H3z0UI_OpenBlizzardEditMode() end
        return
    elseif input and input == "editmode" then
        -- One edit mode: H3z0 UI Layout Mode
        if _G.H3z0UI_ToggleLayoutMode then _G.H3z0UI_ToggleLayoutMode() return end
        -- Toggle Unit Frames Edit Mode
        if _G.H3z0UI_ToggleUnitFrameEditMode then
            _G.H3z0UI_ToggleUnitFrameEditMode()
        else
            print("|cFF56D1FFH3z0 UI:|r Unit Frames module not loaded.")
        end
        return
    end
    
    -- Default: Open custom GUI
    if self.GUI then
        self.GUI:Toggle()
    else
        print("|cFF56D1FFH3z0 UI:|r GUI not loaded yet. Try again in a moment.")
    end
end

function H3z0UI:SlashCommandReload()
    H3z0UI:SafeReload()
end

function H3z0UI:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Initialize H3z0UICore (AceDB-based integration)
    if self.H3z0UICore then
        -- Show intro message if enabled (defaults to true)
        if self.db.profile.chat.showIntroMessage ~= false then
            print("|cFF30D1FFH3z0 UI|r loaded. |cFFFFFF00/h3z0ui|r to setup.")
            print("|cFF30D1FFH3z0 UI REMINDER:|r")
            print("|cFF34D3991.|r ENABLE |cFFFFFF00Cooldown Manager|r in Options > Gameplay Enhancement")
            print("|cFF34D3992.|r Action Bars & Menu Bar |cFFFFFF00HIDDEN|r on mouseover |cFFFFFF00by default|r. Go to |cFFFFFF00'Actionbars'|r tab in |cFFFFFF00/h3z0ui|r to unhide.")
            print("|cFF34D3993.|r Use |cFFFFFF00100% Icon Size|r on CDM Essential & Utility bars via |cFFFFFF00Edit Mode|r for best results.")
            print("|cFF34D3994.|r Position your |cFFFFFF00CDM bars|r in |cFFFFFF00Edit Mode|r and click |cFFFFFF00Save|r before exiting.")
        end
    end
end

function H3z0UI:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
    H3z0UI:BackwardsCompat()

    -- Ensure debug table exists
    if not self.db.char.debug then
        self.db.char.debug = { reload = false }
    end

    if not self.DEBUG_MODE then
        if self.db.char.debug.reload then
            self.DEBUG_MODE = true
            self.db.char.debug.reload = false
            self:DebugPrint("Debug Mode Enabled")
        end
    else
        self:DebugPrint("Debug Mode Enabled")
    end
end

function H3z0UI:DebugPrint(...)
    if self.DEBUG_MODE then
        self:Print(...)
    end
end

-- ADDON COMPARTMENT FUNCTIONS --
function H3z0UI_CompartmentClick()
    -- Open the new GUI
    if H3z0UI.GUI then
        H3z0UI.GUI:Toggle()
    end
end

local GameTooltip = GameTooltip
function H3z0UI_CompartmentOnEnter(self, button)
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(type(self) ~= "string" and self or button, "ANCHOR_LEFT")
    GameTooltip:AddLine("H3z0 UI v" .. H3z0UI.versionString)
    GameTooltip:AddLine("Left Click: Open Options")
    GameTooltip:Show()
end

function H3z0UI_CompartmentOnLeave()
    GameTooltip:Hide()
end
