-- luacheck: globals ToggleAllBags
-- luacheck: read globals ContainerFrame_AllowedToOpenBags debugstack
-- luacheck: read globals SetCVarBitfield LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG
local ADDON_NAME, ns = ...
local Bags = ns.Bags or {}; ns.Bags = Bags

local Takeover = {}
Bags.Takeover = Takeover

local active = false
local hooksInstalled = false
local originalToggleAllBags = nil
local originalParents = {}
local hiddenHolder = nil
local openedByFrameName = nil
local lastToggleTime = -1

local CONTAINER_FRAMES = {
    "ContainerFrame1", "ContainerFrame2", "ContainerFrame3",
    "ContainerFrame4", "ContainerFrame5", "ContainerFrame6",
    "ContainerFrameCombinedBags",
}

function Takeover.IsActive()
    return active
end

local function AllowedToOpen()
    if type(ContainerFrame_AllowedToOpenBags) == "function" then
        return ContainerFrame_AllowedToOpenBags()
    end
    return true
end

local function GetCallStack()
    return (debugstack and debugstack()) or ""
end

function Takeover.OpenForFrame(frame, forceUpdate)
    if not active then return end
    if not AllowedToOpen() then return end
    if Bags.BagWindow.IsShown() then
        if forceUpdate and Bags.BagWindow.Refresh then Bags.BagWindow.Refresh() end
        return
    end
    if frame and Bags.AutoOpen and not Bags.AutoOpen.ShouldOpenFor(frame) then
        return
    end
    openedByFrameName = frame and frame.GetName and frame:GetName() or nil
    Bags.BagWindow.Show()
end

function Takeover.CloseForFrame(frame)
    if not active then return false end
    if frame and frame.GetName then
        local name = frame:GetName()
        if name ~= openedByFrameName then return false end
    end
    local wasShown = Bags.BagWindow.IsShown()
    openedByFrameName = nil
    Bags.BagWindow.Hide()
    return wasShown
end

local function ManualToggle()
    if not AllowedToOpen() then return end
    local now = GetTime and GetTime() or 0
    if now == lastToggleTime then return end
    lastToggleTime = now
    if Bags.BagWindow.IsShown() then
        Takeover.CloseForFrame()
    else
        Takeover.OpenForFrame()
    end
end

local function OurToggleAllBags()
    ManualToggle()
end

local function DirectToggleOnly()
    if not active then return end
    local stack = GetCallStack()
    if stack:match("OpenAllBags") or stack:match("CloseAllBags") then return end
    ManualToggle()
end

local function InstallHooks()
    if hooksInstalled or type(hooksecurefunc) ~= "function" then return end
    hooksInstalled = true

    hooksecurefunc("ToggleBackpack", DirectToggleOnly)
    hooksecurefunc("ToggleBag", DirectToggleOnly)

    hooksecurefunc("OpenAllBags", function(frame, forceUpdate)
        Takeover.OpenForFrame(frame, forceUpdate)
    end)

    if type(_G.OpenAllBagsMatchingContext) == "function" then
        hooksecurefunc("OpenAllBagsMatchingContext", function(frame)
            Takeover.OpenForFrame(frame)
        end)
    end

    hooksecurefunc("OpenBag", function()
        if not active then return end
        if not GetCallStack():match("AlertFrameSystems") then return end
        Takeover.OpenForFrame()
    end)

    hooksecurefunc("CloseAllBags", function(frame)
        if not active then return end
        local stack = GetCallStack()
        if stack:match("CloseAllWindows")
            or stack:match("ToggleBackpack") or stack:match("ToggleBag") then
            return
        end
        Takeover.CloseForFrame(frame)
    end)
end

-- The Classic games show the bank bags in the same container frames as the
-- player's bags, so the frames can't be hidden for good there: only a frame
-- that opens one of the player's own bags is closed again (the H3z0 bag
-- window shows those); bank bags keep Blizzard's bag frames.
local IS_CLASSIC = ns.Client and ns.Client.isClassic
local classicHooked = {}
local function ClassicContainerShown(frame)
    if not active then return end
    local id = frame.GetID and frame:GetID()
    if type(id) == "number" and id >= 0 and id <= (tonumber(NUM_BAG_SLOTS) or 4) then
        frame:Hide()
    end
end

function Takeover.Apply()
    if active then return end
    active = true

    if IS_CLASSIC then
        for i = 1, (tonumber(NUM_CONTAINER_FRAMES) or 13) do
            local frame = _G["ContainerFrame" .. i]
            if frame and not classicHooked[frame] then
                classicHooked[frame] = true
                frame:HookScript("OnShow", ClassicContainerShown)
            end
            if frame and frame:IsShown() then ClassicContainerShown(frame) end
        end
        originalToggleAllBags = _G.ToggleAllBags
        _G.ToggleAllBags = OurToggleAllBags
        InstallHooks()
        return
    end

    if not hiddenHolder then
        hiddenHolder = Bags.TakeoverShared.MakeHiddenHolder()
    end
    for _, name in ipairs(CONTAINER_FRAMES) do
        local frame = _G[name]
        if frame then
            frame:Hide()
            originalParents[frame] = frame:GetParent()
            frame:SetParent(hiddenHolder)
        end
    end

    originalToggleAllBags = _G.ToggleAllBags
    _G.ToggleAllBags = OurToggleAllBags

    InstallHooks()

    if SetCVarBitfield and LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG then
        SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG, true)
    end
end

function Takeover.Revert()
    if not active then return end

    if _G.ToggleAllBags == OurToggleAllBags then
        _G.ToggleAllBags = originalToggleAllBags
    end
    originalToggleAllBags = nil

    for frame, parent in pairs(originalParents) do
        frame:Hide()
        frame:SetParent(parent)
        originalParents[frame] = nil
    end
    openedByFrameName = nil
    active = false
end
