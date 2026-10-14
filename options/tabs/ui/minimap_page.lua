local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local Shared = ns.H3z0UI_Options

local CreateScrollableContent = Shared.CreateScrollableContent

--------------------------------------------------------------------------------
-- PAGE: Minimap & Datatext (coordinator - subtabs from separate files)
--------------------------------------------------------------------------------
local function CreateMinimapPage(parent)
    local scroll, content = CreateScrollableContent(parent)

    GUI:CreateSubTabs(content, {
        {name = "Minimap", builder = ns.H3z0UI_MinimapOptions.BuildMinimapTab},
        {name = "Datatext", builder = ns.H3z0UI_MinimapOptions.BuildDatatextTab},
    })

    content:SetHeight(700)
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------
ns.H3z0UI_MinimapPageOptions = {
    CreateMinimapPage = CreateMinimapPage,
}
