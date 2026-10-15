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

-- School-colored overlay; native text visibility is controlled in settings.
-- UNIT_COMBAT has no attacker identity, so this includes all attackers.
local live = CreateFrame("Frame", nil, UIParent)
live:SetAllPoints(UIParent)
live:SetFrameStrata("HIGH")
local enabled, sequence = true, 0
local tracked = {}
local labelLifetime, removalGrace = 1.8, 0.5
local displayStats = { received = 0, shown = 0, skipped = 0, last = "none" }
local watching = false
local traceLog = {}
local function trace(kind, unit, detail)
    if not watching then return end
    local function safe(value)
        if secret(value) then return "<secret>" end
        if type(value) == "string" or type(value) == "number" then return tostring(value) end
        return "-"
    end
    local time = GetTime and string.format("%.3f", GetTime()) or "-"
    if #traceLog >= 60 then table.remove(traceLog, 1) end
    traceLog[#traceLog + 1] = time .. " " .. kind .. " " .. safe(unit) .. " " .. safe(detail)
end
local function skipped(reason)
    displayStats.skipped = displayStats.skipped + 1
    displayStats.last = reason
    trace("SKIP", nil, reason)
end
local labels = {}
for i = 1, 64 do
    local text = live:CreateFontString(nil, "OVERLAY")
    addon.ApplyFont(text, addon.appearance.size)
    text:Hide()
    labels[i] = { text = text, age = 0, active = false }
end
live:Hide()
local function readPlatePosition(plate)
    local ok, x, y = pcall(function()
        if plate:IsForbidden() then return end
        local px = plate:GetCenter()
        local py = plate:GetTop()
        local plateScale, uiScale = plate:GetEffectiveScale(), UIParent:GetEffectiveScale()
        if secret(px) or secret(py) or secret(plateScale) or secret(uiScale) then return end
        if type(px) ~= "number" or type(py) ~= "number"
            or type(plateScale) ~= "number" or type(uiScale) ~= "number" or uiScale <= 0 then return end
        return px * plateScale / uiScale, py * plateScale / uiScale
    end)
    if ok then return x, y end
end
local function unitPosition(unit)
    local record = tracked[unit]
    if record and record.draining then
        if record.lastX and record.lastY then return record.lastX, record.lastY end
        return nil, nil, record.plate, "killing-blow anchor unavailable"
    end
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
    local x, y = readPlatePosition(plate)
    if x and y then
        if record then record.lastX, record.lastY = x, y end
        return x, y
    end
    -- Geometry can be secret even when a nameplate is accessible. Anchor to
    -- the frame directly without reading or doing arithmetic on its position.
    return nil, nil, plate
end

-- Reserve the settled size with a little breathing room. Brief peak pops may
-- touch, keeping sustained bursts compact rather than spreading across the screen.
-- Frame-relative labels can be compared without reading protected geometry.
local function outgoingCeiling(label)
    if label.incoming then return end
    local ok, ceiling = pcall(function()
        local height = UIParent:GetHeight()
        if secret(height) or type(height) ~= "number" or height <= 0 then return end
        local anchorY = 0
        if label.anchor then
            local _, y = readPlatePosition(label.anchor)
            if not y then return end
            anchorY = y
        end
        local style = addon.GetTextStyle(label.school)
        local edge = style.mode == "none" and 0 or style.thickness * (style.mode == "glow" and 1.95 or 1)
        -- Reserve the peak pop height throughout the animation so the ceiling
        -- stays steady as text grows, settles, and drifts upward.
        return height - anchorY - (label.peakHeight or label.baseSize * 1.5) / 2 - edge - 8
    end)
    if ok then return ceiling end
end

local function placeWithoutOverlap(label)
    addon.ApplyFont(label.text, label.baseSize * 1.1)
    label.peakHeight = label.text:GetStringHeight() / 1.1 * 1.5
    local style = addon.GetTextStyle(label.school)
    local padding = 4 + (style.mode == "none" and 0 or style.thickness * 4)
    label.width = label.text:GetStringWidth() + padding
    label.height = label.text:GetStringHeight() + padding
    local originX, originY = label.x, label.y
    local bestX, bestY, bestOverlap
    local candidates = {}
    local ceiling = outgoingCeiling(label)
    for row = 0, 14 do
        for _, lane in ipairs({ 0, -1, 1, -2, 2, -3, 3, -4, 4 }) do
            local dx, dy = lane * label.width * 0.5, row * label.height * 0.5
            local y = originY + dy
            if ceiling then y = math.min(y, ceiling) end
            candidates[#candidates + 1] = { x = originX + dx, y = y,
                distance = dx * dx + dy * dy, order = #candidates + 1 }
        end
    end
    table.sort(candidates, function(a, b)
        if a.distance == b.distance then return a.order < b.order end
        return a.distance < b.distance
    end)
    for _, candidate in ipairs(candidates) do
            local x, y = candidate.x, candidate.y
            local overlap = 0
            for _, other in ipairs(labels) do
                if other ~= label and other.active and other.anchor == label.anchor and other.incoming == label.incoming then
                    local dx = math.abs(x - other.x)
                    local otherY = other.y + other.age * 12
                    local otherCeiling = outgoingCeiling(other)
                    if otherCeiling then otherY = math.min(otherY, otherCeiling) end
                    local dy = math.abs(y - otherY)
                    local width = (label.width + other.width) / 2 - dx
                    local height = (label.height + other.height) / 2 - dy
                    if width > 0 and height > 0 then overlap = overlap + width * height end
                end
            end
            if not bestOverlap or overlap < bestOverlap then
                bestX, bestY, bestOverlap = x, y, overlap
            end
            if overlap == 0 then label.x, label.y = x, y; return end
    end
    label.x, label.y = bestX, bestY
end

local function positionLabel(label)
    label.text:ClearAllPoints()
    if label.anchor then
        if label.anchor:IsForbidden() then return false end
        if not label.anchor:IsVisible() then
            local record = tracked[label.unit]
            if record and record.lastX and record.lastY then
                label.x, label.y = record.lastX + label.x, record.lastY + label.y
                label.anchor = nil
            else
                -- Hidden anchors do not hide our text: its parent is `live`,
                -- not the nameplate. Keep the existing anchor without reading
                -- secret coordinates, and discard it only if the plate is reused.
                label.retired = true
            end
        end
    end
    local y = label.y + label.age * 12
    local ceiling = outgoingCeiling(label)
    if ceiling then y = math.min(y, ceiling) end
    if label.incoming then
        label.text:SetPoint("CENTER", UIParent, "CENTER", label.x + addon.damageTaken.x, label.y + addon.damageTaken.y + label.age * 12)
    elseif label.anchor then
        label.text:SetPoint("CENTER", label.anchor, "TOP", label.x, y)
    else
        -- Snapshot when readable: old hits remain at their impact position.
        label.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", label.x, y)
    end
    local scale
    if label.age < 0.08 then
        scale = 0.85 + 0.65 * label.age / 0.08
    elseif label.age < 0.24 then
        scale = 1.50 - 0.50 * (label.age - 0.08) / 0.16
    else
        scale = 1
    end
    addon.ApplyFont(label.text, label.baseSize * scale)
    local alpha = math.min(1, (labelLifetime - label.age) / 0.4)
    label.text:SetAlpha(alpha)
    addon.UpdateTextEffect(label.text, label.school, label.baseSize * scale, alpha)
    return true
end
live:SetScript("OnUpdate", function(self, elapsed)
    local any = false
    for _, label in ipairs(labels) do
        if label.active then
            label.age = label.age + elapsed
            if label.age >= labelLifetime then
                label.active = false
                addon.HideDamageText(label.text)
            else
                any = true
                local ok, positioned = pcall(positionLabel, label)
                if not ok or not positioned then
                    label.active = false
                    addon.HideDamageText(label.text)
                    skipped("active nameplate anchor unavailable")
                end
            end
        end
    end
    if not any then self:Hide() end
end)

local outcomes = { MISS = "Miss", RESIST = "Resisted" }
local function handleDamage(unit, event, flags, amount, school)
    trace("LIVE_EVENT", unit, event)
    trace("FLAGS", unit, flags)
    displayStats.received = displayStats.received + 1
    if not enabled then skipped("overlay disabled"); return end
    if secret(unit) or secret(event) then skipped("secret event data"); return end
    local outcome = outcomes[event]
    if event ~= "WOUND" and not outcome then return end
    if not outcome and (secret(school) or secret(amount)) then skipped("secret event data"); return end
    local incoming = unit == "player"
    local record = tracked[unit]
    if record and record.attackable == false then return end
    if not incoming and unit ~= "target" and (not record or (not record.active and not record.draining)) then return end
    if unit == "target" and C_NamePlate then
        -- A target alias and its nameplate token can report the same hit.
        -- Prefer the nameplate subscription; never deduplicate by hit amount.
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        if ok and plate then
            for _, entry in pairs(tracked) do
                if entry.active and entry.plate == plate then
                    trace("ALIAS_SKIPPED", unit, "waiting for nameplate event")
                    return
                end
            end
        end
    end
    if outcome then
        school = -1
    else
        if type(school) ~= "number" or school < 0 then return end
        if type(amount) ~= "number" or amount <= 0 then return end
    end
    local x, y, anchor, reason
    if incoming then x, y = 0, 0 else x, y, anchor, reason = unitPosition(unit) end
    if not anchor and (not x or not y) then skipped(reason); return end
    sequence = sequence + 1
    local label = labels[(sequence - 1) % #labels + 1]
    label.age, label.active, label.school = 0, true, school
    local critical = not outcome and not secret(flags) and flags == "CRITICAL"
    label.critical = critical
    label.incoming = incoming
    label.baseSize = (incoming and addon.damageTaken.size or addon.appearance.size) * (critical and 2 or 1)
    label.anchor, label.unit = anchor, unit
    label.retired = record and record.draining or false
    label.x = (x or 0) + ((sequence - 1) % 3 - 1) * 36
    label.y = (y or 0) + label.baseSize * 0.75 + ((sequence - 1) % 2) * 18
    label.text:SetText(outcome or tostring(amount))
    label.text:SetTextColor(addon.GetColor(school))
    local ok, positioned = pcall(function()
        placeWithoutOverlap(label)
        return positionLabel(label)
    end)
    if not ok or not positioned then
        label.active = false
        addon.HideDamageText(label.text)
        skipped("cannot anchor damage label")
        return
    end
    displayStats.shown = displayStats.shown + 1
    trace("SHOWN", unit, school)
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
    record.generation = (record.generation or 0) + 1
    record.draining = false
    record.lastX, record.lastY = nil, nil
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate then
        for _, label in ipairs(labels) do
            if label.active and label.retired and label.anchor == plate then
                label.active = false
                addon.HideDamageText(label.text)
                label.anchor = nil
                trace("REUSED_ANCHOR_CLEARED", unit)
            end
        end
    end
    record.plate = ok and plate or nil
    record.attackable = nil
    if UnitCanAttack then
        local readable, attackable = pcall(UnitCanAttack, "player", unit)
        if readable and not secret(attackable) then record.attackable = attackable end
    end
    record.active = true
    record.listener:RegisterUnitEvent("UNIT_COMBAT", unit)
    unitPosition(unit) -- Cache the position before combat can restrict geometry.
end

local incomingEvents = CreateFrame("Frame")
incomingEvents:RegisterUnitEvent("UNIT_COMBAT", "player")
incomingEvents:SetScript("OnEvent", function(_, _, ...) handleDamage(...) end)

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
        trace("PLATE_ADDED", unit)
        trackUnit(unit)
    elseif eventName == "NAME_PLATE_UNIT_REMOVED" and not secret(unit) then
        trace("PLATE_REMOVED", unit)
        local record = tracked[unit]
        if record then
            -- A hidden plate can still expose its final coordinates.
            if record.plate then
                local x, y = readPlatePosition(record.plate)
                if x and y then record.lastX, record.lastY = x, y end
            end
            record.active = false
            record.draining = true
            local generation = record.generation
            -- Killing blows can arrive just after NAME_PLATE_UNIT_REMOVED.
            C_Timer.After(removalGrace, function()
                if record.generation ~= generation or record.active then return end
                record.draining = false
                record.listener:UnregisterEvent("UNIT_COMBAT")
                record.plate = nil
                trace("LISTENER_STOPPED", unit, "grace period elapsed")
            end)
        end
        for _, label in ipairs(labels) do
            if label.active and label.anchor and label.unit == unit then
                if record and record.lastX and record.lastY then
                    label.x, label.y = record.lastX + label.x, record.lastY + label.y
                    label.anchor = nil
                    -- Detach immediately, before the hidden plate is recycled.
                    local ok, positioned = pcall(positionLabel, label)
                    if not ok or not positioned then label.active = false; addon.HideDamageText(label.text) end
                else
                    label.retired = true
                    trace("RETAINED_HIDDEN_ANCHOR", unit, "coordinates unavailable")
                end
            end
        end
    elseif eventName == "PLAYER_TARGET_CHANGED" then
        trace("TARGET_CHANGED", "target")
        -- Changing the selected unit does not invalidate the old frame anchor.
        for _, label in ipairs(labels) do
            if label.anchor and label.unit == "target" then
                label.retired = true
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
local positionPoll = 0
damageEvents:SetScript("OnUpdate", function(_, elapsed)
    positionPoll = positionPoll + elapsed
    if positionPoll < 0.1 then return end
    positionPoll = 0
    for unit, record in pairs(tracked) do
        if record.active then unitPosition(unit) end
    end
end)

local preview = CreateFrame("Frame", nil, UIParent)
preview:SetSize(720, 560)
preview:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
preview:Hide()
local samples = {
    { "Auto-attack (overlay)", 1 },
    { "Physical skill / bleed", 1 },
    { "Arcane", 64 }, { "Fire", 4 }, { "Shadow", 32 },
    { "Frost", 16 }, { "Nature", 8 }, { "Holy", 2 },
    { "Frostfire", 20 },
    { "Other / mixed school", 6 },
}
local previewLabels = {}
for i, sample in ipairs(samples) do
    local text = preview:CreateFontString(nil, "OVERLAY")
    addon.ApplyFont(text, addon.appearance.size)
    text:SetPoint("TOP", preview, "TOP", 0, -(i - 1) * 60)
    text:SetText(sample[1] .. "  123")
    text:SetTextColor(addon.GetColor(sample[2], sample[3]))
    addon.UpdateTextEffect(text, sample[2], addon.appearance.size, 1)
    previewLabels[i] = text
end
function addon.RefreshDisplayColors()
    for i, sample in ipairs(samples) do
        previewLabels[i]:SetTextColor(addon.GetColor(sample[2], sample[3]))
        addon.UpdateTextEffect(previewLabels[i], sample[2], addon.appearance.size, 1)
    end
    for _, label in ipairs(labels) do
        if label.active then label.text:SetTextColor(addon.GetColor(label.school)) end
    end
end
function addon.RefreshTextAppearance()
    local spacing = addon.appearance.size * 1.25
    preview:SetSize(720, #samples * spacing)
    for i, text in ipairs(previewLabels) do
        addon.ApplyFont(text, addon.appearance.size)
        addon.UpdateTextEffect(text, samples[i][2], addon.appearance.size, 1)
        text:ClearAllPoints()
        text:SetPoint("TOP", preview, "TOP", 0, -(i - 1) * spacing)
    end
    for _, label in ipairs(labels) do
        if label.active then
            local oldSize = label.baseSize
            label.baseSize = (label.incoming and addon.damageTaken.size or addon.appearance.size) * (label.critical and 2 or 1)
            label.y = label.y + (label.baseSize - oldSize) * 0.75
            local ok, positioned = pcall(positionLabel, label)
            if not ok or not positioned then label.active = false; addon.HideDamageText(label.text) end
        end
    end
end
function addon.ShowDamageTakenPreview()
    handleDamage("player", "WOUND", "", 123, 1)
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
local generation = 0
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
    trace("RAW_TARGET", unit, event)
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
    elseif command == "meter" then
        addon.ProbeDamageMeter(say)
    elseif command == "on" then
        enabled = true
        addon.overlayEnabled = true
        addon.ApplyNativeDamageTakenSetting()
        addon.ApplyNativeDamageSetting()
        say("Damage overlay enabled (all attackers on visible enemy nameplates).")
    elseif command == "off" then
        enabled = false
        addon.overlayEnabled = false
        addon.ApplyNativeDamageTakenSetting()
        addon.ApplyNativeDamageSetting()
        for _, label in ipairs(labels) do
            label.active = false
            addon.HideDamageText(label.text)
        end
        live:Hide()
        say("Damage overlay disabled.")
    elseif command == "watch" then
        buckets, received, restricted = {}, 0, 0
        traceLog = {}
        generation = generation + 1
        local current = generation
        watching = true
        watcher:RegisterUnitEvent("UNIT_COMBAT", "target")
        say("Tracing target events, live nameplate events, and removal order for 20 seconds. Kill one enemy, then /dc report.")
        C_Timer.After(20, function()
            if watching and generation == current then stop() end
        end)
    elseif command == "stop" then
        stop()
    elseif command == "report" then
        local version, build, _, interface = GetBuildInfo()
        say("Client " .. version .. " / " .. build .. " / interface " .. interface)
        say("Nameplate overlay=" .. (enabled and "on" or "off") .. "; physical includes auto-attacks.")
        say("Blizzard damage: " .. addon.nativeDamageStatus)
        say("Blizzard damage taken: " .. addon.nativeDamageTakenStatus)
        local count = 0
        for _, record in pairs(tracked) do if record.active then count = count + 1 end end
        say("Tracked nameplates=" .. count)
        say("Live events=" .. displayStats.received .. "; shown=" .. displayStats.shown .. "; skipped=" .. displayStats.skipped)
        say("Last display skip: " .. displayStats.last)
        say("Target events=" .. received .. "; events containing secrets=" .. restricted)
        say("Combat-log probe disabled: the client blocked its Blizzard-only event registration.")
        local keys = {}
        for key in pairs(buckets) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do say(buckets[key] .. " x " .. key) end
        if #traceLog > 0 then
            say("Recent event order (no damage amounts recorded):")
            for _, line in ipairs(traceLog) do say(line) end
        end
    else
        say("/dc settings | /dc on | /dc off | /dc preview | /dc watch | /dc stop | /dc report | /dc meter")
        say("Overlay includes all attackers on visible enemy nameplates.")
    end
end
