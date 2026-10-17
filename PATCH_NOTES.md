# H3z0 UI - Patch Notes

## 0.23.7 - Streamer Mode
- **Streamer Mode** (Action Bars > Master Settings > "Streamer Mode (hide button press highlight)", `/h3z0ui streamer`): hides the press / active highlight on every action button (pushed glow, checked border, SpellCastAnimFrame, TargetReticleAnimFrame, InterruptDisplay) on all bars, stance, pet and the extra action button. Only alpha is changed, so it works in combat and writes nothing into Blizzard's buttons; turning it off brings the highlights back.

## 0.23.6 - Taint clean-up
- Fixed: "GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'H3z0UI'" (Blizzard_MawBuffs via the Scenario / quest tracker, hundreds of times). The Objective Tracker skin wrote Blizzard's `ObjectiveTrackerFrame.editModeHeight` and called `UpdateHeight()` / `ObjectiveTrackerManager:UpdateAll()` itself, so every later tracker update ran tainted and failed on secret auras. None of that is done any more: the tracker's height comes from Edit Mode (`/h3z0ui blizzedit`), the skin's "Max Height (background)" only limits the H3z0 background, and new tracker font sizes show on the tracker's next own update.
- M+ Timer: Blizzard's scenario tracker is hidden with alpha only (no Hide() / ObjectiveTrackerFrame:Update() from addon code).
- Tracked Bars: Blizzard's BuffBarCooldownViewer fields (isHorizontal, layoutFramesGoingRight/Up) are no longer written; H3z0 UI lays the bars out itself.
- Fixed: the Extra Action / Zone Ability button flickered / kept disappearing. H3z0 UI reparented ExtraActionBarFrame / ZoneAbilityFrame into its own holders and re-anchored them on every Blizzard SetPoint, fighting Blizzard's Extra Ability container. They now stay in Blizzard's container (only scale and "Hide Button Artwork" are applied); position = the container, moved with the "Extra Abilities" handle in H3z0 UI Layout Mode - shown as a 64x64 placeholder while no extra button is active, so it can always be placed - (right-click opens Action Bars > Extra Buttons). The old holder position is migrated once; the X/Y offset sliders are gone and "Toggle Position Movers" became "Move in Layout Mode".
- Fixed: Tracked Buffs (BuffIconCooldownViewer) icons re-skinning / jumping constantly. LayoutBuffIcons resized Blizzard's viewer to the icon grid on every buff change; that fired Blizzard's layout and our OnSizeChanged / Layout hooks again (a loop) and ran Blizzard's size handlers tainted. The viewer is no longer resized; icons are still centred on it, sized and skinned by H3z0 UI.
- Talking Head mute: only stops the sound, Blizzard's voHandle field is left alone. Cooldown Manager sort data stored under H3z0-only keys.

## 0.23.5 - Resize chat / damage meter, quest completion, ready check
- **Resize the chat window and the damage meter in Layout Mode**: their handles get a corner grip (bottom right). Drag it to resize; the top-left corner stays put. Sizes are stored in the H3z0 UI profile (profile.blizzSizes, PC and Deck separately) like the Blizzard frame positions, re-applied after login / Edit Mode updates, and exported in layout codes (blizzSizes).
- Fixed: completed quest objectives (e.g. Prey quests) didn't look complete with the Objective Tracker skin. The skin painted every objective line in the chosen text colour; lines Blizzard marks Complete / Failed now keep Blizzard's colour and check.
- Fixed: Party Frames ready check icons (from 0.23.4) - answers tracked from the ready check events, `/h3z0party ready` previews them.

## 0.23.4 - H3z0 Pro M+ timer, PC Handheld, own layout storage, new default layout
- **Layout Mode no longer touches Blizzard's Edit Mode.** Positions of Blizzard frames (action bars, Cooldown Manager, buffs, objective tracker, ...) are saved in the H3z0 UI profile (PC and Deck separately) and H3z0 UI places the frames itself. No more "H3z0 PC" / "H3z0 Deck" Edit Mode layouts are created or switched; Handheld Mode / PC Handheld only swap the addons. Export codes (v2) carry these positions; older codes still import the H3z0 frame positions.
- **New default layout** for new installs (PC and Deck, Blizzard frames included). Existing setups are not changed; use Import to take it.
- Layout Mode right-click: Chat Frame opens General & QoL > Chat, Extra Action / Zone Ability opens Action Bars > Extra Buttons, Talking Head and the XP / reputation bar open Autohide. Frames without H3z0 settings show a short note on screen instead of chat lines.
- **M+ Timer: H3z0 Pro layout** (Skinning & Autohide > Skinning > H3z0 UI M+ Timer > Layout Mode, now the default layout; existing setups are switched to it once). Big right-aligned timer (gold when timed, red when over), the +3 / +2 / +1 bars with the time left above each bar, enemy forces bar with the current pull shown in orange and as "(+x%)", forces completion time, boss kill times in green, deaths with a death log (who and when) on the tooltip. New option "Enemy Forces in Tooltips" shows the count a mob gives while in a key (game API, or MDT when installed). Toggle Demo Mode shows it. Also fixed for every layout: boss kill times were overwritten with the current time on every update.
- Hover Name: default distance from the cursor raised (18), and while mouselooking / Action Combat the name moves a further "Gap While Aiming" (default 28, General & QoL > Hover Name) away so it never covers the crosshair.
- Fixed: ADDON_ACTION_FORBIDDEN "UpgradeItem()" (Item Upgrade confirm blocked, blamed on H3z0 UI). Root cause: the tooltip module replaced Blizzard's global MoneyFrame_Update / SetTooltipMoney (and GameTooltip.SetSpellByID) with pcall wrappers; the upgrade popup draws its cost with MoneyFrame_Update, so the popup ran addon code and became tainted. Those replacements are gone. Also no longer written: the LOCK_ACTIONBAR global (Blizzard keeps it in sync itself) and the accidental globals StopGlow / UpdateZoneTextDisplay (now local). In addition, every H3z0 UI popup (reload prompts, layout import, Plater import, gold data, ...) now uses H3z0 UI's own dialog (core/popup.lua) instead of Blizzard's StaticPopup, which an addon taints just by using it. "Auto-Fill DELETE Text" is off by default now (it must write into Blizzard's delete popup) and no longer calls Blizzard's handler itself.
- Fixed: Objective Tracker skin hid the delve banner (title / tier), leaving an empty gap at the top of the Delves section. The banner is kept while in a delve; the tracker is re-laid out after SCENARIO_COMPLETED and zone changes so a finished delve doesn't linger.
- Fixed: Party Frames ready check icons not showing. Answers are tracked from READY_CHECK (initiator = ready, everyone else waiting) and READY_CHECK_CONFIRM (per unit, raidN mapped to partyN), with GetReadyCheckStatus / C_PartyInfo only as a fallback; the icon is kept above the portrait and Frame Style overlays. `/h3z0party ready` previews the icons.
- **PC Handheld** (H3z0 Features > Steam Deck + PC Controller, `/h3z0ui pchandheld`): the Steam Deck setup on PC - Steam Deck HUD and Deck frame positions and ConsolePort (Action Combat Mode off), but your normal PC UI scale. Only one of PC Controller, PC Handheld and Steam Deck can be on; switching between them reloads. Unticking PC Handheld goes back to the normal PC layout and addons.

