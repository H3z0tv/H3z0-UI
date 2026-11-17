local ADDON_NAME, ns = ...
local NP = ns.H3zPlates
if not NP then return end

---------------------------------------------------------------------------
-- Debuff icons through the game's own aura container (CustomAuraContainerTemplate).
--
-- The game keeps aura data away from addons, but it gives addons a container that draws
-- the auras itself. The addon only says which auras (your debuffs) and where the row
-- sits, so the icons can be moved, sized and switched off, in and out of combat.
-- The container lives under H3z0 UI's own plate frame, never under the game's UnitFrame.
-- The game's own debuff list on the plate is made invisible while the container is on.
-- When the game has no aura container, the old icon row (nameplates_extras.lua) is used.
---------------------------------------------------------------------------

local AC = {}
NP.AuraContainers = AC

local BASE, GAP, MAXN = 32, 4, 10
local supported

local function Settings() return NP.GetSettings and NP.GetSettings() end

local function LoadAPI()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    elseif UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_AuraContainer")
    end
    return AuraUtil and AuraUtil.CreateFilterString and AuraUtil.AuraFilters and true or false
end

function AC.Supported()
    if supported == nil then
        supported = false
        if LoadAPI() then
            local ok, f = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
            if ok and f then
                supported = type(f.AddAuraGroup) == "function" and type(f.SetUnit) == "function"
                pcall(f.Hide, f)
            end
        end
    end
    return supported
end

local function FlowDir(key)
    local flow = AnchorUtil and AnchorUtil.FlowDirection
    return flow and flow[key] or nil
end

local function SetFlow(container, maxCount)
    if container.SetFlowLayoutAnchorPoint then pcall(container.SetFlowLayoutAnchorPoint, container, "LEFT")
    elseif container.SetAuraLayoutAnchorPoint then pcall(container.SetAuraLayoutAnchorPoint, container, "LEFT") end
    local right, up = FlowDir("Right"), FlowDir("Up")
    if right and up then
        if container.SetFlowLayoutGrowthDirection then pcall(container.SetFlowLayoutGrowthDirection, container, right, up)
        elseif container.SetAuraLayoutGrowthDirection then pcall(container.SetAuraLayoutGrowthDirection, container, right, up) end
    end
    if container.SetFlowLayoutMaximumLineSize then
        pcall(container.SetFlowLayoutMaximumLineSize, container, maxCount * BASE + (maxCount - 1) * GAP)
    end
end

local function InitButton(button)
    button:SetSize(BASE, BASE)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if button.SetIcon then button:SetIcon(icon) end
    local edge = button:CreateTexture(nil, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 1)
    local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetDrawBling then cd:SetDrawBling(false) end
    if cd.SetReverse then cd:SetReverse(true) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    if button.SetDurationCooldown then button:SetDurationCooldown(cd) end
    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
    if button.SetApplicationCount then button:SetApplicationCount(count, {}) end
    if button.SetHideTooltipInCombat then button:SetHideTooltipInCombat(false) end
    if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
end

local function AddGroup(container, key, filter, layoutIndex, candidate)
    local options = {
        maxFrameCount = MAXN,
        initializeFrame = InitButton,
        candidateFilters = candidate or {},
        layout = { elementSpacing = GAP, lineSpacing = GAP, elementWidth = BASE, elementHeight = BASE, layoutIndex = layoutIndex },
    }
    if AuraContainerSortMethod then options.sortMethod = AuraContainerSortMethod.Default end
    if AuraContainerSortDirection then options.sortDirection = AuraContainerSortDirection.Normal end
    return pcall(container.AddAuraGroup, container, key, filter, options)
end

