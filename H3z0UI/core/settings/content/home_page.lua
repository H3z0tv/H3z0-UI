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
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function Accent()
    local a = C.accent or { 0.204, 0.827, 0.6, 1 }
    return a[1], a[2], a[3]
end

local function Card(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    local R = ns.Round
    if R and R.Panel then
        local p = R.Panel(f, 10)
        p:SetAllPoints(f)
        p:SetFrameLevel(f:GetFrameLevel())
        p:SetFillColor(1, 1, 1, 0.035)
        p:SetBorderColor(1, 1, 1, 0.07)
    else
        local t = f:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(1, 1, 1, 0.035)
    end
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

---------------------------------------------------------------------------
-- live values
---------------------------------------------------------------------------
local function CharacterInfo()
    local name = UnitName("player") or "?"
    local level = UnitLevel("player") or 0
    local className, classFile = UnitClass("player")
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    local hex = color and color.colorStr or "ffffffff"
    return string.format("|c%s%s|r", hex, name), string.format("Level %d %s", level, className or "")
end

local function SpecInfo()
    if not (GetSpecialization and GetSpecializationInfo) then return "-", "" end
    local i = GetSpecialization()
    if not i then return "-", "" end
    local _, name = GetSpecializationInfo(i)
    return name or "-", ""
end

local function ItemLevelInfo()
    if not GetAverageItemLevel then return "-" end
    local _, equipped = GetAverageItemLevel()
    return equipped and string.format("%.1f", equipped) or "-"
end

local function ProfileName()
    local core = ns.Addon
    local db = core and core.db
    if db and db.GetCurrentProfile then return db:GetCurrentProfile() or "Default" end
    return "Default"
end

local function LayoutName()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    local h = p and p.handheld
    if type(h) ~= "table" then return "PC" end
    if h.enabled then return "Handheld" end
    if h.pcHandheld then return "PC Handheld" end
    if h.pcController then return "PC Controller" end
    return "PC"
end

local function ModuleCounts()
    local mp = ns.H3z0UI_ModulesPage
    if mp and mp.CollectVisibleModules then
        local ok, _, _, total, enabled = pcall(mp.CollectVisibleModules)
        if ok and total then return enabled or 0, total end
    end
    return nil
end

---------------------------------------------------------------------------
-- navigation helpers
---------------------------------------------------------------------------
local function GoToTilePage(tileId, subPage)
    local frame = GUI.MainFrame
    if not frame then return end
    local _, idx = GUI:FindV2TileByID(frame, tileId)
    if not idx then return end
    if frame._searchBox and frame._searchBox.editBox then frame._searchBox.editBox:SetText("") end
    if frame._searchResultsArea then frame._searchResultsArea:Hide() end
    if frame._tileContent then frame._tileContent:Show() end
    GUI:SelectFeatureTile(frame, idx, { subPageIndex = subPage })
end

local function GoToRecent(entry)
    local frame = GUI.MainFrame
    if not frame or not entry then return end
    GUI:SelectFeatureTile(frame, entry.tileIndex, { subPageIndex = entry.pageIndex })
    local tile = frame._tiles and frame._tiles[entry.tileIndex]
    local descriptor = tile and tile._surfacePagesByPage and tile._surfacePagesByPage[entry.pageIndex]
    if entry.key and descriptor and descriptor.selectTab then descriptor.selectTab(entry.key) end
end

---------------------------------------------------------------------------
-- page
---------------------------------------------------------------------------
local function BuildHomeContent(content)
    local y = -8
    local cw = content.GetWidth and content:GetWidth() or 0
    if not cw or cw < 300 then cw = 720 end
    local W = math.min(cw - PADDING * 2, 860)
    local r, g, b = Accent()
    local updaters = {}

    -- hero
    local hero = Card(content, W, 74)
    hero:SetPoint("TOPLEFT", PADDING, y)
    local glow = hero:CreateTexture(nil, "BORDER")
    glow:SetTexture(WHITE)
    glow:SetPoint("TOPLEFT", 6, -6)
    glow:SetPoint("BOTTOMRIGHT", -6, 6)
    glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.16), CreateColor(r, g, b, 0))
    local title = CreateWrappedLabel(hero, "H3z0 UI", 22, C.text)
    title:SetWordWrap(false)
    title:SetPoint("TOPLEFT", 20, -14)
    local who = CreateWrappedLabel(hero, "", 12, C.textMuted, W - 40)
    who:SetWordWrap(false)
    who:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    updaters[#updaters + 1] = function()
        local n, d = CharacterInfo()
        who:SetText(n .. "  -  " .. d)
    end
    y = y - 74 - 16

    -- stat tiles
    y = SectionTitle(content, "Overview", y, W)
    local stats = {
        { "Specialization", function() return (SpecInfo()) end },
        { "Item level", ItemLevelInfo },
        { "Profile", ProfileName },
        { "Layout", LayoutName },
        { "Modules on", function()
            local e, t = ModuleCounts()
            return e and (e .. " / " .. t) or "-"
        end },
    }
    local gap, perRow = 10, 3
    local tw = math.floor((W - gap * (perRow - 1)) / perRow)
    for i, s in ipairs(stats) do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        local card = Card(content, tw, 58)
        card:SetPoint("TOPLEFT", PADDING + col * (tw + gap), y - row * 68)
        local cap = CreateWrappedLabel(card, s[1], 10, C.textMuted)
        cap:SetWordWrap(false)
        cap:SetPoint("TOPLEFT", 14, -10)
        local val = CreateWrappedLabel(card, "", 15, C.text, tw - 28)
        val:SetWordWrap(false)
        val:SetPoint("TOPLEFT", cap, "BOTTOMLEFT", 0, -6)
        local fn = s[2]
        updaters[#updaters + 1] = function() val:SetText(tostring(fn() or "-")) end
    end
    y = y - (math.ceil(#stats / perRow) * 68) - 8

    -- quick actions
    y = SectionTitle(content, "Quick Actions", y, W)
    local actions = {
        { "Unlock Mode", function()
            if _G.H3z0UI_ToggleLayoutMode then _G.H3z0UI_ToggleLayoutMode() end
        end },
        { "Profiles", function() GoToTilePage("global", 1) end },
        { "Modules", function() GoToTilePage("global", 4) end },
        { "Patch Notes", function()
            if _G.H3z0UI_ShowWhatsNew then _G.H3z0UI_ShowWhatsNew() end
        end },
        { "Reload UI", function() ReloadUI() end },
        { "Reset Layout", function()
            if _G.H3z0UI_ResetLayout then _G.H3z0UI_ResetLayout() end
        end },
    }
    local bw = math.floor((W - gap * 2) / 3)
    for i, a in ipairs(actions) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local btn = GUI:CreateButton(content, a[1], bw, 30, a[2])
        btn:SetPoint("TOPLEFT", PADDING + col * (bw + gap), y - row * 38)
    end
    y = y - (math.ceil(#actions / 3) * 38) - 10

    -- recent pages and favorites, rebuilt on every show
    local listHolder = CreateFrame("Frame", nil, content)
    listHolder:SetPoint("TOPLEFT", PADDING, y)
    listHolder:SetSize(W, 10)
    local rows = {}
    local function Rebuild()
        for _, row in ipairs(rows) do row:Hide() end
        local ry, n = 0, 0
        local function Header(text)
            n = n + 1
            local fs = rows[n]
            if not fs or not fs._isHeader then
                fs = CreateWrappedLabel(listHolder, "", 13, C.text)
                fs._isHeader = true
                rows[n] = fs
            end
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 0, -ry)
            fs:SetText(text)
            fs:Show()
            ry = ry + 24
        end
        local function Item(label, go)
            n = n + 1
            local btn = rows[n]
            if not btn or btn._isHeader then
                btn = GUI:CreateButton(listHolder, "", W, 28, function(self)
                    if self._go then self._go() end
                end, "ghost")
                rows[n] = btn
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 0, -ry)
            btn:SetWidth(W)
            btn:SetText(label)
            if btn.text then
                btn.text:SetJustifyH("LEFT")
                btn.text:ClearAllPoints()
                btn.text:SetPoint("LEFT", 10, 0)
                btn.text:SetPoint("RIGHT", -10, 0)
            end
            btn._go = go
            btn:Show()
            ry = ry + 32
        end

        Header("Recent Pages")
        local recent = GUI.MainFrame and GUI.MainFrame._recentDestinations or {}
        if #recent == 0 then
            Header("Pages you open will show up here.")
        end
        for _, entry in ipairs(recent) do
            local e = entry
            Item(e.label, function() GoToRecent(e) end)
        end

        ry = ry + 8
        Header("Favorites")
        local pins = Settings and Settings.Pins
        local favs = pins and pins.List and pins:List() or {}
        if #favs == 0 then
            Header("Pin settings to keep them here.")
        end
        for i = 1, math.min(8, #favs) do
            local f = favs[i]
            Item(f.label, function() pins:NavigateToPinned(f.path) end)
        end
        listHolder:SetHeight(ry + 4)
        content:SetHeight(math.abs(y) + ry + 20)
    end
    updaters[#updaters + 1] = Rebuild

    local function Refresh()
        for _, fn in ipairs(updaters) do pcall(fn) end
    end
    content:HookScript("OnShow", Refresh)
    Refresh()
    content:SetHeight(math.abs(y) + (listHolder:GetHeight() or 0) + 20)
end

ns.H3z0UI_HomeOptions = { BuildHomeContent = BuildHomeContent }

if Registry and Schema
    and type(Registry.RegisterFeature) == "function"
    and type(Schema.Feature) == "function"
    and type(Schema.Section) == "function" then
    Registry:RegisterFeature(Schema.Feature({
        id = "homePage",
        moverKey = "home",
        category = "global",
        nav = { tileId = "home" },
        noSearch = true,
        sections = {
            Schema.Section({
                id = "settings",
                kind = "page",
                minHeight = 80,
                build = BuildHomeContent,
            }),
        },
    }))
end
