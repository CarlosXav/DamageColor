local _, addon = ...

-- School masks are exact matches; hybrids deliberately use the fallback.
addon.colors = {
    [1] = { 1, 0.20, 0.20 },       -- Physical abilities, including bleeds.
    [2] = { 1, 0.95, 0.60 },       -- Holy.
    [4] = { 1, 0.50, 0.10 },       -- Fire.
    [8] = { 0.25, 1, 0.30 },       -- Nature.
    [16] = { 0.55, 0.85, 1 },      -- Frost.
    [32] = { 0.45, 0.35, 0.85 },   -- Shadow.
    [64] = { 0.85, 0.40, 1 },      -- Arcane.
}
local white, yellow = { 1, 1, 1 }, { 1, 1, 0 }
local function secret(value)
    return issecretvalue and issecretvalue(value)
end

function addon.GetColor(school, isAutoAttack)
    if not secret(isAutoAttack) and isAutoAttack == true then
        return unpack(white)
    end
    if secret(school) or type(school) ~= "number" then
        return unpack(yellow)
    end
    return unpack(addon.colors[school] or yellow)
end

local function say(message)
    print("|cffbb66ffDamageColor:|r " .. message)
end

-- An additive display: native text stays enabled to preserve white swings.
-- UNIT_COMBAT has no attacker identity, so this includes all target damage.
local live = CreateFrame("Frame", nil, UIParent)
live:SetAllPoints(UIParent)
local enabled, sequence = true, 0
local labels = {}
for i = 1, 24 do
    local text = live:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 24, "OUTLINE")
    text:Hide()
    labels[i] = { text = text, age = 0, active = false }
end
live:Hide()
live:SetScript("OnUpdate", function(self, elapsed)
    local any = false
    for _, label in ipairs(labels) do
        if label.active then
            label.age = label.age + elapsed
            if label.age >= 1.3 then
                label.active = false
                label.text:Hide()
            else
                any = true
                label.text:ClearAllPoints()
                label.text:SetPoint("CENTER", UIParent, "CENTER", label.x, 100 + label.age * 55)
                label.text:SetAlpha(math.min(1, (1.3 - label.age) / 0.4))
            end
        end
    end
    if not any then self:Hide() end
end)

local damageEvents = CreateFrame("Frame")
damageEvents:RegisterUnitEvent("UNIT_COMBAT", "target")
damageEvents:SetScript("OnEvent", function(_, _, unit, event, flags, amount, school)
    if not enabled or secret(unit) or secret(event) or secret(school) or secret(amount) then return end
    if unit ~= "target" or event ~= "WOUND" then return end
    -- No physical overlay: the feed cannot distinguish skills from swings.
    -- With an unreadable school, we cannot safely rule out physical damage.
    if type(school) ~= "number" or school <= 1 then return end
    if type(amount) ~= "number" or amount <= 0 then return end
    sequence = sequence + 1
    local label = labels[(sequence - 1) % #labels + 1]
    label.age, label.active = 0, true
    label.x = ((sequence - 1) % 5 - 2) * 65
    label.text:SetText(tostring(amount))
    label.text:SetTextColor(addon.GetColor(school))
    label.text:SetAlpha(1)
    label.text:ClearAllPoints()
    label.text:SetPoint("CENTER", UIParent, "CENTER", label.x, 100)
    label.text:Show()
    live:Show()
end)

local preview = CreateFrame("Frame", nil, UIParent)
preview:SetSize(360, 300)
preview:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
preview:Hide()
local samples = {
    { "Auto-attack", 1, true },
    { "Physical skill / bleed", 1 },
    { "Arcane", 64 }, { "Fire", 4 }, { "Shadow", 32 },
    { "Frost", 16 }, { "Nature", 8 }, { "Holy", 2 },
    { "Other / mixed school", 20 },
}
for i, sample in ipairs(samples) do
    local text = preview:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
    text:SetPoint("TOP", preview, "TOP", 0, -(i - 1) * 30)
    text:SetText(sample[1] .. "  123")
    text:SetTextColor(addon.GetColor(sample[2], sample[3]))
end
local previewTime = 0
preview:SetScript("OnUpdate", function(self, elapsed)
    previewTime = previewTime + elapsed
    if previewTime >= 10 then self:Hide() end
end)

-- Bounded metadata-only diagnostics. Never stringify or inspect secret data.
local watcher = CreateFrame("Frame")
local watching, generation = false, 0
local buckets, received, restricted = {}, 0, 0
local function readable(value)
    if secret(value) then return "<secret>" end
    local kind = type(value)
    if kind == "string" or kind == "number" then return tostring(value) end
    return "<" .. kind .. ">"
end
local function stop()
    watching = false
    watcher:UnregisterEvent("UNIT_COMBAT")
    say("Watch stopped. Use /dc report to see event metadata.")
end
watcher:SetScript("OnEvent", function(_, _, unit, event, flags, amount, school)
    if not watching then return end
    received = received + 1
    if secret(unit) or secret(event) or secret(flags) or secret(amount) or secret(school) then
        restricted = restricted + 1
    end
    local key = readable(unit) .. " | " .. readable(event) .. " | "
        .. readable(flags) .. " | school=" .. readable(school)
    -- Keep memory and chat output bounded, even if the beta changes payloads.
    if buckets[key] then
        buckets[key] = buckets[key] + 1
    elseif received <= 40 then
        buckets[key] = 1
    end
end)

SLASH_DAMAGECOLOR1 = "/damagecolor"
SLASH_DAMAGECOLOR2 = "/dc"
SlashCmdList.DAMAGECOLOR = function(message)
    local command = message:match("^%s*(%S*)"):lower()
    if command == "preview" then
        previewTime = 0
        preview:Show()
        say("Synthetic palette preview for 10 seconds; physical red is a planned color only.")
    elseif command == "on" then
        enabled = true
        say("Magic damage overlay enabled (all attackers on your target).")
    elseif command == "off" then
        enabled = false
        for _, label in ipairs(labels) do
            label.active = false
            label.text:Hide()
        end
        live:Hide()
        say("Magic damage overlay disabled.")
    elseif command == "watch" then
        buckets, received, restricted = {}, 0, 0
        generation = generation + 1
        local current = generation
        watching = true
        watcher:RegisterUnitEvent("UNIT_COMBAT", "target")
        say("Watching your target for 20 seconds; all attackers may be included.")
        C_Timer.After(20, function()
            if watching and generation == current then stop() end
        end)
    elseif command == "stop" then
        stop()
    elseif command == "report" then
        local version, build, _, interface = GetBuildInfo()
        say("Client " .. version .. " / " .. build .. " / interface " .. interface)
        say("Magic overlay=" .. (enabled and "on" or "off") .. "; physical text remains native.")
        say("Target events=" .. received .. "; events containing secrets=" .. restricted)
        local keys = {}
        for key in pairs(buckets) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do say(buckets[key] .. " x " .. key) end
    else
        say("/dc on | /dc off | /dc preview | /dc watch | /dc stop | /dc report")
        say("Magic overlay includes all attackers on your target; physical text remains native.")
    end
end
