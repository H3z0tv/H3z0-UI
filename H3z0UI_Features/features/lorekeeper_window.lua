---------------------------------------------------------------------------
-- H3z0 UI - Lorekeeper
-- Extras for the quest and NPC (gossip) windows. The windows themselves are
-- the normal ones with the H3z0 UI skin (Appearance > Skinning > Quest /
-- Gossip); Lorekeeper adds:
--   * camera: moves in on the NPC while you talk, back where it was afterwards
--   * typewriter: the NPC / quest text writes itself out (click the window to
--     show it all at once)
--   * editing: font sizes for the text, titles, choices and rewards, and the
--     size of the windows (move them by dragging, Blizzard Frame Mover: Quest)
-- Not used while another quest UI (DialogueUI, Immersion, Storyline) is loaded.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local Helpers = ns.Helpers

-- Lorekeeper style "Quest Window": the extras on the normal quest / NPC windows.
-- lorekeeper.lua (the scroll style) calls this one when that style is picked.
local Lorekeeper = {}
ns.H3z0LorekeeperWindow = Lorekeeper

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = true, style = "scroll",
    camera = true, cameraDistance = 5,
    typewriter = true, typeSpeed = 60,
    fonts = true,
    fontSize = 15, titleSize = 18, optionSize = 14, rewardSize = 13,
    scale = 1,
    npcWidth = 0, npcHeight = 0, questWidth = 0, questHeight = 0,
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

local function On() return Get("enabled") ~= false and Get("style") == "window" end

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

local active = false
local function Active() return active and On() end

-- true while Lorekeeper looks after the quest windows (H3z0 UI's own quest
-- automation steps aside then, so no quest text is skipped)
Lorekeeper.IsActive = function() return Active() or false end
Lorekeeper.BlockedBy = function() return blockedBy end

---------------------------------------------------------------------------
-- Camera: move in on the NPC, back to where it was afterwards
---------------------------------------------------------------------------
local savedZoom
local function CameraIn()
    if not Get("camera") or savedZoom then return end
    if not (UnitExists("npc") and not UnitIsUnit("npc", "player")) then return end
    if not (GetCameraZoom and CameraZoomIn and CameraZoomOut) then return end
    local zoom = GetCameraZoom()
    if not zoom then return end
    savedZoom = zoom
    local want = math.max(1, math.min(20, tonumber(Get("cameraDistance")) or 5))
    if zoom > want then CameraZoomIn(zoom - want) elseif zoom < want then CameraZoomOut(want - zoom) end
end

local function CameraOut()
    if not savedZoom then return end
    local want, zoom = savedZoom, GetCameraZoom and GetCameraZoom()
    savedZoom = nil
    if not zoom then return end
    if zoom > want then CameraZoomIn(zoom - want) elseif zoom < want then CameraZoomOut(want - zoom) end
end

local function Talking()
    local q, g = _G.QuestFrame, _G.GossipFrame
    return (q and q:IsShown()) or (g and g:IsShown()) or false
end

---------------------------------------------------------------------------
-- Typewriter: reveals a text with an alpha gradient. The whole text is shown
-- by putting the gradient start past the end (a length of 0 is not allowed).
---------------------------------------------------------------------------
local typer = CreateFrame("Frame")
typer:Hide()
local typeFS, typePos, typeLen

local function Len(fs)
    local ok, t = pcall(fs.GetText, fs)
    return (ok and type(t) == "string") and #t or 0
end

local function ShowAll(fs)
    if fs then pcall(fs.SetAlphaGradient, fs, Len(fs) + 1, 1) end
end

local function StopTyping()
    typer:Hide()
    if typeFS then ShowAll(typeFS) end
    typeFS = nil
end

typer:SetScript("OnUpdate", function(self, elapsed)
    if not typeFS or not typeFS:IsVisible() then StopTyping() return end
    typePos = typePos + elapsed * (tonumber(Get("typeSpeed")) or 60)
    if typePos >= typeLen then StopTyping() return end
    pcall(typeFS.SetAlphaGradient, typeFS, math.max(0, math.floor(typePos)), 24)
end)

-- every text Lorekeeper may type keeps the whole text visible when Blizzard
-- puts a new text in it while nothing is being typed
local guarded = {}
local function Guard(fs)
    if not fs or guarded[fs] then return end
    guarded[fs] = true
    hooksecurefunc(fs, "SetText", function(self)
        if typeFS ~= self then ShowAll(self) end
    end)
end

