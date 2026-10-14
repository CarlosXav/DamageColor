local _, addon = ...

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

function addon.GetColor(school)
    if secret(school) or type(school) ~= "number" then
        return unpack(addon.colors[0])
    end
    return unpack(addon.colors[school] or addon.colors[0])
end

local function say(message)
    print("|cffbb66ffDamageColor:|r " .. message)
end

-- An additive display: native text stays enabled.
-- UNIT_COMBAT has no attacker identity, so this includes all attackers.
local live = CreateFrame("Frame", nil, UIParent)
live:SetAllPoints(UIParent)
live:SetFrameStrata("HIGH")
local enabled, sequence = true, 0
local tracked = {}
local displayStats = { received = 0, shown = 0, skipped = 0, last = "none" }
local function skipped(reason)
    displayStats.skipped = displayStats.skipped + 1
    displayStats.last = reason
end
local labels = {}
for i = 1, 64 do
    local text = live:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 24, "OUTLINE")
    text:Hide()
    labels[i] = { text = text, age = 0, active = false }
end
live:Hide()
local function unitPosition(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil, nil, nil, "nameplate API unavailable" end
    local ok, plate, reason = pcall(function()
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if not plate then return nil, "no nameplate (enable enemy nameplates with V)" end
        if plate:IsForbidden() then return nil, "nameplate forbidden" end
        if not plate:IsVisible() then return nil, "nameplate hidden" end
        return plate
    end)
    if not ok then return nil, nil, nil, "nameplate lookup or visibility restricted" end
    if not plate then return nil, nil, nil, reason end
    local positioned, x, y = pcall(function()
        local px = plate:GetCenter()
        local py = plate:GetTop()
        local plateScale, uiScale = plate:GetEffectiveScale(), UIParent:GetEffectiveScale()
        if secret(px) or secret(py) or secret(plateScale) or secret(uiScale) then return end
        if type(px) ~= "number" or type(py) ~= "number"
            or type(plateScale) ~= "number" or type(uiScale) ~= "number" or uiScale <= 0 then return end
        return px * plateScale / uiScale, py * plateScale / uiScale
    end)
    if positioned and x and y then return x, y end
    -- Geometry can be secret even when a nameplate is accessible. Anchor to
    -- the frame directly without reading or doing arithmetic on its position.
    return nil, nil, plate
end

local function positionLabel(label)
    label.text:ClearAllPoints()
    if label.anchor then
        if label.anchor:IsForbidden() or not label.anchor:IsVisible() then return false end
        label.text:SetPoint("CENTER", label.anchor, "TOP", label.x, label.y + label.age * 12)
    else
        -- Snapshot when readable: old hits remain at their impact position.
        label.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", label.x, label.y + label.age * 12)
    end
    local scale
    if label.age < 0.08 then
        scale = 0.85 + 0.65 * label.age / 0.08
    elseif label.age < 0.24 then
        scale = 1.50 - 0.50 * (label.age - 0.08) / 0.16
    else
        scale = 1
    end
    label.text:SetFont(STANDARD_TEXT_FONT, 24 * scale, "OUTLINE")
    label.text:SetAlpha(math.min(1, (1.0 - label.age) / 0.3))
    return true
end
live:SetScript("OnUpdate", function(self, elapsed)
    local any = false
    for _, label in ipairs(labels) do
        if label.active then
            label.age = label.age + elapsed
            if label.age >= 1.0 then
                label.active = false
                label.text:Hide()
            else
                any = true
                local ok, positioned = pcall(positionLabel, label)
                if not ok or not positioned then
                    label.active = false
                    label.text:Hide()
                    skipped("active nameplate anchor unavailable")
                end
            end
        end
    end
    if not any then self:Hide() end
end)

local function handleDamage(unit, event, flags, amount, school)
    displayStats.received = displayStats.received + 1
    if not enabled then skipped("overlay disabled"); return end
    if secret(unit) or secret(event) or secret(school) or secret(amount) then skipped("secret event data"); return end
    if event ~= "WOUND" then return end
    local record = tracked[unit]
    if record and record.attackable == false then return end
    if unit ~= "target" and (not record or not record.active) then return end
    if unit == "target" and C_NamePlate then
        -- A target alias and its nameplate token can report the same hit.
        -- Prefer the nameplate subscription; never deduplicate by hit amount.
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        if ok and plate then
            for _, entry in pairs(tracked) do
                if entry.active and entry.plate == plate then return end
            end
        end
    end
    if type(school) ~= "number" or school < 0 then return end
    if type(amount) ~= "number" or amount <= 0 then return end
    local x, y, anchor, reason = unitPosition(unit)
    if not anchor and (not x or not y) then skipped(reason); return end
    sequence = sequence + 1
    local label = labels[(sequence - 1) % #labels + 1]
    label.age, label.active, label.school = 0, true, school
    label.anchor, label.unit = anchor, unit
    label.x = (x or 0) + ((sequence - 1) % 3 - 1) * 36
    label.y = (y or 0) + 36 + ((sequence - 1) % 2) * 18
    label.text:SetText(tostring(amount))
    label.text:SetTextColor(addon.GetColor(school))
    local ok, positioned = pcall(positionLabel, label)
    if not ok or not positioned then
        label.active = false
        label.text:Hide()
        skipped("cannot anchor damage label")
        return
    end
    displayStats.shown = displayStats.shown + 1
    label.text:Show()
    live:Show()
end

local function trackUnit(unit)
    if secret(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local record = tracked[unit]
    if not record then
        record = { listener = CreateFrame("Frame") }
        tracked[unit] = record
        record.listener:SetScript("OnEvent", function(_, _, ...)
            handleDamage(...)
        end)
    end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    record.plate = ok and plate or nil
    record.attackable = nil
    if UnitCanAttack then
        local readable, attackable = pcall(UnitCanAttack, "player", unit)
        if readable and not secret(attackable) then record.attackable = attackable end
    end
    record.active = true
    record.listener:RegisterUnitEvent("UNIT_COMBAT", unit)
end

local damageEvents = CreateFrame("Frame")
damageEvents:RegisterUnitEvent("UNIT_COMBAT", "target")
damageEvents:RegisterEvent("NAME_PLATE_UNIT_ADDED")
damageEvents:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
damageEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
damageEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
damageEvents:SetScript("OnEvent", function(_, eventName, unit, ...)
    if eventName == "UNIT_COMBAT" then
        handleDamage(unit, ...)
    elseif eventName == "NAME_PLATE_UNIT_ADDED" then
        trackUnit(unit)
    elseif eventName == "NAME_PLATE_UNIT_REMOVED" and not secret(unit) then
        local record = tracked[unit]
        if record then
            record.active = false
            record.listener:UnregisterEvent("UNIT_COMBAT")
            record.plate = nil
        end
        for _, label in ipairs(labels) do
            if label.anchor and label.unit == unit then
                label.active = false; label.text:Hide(); label.anchor = nil
            end
        end
    elseif eventName == "PLAYER_TARGET_CHANGED" then
        -- Only legacy target-anchored hits depend on the selected target.
        for _, label in ipairs(labels) do
            if label.anchor and label.unit == "target" then
                label.active = false; label.text:Hide(); label.anchor = nil
            end
        end
    elseif eventName == "PLAYER_ENTERING_WORLD" and C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local readable, token = pcall(function() return plate.namePlateUnitToken end)
                if readable then trackUnit(token) end
            end
        end
    end
end)

local preview = CreateFrame("Frame", nil, UIParent)
preview:SetSize(360, 300)
preview:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
preview:Hide()
local samples = {
    { "Auto-attack (overlay)", 1 },
    { "Physical skill / bleed", 1 },
    { "Arcane", 64 }, { "Fire", 4 }, { "Shadow", 32 },
    { "Frost", 16 }, { "Nature", 8 }, { "Holy", 2 },
    { "Other / mixed school", 20 },
}
local previewLabels = {}
for i, sample in ipairs(samples) do
    local text = preview:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
    text:SetPoint("TOP", preview, "TOP", 0, -(i - 1) * 30)
    text:SetText(sample[1] .. "  123")
    text:SetTextColor(addon.GetColor(sample[2], sample[3]))
    previewLabels[i] = text
end
function addon.RefreshDisplayColors()
    for i, sample in ipairs(samples) do
        previewLabels[i]:SetTextColor(addon.GetColor(sample[2], sample[3]))
    end
    for _, label in ipairs(labels) do
        if label.active then label.text:SetTextColor(addon.GetColor(label.school)) end
    end
end
local previewTime = 0
function addon.ShowPreview()
    previewTime = 0
    preview:Show()
end
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
    if command == "" or command == "config" or command == "settings" then
        addon.OpenSettings()
    elseif command == "preview" then
        addon.ShowPreview()
        say("Synthetic palette preview for 10 seconds; physical includes auto-attacks.")
    elseif command == "on" then
        enabled = true
        say("Damage overlay enabled (all attackers on visible enemy nameplates).")
    elseif command == "off" then
        enabled = false
        for _, label in ipairs(labels) do
            label.active = false
            label.text:Hide()
        end
        live:Hide()
        say("Damage overlay disabled.")
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
        say("Nameplate overlay=" .. (enabled and "on" or "off") .. "; physical includes auto-attacks; native text unchanged.")
        local count = 0
        for _, record in pairs(tracked) do if record.active then count = count + 1 end end
        say("Tracked nameplates=" .. count)
        say("Live events=" .. displayStats.received .. "; shown=" .. displayStats.shown .. "; skipped=" .. displayStats.skipped)
        say("Last display skip: " .. displayStats.last)
        say("Target events=" .. received .. "; events containing secrets=" .. restricted)
        local keys = {}
        for key in pairs(buckets) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do say(buckets[key] .. " x " .. key) end
    else
        say("/dc settings | /dc on | /dc off | /dc preview | /dc watch | /dc stop | /dc report")
        say("Overlay includes all attackers on visible enemy nameplates. Native text unchanged.")
    end
end
