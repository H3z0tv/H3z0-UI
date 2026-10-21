local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI Cooldown Manager: links between the H3z0 CDM (Blizzard's
-- Essential / Utility / Buff viewers, skinned) and the core
---------------------------------------------------------------------------

local H3z0UI = _G.H3z0UI
local H3z0UICore = ns.Addon
if not H3z0UICore then return end

local AceSerializer = LibStub("AceSerializer-3.0", true)
local LibDeflate    = LibStub("LibDeflate", true)

-- the core skins no viewer itself any more (all handled by cdm_viewer / buffbar)
H3z0UICore.viewers = H3z0UICore.viewers or {}

-- Blizzard viewer for a CDM key (used by anchoring, keybinds, ...)
local VIEWERS = {
    essential = "EssentialCooldownViewer", cdmEssential = "EssentialCooldownViewer",
    utility = "UtilityCooldownViewer", cdmUtility = "UtilityCooldownViewer",
    buff = "BuffIconCooldownViewer", buffIcon = "BuffIconCooldownViewer",
    trackedBar = "BuffBarCooldownViewer", buffBar = "BuffBarCooldownViewer",
}
_G.H3z0UI_GetCDMViewerFrame = function(key)
    if type(key) ~= "string" then return nil end
    local name = VIEWERS[key] or key
    local f = _G[name]
    if type(f) == "table" and f.GetObjectType then return f end
    return nil
end

-- size of the cooldown rows (the resource bars match the Essential / Utility width)
_G.H3z0UI_GetCDMViewerState = function(viewer)
    if type(viewer) ~= "table" then return nil end
    local w = viewer.__cdmIconWidth
    if not w then return nil end
    return {
        iconWidth = w,
        rawContentWidth = w,
        row1Width = w,
        bottomRowWidth = viewer.__cdmBottomRowWidth or w,
        totalHeight = viewer.__cdmTotalHeight,
        row1BorderSize = viewer.__cdmBottomRowBorderSize,
        layoutDir = viewer.__cdmLayoutDirection,
    }
end

if not H3z0UICore.ForceRefreshBuffIcons then
    function H3z0UICore:ForceRefreshBuffIcons()
        if _G.H3z0UI_RefreshBuffBar then pcall(_G.H3z0UI_RefreshBuffBar) end
    end
end

---------------------------------------------------------------------------
-- Edit Mode selection (nudge arrows on the power bars)
---------------------------------------------------------------------------
if not H3z0UICore.SelectEditModeElement then

H3z0UICore.EditModeSelection = {
    selectedType = nil,  -- "unitframe", "powerbar", "cdm"
    selectedKey = nil,   -- "player", "primary", "EssentialCooldownViewer", etc.
}

-- Select an element and show its nudge arrows (hides arrows on previous selection)
function H3z0UICore:SelectEditModeElement(elementType, elementKey)
    -- Skip if already selected
    if self.EditModeSelection.selectedType == elementType and self.EditModeSelection.selectedKey == elementKey then
        return
    end

    -- Hide arrows on previously selected element
    self:HideCurrentSelectionArrows()

    -- Update selection
    self.EditModeSelection.selectedType = elementType
    self.EditModeSelection.selectedKey = elementKey

    -- Show arrows on newly selected element
    self:ShowSelectionArrows(elementType, elementKey)
end

-- Clear selection (called when exiting Edit Mode)
function H3z0UICore:ClearEditModeSelection()
    self:HideCurrentSelectionArrows()
    self.EditModeSelection.selectedType = nil
    self.EditModeSelection.selectedKey = nil
end

-- Hide nudge arrows on the currently selected element
function H3z0UICore:HideCurrentSelectionArrows()
    local sel = self.EditModeSelection
    if not sel.selectedType then return end

    if sel.selectedType == "unitframe" then
        -- Unit frames store their overlay on the frame itself
        if ns.H3z0UI_UnitFrames and ns.H3z0UI_UnitFrames.frames then
            local frame = ns.H3z0UI_UnitFrames.frames[sel.selectedKey]
            if frame and frame.editOverlay then
                self:HideNudgeButtons(frame.editOverlay)
            end
        end
    elseif sel.selectedType == "powerbar" then
        local bar = (sel.selectedKey == "primary") and self.powerBar or self.secondaryPowerBar
        if bar and bar.editOverlay then
            self:HideNudgeButtons(bar.editOverlay)
        end
    elseif sel.selectedType == "cdm" then
        if self.cdmOverlays and self.cdmOverlays[sel.selectedKey] then
            self:HideNudgeButtons(self.cdmOverlays[sel.selectedKey])
        end
    elseif sel.selectedType == "blizzard" then
        if self.blizzardOverlays and self.blizzardOverlays[sel.selectedKey] then
            self:HideNudgeButtons(self.blizzardOverlays[sel.selectedKey])
        end
    elseif sel.selectedType == "minimap" then
        if self.minimapOverlay then
            self:HideNudgeButtons(self.minimapOverlay)
        end
    end
