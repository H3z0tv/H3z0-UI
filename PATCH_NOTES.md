# H3z0 UI - Patch Notes

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
