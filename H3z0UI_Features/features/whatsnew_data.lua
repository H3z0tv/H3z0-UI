--[[
    H3z0 UI - What's New (shown once after each update)

    Change version for every release you hand out, and raise build for every
    update of the same version: the window shows once on the first login with
    a version + build that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.25.0",
    build = 3,
    new = {
        "|cff34D399New base|r: H3z0 UI is rebuilt on a new, larger codebase. Every part ships as its own module folder (H3z0UI_ActionBars, H3z0UI_CDM, H3z0UI_UnitFrames, ...) and can be switched off in Options > General > Feature Toggles.",
        "|cff34D399Your own modules kept|r: Chat, Damage Meter skin, H3z0 Features, Nameplates, Unit Frames, Party Frames and Raid Frames.",
        "|cff34D399Bottom Bar|r: now the Info Bar, set up with your Bottom Bar settings and your own menu icons (spec left, clock in the middle, professions, gold, bags and location right). It hides Blizzard's micro menu and bag bar again. All its settings are on the Bottom Bar page.",
        "|cff34D399Action Bars|r: H3z0 UI draws its own action bars now, with your H3z0 look (skin, text, mouseover fade, Modern Action Buttons, Streamer Mode). Blizzard can't push them around any more. Each bar keeps the place you gave it in H3z0 UI Edit Mode and its icon size, padding and rows.",
        "|cff34D399H3z0 UI Edit Mode|r: action bars, chat and damage meter can be moved there; chat and damage meter also resized (grip in the corner). PC and Deck keep separate positions.",
        "|cff34D399Bags|r: new Inventory window - categories sidebar (All Items, OneBag, Pinned, Recent, The Armory, Adventure Prep, Professions, Reagent Bag, ...), middle-click to pin, drop an item on a category's + to keep it there, Add Category for your own.",
        "|cff34D399Quick Access|r is back on the Group Finder, with My Searches: type a dungeon or words plus a key level, search, or keep it as your own button.",
        "|cff34D399Streamer Mode|r is back in H3z0 Features (also /h3z0ui streamer).",
        "|cff34D399Character and Inspect|r: homeland background and the H3z0 UI logo in the corner again.",
        "|cff34D399Chat|r: move and resize it in H3z0 UI Edit Mode (Chat Frame handle, corner grips to resize).",
        "|cff34D399Esc menu|r: Blizzard's own look; H3z0 UI and H3z0 UI Edit Mode sit right under Return to Game.",
        "|cff34D399Cooldown Manager|r: your H3z0 UI Cooldown Manager is back - Essential, Utility, Custom Entries, Buff and Effects pages, with your own look (no green line under Essential).",
        "|cff34D399Buff Bars|r: your buff icons and buff bars are back, set on Cooldown Manager > Buff.",
        "|cff34D399Resource Bars|r: primary and secondary bars sit under the Essential cooldowns with your H3z0 look; settings on the Resource Bars page and in H3z0 UI Edit Mode (right-click the bar). Positions no longer reset.",
        "|cff34D399Custom Trackers|r: your tracker bars and the spell scanner are back on their own page.",
        "|cff34D399H3z0 UI Edit Mode|r: the Cooldown Manager viewers (Essential, Utility, Buff Icons, Buff Bars) can be moved there too.",
        "|cff34D399Minimap|r: your H3z0 UI minimap is back with its own layout (square map, zone text, clock, coordinates, datatext panel under the map). Move the map and the coordinates in H3z0 UI Edit Mode.",
        "|cff34D399Hover Name|r is back: names next to the cursor while hovering players and NPCs (H3z0 Features > Hover Name).",
        "|cff34D399Chat|r settings are one page again (Chat and Look & Hide together), with the module switch next to it.",
        "|cff34D399Damage Meter|r: always listed in H3z0 UI Edit Mode (shown while it is open), extra meter windows too.",
        "|cff34D399Friendly NPC nameplates|r: Always Off (default), Always On or Game Setting on the Nameplates page.",
    },
    fixed = {
        "Skyriding bar is off by default.",
        "Cooldown Manager: no press / click highlight on the icons.",
        "Bags: rounded window with a softer slate background.",
        "WoW: Forever: empty action buttons are hidden by default.",
        "H3z0 UI Edit Mode: scaled frames stay exactly where you drop them (they used to jump when Edit Mode closed).",
        "H3z0 UI Edit Mode: chat and damage meter can be resized again with the grip in the corner of their handle.",
        "Chat and Damage Meter: background opacity and window skin in their H3z0 UI Edit Mode settings (right-click the handle) and on the Chat page.",
        "Bottom Bar: while it is on, the action bars' micro menu and bag bar are off (its menu icons replace them).",
        "Install: delete the old H3z0UI folder first, then copy all H3z0UI folders from the zip into AddOns. Your settings (H3z0UIDB) are kept; a backup of your profile is made on the first login.",
    },
}
