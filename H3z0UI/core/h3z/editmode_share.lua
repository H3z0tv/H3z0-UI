local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Blizzard Edit Mode layout inside the H3z0 UI profile string
-- Export: the Edit Mode layout you use now goes into the profile string, so
-- whoever imports it gets the same Blizzard frame layout too.
-- Import: it is saved as the Edit Mode layout "H3z0 UI Shared" and made
-- active (out of combat; after combat if needed).
---------------------------------------------------------------------------

local ES = {}
ns.H3z0EditModeShare = ES

ES.KEY = "_h3z0uiEditMode"
ES.LAYOUT_NAME = "H3z0 UI Shared"

local function Available()
    return C_EditMode and C_EditMode.GetLayouts and C_EditMode.ConvertLayoutInfoToString
        and C_EditMode.ConvertStringToLayoutInfo and C_EditMode.SaveLayouts and C_EditMode.SetActiveLayout
        and Enum and Enum.EditModeLayoutType and _G.EditModePresetLayoutManager
        and _G.EditModePresetLayoutManager.GetCopyOfPresetLayouts
end

-- all layouts in Blizzard's order (presets first, then yours) and the active index
local function AllLayouts()
    local info = C_EditMode.GetLayouts()
    if type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
    local list = _G.EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    if type(list) ~= "table" then return nil end
    local presets = #list
    for i = 1, #info.layouts do list[#list + 1] = info.layouts[i] end
    return info, list, presets
end

-- { name = "...", data = "<Edit Mode export string>" } of the active layout
function ES.Export()
    if not Available() then return nil end
    local ok, res = pcall(function()
        local info, list = AllLayouts()
        if not info then return nil end
        local active = list[info.activeLayout or 0]
        if type(active) ~= "table" then return nil end
        local str = C_EditMode.ConvertLayoutInfoToString(active)
        if type(str) ~= "string" or str == "" then return nil end
        return { name = tostring(active.layoutName or "Layout"), data = str }
    end)
    return ok and res or nil
end

---------------------------------------------------------------------------
-- Buff frame and debuff frame anchored to each other in an Edit Mode layout
-- (snapping one to the other both ways). Blizzard then warns "Cannot anchor
-- to a region dependent on it" every time it applies the layout. The buff
-- frame gets its own spot again (top right of the screen); H3z0 UI draws its
-- own buff / debuff icons anyway.
---------------------------------------------------------------------------
local function RelName(anchor)
    local r = anchor and anchor.relativeTo
    if type(r) == "table" and r.GetName then r = r:GetName() end
    return r
end

function ES.FixAuraLoop(layout)
    local S = Enum and Enum.EditModeSystem
    local I = Enum and Enum.EditModeAuraFrameSystemIndices
    if not (S and S.AuraFrame ~= nil and I and type(layout) == "table" and type(layout.systems) == "table") then return false end
    local buff, debuff
    for _, sys in ipairs(layout.systems) do
        if sys.system == S.AuraFrame then
            if sys.systemIndex == I.BuffFrame then buff = sys
            elseif sys.systemIndex == I.DebuffFrame then debuff = sys end
        end
    end
    if not (buff and debuff) then return false end
    local function points(sys, name)
        return RelName(sys.anchorInfo) == name or RelName(sys.anchorInfo2) == name
    end
    if points(buff, "DebuffFrame") and points(debuff, "BuffFrame") then
        buff.anchorInfo = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", offsetX = -205, offsetY = -13 }
        buff.anchorInfo2 = nil
        buff.isInDefaultPosition = false
        return true
    end
    return false
end

-- the layout in use: fixed once if it has that loop
function ES.FixActiveLayout()
    if not Available() or InCombatLockdown() then return end
    pcall(function()
        local info, list, presets = AllLayouts()
        if not info then return end
        local idx = info.activeLayout
        if not idx or idx <= presets then return end      -- Blizzard's presets are fine
        if ES.FixAuraLoop(list[idx]) then
            info.layouts = list
            C_EditMode.SaveLayouts(info)
        end
    end)
end

local pending
function ES.Import(entry)
    if type(entry) ~= "table" or type(entry.data) ~= "string" or entry.data == "" then return false end
    if not Available() then return false, "Edit Mode is not available on this client." end
    if InCombatLockdown() then
        pending = entry
        return true, "after combat"
    end
    local ok, err = pcall(function()
        local newInfo = C_EditMode.ConvertStringToLayoutInfo(entry.data)
        if type(newInfo) ~= "table" or type(newInfo.systems) ~= "table" then
            error("The Edit Mode layout in this profile string was not recognized.", 0)
        end
        ES.FixAuraLoop(newInfo)
        local info, list, presets = AllLayouts()
        if not info then error("Edit Mode layout list unavailable.", 0) end
        local target
        for i = presets + 1, #list do
            if list[i].layoutName == ES.LAYOUT_NAME then target = i break end
        end
        if target then
            list[target].systems = newInfo.systems
        else
            newInfo.layoutType = Enum.EditModeLayoutType.Account
            newInfo.layoutName = ES.LAYOUT_NAME
            list[#list + 1] = newInfo
            target = #list
        end
        info.layouts = list
        C_EditMode.SaveLayouts(info)
        C_EditMode.SetActiveLayout(target)
    end)
    if not ok then return false, tostring(err) end
    return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        C_Timer.After(3, ES.FixActiveLayout)
        return
    end
    if pending then
        local e = pending
        pending = nil
        ES.Import(e)
    end
end)
