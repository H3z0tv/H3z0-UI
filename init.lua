-- Keybinding display name (must be global before Bindings.xml loads)
BINDING_NAME_H3z0UI_TOGGLE_OPTIONS = "Open H3z0 UI Options"

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
    elseif input and (input == "deck" or input == "handheld") then
        -- Toggle Handheld / Steam Deck Mode
        if _G.H3z0UI_Handheld then
            _G.H3z0UI_Handheld.Toggle()
        else
            print("|cFF56D1FFH3z0 UI:|r Handheld module not loaded.")
        end
        return
    elseif input and input == "editmode" then
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
