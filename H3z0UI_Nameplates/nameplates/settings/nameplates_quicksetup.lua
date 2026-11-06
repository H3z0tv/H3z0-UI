local ADDON_NAME, ns = ...
local H3z0UI = H3z0UI
local GUI = H3z0UI.GUI
local C = GUI.Colors

---------------------------------------------------------------------------
-- Nameplate Quick Setup: 5 short steps with a live preview and ready-made
-- templates. The choices are applied to your nameplate settings straight
-- away so the preview (and the real plates) show them; Cancel puts the old
-- settings back. A backup of the whole profile is made when you start.
---------------------------------------------------------------------------
local Q = {}
ns.H3z0UI_NPQuickSetup = Q
local function P() return ns.H3zPlates end

local TEMPLATES = {
    minimalist = { name = "Minimalist", about = "Thin bars, names only, nothing extra.",
        v = { width = 130, height = 10, nameSize = 10, textSize = 9, showLevel = false, showHealth = false, showPercent = false,
              castHeight = 10, threat = true, arrows = false, auras = "off", auraDispel = false,
              castScale = 1, focusScale = 1, nonTargetAlpha = 1, classScale = false, targetScale = 1.1 } },
    mplus_tank = { name = "Mythic+ Tank", about = "Threat colours, bigger bosses, your debuffs, bigger casters.",
        v = { width = 150, height = 16, nameSize = 11, textSize = 10, showLevel = true, showHealth = true, showPercent = true,
              castHeight = 16, threat = true, arrows = true, auras = "mine", auraDispel = false, auraPandemic = true,
              castScale = 1.15, focusScale = 1, nonTargetAlpha = 1, classScale = true, targetScale = 1.1, interruptReady = true } },
    mplus_dps = { name = "Mythic+ Damage", about = "Interrupt-ready casts, your debuffs, clean bars.",
        v = { width = 140, height = 14, nameSize = 11, textSize = 10, showLevel = true, showHealth = true, showPercent = true,
              castHeight = 16, threat = true, arrows = true, auras = "mine", auraDispel = false, auraPandemic = true,
              castScale = 1.2, focusScale = 1.1, nonTargetAlpha = 1, classScale = true, targetScale = 1.1, interruptReady = true } },
    mplus_healer = { name = "Mythic+ Healer", about = "Dispellable buffs, big casts, friendly names only.",
        v = { width = 140, height = 14, nameSize = 11, textSize = 10, showLevel = false, showHealth = true, showPercent = false,
              castHeight = 16, threat = true, arrows = true, auras = "mine", auraDispel = true, auraPandemic = true,
              castScale = 1.25, focusScale = 1, nonTargetAlpha = 1, classScale = true, targetScale = 1.1, friendlyNamesOnly = true } },
    raid_leader = { name = "Raid Leader", about = "Compact plates, focus stands out, others fade.",
        v = { width = 130, height = 12, nameSize = 10, textSize = 9, showLevel = false, showHealth = true, showPercent = true,
              castHeight = 12, threat = true, arrows = true, auras = "mine", auraDispel = false, auraPandemic = true,
              castScale = 1.1, focusScale = 1.25, nonTargetAlpha = 0.7, classScale = true, targetScale = 1.2 } },
    pvp = { name = "PvP", about = "Class colours, dispellable buffs, big casts.",
        v = { width = 150, height = 16, nameSize = 11, textSize = 10, showLevel = false, showHealth = true, showPercent = true,
              castHeight = 18, threat = false, arrows = true, auras = "mine", auraDispel = true, auraPandemic = true,
              castScale = 1.25, focusScale = 1.15, nonTargetAlpha = 1, classScale = false, targetScale = 1.15,
              friendly = true, friendlyNamesOnly = false, instClassColors = true } },
}
Q.Templates = TEMPLATES
local TEMPLATE_ORDER = { "mplus_tank", "mplus_dps", "mplus_healer", "raid_leader", "pvp", "minimalist" }

local SIZES = {
    compact = { label = "Compact", scale = 0.85 },
    standard = { label = "Standard", scale = 1.0 },
    large = { label = "Large", scale = 1.2 },
}

local function Say(msg) print("|cff34D399H3z0 UI nameplates:|r " .. msg) end

