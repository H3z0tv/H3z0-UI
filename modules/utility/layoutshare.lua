--[[
    H3z0 UI - Layout sharing (Export / Import)

    One text code holds the whole layout, for PC and Deck:
      - positions of every H3z0 UI frame (the same values Layout Mode saves)
      - the Blizzard frame layouts ("H3z0 PC" / "H3z0 Deck" Edit Mode layouts:
        action bars, Cooldown Manager, buffs, ...)
    Export shows the code to copy; Import applies a pasted code and reloads.

    ns.H3z0DefaultLayout (layout_default.lua) is applied once on a brand-new
    install, so new users start with that layout.
]]

local ADDON_NAME, ns = ...

local Share = {}
ns.LayoutShare = Share

local PREFIX = "H3Z0LAYOUT1:"
local AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
local LibDeflate = LibStub and LibStub("LibDeflate", true)

local function Say(msg) print("|cff34D399H3z0 UI:|r " .. msg) end

local function Profile()
    local core = ns.Addon
    return core and core.db and core.db.profile
end

local function Accent()
    local C = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    local a = C and C.accent
    if a then return a[1], a[2], a[3] end
    return 0.204, 0.827, 0.6
end

---------------------------------------------------------------------------
-- Build / read the code
---------------------------------------------------------------------------
local function BlizzardLayoutString(name)
    local LS = ns.LayoutSets
    local info = LS and LS.GetLayouts()
    if not (info and C_EditMode and C_EditMode.ConvertLayoutInfoToString) then return nil end
    local idx = LS.FindLayout(name, info)
    local layout = idx and info.layouts[idx - LS.NumPresetLayouts()]
    if not layout then return nil end
    local ok, str = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
    return ok and str or nil
end

function Share.Export()
    local LS = ns.LayoutSets
    local p = Profile()
    if not (LS and p and AceSerializer and LibDeflate) then
        return nil, "Export needs AceSerializer-3.0 and LibDeflate."
    end
    local mode = LS.CurrentMode()
    local other = (mode == "deck") and "pc" or "deck"
    local data = {
        v = 2,
        positions = {
            [mode] = LS.Capture(),                                  -- live values of the mode in use
            [other] = p.layoutSets and p.layoutSets[other] or nil,  -- saved values of the other mode
        },
        -- Blizzard frames (action bars, Cooldown Manager, ...) as saved by H3z0 UI
        blizzPositions = ns.BlizzPositions and ns.BlizzPositions.GetAll() or nil,
    }
    local serialized = AceSerializer:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
    return PREFIX .. LibDeflate:EncodeForPrint(compressed)
end

