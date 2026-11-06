--[[
    H3z0 UI - own popup dialog

    H3z0 UI never uses Blizzard's StaticPopup system: popups shown by an addon
    there "taint" Blizzard's shared popup frames, and the next protected popup
    (item upgrade, delete item, ...) is then blocked with ADDON_ACTION_FORBIDDEN.

    ns.Popups[name] = { text, button1, button2, OnAccept, OnCancel }   (same fields as before)
    ns.ShowPopup(name, textArg)    -- textArg fills a "%s" in text
]]

local ADDON_NAME, ns = ...

ns.Popups = ns.Popups or {}

local dlg

local function Accent()
    local C = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    local a = C and C.accent
    if a then return a[1], a[2], a[3] end
    return 0.204, 0.827, 0.6
end

local function MakeButton(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(120, 26)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("CENTER")
    local function Idle(self) local r, g, bl = Accent(); self:SetBackdropColor(r, g, bl, 0.15); self:SetBackdropBorderColor(r, g, bl, 0.8) end
    b:SetScript("OnEnter", function(self) local r, g, bl = Accent(); self:SetBackdropColor(r, g, bl, 0.45) end)
    b:SetScript("OnLeave", Idle)
    b.Idle = Idle
    return b
end

local function Build()
    if dlg then return dlg end
    local f = CreateFrame("Frame", "H3z0UI_PopupFrame", UIParent, "BackdropTemplate")
    f:SetSize(380, 140)
    f:SetPoint("TOP", UIParent, "TOP", 0, -160)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.07, 0.10, 0.97)
    f:Hide()
    tinsert(UISpecialFrames, "H3z0UI_PopupFrame")   -- Esc closes it

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT", 18, -18)
    f.text:SetPoint("TOPRIGHT", -18, -18)
    f.text:SetJustifyH("CENTER")
    f.text:SetSpacing(2)

    -- optional text input (def.hasEditBox) and gold / silver / copper input (def.hasMoneyInput)
    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetSize(240, 22)
    eb:SetAutoFocus(false)
    eb:Hide()
    f.editBox = eb

    local money = CreateFrame("Frame", nil, f)
    money:SetSize(260, 22)
    money:Hide()
    local function MoneyBox(label, width)
        local b = CreateFrame("EditBox", nil, money, "InputBoxTemplate")
        b:SetSize(width, 22)
        b:SetAutoFocus(false)
        b:SetNumeric(true)
        b.label = money:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.label:SetPoint("LEFT", b, "RIGHT", 4, 0)
        b.label:SetText(label)
        return b
    end
    money.gold = MoneyBox("g", 90)
    money.silver = MoneyBox("s", 34)
    money.copper = MoneyBox("c", 34)
    money.gold:SetPoint("LEFT", money, "LEFT", 6, 0)
    money.silver:SetPoint("LEFT", money.gold, "RIGHT", 22, 0)
    money.copper:SetPoint("LEFT", money.silver, "RIGHT", 22, 0)
    money.silver:SetMaxLetters(2)
    money.copper:SetMaxLetters(2)
    f.money = money
    function f:GetMoney()
        local g = tonumber(money.gold:GetText()) or 0
        local sv = tonumber(money.silver:GetText()) or 0
        local c = tonumber(money.copper:GetText()) or 0
        return g * 10000 + sv * 100 + c
    end

    f.b1 = MakeButton(f)
    f.b2 = MakeButton(f)
    f.b1:SetScript("OnClick", function()
        local def = f.def
        -- what was typed is read before the popup clears itself
        local value
        if def and def.hasEditBox then value = strtrim(f.editBox:GetText() or "")
        elseif def and def.hasMoneyInput then value = f:GetMoney() end
        f:Hide()
        if def and def.OnAccept then def.OnAccept(f, f.data, value) end
    end)
    f.b2:SetScript("OnClick", function()
        local def = f.def
        f.def = nil
        f:Hide()
        if def and def.OnCancel then def.OnCancel(f, f.data) end
    end)
    local function Accept() if f.b1:IsShown() then f.b1:Click() end end
    local function Cancel() if f.def and f.b2:IsShown() then f.b2:Click() else f:Hide() end end
    for _, box in ipairs({ eb, money.gold, money.silver, money.copper }) do
        box:SetScript("OnEnterPressed", Accept)
        box:SetScript("OnEscapePressed", Cancel)
    end
    f:SetScript("OnHide", function(self)
        self.editBox:ClearFocus()
        for _, k in ipairs({ "gold", "silver", "copper" }) do self.money[k]:SetText(""); self.money[k]:ClearFocus() end
    end)
    dlg = f
    return f
