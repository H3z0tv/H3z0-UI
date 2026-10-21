local ADDON_NAME, ns = ...
local Bags = ns.Bags or {}; ns.Bags = Bags
local Storage = ns.Storage

local Helpers = ns.Helpers
local GetSettings = Helpers.CreateDBGetter("bags")

local eventFrame = CreateFrame("Frame")
local uiActive = false
local started = false

function Bags.IsActive()
    return uiActive
end

local UI_EVENTS = {
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "ITEM_LOCK_CHANGED",
    "BAG_UPDATE_COOLDOWN",
    "EQUIPMENT_SETS_CHANGED",
    "PLAYER_LEVEL_UP",
    "SKILL_LINES_CHANGED",
    "NEW_RECIPE_LEARNED",
    "FACTION_STANDING_CHANGED",
    "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "GUILDBANKFRAME_OPENED",
    "GUILDBANKFRAME_CLOSED",
    "GUILDBANKLOG_UPDATE",
    "ADDON_LOADED",
}

local function IsEnabled()
    local s = GetSettings()
    return (s and s.enabled) and true or false
end

local function StartUI()
    if uiActive then return end
    uiActive = true
    Bags.Takeover.Apply()
    Bags.BankTakeover.Suppress()
    Bags.GuildTakeover.Init()
    ns.RunAfterFirstFrame(function()
        if not uiActive then return end
        for _, ev in ipairs(UI_EVENTS) do eventFrame:RegisterEvent(ev) end
        Bags.GuildTakeover.Init()
        if Bags.NewItems then Bags.NewItems.OnLogin() end
    end, 0.5)
end

local function StopUI()
    if not uiActive then return end
    uiActive = false
    for _, ev in ipairs(UI_EVENTS) do eventFrame:UnregisterEvent(ev) end
    Bags.BagWindow.Hide()
    Bags.BankWindow.Hide()
    Bags.GuildWindow.Hide()
    Bags.SearchWindow.Hide()
    if Bags.SortExecutor and Bags.SortExecutor.Cancel then Bags.SortExecutor.Cancel() end
    if Bags.Transfers and Bags.Transfers.Cancel then Bags.Transfers.Cancel() end
    if Bags.Junk and Bags.Junk.OnMerchant then Bags.Junk.OnMerchant(false) end
    if Bags.NewItems then Bags.NewItems.OnDisable() end
    Bags.Takeover.Revert()
    Bags.BankTakeover.Revert()
    Bags.GuildTakeover.Revert()
end

local function RefreshUnusableItems()
    if not uiActive then return end
    if Bags.ItemButtons then Bags.ItemButtons.InvalidateUnusableCache() end
    if Bags.BagWindow.IsShown() then
        Storage.Bus.Publish("BagsChanged", Storage.Store.GetCurrentCharacterKey(), {})
    end
    if Bags.BankWindow.IsShown() then
        Storage.Bus.Publish("BankChanged", Storage.Store.GetCurrentCharacterKey(), {})
        Storage.Bus.Publish("WarbandChanged", {})
    end
    if Bags.GuildWindow.IsShown() then Bags.GuildWindow.Refresh() end
end

Storage.Bus.Subscribe("RecipeLearningChanged", RefreshUnusableItems)

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "BANKFRAME_OPENED" then
        Bags.BankTakeover.OnBankOpened()
        if Bags.Transfers and Bags.Transfers.AutoDepositReagentsOnOpen then
            Bags.Transfers.AutoDepositReagentsOnOpen()
        end
    elseif event == "BANKFRAME_CLOSED" then
        if Bags.Transfers and Bags.Transfers.Cancel then Bags.Transfers.Cancel() end
        Bags.BankTakeover.OnBankClosed()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        Bags.AutoOpen.OnInteraction(arg1, true)
        if arg1 == Enum.PlayerInteractionType.Merchant and Bags.Junk then
            Bags.Junk.OnMerchant(true)
        elseif arg1 == Enum.PlayerInteractionType.GuildBanker
            and Bags.GuildTakeover then
            Bags.GuildTakeover.OnOpened()
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        Bags.AutoOpen.OnInteraction(arg1, false)
        if arg1 == Enum.PlayerInteractionType.Merchant and Bags.Junk then
            Bags.Junk.OnMerchant(false)
        elseif arg1 == Enum.PlayerInteractionType.GuildBanker
            and Bags.GuildTakeover then
            Bags.GuildTakeover.OnClosed()
        end
    elseif event == "ITEM_LOCK_CHANGED" or event == "BAG_UPDATE_COOLDOWN"
        or event == "EQUIPMENT_SETS_CHANGED" then
        local changed = {}
        if event == "ITEM_LOCK_CHANGED" and arg2 then changed[1] = arg1 end
        if Bags.BagWindow.IsShown() then
            Storage.Bus.Publish("BagsChanged", Storage.Store.GetCurrentCharacterKey(), changed)
        end
        if Bags.BankWindow.IsShown() then
            Storage.Bus.Publish("BankChanged", Storage.Store.GetCurrentCharacterKey(), {})
            Storage.Bus.Publish("WarbandChanged", {})
        end
    elseif event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED"
        or event == "NEW_RECIPE_LEARNED" or event == "FACTION_STANDING_CHANGED"
        or event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED"
        or (event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player") then
        RefreshUnusableItems()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if Bags.SortExecutor then Bags.SortExecutor.OnCombat() end
        if Bags.Transfers then Bags.Transfers.OnCombat() end
        if Bags.Junk and Bags.Junk.OnCombat then Bags.Junk.OnCombat() end
        if Bags.GuildWindow.IsShown() then Bags.GuildWindow.Refresh() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if Bags.cooldownRefreshPending then
            Bags.cooldownRefreshPending = nil
            if Bags.BagWindow.IsShown() then Bags.BagWindow.Refresh() end
            if Bags.BankWindow.IsShown() then Bags.BankWindow.Refresh() end
        end
        if Bags.GuildWindow.IsShown() then Bags.GuildWindow.Refresh() end
    elseif event == "GUILDBANKFRAME_OPENED" then
        Bags.GuildTakeover.OnOpened()
    elseif event == "GUILDBANKFRAME_CLOSED" then
        Bags.GuildTakeover.OnClosed()
    elseif event == "GUILDBANKLOG_UPDATE" then
        if Bags.GuildWindow.IsShown() then
            Bags.GuildWindow.OnLogUpdate()
        end
    elseif event == "ADDON_LOADED" then
        Bags.GuildTakeover.OnAddonLoaded(arg1)
    end
end)

