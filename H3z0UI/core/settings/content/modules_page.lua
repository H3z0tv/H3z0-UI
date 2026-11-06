local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options
local Settings = ns.Settings
local Registry = Settings and Settings.Registry
local Schema = Settings and Settings.Schema
local UIKit = ns.UIKit

local CreateWrappedLabel = Shared.CreateWrappedLabel
local PADDING = Shared.PADDING or 15

local CONTENT_WIDTH   = 680
local GROUP_HDR_H     = 22
local BOTTOM_PADDING  = 20

local CONTENT_TOP_Y   = -66

local function CollectVisibleModules()
    local groups     = {}
    local groupOrder = {}
    local total, enabled = 0, 0

    if not Registry or not Registry._featuresById then
        return groupOrder, groups, total, enabled
    end

    for featureId, spec in pairs(Registry._featuresById) do
        local entry = spec and spec.moduleEntry
        if type(entry) == "table" then
            local hide = entry.hidden
            if type(hide) ~= "function" or not hide() then
                local groupName = type(entry.group) == "string" and entry.group ~= ""
                    and entry.group or "Other"
                local bucket = groups[groupName]
                if not bucket then
                    bucket = {}
                    groups[groupName] = bucket
                    groupOrder[#groupOrder + 1] = groupName
                end
                bucket[#bucket + 1] = {
                    id    = featureId,
                    entry = entry,
                    label = entry.label or spec.name or featureId,
                }
                total = total + 1
                if type(entry.isEnabled) == "function" and entry.isEnabled() then
                    enabled = enabled + 1
                end
            end
        end
    end

    table.sort(groupOrder)
    for i, name in ipairs(groupOrder) do
        if name == ns.L["Module Addons"] and i > 1 then
            table.remove(groupOrder, i)
            table.insert(groupOrder, 1, name)
            break
        end
    end
    for _, name in ipairs(groupOrder) do
        table.sort(groups[name], function(a, b)
            local ao = a.entry.order or 1000
            local bo = b.entry.order or 1000
            if ao ~= bo then return ao < bo end
            return a.label < b.label
        end)
    end

    return groupOrder, groups, total, enabled
end

local function CreateModuleTogglePill(parent, featureId, entry)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(26, 14)

    local track = btn:CreateTexture(nil, "ARTWORK")
    track:SetAllPoints(btn)
    track:SetColorTexture(C.toggleOff[1], C.toggleOff[2], C.toggleOff[3], C.toggleOff[4])

    local trackMask = btn:CreateMaskTexture()
    trackMask:SetTexture(ns.Helpers.AssetPath .. "pill_mask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    trackMask:SetAllPoints(track)
    track:AddMaskTexture(trackMask)

    local knob = btn:CreateTexture(nil, "OVERLAY")
    knob:SetSize(10, 10)
    knob:SetColorTexture(C.toggleThumb[1], C.toggleThumb[2], C.toggleThumb[3], C.toggleThumb[4])
    knob:ClearAllPoints()
    knob:SetPoint("LEFT", btn, "LEFT", 2, 0)

    local knobMask = btn:CreateMaskTexture()
    knobMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    knobMask:SetAllPoints(knob)
    knob:AddMaskTexture(knobMask)

    local isHovered = false

    local function ApplyVisual()
        local on = type(entry.isEnabled) == "function" and entry.isEnabled() or false
        local locked = entry.combatLocked and InCombatLockdown()
        local hoverBoost = isHovered and 0.06 or 0

        if locked then
            track:SetColorTexture(0.2, 0.2, 0.2, 0.6)
            knob:ClearAllPoints()
            if on then
                knob:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
            else
                knob:SetPoint("LEFT", btn, "LEFT", 2, 0)
            end
            knobMask:SetAllPoints(knob)
            knob:SetVertexColor(0.5, 0.5, 0.5, 1)
            btn._isLocked = true
        else
            knob:SetVertexColor(1, 1, 1, 1)
            if on then
                track:SetColorTexture(C.accent[1], C.accent[2], C.accent[3],
                    math.min(1, (C.accent[4] or 1) + hoverBoost))
                knob:ClearAllPoints()
                knob:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
            else
                track:SetColorTexture(C.toggleOff[1], C.toggleOff[2], C.toggleOff[3],
                    math.min(1, (C.toggleOff[4] or 1) + hoverBoost))
                knob:ClearAllPoints()
                knob:SetPoint("LEFT", btn, "LEFT", 2, 0)
            end
            knobMask:SetAllPoints(knob)
            btn._isLocked = false
        end
    end
    ApplyVisual()

    btn:SetScript("OnClick", function(self)
        if self._isLocked then return end
        local current = type(entry.isEnabled) == "function" and entry.isEnabled() or false
        if ns.H3z0UI_Modules and type(ns.H3z0UI_Modules.SetEnabled) == "function" then
            ns.H3z0UI_Modules:SetEnabled(featureId, not current)
        elseif type(entry.setEnabled) == "function" then
            entry.setEnabled(not current)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        if self._isLocked then
            GUI.Tooltip:Show(self, ns.L["Cannot change during combat — leave combat to toggle."], { anchor = "TOP" })
            return
        end
        isHovered = true
        ApplyVisual()
    end)

    btn:SetScript("OnLeave", function(self)
        GUI.Tooltip:Hide(false, self)
        isHovered = false
        ApplyVisual()
    end)

    local token
    local function Subscribe()
        if not token and ns.H3z0UI_Modules then
            token = ns.H3z0UI_Modules:Subscribe(featureId, ApplyVisual)
        end
    end
    local function Unsubscribe()
        if token then
            ns.H3z0UI_Modules:Unsubscribe(token)
            token = nil
        end
    end

    Subscribe()
    btn:SetScript("OnShow", function()
        Subscribe()
        ApplyVisual()
    end)
    btn:SetScript("OnHide", Unsubscribe)

    btn._refresh = ApplyVisual
    return btn
end

local function BuildModuleCell(parent, item)
    local entry = item.entry
    local label = item.label
    local pill = CreateModuleTogglePill(parent, item.id, entry)
    local cell = Shared.BuildSettingRow(parent, label, pill)
    local nameLabel = cell._label

    if entry.caption and entry.caption ~= "" then
        cell:EnableMouse(true)
        cell:SetScript("OnEnter", function(self)
            GUI.Tooltip:Show(self, entry.caption, { title = label, anchor = "TOP" })
        end)
        cell:SetScript("OnLeave", function(self)
            GUI.Tooltip:Hide(false, self)
        end)
    end

    cell._pill       = pill
    cell._nameLabel  = nameLabel
    return cell
end

local function RelayoutVisibleRows(content)
    local groupOrder = content._groupOrder or {}

    local y = CONTENT_TOP_Y
    for _, gn in ipairs(groupOrder) do
        local hdr  = content._groupHeaders and content._groupHeaders[gn]
        local card = content._groupCards   and content._groupCards[gn]
        if hdr and hdr:IsShown() then
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, y)
            hdr:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
            y = y - GROUP_HDR_H - 4
        end
        if card and card.frame:IsShown() then
            card.frame:ClearAllPoints()
            card.frame:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, y)
            card.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
            y = y - card.frame:GetHeight() - 8
        end
    end
    content:SetHeight(math.abs(y) + BOTTOM_PADDING)
