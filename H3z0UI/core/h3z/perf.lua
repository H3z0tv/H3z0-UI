--[[
    H3z0 UI - Performance window   (/h3z0ui perftest, not listed anywhere)

    Shows how much time each H3z0 UI addon takes per frame, straight from the
    game's own addon profiler, next to your other addons and the whole game:
      Avg     average time per frame over the last few seconds (ms)
      Peak    the slowest single frame since login (ms)
      >5 / >50 / >100   frames since login or Reset where the addon took longer
    "Worst other addons" lists the addons outside H3z0 UI with the most slow
    frames, so a stutter from another addon is easy to find.
    "Game" counts every frame the whole game took longer than 50 / 100 ms.

    /h3z0ui perftest   open / close the window
    /h3z0ui perftest spikes   Spike Log on / off: a chat line whenever an addon (H3z0 UI
                       or any other) takes longer than 50 ms in a frame, with the
                       game events of that moment, the zone and combat state
    /h3z0ui perftest reset    reset the counters
]]

local ADDON_NAME, ns = ...

local P
local M = Enum and Enum.AddOnProfilerMetric or {}
local AVG     = M.RecentAverageTime or 1
local LAST    = M.LastTime or 3
local PEAK    = M.PeakTime or 4
local OVER5   = M.CountTimeOver5Ms or 6
local OVER50  = M.CountTimeOver50Ms or 8
local OVER100 = M.CountTimeOver100Ms or 9

local ACCENT = "|cff34d399"
local PREFIX = ACCENT .. "H3z0 UI|r "
local OTHER_ROWS = 4

local function Available()
    P = C_AddOnProfiler
    return P and P.GetAddOnMetric and (not P.IsEnabled or P.IsEnabled())
end

-- loaded addons: ours (H3z0 UI) and the others
local ours, others
local function Scan()
    if ours then return end
    ours, others = {}, {}
    local num = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
    for i = 1, num do
        local name, title = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(i) then
            if name:find("^H3z0UI") then
                local short = name:gsub("^H3z0UI_?", "")
                if short == "" then short = "H3z0 UI" end
                if name == "H3z0UI_UnderlightAnglerHelper" then short = "Tidecaller" end
                ours[#ours + 1] = { name = name, label = short }
            elseif not name:find("^Blizzard_") then
                others[#others + 1] = { name = name, label = name }
            end
        end
    end
end
local function Ours() Scan(); return ours end
local function Others() Scan(); return others end

local function Metric(name, m)
    local ok, v = pcall(P.GetAddOnMetric, name, m)
    return ok and type(v) == "number" and v or 0
end
local function Overall(m)
    if not P.GetOverallMetric then return 0 end
    local ok, v = pcall(P.GetOverallMetric, m)
    return ok and type(v) == "number" and v or 0
end
local function Game(m)
    if not P.GetApplicationMetric then return 0 end
    local ok, v = pcall(P.GetApplicationMetric, m)
    return ok and type(v) == "number" and v or 0
end

-- counters are totals since login: Reset remembers where they were
local base = {}
local function Count(key, value) return value - (base[key] or 0) end
local function Reset()
    if not Available() then return end
    for _, list in ipairs({ Ours(), Others() }) do
        for _, a in ipairs(list) do
            base[a.name .. "5"] = Metric(a.name, OVER5)
            base[a.name .. "50"] = Metric(a.name, OVER50)
            base[a.name .. "100"] = Metric(a.name, OVER100)
        end
    end
    base.all5, base.all50, base.all100 = Overall(OVER5), Overall(OVER50), Overall(OVER100)
    base.game50, base.game100 = Game(OVER50), Game(OVER100)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local win
local ROW_H = 18
local COLS = { { "Addon", 150, "LEFT" }, { "Avg", 56 }, { "Peak", 60 }, { ">5", 46 }, { ">50", 46 }, { ">100", 46 } }

local function Accent()
    local C = _G.H3z0UI and _G.H3z0UI.GUI and _G.H3z0UI.GUI.Colors
    local a = C and C.accent
    if a then return a[1], a[2], a[3] end
    return 0.204, 0.827, 0.6
end

local function MakeRow(parent, i)
    local row = { cells = {} }
    local x = 12
    for c, col in ipairs(COLS) do
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetWidth(col[2])
        fs:SetJustifyH(col[3] or "RIGHT")
        fs:SetWordWrap(false)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -34 - i * ROW_H)
        x = x + col[2]
        row.cells[c] = fs
    end
    return row
end

local function MakeButton(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 22)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    local function Idle(self) local r, g, bl = Accent(); self:SetBackdropColor(r, g, bl, 0.15); self:SetBackdropBorderColor(r, g, bl, 0.8) end
    b:SetScript("OnEnter", function(self) local r, g, bl = Accent(); self:SetBackdropColor(r, g, bl, 0.45) end)
    b:SetScript("OnLeave", Idle)
    Idle(b)
    return b
end

local function Fmt(ms) return string.format("%.2f", ms) end
local function Color(fs, value, warn, bad)
    if value >= bad then fs:SetTextColor(1, 0.35, 0.35)
    elseif value >= warn then fs:SetTextColor(1, 0.82, 0.25)
    else fs:SetTextColor(0.85, 0.85, 0.85) end
end

local spikeLog = false
local Refresh

-- row layout: our addons, "H3z0 UI total", a heading, the worst other
-- addons, "All addons", "Game"
local function RowCount() return #Ours() + 1 + 1 + OTHER_ROWS + 2 end

local function Build()
    if win then return win end
    local f = CreateFrame("Frame", "H3z0UI_PerfFrame", UIParent, "BackdropTemplate")
    local width = 24
    for _, col in ipairs(COLS) do width = width + col[2] end
    f:SetSize(width, 34 + (RowCount() + 1) * ROW_H + 64)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.07, 0.10, 0.95)
    local r, g, b = Accent()
    f:SetBackdropBorderColor(r, g, b, 0.6)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetText("H3z0 UI Performance")
    f.title:SetTextColor(r, g, b)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    f.header = MakeRow(f, 0)
    for c, col in ipairs(COLS) do
        f.header.cells[c]:SetText(col[1])
        f.header.cells[c]:SetTextColor(r, g, b)
    end

    f.rows = {}
    for i = 1, RowCount() do f.rows[i] = MakeRow(f, i) end

    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.note:SetPoint("BOTTOMLEFT", 12, 38)
    f.note:SetPoint("BOTTOMRIGHT", -12, 38)
    f.note:SetJustifyH("LEFT")
    f.note:SetText("Avg / Peak in ms per frame. >5 / >50 / >100: frames over that since login or Reset. Reset after a loading screen to see only play time.")

    local reset = MakeButton(f, "Reset", 90)
    reset:SetPoint("BOTTOMLEFT", 12, 10)
    reset:SetScript("OnClick", function() Reset(); Refresh() end)

    local spikes = MakeButton(f, "", 150)
    spikes:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    local function SpikeText() spikes.text:SetText(spikeLog and "Spike Log: On" or "Spike Log: Off") end
    spikes:SetScript("OnClick", function() _G.H3z0UI_PerfSpikes(not spikeLog) end)
    f.SpikeText = SpikeText
    SpikeText()

    local since = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since < 1 then return end
        since = 0
        Refresh()
    end)
    f:SetScript("OnShow", function() since = 0; Refresh() end)
    tinsert(UISpecialFrames, "H3z0UI_PerfFrame")
    win = f
    return f
