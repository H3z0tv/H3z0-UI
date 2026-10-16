---------------------------------------------------------------------------
-- H3z0 UI Steam Deck layout preset (unit frames)
-- 0.22: re-laid out to match the H3z0 Steam Deck HUD reference (1280x800):
--   * target = wide hostility-coloured bar at the top centre (name left, % right, small portrait right)
--   * player = portrait + slim name/health bar at the top left (portrait sits left of the bar)
--   * primary power bar = slim bar under the character at the bottom centre
--   * focus / target-of-target = small bars next to the target bar, pet = tiny bar under the player portrait
-- Applied by handheld.lua while Handheld / Steam Deck Mode is ON and restored when it is turned OFF.
-- ns.HandheldUnitFrameLayout: h3z0uiUnitFrames settings per unit.
-- ns.HandheldProfileLayout:   top-level profile tables (e.g. powerBar).
-- "a.b" paths address nested tables. Positions are offsets from the screen centre.
--
-- 0.22.5: positions were re-measured from the H3z0 reference screenshot (2560x1440, UI scale 0.85, Handheld Mode on):
--   player bar centre (-670, 419) = portrait 10 units from the left edge and 5 units from the top edge;
--   primary power bar (0, -250), 310 x 8 - unchanged, it already matched.
-- The layout is proportional: handheld.lua scales every size, font and position by (UI height now / reference UI
-- height), so it fills the same share of the screen at ANY Handheld UI scale (0.5 - 1.4) and on any resolution
-- (Deck 1280x800, Ally 1920x1080, Legion Go 2560x1600, docked 4K ...). The reference screen is 16:9 and a Deck is
-- 16:10, so ns.HandheldEdgeAnchors lists the values that hug the left/right screen edge (they keep their scaled
-- distance from that edge instead of from the centre). Everything else is scaled from the screen centre.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- Screen the values below were measured on, in UI units (2560x1440 at UI scale 0.85 = 768 / 0.85 high).
ns.HandheldLayoutRef = { width = 1606.3, height = 903.5 }

-- unit / profile table -> { x = "LEFT"|"RIGHT" } (the side its offsetX is measured from)
ns.HandheldEdgeAnchors = {
    units = {
        player = { x = "LEFT" },
        pet    = { x = "LEFT" },
    },
    profile = {},
}

