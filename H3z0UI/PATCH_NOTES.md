H3z0 UI 0.28.2

Midnight
- Lorekeeper: the confirm and cancel hints on the two big buttons now follow your controller. Under Lorekeeper > Button Hints Written For you can pick Automatic, Keyboard and mouse (Space, Esc), Xbox (A, B), PlayStation (Cross, Circle) or Switch (B, A). Automatic shows the Xbox letters when a game controller is on and ConsolePort is not.
- Lorekeeper: with an Xbox, PlayStation or Switch controller picked (or found automatically), the two big buttons show round controller button pictures (A and B, Cross and Circle) instead of key letters. The gold coin and the green arrow on rewards are now Lorekeeper's own pictures.
- Lorekeeper: when a quest lets you choose a reward, the choice that sells for the most gets a small gold coin on its icon (only when the game knows the sell price of every choice and one is clearly the highest). Gear that is better than what you wear in that slot gets a green arrow, and the tooltip says by how much. Both can be switched off in the Lorekeeper options.
- Lorekeeper: new option Smaller Currency Rewards. Currency and money rewards show only the icon and the amount, in a smaller icon.
- Lorekeeper: new scroll picture (a rolled parchment with red ends). When it opens, the two rolls start together in the middle and move apart, up and down, while the paper unrolls between them, then the text and buttons fade in. It is part of Smooth Transitions.
- Lorekeeper: the camera now moves toward the NPC smoothly when you click them. It zooms in, looks at the NPC and slides to the side, so you and the NPC are on the left of the screen and the scroll is on the right, and it moves back when the talk ends. It uses the game's own interact camera settings and puts every one back. With DynamicCam installed, Lorekeeper leaves the zooming to DynamicCam (two addons zooming at once made the camera jump) and only turns and slides the camera. New option Turn the Camera Toward the NPC (turn it off if another camera addon should control the camera).
- Lorekeeper: the scroll is bigger by default (wider, taller and larger text) and the default camera distance is a little closer. Sizes still at the old default are moved to the new default once; sizes you set yourself are not changed.
- Lorekeeper: with Hide the Rest of the UI While Talking on, the action bars and other frames came back over the scroll when you moved your character. They are now kept hidden while the scroll is open.
- Lorekeeper: new option Hide the Names of Other Players and NPCs. The name tags are hidden while you talk and come back when the scroll closes (also if the game was closed in the middle of a talk, the saved settings are restored on the next talk).
- These Lorekeeper additions were built after studying the ideas of another dialogue addon; none of its code is used. They were tested in a simulator only, not yet in the game, so please tell me what does not work.
- New command /h3z0ui lkcheck: prints why the Lorekeeper scroll is or is not opening (is it switched on, is another quest addon in the way, did the game's NPC window events arrive, and the last error). Send me its output if the scroll does not open.
- True Reticle (type /tr) replaces Action Combat Mode in H3z0 UI. The old Combat Mode page is now the True Reticle page: it shows its status and opens its settings, and Handheld Mode and PC Controller switch it off with a controller and on with mouse and keyboard. Support for the Action Combat Mode addon is removed.
- Hover Name: the name no longer jumps around when you click while using True Reticle (or any aim reticle addon). The aiming state has to stay the same for a moment before it counts, the name keeps its place while it settles and appears at the right place at once instead of flashing at its old one, it is not hidden for the short moment the game loses the hovered unit, and while you aim it hangs on the middle of the screen.
- Nameplates: some mobs (often ones further away) kept the game's own tiny name instead of the H3z0 nameplate. The game had not given the mob its health yet when the plate appeared, so H3z0 UI skipped it for good. It now tries again a few times for about three seconds. New command /h3z0ui npcheck lists every nameplate on screen and, for each one not drawn by H3z0 UI, the reason.
- Nameplates: new option Only Show Nameplates Close to You with a Nameplate Distance slider (10 to 60 yards, 40 by default). Mobs further away than that get no nameplate at all, so you only see the ones in front of you and not the tiny names of mobs far away. Switching the option off puts your own game value back.

Forever
- Lorekeeper: the confirm and cancel hints on the two big buttons now follow your controller. Under Lorekeeper > Button Hints Written For you can pick Automatic, Keyboard and mouse (Space, Esc), Xbox (A, B), PlayStation (Cross, Circle) or Switch (B, A). Automatic shows the Xbox letters when the game controller is on and ConsolePort is not.
- Lorekeeper: with an Xbox, PlayStation or Switch controller picked (or found automatically), the two big buttons show round controller button pictures (A and B, Cross and Circle) instead of key letters. The gold coin and the green arrow on rewards are now Lorekeeper's own pictures.
- Lorekeeper: when a quest lets you choose a reward, the choice that sells for the most gets a small gold coin on its icon (only when the game knows the sell price of every choice and one is clearly the highest). Gear that is better than what you wear in that slot gets a green arrow, and the tooltip says by how much. Both can be switched off in the Lorekeeper options.
- Lorekeeper: new option Smaller Currency Rewards. Currency and money rewards show only the icon and the amount, in a smaller icon.
- Lorekeeper: new scroll picture (a rolled parchment with red ends). When it opens, the two rolls start together in the middle and move apart, up and down, while the paper unrolls between them, then the text and buttons fade in. It is part of Smooth Transitions.
- Lorekeeper: the camera now moves toward the NPC smoothly when you click them. It zooms in, looks at the NPC and slides to the side, so you and the NPC are on the left of the screen and the scroll is on the right, and it moves back when the talk ends. It uses the game's own interact camera settings and puts every one back. With DynamicCam installed, Lorekeeper leaves the zooming to DynamicCam (two addons zooming at once made the camera jump) and only turns and slides the camera. New option Turn the Camera Toward the NPC (turn it off if another camera addon should control the camera).
- Lorekeeper: the scroll is bigger by default (wider, taller and larger text) and the default camera distance is a little closer. Sizes still at the old default are moved to the new default once; sizes you set yourself are not changed.
- Lorekeeper: with Hide the Rest of the UI While Talking on, the action bars and other frames came back over the scroll when you moved your character. They are now kept hidden while the scroll is open.
- Lorekeeper: new option Hide the Names of Other Players and NPCs. The name tags are hidden while you talk and come back when the scroll closes (also if the game was closed in the middle of a talk, the saved settings are restored on the next talk).
- These Lorekeeper additions were built after studying the ideas of another dialogue addon; none of its code is used. They were tested in a simulator only, not yet in the game, so please tell me what does not work.
- New command /h3z0ui lkcheck: prints why the Lorekeeper scroll is or is not opening (is it switched on, is another quest addon in the way, did the game's NPC window events arrive, and the last error). Send me its output if the scroll does not open.
- True Reticle (type /tr) replaces Action Combat Mode in H3z0 UI. The old Combat Mode page is now the True Reticle page: it shows its status and opens its settings, and Handheld Mode and PC Controller switch it off with a controller and on with mouse and keyboard. Support for the Action Combat Mode addon is removed.
- Hover Name: the name no longer jumps around when you click while using True Reticle (or any aim reticle addon). The aiming state has to stay the same for a moment before it counts, the name keeps its place while it settles and appears at the right place at once instead of flashing at its old one, it is not hidden for the short moment the game loses the hovered unit, and while you aim it hangs on the middle of the screen.
- Nameplates: some mobs (often ones further away) kept the game's own tiny name instead of the H3z0 nameplate. The game had not given the mob its health yet when the plate appeared, so H3z0 UI skipped it for good. It now tries again a few times for about three seconds. New command /h3z0ui npcheck lists every nameplate on screen and, for each one not drawn by H3z0 UI, the reason.
- Nameplates: new option Only Show Nameplates Close to You with a Nameplate Distance slider (10 to 60 yards, 40 by default). Mobs further away than that get no nameplate at all, so you only see the ones in front of you and not the tiny names of mobs far away. Switching the option off puts your own game value back.

H3z0 UI 0.28.1

Midnight
- Interrupt Tracker: in the group list, a member whose interrupt is on cooldown now shows a grey spell icon with a red X over it (a ready interrupt shows the normal icon), and the seconds left are shown in red.
- Cooldown Manager custom trackers: changing spec or talents in combat (or anything that rebuilt the custom tracker bars) raised an ADDON_ACTION_BLOCKED error about Frame:Hide(). The bars are now rebuilt when combat ends instead.
- Setup wizard: choosing Use the H3z0 UI Edit Mode layout now also puts every H3z0 UI frame (player, target, party, raid, bars, trackers, minimap, text panels ...) in its place from the H3z0 UI default setup, whatever else was chosen in the wizard, so the layout always looks the same afterwards. A pasted profile and the Handheld layout keep their own positions. Skipping the wizard on a first install does the same.
- Settings: choosing a setting in the H3z0 UI menu froze the game for a moment, most on Forever where every skin is on. Each click refreshed every skin in one go. Requests that come close together now become one, and the skins are refreshed a few at a time over several frames, so there is no freeze.
- Reticle (the circle around the cursor) is now off by default.
- Action bars now show empty slots by default, also on Forever (before, Forever hid them). On Forever the setting is set back to showing them once for every profile (the earlier automatic change also hid them in new profiles); Hide Empty Slots in Action Bars still turns it on.
- Lorekeeper: when a quest lets you choose a reward, the reward you picked now has a bright frame, a stronger fill and a check mark, and the rewards you can still choose have a faint frame, so it is clear which one will be taken.
- Profiles: a profile string exported on Midnight can now be imported on Forever and the other way round (it was refused as being from a different client). Settings that only exist on one of the two are simply ignored on the other. Classic Era and TBC still only take their own profiles.
- Bottom bar (micro menu): a panel you cannot use right now (locked by level, the store closed, or switched off by the game on Forever) stays on the bar greyed out and does nothing when clicked, and becomes normal and clickable again as soon as you can use it. They were left off the bar before. The bar checks once a second, and not during combat.
- Options: the version in the bottom corner of the options window now also shows the build number (for example v0.28.1 build 1), so you can see that the newest build is installed. The version at the top stays short.
- Options: new Reset Layout button in Quick Actions on the Home page. It asks first, then puts every H3z0 UI frame back in its H3z0 UI place and reloads (the same as /h3z0ui layoutreset; on Forever the Forever layout).
- /h3z0ui layoutreset and the Reset Layout button: the layout was reset but the reload did not happen (the game ignores a reload that does not come straight from a key press or click). The reload now happens right away.
- Cast bars: when you are hit while casting, the cast bar now moves back with the cast (pushback), and a channel that gets shorter is shown shorter. The bars did not listen to the game's delay message, so they kept running to the old end. This is for the Player, Target, Focus and Boss cast bars.
- Blizzard Frame Mover is now off by default: new profiles, Reset Profile and the setup wizard's fresh start (from the H3z0 UI default profile on Midnight and on Forever) no longer let you drag Blizzard's windows until you turn it on. Profiles that already have it on keep it.
- Lorekeeper: controller support through ConsolePort. When ConsolePort is installed, the Lorekeeper scroll is added to its interface cursor, so the cursor moves over the choices, the rewards and the buttons and A clicks them like in any other window. The cursor is put on the next thing to do each time the text changes. Midnight uses ConsolePort only (no separate gamepad handling of its own).
- Unit frames: the Player and Target frames now show the unit's level as a number hanging under the portrait (at the left end of the frame when there is no portrait), coloured by how hard the unit is for you, with red ?? for boss and skull levels. It can be turned on for any unit frame with Show Level in its options, and off for the Player or Target.
- Unit frames: the resource number (mana, energy, rage ...) in the power colour was hard to read on bright ground, mostly the dark mana blue. The colour is now lifted towards white.
- Nameplates: units you need for a quest get a gold ! above their name. It follows your quest log (it appears when you pick up the quest and goes when the quest no longer needs the unit) and can be turned off with Show Quest Marker in the nameplate options. It only shows when the game tells the addon that the unit is part of a quest.
- Nameplates: the quest marker turns into a green tick when the objective it stands for is full (for example 6/6). The tick shows only while the game still lists that objective on the unit.

Forever
- Settings: choosing a setting in the H3z0 UI menu froze the game for a moment, most on Forever where every skin is on. Each click refreshed every skin in one go. Requests that come close together now become one, and the skins are refreshed a few at a time over several frames, so there is no freeze.
- Reticle (the circle around the cursor) is now off by default.
- Action bars now show empty slots by default, also on Forever (before, Forever hid them). On Forever the setting is set back to showing them once for every profile (the earlier automatic change also hid them in new profiles); Hide Empty Slots in Action Bars still turns it on.
- Lorekeeper: when a quest lets you choose a reward, the reward you picked now has a bright frame, a stronger fill and a check mark, and the rewards you can still choose have a faint frame, so it is clear which one will be taken.
- Profiles: a profile string exported on Midnight can now be imported on Forever and the other way round (it was refused as being from a different client). Settings that only exist on one of the two are simply ignored on the other. Classic Era and TBC still only take their own profiles.
- Bottom bar (micro menu): a panel you cannot use right now (locked by level, the store closed, or switched off by the game on Forever) stays on the bar greyed out and does nothing when clicked, and becomes normal and clickable again as soon as you can use it. They were left off the bar before. The bar checks once a second, and not during combat.
- Options: the version in the bottom corner of the options window now also shows the build number (for example v0.28.1 build 1), so you can see that the newest build is installed. The version at the top stays short.
- Options: new Reset Layout button in Quick Actions on the Home page. It asks first, then puts every H3z0 UI frame back in its H3z0 UI place and reloads (the same as /h3z0ui layoutreset; on Forever the Forever layout).
- /h3z0ui layoutreset and the Reset Layout button: the layout was reset but the reload did not happen (the game ignores a reload that does not come straight from a key press or click). The reload now happens right away.
- Cast bars: when you are hit while casting, the cast bar now moves back with the cast (pushback), and a channel that gets shorter is shown shorter. The bars did not listen to the game's delay message, so they kept running to the old end. This is for the Player, Target, Focus and Boss cast bars.
- Blizzard Frame Mover is now off by default: new profiles, Reset Profile and the setup wizard's fresh start (from the H3z0 UI default profile on Midnight and on Forever) no longer let you drag Blizzard's windows until you turn it on. Profiles that already have it on keep it.
- Forever: clicking the Adventure Guide button of the game's micro menu could raise a Lua error because a function it calls was missing on that client. A safe stand-in is now provided when it is missing, a click on the button that still fails is caught and opens the Adventure Guide window directly, and /h3z0ui ejcheck prints which parts of the Adventure Guide are present.
- Forever: the resize handle in the bottom right corner of the damage meter showed as a red question mark because the Forever client does not have the image the game uses for it. It now uses the game's own chat window grabber there.
- Forever and Classic: you now choose where the Player resource bar lives. Resource Bar in the Player frame options switches between On the frame, with health (under the health bar, inside the same frame, with its number) and Separate bars (the floating resource bars). Only one is on at a time: choosing one switches the other off. The frame bar has its own Power Bar Height, new Power Bar Width (percent of the frame), Power Bar Border, colour and number (Show Power Text with Percent, Current or Both). New profiles start with the bar on the frame; the Target frame keeps its resource bar under the health bar.
- Forever and Classic: the resource bar number of the Player frame (mana, rage ...) now sits right under the frame, below the health number, outside the bar so it is easy to read. It is placed once for existing profiles; the text position stays adjustable in the Player frame options.
- Forever and Classic: the Target frame now shows its resource number (mana, rage, energy ...) under the frame on the left side, the same way the Player frame shows yours. It is turned on once for existing profiles; Show Power Text in the Target frame options turns it off.
- Forever: the black box behind the model in the character window is gone. The game lays a dark cover over the model area there but hides the picture it is meant to cover; only that cover is made invisible. Nothing else in the window changes.
- Setup wizard (Forever): finishing the wizard scattered the frames all over the screen on Forever (action bars, objectives, minimap and unit frames in the middle). Forever did not have the H3z0 UI setup the wizard takes the places from, so it used an old starter set with other places. Forever now has it, the wizard only moves frames the H3z0 UI setup has a place for (all others keep theirs), and nothing is moved at all when that setup cannot be read. New command /h3z0ui layoutreset puts every frame back in the H3z0 UI places and reloads, to repair a layout the wizard scattered.
- Setup wizard and /h3z0ui layoutreset (Forever): the frames are put exactly where H3z0's own Forever profile has them (every frame placed with Layout Mode, the unit frames and their cast bars, minimap, power bars, timers, text panels and the rest). The Midnight places are made for another screen size and are no longer used on Forever. Frames that profile has no place for keep their own. On Forever this happens whatever you choose in the wizard (only a pasted profile and the Handheld layout keep their own places).
- /h3z0ui layoutreset, Reset Layout and the setup wizard (Forever): the chat window and the damage meter are put back too (they are Blizzard windows and were not part of the reset), at their places and sizes from H3z0's Forever layout, and other Blizzard windows H3z0 UI had placed go back to the Edit Mode layout.
- Forever: H3z0's own Forever setup is now the Forever default profile. A new profile on Forever, Reset Profile and the setup wizard's Fresh H3z0 UI defaults start from exactly that setup (every setting and every position), like the H3z0 UI default profile on Midnight. Existing profiles are not changed.
- Forever and Classic: friendly nameplates are shown again. Those games have an extra switch in front of the friendly nameplates (show friendly nameplates, Shift+V) that is off by default, so no friendly plate appeared at all; H3z0 UI now turns it on, unless friendly players are hidden and friendly NPC nameplates are off. Friendly players get the same H3z0 look as on Midnight.
- Forever and Classic: the Target frame no longer shows a 0 under the frame for a target that has no resource (most beasts).
- Forever and Classic: friendly players and NPCs now get the H3z0 name tag (the name only, players in their class colour, NPCs in green, in the H3z0 nameplate font) instead of the game's own friendly nameplate with its bar. Those games have no names-only plate of their own, so the game's plate showed. Turn off Friendly Nameplates: Text Only to give them full H3z0 nameplates with a health bar.
- Forever and Classic: the friendly name tags no longer flicker when you target someone or move the mouse over them; they keep full strength while the game fades its plates in and out.
- Lorekeeper: game controller support. Without ConsolePort, the D-pad (or the shoulder buttons) moves a highlight over the choices, rewards and buttons, A / Cross picks the highlighted one or continues the text, and B / Circle says goodbye or declines the quest. Other buttons (triggers, sticks) are left to the game. In combat the buttons are off like the keys. It can be turned off with Game Controller Support on the Lorekeeper page.
- Lorekeeper: with ConsolePort installed on Forever, the scroll is added to ConsolePort's interface cursor and ConsolePort does the moving and clicking (the built-in controller handling steps aside so the two do not both react). On a Steam Deck use a gamepad layout in Steam Input, or the trackpad, to click.
- Forever and Classic: hovering or targeting a unit could raise an error (comparing a secret power value) in the Target frame resource text. The check that hides a 0 for units without a resource now skips values the game keeps secret.
- Unit frames: the Player and Target frames now show the unit's level as a number hanging under the portrait (at the left end of the frame when there is no portrait), coloured by how hard the unit is for you, with red ?? for boss and skull levels. It can be turned on for any unit frame with Show Level in its options, and off for the Player or Target.
- Unit frames: the resource number (mana, energy, rage ...) in the power colour was hard to read on bright ground, mostly the dark mana blue. The colour is now lifted towards white.
- Action bars: slots that kept an old spell rank (for example Maul rank 1 on the bear page after learning rank 2) gave the error Old spell rank when pressed. After you change form, log in or learn a spell, and out of combat, every slot is now checked and set to the highest rank you know. The command /h3z0ui fixranks does it right away and lists what it changed.
- Action bars: after changing form the number keys could stop working while clicking with the mouse still worked. The key bindings of the main bar are now set again a moment after the form change, once the game has finished it. /h3z0ui bardump also shows which key is bound to button 1 and what it does.
- Micro menu: the Legacy button is left out of the bottom bar while it is locked (before level 25) and appears on its own when it becomes available. The other buttons close up the gap.
- Fixes: the Reload Now button in our own popups no longer calls the protected UIReload on Forever (it was reported as a blocked action); the character stats panel skips a stat the game keeps secret (movement speed) instead of raising an error; the target-of-target and other unit frames no longer error when the game returns a secret class for a player.
- Nameplates: units you need for a quest get a gold ! above their name. It follows your quest log (it appears when you pick up the quest and goes when the quest no longer needs the unit) and can be turned off with Show Quest Marker in the nameplate options. It only shows when the game tells the addon that the unit is part of a quest.
- Nameplates: the quest marker turns into a green tick when the objective it stands for is full (for example 6/6). The tick shows only while the game still lists that objective on the unit.

H3z0 UI 0.27.9

New
- Interrupt Tracker: the tracker now reacts the moment the game says its interrupt list changed, and reads who kicked from the shape of that list, which the game does not hide in combat: a member who gets a new row there kicked for the first time, a row that moves up past another one kicked again, and a member whose spell list grows kicked a new spell. A member is only named when the row can belong to one group member; two members of the same class and spec are never guessed. This works in combat, keystones and delves where the cast and the interrupter are hidden.
- Interrupt Tracker: the number of interrupts in a row is also shown while the game hides it from addons (it is handed to the screen as it is, without reading it), as long as the count for this run started from zero in the game's meter.
- Interrupt Tracker: the self test (/h3z0ui inttest) also checks the new meter-list detection: a new row, a row that moves up, and two members of one class that must not be guessed.
- Lorekeeper: the quest icons of an NPC that offers quests without the gossip list (the older greeting window) now read the quest type correctly; the values were read in the wrong order, so a repeatable quest there could still show the yellow icon.
- Bank: middle click no longer pins items while the bank shows its plain grid (pins are only used in the Inventory layout).
- Bank: in the Inventory layout, identical items that share one button now show their total count, and the Free Slots button shows how many slots are free (it showed the count of one stack and no number).
- Bags: in the Categories and Inventory layouts, a lock or cooldown change (every item you pick up, move or use) no longer rebuilds and re-sorts the whole window; only the buttons are redrawn. The layout is still rebuilt when items arrive, leave, change place or change count.
- Tooltips: while you hover a unit the game refreshes its tooltip several times a second, and the coloured border was rebuilt twice for every refresh. It is now drawn only when the colour changes.
- Interrupt Tracker: the interrupt counts are read from the damage meter every 2 seconds instead of every half second.
- Bags and Bank: the fps drop while moving items between the bank and your bags, selling or sorting is fixed. The windows no longer rebuild their whole layout for every single item that moves: the bank window keeps its layout while the same items stay in the same slots and only redraws the buttons, and while a transfer, a sort or selling is running a window refreshes at most every 0.4 seconds. A window that is slow to rebuild now waits longer between refreshes by itself.
- Bank: the bank window can now use the same layout as the Inventory bags: a list of categories on the left (All Items, Whole Bank, Pinned Items, Recent Items, Weapon, Armor, Potion, Food and so on with the number of items), and the items in sections under their category title with a + slot to add an item by hand. The tabs of the bank (and the Warband bank) stay on top; All shows every tab, one tab shows only that tab's categories. Middle click pins an item, right click on a category moves, hides or renames it, and the Add Category button makes your own. It uses the category settings of the Inventory bags and keeps its own choice of category and pinned items. It is on when the bag Layout is Inventory; turn it off with Bank: Inventory Layout in the Bags options to get the plain grid back.


H3z0 UI 0.27.8

New
- Interrupt Tracker: new command /h3z0ui inttest checks the tracker without a dungeon or Mythic. It adds four made-up group members to the list for about 15 seconds, feeds them made-up events (a hidden cast with an interrupt, two members casting at once, a healer, a message from another H3z0 UI user, a readable cast, a cast that just stopped) and prints PASS or FAIL for each one in chat. It shows whether the tracker's own logic works; whether the game hands over the information in a real dungeon is still seen with /h3z0ui intdebug.
- Interrupt Tracker: each member's row now shows how many interrupts they have done, next to the cooldown. The numbers come from the game's own damage meter (the whole run), and the tracker adds the interrupts it saw itself when the game hides the meter numbers. It can be turned off with Show How Many Interrupts Everyone Did.
- Interrupt Tracker: the interrupt counts now start from zero on every Mythic+ start, and every run is saved in a history with the interrupts of every member, by dungeon and key level (the last 30 runs, a run you leave early is saved too). Open it with the small Log button above the interrupt list, the Open History button in the Interrupt Tracker options or /h3z0ui intlog. The window also has Reset Counts and Clear History buttons.
- Lorekeeper: quest icons in the scroll now follow the kind of quest like the game's own list. A repeatable, daily or weekly quest shows its blue icon, legendary, important and campaign style quests show theirs, and a quest ready to hand in shows the matching turn-in icon, instead of every quest showing the same yellow exclamation mark.


H3z0 UI 0.27.7

New
- Interrupt Tracker: cooldowns are now kept per group slot (player, party1 to party4) instead of by GUID. The game can hide a member's GUID, and a hidden value cannot be stored, which could stop other members' interrupts from showing at all.
- Interrupt Tracker: group members who also run H3z0 UI now tell each other when they interrupt, so the cooldown shows even when the game hides the cast. The game blocks addon messages during a keystone run, a boss fight and PvP; the other ways of seeing an interrupt still work there.
- Interrupt Tracker: the game hides who interrupted and with which spell, so the tracker now also works it out from timing. When an enemy cast is interrupted and exactly one group member whose interrupt is ready cast something at that moment, that member's cooldown starts. It is a good guess, not a certainty, and it is skipped when two members could have done it.


H3z0 UI 0.27.6

New
- Interrupt Tracker: other group members now show their interrupt cooldown too. The game hides what spell other players cast in combat, so the tracker also listens for the moment an interrupt lands (the game says who did it) and starts that member's cooldown with the usual interrupt of their class. An interrupt that does not land on a cast is not seen.
- Interrupt Tracker: a caster that uses another spell number for the same interrupt (a Delve companion, for example) is now recognised by the spell name. New command /h3z0ui intdebug prints what the game tells the tracker about casts and interrupts of your group, so a case that still does not work can be looked at.
- Interrupt Tracker: it now also reads the game's own damage meter, which counts interrupts per player. When a group member's interrupt count goes up, their cooldown starts. This works when the game lets addons read those numbers in combat; /h3z0ui intdebug shows what it says.

H3z0 UI 0.27.5

New
- Event bar on the world map: a strip of tiles right under the map window, so it does not cover the map. Weekly Quest shows how many of the season's weekly storylines are done; hover it to see every storyline with its zone, quest and state (Completed, In Progress, Not Accepted). Professions Weekly does the same for your two professions. Stormarion Assault shows a countdown with a bar, green and In Progress while it runs, and when the next one starts. Cursed Surges shows the zone and the countdown from the game's event schedule; click it to put a pin on the map. A Great Vault tile shows the unlocked slots of Raid, Mythic+ and World. Click a tile to open the map at its zone. Switches: Lorekeeper settings > Event Bar on the World Map (on / off, Great Vault tile).
- Interrupt Tracker (new, off by default): a list of your group members in the colour of their class, full and bright when their interrupt is ready and shrinking with the seconds left while it is on cooldown, plus a big icon with the cooldown of your own interrupt (green border ready, red border on cooldown). It sees the cast of an interrupt and counts the base cooldown of that spell, so a talent that shortens a cooldown is not known, and a cast the game hides in combat cannot be seen. Settings: Interrupts tile (on / off, list, icon, only in dungeons and raids, size). The test button shows four example members and lets you drag the list and the icon where you want them.
- Home page: the options window now opens on a new Home page. It shows your character, specialization, item level, active profile, layout and how many modules are on, with quick buttons for Unlock Mode, Profiles, Modules, Patch Notes and Reload UI, and lists of your recent pages and favorites.
- New look for the options window: a thin accent line on top, the sidebar and the pages sit on their own rounded panels, and a Profile chip in the header shows the active profile and opens Profiles when clicked. Prefer the old look? Type /h3z0ui menu classic and /reload (/h3z0ui menu new to come back).
- /h3z0 now works like /h3z0ui, so /h3z0 unlock opens Layout Mode.
- Layout Mode (unlock) has Undo and Redo: Ctrl+Z, Ctrl+Y (or Ctrl+Shift+Z) and two buttons in the side panel. They cover moves by dragging, arrow keys and Reset to Center; up to 100 steps, cleared when you close Layout Mode. Moves that change an anchor are not recorded.
- Layout Mode: Lock Selected keeps the chosen element from being dragged, nudged or reset until you unlock it (for this Layout Mode session). Copy Position and Paste Position put one element exactly where another one is, and Undo takes it back.
- Layout Mode: Match Width and Match Height give a chat window the width or height of the element you copied with Copy Position. This works for the chat windows only, the elements whose size Layout Mode can set.
- Modules page (General > Modules) is now a small manager: a search box and All / On / Off buttons dim the modules that do not match, and every group has All on and All off buttons (All off asks you to press twice). Modules locked in combat are skipped.
- Overrides (General > Overrides): rules that turn chosen modules on or off by role (Tank, Healer, Damage) and by place (open world, dungeon, raid, PvP, scenario), then put them back when the rule stops matching. Pick the modules for each rule from a list. Nothing changes in combat, and the original state is saved so it also comes back after a /reload.
- Profile Tools (General > Profile Tools): rename a profile, duplicate it, keep up to 8 full backups of the current profile and restore one (asks twice), and choose which profile each of your characters uses.
- Looks (General > Looks): six ready-made looks (Clean Dark, Soft Rose, Bold Amber, Midnight Glass, Mint Classic, Class Colours). One click sets the accent colour, font, outline and bar texture and applies them to every module, like Sync Fonts does. Each card previews the font and bar texture. Your profile is backed up first and Undo Last Look brings it back. Positions, sizes and module switches are not changed.
- Nameplates Quick Setup (Nameplates page > Quick Setup, or /h3z0ui npsetup): five short steps with a live preview. Pick a style (Mythic+ Tank, Mythic+ Damage, Mythic+ Healer, Raid Leader, PvP, Minimalist, or Automatic from your spec), a size, threat and priority options and auras. Your profile is backed up first, and Cancel puts everything back.
- Nameplate auras: your own debuffs (and, if you want, dispellable enemy buffs) as icons above the plate with the time left. The icon border turns gold in the last 30% of the time (pandemic) when the game shows addons the times. Off by default.
- Nameplate focus and scaling: a bigger plate for your focus, a bigger plate while a unit casts, other plates fade when you have a target, and bigger plates for bosses and rares. Neutral by default.
- Nameplate Highlight Rules: add a unit by exact name or NPC number and it gets a gold bar and a bigger plate.
- Nameplate auras update through one shared queue with a time budget, and slow down to 5 times a second when more than 25 plates are shown. /h3z0ui npperf prints what the nameplate extras cost.
- Nameplates: much bigger ranges. Health bar width up to 500 and height up to 80, cast bar height up to 48, cast bar width up to 600.
- Nameplates: new cast bar settings - sideways offset, gap under the health bar, icon side (left, right, hidden), icon size, text size, show or hide the spell name and the cast time - and a name gap above the health bar.
- Friendly nameplates are now text only (name in class colour) in towns, the open world, dungeons and Mythic+ by default. Turn it off with the Friendly Nameplates: Text Only and Friendly Players as Names Only options on the Nameplates page.
- The Bottom Bar is now called Dock Bar. Searching for bottom bar or info bar still finds it.
- Edit Mode: every element now has an Options button in the top bar of its settings panel that opens that element's page in the H3z0 UI menu (Unit Frames, Party and Raid Frames, Herald, Lorekeeper, Arcanum, Chat and Damage Meter windows, Minimap, alerts, toasts, loot, widgets and more). Before, about half of them had no link.
- Lorekeeper is no longer an Edit Mode element. Its position is set only in the H3z0 UI menu (Lorekeeper page: Distance From the Right Edge and Vertical Position).
- Lorekeeper: a new Move by Dragging button on its page. It shows a blue handle over the scroll; drag it anywhere, nudge with the arrow keys (Shift for bigger steps), right-click or Esc to finish. It changes the same two values as the sliders, so both always agree.
- Bags: opening the bags in combat no longer spreads the whole inventory over the screen when you scroll. The bag window is now prepared before combat, and if it could not be, it waits and fills in when combat ends.
- Tooltip: new options on the Tooltip page. Colours by Type (border by class or reaction colour for units and by quality for items, optional background tint). Health Bar (height, class or reaction colour, health and percent text on the bar - turn Hide Health Bar off to see it). Fonts per Line (separate sizes for the name, guild and other lines, optional outline). Anchors per kind (units in the world and frames can follow the cursor or sit at the fixed spot separately). Icons On the Name Line (raid marker and group role). All off by default.


H3z0 UI 0.27.4

New
- Oracle raid boss lines: all 8 bosses of the new raid, The Venomous Abyss (Nek'zali the Soulcoiler, Entombed Sentinels, The Lost Explorers, Vashnik the Malignant, Sszorak, The Twin Fangs, The Coiled Altar, Ula'tek), now say what exactly to do, with the same text on screen: Tank swap, Share the damage, Raid cooldown, Feed the fish, Keep them apart, Break the shield, Damage window and more. About 67 boss abilities. Tank and healer lines only for your role. Switch: Oracle > Boss-Specific Lines.
- Oracle test for every boss: Test Every Boss Line plays all lines of a chosen dungeon or raid one after the other, boss by boss, with the warning on screen. The chat says which abilities the game does not have and ends with PASS or FAIL. Test a Boss Line and Check the Boss Lines now include the raid.
- Oracle raid boss lines for the earlier raids too: The Voidspire (Imperator Averzian, Vorasius, Fallen-King Salhadaar, Vaelgor and Ezzorak, Lightblinded Vanguard, Crown of the Cosmos), The Dreamrift (Chimaerus) and March on Quel'Danas (Belo'ren, Midnight Falls). The test buttons list them as well.


H3z0 UI 0.27.3

New
- Game Menu: more around the menu when you press Esc. Top left: a random World of Warcraft fact (a new one every time you open it). Bottom left: the patch notes of your version, with the main points of New, Fixed and Changed. Bottom right: your last Mythic+ keys, its title (yellow like the others) on the same line as the Patch Notes title. Switch: Appearance > Skinning > Game Menu > Character & Pet Scene.
- Oracle: on-screen warning. At the same moment the voice speaks, a big word (SOAK, SPREAD, BIG HIT and so on) with the ability icon and name shows on screen, in the colour of the callout. Abilities Oracle cannot name show INCOMING (can be switched off). Settings: Gameplay & Utilities > Oracle > On-Screen Warning: on/off, seconds shown, size. It fades in and out softly instead of popping. Drag it where you want it with the test button.
- Oracle boss lines: the bosses of this season's Mythic+ dungeons (Altar of Fangs, Murder Row, Den of Nalorakk, The Blinding Vale, Voidscar Arena, Kings' Rest, Temple of Sethraliss, Ruby Life Pools) now say what exactly to do: Soak the beams, Tank defensive, Take the gateway, Break the tethers, Hide behind a barrel and more, with the same text on screen. About 120 boss abilities. Tank and healer lines only for your role. Abilities without a line keep the general callout. Switch: Oracle > Boss-Specific Lines.
- Oracle boss line tests: Test a Boss Line (voice and warning of a random line of a dungeon), Check the Boss Lines (tells per dungeon how many lines found their ability in the game and names the ones that did not) and Play All Boss Voices.
- Oracle tests: Show the Warning (8 seconds, drag it) and Test the Timeline, which puts a real test event on the game's boss timeline and tells you in chat with PASS or FAIL if Oracle reacted. Check Setup now also reports how many boss highlights Oracle has seen.


