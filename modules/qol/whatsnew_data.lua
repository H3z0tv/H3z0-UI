--[[
    H3z0 UI - What's New (shown once after each update)

    Change version for every release you hand out, and raise build for every
    update of the same version: the window shows once on the first login with
    a version + build that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.24.3",
    build = 1,
    new = {
        "|cff34D399Smoother H3z0 Nameplates|r: the nameplates do much less work per update in big pulls - settings, zone, spec and addon checks are no longer redone on every health or cast update, borders only change when the threat or target state changes, and a plate that shows up again keeps its layout.",
        "Coming from 0.24.1 or older? 0.24.2 brought the UI Look page (Classic / Modern / Modern v2 with only that version's options), Character and Inspect v2, a much faster options window and many fixes - see PATCH_NOTES.md.",
    },
    fixed = {
        "Tracked buff bars (Cooldown Manager): a bar that stayed in Blizzard's look and position and overlapped the H3z0 UI bars is styled and stacked like the rest now.",
        "Tracked bars are only re-styled when something changed instead of 10 times a second for every bar.",
        "Changing your target looks up the target's nameplate once instead of once per nameplate.",
    },
}
