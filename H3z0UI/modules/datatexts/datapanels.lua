local ADDON_NAME, ns = ...
local H3z0UICore = ns.Addon
local LSM = ns.LSM

local Datapanels = {}
H3z0UICore.Datapanels = Datapanels

local function Warn(message)
    if H3z0UICore and type(H3z0UICore.Print) == "function" then
        H3z0UICore:Print(message)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000H3z0UI:|r " .. message)
    end
end

local function PersistPanelPosition(panel)
    panel:StopMovingOrSizing()

    local point, _, relPoint, x, y = H3z0UICore:SnapFramePosition(panel)
    if point then
        panel.config.position = {point, relPoint, x, y}
    end

    local db = H3z0UICore.db.profile.h3z0uiDatatexts
    if db and db.panels then
        for i, panelConfig in ipairs(db.panels) do
            if panelConfig.id == panel.panelID then
                db.panels[i].position = panel.config.position
                break
            end
        end
    end
end

local function DatapanelElementInfo(i, panelConfig)
    local panelID = panelConfig.id
    local elementKey = "datapanel_" .. panelID
    local displayName = panelConfig.name or ("Datapanel: " .. panelID)
    return elementKey, displayName, 10 + i
end

Datapanels.activePanels = {}

local rebuildPendingCombat = false

local regenWatcher = CreateFrame("Frame")
regenWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
regenWatcher:SetScript("OnEvent", function()
    if rebuildPendingCombat then
        rebuildPendingCombat = false
        Datapanels:RefreshAll()
    end
end)

local function PanelShouldShow(config)
    if not config.enabled then return false end
    if config.slots then
        for i = 1, (config.numSlots or 3) do
            if config.slots[i] and config.slots[i] ~= "" then
                return true
            end
        end
    end
    return false
end

--- Accent line on the edge of the panel that faces the screen center
local function ApplyAccent(panel)
    local cfg = panel.config
    if not cfg then return end
    if not panel.accentLine then
        panel.accentLine = panel:CreateTexture(nil, "ARTWORK")
    end
    local line = panel.accentLine
    -- 0.24.0: accent lines are off by default (once; the option can turn it back on)
    if not cfg.h3zNoAccent024 then
        cfg.h3zNoAccent024 = true
        cfg.accentLine = false
    end
    if not cfg.accentLine then
        line:Hide()
        return
    end
    local r, g, b, a = 0.6, 0.3, 1, 1
    if cfg.accentColor then
        r, g, b, a = cfg.accentColor[1], cfg.accentColor[2], cfg.accentColor[3], cfg.accentColor[4] or 1
    elseif ns.Helpers and ns.Helpers.GetSkinColors then
        local sr, sg, sb = ns.Helpers.GetSkinColors()
        if sr then r, g, b = sr, sg, sb end
    end
    local point = cfg.position and cfg.position[1] or "BOTTOM"
    local onTop = tostring(point):find("TOP") ~= nil
    line:ClearAllPoints()
    if onTop then
        line:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    else
        line:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    end
    line:SetHeight(2)
    line:SetColorTexture(r, g, b, a)
    line:Show()
end

-- H3z0 UI: full-width panels (Bottom Bar) follow the screen width
local function ApplyFullWidth(config)
    if config and config.fullWidth then
        config.width = math.floor(UIParent:GetWidth() or config.width or 300)
    end
end

