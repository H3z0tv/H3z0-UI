--[[
    H3z0 UI - What's New (shown once after each update)

    Change version for every release you hand out, and raise build for every
    update of the same version: the window shows once on the first login with
    a version + build that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.24.5",
    build = 2,
    new = {
        "|cff34D399Raid Frames|r: one column per group with the group number on top, slate tiles with the name in class colour, level, class coloured health, tank / healer badge and a power bar for tanks and healers, and the pets in their own column. Works in combat (click to target, right click menu).",
        "Move them in |cff34D399Layout Mode|r - a 20-player preview with pets shows while you are not in a raid. Settings: Party Frames > Raid Frames.",
    },
    fixed = {
        "Raid frames preview shows without a group again (Layout Mode, Party Frames > Raid Frames > Preview, /h3z0raid test).",
        "In a raid the party frames step aside while the raid frames are on.",
        "From 0.24.4: nameplate Stacking & Overlap, cleaner options window, H3z0 UI Forever name, Forever menu icons and nameplate level box.",
    },
}
