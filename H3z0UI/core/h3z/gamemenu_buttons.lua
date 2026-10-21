local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Esc menu: "H3z0 UI" and "H3z0 UI Edit Mode" right under "Return to Game"
-- The menu keeps Blizzard's own look. The two buttons use Blizzard's menu
-- button template and join the menu's own layout, so the menu grows to fit.
---------------------------------------------------------------------------

local TEMPLATES = { "MainMenuFrameButtonTemplate", "GameMenuButtonTemplate", "UIPanelButtonTemplate" }
local SECTION_GAP = 10

local buttons = {}

local function General()
    local core = ns.Addon
    local p = core and core.db and core.db.profile
    return p and p.general
end

local function NewButton(name, text, onClick)
    local b
    for _, template in ipairs(TEMPLATES) do
        local ok, frame = pcall(CreateFrame, "Button", name, GameMenuFrame, template)
        if ok and frame then b = frame break end
    end
    if not b then return nil end
    b:SetText(text)
    b:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION) end
        HideUIPanel(GameMenuFrame)
        onClick()
    end)
    b:Hide()
    return b
end

local function GetButtons()
    if buttons.options then return buttons end
    buttons.options = NewButton("H3z0UIGameMenuButton", "H3z0 UI", function()
        local addon = _G.H3z0UI
        if addon and addon.OpenOptions then addon:OpenOptions() end
    end)
    buttons.edit = NewButton("H3z0UIGameMenuEditModeButton", "H3z0 UI Edit Mode", function()
        if _G.H3z0UI_ToggleLayoutMode then _G.H3z0UI_ToggleLayoutMode() end
    end)
    return buttons
end

-- the last Blizzard button ("Return to Game")
local function FindLastButton(menu)
    local last, lastIndex, lastBottom
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        for button in menu.buttonPool:EnumerateActive() do
            local idx = button.layoutIndex
            if type(idx) == "number" then
                if not lastIndex or idx > lastIndex then last, lastIndex = button, idx end
            elseif not lastIndex then
                local bottom = button:GetBottom()
                if bottom and (not lastBottom or bottom < lastBottom) then last, lastBottom = button, bottom end
            end
        end
    end
    return last, lastIndex
end

-- fallback when the menu has no layout system: anchor below and grow the menu
local function PlaceManually(menu, last, list)
    local prev = last
    for i, b in ipairs(list) do
        b:ClearAllPoints()
        b:SetPoint("TOP", prev, "BOTTOM", 0, i == 1 and -SECTION_GAP or -2)
        prev = b
    end
    C_Timer.After(0, function()
        local top, bottom = menu:GetTop(), prev:GetBottom()
        if top and bottom and menu:GetBottom() and bottom < menu:GetBottom() + 16 then
            menu:SetHeight(top - bottom + 24)
        end
    end)
end

local function OnInitButtons(menu)
    local g = General()
    local wantOptions = not (g and g.addH3z0UIButton == false)
    local wantEdit = not (g and g.addEditModeButton == false)
    local b = GetButtons()
    if not (b.options and b.edit) then return end

    local last, lastIndex = FindLastButton(menu)
    local list = {}
    for _, info in ipairs({ { b.options, wantOptions }, { b.edit, wantEdit } }) do
        local btn, want = info[1], info[2]
        if want and last then
            btn:SetSize(last:GetWidth(), last:GetHeight())
            btn:Show()
            list[#list + 1] = btn
        else
            btn:Hide()
            btn.layoutIndex = nil
        end
    end
    if #list == 0 or not last then return end

    if lastIndex and menu.MarkDirty then
        for i, btn in ipairs(list) do
            btn.layoutIndex = lastIndex + i
            btn.topPadding = (i == 1) and SECTION_GAP or nil
            btn.align = "center"
        end
        menu:MarkDirty()
        -- check that the layout picked them up; otherwise place them by hand
        C_Timer.After(0, function()
            local first = list[1]
            local fTop, lBottom = first:GetTop(), last:GetBottom()
            if not (first:GetNumPoints() > 0 and fTop and lBottom and fTop <= lBottom + 1) then
                PlaceManually(menu, last, list)
            end
        end)
    else
        PlaceManually(menu, last, list)
    end
end

local function Install()
    if not GameMenuFrame or GameMenuFrame._h3zButtonsHooked then return end
    GameMenuFrame._h3zButtonsHooked = true
    if GameMenuFrame.InitButtons then
        hooksecurefunc(GameMenuFrame, "InitButtons", OnInitButtons)
    end
end

if GameMenuFrame then
    Install()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Install()
    end)
end
