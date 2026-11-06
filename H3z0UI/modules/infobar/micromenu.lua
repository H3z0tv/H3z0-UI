local _, ns = ...
local H3z0UICore = ns.Addon
local Datatexts = H3z0UICore and H3z0UICore.Datatexts
if not Datatexts then return end

local max = math.max
local ipairs = ipairs

local ToggleProfessionsBook = _G.ToggleProfessionsBook
local ToggleQuestLog = _G.ToggleQuestLog
local ToggleEncounterJournal = _G.ToggleEncounterJournal
local C_Texture = _G.C_Texture
local isForever = ns.Client and ns.Client.isLegacy or false

local ATLAS_PREFIX = "UI-HUD-MicroMenu-"

local function ToggleStore()
    local kiosk = _G.Kiosk
    if _G.DISALLOW_FRAME_TOGGLING or (kiosk and kiosk.IsEnabled()) then return end

    local useCatalogShop = _G.C_CatalogShop and _G.C_CatalogShop.IsShop2Enabled()
    local frame = useCatalogShop and _G.CatalogShopFrame or _G.StoreFrame
    if not frame then return end

    local shown = frame:GetAttribute("isshown")
    if not shown then
        local glue = _G.C_Glue
        if not (glue and glue.IsOnGlueScreen()) then
            _G.securecall("CloseAllWindows")
        end
        frame:SetAttribute("contextkey", "StoreMicroButton")
    end
    frame:SetAttribute("action", shown and "Hide" or "Show")
end

local BUTTONS = {
    {
        key = "character", label = ns.L["Character"], portrait = true,
        clickButton = "CharacterMicroButton",   -- always Blizzard's own button (no tainted windows)
        onClick = function() ToggleCharacter("PaperDollFrame") end,
    },
    {
        key = "spellbook", label = ns.L["Spellbook"],
        clickButton = isForever and "SpellbookMicroButton" or "PlayerSpellsMicroButton",
        icon = "Interface\\Spellbook\\Spellbook-Icon",
    },
    {
        key = "talents", label = ns.L["Talents"], atlas = "SpecTalents",
        clickButton = isForever and "TalentMicroButton" or "PlayerSpellsMicroButton",
    },
    {
        key = "professions", label = ns.L["Professions"], atlas = "Professions",
        clickButton = "ProfessionMicroButton",   -- always Blizzard's own button (no tainted windows)
        onClick = function() ToggleProfessionsBook() end,
    },
    {
        key = "achievements", label = ns.L["Achievements"], atlas = "Achievements", forever = false,
        clickButton = "AchievementMicroButton",   -- always Blizzard's own button (no tainted windows)
        onClick = function() ToggleAchievementFrame() end,
    },
    {
        key = "legacy", label = ns.L["Legacy"], atlas = "Legacy", forever = true,
        combatClickButton = "LegacyMicroButton",
        onClick = function() _G.ToggleLegacySystemUI() end,
    },
    {
        key = "questlog", label = ns.L["Quest Log"], atlas = "Questlog",
        clickButton = "QuestLogMicroButton",   -- always Blizzard's own button (no tainted windows)
        onClick = function() ToggleQuestLog() end,
    },
    {
        key = "collections", label = ns.L["Collections"], atlas = "Collections",
        clickButton = "CollectionsMicroButton",   -- always Blizzard's own button (no tainted windows)
        onClick = function() ToggleCollectionsJournal() end,
    },
    {
        key = "lfg", label = ns.L["Group Finder"], atlas = "Groupfinder",
        clickButton = "LFDMicroButton",   -- always Blizzard's own button (no tainted windows)
        onClick = function() (_G.ToggleGroupFinderFrame or _G.PVEFrame_ToggleFrame)() end,
    },
    {
        key = "adventureguide", label = ns.L["Adventure Guide"], atlas = "AdventureGuide",
        clickButton = "EJMicroButton",   -- always Blizzard's own button (no tainted windows)
        onClick = function() ToggleEncounterJournal() end,
    },
    {
        key = "housing", label = ns.L["Housing"], atlas = "Housing",
        clickButton = "HousingMicroButton",   -- always Blizzard's own button (no tainted windows)
        onClick = function()
            local u = _G.HousingFramesUtil
            if u and u.ToggleHousingDashboard then u.ToggleHousingDashboard() end
        end,
    },
    {
        key = "shop", label = ns.L["Shop"], atlas = "Shop",
        combatClickButton = "StoreMicroButton",
        onClick = ToggleStore,
    },
    {
        key = "help", label = ns.L["Support"], atlas = "GameMenu",
        combatClickButton = "HelpMicroButton",
        onClick = function() ToggleHelpFrame() end,
    },
}

local FOREVER_DISABLED_RULES = {
    character = "CharacterPanelDisabled",
    professions = "ProfessionsPanelDisabled",
    questlog = "QuestLogMicrobuttonDisabled",
    housing = "HousingDashboardDisabled",
    lfg = "FinderPanelDisabled",
    collections = "CollectionsPanelDisabled",
    help = "HelpPanelDisabled",
    shop = "StoreDisabled",
}

-- hidden by the user in the settings (these are left out of the bar)
local function IsButtonEnabled(key)
    local db = H3z0UICore.db and H3z0UICore.db.profile
    local mm = db and db.infobar and db.infobar.micromenu
    local buttons = mm and mm.buttons
    return not (buttons and buttons[key] == false)
