local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options
local Settings = ns.Settings
local Registry = Settings and Settings.Registry
local Schema = Settings and Settings.Schema

local CreateWrappedLabel = Shared.CreateWrappedLabel
local PADDING = Shared.PADDING or 15

---------------------------------------------------------------------------
-- Looks: one click sets the accent colour, the font, the outline and the bar
-- texture together and syncs them to every module, the same way the
-- Sync Fonts button does. A backup of the profile is made first, so a look
-- can be undone.
---------------------------------------------------------------------------
local Looks = {}
ns.H3z0UI_Looks = Looks

Looks.List = {
    { name = "Clean Dark",     theme = "Sky Blue",     font = "Expressway",       outline = "OUTLINE", texture = "H3z0UI v5",
      about = "Sharp blue accent, thin outlined text, the standard H3z0 bar." },
    { name = "Soft Rose",      theme = "Rose",         font = "Poppins Medium",   outline = "",        texture = "Satin",
      about = "Rose accent, rounded text without outline, smooth satin bars." },
    { name = "Bold Amber",     theme = "Amber",        font = "Poppins Bold",     outline = "OUTLINE", texture = "Flat",
      about = "Warm amber accent, heavy text, flat bars." },
    { name = "Midnight Glass", theme = "Midnight",     font = "Poppins SemiBold", outline = "",        texture = "H3z0UI v3",
      about = "Violet accent, clean text, glassy bars." },
    { name = "Mint Classic",   theme = "Classic Mint", font = "H3z0UI",           outline = "OUTLINE", texture = "H3z0UI v5",
      about = "The original H3z0 mint look." },
    { name = "Class Colours",  theme = "Class Colored", font = "Expressway",      outline = "OUTLINE", texture = "Satin",
      about = "Accent follows your class colour." },
}

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function Valid(kind, name)
    local lsm = LSM()
    if not lsm or not name or name == "" then return false end
    return lsm:IsValid(kind, name)
end

local function Core()
    return ns.Addon or (ns.Helpers and ns.Helpers.GetCore and ns.Helpers.GetCore())
end

local function SyncAll(profile, font, outline, texture)
    local function Walk(t, depth)
        if depth > 10 then return end
        for k, v in pairs(t) do
            if type(v) == "table" then
                Walk(v, depth + 1)
            elseif k == "font" and type(v) == "string" and font then
                t[k] = font
            elseif k == "fontOutline" and type(v) == "string" and outline then
                t[k] = outline
            elseif k == "texture" and type(v) == "string" and texture and not v:find("^Interface\\") then
                t[k] = texture
            end
        end
    end
    Walk(profile, 0)
end

local function RefreshEverything()
    local uf = ns.H3z0UI_UnitFrames
    if uf and uf.RefreshAll then pcall(uf.RefreshAll, uf) end
    for _, name in ipairs({
        "H3z0UI_RefreshGroupFrames", "H3z0UI_RefreshNCDM", "H3z0UI_RefreshActionBars", "H3z0UI_RefreshChat",
        "H3z0UI_RefreshInfoBar", "H3z0UI_RefreshDatapanels", "H3z0UI_RefreshMinimap", "H3z0UI_RefreshCastbars",
        "H3z0UI_RefreshBags",
    }) do
        local fn = _G[name]
        if type(fn) == "function" then pcall(fn) end
    end
    if ns.Registry and ns.Registry.RefreshAll then pcall(ns.Registry.RefreshAll, ns.Registry, "skinning") end
end

function Looks.Find(name)
    for _, l in ipairs(Looks.List) do if l.name == name then return l end end
end