function Datapanels:CreatePanel(panelID, config)
    if self.activePanels[panelID] then
        Warn("Panel '" .. panelID .. "' already exists!")
        return self.activePanels[panelID]
    end

    ApplyFullWidth(config)
    local panel = CreateFrame("Frame", "H3z0UI_Datapanel_" .. panelID, UIParent)
    panel:SetFrameStrata("LOW")
    panel:SetFrameLevel(100)
    panel:SetSize(config.width or 300, config.height or 22)

    if config.position then
        panel:SetPoint(config.position[1], UIParent, config.position[2], config.position[3], config.position[4])
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 300)
    end

    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()
    local _, _, _, _, bgR, bgG, bgB = ns.Helpers.GetWindowColors(config, "")
    panel.bg:SetColorTexture(bgR, bgG, bgB, (config.bgOpacity or 50) / 100)

    local borderSize = config.borderSize or 2
    local bR, bG, bB, bA = ns.Helpers.GetWindowColors(config, "")
    local borderColor = { bR, bG, bB, bA }
    panel.borderLeft = panel:CreateTexture(nil, "BORDER")
    panel.borderRight = panel:CreateTexture(nil, "BORDER")
    panel.borderTop = panel:CreateTexture(nil, "BORDER")
    panel.borderBottom = panel:CreateTexture(nil, "BORDER")

    panel.borderLeft:SetColorTexture(unpack(borderColor))
    panel.borderRight:SetColorTexture(unpack(borderColor))
    panel.borderTop:SetColorTexture(unpack(borderColor))
    panel.borderBottom:SetColorTexture(unpack(borderColor))

    panel.borderLeft:SetWidth(borderSize)
    panel.borderRight:SetWidth(borderSize)
    panel.borderTop:SetHeight(borderSize)
    panel.borderBottom:SetHeight(borderSize)

    local showBorder = borderSize > 0
    panel.borderLeft:SetShown(showBorder)
    panel.borderRight:SetShown(showBorder)
    panel.borderTop:SetShown(showBorder)
    panel.borderBottom:SetShown(showBorder)

    panel.borderLeft:SetPoint("TOPRIGHT", panel, "TOPLEFT", 0, 0)
    panel.borderLeft:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", 0, 0)

    panel.borderRight:SetPoint("TOPLEFT", panel, "TOPRIGHT", 0, 0)
    panel.borderRight:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", 0, 0)

    panel.borderTop:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", -borderSize, 0)
    panel.borderTop:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", borderSize, 0)

    panel.borderBottom:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", -borderSize, 0)
    panel.borderBottom:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", borderSize, 0)

    panel.panelID = panelID
    panel.config = config
    panel.slots = {}

    ApplyAccent(panel)

    self:SetupDragging(panel)

    self:UpdateSlots(panel)

    self.activePanels[panelID] = panel

    if PanelShouldShow(config) then
        panel:Show()
    else
        panel:Hide()
    end

    return panel
end

function Datapanels:SetupDragging(panel)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)

    panel:SetScript("OnDragStart", function(self)
        if not self.config.locked then
            self:StartMoving()
        end
    end)

    panel:SetScript("OnDragStop", function(self)
        PersistPanelPosition(self)
    end)
end

local slotPool = {}
local SLOT_POOL_CAP = 32

