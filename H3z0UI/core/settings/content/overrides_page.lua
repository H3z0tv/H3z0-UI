local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options
local Settings = ns.Settings
local Registry = Settings and Settings.Registry
local Schema = Settings and Settings.Schema

local CreateWrappedLabel = Shared.CreateWrappedLabel
local PADDING = Shared.PADDING or 15

local ROLE_TEXT = { any = "Any role", TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }
local CONTENT_TEXT = {
    any = "Anywhere", world = "Open world", dungeon = "Dungeon",
    raid = "Raid", pvp = "PvP", scenario = "Scenario / Delve",
}

local function O() return ns.H3z0UI_Overrides or _G.H3z0UI_Overrides end

local function Cycle(list, value)
    for i, v in ipairs(list) do
        if v == value then return list[i % #list + 1] end
    end
    return list[1]
end

local function CountMods(rule)
    local n = 0
    for _ in pairs(rule.mods or {}) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- module picker for one rule
---------------------------------------------------------------------------
local picker
local function ShowPicker(rule, onClose)
    local MP = ns.H3z0UI_ModulesPage
    if not (MP and MP.CollectVisibleModules) then return end
    local groupOrder, groups = MP.CollectVisibleModules()

    if not picker then
        picker = CreateFrame("Frame", "H3z0UI_OverridesPicker", UIParent, "BackdropTemplate")
        picker:SetSize(420, 520)
        picker:SetPoint("CENTER")
        picker:SetFrameStrata("FULLSCREEN_DIALOG")
        picker:SetFrameLevel(900)
        picker:EnableMouse(true)
        picker:SetMovable(true)
        picker:RegisterForDrag("LeftButton")
        picker:SetScript("OnDragStart", picker.StartMoving)
        picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
        local bg = picker:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.06, 0.08, 0.97)
        picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        picker.title:SetPoint("TOPLEFT", 14, -12)
        local hint = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 14, -34)
        hint:SetText("Click a module to cycle: Leave alone, Turn on, Turn off.")
        hint:SetTextColor(0.7, 0.7, 0.7)
        local scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -56)
        scroll:SetPoint("BOTTOMRIGHT", -32, 48)
        picker.content = CreateFrame("Frame", nil, scroll)
        picker.content:SetSize(370, 10)
        scroll:SetScrollChild(picker.content)
        local done = GUI:CreateButton(picker, "Done", 100, 24, function() picker:Hide() end)
        done:SetPoint("BOTTOM", 0, 14)
        picker:SetScript("OnHide", function(self)
            if self.onClose then self.onClose() end
        end)
    end

    picker.onClose = onClose
    picker.title:SetText("Modules for: " .. (rule.name or "Rule"))
    local content = picker.content
    for _, child in ipairs({ content:GetChildren() }) do child:Hide(); child:SetParent(nil) end
    for _, region in ipairs({ content:GetRegions() }) do region:Hide() end

    local y = 0
    rule.mods = rule.mods or {}
    for _, gname in ipairs(groupOrder) do
        local hdr = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOPLEFT", 0, -y)
        hdr:SetText(gname)
        hdr:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
        y = y + 20
        for _, item in ipairs(groups[gname]) do
            local row = CreateFrame("Button", nil, content)
            row:SetSize(370, 22)
            row:SetPoint("TOPLEFT", 0, -y)
            local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            name:SetPoint("LEFT", 6, 0)
            name:SetText(item.label)
            local state = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            state:SetPoint("RIGHT", -6, 0)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.06)
            local function Paint()
                local v = rule.mods[item.id]
                if v == true then state:SetText("Turn on"); state:SetTextColor(0.3, 0.9, 0.5)
                elseif v == false then state:SetText("Turn off"); state:SetTextColor(1, 0.4, 0.4)
                else state:SetText("Leave alone"); state:SetTextColor(0.6, 0.6, 0.6) end
            end
            Paint()
            row:SetScript("OnClick", function()
                local v = rule.mods[item.id]
                if v == nil then rule.mods[item.id] = true
                elseif v == true then rule.mods[item.id] = false
                else rule.mods[item.id] = nil end
                Paint()
            end)
            y = y + 22
        end
        y = y + 8
    end
    content:SetHeight(y + 10)
    picker:Show()
end

