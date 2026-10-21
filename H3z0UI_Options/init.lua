local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI

local function IsLockedDown()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function SetKeyboardPropagation(frame, propagate)
    if IsLockedDown() then return false end
    if frame and frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(propagate)
        return true
    end
    return false
end

function GUI:InitializeOptions()
    local frame = self:CreateMainFrame()

    self:AddSidebarSearchBar(frame)

    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(self, key)
        local focused = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if (not focused or key == "ESCAPE") and GUI.HandleNavigationKey and GUI:HandleNavigationKey(self, key) then
            SetKeyboardPropagation(self, false)
            return
        end
        if key == "ESCAPE" then
            SetKeyboardPropagation(self, false)
            self:Hide()
            return
        end
        if focused and focused ~= frame._searchBox and focused ~= (frame._searchBox and frame._searchBox.editBox) then
            SetKeyboardPropagation(self, true)
            return
        end
        local ctrl = IsControlKeyDown and IsControlKeyDown()
        if ctrl and key == "F" then
            SetKeyboardPropagation(self, false)
            C_Timer.After(0, function()
                GUI:FocusSearchBox()
            end)
            return
        end
        SetKeyboardPropagation(self, true)
    end)

    if ns.H3z0UI_Options and type(ns.H3z0UI_Options.RegisterFeatureTile) == "function" then
        ns.H3z0UI_Options.RegisterFeatureTile(frame, {
            id = "welcome",
            icon = "*",
            name = ns.L["Welcome"],
            subtitle = ns.L["Getting started · Tips · What's new"],
            featureId = "welcomePage",
            noScroll = false,
        })
    end

    if ns.H3z0UI_H3z0Tiles then
        ns.H3z0UI_H3z0Tiles.RegisterAll(frame)
    end

    if ns.H3z0UI_GlobalTile then
        ns.H3z0UI_GlobalTile.Register(frame)
    end
    if ns.H3z0UI_ActionBarsTile then
        ns.H3z0UI_ActionBarsTile.Register(frame)
    end
    if ns.H3z0UI_AurasTile then
        ns.H3z0UI_AurasTile.Register(frame)
    end
    if ns.H3z0UI_CooldownManagerTile then
        ns.H3z0UI_CooldownManagerTile.Register(frame)
    end
    if ns.H3z0UI_ResourceBarsTile then
        ns.H3z0UI_ResourceBarsTile.Register(frame)
    end
    if ns.H3z0UI_MinimapTile then
        ns.H3z0UI_MinimapTile.Register(frame)
    end
    if ns.H3z0UI_InfoBarTile then
        ns.H3z0UI_InfoBarTile.Register(frame)
    end
    if ns.H3z0UI_AppearanceTile then
        ns.H3z0UI_AppearanceTile.Register(frame)
    end
    if ns.H3z0UI_ChatTooltipsTile then
        ns.H3z0UI_ChatTooltipsTile.Register(frame)
    end
    if ns.H3z0UI_GameplayTile then
        ns.H3z0UI_GameplayTile.Register(frame)
    end
    if ns.H3z0UI_RemindersTile then
        ns.H3z0UI_RemindersTile.Register(frame)
    end
    if ns.H3z0UI_QoLTile then
        ns.H3z0UI_QoLTile.Register(frame)
    end
    if ns.H3z0UI_BagsTile then
        ns.H3z0UI_BagsTile.Register(frame)
    end
    if ns.H3z0UI_AltsTile then
        ns.H3z0UI_AltsTile.Register(frame)
    end

    if ns.H3z0UI_HelpTile then
        ns.H3z0UI_HelpTile.Register(frame)
    end

    self:AddToolsStripButton(frame, {
        id = "cdm_settings", icon = "+", label = ns.L["Blizz CDM"],
        onClick = function()
            if CooldownViewerSettings then
                CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown())
            end
        end,
    })
    self:AddToolsStripButton(frame, {
        id = "blizz_edit", icon = ">", label = ns.L["Blizz Edit"],
        onClick = function()
            if InCombatLockdown() then return end
            if EditModeManagerFrame then
                ShowUIPanel(EditModeManagerFrame)
            end
        end,
    })
    self:AddToolsStripButton(frame, {
        id = "layout", label = ns.L["Layout Mode"],
        onClick = function()
            if InCombatLockdown and InCombatLockdown() then
                print("|cff60A5FAH3z0UI:|r Cannot open Layout Mode during combat.")
                return
            end
            if GUI and GUI.Hide then GUI:Hide() end
            if _G.H3z0UI_OpenLayoutMode then _G.H3z0UI_OpenLayoutMode() end
        end,
    })

    self:SeedStaticSearchRoutesFromTiles(frame)

    if self.LayoutSidebarGroups then self:LayoutSidebarGroups(frame) end

    GUI:SelectFeatureTile(frame, 1)

    return frame
end
