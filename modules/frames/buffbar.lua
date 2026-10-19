local ADDON_NAME, ns = ...
local H3z0UICore = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

local function GetCore()
    return (_G.H3z0UI and _G.H3z0UI.H3z0UICore) or ns.Addon
end

---------------------------------------------------------------------------
-- H3z0UI Buff Bar Manager
-- Handles dynamic centering of BuffIconCooldownViewer and BuffBarCooldownViewer
-- Uses hash-based polling + sticky center debounce for stable updates
---------------------------------------------------------------------------

local H3z0UI_BuffBar = {}
ns.BuffBar = H3z0UI_BuffBar

---------------------------------------------------------------------------
-- HELPER: Get font from general settings (uses shared helpers)
---------------------------------------------------------------------------
local Helpers = ns.Helpers
local GetGeneralFont = Helpers.GetGeneralFont
local GetGeneralFontOutline = Helpers.GetGeneralFontOutline

---------------------------------------------------------------------------
-- UTILITY FUNCTIONS
---------------------------------------------------------------------------

local floor = math.floor

-- Tolerance-based position check: skip repositioning if within tolerance
-- Prevents jitter from floating-point drift
local abs = math.abs

-- 0.24.8: in combat Blizzard's cooldown frames can hand back secret values for their size,
-- anchors and shown state. Comparing a secret value is an error, and one error stopped the
-- whole bar layout half way (the rest kept Blizzard's look and position and overlapped).
-- Everything read from those frames goes through these first: secret -> nil (unknown).
local issecret = issecretvalue or function() return false end
local function SafeVal(v)
    if v == nil or issecret(v) then return nil end
    return v
end
local function SafeShown(f)
    local ok, v = pcall(f.IsShown, f)
    if not ok then return true end
    v = SafeVal(v)
    if v == nil then return true end   -- unknown: treat as shown (a gap is better than an overlap)
    return v
end
local function SafeWidth(f) local ok, v = pcall(f.GetWidth, f); return ok and SafeVal(v) or nil end
local function SafeHeight(f) local ok, v = pcall(f.GetHeight, f); return ok and SafeVal(v) or nil end
local function SafePoint(f)
    local ok, point, rel, relPoint, x, y = pcall(f.GetPoint, f, 1)
    if not ok then return nil end
    return SafeVal(point), rel, SafeVal(relPoint), SafeVal(x), SafeVal(y)
end
local function SafeNumPoints(f)
    local ok, n = pcall(f.GetNumPoints, f)
    return ok and SafeVal(n) or nil
end

local function PositionMatchesTolerance(icon, expectedX, tolerance)
    if not icon then return false end
    local point, _, _, xOfs = SafePoint(icon)
    if not point or not xOfs then return false end
    return abs(xOfs - expectedX) <= (tolerance or 2)
end

---------------------------------------------------------------------------
-- DATABASE ACCESS
---------------------------------------------------------------------------

-- DB accessor using shared helpers
local GetDB = Helpers.CreateDBGetter("ncdm")

local function GetBuffSettings()
    local db = GetDB()
    if db and db.buff then
        local buff = db.buff
        -- Migrate old 'shape' setting to new 'aspectRatioCrop'
        if buff.aspectRatioCrop == nil and buff.shape then
            if buff.shape == "rectangle" or buff.shape == "flat" then
                buff.aspectRatioCrop = 1.33  -- 4:3 aspect ratio
            else
                buff.aspectRatioCrop = 1.0  -- square
            end
        end
        return buff
    end
    -- Return defaults if no DB
    return {
        enabled = true,
        iconSize = 42,
        borderSize = 2,
        aspectRatioCrop = 1.0,
        zoom = 0,
        padding = 0,
        opacity = 1.0,
    }
end

local function GetTrackedBarSettings()
    local db = GetDB()
    if db and db.trackedBar then
        return db.trackedBar
    end
    -- Return defaults if no DB
    return {
        enabled = true,
        barHeight = 24,
        barWidth = 200,
        texture = "H3z0UI v5",
        useClassColor = true,
        barColor = {0.204, 0.827, 0.6, 1},
        barOpacity = 1.0,
        borderSize = 1,
        bgColor = {0, 0, 0, 1},
        bgOpacity = 0.7,
        textSize = 12,
        spacing = 4,
        growUp = true,
        hideText = false,
        -- Vertical bar settings
        orientation = "horizontal",
        fillDirection = "up",
        iconPosition = "top",
        showTextOnVertical = false,
    }
end

---------------------------------------------------------------------------
-- FORWARD DECLARATIONS
---------------------------------------------------------------------------

local LayoutBuffIcons
local LayoutBuffBars

---------------------------------------------------------------------------
-- RE-ENTRY GUARDS: Prevent recursive layout calls
---------------------------------------------------------------------------

local isIconLayoutRunning = false
local isBarLayoutRunning = false

---------------------------------------------------------------------------
-- ARCHITECTURE NOTES:
-- - Hash-based change detection: only layout when count OR settings change
-- - Direct centering: immediate layout on count change (no debounce)
-- - 0.05s polling rate (20 FPS) matches proven stable implementations
-- - Per-icon OnShow hooks REMOVED - they caused cascade during rapid changes
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- LAYOUT SUPPRESSION: Prevents recursive layout calls from our own SetSize()
---------------------------------------------------------------------------

local layoutSuppressed = 0

local function SuppressLayout()
    layoutSuppressed = layoutSuppressed + 1
end

local function UnsuppressLayout()
    layoutSuppressed = math.max(0, layoutSuppressed - 1)
end

local BarLookDrifted
local lastBarError
local function Guard(fn)
    local ok, err = pcall(fn)
    if not ok then lastBarError = err end
end

local function IsLayoutSuppressed()
    return layoutSuppressed > 0
end

---------------------------------------------------------------------------
-- ICON FRAME COLLECTION
---------------------------------------------------------------------------

local function GetBuffIconFrames()
    if not BuffIconCooldownViewer then
        return {}
    end

    local all = {}

    for _, child in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
        if child then
            -- Skip Selection frame (Edit Mode)
            if child == BuffIconCooldownViewer.Selection then
                -- Skip
            else
                local hasIcon = child.icon or child.Icon
                local hasCooldown = child.cooldown or child.Cooldown

                if hasIcon or hasCooldown then
                    table.insert(all, child)
                end
            end
        end
    end

    local function ILI(f)
        local v = SafeVal(f.layoutIndex)
        return type(v) == "number" and v or 0
    end
    pcall(table.sort, all, function(a, b) return ILI(a) < ILI(b) end)

    -- Only keep visible icons that have been fully initialized (have cooldownID)
    local visible = {}
    for _, icon in ipairs(all) do
        if SafeShown(icon) and icon.cooldownID then
            table.insert(visible, icon)
        end
    end

    return visible
end

---------------------------------------------------------------------------
-- BAR FRAME COLLECTION
---------------------------------------------------------------------------

local barSeenOrder = setmetatable({ n = 0 }, { __mode = "k" })

local function GetBuffBarFrames()
    if not BuffBarCooldownViewer then
        return {}
    end

    local frames, seen = {}, {}
    local function Add(f)
        if f and not seen[f] and f ~= BuffBarCooldownViewer.Selection then
            seen[f] = true
            frames[#frames + 1] = f
        end
    end

    -- the viewer's own list of bars
    if BuffBarCooldownViewer.GetItemFrames then
        local ok, items = pcall(BuffBarCooldownViewer.GetItemFrames, BuffBarCooldownViewer)
        if ok and type(items) == "table" then
            for _, f in ipairs(items) do Add(f) end
        end
    end

    -- 0.24.2: plus every child bar. Before, children were only read when the list was empty, and
    -- then only the first one (pcall returned just the first child). A bar the list did not have
    -- kept Blizzard's look and position and overlapped the styled bars.
    local kids = { pcall(BuffBarCooldownViewer.GetChildren, BuffBarCooldownViewer) }
    if kids[1] then
        for i = 2, #kids do
            local child = kids[i]
            if child and child.IsObjectType and child:IsObjectType("Frame") and (child.Bar or child.Icon) then
                Add(child)
            end
        end
    end

    -- Filter to active/visible frames
    local active = {}
    for _, frame in ipairs(frames) do
        local okV, vis = pcall(frame.IsVisible, frame)
        vis = okV and SafeVal(vis)
        if SafeShown(frame) and vis ~= false then
            table.insert(active, frame)
        end
    end

    -- 0.24.8: stable order. Bars with the same (or no) layoutIndex used to swap places on every
    -- check, so they jumped around and were re-skinned over and over. Ties keep the order we first saw.
    for _, f in ipairs(active) do
        if not barSeenOrder[f] then barSeenOrder.n = barSeenOrder.n + 1; barSeenOrder[f] = barSeenOrder.n end
    end
    local function LI(f)
        local v = SafeVal(f.layoutIndex)
        if type(v) ~= "number" then return 0 end
        return v
    end
    pcall(table.sort, active, function(a, b)
        local la, lb = LI(a), LI(b)
        if la ~= lb then return la < lb end
        return barSeenOrder[a] < barSeenOrder[b]
    end)

    return active
end

---------------------------------------------------------------------------
-- HELPER: Strip Blizzard's overlay texture (the square artifact)
---------------------------------------------------------------------------

local function StripBlizzardOverlay(icon)
    if not icon or not icon.GetRegions then return end

    for _, region in ipairs({ icon:GetRegions() }) do
        if region:IsObjectType("Texture") then
            -- Check for the specific overlay atlas
            if region.GetAtlas then
                local atlas = region:GetAtlas()
                if atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                    region:SetTexture("")
                    region:Hide()
                    -- hooksecurefunc (not method replacement) so Blizzard code is not tainted
                    if not region.__h3z0uiShowHooked then
                        region.__h3z0uiShowHooked = true
                        hooksecurefunc(region, "Show", function(self) self:Hide() end)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- HELPER: Disable atlas-based border textures (debuff type colors, etc.)
-- Hooks SetAtlas to prevent Blizzard from re-applying borders on updates
---------------------------------------------------------------------------

local function DisableAtlasBorder(tex)
    if not tex then return end

    -- Immediately clear everything
    if tex.SetAtlas then tex:SetAtlas(nil) end
    if tex.SetTexture then tex:SetTexture(nil) end
    if tex.SetAlpha then tex:SetAlpha(0) end
    if tex.Hide then tex:Hide() end

    -- Hook to re-clear on future SetAtlas calls (Blizzard re-applies on buff updates)
    if tex.SetAtlas and not tex._h3z0uiAtlasDisabled then
        tex._h3z0uiAtlasDisabled = true
        hooksecurefunc(tex, "SetAtlas", function(self)
            C_Timer.After(0, function()
                -- Safety check in case texture was released before timer fires
                if not self or (self.IsForbidden and self:IsForbidden()) then return end
                -- Must also clear the atlas, not just texture/alpha
                pcall(function()
                    self:SetAtlas(nil)
                    self:SetTexture(nil)
                    self:SetAlpha(0)
                    self:Hide()
                end)
            end)
        end)
    end
end

---------------------------------------------------------------------------
-- HELPER: One-time icon setup (mask removal, overlay strip)
-- NOTE: Per-icon OnShow hooks removed - they caused cascade during rapid buff changes
-- Polling at 0.05s + viewer hooks handle detection efficiently
---------------------------------------------------------------------------

local function SetupIconOnce(icon)
    if icon._buffSetup then return end

    -- Remove ALL of Blizzard's masks (they may have multiple)
    local textures = { icon.Icon, icon.icon, icon.texture, icon.Texture }
    for _, tex in ipairs(textures) do
        if tex and tex.GetMaskTexture then
            for i = 1, 10 do
                local mask = tex:GetMaskTexture(i)
                if mask then
                    tex:RemoveMaskTexture(mask)
                end
            end
        end
    end

    -- Hide any NormalTexture border that Blizzard adds
    if icon.NormalTexture then icon.NormalTexture:SetAlpha(0) end
    if icon.GetNormalTexture then
        local normalTex = icon:GetNormalTexture()
        if normalTex then normalTex:SetAlpha(0) end
    end

    -- Strip Blizzard's overlay texture
    StripBlizzardOverlay(icon)

    -- Disable aura type border textures (debuff colors, buff borders, enchant borders)
    DisableAtlasBorder(icon.DebuffBorder)
    DisableAtlasBorder(icon.BuffBorder)
    DisableAtlasBorder(icon.TempEnchantBorder)

    icon._buffSetup = true
end

---------------------------------------------------------------------------
-- HELPER: Apply icon size, aspect ratio, border, and perfect square fix
---------------------------------------------------------------------------

local function ApplyIconStyle(icon, settings)
    if not icon then return end

    SetupIconOnce(icon)

    local size = settings.iconSize or 42
    local aspectRatio = settings.aspectRatioCrop or 1.0
    local zoom = settings.zoom or 0
    local borderSize = settings.borderSize or 2

    -- Calculate dimensions using crop-based aspect ratio
    local width, height = size, size
    if aspectRatio > 1.0 then
        -- Wider: height shrinks
        height = size / aspectRatio
    elseif aspectRatio < 1.0 then
        -- Taller: width shrinks
        width = size * aspectRatio
    end

    icon:SetSize(width, height)

    -- Create or update border (using BACKGROUND texture to avoid secret value errors during combat)
    -- BackdropTemplate causes "arithmetic on secret value" crashes when frame is resized during combat
    if borderSize > 0 then
        if not icon._buffBorder then
            icon._buffBorder = icon:CreateTexture(nil, "BACKGROUND", nil, -8)
            icon._buffBorder:SetColorTexture(0, 0, 0, 1)
        end

        icon._buffBorder:ClearAllPoints()
        icon._buffBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -borderSize, borderSize)
        icon._buffBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", borderSize, -borderSize)
        icon._buffBorder:Show()
        icon._buffBorderSize = borderSize
    else
        if icon._buffBorder then
            icon._buffBorder:Hide()
        end
        icon._buffBorderSize = 0
    end

    -- Calculate texture coordinates (crop-based, no stretching)
    -- BASE_CROP always applied first to hide Blizzard's grey icon edges
    local BASE_CROP = 0.08
    local left, right, top, bottom = BASE_CROP, 1 - BASE_CROP, BASE_CROP, 1 - BASE_CROP

    -- Apply aspect ratio crop ON TOP of base crop (within the already-cropped area)
    if aspectRatio > 1.0 then
        -- Wider: crop MORE from top/bottom
        local cropAmount = 1.0 - (1.0 / aspectRatio)
        local availableHeight = bottom - top
        local offset = (cropAmount * availableHeight) / 2.0
        top = top + offset
        bottom = bottom - offset
    elseif aspectRatio < 1.0 then
        -- Taller: crop MORE from left/right
        local cropAmount = 1.0 - aspectRatio
        local availableWidth = right - left
        local offset = (cropAmount * availableWidth) / 2.0
        left = left + offset
        right = right - offset
    end

    -- Apply zoom on top of everything (zooms into center)
    if zoom > 0 then
        local centerX = (left + right) / 2.0
        local centerY = (top + bottom) / 2.0
        local currentWidth = right - left
        local currentHeight = bottom - top
        local visibleSize = 1.0 - (zoom * 2)
        left = centerX - (currentWidth * visibleSize / 2.0)
        right = centerX + (currentWidth * visibleSize / 2.0)
        top = centerY - (currentHeight * visibleSize / 2.0)
        bottom = centerY + (currentHeight * visibleSize / 2.0)
    end

    local function ProcessTexture(tex)
        if not tex then return end
        tex:ClearAllPoints()
        tex:SetAllPoints(icon)
        if tex.SetTexCoord then
            tex:SetTexCoord(left, right, top, bottom)
        end
    end

    -- Try common texture property names
    ProcessTexture(icon.Icon)
    ProcessTexture(icon.icon)
    ProcessTexture(icon.texture)
    ProcessTexture(icon.Texture)

    -- Fix the Cooldown frame
    local cooldown = icon.Cooldown or icon.cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(icon)
        -- Use simple stretchable texture so swipe fills entire frame
        cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
        cooldown:SetSwipeColor(0, 0, 0, 0.8)

        -- Show cooldown swipe based on showBuffIconSwipe setting (opt-in, default OFF)
        local core = GetCore()
        local showBuffIconSwipe = core and core.db and core.db.profile.cooldownSwipe
            and core.db.profile.cooldownSwipe.showBuffIconSwipe or false
        if cooldown.SetDrawSwipe then
            cooldown:SetDrawSwipe(showBuffIconSwipe)
        end
        if cooldown.SetDrawEdge then
            cooldown:SetDrawEdge(showBuffIconSwipe)
        end
    end

    -- Fix CooldownFlash if it exists
    if icon.CooldownFlash then
        icon.CooldownFlash:ClearAllPoints()
        icon.CooldownFlash:SetAllPoints(icon)
    end

    -- Apply text sizes and offsets
    local durationSize = settings.durationSize or 12
    local stackSize = settings.stackSize or 12
    local durationOffsetX = settings.durationOffsetX or 0
    local durationOffsetY = settings.durationOffsetY or 0
    local durationAnchor = settings.durationAnchor or "CENTER"
    local stackOffsetX = settings.stackOffsetX or 0
    local stackOffsetY = settings.stackOffsetY or 0
    local stackAnchor = settings.stackAnchor or "BOTTOMRIGHT"

    -- Get font from general settings
    local generalFont = GetGeneralFont()
    local generalOutline = GetGeneralFontOutline()

    -- Apply duration text size and offset (cooldown text)
    if cooldown and durationSize then
        -- Method 1: Check for OmniCC text
        if cooldown.text then
            cooldown.text:SetFont(generalFont, durationSize, generalOutline)
            pcall(function()
                cooldown.text:ClearAllPoints()
                cooldown.text:SetPoint(durationAnchor, icon, durationAnchor, durationOffsetX, durationOffsetY)
            end)
        end

        -- Method 2: Check for Blizzard's built-in cooldown text (GetRegions)
        for _, region in ipairs({ cooldown:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                region:SetFont(generalFont, durationSize, generalOutline)
                pcall(function()
                    region:ClearAllPoints()
                    region:SetPoint(durationAnchor, icon, durationAnchor, durationOffsetX, durationOffsetY)
                end)
            end
        end
    end

    -- Apply stack text size using same approach as core/main.lua
    local fs = nil

    -- 1. ChargeCount (ability charges)
    local charge = icon.ChargeCount
    if charge then
        fs = charge.Current or charge.Text or charge.Count or nil
        if not fs and charge.GetRegions then
            for _, region in ipairs({ charge:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    fs = region
                    break
                end
            end
        end
    end

    -- 2. Applications (Buff stacks)
    if not fs then
        local apps = icon.Applications
        if apps and apps.GetRegions then
            for _, region in ipairs({ apps:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    fs = region
                    break
                end
            end
        end
    end

    -- 3. Fallback: look for named stack text
    if not fs and icon.GetRegions then
        for _, region in ipairs({ icon:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                local name = region:GetName()
                if name and (name:find("Stack") or name:find("Applications") or name:find("Count")) then
                    fs = region
                    break
                end
            end
        end
    end

    -- Apply the stack size and offset
    if fs and stackSize then
        fs:SetFont(generalFont, stackSize, generalOutline)
        pcall(function()
            fs:ClearAllPoints()
            fs:SetPoint(stackAnchor, icon, stackAnchor, stackOffsetX, stackOffsetY)
        end)
    end

    -- Apply opacity
    local opacity = settings.opacity or 1.0
    icon:SetAlpha(opacity)
end

---------------------------------------------------------------------------
-- BAR STYLING (for BuffBarCooldownViewer item cooldowns)
---------------------------------------------------------------------------

-- Blizzard sets its own bar texture / colour again when a buff is refreshed or a bar is
-- reused for another spell. Before 0.24.8 we noticed that only up to a second later, so the
-- bars flickered between Blizzard's look and ours. Now the look is put back straight away.
local hookedStatusBars = setmetatable({}, { __mode = "k" })
local appliedTex = setmetatable({}, { __mode = "k" })   -- statusBar -> texture we put on

local function CurrentBarTex(statusBar)
    local ok, t = pcall(function() return statusBar:GetStatusBarTexture():GetTexture() end)
    if ok then return SafeVal(t) end
end
local inReapply = false

local function BarTexturePath(settings)
    return LSM:Fetch("statusbar", settings.texture or "H3z0UI v5") or LSM:Fetch("statusbar", "H3z0UI v5")
end

local function ApplyBarColor(statusBar, settings)
    local a = settings.barOpacity or 1.0
    if settings.useClassColor then
        local _, class = UnitClass("player")
        local color = RAID_CLASS_COLORS[class]
        if color then statusBar:SetStatusBarColor(color.r, color.g, color.b, a) end
    else
        local c = settings.barColor or {0.204, 0.827, 0.6, 1}
        statusBar:SetStatusBarColor(c[1] or 0.2, c[2] or 0.8, c[3] or 0.6, a)
    end
end

local function ReapplyBarLook(statusBar)
    if inReapply then return end
    local settings = GetTrackedBarSettings()
    if not (settings and settings.enabled) then return end
    inReapply = true
    pcall(function()
        local path = BarTexturePath(settings)
        if path then statusBar:SetStatusBarTexture(path) end
        ApplyBarColor(statusBar, settings)
        appliedTex[statusBar] = CurrentBarTex(statusBar)
    end)
    inReapply = false
end

local function HookStatusBar(statusBar)
    if not statusBar or hookedStatusBars[statusBar] then return end
    hookedStatusBars[statusBar] = true
    if statusBar.SetStatusBarTexture then
        hooksecurefunc(statusBar, "SetStatusBarTexture", function(self) ReapplyBarLook(self) end)
    end
    if statusBar.SetStatusBarColor then
        hooksecurefunc(statusBar, "SetStatusBarColor", function(self) ReapplyBarLook(self) end)
    end
end

local function ApplyBarStyle(frame, settings)
    if not frame then return end
    if frame.IsForbidden and frame:IsForbidden() then return end

    local barHeight = settings.barHeight or 24
    local barWidth = settings.barWidth or 200
    local texture = settings.texture or "H3z0UI v5"
    local useClassColor = settings.useClassColor
    local barColor = settings.barColor or {0.204, 0.827, 0.6, 1}
    local barOpacity = settings.barOpacity or 1.0
    local borderSize = settings.borderSize or 1
    local bgColor = settings.bgColor or {0, 0, 0, 1}
    local bgOpacity = settings.bgOpacity or 0.7
    local textSize = settings.textSize or 12
    local hideIcon = settings.hideIcon
    local hideText = settings.hideText

    -- Vertical bar settings
    local orientation = settings.orientation or "horizontal"
    local isVertical = (orientation == "vertical")
    local fillDirection = settings.fillDirection or "up"
    local iconPosition = settings.iconPosition or "top"
    local showTextOnVertical = settings.showTextOnVertical or false

    -- For vertical bars: swap width/height conceptually
    -- "Bar Height" setting becomes bar width, "Bar Width" becomes bar height
    local frameWidth, frameHeight
    if isVertical then
        frameWidth = barHeight   -- Height setting becomes width
        frameHeight = barWidth   -- Width setting becomes height
    else
        frameWidth = barWidth
        frameHeight = barHeight
    end

    -- Get the StatusBar child (usually frame.Bar)
    local statusBar = frame.Bar
    if not statusBar and frame.GetChildren then
        local okC, children = pcall(frame.GetChildren, frame)
        if okC and children then
            for _, child in ipairs({children}) do
                if child and child.IsObjectType and child:IsObjectType("StatusBar") then
                    statusBar = child
                    break
                end
            end
        end
    end

    -- 1. STRIP Blizzard's decorative textures from the statusBar (keep only the fill texture)
    if statusBar and statusBar.GetRegions then
        pcall(function()
            local mainTex = statusBar:GetStatusBarTexture()
            for _, region in ipairs({statusBar:GetRegions()}) do
                if region and region:IsObjectType("Texture") and region ~= mainTex then
                    region:SetTexture(nil)
                    region:Hide()
                end
            end
        end)
    end

    -- 1b. Disable atlas borders on the bar FRAME itself (debuff type colors like red/purple/green)
    DisableAtlasBorder(frame.DebuffBorder)
    DisableAtlasBorder(frame.BuffBorder)
    DisableAtlasBorder(frame.TempEnchantBorder)

    -- 2. Set bar dimensions (swapped for vertical orientation)
    pcall(function()
        frame:SetHeight(frameHeight)
        frame:SetWidth(frameWidth)
        if statusBar then
            statusBar:SetHeight(frameHeight)
            statusBar:SetWidth(frameWidth)
            -- Set StatusBar orientation
            if statusBar.SetOrientation then
                statusBar:SetOrientation(isVertical and "VERTICAL" or "HORIZONTAL")
            end
            -- Set fill direction for vertical bars
            if isVertical and statusBar.SetReverseFill then
                statusBar:SetReverseFill(fillDirection == "down")
            end
        end
    end)

    -- 3. Handle icon visibility and styling
    local iconContainer = frame.Icon
    if iconContainer then
        if hideIcon then
            -- Hide icon completely when user wants no icon
            pcall(function()
                iconContainer:Hide()
                iconContainer:SetAlpha(0)
            end)
        else
            -- Show and style icon with full texture stripping for clean rendering
            pcall(function()
                iconContainer:Show()
                iconContainer:SetAlpha(1)

                -- Disable atlas borders on iconContainer (prevents thick border reappearance)
                DisableAtlasBorder(iconContainer.DebuffBorder)
                DisableAtlasBorder(iconContainer.BuffBorder)
                DisableAtlasBorder(iconContainer.TempEnchantBorder)

                -- Icon size: use the smaller dimension for vertical bars
                local iconSize = isVertical and frameWidth or frameHeight
                iconContainer:SetSize(iconSize, iconSize)

            -- Get the actual icon texture inside the container
            local iconTexture = iconContainer.Icon or iconContainer.icon or iconContainer.texture
            if iconTexture and iconTexture.IsObjectType and iconTexture:IsObjectType("Texture") then
                -- Step A: Remove ALL mask textures FIRST (iterate through all of them)
                if iconTexture.GetMaskTexture then
                    local i = 1
                    local mask = iconTexture:GetMaskTexture(i)
                    while mask do
                        iconTexture:RemoveMaskTexture(mask)
                        i = i + 1
                        mask = iconTexture:GetMaskTexture(i)
                    end
                end

                -- Disable cooldown swipe on buff bar icons (bar shows duration, swipe is redundant)
                local cooldown = iconContainer.Cooldown or iconContainer.cooldown
                if cooldown then
                    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(false) end
                    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
                end

                -- Step B: Clear anchor points and fill container completely
                iconTexture:ClearAllPoints()
                iconTexture:SetPoint("TOPLEFT", iconContainer, "TOPLEFT", 0, 0)
                iconTexture:SetPoint("BOTTOMRIGHT", iconContainer, "BOTTOMRIGHT", 0, 0)

                -- Step C: Apply TexCoord cropping (removes transparent icon border)
                iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

                -- Step D: Strip ALL sibling textures from iconContainer (removes debuff rings, borders)
                for _, region in ipairs({iconContainer:GetRegions()}) do
                    if region:IsObjectType("Texture") and region ~= iconTexture then
                        region:SetTexture(nil)
                        region:Hide()
                    end
                end

                -- Step E: Also strip any child frames that might contain borders
                if iconContainer.GetChildren then
                    for _, child in ipairs({iconContainer:GetChildren()}) do
                        if child and child ~= iconTexture then
                            -- Hide border frames but not the cooldown
                            local childName = child.GetName and child:GetName() or ""
                            if not childName:find("Cooldown") then
                                for _, reg in ipairs({child:GetRegions()}) do
                                    if reg:IsObjectType("Texture") then
                                        reg:SetTexture(nil)
                                        reg:Hide()
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Step E2: Hide all text on icon (duration shown by bar, text is redundant)
            for _, region in ipairs({iconContainer:GetRegions()}) do
                if region:IsObjectType("FontString") then
                    region:SetAlpha(0)
                end
            end
            -- Also check icon children for text (cooldown timers, count text)
            if iconContainer.GetChildren then
                for _, child in ipairs({iconContainer:GetChildren()}) do
                    if child.GetRegions then
                        for _, region in ipairs({child:GetRegions()}) do
                            if region:IsObjectType("FontString") then
                                region:SetAlpha(0)
                            end
                        end
                    end
                end
            end

            -- Step F: Hook SetAtlas on icon texture to prevent Blizzard re-applying borders (one-time hook)
            if iconTexture and iconTexture.SetAtlas and not iconTexture._h3z0uiAtlasHooked then
                iconTexture._h3z0uiAtlasHooked = true
                hooksecurefunc(iconTexture, "SetAtlas", function(self)
                    -- Restore TexCoord after any atlas change
                    self:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                end)
            end
        end)
        end  -- end else (not hideIcon)
    end

    -- 3b. Reposition statusBar and icon based on orientation and visibility
    if statusBar then
        pcall(function()
            statusBar:ClearAllPoints()

            if isVertical then
                -- VERTICAL: Icon at top or bottom, bar fills remaining space
                if hideIcon or not iconContainer then
                    -- No icon: bar fills entire frame
                    statusBar:SetAllPoints(frame)
                else
                    -- Position icon based on iconPosition setting
                    iconContainer:ClearAllPoints()
                    if iconPosition == "bottom" then
                        iconContainer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
                        statusBar:SetPoint("TOP", frame, "TOP", 0, 0)
                        statusBar:SetPoint("LEFT", frame, "LEFT", 0, 0)
                        statusBar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
                        statusBar:SetPoint("BOTTOM", iconContainer, "TOP", 0, 0)
                    else -- "top" (default)
                        iconContainer:SetPoint("TOP", frame, "TOP", 0, 0)
                        statusBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
                        statusBar:SetPoint("LEFT", frame, "LEFT", 0, 0)
                        statusBar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
                        statusBar:SetPoint("TOP", iconContainer, "BOTTOM", 0, 0)
                    end
                end
            else
                -- HORIZONTAL: Original behavior
                if hideIcon or not iconContainer then
                    statusBar:SetPoint("LEFT", frame, "LEFT", 0, 0)
                else
                    statusBar:SetPoint("LEFT", iconContainer, "RIGHT", 0, 0)
                end
                statusBar:SetPoint("TOP", frame, "TOP", 0, 0)
                statusBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
                statusBar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            end
        end)
    end

    -- 4 + 5. StatusBar texture and colour (class or custom) with opacity, kept in place by the hooks
    if statusBar and statusBar.SetStatusBarTexture then
        local _ = texture and useClassColor and barColor and barOpacity
        inReapply = false
        ReapplyBarLook(statusBar)
        HookStatusBar(statusBar)
    end

    -- 6. Apply clean backdrop (solid background BEHIND the statusBar fill)
    -- Create on the frame itself, positioned behind statusBar
    if not frame._trackedBg then
        frame._trackedBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    end
    -- Apply background color from settings
    local bgR, bgG, bgB = bgColor[1] or 0, bgColor[2] or 0, bgColor[3] or 0
    frame._trackedBg:SetColorTexture(bgR, bgG, bgB, 1)
    if statusBar then
        frame._trackedBg:ClearAllPoints()
        frame._trackedBg:SetAllPoints(statusBar)
    end
    frame._trackedBg:SetAlpha(bgOpacity)
    frame._trackedBg:Show()

    -- 7. Apply crisp border using 4-edge technique
    -- Parent to the bar frame itself (not viewer) so it hides when bar hides
    if borderSize > 0 then
        if not frame._trackedBorderContainer then
            local container = CreateFrame("Frame", nil, frame)
            container:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 1) + 5)

            -- Create 4 edge textures
            container._top = container:CreateTexture(nil, "OVERLAY", nil, 7)
            container._top:SetColorTexture(0, 0, 0, 1)
            container._bottom = container:CreateTexture(nil, "OVERLAY", nil, 7)
            container._bottom:SetColorTexture(0, 0, 0, 1)
            container._left = container:CreateTexture(nil, "OVERLAY", nil, 7)
            container._left:SetColorTexture(0, 0, 0, 1)
            container._right = container:CreateTexture(nil, "OVERLAY", nil, 7)
            container._right:SetColorTexture(0, 0, 0, 1)

            frame._trackedBorderContainer = container
        end

        local container = frame._trackedBorderContainer
        -- Position container to wrap around the bar (extends OUTSIDE by borderSize)
        container:ClearAllPoints()
        container:SetPoint("TOPLEFT", frame, "TOPLEFT", -borderSize, borderSize)
        container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", borderSize, -borderSize)

        -- Top edge
        container._top:ClearAllPoints()
        container._top:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        container._top:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
        container._top:SetHeight(borderSize)

        -- Bottom edge
        container._bottom:ClearAllPoints()
        container._bottom:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        container._bottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        container._bottom:SetHeight(borderSize)

        -- Left edge
        container._left:ClearAllPoints()
        container._left:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        container._left:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        container._left:SetWidth(borderSize)

        -- Right edge
        container._right:ClearAllPoints()
        container._right:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
        container._right:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        container._right:SetWidth(borderSize)

        container:Show()
    else
        if frame._trackedBorderContainer then
            frame._trackedBorderContainer:Hide()
        end
    end

    -- 8. Apply text size to duration/name text (hide if hideText enabled or vertical without showTextOnVertical)
    local generalFont = GetGeneralFont()
    local generalOutline = GetGeneralFontOutline()
    local showText = not hideText and (not isVertical or showTextOnVertical)

    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            if region and region:GetObjectType() == "FontString" then
                pcall(function()
                    if showText then
                        region:SetFont(generalFont, textSize, generalOutline)
                        region:SetAlpha(1)
                    else
                        region:SetAlpha(0)
                    end
                end)
            end
        end
    end

    if statusBar and statusBar.GetRegions then
        for _, region in ipairs({statusBar:GetRegions()}) do
            if region and region:GetObjectType() == "FontString" then
                pcall(function()
                    if showText then
                        region:SetFont(generalFont, textSize, generalOutline)
                        region:SetAlpha(1)
                    else
                        region:SetAlpha(0)
                    end
                end)
            end
        end
    end

    frame._trackedBarStyled = true
end

---------------------------------------------------------------------------
-- ICON CENTER MANAGER (PARENT-SYNCHRONIZED & STABILIZED)
---------------------------------------------------------------------------

local iconState = {
    isInitialized = false,
    lastCount     = 0,
}

local function LayoutBuffIconsBody()
    if not BuffIconCooldownViewer then return end
    if isIconLayoutRunning then return end  -- Re-entry guard
    if IsLayoutSuppressed() then return end

    isIconLayoutRunning = true

    local settings = GetBuffSettings()
    if not settings.enabled then
        isIconLayoutRunning = false
        return
    end

    -- Apply HUD layer priority
    local core = GetCore()
    local hudLayering = core and core.db and core.db.profile and core.db.profile.hudLayering
    local layerPriority = hudLayering and hudLayering.buffIcon or 5
    if core and core.GetHUDFrameLevel then
        local frameLevel = core:GetHUDFrameLevel(layerPriority)
        BuffIconCooldownViewer:SetFrameLevel(frameLevel)
    end

    local icons = GetBuffIconFrames()
    local currentCount = #icons

    -- Handle empty state
    if currentCount == 0 then
        iconState.lastCount = 0
        iconState.isInitialized = false
        isIconLayoutRunning = false
        return
    end

    -- Get settings
    local iconSize = settings.iconSize or 42
    local padding = settings.padding or 0
    local aspectRatio = settings.aspectRatioCrop or 1.0
    local growthDirection = settings.growthDirection or "CENTERED_HORIZONTAL"

    -- Calculate dimensions using crop-based aspect ratio
    local iconWidth, iconHeight = iconSize, iconSize
    if aspectRatio > 1.0 then
        -- Wider: height shrinks
        iconHeight = iconSize / aspectRatio
    elseif aspectRatio < 1.0 then
        -- Taller: width shrinks
        iconWidth = iconSize * aspectRatio
    end

    local targetCount = currentCount
    iconState.lastCount = currentCount
    iconState.isInitialized = true

    -- Determine if vertical or horizontal layout
    local isVertical = (growthDirection == "UP" or growthDirection == "DOWN")

    -- Calculate total size using our settings
    local totalWidth, totalHeight
    if isVertical then
        totalWidth = iconWidth
        totalHeight = (targetCount * iconHeight) + ((targetCount - 1) * padding)
        totalHeight = H3z0UICore:PixelRound(totalHeight)
    else
        totalWidth = (targetCount * iconWidth) + ((targetCount - 1) * padding)
        totalWidth = H3z0UICore:PixelRound(totalWidth)
        totalHeight = iconHeight
    end

    -- Calculate starting position for centering within the viewer
    local startX, startY
    if isVertical then
        startX = 0
        if growthDirection == "UP" then
            -- Grow up: icon 1 at bottom, icons stack upward
            startY = -totalHeight / 2 + iconHeight / 2
        else -- DOWN
            -- Grow down: icon 1 at top, icons stack downward
            startY = totalHeight / 2 - iconHeight / 2
        end
        startY = H3z0UICore:PixelRound(startY)
    else
        -- Horizontal (centered)
        startX = -totalWidth / 2 + iconWidth / 2
        startX = H3z0UICore:PixelRound(startX)
        startY = 0
    end

    -- Tolerance-based check: skip repositioning if all icons are already in correct positions
    -- Prevents jitter from floating-point drift (allows 2px tolerance)
    local needsReposition = false
    for i, icon in ipairs(icons) do
        local expectedX, expectedY
        if isVertical then
            expectedX = 0
            if growthDirection == "UP" then
                expectedY = H3z0UICore:PixelRound(startY + (i - 1) * (iconHeight + padding))
            else -- DOWN
                expectedY = H3z0UICore:PixelRound(startY - (i - 1) * (iconHeight + padding))
            end
            -- Check Y position for vertical layout
            local point, _, _, _, yOfs = SafePoint(icon)
            if not point or not yOfs or abs(yOfs - expectedY) > 2 then
                needsReposition = true
                break
            end
        else
            expectedX = H3z0UICore:PixelRound(startX + (i - 1) * (iconWidth + padding))
            if not PositionMatchesTolerance(icon, expectedX, 2) then
                needsReposition = true
                break
            end
        end
    end

    if needsReposition then
        -- TWO-PASS LAYOUT: Clear all points first, then position - prevents mixed state flicker
        -- PASS 1: Clear all points first
        for _, icon in ipairs(icons) do
            icon:ClearAllPoints()
        end

        -- PASS 2: Apply style and position each icon
        for i, icon in ipairs(icons) do
            ApplyIconStyle(icon, settings)
            if isVertical then
                local y
                if growthDirection == "UP" then
                    y = startY + (i - 1) * (iconHeight + padding)
                else -- DOWN
                    y = startY - (i - 1) * (iconHeight + padding)
                end
                icon:SetPoint("CENTER", BuffIconCooldownViewer, "CENTER", 0, H3z0UICore:PixelRound(y))
            else
                local x = startX + (i - 1) * (iconWidth + padding)
                icon:SetPoint("CENTER", BuffIconCooldownViewer, "CENTER", H3z0UICore:PixelRound(x), 0)
            end
        end
    else
        -- Positions are correct, just apply styling (skip SetPoint calls)
        for _, icon in ipairs(icons) do
            ApplyIconStyle(icon, settings)
        end
    end

    -- The viewer itself is NOT resized any more: resizing Blizzard's viewer every time
    -- the buff count changed made Blizzard lay it out again, which made us re-layout and
    -- re-skin, over and over (icons jumping / changing look), and it tainted the viewer.
    local _ = totalWidth and totalHeight

    isIconLayoutRunning = false
end

LayoutBuffIcons = function()
    local ok = pcall(LayoutBuffIconsBody)
    if not ok then isIconLayoutRunning = false end
end

---------------------------------------------------------------------------
-- BAR ALIGNMENT MANAGER (FORCED UPWARD GROWTH)
---------------------------------------------------------------------------

local barState = {
    lastCount      = 0,
    lastBarWidth   = nil,
    lastBarHeight  = nil,
    lastSpacing    = nil,
}

-- cheap check (10 times a second): did Blizzard put its own size / background back?
BarLookDrifted = function(bar, settings)
    local isVertical = settings.orientation == "vertical"
    local wantH = isVertical and (settings.barWidth or 200) or (settings.barHeight or 24)
    local wantW = isVertical and (settings.barHeight or 24) or (settings.barWidth or 200)
    -- unknown (secret) sizes count as fine here; the regular re-skin still covers them
    local h, w = SafeHeight(bar), SafeWidth(bar)
    if h and math.abs(h - wantH) > 0.5 then return true end
    if w and math.abs(w - wantW) > 0.5 then return true end
    if bar._trackedBg and not bar._trackedBg:IsShown() then return true end
    local sb = bar.Bar
    if sb and appliedTex[sb] ~= nil then
        local cur = CurrentBarTex(sb)
        if cur ~= nil and cur ~= appliedTex[sb] then return true end
    end
    local icon = bar.Icon
    local ih = icon and not settings.hideIcon and SafeHeight(icon)
    if ih and math.abs(ih - (isVertical and (settings.barHeight or 24) or wantH)) > 0.5 then
        return true
    end
    return false
end

local function LayoutBuffBarsBody()
    if not BuffBarCooldownViewer then return end
    if isBarLayoutRunning then return end  -- Re-entry guard
    if IsLayoutSuppressed() then return end

    isBarLayoutRunning = true

    -- Apply HUD layer priority (strata + level)
    local core = GetCore()
    local hudLayering = core and core.db and core.db.profile and core.db.profile.hudLayering
    local layerPriority = hudLayering and hudLayering.buffBar or 5
    local frameLevel = 200  -- Default fallback
    if core and core.GetHUDFrameLevel then
        frameLevel = core:GetHUDFrameLevel(layerPriority)
    end
    -- Set strata to MEDIUM to match power bars, then apply frame level
    BuffBarCooldownViewer:SetFrameStrata("MEDIUM")
    BuffBarCooldownViewer:SetFrameLevel(frameLevel)

    local bars = GetBuffBarFrames()
    local count = #bars
    if count == 0 then
        barState.lastCount = 0
        isBarLayoutRunning = false
        return
    end

    local refBar = bars[1]
    if not refBar then
        isBarLayoutRunning = false
        return
    end

    -- Get tracked bar settings
    local settings = GetTrackedBarSettings()
    local stylingEnabled = settings.enabled

    -- Use settings for dimensions if styling enabled, otherwise use frame defaults
    local barWidth = (stylingEnabled and settings.barWidth) or SafeWidth(refBar) or 220
    local barHeight = (stylingEnabled and settings.barHeight) or SafeHeight(refBar) or 30
    local spacing = stylingEnabled and settings.spacing or (BuffBarCooldownViewer.childYPadding or 0)
    local growFromBottom = (not stylingEnabled) or (settings.growUp ~= false)

    -- Vertical bar support
    local orientation = stylingEnabled and settings.orientation or "horizontal"
    local isVertical = (orientation == "vertical")

    -- NOTE (taint fix): we no longer write isHorizontal / layoutFramesGoingRight / layoutFramesGoingUp
    -- onto Blizzard's BuffBarCooldownViewer. Writing to that frame's table from addon code tainted it and
    -- caused "attempted to index a table that cannot be accessed while tainted" in CooldownViewer.lua.
    -- Our bar positioning below (SetPoint on each bar) already overrides Blizzard's layout.

    -- For vertical bars, swap dimensions (height setting becomes width)
    local effectiveBarWidth, effectiveBarHeight
    if isVertical then
        effectiveBarWidth = barHeight  -- Height setting becomes bar width
        effectiveBarHeight = stylingEnabled and settings.barWidth or 200  -- Width setting becomes bar height
    else
        effectiveBarWidth = barWidth
        effectiveBarHeight = barHeight
    end

    if not effectiveBarHeight or effectiveBarHeight == 0 then
        isBarLayoutRunning = false
        return
    end

    barState.lastCount = count
    barState.lastBarWidth = effectiveBarWidth
    barState.lastBarHeight = effectiveBarHeight
    barState.lastSpacing = spacing

    -- Total size of the stack (height for horizontal bars, width for vertical)
    local totalSize
    if isVertical then
        totalSize = (count * effectiveBarWidth) + ((count - 1) * spacing)
    else
        totalSize = (count * effectiveBarHeight) + ((count - 1) * spacing)
    end
    totalSize = H3z0UICore:PixelRound(totalSize)

    -- POSITION VERIFICATION: Check if bars are already in correct positions (within 2px tolerance)
    -- This mirrors the icon layout's self-correcting behavior - if Blizzard moves a bar,
    -- we detect it and snap it back immediately
    local needsReposition = false
    local wantPoint = isVertical and (growFromBottom and "LEFT" or "RIGHT") or (growFromBottom and "BOTTOM" or "TOP")
    local wantWidth = stylingEnabled and (isVertical and barHeight or settings.barWidth) or nil
    for index, bar in ipairs(bars) do
        local offsetIndex = index - 1

        -- Blizzard sometimes anchors a bar by two points (left + right edge), which
        -- overrides the width and shifts it: only one anchor of ours on the viewer is OK
        local p1, rel, _, px, py = SafePoint(bar)
        if SafeNumPoints(bar) ~= 1 or p1 ~= wantPoint or rel ~= BuffBarCooldownViewer then
            needsReposition = true
            break
        end
        local bw = SafeWidth(bar)
        if wantWidth and (not bw or math.abs(bw - wantWidth) > 1) then
            needsReposition = true
            break
        end

        if isVertical then
            -- Check X position for vertical layout
            local expectedX
            if growFromBottom then
                expectedX = H3z0UICore:PixelRound(offsetIndex * (effectiveBarWidth + spacing))
            else
                expectedX = H3z0UICore:PixelRound(-offsetIndex * (effectiveBarWidth + spacing))
            end
            if not px or abs(px - expectedX) > 2 then
                needsReposition = true
                break
            end
        else
            -- Check Y position for horizontal layout
            local expectedY
            if growFromBottom then
                expectedY = H3z0UICore:PixelRound(offsetIndex * (effectiveBarHeight + spacing))
            else
                expectedY = H3z0UICore:PixelRound(-offsetIndex * (effectiveBarHeight + spacing))
            end
            if not py or abs(py - expectedY) > 2 then
                needsReposition = true
                break
            end
        end
    end

    if needsReposition then
        -- PASS 1: Clear all points
        for _, bar in ipairs(bars) do
            pcall(bar.ClearAllPoints, bar)
        end

        -- PASS 2: Position each bar (each one guarded, so one bad bar can't stop the rest)
        for index, bar in ipairs(bars) do Guard(function()
            local offsetIndex = index - 1
            -- Blizzard sets its own width when a bar is reused: put ours back with the anchor
            if wantWidth then bar:SetWidth(wantWidth) end

            if isVertical then
                -- VERTICAL BARS: Stack horizontally (left/right)
                local x
                if growFromBottom then
                    -- Grow Right: bar 1 at LEFT edge, stacks rightward
                    x = offsetIndex * (effectiveBarWidth + spacing)
                    x = H3z0UICore:PixelRound(x)
                    bar:SetPoint("LEFT", BuffBarCooldownViewer, "LEFT", x, 0)
                else
                    -- Grow Left: bar 1 at RIGHT edge, stacks leftward
                    x = -offsetIndex * (effectiveBarWidth + spacing)
                    x = H3z0UICore:PixelRound(x)
                    bar:SetPoint("RIGHT", BuffBarCooldownViewer, "RIGHT", x, 0)
                end
            else
                -- HORIZONTAL BARS: Stack vertically (up/down)
                local y
                if growFromBottom then
                    y = offsetIndex * (effectiveBarHeight + spacing)
                    y = H3z0UICore:PixelRound(y)
                    bar:SetPoint("BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, y)
                else
                    y = -offsetIndex * (effectiveBarHeight + spacing)
                    y = H3z0UICore:PixelRound(y)
                    bar:SetPoint("TOP", BuffBarCooldownViewer, "TOP", 0, y)
                end
            end
        end) end
    end

    -- Apply visual styling and frame strata/level to each bar
    local now = GetTime()
    local stamp = H3z0UI_BuffBar._styleGen or 0
    for _, bar in ipairs(bars) do Guard(function()
        if stylingEnabled then
            local cid = SafeVal(bar.cooldownID)
            if bar.h3zStyleGen ~= stamp or bar.h3zStyleCID ~= cid or bar.h3zStyleW ~= settings.barWidth
                or BarLookDrifted(bar, settings) or now - (bar.h3zStyledAt or 0) > 3 then
                ApplyBarStyle(bar, settings)
                bar.h3zStyleGen, bar.h3zStyleCID, bar.h3zStyleW, bar.h3zStyledAt = stamp, cid, settings.barWidth, now
            end
        end
        -- Apply frame strata/level to each bar AND its .Bar child for proper HUD layering
        bar:SetFrameStrata("MEDIUM")
        bar:SetFrameLevel(frameLevel)
        if bar.Bar then
            bar.Bar:SetFrameStrata("MEDIUM")
            bar.Bar:SetFrameLevel(frameLevel + 1)
        end
        if bar.Icon then
            bar.Icon:SetFrameStrata("MEDIUM")
            bar.Icon:SetFrameLevel(frameLevel + 1)
        end
    end) end

    -- Update container dimensions to prevent Blizzard's Layout() from resizing and causing drift
    -- Both vertical and horizontal set ONE dimension fixed, letting bars overflow the other dimension
    -- NOTE (taint fix): viewer:SetSize() removed. Resizing Blizzard's viewer from addon code fires its
    -- OnSizeChanged handler in tainted execution, which tainted the aura table of the Tracked Bars viewer.

    isBarLayoutRunning = false
end

-- 0.24.8: run guarded. Before, one error inside the layout left isBarLayoutRunning set for the
-- rest of the session: every bar Blizzard made after that kept Blizzard's look and position and
-- sat on top of our bars.
LayoutBuffBars = function()
    local ok, err = pcall(LayoutBuffBarsBody)
    if not ok then
        isBarLayoutRunning = false
        lastBarError = err
    end
end
H3z0UI_BuffBar.LastBarError = function() return lastBarError end

-- /h3z0bars: what the tracked bars look like right now (for bug reports)
SLASH_H3Z0BARS1 = "/h3z0bars"
SlashCmdList["H3Z0BARS"] = function()
    local P = function(m) print("|cff34D399H3z0 bars:|r " .. m) end
    if not BuffBarCooldownViewer then P("no Tracked Bars viewer") return end
    local list = {}
    for _, f in ipairs(GetBuffBarFrames()) do list[f] = true end
    local n = 0
    for _, c in ipairs({ BuffBarCooldownViewer:GetChildren() }) do
        if c.Bar then
            n = n + 1
            local okS, sh = pcall(c.IsShown, c)
            local p1, rel, _, x, y = SafePoint(c)
            P(string.format("#%d idx=%s shown=%s inList=%s styled=%s w=%s h=%s pts=%s %s->%s %s,%s",
                n, tostring(SafeVal(c.layoutIndex)), okS and (issecret(sh) and "secret" or tostring(sh)) or "err",
                tostring(list[c] or false), tostring(c._trackedBarStyled or false),
                tostring(SafeWidth(c) and floor(SafeWidth(c)) or "?"), tostring(SafeHeight(c) and floor(SafeHeight(c)) or "?"),
                tostring(SafeNumPoints(c) or "?"), tostring(p1),
                rel == BuffBarCooldownViewer and "viewer" or tostring(rel and rel.GetName and rel:GetName() or rel),
                tostring(x and floor(x) or "?"), tostring(y and floor(y) or "?")))
        end
    end
    P("last layout error: " .. tostring(lastBarError or "none"))
end

---------------------------------------------------------------------------
-- CHANGE DETECTION (called from OnUpdate hooks on viewers)
-- Icons: Hash-based detection for count/settings changes
-- Bars: Position verification (hash removed - bars now self-correct via position checks)
---------------------------------------------------------------------------

local lastIconHash = ""

-- Build hash of icon count + settings to detect actual changes
local function BuildIconHash(count, settings)
    return string.format("%d_%d_%d_%.2f_%d_%s",
        count,
        settings.iconSize or 42,
        settings.padding or 0,
        settings.aspectRatioCrop or 1.0,
        settings.borderSize or 2,
        settings.growthDirection or "CENTERED_HORIZONTAL"
    )
end

local function CheckIconChanges()
    if not BuffIconCooldownViewer then return end
    if isIconLayoutRunning then return end
    if IsLayoutSuppressed() then return end

    -- Count visible icons
    local visibleCount = 0
    for _, child in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
        if child and child ~= BuffIconCooldownViewer.Selection then
            if (child.icon or child.Icon) and SafeShown(child) then
                visibleCount = visibleCount + 1
            end
        end
    end

    -- Build hash including count AND settings
    local settings = GetBuffSettings()
    local hash = BuildIconHash(visibleCount, settings)

    -- Only layout if hash changed (count or settings)
    if hash == lastIconHash then
        return
    end

    lastIconHash = hash
    LayoutBuffIcons()
end

local function CheckBarChanges()
    if not BuffBarCooldownViewer then return end
    if isBarLayoutRunning then return end  -- Skip if already laying out

    -- Always call LayoutBuffBars - it now has internal position verification
    -- that will skip repositioning if all bars are already in correct positions.
    -- This ensures we catch any position drift caused by Blizzard's Layout()
    -- even when count/settings haven't changed.
    LayoutBuffBars()
end

---------------------------------------------------------------------------
-- FORCE POPULATE: Briefly trigger Edit Mode behavior to load all spells
-- This ensures the buff icons know what spells to display on first load
---------------------------------------------------------------------------

local forcePopulateDone = false

local function ForcePopulateBuffIcons()
    if forcePopulateDone then return end
    if InCombatLockdown() then return end

    local viewer = BuffIconCooldownViewer
    if not viewer then return end

    forcePopulateDone = true

    -- Methods 1/2 REMOVED: calling viewer:Layout() and nudging viewer:SetSize() from addon code ran Blizzard's
    -- layout (and the OnSizeChanged handlers it fires) TAINTED. That left the Tracked Buffs viewer with tainted
    -- state, and its UNIT_AURA handling then failed with "attempted to index a table that cannot be accessed
    -- while tainted". Blizzard populates the viewer by itself; we only rescan/skin what it creates (below).

    -- Method 3: Force a rescan via H3z0UICore if available
    local core = GetCore()
    if core and core.ForceRefreshBuffIcons then
            C_Timer.After(0.2, function()
                pcall(function() core:ForceRefreshBuffIcons() end)
            end)
    end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

local initialized = false
local iconAuraHook, iconRescanPending

-- 0.24.9: the checks run on a frame of our own. They used to be hooked into the viewers'
-- OnUpdate script, but Blizzard's layout code replaces that script (SetScript) every time it
-- lays the bars out, which silently removed our hook: from then on a bar Blizzard reused kept
-- Blizzard's look and size. The viewers can also load after us, so hooks are added whenever
-- they show up.
local iconHooked, barHooked = false, false
local function HookViewers()
    if BuffIconCooldownViewer and not iconHooked then
        iconHooked = true
        BuffIconCooldownViewer:HookScript("OnSizeChanged", function()
            if IsLayoutSuppressed() or isIconLayoutRunning then return end
            LayoutBuffIcons()
        end)
        BuffIconCooldownViewer:HookScript("OnShow", function()
            if IsLayoutSuppressed() or isIconLayoutRunning then return end
            LayoutBuffIcons()
        end)
        if BuffIconCooldownViewer.Layout then
            hooksecurefunc(BuffIconCooldownViewer, "Layout", function()
                if IsLayoutSuppressed() or isIconLayoutRunning then return end
                LayoutBuffIcons()
            end)
        end
    end
    if BuffBarCooldownViewer and not barHooked then
        barHooked = true
        if BuffBarCooldownViewer.Layout then
            hooksecurefunc(BuffBarCooldownViewer, "Layout", function()
                if IsLayoutSuppressed() or isBarLayoutRunning then return end
                LayoutBuffBars()
            end)
        end
        BuffBarCooldownViewer:HookScript("OnShow", function()
            if IsLayoutSuppressed() or isBarLayoutRunning then return end
            LayoutBuffBars()
        end)
    end
end

local driver = CreateFrame("Frame")
do
    local acc = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.1 then return end   -- 10 checks a second
        acc = 0
        if not (iconHooked and barHooked) then HookViewers() end
        if BuffIconCooldownViewer and SafeShown(BuffIconCooldownViewer) then CheckIconChanges() end
        if BuffBarCooldownViewer and SafeShown(BuffBarCooldownViewer) then CheckBarChanges() end
    end)
end

local function Initialize()
    if initialized then return end
    initialized = true

    -- Force populate buff icons first (teaches the viewer what spells to show)
    ForcePopulateBuffIcons()

    HookViewers()

    ---------------------------------------------------------------------------
    -- EVENT-BASED UPDATES: UNIT_AURA hook for immediate buff change detection
    -- (Replaces polling as primary detection - polling becomes fallback only)
    ---------------------------------------------------------------------------

    if BuffIconCooldownViewer and not iconAuraHook then
        iconAuraHook = CreateFrame("Frame")
        iconAuraHook:RegisterEvent("UNIT_AURA")
        iconAuraHook:SetScript("OnEvent", function(_, event, unit)
            if unit == "player" and BuffIconCooldownViewer:IsShown() then
                -- Debounce: only queue one rescan per 0.1s window
                if not iconRescanPending then
                    iconRescanPending = true
                    C_Timer.After(0.1, function()
                        iconRescanPending = nil
                        -- Re-check visibility after timer (viewer may have hidden)
                        if BuffIconCooldownViewer:IsShown() then
                            if isIconLayoutRunning then return end
                            if IsLayoutSuppressed() then return end
                            -- Reset hash to force layout recalculation
                            lastIconHash = ""
                            CheckIconChanges()
                        end
                    end)
                end
            end
        end)
    end

    -- Initial layouts (after force populate)
    C_Timer.After(0.3, function()
        LayoutBuffIcons()  -- Direct calls
        LayoutBuffBars()
    end)
end

---------------------------------------------------------------------------
-- EVENT HANDLING
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, Initialize)
        -- Additional force populate attempts
        C_Timer.After(2, ForcePopulateBuffIcons)
        C_Timer.After(4, ForcePopulateBuffIcons)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if isInitialLogin or isReloadingUi then
            C_Timer.After(1.5, function()
                ForcePopulateBuffIcons()
                LayoutBuffIcons()  -- Direct calls
                LayoutBuffBars()
            end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- After combat ends, try to populate if we haven't yet
        C_Timer.After(0.5, function()
            ForcePopulateBuffIcons()
            LayoutBuffIcons()  -- Direct calls
            LayoutBuffBars()
        end)
    end
end)

-- Also try to initialize immediately if viewers exist
C_Timer.After(0, function()
    if BuffIconCooldownViewer or BuffBarCooldownViewer then
        Initialize()
    end
end)

---------------------------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------------------------

H3z0UI_BuffBar.LayoutIcons = LayoutBuffIcons
H3z0UI_BuffBar.LayoutBars = LayoutBuffBars
H3z0UI_BuffBar.Initialize = Initialize

-- Force refresh function (can be called from GUI)
function H3z0UI_BuffBar.Refresh()
    -- settings may have changed: every bar is styled again
    H3z0UI_BuffBar._styleGen = (H3z0UI_BuffBar._styleGen or 0) + 1
    -- Reset states to force recalculation
    iconState.isInitialized = false
    iconState.lastCount = 0
    barState.lastCount = 0
    lastIconHash = ""  -- Force hash recalculation for icons

    -- Blizzard's viewer fields (isHorizontal / layoutFramesGoing*) are NOT written any
    -- more: the Tracked Bars viewer reads auras, and values written by an addon taint
    -- it ("Auras cannot be accessed when secret while tainted"). LayoutBuffBars below
    -- arranges the bars in the chosen orientation / direction itself.

    LayoutBuffIcons()
    LayoutBuffBars()
end

-- Global refresh function for GUI
_G.H3z0UI_RefreshBuffBar = H3z0UI_BuffBar.Refresh
