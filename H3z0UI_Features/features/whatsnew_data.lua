--[[
    H3z0 UI - What's New (shown once after each update)

    Same text as PATCH_NOTES.md (the newest version). Change version for every
    release you hand out, and raise build for every update of the same version:
    the window shows once on the first login with a version + build that hasn't
    been seen yet.
]]

local ADDON_NAME, ns = ...

ns.WhatsNew = {
    version = "0.28.2",
    build = 16,
    sections = {
        {
            title = "Midnight",
            items = {
                "Lorekeeper: the confirm and cancel hints on the two big buttons now follow your controller. Under Lorekeeper > Button Hints Written For you can pick Automatic, Keyboard and mouse (Space, Esc), Xbox (A, B), PlayStation (Cross, Circle) or Switch (B, A). Automatic shows the Xbox letters when a game controller is on and ConsolePort is not.",
                "Lorekeeper: with an Xbox, PlayStation or Switch controller picked (or found automatically), the two big buttons show round controller button pictures (A and B, Cross and Circle) instead of key letters. The gold coin and the green arrow on rewards are now Lorekeeper's own pictures.",
                "Lorekeeper: when a quest lets you choose a reward, the choice that sells for the most gets a small gold coin on its icon (only when the game knows the sell price of every choice and one is clearly the highest). Gear that is better than what you wear in that slot gets a green arrow, and the tooltip says by how much. Both can be switched off in the Lorekeeper options.",
                "Lorekeeper: new option Smaller Currency Rewards. Currency and money rewards show only the icon and the amount, in a smaller icon.",
                "Lorekeeper: new scroll picture (a rolled parchment with red ends). When it opens, the two rolls start together in the middle and move apart, up and down, while the paper unrolls between them, then the text and buttons fade in. It is part of Smooth Transitions.",
                "Lorekeeper: the camera now moves toward the NPC smoothly when you click them. It zooms in, looks at the NPC and slides to the side, so you and the NPC are on the left of the screen and the scroll is on the right, and it moves back when the talk ends. It uses the game's own interact camera settings and puts every one back. With DynamicCam installed, Lorekeeper leaves the zooming to DynamicCam (two addons zooming at once made the camera jump) and only turns and slides the camera. New option Turn the Camera Toward the NPC (turn it off if another camera addon should control the camera).",
                "Lorekeeper: the scroll is bigger by default (wider, taller and larger text) and the default camera distance is a little closer. Sizes still at the old default are moved to the new default once; sizes you set yourself are not changed.",
                "Lorekeeper: with Hide the Rest of the UI While Talking on, the action bars and other frames came back over the scroll when you moved your character. They are now kept hidden while the scroll is open.",
                "Lorekeeper: new option Hide the Names of Other Players and NPCs. The name tags are hidden while you talk and come back when the scroll closes (also if the game was closed in the middle of a talk, the saved settings are restored on the next talk).",
                "These Lorekeeper additions were built after studying the ideas of another dialogue addon; none of its code is used. They were tested in a simulator only, not yet in the game, so please tell me what does not work.",
                "New command /h3z0ui lkcheck: prints why the Lorekeeper scroll is or is not opening (is it switched on, is another quest addon in the way, did the game's NPC window events arrive, and the last error). Send me its output if the scroll does not open.",
                "True Reticle (type /tr) replaces Action Combat Mode in H3z0 UI. The old Combat Mode page is now the True Reticle page: it shows its status and opens its settings, and Handheld Mode and PC Controller switch it off with a controller and on with mouse and keyboard. Support for the Action Combat Mode addon is removed.",
                "Hover Name: the name no longer jumps around when you click while using True Reticle (or any aim reticle addon). The aiming state has to stay the same for a moment before it counts, the name keeps its place while it settles and appears at the right place at once instead of flashing at its old one, it is not hidden for the short moment the game loses the hovered unit, and while you aim it hangs on the middle of the screen.",
                "Nameplates: some mobs (often ones further away) kept the game's own tiny name instead of the H3z0 nameplate. The game had not given the mob its health yet when the plate appeared, so H3z0 UI skipped it for good. It now tries again a few times for about three seconds. New command /h3z0ui npcheck lists every nameplate on screen and, for each one not drawn by H3z0 UI, the reason.",
                "Nameplates: new option Only Show Nameplates Close to You with a Nameplate Distance slider (10 to 60 yards, 40 by default). Mobs further away than that get no nameplate at all, so you only see the ones in front of you and not the tiny names of mobs far away. Switching the option off puts your own game value back.",
            },
        },
        {
            title = "Forever",
            items = {
                "Lorekeeper: the confirm and cancel hints on the two big buttons now follow your controller. Under Lorekeeper > Button Hints Written For you can pick Automatic, Keyboard and mouse (Space, Esc), Xbox (A, B), PlayStation (Cross, Circle) or Switch (B, A). Automatic shows the Xbox letters when the game controller is on and ConsolePort is not.",
                "Lorekeeper: with an Xbox, PlayStation or Switch controller picked (or found automatically), the two big buttons show round controller button pictures (A and B, Cross and Circle) instead of key letters. The gold coin and the green arrow on rewards are now Lorekeeper's own pictures.",
                "Lorekeeper: when a quest lets you choose a reward, the choice that sells for the most gets a small gold coin on its icon (only when the game knows the sell price of every choice and one is clearly the highest). Gear that is better than what you wear in that slot gets a green arrow, and the tooltip says by how much. Both can be switched off in the Lorekeeper options.",
                "Lorekeeper: new option Smaller Currency Rewards. Currency and money rewards show only the icon and the amount, in a smaller icon.",
                "Lorekeeper: new scroll picture (a rolled parchment with red ends). When it opens, the two rolls start together in the middle and move apart, up and down, while the paper unrolls between them, then the text and buttons fade in. It is part of Smooth Transitions.",
                "Lorekeeper: the camera now moves toward the NPC smoothly when you click them. It zooms in, looks at the NPC and slides to the side, so you and the NPC are on the left of the screen and the scroll is on the right, and it moves back when the talk ends. It uses the game's own interact camera settings and puts every one back. With DynamicCam installed, Lorekeeper leaves the zooming to DynamicCam (two addons zooming at once made the camera jump) and only turns and slides the camera. New option Turn the Camera Toward the NPC (turn it off if another camera addon should control the camera).",
                "Lorekeeper: the scroll is bigger by default (wider, taller and larger text) and the default camera distance is a little closer. Sizes still at the old default are moved to the new default once; sizes you set yourself are not changed.",
                "Lorekeeper: with Hide the Rest of the UI While Talking on, the action bars and other frames came back over the scroll when you moved your character. They are now kept hidden while the scroll is open.",
                "Lorekeeper: new option Hide the Names of Other Players and NPCs. The name tags are hidden while you talk and come back when the scroll closes (also if the game was closed in the middle of a talk, the saved settings are restored on the next talk).",
                "These Lorekeeper additions were built after studying the ideas of another dialogue addon; none of its code is used. They were tested in a simulator only, not yet in the game, so please tell me what does not work.",
                "New command /h3z0ui lkcheck: prints why the Lorekeeper scroll is or is not opening (is it switched on, is another quest addon in the way, did the game's NPC window events arrive, and the last error). Send me its output if the scroll does not open.",
                "True Reticle (type /tr) replaces Action Combat Mode in H3z0 UI. The old Combat Mode page is now the True Reticle page: it shows its status and opens its settings, and Handheld Mode and PC Controller switch it off with a controller and on with mouse and keyboard. Support for the Action Combat Mode addon is removed.",
                "Hover Name: the name no longer jumps around when you click while using True Reticle (or any aim reticle addon). The aiming state has to stay the same for a moment before it counts, the name keeps its place while it settles and appears at the right place at once instead of flashing at its old one, it is not hidden for the short moment the game loses the hovered unit, and while you aim it hangs on the middle of the screen.",
                "Nameplates: some mobs (often ones further away) kept the game's own tiny name instead of the H3z0 nameplate. The game had not given the mob its health yet when the plate appeared, so H3z0 UI skipped it for good. It now tries again a few times for about three seconds. New command /h3z0ui npcheck lists every nameplate on screen and, for each one not drawn by H3z0 UI, the reason.",
                "Nameplates: new option Only Show Nameplates Close to You with a Nameplate Distance slider (10 to 60 yards, 40 by default). Mobs further away than that get no nameplate at all, so you only see the ones in front of you and not the tiny names of mobs far away. Switching the option off puts your own game value back.",
            },
        },
    },
}

-- shown next to the version in the options window
_G.H3z0UI_BuildNumber = ns.WhatsNew.build

-- A section titled "Midnight" is only shown on Midnight, one titled "Forever" only on Forever (and
-- the Classic games); every other section everywhere
function ns.WhatsNewShowSection(sec)
    local title = sec and sec.title
    local legacy = ns.Client and ns.Client.isLegacy
    if title == "Midnight" then return not legacy end
    if title == "Forever" then return legacy and true or false end
    return true
end
_G.H3z0UI_WhatsNewShowSection = ns.WhatsNewShowSection