end

-- Show nudge arrows on the specified element
function H3z0UICore:ShowSelectionArrows(elementType, elementKey)
    if elementType == "unitframe" then
        if ns.H3z0UI_UnitFrames and ns.H3z0UI_UnitFrames.frames then
            local frame = ns.H3z0UI_UnitFrames.frames[elementKey]
            if frame and frame.editOverlay then
                self:ShowNudgeButtons(frame.editOverlay)
            end
        end
    elseif elementType == "powerbar" then
        local bar = (elementKey == "primary") and self.powerBar or self.secondaryPowerBar
        if bar and bar.editOverlay then
            self:ShowNudgeButtons(bar.editOverlay)
        end
    elseif elementType == "cdm" then
        if self.cdmOverlays and self.cdmOverlays[elementKey] then
            self:ShowNudgeButtons(self.cdmOverlays[elementKey])
        end
    elseif elementType == "blizzard" then
        if self.blizzardOverlays and self.blizzardOverlays[elementKey] then
            self:ShowNudgeButtons(self.blizzardOverlays[elementKey])
        end
    elseif elementType == "minimap" then
        if self.minimapOverlay then
            self:ShowNudgeButtons(self.minimapOverlay)
            -- Update info text with current position
            local settings = self.db and self.db.profile and self.db.profile.minimap
            if settings and settings.position and self.minimapOverlay.infoText then
                self.minimapOverlay.infoText:SetText(string.format("Minimap  X:%d Y:%d",
                    math.floor(settings.position[3] or 0),
                    math.floor(settings.position[4] or 0)))
            end
        end
    end
end

-- Helper to show nudge buttons on an overlay
function H3z0UICore:ShowNudgeButtons(overlay)
    if not overlay then return end
    if overlay.nudgeUp then overlay.nudgeUp:Show() end
    if overlay.nudgeDown then overlay.nudgeDown:Show() end
    if overlay.nudgeLeft then overlay.nudgeLeft:Show() end
    if overlay.nudgeRight then overlay.nudgeRight:Show() end
    if overlay.infoText then overlay.infoText:Show() end
end

-- Helper to hide nudge buttons on an overlay
function H3z0UICore:HideNudgeButtons(overlay)
    if not overlay then return end
    if overlay.nudgeUp then overlay.nudgeUp:Hide() end
    if overlay.nudgeDown then overlay.nudgeDown:Hide() end
    if overlay.nudgeLeft then overlay.nudgeLeft:Hide() end
    if overlay.nudgeRight then overlay.nudgeRight:Hide() end
    if overlay.infoText then overlay.infoText:Hide() end
end

end

---=================================================================================
--- CUSTOM TRACKER BAR IMPORT/EXPORT
---=================================================================================

-- Export a single tracker bar (with its spec-specific entries if enabled)
function H3z0UICore:ExportSingleTrackerBar(barIndex)
    if not self.db or not self.db.profile or not self.db.profile.customTrackers
        or not self.db.profile.customTrackers.bars then
        return nil, "No tracker data loaded."
    end
    if not AceSerializer or not LibDeflate then
        return nil, "Export requires AceSerializer-3.0 and LibDeflate."
    end

    local bar = self.db.profile.customTrackers.bars[barIndex]
    if not bar then
        return nil, "Bar not found."
    end

    -- Build export data including spec-specific entries if enabled
    local exportData = {
        bar = bar,
        specEntries = nil,
    }

    -- Include spec-specific entries if the bar uses them
    if bar.specSpecificSpells and bar.id and self.db.global and self.db.global.specTrackerSpells then
        exportData.specEntries = self.db.global.specTrackerSpells[bar.id]
    end

    local serialized = AceSerializer:Serialize(exportData)
    if not serialized or type(serialized) ~= "string" then
        return nil, "Failed to serialize bar."
    end

    local compressed = LibDeflate:CompressDeflate(serialized)
    if not compressed then
        return nil, "Failed to compress bar data."
    end

    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then
        return nil, "Failed to encode bar data."
    end

    return "HCB1:" .. encoded
end

