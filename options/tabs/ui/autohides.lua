local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local Shared = ns.H3z0UI_Options

local CreateScrollableContent = Shared.CreateScrollableContent

--------------------------------------------------------------------------------
-- PAGE: Autohide & Skinning (coordinator - subtabs from separate files)
--------------------------------------------------------------------------------
local function CreateAutohidesPage(parent)
    local scroll, content = CreateScrollableContent(parent)

    GUI:CreateSubTabs(content, {
        {name = "Autohide", builder = ns.H3z0UI_AutohideOptions.BuildAutohideTab},
        {name = "Skinning", builder = ns.H3z0UI_SkinningOptions.BuildSkinningTab},
    })

    content:SetHeight(600)
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------
ns.H3z0UI_AutohidesOptions = {
    CreateAutohidesPage = CreateAutohidesPage,
}
