---------------------------------------------------------------------------
-- H3z0 UI - Lorekeeper
-- Style "Scroll" (default): talking to NPCs and quests on a parchment scroll on
-- the right of the screen instead of Blizzard's gossip and quest windows
-- (H3z0 UI's own parchment art, assets\lorekeeper):
--   * the camera moves in on the NPC while you talk (and back afterwards)
--   * the text writes itself out (typewriter), long texts are split in pages
--   * numbered choices: keys 1-9 pick, Space continues / accepts / completes,
--     Esc says goodbye (or declines a quest)
--   * quests show their objectives, rewards (hover for the tooltip, click to
--     choose your reward), required items, gold and experience
--   * the rest of the UI can fade out while you talk
--   * a short setup the first time, every option on the Lorekeeper page
--     (Interface tab)
-- Turning Lorekeeper on or off takes effect after a reload (Blizzard's windows
-- are switched off at login).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

local Lorekeeper = {}
ns.H3z0Lorekeeper = Lorekeeper

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = true, setupDone = false, style = "scroll",
    camera = true, cameraDistance = 4,
    hideUI = true, animate = true,
    typewriter = true, typeSpeed = 60,
    fontSize = 18, titleSize = 24, npcSize = 17, optionSize = 18, rewardSize = 14, buttonSize = 16,
    scale = 1, width = 760, minHeight = 720, offsetX = 180, offsetY = 40, bgAlpha = 1,
    showNpcName = true, keyHints = true,
    numberKeys = true, spaceKey = true, spaceSelectsFirst = true,
    autoSelectSingle = false, showObjectives = true,
    pageSound = true,
    controller = true,
    inputDevice = "auto",
    markSellPrice = true, markUpgrade = true, simpleCurrency = false,
    hideNames = false, cameraFocus = true,
}

local function DB()
    return Helpers and Helpers.GetModuleDB and Helpers.GetModuleDB("lorekeeper")
end