## 0.23.1 - Fixes and menu order
- Menu order: **Nameplates** and **Party Frames** are their own pages in the sidebar (after H3z0 Features and after General & QoL), and **Portraits** is a tab in Unit Frames.
- **What's New window**: opens once after each update with what's new and what's fixed (not on a fresh install). `/h3z0ui whatsnew` or H3z0 Features > Extras opens it again. Entries live in modules/qol/whatsnew_data.lua.
- Fixed: Objective Tracker skin text overlapping / misplaced after changing its font sizes. The sizes now go into Blizzard's own tracker fonts, so Blizzard lays the tracker out correctly (no more manual line moving). Layout Mode: right-click on the Objective Tracker opens its skin settings, buffs/debuffs open Buff & Debuff.
- Fixed: dropdown lists in the options (e.g. Bar Texture) opened behind switches and headers and could not be clicked after a right-click from Layout Mode. Dropdown lists and popups now always stay on top, and Layout Mode no longer changes the options window's layer.
- Fixed: the ConsolePort / Action Combat Mode switch (Handheld Mode, PC Controller, Setup Wizard) did not work reliably on WoW: Forever. It now reads the addon state the way both clients answer, switches all ConsolePort modules together (ConsolePort_Bar, _Menu, ...), sets them for all characters and the current one, turns the game's gamepad support on for ConsolePort, and lists in chat what it switched.

