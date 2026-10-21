local MANIFEST = {
    { folder = "H3z0UI_ActionBars",   class = "login",                                                  sources = { "modules/actionbars" } },
    { folder = "H3z0UI_CDM",          class = "login",                                                  sources = { "modules/cdm" } },
    { folder = "H3z0UI_Chat",         class = "login",                                                  sources = {} },
    { folder = "H3z0UI_Nameplates",   class = "login",                                                  sources = {} },
    { folder = "H3z0UI_ResourceBars", class = "login",                                                  sources = { "modules/resourcebars" } },
    { folder = "H3z0UI_UnitFrames",   class = "login",                                                  sources = {} },
    { folder = "H3z0UI_Features",     class = "login",                                                  sources = {} },
    { coreModule = "minimap",   flag = { "minimap",      "enabled" } },
    { coreModule = "infobar",   flag = { "infobar",      "enabled" } },
    { coreModule = "alts",      flag = { "alts",         "enabled" } },
    { coreModule = "datatexts", flag = { "h3z0uiDatatexts", "enabled" } },
    { coreModule = "skinning",  flag = { "skinning",     "enabled" } },
    { folder = "H3z0UI_DamageMeter",  class = "login",                                                  sources = {} },
    { folder = "H3z0UI_Bags",         class = "lod", legacyFlag = { "bags", "enabled" }, loadPolicy = "profile", sources = { "modules/bags" } },
    { folder = "H3z0UI_Reminders",    class = "lod",                                                    sources = {} },
    { folder = "H3z0UI_UnderlightAnglerHelper", class = "lod",                                          sources = {} },
}

local ADDON_NAME, ns = ...
if type(ns) == "table" then
    ns.AddonManifest = MANIFEST
end
return MANIFEST