Fixed
- Game Menu: parts of the minimap (its small icons) stayed visible on the screen while the Esc menu was open. The minimap is now hidden while the menu is open and comes back when you close it (not in combat, where the game does not allow it, so no error appears).

H3z0 UI 0.27.2

New
- Mythic+: when you put your key in the keystone window, two round buttons sit at the top of it. The left one starts a ready check, the right one starts a pull timer (10 seconds, change it in the settings). Group leader or assistant only. Switch: H3z0 Features > Extras > Mythic+ Groups.
- Premade Groups: the people applying to your group are sorted by Mythic+ rating, highest first. Each name gets a small flag for the language of the player's realm (German, French, Spanish, Russian, Italian, Portuguese, English; in the Americas: US, Brazil, Latin America, Oceania). Hover a flag to see what it is. Switches: H3z0 Features > Extras > Mythic+ Groups.
- Waygate: a new tab on the world map, under the quest log tabs, with every teleport in one place: Favorites, Home (hearthstones and hearthstone toys), Class teleports and the dungeon teleports of every expansion, newest first. Left-click teleports, right-click stars a teleport so it shows under Favorites. Dungeon teleports you haven't earned yet show greyed out (you can hide them). On by default; switch: Lorekeeper settings > Waygate.
- Oracle: spoken boss warnings. Before a boss ability lands you hear what to do: Soak, Spread, Stack up, Fixate, Interrupt, Knockback, Line of sight, Move, Adds, Raid damage, Dispel, Tank buster (tanks), Heal up (healers), Big hit and Enrage. The game plays the voice about 5 seconds before the ability. Oracle goes through every boss ability the game knows, so all raid bosses and all Mythic+ dungeon bosses of the season are covered, and it needs no boss mod. Each callout can be switched off. Menu: Gameplay & Utilities > Oracle.
- Oracle tests: Check Setup, Play All Voices, Test This Callout and Test With a Real Boss Ability (the game plays its own stored sound for a real ability and the chat names it). Every test prints PASS or FAIL in the chat. Chat: /h3z0ui oracle and /h3z0ui oracletest. The voice files are new, so close the game completely and start it again once after updating (a /reload is not enough).