-- returns ok, message
function Looks.Apply(name)
    local look = Looks.Find(name)
    local core = Core()
    local db = core and core.db
    if not (look and db) then return false, "That look is not available." end
    if InCombatLockdown() then return false, "Not in combat." end

    local font = Valid("font", look.font) and look.font or nil
    local texture = Valid("statusbar", look.texture) and look.texture or nil
    local skipped = {}
    if not font then skipped[#skipped + 1] = "font " .. look.font end
    if not texture then skipped[#skipped + 1] = "texture " .. look.texture end

    local tools = ns.H3z0UI_ProfileTools
    if tools and tools.Backup then tools.Backup("Before look: " .. look.name) end

    local profile = db.profile
    profile.general = profile.general or {}
    local g = profile.general
    if font then g.font = font end
    if texture then g.texture = texture end
    g.fontOutline = look.outline
    SyncAll(profile, font, look.outline, texture)

    -- accent colour / theme
    if GUI.ResolveThemePreset then
        local r, gr, b = GUI:ResolveThemePreset(look.theme)
        g.themePreset = look.theme
        g.skinUseClassColor = (look.theme == "Class Colored")
        g.addonAccentColor = { r, gr, b, 1 }
        GUI:ApplyAccentColor(r, gr, b)
        if GUI.RefreshAccentColor then GUI:RefreshAccentColor() end
    end

    RefreshEverything()
    local msg = "Applied " .. look.name .. "."
    if #skipped > 0 then msg = msg .. " Not installed, so unchanged: " .. table.concat(skipped, ", ") .. "." end
    return true, msg
end

-- newest backup made by a look, or nil
function Looks.LastBackupIndex()
    local tools = ns.H3z0UI_ProfileTools
    local list = tools and tools.ListBackups() or {}
    for i = #list, 1, -1 do
        if type(list[i].label) == "string" and list[i].label:find("^Before look:") then return i end
    end
end

function Looks.Undo()
    local tools = ns.H3z0UI_ProfileTools
    local i = Looks.LastBackupIndex()
    if not (tools and i) then return false, "No look to undo." end
    local ok, res = tools.Restore(i)
    if ok then tools.DeleteBackup(i); return true, "Went back to how it was before the last look." end
    return false, res
end

---------------------------------------------------------------------------
-- page
---------------------------------------------------------------------------
local function Say(msg) print("|cff60A5FAH3z0UI:|r " .. msg) end

local function BuildLooksContent(content)
    if content._lkHolder then content._lkHolder:Hide(); content._lkHolder:SetParent(nil) end
    local holder = CreateFrame("Frame", nil, content)
    holder:SetAllPoints(content)
    content._lkHolder = holder
    local function Rebuild() BuildLooksContent(content) end

    local W = 640
    local y = -12
    local intro = CreateWrappedLabel(holder,
        "A look sets the accent colour, font, outline and bar texture together and applies them to every module. Your profile is backed up first, so Undo Last Look can bring everything back. Positions, sizes and module switches are not touched.",
        11, C.textMuted, W)
    intro:SetPoint("TOPLEFT", PADDING, y)
    y = y - (intro:GetStringHeight() or 40) - 12

    local undo = GUI:CreateButton(holder, "Undo Last Look", 150, 26, function()
        local ok, msg = Looks.Undo()
        Say(msg)
        Rebuild()
    end)
    undo:SetPoint("TOPLEFT", PADDING, y)
    undo:SetAlpha(Looks.LastBackupIndex() and 1 or 0.4)
    y = y - 42

    local cw, gap = math.floor((W - 12) / 2), 12
    local lsm = LSM()
    for i, look in ipairs(Looks.List) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local card = CreateFrame("Frame", nil, holder)
        card:SetSize(cw, 118)
        card:SetPoint("TOPLEFT", PADDING + col * (cw + gap), y - row * 128)
        local R = ns.Round
        if R and R.Panel then
            local p = R.Panel(card, 10)
            p:SetAllPoints(card)
            p:SetFillColor(1, 1, 1, 0.035)
            p:SetBorderColor(1, 1, 1, 0.07)
        else
            local t = card:CreateTexture(nil, "BACKGROUND")
            t:SetAllPoints()
            t:SetColorTexture(1, 1, 1, 0.035)
        end

        local r, g, b = 1, 1, 1
        if GUI.ResolveThemePreset then r, g, b = GUI:ResolveThemePreset(look.theme) end

        local swatch = card:CreateTexture(nil, "ARTWORK")
        swatch:SetColorTexture(r, g, b, 1)
        swatch:SetSize(4, 40)
        swatch:SetPoint("TOPLEFT", 12, -12)

        local title = card:CreateFontString(nil, "OVERLAY")
        local fontPath = lsm and Valid("font", look.font) and lsm:Fetch("font", look.font) or STANDARD_TEXT_FONT
        title:SetFont(fontPath, 15, look.outline)
        title:SetPoint("TOPLEFT", swatch, "TOPRIGHT", 8, -2)
        title:SetText(look.name)
        title:SetTextColor(1, 1, 1, 1)

        local about = CreateWrappedLabel(card, look.about, 10, C.textMuted, cw - 40)
        about:SetPoint("TOPLEFT", swatch, "TOPRIGHT", 8, -24)

        local bar = CreateFrame("StatusBar", nil, card)
        bar:SetSize(cw - 130, 10)
        bar:SetPoint("BOTTOMLEFT", 14, 14)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(70)
        local texPath = lsm and Valid("statusbar", look.texture) and lsm:Fetch("statusbar", look.texture)
            or "Interface\\Buttons\\WHITE8X8"
        bar:SetStatusBarTexture(texPath)
        bar:SetStatusBarColor(r, g, b, 1)

        local apply = GUI:CreateButton(card, "Apply", 90, 24, function()
            local ok, msg = Looks.Apply(look.name)
            Say(msg)
            if ok then Rebuild() end
        end)
        apply:SetPoint("BOTTOMRIGHT", -12, 9)
    end
    y = y - math.ceil(#Looks.List / 2) * 128

    content:SetHeight(math.abs(y) + 30)
end

ns.H3z0UI_LooksPage = { BuildLooksContent = BuildLooksContent }

if Registry and Schema
    and type(Registry.RegisterFeature) == "function"
    and type(Schema.Feature) == "function"
    and type(Schema.Section) == "function" then
    Registry:RegisterFeature(Schema.Feature({
        id = "looksPage",
        category = "global",
        nav = { tileId = "global", subPageIndex = 9 },
        sections = {
            Schema.Section({
                id = "looksList",
                kind = "page",
                minHeight = 300,
                build = BuildLooksContent,
            }),
        },
    }))
end