local function CopyTable(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and CopyTable(v) or v end
    return out
end

-- role of the current spec -> a template id
local function AutoTemplate()
    local role
    if GetSpecialization and GetSpecializationRole then
        local i = GetSpecialization()
        if i then role = GetSpecializationRole(i) end
    end
    if role == "TANK" then return "mplus_tank" end
    if role == "HEALER" then return "mplus_healer" end
    return "mplus_dps"
end

-- write a template into the settings; only the keys the template lists change
function Q.ApplyTemplate(id)
    local t = TEMPLATES[id]
    local s = P().GetSettings and P().GetSettings()
    if not (t and s) then return false end
    for k, v in pairs(t.v) do s[k] = v end
    return true
end

local function ApplySize(sizeId, base)
    local s = P().GetSettings()
    local f = SIZES[sizeId] and SIZES[sizeId].scale or 1
    if base then
        s.width = math.floor(base.width * f + 0.5)
        s.height = math.floor(base.height * f + 0.5)
        s.nameSize = math.max(7, math.floor(base.nameSize * f + 0.5))
        s.textSize = math.max(7, math.floor(base.textSize * f + 0.5))
        s.castHeight = math.max(6, math.floor(base.castHeight * f + 0.5))
    end
end

---------------------------------------------------------------------------
-- window
---------------------------------------------------------------------------
local win
local state

local function Refresh()
    if P().Refresh then P().Refresh() end
    if P().RefreshExtras then P().RefreshExtras() end
    if win and win.preview and win.preview.Refresh then pcall(win.preview.Refresh, win.preview) end
end

local STEPS = { "Role", "Size", "Threat and priority", "Auras", "Finish" }

local RenderStep

local function Choice(parent, y, text, about, selected, onClick)
    local b = GUI:CreateButton(parent, text, 190, 28, onClick)
    b:SetPoint("TOPLEFT", 14, y)
    b:SetAlpha(selected and 1 or 0.55)
    local l = GUI:CreateLabel(parent, about or "", 10, C.textMuted)
    l:SetPoint("LEFT", b, "RIGHT", 10, 0)
    l:SetWidth(250)
    l:SetJustifyH("LEFT")
    return b
end

local function Build()
    win = CreateFrame("Frame", "H3z0UI_NPQuickSetup", UIParent)
    win:SetSize(560, 560)
    win:SetPoint("CENTER")
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetFrameLevel(800)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    local bg = win:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.06, 0.08, 0.97)
    win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    win.title:SetPoint("TOPLEFT", 16, -14)
    win.stepText = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    win.stepText:SetPoint("TOPRIGHT", -16, -18)

    if P().CreatePreview then
        win.preview = P().CreatePreview(win)
        win.preview:SetPoint("TOPLEFT", 16, -48)
        win.preview:SetPoint("RIGHT", win, "RIGHT", -16, 0)
    end

    win.body = CreateFrame("Frame", nil, win)
    win.body:SetPoint("TOPLEFT", 16, -214)
    win.body:SetPoint("BOTTOMRIGHT", -16, 56)

    win.back = GUI:CreateButton(win, "Back", 90, 26, function()
        if state.step > 1 then state.step = state.step - 1; RenderStep() end
    end)
    win.back:SetPoint("BOTTOMLEFT", 16, 16)
    win.cancel = GUI:CreateButton(win, "Cancel", 90, 26, function() Q.Cancel() end)
    win.cancel:SetPoint("LEFT", win.back, "RIGHT", 10, 0)
    win.next = GUI:CreateButton(win, "Next", 110, 26, function()
        if state.step < #STEPS then state.step = state.step + 1; RenderStep()
        else Q.Finish() end
    end)
    win.next:SetPoint("BOTTOMRIGHT", -16, 16)
    win:Hide()
end