Fixed
- Info bar: the Mythic+ Key text now updates when your key changes level, for example when you lower it at the keystone vendor. Before, it kept showing the old level until a reload.
- Cast bars: a long spell name no longer runs over the timer. The name now stops where the timer starts and is shortened with ... when it does not fit, with any font.
- Group Finder: the Party Keys panel under the window no longer covers the tabs (Dungeons & Raids, Player vs. Player, Mythic+ Dungeons). It now sits below them.
- Premade Groups: a long applicant name no longer runs into the flag and the role icons. The name is shortened with ... so the name and flag always fit before the roles.
- Group Finder: the Browse Groups button (under your listing) has the same look as the Delist and Edit buttons now, instead of the game's red button.

Changed
- What's New window: new look with a list of every version on the left (click one to read it) and the notes of that version on the right. All the earlier updates stay in the list, so you can read back what changed in any version. Open it from the settings window (Patch Notes) or with /h3z0ui whatsnew.

Removed
- Minimap coordinates: the small X, Y numbers above the info bar (they came from the game itself, not from H3z0 UI) are switched off and hidden. The game setting Show Minimap Coordinates stays off.


H3z0 UI 0.27.1

New
- Map: /way puts map pins from chat: /way 45.2 62.1 Mailbox, /way Elwynn Forest 42 65 Inn or /way #1453 60 70 (several with ; between them). It prints a link; click it to set the game's map pin, and you get a message when you arrive. /way clear forgets them. If another addon already uses /way, it is /h3way. Switch: H3z0 Features > Extras > Map.
- WoW: Forever: the world map shows the areas you have not explored yet (tinted, colour of your choice), and hovering a zone on a continent map shows its level range and the fishing skill it needs. Switches: H3z0 Features > Extras > Map.