local function Type(fs)
    if not fs then return end
    Guard(fs)
    if typeFS and typeFS ~= fs then StopTyping() end
    local n = Len(fs)
    if not Active() or not Get("typewriter") or n == 0 then ShowAll(fs) return end
    typeFS, typePos, typeLen = fs, 0, n
    pcall(fs.SetAlphaGradient, fs, 0, 24)
    typer:Show()
end

---------------------------------------------------------------------------
-- Fonts (editing): sizes for the texts of the quest and gossip windows. The
-- font itself stays the H3z0 UI / skin font, only the size changes.
---------------------------------------------------------------------------
local function Size(fs, size)
    if not (fs and fs.GetFont and fs.SetFont) then return end
    local path, cur, flags = fs:GetFont()
    size = tonumber(size)
    if not path or not size or cur == size then return end
    pcall(fs.SetFont, fs, path, size, flags or "")
end

local BODY = { "GreetingText", "QuestInfoDescriptionText", "QuestProgressText", "QuestInfoRewardText" }
local TITLES = { "QuestInfoTitleHeader", "QuestProgressTitleText", "QuestInfoDescriptionHeader",
    "QuestInfoObjectivesHeader", "CurrentQuestsText", "AvailableQuestsText" }
local REWARDS = { "QuestInfoObjectivesText", "QuestInfoGroupSize", "QuestProgressRequiredItemsText" }

local function ApplyQuestFonts()
    if not (Active() and Get("fonts")) then return end
    for _, n in ipairs(BODY) do Size(_G[n], Get("fontSize")) end
    for _, n in ipairs(TITLES) do Size(_G[n], Get("titleSize")) end
    for _, n in ipairs(REWARDS) do Size(_G[n], Get("rewardSize")) end
    local rf = _G.QuestInfoRewardsFrame
    if rf then
        Size(rf.Header, Get("titleSize"))
        Size(rf.ItemChooseText, Get("rewardSize"))
        Size(rf.ItemReceiveText, Get("rewardSize"))
        for _, b in pairs(rf.RewardButtons or {}) do Size(b.Name, Get("rewardSize")) end
    end
    for i = 1, 6 do
        local b = _G["QuestProgressItem" .. i]
        if b then Size(b.Name or _G["QuestProgressItem" .. i .. "Name"], Get("rewardSize")) end
    end
end

-- gossip rows: the size has to be set before the row measures its height, so
-- it is done the moment a row is taken
local fontPath
local function GossipRow(row)
    if not (row and Active() and Get("fonts")) then return end
    if row.GreetingText then
        Size(row.GreetingText, Get("fontSize"))
        fontPath = fontPath or row.GreetingText:GetFont()
    end
    local fs = row.GetFontString and row:GetFontString()
    if fs then
        Size(fs, Get("optionSize"))
        fontPath = fontPath or fs:GetFont()
    end
end

