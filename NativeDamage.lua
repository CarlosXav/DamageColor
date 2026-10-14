local _, addon = ...

addon.overlayEnabled = true
addon.nativeDamageStatus = "not applied"
local function get(name)
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if not getter then return end
    local ok, value = pcall(getter, name)
    if ok and (value == "0" or value == "1") then return value end
end
local function set(name, value)
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if not setter then return false end
    local ok = pcall(setter, name, value)
    return ok and get(name) == value
end

function addon.ApplyNativeDamageSetting(forceRestore)
    if not DamageColorDB then return end
    local previous = DamageColorDB.nativeDamageRestore
    if type(previous) ~= "table" or
        (previous.name ~= "floatingCombatTextCombatDamage_v2" and previous.name ~= "floatingCombatTextCombatDamage") or
        (previous.value ~= "0" and previous.value ~= "1") then
        previous = nil
        DamageColorDB.nativeDamageRestore = nil
    end
    local hiding = addon.hideBlizzardDamage and addon.overlayEnabled and not forceRestore
    if hiding then
        local name = previous and previous.name or "floatingCombatTextCombatDamage_v2"
        local value = get(name)
        if not value and not previous then
            name = "floatingCombatTextCombatDamage"
            value = get(name)
        end
        if not value then addon.nativeDamageStatus = "damage setting unavailable"; return end
        if not previous then
            previous = { name = name, value = value }
            DamageColorDB.nativeDamageRestore = previous
        end
        local hidden = value == "0" or set(name, "0")
        addon.nativeDamageStatus = hidden and "hidden" or "hide pending (will retry after combat)"
    elseif previous then
        -- Preserve an external change that already re-enabled native damage.
        local current = get(previous.name)
        if current == "1" or (current and (current == previous.value or set(previous.name, previous.value))) then
            DamageColorDB.nativeDamageRestore = nil
            addon.nativeDamageStatus = "previous setting restored"
        else
            addon.nativeDamageStatus = "restore pending (will retry after combat)"
        end
    else
        addon.nativeDamageStatus = "native setting unchanged"
    end
end

function addon.SetHideBlizzardDamage(value)
    if type(value) ~= "boolean" then return end
    addon.hideBlizzardDamage = value
    DamageColorDB.hideBlizzardDamage = value
    addon.ApplyNativeDamageSetting()
    if addon.OnNativeDamageChanged then addon.OnNativeDamageChanged() end
end

local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("PLAYER_LOGIN")
lifecycle:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycle:RegisterEvent("PLAYER_REGEN_ENABLED")
lifecycle:RegisterEvent("PLAYER_LOGOUT")
lifecycle:SetScript("OnEvent", function(_, event)
    addon.ApplyNativeDamageSetting(event == "PLAYER_LOGOUT")
end)
