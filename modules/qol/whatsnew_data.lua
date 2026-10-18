--[[
    H3z0 UI - What's New (shown once after each update)

    Change version for every release you hand out, and raise build for every
    update of the same version: the window shows once on the first login with
    a version + build that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.24.7",
    build = 3,
    new = {
        "|cff34D399Resource orbs|r: the secondary class resource bar can show combo points, holy power, chi, soul shards, essence and arcane charges as round orbs (Style: Orbs). Cooldown Manager > Class Resource Bar.",
        "|cff34D399Layout Mode controls everything|r: click a frame for an on / off switch and its settings (action bars: rows, icons, size, padding, visibility), and Show / Hide lists every frame to switch on or off. No need to open Blizzard's Edit Mode.",
        "|cff34D399Bar Layout|r (Action Bars, first tab): orientation, rows, number of icons, icon size, padding and visibility of every bar, like Blizzard's Edit Mode, right in the H3z0 UI options. Right click a bar in Layout Mode to open it there.",
    },
    fixed = {
        "Switching a cast bar (or a unit frame in Layout Mode) on or off reloads right away, so there are never two cast bars.",
        "Character and Inspect windows no longer overlap when both are open.",
        "From 0.24.5: H3z0 UI Raid Frames with a 20-player preview in Layout Mode.",
    },
}
