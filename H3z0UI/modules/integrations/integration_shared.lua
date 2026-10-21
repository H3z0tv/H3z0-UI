local ADDON_NAME, ns = ...

local IntegrationShared = {}
ns.H3z0UI_IntegrationShared = IntegrationShared

function IntegrationShared.GetAnchorFrame(anchorName)
    if not anchorName or anchorName == "disabled" then
        return nil
    end

    local H3z0UICore = ns.Addon

    if anchorName == "essential" then
        return _G.H3z0UI_GetCDMViewerFrame and _G.H3z0UI_GetCDMViewerFrame("essential")
    elseif anchorName == "utility" then
        return _G.H3z0UI_GetCDMViewerFrame and _G.H3z0UI_GetCDMViewerFrame("utility")
    elseif anchorName == "primary" then
        return H3z0UICore and H3z0UICore.powerBar
    elseif anchorName == "secondary" then
        return H3z0UICore and H3z0UICore.secondaryPowerBar
    elseif anchorName == "playerCastbar" then
        return ns.H3z0UI_Castbar and ns.H3z0UI_Castbar.castbars and ns.H3z0UI_Castbar.castbars["player"]
    elseif anchorName == "playerFrame" then
        return ns.H3z0UI_UnitFrames and ns.H3z0UI_UnitFrames.frames and ns.H3z0UI_UnitFrames.frames.player
    elseif anchorName == "targetFrame" then
        return ns.H3z0UI_UnitFrames and ns.H3z0UI_UnitFrames.frames and ns.H3z0UI_UnitFrames.frames.target
    end

    if ns.H3z0UI_Anchoring and ns.H3z0UI_Anchoring.GetAnchorTarget then
        return ns.H3z0UI_Anchoring:GetAnchorTarget(anchorName)
    end

    return nil
end

function IntegrationShared.MakeQueueRetry(moduleName)
    local retryTimer
    return function()
        if retryTimer then
            return
        end
        retryTimer = C_Timer.NewTimer(1.0, function()
            retryTimer = nil
            local module = ns[moduleName]
            if module then
                module:ApplyAllPositions()
            end
        end)
    end
end