local function Build(p)
    if not AC.Supported() then return nil end
    local AF, FS = AuraUtil.AuraFilters, AuraUtil.CreateFilterString
    local anchor = CreateFrame("Frame", nil, p)
    anchor:SetSize(MAXN * BASE + (MAXN - 1) * GAP, BASE + 4)
    anchor:SetFrameLevel((p:GetFrameLevel() or 1) + 12)
    anchor:Hide()
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
    if not ok or not container then anchor:Hide() return nil end
    container:SetEnabled(false)
    container:Hide()
    container:SetPoint("LEFT", anchor, "LEFT", 0, 0)
    if container.SetFlattensRenderLayers then pcall(container.SetFlattensRenderLayers, container, true) end
    SetFlow(container, MAXN)

    local mine = FS(AF.Harmful, AF.Player or "PLAYER", AF.IncludeNameplateOnly)
    local okMine = AddGroup(container, "Mine", mine, 1, { isFromPlayerOrPlayerPet = true })
    local helpful = FS(AF.Helpful, AF.IncludeNameplateOnly)
    local okSteal = AddGroup(container, "Dispel", helpful, 2, { isStealable = true })
    if not okMine then anchor:Hide() return nil end
    return { anchor = anchor, container = container, hasDispel = okSteal and true or false }
end

local function GroupEnabled(container, key, on)
    if type(container.HasAuraGroup) ~= "function" or type(container.SetAuraGroupEnabled) ~= "function" then return end
    local okHas, has = pcall(container.HasAuraGroup, container, key)
    if okHas and has then pcall(container.SetAuraGroupEnabled, container, key, on and true or false) end
end

local function NativeLists(p)
    local np = p.namePlate
    local uf = np and np.UnitFrame
    return uf and (uf.AurasFrame or uf.AuraFrame) or nil
end

local function NativeAlpha(p, a)
    local auras = NativeLists(p)
    if not auras then return end
    for _, k in ipairs({ "DebuffListFrame" }) do
        local f = auras[k]
        if f and f.SetAlpha then pcall(f.SetAlpha, f, a) end
    end
end

function AC.Release(p)
    local set = p.h3zAC
    if not set then return end
    pcall(set.container.SetEnabled, set.container, false)
    pcall(set.container.Hide, set.container)
    pcall(set.anchor.Hide, set.anchor)
    set.unit = nil
    if p.h3zACOn then
        p.h3zACOn = false
        NativeAlpha(p, 1)
    end
end

-- true when the container shows the debuffs of this plate
function AC.Apply(p, s)
    if not p.unit or not p.border then AC.Release(p) return false end
    local set = p.h3zAC
    if not set then
        set = Build(p)
        if not set then return false end
        p.h3zAC = set
    end
    local container, anchor = set.container, set.anchor
    local size = tonumber(s.auraSize) or 18
    local maxN = math.max(1, math.min(MAXN, tonumber(s.auraMax) or 6))
    local scale = size / BASE
    local ox, oy = tonumber(s.auraX) or 0, tonumber(s.auraY) or 0

    SetFlow(container, maxN)
    anchor:SetSize(maxN * BASE + (maxN - 1) * GAP, BASE + 4)
    pcall(anchor.SetScale, anchor, scale)
    -- above the name when the name sits above the bar, else just above the bar
    local lift = 4
    if p.name and p.name:IsShown() then
        local h = p.name.GetStringHeight and p.name:GetStringHeight() or 12
        if type(h) == "number" and h > 0 and h < 60 then lift = h + 6 end
    end
    anchor:ClearAllPoints()
    anchor:SetPoint("BOTTOMLEFT", p.border, "TOPLEFT", ox / scale, (lift + oy) / scale)

    GroupEnabled(container, "Mine", true)
    GroupEnabled(container, "Dispel", s.auraDispel and set.hasDispel)

    if set.unit ~= p.unit then
        local okU = pcall(container.SetUnit, container, p.unit)
        if not okU then AC.Release(p) return false end
        set.unit = p.unit
    end
    local okE = pcall(container.SetEnabled, container, true)
    local okS = okE and pcall(container.Show, container)
    local okA = okS and pcall(anchor.Show, anchor)
    if not (okE and okS and okA) then AC.Release(p) return false end
    -- the game's own list is hidden only after ours is running
    p.h3zACOn = true
    NativeAlpha(p, 0)
    return true
end