ns.HandheldUnitFrameLayout = {
    player = {
        ["absorbs.enabled"] = false,
        ["anchorTo"] = "disabled",
        ["auras.showBuffs"] = false,
        ["auras.showDebuffs"] = false,
        ["borderSize"] = 1,
        -- H3z0 UI cast bar stays on (otherwise Blizzard's default cast bar shows);
        -- free position so it can be moved in H3z0 UI Layout Mode
        ["castbar.enabled"] = true,
        ["castbar.anchor"] = "none",
        ["castbar.width"] = 260,
        ["castbar.height"] = 18,
        ["castbar.offsetX"] = 0,
        ["castbar.offsetY"] = -200,
        ["customHealthColor"] = { 0.2, 0.8, 0.2, 1 },
        ["enabled"] = true,
        ["height"] = 14,
        ["nameAnchor"] = "LEFT",
        ["nameFontSize"] = 10,
        ["nameOffsetX"] = 5,
        ["nameOffsetY"] = 0,
        ["offsetX"] = -670,
        ["offsetY"] = 419,
        ["portraitBorderSize"] = 2,
        ["portraitBorderUseClassColor"] = true,
        ["portraitGap"] = 2,
        ["portraitSide"] = "LEFT",
        ["portraitSize"] = 56,
        ["showHealth"] = false,
        ["showName"] = true,
        ["showPortrait"] = true,
        ["showPowerBar"] = false,
        ["showPowerText"] = false,
        ["useClassColor"] = false,
        ["width"] = 130,
    },
    target = {
        ["absorbs.enabled"] = false,
        ["anchorTo"] = "disabled",
        ["auras.buffIconSize"] = 22,
        ["auras.iconSize"] = 22,
        ["auras.showBuffs"] = false,
        ["auras.showDebuffs"] = false,
        ["borderSize"] = 1,
        ["castbar.enabled"] = false,
        ["enabled"] = true,
        ["healthAnchor"] = "RIGHT",
        ["healthDisplayStyle"] = "percent",
        ["healthFontSize"] = 12,
        ["healthOffsetX"] = -6,
        ["healthOffsetY"] = 0,
        ["height"] = 14,
        ["nameAnchor"] = "LEFT",
        ["nameFontSize"] = 12,
        ["nameOffsetX"] = 6,
        ["nameOffsetY"] = 0,
        ["offsetX"] = 0,
        ["offsetY"] = 365,
        ["portraitSide"] = "RIGHT",
        ["portraitSize"] = 24,
        ["showHealth"] = true,
        ["showHealthAbsolute"] = false,
        ["showHealthPercent"] = true,
        ["showName"] = true,
        ["showPortrait"] = true,
        ["showPowerBar"] = false,
        ["useClassColor"] = false,
        ["useHostilityColor"] = true,
        ["width"] = 490,
    },
    focus = {
        ["absorbs.enabled"] = false,
        ["auras.buffIconSize"] = 22,
        ["auras.iconSize"] = 22,
        ["auras.showBuffs"] = false,
        ["auras.showDebuffs"] = false,
        ["borderSize"] = 3,
        ["castbar.enabled"] = false,
        ["enabled"] = true,
        ["height"] = 15,
        ["offsetX"] = -330,
        ["offsetY"] = 335,
        ["showHealth"] = false,
        ["showName"] = false,
        ["showPortrait"] = false,
        ["showPowerBar"] = false,
        ["useClassColor"] = true,
        ["width"] = 110,
    },
    targettarget = {
        ["borderSize"] = 1,
        ["enabled"] = true,
        ["height"] = 15,
        ["offsetX"] = 330,
        ["offsetY"] = 335,
        ["showHealth"] = false,
        ["showName"] = false,
        ["showPowerBar"] = false,
        ["useClassColor"] = false,
        ["width"] = 60,
    },
    pet = {
        ["borderSize"] = 1,
        ["enabled"] = true,
        ["height"] = 8,
        ["offsetX"] = -670,
        ["offsetY"] = 381,
        ["showHealth"] = false,
        ["showName"] = false,
        ["showPowerBar"] = false,
        ["useClassColor"] = false,
        ["width"] = 130,
    },
    boss = {
        ["auras.buffIconSize"] = 22,
        ["auras.iconSize"] = 22,
        ["auras.showBuffs"] = false,
        ["auras.showDebuffs"] = true,
        ["borderSize"] = 1,
        ["castbar.enabled"] = true,
        ["castbar.height"] = 14,
        ["enabled"] = false,
        ["healthAnchor"] = "RIGHT",
        ["healthDisplayStyle"] = "percent",
        ["healthFontSize"] = 12,
        ["healthOffsetX"] = 0,
        ["healthOffsetY"] = 0,
        ["height"] = 40,
        ["nameAnchor"] = "LEFT",
        ["nameFontSize"] = 12,
        ["nameOffsetX"] = 0,
        ["nameOffsetY"] = 0,
        ["offsetX"] = 660.8,
        ["offsetY"] = 250.7,
        ["powerBarHeight"] = 6,
        ["showHealth"] = true,
        ["showHealthAbsolute"] = false,
        ["showHealthPercent"] = true,
        ["showName"] = true,
        ["showPowerBar"] = true,
        ["spacing"] = 40,
        ["useClassColor"] = true,
        ["width"] = 160,
    },
}

-- Top-level profile tables touched while Handheld Mode is on (restored when it is turned off).
-- The primary resource (power) bar becomes the slim bar under the character at the bottom centre.
-- The secondary bar - combo points, runes, holy power - is not touched.
ns.HandheldProfileLayout = {
    powerBar = {
        ["enabled"] = true,
        ["autoAttach"] = false,
        ["lockedToEssential"] = false,
        ["lockedToUtility"] = false,
        ["width"] = 310,
        ["height"] = 8,
        ["offsetX"] = 0,
        ["offsetY"] = -250,
        ["showText"] = false,
        ["showPercent"] = false,
    },
}
