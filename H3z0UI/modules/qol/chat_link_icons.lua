local ADDON_NAME, ns = ...

-- Shows the icon of an item, spell, currency or achievement next to the tooltip you get
-- when you click a link in chat (the skinned tooltip has no icon of its own).

local ICON_SIZE = 40

local frameIcon

local function EnsureIcon()
    if frameIcon then return frameIcon end
    local tip = _G.ItemRefTooltip
    if not tip then return nil end
    local f = CreateFrame("Frame", nil, tip)
    f:SetSize(ICON_SIZE, ICON_SIZE)
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT", -4, 0)
    f:SetFrameLevel(tip:GetFrameLevel() + 1)
    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 0.9)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", -2, 2)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.tex = tex
    f:Hide()
    tip:HookScript("OnHide", function() f:Hide() end)
    frameIcon = f
    return f
end

local function IconForLink(link)
    if type(link) ~= "string" then return nil end
    if issecretvalue and issecretvalue(link) then return nil end
    local kind, id = link:match("(%a+):(%d+)")
    id = tonumber(id)
    if not kind or not id then return nil end
    if kind == "item" then
        if C_Item and C_Item.GetItemInfoInstant then
            local _, _, _, _, icon = C_Item.GetItemInfoInstant(link)
            if icon then return icon end
        end
        return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) or nil
    elseif kind == "spell" or kind == "talent" then
        if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
        if GetSpellTexture then return GetSpellTexture(id) end
    elseif kind == "currency" then
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
        return info and info.iconFileID or nil
    elseif kind == "achievement" then
        if GetAchievementInfo then return select(10, GetAchievementInfo(id)) end
    end
    return nil
end

local function OnSetHyperlink(tip, link)
    local f = EnsureIcon()
    if not f then return end
    local icon = IconForLink(link)
    if icon then
        f.tex:SetTexture(icon)
        f:Show()
    else
        f:Hide()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local tip = _G.ItemRefTooltip
    if tip and tip.SetHyperlink then
        hooksecurefunc(tip, "SetHyperlink", OnSetHyperlink)
    end
end)
