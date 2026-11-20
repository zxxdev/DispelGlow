local _UnitAura = UnitAura
local magic, buff, player = "Magic", "HELPFUL", "player"
UnitAura = function(...)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, castByPlayer, nameplateShowPersonal, timeMod, text, value1, value2, value3 = _UnitAura(...)
    local unit = ...
    if not UnitCanAttack(player, unit) then return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, castByPlayer, nameplateShowPersonal, timeMod, text, value1, value2, value3 end
    if debuffType == magic then
        local filter = select(3, ...)
        if filter and filter == buff then
            isStealable = true
        end
    end
    return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, castByPlayer, nameplateShowPersonal, timeMod, text, value1, value2, value3
end

local _UnitBuff = UnitBuff
UnitBuff = function(...)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, castByPlayer, nameplateShowPersonal, timeMod, text, value1, value2, value3 = _UnitBuff(...)
    local unit = ...
    if not UnitCanAttack(player, unit) then return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, castByPlayer, nameplateShowPersonal, timeMod, text, value1, value2, value3 end
    if debuffType == magic then
        isStealable = true
    end
    return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, castByPlayer, nameplateShowPersonal, timeMod, text, value1, value2, value3
end

local fx = CreateFrame("Frame")
fx:RegisterEvent("PLAYER_LOGOUT")
fx:SetScript("OnEvent", function(self, event)
    if Details and Details.ResetSegmentData then
        Details:ResetSegmentData()
    end
end)
