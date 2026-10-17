--[[
    H3z0 UI - What's New (shown once after each update)

    Change `version` for every release you hand out: the window shows once on
    the first login with a version that hasn't been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.23.7",
    new = {
        "|cff34D399Streamer Mode|r (Action Bars > Master Settings, or /h3z0ui streamer): hides the yellow highlight that shows on an action button when you press it (press glow, active border, cast fill), so viewers can't see which keys you press.",
        "|cff34D399Resize the chat window and the damage meter|r in H3z0 UI Layout Mode: drag the corner grip at the bottom right of their handle. Sizes are saved in H3z0 UI (PC and Deck) and included in layout codes.",
        "|cff34D399PC Handheld|r (H3z0 Features > Steam Deck + PC Controller, /h3z0ui pchandheld): the Steam Deck layout and ConsolePort on PC, with your normal PC UI scale.",
        "Layout Mode now saves Blizzard frame positions (action bars, Cooldown Manager, buffs, ...) in H3z0 UI - Blizzard's Edit Mode layouts are no longer created or changed.",
        "New default H3z0 UI layout for new installs (PC and Deck).",
        "M+ Timer: new |cff34D399H3z0 Pro|r layout - big timer, +3 / +2 / +1 bars with the time left above them, enemy forces with your current pull (orange), boss kill times, a death log on the deaths tooltip and enemy forces in unit tooltips. Skinning & Autohide > Skinning > H3z0 UI M+ Timer (Toggle Demo Mode to see it). Your timer is switched to it once - pick another layout there if you prefer.",
    },
    fixed = {
        "Tracked Bars: a bar could come out shorter and shifted to the side (Blizzard anchored it by both edges). Every bar is now checked for the right anchor and width and put back in line.",
        "Party Frames ready check: icons still didn't show for some groups - the icon now sits on its own top layer, every step is protected so one odd value can't stop it, and the frames re-check twice a second while a ready check runs. /h3z0party rcdebug prints what happens if it still fails.",
        "Tracked Buffs kept changing look and jumping around while playing: H3z0 UI resized Blizzard's buff viewer on every buff change, which made both sides lay the icons out again and again. The viewer keeps its size now; H3z0 UI only arranges and skins the icons.",
        "Extra Action / Zone Ability button kept disappearing and couldn't be moved in Layout Mode: it now stays in Blizzard's own container (H3z0 UI only applies scale / hide artwork) and is moved with the Extra Abilities handle in Layout Mode (a square placeholder when no extra button is active). Your old position is carried over once.",
        "\"GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by H3z0UI\" (hundreds of times, from the quest tracker): H3z0 UI no longer writes into or runs Blizzard's Objective Tracker, Tracked Bars or Talking Head code. The tracker's own height is set in Edit Mode now (the H3z0 \"Max Height\" only limits the background).",
        "Objective Tracker skin: completed objectives (e.g. Prey quests) looked unfinished because every line was painted in the text colour - completed / failed lines keep Blizzard's colours and tick now.",
        "Party Frames: ready check icons didn't show - answers are now read straight from the ready check itself (tick / cross / waiting on each portrait). /h3z0party ready previews them.",
        "Switching Handheld Mode / PC Controller no longer creates or switches \"H3z0 PC\" / \"H3z0 Deck\" Edit Mode layouts - pick your own Edit Mode layout once with /h3z0ui blizzedit if needed.",
        "Layout Mode: right-clicking the Chat Frame opens the Chat settings (Extra Action / Talking Head / XP bar open theirs too); frames without settings no longer print lines in chat.",
        "Unticking PC Handheld did nothing - it now turns PC Handheld off (back to the normal PC layout and addons) and reloads. Switching from Steam Deck to PC Handheld in the menu works too.",
        "Hover Name sat right on the cursor and covered your aim - it now keeps more distance, and extra while mouselooking / Action Combat (new \"Gap While Aiming\" slider in General & QoL > Hover Name).",
        "ADDON_ACTION_FORBIDDEN \"UpgradeItem()\" when upgrading items: H3z0 UI replaced Blizzard's money display function (used by the upgrade cost in that popup) - it no longer replaces any Blizzard function, and its popups use their own window. \"Auto-Fill DELETE Text\" (General & QoL) is now off by default because it has to write into Blizzard's popup.",
        "Objective Tracker skin: the Delves section showed an empty gap (the delve banner was hidden) - the banner stays in delves now, and the tracker refreshes when a scenario ends or you change zone.",
        "Only one of PC Controller, PC Handheld and Steam Deck can be on at a time.",
    },
}