local function Decode(str)
    if not (AceSerializer and LibDeflate) then return nil, "Import needs AceSerializer-3.0 and LibDeflate." end
    str = tostring(str or ""):gsub("%s", "")
    if str:sub(1, #PREFIX) ~= PREFIX then return nil, "This is not an H3z0 UI layout code." end
    local decoded = LibDeflate:DecodeForPrint(str:sub(#PREFIX + 1))
    local inflated = decoded and LibDeflate:DecompressDeflate(decoded)
    if not inflated then return nil, "The code is damaged (copy it again)." end
    local ok, data = AceSerializer:Deserialize(inflated)
    if not ok or type(data) ~= "table" or (data.v ~= 1 and data.v ~= 2) then return nil, "The code could not be read." end
    return data
end

-- Applies a code. Returns true, or nil + reason.
function Share.Import(str, quiet)
    if InCombatLockdown() then return nil, "Leave combat first." end
    local data, err = Decode(str)
    if not data then return nil, err end
    local LS = ns.LayoutSets
    local p = Profile()
    if not (LS and p) then return nil, "Settings are not loaded yet." end

    -- H3z0 UI frame positions
    p.layoutSets = p.layoutSets or {}
    for mode, snap in pairs(data.positions or {}) do
        if (mode == "pc" or mode == "deck") and type(snap) == "table" then
            p.layoutSets[mode] = snap
        end
    end
    LS.Load(LS.CurrentMode())

    -- Blizzard frame positions (kept in H3z0 UI; Blizzard's Edit Mode layouts are never changed)
    if type(data.blizzPositions) == "table" and ns.BlizzPositions then
        ns.BlizzPositions.SetAll(data.blizzPositions)
        ns.BlizzPositions.ApplyAll()
    end

    if not quiet then
        ns.ShowPopup("H3Z0UI_LAYOUT_IMPORTED")
    end
    return true
end

ns.Popups["H3Z0UI_LAYOUT_IMPORTED"] = {
    text = "Layout imported (PC and Deck).\n\nReload the UI now to put every frame in place?",
    button1 = RELOADUI or "Reload UI",
    button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

---------------------------------------------------------------------------
-- Overlay window
---------------------------------------------------------------------------
local win

local function Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 26)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    local function Idle() local r, g, bb = Accent(); b:SetBackdropColor(r, g, bb, 0.15); b:SetBackdropBorderColor(r, g, bb, 0.8) end
    Idle()
    b:SetScript("OnEnter", function(self) local r, g, bb = Accent(); self:SetBackdropColor(r, g, bb, 0.45) end)
    b:SetScript("OnLeave", Idle)
    b:SetScript("OnClick", onClick)
    return b
end

local function Build()
    if win then return win end
    local f = CreateFrame("Frame", "H3z0UI_LayoutShareFrame", UIParent, "BackdropTemplate")
    f:SetSize(560, 340)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.07, 0.10, 0.97)
    local r, g, b = Accent()
    f:SetBackdropBorderColor(r, g, b, 0.9)
    tinsert(UISpecialFrames, "H3z0UI_LayoutShareFrame")

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\H3z0UI\\assets\\icon")
    logo:SetSize(26, 26)
    logo:SetPoint("TOPLEFT", 12, -10)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", 14, -44)
    f.hint:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.hint:SetJustifyH("LEFT")

    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 14, -78)
    box:SetPoint("BOTTOMRIGHT", -14, 50)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(0, 0, 0, 0.5)
    box:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(490)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(edit)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    f.edit = edit

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("BOTTOMLEFT", 14, 20)
    f.status:SetPoint("RIGHT", f, "RIGHT", -230, 0)
    f.status:SetJustifyH("LEFT")

    f.close = Button(f, CLOSE or "Close", 100, function() f:Hide() end)
    f.close:SetPoint("BOTTOMRIGHT", -14, 14)
    f.action = Button(f, "Import", 110, function()
        local ok, err = Share.Import(edit:GetText())
        if ok then
            f:Hide()
        else
            f.status:SetText("|cffff5555" .. tostring(err) .. "|r")
        end
    end)
    f.action:SetPoint("RIGHT", f.close, "LEFT", -8, 0)

    win = f
    return f
end

function Share.ShowExport()
    local f = Build()
    local code, err = Share.Export()
    f.title:SetText("|cff34D399H3z0 UI|r  Export Layout")
    f.hint:SetText("Copy this code (Ctrl+A, Ctrl+C) and share it. It contains the positions of every frame for PC and Deck, including the Blizzard frames (saved in H3z0 UI, not in Edit Mode).")
    f.edit:SetText(code or "")
    f.action:Hide()
    f.status:SetText(code and "" or ("|cffff5555" .. tostring(err) .. "|r"))
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

function Share.ShowImport()
    local f = Build()
    f.title:SetText("|cff34D399H3z0 UI|r  Import Layout")
    f.hint:SetText("Paste a layout code (Ctrl+V) and press Import. Your frames move to the shared positions for PC and Deck; a reload finishes it.")
    f.edit:SetText("")
    f.action:Show()
    f.status:SetText("")
    f:Show()
    f.edit:SetFocus()
end

_G.H3z0UI_ExportLayout = Share.ShowExport
_G.H3z0UI_ImportLayout = Share.ShowImport

---------------------------------------------------------------------------
-- Built-in default layout for new installs
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local code = ns.H3z0DefaultLayout
    if type(code) ~= "string" or code == "" then return end
    -- before the Setup Wizard opens (it opens 2s after login on a new install)
    local tries = 0
    local function TryApply()
        tries = tries + 1
        local wiz = _G.H3z0UI_Setup
        local p = Profile()
        if not (p and wiz and wiz.ShouldAutoShow and wiz.ShouldAutoShow()) then return end
        if p._h3zDefaultLayoutApplied then return end
        local ok = Share.Import(code, true)
        if ok then
            p._h3zDefaultLayoutApplied = true
            Say("Default H3z0 UI layout applied - it shows fully after the Setup Wizard's reload.")
        end
    end
    C_Timer.After(1, TryApply)
end)