local function Get(key)
    local db = DB()
    local v = db and db[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

-- 0.28.2 made the scroll bigger by default. A saved profile keeps the old default
-- numbers, so the ones still equal to the old defaults are moved to the new ones (once).
local OLD_NEW = { width = { 600, 760 }, minHeight = { 640, 720 }, fontSize = { 16, 18 }, titleSize = { 21, 24 },
    npcSize = { 15, 17 }, optionSize = { 16, 18 }, rewardSize = { 13, 14 }, buttonSize = { 15, 16 }, cameraDistance = { 5, 4 } }
local function MigrateSizes()
    local db = DB()
    if not db or db.sizeStep == 282 then return end
    db.sizeStep = 282
    for key, pair in pairs(OLD_NEW) do
        if db[key] == nil or tonumber(db[key]) == pair[1] then db[key] = pair[2] end
    end
end

local function On() return Get("enabled") ~= false and Get("style") ~= "window" end
local function WindowStyle() return Get("style") == "window" end
local function WindowModule() return ns.H3z0LorekeeperWindow end

-- the parchment art (H3z0 UI's own)
local ART = "Interface\\AddOns\\H3z0UI\\assets\\lorekeeper\\"
-- ink colours on the parchment
local INK = { 0.20, 0.12, 0.05 }
local INK_TITLE = { 0.42, 0.13, 0.05 }
local INK_SOFT = { 0.33, 0.22, 0.11 }

local function Font()
    return (Helpers and Helpers.GetGeneralFont and Helpers.GetGeneralFont()) or STANDARD_TEXT_FONT
end

local function Accent()
    local C = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    local a = C and C.accent
    if a then return a[1], a[2], a[3] end
    return 0.204, 0.827, 0.6
end

-- In dungeons, raids and Mythic+ the game can hand out "secret" values (the
-- NPC's name, sometimes texts) that can't be compared or measured. Every text
-- Lorekeeper reads goes through these, so a secret value never stops the scroll.
local function IsSecret(v)
    return issecretvalue ~= nil and v ~= nil and issecretvalue(v) or false
end
local function Str(v)
    if v == nil or IsSecret(v) or type(v) ~= "string" then return "" end
    return v
end
local function Num(v)
    if v == nil or IsSecret(v) or type(v) ~= "number" then return 0 end
    return v
end

-- Sizes of texts. After a text came from a secret value (or when the game was
-- tainted by another addon's click, e.g. a quest popup in the tracker) the game
-- may hand back a secret size that can't be added up. Then the size is worked
-- out from the font size and the length of the text instead.
local function FontSize(fs)
    local ok, _, size = pcall(fs.GetFont, fs)
    if ok and type(size) == "number" and not IsSecret(size) then return size end
    return 14
end
local function StrH(fs, text, width)
    local ok, h = pcall(fs.GetStringHeight, fs)
    if ok and type(h) == "number" and not IsSecret(h) then return h end
    local size = FontSize(fs)
    local lines = 1
    if type(text) == "string" and width and width > 0 then
        lines = math.max(1, math.ceil(#text * size * 0.52 / width))
    end
    return lines * size * 1.3
end
local function StrW(fs, text)
    local ok, w = pcall(fs.GetStringWidth, fs)
    if ok and type(w) == "number" and not IsSecret(w) then return w end
    return (type(text) == "string" and #text or 8) * FontSize(fs) * 0.55
end

---------------------------------------------------------------------------
-- Camera: move in on the NPC, back to where it was afterwards
---------------------------------------------------------------------------
local savedZoom
local FOCUS_STATIC = { test_cameraTargetFocusInteractEnable = "1", test_cameraTargetFocusInteractStrengthYaw = "0",
    CameraKeepCharacterCentered = "0", test_cameraHeadMovementStrength = "0" }
local PITCH_CV, SHOULDER_CV = "test_cameraTargetFocusInteractStrengthPitch", "test_cameraOverShoulder"

-- The camera moves toward the NPC smoothly: the game's interact focus (look at the NPC)
-- fades in and the camera slides to the side, so you and the NPC are on the left of the
-- screen and the scroll on the right. Everything it changes is written down and put back.
local focus = { backup = nil, mode = nil, t = 0, dur = 1, pitch = 0, shoulder = 0, toPitch = 1, toShoulder = 0,
    fromPitch = 0, fromShoulder = 0 }
local focusFrame = CreateFrame("Frame")
focusFrame:Hide()

local function CV(name)
    local ok, v = pcall(GetCVar, name)
    if ok then return v end
end
local function SetCV(name, value) pcall(SetCVar, name, tostring(value)) end

local function DynamicCamHold(on)
    local dc = _G.DynamicCam
    if type(dc) ~= "table" then return end
    local fn = on and dc.BlockShoulderOffsetZoom or dc.AllowShoulderOffsetZoom
    if type(fn) == "function" then pcall(fn, dc) end
end

focusFrame:SetScript("OnUpdate", function(self, elapsed)
    if not focus.mode then self:Hide() return end
    focus.t = focus.t + elapsed
    local p = math.min(1, focus.t / focus.dur)
    local e = math.sin(p * math.pi / 2)
    focus.pitch = focus.fromPitch + (focus.toPitch - focus.fromPitch) * e
    focus.shoulder = focus.fromShoulder + (focus.toShoulder - focus.fromShoulder) * e
    SetCV(PITCH_CV, focus.pitch)
    SetCV(SHOULDER_CV, focus.shoulder)
    if p >= 1 then
        local mode = focus.mode
        focus.mode = nil
        self:Hide()
        if mode == "out" and focus.backup then
            for cv, val in pairs(focus.backup) do SetCV(cv, val) end
            focus.backup = nil
            DynamicCamHold(false)
        end
    end
end)

local function FocusIn(zoom)
    if Get("cameraFocus") == false then return end
    if not focus.backup then
        local bk = {}
        for cv in pairs(FOCUS_STATIC) do
            local cur = CV(cv)
            if cur ~= nil then bk[cv] = cur end
        end
        local sp, ss = CV(PITCH_CV), CV(SHOULDER_CV)
        if sp == nil and ss == nil and CV("test_cameraTargetFocusInteractEnable") == nil then return end   -- not in this game
        if sp ~= nil then bk[PITCH_CV] = sp end
        if ss ~= nil then bk[SHOULDER_CV] = ss end
        focus.backup = bk
        DynamicCamHold(true)
        for cv, val in pairs(FOCUS_STATIC) do if bk[cv] ~= nil then SetCV(cv, val) end end
        focus.pitch, focus.shoulder = 0, tonumber(ss) or 0
    end
    focus.fromPitch, focus.fromShoulder = focus.pitch, focus.shoulder
    focus.toPitch = 1
    -- the further the camera is from you, the more it has to slide to the side
    focus.toShoulder = math.max(0.4, (zoom or 5) * 0.33)
    focus.mode, focus.t, focus.dur = "in", 0, 1.0
    focusFrame:Show()
end

local function FocusOut()
    if not focus.backup then return end
    focus.fromPitch, focus.fromShoulder = focus.pitch, focus.shoulder
    focus.toPitch = tonumber(focus.backup[PITCH_CV]) or 0
    focus.toShoulder = tonumber(focus.backup[SHOULDER_CV]) or 0
    focus.mode, focus.t, focus.dur = "out", 0, 0.5
    focusFrame:Show()
end

local function CameraIn()
    if not Get("camera") then return end
    if not (UnitExists("npc") and not UnitIsUnit("npc", "player")) then return end
    local want = math.max(1, math.min(20, tonumber(Get("cameraDistance")) or 4))
    FocusIn(want)
    -- DynamicCam does its own zooming for talks; two addons zooming at once makes the camera jump
    if savedZoom or type(_G.DynamicCam) == "table" then return end
    if not (GetCameraZoom and CameraZoomIn and CameraZoomOut) then return end
    local zoom = GetCameraZoom()
    if not zoom then return end
    savedZoom = zoom
    -- the game moves the zoom smoothly by itself
    if zoom > want then CameraZoomIn(zoom - want) elseif zoom < want then CameraZoomOut(want - zoom) end
end

local function CameraOut()
    FocusOut()
    if not savedZoom then return end
    local want, zoom = savedZoom, GetCameraZoom and GetCameraZoom()
    savedZoom = nil
    if not zoom then return end
    if zoom > want then CameraZoomIn(zoom - want) elseif zoom < want then CameraZoomOut(want - zoom) end
end

---------------------------------------------------------------------------
-- Hide the rest of the UI while talking (not in combat)
---------------------------------------------------------------------------
local faded = {}
local panel
local KEEP = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4", "H3z0UI_PopupFrame",
    "H3z0UI_LorekeeperSetup", "H3z0UI_LorekeeperHolder", "H3z0UI_ArcanumToasts", "H3z0UI_HeraldHolder" }

local keepSet
local hooked = setmetatable({}, { __mode = "k" })
local holding = false

-- When another part of the UI sets the alpha of a hidden frame again (bars and frames that
-- fade in when you move), the new value is written down as "what it should be afterwards"
-- and the frame is put back to 0 at once, in the same moment, so nothing flashes.
local function Hook(f)
    if hooked[f] or not f.SetAlpha then return end
    hooked[f] = true
    pcall(hooksecurefunc, f, "SetAlpha", function(self, a)
        if not holding or hooked[self] ~= true or faded[self] == nil then return end
        if type(a) ~= "number" or a <= 0 or InCombatLockdown() then return end
        faded[self] = a
        hooked[self] = "busy"
        pcall(self.SetAlpha, self, 0)
        hooked[self] = true
    end)
end

local function HideScan()
    if not keepSet then keepSet = {} end
    for _, name in ipairs(KEEP) do if _G[name] then keepSet[_G[name]] = true end end
    if panel then keepSet[panel] = true end
    for _, f in ipairs({ UIParent:GetChildren() }) do
        if not keepSet[f] and not (f.IsForbidden and f:IsForbidden()) and f:IsShown() then
            local ok, a = pcall(f.GetAlpha, f)
            if ok and a and a > 0 then
                local was = faded[f]
                if pcall(f.SetAlpha, f, 0) then
                    if was == nil then faded[f] = a end
                    Hook(f)
                end
            end
        end
    end
end

-- frames that appear while the scroll is open are hidden too
local holdFrame = CreateFrame("Frame")
holdFrame:Hide()
local holdT = 0
holdFrame:SetScript("OnUpdate", function(self, elapsed)
    holdT = holdT + elapsed
    if holdT < 0.25 then return end
    holdT = 0
    if not next(faded) or InCombatLockdown() or not (panel and panel:IsShown()) then return end
    HideScan()
end)

local function FadeUI()
    if not Get("hideUI") or InCombatLockdown() or next(faded) then return end
    holding = true
    HideScan()
    holdFrame:Show()
end

local function RestoreUI()
    holding = false
    holdFrame:Hide()
    for f, a in pairs(faded) do
        local ok, now = pcall(f.GetAlpha, f)
        if ok and now == 0 then pcall(f.SetAlpha, f, a) end
    end
    wipe(faded)
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local MAX_PAGE = 420
local state = { mode = nil, pages = {}, page = 1, choice = nil, typing = false }
local optionPool, rewardPool = {}, {}

local function SetFont(fs, size, flags)
    if Helpers and Helpers.ApplyFontWithFallback then
        Helpers.ApplyFontWithFallback(fs, Font(), size, flags or "")
    else
        fs:SetFont(Font(), size, flags or "")
    end
end

---------------------------------------------------------------------------
-- Hide the names above other players and NPCs while talking. The values they had are
-- written down in the saved settings first, so they come back even after a crash.
---------------------------------------------------------------------------
local NAME_CVARS = { "UnitNameFriendlyPlayerName", "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName",
    "UnitNameFriendlyTotemName", "UnitNameFriendlyMinionName", "UnitNameEnemyPlayerName", "UnitNameEnemyPetName",
    "UnitNameEnemyGuardianName", "UnitNameEnemyTotemName", "UnitNameNPC", "UnitNameNonCombatCreatureName" }
local namesWaiting

local function ShowNames()
    local db = DB()
    local saved = db and db.savedNames
    if not saved then return end
    if InCombatLockdown() then
        if not namesWaiting then
            namesWaiting = CreateFrame("Frame")
            namesWaiting:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                local d = DB()
                if d and d.savedNames then
                    for cv, val in pairs(d.savedNames) do pcall(SetCVar, cv, val) end
                    d.savedNames = nil
                end
            end)
        end
        namesWaiting:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    for cv, val in pairs(saved) do pcall(SetCVar, cv, val) end
    db.savedNames = nil
end

local function HideNames()
    if Get("hideNames") ~= true or InCombatLockdown() then return end
    local db = DB()
    if not db or db.savedNames then return end
    local saved = {}
    for _, cv in ipairs(NAME_CVARS) do
        local cur = GetCVar and GetCVar(cv)
        if cur ~= nil and cur ~= "0" then
            saved[cv] = cur
            pcall(SetCVar, cv, "0")
        end
    end
    if next(saved) then db.savedNames = saved end
end

local function SplitPages(text)
    local pages = {}
    text = (text or ""):gsub("\r", "")
    if text == "" then return { "" } end
    local cur = ""
    for para in (text .. "\n\n"):gmatch("(.-)\n\n+") do
        if para ~= "" then
            if cur ~= "" and (#cur + #para) > MAX_PAGE then
                pages[#pages + 1] = cur
                cur = para
            else
                cur = (cur == "") and para or (cur .. "\n\n" .. para)
            end
        end
    end
    if cur ~= "" then pages[#pages + 1] = cur end
    if #pages == 0 then pages[1] = text end
    return pages
end

-- typewriter: reveals the text with an alpha gradient. The whole text is shown
-- by putting the gradient start past the end (a length of 0 is not allowed).
local typer = CreateFrame("Frame")
typer:Hide()
local typePos, typeLen = 0, 0

local function ShowAllText()
    if not panel then return end
    local n = #(panel.body:GetText() or "")
    pcall(panel.body.SetAlphaGradient, panel.body, n + 1, 1)
end

typer:SetScript("OnUpdate", function(self, elapsed)
    if not panel then self:Hide() return end
    typePos = typePos + elapsed * (tonumber(Get("typeSpeed")) or 60)
    if typePos >= typeLen then
        state.typing = false
        self:Hide()
        ShowAllText()
        return
    end
    pcall(panel.body.SetAlphaGradient, panel.body, math.max(0, math.floor(typePos)), 24)
end)

local function StopTyping()
    typer:Hide()
    state.typing = false
    ShowAllText()
end

local function StartTyping(text)
    if not Get("typewriter") or #text == 0 then StopTyping() return end
    typePos, typeLen = 0, #text
    state.typing = true
    pcall(panel.body.SetAlphaGradient, panel.body, 0, 24)
    typer:Show()
end

local Render

local function KeyBadge(parent)
    local k = CreateFrame("Frame", nil, parent)
    k:SetSize(24, 24)
    k.tex = k:CreateTexture(nil, "ARTWORK")
    k.tex:SetAllPoints()
    k.tex:SetTexture(ART .. "lore_key")
    k.text = k:CreateFontString(nil, "OVERLAY")
    k.text:SetPoint("CENTER", 0, 0)
    -- a controller button picture (Xbox, PlayStation, Switch) shown instead of the key
    k.glyph = k:CreateTexture(nil, "OVERLAY")
    k.glyph:SetAllPoints()
    k.glyph:Hide()
    return k
end

local function OptionButton(i)
    local b = optionPool[i]
    if b then return b end
    b = CreateFrame("Button", nil, panel.content)
    b:SetHeight(34)
    b.band = b:CreateTexture(nil, "BACKGROUND")
    b.band:SetAllPoints()
    b.band:SetTexture(ART .. "lore_band")
    b.hl = b:CreateTexture(nil, "BORDER")
    b.hl:SetAllPoints(b.band)
    b.hl:SetTexture(ART .. "lore_band")
    b.hl:SetBlendMode("ADD")
    b.hl:SetAlpha(0)
    b.badge = KeyBadge(b)
    b.badge:SetPoint("LEFT", 8, 0)
    b.key = b.badge.text
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", b.badge, "RIGHT", 8, 0)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.text:SetPoint("RIGHT", -10, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(true)
    b:SetScript("OnEnter", function(self) self.hl:SetAlpha(0.35) end)
    b:SetScript("OnLeave", function(self) self.hl:SetAlpha(0) end)
    b:SetScript("OnClick", function(self) if self.run then self.run() end end)
    optionPool[i] = b
    return b
end

local function RewardButton(i)
    local b = rewardPool[i]
    if b then return b end
    b = CreateFrame("Button", nil, panel.content)
    b:SetSize(196, 36)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(1, 1, 1, 0.04)
    b.sel = b:CreateTexture(nil, "BORDER")
    b.sel:SetAllPoints()
    -- a frame around the reward: faint on a reward you can choose, strong on the chosen one
    b.edges = {}
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
                         { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil } }) do
        local tx = b:CreateTexture(nil, "OVERLAY")
        tx:SetPoint(e[1]); tx:SetPoint(e[2])
        if e[3] then tx:SetWidth(e[3]) else tx:SetHeight(e[4]) end
        tx:SetColorTexture(1, 1, 1, 0)
        b.edges[#b.edges + 1] = tx
    end
    b.check = b:CreateTexture(nil, "OVERLAY", nil, 3)
    b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    b.check:SetSize(22, 22)
    b.check:SetPoint("TOPRIGHT", b, "TOPRIGHT", 2, 2)
    b.check:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(30, 30)
    b.icon:SetPoint("LEFT", 3, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 0, 1)
    -- helpers on a reward you can choose: a coin on the one that sells highest,
    -- a green arrow on gear that is better than what you wear
    b.coin = b:CreateTexture(nil, "OVERLAY", nil, 4)
    b.coin:SetTexture(ART .. "lore_coin")
    b.coin:SetSize(16, 16)
    b.coin:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -3, 3)
    b.coin:Hide()
    b.up = b:CreateTexture(nil, "OVERLAY", nil, 4)
    b.up:SetTexture(ART .. "lore_upgrade")
    b.up:SetSize(16, 16)
    b.up:SetPoint("TOPRIGHT", b.icon, "TOPRIGHT", 3, 3)
    b.up:Hide()
    b.name = b:CreateFontString(nil, "OVERLAY")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.name:SetPoint("RIGHT", -4, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(true)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.kind == "currency" then
            pcall(GameTooltip.SetQuestCurrency, GameTooltip, self.qtype, self.index)
        elseif self.kind == "item" and self.qtype then
            pcall(GameTooltip.SetQuestItem, GameTooltip, self.qtype, self.index)
            if self.upDelta then
                GameTooltip:AddLine(self.upDelta > 0 and ("This item is an upgrade for you (+" .. self.upDelta .. " item level)")
                    or "This item fits an empty slot", 0.3, 1, 0.3)
            end
            if self.bestSell then GameTooltip:AddLine("Sells for the most of your choices", 1, 0.82, 0.2) end
        else
            GameTooltip:SetText(self.name and self.name:GetText() or "")
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        if HandleModifiedItemClick and self.qtype and self.kind == "item" then
            local link = GetQuestItemLink and GetQuestItemLink(self.qtype, self.index)
            if link and HandleModifiedItemClick(link) then return end
        end
        if self.choice then
            state.choice = self.index
            Render()
        end
    end)
    rewardPool[i] = b
    return b
end

local function ActionButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(200, 40)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(ART .. "lore_button")
    b.hl = b:CreateTexture(nil, "BORDER")
    b.hl:SetAllPoints()
    b.hl:SetTexture(ART .. "lore_button")
    b.hl:SetBlendMode("ADD")
    b.hl:SetAlpha(0)
    b.badge = KeyBadge(b)
    b.badge:SetPoint("LEFT", 10, 0)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetPoint("LEFT", b.badge, "RIGHT", 10, 0)
    b:SetScript("OnEnter", function(self) self.hl:SetAlpha(0.35) end)
    b:SetScript("OnLeave", function(self) self.hl:SetAlpha(0) end)
    b:SetScript("OnClick", function(self) if self.run then self.run() end end)
    return b
end

-- Which controller the hints are written for. Automatic: a game controller is on and
-- ConsolePort is not doing the controlling (it has its own buttons) -> Xbox letters,
-- otherwise keyboard keys. Confirm / cancel are the bottom and right face buttons.
local DEVICE_LABELS = {
    xbox = { "A", "B" }, playstation = { "Cross", "Circle" }, switch = { "B", "A" },
}
local function Device()
    local d = Get("inputDevice")
    if d == "auto" or d == nil then
        local pad = _G.C_GamePad and _G.C_GamePad.IsEnabled and _G.C_GamePad.IsEnabled()
        if pad and not (type(_G.ConsolePort) == "table") then return "xbox" end
        return "kbm"
    end
    return d
end
local GLYPHS = {
    xbox = { A = "lore_pad_xbox_a", B = "lore_pad_xbox_b" },
    playstation = { Cross = "lore_pad_ps_cross", Circle = "lore_pad_ps_circle" },
    switch = { A = "lore_pad_switch_a", B = "lore_pad_switch_b" },
}
local function KeyForDevice(key)
    local labels = DEVICE_LABELS[Device()]
    if not labels then return key end
    if key == "Space" then return labels[1] end
    if key == "Esc" then return labels[2] end
    return key
end

-- a key badge and label on an action button (no badge when the key isn't used)
local function SetAction(btn, label, key)
    key = key and KeyForDevice(key)
    local hints = Get("keyHints") and key
    btn.badge:SetShown(hints and true or false)
    local glyph = hints and GLYPHS[Device()] and GLYPHS[Device()][key]
    btn.badge.glyph:SetShown(glyph and true or false)
    btn.badge.tex:SetShown(not glyph)
    btn.badge.text:SetShown(not glyph)
    if glyph then btn.badge.glyph:SetTexture(ART .. glyph) end
    if glyph then
        btn.badge:SetWidth(26)
        btn.text:ClearAllPoints()
        btn.text:SetPoint("LEFT", btn.badge, "RIGHT", 10, 0)
    elseif hints then
        btn.badge.text:SetText(key)
        btn.badge:SetWidth(math.max(24, StrW(btn.badge.text, key) + 12))
        btn.text:ClearAllPoints()
        btn.text:SetPoint("LEFT", btn.badge, "RIGHT", 10, 0)
    else
        btn.text:ClearAllPoints()
        btn.text:SetPoint("CENTER")
    end
    btn.text:SetText(label)
    local w = (hints and (btn.badge:GetWidth() + 20) or 0) + StrW(btn.text, label) + 34
    btn:SetWidth(math.max(150, w))
end

-- A quest offer you closed (Esc / Decline). Offers pushed by walking into an
-- area (often in dungeons) are sent again and again while you stand there;
-- the same offer coming straight back is closed quietly instead of popping
-- the scroll open again.
local dismissed = { id = nil, t = 0 }
local DISMISS_TIME = 10
local function RememberDismissed()
    local id = GetQuestID and GetQuestID()
    if id and id ~= 0 then dismissed.id, dismissed.t = id, GetTime() end
end

local closing = false
local function CloseInteraction()
    closing = true
    if state.mode == "gossip" then
        if C_GossipInfo and C_GossipInfo.CloseGossip then C_GossipInfo.CloseGossip() end
    else
        if CloseQuest then CloseQuest() end
    end
    closing = false
end

-- the holder is what H3z0 UI Edit Mode moves; the panel hangs from its top
local holder
local LAYOUT_KEY = "h3zLorekeeper"
local function SavedPlace()
    local core = Helpers and Helpers.GetCore and Helpers.GetCore()
    local fa = core and core.db and core.db.profile and core.db.profile.frameAnchoring
    return false    -- the position comes from the settings sliders only
end
local function Holder()
    if holder then return holder end
    holder = CreateFrame("Frame", "H3z0UI_LorekeeperHolder", UIParent)
    holder:SetSize(460, 560)
    holder:SetPoint("RIGHT", UIParent, "RIGHT", -180, 40)
    return holder
end
local function PlaceHolder()
    local h = Holder()
    h:SetSize(math.max(320, math.min(1000, tonumber(Get("width")) or 600)),
        math.max(200, math.min(1000, tonumber(Get("minHeight")) or 640)))
    if not SavedPlace() then
        h:ClearAllPoints()
        h:SetPoint("RIGHT", UIParent, "RIGHT", -(tonumber(Get("offsetX")) or 180), tonumber(Get("offsetY")) or 40)
    elseif _G.H3z0UI_ApplyFrameAnchor and not InCombatLockdown() then
        pcall(_G.H3z0UI_ApplyFrameAnchor, LAYOUT_KEY)
    end
end

---------------------------------------------------------------------------
-- Smooth transitions: the scroll slides in from the right and fades in, fades
-- out when the talk ends, grows / shrinks smoothly to the new text, and the
-- text fades over when the page changes (gossip -> quest, next page, ...).
-- Settings: Smooth Transitions (on by default).
---------------------------------------------------------------------------
local SLIDE = 46
local UNROLL_TIME = 0.6
local fx = { slide = 0, mode = nil, t = 0, dur = 0.3, alphaFrom = 0, alphaTo = 1,
    slideFrom = 0, slideTo = 0, onDone = nil, hTarget = nil, content = nil }
local function Animate() return Get("animate") ~= false end
local function Ease(t) return 1 - (1 - t) * (1 - t) * (1 - t) end
local function Anchor()
    if not panel then return end
    panel:ClearAllPoints()
    if fx.unroll and fx.finalH then
        -- unrolling: the scroll grows from its middle, up and down
        panel:SetPoint("CENTER", Holder(), "TOPRIGHT", fx.slide - panel:GetWidth() / 2, -fx.finalH / 2)
    else
        panel:SetPoint("TOPRIGHT", Holder(), "TOPRIGHT", fx.slide, 0)
    end
end

-- the writing (text, buttons) is hidden while the scroll unrolls
local function SetInk(a)
    local f = panel
    if not f then return end
    f.content:SetAlpha(a)
    f.pageText:SetAlpha(a)
    f.primary:SetAlpha(a)
    f.secondary:SetAlpha(a)
end

local fxFrame = CreateFrame("Frame")
fxFrame:Hide()
Lorekeeper._fxFrame = fxFrame
Lorekeeper._fx = fx
fxFrame:SetScript("OnUpdate", function(self, elapsed)
    local f = panel
    if not f then self:Hide() return end
    local busy = false
    if fx.mode then
        fx.t = fx.t + elapsed
        local p = math.min(1, fx.t / fx.dur)
        local e = Ease(p)
        f:SetAlpha(fx.alphaFrom + (fx.alphaTo - fx.alphaFrom) * e)
        fx.slide = fx.slideFrom + (fx.slideTo - fx.slideFrom) * e
        Anchor()
        if p >= 1 then
            local done = fx.mode == "out" and fx.onDone
            fx.mode, fx.onDone = nil, nil
            if done then done() end
        else
            busy = true
        end
    end
    if fx.unroll then
        fx.unroll = math.min(1, fx.unroll + elapsed / UNROLL_TIME)
        local e = Ease(fx.unroll)
        local minH = f.rollTop:GetHeight() + f.rollBottom:GetHeight() - 6
        f:SetHeight(minH + (fx.finalH - minH) * e)
        SetInk(math.max(0, math.min(1, (fx.unroll - 0.5) / 0.45)))
        if fx.unroll >= 1 then
            fx.unroll = nil
            f:SetHeight(fx.finalH)
            SetInk(1)
            fx.content = nil
        else
            busy = true
        end
        Anchor()
    end
    if fx.hTarget and not fx.unroll and f:IsShown() then
        local cur = f:GetHeight()
        local d = fx.hTarget - cur
        if math.abs(d) < 1 then
            f:SetHeight(fx.hTarget)
            fx.hTarget = nil
        else
            f:SetHeight(cur + d * math.min(1, elapsed * 14))
            busy = true
        end
    end
    if fx.content and f.content and not fx.unroll then
        fx.content = math.min(1, fx.content + elapsed / 0.2)
        f.content:SetAlpha(fx.content)
        if fx.content >= 1 then fx.content = nil else busy = true end
    end
    if not busy and not fx.mode then self:Hide() end
end)

-- show the scroll: slide in + fade in (also turns a fade-out back around)
local function FadeIn()
    local f = panel
    if not f then return end
    if not Animate() then
        fx.mode, fx.onDone, fx.slide = nil, nil, 0
        f:SetAlpha(1)
        Anchor()
        return
    end
    local fresh = not f:IsShown()
    if fresh then
        -- the scroll opens from its middle: the rolls move apart, the sheet grows between them
        fx.finalH = f:GetHeight()
        fx.unroll = 0
        SetInk(0)
    end
    fx.alphaFrom = fresh and 0 or f:GetAlpha()
    fx.slideFrom = fresh and SLIDE or fx.slide
    fx.alphaTo, fx.slideTo = 1, 0
    fx.mode, fx.onDone, fx.t, fx.dur = "in", nil, 0, 0.3
    fx.slide = fx.slideFrom
    f:SetAlpha(fx.alphaFrom)
    Anchor()
    fxFrame:Show()
end

-- hide the scroll after a short fade-out; done() does the real Hide
local function FadeOut(done)
    local f = panel
    if not (f and f:IsShown()) then return end
    if not Animate() then done() return end
    if fx.mode == "out" then return end
    fx.alphaFrom, fx.alphaTo = f:GetAlpha(), 0
    fx.slideFrom, fx.slideTo = fx.slide, SLIDE * 0.6
    fx.mode, fx.onDone, fx.t, fx.dur = "out", done, 0, 0.22
    fxFrame:Show()
end

local function FadingOut() return fx.mode == "out" end

-- the text fades over when the scroll changes while open
local function ContentSwap()
    if not (panel and panel:IsShown() and Animate()) then return end
    fx.content = 0
    panel.content:SetAlpha(0)
    fxFrame:Show()
end

-- the scroll's height: smooth while it is open, at once when it opens
local function SetPanelHeight(h)
    local f = panel
    if not f then return end
    if fx.unroll then
        fx.finalH = h        -- still unrolling: the new height is where it ends
        return
    end
    if Animate() and f:IsShown() and not FadingOut() and math.abs(f:GetHeight() - h) >= 1 then
        fx.hTarget = h
        fxFrame:Show()
    else
        fx.hTarget = nil
        f:SetHeight(h)
    end
end

local function Build()
    if panel then return panel end
    local f = CreateFrame("Frame", "H3z0UI_Lorekeeper", UIParent)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:Hide()

    -- the scroll: a roll at the top, the sheet, a roll at the bottom (three
    -- pieces, so the sheet can stretch and the rolls keep their shape)
    f.rollTop = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    f.rollTop:SetTexture(ART .. "lore_roll_top")
    f.rollTop:SetPoint("TOPLEFT", 0, 0)
    f.rollTop:SetPoint("TOPRIGHT", 0, 0)
    f.rollBottom = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    f.rollBottom:SetTexture(ART .. "lore_roll_bottom")
    f.rollBottom:SetPoint("BOTTOMLEFT", 0, 0)
    f.rollBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    f.sheet = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.sheet:SetTexture(ART .. "lore_parchment")
    f.sheet:SetPoint("TOPLEFT", f.rollTop, "BOTTOMLEFT", 0, 3)
    f.sheet:SetPoint("BOTTOMRIGHT", f.rollBottom, "TOPRIGHT", 0, -3)

    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", 52, -100)
    f.content:SetPoint("BOTTOMRIGHT", -52, 150)
    f.content:SetClipsChildren(false)

    f.npc = f.content:CreateFontString(nil, "OVERLAY")
    f.npc:SetPoint("TOPLEFT", 0, 0)
    f.npc:SetJustifyH("LEFT")
    f.title = f.content:CreateFontString(nil, "OVERLAY")
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(true)
    f.body = f.content:CreateFontString(nil, "OVERLAY")
    f.body:SetJustifyH("LEFT")
    f.body:SetWordWrap(true)
    f.body:SetSpacing(3)
    f.sub = f.content:CreateFontString(nil, "OVERLAY")
    f.sub:SetJustifyH("LEFT")
    f.sub:SetWordWrap(true)
    f.subHead = f.content:CreateFontString(nil, "OVERLAY")
    f.subHead:SetJustifyH("LEFT")
    f.money = f.content:CreateFontString(nil, "OVERLAY")
    f.money:SetJustifyH("LEFT")
    f.pageText = f:CreateFontString(nil, "OVERLAY")
    f.pageText:SetPoint("BOTTOMLEFT", 52, 104)

    f.primary = ActionButton(f)
    f.primary:SetPoint("BOTTOMRIGHT", -52, 100)
    f.secondary = ActionButton(f)
    f.secondary:SetPoint("RIGHT", f.primary, "LEFT", -10, 0)

    -- click the text: finish typing / next page
    f.clicker = CreateFrame("Button", nil, f)
    f.clicker:SetPoint("TOPLEFT", f.body, "TOPLEFT")
    f.clicker:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT")
    f.clicker:SetScript("OnClick", function() Lorekeeper.Advance() end)

    f:SetScript("OnKeyDown", function(self, key)
        local handled = Lorekeeper.OnKey(key)
        if not handled and type(key) == "string" and key:find("^PAD") then handled = Lorekeeper.OnPad(key) end
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
    end)
    if f.EnableGamePadButton then
        f:SetScript("OnGamePadButtonDown", function(self, button)
            local handled = Lorekeeper.OnPad(button)
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
        end)
    end
    f:SetScript("OnHide", function(self)
        fx.mode, fx.onDone, fx.hTarget, fx.content, fx.slide = nil, nil, nil, nil, 0
        fx.unroll = nil
        self:SetAlpha(1)
        SetInk(1)
        StopTyping()
        RestoreUI()
        CameraOut()
        ShowNames()
        if not closing and state.mode and state.mode ~= "test" then
            local mode = state.mode
            state.mode = nil
            if mode == "gossip" then
                if C_GossipInfo and C_GossipInfo.CloseGossip then C_GossipInfo.CloseGossip() end
            elseif CloseQuest then
                if mode == "detail" then RememberDismissed() end
                CloseQuest()
            end
        end
        state.mode = nil
    end)
    tinsert(UISpecialFrames, "H3z0UI_Lorekeeper")
    panel = f
    return f
end

local function ApplyLook()
    local f = Build()
    local alpha = math.max(0.3, math.min(1, tonumber(Get("bgAlpha")) or 1))
    f.sheet:SetAlpha(alpha)
    f.rollTop:SetAlpha(alpha)
    f.rollBottom:SetAlpha(alpha)
    if not (ns.H3z0UI_LayoutMode and ns.H3z0UI_LayoutMode.isActive) then PlaceHolder() end
    f:SetScale(math.max(0.6, math.min(1.6, tonumber(Get("scale")) or 1)))
    f:SetWidth(math.max(320, math.min(1000, tonumber(Get("width")) or 600)))
    local w = f:GetWidth()
    f.rollTop:SetHeight(math.floor(w * 150 / 1000 + 0.5))
    f.rollBottom:SetHeight(math.floor(w * 150 / 1000 + 0.5))
    -- the text area starts under the top roll and ends over the bottom roll
    f.content:ClearAllPoints()
    f.content:SetPoint("TOPLEFT", 52, -(f.rollTop:GetHeight() + 22))
    f.content:SetPoint("BOTTOMRIGHT", -52, f.rollBottom:GetHeight() + 56)
    f.primary:ClearAllPoints()
    f.primary:SetPoint("BOTTOMRIGHT", -52, f.rollBottom:GetHeight() + 6)
    f.pageText:ClearAllPoints()
    f.pageText:SetPoint("BOTTOMLEFT", 52, f.rollBottom:GetHeight() + 14)
    Anchor()
    local size = tonumber(Get("fontSize")) or 16
    SetFont(f.npc, tonumber(Get("npcSize")) or 15, "")
    f.npc:SetTextColor(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])
    SetFont(f.title, tonumber(Get("titleSize")) or 21, "")
    f.title:SetTextColor(INK_TITLE[1], INK_TITLE[2], INK_TITLE[3])
    SetFont(f.body, size, "")
    f.body:SetTextColor(INK[1], INK[2], INK[3])
    f.body:SetShadowOffset(0, 0)
    SetFont(f.sub, size - 1, "")
    f.sub:SetTextColor(INK[1], INK[2], INK[3])
    SetFont(f.subHead, size, "")
    f.subHead:SetTextColor(INK_TITLE[1], INK_TITLE[2], INK_TITLE[3])
    SetFont(f.money, size - 1, "")
    f.money:SetTextColor(INK[1], INK[2], INK[3])
    SetFont(f.pageText, 12, "")
    f.pageText:SetTextColor(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])
    local bsize = tonumber(Get("buttonSize")) or 15
    for _, btn in ipairs({ f.primary, f.secondary }) do
        SetFont(btn.text, bsize, "")
        btn.text:SetTextColor(0.97, 0.95, 0.9)
        SetFont(btn.badge.text, math.max(10, bsize - 3), "")
        btn.badge.text:SetTextColor(0.95, 0.95, 0.95)
        btn:SetHeight(bsize + 24)
    end
end

---------------------------------------------------------------------------
-- Content of each kind of window
---------------------------------------------------------------------------
local function KeyLabel(i)
    if not Get("numberKeys") or i > 9 then return nil end
    return tostring(i)
end

local QUEST_ICON_AVAILABLE = "Interface\\GossipFrame\\AvailableQuestIcon"
local QUEST_ICON_ACTIVE = "Interface\\GossipFrame\\ActiveQuestIcon"
local QUEST_ICON_INCOMPLETE = "Interface\\GossipFrame\\IncompleteQuestIcon"

-- The quest icon of a row follows the kind of quest the way the game's own list does:
-- yellow for a normal quest, blue for a repeatable / daily / weekly one, and so on,
-- and a question mark once it is ready to turn in. The game names the icon itself when
-- it can (by quest ID); if not, it is chosen from what the game says about the quest;
-- the old plain icons stay as the last fallback.
local function AtlasOk(name)
    if type(name) ~= "string" or name == "" then return false end
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        return ok and info ~= nil and info ~= false
    end
    return false
end

local function FirstAtlas(list)
    for _, n in ipairs(list) do if AtlasOk(n) then return n end end
end

local function Repeats(q)
    if not q then return false end
    local f = q.frequency
    if type(f) == "number" and not IsSecret(f) and f > 0 then return true end
    if q.repeatable == true or q.isRepeatable == true then return true end
    return false
end

local function OfferIcon(questID, q)
    local QU = _G.QuestUtil
    if QU and QU.GetQuestIconOfferForQuestID and type(questID) == "number" then
        local ok, a = pcall(QU.GetQuestIconOfferForQuestID, questID)
        if ok and AtlasOk(a) then return a end
    end
    if q and q.isLegendary then
        local a = FirstAtlas({ "UI-QuestPoiLegendary-QuestBang", "QuestLegendary" })
        if a then return a end
    end
    if q and q.isMeta then
        local a = FirstAtlas({ "UI-QuestPoiWrapper-QuestBang" })
        if a then return a end
    end
    if Repeats(q) then
        local a = FirstAtlas({ "UI-QuestPoiRecurring-QuestBang", "quest-recurring-available", "QuestDaily", "QuestRepeatableTurnin" })
        if a then return a end
    end
    if q and q.isImportant then
        local a = FirstAtlas({ "UI-QuestPoiImportant-QuestBang", "QuestImportant" })
        if a then return a end
    end
    if q and q.isTrivial then
        local a = FirstAtlas({ "UI-QuestPoiTrivial-QuestBang", "QuestTrivial" })
        if a then return a end
    end
    return FirstAtlas({ "QuestNormal", "UI-QuestPoiNormal-QuestBang" }) or QUEST_ICON_AVAILABLE
end

local function ActiveIcon(questID, q, complete)
    if not complete then
        local QU = _G.QuestUtil
        if QU and QU.GetQuestIconActiveForQuestID and type(questID) == "number" then
            local ok, a = pcall(QU.GetQuestIconActiveForQuestID, questID)
            if ok and AtlasOk(a) then return a end
        end
        return QUEST_ICON_INCOMPLETE
    end
    local QU = _G.QuestUtil
    if QU and QU.GetQuestIconActiveForQuestID and type(questID) == "number" then
        local ok, a = pcall(QU.GetQuestIconActiveForQuestID, questID)
        if ok and AtlasOk(a) then return a end
    end
    if Repeats(q) then
        local a = FirstAtlas({ "UI-QuestPoiRecurring-QuestTurnIn", "QuestRepeatableTurnin", "quest-recurring-turnin" })
        if a then return a end
    end
    return FirstAtlas({ "QuestTurnin", "UI-QuestPoiNormal-QuestTurnIn" }) or QUEST_ICON_ACTIVE
end

-- builds state.options = { { text, icon, run }, ... }
local function GossipOptions()
    local list = {}
    local GI = C_GossipInfo
    if not GI then return list end
    for _, q in ipairs(GI.GetActiveQuests and GI.GetActiveQuests() or {}) do
        local id = q.questID
        list[#list + 1] = { text = Str(q.title) ~= "" and q.title or "?", secretText = IsSecret(q.title) and q.title or nil, icon = ActiveIcon(id, q, q.isComplete),
            run = function() GI.SelectActiveQuest(id) end, quest = true }
    end
    for _, q in ipairs(GI.GetAvailableQuests and GI.GetAvailableQuests() or {}) do
        local id = q.questID
        list[#list + 1] = { text = Str(q.title) ~= "" and q.title or "?", secretText = IsSecret(q.title) and q.title or nil, icon = OfferIcon(id, q),
            run = function() GI.SelectAvailableQuest(id) end, quest = true }
    end
    local opts = GI.GetOptions and GI.GetOptions() or {}
    pcall(table.sort, opts, function(a, b) return Num(a.orderIndex) < Num(b.orderIndex) end)
    for _, o in ipairs(opts) do
        local id = o.gossipOptionID
        list[#list + 1] = { text = Str(o.name) ~= "" and o.name or "?", secretText = IsSecret(o.name) and o.name or nil, icon = (not IsSecret(o.icon)) and o.icon or nil,
            run = function() GI.SelectOption(id) end }
    end
    return list
end

local function GreetingOptions()
    local list = {}
    for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
        local idx = i
        local title, isComplete = GetActiveTitle(i)
        local qid = GetActiveQuestID and GetActiveQuestID(i)
        list[#list + 1] = { text = Str(title) ~= "" and title or "?", secretText = IsSecret(title) and title or nil, icon = ActiveIcon(qid, nil, isComplete),
            run = function() SelectActiveQuest(idx) end, quest = true }
    end
    for i = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
        local idx = i
        -- the game returns: isTrivial, frequency, isRepeatable, isLegendary, questID
        local isTrivial, freq, isRepeatable, isLegendary, qid
        if GetAvailableQuestInfo then isTrivial, freq, isRepeatable, isLegendary, qid = GetAvailableQuestInfo(i) end
        local info = { frequency = freq, isRepeatable = isRepeatable, isLegendary = isLegendary, isTrivial = isTrivial }
        list[#list + 1] = { text = Str(GetAvailableTitle(i)) ~= "" and GetAvailableTitle(i) or "?", secretText = IsSecret(GetAvailableTitle(i)) and GetAvailableTitle(i) or nil, icon = OfferIcon(qid, info),
            run = function() SelectAvailableQuest(idx) end, quest = true }
    end
    return list
end

-- rewards: { { kind, qtype, index, name, texture, count, quality, choice } }
-- A choice can be an item OR a currency (crests, ...): the game says which,
-- like Blizzard's own quest window reads it.
-- sell price (per stack) and "is it better than what I wear" for a quest reward item
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_BODY = { 4 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}

local function ItemInfo(link)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(link) end
    return GetItemInfo(link)
end

local function SellValue(rw)
    if rw.kind ~= "item" or not GetQuestItemLink then return nil end
    local link = GetQuestItemLink(rw.qtype, rw.index)
    if not link then return nil end
    local price = select(11, ItemInfo(link))
    if type(price) ~= "number" or IsSecret(price) then return nil end
    return price * math.max(1, tonumber(rw.count) or 1)
end

-- number: item level gained over the worse of the matching slots; 0 = an empty slot; nil = not gear / unknown
local function UpgradeDelta(rw)
    if rw.kind ~= "item" or not GetQuestItemLink or not GetInventoryItemLink then return nil end
    local link = GetQuestItemLink(rw.qtype, rw.index)
    if not link then return nil end
    local loc
    if C_Item and C_Item.GetItemInfoInstant then loc = select(4, C_Item.GetItemInfoInstant(link))
    elseif GetItemInfoInstant then loc = select(4, GetItemInfoInstant(link)) end
    local slots = loc and EQUIP_SLOTS[loc]
    if not slots then return nil end
    local ilvl = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link)
    if type(ilvl) ~= "number" or IsSecret(ilvl) then return nil end
    local worst
    for _, slot in ipairs(slots) do
        local cur = GetInventoryItemLink("player", slot)
        local curLevel = 0
        if cur then curLevel = GetDetailedItemLevelInfo(cur) or 0 end
        if not worst or curLevel < worst then worst = curLevel end
    end
    if worst == 0 then return 0 end
    if ilvl > worst then return ilvl - worst end
    return nil
end

local function RewardEntry(qtype, i, isChoice)
    -- only the choice list mixes items and currencies; the reward list is items
    -- (its currencies are counted separately below)
    local lootType = (qtype == "choice" and GetQuestItemInfoLootType and GetQuestItemInfoLootType(qtype, i)) or 0
    if lootType == 1 and C_QuestOffer and C_QuestOffer.GetQuestRewardCurrencyInfo then
        local info = C_QuestOffer.GetQuestRewardCurrencyInfo(qtype, i)
        if info then
            return { kind = "currency", qtype = qtype, index = i, name = info.name, texture = info.texture,
                count = info.totalRewardAmount or info.baseRewardAmount, quality = info.quality, choice = isChoice }
        end
        return nil
    end
    local name, tex, count, quality = GetQuestItemInfo(qtype, i)
    if not name and not tex then return nil end
    return { kind = "item", qtype = qtype, index = i, name = name, texture = tex,
        count = count, quality = quality, choice = isChoice }
end

local function Rewards()
    local list = {}
    local nChoice = GetNumQuestChoices and GetNumQuestChoices() or 0
    for i = 1, nChoice do
        local e = RewardEntry("choice", i, nChoice > 1)
        if e then list[#list + 1] = e end
    end
    for i = 1, (GetNumQuestRewards and GetNumQuestRewards() or 0) do
        local e = RewardEntry("reward", i, false)
        if e then list[#list + 1] = e end
    end
    -- currencies that are not part of the item list
    local nCur = GetNumRewardCurrencies and GetNumRewardCurrencies() or 0
    for i = 1, nCur do
        local info = C_QuestOffer and C_QuestOffer.GetQuestRewardCurrencyInfo and C_QuestOffer.GetQuestRewardCurrencyInfo("reward", i)
        if info then
            list[#list + 1] = { kind = "currency", qtype = "reward", index = i, name = info.name, texture = info.texture,
                count = info.totalRewardAmount or info.baseRewardAmount, quality = info.quality }
        end
    end
    -- renown / reputation with the major factions
    if C_QuestOffer and C_QuestOffer.GetQuestOfferMajorFactionReputationRewards then
        local ok, reps = pcall(C_QuestOffer.GetQuestOfferMajorFactionReputationRewards)
        if ok and type(reps) == "table" then
            for n, rep in ipairs(reps) do
                if n > 10 then break end
                do
                local data = C_MajorFactions and C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(rep.factionID)
                local name = data and data.name or (REPUTATION or "Reputation")
                local icon = data and data.textureKit and ("Interface\\Icons\\UI_MajorFaction_" .. data.textureKit) or 236681
                list[#list + 1] = { kind = "rep", name = name, texture = icon, count = rep.rewardAmount, quality = 1 }
            end
            end
        end
    end
    -- honor
    local honor = GetRewardHonor and GetRewardHonor() or 0
    if honor and honor > 0 then
        list[#list + 1] = { kind = "honor", name = HONOR or "Honor", texture = 1455894, count = honor, quality = 1 }
    end
    return list, nChoice
end

local function RequiredItems()
    local list = {}
    for i = 1, (GetNumQuestItems and GetNumQuestItems() or 0) do
        local name, tex, count, quality = GetQuestItemInfo("required", i)
        list[#list + 1] = { kind = "item", qtype = "required", index = i, name = name, texture = tex, count = count, quality = quality }
    end
    return list
end

local function MoneyLine(money, xp)
    local parts = {}
    if money and money > 0 and GetMoneyString then parts[#parts + 1] = GetMoneyString(money, true) end
    if xp and xp > 0 then parts[#parts + 1] = string.format("%s XP", BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp) end
    return table.concat(parts, "    ")
end

-- keep a text; if the game made it secret it can't be read or measured, but it
-- can still be put on screen as it is
local function Keep(c, key, raw)
    c[key] = Str(raw)
    if IsSecret(raw) then
        c.secrets = c.secrets or {}
        c.secrets[key] = raw
    end
end

local function Collect()
    local mode = state.mode
    local rawName = UnitName("npc")
    local c = { npc = Str(rawName), title = "", text = "", options = {}, rewards = {}, sub = "", subHead = "" }
    -- a secret NPC name can still be shown (just not measured or compared)
    if IsSecret(rawName) then c.npcSecret = rawName end
    if mode == "gossip" then
        Keep(c, "text", C_GossipInfo and C_GossipInfo.GetText and C_GossipInfo.GetText())
        c.options = GossipOptions()
        c.primaryText = (#c.options > 0 and Get("spaceSelectsFirst")) and CONTINUE or GOODBYE
        c.secondaryText = GOODBYE
    elseif mode == "greeting" then
        Keep(c, "text", GetGreetingText and GetGreetingText())
        c.options = GreetingOptions()
        c.primaryText = #c.options > 0 and CONTINUE or GOODBYE
        c.secondaryText = GOODBYE
    elseif mode == "detail" then
        Keep(c, "title", GetTitleText and GetTitleText())
        Keep(c, "text", GetQuestText and GetQuestText())
        if Get("showObjectives") then
            c.subHead = QUEST_OBJECTIVES or "Objectives"
            Keep(c, "sub", GetObjectiveText and GetObjectiveText())
        end
        c.rewards = Rewards()
        c.money = MoneyLine(GetRewardMoney and GetRewardMoney(), GetRewardXP and GetRewardXP())
        c.auto = QuestGetAutoAccept and QuestGetAutoAccept()
        c.primaryText = c.auto and OKAY or ACCEPT
        c.secondaryText = c.auto and nil or DECLINE
    elseif mode == "progress" then
        Keep(c, "title", GetTitleText and GetTitleText())
        Keep(c, "text", GetProgressText and GetProgressText())
        local req = RequiredItems()
        if #req > 0 then
            c.subHead = TURN_IN_ITEMS or "Required items"
            c.rewards = req
        end
        local needMoney = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
        if needMoney > 0 and GetMoneyString then c.money = GetMoneyString(needMoney, true) end
        c.completable = IsQuestCompletable and IsQuestCompletable()
        c.primaryText = c.completable and CONTINUE or GOODBYE
        c.secondaryText = c.completable and GOODBYE or nil
    elseif mode == "complete" then
        Keep(c, "title", GetTitleText and GetTitleText())
        Keep(c, "text", GetRewardText and GetRewardText())
        local list, nChoice = Rewards()
        c.rewards, c.nChoice = list, nChoice
        if nChoice > 1 then c.subHead = REWARD_CHOOSE or "Choose your reward" end
        c.money = MoneyLine(GetRewardMoney and GetRewardMoney(), GetRewardXP and GetRewardXP())
        c.primaryText = COMPLETE_QUEST or "Complete Quest"
        c.secondaryText = nil
    end
    return c
end

-- the main action of the window (Space, the right button)
function Lorekeeper.Primary()
    local c = state.content
    if not c then return end
    local mode = state.mode
    if mode == "gossip" or mode == "greeting" then
        if #c.options > 0 and (mode == "greeting" or Get("spaceSelectsFirst")) then
            c.options[1].run()
        else
            Lorekeeper.Close()
        end
    elseif mode == "detail" then
        if c.auto then
            if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
            Lorekeeper.Close()
        else
            AcceptQuest()
        end
    elseif mode == "progress" then
        if c.completable then CompleteQuest() else Lorekeeper.Close() end
    elseif mode == "complete" then
        local n = c.nChoice or 0
        if n > 1 and not state.choice then
            -- a reward has to be chosen first
            if UIErrorsFrame then UIErrorsFrame:AddMessage(REWARD_CHOICES or "Choose a reward first", 1, 0.3, 0.3) end
            return
        end
        GetQuestReward(n > 1 and state.choice or (n == 1 and 1 or nil))
    end
end

function Lorekeeper.Secondary()
    if state.mode == "detail" then
        RememberDismissed()
        if DeclineQuest then DeclineQuest() end
    end
    Lorekeeper.Close()
end

function Lorekeeper.Close()
    if panel and panel:IsShown() then
        FadeOut(function() panel:Hide() end)
    end
end

function Lorekeeper.Advance()
    if state.typing then StopTyping() return end
    if state.page < #state.pages then
        state.page = state.page + 1
        if Get("pageSound") and PlaySound and SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_SELECT then
            PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
        end
        Render(true)
        ContentSwap()
        return
    end
    Lorekeeper.Primary()
end

function Lorekeeper.OnKey(key)
    if not (panel and panel:IsShown()) then return false end
    -- closing already: Esc must not fall through to the game menu
    if FadingOut() then return key == "ESCAPE" end
    if key == "ESCAPE" then
        Lorekeeper.Secondary()
        return true
    end
    if key == "SPACE" and Get("spaceKey") then
        Lorekeeper.Advance()
        return true
    end
    local n = tonumber(key)
    if n and n >= 1 and n <= 9 and Get("numberKeys") then
        local c = state.content
        if state.mode == "complete" and c and c.nChoice and c.nChoice > 1 then
            if n <= c.nChoice then state.choice = n; Render() end
            return true
        end
        local opt = c and c.options and c.options[n]
        if opt and state.page >= #state.pages then
            StopTyping()
            opt.run()
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Controller support
--   ConsolePort (Midnight and Forever): the scroll is registered with
--     ConsolePort's interface cursor, so its cursor moves over the choices,
--     rewards and buttons and A clicks them like any other window.
--   Native game controller (Forever only): D-pad moves a highlight, the
--     confirm button (A / Cross) picks or continues, the cancel button
--     (B / Circle) says goodbye or declines. Not used while ConsolePort is
--     loaded (ConsolePort already owns the controller then).
---------------------------------------------------------------------------
local function CP() return _G.ConsolePort end

local function HasConsolePort()
    local cp = CP()
    return type(cp) == "table" and type(cp.AddInterfaceCursorFrame) == "function"
end
Lorekeeper.HasConsolePort = HasConsolePort

local cpRegistered
local function RegisterConsolePort()
    if cpRegistered or not panel or not HasConsolePort() then return end
    local ok, found = pcall(CP().AddInterfaceCursorFrame, CP(), panel)
    if ok and found then cpRegistered = true end
end
Lorekeeper.RegisterConsolePort = RegisterConsolePort

-- native pad: Forever / Classic only, and only when ConsolePort isn't there
local function NativePad()
    return Get("controller") ~= false and ns.Client and ns.Client.isLegacy and not HasConsolePort()
end
Lorekeeper.NativePad = NativePad

local padUsed, padFocus = false, nil

local function PadList()
    local list = {}
    if not panel then return list end
    for _, b in ipairs(rewardPool) do
        if b:IsShown() and b.choice then list[#list + 1] = b end
    end
    for _, b in ipairs(optionPool) do
        if b:IsShown() and b.run then list[#list + 1] = b end
    end
    if panel.secondary:IsShown() then list[#list + 1] = panel.secondary end
    if panel.primary:IsShown() then list[#list + 1] = panel.primary end
    table.sort(list, function(a, b)
        local at, bt = a:GetTop() or 0, b:GetTop() or 0
        if math.abs(at - bt) > 6 then return at > bt end
        return (a:GetLeft() or 0) < (b:GetLeft() or 0)
    end)
    return list
end

local function PadDefault(list)
    list = list or PadList()
    -- the next thing to do: a reward to choose, else the first choice, else the main button
    for _, b in ipairs(list) do if b.choice then return b end end
    if state.mode == "gossip" or state.mode == "greeting" then
        for _, b in ipairs(list) do if b ~= panel.primary and b ~= panel.secondary then return b end end
    end
    return panel and panel.primary:IsShown() and panel.primary or list[1]
end

local function FocusBox()
    if panel.focusBox then return panel.focusBox end
    local fb = CreateFrame("Frame", nil, panel)
    fb:SetFrameLevel(panel:GetFrameLevel() + 30)
    fb.edges = {}
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
                         { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil } }) do
        local t = fb:CreateTexture(nil, "OVERLAY")
        t:SetPoint(e[1]); t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
        t:SetColorTexture(0.55, 0.12, 0.08, 1)
        fb.edges[#fb.edges + 1] = t
    end
    fb:Hide()
    panel.focusBox = fb
    return fb
end

local function PadShowFocus()
    if not panel then return end
    local fb = FocusBox()
    if padUsed and padFocus and padFocus:IsShown() and NativePad() then
        fb:ClearAllPoints()
        fb:SetPoint("TOPLEFT", padFocus, "TOPLEFT", -3, 3)
        fb:SetPoint("BOTTOMRIGHT", padFocus, "BOTTOMRIGHT", 3, -3)
        fb:Show()
    else
        fb:Hide()
    end
end

-- called after every Render: keeps the focus on something that exists
function Lorekeeper.PadRefresh(newContent)
    if not panel then return end
    RegisterConsolePort()
    local list = PadList()
    if newContent or not (padFocus and padFocus:IsShown()) then
        padFocus = PadDefault(list)
        -- ConsolePort: put its cursor on the same thing
        if HasConsolePort() and cpRegistered and padFocus and CP().SetCursorNodeIfActive then
            pcall(CP().SetCursorNodeIfActive, padFocus, false)
        end
    end
    PadShowFocus()
end

local function PadMove(step)
    local list = PadList()
    if #list == 0 then return end
    local at
    for i, b in ipairs(list) do if b == padFocus then at = i break end end
    if not at then padFocus = PadDefault(list)
    else padFocus = list[((at - 1 + step) % #list) + 1] end
    PadShowFocus()
end

local lastPad = { b = nil, t = 0 }
-- returns true when the button was used
function Lorekeeper.OnPad(button)
    if not (panel and panel:IsShown()) or not NativePad() then return false end
    local now = GetTime()
    if lastPad.b == button and now - lastPad.t < 0.05 then return true end
    lastPad.b, lastPad.t = button, now
    if FadingOut() then return button == "PAD2" end
    if button == "PADDUP" or button == "PADDLEFT" or button == "PADLSHOULDER" then
        padUsed = true; PadMove(-1); return true
    elseif button == "PADDDOWN" or button == "PADDRIGHT" or button == "PADRSHOULDER" then
        padUsed = true; PadMove(1); return true
    elseif button == "PAD1" then
        padUsed = true
        if state.typing or (state.page or 1) < #(state.pages or {}) then
            Lorekeeper.Advance()
        else
            if not (padFocus and padFocus:IsShown()) then padFocus = PadDefault() end
            if padFocus then padFocus:Click() else Lorekeeper.Advance() end
        end
        PadShowFocus()
        return true
    elseif button == "PAD2" then
        padUsed = true
        Lorekeeper.Secondary()
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Layout of the panel (top to bottom)
---------------------------------------------------------------------------
Render = function(typeIt)
    local f = Build()
    ApplyLook()
    local c = state.content
    if not c then return end
    local width = f:GetWidth() - 104
    local y = 0
    local gap = 8

    if Get("showNpcName") and c.npcSecret then
        -- a secret name is shown but can't be measured: one line of its size
        f.npc:SetText(c.npcSecret)
        f.npc:Show()
        y = y - (math.floor((tonumber(Get("npcSize")) or 15) * 1.25) + 4)
    elseif Get("showNpcName") and c.npc ~= "" then
        f.npc:SetText(c.npc)
        f.npc:Show()
        y = y - (StrH(f.npc, c.npc) + 4)
    else
        f.npc:Hide()
    end
    local secrets = c.secrets or {}
    if c.title ~= "" or secrets.title then
        f.title:ClearAllPoints()
        f.title:SetPoint("TOPLEFT", 0, y)
        f.title:SetWidth(width)
        f.title:SetText(secrets.title or c.title)
        f.title:Show()
        y = y - (StrH(f.title, secrets.title and string.rep("x", 40) or c.title, width) + gap)
    else
        f.title:Hide()
    end

    local pageText = state.pages[state.page] or ""
    f.body:ClearAllPoints()
    f.body:SetPoint("TOPLEFT", 0, y)
    f.body:SetWidth(width)
    if secrets.text and pageText == "" then
        -- secret text: shown as it is, without the typing effect
        pcall(StopTyping)
        f.body:SetText(secrets.text)
        y = y - (StrH(f.body, string.rep("x", 280), width) + gap * 1.5)
    else
        f.body:SetText(pageText)
        if typeIt then StartTyping(pageText) end
        y = y - (StrH(f.body, pageText, width) + gap * 1.5)
    end

    local lastPage = state.page >= #state.pages
    if #state.pages > 1 then
        f.pageText:SetText(string.format("%d / %d", state.page, #state.pages))
        f.pageText:Show()
    else
        f.pageText:Hide()
    end

    -- objectives / required items heading + text (last page only)
    if lastPage and c.subHead ~= "" then
        f.subHead:ClearAllPoints()
        f.subHead:SetPoint("TOPLEFT", 0, y)
        f.subHead:SetText(c.subHead)
        f.subHead:Show()
        y = y - (StrH(f.subHead, c.subHead, width) + 4)
    else
        f.subHead:Hide()
    end
    if lastPage and (c.sub ~= "" or secrets.sub) then
        f.sub:ClearAllPoints()
        f.sub:SetPoint("TOPLEFT", 0, y)
        f.sub:SetWidth(width)
        f.sub:SetText(secrets.sub or c.sub)
        f.sub:Show()
        y = y - (StrH(f.sub, secrets.sub and string.rep("x", 120) or c.sub, width) + gap)
    else
        f.sub:Hide()
    end

    -- rewards / required items: two per row
    local used = 0
    if lastPage and #c.rewards > 0 then
        if (state.mode == "detail") and c.subHead ~= "" then
            -- rewards heading under the objectives
            local head = f.rewardHead
            if not head then
                head = f.content:CreateFontString(nil, "OVERLAY")
                f.rewardHead = head
            end
            SetFont(head, (tonumber(Get("fontSize")) or 15), "OUTLINE")
            local r, g, b = Accent()
            head:SetTextColor(r, g, b)
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", 0, y)
            head:SetText(REWARDS or "Rewards")
            head:Show()
            y = y - (StrH(head, REWARDS or "Rewards", width) + 4)
        elseif f.rewardHead then
            f.rewardHead:Hide()
        end
        local colW = math.floor((width - 8) / 2)
        local rsize = tonumber(Get("rewardSize")) or 13
        local rowH = math.max(36, rsize * 2 + 10)
        -- which choice sells for the most (only when there is a real choice and every price is known)
        local bestIdx
        if Get("markSellPrice") ~= false then
            local best, ties, known = -1, 0, 0
            for i, rw in ipairs(c.rewards) do
                if rw.choice then
                    local v = SellValue(rw)
                    if v then
                        known = known + 1
                        if v > best then best, ties, bestIdx = v, 1, i elseif v == best then ties = ties + 1 end
                    end
                end
            end
            local nChoices = 0
            for _, rw in ipairs(c.rewards) do if rw.choice then nChoices = nChoices + 1 end end
            if known < nChoices or best <= 0 or ties > 1 then bestIdx = nil end
        end
        for i, rw in ipairs(c.rewards) do
            used = i
            local b = RewardButton(i)
            b:SetSize(colW, rowH)
            b.icon:SetSize(rowH - 6, rowH - 6)
            b.kind, b.qtype, b.index, b.choice = rw.kind, rw.qtype, rw.index, rw.choice
            b.icon:SetTexture(rw.texture or 134400)
            SetFont(b.count, math.max(10, rsize - 1), "OUTLINE")
            b.count:SetText((rw.count and rw.count > 1) and rw.count or "")
            SetFont(b.name, rsize, "")
            -- smaller currency rewards: a smaller icon and no name (the tooltip has it)
            local simple = rw.kind == "currency" and Get("simpleCurrency") == true
            if simple then b.icon:SetSize(math.max(16, rowH - 18), math.max(16, rowH - 18)) end
            b.name:SetText(simple and "" or (rw.name or ""))
            b.bestSell = (bestIdx == i) or nil
            b.coin:SetShown(b.bestSell and true or false)
            local delta = rw.choice and Get("markUpgrade") ~= false and UpgradeDelta(rw) or nil
            b.upDelta = delta
            b.up:SetShown(delta ~= nil)
            local q = rw.quality
            -- dark ink on the parchment; epic and better keep their colour (darkened)
            local qc = q and q >= 3 and type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
            if qc then b.name:SetTextColor(qc.r * 0.6, qc.g * 0.6, qc.b * 0.6) else b.name:SetTextColor(INK[1], INK[2], INK[3]) end
            local selected = rw.choice and state.choice == rw.index
            local r, g, bb = Accent()
            b.sel:SetColorTexture(r, g, bb, selected and 0.45 or 0)
            -- chosen: bright frame and a check mark; a choosable one gets a faint frame
            local ea = selected and 1 or (rw.choice and 0.28 or 0)
            for _, e in ipairs(b.edges) do e:SetColorTexture(selected and r or 0.3, selected and g or 0.2, selected and bb or 0.1, ea) end
            b.check:SetShown(selected and true or false)
            local col = (i - 1) % 2
            local rowI = math.floor((i - 1) / 2)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", col * (colW + 8), y - rowI * (rowH + 4))
            b:Show()
        end
        y = y - math.ceil(#c.rewards / 2) * (rowH + 4) - 2
    elseif f.rewardHead then
        f.rewardHead:Hide()
    end
    for i = used + 1, #rewardPool do rewardPool[i]:Hide() end

    if lastPage and c.money and c.money ~= "" then
        f.money:ClearAllPoints()
        f.money:SetPoint("TOPLEFT", 0, y)
        f.money:SetText(c.money)
        f.money:Show()
        y = y - (StrH(f.money, c.money, width) + gap)
    else
        f.money:Hide()
    end

    -- choices (last page only)
    local shown = 0
    if lastPage then
        for i, opt in ipairs(c.options) do
            shown = i
            local b = OptionButton(i)
            local osize = tonumber(Get("optionSize")) or 16
            SetFont(b.key, math.max(10, osize - 3), "")
            b.key:SetTextColor(0.95, 0.95, 0.95)
            SetFont(b.text, osize, "")
            local label = KeyLabel(i)
            b.badge:SetShown(label ~= nil)
            b.key:SetText(label or "")
            b.badge:SetSize(osize + 8, osize + 8)
            b.icon:ClearAllPoints()
            if label then
                b.icon:SetPoint("LEFT", b.badge, "RIGHT", 8, 0)
            else
                b.icon:SetPoint("LEFT", 10, 0)
            end
            b.icon:SetSize(osize + 2, osize + 2)
            if type(opt.icon) == "string" and not opt.icon:find("[\\/]") and AtlasOk(opt.icon) then
                b.icon:SetTexCoord(0, 1, 0, 1)
                b.icon:SetAtlas(opt.icon)
            else
                b.icon:SetTexture(opt.icon or "Interface\\GossipFrame\\GossipGossipIcon")
            end
            b:SetWidth(width)
            -- the text gets a fixed width (so its height is right the moment it is set)
            -- and loses the game's own colour codes (a dark blue is unreadable on the band)
            local textLeft = label and (2 * osize + 34) or (osize + 20)
            b.text:ClearAllPoints()
            b.text:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
            b.text:SetWidth(math.max(60, width - textLeft - 10))
            local shownText = opt.text
            if type(shownText) == "string" then
                shownText = shownText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            end
            b.text:SetText(opt.secretText or shownText)
            b.text:SetTextColor(opt.quest and 1 or 0.96, opt.quest and 0.88 or 0.96, opt.quest and 0.55 or 0.94)
            b.run = function() pcall(StopTyping); opt.run() end
            local sh = StrH(b.text, opt.secretText and string.rep("x", 40) or shownText, math.max(60, width - textLeft - 10))
            local h = math.max(osize + 20, sh + 18)
            b:SetHeight(h)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, y)
            b:Show()
            y = y - (h + 6)
        end
    end
    for i = shown + 1, #optionPool do optionPool[i]:Hide() end

    -- the main button (Space) gets a muted red tint; Esc buttons stay plain
    local function Tint(btn, r, g, b)
        btn.bg:SetVertexColor(r, g, b)
        btn.hl:SetVertexColor(r, g, b)
    end
    Tint(f.primary, 1, 1, 1)
    Tint(f.secondary, 1, 1, 1)
    -- (the Space button: Continue / Accept / Complete / Next, never Goodbye)
    if state.mode ~= "gossip" and state.mode ~= "greeting" and state.mode ~= "test" or not lastPage then
        Tint(f.primary, 1, 0.42, 0.36)
    end

    -- buttons with their key: Esc says goodbye / declines, Space continues
    local primaryLabel = (not lastPage) and (NEXT or "Next") or c.primaryText
    if state.mode == "gossip" or state.mode == "greeting" or state.mode == "test" then
        -- talking: only Goodbye (and Next while there are more pages)
        if not lastPage then
            SetAction(f.primary, NEXT or "Next", Get("spaceKey") and "Space" or nil)
            f.primary.run = function() Lorekeeper.Advance() end
            f.primary:Show()
            SetAction(f.secondary, GOODBYE or "Goodbye", "Esc")
            f.secondary.run = Lorekeeper.Close
            f.secondary:Show()
        else
            SetAction(f.primary, GOODBYE or "Goodbye", "Esc")
            f.primary.run = Lorekeeper.Close
            f.primary:Show()
            f.secondary:Hide()
        end
    else
        SetAction(f.primary, primaryLabel or CONTINUE or "Continue", Get("spaceKey") and "Space" or nil)
        f.primary.run = function() Lorekeeper.Advance() end
        f.primary:Show()
        if c.secondaryText then
            SetAction(f.secondary, c.secondaryText, "Esc")
            f.secondary.run = Lorekeeper.Secondary
            f.secondary:Show()
        else
            f.secondary:Hide()
        end
    end

    -- top roll + text + a gap + the buttons + the bottom roll
    local buttonsH = (tonumber(Get("buttonSize")) or 15) + 24
    local need = f.rollTop:GetHeight() + 14 + (-y) + 20 + buttonsH + 6 + f.rollBottom:GetHeight()
    SetPanelHeight(math.max(tonumber(Get("minHeight")) or 640, need))
    if Lorekeeper.PadRefresh then Lorekeeper.PadRefresh(false) end
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
local closeTimer
local function OpenMode(mode)
    if closeTimer then closeTimer:Cancel(); closeTimer = nil end
    local f = Build()
    state.mode = mode
    state.choice = nil
    state.page = 1
    state.content = Collect()
    state.pages = SplitPages(state.content.text)
    -- gossip with nothing to read and only one option: pick it (if wanted)
    if mode == "gossip" and Get("autoSelectSingle") and #state.content.options == 1
        and not state.content.options[1].quest and (state.content.text or "") == ""
        and not (state.content.secrets and state.content.secrets.text) then
        state.content.options[1].run()
        return
    end
    local wasOpen = f:IsShown() and not FadingOut()
    Render(true)
    if not f:IsShown() then
        FadeIn()
        f:Show()
        CameraIn()
        HideNames()
        FadeUI()
    elseif FadingOut() then
        FadeIn()          -- the next window followed (quest after gossip): turn around
    end
    if wasOpen then ContentSwap() end
    if not InCombatLockdown() then
        f:EnableKeyboard(true)
        f:SetPropagateKeyboardInput(true)
        if f.EnableGamePadButton then f:EnableGamePadButton(NativePad() and true or false) end
    end
    Lorekeeper.PadRefresh(true)
    if not Get("setupDone") and Lorekeeper.ShowSetup and not WindowStyle() then Lorekeeper.ShowSetup() end
end

-- If reading the NPC's window ever fails (a value the game keeps secret in an
-- instance, ...), the scroll still opens with what can be read, so the talk
-- is never stuck without a window.
local lkErr
local function SafeOpen(mode)
    local ok, err = pcall(OpenMode, mode)
    if ok then return end
    lkErr = tostring(err)
    if geterrorhandler then geterrorhandler()(err) end
    local f = Build()
    state.mode, state.page, state.choice = mode, 1, nil
    local options = {}
    if mode == "gossip" then
        local okO, list = pcall(GossipOptions)
        if okO then options = list end
    elseif mode == "greeting" then
        local okO, list = pcall(GreetingOptions)
        if okO then options = list end
    end
    state.content = { npc = "", title = "", text = "", options = options, rewards = {}, sub = "", subHead = "",
        primaryText = (mode == "detail") and ACCEPT or ((mode == "complete") and (COMPLETE_QUEST or "Complete Quest")) or GOODBYE,
        secondaryText = (mode == "detail") and DECLINE or GOODBYE }
    state.pages = { "" }
    pcall(Render, false)
    if not f:IsShown() or FadingOut() then FadeIn() end
    f:Show()
end

-- a window closed: wait a moment, the next one (quest after gossip) may follow
local function ClosedSoon()
    if closeTimer then closeTimer:Cancel() end
    closeTimer = C_Timer.NewTimer(0.15, function()
        closeTimer = nil
        if panel and panel:IsShown() then
            FadeOut(function()
                closing = true
                panel:Hide()
                closing = false
            end)
        end
    end)
end

---------------------------------------------------------------------------
-- Events: Blizzard's gossip / quest windows are switched off at login while
-- Lorekeeper is on, and these events drive the panel instead
---------------------------------------------------------------------------
local active = false
local ev = CreateFrame("Frame")

-- Blizzard's quest window takes the "click to complete / accept" popup out of the
-- quest tracker when it closes. Lorekeeper replaces that window, so it does it itself.
local function ClearTrackerPopup(questID)
    if not (questID and questID ~= 0) then return end
    -- the game's own list only (a C function): calling the tracker's method from here
    -- made the tracker's next update run as H3z0 UI (secret aura errors); the
    -- tracker drops the popup at its next own update
    if type(_G.RemoveAutoQuestPopUp) == "function" then pcall(_G.RemoveAutoQuestPopUp, questID) end
end

local EVENTS = {
    GOSSIP_SHOW = function() SafeOpen("gossip") end,
    GOSSIP_CLOSED = function() ClosedSoon() end,
    QUEST_GREETING = function() SafeOpen("greeting") end,
    QUEST_DETAIL = function(questStartItemID)
        local qid = GetQuestID and GetQuestID()
        local fromArea = QuestIsFromAreaTrigger and QuestIsFromAreaTrigger() or false
        -- the same rules as Blizzard's own quest window:
        -- a quest opened from the adventure map is shown there, not here
        if QuestIsFromAdventureMap and QuestIsFromAdventureMap() then return end
        -- offers from an item, or an area offer that only needs an OK, go to
        -- the quest tracker as a popup (click it to read it)
        local fromItem = questStartItemID ~= nil and questStartItemID ~= 0
        if fromItem or (fromArea and QuestGetAutoAccept and QuestGetAutoAccept()) then
            -- Blizzard's quest window code adds the popup itself (it still gets the event)
            if CloseQuest then CloseQuest() end
            return
        end
        -- the offer you just closed, sent again by the area: stay closed
        if qid and qid ~= 0 and qid == dismissed.id and GetTime() - dismissed.t < DISMISS_TIME
            and (fromArea or not UnitExists("npc")) then
            dismissed.t = GetTime()
            if CloseQuest then CloseQuest() end
            return
        end
        -- everything else (also a popup you clicked) is shown on the scroll
        SafeOpen("detail")
    end,
    QUEST_PROGRESS = function() SafeOpen("progress") end,
    QUEST_COMPLETE = function()
        ClearTrackerPopup(GetQuestID and GetQuestID())
        SafeOpen("complete")
    end,
    QUEST_TURNED_IN = function(questID) ClearTrackerPopup(questID) end,
    QUEST_FINISHED = function() ClosedSoon() end,
    QUEST_ITEM_UPDATE = function()
        if panel and panel:IsShown() and state.mode and state.mode ~= "gossip" then
            state.content = Collect()
            Render(false)
        end
    end,
    PLAYER_REGEN_DISABLED = function()
        if panel then
            panel:EnableKeyboard(false)
            if panel.EnableGamePadButton then panel:EnableGamePadButton(false) end
            RestoreUI()
        end
    end,
    PLAYER_REGEN_ENABLED = function()
        if panel and panel:IsShown() then
            panel:EnableKeyboard(true)
            panel:SetPropagateKeyboardInput(true)
            if panel.EnableGamePadButton then panel:EnableGamePadButton(NativePad() and true or false) end
        end
    end,
}

-- another quest / dialogue UI is installed: Lorekeeper stays out of its way
local OTHER_QUEST_UIS = { "DialogueUI", "Immersion", "Storyline" }
local blockedBy
local function OtherQuestUI()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not loaded then return nil end
    for _, name in ipairs(OTHER_QUEST_UIS) do
        local ok, on = pcall(loaded, name)
        if ok and on then return name end
    end
    return nil
end

-- true while Lorekeeper is the one showing gossip and quests (H3z0 UI's own
-- quest automation steps aside then, so every quest goes through Lorekeeper)
-- (style "Quest Window": the answers come from lorekeeper_window.lua)
_G.H3z0UI_LorekeeperActive = function()
    if WindowStyle() then
        local W = WindowModule()
        return W and W.IsActive and W.IsActive() or false
    end
    return active and On() or false
end
_G.H3z0UI_LorekeeperBlockedBy = function()
    if WindowStyle() then
        local W = WindowModule()
        return W and W.BlockedBy and W.BlockedBy() or nil
    end
    return blockedBy
end

local function TakeOver()
    if active or not On() then return end
    ShowNames()   -- names left hidden by an earlier session come back
    blockedBy = OtherQuestUI()
    if blockedBy then return end
    active = true
    for _, name in ipairs({ "GossipFrame", "QuestFrame" }) do
        local f = _G[name]
        if f and f.UnregisterAllEvents then f:UnregisterAllEvents() end
        -- if the game still opens its own window, keep it invisible so only
        -- the scroll shows (no second window next to it)
        if f and f.HookScript then
            f:HookScript("OnShow", function(self)
                self:SetAlpha((active and not WindowStyle()) and 0 or 1)
            end)
            if f.IsShown and f:IsShown() and not WindowStyle() then f:SetAlpha(0) end
        end
    end
    for e in pairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
end

local seen, lastEvent, lastErr = 0, nil, nil
ev:SetScript("OnEvent", function(_, event, ...)
    local fn = EVENTS[event]
    if fn then
        seen, lastEvent = seen + 1, event
        local ok, err = pcall(fn, ...)
        if not ok then
            lastErr = tostring(err)
            if geterrorhandler then geterrorhandler()(err) end
        end
    end
end)

-- /h3z0ui lkcheck: says why the scroll is or is not opening
_G.H3z0UI_LorekeeperCheck = function(say)
    local function loaded(n)
        local f = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
        local ok, on = pcall(f, n)
        return ok and on and true or false
    end
    say("Lorekeeper: enabled=" .. tostring(On()) .. " style=" .. tostring(Get("style")) .. " takenOver=" .. tostring(active)
        .. " blockedBy=" .. tostring(blockedBy))
    local reg = {}
    for e in pairs(EVENTS) do reg[#reg + 1] = e .. "=" .. tostring(ev:IsEventRegistered(e) and true or false) end
    table.sort(reg)
    say("Events: " .. table.concat(reg, " "))
    say("Received " .. seen .. " window event(s), last: " .. tostring(lastEvent))
    say("Scroll shown: " .. tostring(panel and panel:IsShown() and true or false)
        .. "  Blizzard gossip frame shown: " .. tostring(_G.GossipFrame and _G.GossipFrame:IsShown() and true or false))
    say("Other addons: TrueReticle=" .. tostring(loaded("TrueReticle")) .. " DynamicCam=" .. tostring(loaded("DynamicCam"))
        .. " CombatMode=" .. tostring(loaded("CombatMode")) .. " ConsolePort=" .. tostring(loaded("ConsolePort")))
    say("Last error: " .. tostring(lastErr or lkErr))
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        -- ConsolePort's cursor can load after the scroll was built
        if panel and not cpRegistered and type(name) == "string" and name:find("^ConsolePort") then
            RegisterConsolePort()
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    pcall(MigrateSizes)
    local ok, err = pcall(TakeOver)
    if not ok then
        lastErr = "TakeOver: " .. tostring(err)
        if geterrorhandler then geterrorhandler()(err) end
    end
end)

_G.H3z0UI_RefreshLorekeeper = function()
    if WindowStyle() then
        local W = WindowModule()
        if W and W.Refresh then W.Refresh() end
        return
    end
    if panel and panel:IsShown() then Render(false) elseif panel then ApplyLook() end
end

-- preview from the settings (no NPC needed)
_G.H3z0UI_LorekeeperTest = function()
    if WindowStyle() then
        local W = WindowModule()
        if W and W.Test then W.Test() end
        return
    end
    local f = Build()
    state.mode = "test"
    state.page = 1
    state.choice = nil
    state.content = {
        npc = "Lady Liadrin", title = "",
        text = "The Light has not abandoned Quel'Thalas, champion. Our scouts report movement along the border, and I would have you see it with your own eyes.\n\nGo to the ridge north of here and report what you find.",
        options = {
            { text = "Tell me more about the border.", icon = "Interface\\GossipFrame\\GossipGossipIcon", run = function() end },
            { text = "I am ready.", icon = QUEST_ICON_AVAILABLE, quest = true, run = function() Lorekeeper.Close() end },
        },
        rewards = {}, sub = "", subHead = "",
        money = "",
    }
    state.mode = "test"
    state.pages = SplitPages(state.content.text)
    local wasOpen = f:IsShown() and not FadingOut()
    Render(true)
    if not f:IsShown() or FadingOut() then FadeIn() end
    f:Show()
    if wasOpen then ContentSwap() end
end

---------------------------------------------------------------------------
-- First-time setup: the four choices that change the feel the most
---------------------------------------------------------------------------
local setup
function Lorekeeper.ShowSetup()
    local db = DB()
    if not db then return end
    if not setup then
        local s = CreateFrame("Frame", "H3z0UI_LorekeeperSetup", UIParent)
        s:SetSize(360, 250)
        s:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        s:SetFrameStrata("DIALOG")
        s:EnableMouse(true)
        local Round = ns.Round
        if Round and Round.Panel then
            local ok, bg = pcall(Round.Panel, s, 10)
            if ok and bg then
                bg:SetAllPoints(s)
                bg:SetFrameLevel(s:GetFrameLevel())
                local fill = Round.SLATE_FILL or { 0.075, 0.095, 0.12 }
                pcall(bg.SetFillColor, bg, fill[1], fill[2], fill[3], 0.97)
                pcall(bg.SetBorderColor, bg, 0, 0, 0, 0)
            end
        end
        local r, g, b = Accent()
        s.title = s:CreateFontString(nil, "OVERLAY")
        SetFont(s.title, 16, "OUTLINE")
        s.title:SetPoint("TOP", 0, -14)
        s.title:SetText("H3z0 UI Lorekeeper")
        s.title:SetTextColor(r, g, b)
        s.sub = s:CreateFontString(nil, "OVERLAY")
        SetFont(s.sub, 11, "")
        s.sub:SetPoint("TOP", s.title, "BOTTOM", 0, -6)
        s.sub:SetWidth(320)
        s.sub:SetText("How do you want to talk to NPCs? Everything can be changed later on the Lorekeeper page (Interface).")
        s.sub:SetTextColor(0.75, 0.75, 0.75)
        s.rows = {}
        local items = {
            { key = "camera", text = "Move the camera in on the NPC" },
            { key = "hideUI", text = "Hide the rest of the UI while talking" },
            { key = "typewriter", text = "Text writes itself out (typewriter)" },
            { key = "keyHints", text = "Show the keys on the buttons" },
        }
        for i, it in ipairs(items) do
            local row = CreateFrame("CheckButton", nil, s, "UICheckButtonTemplate")
            row:SetSize(24, 24)
            row:SetPoint("TOPLEFT", 26, -70 - (i - 1) * 32)
            local label = row:CreateFontString(nil, "OVERLAY")
            SetFont(label, 13, "")
            label:SetPoint("LEFT", row, "RIGHT", 6, 0)
            label:SetText(it.text)
            row.key = it.key
            row:SetScript("OnClick", function(self)
                local d = DB()
                if d then d[self.key] = self:GetChecked() and true or false end
                if _G.H3z0UI_RefreshLorekeeper then _G.H3z0UI_RefreshLorekeeper() end
            end)
            s.rows[#s.rows + 1] = row
        end
        local done = ActionButton(s)
        done:SetPoint("BOTTOM", 0, 14)
        SetFont(done.text, 12, "OUTLINE")
        done.text:SetText("Done")
        done.bg:SetColorTexture(r, g, b, 0.3)
        done.run = function()
            local d = DB()
            if d then d.setupDone = true end
            s:Hide()
        end
        s:Hide()
        setup = s
    end
    for _, row in ipairs(setup.rows) do row:SetChecked(Get(row.key) and true or false) end
    setup:Show()
end
_G.H3z0UI_LorekeeperSetup = function() Lorekeeper.ShowSetup() end

---------------------------------------------------------------------------
-- The scroll is placed only with the Lorekeeper sliders in the H3z0 UI menu
-- (Distance From the Right Edge, Vertical Position). It is not an Edit Mode element.
---------------------------------------------------------------------------
local function RegisterLayout()
    if WindowStyle() then return end      -- the quest window style uses Blizzard's windows
    Holder()
    PlaceHolder()
end


---------------------------------------------------------------------------
-- Free moving from the settings page: Move by Dragging puts a handle over the
-- scroll; dragging it changes the same two values the sliders show.
---------------------------------------------------------------------------
local mover
local function StopMove()
    if not mover then return end
    mover:SetScript("OnUpdate", nil)
    mover:Hide()
    mover.dragging = false
    if panel and panel:IsShown() and state.mode == "test" then panel:Hide() end
    -- rebuild the open Lorekeeper page so the sliders show the new numbers
    local GUI = H3z0UI and H3z0UI.GUI
    local frame = GUI and GUI.MainFrame
    if frame and frame:IsShown() and GUI.FindV2TileByID and GUI.SelectFeatureTile then
        local _, idx = GUI:FindV2TileByID(frame, "h3z_lorekeeper")
        if idx then pcall(GUI.SelectFeatureTile, GUI, frame, idx, { subPageIndex = 1 }) end
    end
end
local function BuildMover()
    if mover then return mover end
    mover = CreateFrame("Frame", "H3z0UI_LorekeeperMover", UIParent)
    mover:SetFrameStrata("FULLSCREEN_DIALOG")
    mover:SetFrameLevel(200)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    local bg = mover:CreateTexture(nil, "OVERLAY")
    bg:SetAllPoints()
    bg:SetColorTexture(0.38, 0.65, 0.98, 0.18)
    local lbl = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOP", 0, -14)
    lbl:SetText("Drag to move Lorekeeper\nArrow keys nudge. Right-click or Esc when done.")
    mover:EnableKeyboard(true)
    mover:SetPropagateKeyboardInput(true)
    local function Save(dx, dy)
        local db = DB()
        if not db then return end
        local ox = math.max(0, math.min(1600, math.floor((tonumber(db.offsetX) or 180) + dx + 0.5)))
        local oy = math.max(-600, math.min(600, math.floor((tonumber(db.offsetY) or 40) + dy + 0.5)))
        db.offsetX, db.offsetY = ox, oy
        PlaceHolder()
    end
    mover:SetScript("OnDragStart", function(self)
        local db = DB()
        if not db then return end
        local s = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        self.dragging = true
        self.sx, self.sy = cx / s, cy / s
        self.ox, self.oy = tonumber(db.offsetX) or 180, tonumber(db.offsetY) or 40
        self:SetScript("OnUpdate", function(f)
            local x, y = GetCursorPosition()
            x, y = x / s, y / s
            db.offsetX = math.max(0, math.min(1600, math.floor(f.ox - (x - f.sx) + 0.5)))
            db.offsetY = math.max(-600, math.min(600, math.floor(f.oy + (y - f.sy) + 0.5)))
            PlaceHolder()
        end)
    end)
    mover:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.dragging = false
    end)
    mover:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then StopMove() end
    end)
    mover:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:SetPropagateKeyboardInput(false); StopMove(); return end
        local step = IsShiftKeyDown() and 10 or 1
        if key == "LEFT" then self:SetPropagateKeyboardInput(false); Save(step, 0)
        elseif key == "RIGHT" then self:SetPropagateKeyboardInput(false); Save(-step, 0)
        elseif key == "UP" then self:SetPropagateKeyboardInput(false); Save(0, step)
        elseif key == "DOWN" then self:SetPropagateKeyboardInput(false); Save(0, -step)
        else self:SetPropagateKeyboardInput(true) end
    end)
    mover:SetScript("OnKeyUp", function(self) self:SetPropagateKeyboardInput(true) end)
    mover:Hide()
    return mover
end
_G.H3z0UI_LorekeeperMove = function()
    if InCombatLockdown() then return end
    if WindowStyle() then return end
    if _G.H3z0UI_LorekeeperTest then _G.H3z0UI_LorekeeperTest() end
    local h = Holder()
    PlaceHolder()
    local m = BuildMover()
    m:ClearAllPoints()
    m:SetAllPoints(h)
    m:Show()
end

local lmEv = CreateFrame("Frame")
lmEv:RegisterEvent("PLAYER_LOGIN")
lmEv:SetScript("OnEvent", function() pcall(RegisterLayout) end)
