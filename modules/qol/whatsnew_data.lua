--[[
    H3z0 UI - What's New (shown once after each update)

    Change version for every release you hand out, and raise build for every
    update of the same version: the window shows once on the first login with
    a version + build that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.24.4",
    build = 2,
    new = {
        "|cff34D399Stacking & Overlap|r (Nameplates page): Stacked or Overlapping nameplates, and Vertical / Horizontal Spacing sliders for how close they may sit. Works for every nameplate and is kept on every login.",
    },
    fixed = {
        "Options window: the sidebar names (Cooldown Manager, Skinning & Autohide) no longer run over the divider line.",
        "WoW: Forever: the addon is now called H3z0 UI Forever there.",
        "Options window: long option names no longer run into the switches, sliders and dropdowns (wider name column, retail and WoW: Forever).",
        "WoW: Forever nameplates: Blizzard's level box no longer sticks out on the right of the bar.",
        "From 0.24.3: smoother H3z0 Nameplates in big pulls and the tracked buff bar overlap fix.",
    },
}