Fixed
- Font (used everywhere) in H3z0 Features > UI Look now really changes the font everywhere: unit frames, party and raid frames, nameplates, minimap, datatexts, timers and every other font setting take the font you pick (before, only the general font changed). Some parts finish after a /reload, the window offers it.
- Settings window: windows opened from it (Patch Notes, the copy-link box, confirmations, the import box and the colour picker) now open on top of the settings window instead of behind it.
- Objective tracker: no more error 'GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by H3z0UI'. After restyling the tracker fonts, H3z0 UI asked the tracker to lay itself out again, which made the tracker's update run as H3z0 UI. It no longer does that; the fonts apply at the tracker's next own update. Lorekeeper also no longer adds or removes the quest popups through the tracker itself (the same problem).
- Damage Meter: no more error 'attempt to compare local durationSeconds (a secret number value, while execution tainted by H3z0UI)'. Opening and closing H3z0 UI Layout Mode showed the meter window and asked it to update from H3z0 UI's own code, which left the meter in a broken state until the next reload. Layout Mode now only shows the meter's box, it no longer opens the meter window itself.

Removed
- Minimap: the map coordinates are removed (the X,Y numbers on the minimap, the XY button, their settings page and their Layout Mode handle).


H3z0 UI 0.27.0

New
- Cooldown Manager: the proc glow on the icons is the same glow as on your action bars (same style and colour, following your theme colour). Switch it off with Same Glow as the Action Bars in the Cooldown Manager glow settings to use the separate glow type and colour again.
- Cooldown Manager: the ability the game suggests pressing next gets a green border on its Cooldown Manager icon. It uses the game's own rotation suggestion (Assisted Combat). On by default; switch it off with Green Border on the Ability to Press Next on the Essential and Utility pages of the Cooldown Manager settings.
- Language: Bulgarian (Български) can now be chosen in the Language list at the top of the settings window. The menu names, page titles, buttons and help texts are translated first; the rest of the settings stay in English for now and get translated in the next updates.
- Font: the H3z0UI font is the default font now (it also has the Cyrillic letters Bulgarian needs). Every font setting that was still on the old default (Poppins) moves to H3z0UI once; fonts you picked yourself stay.
- Lorekeeper: the Space button (Continue, Accept, Complete Quest, Next) always has the muted red colour now, not only Accept, so the main button is easy to see. Goodbye and Decline stay plain.
- Nameplates: enemy shields now show on the health bar. A light bar fills in from the right end for the shield amount (damage it absorbs), and a dark red bar from the end of the health shows heal absorbs. Turn it off with Show Shields and Heal Absorbs in the Nameplates settings.

