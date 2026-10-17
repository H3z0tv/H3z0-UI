--[[
    H3z0 UI - What's New (shown once after each update)

    Change `version` for every release you hand out: the window shows once on
    the first login with a version that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.24.1",
    new = {
        "|cff34D399One font for everything|r: Poppins SemiBold is the H3z0 UI font for unit frames, bars, chat, tooltips, nameplates, Blizzard's menus and the options window. Pick another in the Setup Wizard (new \"Pick your font\" step) or General & QoL > Default Font Settings - it goes on everything at once.",
        "|cff34D399Slate look|r for the chat and the damage meter: one solid dark panel with a thin grey border, readable tab names, no tab boxes and a typing box with no background - only \"Say:\". Separate opacity sliders for chat and damage meter. Unit Frames > Portraits > Window Skins.",
        "|cff34D399Modern Action Buttons|r: slate tiles in the same colour as the chat, small rounded corners, rounded cooldown swipe. Controlled by Action Bars > Button Appearance (Backdrop, Borders, Gloss, Icon Crop).",
        "|cff34D399Modern Cast Bars|r: player / target / focus / boss cast bars in the H3z0 Nameplates look - rounded outline and the spell icon as its own tile.",
        "|cff34D399Unit frames in nameplate colours|r: Player, Target, Focus and boss frames use the H3z0 Nameplates colours (class, hostile, neutral, friendly, tapped and the Mythic colours). Nameplates page > Nameplate Colours on Unit Frames.",
        "|cff34D399H3z0 Nameplates|r cast bar: same width as the health bar, bigger and rounded; Blizzard's nameplate cast bar stays hidden.",
        "|cff34D399H3z0 Nameplates|r (from 0.24.0, Nameplates page or /h3z0ui plates): rounded bars, level | name, cast bar, target arrows, threat border and Mythic colours, made to keep working in Mythic+ keys.",
    },
    fixed = {
        "Rounded corners only rounded three corners (the game applies at most three masks to one texture) - all four corners are round now.",
        "The rounded square minimap stayed square - fixed, and if another addon (for example Leatrix Plus square minimap) puts its own shape on the map, H3z0 UI puts the rounded one back. /h3z0ui round shows what replaced it.",
        "Chat tab names were hidden behind the new chat background.",
        "The Panel Scale slider in the options header ran into the close button.",
        "Removed the green accent lines on the minimap info bar, the damage meter header and the Bottom Bar.",
        "The Default Font only changed some text - it now goes on every element.",
    },
}
