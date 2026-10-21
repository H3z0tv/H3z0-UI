local _, ns = ...

_G.H3z0UI_OpenAltsRoster = function()
    local p = H3z0UI and H3z0UI.db and H3z0UI.db.profile
    if p and p.alts and p.alts.enabled == false then return end
    if ns.Alts and ns.Alts.Window then ns.Alts.Window.Toggle() end
end