## 0.23 - Layout Mode, Midnight + WoW: Forever
Everything from 0.22.18 is unchanged (same menu, same frames, same sizes). New:
- **Share layouts**: Export / Import buttons in the Layout Mode toolbar and in H3z0 Features > Layout & Bars (`/h3z0ui export`, `/h3z0ui import`). One code holds every frame position for PC and Deck, Blizzard frames included. The H3z0 default layout (layout_default.lua) is applied automatically the first time someone runs the addon (new installs only; existing setups are never overwritten).
- Fixed: long option names in the menu ran under their switch / slider / dropdown. Labels now stay in their column everywhere (wrap to two lines, slightly smaller text when needed).
- **PC Controller**: play on PC with a controller. Keeps the normal PC layout and only swaps the addons (ConsolePort on, Action Combat Mode off), then reloads. In H3z0 Features > Steam Deck + PC Controller, the Setup Wizard (new "PC + Controller" choice) and `/h3z0ui controller`. PC Controller and Steam Deck (Handheld Mode) can't be on together: turning one on turns the other off.
- Fixed: the preview cast on the cast bars kept showing after every reload (it stayed saved when the UI reloaded while Layout Mode was open). Previews are now always off after a login or reload.
- Layout Mode: right-click a handle to open that frame's settings page in the H3z0 UI options on top of Layout Mode (it stays open; Esc closes the options first, then Layout Mode) (unit frames, cast bars, party, power bars, totems, timers, minimap, coordinates, panels, action bars, Cooldown Manager).
- Fixed: ADDON_ACTION_BLOCKED "GameMenuFrame:SetSize()" when opening the Esc menu in combat. H3z0 UI no longer changes the Esc menu (buttons, skin, layout) while in combat.
- `/h3z0ui cdm`: checks why Essential / Utility / Buff Icons / Tracked Bars do not show and repairs it (Cooldown Manager option off, viewer set to Hidden in the Edit Mode layout, viewer off-screen).
- Layout Mode no longer shows Action Bars 1-3 while Handheld Mode (Deck) is on.
- Fixed: in Steam Deck / Handheld Mode the player cast bar was Blizzard's default one. The H3z0 UI cast bar now stays on there, free-positioned (below the screen centre) so it can be moved in H3z0 UI Layout Mode.
- Fixed: Handheld Mode did not switch the Combat Mode addon after it was renamed to "Action Combat Mode". It is now found by its folder (CombatMode) or any of its names.
- **One Layout Mode for everything, with PC and Deck layouts.** H3z0 UI Layout Mode now also moves Blizzard frames (Cooldown Manager, buffs/debuffs, objective tracker, micro menu, bags, extra button and the rest of Edit Mode). Their positions are written into the Edit Mode layouts "H3z0 PC" and "H3z0 Deck" that H3z0 UI manages, so Blizzard Edit Mode is not needed: the Esc menu's Edit Mode button now opens H3z0 UI Layout Mode, and Blizzard's editor is only reachable with /h3z0ui blizzedit for its size settings. Every H3z0 UI frame also keeps one position for PC and one for Deck; Handheld Mode switches between them. The Deck layout starts from your existing "H3z0 Deck" Edit Mode layout.
- **Handheld Mode** switch: turning it on disables Action Combat Mode, enables ConsolePort, switches Edit Mode to the layout named "H3z0 Deck" and reloads the UI. Turning it off enables Action Combat Mode, disables ConsolePort, switches back to your normal Edit Mode layout and reloads. When a reload follows, the settings are only saved (no live UI rescale or frame refreshes first), so the switch no longer freezes the game before the reload.
- **H3z0 Features** tab at the top of the options sidebar. Everything H3z0 UI added is in one place there: Portraits (Frame Style, the unit frame portraits and the party portrait size, moved from their old tabs), Combat Mode, Bottom Bar, Steam Deck + PC Controller, Nameplates and Party Frames (moved from General & QoL), Layout & Bars (Layout Mode, Compact Action Bars), Map (coordinates, moved from Minimap) and Extras (party, WoW: Forever, Setup Wizard, chat commands).
- **Look (Test)** in H3z0 Features. Both parts can be switched on and off at any time to compare:
  - **Frame Style** with two looks. Your unit frame settings are not changed; turning it off restores them. `/h3z0ui style`
    - *Round Portrait*: round portrait with a class/reaction colored ring beside Player, Target (and optionally Focus), name above the bar.
    - *Docked Portrait*: one bordered box with the portrait inside on the outer side, class colored bar filling the rest (missing health in a light tint of the class color), name on the top edge, rested "Z" in the middle, no power bar. Pet bar docked under the left half with its name on the bottom edge; health text ("445K | 100%") level with it on the right.
    - Both keep your health bar color (class color) and share one set of settings: Frame Height, Portrait Size, Portrait Border Thickness, Class Colored Border, Name on Top, Pet Bar Under the Player.
  - **Compact Action Bars**: switches Blizzard Edit Mode to a separate "H3z0 Compact" layout (Action Bars 1-3 as an 8-button grid at the bottom center, Action Bar 4 underneath). Your own layout is untouched; press again to go back. `/h3z0ui bars`
- Fixed: Reticle GCD ring and Rotation Assist swipe throwing "Secret values are only allowed during untainted execution" (SetCooldown) on Midnight. They now use the DurationObject cooldown API, and the reticle no longer runs its GCD code while the reticle is disabled.
- **Layout Mode**: one place to move every H3z0 UI frame. Open it with `/h3z0ui layout`, the Esc menu's **Edit Mode** button, or the **Layout Mode** button at the top of the options window.
  - Green handles on: Player, Target, Focus, Pet, Target of Target and Boss frames, their cast bars, Party Frames, Raid Control tab, Power Bar, Secondary Power Bar, Totem Bar, Combat Timer, M+ Timer, Minimap, Bottom Bar and other datatext panels, Action Bars 1-8, Stance Bar and Pet Bar.
  - Drag a handle to move the frame. Click to select, then arrow keys nudge 1px (Shift = 10px). Grid and Snap buttons in the toolbar. Esc or Done to leave. It closes by itself when combat starts.
  - Only positions change, never sizes. Positions are saved through each frame's own settings, so the options menu shows the new X/Y values.
  - Frames locked to another frame (for example a cast bar locked to the unit frame) show "(locked)"; change their anchor in the options to move them freely.
  - **Action bars** (Action Bar 1-8, Stance Bar, Pet Bar) can be moved too. Their position is saved into your active Blizzard Edit Mode layout (the bar itself is never moved by the addon, Blizzard moves it), so it is the same as moving them in Edit Mode. Rows, number of buttons and icon size stay in Edit Mode. If you are on Blizzard's Modern/Classic preset, Layout Mode offers to copy it to a custom "H3z0 UI" layout first. If a bar doesn't jump to its new spot right away, /reload.
  - Cooldown Manager rows, buffs/debuffs and the quest tracker stay in Blizzard's Edit Mode (toolbar button "Blizzard Edit Mode").
  - Party frames and the Raid Control tab are shown as a preview while you're solo, cast bars/totem bar/combat timer/M+ timer show their previews.
