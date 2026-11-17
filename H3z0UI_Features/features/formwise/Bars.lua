-- The bars: one per form resource, stacked in a container under the player frame.
-- Values may be secrets in combat, so they only ever reach StatusBar:SetValue/SetMinMaxValues,
-- FontString:SetText and string.format, the calls that accept them.
-- Formwise 1.0.0 by kragtenb (MIT License, see LICENSE.txt), bundled into H3z0 UI.
-- Kept in a private namespace (ns.Formwise) so it cannot clash with H3z0 UI's own tables.
local _, host = ...
host.Formwise = host.Formwise or {}
local ns = host.Formwise
local Model, Player = ns.Model, ns.Player

local Bars = {}
ns.Bars = Bars

Bars.ORDER = { "mana", "rage", "energy" }
Bars.POWER = { mana = Player.MANA, rage = Player.RAGE, energy = Player.ENERGY }

-- The stock player frame's fills, with a plain coloured texture if the client lacks them.
local ATLAS = {
    mana = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana",
    rage = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage",
    energy = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy",
}
local TOKEN = { mana = "MANA", rage = "RAGE", energy = "ENERGY" }
local FALLBACK_COLOR = { mana = { 0, 0, 1 }, rage = { 1, 0, 0 }, energy = { 1, 1, 0 } }
local FALLBACK_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local CHANCE_ALPHA = 0.35

local function hasAtlas(name)
    return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(name) ~= nil
end

local function color(key)
    local stock = PowerBarColor and PowerBarColor[TOKEN[key]]
    if stock and stock.r then
        return stock.r, stock.g, stock.b
    end
    return unpack(FALLBACK_COLOR[key])
end

local function styleFill(statusBar, key)
    if hasAtlas(ATLAS[key]) then
        statusBar:SetStatusBarTexture(FALLBACK_TEXTURE)
        statusBar:GetStatusBarTexture():SetAtlas(ATLAS[key])
    else
        statusBar:SetStatusBarTexture(FALLBACK_TEXTURE)
        statusBar:SetStatusBarColor(color(key))
    end
end

local function newStatusBar(parent, key, level)
    local statusBar = CreateFrame("StatusBar", nil, parent)
    statusBar:SetFrameLevel(parent:GetFrameLevel() + level)
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)
    styleFill(statusBar, key)
    return statusBar
end

