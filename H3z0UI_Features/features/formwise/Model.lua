-- What each form's resource would be after a shift, from WoW: Forever's Furor. From the client's
-- tooltip data (build 1.60.1): at rank r, a 20r% chance of 10 Rage on entering Bear or Dire Bear
-- Form; entering Cat Form regains 20r% of the Energy held when Cat Form was last left, plus 2r
-- Energy per second spent outside Bear, Cat and Dire Bear Form, up to 20r Energy (read here as a
-- cap on the total, with time counted continuously). Bear Form keeps the stored Energy, with accrual
-- halted (tooltip and Blizzard's October 15 beta notes, from build 70425). Nothing else in the
-- client's spell data changes the power a shift gives: Wolfshead Helm now boosts Enrage and
-- Shifting Power instead.
-- Pure functions; Core feeds them the client's state.
-- Formwise 1.0.0 by kragtenb (MIT License, see LICENSE.txt), bundled into H3z0 UI.
-- Kept in a private namespace (ns.Formwise) so it cannot clash with H3z0 UI's own tables.
local _, host = ...
host.Formwise = host.Formwise or {}
local ns = host.Formwise

local Model = {}
ns.Model = Model

Model.FUROR_MAX_RANK = 5
Model.FUROR_RAGE = 10

local function isSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- Whole Energy, forgiving float drift in the clock (2.9999 seconds is 3).
local function whole(value)
    return math.floor(value + 1e-6)
end

-- Form kinds are "cat", "bear" or "caster" (any form whose power is mana).
-- Energy state: base is the Energy held on leaving Cat Form (a number, or a secret in combat);
-- accrued is seconds banked outside Cat Form; since is when accrual last (re)started, nil while
-- halted (in Cat or Bear Form).
function Model.NewEnergyState()
    return { base = 0, accrued = 0, since = nil }
end

function Model.SecondsOutside(state, now)
    return state.accrued + (state.since and math.max(0, now - state.since) or 0)
end

-- from is nil at login. energy: the Energy just before the shift (only read when leaving Cat Form).
function Model.Transition(state, from, to, now, energy)
    if from == to then
        return
    end
    if from == "cat" then
        state.base, state.accrued = energy, 0
    end
    if to == "caster" then
        state.since = state.since or now
    else
        state.accrued = Model.SecondsOutside(state, now)
        state.since = nil
    end
end

-- The Energy Cat Form would start with. Returns a table:
--   value: the prediction, or nil when it depends on a secret base
--   gain, cap: the time-based part and the most Furor restores
--   base, fraction: the stored Energy and the share of it restored (for drawing a secret base)
function Model.PredictEnergy(state, rank, now, maxEnergy)
    if rank <= 0 then
        return { value = 0, gain = 0, cap = 0, base = 0, fraction = 0 }
    end
    local fraction = rank / Model.FUROR_MAX_RANK
    local cap = math.min(20 * rank, maxEnergy)
    local gain = math.min(cap, 2 * rank * Model.SecondsOutside(state, now))
    local prediction = { gain = gain, cap = cap, base = state.base, fraction = fraction }
    if gain >= cap then
        prediction.value = whole(cap)
    elseif not isSecret(state.base) then
        prediction.value = whole(math.min(cap, fraction * state.base + gain))
    end
    return prediction
end

-- For a prediction with a secret base: the least whole stored Energy that makes Cat Form start
-- with `value` or more, nil past Furor's cap. The bars test the secret base against it.
function Model.LeastBase(prediction, value)
    if value > prediction.cap then
        return nil
    end
    return math.max(0, math.ceil((value - prediction.gain - 1e-6) / prediction.fraction))
end

-- The Rage Bear Form would start with: guaranteed, plus Furor's chance-based Rage below rank 5.
function Model.PredictRage(rank, maxRage)
    local chance = math.max(0, math.min(rank, Model.FUROR_MAX_RANK)) * 20
    local guaranteed = chance >= 100 and Model.FUROR_RAGE or 0
    local possible = chance > 0 and Model.FUROR_RAGE or 0
    return { guaranteed = math.min(guaranteed, maxRage), possible = math.min(possible, maxRage), chance = chance }
end

-- Furor ranks that explain an observed Cat Form entry, given the state just before it.
function Model.RanksMatchingEnergy(state, now, maxEnergy, observed, tolerance)
    local ranks = {}
    for rank = 0, Model.FUROR_MAX_RANK do
        local value = Model.PredictEnergy(state, rank, now, maxEnergy).value
        if value and math.abs(value - observed) <= tolerance then
            table.insert(ranks, rank)
        end
    end
    return ranks
end

-- Copy of a state that SavedVariables can hold: a secret base is unknowable later, so it becomes 0.
function Model.Snapshot(state, now)
    local base = state.base
    if isSecret(base) then
        base = 0
    end
    return { base = base, seconds = Model.SecondsOutside(state, now), accruing = state.since ~= nil }
end

-- Rebuilds a state from Model.Snapshot after `away` seconds logged out or reloading. Time away
-- counts as outside Cat Form only if the player was accruing (not in Cat or Bear Form).
function Model.Restore(snapshot, now, away)
    local state = Model.NewEnergyState()
    if type(snapshot) ~= "table" then
        return state
    end
    state.base = tonumber(snapshot.base) or 0
    state.accrued = (tonumber(snapshot.seconds) or 0) + (snapshot.accruing and math.max(0, away or 0) or 0)
    if snapshot.accruing then
        state.since = now
    end
    return state
end

return Model