-- Export all tracker bars
function H3z0UICore:ExportAllTrackerBars()
    if not self.db or not self.db.profile or not self.db.profile.customTrackers then
        return nil, "No tracker data loaded."
    end
    if not AceSerializer or not LibDeflate then
        return nil, "Export requires AceSerializer-3.0 and LibDeflate."
    end

    local bars = self.db.profile.customTrackers.bars
    if not bars or #bars == 0 then
        return nil, "No tracker bars to export."
    end

    local exportData = {
        bars = bars,
        specEntries = self.db.global and self.db.global.specTrackerSpells or nil,
    }

    local serialized = AceSerializer:Serialize(exportData)
    if not serialized or type(serialized) ~= "string" then
        return nil, "Failed to serialize bars."
    end

    local compressed = LibDeflate:CompressDeflate(serialized)
    if not compressed then
        return nil, "Failed to compress bar data."
    end

    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then
        return nil, "Failed to encode bar data."
    end

    return "HCT1:" .. encoded
end

-- Import a single tracker bar (appends to existing bars)
-- Generate a collision-safe unique tracker ID
local function GenerateUniqueTrackerID(self)
    local used = {}
    local bars = self.db.profile.customTrackers and self.db.profile.customTrackers.bars or {}
    for _, b in ipairs(bars) do
        if b.id then used[b.id] = true end
    end
    if self.db.global and self.db.global.specTrackerSpells then
        for id in pairs(self.db.global.specTrackerSpells) do
            used[id] = true
        end
    end
    local id
    repeat
        id = "tracker" .. time() .. math.random(1000, 9999)
    until not used[id]
    return id
end

function H3z0UICore:ImportSingleTrackerBar(str)
    if not self.db or not self.db.profile then
        return false, "No profile loaded."
    end
    if not AceSerializer or not LibDeflate then
        return false, "Import requires AceSerializer-3.0 and LibDeflate."
    end
    if not str or str == "" then
        return false, "No data provided."
    end

    str = str:gsub("%s+", "")

    -- Check for correct prefix
    if not str:match("^HCB1:") then
        return false, "This doesn't appear to be a tracker bar export."
    end
    str = str:gsub("^HCB1:", "")

    local compressed = LibDeflate:DecodeForPrint(str)
    if not compressed then
        return false, "Could not decode string (maybe corrupted)."
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return false, "Could not decompress data."
    end

    local ok, data = AceSerializer:Deserialize(serialized)
    if not ok or type(data) ~= "table" or not data.bar then
        return false, "Could not deserialize bar data."
    end

    -- Ensure customTrackers structure exists
    if not self.db.profile.customTrackers then
        self.db.profile.customTrackers = { bars = {} }
    end
    if not self.db.profile.customTrackers.bars then
        self.db.profile.customTrackers.bars = {}
    end

    -- Generate collision-safe unique ID for the imported bar
    local oldID = data.bar.id
    local newID = GenerateUniqueTrackerID(self)
    data.bar.id = newID

    -- Append bar to existing bars
    table.insert(self.db.profile.customTrackers.bars, data.bar)

    -- Copy spec-specific entries if present (with new ID)
    if data.specEntries then
        if not self.db.global then self.db.global = {} end
        if not self.db.global.specTrackerSpells then self.db.global.specTrackerSpells = {} end
        self.db.global.specTrackerSpells[newID] = data.specEntries
    end

    return true, "Bar imported successfully."
end

