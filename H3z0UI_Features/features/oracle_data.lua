--[[
    H3z0 UI - Oracle boss lines (retail only)

    Boss-specific callouts for the Mythic+ dungeons of the current season.
    Every row ties one boss ability to a short voice line and a line of text for
    the on-screen warning. Oracle matches a row by the ability's spell ID or, when
    the ID differs (the guides list test-server IDs), by the ability's name.

    A row is { ability name, spell ID, voice, on-screen text, role }.
      voice = a key of PHRASES below (own voice clip) or of the generic callouts in
              oracle.lua (soak, spread, stack, fixate, interrupt, knockback, hide,
              move, adds, raid, dispel, tank, healer, deadly, enrage).
      role  = "TANK" or "HEALER" when only that role should hear it (optional).

    Abilities without a row keep the generic callout from oracle.lua.
]]

local ADDON_NAME, ns = ...

local D = {}
ns.OracleData = D

-- voice clips: sounds\oracle\<key>.ogg. cat = colour of the on-screen warning
D.phrases = {
    c_soak_beams  = { say = "Soak the beams",           cat = "soak" },
    c_soak_circles= { say = "Soak the circles",         cat = "soak" },
    c_soak_orbs   = { say = "Soak the orbs",            cat = "soak" },
    c_defensive   = { say = "Tank, defensive",          cat = "tank" },
    c_defensive_me= { say = "Use a defensive",          cat = "deadly" },
    c_tank_away   = { say = "Face it away",             cat = "tank" },
    c_run_out     = { say = "Run out",                  cat = "move" },
    c_dodge       = { say = "Dodge it",                 cat = "move" },
    c_kill_adds   = { say = "Kill the adds",            cat = "adds" },
    c_swap        = { say = "Swap target",              cat = "adds" },
    c_dispel      = { say = "Dispel it",                cat = "dispel" },
    c_heal_cds    = { say = "Healing cooldowns",        cat = "healer" },
    c_top_up      = { say = "Top everyone up",          cat = "healer" },
    c_move_away   = { say = "Move away from the group", cat = "spread" },
    c_drop        = { say = "Drop it away from the group", cat = "spread" },
    c_group_up    = { say = "Group up",                 cat = "stack" },
    c_kite        = { say = "Kite it",                  cat = "fixate" },
    c_pickup      = { say = "Pick up the add",          cat = "tank" },
    c_behind      = { say = "Get behind cover",         cat = "hide" },
    c_barrel      = { say = "Hide behind a barrel",     cat = "hide" },
    c_tethers     = { say = "Break the tethers",        cat = "move" },
    c_gateway     = { say = "Take the gateway",         cat = "move" },
    c_shield      = { say = "Break the shield",         cat = "adds" },
    c_free        = { say = "Free the player",          cat = "alert" },
    c_totem       = { say = "Kill the totem",           cat = "adds" },
    c_wall        = { say = "Form a wall",              cat = "stack" },
    c_run_back    = { say = "Run back and soak",        cat = "soak" },
    c_cleave      = { say = "Cleave it",                cat = "adds" },
    c_block       = { say = "Block the spire",          cat = "move" },
    c_echoes      = { say = "Drop the echoes",          cat = "spread" },
    -- raids
    c_tank_swap   = { say = "Tank swap",                cat = "tank" },
    c_split_dmg   = { say = "Share the damage",         cat = "soak" },
    c_raid_cds    = { say = "Raid cooldown",            cat = "raid" },
    c_burst       = { say = "Damage window, cooldowns", cat = "interrupt" },
    c_fish        = { say = "Feed the fish",            cat = "enrage" },
    c_keep_apart  = { say = "Keep them apart",          cat = "spread" },
    c_carry       = { say = "Carry the globules",       cat = "adds" },
    c_stay_side   = { say = "Stay on your side",        cat = "hide" },
}

local rows = {}
D.rows = rows