Fixed
- Action bars: spells you can't use right now are dimmed with a see-through dark tint (blue without enough power, red out of range) and the icon stays visible, no more black squares. The tint also fades out with the bars, so the black squares that stayed on screen with the Esc menu open are gone.
- Esc menu: with Hide UI While Open, the small black squares that stayed on screen are gone. Frames without a parent frame (some icons and bars) now fade out with the rest of the UI too. If something still stays, open the Esc menu once, close it and type /h3z0ui menuscan: it lists what stayed visible.
- Cooldown Manager: procs light up again. When a spell procs (or needs to be used), its Cooldown Manager icon gets the yellow H3z0 UI glow; the game's own proc glow did not show on the skinned icons. The green border on the ability to press next now finds the right icon too (it compared the wrong number before, so it never showed).
- Custom trackers (Cooldown Manager): no more ADDON_ACTION_BLOCKED error 'tried to call the protected function Frame:Show()' when your spells or talents change in combat. The trackers now update right after combat ends.
- Action bars: buttons show again what you can't use right now: dimmed when the ability can't be used, blue when you don't have enough power, red when the target is out of range. Both were switched off in the default profile; they are turned on once for every profile (Action Bars > General > Range & Usability).
- Names above players and NPCs (the game's own nameplates, like friendly names in class colours) are sharp again. They now keep the game's own font: with the H3z0 UI font they were drawn small and scaled up, so they looked blurry.
- Action bars: a second loading screen no longer leaves the bars in the wrong state while the first one is still starting up.


H3z0 UI 0.26.28

New
- Raid frames: during a ready check the ticks, crosses and question marks show only on the H3z0 raid tiles. Blizzard's own raid frame icons stay off while H3z0 raid frames replace them, and the party frames show no ticks while you are in a raid. If you still see extra ticks, do a ready check and type /h3z0ui rcscan: it lists every visible ready check icon and who owns it.
- Lorekeeper: the Accept button on the quest scroll has a muted red colour now, so it stands out from Decline.


H3z0 UI 0.26.27

New
- Chat links: when you click an item, spell, currency or achievement link in chat, its icon now shows at the left of the tooltip (the tooltip had no icon before).
- Settings window: the Profiles & Presets row in the sidebar opens the Profiles page again (it did nothing before), and it also leaves the search results.
- Windows: when you open Inspect while the Character window is open, Inspect now opens next to it (on the right, or on the left if there is no room) and no longer sits on top of it. If you have moved Inspect yourself and saved its place, your place is used.
- Settings window: the TOOLS buttons (Layout Mode, Blizz CDM, Blizz Edit) and the version number no longer overlap each other, and the last entries of the sidebar list (like Herald) are no longer covered by the TOOLS line.
- Blizzard Mover: new command /h3z0ui moverscan lists which windows can be dragged and which ones are not ready, with the reason. The mover stays off by default; turn it on with Enable Blizzard UI Mover in the Appearance settings.
- Move windows with Shift+drag: Books and Letters (ItemTextFrame), the Guild Registrar with its Tabard window, and the Guild Invite window can now be moved too.
- Settings window: Discord, YouTube and Twitch buttons in the middle of the bottom bar (they open a box with the link to copy), and the version number in the bottom corner of the sidebar.
- Settings window: new look. The sidebar starts with a banner with the H3z0 UI logo and name (Midnight or Forever, one look for each game), then two quick rows: Profiles & Presets and Patch Notes (Layout Mode is in the TOOLS box at the bottom). The group names in the list are in the accent colour. Every page has a big title with its subtitle on a darker header band, and the bottom has Reload UI on the left and Close on the right.


H3z0 UI 0.26.26

New
- Nameplates: friendly nameplates show only the name, in the class colour (like in raids), everywhere in the world and in dungeons. This is the game's own names-only plate, so there is no health bar on friendly players and NPCs. Turn it off with Friendly Nameplates: Name Only, in Class Colours in the Nameplates settings.


H3z0 UI 0.26.25

New
- Item Upgrade: the Character window opens together with the Item Upgrade window, and closes with it again, so your equipped items are right there.
- Minimap: the tracking button is shown again, so you can choose what appears on the minimap (herbs, ore, rare creatures, critters, ...). You can hide it with Hide Tracking in the Minimap settings.

Fixed
- Lorekeeper: long choices on the scroll (like the keystone and Lindormi's Guidance ones) fit their band again, and the game's colour codes (a dark blue that was hard to read) are no longer used in the choices.
- Minimap: the coordinates no longer sit on top of the texts of the bar under the minimap (FPS, Gear, time). With that bar shown, they stay on the map.
- Lorekeeper: the "Click to complete quest" popup in the quest tracker (for example the Prey hunts) goes away once you complete the quest. Before, it stayed and came back after the quest was done.
- Nameplates: with friendly nameplates on, objects you can use (like the Rostrum of Transformation) no longer get an empty health bar with "??" and 0%. They keep the game's own name tag.
- Nameplates: a long spell name on the cast bar no longer runs into the cast time. The name is cut off where the time starts.
- Damage Meter: H3z0 UI no longer styles the meter bars or its window while you are in combat, only a moment after it ends, so it stays out of the way while the meter updates every moment. If the error "attempt to compare local durationSeconds (a secret number value, while execution tainted by H3z0UI)" still shows for you, turn off Damage Meter under H3z0 Features > UI Look > Chat + Damage Meter and tell us if it goes away.


H3z0 UI 0.26.24

Fixed
- Damage Meter: fixed the error "attempt to compare local durationSeconds (a secret number value, while execution tainted by H3z0UI)" for good. Opening Layout Mode, or moving and resizing the meter, made H3z0 UI run Blizzard's own meter code in a way the game marks as tainted, and the meter then failed on its numbers every time it updated. Showing, moving and resizing Blizzard frames now goes through the game's secure call, and the meter bars are styled the same way.
- Options window: the title and the grey line under it no longer show doubled, scrambled text on every tab. After a page was rebuilt (for example after changing the UI Version or turning the Chat skin on or off), the old copy stayed on screen behind the other tabs; it is now removed.
- Bottom Bar: a new default font now reaches every part of the bar right away (texts, spec switch, travel, menu icon letters and counters), not only after a reload.
- Bottom Bar: everything can go much bigger. Bar Height up to 80, Font Size up to 32, Menu Icon Size up to 80, Menu Icon Spacing up to 40, and a new Menu Counter Size slider for the small numbers above the menu icons.
- Objective tracker: the H3z0 UI font now also applies to the Campaign quests (title and objectives), not only to the normal quests. The tracker checks every list again after each update, so quests the game fills in later get the font too.


H3z0 UI 0.26.23

New
- Girly Look (H3z0 Features > UI Look): soft pastel pink backgrounds with little flowers behind your action bars (hearts, sparkles, polka dots and bows are there too, and the chat, damage meter and Bottom Bar can get it if you want). Pick the colours (Pink, Rose, Lavender, Peach, Mint, Baby Blue or your own), the pattern, how strong the pattern is, its size, the background opacity and how light it is (from dark to pastel), a coloured border, and which parts get it. A live preview shows every change. Works in every version of the look and in the Classic games. Turn it on or off with /h3z0ui girly.

Fixed
- Lorekeeper: the scroll no longer shows up empty (no NPC name, no greeting text) and no second window opens next to it. Texts the game hides as secret in dungeons are now shown on the scroll as they are, and the game's own NPC window is kept invisible while Lorekeeper is on.
- Lorekeeper: clicking a quest popup in the quest tracker no longer gives the error "attempt to perform arithmetic on a secret number value". The scroll now works out the size of every text safely, so it opens even when the game hides the real sizes (also in dungeons and for quests from popups).
- Damage Meter: fixed the error "attempt to compare local durationSeconds (a secret number value, while execution tainted by H3z0UI)" that Blizzard's damage meter showed over and over. H3z0 UI no longer runs its own code inside Blizzard's meter list; the meter bars are styled a moment later on their own, so the meter keeps working the normal way.
- Bank: clicking items in the bank (character bank and warband bank) works again and no longer drops your FPS. The bank window kept redrawing itself while an item was picked up, which ate the click; it now only changes the slots that changed and redraws at most ten times a second.
- Lorekeeper: Esc closes a quest offer for good. Offers the game sends again and again while you stand in an area (often in dungeons) no longer pop the scroll back open after you close them; offers that only need an OK, or that come from an item, go to the quest tracker as a popup like in Blizzard's own quest window. Esc pressed while the scroll is closing no longer opens the game menu.
- General & QoL: Auto Accept Quests and Auto Turn-In Quests are now off by default, so every quest is read in Lorekeeper. If you switched them on yourself, they stay on.
- Bags and bank: an item whose details the game keeps sending back without its quality is no longer loaded again and again (that made the bank rescan every frame).


H3z0 UI 0.26.22

New
- Classic games (first step): H3z0 UI now also loads in Classic Era, the Anniversary realms and TBC Anniversary, from the same zip. The options window, profiles, setup wizard, H3z0 look, Esc menu, Bottom Bar, minimap, chat, action bars, unit and party frames, nameplates and bags work there; things those games don't have (Mythic+, keystones, delves, skyriding, the great vault, warband bank, salvage, prey tracker, spell reminders, the Tidecaller helper) switch themselves off and their pages are hidden.
- Classic games: Character window with the H3z0 look: one rounded window instead of the old art, gear slots with a border in the item's quality colour and the item level on each slot, the average item level on top, H3z0 tabs and close button (Appearance > Skinning > Character Frame Chrome).
- Classic games: the bank and guild bank keep Blizzard's own windows (the bank bags too); the H3z0 bag window shows your own bags. The old gryphon art under the action bars is hidden while the H3z0 UI action bars are on. The Bottom Bar menu gets Spellbook and Talents (two windows in these games) and leaves out what they don't have.
- Arcanum: connected to H3z0 UI Edit Mode. Right-click the Arcanum Loot Toasts handle in Edit Mode to open all Arcanum settings right there (loot toasts with width, height, side, growth, scale and time on screen, alerts, auto vendor, self highlight, achievements). Changes apply live, and the Open Arcanum Settings button takes you to the Arcanum page in the H3z0 UI menu.
- Lorekeeper (Interface tab): talk to NPCs and handle quests on a parchment scroll on the right of the screen (a rolled paper scroll that grows with the text, written in your H3z0 UI font) instead of Blizzard's windows: numbered choices on dark bands (keys 1-9), Esc says goodbye or declines, Space continues, accepts or completes, quests show objectives, rewards (hover for the tooltip, click to choose), gold and experience. The camera moves in on the NPC and the text writes itself out like a typewriter. Every size, the position (or drag it in H3z0 UI Edit Mode) and the keys can be set. Style: Scroll, or Quest Window (the normal windows with the H3z0 UI look plus the camera, typewriter, font sizes and window size). Works everywhere: open world, dungeons, raids, delves and quests from items. Smooth Transitions: the scroll slides in and fades in when you talk to an NPC, fades out when you stop, grows or shrinks smoothly with the text, and the text fades over when the page changes (can be turned off).
- Esc menu scene: your item level under the class and specialization, your last 5 Mythic+ keys of the season (level, dungeon, in time or not) in large text in the bottom right corner, and "H3z0 UI" with the addon version in large text below the logo.
- Nameplates: Cast Bar Width (0 = as wide as the nameplate); a wider cast bar sits centred under the nameplate.
- Lorekeeper: while it is on, Auto Accept Quests, Auto Turn-In Quests and Auto Select Single Gossip Option (General & QoL) are switched off so no quest text is skipped. If another quest UI is installed (DialogueUI, Immersion or Storyline), Lorekeeper switches itself off and leaves quests to it.
- Options: Herald, Arcanum and Lorekeeper have an on / off switch in the sidebar like the Bottom Bar (the same as their Enable checkbox), and their own icons.
- Nameplates: Teammates as Names Only (Mythic dungeons and Mythic+ only). Friendly nameplates show only names in Mythic dungeons and Mythic+ keys, and go back to your own setting everywhere else (normal and heroic dungeons, raids, the open world).
- Nameplates: Live Preview at the top of the Nameplates settings. Two sample nameplates (your target casting, another enemy channelling with the threat border) show every change right away: size, font, texts, colours, rounded corners, target arrows and the cast bar. It stays at the top while you scroll through the settings.
- H3z0 Colour (Appearance > Theme & Colors): one background colour for everything. Any colour you pick is used as a dark shade of itself (bright colours are toned down), so windows always keep the dark H3z0 look. Change it and every background follows: H3z0 UI windows and panels, bags, chat, damage meter, action button slots and all skinned Blizzard windows (Mounts, Character, Adventure Guide, ...). Only the backgrounds change: buttons (menus, tabs, dropdowns, action button slots), borders and the rest of the H3z0 UI style stay the same. Backgrounds stay solid so nothing behind them shows through as lines. Default H3z0 Colour brings the original slate back.
- Bottom Bar: Bar Width (0 = full screen), Bar Scale, Horizontal and Vertical Position, your own Background Colour, and Menu Icon Size and Spacing, next to the height, font size, opacity and border that were there.
- Setup wizard: the UI size step now asks which screen you play on: 1080p (Full HD), 1440p (2K / QHD), 1440p+ (Ultrawide / 4K), match my screen, or keep the current size.

Fixed
- Lorekeeper: the scroll now opens for every NPC in dungeons, raids and Mythic+ too. Names and texts the game keeps hidden there no longer stop it from opening; if something can't be read, the scroll still opens with what can be read.
- Follower dungeons (solo with AI followers): the Dungeon Assistance toggle (followers lead or you lead) is shown again. If Blizzard's button can't be seen, H3z0 UI shows its own Dungeon Assistance button where the zone ability sits.
- Bottom Bar: the Coordinates widget has a fixed width, so it no longer runs into the FPS / latency widget next to it (and the bar no longer shifts while you move).
- Character window: the zoom and rotate buttons sit in a row at the top of the character model, between the gear columns, instead of in the middle over the character; the Reset button is wide enough for its text.
- Adventure Guide: no more freezing. Its skin is applied once after the guide finishes updating instead of again for every update (loot list, search, each encounter).
- Minimap: keeps your zoom. The zoom you set (one for outdoors, one for indoors) comes back after a login, reload or loading screen.
- Item Upgrade window: the Current and Upgrade boxes have their border lines again (only the corners were showing).



H3z0 UI 0.26.21

New
- Arcanum: set the loot toast width (200–600 px) and height (24–80 px) in the Arcanum options. Changes apply immediately to active toasts and the Edit Mode preview.
- Nameplates: casts you can interrupt show grey while your interrupt is on cooldown and turn back to the cast colour (yellow, or green for channels) the moment your interrupt is ready again, also in the middle of a cast. Uses your class interrupt (Pummel, Kick, Mind Freeze, Disrupt, Rebuke, Wind Shear, Counter Shot / Muzzle, Counterspell, Silence, Spell Lock, Spear Hand Strike, Skull Bash / Solar Beam, Quell). Casts that can't be interrupted keep their own grey. Switch: Nameplates > Grey Casts While Your Interrupt Is On Cooldown (on by default); the grey has its own colour (Interrupt On Cooldown).


H3z0 UI 0.26.1

New
- Bags: Categories layout rebuilt (Bags > General > Layout: Categories). Items are sorted into a long list of categories: Recent, Equipment Sets, Hearthstone, Keystone, Potion, Flask, Food, Consumable, Gem, Item Enhancement, Profession, Key, Battle Pet, Toy, Mount, Housing, Reagent, Trade Goods, Weapon, Armor, Container, Recipe, Quest Item, Miscellaneous, Other, Junk and Empty. Categories sit next to each other as blocks, row by row, instead of one long column.
- Bags: new Categories page. Show or hide every category, change their order with the arrows, make your own categories from a name and search text (for example #potion|#flask or epic&#armor), edit their search text or delete them, and reset the order.
- Bags: drop an item on a category title in the bag window to put that item in that category for good; right-click a title to move it left or right or hide it. Items placed by hand can be sent back from the Categories page.
- Bags: Group Identical Items (stacks of the same item share one button with the total count) and Group Empty Slots (all free slots in one button with the free count) for the Categories layout, plus Category Spacing and a separate Sort Inside Categories choice.
- Bags: new icon corners: Bind On Equip, Bind On Use, Bind On Account, Warbound Until Equipped, Warbound, Tradeable Loot, Upgrade Arrow, Uncollected Appearance, Equipment Set Icon, Keystone Level and Battle Pet Level.
- Bags: Upgrade Detection (Behavior page): Pawn if you have it, otherwise item level compared with what you have equipped; or item level only; or Pawn only. Used by the Upgrade Arrow corner and the #upgrade search.
- Bags: more search words: #weapon #armor #cloth #leather #mail #plate #cosmetic #shield #consumable #potion #flask #food #bandage #gem #enhancement #reagent #tradegoods #recipe #quest #key #container #toy #mount #battlepet #keystone #housing #glyph #profession #boe #bou #boa #wue #warbound #upgrade #transmog #set, plus item level as ilvl>600 or ilvl:600-650. ! now works as "not" next to ~, and # in front means the keyword only (a plain word still finds item names too, so "mail" still finds Chainmail).
- Bags: saved searches. Right-click the search box to pick a saved search, save the current one or delete one.
- Bags: Show Search Box, Reduce Spacing, Blank Space (part-filled row at the top or the bottom), Show Buttons (always, or only while Alt is held), Hide BoE On Common Items and Flashing New Items (General page).
- Bags: Lock Windows, Flash Duplicates (Alt+click an item and every copy of it flashes), Show Sort Button, Sort On Open, Arrange Items (from the top or from the bottom) and Ignored Slots (how many of the last or first bag slots the sort never touches) (Behavior page).
- Bags: auto-open with the Catalyst, the crafting window and the Character panel (the last two are off by default).

Changed
- Bags: Hearthstone and Keystone are always the first categories, at the top of the Inventory and Categories layouts (above Pinned Items).
- Bags: Weapons and Armor are separate categories (their own tabs in the Inventory sidebar) instead of one Armory group.

Fixed
- Bags: the Categories settings now work in the Inventory layout too. The Inventory view uses the same categories as the Categories layout, so hiding, ordering, your own categories (with search text), items placed by hand, Group Identical Items and Group Empty Slots apply to both. Your Inventory categories and the items you put in them are kept. Right-click a category in the sidebar to move, hide, rename, change the search text of or delete it.



H3z0 UI 0.26.0

Changed
- Action bars: after a loading screen (zoning, entering a dungeon, logging in) the second refresh of the bars is spread over several frames, one bar per frame, instead of all bars in a single frame. That single frame was a hitch of up to 200 ms right after the loading screen.
- Unit frames: buffs and debuffs on the player, target, focus, pet and boss frames are rebuilt once per short moment (50 ms) instead of on every single aura change, and each frame only listens to its own unit instead of every nameplate and group member. Big pulls with lots of auras no longer make the unit frames work every frame.
- Custom Trackers: cooldown, cast and aura changes update the bars once per frame instead of once per event, and only your own casts and auras are listened to.
- Bags and Mythic+ Keystone datatexts update once after you loot or move items instead of on every single bag change.
- System datatext: the addon memory list in its tooltip is read at most every 15 seconds. Reading it made the game stall for a moment every time you hovered it.
- Hover Name: only moves when the cursor moves, and reads its settings once per hovered unit instead of every frame.
- Bottom Bar Game Menu icon: the hover check runs 20 times a second and only while the bar is shown, instead of every frame all the time.
- Dungeon teleports (Mythic+ window and world map): their cooldowns are only updated while they are on screen.
- Cooldown Manager positions: if something else keeps moving a Cooldown Manager viewer, H3z0 UI stops putting it back for a few seconds instead of moving it back and forth every frame.


H3z0 UI 0.25.9

New
- Bottom Bar: a UI Mode button between Collections and Housing switches between PC, PC Controller, PC Handheld and Steam Deck. Its icon shows the mode you are in (monitor, gamepad, handheld, Steam Deck). Click it to open a list of the four modes with the current one marked, pick one and the UI switches and reloads. In combat it tells you to leave combat first.
- Esc menu: Hide UI While Open (Appearance > Skinning > Game Menu, on by default). While the Game Menu is open the rest of the UI (action bars, unit frames, chat, minimap, quest tracker, ...) fades out, so only the world, the menu and the Character & Pet Scene are left; everything comes back when the menu closes. Frames that fade themselves back in (mouseover fade, moving, windows that open) are kept hidden until the menu closes. It only makes things invisible, so it also works in combat.

Fixed
- Herald: no more banners on top of Blizzard's own (the gold zone / world quest area banner, the boss banner). Herald waits until Blizzard's banner is gone and then shows its own; if Blizzard's banner appears while Herald is showing, Herald steps back and plays its banner again afterwards.
- Arcanum: no more double loot notifications. While Arcanum's loot toasts are on, Blizzard's own "You received ..." alerts (items, currency, gold, loot upgrades) are hidden; switch Arcanum's toasts off (or just Currency / Gold) and Blizzard's come back.
- Action bars: flyouts with a long list (mage teleports and portals, the dungeon teleports) show every spell. A flyout that doesn't fit on the screen in its direction wraps into extra columns (or rows) instead of running off the edge, its buttons match the size of your action buttons, and teleports you have learned are no longer left out.


H3z0 UI 0.25.8

New
- Esc menu scene (Appearance > Skinning > Game Menu > Character & Pet Scene, on by default): while the menu is open your character stands on the left as it looks right now (shapeshift forms too) and does a random emote every few seconds (dance, cheer, wave, flex, laugh, roar, ...), a random pet from your collection sits on the right, the crest of the class you are playing is on top with your class name (in class colour) and specialization under it (the Midnight Edition class crests; Death Knight, Shaman and Monk have two crests and show one of them at random), and the H3z0 UI logo is at the bottom. Dark cinematic bands cover the top and bottom of the screen with a thin line at their edge, the middle with the menu, character and pet stays clear (they replace Dim Background while the scene is on). The menu itself keeps its look.
- Housing Dashboard skin (Appearance > Skinning > Skin Blizzard Frames, on by default): the dashboard gets the H3z0 UI window look in your theme colours. The wooden art (backgrounds, filigree corners, dividers) is gone, reward tiles and Endeavor rows sit in H3z0 UI panels, and the House Level / Endeavors tabs, side tabs, House Finder button, house picker and close button use the H3z0 UI controls. The level ring, pips, checkmarks and reward icons stay as they are.

Changed
- Every skin is on by default (Appearance > Skinning): Game Menu, Loot Window, Roll Frames, Loot History, Alerts, Damage Meter, Objective Tracker, Housing Dashboard and every Blizzard window in Skin Blizzard Frames, both on a new install and for new profiles. Existing profiles get them switched on once with a reload popup; you can switch any of them off again and it stays off.
- Patch notes and What's New no longer repeat the install steps.


H3z0 UI 0.25.7

New
- Herald (Interface tab): cinematic banners in the middle of the screen for new zones and subzones (with "Discovered" on your first visit), level ups, achievements, boss emotes, quests accepted, quest progress, quests and world quests completed, and scenario / delve stages. One banner at a time, up to 5 more wait in line with the most important first. Moving between subzones of the zone on screen only changes the subtitle. Every kind has its own switch, Blizzard's zone text and boss emote line step aside while Herald shows them, and it stays quiet about zones, quests and scenarios during a Mythic+ key. Position, scale, title and subtitle size, time on screen and animation speed are adjustable, with a Show Test Banners button.
- Arcanum (Interface tab): loot toasts for items, gold, currency and reputation that slide in at the side of the screen, one slim dark rounded row each with the icon on the left and the name in its quality colour. Repeats stack into the toast already showing (x3, +450 gold), epic and better stay longer with a sound, and hovering a toast keeps it on screen with the item tooltip. Lowest item quality, screen side, which way the stack grows, offsets, scale, time on screen and how many toasts at once are adjustable.
- Arcanum alerts: low durability, bags nearly full (each with its own threshold), new mail, friends coming online or going offline, and Great Vault rewards waiting.
- Arcanum helpers: Auto Vendor (the same Sell Junk and Auto Repair switches as Quality of Life), Self Highlight (Blizzard's outline / circle / icon marker on your character in combat, and when you target an enemy if you want) and Untrack Achievements When Earned.

Changed
- Herald: clean white look - white title, a thin white line and the subtitle under it, no dark band behind it. The small label above the title keeps the colour of the banner kind (zone, level up, boss emote, ...). Blizzard's own zone and subzone text no longer show up under Herald's banner.
- Arcanum loot toasts: new slim look - one dark rounded row per drop, icon on the left, the name in its quality colour and the amount on the right. Grey items show too (Lowest Item Quality can raise that).
- H3z0 UI Edit Mode: Herald Banner and Arcanum Loot Toasts are now elements you can drag anywhere (Display group), with a preview while Edit Mode is open. Herald's Vertical Position and Arcanum's side / offsets are used until you move them there.
- Underlight Angler Helper is now called Tidecaller, in the addon list, on the Module Addons page and on its window title. It is the helper for the Underlight Angler fishing rod (Legion artifact): a checklist of what you still need to unlock it and its trait tree, where you click a trait to buy it. Open it with /angler or on the artifact window; it only loads when you use it. Nothing about how it works has changed.

Fixed
- Skin Game Menu (Appearance > Skinning) works again: the Esc menu gets the H3z0 UI window look (dark rounded window in your theme colours, the same dark rounded buttons as the H3z0 UI windows with all of Blizzard's red button art gone, and one Game Menu title in your accent colour) instead of Blizzard's red buttons. The H3z0 UI and H3z0 UI Edit Mode buttons under Return to Game get the same look, and Dim Background works with it.


H3z0 UI 0.25.6

New
- Bottom Bar: the old 0.24.9 Bottom Bar is removed for good, the 0.25 Bottom Bar is the only one. If a test build switched the old one back on (two bars on top of each other), it is deleted on login and the Bottom Bar is switched back on. The Add Bottom Bar Preset button on the Minimap & Datatext page is gone too.
- Mythic+ timer: the H3z0 timer hides the quest / objective tracker as soon as you enter a Mythic dungeon (before and during the key) and it comes back when you leave. Switch on the M+ timer page: Hide Quest Tracker in Mythic Dungeons (on by default).

Fixed
- Bottom Bar menu icons: the Game Menu icon holds Blizzard's own menu button (no more "has been blocked from an action only available to the Blizzard UI" or "tried to call the protected function SpellStopCasting()"), hovering it shows the icon's tooltip instead of Blizzard's latency box and no longer causes FPS spikes (Blizzard's button built its addon memory list on every hover), and the other icons press Blizzard's own micro buttons.
- Character window: no more "attempt to compare a secret number value (execution tainted by H3z0UI)". Left clicks on Gold (Currency tab), Durability, Currencies, Reputation, Guild and Mythic Key go through Blizzard's buttons. Right and middle clicks work like before.
- Esc menu: the H3z0 UI and H3z0 UI Edit Mode buttons are back under Return to Game.
- Blizzard popups (Group Finder listing, invites, delete item, ...): no more "tried to call the protected function RemoveListing()". H3z0 UI's own questions (other bag addon found, bank / guild bank tab rename and buy, deposit / withdraw gold, bag categories, aura wizard, Underlight Angler) use the H3z0 UI popup and never Blizzard's.
- Toys: no more "tried to call the protected function UseToy()". The Auto-Unwrap New Collectibles option is removed.
- Edit Mode layouts with the buff and debuff frames snapped to each other no longer give "Cannot anchor to a region dependent on it".
- GSE: Actionbar Overrides set on Blizzard's button names are passed on to the H3z0 UI action button in the same place.


H3z0 UI 0.25.5

New
- Mythic+ timer: the H3z0 Pro timer is back and is the default layout again - big right-aligned timer, the time left above the +3 / +2 / +1 bars, enemy forces with your current pull, boss kill times. Pick another layout in its settings (H3z0 Pro, Compact, Full, Sleek).

Changed
- Welcome page: new look. One big H3z0 UI logo in the background, a hero card with the H3z0 UI title, version badge, Discord, YouTube and Twitch links, the Quick Setup Guide as numbered cards and the FAQ as cards. Keyword colours follow your theme accent. Nothing about how the buttons or the addon work has changed.
- Setup Wizard: new look. Rounded window, cards, buttons and boxes, a big faint H3z0 UI logo behind the pages, the H3z0 UI logo in the header badge, and a progress bar that marks the steps you have done. The first page's cards are taller so their text fits. The steps and what they do are unchanged.


H3z0 UI 0.25.4

Changed
- Bags: no white outline around the bag, bank and guild bank windows any more.
- Bags: crests and other tracked currencies sit in the bottom bar right next to your gold, instead of a separate row above it.
- Bags: a new item you hover stops glowing but stays in Recent for one more minute, so you can still open Recent and find it there.
- Bags (Inventory window, All Items): items in Recent Items are the real items now - right-click to use them, drag them, sell them - and they join their own category once they are no longer new (before they were only a preview copy).
- Bags: gear is shown highest item level first (the number on the icon), then by quality; the other sections keep quality first, then item type and name.

Fixed
- Steam Deck, PC Handheld and PC Controller: when ConsolePort's bars are used, H3z0 UI action bars 1-3 are hidden so they no longer sit under ConsolePort's bar. They come back when you leave the mode. New switch in Handheld settings: Hide action bars 1-3 when ConsolePort's bars are used.


H3z0 UI 0.25.3

New
- Setup Wizard: "The full H3z0 UI setup" (the first page) now gives exactly H3z0's own screen: every setting, every position and the Blizzard Edit Mode layout, in a profile named "H3z0 UI". It finishes right away; turn anything on or off afterwards.
- New profiles and Reset Profile start from the same full H3z0 UI setup, with the H3z0 UI Edit Mode layout. Skipping the wizard on a first install gives that setup too.
- WoW: Forever keeps its own defaults for now (a profile string only fits the client it was made on).

Changed
- General: Import / Export now sits right under Profiles (Current Profile, Manage Profiles, Copy Feature Settings, Spec Auto-Switch, Pinned Globals), before Feature Toggles.


H3z0 UI 0.25.2

New
- Profiles: FULL PROFILE in General > Import / Export now makes one string with your whole setup, your Blizzard Edit Mode layout included. Send it to someone: importing it gives them exactly the same screen (H3z0 UI settings, all H3z0 UI Edit Mode positions for PC and Deck, Chat, Damage Meter and Cooldown Manager places and sizes, UI scale, and Blizzard's layout as "H3z0 UI Shared").
- Bags: while H3z0 UI Bags is on, other bag addons (Baganator, Bagnon, AdiBags, ArkInventory, BetterBags and others) are turned off, so only one set of bags opens (also at the bank). A reload is asked once. Turning H3z0 UI Bags off turns them back on.

Changed
- Skinned Blizzard windows (Auction House, bank, mail, professions and the rest that were black) now use the same slate colours as the bags. A colour you picked yourself in Appearance > Theme & Colors is kept.
- Options window: the H3z0 UI logo sits faintly in the background of the settings pages.

Fixed
- Streamer Mode works on the H3z0 UI action bars again: the press, checked and flash highlights stay hidden, also after the bars re-skin themselves (form change, pet, spec, reload).
- Character and Inspect: opening both no longer puts one window on top of the other; they sit side by side.
- Buff frame: buffs that never run out (Cat Form and other forms, Skyriding, delve companion, mount auras and the like) are left out. New Hide Permanent Buffs switch in Autohide > Buff / Debuff Frames and Action Bars > Buff/Debuff Frames brings them back.
- Buff and debuff icons: no dark cooldown swipe over the icons any more, just the icons and their time left. New Hide Duration Swipe switch in Autohide > Buff / Debuff Frames (same as Action Bars > Buff/Debuff Frames) turns it back on.
- Action bars no longer hide when you mount, fly or skyride. New Mounted & Flying options in Action Bars > Mouseover Hide (Hide When Mounted, Hide When Flying, Hide When Skyriding, Hide In Vehicle) turn it back on if you want it.
- Autohide: Hide Error Messages (red text) now keeps them hidden all the time, also in combat ("You are in combat" and the like), after Edit Mode, and whichever way Blizzard puts the red text on the screen.
- Autohide: Hide Info Messages (yellow text) also stays on after combat and Edit Mode.


H3z0 UI 0.25.1

New
- H3z0 UI Edit Mode: right-click any handle and the settings panel has an ON/OFF switch next to the close button, for everything that can be turned off. It is the same switch as the eye in the frames list.
- H3z0 UI Edit Mode: the Cooldown Manager viewers (Essential, Utility, Buff Icons, Buff Bars), the party and raid frames and the player, target and focus cast bars can now be turned off and on.
- H3z0 UI Edit Mode: right-click Essential, Utility, Buff Icons or Buff Bars to get its own Cooldown Manager settings; Open in Settings goes to that tab.
- H3z0 UI Edit Mode: right-click the Minimap (or the map coordinates) to get the Minimap and Datatext settings; Open in Settings goes to the Minimap & Datatext page.
- Action Tracker: Enabled switch at the top of its settings.

Fixed
- Cooldown Manager: Essential, Utility, Buff Icons and Buff Bars no longer jump back to an old place (reload, spec change, opening and closing Edit Mode).
- Cooldown Manager: a viewer moved in Blizzard's Edit Mode keeps that place in H3z0 UI too.
- WoW: Forever: the chat typing box (after pressing Enter) is transparent again, no dark box around it.
- Resource Bars: the width you set for the primary (and secondary) resource bar stays after a reload. New Match Cooldown Width option next to Width: on, the bar takes the Essential cooldowns' width; setting a Width turns it off.


H3z0 UI 0.25.0

New
- H3z0 UI is rebuilt on a new, larger codebase. Every part ships as its own module folder and can be switched off in Options > General > Feature Toggles.
- Action Bars: H3z0 UI now draws its own action bars (its own bar frames, not Blizzard's), with the H3z0 UI look: the H3z0 skin (backdrop, gloss, borders), keybind and count text, mouseover fade, Modern Action Buttons and Streamer Mode. Blizzard can no longer move them around (combat, mounting, vehicles, XP bar or Blizzard's Edit Mode used to push the bars back to Blizzard's spots). Settings: Action Bars > General, Per-Bar, Totem Bar, Raid Markers, Bag Bar, Extra & Zone.
- Action Bars: on the first login each bar takes over the place you gave it in H3z0 UI Edit Mode and the icon size, padding, rows and icon count it had in Blizzard's Edit Mode. Bars 1 to 3 you never placed start stacked in the middle, just above the Bottom Bar.
- H3z0 UI Edit Mode: action bars, chat and damage meter can be moved; chat and damage meter can also be resized with the grip in the corner.
- Bottom Bar: while it is on, the micro menu bar and bag bar of the action bars are off (its menu icons replace them); turning the Bottom Bar off brings them back.
- Bags: new Inventory window. Categories sidebar (All Items, OneBag, Pinned Items, Recent Items, The Armory with Weapons / Trinkets, Armor and Item Set Gear, Adventure Prep with Consumables, Professions, Reagent Bag, Miscellaneous), item level on every item, gold in the corner.
- Bags: middle-click an item to pin it. Drop an item on a category's + slot to keep it there. Add Category makes your own (right-click to rename or delete).
- Quick Access is back on the Group Finder: one-click Mythic+, Raids, Delves, Quest and Custom, dungeon filters, and My Searches - type a dungeon or words plus a key level, search right away or keep it as your own button.
- Streamer Mode is back in H3z0 Features (also /h3z0ui streamer).
- Character and Inspect: homeland background and the H3z0 UI logo in the corner.
- Esc menu: Blizzard's own look again; H3z0 UI and H3z0 UI Edit Mode sit right under Return to Game.
- Layout Mode moves everything, the H3z0 unit, party and raid frames included. PC and Deck (Handheld Mode) keep separate positions.
- Cooldown Manager: the H3z0 UI Cooldown Manager is back with its own look (Essential, Utility, Custom Entries, Buff, Effects). The green line under Essential is gone.
- Buff Bars: the H3z0 UI buff icons and buff bars are back, set on Cooldown Manager > Buff.
- Resource Bars: the primary and secondary power bars now sit under the Essential cooldowns and follow their width, with the H3z0 UI look (texture, colours, text, ticks, border). All their settings are on the Resource Bars page (Primary Resource, Secondary Resource), and right-clicking them in H3z0 UI Edit Mode opens the same settings. Positions no longer reset.
- Custom Trackers: tracker bars and the spell scanner are back on their own page (Abilities & Auras).
- H3z0 UI Edit Mode: the Cooldown Manager viewers (Essential, Utility, Buff Icons, Buff Bars) can be moved too.
- /h3z0ui cdm opens Blizzard's Cooldown Manager settings.
- Minimap: the H3z0 UI minimap is back with its own layout (square map, zone text, clock, coordinates, datatext panel under the map). The map and the coordinates can be moved in H3z0 UI Edit Mode.
- Hover Name is back: names next to the cursor while hovering players and NPCs (H3z0 Features > Hover Name).
- Chat settings are one page again (Chat and Look & Hide together), with the module switch next to it.
- Damage Meter: always listed in H3z0 UI Edit Mode and shown while it is open; extra meter windows can be moved too.
- Friendly NPC nameplates: Always Off (default), Always On or Game Setting on the Nameplates page. Always Off / Always On keep it that way even if the game's option is changed.

Changed
- Skyriding bar is off by default.
- Cooldown Manager: no press / click highlight on the icons.
- Bags: rounded window with a softer slate background.
- Keybind text: action bars and the Utility cooldowns show the key in the same place by default (top right, size 12, X -1, Y -7).
- Language: H3z0 UI is English only for now; (more languages, Bulgarian first, will come later).
- WoW: Forever: empty action buttons are hidden by default.
- H3z0 UI Edit Mode: scaled frames (Cooldown Manager, chat, damage meter, unit frames) stay exactly where you drop them; before, closing Edit Mode put them back with the wrong scale.
- H3z0 UI Edit Mode: the resize grip in the bottom-right corner of the chat and damage meter handles works again (it was never shown); drag it to make them bigger or smaller.
- H3z0 UI Edit Mode: right-click the Chat Window or Damage Meter handle for its settings: dark rounded window, background opacity and a link to the Chat page.
- Chat page: new Chat & Damage Meter Windows section with the window skin and a background opacity slider for each.
- WoW: Forever: empty action buttons are hidden once on the first login (Action Bars > General > Hide Empty Slots turns them back on).

- Your settings are kept; a backup of your profile is made on the first login.