local function ReleasePanelSlots(panel)
    for _, slot in ipairs(panel.slots) do
        if H3z0UICore.Datatexts then
            H3z0UICore.Datatexts:DetachFromSlot(slot)
        end
        slot.index = nil
        slot.shortLabel = nil
        slot.noLabel = nil
        slot._h3z0uiFixedWidth = nil
        slot._h3z0uiLdbName = nil
        slot._h3z0uiOnWidthDirty = nil
        slot.text:SetText("")
        slot:Hide()
        if #slotPool < SLOT_POOL_CAP then
            slotPool[#slotPool + 1] = slot
        else
            slot:SetParent(nil)
        end
    end
    panel.slots = {}
end

function Datapanels:UpdateSlots(panel)
    ReleasePanelSlots(panel)

    local numSlots = panel.config.numSlots or 3
    local slotHeight = panel:GetHeight()

    -- H3z0 UI: optional per-slot width weights (default 1 each)
    local weights, totalWeight = {}, 0
    for i = 1, numSlots do
        local w = tonumber(panel.config.slotWeights and panel.config.slotWeights[i]) or 1
        if w < 0.1 then w = 0.1 end
        weights[i] = w
        totalWeight = totalWeight + w
    end
    local slotX = 0

    local generalFont = "H3z0UI"
    local generalOutline = "OUTLINE"
    if H3z0UICore and H3z0UICore.db and H3z0UICore.db.profile and H3z0UICore.db.profile.general then
        local general = H3z0UICore.db.profile.general
        generalFont = general.font or "H3z0UI"
        generalOutline = general.fontOutline or "OUTLINE"
    end
    local fontPath = LSM:Fetch("font", generalFont) or "Fonts\\FRIZQT__.TTF"
    local fontSize = panel.config.fontSize or 12

    for i = 1, numSlots do
        local slot = table.remove(slotPool)
        if slot then
            slot:SetParent(panel)
            slot:Show()
        else
            slot = CreateFrame("Button", nil, panel)
            slot.text = slot:CreateFontString(nil, "OVERLAY")
            slot.text:SetPoint("LEFT", slot, "LEFT", 1, 0)
            slot.text:SetPoint("RIGHT", slot, "RIGHT", -1, 0)
            slot.text:SetJustifyH("CENTER")
            slot.text:SetWordWrap(false)
        end
        local slotWidth = panel:GetWidth() * weights[i] / totalWeight
        slot:SetSize(slotWidth, slotHeight)
        slot:ClearAllPoints()
        slot:SetPoint("LEFT", panel, "LEFT", slotX, 0)
        slotX = slotX + slotWidth

        if ns.Helpers and ns.Helpers.ApplyFontWithFallback then
            ns.Helpers.ApplyFontWithFallback(slot.text, fontPath, fontSize, generalOutline)
        else
            H3z0UICore:SafeSetFont(slot.text, fontPath, fontSize, generalOutline)
        end
        slot.text:SetTextColor(1, 1, 1, 1)

        slot.index = i

        local slotSettings = panel.config.slotSettings and panel.config.slotSettings[i]
        slot.shortLabel = slotSettings and slotSettings.shortLabel or false
        slot.noLabel = slotSettings and slotSettings.noLabel or false

        slot:EnableMouse(true)
        slot:RegisterForDrag("LeftButton")
        slot:SetScript("OnDragStart", function()
            if not panel.config.locked then
                panel:StartMoving()
            end
        end)
        slot:SetScript("OnDragStop", function()
            PersistPanelPosition(panel)
        end)

        local datatextID = panel.config.slots and panel.config.slots[i]
        if datatextID and H3z0UICore.Datatexts then
            H3z0UICore.Datatexts:AttachToSlot(slot, datatextID, panel.config)
        else
            slot.text:SetText("|cffFFAA00" .. ns.L["Slot "] .. i .. "|r")
            slot.text:Show()
        end

        table.insert(panel.slots, slot)
    end
end

function Datapanels:UpdatePanel(panelID)
    local panel = self.activePanels[panelID]
    if not panel then return end

    if InCombatLockdown() then
        rebuildPendingCombat = true
        return
    end

    ApplyFullWidth(panel.config)
    panel:SetSize(panel.config.width or 300, panel.config.height or 22)

    local _, _, _, _, bgR, bgG, bgB = ns.Helpers.GetWindowColors(panel.config, "")
    panel.bg:SetColorTexture(bgR, bgG, bgB, (panel.config.bgOpacity or 50) / 100)

    local borderSize = panel.config.borderSize or 2
    local bR, bG, bB, bA = ns.Helpers.GetWindowColors(panel.config, "")
    local borderColor = { bR, bG, bB, bA }
    panel.borderLeft:SetWidth(borderSize)
    panel.borderRight:SetWidth(borderSize)
    panel.borderTop:SetHeight(borderSize)
    panel.borderBottom:SetHeight(borderSize)
    panel.borderLeft:SetColorTexture(unpack(borderColor))
    panel.borderRight:SetColorTexture(unpack(borderColor))
    panel.borderTop:SetColorTexture(unpack(borderColor))
    panel.borderBottom:SetColorTexture(unpack(borderColor))

    panel.borderTop:ClearAllPoints()
    panel.borderTop:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", -borderSize, 0)
    panel.borderTop:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", borderSize, 0)
    panel.borderBottom:ClearAllPoints()
    panel.borderBottom:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", -borderSize, 0)
    panel.borderBottom:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", borderSize, 0)

    local showBorder = borderSize > 0
    panel.borderLeft:SetShown(showBorder)
    panel.borderRight:SetShown(showBorder)
    panel.borderTop:SetShown(showBorder)
    panel.borderBottom:SetShown(showBorder)

    if panel.config.position and not (_G.H3z0UI_IsLayoutModeActive and _G.H3z0UI_IsLayoutModeActive()) then
        panel:ClearAllPoints()
        panel:SetPoint(panel.config.position[1], UIParent, panel.config.position[2], panel.config.position[3], panel.config.position[4])
    end

    ApplyAccent(panel)

    self:UpdateSlots(panel)

    if PanelShouldShow(panel.config) then
        panel:Show()
    else
        panel:Hide()
    end
end

function Datapanels:DeletePanel(panelID)
    local panel = self.activePanels[panelID]
    if not panel then return end

    if InCombatLockdown() then
        rebuildPendingCombat = true
        return
    end

    ReleasePanelSlots(panel)

    panel:Hide()
    panel:SetParent(nil)

    self.activePanels[panelID] = nil
end

function Datapanels:RegisterFrameResolvers()
    local RegisterResolver = _G.H3z0UI_RegisterFrameResolver
    if not RegisterResolver then return end

    local db = H3z0UICore.db and H3z0UICore.db.profile and H3z0UICore.db.profile.h3z0uiDatatexts
    if not db or not db.panels then return end

    for i, panelConfig in ipairs(db.panels) do
        local panelID = panelConfig.id
        if panelID then
            local elementKey, displayName, order = DatapanelElementInfo(i, panelConfig)
            RegisterResolver(elementKey, {
                resolver = function() return Datapanels.activePanels[panelID] end,
                displayName = displayName,
                category = "Display",
                order = order,
            })
        end
    end
end

function Datapanels:RefreshAll()
    local p = H3z0UICore and H3z0UICore.db and H3z0UICore.db.profile
    if p and p.h3z0uiDatatexts and p.h3z0uiDatatexts.enabled == false then return end

    if not H3z0UICore.db or not H3z0UICore.db.profile then return end

    if InCombatLockdown() and next(self.activePanels) then
        rebuildPendingCombat = true
        return
    end

    local db = H3z0UICore.db.profile.h3z0uiDatatexts
    local wanted = {}
    if db and db.panels then
        for _, panelConfig in ipairs(db.panels) do
            if panelConfig.id then
                wanted[panelConfig.id] = true
            end
        end
    end

    for panelID in pairs(self.activePanels) do
        if not wanted[panelID] then
            self:DeletePanel(panelID)
        end
    end

    if not db or not db.panels then return end

    for _, panelConfig in ipairs(db.panels) do
        if panelConfig.id then
            local panel = self.activePanels[panelConfig.id]
            if panel then
                panel.config = panelConfig
                self:UpdatePanel(panelConfig.id)
            else
                self:CreatePanel(panelConfig.id, panelConfig)
            end
        end
    end

    self:RegisterFrameResolvers()

    if _G.H3z0UI_ApplyAllFrameAnchors then
        _G.H3z0UI_ApplyAllFrameAnchors()
    end
end

_G.H3z0UI_RefreshDatapanels = function()
    if H3z0UICore and H3z0UICore.Datapanels then
        H3z0UICore.Datapanels:RefreshAll()
    end
end

if ns.Registry then
    ns.Registry:Register("datapanels", {
        refresh = _G.H3z0UI_RefreshDatapanels,
        priority = 40,
        group = "data",
        importCategories = { "minimapDatatexts" },
    })
    ns.Registry:Register("datapanelsSkin", {
        refresh = function()
            for _, panel in pairs(Datapanels.activePanels) do
                local bR, bG, bB, bA = ns.Helpers.GetWindowColors(panel.config, "")
                panel.borderLeft:SetColorTexture(bR, bG, bB, bA)
                panel.borderRight:SetColorTexture(bR, bG, bB, bA)
                panel.borderTop:SetColorTexture(bR, bG, bB, bA)
                panel.borderBottom:SetColorTexture(bR, bG, bB, bA)
            end
        end,
        priority = 40,
        group = "skinning",
        importCategories = { "skinning", "theme" },
    })
end

local function CollectDatatextSurfaces(profile)
    local out = {}
    if type(profile) ~= "table" then return out end

    if type(profile.datatext) == "table" and profile.datatext.borderColor ~= nil then
        out[#out + 1] = profile.datatext
    end

    local store = profile.h3z0uiDatatexts
    if type(store) == "table" and type(store.panels) == "table" then
        for _, panelDB in ipairs(store.panels) do
            if type(panelDB) == "table" and panelDB.borderColor ~= nil then
                out[#out + 1] = panelDB
            end
        end
    end

    return out
end

if ns.Helpers and ns.Helpers.BorderRegistry then
    ns.Helpers.BorderRegistry.Register({
        key      = "datatext",
        label    = "Datatext",
        category = "HUD",
        prefix   = "",
        multi    = true,
        instances = CollectDatatextSurfaces,
        db       = function(p)
            local insts = CollectDatatextSurfaces(p)
            return insts and insts[1]
        end,
        refresh  = function()
            if _G.H3z0UI_RefreshMinimap then _G.H3z0UI_RefreshMinimap() end
            if _G.H3z0UI_RefreshDatapanels then _G.H3z0UI_RefreshDatapanels() end
        end,
        legacy   = {},
    })
end

if ns.WhenLoggedIn then
    ns.WhenLoggedIn(function()
        C_Timer.After(0.5, function()
            Datapanels:RefreshAll()

            local count = 0
            for _ in pairs(Datapanels.activePanels) do count = count + 1 end
            local db = H3z0UICore.db and H3z0UICore.db.profile and H3z0UICore.db.profile.h3z0uiDatatexts
            local expectedPanels = db and db.panels and #db.panels or 0
            if count < expectedPanels then
                C_Timer.After(2.0, function()
                    Datapanels:RefreshAll()
                end)
            end
        end)
    end)
end

local SETTINGS_FEATURE_ID = "datatextPanel"
local registeredSettingsLookups = {}

local function GetSettingsRegistry()
    local Settings = ns.Settings
    local Registry = Settings and Settings.Registry
    if not Registry
        or type(Registry.GetFeature) ~= "function"
        or type(Registry.RegisterLookupKey) ~= "function"
        or type(Registry.UnregisterLookupKey) ~= "function" then
        return nil
    end
    if not Registry:GetFeature(SETTINGS_FEATURE_ID) then
        return nil
    end
    return Registry
end

local function RegisterDatapanelSettingsLookup(panelID, elementKey)
    local Registry = GetSettingsRegistry()
    if not Registry then
        return false
    end

    if type(elementKey) ~= "string" or elementKey == "" then
        if type(panelID) ~= "string" or panelID == "" then
            return false
        end
        elementKey = "datapanel_" .. panelID
    end

    Registry:RegisterLookupKey(SETTINGS_FEATURE_ID, elementKey)
    registeredSettingsLookups[elementKey] = true
    return true
end

local function UnregisterDatapanelSettingsLookup(panelID, elementKey)
    local Registry = GetSettingsRegistry()
    if not Registry then
        return false
    end

    if type(elementKey) ~= "string" or elementKey == "" then
        if type(panelID) ~= "string" or panelID == "" then
            return false
        end
        elementKey = "datapanel_" .. panelID
    end

    Registry:UnregisterLookupKey(SETTINGS_FEATURE_ID, elementKey)
    registeredSettingsLookups[elementKey] = nil
    return true
end

Datapanels.RegisterSettingsLookup = RegisterDatapanelSettingsLookup
Datapanels.UnregisterSettingsLookup = UnregisterDatapanelSettingsLookup

do
    local function RegisterLayoutModeElements()
        local um = ns.H3z0UI_LayoutMode
        if not um then return end

        local db = H3z0UICore.db and H3z0UICore.db.profile and H3z0UICore.db.profile.h3z0uiDatatexts
        if not db or not db.panels then
            for elementKey in pairs(registeredSettingsLookups) do
                UnregisterDatapanelSettingsLookup(nil, elementKey)
            end
            return
        end

        local desiredLookups = {}

        for i, panelConfig in ipairs(db.panels) do
            local panelID = panelConfig.id
            if panelID then
                local elementKey, displayName, order = DatapanelElementInfo(i, panelConfig)
                desiredLookups[elementKey] = true

                um:RegisterElement({
                    key = elementKey,
                    label = displayName,
                    group = ns.L["Display"],
                    order = order,
                    isOwned = true,
                    getFrame = function()
                        return Datapanels.activePanels[panelID]
                    end,
                    isEnabled = function()
                        local panel = Datapanels.activePanels[panelID]
                        return panel and panel:IsShown()
                    end,
                    setEnabled = function(val)
                        local panel = Datapanels.activePanels[panelID]
                        if panel then
                            panel.config.enabled = val
                            if val then
                                panel:Show()
                            else
                                panel:Hide()
                            end
                        end
                    end,
                    setGameplayHidden = function(hide)
                        local panel = Datapanels.activePanels[panelID]
                        if not panel then return end
                        if hide then panel:Hide() else panel:Show() end
                    end,
                })

                if ns.FRAME_ANCHOR_INFO then
                    ns.FRAME_ANCHOR_INFO[elementKey] = {
                        displayName = displayName,
                        category = "Display",
                        order = order,
                    }
                end
                local anchoring = ns.H3z0UI_Anchoring
                if anchoring and anchoring.RegisterAnchorTarget then
                    local panel = Datapanels.activePanels[panelID]
                    if panel then
                        anchoring:RegisterAnchorTarget(elementKey, panel, {
                            displayName = displayName,
                            category = "Display",
                            order = order,
                        })
                    end
                end

                RegisterDatapanelSettingsLookup(panelID, elementKey)
            end
        end

        for elementKey in pairs(registeredSettingsLookups) do
            if not desiredLookups[elementKey] then
                UnregisterDatapanelSettingsLookup(nil, elementKey)
            end
        end
    end

    C_Timer.After(2, RegisterLayoutModeElements)
end

SLASH_H3z0UIDATAPANELS1 = "/quidp"
SlashCmdList["H3z0UIDATAPANELS"] = function(msg)
    if msg == "show" then
        local count = 0
        for id, panel in pairs(Datapanels.activePanels) do
            count = count + 1
            print(string.format("|cff00ff00Panel %s:|r %s at %s, %dx%d, %s",
                id,
                panel:IsShown() and "VISIBLE" or "HIDDEN",
                tostring(panel.config.position),
                panel:GetWidth(),
                panel:GetHeight(),
                panel.config.enabled and "enabled" or "disabled"
            ))
        end
        print(string.format("|cff00ff00H3z0UI:|r Total panels: %d", count))
    elseif msg == "refresh" then
        Datapanels:RefreshAll()
        print("|cff00ff00H3z0UI:|r Refreshed all datapanels")
    else
        print("|cff00ff00H3z0UI Datapanels Commands:|r")
        print("/quidp show - List all panels and their status")
        print("/quidp refresh - Refresh all panels")
    end
end
