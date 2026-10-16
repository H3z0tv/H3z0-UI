--[[
    H3z0 UI - What's New (shown once after each update)

    Change `version` for every release you hand out: the window shows once on
    the first login with a version that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.23.2",
    new = {
        "|cff34D399PC Handheld|r (H3z0 Features > Steam Deck + PC Controller, /h3z0ui pchandheld): the Steam Deck layout and ConsolePort on PC, with your normal PC UI scale.",
        "Layout Mode now saves Blizzard frame positions (action bars, Cooldown Manager, buffs, ...) in H3z0 UI - Blizzard's Edit Mode layouts are no longer created or changed.",
        "New default H3z0 UI layout for new installs (PC and Deck).",
    },
    fixed = {
        "Switching Handheld Mode / PC Controller no longer creates or switches \"H3z0 PC\" / \"H3z0 Deck\" Edit Mode layouts - pick your own Edit Mode layout once with /h3z0ui blizzedit if needed.",
        "Only one of PC Controller, PC Handheld and Steam Deck can be on at a time.",
    },
}
