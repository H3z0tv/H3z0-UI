local addonName, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI skin: Housing Dashboard (Retail)
-- * the window gets the H3z0 UI window look (theme colours, rounded border,
--   H3z0 UI close button), like the other skinned windows
-- * the wooden / parchment art (backgrounds, filigree corners, corbels,
--   dividers) is hidden; reward tiles and Endeavor rows get H3z0 UI panels
-- * tabs (House Level / Endeavors), side tabs, buttons and the house picker
--   use the H3z0 UI controls
-- * the level ring, pips, checkmarks and reward icons are left as they are
-- Protected buttons (teleport home) are never touched.
---------------------------------------------------------------------------

if ns.IsSkinningEnabled and not ns.IsSkinningEnabled() then return end
local SkinBase = ns.SkinBase
local GetCore = ns.Helpers.GetCore

local function Enabled()
    local core = GetCore()
    local g = core and core.db and core.db.profile and core.db.profile.general
    return g and g.skinHousing ~= false
end

-- art to hide (atlas names) / art that marks a panel that gets an H3z0 UI box
local HIDE = {
    "^housing%-dashboard%-bg", "filigree", "corbel", "header%-divider",
    "reward%-track%-bg", "radial%-glow", "timertag%-bg", "%-sidetab",
}
local PANEL = { "tile%-bg", "listitem%-bg" }

local function Matches(atlas, list)
    for _, p in ipairs(list) do
        if atlas:find(p) then return true end
    end
    return false
end

local function Panel(owner)
    if not owner or SkinBase.GetBackdrop(owner) then return end
    local sr, sg, sb, sa, bgr, bgg, bgb = SkinBase.GetWindowColors()
    local boost = (SkinBase.CHROME and SkinBase.CHROME.BUTTON_BOOST) or 0.04
    SkinBase.CreateBackdrop(owner, sr, sg, sb, sa * 0.6,
        math.min(bgr + boost, 1), math.min(bgg + boost, 1), math.min(bgb + boost, 1), 0.9, 6)
    local bd = SkinBase.GetBackdrop(owner)
    if bd then bd:SetFrameLevel(math.max(0, owner:GetFrameLevel() - 1)) end
end

