local addonName, addon = ...

-- Exact masks only: hybrids use the configurable fallback (key 0).
local defaults = {
    [0] = { 1, 1, 0 },
    [1] = { 1, 0.20, 0.20 },
    [2] = { 1, 0.95, 0.60 },
    [4] = { 1, 0.50, 0.10 },
    [8] = { 0.25, 1, 0.30 },
    [16] = { 0.55, 0.85, 1 },
    [32] = { 0.45, 0.35, 0.85 },
    [64] = { 0.85, 0.40, 1 },
}
addon.colors = {}
addon.fonts = {
    { key = "default", name = "Game default", path = STANDARD_TEXT_FONT },
    { key = "friz", name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "arial", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { key = "skurri", name = "Skurri", path = "Fonts\\skurri.ttf" },
}
addon.appearance = { font = "default", size = 48 }
addon.hideBlizzardDamage = true
local function fontInfo(key)
    for _, font in ipairs(addon.fonts) do if font.key == key then return font end end
end
local function validSize(size)
    return type(size) == "number" and size == size and size >= 12 and size <= 96
end
function addon.GetFont()
    return fontInfo(addon.appearance.font) or addon.fonts[1]
end
function addon.ApplyFont(text, size)
    if text:SetFont(addon.GetFont().path, size, "OUTLINE") == false then
        text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    end
end
function addon.SetAppearance(font, size)
    if not fontInfo(font) or not validSize(size) then return end
    size = math.floor(size + 0.5)
    if addon.appearance.font == font and addon.appearance.size == size then return end
    addon.appearance.font, addon.appearance.size = font, size
    if DamageColorDB then DamageColorDB.appearance = { font = font, size = size } end
    if addon.OnAppearanceChanged then addon.OnAppearanceChanged() end
end
local function copy(color) return { color[1], color[2], color[3] } end
local function valid(color)
    if type(color) ~= "table" then return false end
    for i = 1, 3 do
        local value = color[i]
        if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return false end
    end
    return true
end
for school, color in pairs(defaults) do addon.colors[school] = copy(color) end

function addon.SetColor(school, r, g, b)
    local color = { r, g, b }
    if not defaults[school] or not valid(color) then return end
    addon.colors[school] = color
    if DamageColorDB then DamageColorDB.colors[school] = copy(color) end
    if addon.OnPaletteChanged then addon.OnPaletteChanged() end
end

function addon.ResetColors()
    for school, color in pairs(defaults) do
        addon.colors[school] = copy(color)
        if DamageColorDB then DamageColorDB.colors[school] = copy(color) end
    end
    if addon.OnPaletteChanged then addon.OnPaletteChanged() end
end

-- SavedVariables are available only after this addon's ADDON_LOADED event.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    if type(DamageColorDB) ~= "table" then DamageColorDB = {} end
    if type(DamageColorDB.colors) ~= "table" then DamageColorDB.colors = {} end
    for school, default in pairs(defaults) do
        local color = DamageColorDB.colors[school]
        addon.colors[school] = copy(valid(color) and color or default)
        DamageColorDB.colors[school] = copy(addon.colors[school])
    end
    local appearance = type(DamageColorDB.appearance) == "table" and DamageColorDB.appearance or {}
    addon.appearance.font = fontInfo(appearance.font) and appearance.font or "default"
    addon.appearance.size = validSize(appearance.size) and math.floor(appearance.size + 0.5) or 48
    DamageColorDB.appearance = { font = addon.appearance.font, size = addon.appearance.size }
    if type(DamageColorDB.hideBlizzardDamage) ~= "boolean" then DamageColorDB.hideBlizzardDamage = true end
    addon.hideBlizzardDamage = DamageColorDB.hideBlizzardDamage
    addon.ApplyNativeDamageSetting()
    if addon.OnNativeDamageChanged then addon.OnNativeDamageChanged() end
    if addon.OnPaletteChanged then addon.OnPaletteChanged() end
    if addon.OnAppearanceChanged then addon.OnAppearanceChanged() end
    self:UnregisterEvent("ADDON_LOADED")
end)
