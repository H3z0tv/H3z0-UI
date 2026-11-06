local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- One-time settings fixes for existing profiles
---------------------------------------------------------------------------

local function Profile()
    local core = ns.Addon
    return core and core.db and core.db.profile
end

-- Cooldown Manager: no press / click highlight on the icons
local function CDMPressedOff(p)
    local ncdm = p.ncdm
    if type(ncdm) ~= "table" or ncdm._h3zPressedOff then return end
    ncdm._h3zPressedOff = true
    local function Walk(t, depth)
        if type(t) ~= "table" or depth > 4 then return end
        if t.pressedEffect ~= nil then t.pressedEffect = "off" end
        for k, v in pairs(t) do
            if type(v) == "table" and k ~= "ownedSpells" and k ~= "removedSpells" and k ~= "dormantSpells" and k ~= "spellOverrides" then
                Walk(v, depth + 1)
            end
        end
    end
    Walk(ncdm, 0)
end

-- H3z0 resource bars and Cooldown Manager keep their own positions:
-- drop frame anchors an earlier 0.25.0 build may have saved for them
local function DropCDMAnchors(p)
    if p._h3zCDMAnchorsOff then return end
    p._h3zCDMAnchorsOff = true
    local fa = p.frameAnchoring
    if type(fa) ~= "table" then return end
    for _, key in ipairs({ "cdmEssential", "cdmUtility", "buffIcon", "buffBar" }) do
        fa[key] = nil
    end
end

-- H3z0 UI minimap keeps its own position (minimap.position)
local function DropMinimapAnchors(p)
    if p._h3zMinimapAnchorsOff then return end
    p._h3zMinimapAnchorsOff = true
    local fa = p.frameAnchoring
    if type(fa) ~= "table" then return end
    for _, key in ipairs({ "minimap", "datatextPanel" }) do
        fa[key] = nil
    end
end

-- Empty action slots are shown by default now. An earlier build hid them once on Forever; undo that
-- one time (the switch stays in Action Bars > Bar Layout > Hide Empty Slots)
local function ShowEmptySlots(p)
    local ab = p.actionBars
    if type(ab) ~= "table" or ab._h3zEmptyShownDefault then return end
    ab._h3zEmptyShownDefault = true
    -- the Forever default also hid them in profiles made after that change (no flag was saved there)
    if ab._h3zForeverEmptyHidden or (ns.Client and ns.Client.isForever) then
        ab.global = ab.global or {}
        ab.global.hideEmptySlots = false
        C_Timer.After(2, function()
            if _G.H3z0UI_RefreshActionBars then pcall(_G.H3z0UI_RefreshActionBars) end
        end)
    end
end

-- Keybind text: action bars and the Utility cooldowns in the same place (top right, -1 / -7, size 12)
local function KeybindPlace(p)
    if p._h3zKeybindPlace then return end
    p._h3zKeybindPlace = true
    local ab = p.actionBars and p.actionBars.global
    if type(ab) == "table" then
        ab.keybindFontSize, ab.keybindAnchor, ab.keybindOffsetX, ab.keybindOffsetY = 12, "TOPRIGHT", -1, -7
    end
    local u = p.viewers and p.viewers.UtilityCooldownViewer
    if type(u) == "table" then
        u.keybindTextSize, u.keybindAnchor, u.keybindOffsetX, u.keybindOffsetY = 12, "TOPRIGHT", -1, -7
    end
    C_Timer.After(2, function()
        if _G.H3z0UI_RefreshActionBars then pcall(_G.H3z0UI_RefreshActionBars) end
        if _G.H3z0UI_RefreshKeybinds then pcall(_G.H3z0UI_RefreshKeybinds) end
    end)
end

-- Stack count text on the action bars: bottom right, size 12, X -2, Y 1
local function CountPlace(p)
    if p._h3zCountPlace then return end
    p._h3zCountPlace = true
    local ab = p.actionBars and p.actionBars.global
    if type(ab) == "table" then
        ab.showCounts = true
        ab.countFontSize, ab.countAnchor, ab.countOffsetX, ab.countOffsetY = 12, "BOTTOMRIGHT", -2, 1
        C_Timer.After(2, function()
            if _G.H3z0UI_RefreshActionBars then pcall(_G.H3z0UI_RefreshActionBars) end
        end)
    end
end

