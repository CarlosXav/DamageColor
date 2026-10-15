local _, addon = ...

-- Observe Blizzard only after its secure handlers finish. Calling OnEvent from
-- an addon wrapper taints its secret health/power arithmetic, even for events
-- unrelated to damage. Never replace scripts or call Blizzard handlers here.
local damageTypes = {}
for _, kind in ipairs({ "DAMAGE", "DAMAGE_CRIT", "DAMAGE_SHIELD", "SPELL_DAMAGE", "SPELL_DAMAGE_CRIT",
    "BLOCK", "SPELL_BLOCK", "ABSORB", "SPELL_ABSORB", "RESIST", "SPELL_RESIST" }) do
    damageTypes[kind] = true
end
local hooked = setmetatable({}, { __mode = "k" })
local suppress = false
addon.nativeDamageTakenStatus = "not applied"
function addon.ApplyNativeDamageTakenSetting(forceRestore)
    suppress = addon.hideBlizzardDamageTaken and addon.overlayEnabled and not forceRestore
    if not suppress then addon.nativeDamageTakenStatus = "native setting unchanged"; return end
    local frame = CombatText
    if not frame then addon.nativeDamageTakenStatus = "waiting for Blizzard combat text"; return end
    if hooked[frame] then addon.nativeDamageTakenStatus = "hidden"; return end
    if not hooksecurefunc or not frame.HookScript or type(frame.AddMessage) ~= "function" then
        addon.nativeDamageTakenStatus = "incoming display hooks unavailable"
        return
    end
    local pending
    -- AddMessage appends the newly acquired string to activeFontStrings. Keep
    -- the reference outside Blizzard's tables and consume it after each event.
    hooksecurefunc(frame, "AddMessage", function(self)
        pending = nil
        if not suppress then return end
        local strings = self.activeFontStrings
        if (issecretvalue and issecretvalue(strings)) or type(strings) ~= "table"
            or (issecrettable and issecrettable(strings)) then return end
        local text = strings[#strings]
        if not (issecretvalue and issecretvalue(text)) then pending = text end
    end)
    frame:HookScript("OnEvent", function(_, event, kind)
        local text = pending
        pending = nil
        if not suppress or not text or event ~= "COMBAT_TEXT_UPDATE" then return end
        if (issecretvalue and issecretvalue(kind)) or type(kind) ~= "string" then return end
        if damageTypes[kind] then text:Hide() end
    end)
    -- Discard messages emitted outside an event before another frame starts.
    frame:HookScript("OnUpdate", function() pending = nil end)
    hooked[frame] = true
    addon.nativeDamageTakenStatus = "hidden"
end
function addon.SetHideBlizzardDamageTaken(value)
    if type(value) ~= "boolean" then return end
    addon.hideBlizzardDamageTaken = value
    if DamageColorDB then DamageColorDB.hideBlizzardDamageTaken = value end
    addon.ApplyNativeDamageTakenSetting()
    if addon.OnNativeDamageChanged then addon.OnNativeDamageChanged() end
end
local lifecycle = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_LOGOUT" }) do
    lifecycle:RegisterEvent(event)
end
lifecycle:SetScript("OnEvent", function(_, event)
    addon.ApplyNativeDamageTakenSetting(event == "PLAYER_LOGOUT")
end)
