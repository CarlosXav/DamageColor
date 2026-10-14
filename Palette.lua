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
    if addon.OnPaletteChanged then addon.OnPaletteChanged() end
    self:UnregisterEvent("ADDON_LOADED")
end)