-- the list works out how tall every row is from its text. With bigger text
-- the rows have to be measured with the new size, or the list ends too early
-- (the last choices can't be reached) and rows run over each other.
local measureFS
local function MeasureText(text, size, width)
    if not measureFS then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
        measureFS = holder:CreateFontString(nil, "OVERLAY")
        measureFS:SetWordWrap(true)
    end
    local path = fontPath or (Helpers and Helpers.GetGeneralFont and Helpers.GetGeneralFont()) or STANDARD_TEXT_FONT
    if not pcall(measureFS.SetFont, measureFS, path, size, "") then return nil end
    measureFS:SetWidth(math.max(50, width))
    if issecretvalue and issecretvalue(text) then return nil end
    measureFS:SetText(text)
    local h = measureFS:GetStringHeight()
    if issecretvalue and issecretvalue(h) then return nil end
    return h
end

local function ElementText(data)
    if type(data) ~= "table" then return nil end
    local info = data.info
    if type(info) == "table" then
        local t = info.name or info.title or info.text
        if type(t) == "string" and t ~= "" then return t, false end
    end
    local t = data.text or data.greetingText or data.titleText
    if type(t) == "string" and t ~= "" then return t, true end
    return nil
end

local GREET_PAD, OPTION_PAD, OPTION_MIN = 14, 8, 18

-- height one row of the list needs with Lorekeeper's sizes (nil: not known)
local function RowExtent(data, boxWidth)
    local text, greet = ElementText(data)
    if not text then return nil end
    local size = tonumber(greet and Get("fontSize") or Get("optionSize")) or 14
    if not Get("fonts") then size = greet and 14 or 13 end
    local h = MeasureText(text, size, (boxWidth or 300) - (greet and 24 or 44))
    if not h then return nil end
    if greet then return math.ceil(h + GREET_PAD) end
    return math.max(OPTION_MIN, math.ceil(h + OPTION_PAD))
end

local gossipHooked = false
local function HookGossipRows()
    local g = _G.GossipFrame
    local box = g and g.GreetingPanel and g.GreetingPanel.ScrollBox
    if gossipHooked or not box or not (ScrollUtil and ScrollUtil.AddAcquiredFrameCallback) then return false end
    gossipHooked = true
    ScrollUtil.AddAcquiredFrameCallback(box, function(_, frame) GossipRow(frame) end, Lorekeeper, true)
    -- row heights measured with Lorekeeper's sizes
    local view = box.GetView and box:GetView()
    if view and view.SetElementExtentCalculator then
        local old = view.elementExtentCalculator
        local ok = pcall(view.SetElementExtentCalculator, view, function(dataIndex, data)
            if Active() and Get("fonts") then
                local h = RowExtent(data, box:GetWidth())
                if h then return h end
            end
            if old then return old(dataIndex, data) end
            return OPTION_MIN
        end)
        Lorekeeper.extentHooked = ok
    end
    -- the list lays itself out again (scrolling, updates): check the rows after it
    if type(box.Layout) == "function" then
        hooksecurefunc(box, "Layout", function()
            if Lorekeeper.fixPending then return end
            Lorekeeper.fixPending = true
            C_Timer.After(0, function()
                Lorekeeper.fixPending = false
                if Lorekeeper.FixGossipLayout then Lorekeeper.FixGossipLayout() end
            end)
        end)
    end
    return true
end

-- safety net: if rows still run over each other, make them taller and stack
-- them under each other with the same gaps as before
local function FixGossipLayout()
    if not (Active() and Get("fonts")) then return end
    local g = _G.GossipFrame
    local box = g and g:IsShown() and g.GreetingPanel and g.GreetingPanel.ScrollBox
    if not (box and box.ForEachFrame) then return end
    local rows = {}
    pcall(box.ForEachFrame, box, function(row)
        if row:IsShown() and row:GetTop() then rows[#rows + 1] = row end
    end)
    if #rows == 0 then return end
    table.sort(rows, function(a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)
    local overlap = false
    for _, row in ipairs(rows) do
        local text = row.GreetingText or (row.GetFontString and row:GetFontString())
        local th = text and text.GetStringHeight and text:GetStringHeight()
        if th ~= nil and issecretvalue and issecretvalue(th) then th = nil end
        if th and th > (row:GetHeight() or 0) + 1 then
            overlap = true
            break
        end
    end
    if not overlap then return end
    local gaps, dx = {}, {}
    for i = 2, #rows do
        local gap = (rows[i - 1]:GetBottom() or 0) - (rows[i]:GetTop() or 0)
        gaps[i] = math.max(0, math.min(gap, 16))
        dx[i] = (rows[i]:GetLeft() or 0) - (rows[i - 1]:GetLeft() or 0)
    end
    local top0 = rows[1]:GetTop()
    for i, row in ipairs(rows) do
        local text = row.GreetingText or (row.GetFontString and row:GetFontString())
        if text and text.GetStringHeight then
            local h = text:GetStringHeight() or 0
            if issecretvalue and issecretvalue(h) then h = 0 end
            local want = row.GreetingText and math.ceil(h + GREET_PAD) or math.max(OPTION_MIN, math.ceil(h + OPTION_PAD))
            if math.abs((row:GetHeight() or 0) - want) > 0.5 then
                local w = row:GetWidth()
                row:SetHeight(want)
                if w and w > 0 then row:SetWidth(w) end
            end
        end
        if i > 1 then
            local w = row:GetWidth()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", dx[i] or 0, -(gaps[i] or 0))
            if w and w > 0 then row:SetWidth(w) end
        end
    end
    local target = (box.GetScrollTarget and box:GetScrollTarget()) or box.ScrollTarget
    local bottom = rows[#rows]:GetBottom()
    if target and top0 and bottom then
        local need = (target:GetTop() or top0) - bottom + 10
        if need > (target:GetHeight() or 0) then pcall(target.SetHeight, target, need) end
    end
end

Lorekeeper.FixGossipLayout = FixGossipLayout

local function GossipGreeting()
    local g = _G.GossipFrame
    local box = g and g.GreetingPanel and g.GreetingPanel.ScrollBox
    local found
    if box and box.ForEachFrame then
        pcall(box.ForEachFrame, box, function(row)
            if not found and row.GreetingText and row:IsShown() then found = row.GreetingText end
        end)
    end
    return found
end

---------------------------------------------------------------------------
-- Window size: scale, and width / height of the NPC and quest windows
-- (0 = the normal size)
---------------------------------------------------------------------------
local orig = {}
local function Remember(f)
    if f and not orig[f] then orig[f] = { w = f:GetWidth(), h = f:GetHeight() } end
    return f and orig[f]
end

local QUEST_SCROLLS = { "QuestDetailScrollFrame", "QuestProgressScrollFrame", "QuestRewardScrollFrame", "QuestGreetingScrollFrame" }
local QUEST_CHILDREN = { "QuestDetailScrollChildFrame", "QuestProgressScrollChildFrame", "QuestRewardScrollChildFrame", "QuestGreetingScrollChildFrame" }
local QUEST_TEXTS = { "QuestInfoTitleHeader", "QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestInfoRewardText",
    "QuestProgressTitleText", "QuestProgressText", "GreetingText" }
local questDW, questDH = 0, 0

-- the quest window's inside grows with it (scroll areas and text width)
local function StretchQuestInside()
    for _, n in ipairs(QUEST_SCROLLS) do
        local f = _G[n]
        local o = Remember(f)
        if o and o.w and o.h then
            pcall(f.SetSize, f, math.max(50, o.w + questDW), math.max(50, o.h + questDH))
        end
    end
    for _, n in ipairs(QUEST_CHILDREN) do
        local f = _G[n]
        local o = Remember(f)
        if o and o.w then pcall(f.SetWidth, f, math.max(50, o.w + questDW)) end
    end
    for _, n in ipairs(QUEST_TEXTS) do
        local f = _G[n]
        local o = Remember(f)
        if o and o.w and o.w > 0 then pcall(f.SetWidth, f, math.max(50, o.w + questDW)) end
    end
end

-- the NPC window's inside (the list and its scroll bar) grows with the window
local GOSSIP_PARTS = { "GreetingPanel", "ScrollBox", "ScrollBar" }
local function GossipParts()
    local g = _G.GossipFrame
    local p = g and g.GreetingPanel
    if not p then return {} end
    return { p, p.ScrollBox, p.ScrollBar }
end

local function StretchGossipInside(dW, dH)
    for i, f in ipairs(GossipParts()) do
        local o = f and Remember(f)
        if o and o.w and o.h then
            if i == 3 then
                pcall(f.SetHeight, f, math.max(30, o.h + dH))      -- the scroll bar only gets taller
            else
                pcall(f.SetSize, f, math.max(60, o.w + dW), math.max(30, o.h + dH))
            end
        end
    end
end

-- how tall the whole list is (every row, also the ones that don't fit)
local function GossipContentHeight()
    local g = _G.GossipFrame
    local box = g and g.GreetingPanel and g.GreetingPanel.ScrollBox
    local dp = box and box.GetDataProvider and box:GetDataProvider()
    if not (dp and dp.Enumerate) then return nil end
    local total, n = 0, 0
    local ok = pcall(function()
        for _, data in dp:Enumerate() do
            n = n + 1
            total = total + (RowExtent(data, box:GetWidth()) or OPTION_MIN) + 2
        end
    end)
    if not ok or n == 0 then return nil end
    return total + 16
end

local function ApplyScale()
    if InCombatLockdown() then return end
    local on = Active()
    local s = on and (tonumber(Get("scale")) or 1) or 1
    for _, name in ipairs({ "QuestFrame", "GossipFrame" }) do
        local f = _G[name]
        if f and f.GetScale and math.abs((f:GetScale() or 1) - s) > 0.001 then pcall(f.SetScale, f, s) end
    end
    local sizes = { GossipFrame = { "npcWidth", "npcHeight" }, QuestFrame = { "questWidth", "questHeight" } }
    for name, keys in pairs(sizes) do
        local f = _G[name]
        local o = Remember(f)
        if o then
            local w = on and tonumber(Get(keys[1])) or 0
            local h = on and tonumber(Get(keys[2])) or 0
            local W = (w and w > 0) and w or o.w
            local H = (h and h > 0) and h or o.h
            -- NPC window at height 0: as tall as the whole list needs (up to most of the screen)
            if on and name == "GossipFrame" and not (h and h > 0) then
                local box = f.GreetingPanel and f.GreetingPanel.ScrollBox
                local ob = box and Remember(box)
                local need = GossipContentHeight()
                if ob and ob.h and need and need > ob.h then
                    local maxH = (UIParent:GetHeight() or 800) * 0.85 / math.max(0.1, s)
                    H = math.min(maxH, o.h + (need - ob.h))
                end
            end
            if math.abs((f:GetWidth() or 0) - W) > 0.5 or math.abs((f:GetHeight() or 0) - H) > 0.5 then
                pcall(f.SetSize, f, W, H)
            end
            if name == "QuestFrame" then
                questDW, questDH = W - o.w, H - o.h
                StretchQuestInside()
            else
                StretchGossipInside(W - o.w, H - o.h)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function QuestText(mode)
    if mode == "greeting" then return _G.GreetingText end
    if mode == "detail" then return _G.QuestInfoDescriptionText end
    if mode == "progress" then return _G.QuestProgressText end
    if mode == "complete" then return _G.QuestInfoRewardText end
end

local function OnQuest(mode)
    CameraIn()
    ApplyScale()
    -- after Blizzard (and the skin) filled the window
    C_Timer.After(0, function()
        if not Active() then return end
        ApplyQuestFonts()
        Type(QuestText(mode))
    end)
end

local rebuilding = false
local function OnGossip()
    CameraIn()
    ApplyScale()
    local g = _G.GossipFrame
    if HookGossipRows() and Get("fonts") and g and g.Update and not rebuilding then
        -- the first time: build the list again so the rows measure the new sizes
        rebuilding = true
        pcall(g.Update, g)
        rebuilding = false
    end
    C_Timer.After(0, function()
        if not Active() then return end
        ApplyScale()
        FixGossipLayout()
        Type(GossipGreeting())
    end)
    -- once more when the window has settled (fonts / skin applied late)
    C_Timer.After(0.05, FixGossipLayout)
end

local closeTimer
local function ClosedSoon()
    if closeTimer then closeTimer:Cancel() end
    closeTimer = C_Timer.NewTimer(0.25, function()
        closeTimer = nil
        if not Talking() then
            StopTyping()
            CameraOut()
        end
    end)
end

local ev = CreateFrame("Frame")
local EVENTS = {
    GOSSIP_SHOW = OnGossip,
    GOSSIP_CLOSED = ClosedSoon,
    QUEST_GREETING = function() OnQuest("greeting") end,
    QUEST_DETAIL = function() OnQuest("detail") end,
    QUEST_PROGRESS = function() OnQuest("progress") end,
    QUEST_COMPLETE = function() OnQuest("complete") end,
    QUEST_FINISHED = ClosedSoon,
    QUEST_ITEM_UPDATE = function() C_Timer.After(0, ApplyQuestFonts) end,
    PLAYER_REGEN_ENABLED = ApplyScale,
}
ev:SetScript("OnEvent", function(_, event, ...)
    if not Active() then return end
    local fn = EVENTS[event]
    if fn then
        local ok, err = pcall(fn, ...)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end)

-- click the window: show the whole text at once
local function HookClicks()
    for _, name in ipairs({ "QuestFrame", "GossipFrame" }) do
        local f = _G[name]
        if f and not f._h3zLoreClick then
            f._h3zLoreClick = true
            f:HookScript("OnMouseDown", function() if typeFS then StopTyping() end end)
        end
    end
end

local started = false
local function Start()
    blockedBy = OtherQuestUI()
    if blockedBy then active = false return end
    active = true
    if started then return end
    started = true
    for e in pairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    HookClicks()
    -- the sizes follow the windows every time Blizzard lays them out
    for _, fn in ipairs({ "QuestInfo_Display", "QuestFrameProgressItems_Update" }) do
        if type(_G[fn]) == "function" then
            hooksecurefunc(fn, function()
                if not Active() then return end
                ApplyQuestFonts()
                if (questDW ~= 0 or questDH ~= 0) and not InCombatLockdown() then StretchQuestInside() end
            end)
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if On() then Start() end
end)

-- settings changed
Lorekeeper.Refresh = function()
    if On() and not started then Start() end
    ApplyScale()
    if not On() then StopTyping() CameraOut() return end
    if _G.QuestFrame and _G.QuestFrame:IsShown() then ApplyQuestFonts() end
    local g = _G.GossipFrame
    if g and g:IsShown() and g.Update then
        HookGossipRows()
        pcall(g.Update, g)
        C_Timer.After(0, FixGossipLayout)
    end
end

-- "Show a Preview": types the text of the open quest / gossip window again
Lorekeeper.Test = function()
    local fs
    if _G.QuestFrame and _G.QuestFrame:IsShown() then
        for _, n in ipairs(BODY) do
            local f = _G[n]
            if f and f:IsVisible() and Len(f) > 0 then fs = f break end
        end
    end
    fs = fs or GossipGreeting()
    if fs and fs:IsVisible() then Type(fs) return end
    print("|cff60A5FAH3z0 UI:|r Lorekeeper - talk to an NPC or open a quest, then press Show a Preview.")
end
