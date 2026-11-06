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

---------------------------------------------------------------------------
-- 0.25.5 look: one big H3z0 logo behind the page, a hero card, numbered
-- step cards and FAQ cards. Text and links are the same as before.
---------------------------------------------------------------------------
local LOGO = "Interface\\AddOns\\H3z0UI\\assets\\h3z0ui_logo_bg.png"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function Accent()
    local a = C.accent or { 0.204, 0.827, 0.6, 1 }
    return a[1], a[2], a[3]
end

local function AccentHex()
    local r, g, b = Accent()
    return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- the old texts colour their keywords blue: use the theme accent instead
local function Recolor(text)
    return (text:gsub("|cff60A5FA", "|cff" .. AccentHex()))
end

-- rounded card (falls back to a flat one)
local function Card(parent, w, fillA, borderA, radius)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 10)
    local R = ns.Round
    if R and R.Panel then
        local p = R.Panel(f, radius or 10)
        p:SetAllPoints(f)
        p:SetFrameLevel(f:GetFrameLevel())
        p:SetFillColor(1, 1, 1, fillA or 0.035)
        p:SetBorderColor(1, 1, 1, borderA or 0.07)
        f._panel = p
    else
        local t = f:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(1, 1, 1, fillA or 0.035)
    end
    return f
end

local function Badge(parent, text, size)
    local r, g, b = Accent()
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local R = ns.Round
    if R and R.Panel then
        local p = R.Panel(f, math.floor(size / 2))
        p:SetAllPoints(f)
        p:SetFillColor(r, g, b, 0.16)
        p:SetBorderColor(r, g, b, 0.55)
    else
        local t = f:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(r, g, b, 0.16)
    end
    local fs = CreateWrappedLabel(f, text, math.floor(size * 0.5), { r, g, b, 1 })
    fs:SetWordWrap(false)
    fs:SetJustifyH("CENTER")
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", 0, 0)
    return f
end

local function SectionTitle(parent, text, y, w)
    local r, g, b = Accent()
    local bar = parent:CreateTexture(nil, "ARTWORK")
    bar:SetTexture(WHITE)
    bar:SetVertexColor(r, g, b, 1)
    bar:SetSize(3, 16)
    bar:SetPoint("TOPLEFT", PADDING, y)
    local fs = CreateWrappedLabel(parent, text, 15, C.text)
    fs:SetWordWrap(false)
    fs:SetPoint("LEFT", bar, "RIGHT", 8, 0)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 12, 0)
    line:SetPoint("RIGHT", parent, "TOPLEFT", PADDING + w, y - 8)
    line:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.45), CreateColor(r, g, b, 0))
    return y - 30
end

