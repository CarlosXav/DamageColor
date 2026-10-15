local _, addon = ...

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

local function readableTable(value)
    return not secret(value) and type(value) == "table"
        and not (issecrettable and issecrettable(value))
end

local function describe(value)
    if secret(value) then return "<secret>" end
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    if value == nil then return "missing" end
    return "unexpected type"
end

-- Manual snapshots only: no registrations, meter resets, or saved data.
function addon.ProbeDamageMeter(say)
    local ok = pcall(function()
        say("Damage-meter snapshot; in combat=" .. describe(InCombatLockdown and InCombatLockdown()))
        local api = C_DamageMeter
        if type(api) ~= "table" then say("C_DamageMeter unavailable."); return end
        if type(api.IsDamageMeterAvailable) == "function" then
            local available = api.IsDamageMeterAvailable()
            say("Meter available=" .. describe(available))
            if secret(available) or available == false then return end
        end
        local sessionTypes = Enum and Enum.DamageMeterSessionType
        local damageTypes = Enum and Enum.DamageMeterType
        if not sessionTypes or not damageTypes or sessionTypes.Current == nil
            or damageTypes.DamageDone == nil or type(api.GetCombatSessionFromType) ~= "function" then
            say("Current-session query or damage enums unavailable."); return
        end
        local session = api.GetCombatSessionFromType(sessionTypes.Current, damageTypes.DamageDone)
        if not readableTable(session) then say("Current session missing or restricted."); return end
        say("Session total=" .. describe(session.totalAmount))
        local sources = session.combatSources
        if not readableTable(sources) then say("Source list missing or restricted."); return end
        local player
        for i = 1, math.min(#sources, 80) do
            local source = sources[i]
            if readableTable(source) and not secret(source.isLocalPlayer) and source.isLocalPlayer == true then
                player = source; break
            end
        end
        if not player then say("Local player not found in current session (scan limit 80)."); return end
        say("Local player found; total=" .. describe(player.totalAmount)
            .. "; DPS=" .. describe(player.amountPerSecond))
        local guid = player.sourceGUID
        if secret(guid) or type(guid) ~= "string" then
            say("Player identifier missing or restricted; spell query skipped."); return
        end
        if type(api.GetCombatSessionSourceFromType) ~= "function" then
            say("Player spell query unavailable."); return
        end
        local details = api.GetCombatSessionSourceFromType(sessionTypes.Current, damageTypes.DamageDone, guid)
        if not readableTable(details) then say("Player spell data missing or restricted."); return end
        local spells = details.combatSpells
        if not readableTable(spells) then say("Spell list missing or restricted."); return end
        say("Player spells=" .. #spells .. "; showing up to 5 aggregated entries:")
        for i = 1, math.min(#spells, 5) do
            local spell = spells[i]
            if readableTable(spell) then
                say("Spell ID=" .. describe(spell.spellID) .. "; total=" .. describe(spell.totalAmount))
            else
                say("Spell entry restricted.")
            end
        end
    end)
    if not ok then say("Damage-meter snapshot could not finish: API call or data access failed.") end
end
