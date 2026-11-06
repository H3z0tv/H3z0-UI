local ADDON_NAME, ns = ...

local Registry = {}
ns.Registry = Registry

Registry._modules = {}
Registry._moduleOrder = nil

function Registry:Register(name, def)
    if not name or type(def) ~= "table" then return end
    def.name = name
    def.priority = def.priority or 50
    self._modules[name] = def
    self._moduleOrder = nil
end

function Registry:_RebuildOrder()
    local order = {}
    for name in pairs(self._modules) do
        order[#order + 1] = name
    end
    table.sort(order, function(a, b)
        local pa = self._modules[a].priority
        local pb = self._modules[b].priority
        if pa ~= pb then return pa < pb end
        return a < b
    end)
    self._moduleOrder = order
end

local function SafeCallRefresh(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        print("|cFFFF6666H3z0UI:|r refresh error [" .. name .. "]: " .. tostring(err))
    end
end

-- A refresh of a whole group (every skin, say) used to run all its modules in one go on every
-- single click in the settings, which froze the game for a moment. Now several requests that come
-- close together become one, and the modules are refreshed a few at a time, spread over frames.
local pendingGroups = {}
local groupRunner

local function RunGroupQueue(self)
    local budget = 4   -- milliseconds per frame
    local start = debugprofilestop and debugprofilestop() or 0
    local any = false
    for group, q in pairs(pendingGroups) do
        any = true
        while q.i <= #q.names do
            local name = q.names[q.i]
            q.i = q.i + 1
            local m = Registry._modules[name]
            if m and m.refresh then SafeCallRefresh(name, m.refresh) end
            if debugprofilestop and debugprofilestop() - start > budget then return end
        end
        pendingGroups[group] = nil
    end
    if not any or next(pendingGroups) == nil then self:SetScript("OnUpdate", nil) end
end

function Registry:RefreshAll(groupFilter)
    if not self._moduleOrder then self:_RebuildOrder() end
    if groupFilter and CreateFrame and C_Timer then
        local names = {}
        for _, name in ipairs(self._moduleOrder) do
            local m = self._modules[name]
            if m.refresh and m.group == groupFilter then names[#names + 1] = name end
        end
        pendingGroups[groupFilter] = { names = names, i = 1 }   -- a newer request starts the list again
        if not groupRunner then groupRunner = CreateFrame("Frame") end
        groupRunner:SetScript("OnUpdate", RunGroupQueue)
        return
    end
    for _, name in ipairs(self._moduleOrder) do
        local m = self._modules[name]
        if m.refresh and (not groupFilter or m.group == groupFilter) then
            SafeCallRefresh(name, m.refresh)
        end
    end
end

function Registry:RefreshByCategories(categoryIDs)
    if not categoryIDs or #categoryIDs == 0 then return end

    local categorySet = {}
    for _, id in ipairs(categoryIDs) do
        categorySet[id] = true
    end

    if not self._moduleOrder then self:_RebuildOrder() end
    for _, name in ipairs(self._moduleOrder) do
        local m = self._modules[name]
        if m.refresh and m.importCategories then
            for _, catID in ipairs(m.importCategories) do
                if categorySet[catID] then
                    SafeCallRefresh(name, m.refresh)
                    break
                end
            end
        end
    end
end