RenderStep = function()
    local body = win.body
    for _, c in ipairs({ body:GetChildren() }) do c:Hide(); c:SetParent(nil) end
    for _, r in ipairs({ body:GetRegions() }) do r:Hide() end
    win.title:SetText("Nameplate Quick Setup")
    win.stepText:SetText("Step " .. state.step .. " of " .. #STEPS .. ": " .. STEPS[state.step])
    win.back:SetAlpha(state.step > 1 and 1 or 0.4)
    win.next:SetText(state.step == #STEPS and "Finish" or "Next")
    local s = P().GetSettings()
    local y = 0
    local function Again() Refresh(); RenderStep() end

    if state.step == 1 then
        local hint = GUI:CreateLabel(body, "Pick the style that fits how you play. You can change everything afterwards.", 11, C.textMuted)
        hint:SetPoint("TOPLEFT", 14, y)
        y = y - 26
        Choice(body, y, "Automatic (from my spec)", TEMPLATES[AutoTemplate()].name, state.template == "auto", function()
            state.template = "auto"
            Q.ApplyTemplate(AutoTemplate()); state.base = CopyTable(P().GetSettings()); Again()
        end)
        y = y - 34
        for _, id in ipairs(TEMPLATE_ORDER) do
            local t = TEMPLATES[id]
            Choice(body, y, t.name, t.about, state.template == id, function()
                state.template = id
                Q.ApplyTemplate(id); state.base = CopyTable(P().GetSettings()); Again()
            end)
            y = y - 34
        end
    elseif state.step == 2 then
        local hint = GUI:CreateLabel(body, "How big should the plates be?", 11, C.textMuted)
        hint:SetPoint("TOPLEFT", 14, y)
        y = y - 26
        for _, id in ipairs({ "compact", "standard", "large" }) do
            Choice(body, y, SIZES[id].label, "", state.size == id, function()
                state.size = id
                local base = state.base or CopyTable(s)
                ApplySize(id, base); Again()
            end)
            y = y - 34
        end
    elseif state.step == 3 then
        local hint = GUI:CreateLabel(body, "Threat and priority", 11, C.textMuted)
        hint:SetPoint("TOPLEFT", 14, y)
        y = y - 26
        Choice(body, y, s.threat and "Threat border: on" or "Threat border: off", "Red when a non-tank has aggro, orange when a tank lost it.", s.threat, function()
            s.threat = not s.threat; Again()
        end)
        y = y - 34
        Choice(body, y, s.classScale and "Bigger bosses and rares: on" or "Bigger bosses and rares: off", "Bosses and rares get a bigger plate.", s.classScale, function()
            s.classScale = not s.classScale; Again()
        end)
        y = y - 34
        Choice(body, y, s.arrows and "Target arrows: on" or "Target arrows: off", "Arrows beside the plate you target.", s.arrows, function()
            s.arrows = not s.arrows; Again()
        end)
    elseif state.step == 4 then
        local hint = GUI:CreateLabel(body, "Aura icons above the plate.", 11, C.textMuted)
        hint:SetPoint("TOPLEFT", 14, y)
        y = y - 26
        Choice(body, y, "No auras", "", s.auras == "off", function() s.auras = "off"; Again() end)
        y = y - 34
        Choice(body, y, "My debuffs", "Your damage-over-time effects with the time left.", s.auras == "mine" and not s.auraDispel, function()
            s.auras = "mine"; s.auraDispel = false; Again()
        end)
        y = y - 34
        Choice(body, y, "My debuffs + dispellable buffs", "Also enemy buffs you can dispel.", s.auras == "mine" and s.auraDispel, function()
            s.auras = "mine"; s.auraDispel = true; Again()
        end)
        y = y - 34
        Choice(body, y, s.auraPandemic and "Pandemic cue: on" or "Pandemic cue: off", "Gold border in the last 30% of the time (when the game shows the times).", s.auraPandemic, function()
            s.auraPandemic = not s.auraPandemic; Again()
        end)
    else
        local lines = {
            "Style: " .. (state.template == "auto" and TEMPLATES[AutoTemplate()].name or (TEMPLATES[state.template] and TEMPLATES[state.template].name or "your current settings")),
            "Size: " .. (SIZES[state.size] and SIZES[state.size].label or "unchanged"),
            "Threat border: " .. (s.threat and "on" or "off") .. ", bigger bosses/rares: " .. (s.classScale and "on" or "off"),
            "Auras: " .. (s.auras == "off" and "off" or (s.auraDispel and "my debuffs + dispellable buffs" or "my debuffs")),
        }
        local text = GUI:CreateLabel(body, table.concat(lines, "\n") .. "\n\nFinish keeps these settings. Your profile was backed up when you started: General > Profile Tools lists it as 'Before nameplate setup'.", 12, C.text)
        text:SetPoint("TOPLEFT", 14, y)
        text:SetWidth(500)
        text:SetJustifyH("LEFT")
    end
    if win.preview and win.preview.Refresh then pcall(win.preview.Refresh, win.preview) end
end

function Q.Open()
    if InCombatLockdown() then Say("Not in combat.") return end
    local s = P().GetSettings()
    if not s then return end
    if not win then Build() end
    local tools = ns.H3z0UI_ProfileTools
    if tools and tools.Backup then tools.Backup("Before nameplate setup") end
    state = { step = 1, snapshot = CopyTable(s), template = nil, size = nil, base = CopyTable(s) }
    s.enabled = true
    win:Show()
    RenderStep()
    Refresh()
end

function Q.Cancel()
    if state and state.snapshot then
        local s = P().GetSettings()
        for k in pairs(s) do s[k] = nil end
        for k, v in pairs(state.snapshot) do s[k] = v end
        Refresh()
    end
    state = nil
    if win then win:Hide() end
end

function Q.Finish()
    state = nil
    if win then win:Hide() end
    Refresh()
    Say("Setup finished. Open the Nameplates page to fine-tune anything.")
end

_G.H3z0UI_NPQuickSetup_Open = function() return Q.Open() end