local function Refresh()
    if not started then return end
    if IsEnabled() then StartUI() else StopUI() end
    if uiActive then
        if Bags.BagWindow.OnProfileChanged then Bags.BagWindow.OnProfileChanged() end
        if Bags.BankWindow.OnProfileChanged then Bags.BankWindow.OnProfileChanged() end
        if Bags.GuildWindow.OnProfileChanged then Bags.GuildWindow.OnProfileChanged() end
        if Bags.SearchWindow.OnProfileChanged then Bags.SearchWindow.OnProfileChanged() end
    end
end

-- luacheck: globals BINDING_HEADER_H3z0UIBAGS BINDING_NAME_H3z0UI_BAGS_TOGGLE
-- luacheck: globals BINDING_NAME_H3z0UI_BAGS_SEARCH_EVERYWHERE
-- luacheck: globals BINDING_NAME_H3z0UI_BAGS_TOGGLE_BANK BINDING_NAME_H3z0UI_BAGS_TOGGLE_GUILD
-- luacheck: globals H3z0UI_BagsToggle H3z0UI_BagsSearchEverywhere
-- luacheck: globals H3z0UI_BagsToggleBank H3z0UI_BagsToggleGuild
BINDING_HEADER_H3z0UIBAGS = ns.L["H3z0UI Bags"]
BINDING_NAME_H3z0UI_BAGS_TOGGLE = ns.L["Toggle Bags"]
BINDING_NAME_H3z0UI_BAGS_SEARCH_EVERYWHERE = ns.L["Search Everywhere"]
BINDING_NAME_H3z0UI_BAGS_TOGGLE_BANK = ns.L["Toggle Bank (cached anywhere)"]
BINDING_NAME_H3z0UI_BAGS_TOGGLE_GUILD = ns.L["Toggle Guild Bank (cached anywhere)"]

function H3z0UI_BagsToggle()
    if not Bags.IsActive() then return end
    Bags.BagWindow.Toggle()
end

function H3z0UI_BagsSearchEverywhere()
    if not Bags.IsActive() then return end
    Bags.SearchWindow.Toggle()
end

function H3z0UI_BagsToggleBank()
    if not Bags.IsActive() then return end
    if Bags.BankWindow.IsShown() then
        Bags.BankWindow.Hide()
    elseif Bags.BankTakeover and Bags.BankTakeover.IsLive and Bags.BankTakeover.IsLive() then
        Bags.BankWindow.ShowLive()
    else
        Bags.BankWindow.ShowCached()
    end
end

function H3z0UI_BagsToggleGuild()
    if not Bags.IsActive() then return end
    if Bags.GuildWindow.IsShown() then
        Bags.GuildWindow.Hide()
    elseif Bags.GuildTakeover and Bags.GuildTakeover.IsLive and Bags.GuildTakeover.IsLive() then
        Bags.GuildWindow.ShowLive()
    else
        Bags.GuildWindow.ShowCached()
    end
end

-- luacheck: globals SLASH_H3z0UIBAGS1
SLASH_H3z0UIBAGS1 = "/h3z0uibags"
SlashCmdList["H3z0UIBAGS"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if not Bags.IsActive() then
        print("|cff00ff00H3z0UI:|r the Bags module is disabled (Options → Modules).")
        return
    end
    if msg == "" then
        Bags.BagWindow.Toggle()
    elseif msg == "search" then
        Bags.SearchWindow.Toggle()
    elseif msg == "bank" then
        H3z0UI_BagsToggleBank()
    elseif msg == "guild" then
        H3z0UI_BagsToggleGuild()
    elseif msg == "clearnew" then
        if Bags.NewItems and Bags.NewItems.ClearAllNew then
            Bags.NewItems.ClearAllNew()
        end
    else
        print("|cff00ff00H3z0UI:|r /h3z0uibags — toggle the bag window; /h3z0uibags search — search everywhere; /h3z0uibags bank|guild — browse the (cached) bank / guild bank anywhere; /h3z0uibags clearnew — clear all new-item glows.")
    end
end

_G.H3z0UI_RefreshBags = Refresh

if ns.Registry then
    ns.Registry:Register("bags", {
        refresh = _G.H3z0UI_RefreshBags,
        priority = 50,
        group = "bags",
        importCategories = { "bags" },
    })
end

ns.WhenLoggedIn(function()
    started = true
    if IsEnabled() then StartUI() end
end)