- **Minimap coordinates**: new "Coordinates" section in Minimap & Datatext > Minimap: show/hide, precision (45,62 / 45.3,62.1 / 45.31,62.08), horizontal and vertical offset, text size, alignment and class color. The coordinates also have their own handle in Layout Mode, so you can just drag them.
- **Map coordinates on/off**: an **XY** button appears in the bottom-left corner of the minimap when you hover it - click to show/hide the coordinates (green = on). Also `/h3z0ui coords` and a keybind (Key Bindings > AddOns > H3z0UI: "Show / hide map coordinates", plus "Toggle H3z0 UI Layout Mode"). The XY button can be turned off in the Coordinates options. Coordinates stay off by default.
- **Setup Wizard step 4 "Extras and helpers"**: map coordinates, H3z0 party frames, combat timer, M+ timer (Midnight), consumable check, crosshair, totem bar and skyriding bar (Midnight) - each one switch. The last page has an **Open Layout Mode** button to place everything right away.
- **Party frames: ready check**: during a ready check each member's portrait shows a green tick (ready), red cross (not ready) or the waiting icon. The result stays for a few seconds after the check ends (no answer = not ready), then fades out.
- **Party frames**: Blizzard's raid frame manager tab on the left screen edge is hidden while you're in a party (the H3z0 UI Raid Control tab does that job). It comes back in raids or when "Hide Blizzard party frames" is off.
- **WoW: Forever**: fixed `customtrackers.lua:234: attempt to call a nil value` (and the same problem in the spec datatext, profiles spec switching, resource bars, pet warning, quick access and character pane). Forever doesn't have the old global spec functions; the addon now uses the C_SpecializationInfo versions there.
- **WoW: Forever**: the custom character pane and inspect overlays are off; Blizzard's own character and inspect frames are used. The character frame shows the item level on every equipped slot (quality colored, red when durability is under 25%) and the average item level (equipped / overall) at the top. Turning "Character Pane" off in the options hides these too. Midnight is unchanged.
- **WoW: Forever**: the gryphons and bar art around the main action bar and the micro menu are hidden.
- **Works on Midnight and WoW: Forever**: the addon loads on both clients (interface 120000-120105 and 16001). On Forever the 12.x health/power APIs are used, and LibOpenRaid stays off (party keystones are not available there).

## 0.22.18 - Chat background after reload
- Fixed the chat showing Blizzard's background again after /reload (until a button was clicked). With the glass background off, Blizzard's own chat background was never removed at login; it is now always stripped, and stripped again after Blizzard re-applies it (login, fade in/out, opacity changes).

## 0.22.17 - H3z0 UI Party Frames
- New own party frames: round portrait with class-colored ring (white when targeted), level badge, role icon, leader crown, class-colored name, health bar with abbreviated value, power bar and an aura row (debuffs red-bordered, stacks and swipes).
- Secure unit buttons: click targets, right click opens the menu, works in combat. Members fade when out of range.
- Settings in General & QoL > Party Frames (scale, spacing, grow up, sizes, colors, elements, auras, show yourself, hide Blizzard party frames). Shift+drag a frame to move the list, `/h3z0party test` previews, `/h3z0party reset` resets the position.
- The Raid Control tab now sits on top of these party frames.

## 0.22.16 - Raid Control moved to a party tab
- Raid Control is now a small crown + arrow tab at the top-left of your party frames, shown only while you are in a 5-man party (hidden in raids and when solo). Click it to open the skinned panel (Ready Check, Role Check, Pull Timer, Cancel Pull, Convert to Raid).
- Shift+drag the tab to move it; `/h3z0rc reset` puts it back. `/h3z0rc` still toggles the panel.
- Removed the Raid Control button from the Bottom Bar Menu Icons.

## 0.22.15 - Raid Control panel (works in party)
- New movable Raid Control panel: Ready Check, Role Check, Pull Timer (custom seconds), Cancel Pull and Convert to Raid/Party. Works in a 5-man party, where Blizzard's own panel is not available.
- Open it with the new crown "Raid Control" button in the Bottom Bar Menu Icons, or with /h3z0rc (or /raidcontrol). Drag it to move; the position and pull seconds are remembered.

## 0.22.14 - Chat style presets
- General & QoL > Chat: new "Chat Style" buttons at the top. "Clean (no background)" gives a transparent chat with outlined text and blue [HH:MM] timestamps; "Glass (default)" restores the dark see-through panel.

## 0.22.13 - Housing button
- Added a Housing button (own house icon) to the Bottom Bar's Menu Icons, next to the Great Vault. Click opens the Housing Dashboard.

## 0.22.12 - Consumable check aura fix
- Fixed `GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'H3z0UI'` (consumablecheck.lua).
- Player buff scans are now wrapped so a blocked aura read can never throw an error.
- The post-combat consumable refresh no longer runs when the Consumable Check is switched off.

## 0.22.11 - Cooldown swipe secret-value fix
- Fixed `swipe.lua:42: attempt to compare a secret number value (execution tainted by 'H3z0UI')`.
- The swipe hook compared `auraInstanceID > 0`, but that ID can be a secret value. It is now checked with `issecretvalue` first (a secret ID counts as an active aura).

## 0.22.10 - Tracked Bars taint fix
- Fixed `CooldownViewer.lua:1862: attempted to index a table that cannot be accessed while tainted (execution tainted by 'H3z0UI')`.
- H3z0 UI no longer writes properties (`isHorizontal`, `layoutFramesGoingRight/Up`, internal flags) onto Blizzard's Tracked Bars frame, and no longer resizes it (`SetSize`) from addon code. Those writes tainted the frame's aura table.
- Polling timers/flags for the Tracked Buffs/Bars viewers now live in the addon's own locals.
- Note: bars are still skinned and positioned by H3z0 UI; the viewer frame itself is left to Blizzard.

