--[[
    H3z0 UI - What's New (shown once after each update)

    Change version for every release you hand out, and raise build for every
    update of the same version: the window shows once on the first login with
    a version + build that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.24.9",
    build = 1,
    new = {
        "|cff34D399Reload popup|r: when a change only fully applies after a reload (a module switched off, party / raid frames on or off, a profile imported, ...), H3z0 UI asks: Reload Now or Later. Several changes are collected into one popup.",
        "|cff34D399Character Panel|r: every Slot Overlays option now works in the Modern v2 look - equipment name, item level with upgrade track, enchant names and colours, gems and durability bars. Display Format, Header Color and Background Color work there too.",
    },
    fixed = {
        "Tracked bars: only Blizzard's look showed and the options did nothing. Blizzard replaces the bars' update script whenever it lays them out, which removed the H3z0 UI check - it now runs on its own frame, so the H3z0 look stays on every bar.",
        "Stat tooltips switch on and off right away.",
        "Skyriding: Segment Marker Color now colours the markers.",
        "Every option in the addon was checked against the code that uses it; the one that did nothing (Minimap datatext Force Single Line) was removed.",
    },
}
