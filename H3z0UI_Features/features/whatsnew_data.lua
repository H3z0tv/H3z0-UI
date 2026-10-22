--[[
    H3z0 UI - What's New (shown once after each update)

    Same text as PATCH_NOTES.md (the newest version). Change version for every
    release you hand out, and raise build for every update of the same version:
    the window shows once on the first login with a version + build that hasn't
    been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.25.1",
    build = 2,
    sections = {
        {
            title = "New",
            items = {
                "H3z0 UI Edit Mode: right-click any handle and the settings panel has an ON/OFF switch next to the close button, for everything that can be turned off. It is the same switch as the eye in the frames list.",
                "H3z0 UI Edit Mode: the Cooldown Manager viewers (Essential, Utility, Buff Icons, Buff Bars), the party and raid frames and the player, target and focus cast bars can now be turned off and on.",
                "H3z0 UI Edit Mode: right-click Essential, Utility, Buff Icons or Buff Bars to get its own Cooldown Manager settings; Open in Settings goes to that tab.",
                "H3z0 UI Edit Mode: right-click the Minimap (or the map coordinates) to get the Minimap and Datatext settings; Open in Settings goes to the Minimap & Datatext page.",
                "Action Tracker: Enabled switch at the top of its settings.",
            },
        },
        {
            title = "Fixed",
            items = {
                "Cooldown Manager: Essential, Utility, Buff Icons and Buff Bars no longer jump back to an old place (reload, spec change, opening and closing Edit Mode).",
                "Cooldown Manager: a viewer moved in Blizzard's Edit Mode keeps that place in H3z0 UI too.",
                "WoW: Forever: the chat typing box (after pressing Enter) is transparent again, no dark box around it.",
                "Resource Bars: the width you set for the primary (and secondary) resource bar stays after a reload. New Match Cooldown Width option next to Width: on, the bar takes the Essential cooldowns' width; setting a Width turns it off.",
            },
        },
        {
            title = "Install",
            items = {
                "Delete the old H3z0UI folders first, then copy all H3z0UI folders from the zip into AddOns.",
                "Your settings are kept.",
            },
        },
    },
}
