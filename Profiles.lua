local addonName, addon = ...
local profiles = {}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function snapshot()
    return copy({ colors = addon.colors, textStyles = addon.textStyles,
        disableDamageDealtInInstances = addon.disableDamageDealtInInstances,
        disableDamageTakenInInstances = addon.disableDamageTakenInInstances,
        showDamageDealt = addon.showDamageDealt, showDamageTaken = addon.showDamageTaken,
        appearance = addon.appearance, hideBlizzardDamage = addon.hideBlizzardDamage,
        damageTaken = addon.damageTaken, hideBlizzardDamageTaken = addon.hideBlizzardDamageTaken })
end
local function normalize(profile)
    local result = addon.GetDefaultProfile()
    if type(profile) ~= "table" then return result end
    local function number(value, low, high)
        return type(value) == "number" and value == value and value >= low and value <= high
    end
    local function color(value)
        return type(value) == "table" and number(value[1], 0, 1)
            and number(value[2], 0, 1) and number(value[3], 0, 1)
    end
    for school in pairs(result.colors) do
        local c = type(profile.colors) == "table" and profile.colors[school]
        if color(c) then result.colors[school] = { c[1], c[2], c[3] } end
        local s = type(profile.textStyles) == "table" and profile.textStyles[school]
        if type(s) == "table" and (s.mode == "none" or s.mode == "outline" or s.mode == "glow")
            and number(s.thickness, 1, 6) and color(s.color) then
            result.textStyles[school] = { mode = s.mode, thickness = s.thickness,
                color = { s.color[1], s.color[2], s.color[3] } }
        end
    end
    local appearance = type(profile.appearance) == "table" and profile.appearance or {}
    for _, font in ipairs(addon.fonts) do
        if font.key == appearance.font then result.appearance.font = font.key end
    end
    if number(appearance.size, 12, 96) then result.appearance.size = math.floor(appearance.size + 0.5) end
    if type(profile.hideBlizzardDamage) == "boolean" then result.hideBlizzardDamage = profile.hideBlizzardDamage end
    result.damageTaken = addon.NormalizeDamageTaken(profile.damageTaken, result.appearance.size)
    if type(profile.hideBlizzardDamageTaken) == "boolean" then result.hideBlizzardDamageTaken = profile.hideBlizzardDamageTaken end
    for _, key in ipairs({ "showDamageDealt", "showDamageTaken", "disableDamageDealtInInstances", "disableDamageTakenInInstances" }) do
        if type(profile[key]) == "boolean" then result[key] = profile[key] end
    end
    return result
end
function addon.GetProfileNames()
    local names = {}
    for name in pairs(profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        if a == "Default" then return b ~= "Default" end
        if b == "Default" then return false end
        return a < b
    end)
    return names
end
function addon.GetProfile(name)
    return profiles[name] and copy(profiles[name])
end
function addon.ProfileIsDirty()
    return not same(snapshot(), profiles[addon.activeProfile])
end
function addon.SaveProfile(name)
    if type(name) ~= "string" then return false, "Enter a profile name." end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or #name > 40 or name:find("[%c|]") then
        return false, "Use a name of 1–40 characters without control characters or |."
    end
    if name == "Default" then return false, "Default is fixed. Save under another name." end
    profiles[name] = snapshot()
    addon.activeProfile = name
    DamageColorDB.activeProfile = name
    if addon.OnProfilesChanged then addon.OnProfilesChanged() end
    return true, "Saved profile: " .. name
end
function addon.LoadProfile(name)
    local profile = profiles[name]
    if not profile then return false end
    local data = copy(profile)
    -- Setters validate profile values and refresh the live display/menu.
    for school, color in pairs(data.colors) do addon.SetColor(school, unpack(color)) end
    for school, style in pairs(data.textStyles) do
        addon.SetTextStyle(school, style.mode, style.thickness, unpack(style.color))
    end
    addon.SetAppearance(data.appearance.font, data.appearance.size)
    addon.SetDamageNumbersVisible(false, data.showDamageDealt)
    addon.SetDamageNumbersVisible(true, data.showDamageTaken)
    addon.SetDisableDamageInInstances(false, data.disableDamageDealtInInstances)
    addon.SetDisableDamageInInstances(true, data.disableDamageTakenInInstances)
    addon.SetDamageTaken(data.damageTaken.size, data.damageTaken.x, data.damageTaken.y)
    addon.SetHideBlizzardDamageTaken(data.hideBlizzardDamageTaken)
    addon.SetHideBlizzardDamage(data.hideBlizzardDamage)
    addon.activeProfile, DamageColorDB.activeProfile = name, name
    if addon.OnProfilesChanged then addon.OnProfilesChanged() end
    return true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    if type(DamageColorDB.profiles) ~= "table" then DamageColorDB.profiles = {} end
    profiles = DamageColorDB.profiles
    for key, profile in pairs(profiles) do
        if type(key) ~= "string" or #key < 1 or #key > 40 or key:find("[%c|]") then
            profiles[key] = nil
        else
            profiles[key] = normalize(profile)
        end
    end
    -- Default is always the factory style; seed custom presets only once.
    profiles.Default = addon.GetDefaultProfile()
    for presetName, preset in pairs(addon.bundledProfiles) do
        if type(profiles[presetName]) ~= "table" then profiles[presetName] = normalize(preset) end
    end
    addon.activeProfile = type(DamageColorDB.activeProfile) == "string"
        and profiles[DamageColorDB.activeProfile] and DamageColorDB.activeProfile
        or (same(snapshot(), profiles["Power Glow"]) and "Power Glow" or "Default")
    DamageColorDB.activeProfile = addon.activeProfile
    -- Preserve existing working settings on upgrade and across reloads.
    if addon.OnProfilesChanged then addon.OnProfilesChanged() end
    self:UnregisterEvent("ADDON_LOADED")
end)
