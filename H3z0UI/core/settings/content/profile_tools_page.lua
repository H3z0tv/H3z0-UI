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
local MAX_BACKUPS = 8

---------------------------------------------------------------------------
-- profile tools (no UI): rename, duplicate, backups, per-character profile
---------------------------------------------------------------------------
local Tools = {}
ns.H3z0UI_ProfileTools = Tools

local function Core()
    return ns.Addon or (ns.Helpers and ns.Helpers.GetCore and ns.Helpers.GetCore())
end

local function DB()
    local core = Core()
    return core and core.db, core
end

local function Copy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, x in pairs(v) do out[Copy(k, seen)] = Copy(x, seen) end
    return out
end

local function ValidName(name)
    if type(name) ~= "string" then return false end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name ~= "" and #name <= 40, name
end

function Tools.ProfileNames()
    local db = DB()
    if not db then return {} end
    local list = {}
    for _, n in ipairs(db:GetProfiles()) do list[#list + 1] = n end
    table.sort(list)
    return list
end

function Tools.Duplicate(source, newName)
    local db = DB()
    local ok, name = ValidName(newName)
    if not db or not ok then return false, "Type a name of 1 to 40 characters." end
    local sv = db.sv
    if not (sv and sv.profiles and sv.profiles[source]) then return false, "That profile does not exist." end
    if sv.profiles[name] then return false, "A profile with that name already exists." end
    sv.profiles[name] = Copy(sv.profiles[source])
    return true, name
end

function Tools.Rename(old, newName)
    local db = DB()
    local ok, name = ValidName(newName)
    if not db or not ok then return false, "Type a name of 1 to 40 characters." end
    local sv = db.sv
    if not (sv and sv.profiles and sv.profiles[old]) then return false, "That profile does not exist." end
    if sv.profiles[name] then return false, "A profile with that name already exists." end
    if old == name then return false, "That is already its name." end
    local wasCurrent = db:GetCurrentProfile() == old
    sv.profiles[name] = sv.profiles[old]
    for key, value in pairs(sv.profileKeys or {}) do
        if value == old then sv.profileKeys[key] = name end
    end
    -- spec profiles (dual spec) keep profile names per character
    for _, chardata in pairs(sv.char or {}) do
        if type(chardata) == "table" then
            for k, v in pairs(chardata) do
                if type(k) == "number" and v == old then chardata[k] = name end
            end
        end
    end
    if wasCurrent then
        db:SetProfile(name)
        if db:GetCurrentProfile() == old then
            -- the game paused the switch (for example inside a Mythic+ dungeon): undo everything
            for key, value in pairs(sv.profileKeys or {}) do
                if value == name then sv.profileKeys[key] = old end
            end
            for _, chardata in pairs(sv.char or {}) do
                if type(chardata) == "table" then
                    for k, v in pairs(chardata) do
                        if type(k) == "number" and v == name then chardata[k] = old end
                    end
                end
            end
            sv.profiles[name] = nil
            return false, "The active profile cannot be renamed right now. Try again outside this content."
        end
    end
    sv.profiles[old] = nil
    return true, name
end

-- backups live in the account-wide part of the saved data
local function Backups(create)
    local db = DB()
    if not db or not db.global then return nil end
    if not db.global.h3zProfileBackups and create then db.global.h3zProfileBackups = {} end
    return db.global.h3zProfileBackups
end

function Tools.ListBackups()
    return Backups(false) or {}
end

function Tools.Backup(label)
    local db = DB()
    local list = Backups(true)
    if not (db and list) then return false, "Settings are not ready yet." end
    local profileName = db:GetCurrentProfile()
    local ok, text = ValidName(label or "")
    list[#list + 1] = {
        label = ok and text or "Backup",
        profile = profileName,
        time = (time and time()) or 0,
        data = Copy(db.profile),
    }
    while #list > MAX_BACKUPS do table.remove(list, 1) end
    return true, profileName
end

function Tools.Restore(index)
    local db = DB()
    local list = Backups(false)
    local b = list and list[index]
    if not (db and b) then return false, "That backup does not exist." end
    if InCombatLockdown() then return false, "Not in combat." end
    local target = db.profile
    for k in pairs(target) do target[k] = nil end
    for k, v in pairs(Copy(b.data)) do target[k] = v end
    if ns.Registry and ns.Registry.RefreshAll then pcall(ns.Registry.RefreshAll, ns.Registry) end
    return true, b.profile
end

function Tools.DeleteBackup(index)
    local list = Backups(false)
    if list and list[index] then table.remove(list, index) return true end
    return false
end

-- characters that use this saved data and the profile each one is on
function Tools.Characters()
    local db = DB()
    local list = {}
    if not (db and db.sv and db.sv.profileKeys) then return list end
    for char, profile in pairs(db.sv.profileKeys) do
        list[#list + 1] = { char = char, profile = profile, current = (char == db.keys.char) }
    end
    table.sort(list, function(a, b)
        if a.current ~= b.current then return a.current end
        return a.char < b.char
    end)
    return list
end

function Tools.Assign(char, profile)
    local db = DB()
    if not (db and db.sv and db.sv.profiles and db.sv.profiles[profile]) then return false end
    if char == db.keys.char then
        db:SetProfile(profile)
    else
        db.sv.profileKeys[char] = profile
    end
    return true
end

---------------------------------------------------------------------------
-- page
---------------------------------------------------------------------------
local function Say(msg) print("|cff60A5FAH3z0UI:|r " .. msg) end

local function Cycle(list, value)
    for i, v in ipairs(list) do
        if v == value then return list[i % #list + 1] end
    end
    return list[1]
end

local function BuildProfileToolsContent(content)
    if content._ptHolder then content._ptHolder:Hide(); content._ptHolder:SetParent(nil) end
    local holder = CreateFrame("Frame", nil, content)
    holder:SetAllPoints(content)
    content._ptHolder = holder
    local function Rebuild() BuildProfileToolsContent(content) end

    local db = DB()
    local W = 640
    if not db then
        local l = CreateWrappedLabel(holder, "Settings are not ready yet. Reopen this page in a moment.", 12, C.textMuted, W)
        l:SetPoint("TOPLEFT", PADDING, -16)
        content:SetHeight(80)
        return
    end

    local y = -12
    local function Title(text)
        local fs = CreateWrappedLabel(holder, text, 14, C.text)
        fs:SetPoint("TOPLEFT", PADDING, y)
        y = y - 26
    end
    local function Note(text)
        local fs = CreateWrappedLabel(holder, text, 11, C.textMuted, W)
        fs:SetPoint("TOPLEFT", PADDING, y)
        y = y - (fs:GetStringHeight() or 14) - 10
    end
    local function EditRow(label, buttonText, onClick, initial)
        local box = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
        box:SetSize(220, 20)
        box:SetPoint("TOPLEFT", PADDING + 6, y)
        box:SetAutoFocus(false)
        box:SetFontObject(ChatFontNormal)
        box:SetText(initial or "")
        local hint = CreateWrappedLabel(holder, label, 10, C.textMuted, 200)
        hint:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -4, 2)
        local btn = GUI:CreateButton(holder, buttonText, 120, 24, function() onClick(box:GetText()) end)
        btn:SetPoint("LEFT", box, "RIGHT", 14, 0)
        y = y - 46
        return box
    end

    local current = db:GetCurrentProfile()
    Title("Current profile: " .. current)

    -- which profile do rename / duplicate act on: the one picked here
    local names = Tools.ProfileNames()
    local pick = content._ptPick
    if not pick or not db.sv.profiles[pick] then pick = current end
    content._ptPick = pick
    local pickBtn = GUI:CreateButton(holder, "Work on: " .. pick, 280, 26, function()
        content._ptPick = Cycle(names, pick)
        Rebuild()
    end)
    pickBtn:SetPoint("TOPLEFT", PADDING, y)
    y = y - 40

    EditRow("New name for this profile", "Rename", function(text)
        local ok, res = Tools.Rename(pick, text)
        if ok then content._ptPick = res; Say("Renamed to " .. res) else Say(res) end
        Rebuild()
    end, pick)
    EditRow("Name of the copy", "Duplicate", function(text)
        local ok, res = Tools.Duplicate(pick, text)
        if ok then Say("Created " .. res .. " as a copy of " .. pick) else Say(res) end
        Rebuild()
    end, pick .. " copy")

    y = y - 6
    Title("Backups of the current profile")
    Note("A backup is a full copy of the profile you are on now, kept for all your characters. Restoring replaces the current profile with the backup. The last " .. MAX_BACKUPS .. " backups are kept.")
    EditRow("Backup label (optional)", "Back up now", function(text)
        local ok, res = Tools.Backup(text)
        if ok then Say("Backed up " .. res) else Say(res) end
        Rebuild()
    end, "")

    local backups = Tools.ListBackups()
    if #backups == 0 then
        Note("No backups yet.")
    end
    for i = #backups, 1, -1 do
        local b = backups[i]
        local row = CreateFrame("Frame", nil, holder)
        row:SetSize(W, 26)
        row:SetPoint("TOPLEFT", PADDING, y)
        local when = b.time and b.time > 0 and date and date("%Y-%m-%d %H:%M", b.time) or "?"
        local text = CreateWrappedLabel(row, string.format("%s  -  %s  (%s)", b.label or "Backup", b.profile or "?", when), 11, C.text, 380)
        text:SetPoint("LEFT", 4, 0)
        local restore
        local armed
        restore = GUI:CreateButton(row, "Restore", 80, 22, function()
            if not armed then
                armed = true
                restore:SetText("Sure?")
                C_Timer.After(3, function() armed = nil; restore:SetText("Restore") end)
                return
            end
            local ok, res = Tools.Restore(i)
            if ok then Say("Restored backup into the current profile. A /reload is recommended.") else Say(res) end
            Rebuild()
        end)
        restore:SetPoint("RIGHT", row, "RIGHT", -76, 0)
        local del = GUI:CreateButton(row, "Delete", 66, 22, function()
            Tools.DeleteBackup(i)
            Rebuild()
        end)
        del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        y = y - 30
    end

    y = y - 10
    Title("Profile per character")
    Note("Choose which profile each of your characters uses. Click a profile name to cycle through your profiles. Other characters pick the change up the next time they log in.")
    for _, rec in ipairs(Tools.Characters()) do
        local row = CreateFrame("Frame", nil, holder)
        row:SetSize(W, 26)
        row:SetPoint("TOPLEFT", PADDING, y)
        local label = rec.char .. (rec.current and "  (this character)" or "")
        local text = CreateWrappedLabel(row, label, 11, C.text, 340)
        text:SetPoint("LEFT", 4, 0)
        local btn = GUI:CreateButton(row, rec.profile, 220, 22, function()
            local nextName = Cycle(Tools.ProfileNames(), rec.profile)
            Tools.Assign(rec.char, nextName)
            Rebuild()
        end)
        btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        y = y - 30
    end

    content:SetHeight(math.abs(y) + 30)
end

ns.H3z0UI_ProfileToolsPage = { BuildProfileToolsContent = BuildProfileToolsContent }

if Registry and Schema
    and type(Registry.RegisterFeature) == "function"
    and type(Schema.Feature) == "function"
    and type(Schema.Section) == "function" then
    Registry:RegisterFeature(Schema.Feature({
        id = "profileToolsPage",
        category = "global",
        nav = { tileId = "global", subPageIndex = 8 },
        sections = {
            Schema.Section({
                id = "profileToolsList",
                kind = "page",
                minHeight = 300,
                build = BuildProfileToolsContent,
            }),
        },
    }))
end
