local addon = {}
assert(loadfile("MeterProbe.lua"))("DamageColor", addon)
local hidden = setmetatable({}, { __tostring = function() error("secret leaked") end })
issecretvalue = function(v) return rawequal(v, hidden) end
issecrettable = function(v) return rawequal(v, hidden) end
InCombatLockdown = function() return true end
Enum = { DamageMeterSessionType = { Current = 1 }, DamageMeterType = { DamageDone = 0 } }
local function probe()
    local lines = {}
    addon.ProbeDamageMeter(function(line) lines[#lines + 1] = line end)
    return table.concat(lines, "\n")
end
assert(probe():find("unavailable", 1, true))
local calls = 0
local player = { isLocalPlayer = true, totalAmount = 123, amountPerSecond = 12, sourceGUID = "private-guid" }
local session = { totalAmount = 456, combatSources = { { isLocalPlayer = false, totalAmount = 333 }, player } }
C_DamageMeter = {
    IsDamageMeterAvailable = function() return true end,
    GetCombatSessionFromType = function(kind, metric)
        assert(kind == 1 and metric == 0)
        return session
    end,
    GetCombatSessionSourceFromType = function(kind, metric, guid)
        assert(kind == 1 and metric == 0 and guid == "private-guid")
        calls = calls + 1
        local spells = {}
        for i = 1, 8 do spells[i] = { spellID = i, totalAmount = i * 10 } end
        return { combatSpells = spells }
    end,
    ResetAllCombatSessions = function() error("must not reset") end,
}
local output = probe()
assert(output:find("Local player found; total=123; DPS=12", 1, true))
assert(output:find("Spell ID=5; total=50", 1, true))
assert(not output:find("Spell ID=6", 1, true))
assert(not output:find("private-guid", 1, true))
player.totalAmount, player.amountPerSecond, player.sourceGUID = hidden, hidden, hidden
output = probe()
assert(output:find("total=<secret>; DPS=<secret>", 1, true))
assert(output:find("spell query skipped", 1, true) and calls == 1)
session.combatSources = hidden
assert(probe():find("Source list missing or restricted", 1, true))
session = hidden
assert(probe():find("Current session missing or restricted", 1, true))
C_DamageMeter.GetCombatSessionFromType = function() error("unexpected API failure") end
assert(probe():find("could not finish", 1, true))
C_DamageMeter.IsDamageMeterAvailable = function() return false end
assert(probe():find("Meter available=false", 1, true))
print("PASS: meter availability, local-player selection, secret guards, bounded output, and API failures")