local function edge(frame, point1, point2, horizontal, list)
    local line = frame:CreateTexture(nil, "OVERLAY")
    if list then list[#list + 1] = line end
    line:SetColorTexture(0, 0, 0, 1)
    -- Unsnapped, so a 1px line between screen pixels doesn't round away to nothing.
    line:SetSnapToPixelGrid(false)
    line:SetTexelSnappingBias(0)
    line:SetPoint(point1)
    line:SetPoint(point2)
    if horizontal then
        line:SetHeight(1)
    else
        line:SetWidth(1)
    end
end

-- Shift icons: in a row under the bars, one icon per form, each with the number of shifts into
-- that form Mana covers. Mana may be secret, so it is never divided: there is a layer
-- per count, each a StatusBar whose fill is the icon, empty below its multiple of the cost and
-- full at it. Its number sits in a frame clipped to that fill, and higher counts stack on top, so
-- the top full layer shows. Icon size follows the bars' height.
Bars.SHIFT_FORMS = { "bear", "cat", "travel", "moonkin" }
local SHIFT_ICON = {
    bear = "Interface\\Icons\\Ability_Racial_BearForm",
    cat = "Interface\\Icons\\Ability_Druid_CatForm",
    travel = "Interface\\Icons\\Ability_Druid_TravelForm",
    moonkin = "Interface\\Icons\\Spell_Nature_ForceOfNature",
}
Bars.SHIFTING_POWER_ICON = 538514 -- a file ID, from the spell's client data
local ICON_SHARE = 2.4 -- icon size per bar height
local NUMBER_SHARE = 0.6 -- of the icon's size
local NUMBER_FONT = "Fonts\\FRIZQT__.TTF"
-- At least LAYER_CAP layers, and LAYER_HEADROOM beyond what the last plain max Mana covers, so a
-- max that rises while secret still counts; unused layers stay empty. The top one reads "N+".
local LAYER_HEADROOM, LAYER_CAP = 2, 20

local function setNumberSize(layer, size)
    layer.text:SetFont(NUMBER_FONT, math.max(6, math.floor(size * NUMBER_SHARE)), "OUTLINE")
end

-- Layer for `shifts` shifts, stored at shifts + 1; 0 is drawn faded.
local function shiftLayer(holder, shifts)
    local layer = holder.layers[shifts + 1]
    if not layer then
        layer = CreateFrame("StatusBar", nil, holder)
        layer:SetAllPoints()
        layer:SetFrameLevel(holder:GetFrameLevel() + 1 + 2 * shifts)
        layer:SetStatusBarTexture(holder.icon)
        if shifts == 0 then
            layer:GetStatusBarTexture():SetDesaturated(true)
            layer:SetAlpha(0.6)
        end
        layer.window = CreateFrame("Frame", nil, layer)
        layer.window:SetFrameLevel(layer:GetFrameLevel() + 1)
        layer.window:SetClipsChildren(true)
        layer.window:SetPoint("TOPLEFT", layer, "TOPLEFT")
        layer.window:SetPoint("BOTTOMRIGHT", layer:GetStatusBarTexture(), "BOTTOMRIGHT")
        layer.text = layer.window:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        layer.text:SetPoint("CENTER", layer)
        setNumberSize(layer, holder.size)
        holder.layers[shifts + 1] = layer
    end
    return layer
end

-- holder: a form's icon from container.shifts; plainMax: the last plain max Mana, nil if none
-- seen; cost: Mana per shift into the form (nil shows none); icon: a texture to draw instead
-- (file ID or path), nil for the form's own.
function Bars.ShowShifts(holder, mana, plainMax, cost, icon)
    icon = icon or SHIFT_ICON[holder.form]
    if holder.icon ~= icon then
        holder.icon = icon
        -- SetTexture on the existing fill keeps each number's clip anchored to it.
        for _, layer in ipairs(holder.layers) do
            layer:GetStatusBarTexture():SetTexture(icon)
        end
    end
    local most = -1
    if cost and cost > 0 then
        most = math.max(LAYER_CAP, plainMax and math.floor(plainMax / cost) + LAYER_HEADROOM or 0)
    end
    for shifts = 0, math.max(most, #holder.layers - 1) do
        local layer = shiftLayer(holder, shifts)
        layer:SetShown(shifts <= most)
        if shifts <= most then
            layer.text:SetText(shifts == most and shifts .. "+" or tostring(shifts))
            layer:SetMinMaxValues(shifts * cost - 1, shifts * cost)
            layer:SetValue(mana)
        end
    end
end


-- Look of H3z0 UI's own power bar: its bar texture, and rounded ends when Rounded Corners are on.
-- frame: the bar; fills: its StatusBars; textures: extra textures to round; bg/lines: the square
-- background and edge lines to drop while the rounded panel draws them.
function Bars.CurrentTexture()
    local f = _G.H3z0UI_Player
    local pb = f and (f.powerBar or f.healthBar)
    local tex = pb and pb.GetStatusBarTexture and pb:GetStatusBarTexture()
    local path = tex and tex.GetTexture and tex:GetTexture()
    if path and not (issecretvalue and issecretvalue(path)) then return path end
    return nil
end

function Bars.Skin(frame, fills, bg, lines, key, path)
    local Round = host.Round
    if path then
        for _, sb in ipairs(fills) do
            local t = sb:GetStatusBarTexture()
            if t then t:SetTexture(path) end
            if frame.fwColor then sb:SetStatusBarColor(frame.fwColor[1], frame.fwColor[2], frame.fwColor[3]) end
        end
    end
    local rounded = Round and Round.Enabled and Round.Enabled() and Round.Panel and true or false
    if rounded then
        local h = frame:GetHeight() or 10
        local radius = math.max(2, math.min((Round.Radius and Round.Radius()) or 4, h / 2))
        if not frame.fwPanel then
            frame.fwPanel = Round.Panel(frame, radius)
            frame.fwPanel:SetAllPoints(frame)
            frame.fwPanel:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
        end
        frame.fwPanel.radius = radius
        frame.fwPanel:SetFillColor(0.04, 0.05, 0.07, 0.9)
        frame.fwPanel:SetBorderColor(0, 0, 0, 1)
        frame.fwPanel:Show()
        if frame.fwPanel.Layout then pcall(frame.fwPanel.Layout, frame.fwPanel) end
        if bg then bg:Hide() end
        for _, l in ipairs(lines or {}) do l:Hide() end
        for _, sb in ipairs(fills) do
            local t = sb:GetStatusBarTexture()
            if t then
                local set = Round.CornerMasks(sb, frame, radius, 1, key or "fwRound")
                Round.Mask(t, set, true)
            end
        end
    else
        if frame.fwPanel then frame.fwPanel:Hide() end
        if bg then bg:Show() end
        for _, l in ipairs(lines or {}) do l:Show() end
        for _, sb in ipairs(fills) do
            local t = sb:GetStatusBarTexture()
            if t and Round and Round.Mask then Round.Mask(t, nil, false) end
        end
    end
end

local function newBar(container, key)
    local bar = CreateFrame("Frame", nil, container)
    bar.key = key

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.55)

    -- possible: Furor's chance-based Rage, drawn faint behind the guaranteed fill.
    bar.possible = newStatusBar(bar, key, 1)
    bar.possible:SetAllPoints()
    bar.possible:SetAlpha(CHANCE_ALPHA)

    bar.fill = newStatusBar(bar, key, 2)
    bar.fill:SetPoint("TOPLEFT")
    bar.fill:SetPoint("BOTTOMLEFT")

    -- A secret stored Energy is drawn in place of the fill, scaled by the share Furor restores,
    -- with the time-based gain anchored to its fill's end, both clipped at Furor's cap: the sum
    -- without any arithmetic on it. At the cap already, the gain lies past the clip.
    bar.clip = CreateFrame("Frame", nil, bar)
    bar.clip:SetPoint("TOPLEFT")
    bar.clip:SetPoint("BOTTOMLEFT")
    bar.clip:SetClipsChildren(true)
    bar.base = newStatusBar(bar.clip, key, 3)
    bar.base:SetPoint("TOPLEFT", bar.clip, "TOPLEFT", 0, 0)
    bar.base:SetPoint("BOTTOMLEFT", bar.clip, "BOTTOMLEFT", 0, 0)
    bar.gain = newStatusBar(bar.clip, key, 3)
    bar.gain:SetValue(1)
    bar.gain:SetPoint("TOPLEFT", bar.base:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    bar.gain:SetPoint("BOTTOMLEFT", bar.base:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)

    local overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 5)

    bar.lines = {}
    edge(overlay, "TOPLEFT", "TOPRIGHT", true, bar.lines)
    edge(overlay, "BOTTOMLEFT", "BOTTOMRIGHT", true, bar.lines)
    edge(overlay, "TOPLEFT", "BOTTOMLEFT", false, bar.lines)
    edge(overlay, "TOPRIGHT", "BOTTOMRIGHT", false, bar.lines)
    bar.background = background

    bar.font = TextStatusBarText and "TextStatusBarText" or "GameFontHighlightSmall"
    bar.text = overlay:CreateFontString(nil, "OVERLAY", bar.font)
    bar.text:SetPoint("CENTER")

    -- Stands in for the text while the stored Energy is secret (Bars.ShowEnergy).
    bar.number = CreateFrame("Frame", nil, overlay)
    bar.number:SetAllPoints()
    bar.number.steps = {}
    bar.number:Hide()
    return bar
end

function Bars.Create(name)
    local container = CreateFrame("Frame", name, UIParent)
    container:SetClampedToScreen(true)
    container:SetMovable(true)
    container:SetDontSavePosition(true) -- Core saves the position; the client must not restore its own
    container.bars = {}
    for _, key in ipairs(Bars.ORDER) do
        container.bars[key] = newBar(container, key)
    end
    container.shifts = {}
    for _, form in ipairs(Bars.SHIFT_FORMS) do
        local holder = CreateFrame("Frame", nil, container)
        holder.form, holder.layers = form, {}
        holder:Hide() -- until Layout sizes it
        container.shifts[form] = holder
    end

    -- Shown while unlocked: a tint to grab, as Blizzard's Edit Mode does.
    container.mover = container:CreateTexture(nil, "OVERLAY")
    container.mover:SetAllPoints()
    container.mover:SetColorTexture(0.3, 0.6, 1, 0.35)
    container.mover:Hide()
    return container
end

-- Sizes the bars and stacks the shown ones top to bottom in Bars.ORDER, then the shown shift
-- icons (icons: by form) in a row under them. embedded: the bars live in the H3z0 player
-- frame (Core places them there), so only the shift icons are laid out here.
function Bars.Layout(container, settings, shown, icons, embedded)
    local y, count = 0, 0
    for _, key in ipairs(Bars.ORDER) do
        local bar = container.bars[key]
        if embedded then
            if shown[key] then count = count + 1 end
        else
            bar:SetShown(shown[key] == true)
        end
        if shown[key] and not embedded then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
            bar:SetSize(settings.width, settings.height)
            bar.width = settings.width
            bar.fwColor = Bars.ColorOf(key)
            pcall(Bars.Skin, bar, { bar.fill, bar.possible, bar.base, bar.gain }, bar.background, bar.lines, "fwRound", Bars.CurrentTexture())
            bar.text:SetShown(settings.showText)
            y = y + settings.height + settings.spacing
            count = count + 1
        end
    end
    local size, x = math.floor(settings.height * ICON_SHARE), 0
    for _, form in ipairs(Bars.SHIFT_FORMS) do
        local holder = container.shifts[form]
        local iconShown = icons[form] == true and settings.showCost
        holder:SetShown(iconShown)
        if iconShown then
            holder:ClearAllPoints()
            holder:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
            holder:SetSize(size, size)
            holder.size = size
            for _, layer in ipairs(holder.layers) do
                setNumberSize(layer, size)
            end
            x = x + size + settings.spacing
        end
    end
    if x > 0 then
        y = y + size + settings.spacing
    end
    if embedded then
        container:SetScale(1)
        container:SetSize(math.max(1, x - settings.spacing), math.max(1, size))
        return count, x > 0
    end
    container:SetScale(settings.scale)
    -- The icon row can outgrow narrow bars; the frame covers it so it drags and clamps too.
    container:SetSize(math.max(settings.width, x - settings.spacing), math.max(settings.height, y - settings.spacing))
    return count, x > 0
end

-- In the H3z0 player frame the bar takes the frame's look: its bar texture and color, no box of
-- its own (the frame's border and the 1px lines between its bars frame it), and no corner masks
-- of its own (the frame rounds its whole outline, bars included).
function Bars.SkinEmbedded(bar, path)
    local Round = host.Round
    Bars.RecordLevels(bar)
    if bar.fwPanel then bar.fwPanel:Hide() end
    if bar.background then bar.background:Hide() end
    for _, l in ipairs(bar.lines or {}) do l:Hide() end
    for _, sb in ipairs({ bar.fill, bar.possible, bar.base, bar.gain }) do
        local t = sb:GetStatusBarTexture()
        if t then
            if path then t:SetTexture(path) end
            if Round and Round.Mask then Round.Mask(t, nil, false) end
        end
        if bar.fwColor then sb:SetStatusBarColor(bar.fwColor[1], bar.fwColor[2], bar.fwColor[3]) end
    end
end

-- Moving a bar into another parent must keep its pieces stacked as built (fills over the
-- dark back, text over the fills): each child's level offset from its parent is noted the
-- first time it is seen and put back after every move.
local function recordOffsets(f)
    local base = f:GetFrameLevel()
    for _, c in ipairs({ f:GetChildren() }) do
        if c.fwOff == nil then c.fwOff = math.max(1, c:GetFrameLevel() - base) end
        recordOffsets(c)
    end
end

local function applyOffsets(f)
    local base = f:GetFrameLevel()
    for _, c in ipairs({ f:GetChildren() }) do
        local want = base + (c.fwOff or 1)
        if c:GetFrameLevel() ~= want then c:SetFrameLevel(want) end
        applyOffsets(c)
    end
end

Bars.RecordLevels = recordOffsets

function Bars.KeepLevels(bar)
    recordOffsets(bar)
    applyOffsets(bar)
end

-- Back in its own container: drop what the player frame put on it.
function Bars.Unembed(bar, container)
    if bar.h3zSeparator then bar.h3zSeparator:Hide() end
    bar.h3zSubBar = nil
    if bar:GetParent() ~= container then bar:SetParent(container) end
    bar:SetFrameLevel(container:GetFrameLevel() + 1)
    Bars.KeepLevels(bar)
    bar:SetAlpha(1)
end

Bars.Color = color

-- The bar's colour: your own (Shapeshift Bars > Custom Bar Colors) or the game's power colour.
-- Bars.ColorOverride is set by Core.
function Bars.ColorOf(key)
    local c = Bars.ColorOverride and Bars.ColorOverride(key)
    if type(c) == "table" and c[1] then return { c[1], c[2], c[3] } end
    return { color(key) }
end

-- The bar's width. An embedded bar only learns it after the player frame has placed it, which
-- can be after the first update, so fall back to its real size, then to a default.
local function widthOf(bar)
    if type(bar.width) == "number" and bar.width > 1 then return bar.width end
    local w = bar.GetWidth and bar:GetWidth()
    if type(w) == "number" and not (issecretvalue and issecretvalue(w)) and w > 1 then
        bar.width = w
        return w
    end
    return 100
end

local function plainFill(bar, value, max)
    bar.fill:SetWidth(widthOf(bar))
    bar.fill:SetMinMaxValues(0, max)
    bar.fill:SetValue(value)
    bar.fill:Show()
    bar.clip:Hide()
end

-- Mana: the real value and max, maybe secret.
function Bars.ShowMana(bar, mana, max)
    plainFill(bar, mana, max)
    bar.possible:Hide()
    bar.text:SetText(string.format("%d", mana))
end

function Bars.RageText(rage)
    if rage.possible > rage.guaranteed then
        return string.format("%d (%d%%: %d)", rage.guaranteed, rage.chance, rage.possible)
    end
    return string.format("%d", rage.guaranteed)
end

function Bars.ShowRage(bar, rage, max)
    plainFill(bar, rage.guaranteed, max)
    bar.possible:SetShown(rage.possible > rage.guaranteed)
    bar.possible:SetMinMaxValues(0, max)
    bar.possible:SetValue(rage.possible)
    bar.text:SetText(Bars.RageText(rage))
end

-- A secret base can't be added to, so its number is drawn by steps, one per Energy value, as the
-- shift icons count: an invisible StatusBar that fills once the base reaches the value's least
-- base, and the value's text in a window from the next step's fill end to this one's. Only the
-- highest value reached has a full fill with an empty one above it, so only its window is open.
local NEVER = 1e9 -- least base for a value past Furor's cap

-- Step for `value`, stored at value + 1.
local function numberStep(bar, value)
    local steps = bar.number.steps
    if not steps[value + 1] then
        local threshold = CreateFrame("StatusBar", nil, bar.number)
        threshold:SetAllPoints()
        threshold:SetStatusBarTexture(FALLBACK_TEXTURE)
        threshold:GetStatusBarTexture():SetAlpha(0)
        steps[value + 1] = { threshold = threshold }
    end
    return steps[value + 1]
end

local function numberWindow(bar, value)
    local step, above = numberStep(bar, value), numberStep(bar, value + 1)
    if not step.window then
        step.window = CreateFrame("Frame", nil, bar.number)
        step.window:SetClipsChildren(true)
        step.window:SetPoint("TOPLEFT", above.threshold:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
        step.window:SetPoint("BOTTOMRIGHT", step.threshold:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
        step.text = step.window:CreateFontString(nil, "OVERLAY", bar.font)
        step.text:SetPoint("CENTER", bar)
        step.text:SetText(tostring(value))
    end
    return step.window
end

local function showNumber(bar, prediction)
    local exact = prediction.value ~= nil
    bar.text:SetText(exact and string.format("%d", prediction.value) or "")
    bar.number:SetShown(not exact and bar.text:IsShown())
    if not bar.number:IsShown() then
        return
    end
    for value = 0, math.max(prediction.cap + 1, #bar.number.steps - 1) do
        local step = numberStep(bar, value)
        local least = Model.LeastBase(prediction, value) or NEVER
        step.threshold:SetMinMaxValues(least - 1, least)
        step.threshold:SetValue(prediction.base)
        if value <= prediction.cap then
            numberWindow(bar, value):Show()
        elseif step.window then
            step.window:Hide()
        end
    end
end

function Bars.ShowEnergy(bar, prediction, max)
    bar.possible:Hide()
    showNumber(bar, prediction)
    if prediction.value then
        plainFill(bar, prediction.value, max)
        return
    end
    bar.fill:Hide()
    bar.clip:SetWidth(widthOf(bar) * prediction.cap / max)
    bar.clip:Show()
    bar.base:SetWidth(widthOf(bar))
    bar.base:SetMinMaxValues(0, max / prediction.fraction)
    bar.base:SetValue(prediction.base)
    local gainWidth = widthOf(bar) * prediction.gain / max
    bar.gain:SetShown(gainWidth > 0)
    bar.gain:SetWidth(math.max(gainWidth, 1))
end

-- The five-second rule's spark: a line that crosses a mana bar while Spirit regen is paused. It
-- rides the end of an invisible StatusBar fill laid over the bar, so it never reads a bar's width.
local SPARK_WIDTH, SPARK_OVERHANG = 2, 2

function Bars.CreateSpark()
    local spark = CreateFrame("StatusBar", nil, UIParent)
    spark:SetStatusBarTexture(FALLBACK_TEXTURE)
    spark:GetStatusBarTexture():SetAlpha(0)
    spark.line = spark:CreateTexture(nil, "OVERLAY")
    spark.line:SetColorTexture(1, 1, 1, 0.9)
    spark.line:SetWidth(SPARK_WIDTH)
    spark.line:SetPoint("TOP", spark:GetStatusBarTexture(), "TOPRIGHT", 0, SPARK_OVERHANG)
    spark.line:SetPoint("BOTTOM", spark:GetStatusBarTexture(), "BOTTOMRIGHT", 0, -SPARK_OVERHANG)
    spark:Hide()
    return spark
end

-- bar: the mana bar to cross, nil hides the spark; elapsed of duration seconds have passed.
function Bars.ShowSpark(spark, bar, elapsed, duration)
    spark:SetShown(bar ~= nil)
    if not bar then
        return
    end
    if spark.bar ~= bar then
        spark.bar = bar
        spark:SetParent(bar)
        spark:SetFrameLevel(bar:GetFrameLevel() + 10)
        spark:ClearAllPoints()
        spark:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        spark:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    end
    spark:SetMinMaxValues(0, duration)
    spark:SetValue(elapsed)
end

return Bars