end

function ns.ShowPopup(name, textArg, data)
    local def = type(name) == "table" and name or ns.Popups[name]
    if not def then return end
    local f = Build()
    f.def, f.data = def, data
    local r, g, b = Accent()
    f:SetBackdropBorderColor(r, g, b, 0.9)

    local text = def.text or ""
    if textArg ~= nil and text:find("%%s") then text = text:format(tostring(textArg)) end
    f.text:SetText(text)

    f.b1.text:SetText(def.button1 or OKAY or "OK")
    f.b1:Idle()
    f.b1:ClearAllPoints()
    if def.button2 then
        f.b2.text:SetText(def.button2)
        f.b2:Idle()
        f.b2:ClearAllPoints()
        f.b1:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
        f.b2:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
        f.b2:Show()
    else
        f.b1:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
        f.b2:Hide()
    end
    local extra = 0
    f.editBox:Hide(); f.money:Hide()
    local textH = f.text:GetStringHeight() or 20
    if def.hasEditBox then
        f.editBox:ClearAllPoints()
        f.editBox:SetPoint("TOP", f.text, "TOP", 0, -(textH + 12))
        f.editBox:SetMaxLetters(def.maxLetters or 0)
        f.editBox:SetText(def.editText or "")
        f.editBox:Show()
        extra = 34
    elseif def.hasMoneyInput then
        f.money:ClearAllPoints()
        f.money:SetPoint("TOP", f.text, "TOP", 0, -(textH + 12))
        f.money:Show()
        extra = 34
    end
    f:SetHeight(math.max(110, textH + 76 + extra))
    f:Show()
    f:Raise()
    if def.hasEditBox then
        f.editBox:SetFocus()
        f.editBox:HighlightText()
    elseif def.hasMoneyInput then
        f.money.gold:SetFocus()
    end
    return f
end

_G.H3z0UI_ShowPopup = ns.ShowPopup
function ns.HidePopup()
    if dlg and dlg:IsShown() then dlg.def = nil; dlg:Hide() end
end
_G.H3z0UI_HidePopup = ns.HidePopup

---------------------------------------------------------------------------
-- 0.24.9: one "reload needed" popup for every option that only fully applies after a
-- reload. Several changes in a row are collected into one popup.
--   ns.NeedReload("Tracked bar styling switched off.")
--   ns.NeedReloadIf(condition, reason)   -- e.g. only when something was switched off
---------------------------------------------------------------------------
local reloadReasons, reloadSeen, reloadQueued = {}, {}, false

ns.Popups["H3Z0UI_NEED_RELOAD"] = {
    text = "%s\n\nThis change needs a reload to take full effect.\nReload now?",
    button1 = "Reload Now",
    button2 = "Later",
    OnAccept = function()
        local ui = _G.H3z0UI
        if ui and ui.SafeReload then ui:SafeReload() else ReloadUI() end
    end,
}

function ns.NeedReload(reason)
    reason = reason or "Settings changed."
    if not reloadSeen[reason] then
        reloadSeen[reason] = true
        reloadReasons[#reloadReasons + 1] = reason
    end
    if reloadQueued then return end
    reloadQueued = true
    C_Timer.After(0.3, function()
        reloadQueued = false
        local text = table.concat(reloadReasons, "\n")
        wipe(reloadReasons)
        wipe(reloadSeen)
        ns.ShowPopup("H3Z0UI_NEED_RELOAD", text)
    end)
end

function ns.NeedReloadIf(cond, reason)
    if cond then ns.NeedReload(reason) end
end

_G.H3z0UI_NeedReload = ns.NeedReload
