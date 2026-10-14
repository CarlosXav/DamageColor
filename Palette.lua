local addonName, addon = ...

-- Exact masks only: hybrids use the configurable fallback (key 0).
local defaults = {
    [0] = { 1, 1, 0 },
    [1] = { 1, 0.20, 0.20 },
    [2] = { 1, 0.95, 0.60 },
    [4] = { 1, 0.50, 0.10 },
    [8] = { 0.25, 1, 0.30 },
    [16] = { 0.55, 0.85, 1 },
    [20] = { 0.55, 0.85, 1 }, -- Frostfire: frost center, fire outline.
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
    if text:SetFont(addon.GetFont().path, size, "") == false then
        text:SetFont(STANDARD_TEXT_FONT, size, "")
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
addon.textStyles = {}
local function defaultStyle(school)
    if school == 20 then return { mode = "outline", thickness = 1.5, color = { 1, 0.50, 0.10 } } end
    return { mode = "none", thickness = 1.5, color = { 1, 1, 1 } }
end
local function validStyle(style)
    return type(style) == "table" and (style.mode == "none" or style.mode == "outline" or style.mode == "glow")
        and type(style.thickness) == "number" and style.thickness >= 1 and style.thickness <= 6
        and valid(style.color)
end
local function copyStyle(style)
    return { mode = style.mode, thickness = style.thickness, color = copy(style.color) }
end
for school in pairs(defaults) do addon.textStyles[school] = defaultStyle(school) end
function addon.GetTextStyle(school) return addon.textStyles[school] or addon.textStyles[0] end
function addon.SetTextStyle(school, mode, thickness, r, g, b)
    local style = { mode = mode, thickness = thickness, color = { r, g, b } }
    if not defaults[school] or not validStyle(style) then return end
    local old = addon.textStyles[school]
    if old.mode == mode and old.thickness == thickness and old.color[1] == r and old.color[2] == g and old.color[3] == b then return end
    addon.textStyles[school] = style
    if DamageColorDB then DamageColorDB.textStyles[school] = copyStyle(style) end
    if addon.OnTextStyleChanged then addon.OnTextStyleChanged() end
end
function addon.ResetTextStyle(school)
    local style = defaultStyle(school)
    addon.SetTextStyle(school, style.mode, style.thickness, unpack(style.color))
end

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
    if type(DamageColorDB.textStyles) ~= "table" then DamageColorDB.textStyles = {} end
    if DamageColorDB.frostfireDefaultsVersion ~= 1 then
        local function sameColor(a, b)
            return valid(a) and valid(b) and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
        end
        local oldColor = DamageColorDB.colors[20]
        if sameColor(oldColor, { 1, 1, 0 }) or sameColor(oldColor, DamageColorDB.colors[0]) then
            DamageColorDB.colors[20] = nil
        end
        local oldStyle, other = DamageColorDB.textStyles[20], DamageColorDB.textStyles[0]
        if validStyle(oldStyle) and ((oldStyle.mode == "none" and oldStyle.thickness == 1.5
            and sameColor(oldStyle.color, { 1, 1, 1 })) or (validStyle(other)
            and oldStyle.mode == other.mode and oldStyle.thickness == other.thickness
            and sameColor(oldStyle.color, other.color))) then
            DamageColorDB.textStyles[20] = nil
        end
        DamageColorDB.frostfireDefaultsVersion = 1
    end
    for school, default in pairs(defaults) do
        local color = DamageColorDB.colors[school]
        addon.colors[school] = copy(valid(color) and color or default)
        DamageColorDB.colors[school] = copy(addon.colors[school])
        local style = DamageColorDB.textStyles[school]
        -- Upgrade only the previous default; preserve customized edges.
        if DamageColorDB.textStyleDefaultsVersion ~= 3 and validStyle(style) then
            local oldOutline = DamageColorDB.textStyleDefaultsVersion ~= 2
                and style.mode == "outline" and style.thickness == 1
                and style.color[1] == 0 and style.color[2] == 0 and style.color[3] == 0
            local oldGlow = style.mode == "glow" and style.thickness == 1.5
                and style.color[1] == 1 and style.color[2] == 1 and style.color[3] == 1
            if oldOutline or oldGlow then style = defaultStyle(school) end
        end
        addon.textStyles[school] = validStyle(style) and copyStyle(style) or defaultStyle(school)
        DamageColorDB.textStyles[school] = copyStyle(addon.textStyles[school])
    end
    DamageColorDB.textStyleDefaultsVersion = 3
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
    if addon.OnTextStyleChanged then addon.OnTextStyleChanged() end
    self:UnregisterEvent("ADDON_LOADED")
end)