-- Import all tracker bars (replaceExisting: true = replace all, false = merge/append)
function H3z0UICore:ImportAllTrackerBars(str, replaceExisting)
    if not self.db or not self.db.profile then
        return false, "No profile loaded."
    end
    if not AceSerializer or not LibDeflate then
        return false, "Import requires AceSerializer-3.0 and LibDeflate."
    end
    if not str or str == "" then
        return false, "No data provided."
    end

    str = str:gsub("%s+", "")

    -- Check for correct prefix
    if not str:match("^HCT1:") then
        return false, "This doesn't appear to be a tracker bars export."
    end
    str = str:gsub("^HCT1:", "")

    local compressed = LibDeflate:DecodeForPrint(str)
    if not compressed then
        return false, "Could not decode string (maybe corrupted)."
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return false, "Could not decompress data."
    end

    local ok, data = AceSerializer:Deserialize(serialized)
    if not ok or type(data) ~= "table" or not data.bars then
        return false, "Could not deserialize bars data."
    end

    -- Ensure customTrackers structure exists
    if not self.db.profile.customTrackers then
        self.db.profile.customTrackers = { bars = {} }
    end

    if replaceExisting then
        -- Replace all bars
        self.db.profile.customTrackers.bars = data.bars

        -- Replace spec entries (or clear if none provided)
        if not self.db.global then self.db.global = {} end
        self.db.global.specTrackerSpells = data.specEntries or {}
    else
        -- Merge: append bars with new IDs
        if not self.db.profile.customTrackers.bars then
            self.db.profile.customTrackers.bars = {}
        end

        local idMapping = {}  -- old ID -> new ID

        for _, bar in ipairs(data.bars) do
            local oldID = bar.id
            local newID = GenerateUniqueTrackerID(self)
            bar.id = newID
            idMapping[oldID] = newID
            table.insert(self.db.profile.customTrackers.bars, bar)
        end

        -- Copy spec entries with new IDs
        if data.specEntries then
            if not self.db.global then self.db.global = {} end
            if not self.db.global.specTrackerSpells then self.db.global.specTrackerSpells = {} end

            for oldID, specData in pairs(data.specEntries) do
                local newID = idMapping[oldID]
                if newID then
                    self.db.global.specTrackerSpells[newID] = specData
                end
            end
        end
    end

    return true, "Tracker bars imported successfully."
end

---=================================================================================
--- SPELL SCANNER IMPORT/EXPORT
---=================================================================================

-- Export spell scanner learned data
function H3z0UICore:ExportSpellScanner()
    if not self.db or not self.db.global or not self.db.global.spellScanner then
        return nil, "No spell scanner data to export."
    end
    if not AceSerializer or not LibDeflate then
        return nil, "Export requires AceSerializer-3.0 and LibDeflate."
    end

    local scannerData = self.db.global.spellScanner
    local spellCount = 0
    local itemCount = 0

    if scannerData.spells then
        for _ in pairs(scannerData.spells) do spellCount = spellCount + 1 end
    end
    if scannerData.items then
        for _ in pairs(scannerData.items) do itemCount = itemCount + 1 end
    end

    if spellCount == 0 and itemCount == 0 then
        return nil, "No learned spells or items to export."
    end

    local exportData = {
        spells = scannerData.spells,
        items = scannerData.items,
    }

    local serialized = AceSerializer:Serialize(exportData)
    if not serialized or type(serialized) ~= "string" then
        return nil, "Failed to serialize spell scanner data."
    end

    local compressed = LibDeflate:CompressDeflate(serialized)
    if not compressed then
        return nil, "Failed to compress spell scanner data."
    end

    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then
        return nil, "Failed to encode spell scanner data."
    end

    return "QSS1:" .. encoded
end

-- Import spell scanner data (replaceExisting: true = replace all, false = merge)
function H3z0UICore:ImportSpellScanner(str, replaceExisting)
    if not self.db then
        return false, "No database loaded."
    end
    if not AceSerializer or not LibDeflate then
        return false, "Import requires AceSerializer-3.0 and LibDeflate."
    end
    if not str or str == "" then
        return false, "No data provided."
    end

    str = str:gsub("%s+", "")

    -- Check for correct prefix
    if not str:match("^QSS1:") then
        return false, "This doesn't appear to be spell scanner data."
    end
    str = str:gsub("^QSS1:", "")

    local compressed = LibDeflate:DecodeForPrint(str)
    if not compressed then
        return false, "Could not decode string (maybe corrupted)."
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return false, "Could not decompress data."
    end

    local ok, data = AceSerializer:Deserialize(serialized)
    if not ok or type(data) ~= "table" then
        return false, "Could not deserialize spell scanner data."
    end

    -- Ensure global structure exists
    if not self.db.global then self.db.global = {} end
    if not self.db.global.spellScanner then
        self.db.global.spellScanner = { spells = {}, items = {}, autoScan = false }
    end

    if replaceExisting then
        -- Replace all learned data
        self.db.global.spellScanner.spells = data.spells or {}
        self.db.global.spellScanner.items = data.items or {}
    else
        -- Merge: add new entries without overwriting existing
        if data.spells then
            for spellID, spellData in pairs(data.spells) do
                if not self.db.global.spellScanner.spells[spellID] then
                    self.db.global.spellScanner.spells[spellID] = spellData
                end
            end
        end
        if data.items then
            for itemID, itemData in pairs(data.items) do
                if not self.db.global.spellScanner.items[itemID] then
                    self.db.global.spellScanner.items[itemID] = itemData
                end
            end
        end
    end

    return true, "Spell scanner data imported successfully."
end