-- dungeon, boss, list of { ability, id, voice, text, role }
local function B(dungeon, boss, list)
    for _, r in ipairs(list) do
        rows[#rows + 1] = { name = r[1], id = r[2], say = r[3], text = r[4], role = r[5], dungeon = dungeon, boss = boss }
    end
end

---------------------------------------------------------------------------
-- Altar of Fangs
---------------------------------------------------------------------------
B("Altar of Fangs", "Rav'i", {
    { "Ravenous Stomp",     1307915, "c_top_up",      "TOP EVERYONE UP",     "HEALER" },
    { "Ssscavenging",       1298221, "c_soak_orbs",   "SOAK THE EATERS" },
    { "Triple Shot",        1297876, "spread",        "SPREAD" },
    { "Regurgitate",        1296069, "c_dodge",       "DODGE THE WAVES" },
    { "Hydrastrike",        1298683, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
})
B("Altar of Fangs", "The Writhing Coil", {
    { "Toxic Atrophy",      1310974, "interrupt",     "INTERRUPT" },
    { "Vindictive Onslaught", 1299940, "c_run_out",   "MOVE OUT OF THE LINE" },
    { "Death Rattle",       1299053, "c_tethers",     "BREAK THE TETHERS" },
    { "Undermining",        1305393, "c_dodge",       "AVOID THE SHOCKWAVES" },
})
B("Altar of Fangs", "Zul'jan", {
    { "Ritual of the Fang", 1300876, "c_soak_beams",  "SOAK THE BEAMS" },
    { "Chop Down",          1301350, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
    { "Axegrinder",         1301111, "c_dodge",       "DODGE THE AXES" },
})

---------------------------------------------------------------------------
-- Murder Row
---------------------------------------------------------------------------
B("Murder Row", "Kystia Manaheart", {
    { "Mirror Images",      1264095, "c_kill_adds",   "KILL THE IMAGES" },
    { "Corroding Spittle",  1228198, "c_dispel",      "DISPEL IT" },
    { "Fel Nova",           1223906, "c_run_out",     "RUN OUT" },
    { "Fel Spray",          1253811, "c_tank_away",   "FACE IT AWAY",        "TANK" },
    { "Chaos Barrage",      1230298, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
})
B("Murder Row", "Zaen Bladesorrow", {
    { "Same-Day Delivery",  474765,  "c_dodge",       "DODGE THE BARRELS" },
    { "Fire Bomb",          1214357, "c_cleave",      "CLEAVE THE FREIGHT" },
    { "Murder In A Row",    1218347, "c_barrel",      "HIDE BEHIND A BARREL" },
    { "Killing Spree",      474478,  "c_heal_cds",    "HEALING COOLDOWNS",   "HEALER" },
    { "Envenom",            1222795, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
})
B("Murder Row", "Xathuux the Annihilator", {
    { "Legion Strike",      473898,  "c_tank_away",   "FACE IT AWAY",        "TANK" },
    { "Axe Toss",           1214663, "c_swap",        "SWAP TO THE AXE" },
    { "Infernal Crush",     1295455, "spread",        "SPREAD" },
    { "Demonic Rage",       474197,  "c_kite",        "KITE IT",             "TANK" },
})
B("Murder Row", "Lithiel Cinderfury", {
    { "Chaos Bolt",         474375,  "interrupt",     "INTERRUPT" },
    { "Summon Vilefiend",   474408,  "c_pickup",      "PICK UP THE ADD",     "TANK" },
    { "Fingers of Gul'dan", 474457,  "spread",        "SPREAD" },
    { "Demonic Gateway",    1214675, "c_gateway",     "TAKE THE GATEWAY" },
    { "Searing Fel Flame",  1216945, "c_heal_cds",    "HEALING COOLDOWNS",   "HEALER" },
})

---------------------------------------------------------------------------
-- Den of Nalorakk
---------------------------------------------------------------------------
B("Den of Nalorakk", "The Hoardmonger", {
    { "Hearty Bellow",      1235125, "knockback",     "KNOCKBACK" },
    { "Bonespike Slam",     1235129, "c_run_out",     "STEP OUT" },
    { "Spoiled Supplies",   1234233, "c_soak_orbs",   "SOAK THE MUSHROOMS" },
})
B("Den of Nalorakk", "Sentinel of Winter", {
    { "Glacial Torment",    1235548, "c_dispel",      "DISPEL IT" },
    { "Raging Squall",      1235623, "c_group_up",    "GROUP UP" },
    { "Shattering Frostspike", 1235783, "c_dodge",    "AVOID THE CIRCLES" },
    { "Winter's Shroud",    1235829, "interrupt",     "INTERRUPT" },
    { "Rimeshatter",        1263590, "soak",          "ONE SOAKS THE SNOW" },
    { "Frozen Tempest",     1235656, "c_heal_cds",    "HEALING COOLDOWNS",   "HEALER" },
})
B("Den of Nalorakk", "Nalorakk", {
    { "Echoing Maul",       1242860, "c_echoes",      "DROP THE ECHOES" },
    { "Overwhelming Onslaught", 1297792, "c_behind",  "GET BEHIND THE SHIELD" },
    { "Forceful Slam",      1297797, "c_run_back",    "RUN BACK AND SOAK",   "TANK" },
    { "Fury of the War God", 1243002, "c_wall",       "FORM A WALL" },
})

---------------------------------------------------------------------------
-- The Blinding Vale
---------------------------------------------------------------------------
B("The Blinding Vale", "Lightblossom Trinity", {
    { "Light Bolt",         1235616, "interrupt",     "INTERRUPT" },
    { "Thornblade",         1235640, "c_move_away",   "MOVE AWAY, RUN OUT" },
    { "Bedrock Slam",       1234753, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
    { "Lightsower Dash",    1234850, "c_dodge",       "DODGE THE LINE" },
    { "Lightblossom Beam",  1235564, "c_soak_circles","SOAK THE CIRCLES" },
})
B("The Blinding Vale", "Ikuzz the Light Hunter", {
    { "Thorncaller Roar",   1236709, "c_heal_cds",    "HEALING COOLDOWNS",   "HEALER" },
    { "Bloodthorn Roots",   1236658, "c_dodge",       "AVOID THE ROOTS" },
    { "Verdant Stomp",      1236746, "knockback",     "KNOCKBACK" },
    { "Bloodthirsty Gaze",  1237090, "c_kite",        "YOU ARE FIXATED, KITE" },
})
B("The Blinding Vale", "Lightwarden Ruia", {
    { "Warden's Wrath",     1239821, "interrupt",     "INTERRUPT" },
    { "Lightfall",          1240098, "c_dodge",       "AVOID THE CIRCLES" },
    { "Lightfire",          1239824, "c_group_up",    "GROUP UP, DEFENSIVE" },
    { "Grievous Thrash",    1241058, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
    { "Pulverizing Strikes", 1240210, "spread",       "SPREAD" },
})
B("The Blinding Vale", "Ziekket", {
    { "Awaken The Lightbloom", 1246372, "c_kill_adds","KILL THE ADDS" },
    { "Lightspore Shot",    1247669, "interrupt",     "INTERRUPT" },
    { "Concentrated Lightbeam", 1246607, "c_cleave",  "BEAM THE ADD BODIES" },
    { "Lightbloom's Essence", 1246858, "c_soak_orbs", "SOAK THE ORBS" },
    { "Thornspike",         1247685, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
})

---------------------------------------------------------------------------
-- Voidscar Arena
---------------------------------------------------------------------------
B("Voidscar Arena", "Taz'Rah", {
    { "Nether Dash",        1222098, "spread",        "SPREAD" },
    { "Void Blast",         1297017, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
    { "Umbral Rupture",     1296963, "c_dodge",       "AVOID THE PUDDLES" },
    { "Dark Bloom",         1300259, "c_dodge",       "DODGE THE ORBS" },
})
B("Voidscar Arena", "Atroxus", {
    { "Poison Splash",      1226031, "c_heal_cds",    "HEALING COOLDOWNS",   "HEALER" },
    { "Noxious Breath",     1222724, "c_dodge",       "DODGE THE BREATH" },
    { "Monstrous Roar",     1262497, "c_kill_adds",   "KILL THE CREEPER" },
    { "Hulking Claw",       1222642, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
})
B("Voidscar Arena", "Charonus", {
    { "Unstable Singularity", 1264191, "c_dodge",     "AVOID THE ORBS" },
    { "Cosmic Crash",       1227197, "spread",        "SPREAD" },
    { "Gravitic Orbs",      1223298, "c_kite",        "KITE THE ORBS" },
    { "Dark Waves",         1311923, "c_tank_away",   "FACE IT AWAY",        "TANK" },
    { "Void Cascade",       1222755, "c_run_out",     "RUN OUT OF THE PATH" },
})

---------------------------------------------------------------------------
-- Kings' Rest
---------------------------------------------------------------------------
B("Kings' Rest", "The Golden Serpent", {
    { "Spit Gold",          265773,  "c_drop",        "DROP THE PUDDLES NEAR OTHERS" },
    { "Serpentine Gust",    1311987, "c_heal_cds",    "HEALING COOLDOWNS",   "HEALER" },
})
B("Kings' Rest", "Mchimba the Embalmer", {
    { "Drain Fluids",       267618,  "c_defensive_me","YOU ARE DRAINED, DEFENSIVE" },
    { "Burn Corruption",    267639,  "c_drop",        "DROP FIRE AWAY" },
    { "Awakening Slam",     1312146, "c_top_up",      "TOP UP, KILL THE MUMMIES", "HEALER" },
    { "Entomb",             267702,  "c_free",        "FREE THE PLAYER" },
})
B("Kings' Rest", "The Council of Tribes", {
    { "Whirling Axes",      266206,  "c_dodge",       "DODGE THE AXES" },
    { "Barrel Through",     266951,  "soak",          "GROUP UP TO SOAK" },
    { "Debilitating Backhand", 266237, "c_defensive", "TANK DEFENSIVE",      "TANK" },
    { "Poison Nova",        267273,  "interrupt",     "INTERRUPT" },
    { "Call the Elements",  nil,  "c_totem",       "KILL THE TOTEM" },
})
B("Kings' Rest", "Dazar, the First King", {
    { "Aerial Smash",       1303115, "spread",        "SPREAD" },
    { "Quaking Leap",       268932,  "c_heal_cds",    "HEALING COOLDOWNS",   "HEALER" },
    { "Blade Combo",        268586,  "c_defensive",   "TANK DEFENSIVE",      "TANK" },
    { "Gilded Destruction", 1303267, "c_tank_away",   "FACE IT AWAY",        "TANK" },
    { "Impaling Spear",     1302945, "c_dodge",       "AVOID THE CIRCLES" },
    { "Deathly Roar",       269369,  "interrupt",     "INTERRUPT" },
})

---------------------------------------------------------------------------
-- Temple of Sethraliss
---------------------------------------------------------------------------
B("Temple of Sethraliss", "Adderis and Aspix", {
    { "Gale Force",         1289059, "knockback",     "SPREAD, KNOCKBACK" },
    { "Thunder and Lightning", 1288049, "soak",       "COLLAPSE AND SOAK" },
    { "Tempest Winds",      1288864, "c_drop",        "DROP IT AWAY FROM OTHERS" },
    { "Overload",           1288428, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
})
B("Temple of Sethraliss", "Merektha", {
    { "Lightning Bite",     1290797, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
    { "Knot of Snakes",     nil, "stack",         "STACK IN MELEE" },
    { "Thunder Spit",       1289109, "c_drop",        "DROP IT AT THE EDGE" },
    { "Serpentstorm",       1293048, "c_heal_cds",    "HEALING COOLDOWNS",   "HEALER" },
    { "Burrow",             264206,  "c_kill_adds",   "KILL THE ADDS" },
})
B("Temple of Sethraliss", "Galvazzt", {
    { "Lightning Spire",    1291618, "c_block",       "BLOCK THE SPIRE" },
    { "Consume Charge",     266512,  "c_block",       "BLOCK THE SPIRE" },
    { "Induction",          1290531, "c_dodge",       "AVOID THE PUDDLE" },
})
B("Temple of Sethraliss", "Avatar of Sethraliss", {
    { "Corrupted Lifeforce", 1300871, "c_soak_orbs",  "SOAK THE LIFEFORCE" },
    { "Corruption Burst",   1302826, "c_run_out",     "RUN OUT" },
})

---------------------------------------------------------------------------
-- Ruby Life Pools
---------------------------------------------------------------------------
B("Ruby Life Pools", "Melidrussa Chillworn", {
    { "Frigid Shard",       372808,  "interrupt",     "INTERRUPT" },
    { "Hailburst",          396044,  "c_group_up",    "GROUP UP, BAIT THE ICE" },
    { "Chillstorm",         372851,  "c_move_away",   "MOVE AWAY, COOLDOWN" },
    { "Awaken Whelps",      373046,  "c_pickup",      "PICK UP THE WHELPS",  "TANK" },
    { "Frost Overload",     373680,  "c_shield",      "BREAK THE SHIELD" },
})
B("Ruby Life Pools", "Kokia Blazehoof", {
    { "Ritual of Blazebinding", 372863, "c_move_away","MOVE AWAY FROM THE GROUP" },
    { "Inferno",            384823,  "c_heal_cds",    "HEALING COOLDOWNS",   "HEALER" },
    { "Blaze Volley",       373017,  "interrupt",     "INTERRUPT" },
    { "Molten Boulder",     372107,  "c_dodge",       "DODGE THE BOULDERS" },
    { "Searing Blows",      372858,  "c_defensive",   "TANK DEFENSIVE",      "TANK" },
})
B("Ruby Life Pools", "Kyrakka and Erkhart Stormvein", {
    { "Inferno Spit",       381862,  "c_move_away",   "MOVE AWAY, DROP FIRE" },
    { "Roaring Flamebreath", nil, "c_dodge",       "DODGE THE BREATH" },
    { "Stormslam",          381512,  "c_dispel",      "DISPEL THE TANK" },
})


---------------------------------------------------------------------------
-- RAID: The Venomous Abyss
---------------------------------------------------------------------------
local RAID = "The Venomous Abyss (Raid)"
B(RAID, "Nek'zali the Soulcoiler", {
    { "Hungering Pyre",     1289855, "c_split_dmg",   "SHARE THE PYRE" },
    { "Essence Rend",       1287426, "c_dispel",      "DISPEL IN THE CORNER" },
    { "Possession Barrage", 1284103, "c_defensive",   "TANK TAKES IT, RAID STAY BACK", "TANK" },
    { "Hollowing Strikes",  1284110, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Soulcoil Rite",      1284033, "c_raid_cds",    "RAID COOLDOWN",       "HEALER" },
    { "Soulcoil Ignition",  1285681, "c_raid_cds",    "RAID COOLDOWN",       "HEALER" },
    { "Gravebound Advance", 1287533, "c_shield",      "BREAK THE SHIELDS" },
    { "Ritual of Awakening", 1289683, "c_kill_adds",  "SEVER THE THREADS" },
    { "Uncoiling",          1290003, "c_raid_cds",    "RAID DAMAGE UP, COOLDOWNS", "HEALER" },
    { "Uncoiled Rage",      1284034, "enrage",        "ENRAGE, BURN HER" },
})
B(RAID, "Entombed Sentinels", {
    { "Ula'tek's Dominance", 1290193, "c_keep_apart", "KEEP THE GOLEMS APART" },
    { "Empowering Slam",    1284458, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Bloodvenom Injection", 1284487, "c_tank_swap", "TANK SWAP",           "TANK" },
    { "Unstable Miasma",    1288232, "c_group_up",    "GROUP UP AT THE MARKED PLAYER" },
    { "Toxic Droplets",     1284434, "c_dodge",       "AVOID THE DROPLETS" },
    { "Venom Coagulation",  1284251, "c_kill_adds",   "KILL THE SLIME" },
    { "Helical Toxins",     1284590, "c_group_up",    "TOUCH A PARTNER, FOUR STACKS" },
})
B(RAID, "The Lost Explorers", {
    { "Final Ascension",    1292779, "c_fish",        "FEED THE FISH" },
    { "Dark Whispers",      1295451, "c_fish",        "BREAK CONTROL WITH THE FISH" },
    { "Shredding Shards",   1295854, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Steady Strikes",     1291930, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Blink Nova",         1292793, "spread",        "SPREAD FROM IKU" },
    { "Mighty Thud",        1296092, "c_split_dmg",   "SHARE THE LEAP" },
    { "Explosive Surprise", 1297625, "c_split_dmg",   "SHARE THE BOMB" },
    { "Frostfire Volley",   1295886, "c_dodge",       "CLEAR THE ZONES" },
    { "United Defense",     1297646, "c_keep_apart",  "KEEP THE EXPLORERS APART" },
})
B(RAID, "Vashnik the Malignant", {
    { "Imbibe",             1283164, "c_raid_cds",    "BIG RAID DAMAGE, COOLDOWNS" },
    { "Toxic Vapor",        1284561, "c_raid_cds",    "RAID COOLDOWN",       "HEALER" },
    { "Dripping Fangs",     1280935, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Malignant Burst",    1280189, "c_kill_adds",   "KILL THE VENOM" },
    { "Stygian Infection",  1294994, "spread",        "SPREAD" },
    { "Exploding Infection", 1295173, "c_dispel",     "DISPEL ONE AT A TIME" },
    { "Malignance",         1304459, "c_dodge",       "AVOID THE VENOM WAVES" },
})
B(RAID, "Sszorak", {
    { "Apex Predator",      1277025, "c_defensive",   "TANK DEFENSIVE",      "TANK" },
    { "Ravage",             1277002, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Corroding Venom",    1282869, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Mutilate",           1277027, "c_split_dmg",   "FIVE IN EACH CONE" },
    { "Venomous Surge",     1305959, "spread",        "SPREAD" },
    { "Raging Crosswinds",  1285419, "knockback",     "KNOCKBACK, WATCH THE DIRECTION" },
    { "Howling Maelstrom",  1285732, "knockback",     "KNOCKBACK" },
    { "Viscous Cyst",       1287008, "c_drop",        "DROP THE CYST" },
    { "Dig In",             1286033, "c_burst",       "DAMAGE WINDOW, COOLDOWNS" },
})
B(RAID, "The Twin Fangs", {
    { "Ravenous Feast",     1290516, "c_split_dmg",   "SOAK THE FEAST, REMOVES STACKS" },
    { "Caustic Deluge",     1289192, "c_tank_away",   "KEEP THE RAID AWAY",  "TANK" },
    { "Caustic Globule",    1289993, "c_soak_orbs",   "SOAK THE GLOBULE" },
    { "Stone Breaker",      1288538, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Stir the Depths",    1290956, "c_raid_cds",    "RAID COOLDOWN",       "HEALER" },
    { "Venomous Emergence", 1291404, "c_kill_adds",   "KILL THE BROODLINGS" },
    { "Vile Flood",         1293749, "c_dodge",       "CROSS IT EARLY" },
    { "Sanguine Storm",     1306872, "c_raid_cds",    "RAID COOLDOWN",       "HEALER" },
})
B(RAID, "The Coiled Altar", {
    { "Sever",              1299680, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Soul Sever",         1286620, "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Guillotine",         1283489, "c_split_dmg",   "THREE UNDER EACH GUILLOTINE" },
    { "Veil of Twilight",   1286912, "c_raid_cds",    "RAID COOLDOWN",       "HEALER" },
    { "Defilement of the Coiled Altar", 1298381, "c_raid_cds", "RAID COOLDOWN", "HEALER" },
    { "Dreadmarch",         1285643, "c_shield",      "BREAK THE ABSORBS" },
    { "Eternal Nightfall",  1286918, "c_shield",      "BREAK THE VEIL FIRST" },
    { "Coalesced Venom",    1282403, "c_carry",       "CARRY THE GLOBULES" },
    { "Gravebound",         1286837, "move",          "PICK UP YOUR SOUL FRAGMENT" },
    { "Toxic Deluge",       1299960, "c_dodge",       "AVOID THE PUDDLES" },
    { "Soulbinding",        1304032, "c_burst",       "KILL IT BEFORE THE RITUAL ENDS" },
})
B(RAID, "Ula'tek", {
    { "Mother's Wrath",     1298367, "knockback",     "KNOCKBACK, WALK BACK IN" },
    { "Caustic Waves",      1292403, "c_dodge",       "KEEP THE EGGS OUT OF THE WAVES" },
    { "Putrid Membrane",    1301268, "c_raid_cds",    "RAID COOLDOWN",       "HEALER" },
    { "Spectral Coils",     1287265, "c_split_dmg",   "SPLIT THE COILS" },
    { "Call of the Serpent", 1300751, "c_kill_adds",  "KILL THE BROOD" },
    { "Rage of the Shackled", 1286860, "c_burst",     "DAMAGE WINDOW, COOLDOWNS" },
})


---------------------------------------------------------------------------
-- RAID: The Voidspire
---------------------------------------------------------------------------
local VS = "The Voidspire (Raid)"
B(VS, "Imperator Averzian", {
    { "Shadow's Advance",   1251361, "c_kill_adds",   "KILL THE VOIDSHAPERS" },
    { "Void Marked",        1280015, "c_dispel",      "DISPEL ON THE VOIDSHAPER" },
    { "Cosmic Shell",       1280035, "c_dispel",      "DISPEL TO BREAK THE SHELL" },
    { "Pitch Bulwark",      1255702, "interrupt",     "INTERRUPT" },
    { "Black Miasma",       1275059, "interrupt",     "INTERRUPT" },
})
B(VS, "Vorasius", {
    { "Primordial Roar",    nil,     "c_group_up",    "GROUP UP, PULL AND KNOCKBACK" },
    { "Shadowclaw Slam",    nil,     "soak",          "TANK SOAKS THE SLAM", "TANK" },
    { "Aftershock",         nil,     "c_dodge",       "MOVE INTO THE GAP IN THE RING" },
    { "Blistercreep",       nil,     "fixate",        "FIXATED, RUN TO THE WALL" },
    { "Void Breath",        nil,     "c_dodge",       "RUN TO THE OPPOSITE SIDE" },
})
B(VS, "Fallen-King Salhadaar", {
    { "Void Convergence",   1247738, "c_kill_adds",   "KILL ONE ORB AT A TIME" },
    { "Nexus Shield",       1275056, "interrupt",     "KICK THE IMAGES IN ORDER" },
    { "Entropic Unraveling", 1246175, "c_raid_cds",   "RAID COOLDOWN",       "HEALER" },
})
B(VS, "Vaelgor and Ezzorak", {
    { "Gloom",              1245391, "c_split_dmg",   "SOAK THE GLOOM" },
    { "Nullbeam",           1262623, "soak",          "TANK SOAKS THE BEAM", "TANK" },
    { "Nullzone",           1244672, "c_tethers",     "BREAK THE TETHERS" },
    { "Nullscatter",        1266570, "c_dodge",       "DODGE THE CIRCLES" },
    { "Void Howl",          1244917, "spread",        "SPREAD LIGHTLY" },
    { "Dread Breath",       1244221, "c_dispel",      "DISPEL IT" },
    { "Twilight Bond",      1270189, "c_keep_apart",  "KEEP THE BOSSES APART" },
})
B(VS, "Lightblinded Vanguard", {
    { "Avenger's Shield",   nil,     "spread",        "SPREAD, DISPEL" },
    { "Execution Sentence", nil,     "c_split_dmg",   "SOAK, FOUR PLAYERS" },
    { "Divine Toll",        nil,     "c_dodge",       "AVOID THE SHIELD WAVES" },
    { "Tyr's Wrath",        nil,     "c_move_away",   "ONE TAKES A STACK AND MOVES" },
    { "Aura of Devotion",   nil,     "c_keep_apart",  "KEEP BELLAMY APART" },
    { "Aura of Wrath",      nil,     "c_keep_apart",  "KEEP VENEL APART" },
    { "Aura of Peace",      nil,     "c_keep_apart",  "STAY OUT OF THE AURA" },
    { "Sacred Toll",        nil,     "c_raid_cds",    "RAID COOLDOWN",       "HEALER" },
    { "Divine Storm",       nil,     "c_dodge",       "AVOID THE TORNADOES" },
    { "Blinding Light",     nil,     "interrupt",     "INTERRUPT" },
    { "Divine Shield",      nil,     "c_dispel",      "MASS DISPEL THE SHIELD" },
})
B(VS, "Crown of the Cosmos", {
    { "Grasp of Emptiness", 1232470, "move",          "MOVE TOGETHER, BEAMS AWAY" },
    { "Void Expulsion",     1255368, "c_drop",        "BAIT AND DROP THE PUDDLES" },
    { "Silverstrike Arrow", 1233602, "c_defensive_me","ARROW, USE A DEFENSIVE" },
    { "Dimensional Slash",  nil,     "c_group_up",    "LET IT LAND, THEN STACK" },
    { "Rift Simulacrum",    nil,     "c_kill_adds",   "SEND DPS THROUGH THE GATE" },
    { "Empowering Darkness", 1237251, "c_keep_apart", "KEEP THE BOSS 25 YARDS FROM THE ADDS" },
    { "Devouring Cosmos",   1238843, "c_dodge",       "AVOID THE PUDDLE" },
})

---------------------------------------------------------------------------
-- RAID: The Dreamrift
---------------------------------------------------------------------------
B("The Dreamrift (Raid)", "Chimaerus the Undreamt God", {
    { "Alndust Upheaval",   nil,     "soak",          "SOAK IT, GO DOWNSTAIRS" },
    { "Consuming Miasma",   nil,     "c_dispel",      "RUN TO A POOL, GET DISPELLED" },
    { "Fearsome Cry",       nil,     "interrupt",     "INTERRUPT" },
    { "Rending Tear",       nil,     "knockback",     "BLEED AND KNOCKBACK" },
    { "Corrupted Devastation", nil,  "c_dodge",       "AVOID THE FLIGHT LINES" },
    { "Ravenous Dive",      nil,     "c_kill_adds",   "KILL ALL ADDS NOW" },
})

---------------------------------------------------------------------------
-- RAID: March on Quel'Danas
---------------------------------------------------------------------------
local MQD = "March on Quel'Danas (Raid)"
B(MQD, "Belo'ren, Child of Al'ar", {
    { "Radiant Echoes",     1242981, "c_kill_adds",   "POP THE ORBS, KEEP THEM OFF THE BOSS" },
    { "Infused Quills",     1242260, "c_split_dmg",   "SOAK THE QUILLS" },
    { "Voidlight Convergence", 1242515, "move",       "STOP POPPING ORBS" },
    { "Embers of Belo'ren", 1241282, "c_raid_cds",    "RAID COOLDOWN" },
})
B(MQD, "Midnight Falls", {
    { "Termination Prism",  1284931, "interrupt",     "INTERRUPT THE MATRIX" },
    { "Dark Quasar",        1285561, "c_dodge",       "CROSS THE BEAMS" },
    { "Tears of L'ura",     1254262, "c_split_dmg",   "SOAK THE TEARS" },
    { "Galvanize",          1284525, "c_split_dmg",   "SOAK THE BEAMS" },
    { "Criticality",        1281184, "spread",        "SPREAD, DO NOT HIT A CRYSTAL" },
    { "Severance",          1274455, "c_stay_side",   "STAY IN YOUR DIMENSION" },
    { "Heaven's Glaives",   nil,     "c_dodge",       "DODGE THE GLAIVES" },
    { "Heaven's Lance",     nil,     "c_tank_swap",   "TANK SWAP",           "TANK" },
    { "Starsplinter",       nil,     "spread",        "SPREAD" },
    { "Light Siphon",       nil,     "c_split_dmg",   "SOAK THE POOLS" },
    { "Dark Constellation", nil,     "c_dodge",       "MOVE THROUGH THE GAPS" },
})

---------------------------------------------------------------------------
-- lookup tables (by spell ID and by lower case ability name)
---------------------------------------------------------------------------
D.byId, D.byName = {}, {}
for _, r in ipairs(rows) do
    if r.id then D.byId[r.id] = r end
    local key = r.name:lower()
    if not D.byName[key] then D.byName[key] = r end
end

function D.Find(spellID, name)
    local r = spellID and D.byId[spellID]
    if r then return r end
    if type(name) == "string" and name ~= "" then return D.byName[name:lower()] end
end