## 0.22.9 - LibOpenRaid secret-value fix
- Fixed the Lua error `LibOpenRaid.lua:3599: attempt to perform boolean test on local 'bUnitIsThePlayer' (a secret boolean
  value, while execution tainted by 'H3z0UI')` (thousands of repeats, e.g. on `UNIT_SPELLCAST_SUCCEEDED` for `targettarget`).
- Cause: the bundled LibOpenRaid cooldown tracker ran `UnitIsUnit(unitId, "player")` for every unit's spell cast and then
  tested the result. In Midnight that result is a secret boolean for non-group units, and tainted code may not test it.
- Fix: the tracker now ignores any unit that is not the player, pet or a party/raid member, and skips secret values
  instead of testing them. Group cooldown tracking is unchanged. LibOpenRaid internal version bumped 173 -> 174.

## 0.22.8 - Cooldown Viewer taint fix
- Fixed the Lua error `CooldownViewer.lua:939: attempted to index a table that cannot be accessed while tainted
  (execution tainted by 'H3z0UI')` (seen on target change / `InteractUnit`, many times in a row).
- Cause: the cooldown manager layout (modules/cooldowns/cdm_viewer.lua) called `Show()`, `Hide()` and `SetSize()` on
  Blizzard's Cooldown Viewer item frames. Those calls synchronously run Blizzard's own OnShow/OnHide/OnSizeChanged
  scripts in tainted execution, which poisoned Blizzard's cooldown cache.