-- Per-bar text / look values from older defaults (keybind and count text 8 px at
-- -20 / -20, no backdrop, no gloss) beat the global settings on every bar: drop them
local function PerBarLookReset(p)
    if p._h3zPerBarLookReset then return end
    p._h3zPerBarLookReset = true
    local bars = p.actionBars and p.actionBars.bars
    if type(bars) ~= "table" then return end
    local OLD = {
        keybindFontSize = 8, keybindOffsetX = -20, keybindOffsetY = -20,
        macroNameFontSize = 8, macroNameOffsetX = -20, macroNameOffsetY = -20,
        countFontSize = 8, countOffsetX = -20, countOffsetY = -20,
        backdropAlpha = 0, glossAlpha = 0, iconZoom = 0.05,
    }
    for _, key in ipairs({ "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet", "stance" }) do
        local b = bars[key]
        if type(b) == "table" and not b.overrideEnabled then
            for k, v in pairs(OLD) do
                if rawget(b, k) == v then b[k] = nil end
            end
        end
    end
    C_Timer.After(2, function()
        if _G.H3z0UI_RefreshActionBars then pcall(_G.H3z0UI_RefreshActionBars) end
    end)
end

-- Action bars no longer hide when mounting / flying / skyriding (once; turn it
-- on again in Action Bars > Mouseover Hide > Mounted & Flying)
local function BarsStayWhenMounted(p)
    local v = p.actionBarsVisibility
    if type(v) ~= "table" or v._h3zMountShown then return end
    v._h3zMountShown = true
    v.hideWhenMounted = false
    v.hideWhenFlying = false
    v.hideWhenSkyriding = false
    C_Timer.After(2, function()
        if _G.H3z0UI_RefreshActionBarsVisibility then pcall(_G.H3z0UI_RefreshActionBarsVisibility) end
    end)
end

-- Buff / debuff icons: no dark cooldown swipe (once; Autohide or
-- Action Bars > Buff/Debuff Frames > Hide Duration Swipe brings it back)
local function BuffSwipeOff(p)
    local b = p.buffBorders
    if type(b) ~= "table" or b._h3zSwipeOff then return end
    b._h3zSwipeOff = true
    b.hideSwipe = true
    C_Timer.After(2, function()
        if _G.H3z0UI_RefreshBuffBorders then pcall(_G.H3z0UI_RefreshBuffBorders) end
    end)
end

-- 0.25.5: the H3z0 Pro M+ timer is back and is the default layout (once)
local function ProTimer(p)
    local m = p.mplusTimer
    if type(m) ~= "table" or m._h3zProTimer025 then return end
    m._h3zProTimer025 = true
    m.layoutMode = "pro"
    local t = _G.H3z0UI_MPlusTimer
    if t and t.UpdateLayout and t.frames and t.frames.root then pcall(t.UpdateLayout, t) end
end

-- 0.25.8: every skin is on by default (once per profile; switch any off again
-- on Appearance > Skinning). Most skins apply on load, so a reload is asked for.
local ALL_SKINS = {
    "skinAchievement", "skinAlerts", "skinAuctionHouse", "skinBank", "skinCharacterFrame",
    "skinCollections", "skinCommunities", "skinContextMenus", "skinCraftingOrders", "skinDelves",
    "skinDressUp", "skinEncounterJournal", "skinFlightMap", "skinFriends", "skinGameMenu",
    "skinGossip", "skinGuildBank", "skinGuildRegistrar", "skinInspectFrame", "skinInstanceFrames",
    "skinItemUpgrade", "skinKeystoneFrame", "skinLegacySystem", "skinMacro", "skinMail",
    "skinMerchant", "skinMirrorTimers", "skinObjectiveTracker", "skinOverrideActionBar", "skinPVPMatch",
    "skinPowerBarAlt", "skinProfessions", "skinQuest", "skinReadyCheck", "skinSocket",
    "skinSpellBook", "skinStable", "skinStaticPopups", "skinStatusTrackingBars", "skinTabard",
    "skinTrade", "skinTrainer", "skinWeeklyRewards", "skinWorldMap", "skinLootWindow",
    "skinLootHistory", "skinRollFrames", "skinDamageMeter", "skinHousing",
}

local function AllSkinsOn(p)
    local g = p.general
    if type(g) ~= "table" or g._h3zAllSkins0258 then return end
    g._h3zAllSkins0258 = true
    local changed = false
    for _, key in ipairs(ALL_SKINS) do
        if g[key] ~= true then
            g[key] = true
            changed = true
        end
    end
    if type(p.skinning) == "table" and p.skinning.enabled == false then
        p.skinning.enabled = true
        changed = true
    end
    if changed and ns.NeedReload then
        ns.NeedReload("H3z0 UI 0.25.8 switches every skin on (Appearance > Skinning).")
    end
