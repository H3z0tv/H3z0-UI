H3z0 UI 0.25.0

New
- H3z0 UI is rebuilt on a new, larger codebase. Every part ships as its own module folder and can be switched off in Options > General > Feature Toggles.
- Kept from H3z0 UI: Chat, Damage Meter skin, H3z0 Features, Nameplates, Unit Frames, Party Frames and Raid Frames.
- Bottom Bar is now the Info Bar, set up with your Bottom Bar settings and your own menu icons: menu icons and spec on the left, the clock in the middle, professions, gold, bags and location on the right. While it is on, Blizzard's micro menu and bag bar are hidden. All its settings are on the Bottom Bar page (Bottom Bar tab + Widgets & Zones tab), including menu icon size and spacing.
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
- Setup wizard: the first-run wizard is now the H3z0 UI setup wizard: start from (keep settings, fresh H3z0 UI defaults or a pasted profile string), look, font, PC / Steam Deck / controller, UI scale, nameplates, features, extras and frame layout (H3z0 UI Edit Mode layout). /h3z0ui install, /h3z0ui setup and the Setup Wizard buttons all open it.
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
- Stack counts on the action bars: bottom right, size 12, X -2, Y 1 by default.
- Clean-up: leftover names, links and internal names from the old codebase are gone; the starter profile now uses H3z0 UI's own fonts and textures.
- Language: H3z0 UI is English only for now; the other translations are removed (more languages, Bulgarian first, will come later).
- WoW: Forever: empty action buttons are hidden by default.
- H3z0 UI Edit Mode: scaled frames (Cooldown Manager, chat, damage meter, unit frames) stay exactly where you drop them; before, closing Edit Mode put them back with the wrong scale.
- H3z0 UI Edit Mode: the resize grip in the bottom-right corner of the chat and damage meter handles works again (it was never shown); drag it to make them bigger or smaller.
- H3z0 UI Edit Mode: right-click the Chat Window or Damage Meter handle for its settings: dark rounded window, background opacity and a link to the Chat page.
- Chat page: new Chat & Damage Meter Windows section with the window skin and a background opacity slider for each.
- WoW: Forever: empty action buttons are hidden once on the first login (Action Bars > General > Hide Empty Slots turns them back on).

Install
- Delete the old H3z0UI folder first, then copy all H3z0UI folders from the zip into AddOns.
- Your settings are kept; a backup of your profile is made on the first login.
