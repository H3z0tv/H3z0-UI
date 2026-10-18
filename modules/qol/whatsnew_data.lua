--[[
    H3z0 UI - What's New (shown once after each update)

    Change version for every release you hand out, and raise build for every
    update of the same version: the window shows once on the first login with
    a version + build that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.24.6",
    build = 1,
    new = {
        "|cff34D399Bar Layout|r (Action Bars, first tab): orientation, rows, number of icons, icon size, padding and visibility of every bar, like Blizzard's Edit Mode, right in the H3z0 UI options. Right click a bar in Layout Mode to open it there.",
    },
    fixed = {
        "From 0.24.5: H3z0 UI Raid Frames with a 20-player preview in Layout Mode.",
    },
}