- Fix: Blizzard's item frames are no longer shown/hidden by H3z0 UI. Icons beyond the row capacity are made invisible
  (alpha 0) instead of hidden, and icon/viewer sizes are only written when they actually change.
  Custom CDM icons (H3z0 UI's own frames) are unaffected.
- Do a `/reload` after updating. If the error still shows up, send the new stack trace.

## 0.22.7 - Minimap button uses the H3z0 logo
- Fixed: the H3z0 UI minimap button showed a squashed, unreadable white blob. It was using the wide wordmark texture
  (`H3z0UI.tga`, 256x32), which gets stretched into the round button.
- The minimap button now uses the H3z0 logo (green skull) via a new square, tightly cropped texture
  `assets/minimap_icon.tga` (128x128), so it stays crisp and centred inside the button ring.
- No settings changes; the tooltip, left/right-click behaviour and the "Hide H3z0 UI Minimap Icon" option work as before.
- Version bumped to 0.22.7 (TOC + README).

## 0.22.6 - Setup Wizard
- New first-start **Setup Wizard** (modules/qol/setupwizard.lua). Three steps: (1) PC or Steam Deck / Handheld (+ handheld UI scale:
  Compact 0.85, Pixel-perfect, Comfortable 1.15), (2) nameplate addon: none / Plater / Platynator / BetterBlizzPlates,
  (3) features: Bottom Bar, minimap, chat, unit frames, action bars, tooltips, character pane, Quick Access, missing raid buffs,
  hover name. The last screen shows a summary, the Plater one-click import (or a pointer to the Nameplates tab for
  Platynator / BetterBlizzPlates) and a Reload UI button.
- Shows once on a brand-new install (it replaces the silent Handheld auto-switch and the old 1280x800 popup there).
  Existing installs are never interrupted. "Skip (use defaults)" keeps the old behaviour; Esc / X just closes it.
- Always available again: `/h3z0ui setup` or the new **Setup Wizard** page in the options sidebar (below Import).
- Choices are saved in the profile (`profile.setup`); device = PC turns Handheld Mode off and stops the small-screen auto-switch.

## 0.22.5 - Steam Deck layout matches the reference screenshot
- Player frame (portrait + name/health bar) moved to the top-left corner exactly as in the reference screenshot
  (portrait 10 units from the left edge, 5 from the top). Pet bar moves with it. The primary power bar already matched.
- The layout is now proportional, so it looks the same at ANY Handheld UI scale (0.5 - 1.4: Compact, Pixel-perfect,
  Comfortable or the slider) and on any handheld resolution (Deck 1280x800, Ally 1080p, Legion Go, docked): sizes, fonts and
  positions are scaled by (UI height now / reference UI height). Reference = 2560x1440 at UI scale 0.85.
- Left-hand frames (player, pet) keep their distance from the left screen edge on 16:10 screens (`ns.HandheldEdgeAnchors`).
- Changing the Handheld UI Scale (slider / preset buttons) now re-applies the layout immediately; it also re-applies
  when the resolution changes (e.g. docking the Deck).
- Nameplates tab: new **BetterBlizzPlates** section (status line, "Open BetterBlizzPlates settings" button, copy box with
  H3z0 UI's BetterBlizzPlates string in importstrings/betterblizzplates.lua - import it in BetterBlizzPlates > Profiles).
- Note: Handheld Mode re-applies the preset values on every login, so frames moved in H3z0 Edit Mode while it is on are
  reset; copy new positions into handheld_layout.lua to make them the preset.

## 0.22 - Default profile for new installs
- H3z0 UI's own profile string (importstrings/h3z0uiprofile.lua) is now the DEFAULT PROFILE: a brand-new install is
  set up with it automatically at first login - no import step, no reload (core/main.lua, `ApplyDefaultProfileOnFirstRun`,
  runs once from OnInitialize before any module reads the profile).
- Existing users are never touched: if the profile already has saved settings the addon only records "skipped"
  (`db.global.firstRunProfile`), so updating from an older version keeps your own settings.
- The profile has Steam Deck / Handheld Mode on auto-detect, so on a Steam Deck or any screen <= 800p the Steam Deck HUD
  layout (see below) switches on by itself the first time; on a desktop screen it stays off (turn it on with /h3z0ui deck).
- To change what new users get: export your profile, paste it between the [[ ]] in importstrings/h3z0uiprofile.lua.
- Welcome line in chat on the first login. If the string ever fails to apply, the addon falls back to its normal
  defaults and prints why.

## 0.22 - Nameplates tab
New sub-tab Options > General & QoL > Nameplates collects everything nameplate related:
- Plater: status line, one-click "Import into Plater" (uses Plater's own ImportAndSwitchProfile into a new profile
  named "H3z0 UI" after a confirmation, so your other Plater profiles are untouched) + copy box with the string.
- Platynator: status line, "Open Platynator settings" button + copy box with the string (import it in Platynator).
- Friendly Nameplates: the two hide toggles moved here from Skinning & Autohide (same settings, same CVars).
- The Plater / Platynator string boxes were removed from Import > H3z0 UI's Strings (now only in the Nameplates tab).
- Credits section removed from README.

## 0.22 - Steam Deck HUD layout
Handheld / Steam Deck Mode now uses a HUD layout modelled on the H3z0 Steam Deck reference screenshot (1280x800):
- Target: wide hostility-coloured bar at the top centre - name left, health % right, small portrait on the right.
- Player: portrait (class-coloured border) at the top left with a slim name/health bar beside it, like the reference.
- Power bar: the primary resource bar is moved to a slim bar under the character at the bottom centre (text off).
  The secondary bar - combo points, runes, holy power - is untouched.
- Focus and target of target: small bars either side of the target bar. Pet: thin bar under the player portrait.
- Boss frames stay off (as before). Everything is restored when Handheld Mode is turned off.
- New in handheld.lua: `ApplyProfileLayout` (save/restore of top-level profile tables from ns.HandheldProfileLayout).
- Not part of the layout (set them yourself in Edit Mode / their own addons): action bar position, objective tracker,
  damage meter, party / companion frame, buffs row.
- Setup popup and options text updated. Version 0.22.

## 0.21 - Tracked Buffs taint (v7)
`ForcePopulateBuffIcons` (modules/frames/buffbar.lua) called Blizzard's `BuffIconCooldownViewer:Layout()` and nudged
its size from addon code at login. That ran Blizzard's layout tainted and caused the "CooldownViewer.lua
CheckAuraAddedAlertTriggers ... cannot be accessed while tainted" error on the Tracked Buffs viewer. Both calls are
removed; the rescan/skin step stays.

## 0.21 - Patch 12.1.5 compatibility
- TOC Interface is now 120105 (12.1.5); 120100/120001/120000 stay listed so older clients still load it.
- Blizzard removed the deprecated global fallbacks in 12.1.5. Every use in the addon was moved to the new API:
  GetItemInfo, GetItemInfoInstant, GetItemGem, GetItemQualityColor, GetDetailedItemLevelInfo -> C_Item.*,
  GetZonePVPInfo -> C_PvP.GetZonePVPInfo (minimap, data texts, character panel, loot/alert skins, LibOpenRaid).
- Checked and unaffected: Cooldown:SetCooldown/Clear (only used on addon-made, unprotected frames), UnitCastingInfo
  (always called with lowercase unit tokens), the removed C_PvP training ground / C_LFG / pet / trade / sound functions.

## 0.21 - Steam Deck unit frame layout
Steam Deck / Handheld Mode now also swaps the unit frames (player, target, focus, pet, target of target, boss) to a
compact 1280x800 layout: size, position, border, name/health text, aura/absorb/castbar switches. The values were read
from an exported EllesmereUI profile string (EllesmereUI is not needed or used) and live in
modules/qol/handheld_layout.lua. Turning Handheld Mode off restores your own values. Switch it in
Options > General & QoL > Steam Deck > "Use the Steam Deck unit frame layout". Frames/castbars that the layout turns
on or off need a /reload. Not copied: portraits above the frame, textures, fonts, class-power bars.

## 0.21 - taint fix / brez removal

### Fixed - "attempted to index a table that cannot be accessed while tainted" (CooldownViewer.lua)
The addon replaced `Show` on Blizzard's cooldown icon overlay textures (`region.Show = function() end`). Every later
Blizzard call to that function then ran tainted and poisoned the Cooldown Viewer's aura handling. Both places
(core/main.lua, modules/frames/buffbar.lua) now use `hooksecurefunc` instead, which does not taint.

### Fixed - "GetAuraSlots(): Auras cannot be accessed when secret while tainted" (LibOpenRaid)
The embedded LibOpenRaid scanned player auras to work out cooldown durations. In Midnight addon code may not read
secret auras, so it threw on every cast. Both aura scans in libs/LibOpenRaid/GetPlayerInformation.lua are now wrapped
in pcall (falls back to the stored durations). Only party keystone sharing uses this library.

### Fixed (attempt 2) - CooldownViewer taint, custom CDM icons
Custom CDM icons (modules/cooldowns/cdm_custom.lua) were children of the Essential/Utility viewers and carried a
`layoutIndex` written by addon code. Blizzard's layout code reads that field, which taints its execution. The field is
removed; H3z0UI orders custom icons itself.

### Removed - Battle Res Counter
It only ever showed "?" (the charges API returns nothing for it in Midnight). The module, its saved-variable defaults
and its options section are gone.

## 0.21

### Changed - Options menu performance (fewer spikes / hitches)
A pure optimization pass on the settings window (`/h3z0ui`). Nothing looks different and no setting changed.
- **Switching pages is lighter.** Every page switch used to re-run the "refresh" script of every frame on the page,
  including hidden ones (closed dropdown menus, sub-tabs you were not looking at, leftover buttons), and built a
  temporary table for every frame on the way. It now only walks what is actually visible. Hidden parts still refresh
  themselves the moment they are shown.
- **Dropdowns no longer leak frames.** Dropdown lists with a scroll bar (fonts, textures, sounds, ...) created a brand
  new button for every entry each time you opened them and only hid the old ones. After a few opens that was hundreds
  of dead frames, which made opening a list - and every page switch after it - slower and slower. The buttons are now
  created once and reused.
- **Search no longer freezes on first click.** The first click on "Search" used to build every page of the menu in one
  go. Now the search index is built quietly in the background, one page at a time, a moment after the menu opens (only
  while the menu is open and you are not in combat). If you click Search before it has finished, the remaining pages
  are built right then, same as before.
- **Sub-tab buttons (General, HUD Visibility, Steam Deck, ...) switch faster.** Clicking one no longer reloads the font
  on every button or repaints the buttons that did not change.
- **Dragging the window's resize corner is smoother.** Updates are limited to about 30 per second, whole pixels only,
  and skipped when the size did not change. Sub-tab buttons and slider bars only re-layout when their width really
  changed.

### Not changed
All settings, pages, saved variables and profiles are untouched. Nothing needs to be reconfigured.

### Files touched
- options/framework.lua (page switch refresh, pooled dropdown buttons, background search index, sub-tab select and
  layout, slider track, resize handle)
- H3z0UI.toc, README.md (version 0.21)

### Not tested yet
Syntax-checked (all addon Lua files load without errors), but not run in the real game client, so the actual
before/after feel could not be measured here. Things to watch: the Search tab results (should be the same as before),
dropdown lists opening and picking a value, and switching General & QoL sub-tabs. If any page looks stale after a
switch or any list is empty, report which page and it will be fixed. The remaining one-time cost is the very first
visit to a big page (for example Cooldown Manager or Custom Trackers), which still builds in one go; that can be
split up in a later version if you still notice it.

---

## 0.20

### Added - Steam Deck setup window
When H3z0 UI detects an exact **1280x800** screen (the Steam Deck), a setup window pops up on login and offers the
one-click Steam Deck setup. It uses the same look as the options menu (logo badge, accent glow) and big buttons that
are easy to hit with the touchscreen or trackpad.
- **Apply Steam Deck Setup**: turns on Handheld Mode with the pixel-perfect UI scale (0.96), action bars always
  visible and the settings window fitted to the screen. Same as the "Apply Steam Deck Preset" button.
- **Not now**: closes it (Esc does the same). It asks again next login.
- **Don't ask again**: never shows the window on login again.
- It tells you whether ConsolePort or WoW's native gamepad support was found. ConsolePort itself is never changed.
- Open it again any time with `/h3z0ui deck setup`, or with the new **Open Setup Window** button on
  General & QoL > Steam Deck.
- It only appears if Handheld Mode is not already on. On other small screens (not exactly 1280x800) the old
  behaviour is unchanged: Handheld Mode switches itself on once, silently.
- Everything you had already set in 0.19 is kept (all saved settings are untouched).

### Files touched
- modules/qol/handheld.lua (setup popup, `Handheld.ApplyPreset()`, login detection)
- options/tabs/qol/handheld.lua (preset button uses the shared function, new "Open Setup Window" button)
- init.lua (`/h3z0ui deck setup`), H3z0UI.toc, README.md (version 0.20)

### Not tested yet
Syntax-checked and run against stubbed WoW functions (the popup is created on a 1280x800 screen and the preset applies
scale 0.96 with bars visible), but not run on a real Steam Deck. If the window looks too big or small on the Deck, or
overlaps anything, send a screenshot and it will be adjusted.

---

## 0.19

### Changed - New options menu design
The settings window (`/h3z0ui`, ESC menu button) has a new look with the addon's identity on it.
- **Branded header**: skull logo badge (tinted with your accent colour, with a thin halo), the **H3Z0 UI** name,
  a version pill (v0.20) and "Created by H3z0". The header has an accent glow behind it and a
  glowing accent line under it that fades out to the right.
- **Social links in the header**: YouTube, Twitch, X and Discord buttons under the name. WoW cannot open a web page,
  so clicking one shows the link already selected in a small box: press Ctrl+C and paste it into your browser
  (the box closes itself after you copy, or with Esc). Hovering shows the full link.
- **HUD corner brackets** in the accent colour on the window corners.
- **Header controls tidied up**: Accent colour, Class colour toggle and Panel Scale are now grouped on the right of the
  header, next to the close button, and are vertically centred.
- **New sidebar**: darker rail with a "SETTINGS" caption, a diamond marker in front of each page, and a glowing
  accent highlight on the active page (the text turns white, with the accent bar and marker). Hovering a page lights
  up its marker.
- **Search / CDM Settings / Edit Mode**: the two action buttons are now outlined accent buttons that light up on
  hover, so they look different from pages. Search stays a normal page at the bottom.
- **Sub-tabs** (General, HUD Visibility, Steam Deck, ...): darker buttons, accent text and an accent underline on the
  selected one.
- Everything follows your accent colour or the Class colour setting, including the live colour preview in the header.
- The window is 30px taller (850 -> 880) to make room for the header. Handheld Mode's "Fit this settings window to the
  screen" still shrinks it to fit a Steam Deck.

### Not changed
All settings, pages, saved variables and profiles are untouched. This is a visual-only update, so nothing needs to be
reconfigured.

### Files touched
- options/framework.lua (header, social links + link popup, sidebar, tab buttons, action buttons, sub-tabs)
- H3z0UI.toc, README.md (version 0.19)

### Not tested yet
The window code was syntax-checked and run against stubbed WoW functions to make sure it builds without errors, but it
has not been looked at in the real game client. If something overlaps, is cut off at a small panel width or the logo
tint looks off, report it with a screenshot and it will be adjusted.

---

## 0.18

### Added - Handheld / Steam Deck Mode
New page: **General & QoL > Steam Deck**. Also toggle with `/h3z0ui deck`.
- **Steam Deck detection**: reads the real screen size (Steam Deck = 1280x800, 16:10) and shows it on the page,
  plus whether WoW's native gamepad support and ConsolePort are loaded.
- **Handheld UI scale**: default is pixel-perfect for the screen (768 / 800 = 0.96 on a Deck). Slider 0.50 - 1.40
  and presets: Compact (0.85), Pixel-perfect, Comfortable (1.15). Your previous UI scale is saved and restored when
  you turn Handheld Mode off.
- **Action bars always visible**: turns off mouseover fade while Handheld Mode is on (a controller has no hover).
  Your old fade setting is restored when it is turned off.
- **Settings window fits the screen**: the 1000x850 options window is shrunk automatically so it fits a 1280x800
  screen (this is not saved over your normal panel scale).
- **Auto-enable**: on the first launch on a small screen (<= 800p) Handheld Mode switches itself on once
  (can be turned off with "Auto-enable on a small screen"). It never switches on by itself on a desktop monitor.
- **"Apply Steam Deck Preset"** button sets everything above in one click.
- **ConsolePort**: Handheld Mode does not modify ConsolePort. It detects it and keeps H3z0 UI's own bars visible
  and sized for the Deck. Set up the ConsolePort bar/bindings inside ConsolePort itself.

### Files touched
- modules/qol/handheld.lua (new), modules/qol/qol.xml
- options/tabs/qol/handheld.lua (new), options/tabs/tabs.xml, options/tabs/core/general.lua
- init.lua (`/h3z0ui deck`), H3z0UI.toc, README.md

### Not tested yet
Written and syntax-checked, and the enable/disable logic was run against stubbed WoW functions, but it has not been
run on a real Steam Deck. If anything overlaps with ConsolePort, report it and it will be adjusted.

---

## 0.17

### Fixed
- **Druid combo points jumping away after you move them** (Secondary Power Bar)
  - Cause: dragging the bar in Edit Mode saved an *absolute* screen position, but the combo bar is
    locked to the Primary bar (or Essential/Utility CDM) and treats the saved offset as a *relative*
    adjustment on top of that locked position - so the two were added together and the bar landed
    far below where you dropped it (your screenshot 1 vs 2).
  - Now the drag converts the position to the correct relative offset, so the bar stays exactly where
    you drop it, and still follows the Primary bar / CDM if those move.
  - After a drop, the bar is re-applied through the normal positioning path immediately.
  - One-time migration: a position you already saved with the old drag (large offset values) is
    converted automatically on first load, so your current placement from screenshot 1 should now
    show up correctly. Small offsets (slider tweaks) are left untouched. If it still looks off,
    just drag it once more in Edit Mode.

- **Character panel stats showing 0 in combat** (Crit / Haste / Mastery / Versatility / Armor / Dodge / etc., and the
  Attributes list going empty)
  - Cause: in Midnight, WoW hides ("secret values") most stats while you are in combat. The panel treated a hidden
    value as "no value" and drew 0 / 0.0%.
  - Now the panel remembers the last values read out of combat and shows those during combat. The cache refreshes
    automatically out of combat (gear change, stat change, leaving combat), even while the panel is closed.
  - Note: in combat the numbers are the last out-of-combat snapshot, so buffs/procs gained mid-fight are not
    reflected until combat ends.

### Added
- **H3z0 skull logo as background of the Character panel and the Inspect panel**
  (same faded watermark style as the options menu). Works with skinning on, and with the
  fallback character background when skinning is off.

### Changed
- **"H3z0 UI" button in the ESC / Game Menu is now at the very bottom** (under "Return to Game"),
  instead of between Macros and Log Out.
- The ESC-menu button is now **ON by default**. It used to be opt-in (default OFF), which is why
  you saw no button in screenshot 3. Existing profiles are switched on once automatically;
  you can still turn it off in Skinning > "Add H3z0 UI Button".
- Version bumped to 0.17 (TOC + README).

### Files touched
- modules/frames/resourcebars.lua
- modules/character/character.lua (stat cache)
- core/utils.lua (new helper Helpers.AttachLogoBackground)
- skinning/frames/character.lua, skinning/frames/inspect.lua, modules/character/character.lua
- skinning/system/gamemenu.lua, core/main.lua, options/tabs/skinning/skinning.lua
- H3z0UI.toc, README.md

---

## Earlier versions (summary)
- 0.11 - Lua error fixes (character.lua secret/tainted value), MorphieBlossom Hover Name integrated
- 0.12 - Options subtab spacing fix, skull logo as options background, Quick Access group-finder panel
- 0.13 - CombatMode integrated
- 0.14 - Bottom info bar
- 0.15 - Renamed to "H3z0 UI", bug/optimization cleanup, Raider.IO overlap fix for Quick Access
