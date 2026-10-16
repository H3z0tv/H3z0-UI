--[[
    H3z0UI Options - Nameplates Tab  (0.22)
    Everything about nameplates in one place:
      * H3z0 UI's Plater profile  - one-click import when Plater is installed (+ copy box)
      * H3z0 UI's Platynator profile - copy box + button that opens Platynator's settings
      * H3z0 UI's BetterBlizzPlates profile - copy box + button that opens BetterBlizzPlates' settings
      * Friendly nameplate hiding (moved here from Skinning & Autohide)
]]

local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options

local PLATER_PROFILE_NAME = "H3z0 UI"

local function IsLoaded(addon)
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon)) and true or false
end

local function GetImportData(key)
    local imports = _G.H3z0UI and _G.H3z0UI.imports
    local entry = imports and imports[key]
    local data = entry and entry.data or ""
    return (data:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Say(msg)
    print("|cff34D399H3z0 UI:|r " .. msg)
end

---------------------------------------------------------------------------
-- Small scrollable copy box (same look as the Import tab)
---------------------------------------------------------------------------
local function CreateCopyBox(parent, height, text)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetHeight(height)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container:SetBackdropColor(0.1, 0.1, 0.1, 1)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)

    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName() .. "ScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 18)
    end

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() or 400)
    editBox:SetText(text or "")
    editBox:SetCursorPosition(0)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    container:SetScript("OnSizeChanged", function(self)
        editBox:SetWidth(math.max(50, self:GetWidth() - 36))
    end)
    scrollFrame:SetScrollChild(editBox)

    container.editBox = editBox
    return container
end