local function Walk(frame, depth)
    if not frame or depth > 9 then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    if frame.IsProtected and frame:IsProtected() then return end
    for i = 1, select("#", frame:GetRegions()) do
        local r = select(i, frame:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") and r.GetAtlas then
            local atlas = r:GetAtlas()
            if type(atlas) == "string" and atlas ~= "" then
                if Matches(atlas, PANEL) then
                    SkinBase.ClampTextureHidden(r, true)
                    Panel(frame)
                elseif Matches(atlas, HIDE) then
                    SkinBase.ClampTextureHidden(r, true)
                end
            end
        end
    end
    for i = 1, select("#", frame:GetChildren()) do
        Walk(select(i, frame:GetChildren()), depth + 1)
    end
end

-- side tabs (house / catalog / blueprints): H3z0 UI box, accent line when selected
local function SkinSideTabs(frame)
    local ar, ag, ab = SkinBase.GetSkinColors()
    for _, tab in ipairs(frame.TabButtons or {}) do
        if tab and not (tab.IsForbidden and tab:IsForbidden()) then
            SkinBase.ClampTextureHidden(tab.Background, true)
            SkinBase.ClampTextureHidden(tab.SelectedTexture, true)
            if not SkinBase.GetBackdrop(tab) then
                local r, g, b, a, br, bg, bb, ba = SkinBase.GetWindowColors()
                SkinBase.CreateBackdrop(tab, r, g, b, a, br, bg, bb, ba, 5)
                local chrome = SkinBase.GetBackdrop(tab)
                if chrome then chrome:SetFrameLevel(math.max(0, tab:GetFrameLevel() - 1)) end
            end
            for _, key in ipairs({ "HighlightTexture", "TabGlow" }) do
                local texture = tab[key]
                if texture then
                    texture:SetColorTexture(ar, ag, ab, 0.08)
                    texture:ClearAllPoints()
                    texture:SetAllPoints(tab)
                end
            end
            local marker = SkinBase.GetFrameData(tab, "h3zHousingTabMarker")
            if not marker then
                marker = tab:CreateTexture(nil, "OVERLAY")
                SkinBase.SetFrameData(tab, "h3zHousingTabMarker", marker)
            end
            local px = SkinBase.GetPixelSize(tab, 1)
            marker:SetColorTexture(ar, ag, ab, 1)
            marker:SetWidth(px * 2)
            marker:ClearAllPoints()
            marker:SetPoint("TOPLEFT", tab, "TOPLEFT", px, -px)
            marker:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", px, px)
            marker:SetShown(tab.SelectedTexture and tab.SelectedTexture:IsShown() or false)
            if tab.SetChecked and not SkinBase.GetFrameData(tab, "h3zHousingTabHooked") then
                SkinBase.SetFrameData(tab, "h3zHousingTabHooked", true)
                hooksecurefunc(tab, "SetChecked", function() SkinSideTabs(frame) end)
            end
        end
    end
end

local function SkinControls(frame)
    local info = frame.HouseInfoContent
    for _, b in ipairs({ info and info.HouseFinderButton,
        info and info.DashboardNoHousesFrame and info.DashboardNoHousesFrame.NoHouseButton }) do
        if b and not (b.IsProtected and b:IsProtected()) then
            SkinBase.SkinButton(b)
            if SkinBase.ApplyButtonFontObjects then SkinBase.ApplyButtonFontObjects(b) end
        end
    end
    if frame.HouseDropdown then
        local dd = frame.HouseDropdown.Dropdown or frame.HouseDropdown
        pcall(SkinBase.SkinDropdown, dd, { skinArrow = true })
    end
    local content = info and info.ContentFrame
    local tabs = content and content.TabSystem and content.TabSystem.tabs
    if tabs and #tabs > 0 then
        pcall(SkinBase.SkinTabGroup, tabs, content, {})
    end
    if frame.CloseButton then SkinBase.SkinCloseButton(frame.CloseButton) end
end

local function Apply(frame)
    frame = frame or _G.HousingDashboardFrame
    if not frame or not Enabled() then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    SkinBase.HidePortraitFrameChrome(frame)
    if not SkinBase.GetBackdrop(frame) then
        local sr, sg, sb, sa, bgr, bgg, bgb, bga = SkinBase.GetWindowColors()
        SkinBase.CreateBackdrop(frame, sr, sg, sb, sa, bgr, bgg, bgb, bga, 8)
    end
    if frame.TitleContainer then SkinBase.SkinFrameText(frame.TitleContainer, { chrome = true }) end
    pcall(SkinControls, frame)
    pcall(SkinSideTabs, frame)
    Walk(frame, 1)
    SkinBase.MarkSkinned(frame)
end

local function Hook(frame)
    if SkinBase.GetFrameData(frame, "h3zHousingHooked") then return end
    SkinBase.SetFrameData(frame, "h3zHousingHooked", true)
    frame:HookScript("OnShow", function(self) C_Timer.After(0, function() Apply(self) end) end)
    -- every page builds its art the first time it shows (and lists reuse rows)
    local info = frame.HouseInfoContent
    local content = info and info.ContentFrame
    for _, page in ipairs({
        info, frame.CatalogContent, frame.CollectionContent,
        content and content.InitiativesFrame, content and content.HouseUpgradeFrame,
    }) do
        if page and page.HookScript then
            page:HookScript("OnShow", function() C_Timer.After(0, function() Apply(frame) end) end)
        end
    end
    if frame.SetTab then hooksecurefunc(frame, "SetTab", function() C_Timer.After(0, function() Apply(frame) end) end) end
    if content and content.SetTab then
        hooksecurefunc(content, "SetTab", function() C_Timer.After(0, function() Apply(frame) end) end)
    end
end

local function Setup()
    local frame = _G.HousingDashboardFrame
    if not frame or not Enabled() then return end
    Hook(frame)
    Apply(frame)
end

local function Refresh()
    local frame = _G.HousingDashboardFrame
    if not frame then return end
    local bd = SkinBase.GetBackdrop(frame)
    if bd then
        local sr, sg, sb, sa, bgr, bgg, bgb, bga = SkinBase.GetWindowColors()
        SkinBase.SetBackdropColors(bd, { sr, sg, sb, sa }, { bgr, bgg, bgb, bga })
    end
end

_G.H3z0UI_RefreshHousingColors = Refresh
if ns.Registry then
    ns.Registry:Register("skinHousing", {
        refresh = Refresh,
        priority = 80,
        group = "skinning",
        importCategories = { "skinning", "theme" },
    })
end

SkinBase.OnAddOnLoaded("Blizzard_HousingDashboard", Setup, 0)
