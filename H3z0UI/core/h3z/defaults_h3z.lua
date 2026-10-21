local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI defaults
-- The defaults of the H3z0 UI modules (unit frames, party / raid frames,
-- chat, cast bars, ...). Merged into the core defaults before the profile
-- database is created:
--   * REPLACE keys belong to H3z0 UI modules and use H3z0 UI's defaults
--   * every other key only fills values the core defaults don't have
---------------------------------------------------------------------------

local h3zDefaults = {
    profile = {
        -- Nudge amount for moving frames
        nudgeAmount = 1,

        -- General Settings
        general = {
            uiScale = 0.64,  -- Default UI scale for 1440p+ monitors
            font = "Poppins SemiBold",  -- Default font face
            fontOutline = "OUTLINE",  -- Default font outline: "", "OUTLINE", "THICKOUTLINE"
            texture = "H3z0UI v5",  -- Default bar texture
            darkMode = false,
            darkModeHealthColor = { 0, 0, 0, 1 },
            darkModeBgColor = { 0.592, 0.592, 0.592, 1 },
            darkModeOpacity = 0.7,
            darkModeHealthOpacity = 0.7,
            darkModeBgOpacity = 0.7,
            masterColorNameText = false,
            masterColorToTText = false,
            masterColorPowerText = false,
            masterColorHealthText = false,
            masterColorCastbarText = false,
            defaultUseClassColor = true,
            defaultHealthColor = { 0.2, 0.2, 0.2, 1 },
            hostilityColorHostile = { 0.8, 0.2, 0.2, 1 },
            hostilityColorNeutral = { 1, 1, 0.2, 1 },
            hostilityColorFriendly = { 0.2, 0.8, 0.2, 1 },
            defaultBgColor = { 0, 0, 0, 1 },
            defaultOpacity = 1.0,
            defaultHealthOpacity = 1.0,
            defaultBgOpacity = 1.0,
            applyGlobalFontToBlizzard = true,  -- Apply font to Blizzard UI elements
            autoInsertKey = true,  -- Auto-insert keystone in M+ UI
            skinKeystoneFrame = true,  -- Skin keystone insertion window
            skinGameMenu = false,  -- Skin ESC menu (opt-in)
            addH3z0UIButton = true,   -- Add H3z0UI button to the bottom of the ESC menu (on by default since 0.17)
            gameMenuFontSize = 12,  -- Game menu button font size
            gameMenuDim = true,  -- Dim background when game menu is open
            skinPowerBarAlt = true,  -- Skin encounter/quest power bar (PlayerPowerBarAlt)
            skinOverrideActionBar = false,  -- Skin override/vehicle action bar (opt-in)
            skinObjectiveTracker = false,  -- Skin objective tracker (opt-in)
            objectiveTrackerHeight = 600,  -- Objective tracker max height
            objectiveTrackerModuleFontSize = 12,  -- Module headers (QUESTS, ACHIEVEMENTS, etc.)
            objectiveTrackerTitleFontSize = 10,  -- Quest/achievement titles
            objectiveTrackerTextFontSize = 10,  -- Objective text lines
            hideObjectiveTrackerBorder = false,  -- Hide the class-colored border
            objectiveTrackerModuleColor = { 1.0, 0.82, 0.0, 1.0 },  -- Module header color (Blizzard gold)
            objectiveTrackerTitleColor = { 1.0, 1.0, 1.0, 1.0 },  -- Quest title color (white)
            objectiveTrackerTextColor = { 0.8, 0.8, 0.8, 1.0 },  -- Objective text color (light gray)
            skinInstanceFrames = false,  -- Skin PVE/Dungeon/PVP frames (opt-in)
            skinBgColor = { 0.008, 0.008, 0.008, 1 },  -- Skinning background color (with alpha)
            skinAlerts = true,  -- Skin alert/toast frames
            skinCharacterFrame = true,  -- Skin Character Frame (Character, Reputation, Currency tabs)
            skinInspectFrame = true,  -- Skin Inspect Frame to match Character Frame
            skinLootWindow = true,  -- Skin custom loot window
            skinLootUnderMouse = true,  -- Position loot window at cursor
            skinLootHistory = true,  -- Skin loot history frame
            skinRollFrames = true,  -- Skin loot roll frames
            skinRollSpacing = 6,  -- Spacing between roll frames
            skinUseClassColor = true,  -- Use class color for skin accents
            -- QoL Automation
            sellJunk = true,
            autoRepair = "personal",      -- "off", "personal", "guild"
            autoRoleAccept = true,
            autoAcceptInvites = "all",    -- "off", "all", "friends", "guild", "both"
            autoAcceptQuest = false,
            autoTurnInQuest = false,
            questHoldShift = true,
            fastAutoLoot = true,
            autoSelectGossip = false,  -- Auto-select single gossip options
            autoCombatLog = false,  -- Auto start/stop combat logging in M+ (opt-in)
            autoDeleteConfirm = false, -- Auto-fill DELETE confirmation text (off: touching Blizzard popups can block item upgrades)
            -- Pet Warning (pet-spec classes: Hunter, Warlock, DK, Mage)
            petCombatWarning = true,    -- Show combat warning in instances when pet missing/passive
            petWarningOffsetX = 0,      -- Warning frame X offset from center
            petWarningOffsetY = -200,   -- Warning frame Y offset from center
            -- Consumable Check (disabled by default)
            consumableCheckEnabled = false,       -- Master toggle
            consumableOnReadyCheck = true,        -- Show on ready check
            consumableOnDungeon = false,          -- Show on dungeon entrance
            consumableOnRaid = false,             -- Show on raid entrance
            consumableOnResurrect = false,        -- Show on instanced resurrect
            consumableFood = true,                -- Track food buff
            consumableFlask = true,               -- Track flask buff
            consumableOilMH = true,               -- Track main hand weapon enchant
            consumableOilOH = true,               -- Track off hand weapon enchant
            consumableRune = true,                -- Track augment rune
            consumableHealthstone = true,         -- Track healthstones (warlock in group)
            consumableExpirationWarning = false,  -- Warn when buffs expiring
            consumableExpirationThreshold = 300,  -- Seconds before expiration warning
            consumableAnchorMode = true,          -- Anchor to ready check frame
            consumableIconOffset = 5,             -- Icon offset from anchor
            consumableIconSize = 40,              -- Icon size in pixels
            -- Quick Salvage settings
            quickSalvage = {
                enabled = false,  -- Opt-in, OFF by default
                modifier = "ALT",  -- "ALT", "ALTCTRL", "ALTSHIFT"
            },
            -- M+ Dungeon Teleport
            mplusTeleportEnabled = true,  -- Click-to-teleport on M+ tab icons
            keyTrackerEnabled = true,     -- Show party keys on M+ tab
            keyTrackerFontSize = 9,       -- Font size for key tracker (7-12)
            keyTrackerFont = nil,         -- Font name from LSM (nil = global H3z0UI font "H3z0UI")
            keyTrackerTextColor = {1, 1, 1, 1},  -- RGBA text color for dungeon/player text
            keyTrackerPoint = "TOPRIGHT",         -- Anchor point on KeyTracker frame
            keyTrackerRelPoint = "BOTTOMRIGHT",   -- Relative point on PVEFrame
            keyTrackerOffsetX = 0,                -- X offset from anchor
            keyTrackerOffsetY = 0,                -- Y offset from anchor
            keyTrackerWidth = 170,                -- Frame width in pixels
        },

        -- Alert & Toast Skinning Settings (enabled via general.skinAlerts)
        alerts = {
            enabled = true,
            alertPosition = { point = "TOP", relPoint = "TOP", x = 1.667, y = -293.333 },
            toastPosition = { point = "CENTER", relPoint = "CENTER", x = -5.833, y = 268.333 },
        },

        -- Missing Raid Buffs Display Settings
        raidBuffs = {
            enabled = true,
            showOnlyInGroup = true,
            providerMode = false,
            hideLabelBar = false,  -- Hide the "Missing Buffs" label bar
            iconSize = 32,
            iconSpacing = 4,
            labelFontSize = 12,
            labelTextColor = nil,  -- nil = white, otherwise {r, g, b, a}
            position = nil,
            growDirection = "RIGHT",  -- LEFT, RIGHT, UP, DOWN, CENTER_H, CENTER_V
            iconBorder = {
                show = true,
                width = 1,
                useClassColor = false,
                color = { 0.2, 1.0, 0.6, 1 },  -- Default mint accent
            },
            buffCount = {
                show = true,
                position = "BOTTOM",  -- TOP, BOTTOM, LEFT, RIGHT
                fontSize = 10,
                font = "Poppins SemiBold",  -- Font name from LibSharedMedia
                color = { 1, 1, 1, 1 },  -- White default
                offsetX = 0,
                offsetY = 0,
            },
        },

        -- Custom M+ Timer Settings
        mplusTimer = {
            enabled = false,
            layoutMode = "pro",
            showTimer = true,
            showBorder = true,
            showDeaths = true,
            showAffixes = true,
            showObjectives = true,
            position = { x = -11.667, y = -204.998 },
        },

        -- Character Pane Settings
        character = {
            enabled = true,
            showItemName = true,            -- Show equipment name (line 1)
            showItemLevel = true,           -- Show item level & track (line 2)
            showEnchants = true,            -- Show enchant status (line 3)
            showGems = true,                -- Show gem indicators
            showDurability = false,         -- Show durability bars
            inspectEnabled = true,
            showModelBackground = true,     -- Show background behind model
            -- Inspect-specific overlay settings (separate from character)
            showInspectItemName = true,
            showInspectItemLevel = true,
            showInspectEnchants = true,
            showInspectGems = true,

            -- In-pane customization
            panelScale = 1.0,               -- Panel scale (0.75 - 1.5 multiplier, base 1.30)
            overlayScale = 0.75,            -- Overlay scale for slot info
            backgroundColor = {0, 0, 0, 0.762},  -- Black with transparency
            statsTextSize = 13,             -- Stats text size in pixels (6 - 40)
            statsTextColor = {1, 1, 1, 1},  -- Stats text color (white)
            ilvlTextSize = 8,               -- Item level text size in pixels (8 - 16)
            headerTextSize = 16,            -- Header text size in pixels (10 - 18)
            secondaryStatFormat = "both",   -- Secondary stat format: "percent", "rating", "both"
            compactStats = true,            -- Compact stats mode (reduced spacing)
            headerClassColor = true,        -- Use class color for headers (default on)
            headerColor = {0.204, 0.827, 0.6},  -- Header color (default accent/mint, used when headerClassColor is off)
            enchantTextSize = 10,           -- Enchant text size in pixels (8 - 14) [DEPRECATED - use slotTextSize]
            enchantClassColor = true,       -- Use class color for enchants (default on)
            enchantTextColor = {0.204, 0.827, 0.6},  -- Enchant text color (used when enchantClassColor is off)
            enchantFont = nil,              -- Enchant font (nil = use global font)
            noEnchantTextColor = {1, 0.341, 0.314, 1},  -- "No Enchant" text color (red tint)
            slotTextSize = 12,              -- Unified text size for all 3 slot lines (6 - 40)
            slotPadding = 0,                -- Padding between slot elements
            upgradeTrackColor = {1, 0.816, 0.145, 1},  -- Upgrade track text color (gold)
        },

        -- Loot Window Settings
        loot = {
            enabled = true,           -- Enable custom loot window
            lootUnderMouse = false,   -- Position loot window at cursor
            showTransmogMarker = true, -- Show marker on uncollected appearances
            position = { point = "TOP", relPoint = "TOP", x = 289.166, y = -165.667 },
        },

        -- Loot Roll Frame Settings
        lootRoll = {
            enabled = true,           -- Enable custom roll frames
            growDirection = "DOWN",   -- Roll frame stacking direction (UP/DOWN)
            spacing = 4,              -- Spacing between roll frames
            position = { point = "TOP", relPoint = "TOP", x = -11.667, y = -166 },
        },

        -- Loot History (Results) Settings
        lootResults = {
            enabled = true,           -- Skin GroupLootHistoryFrame
        },

        -- Keybind Overrides (spell/item ID → custom keybind text, shared across viewers)
        keybindOverrides = {},
        keybindOverridesEnabledCDM = true,
        keybindOverridesEnabledTrackers = true,

        -- FPS Settings Backup (stores user's CVars before applying H3z0UI's settings)
        fpsBackup = nil,

        -- H3z0UI New Cooldown Display Manager (NCDM)
        -- Per-row configuration for Essential and Utility viewers
        ncdm = {
            essential = {
                enabled = true,
                layoutDirection = "HORIZONTAL",
                row1 = {
                    iconCount = 8,      -- How many icons in row 1 (0 = disabled)
                    iconSize = 39,      -- Icon size in pixels (width)
                    borderSize = 1,     -- Border thickness around icon (0 to 5)
                    borderColorTable = {0, 0, 0, 1}, -- Border color (RGBA)
                    aspectRatioCrop = 1.0,  -- 1.0 = square, higher = flatter
                    zoom = 0,           -- Icon texture zoom (0 to 0.2)
                    padding = 2,        -- Spacing between icons (-20 to 20)
                    xOffset = 0,        -- Horizontal offset for this row
                    yOffset = 0,        -- Vertical offset for this row (-50 to 50)
                    durationSize = 16,  -- Duration text font size (8 to 24)
                    durationOffsetX = 0, -- Duration text X offset
                    durationOffsetY = 0, -- Duration text Y offset
                    stackSize = 12,     -- Stack count text font size (8 to 24)
                    stackOffsetX = 0,   -- Stack text X offset
                    stackOffsetY = 2,   -- Stack text Y offset
                    durationTextColor = {1, 1, 1, 1}, -- Duration text color (white default)
                    durationAnchor = "CENTER",        -- Duration text anchor point
                    stackTextColor = {1, 1, 1, 1},    -- Stack text color (white default)
                    stackAnchor = "BOTTOMRIGHT",      -- Stack text anchor point
                },
                row2 = {
                    iconCount = 8,
                    iconSize = 39,
                    borderSize = 1,
                    borderColorTable = {0, 0, 0, 1},
                    aspectRatioCrop = 1.0,
                    zoom = 0,
                    padding = 2,
                    xOffset = 0,
                    yOffset = 3,
                    durationSize = 16,
                    durationOffsetX = 0,
                    durationOffsetY = 0,
                    stackSize = 12,
                    stackOffsetX = 0,
                    stackOffsetY = 2,
                    durationTextColor = {1, 1, 1, 1},
                    durationAnchor = "CENTER",
                    stackTextColor = {1, 1, 1, 1},
                    stackAnchor = "BOTTOMRIGHT",
                },
                row3 = {
                    iconCount = 8,      -- 0 = row disabled by default
                    iconSize = 39,
                    borderSize = 1,
                    borderColorTable = {0, 0, 0, 1},
                    aspectRatioCrop = 1.0,
                    zoom = 0,
                    padding = 2,
                    xOffset = 0,
                    yOffset = 0,
                    durationSize = 16,
                    durationOffsetX = 0,
                    durationOffsetY = 0,
                    stackSize = 12,
                    stackOffsetX = 0,
                    stackOffsetY = 2,
                    durationTextColor = {1, 1, 1, 1},
                    durationAnchor = "CENTER",
                    stackTextColor = {1, 1, 1, 1},
                    stackAnchor = "BOTTOMRIGHT",
                },
            },
            utility = {
                enabled = true,
                layoutDirection = "HORIZONTAL",
                row1 = {
                    iconCount = 6,
                    iconSize = 30,
                    borderSize = 1,
                    borderColorTable = {0, 0, 0, 1},
                    aspectRatioCrop = 1.0,
                    zoom = 0,
                    padding = 2,
                    xOffset = 0,
                    yOffset = 0,
                    durationSize = 14,
                    durationOffsetX = 0,
                    durationOffsetY = 0,
                    stackSize = 14,
                    stackOffsetX = 0,
                    stackOffsetY = 0,
                    durationTextColor = {1, 1, 1, 1},
                    durationAnchor = "CENTER",
                    stackTextColor = {1, 1, 1, 1},
                    stackAnchor = "BOTTOMRIGHT",
                },
                row2 = {
                    iconCount = 0,
                    iconSize = 30,
                    borderSize = 1,
                    borderColorTable = {0, 0, 0, 1},
                    aspectRatioCrop = 1.0,
                    zoom = 0,
                    padding = 2,
                    xOffset = 0,
                    yOffset = 8,
                    durationSize = 14,
                    durationOffsetX = 0,
                    durationOffsetY = 0,
                    stackSize = 14,
                    stackOffsetX = 0,
                    stackOffsetY = 0,
                    durationTextColor = {1, 1, 1, 1},
                    durationAnchor = "CENTER",
                    stackTextColor = {1, 1, 1, 1},
                    stackAnchor = "BOTTOMRIGHT",
                },
                row3 = {
                    iconCount = 0,
                    iconSize = 30,
                    borderSize = 1,
                    borderColorTable = {0, 0, 0, 1},
                    aspectRatioCrop = 1.0,
                    zoom = 0,
                    padding = 2,
                    xOffset = 0,
                    yOffset = 4,
                    durationSize = 14,
                    durationOffsetX = 0,
                    durationOffsetY = 0,
                    stackSize = 14,
                    stackOffsetX = 0,
                    stackOffsetY = 0,
                    durationTextColor = {1, 1, 1, 1},
                    durationAnchor = "CENTER",
                    stackTextColor = {1, 1, 1, 1},
                    stackAnchor = "BOTTOMRIGHT",
                },
                anchorBelowEssential = false,
                anchorGap = 0,
            },
            buff = {
                enabled = true,
                iconSize = 32,      -- Icon size in pixels
                borderSize = 1,     -- Border thickness (0 to 8)
                shape = "square",   -- DEPRECATED: use aspectRatioCrop instead
                aspectRatioCrop = 1.0,  -- Aspect ratio (0.5-2.0): <1=taller, 1=square, >1=wider
                growthDirection = "CENTERED_HORIZONTAL",  -- CENTERED_HORIZONTAL, LEFT, or RIGHT
                zoom = 0,           -- Icon texture zoom (0 to 0.2)
                padding = 4,        -- Spacing between icons (-20 to 20)
                durationSize = 14,  -- Duration text font size (8 to 24)
                durationOffsetX = 0,
                durationOffsetY = 8,
                durationAnchor = "TOP",
                stackSize = 14,     -- Stack count text font size (8 to 24)
                stackOffsetX = 0,
                stackOffsetY = -8,
                stackAnchor = "BOTTOM",
            },
            trackedBar = {
                enabled = true,
                hideIcon = false,
                barHeight = 25,
                barWidth = 215,
                texture = "H3z0UI v5",
                useClassColor = true,
                barColor = {0.204, 0.827, 0.6, 1},  -- mint accent fallback
                borderSize = 2,
                bgOpacity = 0.5,
                textSize = 14,
                spacing = 2,
                growUp = true,  -- true = grow upward, false = grow downward
                orientation = "horizontal",
                fillDirection = "UP",
                iconPosition = "top",
                showTextOnVertical = false,
            },
            customBuffs = {
                enabled = true,
                spellIDs = { 1254638 },
            },
        },

        -- CDM Visibility (essentials, utility, buffs, power bars)
        cdmVisibility = {
            showAlways = true,
            showWhenTargetExists = true,
            showInCombat = false,
            showInGroup = false,
            showInInstance = false,
            showOnMouseover = false,
            fadeDuration = 0.2,
            fadeOutAlpha = 0,
            hideWhenMounted = false,
        },

        -- Unitframes Visibility (player, target, focus, pet, tot, boss)
        unitframesVisibility = {
            showAlways = true,
            showWhenTargetExists = false,
            showInCombat = false,
            showInGroup = false,
            showInInstance = false,
            showOnMouseover = false,
            fadeDuration = 0.2,
            fadeOutAlpha = 0,
            alwaysShowCastbars = false,  -- When true, castbars ignore UF visibility
            hideWhenMounted = false,
        },

        -- Custom Trackers Visibility (all custom item/spell bars)
        customTrackersVisibility = {
            showAlways = true,
            showWhenTargetExists = false,
            showInCombat = false,
            showInGroup = false,
            showInInstance = false,
            showOnMouseover = false,
            fadeDuration = 0.2,
            fadeOutAlpha = 0,
            hideWhenMounted = false,
        },

        viewers = {
            EssentialCooldownViewer = {
                enabled          = true,
                iconSize         = 50,
                aspectRatioCrop  = 1.0,
                spacing          = -11,
                zoom             = 0,
                borderSize       = 1,
                borderColor      = { 0, 0, 0, 1 },
                chargeTextAnchor = "BOTTOMRIGHT",
                countTextSize    = 14,
                countTextOffsetX = 0,
                countTextOffsetY = 0,
                durationTextSize = 14,
                rowLimit         = 8,
                -- Row pattern: icons per row (0 = row disabled)
                row1Icons        = 6,
                row2Icons        = 6,
                row3Icons        = 6,
                useRowPattern    = false,  -- false = use rowLimit, true = use row pattern
                rowAlignment     = "CENTER", -- LEFT, CENTER, RIGHT
                -- Keybind display
                showKeybinds      = false,
                keybindTextSize   = 12,
                keybindTextColor  = { 1, 0.82, 0, 1 },  -- Gold/Yellow
                keybindAnchor     = "TOPLEFT",
                keybindOffsetX    = 2,
                keybindOffsetY    = 2,
                -- Rotation Helper overlay (uses C_AssistedCombat)
                showRotationHelper = false,
                rotationHelperColor = { 0, 1, 0.84, 1 },  -- #00FFD6 cyan/mint border
                rotationHelperThickness = 2,  -- Border thickness in pixels
            },
            UtilityCooldownViewer = {
                enabled          = true,
                iconSize         = 42,
                aspectRatioCrop  = 1.0,
                spacing          = -11,
                zoom             = 0.08,
                borderSize       = 1,
                borderColor      = { 0, 0, 0, 1 },
                chargeTextAnchor = "BOTTOMRIGHT",
                countTextSize    = 14,
                countTextOffsetX = 0,
                countTextOffsetY = 0,
                durationTextSize = 14,
                rowLimit         = 0,
                -- Row pattern: icons per row (0 = row disabled)
                row1Icons        = 8,
                row2Icons        = 8,
                useRowPattern    = false,  -- false = use rowLimit, true = use row pattern
                rowAlignment     = "CENTER", -- LEFT, CENTER, RIGHT
                -- Auto-anchor to Essential
                anchorToEssential = false,  -- When true, Utility anchors below Essential's last row
                anchorGap         = 10,     -- Gap between Essential and Utility when anchored
                -- Keybind display
                showKeybinds      = false,
                keybindTextSize   = 12,
                keybindTextColor  = { 1, 0.82, 0, 1 },  -- Gold/Yellow
                keybindAnchor     = "TOPRIGHT",
                keybindOffsetX    = -1,
                keybindOffsetY    = -7,
                -- Rotation Helper overlay (uses C_AssistedCombat)
                showRotationHelper = false,
                rotationHelperColor = { 0, 1, 0.84, 1 },  -- #00FFD6 cyan/mint border
                rotationHelperThickness = 2,  -- Border thickness in pixels
            },
            -- BuffIconCooldownViewer removed - now handled by h3z0ui_buffbar.lua
            -- Settings are at db.profile.ncdm.buff instead
        },

        -- Rotation Assist Icon (standalone icon showing next recommended ability)
        rotationAssistIcon = {
            enabled = false,
            isLocked = true,
            iconSize = 56,
            visibility = "always",  -- "always", "combat", "hostile"
            frameStrata = "MEDIUM",
            -- Border
            showBorder = true,
            borderThickness = 2,
            borderColor = { 0, 0, 0, 1 },
            -- Cooldown
            cooldownSwipeEnabled = true,
            -- Keybind
            showKeybind = true,
            keybindFont = nil,  -- nil = use general.font
            keybindSize = 13,
            keybindColor = { 1, 1, 1, 1 },
            keybindOutline = true,
            keybindAnchor = "BOTTOMRIGHT",
            keybindOffsetX = -2,
            keybindOffsetY = 2,
            -- Position (anchored to CENTER of screen)
            positionX = 0,
            positionY = -180,
        },

        powerBar = {
            enabled           = true,
            autoAttach        = false,
            standaloneMode    = false,
            attachTo          = "EssentialCooldownViewer",
            height            = 8,
            borderSize        = 1,
            offsetY           = -204,      -- Snapped to top of Essential CDM (default position)
            offsetX           = 0,
            width             = 326,       -- Matches Essential CDM width
            useRawPixels      = true,
            texture           = "H3z0UI v5",
            colorMode         = "power",  -- "power" = power type color, "class" = class color
            usePowerColor     = true,     -- Use power type color (customizable in Power Colors section)
            useClassColor     = false,    -- Use class color
            customColor       = { 0.2, 0.6, 1, 1 },  -- Custom power bar color
            showPercent       = true,
            showText          = true,
            textSize          = 16,
            textX             = 1,
            textY             = 3,
            textUseClassColor = false,    -- Use class color for text
            textCustomColor   = { 1, 1, 1, 1 },  -- Custom text color (white default)
            bgColor           = { 0.078, 0.078, 0.078, 1 },
            showTicks         = false,    -- Show tick marks for segmented resources (Holy Power, Chi, etc.)
            tickThickness     = 2,        -- Thickness of tick marks in pixels
            tickColor         = { 0, 0, 0, 1 },  -- Color of tick marks (default black)
            lockedToEssential = false,  -- Auto-resize width when Essential CDM changes
            lockedToUtility   = false,  -- Auto-resize width when Utility CDM changes
            snapGap           = 5,      -- Gap when snapped to CDM
            orientation       = "HORIZONTAL",  -- Bar orientation
        },
        castBar = {
            enabled       = true,
            attachTo      = "EssentialCooldownViewer",
            height        = 24,
            offsetX       = 0,
            offsetY       = -108.5,
            texture       = "H3z0UI",
            color         = { 0.188, 1, 0.988, 1 },
            useClassColor = false,
            textSize      = 16,
            width         = 0,
            bgColor       = { 0.078, 0.078, 0.067, 0.85 },
            showTimeText  = true,
            showIcon      = true,
        },
        targetCastBar = {
            enabled       = true,
            attachTo      = "H3z0UICore_Target",
            height        = 18,
            offsetX       = 0,
            offsetY       = -32,
            texture       = "H3z0UI",
            color         = { 1.0, 0.0, 0.0, 1.0 },
            textSize      = 16,
            width         = 241.2,
            bgColor       = { 0.1, 0.1, 0.1, 1 },
            showTimeText  = true,
            showIcon      = true,
        },
        focusCastBar = {
            enabled       = true,
            attachTo      = "H3z0UICore_Focus",
            height        = 18,
            offsetX       = 0,
            offsetY       = -32,
            texture       = "H3z0UI",
            color         = { 1.0, 0.0, 0.0, 1.0 },
            textSize      = 16,
            width         = 241.2,
            bgColor       = { 0.1, 0.1, 0.1, 1 },
            showTimeText  = true,
            showIcon      = true,
        },
        secondaryPowerBar = {
            enabled       = true,
            autoAttach    = false,
            standaloneMode = false,
            attachTo      = "EssentialCooldownViewer",
            height        = 8,
            borderSize    = 1,
            offsetY       = 0,        -- User adjustment when locked to primary (0 = no offset)
            offsetX       = 0,
            width         = 326,      -- Matches Primary bar width
            useRawPixels  = true,
            texture       = "H3z0UI v5",
            colorMode     = "power",  -- "power" = power type color, "class" = class color
            usePowerColor = true,     -- Use power type color (customizable in Power Colors section)
            useClassColor = false,    -- Use class color
            customColor   = { 1, 0.8, 0.2, 1 },  -- Custom power bar color
            showPercent   = false,
            showText      = false,
            textSize      = 14,
            textX         = 0,
            textY         = 2,
            textUseClassColor = false,    -- Use class color for text
            textCustomColor   = { 1, 1, 1, 1 },  -- Custom text color (white default)
            bgColor       = { 0.078, 0.078, 0.078, 0.83 },
            showTicks     = true,     -- Show tick marks for segmented resources (Holy Power, Chi, etc.)
            tickThickness = 2,        -- Thickness of tick marks in pixels
            tickColor     = { 0, 0, 0, 1 },  -- Color of tick marks (default black)
            lockedToEssential = false,  -- Auto-resize width when Essential CDM changes
            lockedToUtility   = false,  -- Auto-resize width when Utility CDM changes
            lockedToPrimary   = true,   -- Position above + match Primary bar width
            snapGap       = 5,        -- Gap when snapped
            orientation   = "AUTO",   -- Bar orientation
            showFragmentedPowerBarText = false,  -- Show text on fragmented power bars
        },
        -- Power Colors (global, used by both Primary and Secondary power bars)
        powerColors = {
            -- Core Resources
            rage = { 1.00, 0.00, 0.00, 1 },
            energy = { 1.00, 1.00, 0.00, 1 },
            mana = { 0.00, 0.00, 1.00, 1 },
            focus = { 1.00, 0.50, 0.25, 1 },
            runicPower = { 0.00, 0.82, 1.00, 1 },
            fury = { 0.79, 0.26, 0.99, 1 },
            insanity = { 0.40, 0.00, 0.80, 1 },
            maelstrom = { 0.00, 0.50, 1.00, 1 },
            lunarPower = { 0.30, 0.52, 0.90, 1 },

            -- Builder Resources
            holyPower = { 0.95, 0.90, 0.60, 1 },
            chi = { 0.00, 1.00, 0.59, 1 },
            comboPoints = { 1.00, 0.96, 0.41, 1 },
            soulShards = { 0.58, 0.51, 0.79, 1 },
            arcaneCharges = { 0.10, 0.10, 0.98, 1 },
            essence = { 0.20, 0.58, 0.50, 1 },

            -- Specialized Resources
            stagger = { 0.00, 1.00, 0.59, 1 },
            staggerLight = { 0.52, 1.00, 0.52, 1 },     -- Green (0-30% of max health)
            staggerModerate = { 1.00, 0.98, 0.72, 1 },  -- Yellow (30-60% of max health)
            staggerHeavy = { 1.00, 0.42, 0.42, 1 },     -- Red (60%+ of max health)
            useStaggerLevelColors = true,               -- Enable dynamic stagger colors
            soulFragments = { 0.64, 0.19, 0.79, 1 },
            runes = { 0.77, 0.12, 0.23, 1 },
            bloodRunes = { 0.77, 0.12, 0.23, 1 },
            frostRunes = { 0.00, 0.82, 1.00, 1 },
            unholyRunes = { 0.00, 0.80, 0.00, 1 },
        },
        -- Reticle (GCD tracker around cursor)
        reticle = {
            enabled = false,
            -- Reticle
            reticleStyle = "dot",         -- "dot", "cross", "chevron", "diamond"
            reticleSize = 10,             -- Size in pixels (4-20)
            -- Ring
            ringStyle = "standard",       -- "thin", "standard", "thick", "solid"
            ringSize = 40,                -- Ring diameter (20-80)
            -- Colors
            useClassColor = false,        -- Use class color vs custom
            customColor = {1, 1, 1, 1},   -- White default (#ffffff)
            -- Visibility
            inCombatAlpha = 1.0,
            outCombatAlpha = 1.0,
            hideOutOfCombat = false,
            -- Positioning
            offsetX = 0,
            offsetY = 0,
            -- GCD
            gcdEnabled = true,
            gcdFadeRing = 0.35,           -- Fade ring during GCD (0-1)
            gcdReverse = false,           -- Reverse swipe direction
            -- Behavior
            hideOnRightClick = false,
        },
        -- Screen Center Crosshair
        crosshair = {
            enabled = false,         -- Disabled by default
            onlyInCombat = false,    -- Show all the time when enabled
            size = 9,                -- Line length (half-length from center)
            thickness = 3,           -- Line thickness in pixels
            borderSize = 3,          -- Border thickness around lines
            offsetX = 0,             -- X offset from screen center
            offsetY = 0,             -- Y offset from screen center
            r = 0.796,               -- Crosshair color red
            g = 1,                   -- Crosshair color green
            b = 0.780,               -- Crosshair color blue
            a = 1,                   -- Crosshair alpha
            borderR = 0,             -- Border color red
            borderG = 0,             -- Border color green
            borderB = 0,             -- Border color blue
            borderA = 1,             -- Border alpha
            strata = "LOW",          -- Frame strata
            lineColor = { 0.796, 1, 0.780, 1 },
            borderColorTable = { 0, 0, 0, 1 },
            -- Range-based color changes
            changeColorOnRange = false,           -- Master toggle for range checking
            enableMeleeRangeCheck = true,         -- Check melee range (5 yards)
            enableMidRangeCheck = false,          -- Check mid-range (25 yards) for Evokers/Devourers
            outOfRangeColor = { 1, 0.2, 0.2, 1 },  -- Red color when out of range
            midRangeColor = { 1, 0.6, 0.2, 1 },   -- Orange color for 25-yard range (when both checks enabled)
            rangeColorInCombatOnly = false,       -- Only change color in combat
            hideUntilOutOfRange = false,          -- Only show crosshair when in combat AND out of range
        },

        -- Skyriding Vigor Bar
        skyriding = {
            enabled = false,
            width = 250,
            vigorHeight = 20,
            secondWindHeight = 20,
            offsetX = 0,
            offsetY = 135,
            locked = false,
            useClassColorVigor = false,
            barColor = { 0.2, 0.8, 1.0, 1 },              -- 33CCFF
            backgroundColor = { 0.102, 0.102, 0.102, 0.353 }, -- 1A1A1A with lower alpha
            segmentColor = { 0, 0, 0, 1 },                -- 000000
            rechargeColor = { 0.4, 0.9, 1.0, 1 },         -- 66E6FF
            borderSize = 1,
            borderColor = { 0, 0, 0, 1 },
            barTexture = "H3z0UI v4",
            showSegments = true,
            segmentThickness = 1,
            showSpeed = true,
            speedFormat = "PERCENT",
            speedFontSize = 11,
            showVigorText = true,
            vigorTextFormat = "FRACTION",
            vigorFontSize = 11,
            secondWindMode = "MINIBAR",
            secondWindScale = 2.1,
            useClassColorSecondWind = false,
            secondWindColor = { 1.0, 0.8, 0.2, 1 },       -- FFCC33
            secondWindBackgroundColor = { 0.102, 0.102, 0.102, 0.301 }, -- 1A1A1A with lower alpha
            visibility = "FLYING_ONLY",
            fadeDelay = 1,
            fadeDuration = 0.3,
        },

        -- Chat Frame Customization
        chat = {
            enabled = true,
            -- Glass visual effect
            glass = {
                enabled = true,
                bgAlpha = 0.25,          -- Background transparency (0-1.0)
                bgColor = {0, 0, 0},     -- Background color (RGB)
            },
            -- Message fade after inactivity (uses native API)
            fade = {
                enabled = false,         -- Off by default
                delay = 15,              -- Seconds before fade starts
                duration = 0.6,          -- Fade animation duration
            },
            -- Font settings
            font = {
                forceOutline = false,    -- Force font outline
            },
            -- URL detection and copying
            urls = {
                enabled = true,
                color = {0.078, 0.608, 0.992, 1},  -- Clickable URL color (blue)
            },
            -- UI cleanup
            hideButtons = true,          -- Hide social/channel/scroll buttons
            sideButtons = true,          -- H3z0 Friends / Voice / Chat Menu buttons right of the chat
            -- Input box styling
            editBox = {
                enabled = true,          -- Apply glass styling to input box
                bgAlpha = 0.25,          -- Background transparency (0-1.0)
                bgColor = {0, 0, 0},     -- Background color (RGB)
                height = 20,             -- Input box height
                positionTop = false,     -- Position input box above chat tabs
            },
            -- Timestamps
            timestamps = {
                enabled = false,         -- Off by default
                format = "24h",          -- "24h" or "12h"
                color = {0.6, 0.6, 0.6}, -- Gray color
            },
            -- Copy button mode: "always", "hover", "hidden", "disabled"
            copyButtonMode = "always",
            -- Intro message on login
            showIntroMessage = true,
        },

        -- Tooltip Management
        tooltip = {
            enabled = true,                    -- Master toggle for tooltip module
            anchorToCursor = true,             -- Follow cursor vs default anchor
            hideInCombat = true,               -- Suppress tooltips during combat
            classColorName = false,            -- Color player names by class
            skinTooltips = true,               -- Apply H3z0UI theme to tooltips
            bgColor = {0.05, 0.05, 0.05, 1},  -- Custom background color
            bgOpacity = 0.95,                  -- Background opacity (0-1)
            showBorder = true,                 -- Toggle border visibility
            borderThickness = 1,               -- Border thickness (1-10)
            borderColor = {0.2, 1.0, 0.6, 1}, -- Border color (default = mint accent)
            borderUseClassColor = false,       -- Use player class color for border
            borderUseAccentColor = false,      -- Use addon accent color for border
            hideHealthBar = false,             -- Hide health bar on unit tooltips
            showSpellIDs = false,              -- Show spell ID and icon ID on buff/debuff tooltips
            -- Per-Context Visibility (SHOW/HIDE/SHIFT/CTRL/ALT)
            visibility = {
                npcs = "SHOW",                 -- NPCs/players in world
                abilities = "SHOW",            -- Action bar buttons
                items = "SHOW",                -- Bag/bank items
                frames = "SHOW",               -- Unit frame mouseover
                cdm = "SHOW",                  -- CDM views (Essential, Utility, Buff)
                customTrackers = "SHOW",       -- Custom Items/Spells bars
            },
            combatKey = "SHIFT",               -- NONE/SHIFT/CTRL/ALT
            hideHealthBar = true,              -- Hide the health bar on unit tooltips
        },

        -- Quick Access (Group Finder side panel)
        quickAccess = {
            enabled = true,
            side = "AUTO",            -- AUTO / LEFT / RIGHT / BELOW the Group Finder window
            offsetX = 0,
            offsetY = 0,
            locked = false,
            scale = 1.0,
            showFilters = true,
            rememberFilters = true,
            moveTooltip = true,
            infoInPanel = true,
            filters = {
                dungeons = {},
                leaderScore = 0,
                dungeonScore = 0,
                roleAvailable = false,
                hasTank = false,
                hasHealer = false,
            },
        },

        -- Party Frames (H3z0 UI own party frames: portrait ring, name, health/power, auras)
        partyFrames = {
            enabled = true,
            style = "classic",         -- "classic" | "v2" (bars start at the portrait, round end)
            hideBlizzard = true,       -- hide Blizzard's party frames while these are on
            showPlayer = false,        -- also show yourself in the list
            scale = 1.0,
            spacing = 10,
            growUp = false,
            portraitSize = 46,
            barWidth = 96,
            healthHeight = 12,
            powerHeight = 5,
            fontSize = 10,
            classColorName = true,
            classColorHealth = false,
            classColorRing = true,
            showPower = true,
            showRole = true,
            showLevel = false,
            showLeader = true,
            rangeFade = true,
            showAuras = true,
            showBuffs = true,
            showDebuffs = true,
            auraSize = 20,
            auraMax = 6,
        },

        -- Raid Frames (0.24.5: H3z0 UI own raid frames, one column per group, pets on the right)
        raidFrames = {
            enabled = true,
            hideBlizzard = true,       -- hide Blizzard's raid frames while these are on
            width = 150,
            height = 52,
            spacing = 4,               -- between members of a group
            groupSpacing = 6,          -- between the group columns
            maxGroups = 8,
            scale = 1.0,
            fontSize = 12,
            showGroupNumbers = true,
            classColorName = true,
            classColorHealth = true,
            showLevel = true,
            showRole = true,
            powerFor = "role",         -- "role" (tanks + healers) | "all" | "none"
            powerHeight = 4,
            showPets = true,
            petWidth = 110,
            petHeight = 26,
            rangeFade = true,
        },

        -- Hover Name
        hoverName = {
            enabled = true,
            -- Display
            cursorAnchor = "TOP",              -- TOP/BOTTOM/LEFT/RIGHT/TOPLEFT/TOPRIGHT/BOTTOMLEFT/BOTTOMRIGHT
            offsetVertical = 18,
            aimGap = 28,                       -- extra gap from the cursor while mouselooking
            offsetHorizontal = 0,
            fontSize = 12,
            fontType = "Poppins SemiBold",
            fontOutline = "OUTLINE",          -- NONE/OUTLINE/THICKOUTLINE/MONOCHROMEOUTLINE
            bgEnabled = false,
            bgColor = {0, 0, 0, 1},
            bgAlpha = 50,                      -- 0-100
            bgPadding = 2,
            -- Player
            playerClassColor = true,
            playerShowLevel = true,
            playerLevelColor = true,
            playerShowTarget = true,
            playerShowStatus = true,
            playerShowGuildName = false,
            playerShowGuildRank = false,
            playerShowRace = false,
            playerShowFaction = false,
            -- NPC
            npcColorState = true,
            npcShowLevel = true,
            npcLevelColor = true,
            npcShowTarget = true,
            npcShowClassification = true,
            npcShowFaction = false,
            npcShowCreatureType = false,
            npcShowCombat = true,
            -- Quests / Objectives
            questShow = true,
            questShowCompleted = true,
            questFontSize = 9,
            -- Mythic+ Enemy Forces
            mplusShowForces = true,
            mplusContributionFormat = "PERCENT", -- PERCENT/NUMBER/BOTH
            mplusShowProgress = false,
            mplusProgressFormat = "PERCENT",
            mplusFontSize = 12,
            mplusDisplayRight = false,
        },

        -- H3z0UI Action Bars - Button Skinning and Fade System
        actionBars = {
            enabled = true,
            -- Global settings (apply to all bars)
            global = {
                skinEnabled = true,         -- Apply button skinning
                iconSize = 36,              -- Base icon size (36x36)
                iconZoom = 0.05,            -- Icon texture crop (0.05-0.15)
                showBackdrop = true,        -- Show backdrop behind icons
                backdropAlpha = 0.8,        -- Backdrop opacity (0-1)
                showGloss = true,           -- Show gloss/shine overlay
                glossAlpha = 0.6,           -- Gloss opacity (0-1)
                showBorders = true,         -- Show button borders
                showKeybinds = true,        -- Show hotkey text
                showMacroNames = false,     -- Show macro name text
                showCounts = true,          -- Show stack/charge count
                hideEmptyKeybinds = false,  -- Hide placeholder keybinds
                keybindFontSize = 12,       -- Keybind text size
                keybindColor = {1, 1, 1, 1},-- Keybind text color
                keybindAnchor = "TOPRIGHT", -- Keybind text anchor point
                keybindOffsetX = -1,        -- Keybind text X offset
                keybindOffsetY = -7,        -- Keybind text Y offset
                macroNameFontSize = 10,     -- Macro name text size
                macroNameColor = {1, 1, 1, 1}, -- Macro name text color
                macroNameAnchor = "BOTTOM", -- Macro name text anchor point
                macroNameOffsetX = 0,       -- Macro name text X offset
                macroNameOffsetY = 0,       -- Macro name text Y offset
                countFontSize = 12,         -- Count text size
                countColor = {1, 1, 1, 1},  -- Count text color
                countAnchor = "BOTTOMRIGHT", -- Stack count text anchor point
                countOffsetX = -2,          -- Stack count text X offset
                countOffsetY = 1,           -- Stack count text Y offset
                -- Bar Layout settings
                barScale = 1.0,             -- Global scale multiplier (0.5 - 2.0)
                hideEmptySlots = false,     -- Hide buttons with no ability assigned
                lockButtons = false,        -- Prevent dragging abilities off buttons
                -- Range indicator settings
                rangeIndicator = false,     -- Tint out-of-range buttons
                rangeColor = {0.8, 0.1, 0.1, 1}, -- Red tint color
                -- Usability indicator settings
                usabilityIndicator = false,     -- Dim unusable buttons
                usabilityDesaturate = false,    -- Use desaturation (grey) for unusable
                usabilityColor = {0.4, 0.4, 0.4, 1},  -- Fallback color if not desaturating
                manaColor = {0.5, 0.5, 1.0, 1}, -- Out of mana color (blue tint)
                fastUsabilityUpdates = false, -- 5x faster range/usability checks (50ms vs 250ms)
            },
            -- Mouseover fade settings
            fade = {
                enabled = true,             -- Master toggle for mouseover fade
                fadeInDuration = 0.2,       -- Fade in speed (seconds)
                fadeOutDuration = 0.3,      -- Fade out speed (seconds)
                fadeOutAlpha = 0.0,         -- Alpha when faded out (0-1)
                fadeOutDelay = 0.5,         -- Delay before fading out (seconds)
                alwaysShowInCombat = false, -- Force full opacity during combat
                linkBars1to8 = false,       -- Link all action bars 1-8 for mouseover
            },
            -- Per-bar settings (nil = use global, value = override)
            -- alwaysShow = true means bar stays visible even when mouseover hide is enabled
            bars = {
                bar1 = {
                    enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false,
                    hidePageArrow = true,
                    -- Style overrides (nil = use global)
                    overrideEnabled = false,
                    iconZoom = 0.05, showBackdrop = nil, backdropAlpha = 0,
                    showGloss = nil, glossAlpha = 0,
                    showKeybinds = nil, hideEmptyKeybinds = nil, keybindFontSize = 8,
                    keybindColor = nil, keybindAnchor = nil, keybindOffsetX = -20, keybindOffsetY = -20,
                    showMacroNames = nil, macroNameFontSize = 8, macroNameColor = nil,
                    macroNameAnchor = nil, macroNameOffsetX = -20, macroNameOffsetY = -20,
                    showCounts = nil, countFontSize = 8, countColor = nil,
                    countAnchor = nil, countOffsetX = -20, countOffsetY = -20,
                },
                bar2 = {
                    enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false,
                    overrideEnabled = false,
                    iconZoom = 0.05, showBackdrop = nil, backdropAlpha = 0,
                    showGloss = nil, glossAlpha = 0,
                    showKeybinds = nil, hideEmptyKeybinds = nil, keybindFontSize = 8,
                    keybindColor = nil, keybindAnchor = nil, keybindOffsetX = -20, keybindOffsetY = -20,
                    showMacroNames = nil, macroNameFontSize = 8, macroNameColor = nil,
                    macroNameAnchor = nil, macroNameOffsetX = -20, macroNameOffsetY = -20,
                    showCounts = nil, countFontSize = 8, countColor = nil,
                    countAnchor = nil, countOffsetX = -20, countOffsetY = -20,
                },
                bar3 = {
                    enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false,
                    overrideEnabled = false,
                    iconZoom = 0.05, showBackdrop = nil, backdropAlpha = 0,
                    showGloss = nil, glossAlpha = 0,
                    showKeybinds = nil, hideEmptyKeybinds = nil, keybindFontSize = 8,
                    keybindColor = nil, keybindAnchor = nil, keybindOffsetX = -20, keybindOffsetY = -20,
                    showMacroNames = nil, macroNameFontSize = 8, macroNameColor = nil,
                    macroNameAnchor = nil, macroNameOffsetX = -20, macroNameOffsetY = -20,
                    showCounts = nil, countFontSize = 8, countColor = nil,
                    countAnchor = nil, countOffsetX = -20, countOffsetY = -20,
                },
                bar4 = {
                    enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false,
                    overrideEnabled = false,
                    iconZoom = 0.05, showBackdrop = nil, backdropAlpha = 0,
                    showGloss = nil, glossAlpha = 0,
                    showKeybinds = nil, hideEmptyKeybinds = nil, keybindFontSize = 8,
                    keybindColor = nil, keybindAnchor = nil, keybindOffsetX = -20, keybindOffsetY = -20,
                    showMacroNames = nil, macroNameFontSize = 8, macroNameColor = nil,
                    macroNameAnchor = nil, macroNameOffsetX = -20, macroNameOffsetY = -20,
                    showCounts = nil, countFontSize = 8, countColor = nil,
                    countAnchor = nil, countOffsetX = -20, countOffsetY = -20,
                },
                bar5 = {
                    enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false,
                    overrideEnabled = false,
                    iconZoom = 0.05, showBackdrop = nil, backdropAlpha = 0,
                    showGloss = nil, glossAlpha = 0,
                    showKeybinds = nil, hideEmptyKeybinds = nil, keybindFontSize = 8,
                    keybindColor = nil, keybindAnchor = nil, keybindOffsetX = -20, keybindOffsetY = -20,
                    showMacroNames = nil, macroNameFontSize = 8, macroNameColor = nil,
                    macroNameAnchor = nil, macroNameOffsetX = -20, macroNameOffsetY = -20,
                    showCounts = nil, countFontSize = 8, countColor = nil,
                    countAnchor = nil, countOffsetX = -20, countOffsetY = -20,
                },
                bar6 = {
                    enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false,
                    overrideEnabled = false,
                    iconZoom = 0.05, showBackdrop = nil, backdropAlpha = 0,
                    showGloss = nil, glossAlpha = 0,
                    showKeybinds = nil, hideEmptyKeybinds = nil, keybindFontSize = 8,
                    keybindColor = nil, keybindAnchor = nil, keybindOffsetX = -20, keybindOffsetY = -20,
                    showMacroNames = nil, macroNameFontSize = 8, macroNameColor = nil,
                    macroNameAnchor = nil, macroNameOffsetX = -20, macroNameOffsetY = -20,
                    showCounts = nil, countFontSize = 8, countColor = nil,
                    countAnchor = nil, countOffsetX = -20, countOffsetY = -20,
                },
                bar7 = {
                    enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false,
                    overrideEnabled = false,
                    iconZoom = 0.05, showBackdrop = nil, backdropAlpha = 0,
                    showGloss = nil, glossAlpha = 0,
                    showKeybinds = nil, hideEmptyKeybinds = nil, keybindFontSize = 8,
                    keybindColor = nil, keybindAnchor = nil, keybindOffsetX = -20, keybindOffsetY = -20,
                    showMacroNames = nil, macroNameFontSize = 8, macroNameColor = nil,
                    macroNameAnchor = nil, macroNameOffsetX = -20, macroNameOffsetY = -20,
                    showCounts = nil, countFontSize = 8, countColor = nil,
                    countAnchor = nil, countOffsetX = -20, countOffsetY = -20,
                },
                bar8 = {
                    enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false,
                    overrideEnabled = false,
                    iconZoom = 0.05, showBackdrop = nil, backdropAlpha = 0,
                    showGloss = nil, glossAlpha = 0,
                    showKeybinds = nil, hideEmptyKeybinds = nil, keybindFontSize = 8,
                    keybindColor = nil, keybindAnchor = nil, keybindOffsetX = -20, keybindOffsetY = -20,
                    showMacroNames = nil, macroNameFontSize = 8, macroNameColor = nil,
                    macroNameAnchor = nil, macroNameOffsetX = -20, macroNameOffsetY = -20,
                    showCounts = nil, countFontSize = 8, countColor = nil,
                    countAnchor = nil, countOffsetX = -20, countOffsetY = -20,
                },
                -- Pet/Stance/Microbar/Bags/Extra do NOT have style overrides
                pet = { enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false },
                stance = { enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false },
                microbar = { enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false },
                bags = { enabled = true, fadeEnabled = nil, fadeOutAlpha = nil, alwaysShow = false },
                -- Extra Action Button (boss encounters, quests)
                extraActionButton = {
                    enabled = true,
                    fadeEnabled = nil,
                    fadeOutAlpha = nil,
                    alwaysShow = true,
                    scale = 1.0,
                    offsetX = 0,
                    offsetY = 0,
                    position = { point = "CENTER", relPoint = "CENTER", x = -120.833, y = -25.833 },
                    hideArtwork = false,
                },
                -- Zone Ability Button (garrison, covenant, zone powers)
                zoneAbility = {
                    enabled = true,
                    fadeEnabled = nil,
                    fadeOutAlpha = nil,
                    alwaysShow = true,
                    scale = 1.0,
                    offsetX = 0,
                    offsetY = 0,
                    position = { point = "CENTER", relPoint = "CENTER", x = 150, y = -27.5 },
                    hideArtwork = false,
                },
            },
        },

        -- H3z0UI Unit Frames (New Implementation)
        h3z0uiUnitFrames = {
            enabled = true,
            -- General settings (applies to all frames)
            general = {
                darkMode = false,                         -- Instant dark mode toggle (disabled by default)
                darkModeHealthColor = { 0.15, 0.15, 0.15, 1 },  -- #262626
                darkModeBgColor = { 0.25, 0.25, 0.25, 1 },      -- #404040
                darkModeOpacity = 1.0,                          -- Frame opacity when dark mode enabled (0.1 to 1.0)
                darkModeHealthOpacity = 1.0,                    -- Health bar opacity when dark mode enabled
                darkModeBgOpacity = 1.0,                        -- Background opacity when dark mode enabled
                -- Default unitframe colors (when dark mode is OFF)
                defaultUseClassColor = true,                    -- Use class color for health bar (default ON)
                defaultHealthColor = { 0.2, 0.2, 0.2, 1 },      -- Default health bar color (when class color OFF)
                defaultBgColor = { 0, 0, 0, 1 },                -- Default background color (pure black)
                defaultOpacity = 1.0,                           -- Default bar opacity
                defaultHealthOpacity = 1.0,                     -- Health bar opacity when dark mode disabled
                defaultBgOpacity = 1.0,                         -- Background opacity when dark mode disabled
                classColorText = false,                   -- LEGACY: Use class color for all unit frame text (kept for migration)
                -- Master text color overrides (new system - takes precedence over per-unit settings)
                masterColorNameText = false,              -- Apply class/reaction color to ALL name text
                masterColorHealthText = false,            -- Apply class/reaction color to ALL health text
                masterColorPowerText = false,             -- Apply class/reaction color to ALL power text
                masterColorCastbarText = false,           -- Apply class/reaction color to ALL castbar text (spell + timer)
                masterColorToTText = false,               -- Apply class/reaction color to ALL inline ToT text
                font = "Poppins SemiBold",
                fontSize = 12,
                fontOutline = "OUTLINE",                  -- NONE, OUTLINE, THICKOUTLINE
                showTooltips = true,                      -- Show tooltips on unit frame mouseover
                smootherAnimation = false,                -- Uncap 60 FPS throttle for smoother castbar animation
                -- Hostility colors (for NPC unit frames)
                hostilityColorHostile = { 0.8, 0.2, 0.2, 1 },   -- Red (enemies)
                hostilityColorNeutral = { 1, 1, 0.2, 1 },       -- Yellow (neutral NPCs)
                hostilityColorFriendly = { 0.2, 0.8, 0.2, 1 },  -- Green (friendly NPCs)
            },
            -- Player frame settings
            player = {
                enabled = true,
                borderSize = 1,                     -- Frame border thickness (0-5)
                width = 240,
                height = 40,
                offsetX = -290,
                offsetY = -219,
                -- Anchor to frame (disabled, essential, utility, primary, secondary)
                anchorTo = "disabled",
                anchorGap = 10,
                anchorYOffset = 0,
                texture = "H3z0UI v5",
                useClassColor = true,
                customHealthColor = { 0.2, 0.6, 0.2, 1 },
                -- Portrait
                showPortrait = false,
                portraitSide = "LEFT",
                portraitSize = 40,
                portraitBorderSize = 1,
                portraitBorderUseClassColor = false,
                portraitBorderColor = { 0, 0, 0, 1 },
                portraitGap = 0,
                -- Name text
                showName = true,
                nameTextUseClassColor = false,
                nameTextColor = { 1, 1, 1, 1 },
                nameFontSize = 16,
                nameAnchor = "LEFT",
                nameOffsetX = 12,
                nameOffsetY = 0,
                maxNameLength = 0,              -- 0 = no limit, otherwise truncate to N characters
                -- Health text
                showHealth = true,
                showHealthPercent = true,
                showHealthAbsolute = true,
                healthDisplayStyle = "both",    -- "percent", "absolute", "both", "both_reverse"
                healthDivider = " | ",          -- " | ", " - ", " / "
                healthFontSize = 16,
                healthAnchor = "RIGHT",
                healthOffsetX = -12,
                healthOffsetY = 0,
                healthTextUseClassColor = false, -- Independent from name class color
                healthTextColor = { 1, 1, 1, 1 }, -- Custom health text color
                -- Power text
                showPowerText = false,
                powerTextFormat = "percent",    -- "percent", "current", "both"
                powerTextUsePowerColor = true,  -- Use power type color (mana blue, rage red, etc.)
                powerTextUseClassColor = false,
                powerTextColor = { 1, 1, 1, 1 },
                powerTextFontSize = 12,
                powerTextAnchor = "BOTTOMRIGHT",
                powerTextOffsetX = -9,
                powerTextOffsetY = 4,
                -- Power bar
                showPowerBar = false,
                powerBarHeight = 4,
                powerBarBorder = true,
                powerBarUsePowerColor = true,
                powerBarColor = { 0, 0.5, 1, 1 },  -- Custom power bar color
                -- Absorbs
                absorbs = {
                    enabled = false,
                    color = { 1, 1, 1, 1 },
                    opacity = 0.3,
                    texture = "H3z0UI Stripes",
                },
                -- Castbar
                castbar = {
                    enabled = true,
                    showIcon = true,
                    width = 333,
                    height = 25,
                    offsetX = 0,
                    offsetY = -35,
                    widthAdjustment = 0,
                    fontSize = 14,
                    color = {0.404, 1, 0.984, 1},  -- Cyan color from your profile
                    anchor = "none",
                    texture = "H3z0UI v5",
                    bgColor = {0.149, 0.149, 0.149, 1},
                    borderSize = 1,
                    useClassColor = false,
                    highlightInterruptible = false,
                    interruptibleColor = {0.2, 0.8, 0.2, 1},
                    maxLength = 0,
                },
                -- Auras (buffs/debuffs)
                auras = {
                    showBuffs = false,
                    showDebuffs = false,
                    -- Debuff settings
                    iconSize = 22,
                    debuffAnchor = "TOPLEFT",
                    debuffGrow = "RIGHT",
                    debuffMaxIcons = 4,
                    debuffOffsetX = 0,
                    debuffOffsetY = 0,
                    -- Buff settings
                    buffIconSize = 22,
                    buffAnchor = "BOTTOMLEFT",
                    buffGrow = "RIGHT",
                    buffMaxIcons = 4,
                    buffOffsetX = 0,
                    buffOffsetY = 0,
                    -- Duration text
                    iconSpacing = 2,
                    buffSpacing = 2,
                    debuffSpacing = 2,
                    durationColor = {1, 1, 1, 1},
                    showDuration = false,
                    durationSize = 12,
                    durationAnchor = "CENTER",
                    durationOffsetX = 0,
                    durationOffsetY = 0,
                    -- Stack text
                    stackColor = {1, 1, 1, 1},
                    showStack = true,
                    stackSize = 10,
                    stackAnchor = "BOTTOMRIGHT",
                    stackOffsetX = -1,
                    stackOffsetY = 1,
                    -- Buff duration/stack
                    buffDuration = { show = true, fontSize = 12, anchor = "CENTER", offsetX = 0, offsetY = 0, color = {1, 1, 1, 1} },
                    buffStack = { show = true, fontSize = 10, anchor = "BOTTOMRIGHT", offsetX = -1, offsetY = 1, color = {1, 1, 1, 1} },
                    buffShowStack = true,
                    buffStackSize = 10,
                    buffStackAnchor = "BOTTOMRIGHT",
                    buffStackOffsetX = -1,
                    buffStackOffsetY = 1,
                    buffStackColor = {1, 1, 1, 1},
                    -- Debuff duration/stack
                    debuffDuration = { show = false, fontSize = 10, anchor = "CENTER", offsetX = 0, offsetY = 0, color = {1, 1, 1, 1} },
                    debuffStack = { show = true, fontSize = 10, anchor = "BOTTOMRIGHT", offsetX = -1, offsetY = 1, color = {1, 1, 1, 1} },
                    debuffShowStack = true,
                    debuffStackSize = 10,
                    debuffStackAnchor = "BOTTOMRIGHT",
                    debuffStackOffsetX = -1,
                    debuffStackOffsetY = 1,
                    debuffStackColor = {1, 1, 1, 1},
                },
                -- Status indicators (player only)
                indicators = {
                    rested = {
                        enabled = false,      -- Disabled by default
                        size = 16,
                        anchor = "TOPLEFT",
                        offsetX = -2,
                        offsetY = 2,
                    },
                    combat = {
                        enabled = false,      -- Disabled by default
                        size = 16,
                        anchor = "TOPRIGHT",
                        offsetX = -2,
                        offsetY = 2,
                    },
                    stance = {
                        enabled = false,      -- Disabled by default (opt-in)
                        fontSize = 12,
                        anchor = "BOTTOM",
                        offsetX = 0,
                        offsetY = -2,
                        useClassColor = true,
                        customColor = { 1, 1, 1, 1 },
                        showIcon = false,
                        iconSize = 14,
                        iconOffsetX = -2,
                    },
                },
                -- Target marker (raid icons like skull, cross, etc.)
                targetMarker = {
                    enabled = false,    -- Disabled by default for player (rarely marked)
                    size = 20,
                    anchor = "TOP",
                    xOffset = 0,
                    yOffset = 8,
                },
                -- Leader/Assistant icon (crown for leader, flag for assistant)
                leaderIcon = {
                    enabled = false,
                    size = 16,
                    anchor = "TOPLEFT",
                    xOffset = -8,
                    yOffset = 8,
                },
            },
            -- Target frame settings
            target = {
                enabled = true,
                borderSize = 1,                     -- Frame border thickness (0-5)
                width = 240,
                height = 40,
                offsetX = 290,
                offsetY = -219,
                -- Anchor to frame (disabled, essential, utility, primary, secondary)
                anchorTo = "disabled",
                anchorGap = 10,
                anchorYOffset = 0,
                texture = "H3z0UI v5 Inverse",
                useClassColor = true,
                useHostilityColor = true,  -- Use red/yellow/green based on unit hostility
                customHealthColor = { 0.2, 0.6, 0.2, 1 },
                -- Portrait
                showPortrait = false,
                portraitSide = "RIGHT",
                portraitSize = 40,
                portraitBorderSize = 1,
                portraitBorderUseClassColor = false,
                portraitBorderColor = { 0, 0, 0, 1 },
                portraitGap = 0,
                -- Name text
                showName = true,
                nameTextUseClassColor = false,
                nameTextColor = { 1, 1, 1, 1 },
                nameFontSize = 16,
                nameAnchor = "RIGHT",
                nameOffsetX = -9,
                nameOffsetY = 0,
                maxNameLength = 10,              -- 0 = no limit, otherwise truncate to N characters
                -- Inline Target of Target (shows ">> ToT Name" after target name)
                showInlineToT = false,
                totSeparator = " >> ",
                totUseClassColor = true,
                totDividerUseClassColor = false,    -- Color divider by class/reaction
                totDividerColor = {1, 1, 1, 1},     -- Custom divider color (white default)
                totNameCharLimit = 0,               -- 0 = no limit, otherwise limit ToT name length
                -- Health text
                showHealth = true,
                showHealthPercent = true,
                showHealthAbsolute = true,
                healthDisplayStyle = "both",    -- "percent", "absolute", "both", "both_reverse"
                healthDivider = " | ",          -- " | ", " - ", " / "
                healthFontSize = 16,
                healthAnchor = "LEFT",
                healthOffsetX = 9,
                healthOffsetY = 0,
                healthTextUseClassColor = false, -- Independent from name class color
                healthTextColor = { 1, 1, 1, 1 }, -- Custom health text color
                -- Power text
                showPowerText = false,
                powerTextFormat = "percent",    -- "percent", "current", "both"
                powerTextUsePowerColor = false,  -- Use power type color (mana blue, rage red, etc.)
                powerTextUseClassColor = false,
                powerTextColor = { 1, 1, 1, 1 },
                powerTextFontSize = 14,
                powerTextAnchor = "BOTTOMRIGHT",
                powerTextOffsetX = -2,
                powerTextOffsetY = 2,
                -- Power bar
                showPowerBar = false,
                powerBarHeight = 4,
                powerBarBorder = true,
                powerBarUsePowerColor = true,
                powerBarColor = { 0, 0.5, 1, 1 },  -- Custom power bar color
                -- Absorbs
                absorbs = {
                    enabled = true,
                    color = { 1, 1, 1, 1 },
                    opacity = 0.3,
                    texture = "H3z0UI Stripes",
                },
                -- Castbar
                castbar = {
                    enabled = true,
                    showIcon = true,
                    width = 245,
                    height = 25,
                    offsetX = 0,
                    offsetY = 0,
                    widthAdjustment = 0,
                    fontSize = 14,
                    color = {0.2, 0.6, 1, 1},
                    anchor = "unitframe",
                    texture = "H3z0UI v5",
                    bgColor = {0.149, 0.149, 0.149, 1},
                    borderSize = 1,
                    highlightInterruptible = true,
                    interruptibleColor = {0.2, 0.8, 0.2, 1},
                    maxLength = 12,
                },
                -- Auras (buffs/debuffs)
                auras = {
                    showBuffs = false,
                    showDebuffs = false,
                    -- Debuff settings
                    iconSize = 26,
                    debuffAnchor = "TOPLEFT",
                    debuffGrow = "RIGHT",
                    debuffMaxIcons = 4,
                    debuffOffsetX = 0,
                    debuffOffsetY = 0,
                    -- Buff settings
                    buffIconSize = 18,
                    buffAnchor = "BOTTOMLEFT",
                    buffGrow = "RIGHT",
                    buffMaxIcons = 4,
                    buffOffsetX = 0,
                    buffOffsetY = 0,
                    -- Duration text
                    iconSpacing = 2,
                    buffSpacing = 2,
                    debuffSpacing = 2,
                    durationColor = {1, 1, 1, 1},
                    showDuration = false,
                    durationSize = 12,
                    durationAnchor = "CENTER",
                    durationOffsetX = 0,
                    durationOffsetY = 0,
                    -- Stack text
                    stackColor = {1, 1, 1, 1},
                    showStack = true,
                    stackSize = 10,
                    stackAnchor = "BOTTOMRIGHT",
                    stackOffsetX = -1,
                    stackOffsetY = 1,
                    -- Buff duration/stack
                    buffDuration = { show = true, fontSize = 12, anchor = "CENTER", offsetX = 0, offsetY = 0, color = {1, 1, 1, 1} },
                    buffStack = { show = true, fontSize = 10, anchor = "BOTTOMRIGHT", offsetX = -1, offsetY = 1, color = {1, 1, 1, 1} },
                    buffShowStack = true,
                    buffStackSize = 10,
                    buffStackAnchor = "BOTTOMRIGHT",
                    buffStackOffsetX = -1,
                    buffStackOffsetY = 1,
                    buffStackColor = {1, 1, 1, 1},
                    -- Debuff duration/stack
                    debuffDuration = { show = false, fontSize = 10, anchor = "CENTER", offsetX = 0, offsetY = 0, color = {1, 1, 1, 1} },
                    debuffStack = { show = true, fontSize = 10, anchor = "BOTTOMRIGHT", offsetX = -1, offsetY = 1, color = {1, 1, 1, 1} },
                    debuffShowStack = true,
                    debuffStackSize = 10,
                    debuffStackAnchor = "BOTTOMRIGHT",
                    debuffStackOffsetX = -1,
                    debuffStackOffsetY = 1,
                    debuffStackColor = {1, 1, 1, 1},
                },
                -- Target marker (raid icons like skull, cross, etc.)
                targetMarker = {
                    enabled = false,
                    size = 20,
                    anchor = "TOP",
                    xOffset = 0,
                    yOffset = 8,
                },
                -- Leader/Assistant icon (crown for leader, flag for assistant)
                leaderIcon = {
                    enabled = false,
                    size = 16,
                    anchor = "TOPLEFT",
                    xOffset = -8,
                    yOffset = 8,
                },
            },
            -- Target of Target
            targettarget = {
                enabled = false,
                borderSize = 1,                     -- Frame border thickness (0-5)
                width = 160,
                height = 30,
                offsetX = 496,
                offsetY = -214,
                texture = "H3z0UI",
                useClassColor = true,
                useHostilityColor = true,  -- Use red/yellow/green based on unit hostility
                customHealthColor = { 0.2, 0.6, 0.2, 1 },
                -- Name text
                showName = true,
                nameTextUseClassColor = false,
                nameTextColor = { 1, 1, 1, 1 },
                nameFontSize = 14,
                nameAnchor = "LEFT",
                nameOffsetX = 4,
                nameOffsetY = 0,
                maxNameLength = 0,
                -- Health text
                showHealth = true,
                showHealthPercent = true,
                showHealthAbsolute = false,
                healthDisplayStyle = "percent",
                healthDivider = " | ",
                healthFontSize = 14,
                healthAnchor = "RIGHT",
                healthOffsetX = -4,
                healthOffsetY = 0,
                healthTextUseClassColor = false,
                healthTextColor = { 1, 1, 1, 1 },
                -- Power text
                showPowerText = false,
                powerTextFormat = "percent",
                powerTextUsePowerColor = true,
                powerTextUseClassColor = false,
                powerTextColor = { 1, 1, 1, 1 },
                powerTextFontSize = 10,
                powerTextAnchor = "BOTTOMRIGHT",
                powerTextOffsetX = -4,
                powerTextOffsetY = 2,
                -- Power bar
                showPowerBar = false,
                powerBarHeight = 3,
                powerBarBorder = true,
                powerBarUsePowerColor = true,
                powerBarColor = { 0, 0.5, 1, 1 },  -- Custom power bar color
                -- Absorbs
                absorbs = {
                    enabled = true,
                    color = { 1, 1, 1, 1 },
                    opacity = 0.7,
                    texture = "H3z0UI Stripes",
                },
                -- Castbar
                castbar = {
                    enabled = false,
                    showIcon = true,
                    width = 50,
                    height = 12,
                    offsetX = 0,
                    offsetY = -20,
                    widthAdjustment = 0,
                    fontSize = 10,
                    color = {1, 0.7, 0, 1},
                },
                -- Auras (buffs/debuffs)
                auras = {
                    showBuffs = false,
                    showDebuffs = false,
                    -- Debuff settings
                    iconSize = 22,
                    debuffAnchor = "TOPLEFT",
                    debuffGrow = "RIGHT",
                    debuffMaxIcons = 4,
                    debuffOffsetX = 0,
                    debuffOffsetY = 0,
                    -- Buff settings
                    buffIconSize = 22,
                    buffAnchor = "BOTTOMLEFT",
                    buffGrow = "RIGHT",
                    buffMaxIcons = 4,
                    buffOffsetX = 0,
                    buffOffsetY = 0,
                },
                -- Target marker (raid icons like skull, cross, etc.)
                targetMarker = {
                    enabled = false,    -- Disabled by default for ToT (small frame)
                    size = 16,
                    anchor = "TOP",
                    xOffset = 0,
                    yOffset = 6,
                },
            },
            -- Pet frame
            pet = {
                enabled = true,
                borderSize = 1,                     -- Frame border thickness (0-5)
                width = 140,
                height = 25,
                offsetX = -340,
                offsetY = -254,
                texture = "H3z0UI",
                useClassColor = true,
                useHostilityColor = true,
                customHealthColor = { 0.2, 0.6, 0.2, 1 },
                -- Name text
                showName = true,
                nameTextUseClassColor = false,
                nameTextColor = { 1, 1, 1, 1 },
                nameFontSize = 10,
                nameAnchor = "LEFT",
                nameOffsetX = 4,
                nameOffsetY = 0,
                maxNameLength = 0,
                -- Health text
                showHealth = true,
                showHealthPercent = true,
                showHealthAbsolute = false,
                healthDisplayStyle = "percent",
                healthDivider = " | ",
                healthFontSize = 10,
                healthAnchor = "RIGHT",
                healthOffsetX = -4,
                healthOffsetY = 0,
                healthTextUseClassColor = false,
                healthTextColor = { 1, 1, 1, 1 },
                -- Power text
                showPowerText = false,
                powerTextFormat = "percent",
                powerTextUsePowerColor = true,
                powerTextUseClassColor = false,
                powerTextColor = { 1, 1, 1, 1 },
                powerTextFontSize = 10,
                powerTextAnchor = "BOTTOMRIGHT",
                powerTextOffsetX = -4,
                powerTextOffsetY = 2,
                -- Power bar
                showPowerBar = true,
                powerBarHeight = 3,
                powerBarBorder = true,
                powerBarUsePowerColor = true,
                powerBarColor = { 0, 0.5, 1, 1 },  -- Custom power bar color
                -- Absorbs
                absorbs = {
                    enabled = true,
                    color = { 1, 1, 1 },
                    opacity = 0.7,
                    texture = "H3z0UI Stripes",
                },
                -- Auras (buffs/debuffs)
                auras = {
                    showBuffs = false,
                    showDebuffs = false,
                    -- Debuff settings
                    iconSize = 22,
                    debuffAnchor = "TOPLEFT",
                    debuffGrow = "RIGHT",
                    debuffMaxIcons = 4,
                    debuffOffsetX = 0,
                    debuffOffsetY = 0,
                    -- Buff settings
                    buffIconSize = 22,
                    buffAnchor = "BOTTOMLEFT",
                    buffGrow = "RIGHT",
                    buffMaxIcons = 4,
                    buffOffsetX = 0,
                    buffOffsetY = 0,
                },
                -- Target marker (raid icons like skull, cross, etc.)
                targetMarker = {
                    enabled = false,    -- Disabled by default for pet (rarely marked)
                    size = 16,
                    anchor = "TOP",
                    xOffset = 0,
                    yOffset = 6,
                },
                -- Castbar (opt-in for vehicle/RP casts)
                castbar = {
                    enabled = false,  -- Disabled by default (opt-in feature)
                    showIcon = true,
                    width = 140,
                    height = 15,
                    offsetX = 0,
                    offsetY = -20,
                    widthAdjustment = 0,
                    fontSize = 10,
                    color = {0.404, 1, 0.984, 1},
                },
            },
            -- Focus frame
            focus = {
                enabled = false,
                borderSize = 1,                     -- Frame border thickness (0-5)
                width = 160,
                height = 30,
                offsetX = -496,
                offsetY = -214,
                texture = "H3z0UI v5",
                useClassColor = true,
                useHostilityColor = true,  -- Use red/yellow/green based on unit hostility
                customHealthColor = { 0.2, 0.6, 0.2, 1 },
                -- Portrait
                showPortrait = false,
                portraitSide = "RIGHT",
                portraitSize = 30,
                portraitBorderSize = 1,
                portraitBorderUseClassColor = false,
                portraitBorderColor = { 0, 0, 0, 1 },
                portraitGap = 0,
                -- Name text
                showName = true,
                nameTextUseClassColor = false,
                nameTextColor = { 1, 1, 1, 1 },
                nameFontSize = 14,
                nameAnchor = "LEFT",
                nameOffsetX = 4,
                nameOffsetY = 0,
                maxNameLength = 0,
                -- Health text
                showHealth = true,
                showHealthPercent = true,
                showHealthAbsolute = true,
                healthDisplayStyle = "percent",
                healthDivider = " | ",
                healthFontSize = 14,
                healthAnchor = "RIGHT",
                healthOffsetX = -4,
                healthOffsetY = 0,
                healthTextUseClassColor = false,
                healthTextColor = { 1, 1, 1, 1 },
                -- Power text
                showPowerText = false,
                powerTextFormat = "percent",
                powerTextUsePowerColor = true,
                powerTextUseClassColor = false,
                powerTextColor = { 1, 1, 1, 1 },
                powerTextFontSize = 10,
                powerTextAnchor = "BOTTOMRIGHT",
                powerTextOffsetX = -4,
                powerTextOffsetY = 2,
                -- Power bar
                showPowerBar = true,
                powerBarHeight = 3,
                powerBarBorder = true,
                powerBarUsePowerColor = true,
                powerBarColor = { 0, 0.5, 1, 1 },  -- Custom power bar color
                -- Absorbs
                absorbs = {
                    enabled = true,
                    color = { 1, 1, 1, 1 },
                    opacity = 0.7,
                    texture = "H3z0UI Stripes",
                },
                -- Castbar
                castbar = {
                    enabled = true,
                    showIcon = false,
                    width = 160,
                    height = 20,
                    offsetX = 0,
                    offsetY = 0,
                    widthAdjustment = 0,
                    fontSize = 14,
                    color = {0.2, 0.6, 1, 1},
                    anchor = "unitframe",
                },
                -- Auras (buffs/debuffs)
                auras = {
                    showBuffs = false,
                    showDebuffs = false,
                    -- Debuff settings
                    iconSize = 20,
                    debuffAnchor = "TOPLEFT",
                    debuffGrow = "RIGHT",
                    debuffMaxIcons = 16,
                    debuffOffsetX = 0,
                    debuffOffsetY = 2,
                    -- Buff settings
                    buffIconSize = 20,
                    buffAnchor = "BOTTOMLEFT",
                    buffGrow = "RIGHT",
                    buffMaxIcons = 16,
                    buffOffsetX = 0,
                    buffOffsetY = -2,
                },
                -- Target marker (raid icons like skull, cross, etc.)
                targetMarker = {
                    enabled = false,
                    size = 18,
                    anchor = "TOP",
                    xOffset = 0,
                    yOffset = 6,
                },
                -- Leader/Assistant icon (crown for leader, flag for assistant)
                leaderIcon = {
                    enabled = false,
                    size = 16,
                    anchor = "TOPLEFT",
                    xOffset = -8,
                    yOffset = 8,
                },
            },
            -- Boss frames
            boss = {
                enabled = true,
                borderSize = 1,                     -- Frame border thickness (0-5)
                width = 162,
                height = 36,
                offsetX = 974,
                offsetY = 106,
                spacing = 35,           -- Vertical spacing between boss frames
                texture = "H3z0UI v5",
                useClassColor = true,
                useHostilityColor = true,
                customHealthColor = { 0.6, 0.2, 0.2, 1 },
                -- Name text
                showName = true,
                nameTextUseClassColor = false,
                nameTextColor = { 1, 1, 1, 1 },
                nameFontSize = 11,
                nameAnchor = "LEFT",
                nameOffsetX = 4,
                nameOffsetY = 0,
                maxNameLength = 0,
                -- Health text
                showHealth = true,
                healthDisplayStyle = "both",
                healthDivider = " | ",
                healthFontSize = 11,
                healthAnchor = "RIGHT",
                healthOffsetX = -4,
                healthOffsetY = 0,
                healthTextUseClassColor = false,
                healthTextColor = { 1, 1, 1, 1 },
                -- Power text
                showPowerText = false,
                powerTextFormat = "percent",
                powerTextUsePowerColor = true,
                powerTextUseClassColor = false,
                powerTextColor = { 1, 1, 1, 1 },
                powerTextFontSize = 10,
                powerTextAnchor = "BOTTOMRIGHT",
                powerTextOffsetX = -4,
                powerTextOffsetY = 2,
                -- Power bar
                showPowerBar = true,
                powerBarHeight = 3,
                powerBarBorder = true,
                powerBarUsePowerColor = true,
                powerBarColor = { 0, 0.5, 1, 1 },  -- Custom power bar color
                -- Absorbs
                absorbs = {
                    enabled = true,
                    color = { 1, 1, 1 },
                    opacity = 0.7,
                    texture = "H3z0UI Stripes",
                },
                -- Castbar
                castbar = {
                    enabled = true,
                    showIcon = true,
                    width = 162,
                    height = 16,
                    offsetX = 0,
                    offsetY = 0,
                    widthAdjustment = 0,
                    fontSize = 11,
                    color = {1, 0.7, 0, 1},
                    anchor = "unitframe",
                },
                -- Auras (buffs/debuffs)
                auras = {
                    showBuffs = false,
                    showDebuffs = false,
                    -- Debuff settings
                    iconSize = 22,
                    debuffAnchor = "TOPLEFT",
                    debuffGrow = "RIGHT",
                    debuffMaxIcons = 4,
                    debuffOffsetX = 0,
                    debuffOffsetY = 0,
                    -- Buff settings
                    buffIconSize = 22,
                    buffAnchor = "BOTTOMLEFT",
                    buffGrow = "RIGHT",
                    buffMaxIcons = 4,
                    buffOffsetX = 0,
                    buffOffsetY = 0,
                },
                -- Target marker (raid icons like skull, cross, etc.)
                targetMarker = {
                    enabled = false,
                    size = 20,
                    anchor = "TOP",
                    xOffset = 0,
                    yOffset = 8,
                },
            },
        },
        unitFrames = {
            enabled = true,
            General = {
                Font = "Poppins SemiBold",
                FontFlag = "OUTLINE",
                FontShadows = {
                    Color = {0, 0, 0, 0},
                    OffsetX = 0,
                    OffsetY = 0
                },
                ForegroundTexture = "H3z0UI_v5",
                BackgroundTexture = "Solid",
                -- Dark Mode: overrides class colors on unit frame health bars (not resource bars)
                DarkMode = {
                    Enabled = false,
                    ForegroundColor = {0.15, 0.15, 0.15, 1},  -- Very dark for health bar
                    BackgroundColor = {0.25, 0.25, 0.25, 1},  -- Slightly lighter for background
                    UseSolidTexture = true,  -- Force solid texture when dark mode is enabled
                },
                CustomColors = {
                    Reaction = {
                        [1] = {204/255, 64/255, 64/255},    -- Hated
                        [2] = {204/255, 64/255, 64/255},    -- Hostile
                        [3] = {204/255, 128/255, 64/255},   -- Unfriendly
                        [4] = {255/255, 234/255, 126/255},   -- Neutral
                        [5] = {64/255, 204/255, 64/255},    -- Friendly
                        [6] = {64/255, 204/255, 64/255},    -- Honored
                        [7] = {64/255, 204/255, 64/255},    -- Revered
                        [8] = {64/255, 204/255, 64/255},    -- Exalted
                    },
                    Power = {
                        [0] = {0, 0.50, 1},            -- Mana
                        [1] = {1, 0, 0},            -- Rage
                        [2] = {1, 0.5, 0.25},       -- Focus
                        [3] = {1, 1, 0},            -- Energy
                        [6] = {0, 0.82, 1},         -- Runic Power
                        [8] = {0.3, 0.52, 0.9},     -- Lunar Power
                        [11] = {0, 0.5, 1},         -- Maelstrom
                        [13] = {0.4, 0, 0.8},       -- Insanity
                        [17] = {0.79, 0.26, 0.99},  -- Fury
                        [18] = {1, 0.61, 0}         -- Pain
                    },
                },
            },
            player = {
                Enabled = true,
                Frame = {
                    Width = 244,
                    Height = 42,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    Texture = "H3z0UI",
                    ClassColor = true,
                    ReactionColor = false,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                PowerBar = {
                    Enabled = true,
                    Height = 2,
                    ColorByType = true,
                    ColorBackgroundByType = false,
                    FGColor = {8/255, 8/255, 8/255, 0.8},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        OffsetX = 3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = true,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                    Power = {
                        Enabled = false,
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        OffsetX = -4,
                        OffsetY = 4,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
                Absorb = {
                    Enabled = true,
                    Color = {0, 1, 0.96, 0.2},  -- #00FFF5 (cyan) with 20% opacity
                },
            },
            target = {
                Enabled = true,
                Frame = {
                    Width = 244,
                    Height = 42,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    Texture = "H3z0UI",
                    ClassColor = true,
                    ReactionColor = true,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                PowerBar = {
                    Enabled = true,
                    Height = 2,
                    ColorByType = true,
                    ColorBackgroundByType = false,
                    FGColor = {8/255, 8/255, 8/255, 0.8},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        OffsetX = 3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = true,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                    Power = {
                        Enabled = false,
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        OffsetX = -4,
                        OffsetY = 4,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
                Auras = {
                    Width = 0,  -- 0 = use frame width
                    Height = 18,
                    Scale = 2.5,
                    Alpha = 1,
                    RowLimit = 0,  -- 0 = unlimited
                    -- Border settings (applies to both buffs and debuffs)
                    BorderSize = 1,
                    BorderColor = {0, 0, 0, 1},  -- Black border
                    -- Debuff settings
                    ShowDebuffs = true,
                    DebuffOffsetX = 0,
                    DebuffOffsetY = 2,
                    -- Buff settings
                    ShowBuffs = true,
                    BuffOffsetX = 0,
                    BuffOffsetY = 40,
                },
                Absorb = {
                    Enabled = true,
                    Color = {0, 1, 0.96, 0.2},  -- #00FFF5 (cyan) with 20% opacity
                },
            },
            targettarget = {
                Enabled = true,
                Frame = {
                    Width = 122,
                    Height = 21,
                    XPosition = 183.1,
                    YPosition = -10,
                    AnchorFrom = "CENTER",
                    AnchorParent = "H3z0UICore_Target",
                    AnchorTo = "CENTER",
                    Texture = "H3z0UI",
                    ClassColor = true,
                    ReactionColor = true,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        OffsetX = 0,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = false,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                },
            },
            pet = {
                Enabled = true,
                Frame = {
                    Width = 244,
                    Height = 21,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    Texture = "H3z0UI",
                    ClassColor = true,
                    ReactionColor = false,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        OffsetX = 0,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = false,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                    Power = {
                        Enabled = false,
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        OffsetX = -4,
                        OffsetY = 4,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
            },
            focus = {
                Enabled = true,
                Frame = {
                    Width = 122,
                    Height = 21,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    Texture = "H3z0UI",
                    ClassColor = true,
                    ReactionColor = true,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                PowerBar = {
                    Enabled = true,
                    Height = 2,
                    ColorByType = true,
                    ColorBackgroundByType = true,
                    FGColor = {8/255, 8/255, 8/255, 0.8},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        OffsetX = 0,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = false,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                    Power = {
                        Enabled = false,
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        OffsetX = -4,
                        OffsetY = 4,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
            },
            focus = {
                Enabled = true,
                Frame = {
                    Width = 122,
                    Height = 21,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    ClassColor = true,
                    ReactionColor = true,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                PowerBar = {
                    Enabled = true,
                    Height = 2,
                    ColorByType = true,
                    ColorBackgroundByType = true,
                    FGColor = {8/255, 8/255, 8/255, 0.8},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        OffsetX = 0,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = false,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                    Power = {
                        Enabled = false,
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        OffsetX = -4,
                        OffsetY = 4,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
            },
            boss = {
                Enabled = true,
                Frame = {
                    Width = 200,
                    Height = 36,
                    XPosition = 350,
                    YPosition = 0,
                    AnchorFrom = "LEFT",
                    AnchorParent = "H3z0UICore_Target",
                    AnchorTo = "RIGHT",
                    Texture = "H3z0UI",
                    ClassColor = true,
                    ReactionColor = true,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        OffsetX = 4,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        ColorByClass = false,
                        ColorByStatus = true,
                    },
                    Health = {
                        Enabled = true,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -4,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
            },
        },
        -- Config Panel Scale, Width, and Alpha (for the settings UI, not the in-game HUD)
        configPanelScale = 1.0,
        configPanelWidth = 750,
        configPanelAlpha = 0.97,

        -- Addon Accent Color (drives options panel theme + default fallback for skinned elements)
        addonAccentColor = {0.204, 0.827, 0.6, 1},  -- #34D399 Mint

        -- Combat Text Indicator
        combatText = {
            enabled = true,
            displayTime = 0.8,    -- Time text is visible before fade starts (seconds)
            fadeTime = 0.3,       -- Fade animation duration (seconds)
            fontSize = 14,        -- Text size
            xOffset = 0,          -- Horizontal offset from screen center
            yOffset = 0,          -- Vertical offset from screen center (positive = above)
            enterCombatColor = {1, 0.98, 0.2, 1},      -- +Combat text color (#FFFA33 yellow)
            leaveCombatColor = {1, 0.98, 0.2, 1},      -- -Combat text color (#FFFA33 yellow)
        },

        -- Combat Timer (displays elapsed combat time)
        combatTimer = {
            enabled = false,       -- Opt-in feature (disabled by default)
            xOffset = 0,           -- Horizontal offset from screen center
            yOffset = -150,        -- Vertical offset (below center by default)
            width = 80,            -- Frame width
            height = 30,           -- Frame height
            fontSize = 16,         -- Font size for timer text
            useCustomFont = false, -- If false, use global addon font
            font = "Poppins SemiBold",       -- Font name (from LibSharedMedia)
            useClassColorText = false,  -- If true, use player class color for text
            textColor = {1, 1, 1, 1},  -- White text
            -- Backdrop settings
            showBackdrop = true,
            backdropColor = {0, 0, 0, 0.6},  -- Semi-transparent black
            -- Border settings
            borderSize = 1,
            borderTexture = "None", -- Border texture from LibSharedMedia (or "None" for solid)
            useClassColorBorder = false,  -- If true, use player class color
            useAccentColorBorder = false,  -- If true, use addon accent color
            borderColor = {0, 0, 0, 1},  -- Black border
            hideBorder = false,  -- If true, hide border completely (overrides other border settings)
            onlyShowInEncounters = false,  -- If true, only show during boss encounters (not general combat)
        },

        -- Cooldown Manager Effects
        cooldownSwipe = {
            showBuffSwipe = false,      -- Buff/aura duration swipe (Essential/Utility)
            showBuffIconSwipe = false,  -- BuffIcon viewer swipe (opt-in)
            showGCDSwipe = false,       -- GCD swipe (~1.5s)
            showCooldownSwipe = false,  -- Actual spell cooldown swipe
            showRechargeEdge = false,   -- Yellow edge on multi-charge abilities
            showActionSwipe = true,     -- Action bar cooldown swipe
            showNcdmSwipe = true,       -- NCDM cooldown swipe
            showCustomTrackerSwipe = true, -- Custom tracker cooldown swipe
            migratedToV2 = true,        -- Migration marker from old hideEssential/hideUtility
        },
        cooldownEffects = {
            hideEssential = true,
            hideUtility = true,
        },
        cooldownManager = {
            -- hideSwipe removed - now handled by cooldownSwipe
        },
        
        -- Custom Glow Settings (for Essential/Utility cooldown viewers)
        customGlow = {
            -- Essential Cooldowns
            essentialEnabled = true,
            essentialGlowType = "Pixel Glow",  -- "Pixel Glow", "Autocast Shine", "Button Glow"
            essentialColor = {0.95, 0.95, 0.32, 1},  -- Default yellow/gold
            essentialLines = 14,       -- Number of lines for Pixel Glow / spots for Autocast Shine
            essentialFrequency = 0.25, -- Animation speed
            essentialLength = nil,     -- nil = auto-calculate based on icon size
            essentialThickness = 2,    -- Line thickness for Pixel Glow
            essentialScale = 1,        -- Scale for Autocast Shine
            essentialXOffset = 0,
            essentialYOffset = 0,

            -- Utility Cooldowns
            utilityEnabled = true,
            utilityGlowType = "Pixel Glow",
            utilityColor = {0.95, 0.95, 0.32, 1},
            utilityLines = 14,
            utilityFrequency = 0.25,
            utilityLength = nil,
            utilityThickness = 2,
            utilityScale = 1,
            utilityXOffset = 0,
            utilityYOffset = 0,
        },
        
        -- Buff/Debuff Visuals
        buffBorders = {
            enableBuffs = true,
            enableDebuffs = true,
            borderSize = 2,
            fontSize = 12,
            fontOutline = true,
        },
        
        -- H3z0UI Autohides
        uiHider = {
            hideObjectiveTrackerAlways = false,  -- Hide Objective Tracker always
            hideObjectiveTrackerInstanceTypes = {
                mythicPlus = false,
                mythicDungeon = false,
                normalDungeon = false,
                heroicDungeon = false,
                followerDungeon = false,
                raid = false,
                pvp = false,
                arena = false,
            },
            hideMinimapBorder = true,
            hideTimeManager = true,
            hideGameTime = true,
            hideMinimapTracking = true,
            hideRaidFrameManager = true,
            hideMinimapZoneText = true,
            hideBuffCollapseButton = true,
            hideFriendlyPlayerNameplates = true,
            hideFriendlyNPCNameplates = true,
            friendlyNPCNameplates = "off",  -- "off" always off, "on" always on, "game" left to the game
            hideTalkingHead = true,
            muteTalkingHead = false,
            hideErrorMessages = false,
            hideMinimapZoomButtons = true,
            hideWorldMapBlackout = true,
            hideTalkingHeadFrame = true,
            hideXPAtMaxLevel = false,
            hideExperienceBar = false,
            hideReputationBar = false,
            hideMainActionBarArt = false,
        },
        
        -- Minimap Settings
        minimap = {
            enabled = true,  -- Enabled by default for clean minimap experience
            
            -- Shape and Size
            shape = "SQUARE",  -- SQUARE or ROUND
            size = 160,
            scale = 1.0,  -- Scale multiplier for minimap frame
            borderSize = 2,
            borderColor = {0, 0, 0, 1},  -- Black border
            useClassColorBorder = false,
            useAccentColorBorder = false,
            buttonRadius = 2,  -- LibDBIcon button radius for square minimap
            
            -- Position
            lock = false,  -- Unlocked by default so users can position it
            position = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 790, y = 285 },
            
            -- Features
            autoZoom = false,  -- Auto zoom out after 10 seconds
            hideAddonButtons = true,  -- Show addon buttons on hover only
            
            -- Button Visibility
            showZoomButtons = false,
            showMail = false,
            showCraftingOrder = false,
            showAddonCompartment = false,
            showDifficulty = false,
            showMissions = false,
            showCalendar = true,
            showTracking = false,

            -- Dungeon Eye (LFG Queue Status Button) - repositions to minimap when in queue
            dungeonEye = {
                enabled = true,
                corner = "BOTTOMLEFT",
                scale = 0.6,
                offsetX = 0,
                offsetY = 0,
            },

            -- Clock (anchored top-left) - disabled by default, user can enable
            showClock = false,
            clockConfig = {
                offsetX = 0,
                offsetY = 0,
                align = "LEFT",
                font = "Poppins SemiBold",
                fontSize = 12,
                monochrome = false,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                useClassColor = false,
                timeFormat = "local",  -- "local" or "server"
            },
            
            -- Coordinates (anchored top-right)
            showCoords = false,
            coordPrecision = "%d,%d",  -- %d,%d = normal, %.1f,%.1f = high, %.2f,%.2f = very high
            coordUpdateInterval = 1,  -- Update every 1 second
            coordsConfig = {
                offsetX = 0,
                offsetY = 0,
                align = "RIGHT",
                font = "Poppins SemiBold",
                fontSize = 12,
                monochrome = false,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                useClassColor = false,
            },
            
            -- Zone Text (anchored top-center)
            showZoneText = true,
            zoneTextConfig = {
                offsetX = 0,
                offsetY = 0,
                align = "CENTER",
                font = "Poppins SemiBold",
                fontSize = 12,
                allCaps = false,
                monochrome = false,
                outline = "OUTLINE",
                useClassColor = false,
                colorNormal = {1, 0.82, 0, 1},      -- Gold
                colorSanctuary = {0.41, 0.8, 0.94, 1},  -- Light blue
                colorArena = {1.0, 0.1, 0.1, 1},    -- Red
                colorFriendly = {0.1, 1.0, 0.1, 1}, -- Green
                colorHostile = {1.0, 0.1, 0.1, 1},  -- Red
                colorContested = {1.0, 0.7, 0.0, 1}, -- Orange
            },
        },
        
        -- Minimap Button (LibDBIcon) - separate from minimap module
        minimapButton = {
            hide = false,
            minimapPos = 180,  -- 9 o'clock position (left side)
        },
        
        -- Datatext Panel (fixed below minimap - slot-based architecture)
        datatext = {
            enabled = true,
            slots = {"fps", "durability", "time"},  -- 3 configurable datatext slots

            -- Per-slot configuration (shortLabel, noLabel, xOffset, yOffset)
            slot1 = { shortLabel = false, noLabel = false, xOffset = -1, yOffset = 0 },
            slot2 = { shortLabel = false, noLabel = false, xOffset = 6, yOffset = 0 },
            slot3 = { shortLabel = true, noLabel = false, xOffset = 3, yOffset = 0 },

            forceSingleLine = true,  -- If true, ignores wrapping and forces single line
            
            -- Panel Settings (width auto-matches minimap)
            height = 22,
            offsetY = 0,  -- Y offset from minimap bottom
            bgOpacity = 60,  -- 0-100
            borderSize = 2,  -- Border thickness (0-8, 0=hidden)
            borderColor = {0, 0, 0, 1},  -- Black border (#90)

            -- Font Settings
            font = "Poppins SemiBold",
            fontSize = 13,
            fontOutline = "OUTLINE",  -- "OUTLINE" = Thin

            -- Color Settings
            useClassColor = false,
            valueColor = {0.1, 1.0, 0.1, 1},  -- #1AFF1A green
            
            -- Separator
            separator = "  ",
            
            -- Legacy Composite Mode Toggles
            showFPS = true,
            showLatency = false,
            showDurability = true,
            showGold = false,
            showTime = true,
            showCoords = false,
            showFriends = false,
            showGuild = false,
            showLootSpec = false,
            
            -- Time Settings (for Time datatext or legacy mode)
            timeFormat = "local",  -- "local" or "server"
            use24Hour = true,
            useLocalTime = true,  -- For datatext registry
            lockoutCacheMinutes = 5,  -- minutes between lockout data refresh (min 1)

            -- Social datatext settings
            showTotal = true,  -- Show total count (friends/guild)
            showGuildName = false,  -- Show guild name in text

            -- Player Spec datatext settings
            specDisplayMode = "full",  -- "icon" = icon only, "loadout" = icon + loadout, "full" = icon + spec/loadout

            -- System datatext settings (combined FPS + Latency)
            system = {
                latencyType = "home",      -- "home" or "world" latency on main display
                showLatency = true,        -- Show Home/World latency in tooltip
                showProtocols = true,      -- Show IPv4/IPv6 protocols in tooltip
                showBandwidth = true,      -- Show bandwidth/download % when downloading
                showAddonMemory = true,    -- Show addon memory usage in tooltip
                addonCount = 10,           -- Number of addons to show (sorted by memory)
                showFpsStats = true,       -- Show FPS avg/low/high when Shift held
            },

            -- Volume datatext settings
            volume = {
                volumeStep = 5,            -- Volume change per scroll (1-20)
                controlType = "master",    -- Which volume to control: "master", "music", "sfx", "ambience", "dialog"
                showIcon = false,          -- Show speaker icon instead of "Vol:" label
            },
        },
        
        -- Additional Datapanels (user-created, independent of minimap)
        h3z0uiDatatexts = {
            panels = {},  -- Array of panel configurations
        },

        -- Custom Tracker Bars (consumables, trinkets, custom spells)
        customTrackers = {
            bars = {
                {
                    id = "default_tracker_1",
                    name = "Trinket & Pot",
                    enabled = false,
                    locked = false,
                    -- Position (offset from screen center, use snap buttons to align to player)
                    offsetX = -406,
                    offsetY = -152,
                    -- Layout
                    growDirection = "RIGHT",
                    iconSize = 28,
                    spacing = 4,
                    borderSize = 2,
                    aspectRatioCrop = 1.0,
                    zoom = 0,
                    -- Duration text
                    durationSize = 13,
                    durationColor = {1, 1, 1, 1},
                    durationAnchor = "CENTER",
                    durationOffsetX = 0,
                    durationOffsetY = 0,
                    hideDurationText = false,
                    -- Stack text
                    stackSize = 9,
                    stackColor = {1, 1, 1, 1},
                    stackAnchor = "BOTTOMRIGHT",
                    stackOffsetX = 3,
                    stackOffsetY = -1,
                    hideStackText = false,
                    showItemCharges = true,  -- Show item charges (e.g., Healthstone 3 charges) instead of item count
                    -- Background
                    bgOpacity = 0,
                    bgColor = {0, 0, 0, 1},
                    hideGCD = true,
                    hideNonUsable = false,
                    showOnlyOnCooldown = false,
                    showOnlyWhenActive = false,
                    showOnlyWhenOffCooldown = false,
                    showOnlyInCombat = false,
                    -- Click behavior
                    clickableIcons = false,  -- Allow clicking icons to use items/cast spells
                    -- Active state (buff/cast/channel display)
                    showActiveState = true,
                    activeGlowEnabled = true,
                    activeGlowType = "Pixel Glow",
                    activeGlowColor = {1, 0.85, 0.3, 1},
                    -- Pre-populated with Algari Healing Potion
                    entries = {
                        { type = "item", id = 224022 },
                    },
                },
            },
            -- Global keybind settings for custom trackers
            keybinds = {
                showKeybinds = false,
                keybindTextSize = 12,
                keybindTextColor = { 1, 0.82, 0, 1 },  -- Gold
                keybindOffsetX = 2,
                keybindOffsetY = -2,
            },
            -- CDM buff tracking (trinket proc detection)
            cdmBuffTracking = {
                trinketData = {},
                learnedBuffs = {},
            },
        },

        -- Shaman Totem Bar (active totem display)
        totemBar = {
            enabled = false,
            locked = false,
            offsetX = 0,
            offsetY = -200,
            growDirection = "RIGHT",
            iconSize = 36,
            spacing = 4,
            borderSize = 2,
            zoom = 0,
            durationSize = 13,
            durationColor = {1, 1, 1, 1},
            durationAnchor = "CENTER",
            durationOffsetX = 0,
            durationOffsetY = 0,
            hideDurationText = false,
            showSwipe = true,
            swipeColor = {0, 0, 0, 0.6},
        },

        -- HUD Layering: Control frame level ordering for HUD elements
        -- Higher values appear above lower values (range 0-10)
        hudLayering = {
            -- CDM viewers (default 5 - middle)
            essential = 5,
            utility = 5,
            buffIcon = 5,
            buffBar = 5,
            -- Power bars (higher defaults so text visible above CDM)
            primaryPowerBar = 7,
            secondaryPowerBar = 6,
            -- Unit frames (lower defaults, background elements)
            playerFrame = 4,
            playerIndicators = 6,  -- Above player frame for visibility
            targetFrame = 4,
            totFrame = 3,
            petFrame = 3,
            focusFrame = 4,
            bossFrames = 4,
            -- Castbars (middle)
            playerCastbar = 5,
            targetCastbar = 5,
            -- Custom trackers
            customBars = 5,
            -- Totem bar
            totemBar = 5,
        },
    },
    -- Account-wide storage (shared across all characters)
    global = {
        -- Gold tracking per character (realm-name = copper)
        goldData = {},
        -- Spell Scanner: cross-character spell/item duration mappings
        spellScanner = {
            spells = {},   -- [castSpellID] = { buffSpellID, duration, icon, name, scannedAt }
            items = {},    -- [itemID] = { useSpellID, buffSpellID, duration, icon, name, scannedAt }
            autoScan = false,  -- Auto-scan setting (off by default)
        },
    },
}

local REPLACE = {
    h3z0uiUnitFrames = true,
    unitFrames = true,
    partyFrames = true,
    raidFrames = true,
    chat = true,
    castBar = true,
    targetCastBar = true,
    focusCastBar = true,
    addonAccentColor = true,
    -- 0.25.0 build 4: the H3z0 Cooldown Manager, buff bars, resource bars and custom trackers
    ncdm = true,
    viewers = true,
    customTrackers = true,
    cdmVisibility = true,
    unitframesVisibility = true,
    customTrackersVisibility = true,
    -- 0.25.0: the H3z0 UI minimap and its datatext panel, Hover Name
    minimap = true,
    datatext = true,
    hoverName = true,
}

local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = DeepCopy(x) end
    return c
end

local function Fill(dst, src)
    for k, v in pairs(src) do
        local d = dst[k]
        if d == nil then
            dst[k] = DeepCopy(v)
        elseif type(d) == "table" and type(v) == "table" then
            Fill(d, v)
        end
    end
end

-- WoW: Forever shows every empty action button (the classic grid): hide them by default there
if ns.Client and ns.Client.isForever then
    local ab = h3zDefaults.profile.actionBars
    if ab and ab.global then ab.global.hideEmptySlots = true end
end

ns.H3z0Defaults = h3zDefaults

local core = ns.defaults
if type(core) == "table" and type(core.profile) == "table" and type(h3zDefaults.profile) == "table" then
    for key, value in pairs(h3zDefaults.profile) do
        if REPLACE[key] then
            core.profile[key] = DeepCopy(value)
        elseif core.profile[key] == nil then
            core.profile[key] = DeepCopy(value)
        elseif type(core.profile[key]) == "table" and type(value) == "table" then
            Fill(core.profile[key], value)
        end
    end
    if type(h3zDefaults.global) == "table" then
        core.global = core.global or {}
        Fill(core.global, h3zDefaults.global)
    end
end

---------------------------------------------------------------------------
-- Resource bars (primary / secondary): the new-base bars, anchored under the
-- Essential cooldowns, with the H3z0 look (texture, colours, text, ticks, border).
do
    local LOOK = {
        "height", "borderSize", "texture", "colorMode", "usePowerColor", "useClassColor", "customColor",
        "showPercent", "showText", "textSize", "textX", "textY", "textUseClassColor", "textCustomColor",
        "bgColor", "showTicks", "tickThickness", "tickColor", "orientation", "showFragmentedPowerBarText",
    }
    local p = type(core) == "table" and core.profile
    local hp = h3zDefaults.profile
    if type(p) == "table" and type(hp) == "table" then
        for _, barKey in ipairs({ "powerBar", "secondaryPowerBar" }) do
            local cb, hb = p[barKey], hp[barKey]
            if type(cb) == "table" and type(hb) == "table" then
                for _, k in ipairs(LOOK) do
                    if hb[k] ~= nil then cb[k] = DeepCopy(hb[k]) end
                end
            end
        end
        if type(p.powerColors) == "table" and type(hp.powerColors) == "table" then
            for k, v in pairs(hp.powerColors) do p.powerColors[k] = DeepCopy(v) end
        end
    end
end

-- Action bars: H3z0 UI's own bar frames (new base) with the H3z0 look.
-- The bar engine keeps its own defaults (layout, positions); the look - skin,
-- text, fade and per-bar switches - is H3z0 UI's.
---------------------------------------------------------------------------
do
    local cab = type(core) == "table" and core.profile and core.profile.actionBars
    local hab = h3zDefaults.profile and h3zDefaults.profile.actionBars
    if type(cab) == "table" and type(hab) == "table" then
        cab.global = cab.global or {}
        for k, v in pairs(hab.global or {}) do cab.global[k] = DeepCopy(v) end
        cab.fade = cab.fade or {}
        for k, v in pairs(hab.fade or {}) do cab.fade[k] = DeepCopy(v) end
        cab.bars = cab.bars or {}
        for barKey, hb in pairs(hab.bars or {}) do
            if type(hb) == "table" then
                local cb = cab.bars[barKey]
                if type(cb) ~= "table" then
                    cab.bars[barKey] = DeepCopy(hb)
                else
                    for k, v in pairs(hb) do
                        if k ~= "ownedLayout" and k ~= "ownedPosition" then cb[k] = DeepCopy(v) end
                    end
                end
            end
        end
        -- Blizzard-sized buttons with a small gap (the H3z0 bars), until the
        -- first login reads your own sizes from the bars you had
        for i = 1, 8 do
            local cb = cab.bars["bar" .. i]
            local ol = type(cb) == "table" and cb.ownedLayout
            if type(ol) == "table" then
                ol.buttonSize = 45
                ol.buttonSpacing = 2
            end
        end
    end
end