end

-- can the panel be used right now? When not, the button stays on the bar greyed out and does
-- nothing, and it comes alive again when the panel becomes available
local function IsUsable(def)
    local key = def.key
    if isForever then
        local rule = FOREVER_DISABLED_RULES[key]
        if rule and _G.C_GameRules and Enum and Enum.GameRule then
            local ok, active = pcall(_G.C_GameRules.IsGameRuleActive, Enum.GameRule[rule])
            if ok and active then return false end
        end
        if key == "adventureguide" and _G.GameRulesUtil and _G.GameRulesUtil.EJIsDisabled then
            local ok, off = pcall(_G.GameRulesUtil.EJIsDisabled)
            if ok and off then return false end
        end
    end
    -- the game's own micro button is switched off while the panel is locked (level, store closed ...)
    local blz = _G[def.clickButton or def.combatClickButton or ""]
    if blz and blz.IsEnabled and blz:IsEnabled() == false then return false end
    return true
end

local function ApplyUsable(btn, usable)
    if btn._h3zUsable == usable then return end
    if InCombatLockdown() then return end   -- a secure button is not changed in combat; next pass
    btn._h3zUsable = usable
    local nt = btn.GetNormalTexture and btn:GetNormalTexture()
    local ht = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if nt and nt.SetDesaturated then nt:SetDesaturated(not usable) end
    if btn.icon and btn.icon.SetDesaturated then btn.icon:SetDesaturated(not usable) end
    btn:SetAlpha(usable and 1 or 0.4)
    if ht then ht:SetAlpha(usable and 1 or 0) end
    if usable then btn:Enable() else btn:Disable() end
end

local function IconWidthFor(def, size)
    if def.atlas and C_Texture and C_Texture.GetAtlasInfo then
        local info = C_Texture.GetAtlasInfo(ATLAS_PREFIX .. def.atlas .. "-Up")
        if info and info.width and info.height and info.height > 0 then
            return size * (info.width / info.height)
        end
    end
    return size
end

local function CreateIconButton(parent, def, size)
    local opts = {
        size = size,
        tooltip = def.label,
        tooltipAnchor = "ANCHOR_BOTTOM",
        onClick = def.onClick,
        clickButton = _G[def.clickButton],
        combatClickButton = _G[def.combatClickButton],
        combatGuard = true,
        registerClicks = "AnyUp",
    }
    if def.portrait then
        opts.portrait = true
        opts.squareHighlight = true
    elseif def.icon then
        opts.icon = def.icon
        opts.squareHighlight = true
    else
        opts.atlasTriplet = ATLAS_PREFIX .. def.atlas
    end

    local btn = ns.UIKit.CreateIconButton(parent, opts)
    btn:SetSize(IconWidthFor(def, size), size)
    return btn
end

Datatexts:Register("micromenu", {
    displayName = ns.L["Micro Menu"],
    category = ns.L["Interface"],
    description = "Compact row of interface panel buttons",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        frame._slot = slotFrame

        if slotFrame.text then slotFrame.text:SetText("") end

        local size = max((slotFrame:GetHeight() or 0) - 6, 12)
        local gap = 4
        local inset = 4

        local made = {}
        -- the Legacy button has nothing to show before level 25: it is left out of the bar
        -- until it can be used, and the others close up (it comes back by itself)
        local function HiddenWhenLocked(def) return def.key == "legacy" end

        local function Relayout()
            local x, count = inset, 0
            for _, m in ipairs(made) do
                if m.btn:IsShown() then
                    m.btn:ClearAllPoints()
                    m.btn:SetPoint("LEFT", frame, "LEFT", x, 0)
                    x = x + m.btn:GetWidth() + gap
                    count = count + 1
                end
            end
            local total = (count > 0) and (x - gap + inset) or 1
            slotFrame._h3z0uiFixedWidth = total
            if slotFrame._h3z0uiOnWidthDirty then slotFrame._h3z0uiOnWidthDirty() end
        end

        for _, def in ipairs(BUTTONS) do
            if (def.forever == nil or def.forever == isForever) and IsButtonEnabled(def.key) then
                local btn = CreateIconButton(frame, def, size)
                made[#made + 1] = { btn = btn, def = def }
                local usable = IsUsable(def)
                ApplyUsable(btn, usable)
                if HiddenWhenLocked(def) and not usable then btn:Hide() end
            end
        end
        Relayout()

        -- look again every second (level ups, the store opening, game rules changing)
        local acc = 0
        frame:SetScript("OnUpdate", function(_, el)
            acc = acc + el
            if acc < 1 then return end
            acc = 0
            if InCombatLockdown() then return end
            local changed = false
            for _, m in ipairs(made) do
                local usable = IsUsable(m.def)
                if HiddenWhenLocked(m.def) then
                    if usable and not m.btn:IsShown() then m.btn:Show() changed = true
                    elseif not usable and m.btn:IsShown() then m.btn:Hide() changed = true end
                end
                ApplyUsable(m.btn, usable)
            end
            if changed then Relayout() end
        end)

        return frame
    end,

    OnDisable = function(frame)
        if frame and frame._slot then
            frame._slot._h3z0uiFixedWidth = nil
            if frame._slot._h3z0uiOnWidthDirty then frame._slot._h3z0uiOnWidthDirty() end
        end
    end,
})