end

local function Fill(row, label, avg, peak, c5, c50, c100, dim, heading)
    local c = row.cells
    c[1]:SetText(label or "")
    if heading then
        local r, g, b = Accent()
        c[1]:SetTextColor(r, g, b)
    else
        c[1]:SetTextColor(dim and 0.6 or 1, dim and 0.6 or 1, dim and 0.6 or 1)
    end
    c[2]:SetText(avg and Fmt(avg) or "")
    c[3]:SetText(peak and Fmt(peak) or "")
    c[4]:SetText(c5 and tostring(c5) or "")
    c[5]:SetText(c50 and tostring(c50) or "")
    c[6]:SetText(c100 and tostring(c100) or "")
    if avg then Color(c[2], avg, 0.5, 2) end
    if peak then Color(c[3], peak, 16, 50) end
    if c5 then Color(c[4], c5, 1, 20) end
    if c50 then Color(c[5], c50, 1, 1) end
    if c100 then Color(c[6], c100, 1, 1) end
end

local function Measure(a)
    a.avg = Metric(a.name, AVG)
    a.peak = Metric(a.name, PEAK)
    a.c5 = Count(a.name .. "5", Metric(a.name, OVER5))
    a.c50 = Count(a.name .. "50", Metric(a.name, OVER50))
    a.c100 = Count(a.name .. "100", Metric(a.name, OVER100))
end

