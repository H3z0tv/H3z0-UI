local _, ns = ...

local Settings = ns.Settings
local ProviderPanels = Settings and Settings.ProviderPanels
if not ProviderPanels or type(ProviderPanels.RegisterAfterLoad) ~= "function" then
    return
end

ProviderPanels:RegisterAfterLoad(function(ctx)
    local GUI = ctx.GUI
    local U = ctx.U
    local NotifyProviderFor = ctx.NotifyProviderFor

    local function MakeLayout(content)
        return ns.H3z0UI_SettingsLayoutShared.MakeLayout(content, U, nil, { searchSections = true })
    end

    local function row(parent, label, widget, desc)
        return ns.H3z0UI_Options.BuildSettingRow(parent, label, widget, desc)
    end

    local function PlaceNote(L, content, text, height)
        local holder = CreateFrame("Frame", nil, content)
        local lbl = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", holder, "TOPLEFT", 6, -4)
        lbl:SetPoint("RIGHT", holder, "RIGHT", -6, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(true)
        lbl:SetTextColor(0.6, 0.6, 0.6, 1)
        lbl:SetText(text)
        L.placeCustom(holder, height or 30)
    end

    local function ItemLabel(itemID)
        local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(itemID)
        if name and name ~= "" then
            return string.format("%s (%d)", name, itemID)
        end
        return ns.L["Item"] .. " " .. tostring(itemID)
    end

    local function BuildExclusionOptions(junk)
        local ids = {}
        for id in pairs((junk and junk.exclusions) or {}) do ids[#ids + 1] = id end
        table.sort(ids)
        local opts = {}
        for _, id in ipairs(ids) do
            opts[#opts + 1] = { value = id, text = ItemLabel(id) }
        end
        return opts
    end

    local function EnsureCurrencyBarLists(cfg)
        if type(cfg.currencyOrder) ~= "table" then cfg.currencyOrder = {} end
        if type(cfg.currencyEnabled) ~= "table" then cfg.currencyEnabled = {} end
        if type(cfg.currencies) == "table" then
            local legacy = {}
            for id in pairs(cfg.currencies) do legacy[#legacy + 1] = id end
            table.sort(legacy)
            local inOrder = {}
            for _, sid in ipairs(cfg.currencyOrder) do inOrder[tostring(sid)] = true end
            for _, id in ipairs(legacy) do
                local sid = tostring(id)
                if not inOrder[sid] then
                    cfg.currencyOrder[#cfg.currencyOrder + 1] = sid
                end
                cfg.currencyEnabled[sid] = true
            end
            cfg.currencies = nil
        end
    end

    local function BuildCharacterOptions()
        local Store = ns.Storage and ns.Storage.Store
        local opts = {}
        if Store and Store.ListCharacters then
            local current = Store.GetCurrentCharacterKey and Store.GetCurrentCharacterKey()
            for _, key in ipairs(Store.ListCharacters()) do
                if key ~= current then
                    opts[#opts + 1] = { value = key, text = key }
                end
            end
        end
        return opts
    end

    local function BuildGuildOptions()
        local Store = ns.Storage and ns.Storage.Store
        local opts = {}
        if Store and Store.ListGuilds then
            for _, key in ipairs(Store.ListGuilds()) do
                opts[#opts + 1] = { value = key, text = key }
            end
        end
        return opts
    end

    ctx.RegisterShared("bags", { build = function(content, _key, _width, options)
        local db = U.GetProfileDB()
        if not db or not db.bags or not ns.H3z0UI_Options then return 80 end
        local bags = db.bags
        if not bags.appearance then bags.appearance = {} end
        if not bags.behavior then bags.behavior = {} end
        local behavior = bags.behavior
        if not behavior.autoOpen then behavior.autoOpen = {} end
        if not behavior.junk then behavior.junk = {} end
        if not behavior.junk.exclusions then behavior.junk.exclusions = {} end
        if not behavior.newItemGlow then behavior.newItemGlow = {} end
        if not bags.currencyBar then bags.currencyBar = {} end

        local function Refresh() if _G.H3z0UI_RefreshBags then _G.H3z0UI_RefreshBags() end end

        local page = options and options.providerPage
        local L = MakeLayout(content)

        local function ShowBagsReloadPrompt()
            local Q = _G.H3z0UI
            local G2 = Q and Q.GUI
            if G2 and type(G2.ShowConfirmation) == "function" then
                G2:ShowConfirmation({
                    reload = true,
                    title      = ns.L["Reload UI?"],
                    message    = ns.L["This change takes full effect after a reload."],
                    acceptText = ns.L["Reload"],
                    cancelText = ns.L["Later"],
                    onAccept   = function() if Q and Q.SafeReload then Q:SafeReload() end end,
                })
            end
        end
        local function ModuleIsOn()
            local loader = ns.AddonLoader
            local addonOn = loader and loader.IsModuleAddonEnabled
                and loader.IsModuleAddonEnabled("H3z0UI_Bags")
            return (addonOn and bags.enabled) and true or false
        end
        local function ApplyModuleEnabled(val)
            local flipped = val and (bags.enabled == false)
            bags.enabled = val and true or false
            local result
            if ns.AddonLoader and ns.AddonLoader.SetModuleAddonEnabled then
                result = ns.AddonLoader.SetModuleAddonEnabled("H3z0UI_Bags", val and true or false)
            end
            if ns.H3z0UI_Modules then
                ns.H3z0UI_Modules:NotifyChanged("moduleAddon_H3z0UI_Bags")
            end
            Refresh()
            if (not val) or result == "reload" or (flipped and result == "loaded") then
                ShowBagsReloadPrompt()
            end
        end
        local moduleProxy = setmetatable({}, {
            __index = function(_, k)
                if k == "enabled" then return ModuleIsOn() end
            end,
            __newindex = function(_, k, v)
                if k == "enabled" and ((v and true or false) ~= ModuleIsOn()) then
                    ApplyModuleEnabled(v and true or false)
                end
            end,
        })

        if not page or page == "general" then
            L.headerAt(ns.L["General"])
            local g0 = L.sectionAt()
            local moduleW = GUI:CreateFormCheckbox(g0.frame, nil, "enabled", moduleProxy, nil,
                { description = ns.L["H3z0UI's bag takeover. Mirrors the Bags row on the Module Addons page: enabling loads the module (live when possible), disabling hands bags back to Blizzard — a UI reload is prompted for a clean handoff. Everything below applies live while the module is enabled."] })
            g0.AddRow(row(g0.frame, ns.L["Enable Bags Module"], moduleW))
            L.closeSection(g0)
        end

        if not page or page == "general" then
            L.headerAt(ns.L["Appearance"])
            local s1 = L.sectionAt()
            local iconSizeW = GUI:CreateFormSlider(s1.frame, nil, 24, 48, 1, "iconSize", bags.appearance, Refresh,
                { description = ns.L["Pixel size of each item button in the bag, bank, and guild bank windows."] })
            local columnsW = GUI:CreateFormSlider(s1.frame, nil, 6, 20, 1, "columns", bags.appearance, Refresh,
                { description = ns.L["How many item columns the bag window grid uses."] })
            s1.AddRow(row(s1.frame, ns.L["Icon Size"], iconSizeW), row(s1.frame, ns.L["Columns"], columnsW))

            local spacingW = GUI:CreateFormSlider(s1.frame, nil, 0, 8, 1, "spacing", bags.appearance, Refresh,
                { description = ns.L["Pixel gap between item buttons."] })
            local setMarkW = GUI:CreateFormCheckbox(s1.frame, nil, "equipmentSetMark", bags.appearance, Refresh,
                { description = ns.L["Show a small gear icon on items that belong to a saved equipment set (live bag and bank views)."] })
            s1.AddRow(row(s1.frame, ns.L["Item Spacing"], spacingW), row(s1.frame, ns.L["Equipment Set Icon"], setMarkW))

            local layoutModeW = GUI:CreateFormDropdown(s1.frame, nil, {
                { value = "flat", text = ns.L["Flat Grid"] },
                { value = "categories", text = ns.L["Categories"] },
                { value = "inventory", text = "Inventory (sidebar, pinned, categories)" },
            }, "layoutMode", bags.appearance, Refresh,
                { description = ns.L["Bag window layout. Flat Grid mirrors your real bag slots; Categories groups items under headers (Equipment, Consumables, Trade Goods, ... Junk last; new loot lands in Recent) and hides empty slots — the free count stays in the footer."] })
            local reagentW = GUI:CreateFormDropdown(s1.frame, nil, {
                { value = "separate", text = ns.L["Separate Section"] },
                { value = "merged", text = ns.L["Merged Into Grid"] },
                { value = "hidden", text = ns.L["Hidden"] },
            }, "reagentDisplay", bags.appearance, Refresh,
                { description = ns.L["Flat Grid only: show the reagent bag as its own labeled section below the regular bags, merge its slots into the grid, or hide it from the bag window entirely."] })
            s1.AddRow(row(s1.frame, ns.L["Layout"], layoutModeW), row(s1.frame, ns.L["Reagent Bag"], reagentW))

            local bankColsW = GUI:CreateFormSlider(s1.frame, nil, 6, 24, 1, "bankColumns", bags.appearance, Refresh,
                { description = ns.L["How many item columns the bank window grid uses."] })
            local guildColsW = GUI:CreateFormSlider(s1.frame, nil, 6, 24, 1, "guildColumns", bags.appearance, Refresh,
                { description = ns.L["How many item columns the guild bank grid uses."] })
            s1.AddRow(row(s1.frame, ns.L["Bank Columns"], bankColsW), row(s1.frame, ns.L["Guild Bank Columns"], guildColsW))

            local bankInvW = GUI:CreateFormCheckbox(s1.frame, nil, "bankInventory", bags.appearance, Refresh,
                { description = "Use the Inventory layout (categories on the left, items in sections) in the bank window too. It applies when the Layout above is Inventory; turn this off to keep the plain grid with tabs in the bank." })
            s1.AddRow(row(s1.frame, "Bank: Inventory Layout", bankInvW))

            local groupEmptyW = GUI:CreateFormCheckbox(s1.frame, nil, "groupEmptySlots", bags.appearance, Refresh,
                { description = ns.L["Flat Grid only: collapse each section's empty slots into a single cell showing the free count."] })
            local greyJunkW = GUI:CreateFormCheckbox(s1.frame, nil, "greyJunk", bags.appearance, Refresh,
                { description = ns.L["Desaturate junk (grey-quality) items."] })
            s1.AddRow(row(s1.frame, ns.L["Group Empty Slots"], groupEmptyW), row(s1.frame, ns.L["Grey Out Junk"], greyJunkW))

            local markUnusableW = GUI:CreateFormCheckbox(s1.frame, nil, "markUnusable", bags.appearance, Refresh,
                { description = ns.L["Red-tint items your character cannot use, including recipes already known or whose learning requirements are not met."] })
            local setBorderW = GUI:CreateFormCheckbox(s1.frame, nil, "equipmentSetBorder", bags.appearance, Refresh,
                { description = ns.L["Use a cyan border instead of the quality color on items that belong to a saved equipment set (live views)."] })
            s1.AddRow(row(s1.frame, ns.L["Mark Unusable Items"], markUnusableW), row(s1.frame, ns.L["Equipment Set Border"], setBorderW))

            local contextFadeW = GUI:CreateFormCheckbox(s1.frame, nil, "contextFading", bags.appearance, Refresh,
                { description = ns.L["Fade items that don't match the open context UI (socketing, scrapping, item upgrade)."] })
            local bagSlotsW = GUI:CreateFormCheckbox(s1.frame, nil, "showBagSlots", bags.appearance, Refresh,
                { description = ns.L["Show the bag-slot strip at the top of the bag window: your four bag slots plus the reagent bag slot. Drag a container onto a slot (or click with one on the cursor) to equip or swap it; click an equipped bag to pick it up."] })
            s1.AddRow(row(s1.frame, ns.L["Context Fading"], contextFadeW), row(s1.frame, ns.L["Show Bag Slots"], bagSlotsW))

            local hiddenBags = bags.appearance.hiddenBags
            local hide1W = GUI:CreateFormCheckbox(s1.frame, nil, 1, hiddenBags, Refresh,
                { description = ns.L["Hide bag 1's slots from the bag window grid. Display-only: search and sort still cover it."] })
            local hide2W = GUI:CreateFormCheckbox(s1.frame, nil, 2, hiddenBags, Refresh,
                { description = ns.L["Hide bag 2's slots from the bag window grid. Display-only: search and sort still cover it."] })
            s1.AddRow(row(s1.frame, ns.L["Hide Bag 1"], hide1W), row(s1.frame, ns.L["Hide Bag 2"], hide2W))
            local hide3W = GUI:CreateFormCheckbox(s1.frame, nil, 3, hiddenBags, Refresh,
                { description = ns.L["Hide bag 3's slots from the bag window grid. Display-only: search and sort still cover it."] })
            local hide4W = GUI:CreateFormCheckbox(s1.frame, nil, 4, hiddenBags, Refresh,
                { description = ns.L["Hide bag 4's slots from the bag window grid. Display-only: search and sort still cover it."] })
            s1.AddRow(row(s1.frame, ns.L["Hide Bag 3"], hide3W), row(s1.frame, ns.L["Hide Bag 4"], hide4W))

            local searchBoxW = GUI:CreateFormCheckbox(s1.frame, nil, "showSearchBox", bags.appearance, Refresh,
                { description = ns.L["Show the search box in the header of the bag, bank and guild bank windows."] })
            local reduceW = GUI:CreateFormCheckbox(s1.frame, nil, "reduceSpacing", bags.appearance, Refresh,
                { description = ns.L["Tighter window edges around the items for a smaller window."] })
            s1.AddRow(row(s1.frame, ns.L["Show Search Box"], searchBoxW), row(s1.frame, ns.L["Reduce Spacing"], reduceW))

            local blankW = GUI:CreateFormDropdown(s1.frame, nil, {
                { value = false, text = ns.L["At The Bottom"] },
                { value = true, text = ns.L["At The Top"] },
            }, "emptySpaceAtTop", bags.appearance, Refresh,
                { description = ns.L["Flat Grid only: where the part-filled row of items goes, at the bottom (after the last item) or at the top."] })
            local buttonsW = GUI:CreateFormDropdown(s1.frame, nil, {
                { value = "always", text = ns.L["Always"] },
                { value = "alt", text = ns.L["While Alt Held"] },
            }, "showButtons", bags.appearance, Refresh,
                { description = ns.L["Show the header buttons (sort, bank, guild bank, select, character) all the time, or only while you hold Alt for a cleaner window."] })
            s1.AddRow(row(s1.frame, ns.L["Blank Space"], blankW), row(s1.frame, ns.L["Show Buttons"], buttonsW))

            local boeCommonW = GUI:CreateFormCheckbox(s1.frame, nil, "hideBoeOnCommon", bags.appearance, Refresh,
                { description = ns.L["Don't show the BoE / BoU / binding corner text on poor and common quality items."] })
            local flashNewW = GUI:CreateFormCheckbox(s1.frame, nil, "newItemFlash", bags.appearance, Refresh,
                { description = ns.L["Play the flashing animation on new items. Off: new items keep a steady highlight."] })
            s1.AddRow(row(s1.frame, ns.L["Hide BoE On Common Items"], boeCommonW), row(s1.frame, ns.L["Flashing New Items"], flashNewW))
            L.closeSection(s1)
        end

        if not page or page == "corners" then
            L.headerAt(ns.L["Icon Corners"])
            local sc = L.sectionAt()
            local CORNER_OPTS = {
                { value = "none", text = ns.L["None"] },
                { value = "quantity", text = ns.L["Quantity"] },
                { value = "item_level", text = ns.L["Item Level"] },
                { value = "junk", text = ns.L["Junk Coin"] },
                { value = "equipment_set", text = ns.L["Equipment Set"] },
                { value = "binding", text = ns.L["Binding (BoE/BoA)"] },
                { value = "expansion", text = ns.L["Expansion"] },
                { value = "crafting_quality", text = ns.L["Crafting Quality (R1-R5)"] },
                { value = "upgrade_track", text = ns.L["Upgrade Track"] },
                { value = "boe", text = ns.L["Bind On Equip (BoE)"] },
                { value = "bou", text = ns.L["Bind On Use (BoU)"] },
                { value = "boa", text = ns.L["Bind On Account (BoA)"] },
                { value = "wue", text = ns.L["Warbound Until Equipped (WuE)"] },
                { value = "warbound", text = ns.L["Warbound (WB)"] },
                { value = "tradeable", text = ns.L["Tradeable Loot (TL)"] },
                { value = "upgrade", text = ns.L["Upgrade Arrow"] },
                { value = "transmog", text = ns.L["Uncollected Appearance"] },
                { value = "equipment_set_icon", text = ns.L["Equipment Set Icon"] },
                { value = "keystone_level", text = ns.L["Keystone Level"] },
                { value = "battle_pet_level", text = ns.L["Battle Pet Level"] },
            }
            local function cornerDD(key, desc)
                return GUI:CreateFormDropdown(sc.frame, nil, CORNER_OPTS, key, bags.appearance.corners, Refresh,
                    { description = desc })
            end
            sc.AddRow(row(sc.frame, ns.L["Top Left"], cornerDD("tl1",
                    ns.L["Primary widget for the top-left icon corner. The first widget that applies to an item renders."])),
                row(sc.frame, ns.L["Top Left Fallback"], cornerDD("tl2",
                    ns.L["Shown in the top-left corner when the primary widget doesn't apply to the item."])))
            sc.AddRow(row(sc.frame, ns.L["Top Right"], cornerDD("tr1",
                    ns.L["Primary widget for the top-right icon corner."])),
                row(sc.frame, ns.L["Top Right Fallback"], cornerDD("tr2",
                    ns.L["Shown in the top-right corner when the primary widget doesn't apply."])))
            sc.AddRow(row(sc.frame, ns.L["Bottom Left"], cornerDD("bl1",
                    ns.L["Primary widget for the bottom-left icon corner."])),
                row(sc.frame, ns.L["Bottom Left Fallback"], cornerDD("bl2",
                    ns.L["Shown in the bottom-left corner when the primary widget doesn't apply."])))
            sc.AddRow(row(sc.frame, ns.L["Bottom Right"], cornerDD("br1",
                    ns.L["Primary widget for the bottom-right icon corner."])),
                row(sc.frame, ns.L["Bottom Right Fallback"], cornerDD("br2",
                    ns.L["Shown in the bottom-right corner when the primary widget doesn't apply."])))

            local cornerFontW = GUI:CreateFormSlider(sc.frame, nil, 8, 16, 1, "cornerFontSize", bags.appearance, Refresh,
                { description = ns.L["Font size of corner text widgets (quantity, item level, binding, expansion)."] })
            local cornerIconW = GUI:CreateFormSlider(sc.frame, nil, 8, 24, 1, "cornerIconSize", bags.appearance, Refresh,
                { description = ns.L["Size of corner icon widgets (quality/rank badge, junk, equipment set)."] })
            local qualityTextW = GUI:CreateFormCheckbox(sc.frame, nil, "qualityColorText", bags.appearance, Refresh,
                { description = ns.L["Color corner text (item level, binding) by the item's quality instead of white."] })
            sc.AddRow(row(sc.frame, ns.L["Corner Font Size"], cornerFontW), row(sc.frame, ns.L["Corner Icon Size"], cornerIconW))
            sc.AddRow(row(sc.frame, ns.L["Quality-Colored Text"], qualityTextW))
            L.closeSection(sc)
        end

        local sortOptions = {
            { value = "quality", text = ns.L["Quality"] },
            { value = "type", text = ns.L["Type"] },
            { value = "name", text = ns.L["Name"] },
            { value = "ilvl", text = ns.L["Item Level"] },
            { value = "expansion", text = ns.L["Expansion"] },
        }
        local tooltipCountOptions = {
            { value = "on", text = ns.L["Always On"] },
            { value = "off", text = ns.L["Off"] },
            { value = "modifier", text = ns.L["While Shift Held"] },
        }

        if not page or page == "behavior" then
            L.headerAt(ns.L["Behavior"])
            local s2 = L.sectionAt()
            local sortKeyW = GUI:CreateFormDropdown(s2.frame, nil, sortOptions, "sortKey", behavior, Refresh,
                { description = ns.L["Primary ordering the Sort button uses. Quality sorts best-first; the other keys fall back to quality within equal groups. Right-clicking a Sort button changes this too."] })
            local sortRevW = GUI:CreateFormCheckbox(s2.frame, nil, "sortReverse", behavior, Refresh,
                { description = ns.L["Flip the chosen sort order wholesale (worst-first quality, Z-A names, lowest item level first, ...)."] })
            s2.AddRow(row(s2.frame, ns.L["Sort Items By"], sortKeyW), row(s2.frame, ns.L["Reverse Sort Order"], sortRevW))

            local tooltipCountsW = GUI:CreateFormDropdown(s2.frame, nil, tooltipCountOptions, "tooltipCounts", behavior, nil,
                { description = ns.L["Show how many of an item you own across characters, bank, mail, and more on item tooltips. 'While Shift Held' shows the counts only while Shift is down."] })
            local autoReagentsW = GUI:CreateFormCheckbox(s2.frame, nil, "autoDepositReagents", behavior, nil,
                { description = ns.L["Deposit all crafting reagents from your bags into the warband bank every time you open the bank."] })
            s2.AddRow(row(s2.frame, ns.L["Tooltip Item Counts"], tooltipCountsW), row(s2.frame, ns.L["Auto-Deposit Reagents"], autoReagentsW))

            local glowEnableW = GUI:CreateFormCheckbox(s2.frame, nil, "enabled", behavior.newItemGlow, Refresh,
                { description = ns.L["Highlight recently looted items in the bag window until you mouse over them or the timeout passes."] })
            local glowTimeoutW = GUI:CreateFormSlider(s2.frame, nil, 5, 120, 5, "timeoutMinutes", behavior.newItemGlow, nil,
                { description = ns.L["Minutes before a new-item highlight expires on its own."] })
            s2.AddRow(row(s2.frame, ns.L["New Item Highlight"], glowEnableW), row(s2.frame, ns.L["Highlight Timeout (min)"], glowTimeoutW))

            local lockW = GUI:CreateFormCheckbox(s2.frame, nil, "lockWindows", behavior, Refresh,
                { description = ns.L["Lock the bag, bank and guild bank windows in place so they can't be dragged by accident."] })
            local dupW = GUI:CreateFormCheckbox(s2.frame, nil, "flashDuplicates", behavior, Refresh,
                { description = ns.L["Alt+click an item to make every copy of it in your bags flash for a few seconds."] })
            s2.AddRow(row(s2.frame, ns.L["Lock Windows"], lockW), row(s2.frame, ns.L["Flash Duplicates (Alt+Click)"], dupW))

            local sortBtnW = GUI:CreateFormCheckbox(s2.frame, nil, "showSortButton", behavior, Refresh,
                { description = ns.L["Show the sort button in the bag and bank window headers."] })
            local sortOpenW = GUI:CreateFormCheckbox(s2.frame, nil, "sortOnOpen", behavior, Refresh,
                { description = ns.L["Sort your bags every time you open the bag window."] })
            s2.AddRow(row(s2.frame, ns.L["Show Sort Button"], sortBtnW), row(s2.frame, ns.L["Sort On Open"], sortOpenW))

            local arrangeW = GUI:CreateFormDropdown(s2.frame, nil, {
                { value = false, text = ns.L["From The Top"] },
                { value = true, text = ns.L["From The Bottom"] },
            }, "fillFromBottom", behavior, Refresh,
                { description = ns.L["Where sorting puts your items: packed from the first slot, or packed towards the last slot so the empty space is at the top."] })
            local upgradeW = GUI:CreateFormDropdown(s2.frame, nil, {
                { value = "auto", text = ns.L["Pawn If Installed, Else Item Level"] },
                { value = "ilvl", text = ns.L["Item Level"] },
                { value = "pawn", text = ns.L["Pawn Only"] },
            }, "upgradeDetection", behavior, Refresh,
                { description = ns.L["How the Upgrade Arrow corner and the #upgrade search decide an item is an upgrade: Pawn's verdict, or a higher item level than what you have equipped in that slot."] })
            s2.AddRow(row(s2.frame, ns.L["Arrange Items"], arrangeW), row(s2.frame, ns.L["Upgrade Detection"], upgradeW))

            local ignoreW = GUI:CreateFormSlider(s2.frame, nil, 0, 40, 1, "ignoreSlots", behavior, Refresh,
                { description = ns.L["How many bag slots the Sort button never touches (items there stay where they are)."] })
            local ignoreAtW = GUI:CreateFormDropdown(s2.frame, nil, {
                { value = "end", text = ns.L["Last Slots"] },
                { value = "start", text = ns.L["First Slots"] },
            }, "ignoreSlotsAt", behavior, Refresh,
                { description = ns.L["Whether the ignored slots are the last or the first slots of your bags."] })
            s2.AddRow(row(s2.frame, ns.L["Ignored Slots"], ignoreW), row(s2.frame, ns.L["Ignored Slots Are"], ignoreAtW))
            L.closeSection(s2)
        end

        if not page or page == "behavior" then
            L.headerAt(ns.L["Auto-Open"])
            local s3 = L.sectionAt()
            local autoOpenRows = {
                { key = "merchant", label = ns.L["Merchant"], desc = ns.L["Open the bag window when you talk to a merchant."] },
                { key = "mail", label = ns.L["Mailbox"], desc = ns.L["Open the bag window at a mailbox."] },
                { key = "auctionHouse", label = ns.L["Auction House"], desc = ns.L["Open the bag window at the auction house."] },
                { key = "trade", label = ns.L["Trade"], desc = ns.L["Open the bag window when a trade starts."] },
                { key = "scrappingMachine", label = ns.L["Scrapping Machine"], desc = ns.L["Open the bag window at a scrapping machine."] },
                { key = "itemUpgrade", label = ns.L["Item Upgrade"], desc = ns.L["Open the bag window at the item upgrade vendor."] },
                { key = "socket", label = ns.L["Socketing"], desc = ns.L["Open the bag window when socketing an item."] },
                { key = "bank", label = ns.L["Bank"], desc = ns.L["Open the bag window alongside the bank window."] },
                { key = "guildBank", label = ns.L["Guild Bank"], desc = ns.L["Open the bag window alongside the guild bank window."] },
                { key = "catalyst", label = ns.L["Catalyst"], desc = ns.L["Open the bag window at the Catalyst (and other item interaction windows)."] },
                { key = "craftingWindow", label = ns.L["Crafting Window"], desc = ns.L["Open the bag window when you open a profession."] },
                { key = "characterPanel", label = ns.L["Character Panel"], desc = ns.L["Open the bag window with your Character panel."] },
            }
            local pendingCell = nil
            for _, def in ipairs(autoOpenRows) do
                local w = GUI:CreateFormCheckbox(s3.frame, nil, def.key, behavior.autoOpen, nil,
                    { description = def.desc })
                local cell = row(s3.frame, def.label, w)
                if pendingCell then
                    s3.AddRow(pendingCell, cell)
                    pendingCell = nil
                else
                    pendingCell = cell
                end
            end
            if pendingCell then
                s3.AddRow(pendingCell)
            end
            L.closeSection(s3)
        end

        if not page or page == "junk" then
            L.headerAt(ns.L["Junk"])
            local s4 = L.sectionAt()
            local junkDimW = GUI:CreateFormCheckbox(s4.frame, nil, "dim", behavior.junk, Refresh,
                { description = ns.L["Desaturate junk (gray) items and overlay a coin icon in the bag window."] })
            local sellButtonW = GUI:CreateFormCheckbox(s4.frame, nil, "sellButton", behavior.junk, Refresh,
                { description = ns.L["Show a Sell Junk button in the bag window while a merchant is open."] })
            s4.AddRow(row(s4.frame, ns.L["Dim Junk Items"], junkDimW), row(s4.frame, ns.L["Sell Junk Button"], sellButtonW))

            local exclusionWrapper = { selected = "" }
            local exclusionDropdown
            exclusionDropdown = GUI:CreateFormDropdown(s4.frame, nil, BuildExclusionOptions(behavior.junk), "selected", exclusionWrapper, function(value)
                if not value or value == "" then return end
                behavior.junk.exclusions[value] = nil
                print("|cff60A5FAH3z0UI:|r " .. string.format(ns.L["Removed junk exclusion: %s"], ItemLabel(value)))
                exclusionWrapper.selected = ""
                if exclusionDropdown.SetOptions then exclusionDropdown.SetOptions(BuildExclusionOptions(behavior.junk)) end
                if exclusionDropdown.SetValue then exclusionDropdown.SetValue("", true) end
                Refresh()
            end, { description = ns.L["Items excluded from junk dimming, the Sell Junk button, and vendor auto-sell. Selecting one removes the exclusion."] })
            s4.AddRow(row(s4.frame, ns.L["Remove Exclusion"], exclusionDropdown))

            local exclAddInput = GUI:CreateFormEditBox(s4.frame, nil, nil, nil, nil, {
                commitOnEnter = false, commitOnFocusLost = false,
                onEscapePressed = function(self) self:ClearFocus() end,
            }, { description = ns.L["Numeric item ID to exclude from junk handling (find IDs on database sites or via item tooltips). Click Add to validate and append it."] })
            local exclAddControls = CreateFrame("Frame", nil, s4.frame)
            exclAddControls:SetSize(260, 22)
            exclAddInput:SetParent(exclAddControls)
            local exclAddCell = row(s4.frame, ns.L["Add Exclusion by ID"], exclAddControls)
            local exclAddBtn = GUI:CreateButton(exclAddControls, ns.L["Add"], 70, 22, function()
                local text = exclAddInput.editBox and exclAddInput.editBox:GetText()
                local id = tonumber(text)
                if not id or id <= 0 or id % 1 ~= 0 then
                    print("|cffff0000H3z0UI:|r " .. ns.L["Enter a numeric item ID."])
                    return
                end
                local valid = C_Item and C_Item.GetItemInfoInstant
                    and C_Item.GetItemInfoInstant(id)
                if not valid then
                    print("|cffff0000H3z0UI:|r " .. string.format(ns.L["Unknown item ID: %s"], id))
                    return
                end
                behavior.junk.exclusions[id] = true
                if exclAddInput.editBox then exclAddInput.editBox:SetText("") end
                print("|cff60A5FAH3z0UI:|r " .. string.format(ns.L["Added junk exclusion: %s"], ItemLabel(id)))
                if exclusionDropdown.SetOptions then exclusionDropdown.SetOptions(BuildExclusionOptions(behavior.junk)) end
                Refresh()
            end)
            exclAddBtn:SetPoint("RIGHT", exclAddControls, "RIGHT", 0, 0)
            exclAddInput:ClearAllPoints()
            exclAddInput:SetPoint("LEFT", exclAddControls, "LEFT", 0, 0)
            exclAddInput:SetPoint("RIGHT", exclAddBtn, "LEFT", -8, 0)
            s4.AddRow(exclAddCell)

            L.closeSection(s4)
            PlaceNote(L, content,
                ns.L["Exclusions protect specific items from junk dimming, the Sell Junk button, and vendor auto-sell. Add by item ID above; remove via the dropdown."],
                26)
        end

        if not page or page == "currency" then
            L.headerAt(ns.L["Currency Bar"])
            local s5 = L.sectionAt()
            local cbar = bags.currencyBar
            local cbarEnableW = GUI:CreateFormCheckbox(s5.frame, nil, "enabled", cbar, Refresh,
                { description = ns.L["Show a footer row on the bag window with the currencies enabled below."] })
            s5.AddRow(row(s5.frame, ns.L["Enable Currency Bar"], cbarEnableW))
            L.closeSection(s5)

            if ns.H3z0UI_BuildCurrencyOrderSection then
                EnsureCurrencyBarLists(cbar)
                ns.H3z0UI_BuildCurrencyOrderSection(L, content, {
                    dtGlobal = cbar,
                    header = ns.L["Currencies"],
                    hint = ns.L["Enabled currencies show on the bag window's bar, in this order."],
                    toggleDescription = ns.L["Show this currency on the bag window's currency bar. Use the arrows to reorder."],
                    note = ns.L["Lists your backpack-tracked currencies — the same pool as the Currencies datatext."],
                    refresh = Refresh,
                    notify = function(region)
                        if NotifyProviderFor then NotifyProviderFor(region, { structural = true }) end
                    end,
                })
            else
                local noteRow = CreateFrame("Frame", nil, content)
                local note = noteRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                note:SetPoint("LEFT", noteRow, "LEFT", 0, 0)
                note:SetTextColor(1, 0.6, 0.1, 1)
                note:SetText(ns.L["Enable the Datatexts module addon (Modules page) to configure the currency list."])
                L.placeCustom(noteRow, 18)
            end
        end

        if not page or page == "categories" then
            local Cat = ns.Bags and ns.Bags.Categories
            local cdb = Cat and Cat.DB() or {}
            L.headerAt(ns.L["Categories"])
            local sk = L.sectionAt()
            local groupIdW = GUI:CreateFormCheckbox(sk.frame, nil, "groupIdentical", cdb, Refresh,
                { description = ns.L["Identical items share one button that shows the total count (gear only when it is exactly the same item)."] })
            local groupEmptyW = GUI:CreateFormCheckbox(sk.frame, nil, "groupEmpty", cdb, Refresh,
                { description = ns.L["Show all empty slots as one button with the free count (one for your bags, one for the reagent bag). Off: every empty slot is shown."] })
            sk.AddRow(row(sk.frame, ns.L["Group Identical Items"], groupIdW), row(sk.frame, ns.L["Group Empty Slots"], groupEmptyW))
            local spacingW = GUI:CreateFormSlider(sk.frame, nil, 0, 30, 1, "spacing", cdb, Refresh,
                { description = ns.L["Gap between the category blocks."] })
            local catSortOpts = { { value = "", text = ns.L["Same As Bags"] } }
            for _, o in ipairs(sortOptions) do catSortOpts[#catSortOpts + 1] = o end
            local catSortW = GUI:CreateFormDropdown(sk.frame, nil, catSortOpts, "categorySortKey", behavior, Refresh,
                { description = ns.L["How the items inside each category are ordered. Same As Bags uses the Sort Items By setting."] })
            sk.AddRow(row(sk.frame, ns.L["Category Spacing"], spacingW), row(sk.frame, ns.L["Sort Inside Categories"], catSortW))
            L.closeSection(sk)
            PlaceNote(L, content,
                ns.L["These apply to the Inventory and Categories layouts (General page > Layout). Hearthstone and Keystone always stay on top. In the bag window, drop an item on a category (title or + slot) to put it there for good, and right-click a category to move or hide it."],
                40)

            -- the category list: shown / hidden, order, your own categories
            if Cat then
                L.headerAt(ns.L["Category Order"])
                local list = Cat.List()
                local ROW = 26
                local box = CreateFrame("Frame", nil, content)
                local rowsFrames = {}
                local function SmallButton(parent, text, w, onClick)
                    local b = GUI:CreateButton(parent, text, w, 18, onClick)
                    return b
                end
                local function Rebuild()
                    list = Cat.List()
                    for _, rf in ipairs(rowsFrames) do rf:Hide() end
                    local y = -4
                    for i, e in ipairs(list) do
                        local r = rowsFrames[i]
                        if not r then
                            r = CreateFrame("Frame", nil, box)
                            r:SetHeight(ROW - 4)
                            r.cb = GUI:CreateFormCheckbox(r, nil, nil, nil, function(val)
                                Cat.SetHidden(r.key, not val)
                                Refresh()
                            end, { description = ns.L["Show this category in the bag window. A hidden category's items are not shown."] })
                            r.cb:SetPoint("LEFT", 4, 0)
                            r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                            r.name:SetPoint("LEFT", r, "LEFT", 40, 0)
                            r.name:SetJustifyH("LEFT")
                            r.up = SmallButton(r, "^", 22, function() Cat.Move(r.key, -1); Rebuild(); Refresh() end)
                            r.up:SetPoint("RIGHT", r, "RIGHT", -28, 0)
                            r.down = SmallButton(r, "v", 22, function() Cat.Move(r.key, 1); Rebuild(); Refresh() end)
                            r.down:SetPoint("RIGHT", r, "RIGHT", -2, 0)
                            r.del = SmallButton(r, ns.L["Delete"], 60, function()
                                Cat.DeleteCustom(r.key)
                                Refresh()
                                NotifyProviderFor(r.del, { structural = true })
                            end)
                            r.del:SetPoint("RIGHT", r.up, "LEFT", -6, 0)
                            r.edit = SmallButton(r, ns.L["Search"], 60, function()
                                local c = Cat.DB()
                                local def = c and c.custom[r.key]
                                if not def then return end
                                H3z0UI_ShowPopup({
                                    text = ns.L["Search text for"] .. " " .. (def.name or "") .. ":",
                                    button1 = ACCEPT, button2 = CANCEL,
                                    hasEditBox = true, maxLetters = 200, editText = def.search or "",
                                    OnAccept = function(_, _, value)
                                        def.search = value or ""
                                        Rebuild()
                                        Refresh()
                                    end,
                                })
                            end)
                            r.edit:SetPoint("RIGHT", r.del, "LEFT", -6, 0)
                            r.name:SetPoint("RIGHT", r.edit, "LEFT", -6, 0)
                            rowsFrames[i] = r
                        end
                        r.key = e.key
                        r:ClearAllPoints()
                        r:SetPoint("TOPLEFT", box, "TOPLEFT", 0, y)
                        r:SetPoint("RIGHT", box, "RIGHT", 0, 0)
                        local label = e.name
                        if e.custom then
                            local c = Cat.DB()
                            local q = c and c.custom[e.key] and c.custom[e.key].search or ""
                            label = label .. "  |cff888888(" .. (q ~= "" and q or ns.L["no search"]) .. ")|r"
                        end
                        r.name:SetText(label)
                        r.name:SetTextColor(e.hidden and 0.5 or 0.9, e.hidden and 0.5 or 0.9, e.hidden and 0.5 or 0.9)
                        r.cb:SetValue(not e.hidden, true)
                        r.up:SetAlpha(i > 1 and 1 or 0.3)
                        r.down:SetAlpha(i < #list and 1 or 0.3)
                        r.del:SetShown(e.custom)
                        r.edit:SetShown(e.custom)
                        r:Show()
                        y = y - ROW
                    end
                end
                L.placeCustom(box, #list * ROW + 8)
                Rebuild()

                -- new category: name + search text
                L.headerAt(ns.L["New Category"])
                local sn = L.sectionAt()
                local newCat = { name = "", search = "" }
                local nameW = GUI:CreateFormEditBox(sn.frame, nil, "name", newCat, nil, {
                    commitOnEnter = true, commitOnFocusLost = true,
                }, { description = ns.L["Name of the new category."] })
                local searchW = GUI:CreateFormEditBox(sn.frame, nil, "search", newCat, nil, {
                    commitOnEnter = true, commitOnFocusLost = true,
                }, { description = ns.L["Which items go in it, with the bag search words: for example  #potion|#flask   epic&#armor   ilvl>600   #boe   !#junk   or part of an item name."] })
                sn.AddRow(row(sn.frame, ns.L["Name"], nameW), row(sn.frame, ns.L["Search Text"], searchW))
                local addHolder = CreateFrame("Frame", nil, sn.frame)
                addHolder:SetSize(260, 22)
                local addBtn = GUI:CreateButton(addHolder, ns.L["Add Category"], 120, 22, function()
                    local nameText = nameW.editBox and nameW.editBox:GetText() or newCat.name
                    local searchText = searchW.editBox and searchW.editBox:GetText() or newCat.search
                    if not nameText or nameText == "" then
                        print("|cffff0000H3z0UI:|r " .. ns.L["Enter a name for the category."])
                        return
                    end
                    Cat.AddCustom(nameText, searchText or "")
                    newCat.name, newCat.search = "", ""
                    Refresh()
                    NotifyProviderFor(addHolder, { structural = true })
                end)
                addBtn:SetPoint("LEFT", addHolder, "LEFT", 0, 0)
                local resetBtn = GUI:CreateButton(addHolder, ns.L["Reset Order"], 120, 22, function()
                    Cat.Reset()
                    Rebuild()
                    Refresh()
                    NotifyProviderFor(addHolder, { structural = true })
                end)
                resetBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
                sn.AddRow(row(sn.frame, "", addHolder))
                L.closeSection(sn)
                PlaceNote(L, content,
                    ns.L["Search words: #weapon #armor #cloth #leather #mail #plate #consumable #potion #flask #food #gem #reagent #tradegoods #recipe #quest #toy #mount #battlepet #keystone #housing #boe #bou #boa #warbound #junk #upgrade #transmog #set, qualities (epic, rare, ...), expansions (tww, midnight, ...), slots (ring, trinket, ...), item level (ilvl>600, 600-650). Combine with & (and), | (or), ! (not)."],
                    70)

                -- items you put in a category yourself
                local c = Cat.DB()
                local assigned = {}
                for itemID, key in pairs(c and c.assign or {}) do
                    assigned[#assigned + 1] = { value = itemID, text = ItemLabel(itemID) .. " -> " .. Cat.Name(key) }
                end
                table.sort(assigned, function(a, b) return a.text < b.text end)
                if #assigned > 0 then
                    L.headerAt(ns.L["Items Placed By Hand"])
                    local sa = L.sectionAt()
                    local pick = { selected = "" }
                    local opts = { { value = "", text = ns.L["Select to remove..."] } }
                    for _, o in ipairs(assigned) do opts[#opts + 1] = o end
                    local dd
                    dd = GUI:CreateFormDropdown(sa.frame, nil, opts, "selected", pick, function(value)
                        if not value or value == "" then return end
                        c.assign[value] = nil
                        Refresh()
                        NotifyProviderFor(dd, { structural = true })
                    end, { description = ns.L["Items you dropped on a category title. Pick one to send it back to its normal category."] })
                    sa.AddRow(row(sa.frame, ns.L["Remove"], dd))
                    L.closeSection(sa)
                end
            end
        end

        if not page or page == "cache" then
            L.headerAt(ns.L["Cached Data"])
            local s6 = L.sectionAt()
            local charWrapper = { selected = "" }
            local charDropdown
            charDropdown = GUI:CreateFormDropdown(s6.frame, nil, BuildCharacterOptions(), "selected", charWrapper, function(value)
                if not value or value == "" then return end
                GUI:ShowConfirmation({
                    title = ns.L["Delete Cached Character?"],
                    message = string.format(ns.L["Delete the cached inventory data for '%1$s'?"], value),
                    warningText = ns.L["This cannot be undone. The cache rebuilds the next time that character logs in."],
                    acceptText = ns.L["Delete"], cancelText = ns.L["Cancel"], isDestructive = true,
                    onAccept = function()
                        local Store = ns.Storage and ns.Storage.Store
                        if Store and Store.DeleteCharacter then
                            Store.DeleteCharacter(value)
                            print("|cff60A5FAH3z0UI:|r " .. string.format(ns.L["Deleted cached character: %s"], value))
                        end
                        charWrapper.selected = ""
                        if charDropdown.SetOptions then charDropdown.SetOptions(BuildCharacterOptions()) end
                        if charDropdown.SetValue then charDropdown.SetValue("", true) end
                    end,
                    onCancel = function()
                        charWrapper.selected = ""
                        if charDropdown.SetValue then charDropdown.SetValue("", true) end
                    end,
                })
            end, { description = ns.L["Delete a character's cached bags, bank, equipment, mail, and currency data. The current character can't be deleted."] })

            local guildWrapper = { selected = "" }
            local guildDropdown
            guildDropdown = GUI:CreateFormDropdown(s6.frame, nil, BuildGuildOptions(), "selected", guildWrapper, function(value)
                if not value or value == "" then return end
                GUI:ShowConfirmation({
                    title = ns.L["Delete Cached Guild?"],
                    message = string.format(ns.L["Delete the cached guild bank data for '%1$s'?"], value),
                    warningText = ns.L["This cannot be undone. The cache rebuilds on the next guild bank visit."],
                    acceptText = ns.L["Delete"], cancelText = ns.L["Cancel"], isDestructive = true,
                    onAccept = function()
                        local Store = ns.Storage and ns.Storage.Store
                        if Store and Store.DeleteGuild then
                            Store.DeleteGuild(value)
                            print("|cff60A5FAH3z0UI:|r " .. string.format(ns.L["Deleted cached guild: %s"], value))
                        end
                        guildWrapper.selected = ""
                        if guildDropdown.SetOptions then guildDropdown.SetOptions(BuildGuildOptions()) end
                        if guildDropdown.SetValue then guildDropdown.SetValue("", true) end
                    end,
                    onCancel = function()
                        guildWrapper.selected = ""
                        if guildDropdown.SetValue then guildDropdown.SetValue("", true) end
                    end,
                })
            end, { description = ns.L["Delete a guild's cached guild bank data."] })
            s6.AddRow(row(s6.frame, ns.L["Delete Character Cache"], charDropdown), row(s6.frame, ns.L["Delete Guild Cache"], guildDropdown))
            L.closeSection(s6)
        end

        L.relayoutSections()
        return content:GetHeight()
    end })
end)