---------------------------------------------------------------------------
-- Plater: one-click import (Plater.ImportAndSwitchProfile creates/switches to its own profile,
-- so the player's existing Plater profiles are not overwritten)
---------------------------------------------------------------------------
StaticPopupDialogs["H3Z0UI_PLATER_IMPORT"] = {
    text = "Import the H3z0 UI profile into Plater?\n\nPlater switches to a profile named \"" .. PLATER_PROFILE_NAME ..
           "\" (your other Plater profiles stay as they are) and reloads the UI.",
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
        local data = GetImportData("Plater")
        local plater = _G.Plater
        if data == "" then
            Say("No Plater string is bundled with this build.")
            return
        end
        if not (plater and plater.ImportAndSwitchProfile) then
            Say("Plater is not loaded - enable it on the character select screen and try again.")
            return
        end
        local ok, err = pcall(plater.ImportAndSwitchProfile, PLATER_PROFILE_NAME, data, false, false, false)
        if ok then
            Say("Plater profile imported. If the UI did not reload, type |cffFFFF00/reload|r.")
        else
            Say("Plater import failed: " .. tostring(err) .. "  -  use the copy box and Plater's own Import instead.")
        end
    end,
}

---------------------------------------------------------------------------
-- Platynator: find its slash command at runtime and run it (opens its settings)
---------------------------------------------------------------------------
local function OpenAddonSettings(addon, slashPattern)
    if not IsLoaded(addon) then
        Say(addon .. " is not loaded - install/enable it first.")
        return
    end
    local cmd
    for key, value in pairs(_G) do
        if type(key) == "string" and key:match("^SLASH_") and type(value) == "string"
           and value:lower():match(slashPattern) then
            cmd = value
            break
        end
    end
    if not cmd then
        Say("Could not find " .. addon .. "'s slash command - open its settings from Game Menu > Options > AddOns.")
        return
    end
    local box = ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend()
    if box and ChatEdit_SendText then
        box:SetText(cmd)
        ChatEdit_SendText(box)
    else
        Say("Type |cffFFFF00" .. cmd .. "|r to open Platynator.")
    end
end

local function OpenPlatynatorSettings() OpenAddonSettings("Platynator", "^/platy") end
local function OpenBetterBlizzPlatesSettings() OpenAddonSettings("BetterBlizzPlates", "^/bbp") end

local tabRef
local Build

local function Rebuild()
    if not tabRef or not Build then return end
    for _, child in ipairs({tabRef:GetChildren()}) do
        child:Hide()
        child:ClearAllPoints()
    end
    for _, region in ipairs({tabRef:GetRegions()}) do
        region:Hide()
    end
    Build(tabRef)
end

Build = function(tabContent)
    tabRef = tabContent
    local y = -10
    local FORM_ROW = 32
    local PAD = Shared.PADDING
    local db = Shared.GetDB()
    if not db then return end

    GUI:SetSearchContext({tabIndex = 1, tabName = "H3z0 Features", subTabIndex = 5, subTabName = "Nameplates"})

    local boxes = {}
    local function SelectOnly(target)
        for _, eb in ipairs(boxes) do
            if eb ~= target then
                eb:ClearFocus()
                eb:HighlightText(0, 0)
            end
        end
        target:SetFocus()
        target:HighlightText()
    end

    local function Section(title)
        GUI:SetSearchSection(title)
        local header = GUI:CreateSectionHeader(tabContent, title)
        header:SetPoint("TOPLEFT", PAD, y)
        y = y - header.gap
    end

    local function Info(text, h, color)
        local label = GUI:CreateLabel(tabContent, text, 10, color or C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        y = y - (h or 20)
    end

    local function Status(addon)
        if IsLoaded(addon) then
            Info(addon .. ": installed and loaded", 18, {0.2, 0.9, 0.5, 1})
        else
            Info(addon .. ": not installed / not loaded", 18, {1, 0.4, 0.4, 1})
        end
    end

    local function CopyBox(key)
        local data = GetImportData(key)
        local box = CreateCopyBox(tabContent, 70, data)
        box:SetPoint("TOPLEFT", PAD, y)
        box:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        boxes[#boxes + 1] = box.editBox
        y = y - 78
        local btn = GUI:CreateButton(tabContent, "SELECT ALL", 120, 24, function() SelectOnly(box.editBox) end)
        btn:SetPoint("TOPLEFT", PAD, y)
        local tip = GUI:CreateLabel(tabContent, "then press Ctrl+C to copy", 11, C.textMuted)
        tip:SetPoint("LEFT", btn, "RIGHT", 10, 0)
        y = y - 36
        return data
    end

    ---------------------------------------------------------------------
    Section("Plater")
    Info("H3z0 UI's Plater nameplate profile. If Plater is installed you can import it with one click; otherwise copy the string and use Plater > Profiles > Import.", 32)
    Status("Plater")
    local importBtn = GUI:CreateButton(tabContent, "Import into Plater", 180, 28, function()
        if not IsLoaded("Plater") then
            Say("Plater is not installed or not loaded - install it first, or copy the string below.")
            return
        end
        StaticPopup_Show("H3Z0UI_PLATER_IMPORT")
    end)
    importBtn:SetPoint("TOPLEFT", PAD, y)
    local openBtn = GUI:CreateButton(tabContent, "Open Plater options", 180, 28, function()
        if not IsLoaded("Plater") then Say("Plater is not installed or not loaded."); return end
        local plater = _G.Plater
        if plater and plater.OpenOptionsPanel then pcall(plater.OpenOptionsPanel) end
    end)
    openBtn:SetPoint("LEFT", importBtn, "RIGHT", 10, 0)
    y = y - 40
    CopyBox("Plater")

    ---------------------------------------------------------------------
    Section("Platynator")
    Info("H3z0 UI's Platynator nameplate profile. Copy the string, then in Platynator open the profile settings and use Import.", 32)
    Status("Platynator")
    local platyBtn = GUI:CreateButton(tabContent, "Open Platynator settings", 200, 28, OpenPlatynatorSettings)
    platyBtn:SetPoint("TOPLEFT", PAD, y)
    y = y - 40
    CopyBox("Platynator")

    ---------------------------------------------------------------------
    Section("BetterBlizzPlates")
    Info("H3z0 UI's BetterBlizzPlates nameplate profile. Copy the string, then in BetterBlizzPlates open Profiles (/bbp) and use Import.", 32)
    Status("BetterBlizzPlates")
    local bbpBtn = GUI:CreateButton(tabContent, "Open BetterBlizzPlates settings", 220, 28, OpenBetterBlizzPlatesSettings)
    bbpBtn:SetPoint("TOPLEFT", PAD, y)
    y = y - 40
    CopyBox("BetterBlizzPlates")

    ---------------------------------------------------------------------
    Section("Friendly Nameplates")
    Info("Moved here from Skinning & Autohide. These switch Blizzard's friendly nameplate CVars, so they work with Plater, Platynator and BetterBlizzPlates too.", 32)
    db.uiHider = db.uiHider or {}
    local function RefreshUIHider()
        if _G.H3z0UI_RefreshUIHider then _G.H3z0UI_RefreshUIHider() end
    end
    local options = {
        {key = "hideFriendlyPlayerNameplates", label = "Hide Friendly Player Nameplates"},
        {key = "hideFriendlyNPCNameplates", label = "Hide Friendly NPC Nameplates"},
    }
    for _, opt in ipairs(options) do
        local check = GUI:CreateFormCheckbox(tabContent, opt.label, opt.key, db.uiHider, RefreshUIHider)
        check:SetPoint("TOPLEFT", PAD, y)
        check:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW
    end

    tabContent:SetHeight(math.abs(y) + 50)
end

ns.H3z0UI_NameplatesOptions = {
    BuildNameplatesTab = Build,
}
