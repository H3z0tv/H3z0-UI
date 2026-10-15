local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local Shared = ns.H3z0UI_Options

local CreateScrollableContent = Shared.CreateScrollableContent

--------------------------------------------------------------------------------
-- PAGE: General & QoL (coordinator - subtabs from separate files)
--------------------------------------------------------------------------------
local function CreateGeneralQoLPage(parent)
    local scroll, content = CreateScrollableContent(parent)

    GUI:CreateSubTabs(content, {
        {name = "General", builder = ns.H3z0UI_QoLOptions.BuildGeneralTab},
        {name = "HUD Visibility", builder = ns.H3z0UI_HUDVisibilityOptions.BuildHUDVisibilityTab},
        {name = "Cursor & Crosshair", builder = ns.H3z0UI_CrosshairOptions.BuildCrosshairTab},
        {name = "Buff & Debuff", builder = ns.H3z0UI_BuffDebuffOptions.BuildBuffDebuffTab},
        {name = "Chat", builder = ns.H3z0UI_ChatOptions.BuildChatTab},
        {name = "Tooltip", builder = ns.H3z0UI_TooltipsOptions.BuildTooltipTab},
        {name = "Hover Name", builder = ns.H3z0UI_HoverNameOptions.BuildHoverNameTab},
        {name = "Character Pane", builder = ns.H3z0UI_CharacterOptions.BuildCharacterPaneTab},
        {name = "Skyriding", builder = ns.H3z0UI_SkyridingOptions.BuildDragonridingTab},
        {name = "Missing Raid Buffs", builder = ns.H3z0UI_RaidBuffsOptions.BuildRaidBuffsTab},
        {name = "Party Keystones", builder = ns.H3z0UI_PartyKeystonesOptions.BuildPartyKeystonesTab},
        {name = "Quick Access", builder = ns.H3z0UI_QuickAccessOptions.BuildQuickAccessTab},
        {name = "Combat Mode", builder = ns.H3z0UI_CombatModeOptions.BuildCombatModeTab},
        {name = "Bottom Bar", builder = ns.H3z0UI_BottomBarOptions.BuildBottomBarTab},
        {name = "Steam Deck", builder = ns.H3z0UI_HandheldOptions.BuildHandheldTab},
        {name = "Nameplates", builder = ns.H3z0UI_NameplatesOptions.BuildNameplatesTab},
        {name = "Party Frames", builder = ns.H3z0UI_PartyFramesOptions.BuildPartyFramesTab},
    })

    content:SetHeight(600)
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------
ns.H3z0UI_GeneralOptions = {
    CreateGeneralQoLPage = CreateGeneralQoLPage,
}
