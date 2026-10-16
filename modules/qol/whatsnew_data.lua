--[[
    H3z0 UI - What's New (shown once after each update)

    Change `version` for every release you hand out: the window shows once on
    the first login with a version that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.23.1",
    new = {
        "New menu order: |cff34D399H3z0 Features|r, |cff34D399Nameplates|r, General & QoL, |cff34D399Party Frames|r, Cooldown Manager, Unit Frames ... |cff34D399Portraits|r is now a tab in Unit Frames.",
        "H3z0 Features: Combat Mode, Bottom Bar, Steam Deck + PC Controller, Layout & Bars, Map and Extras.",
        "This |cff34D399What's New|r window - opens once after every update (/h3z0ui whatsnew to see it again).",
        "Layout Mode: right-click the |cff34D399Objective Tracker|r to open its skin settings, buffs / debuffs open Buff & Debuff.",
    },
    fixed = {
        "Objective Tracker skin: text overlapping or out of place after changing its font sizes.",
        "Dropdown lists in the menu (e.g. Bar Texture) opening behind switches and headers, so nothing could be picked.",
        "ConsolePort / Action Combat Mode switching on WoW: Forever (Handheld Mode, PC Controller, Setup Wizard) - all ConsolePort modules switch together now.",
    },
}