local function BuildWelcomeContent(content)
    local y = -8
    local cw = content.GetWidth and content:GetWidth() or 0
    if not cw or cw < 300 then cw = 720 end
    local W = math.min(cw - PADDING * 2, 860)
    local r, g, b = Accent()

    -- one big logo behind the whole page
    local logo = content:CreateTexture(nil, "BACKGROUND", nil, -7)
    logo:SetTexture(LOGO)
    logo:SetSize(W * 0.92, W * 0.46)
    logo:SetPoint("TOP", content, "TOPLEFT", PADDING + W / 2, -150)
    logo:SetAlpha(0.06)

    -----------------------------------------------------------------------
    -- hero
    -----------------------------------------------------------------------
    local hero = Card(content, W, 0.04, 0.08, 14)
    hero:SetPoint("TOPLEFT", PADDING, y)
    local glow = hero:CreateTexture(nil, "BORDER")
    glow:SetTexture(WHITE)
    glow:SetPoint("TOPLEFT", 6, -6)
    glow:SetPoint("BOTTOMRIGHT", -6, 6)
    glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.16), CreateColor(r, g, b, 0))
    local heroLogo = hero:CreateTexture(nil, "ARTWORK")
    heroLogo:SetTexture(LOGO)
    heroLogo:SetSize(150, 75)
    heroLogo:SetPoint("RIGHT", hero, "RIGHT", -24, 6)
    heroLogo:SetAlpha(0.9)

    local version = H3z0UI.versionString or "0.25.5"
    local hy = -20
    local kicker = CreateWrappedLabel(hero, ns.L["Welcome to H3z0UI"], 11, C.textMuted)
    kicker:SetWordWrap(false)
    kicker:SetPoint("TOPLEFT", 22, hy)
    hy = hy - 18
    local title = CreateWrappedLabel(hero, "H3z0 UI", 30, { r, g, b, 1 })
    title:SetWordWrap(false)
    title:SetPoint("TOPLEFT", 22, hy)
    local pill = Card(hero, 70, 0.0, 0.0, 9)
    pill:SetSize(64, 20)
    if pill._panel then pill._panel:SetFillColor(r, g, b, 0.18); pill._panel:SetBorderColor(r, g, b, 0.6) end
    local pillText = CreateWrappedLabel(pill, "v" .. version, 11, { r, g, b, 1 })
    pillText:SetWordWrap(false)
    pillText:SetJustifyH("CENTER")
    pillText:ClearAllPoints()
    pillText:SetPoint("CENTER")
    pill:SetWidth(math.max(56, (pillText:GetStringWidth() or 40) + 20))
    pill:SetPoint("LEFT", title, "RIGHT", 12, -2)
    hy = hy - 40
    local tagline = CreateWrappedLabel(hero,
        "Unit, party and raid frames, nameplates, chat, cooldown tracking, action bars, Layout Mode, Bottom Bar, Steam Deck support and quality-of-life features - one clean UI.",
        12, C.textMuted, W - 230)
    tagline:SetPoint("TOPLEFT", 22, hy)
    hy = hy - (tagline:GetStringHeight() or 14) - 16

    local AssetPath = ns.Helpers.AssetPath
    local discordItem = CreateLinkItem(hero,
        ns.L["|cff5865F2Discord|r"], "https://discord.gg/PU6g3WW",
        0.345, 0.396, 0.949,
        AssetPath .. "discord",
        ns.L["Copy Discord Invite"])
    discordItem:SetPoint("TOPLEFT", 22, hy)
    discordItem:SetSize(320, 22)
    local ytItem = CreateLinkItem(hero,
        "|cffFF0000YouTube|r", "https://www.youtube.com/h3z0music",
        1, 0.2, 0.2,
        nil,
        "Copy YouTube URL")
    ytItem:SetPoint("TOPLEFT", 22, hy - 28)
    ytItem:SetSize(350, 22)
    local twitchItem = CreateLinkItem(hero,
        "|cff9146FFTwitch|r", "https://twitch.tv/h3z0",
        0.569, 0.275, 1,
        nil,
        "Copy Twitch URL")
    twitchItem:SetPoint("TOPLEFT", 22, hy - 56)
    twitchItem:SetSize(350, 22)
    hy = hy - 56 - 22 - 18
    hero:SetHeight(-hy)
    y = y - (-hy) - 24

    -----------------------------------------------------------------------
    -- quick setup: numbered step cards, two per row
    -----------------------------------------------------------------------
    y = SectionTitle(content, ns.L["Quick Setup Guide"], y, W)
    local steps = {
        ns.L["Open |cff60A5FA/h3z0ui|r to browse settings, then use the Search tab if you are not sure where a system lives"],
        ns.L["If you want a starting point, install a bundled preset from the |cff60A5FAProfiles|r tab or analyze/import a current H3z0UI profile in |cff60A5FAImport & Export Strings|r"],
        ns.L["Use |cff60A5FA/h3z0ui layout|r or the |cff60A5FAH3z0UI Edit Mode|r button to move H3z0UI-managed frames, then fine-tune anchors and nudges in |cff60A5FAFrame Positioning|r"],
        ns.L["Use Blizzard Edit Mode only for Blizzard-managed elements that H3z0UI does not replace or anchor for you"],
        ns.L["Type |cff60A5FA/rl|r after profile imports or larger changes when a module asks for a reload"],
    }
    local GAP = 12
    local colW = math.floor((W - GAP) / 2)
    local i = 1
    while i <= #steps do
        local rowH = 0
        local cards = {}
        for c = 0, 1 do
            local idx = i + c
            if steps[idx] then
                local last = (idx == #steps) and (c == 0)
                local cwid = last and W or colW
                local card = Card(content, cwid, 0.04, 0.07, 10)
                card:SetPoint("TOPLEFT", PADDING + c * (colW + GAP), y)
                local badge = Badge(card, tostring(idx), 26)
                badge:SetPoint("TOPLEFT", 14, -14)
                local txt = CreateWrappedLabel(card, Recolor(steps[idx]), 12, C.text, cwid - 14 - 26 - 12 - 16)
                txt:SetPoint("TOPLEFT", badge, "TOPRIGHT", 12, -2)
                local h = math.max(54, (txt:GetStringHeight() or 14) + 30)
                rowH = math.max(rowH, h)
                cards[#cards + 1] = card
                if last then break end
            end
        end
        for _, card in ipairs(cards) do card:SetHeight(rowH) end
        y = y - rowH - GAP
        i = i + #cards
    end
    y = y - 14

    -----------------------------------------------------------------------
    -- FAQ cards
    -----------------------------------------------------------------------
    y = SectionTitle(content, ns.L["Frequently Asked Questions"], y, W)
    local faq = {
        { ns.L["What is H3z0UI?"],
          "H3z0 UI is a full UI suite: H3z0 unit, party and raid frames, nameplates and chat, Cooldown Manager viewers, action bars, Layout Mode, profile import/export, skinning and quality-of-life modules - all configurable from one options window." },
        { ns.L["How do I move and resize frames?"],
          ns.L["For H3z0UI-managed elements, use the |cff60A5FAH3z0UI Edit Mode|r button or type |cff60A5FA/h3z0ui layout|r to drag frames, then use |cff60A5FAFrame Positioning|r for exact anchors, offsets, and nudging. Use Blizzard Edit Mode only for Blizzard frames that H3z0UI does not replace. You generally do not need to import a separate Edit Mode string to get started anymore."] },
        { ns.L["What is H3z0UI Layout Mode?"],
          ns.L["Layout Mode is H3z0UI's drag-and-place workflow for H3z0UI-managed frames. It is the fastest way to get elements roughly where you want them on screen. After that, use |cff60A5FAFrame Positioning|r when you want precise anchors, offsets, and nudge controls instead of freeform dragging."] },
        { ns.L["What is the Cooldown Manager (CDM)?"],
          ns.L["The Cooldown Manager powers H3z0UI's essential and utility cooldown viewers, buff trackers, and tracked bars. Use |cff60A5FA/h3z0ui cdm|r to open the CDM Spell Composer and control what gets tracked, then use the Cooldown Manager tab for appearance, glows, keybind text, and custom-entry behavior. If you need Blizzard's viewer settings panel itself, use |cff60A5FA/cdm|r."] },
        { "Using an older H3z0 UI profile string?",
          "Use current H3z0 UI profile strings. Older strings can miss settings or conflict with the current defaults." },
        { ns.L["How do I set up keybinds?"],
          ns.L["Type |cff60A5FA/kb|r to open the keybind overlay. Hover over any action button and press a key to bind it. Keybind display settings and override text live in the Cooldown Manager tab under Keybinds."] },
        { ns.L["How do I report a bug or get help?"],
          "If something still looks wrong after a reload, enable Lua errors with |cff60A5FA/console scriptErrors 1|r and report it on Discord (https://discord.gg/PU6g3WW). Links with copy buttons are at the top of this page." },
    }
    for _, qa in ipairs(faq) do
        local card = Card(content, W, 0.03, 0.06, 10)
        card:SetPoint("TOPLEFT", PADDING, y)
        local edge = card:CreateTexture(nil, "ARTWORK")
        edge:SetTexture(WHITE)
        edge:SetVertexColor(r, g, b, 0.85)
        edge:SetWidth(3)
        edge:SetPoint("TOPLEFT", 10, -12)
        edge:SetPoint("BOTTOMLEFT", 10, 12)
        local q = CreateWrappedLabel(card, Recolor(qa[1]), 13, C.text, W - 44)
        q:SetPoint("TOPLEFT", 24, -12)
        local a = CreateWrappedLabel(card, Recolor(qa[2]), 11, C.textMuted, W - 44)
        a:SetPoint("TOPLEFT", q, "BOTTOMLEFT", 0, -6)
        local h = 12 + (q:GetStringHeight() or 14) + 6 + (a:GetStringHeight() or 14) + 14
        card:SetHeight(h)
        y = y - h - 10
    end

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