end

-- Blizzard's own minimap coordinates (the numbers above the info bar). The
-- setting "Show Minimap Coordinates" is a game setting; H3z0 UI keeps it off
-- and hides the frame.
local function HideBlizzardMinimapCoords()
    if SetCVar then pcall(SetCVar, "minimapShowPlayerCoords", "0") end
    local found = {}
    for _, root in ipairs({ _G.MinimapCluster, _G.Minimap, _G.MinimapBackdrop }) do
        if root and root.PlayerCoords then found[#found + 1] = root.PlayerCoords end
    end
    for _, f in ipairs(found) do
        if not f._h3zNoCoords then
            f._h3zNoCoords = true
            f:HookScript("OnShow", function(self) self:Hide() end)
        end
        f:Hide()
        if f.CoordText then f.CoordText:SetText("") end
    end
end
_G.H3z0UI_HideMinimapCoords = HideBlizzardMinimapCoords

-- Forever: the Adventure Guide button of the game's micro menu calls two functions that are not
-- always there. If they are missing, give them a safe stand-in so a click does not raise an error.
local function ForeverAdventureGuide()
    if not (ns.Client and ns.Client.isForever) then return end
    local function Load()
        local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if not load then return end
        for _, name in ipairs({ "Blizzard_EncounterJournal", "Blizzard_AdventureGuide" }) do
            pcall(load, name)
        end
    end
    if not _G.CanShowEncounterJournal then
        _G.CanShowEncounterJournal = function() return true end
    end
    if not _G.ToggleEncounterJournal then
        local standIn
        standIn = function(...)
            Load()
            local real = _G.ToggleEncounterJournal
            if real and real ~= standIn then return real(...) end
            local f = _G.EncounterJournal or _G.AdventureGuideFrame
            if f then
                if f:IsShown() then HideUIPanel(f) else ShowUIPanel(f) end
            end
        end
        _G.ToggleEncounterJournal = standIn
    end
end

-- Forever: whatever the missing piece is, a click on the micro menu's Adventure Guide button must
-- not raise an error. Its click runs inside a protected call, so a failure is caught here and the
-- Adventure Guide window is opened directly instead.
local function ForeverAdventureButton()
    if not (ns.Client and ns.Client.isForever) then return end
    local b = _G.EJMicroButton
    if not b or b._h3zClickGuard or not b.GetScript then return end
    local orig = b:GetScript("OnClick")
    if not orig then return end
    b._h3zClickGuard = true
    b:SetScript("OnClick", function(self, ...)
        local ok = pcall(orig, self, ...)
        if ok then return end
        local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if load then
            for _, name in ipairs({ "Blizzard_EncounterJournal", "Blizzard_AdventureGuide" }) do pcall(load, name) end
        end
        local f = _G.EncounterJournal or _G.AdventureGuideFrame
        if f then
            if f:IsShown() then HideUIPanel(f) else ShowUIPanel(f) end
        end
    end)
end

-- Forever: the game's damage meter draws its resize handle (bottom right corner) from an image
-- the Forever client does not have, so it shows as a red question mark. Where the image is
-- missing, the handle gets the game's own chat window grabber instead.
local function FixMeterHandles()
    if not (C_Texture and C_Texture.GetAtlasInfo) then return end
    if C_Texture.GetAtlasInfo("damagemeters-scalehandle") then return end
    local function Fix(btn)
        if not btn or btn._h3zHandleFixed or not btn.SetNormalTexture then return end
        btn._h3zHandleFixed = true
        btn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        btn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        btn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        btn:SetSize(22, 22)
    end
    for i = 1, 6 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then
            local mc = w.MinimizeContainer or (w.GetMinimizeContainer and w:GetMinimizeContainer())
            Fix(mc and mc.ResizeButton)
            Fix(w.SourceWindow and w.SourceWindow.ResizeButton)
            if mc and mc.SourceWindow then Fix(mc.SourceWindow.ResizeButton) end
        end
    end
end

-- Forever and Classic: the player's resource bar is either ON THE FRAME (under the health bar, with
-- the frame's own number) or the SEPARATE floating bars. Only one of the two is on at a time.
-- mode = "frame" | "separate"
local function ApplyResourceMode(p, mode)
    if type(p) ~= "table" then return end
    p.h3zResourceMode = mode
    local uf = p.h3z0uiUnitFrames
    local u = type(uf) == "table" and uf.player
    if type(u) == "table" then
        u.showPowerBar = (mode == "frame")
        if mode == "frame" then u.powerBarBorder = true end
    end
    p.powerBar = p.powerBar or {}
    p.secondaryPowerBar = p.secondaryPowerBar or {}
    p.powerBar.enabled = (mode == "separate")
    p.secondaryPowerBar.enabled = (mode == "separate")
    local core = ns.Addon
    if core then
        if core.UpdatePowerBar then pcall(core.UpdatePowerBar, core) end
        if core.UpdateSecondaryPowerBar then pcall(core.UpdateSecondaryPowerBar, core) end
    end
    if _G.H3z0UI_RefreshUnitFrames then pcall(_G.H3z0UI_RefreshUnitFrames) end
end
_G.H3z0UI_ApplyResourceMode = function(mode)
    local p = Profile()
    if p then ApplyResourceMode(p, mode) end
end

-- first time on Forever / Classic: the resource bar is on the frame (with a number), the floating
-- bars are off, and the Target frame gets its resource bar under the health bar too
-- the number of the resource bar sits right under the frame, below the health number
local function PowerTextPlace(p)
    if not (ns.Client and ns.Client.isLegacy) or p._h3zPowerText3 then return end
    p._h3zPowerText3 = true
    local uf = p.h3z0uiUnitFrames
    local u = type(uf) == "table" and uf.player
    if type(u) == "table" then
        u.powerTextAnchor, u.powerTextOffsetX, u.powerTextOffsetY, u.powerTextFontSize = "BOTTOMRIGHT", -9, -20, 12
    end
    C_Timer.After(2, function()
        if _G.H3z0UI_RefreshUnitFrames then pcall(_G.H3z0UI_RefreshUnitFrames) end
    end)
end

-- the character window changes of 0.28.0 build 26 were taken back: item names on again once
local function UndoSlotText(p)
    if not p._h3zSlotText1 or p._h3zSlotTextUndo then return end
    p._h3zSlotTextUndo = true
    if type(p.character) == "table" then p.character.showEquipmentName = true end
end

-- the Target frame shows its resource number too, under the frame at the left (the frame is mirrored)
local function TargetPowerText(p)
    if not (ns.Client and ns.Client.isLegacy) or p._h3zTargetPowerText1 then return end
    p._h3zTargetPowerText1 = true
    local uf = p.h3z0uiUnitFrames
    local u = type(uf) == "table" and uf.target
    if type(u) == "table" then
        u.showPowerText, u.powerTextFormat = true, "current"
        u.powerTextAnchor, u.powerTextOffsetX, u.powerTextOffsetY, u.powerTextFontSize = "BOTTOMLEFT", 9, -20, 12
    end
    C_Timer.After(2, function()
        if _G.H3z0UI_RefreshUnitFrames then pcall(_G.H3z0UI_RefreshUnitFrames) end
    end)
end

local function SharedResourceBar(p)
    if not (ns.Client and ns.Client.isLegacy) or p._h3zResourceMode1 then return end
    p._h3zResourceMode1 = true
    local uf = p.h3z0uiUnitFrames
    if type(uf) ~= "table" then return end
    for _, key in ipairs({ "player", "target" }) do
        local u = uf[key]
        if type(u) == "table" then
            u.showPowerBar, u.powerBarHeight, u.powerBarBorder = true, 6, true
            if key == "player" then u.showPowerText, u.powerTextFormat = true, "current" end
        end
    end
    p._h3zSharedBar = true
    C_Timer.After(2, function() ApplyResourceMode(p, "frame") end)
end

-- /h3z0ui chardump prints the large images of the character window (frame, layer, size, colour)
local function CharacterRoots()
    local roots = {}
    local function Add(f) if f and f.GetChildren then roots[#roots + 1] = f end end
    Add(_G.CharacterFrame); Add(_G.PaperDollFrame); Add(_G.CharacterModelScene); Add(_G.CharacterModelFrame)
    if _G.CharacterFrame then Add(_G.CharacterFrame.Inset); Add(_G.CharacterFrame.RightPaneHost) end
    Add(_G.CharacterFrameInset)
    return roots
end

local function WalkRegions(frame, depth, fn, seen)
    if not frame or depth > 3 or seen[frame] then return end
    seen[frame] = true
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "Texture" then fn(frame, r) end
        end
    end
    if frame.GetChildren then
        for _, c in ipairs({ frame:GetChildren() }) do WalkRegions(c, depth + 1, fn, seen) end
    end
end

function _G.H3z0UI_CharacterDump()
    local seen, n = {}, 0
    for _, root in ipairs(CharacterRoots()) do
        WalkRegions(root, 0, function(f, r)
            if r.IsShown and r:IsShown() then
                local w, h = r:GetSize()
                if w and h and w >= 60 and h >= 60 then
                    n = n + 1
                    if n <= 40 then
                        local vr, vg, vb = 1, 1, 1
                        if r.GetVertexColor then vr, vg, vb = r:GetVertexColor() end
                        print(string.format("|cff66ccffchar|r %s / %s  %dx%d  a=%.2f  atlas=%s  tex=%s  rgb=%.1f,%.1f,%.1f",
                            tostring(f.GetName and f:GetName() or f.GetObjectType and f:GetObjectType()),
                            tostring(r.GetName and r:GetName() or r.GetDrawLayer and r:GetDrawLayer()),
                            w, h, r:GetAlpha() or 1, tostring(r.GetAtlas and r:GetAtlas()), tostring(r.GetTexture and r:GetTexture()), vr, vg, vb))
                    end
                end
            end
        end, seen)
    end
    print("|cff66ccffchar|r " .. n .. " large textures shown")
    -- textures with Background in their name, shown or not (the race picture pieces)
    local m = 0
    for _, root in ipairs(CharacterRoots()) do
        WalkRegions(root, 0, function(f, r)
            local nm = r.GetName and r:GetName()
            if nm and nm:find("Background") and m < 12 then
                m = m + 1
                print(string.format("|cff66ccffchar bg|r %s  shown=%s  a=%.2f  tex=%s  atlas=%s", nm, tostring(r:IsShown()),
                    r:GetAlpha() or 1, tostring(r.GetTexture and r:GetTexture()), tostring(r.GetAtlas and r:GetAtlas())))
            end
        end, {})
    end
    if m == 0 then print("|cff66ccffchar bg|r no textures named Background") end
end

-- Forever: the game lays a dark cover (UI-Character-Info-RaceBG-Overlay, 85%) over the model area of
-- the character window, but hides the picture it is meant to cover, so it shows as a black box. Only
-- that one image is made invisible (0%); nothing else in the window is touched.
local COVER_ATLAS, COVER_ALPHA = "UI-Character-Info-RaceBG-Overlay", 0
local function ForeverModelCover()
    if not (ns.Client and ns.Client.isForever) then return end
    local scene = _G.CharacterModelScene
    if not (scene and scene.GetRegions) then return end
    for _, r in ipairs({ scene:GetRegions() }) do
        if r.GetAtlas and r:GetAtlas() == COVER_ATLAS then
            if not r._h3zCoverHooked then
                r._h3zCoverHooked = true
                -- the game sets the cover back when the window updates: keep it at 0%
                hooksecurefunc(r, "SetAlpha", function(self, a)
                    if self._h3zCoverSetting then return end
                    if a and a > COVER_ALPHA then
                        self._h3zCoverSetting = true
                        self:SetAlpha(COVER_ALPHA)
                        self._h3zCoverSetting = nil
                    end
                end)
            end
            r._h3zCoverSetting = true
            r:SetAlpha(COVER_ALPHA)
            r._h3zCoverSetting = nil
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local p = Profile()
    if not p then return end
    pcall(CDMPressedOff, p)
    pcall(DropCDMAnchors, p)
    pcall(DropMinimapAnchors, p)
    pcall(ShowEmptySlots, p)
    pcall(SharedResourceBar, p)
    pcall(PowerTextPlace, p)
    pcall(TargetPowerText, p)
    pcall(UndoSlotText, p)
    pcall(KeybindPlace, p)
    pcall(CountPlace, p)
    pcall(PerBarLookReset, p)
    pcall(BarsStayWhenMounted, p)
    pcall(BuffSwipeOff, p)
    pcall(ProTimer, p)
    pcall(AllSkinsOn, p)
    pcall(HideBlizzardMinimapCoords)
    pcall(ForeverAdventureGuide)
    pcall(ForeverAdventureButton)
    if ns.Client and ns.Client.isForever and _G.CharacterFrame and _G.CharacterFrame.HookScript then
        pcall(ForeverModelCover)
        _G.CharacterFrame:HookScript("OnShow", function() pcall(ForeverModelCover) end)
    end
    if ns.Client and ns.Client.isForever and C_Timer then
        pcall(FixMeterHandles)
        C_Timer.NewTicker(4, function() pcall(FixMeterHandles) end, 15)
    end
    if C_Timer then C_Timer.After(5, function() pcall(ForeverAdventureButton) end) end
    if C_Timer then C_Timer.After(3, function() pcall(HideBlizzardMinimapCoords) end) end
end)
