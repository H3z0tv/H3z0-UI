local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors
local Shared = ns.H3z0UI_Options
local Settings = ns.Settings
local Registry = Settings and Settings.Registry
local Schema = Settings and Settings.Schema

local CreateWrappedLabel = Shared.CreateWrappedLabel
local CreateLinkItem = Shared.CreateLinkItem
local PADDING = Shared.PADDING or 15

local function CreateQA(parent, question, answer, y, contentWidth)
    local qLabel = CreateWrappedLabel(parent, question, 12, C.text, contentWidth - PADDING * 2)
    qLabel:SetPoint("TOPLEFT", PADDING, y)
    local qHeight = qLabel:GetStringHeight() or 14
    y = y - qHeight - 4

    local aLabel = CreateWrappedLabel(parent, answer, 11, C.textMuted, contentWidth - PADDING * 2 - 10)
    aLabel:SetPoint("TOPLEFT", PADDING + 10, y)
    local aHeight = aLabel:GetStringHeight() or 14
    y = y - aHeight - 12

    return y
end

local function BuildWelcomeContent(content)
    local y = -10
    local contentWidth = 700

    local version = H3z0UI.versionString or "3.00"
    local title = CreateWrappedLabel(content, ns.L["Welcome to H3z0UI"], 20, C.accent, contentWidth)
    title:SetPoint("TOPLEFT", PADDING, y)
    y = y - 28

    local versionLabel = CreateWrappedLabel(content, "v" .. version, 12, C.textMuted, contentWidth)
    versionLabel:SetPoint("TOPLEFT", PADDING, y)
    y = y - 22

    local tagline = CreateWrappedLabel(content,
        "H3z0 UI: unit, party and raid frames, nameplates, chat, cooldown tracking, action bars, Layout Mode, Bottom Bar, Steam Deck support and quality-of-life features.",
        12, C.textMuted, contentWidth - PADDING * 2)
    tagline:SetPoint("TOPLEFT", PADDING, y)
    y = y - (tagline:GetStringHeight() or 14) - 14

    local AssetPath = ns.Helpers.AssetPath
    local discordItem = CreateLinkItem(content,
        ns.L["|cff5865F2Discord|r"], "https://discord.gg/PU6g3WW",
        0.345, 0.396, 0.949,
        AssetPath .. "discord",
        ns.L["Copy Discord Invite"])
    discordItem:SetPoint("TOPLEFT", PADDING, y)
    discordItem:SetSize(320, 22)

    local githubItem = CreateLinkItem(content,
        "|cffFF0000YouTube|r", "https://www.youtube.com/h3z0music",
        1, 0.2, 0.2,
        nil,
        "Copy YouTube URL")
    githubItem:SetPoint("TOPLEFT", PADDING + 330, y)
    githubItem:SetSize(350, 22)

    y = y - 40

    Shared.CreateAccentDotLabel(content, ns.L["Quick Setup Guide"], y); y = y - 30

    local steps = {
        {num = "1.", text = ns.L["Open |cff60A5FA/h3z0ui|r to browse settings, then use the Search tab if you are not sure where a system lives"]},
        {num = "2.", text = ns.L["If you want a starting point, install a bundled preset from the |cff60A5FAProfiles|r tab or analyze/import a current H3z0UI profile in |cff60A5FAImport & Export Strings|r"]},
        {num = "3.", text = ns.L["Use |cff60A5FA/h3z0ui layout|r or the |cff60A5FAH3z0UI Edit Mode|r button to move H3z0UI-managed frames, then fine-tune anchors and nudges in |cff60A5FAFrame Positioning|r"]},
        {num = "4.", text = ns.L["Use Blizzard Edit Mode only for Blizzard-managed elements that H3z0UI does not replace or anchor for you"]},
        {num = "5.", text = ns.L["Type |cff60A5FA/rl|r after profile imports or larger changes when a module asks for a reload"]},
    }

    for _, step in ipairs(steps) do
        local stepLabel = CreateWrappedLabel(content,
            "|cff60A5FA" .. step.num .. "|r  " .. step.text,
            12, C.text, contentWidth - PADDING * 2 - 10)
        stepLabel:SetPoint("TOPLEFT", PADDING + 10, y)
        y = y - (stepLabel:GetStringHeight() or 14) - 8
    end
    y = y - 12

    Shared.CreateAccentDotLabel(content, ns.L["Frequently Asked Questions"], y); y = y - 30

    y = CreateQA(content,
        ns.L["What is H3z0UI?"],
        "H3z0 UI is a full UI suite: H3z0 unit, party and raid frames, nameplates and chat, Cooldown Manager viewers, action bars, Layout Mode, profile import/export, skinning and quality-of-life modules - all configurable from one options window.",
        y, contentWidth)

    y = CreateQA(content,
        ns.L["How do I move and resize frames?"],
        ns.L["For H3z0UI-managed elements, use the |cff60A5FAH3z0UI Edit Mode|r button or type |cff60A5FA/h3z0ui layout|r to drag frames, then use |cff60A5FAFrame Positioning|r for exact anchors, offsets, and nudging. Use Blizzard Edit Mode only for Blizzard frames that H3z0UI does not replace. You generally do not need to import a separate Edit Mode string to get started anymore."],
        y, contentWidth)

    y = CreateQA(content,
        ns.L["What is H3z0UI Layout Mode?"],
        ns.L["Layout Mode is H3z0UI's drag-and-place workflow for H3z0UI-managed frames. It is the fastest way to get elements roughly where you want them on screen. After that, use |cff60A5FAFrame Positioning|r when you want precise anchors, offsets, and nudge controls instead of freeform dragging."],
        y, contentWidth)

    y = CreateQA(content,
        ns.L["What is the Cooldown Manager (CDM)?"],
        ns.L["The Cooldown Manager powers H3z0UI's essential and utility cooldown viewers, buff trackers, and tracked bars. Use |cff60A5FA/h3z0ui cdm|r to open the CDM Spell Composer and control what gets tracked, then use the Cooldown Manager tab for appearance, glows, keybind text, and custom-entry behavior. If you need Blizzard's viewer settings panel itself, use |cff60A5FA/cdm|r."],
        y, contentWidth)

    y = CreateQA(content,
        "Using an older H3z0 UI profile string?",
        "Use current H3z0 UI profile strings. Older strings can miss settings or conflict with the current defaults.",
        y, contentWidth)

    y = CreateQA(content,
        ns.L["How do I set up keybinds?"],
        ns.L["Type |cff60A5FA/kb|r to open the keybind overlay. Hover over any action button and press a key to bind it. Keybind display settings and override text live in the Cooldown Manager tab under Keybinds."],
        y, contentWidth)

    y = CreateQA(content,
        ns.L["How do I report a bug or get help?"],
        "If something still looks wrong after a reload, enable Lua errors with |cff60A5FA/console scriptErrors 1|r and report it on Discord (https://discord.gg/PU6g3WW). Links with copy buttons are at the top of this page.",
        y, contentWidth)

    y = y - 10

    content:SetHeight(math.abs(y))
end

local function CreateWelcomePage(parent)
    local _, content = Shared.CreateScrollableContent(parent)
    BuildWelcomeContent(content)
end

ns.H3z0UI_WelcomeOptions = {
    BuildWelcomeContent = BuildWelcomeContent,
    CreateWelcomePage = CreateWelcomePage,
}

if Registry and Schema
    and type(Registry.RegisterFeature) == "function"
    and type(Schema.Feature) == "function"
    and type(Schema.Section) == "function" then
    Registry:RegisterFeature(Schema.Feature({
        id = "welcomePage",
        moverKey = "welcome",
        category = "global",
        nav = { tileId = "welcome" },
        noSearch = true,
        sections = {
            Schema.Section({
                id = "settings",
                kind = "page",
                minHeight = 80,
                build = BuildWelcomeContent,
            }),
        },
    }))
end