local sorted, worst = {}, {}
Refresh = function()
    if not (win and win:IsShown()) then return end
    wipe(sorted)
    for _, a in ipairs(Ours()) do
        Measure(a)
        sorted[#sorted + 1] = a
    end
    table.sort(sorted, function(x, y) return x.avg > y.avg end)

    -- other addons: most slow frames first, then the highest peak
    wipe(worst)
    for _, a in ipairs(Others()) do
        Measure(a)
        if a.c5 > 0 or a.peak >= 16 then worst[#worst + 1] = a end
    end
    table.sort(worst, function(x, y)
        if x.c100 ~= y.c100 then return x.c100 > y.c100 end
        if x.c50 ~= y.c50 then return x.c50 > y.c50 end
        if x.c5 ~= y.c5 then return x.c5 > y.c5 end
        return x.peak > y.peak
    end)

    local i, sumAvg = 0, 0
    for _, a in ipairs(sorted) do
        i = i + 1
        sumAvg = sumAvg + a.avg
        Fill(win.rows[i], a.label, a.avg, a.peak, a.c5, a.c50, a.c100)
    end
    i = i + 1
    Fill(win.rows[i], "H3z0 UI total", sumAvg)
    i = i + 1
    Fill(win.rows[i], #Others() > 0 and "Worst other addons" or "No other addons", nil, nil, nil, nil, nil, false, true)
    for k = 1, OTHER_ROWS do
        i = i + 1
        local a = worst[k]
        if a then
            Fill(win.rows[i], a.label, a.avg, a.peak, a.c5, a.c50, a.c100)
        else
            Fill(win.rows[i], k == 1 and #Others() > 0 and "  none slow" or "", nil, nil, nil, nil, nil, true)
        end
    end
    i = i + 1
    Fill(win.rows[i], "All addons", Overall(AVG), Overall(PEAK),
        Count("all5", Overall(OVER5)), Count("all50", Overall(OVER50)), Count("all100", Overall(OVER100)), true)
    i = i + 1
    Fill(win.rows[i], "Game (stutters)", Game(AVG), Game(PEAK),
        nil, Count("game50", Game(OVER50)), Count("game100", Game(OVER100)), true)
end

---------------------------------------------------------------------------
-- Spike Log: every frame, checks how long each addon took in the frame
-- before; over 50 ms prints a line with the game events of that moment.
-- Only runs while it is switched on.
---------------------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:Hide()
local seen, seenPrev = {}, {}          -- event names of this frame / the one before
local seenList, seenPrevList = {}, {}
local loading = false

watcher:SetScript("OnEvent", function(_, event)
    if event == "LOADING_SCREEN_ENABLED" then loading = true
    elseif event == "LOADING_SCREEN_DISABLED" then loading = false end
    if not seen[event] and #seenList < 12 then
        seen[event] = true
        seenList[#seenList + 1] = event
    end
end)

local function Report(a, ms)
    local evs = {}
    for _, e in ipairs(seenPrevList) do evs[#evs + 1] = e end
    for _, e in ipairs(seenList) do
        if not seenPrev[e] then evs[#evs + 1] = e end
    end
    local where = GetRealZoneText and GetRealZoneText() or ""
    local extra = {}
    if loading then extra[#extra + 1] = "loading screen" end
    if InCombatLockdown() then extra[#extra + 1] = "in combat" end
    if where ~= "" then extra[#extra + 1] = where end
    print(string.format("%s%s%s: %.0f ms in one frame%s%s",
        PREFIX, a.ours and "" or "|cffffaa00[other]|r ", a.label, ms,
        #extra > 0 and (" (" .. table.concat(extra, ", ") .. ")") or "",
        #evs > 0 and ("  events: " .. table.concat(evs, ", ")) or "  no events (timers / updates)"))
end

local watchList
watcher:SetScript("OnUpdate", function()
    for i = 1, #watchList do
        local a = watchList[i]
        local ms = Metric(a.name, LAST)
        if ms >= 50 then
            if ms ~= a.reported then Report(a, ms) end
            a.reported = ms
        else
            a.reported = nil
        end
    end
    -- this frame's events become "the frame before"
    seen, seenPrev = seenPrev, seen
    seenList, seenPrevList = seenPrevList, seenList
    wipe(seen)
    wipe(seenList)
end)

_G.H3z0UI_PerfSpikes = function(on)
    if not Available() then return end
    spikeLog = on and true or false
    if spikeLog then
        watchList = {}
        for _, a in ipairs(Ours()) do a.ours = true; watchList[#watchList + 1] = a end
        for _, a in ipairs(Others()) do watchList[#watchList + 1] = a end
        watcher:RegisterAllEvents()
        watcher:Show()
        print(PREFIX .. "Spike Log on: a line here whenever an addon takes over 50 ms in one frame, with the game events of that moment. /h3z0ui perftest spikes to switch it off.")
    else
        watcher:UnregisterAllEvents()
        watcher:Hide()
        print(PREFIX .. "Spike Log off.")
    end
    if win and win.SpikeText then win.SpikeText() end
end

_G.H3z0UI_TogglePerfMonitor = function(sub)
    if not Available() then
        print(PREFIX .. "The game's addon profiler is not available on this client.")
        return
    end
    if sub == "spikes" then
        _G.H3z0UI_PerfSpikes(not spikeLog)
        return
    elseif sub == "reset" then
        Reset()
        Refresh()
        print(PREFIX .. "Performance counters reset.")
        return
    end
    local f = Build()
    if f:IsShown() then f:Hide() else f:Show() end
end
