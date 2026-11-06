local _, ns = ...

---------------------------------------------------------------------------
-- H3z0 UI - hide the UI while the Esc menu is open
-- Everything on the UI fades out (alpha 0) while the Game Menu is open and
-- comes back when it closes, so only the world, the menu and the Character &
-- Pet Scene are left. Nothing is hidden or moved (works in combat too), only
-- made invisible. Switch: Appearance > Skinning > Game Menu > Hide UI While Open.
---------------------------------------------------------------------------

local Helpers = ns.Helpers

local function On()
    local core = Helpers.GetCore and Helpers.GetCore()
    local g = core and core.db and core.db.profile and core.db.profile.general
    return g and g.gameMenuHideUI ~= false
end

-- frames that stay visible
local KEEP = {
    "GameMenuFrame", "H3z0UI_GameMenuScene", "H3z0UI_PopupFrame", "GameTooltip",
    "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
    "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
}

local faded = {}       -- frame -> alpha before
local active = false
local minimapHidden = false

local function Keep()
    local set = {}
    for _, name in ipairs(KEEP) do
        local f = _G[name]
        if f then set[f] = true end
    end
    return set
end

-- frames fade themselves back in (mouseover fade, moving, combat): each
-- faded frame gets one hook on SetAlpha that puts it straight back to 0 while
-- the menu is open, and remembers the alpha it wanted for later
local hooked = {}
local busy = false
local function Hook(f)
    if hooked[f] then return end
    hooked[f] = true
    hooksecurefunc(f, "SetAlpha", function(self, a)
        if not active or busy or not faded[self] then return end
        if a and a > 0 then
            faded[self] = a
            busy = true
            pcall(self.SetAlpha, self, 0)
            busy = false
        end
    end)
end

-- one pass over the UI: anything visible goes to alpha 0
local keepSet
local function Sweep()
    local kids = { UIParent:GetChildren() }
    busy = true
    for i = 1, #kids do
        local f = kids[i]
        if not keepSet[f] and not (f.IsForbidden and f:IsForbidden()) and f:IsShown() then
            local ok, a = pcall(f.GetAlpha, f)
            if ok and a and a > 0 and pcall(f.SetAlpha, f, 0) then
                faded[f] = a
                Hook(f)
            end
        end
    end
    busy = false
end

-- frames that have no parent at all (some icons and bars are made that way) are
-- not under UIParent: one pass over every frame when the menu opens
local function SweepOrphans()
    if not EnumerateFrames then return end
    busy = true
    local f = EnumerateFrames()
    while f do
        if f ~= UIParent and f ~= WorldFrame and not keepSet[f]
            and not (f.IsForbidden and f:IsForbidden()) then
            local okP, parent = pcall(f.GetParent, f)
            if okP and parent == nil then
                local okS, shown = pcall(f.IsShown, f)
                if okS and shown and not (issecretvalue and issecretvalue(shown)) then
                    local ok, al = pcall(f.GetAlpha, f)
                    if ok and al and not (issecretvalue and issecretvalue(al)) and al > 0
                        and pcall(f.SetAlpha, f, 0) then
                        faded[f] = al
                        Hook(f)
                    end
                end
            end
        end
        f = EnumerateFrames(f)
    end
    busy = false
end

-- what was still visible after the fade (for /h3z0ui menuscan)
local lastLeft = {}
local function Describe(f)
    local parts, cur, n = {}, f, 0
    while cur and n < 5 do
        local ok, name = pcall(cur.GetName, cur)
        parts[#parts + 1] = (ok and name and name ~= "") and name or (cur.GetObjectType and cur:GetObjectType() or "?")
        local okP, par = pcall(cur.GetParent, cur)
        cur = okP and par or nil
        n = n + 1
    end
    return table.concat(parts, " < ")
end
local function RecordLeftovers()
    wipe(lastLeft)
    if not EnumerateFrames then return end
    local f = EnumerateFrames()
    while f do
        if not (f.IsForbidden and f:IsForbidden()) then
            local okV, vis = pcall(f.IsVisible, f)
            if okV and vis == true then
                -- climb to the top: UIParent (faded) or something else
                local root, cur, steps = f, f, 0
                while cur and steps < 30 do
                    root = cur
                    if keepSet[cur] or cur == UIParent then break end
                    local okP, par = pcall(cur.GetParent, cur)
                    cur = okP and par or nil
                    steps = steps + 1
                end
                if root ~= UIParent and not keepSet[root] and root ~= f or (root == f and f ~= UIParent and f ~= WorldFrame and not keepSet[f]) then
                    local okA, ea = pcall(f.GetEffectiveAlpha, f)
                    if okA and ea and not (issecretvalue and issecretvalue(ea)) and ea > 0.05 and #lastLeft < 40 then
                        lastLeft[#lastLeft + 1] = Describe(f)
                    end
                end
            end
        end
        f = EnumerateFrames(f)
    end
end
_G.H3z0UI_GameMenuLeftovers = function() return lastLeft end

-- windows that open while the menu is up: a light check twice a second
local watcher = CreateFrame("Frame")
watcher:Hide()
local elapsedSince = 0
watcher:SetScript("OnUpdate", function(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.5 then return end
    elapsedSince = 0
    Sweep()
end)

local function FadeOut()
    if active or not On() then return end
    local menu = _G.GameMenuFrame
    if not (menu and menu:IsShown()) then return end
    active = true
    keepSet = Keep()
    Sweep()
    pcall(SweepOrphans)
    -- the minimap draws its icons (blips, POIs) itself and they stay visible at alpha 0:
    -- hide the whole minimap while the menu is open, show it again afterwards
    -- (the minimap is protected in combat: then it is left alone, and nothing is called)
    local mm = _G.Minimap
    if mm and not InCombatLockdown() and mm.IsShown and mm:IsShown() and pcall(mm.Hide, mm) then minimapHidden = true end
    C_Timer.After(0.3, function() if active then pcall(RecordLeftovers) end end)
    watcher:Show()
end

local function FadeIn()
    if not active then return end
    active = false
    watcher:Hide()
    if minimapHidden then
        if InCombatLockdown() then
            -- cannot show it in combat: it comes back when the fight ends
            local w = CreateFrame("Frame")
            w:RegisterEvent("PLAYER_REGEN_ENABLED")
            w:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                if minimapHidden and not active then
                    minimapHidden = false
                    local mm = _G.Minimap
                    if mm and not InCombatLockdown() then pcall(mm.Show, mm) end
                end
            end)
        else
            minimapHidden = false
            local mm = _G.Minimap
            if mm then pcall(mm.Show, mm) end
        end
    end
    busy = true
    for f, a in pairs(faded) do
        -- only put back what is still faded (something else may have set it since)
        local ok, now = pcall(f.GetAlpha, f)
        if ok and now == 0 then pcall(f.SetAlpha, f, a) end
    end
    busy = false
    wipe(faded)
end

_G.H3z0UI_RefreshGameMenuHideUI = function()
    if On() then FadeOut() else FadeIn() end
end

local installed = false
local function Install()
    local menu = _G.GameMenuFrame
    if not menu then return false end
    if installed then return true end
    installed = true
    -- a moment later, so the menu's own show (and the scene) are done first
    menu:HookScript("OnShow", function() C_Timer.After(0, FadeOut) end)
    menu:HookScript("OnHide", FadeIn)
    return true
end

if not Install() then
    local w = CreateFrame("Frame")
    w:RegisterEvent("PLAYER_LOGIN")
    w:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Install()
    end)
end