end

local function BuildModulesContent(content)
    if content._countsToken and ns.H3z0UI_Modules then
        ns.H3z0UI_Modules:Unsubscribe(content._countsToken)
        content._countsToken = nil
    end

    content._panelRows    = {}
    content._groupHeaders = {}
    content._groupCards   = {}
    content._groupOrder   = {}

    if content._sections then
        for k in pairs(content._sections) do content._sections[k] = nil end
    end

    local groupOrder, groups, total, enabled = CollectVisibleModules()
    content._groupOrder = groupOrder

    if total == 0 then
        local label = CreateWrappedLabel(content,
            ns.L["No feature toggles registered yet.\nThis panel will populate as features are onboarded."],
            12, C.textMuted, 500)
        label:SetPoint("TOP", content, "TOP", 0, -60)
        label:SetJustifyH("CENTER")
        content:SetHeight(160)
        return
    end

    local function CountsText(e, t)
        return string.format(ns.L["[%1$d of %2$d enabled]"], e, t)
    end

    local countsLabel = CreateWrappedLabel(content, CountsText(enabled, total),
        11, C.textMuted, 200)
    countsLabel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, -8)
    countsLabel:SetJustifyH("RIGHT")

    if ns.H3z0UI_Modules then
        content._countsToken = ns.H3z0UI_Modules:Subscribe("*", function()
            local _, _, t2, e2 = CollectVisibleModules()
            countsLabel:SetText(CountsText(e2, t2))
        end)
        if not content._countsHooked then
            content._countsHooked = true
            content:HookScript("OnHide", function()
                if content._countsToken and ns.H3z0UI_Modules then
                    ns.H3z0UI_Modules:Unsubscribe(content._countsToken)
                    content._countsToken = nil
                end
            end)
        end
    end

    local yCursor = CONTENT_TOP_Y

    -- filter bar: text search and On / Off / All. Non-matching modules are dimmed.
    local filterText, filterStatus = "", "all"
    local function ApplyFilter()
        for _, rec in ipairs(content._panelRows or {}) do
            local on = type(rec.entry.isEnabled) == "function" and rec.entry.isEnabled() or false
            local okText = filterText == "" or (rec.label and rec.label:lower():find(filterText, 1, true) ~= nil)
            local okStatus = filterStatus == "all" or (filterStatus == "on" and on) or (filterStatus == "off" and not on)
            if rec.cell then rec.cell:SetAlpha((okText and okStatus) and 1 or 0.22) end
        end
    end
    content._applyFilter = ApplyFilter

    local box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    box:SetSize(190, 20)
    box:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -30)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetScript("OnTextChanged", function(self)
        filterText = (self:GetText() or ""):lower()
        ApplyFilter()
    end)
    box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local hint = CreateWrappedLabel(content, "Find a module", 10, C.textMuted, 120)
    hint:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 2, 2)

    local statusBtns = {}
    local function SetStatus(v)
        filterStatus = v
        for key, b in pairs(statusBtns) do b:SetAlpha(key == v and 1 or 0.5) end
        ApplyFilter()
    end
    for i, def in ipairs({ { "all", "All" }, { "on", "On" }, { "off", "Off" } }) do
        local b = GUI:CreateButton(content, def[2], 48, 22, function() SetStatus(def[1]) end)
        b:SetPoint("LEFT", box, "RIGHT", 12 + (i - 1) * 52, 0)
        statusBtns[def[1]] = b
    end
    SetStatus("all")
    if ns.H3z0UI_Modules then
        local tok = ns.H3z0UI_Modules:Subscribe("*", ApplyFilter)
        content:HookScript("OnHide", function() ns.H3z0UI_Modules:Unsubscribe(tok) end)
    end

    for _, groupName in ipairs(groupOrder) do
        local header = Shared.CreateAccentDotLabel(content, groupName, yCursor)

        header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yCursor)

        -- all on / all off for this group (all off asks twice)
        local function GroupSet(want)
            if InCombatLockdown() then return end
            for _, item in ipairs(groups[groupName]) do
                local e = item.entry
                local cur = type(e.isEnabled) == "function" and e.isEnabled() or false
                if cur ~= want and not e.combatLocked then
                    if ns.H3z0UI_Modules and ns.H3z0UI_Modules.SetEnabled then
                        ns.H3z0UI_Modules:SetEnabled(item.id, want)
                    elseif type(e.setEnabled) == "function" then
                        e.setEnabled(want)
                    end
                end
            end
        end
        local offBtn = GUI:CreateButton(header, "All off", 56, 18, nil)
        offBtn:SetPoint("RIGHT", header, "RIGHT", -8, 0)
        local armed
        offBtn:SetScript("OnClick", function(self)
            if not armed then
                armed = true
                self:SetText("Sure?")
                C_Timer.After(3, function() armed = nil; self:SetText("All off") end)
            else
                armed = nil
                self:SetText("All off")
                GroupSet(false)
            end
        end)
        local onBtn = GUI:CreateButton(header, "All on", 56, 18, function() GroupSet(true) end)
        onBtn:SetPoint("RIGHT", offBtn, "LEFT", -6, 0)

        content._groupHeaders[groupName] = header
        yCursor = yCursor - GROUP_HDR_H - 4

        local card = Shared.CreateSettingsCardGroup(content, yCursor)

        local modules = groups[groupName]
        local i = 1
        while i <= #modules do
            local leftItem  = modules[i]
            local rightItem = modules[i + 1]

            leftItem.group = groupName
            local leftCell = BuildModuleCell(card.frame, leftItem)

            local rightCell
            if rightItem then
                rightItem.group = groupName
                rightCell = BuildModuleCell(card.frame, rightItem)
            end

            local row = card.AddRow(leftCell, rightCell)

            content._panelRows[#content._panelRows + 1] = {
                row      = row,
                cell     = leftCell,
                cellSide = "left",
                group    = groupName,
                entry    = leftItem.entry,
                pill     = leftCell._pill,
                label    = leftItem.label,
                id       = leftItem.id,
            }

            if rightItem and rightCell then
                content._panelRows[#content._panelRows + 1] = {
                    row      = row,
                    cell     = rightCell,
                    cellSide = "right",
                    group    = groupName,
                    entry    = rightItem.entry,
                    pill     = rightCell._pill,
                    label    = rightItem.label,
                    id       = rightItem.id,
                }
            end

            i = i + 2
        end

        card.Finalize()

        content._groupCards[groupName] = card

        yCursor = yCursor - card.frame:GetHeight() - 8
    end

    content:SetHeight(math.abs(yCursor) + BOTTOM_PADDING)

    if not content._combatWatcher then
        local combatWatcher = CreateFrame("Frame", nil, content)
        combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
        combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        combatWatcher:SetScript("OnEvent", function()
            for _, rec in ipairs(content._panelRows or {}) do
                if rec.entry.combatLocked and rec.pill and rec.pill._refresh then
                    rec.pill._refresh()
                end
            end
        end)
        content._combatWatcher = combatWatcher

        content:HookScript("OnHide", function()
            if content._combatWatcher then
                content._combatWatcher:UnregisterAllEvents()
                content._combatWatcher:SetScript("OnEvent", nil)
            end
        end)
    end
end

ns.H3z0UI_ModulesPage = {
    BuildModulesContent      = BuildModulesContent,
    CreateModuleTogglePill   = CreateModuleTogglePill,
    CollectVisibleModules    = CollectVisibleModules,
    RelayoutVisibleRows      = RelayoutVisibleRows,
}

if Registry and Schema
    and type(Registry.RegisterFeature) == "function"
    and type(Schema.Feature) == "function"
    and type(Schema.Section) == "function" then
    Registry:RegisterFeature(Schema.Feature({
        id = "modulesPage",
        category = "global",
        nav = { tileId = "global", subPageIndex = 4 },
        sections = {
            Schema.Section({
                id = "modulesList",
                kind = "page",
                minHeight = 400,
                build = BuildModulesContent,
            }),
        },
    }))
end