---------------------------------------------------------------------------
-- page
---------------------------------------------------------------------------
local function BuildOverridesContent(content)
    local ov = O()
    local W = 640
    if content._ovHolder then content._ovHolder:Hide(); content._ovHolder:SetParent(nil) end
    local holder = CreateFrame("Frame", nil, content)
    holder:SetAllPoints(content)
    content._ovHolder = holder

    local function Rebuild()
        BuildOverridesContent(content)
    end
    local function Apply()
        if ov and ov.Request then ov.Request() end
    end

    local store = ov and ov.Store(true)
    if not store then
        local l = CreateWrappedLabel(holder, "Settings are not ready yet. Reopen this page in a moment.", 12, C.textMuted, W)
        l:SetPoint("TOPLEFT", PADDING, -16)
        content:SetHeight(80)
        return
    end

    local y = -12
    local intro = CreateWrappedLabel(holder,
        "Overrides switch modules on or off depending on your role and where you are, then put them back when you leave. Only the modules a rule lists are touched, and nothing changes in combat. A module you change by hand while a rule is active goes back to its saved state when the rule stops matching.",
        11, C.textMuted, W)
    intro:SetPoint("TOPLEFT", PADDING, y)
    y = y - (intro:GetStringHeight() or 40) - 14

    local master = GUI:CreateButton(holder, store.enabled and "Overrides: ON" or "Overrides: OFF", 160, 26, function()
        store.enabled = not store.enabled
        Apply()
        Rebuild()
    end)
    master:SetPoint("TOPLEFT", PADDING, y)
    local nowText = CreateWrappedLabel(holder, "", 11, C.textMuted, W - 180)
    nowText:SetPoint("LEFT", master, "RIGHT", 14, 0)
    local role, area = ov.CurrentRole(), ov.CurrentContent()
    nowText:SetText("Now: " .. (ROLE_TEXT[role or "any"] or "unknown role") .. " in " .. (CONTENT_TEXT[area] or area)
        .. ". Changed by rules: " .. #ov.ActiveList() .. ".")
    y = y - 40

    for index, rule in ipairs(store.rules) do
        local card = CreateFrame("Frame", nil, holder)
        card:SetSize(W, 78)
        card:SetPoint("TOPLEFT", PADDING, y)
        local R = ns.Round
        if R and R.Panel then
            local p = R.Panel(card, 10)
            p:SetAllPoints(card)
            p:SetFillColor(1, 1, 1, 0.035)
            p:SetBorderColor(1, 1, 1, 0.07)
        else
            local t = card:CreateTexture(nil, "BACKGROUND")
            t:SetAllPoints()
            t:SetColorTexture(1, 1, 1, 0.035)
        end

        local name = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
        name:SetSize(200, 20)
        name:SetPoint("TOPLEFT", 16, -10)
        name:SetAutoFocus(false)
        name:SetFontObject(ChatFontNormal)
        name:SetText(rule.name or ("Rule " .. index))
        name:SetScript("OnEnterPressed", function(self) rule.name = self:GetText(); self:ClearFocus() end)
        name:SetScript("OnEditFocusLost", function(self) rule.name = self:GetText() end)

        local on = GUI:CreateButton(card, rule.enabled == false and "Off" or "On", 46, 22, function()
            rule.enabled = (rule.enabled == false)
            Apply()
            Rebuild()
        end)
        on:SetPoint("LEFT", name, "RIGHT", 14, 0)

        local del = GUI:CreateButton(card, "Delete", 64, 22, function()
            table.remove(store.rules, index)
            Apply()
            Rebuild()
        end)
        del:SetPoint("TOPRIGHT", -12, -9)

        local roleBtn = GUI:CreateButton(card, ROLE_TEXT[rule.role or "any"], 120, 24, function()
            rule.role = Cycle(ov.ROLES, rule.role or "any")
            Apply()
            Rebuild()
        end)
        roleBtn:SetPoint("TOPLEFT", 16, -42)
        local contentBtn = GUI:CreateButton(card, CONTENT_TEXT[rule.content or "any"], 150, 24, function()
            rule.content = Cycle(ov.CONTENT, rule.content or "any")
            Apply()
            Rebuild()
        end)
        contentBtn:SetPoint("LEFT", roleBtn, "RIGHT", 10, 0)
        local modsBtn = GUI:CreateButton(card, "Modules (" .. CountMods(rule) .. ")", 130, 24, function()
            ShowPicker(rule, function() Apply(); Rebuild() end)
        end)
        modsBtn:SetPoint("LEFT", contentBtn, "RIGHT", 10, 0)

        y = y - 88
    end

    local add = GUI:CreateButton(holder, "Add a rule", 130, 26, function()
        store.rules[#store.rules + 1] = { name = "Rule " .. (#store.rules + 1), enabled = true, role = "any", content = "any", mods = {} }
        Rebuild()
    end)
    add:SetPoint("TOPLEFT", PADDING, y)
    y = y - 40

    if #store.rules == 0 then
        local l = CreateWrappedLabel(holder, "No rules yet. Example: role Healer, content Raid, turn off a module you do not need there.", 11, C.textMuted, W)
        l:SetPoint("TOPLEFT", PADDING, y)
        y = y - 30
    end

    content:SetHeight(math.abs(y) + 30)
end

ns.H3z0UI_OverridesPage = { BuildOverridesContent = BuildOverridesContent }

if Registry and Schema
    and type(Registry.RegisterFeature) == "function"
    and type(Schema.Feature) == "function"
    and type(Schema.Section) == "function" then
    Registry:RegisterFeature(Schema.Feature({
        id = "overridesPage",
        category = "global",
        nav = { tileId = "global", subPageIndex = 7 },
        sections = {
            Schema.Section({
                id = "overridesList",
                kind = "page",
                minHeight = 300,
                build = BuildOverridesContent,
            }),
        },
    }))
end
